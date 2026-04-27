library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lfsr is
end entity;

architecture arch of tb_lfsr is

    constant CLK_MHZ : real := 1000.0; -- MHz
    signal clk, reset_n, reset : std_logic := '0';

    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal lfsr : std_logic_vector(7 downto 0);

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);
    reset <= not reset_n;

    e_lfsr : entity work.lfsr_fibonacci
    generic map (
        g_TAPS => "10111000"--,
    )
    port map (
        o_lfsr      => lfsr,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    process
    begin
        wait until rising_edge(reset_n);

        DONE(0) <= '1';
        wait;
    end process;

    process
    begin
        wait for 4000 ns;
        if ( DONE = (DONE'range => '1') ) then
            report work.util.sgr(32) & "DONE" & work.util.sgr(0);
        else
            report work.util.sgr(31) & "NOT DONE" & work.util.sgr(0);
        end if;
        assert ( DONE = (DONE'range => '1') ) severity failure;
        wait;
    end process;

end architecture;
