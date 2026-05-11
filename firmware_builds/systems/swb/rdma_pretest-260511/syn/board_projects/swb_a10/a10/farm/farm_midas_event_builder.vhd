-------------------------------------------------------
--! farm_midas_event_builder.vhd
--! @brief the @farm_midas_event_builder builds 32a_banks
--! for MIDAS which are stored in the DDR Memory
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity farm_midas_event_builder is
generic (
    g_NLINKS_SWB_TOTL    : positive :=  16;
    N_PIXEL              : positive :=  8;
    N_SCIFI              : positive :=  8;
    RAM_ADDR             : positive :=  12--;
);
port (
    i_pixel             : in  std_logic_vector(N_PIXEL * 32 + 1 downto 0);
    i_empty_pixel       : in  std_logic;
    o_ren_pixel         : out std_logic;

    i_scifi             : in  std_logic_vector(N_SCIFI * 32 + 1 downto 0);
    i_empty_scifi       : in  std_logic;
    o_ren_scifi         : out std_logic;

    i_farm_id           : in  std_logic_vector(31 downto 0);
    i_builder_ctl       : in  std_logic_vector(31 downto 0);

    -- DDR
    o_data              : out std_logic_vector(511 downto 0);
    o_wen               : out std_logic;
    o_event_ts          : out std_logic_vector(47 downto 0);
    i_ddr_ready         : in  std_logic;

    -- Link data
    o_pixel             : out std_logic_vector(N_PIXEL * 32 + 1 downto 0);
    o_wen_pixel         : out std_logic;

    o_scifi             : out std_logic_vector(N_SCIFI * 32 + 1 downto 0);
    o_wen_scifi         : out std_logic;

    --! status counters
    --! 0: cnt_idle_not_header_pixel
    --! 1: cnt_idle_not_header_scifi
    --! 2: bank_builder_ram_full
    --! 3: bank_builder_tag_fifo_full
    --! 4: # events written to RAM (one subheader of Pixel and Scifi)
    --! 5: # 256b pixel x"FFF"
    --! 6: # 256b scifi x"FFF"
    --! 7: # 256b pixel written to link
    --! 8: # 256b scifi written to link
    o_counters          : out   slv32_array_t(8 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of farm_midas_event_builder is

    -- convert functions
    function convert_to_64_pixel(
        hit_38  : std_logic_vector;
        N       : integer;
        TS      : std_logic_vector--;
    ) return std_logic_vector is
        variable hit_38_v : std_logic_vector(hit_38'length-1 downto 0);
        variable hit_64 : std_logic_vector(N*64-1 downto 0);
    begin
        hit_38_v := hit_38;
        for i in 0 to N-1 loop
            if ( hit_38_v(i * 38 + 37 downto i * 38) = x"3FFFFFFFFF" ) then
                hit_64(i * 64 + 63 downto i * 64) := (others => '1');
            else
                hit_64(i * 64 + 63 downto i * 64) := "00" & x"000000" & hit_38_v(i * 38 + 37 downto i * 38);
            end if;
        end loop;
        return hit_64;
    end function;

    function convert_to_64_scifi(
        hit_38  : std_logic_vector;
        N       : integer;
        TS      : std_logic_vector--;
    ) return std_logic_vector is
        variable hit_38_v : std_logic_vector(hit_38'length-1 downto 0);
        variable hit_64 : std_logic_vector(N*64-1 downto 0);
    begin
        hit_38_v := hit_38;
        for i in 0 to N-1 loop
            if ( hit_38_v(i * 38 + 37 downto i * 38) = x"3FFFFFFFFF" ) then
                hit_64(i * 64 + 63 downto i * 64) := (others => '1');
            else
                -- ASIC #
                hit_64(i * 64 + 63 downto i * 64 + 60) := hit_38_v(i * 38 + 31 downto i * 38 + 28);
                -- Hit type
                hit_64(i * 64 + 59) := hit_38_v(i * 38 + 27);
                -- Channel #
                hit_64(i * 64 + 58 downto i * 64 + 54) := hit_38_v(i * 38 + 26 downto i * 38 + 22);
                -- Timestamp bad hit
                hit_64(i * 64 + 53) := hit_38_v(i * 38 + 21);
                -- Coarse counter value
                hit_64(i * 64 + 52 downto i * 64 + 38) := hit_38_v(i * 38 + 20 downto i * 38 + 6);
                -- Fine counter value
                hit_64(i * 64 + 37 downto i * 64 + 33) := hit_38_v(i * 38 + 5 downto i * 38 + 1);
                -- Energy flag
                hit_64(i * 64 + 32) := hit_38_v(i * 38 + 0);
                -- FPGA ID = LINK ID on the SWB
                hit_64(i * 64 + 31 downto i * 64 + 28) := hit_38_v(i * 38 + 35 downto i * 38 + 32);
                -- Timestamp
                hit_64(i * 64 + 27 downto i * 64 + 0) := TS(27 downto 0);
            end if;
        end loop;
        return hit_64;
    end function;

    -- tagging fifo
    type event_tagging_state_type is (
        EVENT_IDLE, event_head, bank_data_pixel_header, bank_data_pixel_one,
        bank_data_pixel, bank_data_scifi_header, bank_data_scifi_one,
        bank_data_scifi, align_event_size, bank_set_length_pixel,
        bank_set_length_scifi, write_tagging_fifo, bank_set_length_scifi_only--,
    );
    signal event_tagging_state : event_tagging_state_type;
    signal w_ram_addr_reg, w_ram_addr, scifi_header_addr, header_addr : std_logic_vector(RAM_ADDR-1 downto 0);
    signal w_fifo_data, r_fifo_data : std_logic_vector(RAM_ADDR + 47 downto 0);
    signal w_fifo_en, r_fifo_en, tag_fifo_empty, tag_fifo_full : std_logic;

    -- event readout state machine
    type event_counter_state_type is (waiting, get_data, runing, skip_event);
    signal event_counter_state : event_counter_state_type;
    signal event_last_ram_addr : std_logic_vector(RAM_ADDR-1 downto 0);
    type convert_data_type is (idle, one, two, three);
    signal convert_data : convert_data_type;

    -- ram
    signal w_ram_en, wen_convert_fifo, empty_convert_fifo, ren_convert_fifo, rdreq_convert_fifo : std_logic;
    signal data_reg : std_logic_vector(511 downto 0);
    signal q_convert_fifo : std_logic_vector(383 downto 0);
    signal r_ram_addr : std_logic_vector(RAM_ADDR-1 downto 0);
    signal header_pixel : std_logic_vector(N_PIXEL * 32 + 1 downto 0);
    signal header_scifi : std_logic_vector(N_SCIFI * 32 + 1 downto 0);
    signal w_ram_header, w_ram_data, w_ram_pixel_header, w_ram_scifi_data : std_logic_vector(383 downto 0);
    signal r_ram_data : std_logic_vector(383 downto 0);
    signal bank_size_pixel, bank_size_scifi : std_logic_vector(31 downto 0);
    signal i_scifi_reg, i_pixel_reg : std_logic_vector(255 downto 0);

    -- midas event
    signal event_id, trigger_mask : std_logic_vector(15 downto 0);
    signal serial_number, time_tmp, type_bank, flags, event_size_cnt : std_logic_vector(31 downto 0);

    -- bank bank builder
    signal pixel_header, pixel_trailer, scifi_header, scifi_trailer, pixel_error, scifi_error : std_logic;
    signal ts : std_logic_vector(47 downto 0);

    -- error cnt
    signal cnt_idle_not_header_pixel, cnt_idle_not_header_scifi, cnt_idle_pixel_marked, cnt_idle_scifi_marked : std_logic_vector(31 downto 0);
    signal ram_halffull, cnt_fff : std_logic;
    signal sub_addr : std_logic_vector(RAM_ADDR-1 downto 0);

begin

    --! counter
    o_counters(0) <= cnt_idle_not_header_pixel;

    o_counters(1) <= cnt_idle_not_header_scifi;

    -- calculate ram halffull
    sub_addr <= w_ram_addr - r_ram_addr when w_ram_addr >= r_ram_addr else r_ram_addr - w_ram_addr;
    -- TODO: think about 3/4 5/6 etc. full
    ram_halffull <= sub_addr(RAM_ADDR-1) when tag_fifo_empty = '0' else '0';
    e_cnt_ram_halffull : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(2), i_ena => ram_halffull, i_reset_n => i_reset_n, i_clk => i_clk );

    e_cnt_tag_fifo : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(3), i_ena => tag_fifo_full, i_reset_n => i_reset_n, i_clk => i_clk );

    o_counters(4) <= serial_number;

    o_counters(5) <= cnt_idle_pixel_marked;

    o_counters(6) <= cnt_idle_scifi_marked;

    e_cnt_pixel_link : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(7), i_ena => not i_empty_pixel, i_reset_n => i_reset_n, i_clk => i_clk );

    e_cnt_scifi_link : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(8), i_ena => not i_empty_scifi, i_reset_n => i_reset_n, i_clk => i_clk );

    e_ram_32_256 : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => RAM_ADDR,
        g_ADDR1_WIDTH => RAM_ADDR,
        g_DATA0_WIDTH => 384,
        g_DATA1_WIDTH => 384--,
    )
    port map (
        i_addr0     => w_ram_addr,
        i_addr1     => r_ram_addr,
        i_clk0      => i_clk,
        i_clk1      => i_clk,
        i_wdata0    => w_ram_data,
        i_wdata1    => (others => '0'),
        i_we0       => w_ram_en,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => r_ram_data--,
    );

    e_tagging_fifo_event : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => RAM_ADDR,
        g_DATA_WIDTH => RAM_ADDR + 48--,
    )
    port map (
        i_we        => w_fifo_en,
        i_wdata     => w_fifo_data,
        o_wfull     => tag_fifo_full,

        i_rack      => r_fifo_en,
        o_rdata     => r_fifo_data,
        o_rempty    => tag_fifo_empty,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    -- TODO: check full status
    e_convert_hits : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 6,
        g_DATA_WIDTH => 384--,
    )
    port map (
        i_we        => wen_convert_fifo,
        i_wdata     => r_ram_data,
        o_wfull     => open,

        i_rack      => rdreq_convert_fifo,
        o_rdata     => q_convert_fifo,
        o_rempty    => empty_convert_fifo,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    pixel_header <= '1' when i_pixel(N_PIXEL * 32 + 1 downto N_PIXEL * 32) = "01" else '0';
    pixel_trailer<= '1' when i_pixel(N_PIXEL * 32 + 1 downto N_PIXEL * 32) = "10" else '0';
    -- TODO: what to do with the error (run should be stopped)?
    pixel_error  <= '1' when i_pixel(N_PIXEL * 32 + 1 downto N_PIXEL * 32) = "11" else '0';
    scifi_header <= '1' when i_scifi(N_SCIFI * 32 + 1 downto N_SCIFI * 32) = "01" else '0';
    scifi_trailer<= '1' when i_scifi(N_SCIFI * 32 + 1 downto N_SCIFI * 32) = "10" else '0';
    -- TODO: what to do with the error (run should be stopped)?
    scifi_error  <= '1' when i_pixel(N_PIXEL * 32 + 1 downto N_PIXEL * 32) = "11" else '0';

    o_ren_pixel <=
        '1' when ( (event_tagging_state = bank_data_pixel or event_tagging_state = bank_data_pixel_one) and i_empty_pixel = '0' and pixel_header = '0' ) else
        '1' when ( event_tagging_state = event_head and i_empty_pixel = '0' ) else
        '1' when ( event_tagging_state = EVENT_IDLE and i_empty_pixel = '0' and pixel_header = '0' and i_pixel(223 downto 200) = x"FFFFFF" ) else
        '0';

    o_ren_scifi <=
        '1' when ( (event_tagging_state = bank_data_scifi or event_tagging_state = bank_data_scifi_one) and i_empty_scifi = '0' and scifi_header = '0' ) else
        '1' when ( event_tagging_state = event_head and i_empty_scifi = '0' ) else
        '1' when ( event_tagging_state = EVENT_IDLE and i_empty_scifi = '0' and scifi_header = '0' and i_scifi(223 downto 200) = x"FFFFFF" ) else
        '0';

    -- mark if data is send to DDR3 for the next farm pc
    -- TODO: make marking with only 1 bit or max number of FARM PC
    o_pixel(N_PIXEL * 32 + 1 downto 224) <= i_pixel(N_PIXEL * 32 + 1 downto 224);
    o_pixel(223 downto 200) <= x"000000" when ( event_tagging_state = EVENT_IDLE and (pixel_header = '0' or scifi_header = '0' or ram_halffull = '0') ) else x"FFFFFF";
    o_pixel(199 downto 0) <= i_pixel(199 downto 0);
    o_wen_pixel <= not i_empty_pixel;
    cnt_fff <= '0' when ( event_tagging_state = EVENT_IDLE and (pixel_header = '0' or scifi_header = '0' or ram_halffull = '0') ) else '1';
    o_scifi(N_SCIFI * 32 + 1 downto 224) <= i_scifi(N_SCIFI * 32 + 1 downto 224);
    o_scifi(223 downto 200) <= x"000000" when ( event_tagging_state = EVENT_IDLE and (pixel_header = '0' or scifi_header = '0' or ram_halffull = '0') ) else x"FFFFFF";
    o_scifi(199 downto 0) <= i_scifi(199 downto 0);
    o_wen_scifi <= not i_empty_scifi;

    -- write link data to event ram
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        -- ram and tagging fifo write signals
        w_ram_en            <= '0';
        w_ram_data          <= (others => '0');
        w_ram_addr          <= (others => '1');
        w_fifo_en           <= '0';
        w_fifo_data         <= (others => '0');
        w_ram_addr_reg      <= (others => '0');
        w_ram_pixel_header  <= (others => '0');
        w_ram_scifi_data    <= (others => '0');
        i_scifi_reg         <= (others => '0');
        i_pixel_reg         <= (others => '0');

        -- midas signals
        event_id            <= x"0001";
        trigger_mask        <= (others => '0');
        -- TODO: ask stefan what to do with 2 farms
        serial_number       <= x"00000001";
        time_tmp            <= (others => '0');
        flags               <= x"00000031";
        type_bank           <= x"00000006"; -- MIDAS Bank Type TID_DWORD

        -- counters
        event_size_cnt      <= (others => '0');
        cnt_idle_not_header_pixel <= (others => '0');
        cnt_idle_not_header_scifi <= (others => '0');
        cnt_idle_pixel_marked <= (others => '0');
        cnt_idle_scifi_marked <= (others => '0');
        bank_size_pixel <= (others => '0');
        bank_size_scifi <= (others => '0');

        -- state machine singals
        event_tagging_state <= EVENT_IDLE;

        --
    elsif rising_edge(i_clk) then
        flags           <= x"00000031";
        trigger_mask    <= (others => '0');
        event_id        <= x"0001";
        type_bank       <= x"00000006";
        w_ram_en        <= '0';
        w_fifo_en       <= '0';

        if ( event_tagging_state /= EVENT_IDLE ) then
            -- count time for midas event header
            time_tmp <= time_tmp + '1';
        end if;

        -- ram back-pressure
        if ( ram_halffull = '0' ) then
            case event_tagging_state is
            when EVENT_IDLE =>

                if ( i_empty_pixel = '0' and pixel_header = '0' ) then
                    cnt_idle_not_header_pixel <= cnt_idle_not_header_pixel + 1;
                end if;

                if ( i_empty_scifi = '0' and scifi_header = '0' ) then
                    cnt_idle_not_header_scifi <= cnt_idle_not_header_scifi + 1;
                end if;

                if ( i_empty_pixel = '0' and i_pixel(223 downto 200) = x"FFFFFF" ) then
                    cnt_idle_pixel_marked <= cnt_idle_pixel_marked + 1;
                end if;

                if ( i_empty_scifi = '0' and i_scifi(223 downto 200) = x"FFFFFF" ) then
                    cnt_idle_scifi_marked <= cnt_idle_scifi_marked + 1;
                end if;

                -- default mode: readout pixel and scifi
                -- start when both scifi and pixel are not empty, both have header and ram_halffull = '0'
                if ( i_builder_ctl(USE_BIT_PIXEL_ONLY) = '0' and i_builder_ctl(USE_BIT_SCIFI_ONLY) = '0' ) then
                    if ( i_empty_scifi = '0' and i_empty_pixel = '0' and pixel_header = '1' and scifi_header = '1' and ram_halffull = '0' and i_pixel(223 downto 200) = x"000000" and i_scifi(223 downto 200) = x"000000" ) then
                        event_tagging_state <= event_head;
                        header_pixel        <= i_pixel;
                        header_scifi        <= i_scifi;
                    end if;
                -- readout only pixel
                -- start when pixel is not empty, has header and ram_halffull = '0'
                elsif ( i_builder_ctl(USE_BIT_PIXEL_ONLY) = '1' ) then
                    if ( i_empty_pixel = '0' and pixel_header = '1' and ram_halffull = '0' and i_pixel(223 downto 200) = x"000000" ) then
                        event_tagging_state <= event_head;
                        header_pixel        <= i_pixel;
                    end if;
                -- start when scifi is not empty, has header and ram_halffull = '0'
                elsif ( i_builder_ctl(USE_BIT_SCIFI_ONLY) = '1' ) then
                    if ( i_empty_scifi = '0' and scifi_header = '1' and ram_halffull = '0' and i_scifi(223 downto 200) = x"000000" ) then
                        event_tagging_state <= event_head;
                        header_scifi        <= i_scifi;
                    end if;
                end if;

            when event_head =>
                -- TODO: compare TS of headers --> error if not the same?
                -- if ( header_pixel(x downto y) /= header_scifi(x downto y) ) then
                --  error_ts_header <= '1';
                -- end if;

                -- store TS of headers for DDR address
                if ( i_builder_ctl(USE_BIT_SCIFI_ONLY) = '1' ) then
                    ts(15 downto  0) <= header_scifi(87 downto 72);
                    ts(31 downto 16) <= header_scifi(31 downto 16);
                    ts(47 downto 32) <= header_scifi(55 downto 40);
                else
                    ts(15 downto  0) <= header_pixel(87 downto 72);
                    ts(31 downto 16) <= header_pixel(31 downto 16);
                    ts(47 downto 32) <= header_pixel(55 downto 40);
                end if;

                -- event header
                w_ram_header( 31 downto   0) <= trigger_mask & event_id;
                w_ram_header( 63 downto  32) <= serial_number;
                w_ram_header( 95 downto  64) <= time_tmp;
                w_ram_header(127 downto  96) <= (others => '0'); -- e_size
                -- bank header
                w_ram_header(159 downto 128) <= (others => '0'); -- b_size
                w_ram_header(191 downto 160) <= flags;
                -- BANK32A (start with IPIX)
                w_ram_pixel_header(223 downto 192) <= x"58495049"; -- bank header
                w_ram_pixel_header(255 downto 224) <= type_bank;
                w_ram_pixel_header(287 downto 256) <= (others => '0'); -- bank length
                w_ram_pixel_header(319 downto 288) <= (others => '0'); -- bank reserved
                if ( i_builder_ctl(USE_BIT_SCIFI_ONLY) = '1' ) then
                    w_ram_header(351 downto 320) <= header_scifi(127 downto  96); -- overflow (24b) & 7C
                    w_ram_header(383 downto 352) <= header_scifi(159 downto 128); -- overflow (24b) & 7C
                    event_tagging_state          <= bank_data_scifi_header;
                else
                    w_ram_pixel_header(351 downto 320)  <= header_pixel(127 downto  96); -- overflow (24b) & 7C
                    w_ram_pixel_header(383 downto 352)  <= header_pixel(159 downto 128); -- overflow (24b) & 7C
                    event_tagging_state                 <= bank_data_pixel_header;
                end if;
                w_ram_data                 <= (others => '0');
                event_size_cnt             <= event_size_cnt + 8*4; -- b_size, flags, bank name, bank type, bank length, bank reserved, overflow, overflow
                header_addr                <= w_ram_addr + 1;
                w_ram_addr                 <= w_ram_addr + 1;
                w_ram_en                   <= '1';

            when bank_data_pixel_header =>
                w_ram_data(31 downto 0)         <= i_farm_id; -- reserved
                if ( i_builder_ctl(USE_BIT_SCIFI_ONLY) = '1' ) then
                    w_ram_data(63 downto 32)    <= header_scifi(31 downto 16) & header_scifi(87 downto 72); --reserved (TS(31:0))
                    event_tagging_state         <= bank_data_scifi_one;
                else
                    w_ram_data(63 downto 32)    <= header_pixel(31 downto 16) & header_pixel(87 downto 72); --reserved (TS(31:0))
                    event_tagging_state         <= bank_data_pixel_one;
                end if;

            when bank_data_pixel_one =>
                -- check again if the fifo is empty and no header/trailer
                if ( i_empty_pixel = '0' and pixel_header = '0' and pixel_trailer = '0' ) then
                    -- convert 5 38 bit hits to 5 64 bit hits
                    w_ram_data(383 downto 64) <= convert_to_64_pixel(i_pixel(189 downto 0), 5, ts);
                    i_pixel_reg(63 downto 0)  <= convert_to_64_pixel(i_pixel(227 downto 190), 1, ts);
                    event_size_cnt            <= event_size_cnt + 12*4;
                    bank_size_pixel           <= bank_size_pixel + 14*4;
                    w_ram_addr                <= w_ram_addr + 1;
                    w_ram_en                  <= '1';
                    event_tagging_state       <= bank_data_pixel;
                elsif ( pixel_header = '1' or pixel_trailer = '1' ) then
                    w_ram_data(383 downto 64) <= (others => '1');
                    event_size_cnt            <= event_size_cnt + 12*4;
                    bank_size_pixel           <= bank_size_pixel + 14*4;
                    w_ram_addr                <= w_ram_addr + 1;
                    w_ram_en                  <= '1';
                    if ( i_builder_ctl(USE_BIT_PIXEL_ONLY) /= '1' ) then
                        event_tagging_state   <= bank_data_scifi_header;
                    else
                        event_tagging_state   <= align_event_size;
                    end if;
                end if;

            when bank_data_pixel =>
                -- check again if the fifo is empty and no header/trailer
                if ( i_empty_pixel = '0' and pixel_header = '0' and pixel_trailer = '0' ) then
                    w_ram_data(63 downto 0)   <= i_pixel_reg(63 downto 0);
                    w_ram_data(383 downto 64) <= convert_to_64_pixel(i_pixel(189 downto 0), 5, ts);
                    i_pixel_reg(63 downto 0)  <= convert_to_64_pixel(i_pixel(227 downto 190), 1, ts);
                    event_size_cnt            <= event_size_cnt + 12*4;
                    bank_size_pixel           <= bank_size_pixel + 12*4;
                    w_ram_addr                <= w_ram_addr + 1;
                    w_ram_en                  <= '1';
                elsif ( pixel_header = '1' or pixel_trailer = '1' ) then
                    w_ram_data(63 downto 0)   <= i_pixel_reg(63 downto 0);
                    w_ram_data(383 downto 64) <= (others => '1');
                    event_size_cnt            <= event_size_cnt + 12*4;
                    bank_size_pixel           <= bank_size_pixel + 12*4;
                    w_ram_addr                <= w_ram_addr + 1;
                    w_ram_en                  <= '1';
                    if ( i_builder_ctl(USE_BIT_PIXEL_ONLY) = '1' ) then
                        event_tagging_state   <= align_event_size;
                    else
                        event_tagging_state   <= bank_data_scifi_header;
                    end if;
                end if;

            when bank_data_scifi_header =>
                -- BANK32A ISCI
                w_ram_scifi_data( 31 downto   0) <= x"49435349"; -- bank header
                w_ram_scifi_data( 63 downto  32) <= type_bank;
                w_ram_scifi_data( 95 downto  64) <= (others => '0'); -- bank length
                w_ram_scifi_data(127 downto  96) <= (others => '0'); -- bank reserved
                w_ram_scifi_data(159 downto 128) <= header_scifi(127 downto  96); -- overflow (24b) & 7C
                w_ram_scifi_data(191 downto 160) <= header_scifi(159 downto 128); -- overflow (24b) & 7C
                w_ram_scifi_data(223 downto 192) <= i_farm_id; -- reserved
                w_ram_scifi_data(255 downto 224) <= header_scifi(31 downto 16) & header_scifi(87 downto 72); --reserved (TS(31:0))
                event_tagging_state              <= bank_data_scifi_one;

            when bank_data_scifi_one =>
                -- check again if the fifo is empty and no header/trailer
                if ( i_empty_scifi = '0' and scifi_header = '0' and scifi_trailer = '0' ) then
                    -- convert 2 38 bit hits to 2 64 bit hits
                    w_ram_scifi_data(383 downto 256)    <= convert_to_64_scifi(i_scifi(75 downto 0), 2, ts);
                    i_scifi_reg(255 downto 0)           <= convert_to_64_scifi(i_scifi(227 downto 76), 4, ts);
                    event_size_cnt                      <= event_size_cnt + 12*4;
                    bank_size_scifi                     <= bank_size_scifi + 16*4;
                    w_ram_addr                          <= w_ram_addr + 1;
                    scifi_header_addr                   <= w_ram_addr + 1;
                    w_ram_en                            <= '1';
                    event_tagging_state                 <= bank_data_scifi;
                elsif ( scifi_header = '1' or scifi_trailer = '1' ) then
                    w_ram_scifi_data(383 downto 256)    <= (others => '1');
                    event_size_cnt                      <= event_size_cnt + 12*4;
                    bank_size_scifi                     <= bank_size_scifi + 16*4;
                    w_ram_addr                          <= w_ram_addr + 1;
                    scifi_header_addr                   <= w_ram_addr + 1;
                    w_ram_en                            <= '1';
                    event_tagging_state                 <= align_event_size;
                end if;

            when bank_data_scifi =>
                -- check again if the fifo is empty and no header/trailer
                if ( i_empty_scifi = '0' and scifi_header = '0' and scifi_trailer = '0' ) then
                    -- convert 2 38 bit hits to 2 64 bit hits
                    w_ram_data(255 downto 0)  <= i_scifi_reg(255 downto 0);
                    w_ram_data(383 downto 256)<= convert_to_64_scifi(i_scifi(75 downto 0), 2, ts);
                    i_scifi_reg(255 downto 0) <= convert_to_64_scifi(i_scifi(227 downto 76), 4, ts);
                    event_size_cnt            <= event_size_cnt + 12*4;
                    bank_size_scifi           <= bank_size_scifi + 12*4;
                    w_ram_addr                <= w_ram_addr + 1;
                    w_ram_en                  <= '1';
                elsif ( scifi_header = '1' or scifi_trailer = '1' ) then
                    w_ram_data(255 downto 0)  <= i_scifi_reg(255 downto 0);
                    w_ram_data(383 downto 256)<= (others => '1');
                    event_size_cnt            <= event_size_cnt + 12*4;
                    bank_size_scifi           <= bank_size_scifi + 12*4;
                    w_ram_addr                <= w_ram_addr + 1;
                    w_ram_en                  <= '1';
                    event_tagging_state       <= align_event_size;
                end if;

            when align_event_size =>
                -- write padding
                w_ram_data(383 downto 0) <= (others => '1');
                event_size_cnt           <= event_size_cnt + 12*4;
                w_ram_addr               <= w_ram_addr + 1;
                w_ram_addr_reg           <= w_ram_addr + 1;
                w_ram_en                 <= '1';
                -- check if the size of the event data
                -- is in 512 bit if not add dummy words
                if ( w_ram_addr(1 downto 0) + '1' = "00" ) then
                    if ( i_builder_ctl(USE_BIT_SCIFI_ONLY) = '1' ) then
                        event_tagging_state <= bank_set_length_scifi_only;
                    else
                        event_tagging_state <= bank_set_length_pixel;
                    end if;
                else
                    event_size_cnt <= event_size_cnt + 12*4;
                    bank_size_scifi <= bank_size_scifi + 12*4;
                end if;

            when bank_set_length_pixel =>
                w_ram_en  <= '1';
                w_ram_addr <= header_addr;
                -- write header values
                w_ram_data( 95 downto   0) <= w_ram_header(95 downto 0);
                w_ram_data(127 downto  96) <= event_size_cnt; -- event size
                w_ram_data(159 downto 128) <= event_size_cnt - 8; -- all bank size
                w_ram_data(191 downto 160) <= w_ram_header(191 downto 160);
                w_ram_data(255 downto 192) <= w_ram_pixel_header(255 downto 192);
                w_ram_data(287 downto 256) <= bank_size_pixel; -- bank length pixel
                w_ram_data(383 downto 288) <= w_ram_pixel_header(383 downto 288);
                bank_size_pixel <= (others => '0');
                event_size_cnt  <= (others => '0');
                event_tagging_state <= bank_set_length_scifi;

            when bank_set_length_scifi_only =>
                w_ram_en  <= '1';
                w_ram_addr <= header_addr;
                -- write header values
                w_ram_data( 95 downto   0) <= w_ram_header(95 downto 0);
                w_ram_data(127 downto  96) <= event_size_cnt; -- event size
                w_ram_data(159 downto 128) <= event_size_cnt - 8; -- all bank size
                w_ram_data(191 downto 160) <= w_ram_header(191 downto 160);
                w_ram_data(255 downto 192) <= w_ram_pixel_header(255 downto 192);
                w_ram_data(287 downto 256) <= bank_size_scifi; -- bank length pixel
                w_ram_data(383 downto 288) <= w_ram_pixel_header(383 downto 288);
                bank_size_pixel <= (others => '0');
                event_size_cnt  <= (others => '0');
                event_tagging_state <= bank_set_length_scifi;

            when bank_set_length_scifi =>
                w_ram_en        <= '1';
                w_ram_addr      <= scifi_header_addr;
                -- write header values scifi
                w_ram_data( 63 downto   0)  <= w_ram_scifi_data( 63 downto   0);
                w_ram_data( 95 downto  64)  <= bank_size_scifi; -- bank length scifi
                w_ram_data(383 downto  96)  <= w_ram_scifi_data(383 downto   96);
                bank_size_scifi             <= (others => '0');
                event_tagging_state         <= write_tagging_fifo;

            when write_tagging_fifo =>
                w_fifo_en           <= '1';
                w_fifo_data         <= w_ram_addr_reg & ts;
                w_ram_addr          <= w_ram_addr_reg - 1;
                serial_number       <= serial_number + '1';
                event_tagging_state <= EVENT_IDLE;

            when others =>
                event_tagging_state <= EVENT_IDLE;

            end case;
        end if;
    end if;
    end process;

    -- readout MIDAS Bank Builder RAM
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        r_fifo_en               <= '0';
        wen_convert_fifo        <= '0';
        event_last_ram_addr     <= (others => '0');
        r_ram_addr              <= (others => '1');
        event_counter_state     <= waiting;
        --
    elsif rising_edge(i_clk) then

        r_fifo_en        <= '0';
        wen_convert_fifo <= '0';

        case event_counter_state is
        when waiting =>
            if ( tag_fifo_empty = '0' ) then
                r_fifo_en           <= '1';
                event_last_ram_addr <= r_fifo_data(RAM_ADDR+48-1 downto 48);
                r_ram_addr          <= r_ram_addr + '1';
                event_counter_state <= get_data;
            end if;

        when get_data =>
            -- if i_ddr_ready = '0' we switch from
            -- one DDR to the other we wait here until
            -- this happend so that we dont split events over
            -- the two DDR memories
            if ( i_ddr_ready = '1' ) then
                wen_convert_fifo <= '1';
                event_counter_state <= runing;
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when runing =>
            wen_convert_fifo <= '1';
            if(r_ram_addr = event_last_ram_addr - '1') then
                event_counter_state <= waiting;
            else
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when others =>
            event_counter_state <= waiting;

        end case;

    end if;
    end process;

    -- convert data width from 384 to 512
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_data          <= (others => '0');
        data_reg        <= (others => '0');
        o_wen           <= '0';
        convert_data    <= idle;
        o_event_ts      <= (others => '0');
        rdreq_convert_fifo <= '1';
        --
    elsif rising_edge(i_clk) then
        o_wen <= '0';
        case convert_data is
        when idle =>
            if ( empty_convert_fifo = '0' ) then
                rdreq_convert_fifo      <= '1';
                o_data(383 downto 0)    <= q_convert_fifo(383 downto 0);
                o_event_ts              <= q_convert_fifo(47 downto 0);
                convert_data            <= one;
            end if;

        when one =>
            if ( empty_convert_fifo = '0' ) then
                o_wen <= '1';
                rdreq_convert_fifo      <= '1';
                data_reg(255 downto 0)  <= q_convert_fifo(383 downto 128);
                o_data(511 downto 384)  <= q_convert_fifo(127 downto 0);
                convert_data <= two;
            end if;

        when two =>
            if ( empty_convert_fifo = '0' ) then
                o_wen <= '1';
                rdreq_convert_fifo      <= '1';
                data_reg(127 downto 0)  <= q_convert_fifo(383 downto 256);
                o_data(255 downto 0)    <= data_reg(255 downto 0);
                o_data(511 downto 256)  <= q_convert_fifo(255 downto 0);
                convert_data <= three;
            end if;

        when three =>
            if ( empty_convert_fifo = '0' ) then
                o_wen <= '1';
                rdreq_convert_fifo      <= '1';
                o_data(127 downto 0)    <= data_reg(127 downto 0);
                o_data(511 downto 128)  <= q_convert_fifo(383 downto 0);
                convert_data <= idle;
            end if;

        when others =>
            convert_data <= idle;
        end case;
    end if;
    end process;

end architecture;
