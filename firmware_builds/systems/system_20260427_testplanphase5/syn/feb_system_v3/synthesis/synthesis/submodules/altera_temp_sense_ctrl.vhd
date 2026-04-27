-- File name: altera_temp_sense_ctrl.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: May 16, 2024
-- =========
-- Description:	[Altera Temperature Sensor Controller]
--				Interfacing with altera_temp_sense IP
--				Refer to IP manual: https://cdrdv2-public.intel.com/666882/ug_alttemp_sense-683585-666882.pdf
--				Control `ce' and `clr' signal to enable and issue read commands for the ADC which samples the temp sensor voltage.
-- 				It runs in slow clock as the altera IP (< 80 MHz)
--				CSR
--				Write: 
--					bit 0 (enable=1;def=1)
--				Read:
--					byte 0 (temperature reading;signed 2's complement) 
--
--				Note: 
--					Only works for Arria V and other 28 nm devices. Arria 10 (<20 nm devices) has different data type. 
-- Ports:
--	AVMM (agent) for CSR
-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.math_real.floor;
use ieee.std_logic_arith.conv_std_logic_vector;

entity altera_temp_sense_ctrl is 
	generic (
		CLK_FREQ		: natural := 40000000; -- 40 MHz
		DEBUG			: natural := 0
	);
	port (
		-- [AVMM] 
		avs_csr_read			: in  std_logic;
		avs_csr_write			: in  std_logic;
		avs_csr_readdata		: out std_logic_vector(31 downto 0);
		avs_csr_writedata		: in  std_logic_vector(31 downto 0);
		avs_csr_waitrequest		: out std_logic;
		
		-- [Conduit] 
		tsdcalo					: in  std_logic_vector(7 downto 0);
		-- [Conduit] 
		tsdcaldone				: in  std_logic;
		-- [Conduit]
		clr						: out std_logic;
		-- [Conduit]
		ce						: out std_logic;
		
		-- clock and reset interface
		i_clk			: in  std_logic;
		i_rst			: in  std_logic
	);
end entity altera_temp_sense_ctrl;

architecture rtl of altera_temp_sense_ctrl is 

	signal temp_reading_signed	: std_logic_vector(7 downto 0);
	signal reading_enable		: std_logic := '1';
	constant clr_duration		: natural := 80*4; -- at least one adcclk cycle. 

begin

	ce		<= reading_enable;

	proc_avmm : process (i_rst,i_clk)
	begin
		if (i_rst = '1') then 
			reading_enable		<= '1';
		elsif (rising_edge(i_clk)) then
			if (avs_csr_read = '1') then 
				avs_csr_readdata(7 downto 0)		<= 	temp_reading_signed;
				avs_csr_readdata(31 downto 8)		<= (others => '0');
				avs_csr_waitrequest					<= '0';
			elsif (avs_csr_write = '1') then 
				reading_enable				<= avs_csr_writedata(0);
				avs_csr_waitrequest			<= '0';
			else
				avs_csr_readdata			<= (others => '0');
				avs_csr_waitrequest			<= '1';
			end if;
		end if;
	end process proc_avmm;
	
	proc_record_temp : process (i_rst,i_clk)
		variable time_cnt 	: natural range 0 to CLK_FREQ := 0;
		variable time_cnt_s : natural range 0 to clr_duration := 0;
	begin
		if (i_rst = '1') then 
			temp_reading_signed		<= (others => '0'); -- init to 0x0
			time_cnt		:= 0;
			time_cnt_s		:= 0;
			clr				<= '1';
		elsif (rising_edge(i_clk)) then
			-- read from adc
			if (reading_enable = '1') then
				if (tsdcaldone = '1') then -- refer to intel's manual for conversion of data type in 28 nm devices
					temp_reading_signed(7)			<= not tsdcalo(7);
					temp_reading_signed(6 downto 0)	<= tsdcalo(6 downto 0);
				else
					temp_reading_signed		<= temp_reading_signed;
				end if;
			else
				temp_reading_signed		<= temp_reading_signed;
			end if;
			
			-- control the adc to read in a 1s interval 
			if (reading_enable = '1') then
				if (time_cnt = CLK_FREQ) then 
					-- clr active for the small duration 
					time_cnt_s	:= time_cnt_s + 1;
					clr			<= '1';
					if (time_cnt_s = clr_duration) then 
						time_cnt	:= 0;
						clr			<= '0';
					end if;
				else
					time_cnt		:= time_cnt + 1;
					clr				<= '0';
				end if;
			else -- reading not enabled, clr is not needed. 
				-- The ce signal connects to the output enable (oe) port of the clock divider block.
				-- Assert the ce signal to enable the Intel FPGA Temperature Sensor IP core. When you
				-- deassert the ce signal, the IP core disables the ADC, and maintains the previous
				-- values of the tsdcalo[7..0] and tsdcaldone signals unless you assert the clr
				-- signal, or reset the device. The clr signal is asynchronous, and you must assert the
				-- clr signal at least one clock cycle of the adcclk signal to clear the output ports
				time_cnt		:= 0;
				time_cnt_s		:= 0;
			end if;
			
		end if;
	end process proc_record_temp;
	
	
	
	







end architecture rtl;






