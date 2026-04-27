--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity template is
generic (
    g_WIDTH : integer := 8--;
);
port (
    i_data      : in    std_logic_vector(g_WIDTH-1 downto 0);
    o_data      : out   std_logic_vector(g_WIDTH-1 downto 0);

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of template is

    signal data : std_logic_vector(g_WIDTH-1 downto 0);

begin

    o_data <= data;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        data <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        data <= i_data;
        --
    end if;
    end process;

end architecture;
