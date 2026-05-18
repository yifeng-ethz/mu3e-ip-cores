-------------------------------------------------------
--! @musip_mux_4_1.vhd
--! @brief the musip_mux_4_1 takes 4 input links and
--! generates one 256bit output word with 4 hits
--! Author: mkoepp@phys.ethz.ch
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mudaq.all;
use work.mu3e.all;

entity musip_mux_4_1 is
generic (
    -- TODO: this is not really something to change
    g_LINK_N : positive := 4
);
port (
    i_rx              : in  work.mu3e.link32_array_t(g_LINK_N-1 downto 0);
    i_rmask_n         : in  std_logic_vector(g_LINK_N-1 downto 0);
    i_use_direct_mux  : in  std_logic := '0';

    i_lookup_ctrl     : in  std_logic_vector(31 downto 0);

    o_subh_cnt        : out slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    o_hit_cnt         : out slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    o_package_cnt     : out slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    o_word_cnt        : out std_logic_vector(63 downto 0);

    o_subh_rate       : out slv32_array_t(g_LINK_N-1 downto 0);
    o_hit_rate        : out slv32_array_t(g_LINK_N-1 downto 0);
    o_package_rate    : out slv32_array_t(g_LINK_N-1 downto 0);
    o_word_rate       : out std_logic_vector(31 downto 0);

    o_data            : out std_logic_vector(255 downto 0);
    o_valid           : out std_logic;

    i_reset_n         : in  std_logic;
    i_clk             : in  std_logic
);
end entity;

architecture arch of musip_mux_4_1 is

    type int_0_3_array_t is array (natural range <>) of integer range 0 to 3;

    -- chip id lookup path
    signal FEBChipID            : slv6_array_t(g_LINK_N-1 downto 0);

    -- width must match chip_lookup.o_globalChipID
    -- if chip_lookup uses a different width, change this declaration accordingly
    signal globalChipID         : slv14_array_t(g_LINK_N-1 downto 0);

    -- per-link decode state
    signal data_type            : slv6_array_t(g_LINK_N-1 downto 0);
    signal package_stage        : slv3_array_t(g_LINK_N-1 downto 0);
    signal we_write_this_package: std_logic_vector(g_LINK_N-1 downto 0);

    signal ts_high              : slv32_array_t(g_LINK_N-1 downto 0);
    signal ts_low               : slv16_array_t(g_LINK_N-1 downto 0);
    signal last_subheader_time  : slv8_array_t(g_LINK_N-1 downto 0);

    signal next_64bit_word      : slv64_array_t(g_LINK_N-1 downto 0);
    signal next_64bit_word_valid: std_logic_vector(g_LINK_N-1 downto 0);

    -- 4x64 -> 256 packing
    signal rx_256               : slv256_array_t(g_LINK_N-1 downto 0);
    signal rx_valid             : std_logic_vector(g_LINK_N-1 downto 0);
    signal index_256            : int_0_3_array_t(g_LINK_N-1 downto 0);

    signal subtime_data         : std_logic_vector(255 downto 0);
    signal subtime_valid        : std_logic;
    signal subtime_word_cnt     : std_logic_vector(63 downto 0);
    signal subtime_word_rate    : std_logic_vector(31 downto 0);
    signal direct_data          : std_logic_vector(255 downto 0);
    signal direct_valid         : std_logic;
    signal direct_word_cnt      : std_logic_vector(63 downto 0);
    signal direct_word_rate     : std_logic_vector(31 downto 0);
    signal rmask_n_r            : std_logic_vector(g_LINK_N-1 downto 0) := (others => '0');
    signal use_direct_mux_r     : std_logic := '0';
    signal lookup_ctrl_r        : std_logic_vector(31 downto 0) := (others => '0');
    signal lane_reset_n         : std_logic_vector(g_LINK_N-1 downto 0) := (others => '0');
    signal subtime_reset_n      : std_logic := '0';
    signal direct_reset_n       : std_logic := '0';

    -- internal counters
    signal s_subh_cnt           : slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    signal s_hit_cnt            : slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));
    signal s_package_cnt        : slv64_array_t(g_LINK_N-1 downto 0) := (others => (others => '0'));

begin

    o_subh_cnt    <= s_subh_cnt;
    o_hit_cnt     <= s_hit_cnt;
    o_package_cnt <= s_package_cnt;
    p_control_pipe : process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( i_reset_n /= '1' ) then
            rmask_n_r <= (others => '0');
            use_direct_mux_r <= '0';
            lookup_ctrl_r <= (others => '0');
            lane_reset_n <= (others => '0');
            subtime_reset_n <= '0';
            direct_reset_n <= '0';
        else
            rmask_n_r <= i_rmask_n;
            use_direct_mux_r <= i_use_direct_mux;
            lookup_ctrl_r <= i_lookup_ctrl;
            lane_reset_n <= (others => '1');
            subtime_reset_n <= '1';
            direct_reset_n <= '1';
        end if;
    end if;
    end process;

    o_data        <= direct_data when use_direct_mux_r = '1' else subtime_data;
    o_valid       <= direct_valid when use_direct_mux_r = '1' else subtime_valid;
    o_word_cnt    <= direct_word_cnt when use_direct_mux_r = '1' else subtime_word_cnt;
    o_word_rate   <= direct_word_rate when use_direct_mux_r = '1' else subtime_word_rate;

    gen_links_to_256bit : for i in 0 to g_LINK_N-1 GENERATE

        -- in the next step we replace the local chipID to the global one, change the hit from 32bit to 64bit and store the data in another FIFO
        FEBChipID(i) <= "00" & i_rx(i).data(25 downto 22) when data_type(i) = MUPIX_HEADER_ID or data_type(i) = TILE_HEADER_ID else
                        "000" & i_rx(i).data(24 downto 22) when data_type(i) = SCIFI_HEADER_ID else
                        (others => '0');

        e_lookup : entity work.chip_lookup
        port map (
            i_fpgaID        => work.mudaq.link_36_to_std(i),
            i_FEBChipID     => FEBChipID(i),
            i_data_type     => data_type(i),

            i_lookup_ctrl   => lookup_ctrl_r,

            o_globalChipID  => globalChipID(i),

            i_reset_n       => lane_reset_n(i),
            i_clk           => i_clk--,
        );

        -- unpack package to 64bit hits
        process(i_clk)
        begin
        if rising_edge(i_clk) then
            if ( lane_reset_n(i) /= '1' ) then
                data_type(i) <= (others => '0');
                package_stage(i) <= (others => '0');
                we_write_this_package(i) <= '0';
                ts_high(i) <= (others => '0');
                ts_low(i) <= (others => '0');
                s_hit_cnt(i) <= (others => '0');
                s_subh_cnt(i) <= (others => '0');
                s_package_cnt(i) <= (others => '0');
                last_subheader_time(i) <= (others => '0');
                next_64bit_word(i) <= (others => '0');
                next_64bit_word_valid(i) <= '0';
                --
            else

                next_64bit_word_valid(i) <= '0';

                if ( i_rx(i).idle = '0' and rmask_n_r(i) = '1' ) then
                    if ( i_rx(i).sop = '1' ) then
                        we_write_this_package(i) <= '1';
                        package_stage(i) <= "000";
                        -- store package type
                        data_type(i) <= i_rx(i).data(31 downto 26);
                    end if;

                    if ( we_write_this_package(i) = '1' ) then
                        if ( package_stage(i) = "000" ) then
                            ts_high(i) <= i_rx(i).data;
                            package_stage(i) <= "001";
                        elsif ( package_stage(i) = "001" ) then
                            ts_low(i) <= i_rx(i).data(31 downto 16);
                            package_stage(i) <= "010";
                        elsif ( package_stage(i) = "010" ) then
                            package_stage(i) <= "011";
                        elsif ( package_stage(i) = "011" ) then
                            package_stage(i) <= "100";
                        elsif ( i_rx(i).eop = '1' ) then
                            s_package_cnt(i) <= s_package_cnt(i) + '1';
                            we_write_this_package(i) <= '0';
                            package_stage(i) <= "000";
                        elsif ( i_rx(i).sbhdr = '1' ) then
                            s_subh_cnt(i) <= s_subh_cnt(i) + '1';
                            last_subheader_time(i) <= i_rx(i).data(31 downto 24);
                        else
                            -- count hits per FEB
                            s_hit_cnt(i) <= s_hit_cnt(i) + '1';

                            next_64bit_word_valid(i) <= '1';

                            -- set 256bit data
                            if ( data_type(i) = MUPIX_HEADER_ID ) then
                                -- MuSiP-Pixel 64bit format
                                -- Bit 63           indication (0) for pixel data
                                next_64bit_word(i)(63) <= '0';
                                -- Bit 62:58        chipID (0-31)
                                next_64bit_word(i)(62 downto 58) <= globalChipID(i)(4 downto 0);
                                -- Bit 57:50        8 bit column
                                next_64bit_word(i)(57 downto 50) <= i_rx(i).data(21 downto 14);
                                -- Bit 49:42        8 bit row
                                next_64bit_word(i)(49 downto 42) <= i_rx(i).data(13 downto 6);
                                -- Bits 41:37       ToT (timestamp 2)
                                next_64bit_word(i)(41 downto 37) <= i_rx(i).data(5 downto 1);
                                -- Bits 36:0        Hit time (8ns overflow in 1000s)     21 +                       5 +                                  7 +                          4
                                next_64bit_word(i)(36 downto  0) <= ts_high(i)(20 downto 0) & ts_low(i)(15 downto 11) & last_subheader_time(i)(6 downto 0) & i_rx(i).data(31 downto 28);
                            elsif ( data_type(i) = SCIFI_HEADER_ID or data_type(i) = TILE_HEADER_ID ) then
                                -- MuSiP-MuTRiG 64bit format
                                -- Bit 63           indication (1) for mutrig data
                                next_64bit_word(i)(63) <= '1';
                                -- Bit 62:61        chipID (0-3)
                                next_64bit_word(i)(62 downto 61) <= globalChipID(i)(1 downto 0);
                                -- Bits 60:56       Channel ID
                                next_64bit_word(i)(60 downto 56) <= i_rx(i).data(21 downto 17);
                                -- Bits 55:47       E-T (0 for the short hit format and 0x1ff for the energy flag)
                                next_64bit_word(i)(55 downto 47) <= i_rx(i).data(8 downto 0);
                                -- Bits 46:44       Time in 1.6 ns reminder bit
                                next_64bit_word(i)(46 downto 44) <= i_rx(i).data(16 downto 14);
                                -- Bits 43:39        Fine time
                                next_64bit_word(i)(43 downto 39) <= i_rx(i).data(13 downto 9);
                                -- Bits 38:0         Hit time (8ns overflow in 4000s)   23 +                       4 +                      8 +                          4
                                next_64bit_word(i)(38 downto 0) <= ts_high(i)(22 downto 0) & ts_low(i)(15 downto 12) & last_subheader_time(i) & i_rx(i).data(31 downto 28);
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
        end process;

        e_hit_rate : entity work.word_rate
        generic map ( g_CLK_MHZ => 250.0 )
        port map (
            i_valid => next_64bit_word_valid(i), o_rate => o_hit_rate(i),
            i_reset_n => lane_reset_n(i), i_clk => i_clk--,
        );

        e_sbhdr_rate : entity work.word_rate
        generic map ( g_CLK_MHZ => 250.0 )
        port map (
            i_valid => i_rx(i).sbhdr, o_rate => o_subh_rate(i),
            i_reset_n => lane_reset_n(i), i_clk => i_clk--,
        );

        e_package_rate : entity work.word_rate
        generic map ( g_CLK_MHZ => 250.0 )
        port map (
            i_valid => i_rx(i).eop, o_rate => o_package_rate(i),
            i_reset_n => lane_reset_n(i), i_clk => i_clk--,
        );

        -- group words in 256bit
        process(i_clk)
        begin
        if rising_edge(i_clk) then
            if ( lane_reset_n(i) /= '1' ) then
                rx_256(i) <= (others => '0');
                rx_valid(i) <= '0';
                index_256(i) <= 0;
                --
            else

                rx_valid(i) <= '0';
                if (next_64bit_word_valid(i) = '1') then
                    if (index_256(i) = 3) then
                        rx_valid(i) <= '1';
                        rx_256(i)((index_256(i) + 1) * 64 - 1 downto index_256(i) * 64) <= next_64bit_word(i);
                        index_256(i) <= 0;
                    else
                        rx_256(i)((index_256(i) + 1) * 64 - 1 downto index_256(i) * 64) <= next_64bit_word(i);
                        index_256(i) <= index_256(i) + 1;
                    end if;
                end if;

            end if;
        end if;
        end process;

    end generate;

    -- subheader merger
    e_subtime_merger : entity work.subtime_merger
    generic map (
        g_LINK_N => g_LINK_N,
        g_FIFO_ADDR_WIDTH => 8,
        g_N_SUBTIME_BITS => 3,
        g_DATA_WIDTH => 64--,
    )
    port map (
        i_data          => next_64bit_word,
        i_valid         => next_64bit_word_valid,
        i_cur_subtime   => last_subheader_time,
        i_mask_n        => rmask_n_r,

        o_data          => subtime_data,
        o_valid         => subtime_valid,

        o_word_cnt      => subtime_word_cnt,
        o_fifo_full_cnt => open,

        i_reset_n       => subtime_reset_n,
        i_clk           => i_clk--,
    );

    e_subtime_word_rate : entity work.word_rate
    generic map ( g_CLK_MHZ => 250.0 )
    port map (
        i_valid   => subtime_valid,
        o_rate    => subtime_word_rate,
        i_reset_n => subtime_reset_n,
        i_clk     => i_clk--,
    );

    e_mux_4_1_256 : entity work.mux_4_1_256
    generic map (
        N => g_LINK_N--,
    )
    port map (
        i_data      => rx_256,
        i_valid     => rx_valid,

        o_data      => direct_data,
        o_valid     => direct_valid,
        o_word_cnt  => direct_word_cnt,
        o_word_rate => direct_word_rate,

        i_reset_n   => direct_reset_n,
        i_clk       => i_clk--,
    );

end architecture;
