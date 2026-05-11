library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_avalon_onchip_memory2_181_5wm7isq is
		port (
			clk        : in  std_logic                     := 'X';             -- clk
			address    : in  std_logic_vector(16 downto 0) := (others => 'X'); -- address
			clken      : in  std_logic                     := 'X';             -- clken
			chipselect : in  std_logic                     := 'X';             -- chipselect
			write      : in  std_logic                     := 'X';             -- write
			readdata   : out std_logic_vector(31 downto 0);                    -- readdata
			writedata  : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			byteenable : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- byteenable
			reset      : in  std_logic                     := 'X';             -- reset
			reset_req  : in  std_logic                     := 'X';             -- reset_req
			freeze     : in  std_logic                     := 'X'              -- freeze
		);
	end component nios_altera_avalon_onchip_memory2_181_5wm7isq;

end nios_pkg;
