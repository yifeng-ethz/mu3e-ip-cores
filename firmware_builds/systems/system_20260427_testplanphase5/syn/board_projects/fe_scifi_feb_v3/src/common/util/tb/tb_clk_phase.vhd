library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_clk_phase is
end entity;

architecture arch of tb_clk_phase is

    constant CLK_MHZ : real := 1000.03; -- MHz
    signal clk, reset_n, reset : std_logic := '0';

    signal clk1, clk2 : std_logic := '0';
    signal phase : std_logic_vector(9 downto 0);

    signal DONE : std_logic_vector(2 downto 0) := (others => '0');

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);
    reset <= not reset_n;

    clk1 <= not clk1 after (4.0 ns);
    clk2 <= transport clk1 after (1.0 ns);

    e_clk_phase : entity work.clk_phase
    generic map (
        W => phase'length--,
    )
    port map (
        i_clk1          => clk1,
        i_clk2          => clk2,

        o_phase         => phase,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    process(phase)
    begin
        report "phase = " & work.util.to_hstring(phase);
        DONE <= (others => '1');
    end process;

    process
    begin
        wait for 4000 ns;
        assert ( DONE = (DONE'range => '1') ) severity failure;
        wait;
    end process;

end architecture;
