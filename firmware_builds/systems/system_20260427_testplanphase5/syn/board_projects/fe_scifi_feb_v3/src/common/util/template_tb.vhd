--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity template_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of template_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal data : std_logic_vector(7 downto 0);

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0' when ( cycle < 4 ) else '1';
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    e_dut : entity work.template
    generic map (
        g_WIDTH => data'length--,
    )
    port map (
        i_data => data,

        i_reset_n => reset_n,
        i_clk => clk--,
    );

    process
    begin
        wait until rising_edge(clk);

        DONE(0) <= '1';
        wait;
    end process;

    process
    begin
        wait for g_STOP_TIME_US * 1 us;
        if ( and DONE ) then
            report work.util.SGR_FG_GREEN & "I [tb] DONE" & work.util.SGR_RESET;
        else
            report work.util.SGR_FG_RED & "E [tb] NOT DONE" & work.util.SGR_RESET;
        end if;
        assert ( and DONE ) severity error;
        wait;
    end process;

end architecture;
