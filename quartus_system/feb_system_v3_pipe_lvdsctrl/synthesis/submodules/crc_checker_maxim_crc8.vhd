-- ------------------------------------------------------------------------------------------------------------
-- IP Name: 		crc_checker_maxim_crc8
-- Author: 			Yifeng Wang (yifenwan@phys.ethz.ch)
-- Date:			Aug 23, 2024
-- Revision: 		1.1 (IP-wrapping)
-- Description: 	check the crc value by shifting in the bit stream 
-- ------------------------------------------------------------------------------------------------------------
-- ================ synthsizer configuration =================== 
-- altera vhdl_input_version vhdl_2008 
-- ================ synthsizer configuration =================== 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.or_reduce;

entity crc_checker_maxim_crc8 is
port (
	-- control interface
	i_shift_en		: in  std_logic; -- shift in 1 bit enable 
	-- data interface
	i_din			: in  std_logic;
	o_lfsr			: out std_logic_vector(7 downto 0); -- for debug only
	o_crc_error		: out std_logic; -- it is the upper module's responsibility to check error at the right cycle, otherwise it is invalid. 
	-- clock and reset interface
	i_clk			: in  std_logic;
	i_rst			: in  std_logic
);
end entity crc_checker_maxim_crc8;

architecture rtl of crc_checker_maxim_crc8 is

	signal shift_reg 	: std_logic_vector(7 downto 0);

begin

	o_lfsr 			<= shift_reg;
	o_crc_error		<= or_reduce(shift_reg); -- at end state all zeros are good
	
	proc_lfsr_checker : process (i_clk,i_rst) 
	begin
		if (rising_edge(i_clk)) then 
			if (i_rst = '1') then 
				shift_reg		<= (others => '0');
			else
				if (i_shift_en = '1') then 
				-- copy from the MAXIM datasheet of DS18B20
					-- 8-bit, poly x^8 + x^5 + x^4 + 1
					shift_reg(0) 	<= i_din xor shift_reg(7);
					shift_reg(1) 	<= shift_reg(0);
					shift_reg(2) 	<= shift_reg(1);
					shift_reg(3) 	<= shift_reg(2);
					shift_reg(4) 	<= shift_reg(3) xor (i_din xor shift_reg(7));
					shift_reg(5) 	<= shift_reg(4) xor (i_din xor shift_reg(7));
					shift_reg(6) 	<= shift_reg(5);
					shift_reg(7) 	<= shift_reg(6);
				else 
					-- halt
				end if;
			end if;
		end if;
	end process;

end architecture;
