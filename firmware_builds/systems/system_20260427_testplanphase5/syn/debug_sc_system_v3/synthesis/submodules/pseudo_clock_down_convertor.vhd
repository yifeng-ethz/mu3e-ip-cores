-- ------------------------------------------------------------------------------------------------------------
-- IP Name: 		pseudo_clock_down_convertor
-- Author: 			Alexandr Kozlinskiy
-- Author2: 		Yifeng Wang (yifenwan@phys.ethz.ch)
-- Date:			Aug 23, 2024
-- Revision: 		2.0 (upgrade to sync_reset, add tick of output pseudo clock, fix bugs, IP wrapping)
-- Description: 	Down-convert fast clock to a pseudo slow clock and its tick.
--					Clock divider: period (o_clk) = P * period (i_clk)
-- ------------------------------------------------------------------------------------------------------------
-- altera vhdl_input_version vhdl_2008 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pseudo_clock_down_convertor is
generic (
    CLK_DOWN_FACTOR 	: positive := 1 -- down convert factor
);
port (
	-- ref clock and reset interface
	i_clk       		: in  std_logic;
    i_reset_n   		: in  std_logic;
	-- output pseudo clock and its tick 
    o_clk       		: out std_logic;
	o_tick				: out std_logic -- do not use it
);
end entity;

architecture rtl of pseudo_clock_down_convertor is
	-- signals
    signal fast_counter 		: integer range 0 to CLK_DOWN_FACTOR-1; -- counters for generating the slow clock

begin

	-- generate for case of 1
    gen_bypass : if (CLK_DOWN_FACTOR = 1) generate
        o_clk		<= i_clk;
		o_tick		<= '1';	-- force this to '1' to indicate at least the first pulse
    end generate gen_bypass;
	
	assert not (CLK_DOWN_FACTOR=1) report "CLK_DOWN_FACTOR is set to '1'. Be careful: the output tick is NOT meaningful." severity warning;

	
    -- generate for case of even division factor
    gen_even : if (CLK_DOWN_FACTOR > 1 and CLK_DOWN_FACTOR mod 2 = 0) generate
        proc_even : process (i_clk, i_reset_n)
        begin
			if rising_edge(i_clk) then 
				if (i_reset_n /= '1') then -- reset both counter and output
					o_clk				<= '0';
					fast_counter		<= 0;
				else -- normal op (counting up)
					if (fast_counter = CLK_DOWN_FACTOR/2-1) then -- toggle the pseudo slow clock at half of the counter
						o_clk 				<= not o_clk;
						fast_counter		<= 0;
						if (o_clk = '0') then -- rising edge is coming
							o_tick				<= '1';
						end if;
					else 
						fast_counter		<= fast_counter + 1;
						o_tick				<= '0';
					end if;
				end if;
			end if;
        end process;
    end generate gen_even;

	
	-- generate for case of 1
    gen_odd : if (CLK_DOWN_FACTOR > 1 and CLK_DOWN_FACTOR mod 2 = 1) generate
        proc_odd : process (i_clk, i_reset_n)
		begin
			if rising_edge(i_clk) then 
				if (i_reset_n /= '1') then 
					o_clk				<= '0';
					fast_counter		<= 0;
				else -- it is not possible to get 50/50 clock for this odd case
					-- derive clock
					if (fast_counter = CLK_DOWN_FACTOR/2) then -- we pull clk to high at half-0.5, so more high duration
						o_clk				<= '1';
					elsif (fast_counter = CLK_DOWN_FACTOR-1) then -- at the end, we pull clk to low
						o_clk				<= '0';
						fast_counter		<= 0; -- reset counter
					end if;
					-- derive tick
					if (fast_counter = CLK_DOWN_FACTOR/2) then -- rising edge of clock
						o_tick		<= '1';
					else
						o_tick		<= '0';
					end if;
				end if;
			end if;
        end process;
    end generate gen_odd;
	

end architecture rtl;
