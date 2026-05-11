library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_avalon_spi_181_kfqr7jy is
		port (
			clk           : in  std_logic                     := 'X';             -- clk
			reset_n       : in  std_logic                     := 'X';             -- reset_n
			data_from_cpu : in  std_logic_vector(15 downto 0) := (others => 'X'); -- writedata
			data_to_cpu   : out std_logic_vector(15 downto 0);                    -- readdata
			mem_addr      : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- address
			read_n        : in  std_logic                     := 'X';             -- read_n
			spi_select    : in  std_logic                     := 'X';             -- chipselect
			write_n       : in  std_logic                     := 'X';             -- write_n
			irq           : out std_logic;                                        -- irq
			MISO          : in  std_logic                     := 'X';             -- export
			MOSI          : out std_logic;                                        -- export
			SCLK          : out std_logic;                                        -- export
			SS_n          : out std_logic_vector(31 downto 0)                     -- export
		);
	end component nios_altera_avalon_spi_181_kfqr7jy;

end nios_pkg;
