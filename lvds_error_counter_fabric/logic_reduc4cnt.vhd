-- File name: logic_reduc4cnt.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Feb 28, 2024
-- =========
-- Description:	

-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.std_logic_arith.conv_std_logic_vector;
library work;
use work.all;


entity logic_reduc4cnt is 

	generic (
		ERR_W				: natural
	);
	port(
		i_masked_error		: in  std_logic_vector(ERR_W-1 downto 0);
		o_counter_en		: out std_logic
	);
	
end entity logic_reduc4cnt;


architecture rtl_or of logic_reduc4cnt is
	
begin

	proc_logic : process (all)
	begin
		if ( to_integer(unsigned(i_masked_error)) > 0 ) then
			o_counter_en		<= '1';
		else 
			o_counter_en		<= '0';
		end if;
	end process proc_logic;
	
end architecture rtl_or;


architecture rtl_and of logic_reduc4cnt is

	signal all_ones			: std_logic_vector(ERR_W-1 downto 0) := (others=>'1');

begin

	proc_logic : process (all)
	begin
		if ( to_integer(unsigned(i_masked_error)) = to_integer(unsigned(all_ones)) ) then
			o_counter_en		<= '1';
		else 
			o_counter_en		<= '0';
		end if;
	end process proc_logic;

end architecture rtl_and;




