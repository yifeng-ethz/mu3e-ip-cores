library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_avalon_timer_181_twdkgki is
		port (
			clk        : in  std_logic                     := 'X';             -- clk
			reset_n    : in  std_logic                     := 'X';             -- reset_n
			address    : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- address
			writedata  : in  std_logic_vector(15 downto 0) := (others => 'X'); -- writedata
			readdata   : out std_logic_vector(15 downto 0);                    -- readdata
			chipselect : in  std_logic                     := 'X';             -- chipselect
			write_n    : in  std_logic                     := 'X';             -- write_n
			irq        : out std_logic                                         -- irq
		);
	end component nios_altera_avalon_timer_181_twdkgki;

	component nios_altera_avalon_timer_181_aqotr5y is
		port (
			clk        : in  std_logic                     := 'X';             -- clk
			reset_n    : in  std_logic                     := 'X';             -- reset_n
			address    : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- address
			writedata  : in  std_logic_vector(15 downto 0) := (others => 'X'); -- writedata
			readdata   : out std_logic_vector(15 downto 0);                    -- readdata
			chipselect : in  std_logic                     := 'X';             -- chipselect
			write_n    : in  std_logic                     := 'X';             -- write_n
			irq        : out std_logic                                         -- irq
		);
	end component nios_altera_avalon_timer_181_aqotr5y;

end nios_pkg;
