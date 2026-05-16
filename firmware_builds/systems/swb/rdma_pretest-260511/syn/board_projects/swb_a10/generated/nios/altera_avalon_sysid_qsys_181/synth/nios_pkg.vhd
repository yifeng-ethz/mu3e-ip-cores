library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_avalon_sysid_qsys_181_he4eypy is
		port (
			clock    : in  std_logic                     := 'X'; -- clk
			reset_n  : in  std_logic                     := 'X'; -- reset_n
			readdata : out std_logic_vector(31 downto 0);        -- readdata
			address  : in  std_logic                     := 'X'  -- address
		);
	end component nios_altera_avalon_sysid_qsys_181_he4eypy;

end nios_pkg;
