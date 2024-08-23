-- File name: avst2cntr_fab.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Feb 28, 2024
-- =========
-- Description:	[Avalon-ST error to Counter Interconnect] 
-- 		It connects the Avalon-ST "error" signal role. Use a OR-logic to enable
--		the counter to accumulate the number of errors synchronized to the input clock
--		1) The sclr will reset the value but not the overflow flag.
--		2) The rst will reset both the value and the overflow flag.
--		
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
library work;
use work.all;


entity avst2cntr_fab is 
	generic (
		ST_DATA_W			: natural := 9;
		ST_CH_W				: natural := 3;
		ST_ERR_W			: natural := 3;
		EN_LOGIC			: string := "OR";
		ERR_MASK			: std_logic_vector(2 downto 0) := "001";
		DEBUG				: natural := 1
	);
	port (
		-- input avst to monitor the error rate
		asi_in_data			: in  std_logic_vector(ST_DATA_W-1 downto 0); -- this is ignored
		asi_in_valid		: in  std_logic;
		--asi_in_channel		: in  std_logic_vector(ST_CH_W-1 downto 0);
		asi_in_error		: in  std_logic_vector(ST_ERR_W-1 downto 0);
		
		-- counter synchronized clear port
		--i_counter_sclr		: in  std_logic;	
		
		-- counter control conduit
		o_counter_en		: out std_logic;
		o_counter_sclr		: out std_logic; -- this is comb connected to the i_counter_sclr
		
		-- clock and reset interface
		i_rst				: in  std_logic;
		i_clk				: in  std_logic
	);
	
end entity avst2cntr_fab;


architecture rtl of avst2cntr_fab is

	signal masked_error 	: std_logic_vector(ST_ERR_W-1 downto 0);
	signal all_ones			: std_logic_vector(ST_ERR_W-1 downto 0) := (others=>'1');
	
	signal err_mask_trunc	: std_logic_vector(ST_ERR_W-1 downto 0);
	
	signal counter_en		: std_logic;
	
	
begin
	
	--o_counter_sclr		<= i_counter_sclr;
	o_counter_sclr		<= '0'; -- currently disabled TODO: make this configurable
	
	err_mask_trunc		<= ERR_MASK(ST_ERR_W-1 downto 0);
	
	gen_mask : if (EN_LOGIC = "OR")  generate -- only make the not masked bit transparent to the next stage
		masked_error		<= asi_in_error and (not err_mask_trunc);
	elsif (EN_LOGIC = "AND")  generate -- convert mask bit into 1, so it is don't care
		masked_error		<= asi_in_error or err_mask_trunc;
	else generate -- default is OR-logic
		masked_error		<= asi_in_error and (not err_mask_trunc);
	end generate gen_mask;
	
	gen_en : if (EN_LOGIC = "OR") generate -- if there is any non-zero bit, enable will be asserted
		e_logic_reduc4cnt_or : entity work.logic_reduc4cnt(rtl_or) 
		generic map(
			ERR_W			=> ST_ERR_W
		)
		port map(
			i_masked_error	=> masked_error,
			o_counter_en	=> counter_en
		);
	elsif (EN_LOGIC = "AND") generate -- only all ones will enable be asserted
		e_logic_reduc4cnt_and : entity work.logic_reduc4cnt(rtl_and) 
		generic map(
			ERR_W			=> ST_ERR_W
		)
		port map(
			i_masked_error	=> masked_error,
			o_counter_en	=> counter_en
		);
	else generate 
		e_logic_reduc4cnt_or : entity work.logic_reduc4cnt(rtl_or) 
		generic map(
			ERR_W			=> ST_ERR_W
		)
		port map(
			i_masked_error	=> masked_error,
			o_counter_en	=> counter_en
		);
	end generate gen_en;
		
	proc_enable_with_valid : process (i_clk,i_rst)
	-- reg the o_counter_en for better timing 
	begin
		if (i_rst = '1' ) then 
			o_counter_en		<= '0';
		elsif rising_edge(i_clk) then
			if (asi_in_valid = '1') then
				o_counter_en		<= counter_en;
			else
				o_counter_en		<= '0';
			end if;
		end if;
	end process proc_enable_with_valid;

end architecture rtl;













