--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clkdiv_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 100.0--;
);
end entity;

architecture arch of clkdiv_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal clkdiv_clk : std_logic;

    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal n : integer := 0;

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0' when ( cycle < 4 ) else '1';
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_clkdiv : entity work.clkdiv
    generic map (
        g_N => 8--,
    )
    port map (
        o_clk => clkdiv_clk,
        i_N => n,
        i_reset_n => reset_n,
        i_clk => clk--,
    );

    process
    begin
        wait for 200 ns;

        for i in 1 to 8 loop
            n <= n + 1;
            wait for 500 ns;
        end loop;
        for i in 1 to 8 loop
            n <= n - 1;
            wait for 500 ns;
        end loop;

        DONE(0) <= '1';
        wait;
    end process;

end architecture;
