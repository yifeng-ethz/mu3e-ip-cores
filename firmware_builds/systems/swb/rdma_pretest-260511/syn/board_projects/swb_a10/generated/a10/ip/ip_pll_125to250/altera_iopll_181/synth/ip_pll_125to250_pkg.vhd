library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_pll_125to250_pkg is
	component ip_pll_125to250_altera_iopll_181_rno6cgq is
		port (
			rst      : in  std_logic := 'X'; -- reset
			refclk   : in  std_logic := 'X'; -- clk
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic         -- clk
		);
	end component ip_pll_125to250_altera_iopll_181_rno6cgq;

end ip_pll_125to250_pkg;
