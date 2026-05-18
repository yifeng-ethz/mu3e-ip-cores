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

entity farm_midas_event_builder_intrun22 is
port (
    i_rx                : in    work.mu3e.link32_t;
    o_ren               : out   std_logic;
    i_rempty            : in    std_logic;

    -- Data type: "00" = pixel, "01" = scifi, "10" = tiles
    i_data_type         : in    std_logic_vector(1 downto 0) := "00";
    i_event_id          : in    std_logic_vector(15 downto 0) := x"0001";

    -- DDR
    o_data              : out   std_logic_vector(511 downto 0);
    o_wen               : out   std_logic;
    o_event_ts          : out   std_logic_vector(47 downto 0);
    i_ddr_ready         : in    std_logic;
    o_state_out         : out   std_logic_vector(3 downto 0);
    o_sop               : out   std_logic;
    o_eop               : out   std_logic;
    o_err               : out   std_logic;

    --! status counters
    --! 0: bank_builder_idle_not_header
    --! 1: bank_builder_skip_event
    --! 2: bank_builder_cnt_event
    --! 3: bank_builder_tag_fifo_full
    o_counters          : out   slv32_array_t(3 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of farm_midas_event_builder_intrun22 is

    -- tagging fifo
    type event_tagging_state_type is (
        event_head, event_num, event_tmp, event_size, bank_size, bank_flags, bank_name, bank_type, bank_length, bank_data, bank_set_length, event_set_size, bank_set_size, write_tagging_fifo, set_algin_word, bank_reserved, EVENT_IDLE--,
    );
    signal event_tagging_state : event_tagging_state_type;
    signal e_size_addr, b_size_addr, b_length_addr, w_ram_add_reg, w_ram_addr, last_event_addr, align_event_size : std_logic_vector(11 downto 0);
    signal w_fifo_data, r_fifo_data : std_logic_vector(13 + 48 - 1 downto 0);
    signal w_fifo_en, r_fifo_en, tag_fifo_empty, tag_fifo_full, is_error, is_error_q : std_logic;
    signal ts_tagging : std_logic_vector(47 downto 0);

    -- ram
    signal w_ram_en : std_logic;
    signal r_ram_addr : std_logic_vector(7 downto 0);
    signal w_ram_data : std_logic_vector(31 downto 0);
    signal r_ram_data : std_logic_vector(511 downto 0);

    -- midas event
    signal trigger_mask : std_logic_vector(15 downto 0);
    signal serial_number, time_tmp, type_bank, flags, bank_size_cnt, event_size_cnt : std_logic_vector(31 downto 0);

    -- event readout state machine
    type event_counter_state_type is (waiting, get_data, runing, skip_event);
    signal event_counter_state : event_counter_state_type;
    signal cnt_4kb_done : std_logic;
    signal event_last_ram_addr : std_logic_vector(7 downto 0);
    signal word_counter, word_counter_endofevent, cnt_4kb : std_logic_vector(31 downto 0);

    -- error cnt
    signal cnt_tag_fifo_full : std_logic_vector(31 downto 0);
    signal cnt_ram_full : std_logic_vector(31 downto 0);
    signal cnt_skip_event, cnt_event : std_logic_vector(31 downto 0);
    signal cnt_idle_not_header : std_logic_vector(31 downto 0);

begin

    --! counter
    o_counters(0) <= cnt_idle_not_header;
    o_counters(1) <= cnt_skip_event;
    o_counters(2) <= cnt_event;
    e_cnt_tag_fifo : entity work.counter
    generic map ( WRAP => true, W => 32 )
    port map ( o_cnt => o_counters(3), i_ena => tag_fifo_full, i_reset_n => i_reset_n, i_clk => i_clk );

    --! data out
    o_data <= r_ram_data;

    e_ram_32_512 : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 12,
        g_ADDR1_WIDTH => 8,
        g_DATA0_WIDTH => 32,
        g_DATA1_WIDTH => 512--,
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
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => 13+48--,
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

    o_ren <=
        '1' when ( event_tagging_state = bank_data and i_rempty = '0' ) else
        '1' when ( event_tagging_state = EVENT_IDLE and i_rempty = '0' and i_rx.sop = '0' ) else
        '0';

    -- write link data to event ram
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        e_size_addr         <= (others => '0');
        b_size_addr         <= (others => '0');
        b_length_addr       <= (others => '0');
        w_ram_add_reg       <= (others => '0');
        last_event_addr     <= (others => '0');
        align_event_size    <= (others => '0');

        -- ram and tagging fifo write signals
        w_ram_en            <= '0';
        w_ram_data          <= (others => '0');
        w_ram_addr          <= (others => '1');
        w_fifo_en           <= '0';
        w_fifo_data         <= (others => '0');
        is_error            <= '0';
        ts_tagging          <= (others => '0');

        -- midas signals
        trigger_mask        <= (others => '0');
        serial_number       <= x"00000001";
        time_tmp            <= (others => '0');
        flags               <= x"00000031";
        type_bank           <= x"00000006"; -- MIDAS Bank Type TID_DWORD

        -- for size counting in bytes
        bank_size_cnt       <= (others => '0');
        event_size_cnt      <= (others => '0');
        cnt_idle_not_header <= (others => '0');

        -- state machine singals
        event_tagging_state <= EVENT_IDLE;

    --
    elsif rising_edge(i_clk) then
        flags           <= x"00000031";
        trigger_mask    <= (others => '0');
        type_bank       <= x"00000006";
        w_ram_en        <= '0';
        w_fifo_en       <= '0';

        if ( event_tagging_state /= EVENT_IDLE ) then
            -- count time for midas event header
            time_tmp <= time_tmp + '1';
        end if;

        case event_tagging_state is
        when EVENT_IDLE =>
            -- start if at least one not masked link has data
            if ( i_rempty = '0' and i_rx.sop = '1' ) then
                event_tagging_state <= event_head;
            elsif ( i_rempty = '0' and i_rx.sop = '0' ) then
                cnt_idle_not_header <= cnt_idle_not_header + 1;
            end if;

        when event_head =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= trigger_mask & i_event_id;
            last_event_addr     <= w_ram_addr + 1;
            event_tagging_state <= event_num;

        when event_num =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= serial_number;
            event_tagging_state <= event_tmp;

        when event_tmp =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= time_tmp;
            event_tagging_state <= event_size;

        when event_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= (others => '0');
            event_tagging_state <= bank_size;
            e_size_addr         <= w_ram_addr + 1;

        when bank_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= (others => '0');
            event_size_cnt      <= event_size_cnt + 4;
            b_size_addr         <= w_ram_addr + 1;
            event_tagging_state <= bank_flags;

        when bank_flags =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_add_reg       <= w_ram_addr + 1;
            w_ram_data          <= flags;
            event_size_cnt      <= event_size_cnt + 4;
            event_tagging_state <= bank_name;

        when bank_name =>
            -- here we check if the link is empty and if we saw a header
            if ( i_rempty = '0' and i_rx.sop = '1' ) then
                w_ram_en    <= '1';
                w_ram_addr  <= w_ram_add_reg + 1;
                -- MIDAS expects bank names in ascii:
                -- For the run 2021
                -- PCD1 = PixelCentralDebug1
                -- SCD1 = ScifiCentralDebug1
                -- TCD1 = TileCentralDebug1
                -- NONE else
                if ( i_data_type = "00" ) then
                    w_ram_data <= x"31444350";
                elsif ( i_data_type = "01" ) then
                    w_ram_data <= x"31444353";
                elsif ( i_data_type = "10" ) then
                    w_ram_data <= x"31444354";
                else
                    w_ram_data <= x"454E4F4E";
                end if;
                event_size_cnt      <= event_size_cnt + 4;
                event_tagging_state <= bank_type;
            end if;

        when bank_type =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= type_bank;
            event_size_cnt      <= event_size_cnt + 4;
            event_tagging_state <= bank_length;

        when bank_length =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= (others => '0');
            event_size_cnt      <= event_size_cnt + 4;
            b_length_addr       <= w_ram_addr + 1;
            event_tagging_state <= bank_reserved;

        when bank_reserved =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_data          <= (others => '0');
            event_size_cnt      <= event_size_cnt + 4;
            event_tagging_state <= bank_data;

        when bank_data =>
            -- check again if the fifo is empty
            if ( i_rempty = '0' ) then
                w_ram_en            <= '1';
                w_ram_addr          <= w_ram_addr + 1;
                if ( i_rx.err = '1' ) then
                    is_error <= '1';
                end if;
                if ( i_rx.eop = '1' ) then
                    w_ram_data(31 downto 12)    <= x"FC000";
                    w_ram_data(11 downto 8)     <= "00" & i_rx.data(9 downto 8);
                    w_ram_data(7 downto 0)      <= x"9C";
                else
                    w_ram_data      <= i_rx.data;
                end if;
                if ( i_rx.t0 = '1' ) then
                    ts_tagging(47 downto 16) <= i_rx.data;
                end if;
                if ( i_rx.t1 = '1' ) then
                    ts_tagging(15 downto 0) <= i_rx.data(31 downto 16);
                end if;
                event_size_cnt      <= event_size_cnt + 4;
                bank_size_cnt       <= bank_size_cnt + 4;
                if ( i_rx.eop = '1' or i_rx.err = '1' ) then
                    event_tagging_state <= set_algin_word;
                    align_event_size    <= w_ram_addr + 1 - last_event_addr;
                end if;
            end if;

        when set_algin_word =>
            w_ram_en            <= '1';
            w_ram_addr          <= w_ram_addr + 1;
            w_ram_add_reg       <= w_ram_addr + 1;
            w_ram_data          <= x"AFFEAFFE";
            align_event_size    <= align_event_size + 1;
            -- check if the size of the bank data
            -- is in 64 bit and 256 bit
            -- if not add a dummy words
            if ( align_event_size(3 downto 0) + '1' = "0000" ) then
                event_tagging_state <= bank_set_length;
            else
                bank_size_cnt   <= bank_size_cnt + 4;
                event_size_cnt  <= event_size_cnt + 4;
            end if;

        when bank_set_length =>
            w_ram_en            <= '1';
            w_ram_addr          <= b_length_addr;
            w_ram_add_reg       <= w_ram_addr;
            w_ram_data          <= bank_size_cnt;
            bank_size_cnt       <= (others => '0');
            event_tagging_state <= event_set_size;

        when event_set_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= e_size_addr;
            -- Event Data Size: The event data size contains the size of the event in bytes excluding the event header
            w_ram_data          <= event_size_cnt;
            event_tagging_state <= bank_set_size;

        when bank_set_size =>
            w_ram_en            <= '1';
            w_ram_addr          <= b_size_addr;
            -- All Bank Size : Size in bytes of the following data banks including their bank names
            w_ram_data          <= event_size_cnt - 8;
            event_size_cnt      <= (others => '0');
            event_tagging_state <= write_tagging_fifo;

        when write_tagging_fifo =>
            w_fifo_en           <= '1';
            if ( is_error = '1' ) then
                w_fifo_data     <= ts_tagging & '1' & w_ram_add_reg;
            else
                w_fifo_data     <= ts_tagging & '0' & w_ram_add_reg;
            end if;
            ts_tagging          <= (others => '0');
            last_event_addr     <= w_ram_add_reg;
            w_ram_addr          <= w_ram_add_reg - 1;
            event_tagging_state <= EVENT_IDLE;
            b_length_addr       <= (others => '0');
            serial_number       <= serial_number + '1';

        when others =>
            event_tagging_state <= EVENT_IDLE;

        end case;

    end if;
    end process;


    -- dma end of events, count events and write control
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_sop               <= '0';
        o_eop               <= '0';
        o_err               <= '0';
        o_wen               <= '0';
        o_event_ts          <= (others => '0');
        cnt_skip_event      <= (others => '0');
        cnt_event           <= (others => '0');
        r_fifo_en           <= '0';
        r_ram_addr          <= (others => '1');
        event_last_ram_addr <= (others => '0');
        event_counter_state <= waiting;
        --
    elsif rising_edge(i_clk) then

        r_fifo_en       <= '0';
        o_wen           <= '0';
        o_sop           <= '0';
        o_eop           <= '0';
        o_err           <= '0';

        case event_counter_state is
        when waiting =>
            o_state_out             <= x"A";
            -- check if we have an event
            if ( tag_fifo_empty = '0' ) then
                r_fifo_en           <= '1';
                event_last_ram_addr <= r_fifo_data(11 downto 4);
                o_err               <= r_fifo_data(12);
                o_event_ts          <= r_fifo_data(60 downto 13);
                r_ram_addr          <= r_ram_addr + '1';
                event_counter_state <= get_data;
            end if;

        when get_data =>
            o_state_out             <= x"B";
            -- skip event if the DDR is not ready
            if ( i_ddr_ready = '0' ) then
                event_counter_state <= skip_event;
                cnt_skip_event      <= cnt_skip_event + '1';
            else
                o_wen               <= '1';
                o_sop               <= '1';
                cnt_event           <= cnt_event + '1';
                event_counter_state <= runing;
            end if;
            r_ram_addr <= r_ram_addr + '1';

        when runing =>
            o_state_out             <= x"C";
            o_wen                   <= '1';
            if(r_ram_addr = event_last_ram_addr - '1') then
                o_eop               <= '1'; -- end of event
                event_counter_state <= waiting;
            else
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when skip_event =>
            o_state_out <= x"D";
            if(r_ram_addr = event_last_ram_addr - '1') then
                event_counter_state <= waiting;
            else
                r_ram_addr <= r_ram_addr + '1';
            end if;

        when others =>
            o_state_out         <= x"E";
            event_counter_state <= waiting;

        end case;

    end if;
    end process;

end architecture;
