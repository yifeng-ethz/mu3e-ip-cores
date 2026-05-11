library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_madd_pkg is
	component ip_madd_altera_fpdsp_block_181_bs3fhgi is
		port (
			clk    : in  std_logic                     := 'X';             -- clk
			ena    : in  std_logic                     := 'X';             -- ena
			aclr   : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- aclr
			result : out std_logic_vector(31 downto 0);                    -- result
			ax     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- ax
			ay     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- ay
			az     : in  std_logic_vector(31 downto 0) := (others => 'X')  -- az
		);
	end component ip_madd_altera_fpdsp_block_181_bs3fhgi;

end ip_madd_pkg;
