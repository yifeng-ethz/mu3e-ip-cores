--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_grayinc is
end entity;

architecture arch of tb_grayinc is

    constant CLK_MHZ : positive := 100;
    signal clk, reset_n : std_logic := '0';

    signal i : unsigned(7 downto 0);
    signal g1, g2 : std_logic_vector(7 downto 0);

begin

    clk <= not clk after (500 ns / CLK_MHZ);
    reset_n <= '0', '1' after 100 ns;

    g1 <= work.util.bin2gray(std_logic_vector(i));

    process(clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        i <= (others => '0');
        g2 <= (others => '0');
        --
    elsif rising_edge(clk) then
        report "i = 0x" & work.util.to_hstring(i);
        report "g1 = 0x" & work.util.to_hstring(g1);
        report "g2 = 0x" & work.util.to_hstring(g2);
        assert ( g1 = g2 ) severity failure;

        i <= i + 1;
        g2 <= work.util.gray_inc(g2);
        --
    end if; -- rising_edge
    end process;

end architecture;
