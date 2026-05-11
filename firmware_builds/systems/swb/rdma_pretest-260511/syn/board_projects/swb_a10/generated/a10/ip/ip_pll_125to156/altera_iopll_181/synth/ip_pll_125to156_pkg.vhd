library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_pll_125to156_pkg is
	component ip_pll_125to156_altera_iopll_181_tedrqlq is
		port (
			rst      : in  std_logic := 'X'; -- reset
			refclk   : in  std_logic := 'X'; -- clk
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic         -- clk
		);
	end component ip_pll_125to156_altera_iopll_181_tedrqlq;

end ip_pll_125to156_pkg;
