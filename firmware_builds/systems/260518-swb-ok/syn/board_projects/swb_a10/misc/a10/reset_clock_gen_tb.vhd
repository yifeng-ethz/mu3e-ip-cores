--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reset_clock_gen_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 156.25--;
);
end entity;

use work.util_slv.all;

architecture arch of reset_clock_gen_tb is

    signal clk, reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal reset40, clock40 : std_logic_vector(39 downto 0);
    signal reset9 : std_logic_vector(8 downto 0);

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / g_CLK_MHZ);
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_reset_clock_gen_tb : entity work.reset_clock_gen
    port map (
        i_reset9        => reset9,
        o_reset40       => reset40,

        o_clock40       => clock40,

        i_clk_156       => clk,
        i_reset_156_n   => reset_n--,
    );

    reset9 <= '1' & work.util.K28_5 when ( cycle mod 2 = 0 ) else
        '0' & X"CC";

    process
        variable n : integer := -1;
        variable q : std_logic;
    begin
        wait until rising_edge(clk) and reset_n = '1';
        for i in 0 to clock40'length-1 loop
            if is_X(q) then
                --
            elsif ( clock40(i) /= q ) then
                assert ( n < 0 or real(n) * 125.0 = real(40) * g_CLK_MHZ / 2.0 )
                    report "n = " & integer'image(n)
                    severity error;
                n := 0;
            end if;
            if(n >= 0) then
                n := n + 1;
            end if;
            q := clock40(i);
        end loop;
    end process;

    -- [AK] TODO: check total number of clock40 transitions

end architecture;
