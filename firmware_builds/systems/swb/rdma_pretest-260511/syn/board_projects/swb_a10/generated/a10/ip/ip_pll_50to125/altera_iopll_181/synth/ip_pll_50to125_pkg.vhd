library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_pll_50to125_pkg is
	component ip_pll_50to125_altera_iopll_181_zv67xoi is
		port (
			rst      : in  std_logic := 'X'; -- reset
			refclk   : in  std_logic := 'X'; -- clk
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic         -- clk
		);
	end component ip_pll_50to125_altera_iopll_181_zv67xoi;

end ip_pll_50to125_pkg;
