--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity a10_real_data_gen is
port (
    o_data0             : out work.mu3e.link32_t;
    o_data1             : out work.mu3e.link32_t;

    i_enable            : in  std_logic;
    i_slow_down         : in  std_logic_vector(31 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture rtl of a10_real_data_gen is

    signal waiting : std_logic;
    signal wait_counter, state_counter : std_logic_vector(31 downto 0);

begin

    -- slow down process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
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

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_data0              <= work.mu3e.LINK32_ZERO;
        o_data1              <= work.mu3e.LINK32_ZERO;
        state_counter        <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        o_data0  <= work.mu3e.LINK32_IDLE;
        o_data1  <= work.mu3e.LINK32_IDLE;
        if ( i_enable = '1' and waiting = '0' ) then
            state_counter <= state_counter + '1';
            if ( to_integer(unsigned(state_counter)) = 2 ) then
                o_data0.data <= x"E81005BC";
                o_data1.data <= x"E81006BC";
                o_data0.datak <= "0001";
                o_data1.datak <= "0001";
                o_data0.sop <= '1';
                o_data1.sop <= '1';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 3 ) then
                o_data0.data <= x"00004D28";
                o_data1.data <= x"00004D28";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 4 ) then
                o_data0.data <= x"2812A505";
                o_data1.data <= x"2812A505";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 5 ) then
                o_data0.data <= x"FC000000";
                o_data1.data <= x"FC000000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 6 ) then
                o_data0.data <= x"08C0482F";
                o_data1.data <= x"FC010000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 7 ) then
                o_data0.data <= x"08E1C000";
                o_data1.data <= x"FC020000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 8 ) then
                o_data0.data <= x"08E1D418";
                o_data1.data <= x"FC030000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 9 ) then
                o_data0.data <= x"08EEE3F7";
                o_data1.data <= x"FC040000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 10 ) then
                o_data0.data <= x"08FF4037";
                o_data1.data <= x"FC050000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 11 ) then
                o_data0.data <= x"08FF5438";
                o_data1.data <= x"FC060000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 12 ) then
                o_data0.data <= x"08FF5438";
                o_data1.data <= x"FC070000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 13 ) then
                o_data0.data <= x"08FF4037";
                o_data1.data <= x"FC080000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 14 ) then
                o_data0.data <= x"08FF5C38";
                o_data1.data <= x"FC090000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 15 ) then
                o_data0.data <= x"08E1D400";
                o_data1.data <= x"FC0A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 16 ) then
                o_data0.data <= x"08FF5C37";
                o_data1.data <= x"FC0B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 17 ) then
                o_data0.data <= x"08FF5420";
                o_data1.data <= x"FC0C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 18 ) then
                o_data0.data <= x"08FF4038";
                o_data1.data <= x"FC0D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 19 ) then
                o_data0.data <= x"08FF4020";
                o_data1.data <= x"FC0E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 20 ) then
                o_data0.data <= x"08E1D417";
                o_data1.data <= x"FC0F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 21 ) then
                o_data0.data <= x"08E1D418";
                o_data1.data <= x"FC100000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 22 ) then
                o_data0.data <= x"FC010000";
                o_data1.data <= x"FC110000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 23 ) then
                o_data0.data <= x"58C3482F";
                o_data1.data <= x"FC120000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 24 ) then
                o_data0.data <= x"A8A0803C";
                o_data1.data <= x"FC130000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 25 ) then
                o_data0.data <= x"FC020000";
                o_data1.data <= x"FC140000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 26 ) then
                o_data0.data <= x"FC030000";
                o_data1.data <= x"FC150000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 27 ) then
                o_data0.data <= x"FC040000";
                o_data1.data <= x"FC160000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 28 ) then
                o_data0.data <= x"08CCA82F";
                o_data1.data <= x"FC170000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 29 ) then
                o_data0.data <= x"08C3482F";
                o_data1.data <= x"FC180000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 30 ) then
                o_data0.data <= x"FC050000";
                o_data1.data <= x"FC190000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 31 ) then
                o_data0.data <= x"48A02010";
                o_data1.data <= x"FC1A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 32 ) then
                o_data0.data <= x"FC060000";
                o_data1.data <= x"FC1B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 33 ) then
                o_data0.data <= x"58C35C37";
                o_data1.data <= x"FC1C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 34 ) then
                o_data0.data <= x"98C5C80F";
                o_data1.data <= x"FC1D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 35 ) then
                o_data0.data <= x"A8C3516F";
                o_data1.data <= x"FC1E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 36 ) then
                o_data0.data <= x"A8C34837";
                o_data1.data <= x"FC1F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 37 ) then
                o_data0.data <= x"A8C53C2F";
                o_data1.data <= x"FC200000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 38 ) then
                o_data0.data <= x"FC070000";
                o_data1.data <= x"FC210000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 39 ) then
                o_data0.data <= x"28C3482F";
                o_data1.data <= x"FC220000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 40 ) then
                o_data0.data <= x"F8C3482F";
                o_data1.data <= x"FC230000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 41 ) then
                o_data0.data <= x"F8C03C37";
                o_data1.data <= x"FC240000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 42 ) then
                o_data0.data <= x"F8DF5C2F";
                o_data1.data <= x"FC250000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 43 ) then
                o_data0.data <= x"F8C7482F";
                o_data1.data <= x"FC260000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 44 ) then
                o_data0.data <= x"F8CAE837";
                o_data1.data <= x"FC270000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 45 ) then
                o_data0.data <= x"F8D2F2EF";
                o_data1.data <= x"FC280000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 46 ) then
                o_data0.data <= x"F8C5C80F";
                o_data1.data <= x"FC290000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 47 ) then
                o_data0.data <= x"F8C34834";
                o_data1.data <= x"FC2A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 48 ) then
                o_data0.data <= x"F8CF8817";
                o_data1.data <= x"FC2B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 49 ) then
                o_data0.data <= x"F8C34C2F";
                o_data1.data <= x"FC2C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 50 ) then
                o_data0.data <= x"F8D6EBB7";
                o_data1.data <= x"FC2D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 51 ) then
                o_data0.data <= x"F8DF5C37";
                o_data1.data <= x"FC2E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 52 ) then
                o_data0.data <= x"F8C5DC0F";
                o_data1.data <= x"FC2F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 53 ) then
                o_data0.data <= x"F8C3442F";
                o_data1.data <= x"FC300000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 54 ) then
                o_data0.data <= x"F8DF5C2F";
                o_data1.data <= x"FC310000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 55 ) then
                o_data0.data <= x"FC080000";
                o_data1.data <= x"FC320000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 56 ) then
                o_data0.data <= x"FC090000";
                o_data1.data <= x"FC330000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 57 ) then
                o_data0.data <= x"FC0A0000";
                o_data1.data <= x"FC340000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 58 ) then
                o_data0.data <= x"A8C35C2F";
                o_data1.data <= x"FC350000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 59 ) then
                o_data0.data <= x"FC0B0000";
                o_data1.data <= x"FC360000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 60 ) then
                o_data0.data <= x"18C35037";
                o_data1.data <= x"FC370000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 61 ) then
                o_data0.data <= x"28C3502F";
                o_data1.data <= x"FC380000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 62 ) then
                o_data0.data <= x"F8C3483F";
                o_data1.data <= x"FC390000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 63 ) then
                o_data0.data <= x"F8D2E97F";
                o_data1.data <= x"FC3A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 64 ) then
                o_data0.data <= x"F8C3483F";
                o_data1.data <= x"FC3B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 65 ) then
                o_data0.data <= x"F8C34837";
                o_data1.data <= x"FC3C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 66 ) then
                o_data0.data <= x"F8C34837";
                o_data1.data <= x"FC3D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 67 ) then
                o_data0.data <= x"F8C3516F";
                o_data1.data <= x"FC3E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 68 ) then
                o_data0.data <= x"F8D2EBB7";
                o_data1.data <= x"FC3F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 69 ) then
                o_data0.data <= x"F8C3482F";
                o_data1.data <= x"FC400000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 70 ) then
                o_data0.data <= x"F8C5C817";
                o_data1.data <= x"FC410000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 71 ) then
                o_data0.data <= x"F8CCA977";
                o_data1.data <= x"FC420000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 72 ) then
                o_data0.data <= x"F8CCA837";
                o_data1.data <= x"FC430000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 73 ) then
                o_data0.data <= x"F8C5DD5F";
                o_data1.data <= x"FC440000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 74 ) then
                o_data0.data <= x"F8C35C2F";
                o_data1.data <= x"FC450000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 75 ) then
                o_data0.data <= x"F8E1D418";
                o_data1.data <= x"FC460000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 76 ) then
                o_data0.data <= x"F8E1D418";
                o_data1.data <= x"FC470000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 77 ) then
                o_data0.data <= x"F8E1C018";
                o_data1.data <= x"FC480000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 78 ) then
                o_data0.data <= x"F8FF5C38";
                o_data1.data <= x"FC490000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 79 ) then
                o_data0.data <= x"F8E1C000";
                o_data1.data <= x"FC4A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 80 ) then
                o_data0.data <= x"FC0C0000";
                o_data1.data <= x"FC4B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 81 ) then
                o_data0.data <= x"08E1C000";
                o_data1.data <= x"FC4C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 82 ) then
                o_data0.data <= x"08FF4020";
                o_data1.data <= x"FC4D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 83 ) then
                o_data0.data <= x"08FF4020";
                o_data1.data <= x"FC4E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 84 ) then
                o_data0.data <= x"08FF5C38";
                o_data1.data <= x"FC4F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 85 ) then
                o_data0.data <= x"08E1D400";
                o_data1.data <= x"FC500000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 86 ) then
                o_data0.data <= x"08E1D400";
                o_data1.data <= x"FC510000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 87 ) then
                o_data0.data <= x"08FF4038";
                o_data1.data <= x"FC520000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 88 ) then
                o_data0.data <= x"08E1D400";
                o_data1.data <= x"FC530000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 89 ) then
                o_data0.data <= x"08E1D400";
                o_data1.data <= x"FC540000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 90 ) then
                o_data0.data <= x"08E5DC00";
                o_data1.data <= x"FC550000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 91 ) then
                o_data0.data <= x"08FF5420";
                o_data1.data <= x"FC560000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 92 ) then
                o_data0.data <= x"08FF4020";
                o_data1.data <= x"FC570000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 93 ) then
                o_data0.data <= x"08E5D400";
                o_data1.data <= x"FC580000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 94 ) then
                o_data0.data <= x"08E1C000";
                o_data1.data <= x"FC590000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 95 ) then
                o_data0.data <= x"08FF5420";
                o_data1.data <= x"FC5A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 96 ) then
                o_data0.data <= x"FC0E0000";
                o_data1.data <= x"FC5B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 97 ) then
                o_data0.data <= x"08AEF297";
                o_data1.data <= x"FC5C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 98 ) then
                o_data0.data <= x"98DF4837";
                o_data1.data <= x"FC5D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 99 ) then
                o_data0.data <= x"FC0F0000";
                o_data1.data <= x"FC5E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 100 ) then
                o_data0.data <= x"F8C34837";
                o_data1.data <= x"FC5F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 101 ) then
                o_data0.data <= x"F8C5C80F";
                o_data1.data <= x"FC600000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 102 ) then
                o_data0.data <= x"F8C5C817";
                o_data1.data <= x"FC610000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 103 ) then
                o_data0.data <= x"FC100000";
                o_data1.data <= x"FC620000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 104 ) then
                o_data0.data <= x"FC110000";
                o_data1.data <= x"FC630000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 105 ) then
                o_data0.data <= x"FC120000";
                o_data1.data <= x"FC640000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 106 ) then
                o_data0.data <= x"FC130000";
                o_data1.data <= x"FC650000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 107 ) then
                o_data0.data <= x"FC140000";
                o_data1.data <= x"FC660000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 108 ) then
                o_data0.data <= x"FC150000";
                o_data1.data <= x"FC670000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 109 ) then
                o_data0.data <= x"FC160000";
                o_data1.data <= x"FC680000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 110 ) then
                o_data0.data <= x"FC170000";
                o_data1.data <= x"FC690000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 111 ) then
                o_data0.data <= x"FC180000";
                o_data1.data <= x"FC6A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 112 ) then
                o_data0.data <= x"FC190000";
                o_data1.data <= x"FC6B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 113 ) then
                o_data0.data <= x"FC1A0000";
                o_data1.data <= x"FC6C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 114 ) then
                o_data0.data <= x"FC1B0000";
                o_data1.data <= x"FC6D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 115 ) then
                o_data0.data <= x"FC1C0000";
                o_data1.data <= x"FC6E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 116 ) then
                o_data0.data <= x"FC1D0000";
                o_data1.data <= x"FC6F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 117 ) then
                o_data0.data <= x"FC1E0000";
                o_data1.data <= x"FC700000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 118 ) then
                o_data0.data <= x"FC1F0000";
                o_data1.data <= x"FC710000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 119 ) then
                o_data0.data <= x"FC200000";
                o_data1.data <= x"FC720000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 120 ) then
                o_data0.data <= x"08C5C81F";
                o_data1.data <= x"FC730000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 121 ) then
                o_data0.data <= x"FC210000";
                o_data1.data <= x"FC740000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 122 ) then
                o_data0.data <= x"48DF4837";
                o_data1.data <= x"FC750000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 123 ) then
                o_data0.data <= x"FC220000";
                o_data1.data <= x"FC760000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 124 ) then
                o_data0.data <= x"FC230000";
                o_data1.data <= x"FC770000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 125 ) then
                o_data0.data <= x"FC240000";
                o_data1.data <= x"FC780000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 126 ) then
                o_data0.data <= x"08C8A821";
                o_data1.data <= x"FC790000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 127 ) then
                o_data0.data <= x"FC250000";
                o_data1.data <= x"FC7A0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 128 ) then
                o_data0.data <= x"FC260000";
                o_data1.data <= x"FC7B0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 129 ) then
                o_data0.data <= x"FC270000";
                o_data1.data <= x"FC7C0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 130 ) then
                o_data0.data <= x"F8D2FD7F";
                o_data1.data <= x"FC7D0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 131 ) then
                o_data0.data <= x"F8DF5C3E";
                o_data1.data <= x"FC7E0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 132 ) then
                o_data0.data <= x"F8C5C80F";
                o_data1.data <= x"FC7F0000";
                o_data0.datak <= "0000";
                o_data1.datak <= "0000";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '0';
            end if;
                    if ( to_integer(unsigned(state_counter)) = 133 ) then
                o_data0.data <= x"FC280000";
                o_data1.data <= x"0000009C";
                o_data0.datak <= "0000";
                o_data1.datak <= "0001";
                o_data0.sop <= '0';
                o_data1.sop <= '0';
                o_data1.eop <= '1';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 134 ) then
                o_data0.data <= x"FC290000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 135 ) then
                o_data0.data <= x"FC2A0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 136 ) then
                o_data0.data <= x"FC2B0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 137 ) then
                o_data0.data <= x"F8C34837";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 138 ) then
                o_data0.data <= x"FC2C0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 139 ) then
                o_data0.data <= x"FC2D0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 140 ) then
                o_data0.data <= x"FC2E0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 141 ) then
                o_data0.data <= x"FC2F0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 142 ) then
                o_data0.data <= x"F8DF4020";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 143 ) then
                o_data0.data <= x"FC300000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 144 ) then
                o_data0.data <= x"FC310000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 145 ) then
                o_data0.data <= x"FC320000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 146 ) then
                o_data0.data <= x"FC330000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 147 ) then
                o_data0.data <= x"FC340000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 148 ) then
                o_data0.data <= x"FC350000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 149 ) then
                o_data0.data <= x"FC360000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 150 ) then
                o_data0.data <= x"FC370000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 151 ) then
                o_data0.data <= x"FC380000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 152 ) then
                o_data0.data <= x"FC390000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 153 ) then
                o_data0.data <= x"FC3A0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 154 ) then
                o_data0.data <= x"FC3B0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 155 ) then
                o_data0.data <= x"FC3C0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 156 ) then
                o_data0.data <= x"FC3D0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 157 ) then
                o_data0.data <= x"FC3E0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 158 ) then
                o_data0.data <= x"FC3F0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 159 ) then
                o_data0.data <= x"FC400000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 160 ) then
                o_data0.data <= x"FC410000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 161 ) then
                o_data0.data <= x"FC420000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 162 ) then
                o_data0.data <= x"FC430000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 163 ) then
                o_data0.data <= x"FC440000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 164 ) then
                o_data0.data <= x"FC450000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 165 ) then
                o_data0.data <= x"78A2100A";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 166 ) then
                o_data0.data <= x"FC460000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 167 ) then
                o_data0.data <= x"FC470000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 168 ) then
                o_data0.data <= x"FC480000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 169 ) then
                o_data0.data <= x"FC490000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 170 ) then
                o_data0.data <= x"FC4A0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 171 ) then
                o_data0.data <= x"FC4B0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 172 ) then
                o_data0.data <= x"FC4C0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 173 ) then
                o_data0.data <= x"FC4D0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 174 ) then
                o_data0.data <= x"FC4E0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 175 ) then
                o_data0.data <= x"D8A15814";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 176 ) then
                o_data0.data <= x"FC4F0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 177 ) then
                o_data0.data <= x"FC500000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 178 ) then
                o_data0.data <= x"08C34835";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 179 ) then
                o_data0.data <= x"FC510000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 180 ) then
                o_data0.data <= x"FC520000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 181 ) then
                o_data0.data <= x"FC530000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 182 ) then
                o_data0.data <= x"FC540000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 183 ) then
                o_data0.data <= x"FC550000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 184 ) then
                o_data0.data <= x"FC560000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 185 ) then
                o_data0.data <= x"FC570000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 186 ) then
                o_data0.data <= x"FC580000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 187 ) then
                o_data0.data <= x"08C5CC0D";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 188 ) then
                o_data0.data <= x"FC590000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 189 ) then
                o_data0.data <= x"FC5A0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 190 ) then
                o_data0.data <= x"FC5B0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 191 ) then
                o_data0.data <= x"FC5C0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 192 ) then
                o_data0.data <= x"FC5D0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 193 ) then
                o_data0.data <= x"FC5E0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 194 ) then
                o_data0.data <= x"FC5F0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 195 ) then
                o_data0.data <= x"F8C77C25";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 196 ) then
                o_data0.data <= x"FC600000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 197 ) then
                o_data0.data <= x"08D56B95";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 198 ) then
                o_data0.data <= x"FC610000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 199 ) then
                o_data0.data <= x"FC620000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 200 ) then
                o_data0.data <= x"FC630000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 201 ) then
                o_data0.data <= x"FC640000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 202 ) then
                o_data0.data <= x"FC650000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 203 ) then
                o_data0.data <= x"FC660000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 204 ) then
                o_data0.data <= x"FC670000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 205 ) then
                o_data0.data <= x"FC680000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 206 ) then
                o_data0.data <= x"FC690000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 207 ) then
                o_data0.data <= x"FC6A0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 208 ) then
                o_data0.data <= x"FC6B0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 209 ) then
                o_data0.data <= x"28C35C2D";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 210 ) then
                o_data0.data <= x"FC6C0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 211 ) then
                o_data0.data <= x"FC6D0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 212 ) then
                o_data0.data <= x"FC6E0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 213 ) then
                o_data0.data <= x"FC6F0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 214 ) then
                o_data0.data <= x"FC700000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 215 ) then
                o_data0.data <= x"08ADB612";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 216 ) then
                o_data0.data <= x"FC710000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 217 ) then
                o_data0.data <= x"08AF8389";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 218 ) then
                o_data0.data <= x"FC720000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 219 ) then
                o_data0.data <= x"78A742B3";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 220 ) then
                o_data0.data <= x"78B16DD9";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 221 ) then
                o_data0.data <= x"FC730000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 222 ) then
                o_data0.data <= x"F8A5CC0A";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 223 ) then
                o_data0.data <= x"FC740000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 224 ) then
                o_data0.data <= x"08A3FE14";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 225 ) then
                o_data0.data <= x"18A49C34";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 226 ) then
                o_data0.data <= x"FC750000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 227 ) then
                o_data0.data <= x"58AD5014";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 228 ) then
                o_data0.data <= x"FC760000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 229 ) then
                o_data0.data <= x"FC770000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 230 ) then
                o_data0.data <= x"E8A15E01";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 231 ) then
                o_data0.data <= x"E8A15E01";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 232 ) then
                o_data0.data <= x"FC780000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 233 ) then
                o_data0.data <= x"08C5C817";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 234 ) then
                o_data0.data <= x"FC790000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 235 ) then
                o_data0.data <= x"FC7A0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 236 ) then
                o_data0.data <= x"F8A35FF7";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 237 ) then
                o_data0.data <= x"FC7B0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 238 ) then
                o_data0.data <= x"FC7C0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 239 ) then
                o_data0.data <= x"FC7D0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 240 ) then
                o_data0.data <= x"FC7E0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 241 ) then
                o_data0.data <= x"38A3D811";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 242 ) then
                o_data0.data <= x"FC7F0000";
                o_data0.datak <= "0000";
                o_data0.eop <= '0';
            end if;
                        if ( to_integer(unsigned(state_counter)) = 243 ) then
                o_data0.data <= x"0000009C";
                o_data0.datak <= "0001";
                o_data0.eop <= '1';
            end if;
                if ( to_integer(unsigned(state_counter)) = 247 ) then
            state_counter <= (others => '0');
    end if;
    end if;
    end if;
    end process;

end architecture;
