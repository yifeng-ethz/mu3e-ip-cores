-- File name: write_mask_gen.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 11, 2024
-- Revision: 1.1 (clamp signed selector into the implemented LUT range)
--      Date: Mar 30, 2026
-- =========
-- Description:	[Write Mask Generator] 
-- 		The ingress is the original data to be modified and the modifying bits to overwrite the data.
--		With the selector, it controls the starting bit location (LSB) of the overwrite bits in the 
--		original data location. 
--		The egress and the input are connected in combinational logic.
--		

-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.std_logic_arith.conv_std_logic_vector;


entity write_mask_gen is 
generic (
	DEBUG				: natural := 1

);
port (
	-- avalon streaming hit-type 0 interface
	ingress				: in  std_logic_vector(31 downto 0);
	modifying_bits		: in  std_logic_vector(5 downto 0);
	selection			: in  std_logic_vector(5 downto 0); -- 2's complement; -5 to 31 
	
	egress				: out std_logic_vector(31 downto 0)
);
end entity write_mask_gen;


architecture rtl of write_mask_gen is
	type lut_t	is array (-5 to 31) of std_logic_vector(31 downto 0);
	signal lut		: lut_t;
	
	signal selection_integer		: integer range -32 to 31;
	signal selection_lut_index      : integer range -5 to 31;

begin
	
	selection_integer	<= to_integer(signed(selection));
    selection_lut_index <= -5 when selection_integer < -5 else
                           31 when selection_integer > 31 else
                           selection_integer;
	--selection_integer	: integer range -5 to 31; -- 27 normal + 5 overflow + 5 underflow = 37 options 
	-- [i+5 downto i]
	gen_lut_array : for i in -5 to 31 generate 
	
		-- pass-through
		
		gen_up : if i+modifying_bits'high < ingress'high generate -- i+5 < 31 
			lut(i)(ingress'high downto i+modifying_bits'high+1)		<= ingress(ingress'high downto i+modifying_bits'high+1);
		end generate gen_up;
		
		gen_down : if i > 0 generate
			lut(i)(i-1 downto 0)			<= ingress(i-1 downto 0);
		end generate gen_down;
		
		-- modify
		
		gen_mid : if i >= 0 and i <= ingress'high-modifying_bits'high  generate -- normal i=[0,26]
			lut(i)(i+modifying_bits'high downto i)		<= modifying_bits;
		elsif i < 0  generate -- underflow i=[-5,0)
			lut(i)(i+modifying_bits'high downto 0)		<= modifying_bits(modifying_bits'high downto -i);
		elsif i > ingress'high-modifying_bits'high generate -- overflow i=(26,31]
			lut(i)(ingress'high downto i)				<= modifying_bits(ingress'high-i downto 0);
		end generate gen_mid;
		
	
	end generate gen_lut_array;
	

	proc_main : process (all)
	
	begin
		egress		<= lut(selection_lut_index);
		--egress		<= lut(sel_integer);
	
	
	end process proc_main;












end architecture rtl;
	
