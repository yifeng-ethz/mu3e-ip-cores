library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_clkctrl_pkg is
	component ip_clkctrl_altclkctrl_181_4ev4gqi is
		port (
			inclk  : in  std_logic := 'X'; -- inclk
			outclk : out std_logic         -- outclk
		);
	end component ip_clkctrl_altclkctrl_181_4ev4gqi;

end ip_clkctrl_pkg;
