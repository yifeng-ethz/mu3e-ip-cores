-- simple data generator (for slowcontrol and pixel data)
-- writes into pix_data_fifo and sc_data_fifo
-- only Header(sc or pix) + data
-- other headers/signals are added in data_merger.vhd

-- Martin Mueller, January 2019
-- Marius Koeppel, March 2019
-- Marius Koeppel, July 2019

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity data_generator_a10 is
generic (
    fpga_id: std_logic_vector(15 downto 0) := x"FFFF";
    max_row: std_logic_vector(7 downto 0) := (others => '0');
    max_col: std_logic_vector(7 downto 0) := (others => '0');
    test_error: boolean := false;
    is_farm: boolean := false;
    wtot: std_logic := '0';
    go_to_sh : positive := 2;
    go_to_trailer : positive := 3;
    wchip: std_logic := '0';
    DATA_TYPE : std_logic_vector(5 downto 0) := MUPIX_HEADER_ID--;
);
port (
    i_enable            : in  std_logic;
    i_seed              : in  std_logic_vector(15 downto 0);
    o_data              : out work.mu3e.link32_t;
    i_slow_down         : in  std_logic_vector(31 downto 0);
    o_state             : out std_logic_vector(3 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture rtl of data_generator_a10 is

    signal global_time      : std_logic_vector(47 downto 0);
    signal time_cnt_t       : std_logic_vector(31 downto 0);
    signal overflow_time    : std_logic_vector(14 downto 0);

    type data_header_states is (sop, t0, t1, d0, d1, sbhdr, sbhdr2, dthdr, trailer, overflow, zero);
    signal data_header_state, data_header_state_next : data_header_states;

    signal lfsr_chipID, lfsr_tot, lfsr_chipID_reg, lfsr_tot_reg : std_logic_vector(5 downto 0);
    signal row, col : std_logic_vector(7 downto 0);
    signal lfsr_overflow : std_logic_vector(15 downto 0);

    signal waiting : std_logic;
    signal wait_counter, nEvent : std_logic_vector(31 downto 0);

begin

    chip_id_shift : entity work.linear_shift
    generic map (
        g_m => 6,
        g_poly => "110000"
    )
    port map (
        i_sync_reset => not i_reset_n,
        i_seed      => i_seed(5 downto 0),
        i_en        => i_enable,
        o_lfsr      => lfsr_chipID_reg,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    pix_tot_shift : entity work.linear_shift
    generic map (
        g_m => 6,
        g_poly => "110000"
    )
    port map (
        i_sync_reset => not i_reset_n,
        i_seed      => i_seed(15 downto 10),
        i_en        => i_enable,
        o_lfsr      => lfsr_tot_reg,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    overflow_shift : entity work.linear_shift
    generic map (
        g_m => 16,
        g_poly => "1101000000001000"
    )
    port map (
        i_sync_reset => not i_reset_n,
        i_seed      => i_seed,
        i_en        => i_enable,
        o_lfsr      => lfsr_overflow,

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    -- slow down process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        waiting         <= '0';
        wait_counter    <= (others => '0');
    elsif rising_edge(i_clk) then
        if ( wait_counter >= i_slow_down ) then
            wait_counter    <= (others => '0');
            waiting         <= '0';
        else
            wait_counter    <= wait_counter + '1';
            waiting         <= '1';
        end if;
    end if;
    end process;

    lfsr_tot <= (others => '0') when wtot = '0' else lfsr_tot_reg;
    lfsr_chipID <= (others => '0') when wchip = '0' else lfsr_chipID_reg;

    process(i_clk, i_reset_n)
        variable current_overflow   : std_logic_vector(15 downto 0) := (others => '0');
        variable overflow_idx       : integer range 0 to 15 := 0;
    begin
    if ( i_reset_n /= '1' ) then
        o_data              <= work.mu3e.LINK32_IDLE;
        time_cnt_t          <= (others => '0');
        data_header_state   <= sop;
        current_overflow    := (others => '0');
        overflow_idx        := 0;
        o_state             <= (others => '0');
        row                 <= (others => '0');
        nEvent              <= (others => '0');
        col                 <= (others => '0');
        global_time         <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if ( i_enable = '1' and waiting = '0' ) then

            o_data <= work.mu3e.LINK32_IDLE;

            case data_header_state is

            when zero =>
                o_data.data <= (others => '0');
                o_data.datak <= "0000";
                data_header_state <= data_header_state_next;

            when sop =>
                o_state <= x"A";
                data_header_state <= t0;
                data_header_state_next <= t0;
                if (is_farm) then
                    data_header_state <= zero;
                end if;
                o_data.data(31 downto 26)   <= DATA_TYPE;
                o_data.data(25 downto 24)   <= (others => '0');
                o_data.data(23 downto 8)    <= fpga_id;
                o_data.data(7 downto 0)     <= x"bc";
                o_data.datak                <= "0001";

            when t0 =>
                o_state   <= x"B";
                if ( test_error and nEvent > 1 ) then
                    o_data.data <= (others => '1');
                else
                    o_data.data <= global_time(47 downto 16);
                end if;
                o_data.datak        <= "0000";
                global_time         <= global_time + '1';
                data_header_state <= t1;
                data_header_state_next <= t1;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when t1 =>
                o_state   <= x"C";
                o_data.data <= global_time(15 downto 0) & nEvent(15 downto 0);
                o_data.datak <= "0000";
                data_header_state <= d0;
                data_header_state_next <= d0;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when d0 =>
                o_data.data <=  x"AFFED1D1";
                o_data.datak <= "0000";
                data_header_state <= d1;
                data_header_state_next <= d1;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when d1 =>
                o_data.data <=  x"AFFED2D2";
                o_data.datak <= "0000";
                data_header_state <= sbhdr;
                data_header_state_next <= sbhdr;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when sbhdr =>
                o_state       <= x"D";
                global_time     <= global_time + '1';
                if ( DATA_TYPE = MUPIX_HEADER_ID ) then
                    o_data.data(31 downto 24) <= '0' & global_time(10 downto 4);
                elsif ( DATA_TYPE = SCIFI_HEADER_ID ) then
                    o_data.data(31 downto 24) <= global_time(11 downto 4);
                end if;
                o_data.data(23 downto 8)   <= lfsr_overflow;
                o_data.data(7 downto 0)    <= work.util.K23_7;
                o_data.datak <= "0001";
                overflow_idx := 0;
                current_overflow := lfsr_overflow;
                data_header_state <= sbhdr2;
                data_header_state_next <= sbhdr2;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when sbhdr2 =>
                global_time <= global_time + '1';
                if ( DATA_TYPE = MUPIX_HEADER_ID ) then
                    o_data.data(31 downto 24) <= '0' & global_time(10 downto 4);
                elsif ( DATA_TYPE = SCIFI_HEADER_ID ) then
                    o_data.data(31 downto 24) <= global_time(11 downto 4);
                end if;
                o_data.data(23 downto 8)   <= lfsr_overflow;
                o_data.data(7 downto 0)    <= work.util.K23_7;
                o_data.datak <= "0001";
                overflow_idx := 0;
                current_overflow := lfsr_overflow;
                data_header_state <= dthdr;
                data_header_state_next <= dthdr;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when dthdr =>
                o_state <= x"E";
                global_time <= global_time + '1';
                time_cnt_t <= time_cnt_t + '1';

                if (row = max_row) then
                    row <= (others => '0');
                else
                    row <= row + '1';
                end if;

                if (row = max_col) then
                    col <= (others => '0');
                else
                    col <= col + '1';
                end if;

                if ( DATA_TYPE = MUPIX_HEADER_ID ) then
                    --o_data.data <= global_time(3 downto 0) & lfsr_chipID & col & row & lfsr_tot;
                    -- we write chipID 0 to test the chipID rewrite
                    o_data.data <= global_time(3 downto 0) & "000000" & col & row & lfsr_tot;
                elsif ( DATA_TYPE = SCIFI_HEADER_ID ) then
                    o_data.data(31 downto 28) <= global_time(3 downto 0);
                    o_data.data(27 downto 21) <= (others => '0');
                    o_data.data(20 downto 6) <= global_time(14 downto 0);
                    o_data.data(5 downto 0) <= (others => '0');
                end if;
                overflow_time <= global_time(14 downto 0);
                o_data.datak <= "0000";

                data_header_state <= dthdr;
                data_header_state_next <= dthdr;

                if ( and_reduce(global_time(go_to_trailer downto 0)) = '1' ) then
                    data_header_state <= trailer;
                    data_header_state_next <= trailer;
                    time_cnt_t <= (others => '0');
                elsif ( and_reduce(global_time(go_to_sh downto 0)) = '1' ) then
                    data_header_state <= sbhdr;
                    data_header_state_next <= sbhdr;
                elsif (current_overflow(overflow_idx) = '1') then
                    if ( overflow_idx = 15 ) then
                        overflow_idx := 0;
                    else
                        overflow_idx := overflow_idx + 1;
                    end if;
                    data_header_state <= overflow;
                    data_header_state_next <= overflow;
                else
                    if ( overflow_idx = 15 ) then
                        overflow_idx := 0;
                    else
                        overflow_idx := overflow_idx + 1;
                    end if;
                end if;

                -- in the farm case we go to the zero state
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when overflow =>
                o_state <= x"9";
                if ( DATA_TYPE = MUPIX_HEADER_ID ) then
                    --o_data.data <= global_time(3 downto 0) & lfsr_chipID & col & row & lfsr_tot;
                    -- we write chipID 0 to test the chipID rewrite
                    o_data.data <= global_time(3 downto 0) & "000000" & col & row & lfsr_tot;
                elsif ( DATA_TYPE = SCIFI_HEADER_ID ) then
                    o_data.data(31 downto 21)   <= (others => '0');
                    o_data.data(20 downto 6)    <= overflow_time(14 downto 0);
                    o_data.data(5 downto 0)     <= (others => '0');
                end if;
                o_data.datak <= "0000";
                data_header_state <= dthdr;
                data_header_state_next <= dthdr;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when trailer =>
                o_state <= x"8";
                o_data.data(31 downto 8) <= (others => '0');
                o_data.data(7 downto 0) <= x"9c";
                o_data.datak <= "0001";
                nEvent <= nEvent + '1';
                data_header_state <= sop;
                data_header_state_next <= sop;
                if (is_farm) then
                    data_header_state <= zero;
                end if;

            when others =>
                o_state <= x"7";
                data_header_state <= trailer;
                ---
            end case;
        else
            o_state <= x"F";
            o_data  <= work.mu3e.LINK32_IDLE;
        end if;
    end if;
    end process;

end architecture;
