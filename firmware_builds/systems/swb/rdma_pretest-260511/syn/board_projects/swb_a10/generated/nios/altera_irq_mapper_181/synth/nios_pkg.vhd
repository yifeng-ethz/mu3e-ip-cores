library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_irq_mapper_181_ftenc7a is
		port (
			clk           : in  std_logic                     := 'X'; -- clk
			reset         : in  std_logic                     := 'X'; -- reset
			receiver0_irq : in  std_logic                     := 'X'; -- irq
			receiver1_irq : in  std_logic                     := 'X'; -- irq
			receiver2_irq : in  std_logic                     := 'X'; -- irq
			receiver3_irq : in  std_logic                     := 'X'; -- irq
			sender_irq    : out std_logic_vector(31 downto 0)         -- irq
		);
	end component nios_altera_irq_mapper_181_ftenc7a;

end nios_pkg;
