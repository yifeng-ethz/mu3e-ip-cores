-- File name: charge_inj_pulser.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version: 3.0 (Nov 8, 2024) (sync with run control; change setting: frequency -> pwm in cycles;
--                             add avmm *read)
-- Version: 2.0 (May 6, 2024) (replace PLL with counter)
-- Version: 1.3 (using clkdiv old for trigger)
-- Version: 1.2 (using sync pulser)
-- =======================================
-- Date: Aug 10, 2023
-- =========
-- Description:	[Charge Injection Pulser]
--				It generates a periodic pulse for a given width and frequency. 
--				bit 0: 0=disable, 1=enable
--				bit 31-24: width in clock cycle (8ns)
--				bit 23-8: frequency in kHz 
--				
--				For simple usage, set bit 0 to 1 to enable default (set by generic) injection mode. 

-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.math_real.floor;


entity charge_inj_pulser is
generic(
	DEF_PULSE_FREQ	: natural := 100000; -- 100kHz
	DEF_PULSE_WIDTH	: natural := 20; -- 2 clock cycle length
	CLK_FREQUENCY	: natural := 125000000;
	DEBUG			: natural := 1
);
port (
	-- CSR AVMM
	avs_csr_writedata		: in  std_logic_vector(31 downto 0);
	avs_csr_write			: in  std_logic;
	avs_csr_waitrequest		: out std_logic;
	
	-- pulse out conduit
	o_pulse			: out	std_logic;
	
	-- clock and reset interface
	i_clk			: in	std_logic; -- suppose to be 125 MHz
	i_rst			: in	std_logic
	
);
end entity;

architecture rtl of charge_inj_pulser is 
		
	constant LPM_PIPELINE				: natural := 32; -- lookup in the lpm ip
	
	type csr_t is record
		enable		: std_logic;
		pul_width	: std_logic_vector(7 downto 0);
		pul_freq	: std_logic_vector(15 downto 0);
	end record;
	signal csr		: csr_t;
		
	signal counter_tick					: unsigned(31 downto 0);
	signal pulse_wave_d1,pulse_wave		: std_logic;
	signal pulse_trigd					: std_logic;
	signal counter_pulse_high			: unsigned(7 downto 0);
	
	
	component alt_lpm_div
	PORT
	(
		clock		: IN STD_LOGIC ;
		denom		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		numer		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		quotient	: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		remain		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
	end component;
	

	signal set_w			: unsigned(7 downto 0); -- 8ns to 1992ns (8ns per step)
	signal set_f			: unsigned(15 downto 0); -- 1kHz to 65.535MHz (1KHz per step)
	signal set_tick_cnt		: unsigned(31 downto 0); -- derived interval by lpm_div (5 cycle latency).
	signal div_quo			: std_logic_vector(31 downto 0);
	signal lpm_latency_cnt	: unsigned(7 downto 0);
	signal lpm_calc_done	: std_logic;
	signal lpm_latch_done	: std_logic;
	
begin

	proc_avmm : process(i_clk, i_rst)
	-- routine for for avmm interface to write to CSR 
	begin
		if (i_rst = '1') then
			avs_csr_waitrequest		<= '0';
			csr.enable				<= '0';
			csr.pul_width			<= (others => '0');
			csr.pul_freq			<= (others => '0');
		elsif rising_edge(i_clk) then
			avs_csr_waitrequest		<= '1';
			if (avs_csr_write = '1') then
				avs_csr_waitrequest		<= '0';
				csr.enable				<= avs_csr_writedata(0);
				csr.pul_width			<= avs_csr_writedata(31 downto 24);
				csr.pul_freq			<= avs_csr_writedata(23 downto 8);
			end if;
		end if;
		
	end process;
	
	proc_pulse_gen : process(i_clk, i_rst, csr)
		-- if width is larger than a set interval, no new pulse is generated. 
		-- Caution: user must make sure the set width is smaller than the frequency 
	begin
		if (i_rst = '1') then
			counter_tick		<= (others => '0'); -- 32bit (frequency counter)
			pulse_wave			<= '0';
			pulse_wave_d1		<= '0'; 
			counter_pulse_high	<= (others => '0'); -- 8 bit (width counter)
			o_pulse				<= '0';
			lpm_latency_cnt		<= (others => '0');
			lpm_calc_done		<= '0';
			lpm_latch_done		<= '0';
		elsif rising_edge(i_clk) then
			pulse_wave_d1				<= pulse_wave;
			if (pulse_wave_d1 /= pulse_wave) then 
				pulse_trigd		<= '1'; -- pulse for 1 cycle
			else
				pulse_trigd		<= '0'; 
			end if;
					
			-- main pulse generation logic (TODO: check the coverage here, this is shit code! refactor this logic)
			if (avs_csr_waitrequest = '1' and avs_csr_write = '0' and lpm_latch_done = '1') then -- not in csr write transaction (cycle: 3 + lpm_latency + 1)
			-- enabled
				if (csr.enable = '1') then
					if (set_w /= to_unsigned(0,set_w'length) and set_f /= to_unsigned(0,set_f'length)) then 
					-- input check for non-zero
						-- generate tick at the set interval/frequency
						if (counter_tick < set_tick_cnt) then
							counter_tick		<= counter_tick + 1;
						elsif (counter_tick	>= set_tick_cnt) then
							counter_tick		<= (others => '0'); -- reset counter
							pulse_wave			<= not pulse_wave;
						end if;
						-- generate pulse for a given width
						if (pulse_trigd = '1') then -- extend pulse
							counter_pulse_high		<= to_unsigned(1,counter_pulse_high'length); -- init the counter
							o_pulse					<= '1';
						elsif (counter_pulse_high > 0 and counter_pulse_high < set_w) then -- after trig'd
							counter_pulse_high		<= counter_pulse_high + 1; -- cont. count up
						elsif (counter_pulse_high >= set_w) then -- reach the set width
							o_pulse					<= '0';
							counter_pulse_high		<= (others => '0'); -- reset counter
						end if;
					else -- enabled but value is not set correctly, go to default mode
					-- note: switch-over by setting is ok, the counter will overflow to pick the set value
						if (counter_tick < to_unsigned(CLK_FREQUENCY/DEF_PULSE_FREQ,counter_tick'length)) then
							counter_tick		<= counter_tick + 1;
						elsif (counter_tick >= to_unsigned(CLK_FREQUENCY/DEF_PULSE_FREQ,counter_tick'length)) then 
							counter_tick		<= (others => '0');
							pulse_wave			<= not pulse_wave;
						end if;
						if (pulse_trigd = '1') then -- extend pulse
							counter_pulse_high		<= to_unsigned(1,counter_pulse_high'length); -- init the counter
							o_pulse					<= '1';
						elsif (counter_pulse_high > 0 and counter_pulse_high < to_unsigned(DEF_PULSE_WIDTH,counter_pulse_high'length)) then
							counter_pulse_high		<= counter_pulse_high + 1; -- cont. count up
						elsif (counter_pulse_high >= to_unsigned(DEF_PULSE_WIDTH,counter_pulse_high'length)) then
							o_pulse					<= '0';
							counter_pulse_high		<= (others => '0'); -- reset counter
						end if;
					end if;
				else -- not enabled
					-- reset
					counter_tick		<= (others => '0'); -- 32bit
					pulse_wave			<= '0';
					pulse_wave_d1		<= '0';
					counter_pulse_high	<= (others => '0');
					o_pulse				<= '0';
				end if;
			elsif (avs_csr_waitrequest = '0' and avs_csr_write = '1') then -- (cycle: 2)
				-- after write, get the new setting values
				set_w					<= unsigned(csr.pul_width); -- 8 bit
				set_f					<= unsigned(csr.pul_freq); -- 15 bit
				lpm_calc_done			<= '0'; -- in calc
				lpm_latch_done			<= '0';
				lpm_latency_cnt			<= to_unsigned(LPM_PIPELINE,lpm_latency_cnt'length);
				-- derive set_tick_cnt in one cycle after by lpm_div
			elsif (lpm_calc_done = '1') then -- write is unset, latch the calc value (cycle: 3 + lpm_latency)
				set_tick_cnt			<= unsigned(div_quo);
				lpm_latch_done			<= '1';
				-- reset
				counter_tick		<= (others => '0'); -- 32bit
				pulse_wave			<= '0';
				pulse_wave_d1		<= '0';
				counter_pulse_high	<= (others => '0');
				o_pulse				<= '0';
			else -- first cycle of csr write transaction (cycle: 1)
				-- reset
				counter_tick		<= (others => '0'); -- 32bit
				pulse_wave			<= '0';
				pulse_wave_d1		<= '0';
				counter_pulse_high	<= (others => '0');
				o_pulse				<= '0';
			end if;
			
			if (lpm_calc_done = '0') then
				if (lpm_latency_cnt /= 0) then
					lpm_latency_cnt		<= lpm_latency_cnt - 1;
				else
					lpm_calc_done	<= '1';
				end if;
			end if;
			
		end if;
	
	end process;
	
	lpm_div : alt_lpm_div PORT MAP (
		clock => i_clk,
		numer	 => std_logic_vector(to_unsigned(CLK_FREQUENCY/1000,32)),
		denom	 => std_logic_vector(set_f),
		quotient => div_quo,
		remain	 => open
	);



end architecture;