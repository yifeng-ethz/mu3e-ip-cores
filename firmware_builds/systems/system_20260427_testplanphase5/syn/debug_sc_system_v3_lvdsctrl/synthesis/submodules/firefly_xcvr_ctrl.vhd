-- File name: firefly_xcvr_ctrl.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 26.0.0330
--		Date: Mar 30, 2026
--		Change: Reissue the Firefly I2C controller in date-style versioning and bound the reset counter to SYSTEM_CLK_FREQ for Questa-safe analysis
-- =========
-- Description:	[Firefly Tranceiver I2C Controller]
--				Interfacing with two Samtec FireFly ECUO 14G x4 optical modules 
--				Function as the I2C master to monitor the temperature, vcc and rx power of the modules.
-- 				For firefly datasheet: https://www.physi.uni-heidelberg.de/Forschung/he/mu3e/restricted/notes/Mu3e-Note-0040-FireflyTransceiver_B04.pdf
--				
--				The I2C bus speed is 400KHz.
-- Ports:
--	AVMM (agent) for (firefly) status and turn off continuous reading.
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

entity firefly_xcvr_ctrl is
	generic(
		I2C_BAUD_RATE			: natural := 400_000; -- fast mode=400kbps (FireFly maximum); standard mode=100kbps. 
		SYSTEM_CLK_FREQ			: natural := 156_250_000;
		AVS_FIREFLY_ADDR_W		: natural := 5;
		DEBUG					: natural := 1
	);
	port(
		-- [AVMM] slave for reading out firefly status readings
		avs_firefly_address			: in  std_logic_vector(AVS_FIREFLY_ADDR_W-1 downto 0);
		avs_firefly_read			: in  std_logic;
		avs_firefly_write			: in  std_logic;
		avs_firefly_readdata		: out std_logic_vector(31 downto 0);
		avs_firefly_writedata		: in  std_logic_vector(31 downto 0);
		avs_firefly_waitrequest		: out std_logic;
		
		-- [Conduit] to top for physical pin access on UCC8 connector (to micro-crontroller inside firefly)
		i_firefly_present_n					: in  std_logic_vector(1 downto 0);
		-- The Module Present Pin is an output contact and is tied directly to ground inside the FireFly optical assembly.
		-- The PresentL pin is used to indicate to the host that the FireFly connector is populated. In the absence of
		-- a FireFly optical assembly, this should be pulled up to the host Vcc. When the optical assembly is inserted,
		-- it completes the path to ground and pulls PRESENTL to a low state.
		o_firefly_reset_n					: out std_logic_vector(1 downto 0);
		-- The ResetL contact is pulled to Vcc inside the FireFly with a 24 k pull up resistor. A low level on the
		-- ResetL pin for more than 200 μs initiates a complete module reset, returning all user settings to their default
		-- state. During the execution of a reset, the host shall ignore all status bits until optical engine indicates a
		-- completion of the reset interrups. This is indicated by the engine asserting “low” on the IntL pin with the
		-- Data_Not_Ready bit (Lower00 Byte6 bit 0) negated.
		o_firefly_select_n					: out std_logic_vector(1 downto 0);
		-- The module select is an input contact and is biased to the “High” state inside the FireFly optical assembly.
		-- The ModSelL pin allows multiple FireFly optical assemblies to be on a standard I2C Serial bus. By default,
		-- this pin is held low by the host. When in this state, the module will respond to writes and queries on the I2C
		-- interface. When the ModSelL pin is pulled high by the host, the optical assembly does not respond to or
		-- acknowledge any I2C query or command.
		i_firefly_int_n						: in  std_logic_vector(1 downto 0);
		-- IntL is an output contact. When low, it indicates a possible module operational fault or a status critical to
		-- the host system. The host identifies the source of the interrupt using the two-wire serial interface. The IntL
		-- contact is an open collector output and should be pulled to 3.3 V on the host board.
		io_firefly_scl						: inout std_logic; -- i2c clock
		io_firefly_sda						: inout std_logic; -- i2c data

		-- [Clk_Rst] clock and reset interface
		i_clk			: in std_logic; -- system clock 
		i_rst			: in std_logic
	);
end entity firefly_xcvr_ctrl;



architecture rtl of firefly_xcvr_ctrl is 

	signal i2c_read_enable		: std_logic;
	-- [Conduit] comb to firefly.vhd for i2c readings and controls
	signal firefly_pwr          : std_logic_vector(127 downto 0); 
	-- Received Optical Power per channel [byte 34-41] is represented in mW as the average received power.
	-- The received power value is encoded as a 16-bit unsigned integer with the power defined as the full 16-bit
	-- value (0 to 65535) with LSB equal to 0.1 μW, yielding a total measurement range of 0 to 6.5535mw (~0 to
	-- 8.2 dBm). Accuracy is ± 3dB over the temperature and voltage.
	signal firefly_temp         : std_logic_vector(15 downto 0);  
	-- Internally measured temperature [byte 22] is represented as an 8-bit signed two’s complement value in
	-- increments of 1 °Celsius, yielding a total range of –127 °C to +127 °C that is considered valid between -25
	-- °C and 85 °C. Accuracy is ± 3 °C
	signal firefly_alarm        : std_logic_vector(63 downto 0); 
	-- Bytes 3 through 18 form a flag field. Within this field, the status of LOS, Tx Fault, Vcc alarm, internal
	-- temperature and received optical power alarms are reported. For normal operation and default state, the
	-- bits in this field have the value of 0b. When an alarm occurs, the field corresponding to this alarm is changed
	-- to 1b. Once asserted, the bits remained set (latched) until cleared by a read operation that includes the
	-- affected bit or reset by the ResetL pin.
	-- ==============================================
	-- Alarm Byte-field Description: (i2c byte-address-bit location) 
	-- ----------------------------------------------
	-- Latched Loss Of Signal (LOS) fault indicator. Default = 0. Fault condition = 1. Value clears on read.
	-- 3-0: L-Rx1 LOS 
	-- 3-1: L-Rx2 LOS 
	-- 3-2: L-Rx3 LOS
	-- 3-3: L-Rx4 LOS
	-- 3-4: L-Tx1 LOS
	-- 3-5: L-Tx2 LOS
	-- 3-6: L-Tx3 LOS
	-- 3-7: L-Tx4 LOS
	-- ----------------------------------------------
	-- Latched Tx fault indicator. Default = 0. Fault condition = 1. Value clears on read.
	-- 4-0: L_Tx1 Fault
	-- 4-1: L_Tx2 Fault
	-- 4-2: L_Tx3 Fault 
	-- 4-3: L_Tx4 Fault
	-- 4-4~7: Reserved
	-- ----------------------------------------------
	-- Value of 1 when module has experience a reset or at power up. Clear on read
	-- 6-0: Int Complete Flag
	-- 6-1~3: Reserved
	-- Latched temperature alarm and warning, default value =0. High / Low alarm / warning value =1. Resets on read
	-- 6-4: L-Temp Low Warning (0 °C)
	-- 6-5: L-Temp High Warning (85 °C)
	-- 6-6: L-Temp Low Alarm (0 °C)
	-- 6-7: L-Temp High Alarm (85 °C)
	-- ----------------------------------------------
	-- Latched bias alarm and warning, default value = 0. High / Low alarm value =1. Resets on read
	-- 7-0~3: Reserved
	-- 7-4: L-Vcc3.3 Low Warning (3.135 V)
	-- 7-5: L-Vcc3.3 High Warning (3.465 V)
	-- 7-6: L-Vcc3.3 Low Alarm (3.135 V)
	-- 7-7: L-Vcc3.3 High Alarm (3.465 V)
	-- ==============================================
	signal firefly_vcc			: std_logic_vector(31 downto 0); 
	-- Internally measured module supply voltage [Byte 26 and 27] are represented as a 16-bit unsigned integer with 
	-- the voltage defined as the full 16 bit value (0 – 65535) with LSB equal to 100 μVolt, yielding a total
	-- measurement range of 0 to 6.55 Volts. Accuracy is ± 0.1 V.
	
	signal firefly_reset_go,firefly_reset_done			: std_logic;
	--constant time_count_200us			: natural := 156250000;--integer(ceil( real(SYSTEM_CLK_FREQ)*0.0002 ));
	signal reset_cnt				: natural range 0 to SYSTEM_CLK_FREQ;
	signal hidden_csr_on			: std_logic;

begin
	
	

	proc_avs_interface : process (i_clk,i_rst)
	-- register map
	-- constant FIREFLY1_TEMP_REGISTER_R           :   integer := 16#FC16#;        -- DOC: contains the temp of firefly1 | FEB_ALL
	-- constant FIREFLY1_VOLT_REGISTER_R           :   integer := 16#FC17#;        -- DOC: contains the voltage of firefly1 | FEB_ALL
	-- constant FIREFLY1_RX1_POW_REGISTER_R        :   integer := 16#FC18#;        -- DOC: received optical power on link 1 | FEB_ALL
	-- constant FIREFLY1_RX2_POW_REGISTER_R        :   integer := 16#FC19#;        -- DOC: received optical power on link 2 | FEB_ALL
	-- constant FIREFLY1_RX3_POW_REGISTER_R        :   integer := 16#FC1A#;        -- DOC: received optical power on link 3 | FEB_ALL
	-- constant FIREFLY1_RX4_POW_REGISTER_R        :   integer := 16#FC1B#;        -- DOC: received optical power on link 4 | FEB_ALL
	-- constant FIREFLY1_ALARM_REGISTER_R          :   integer := 16#FC1C#;        -- DOC: firefly1 alarm | FEB_ALL
	--
	-- constant FIREFLY2_TEMP_REGISTER_R           :   integer := 16#FC1D#;        -- DOC: contains the temp of firefly2 | FEB_ALL
	-- constant FIREFLY2_VOLT_REGISTER_R           :   integer := 16#FC1E#;        -- DOC: contains the voltage of firefly2 | FEB_ALL
	-- constant FIREFLY2_RX1_POW_REGISTER_R        :   integer := 16#FC1F#;        -- DOC: received optical power on link 5 | FEB_ALL
	-- constant FIREFLY2_RX2_POW_REGISTER_R        :   integer := 16#FC20#;        -- DOC: received optical power on link 6 | FEB_ALL
	-- constant FIREFLY2_RX3_POW_REGISTER_R        :   integer := 16#FC21#;        -- DOC: received optical power on link 7 | FEB_ALL
	-- constant FIREFLY2_RX4_POW_REGISTER_R        :   integer := 16#FC22#;        -- DOC: received optical power on link 8 | FEB_ALL
	-- constant FIREFLY2_ALARM_REGISTER_R          :   integer := 16#FC23#;        -- DOC: firefly1 alarm | FEB_ALL

	begin
	
		if (i_rst = '1') then 
			avs_firefly_waitrequest		<= '1';
			i2c_read_enable				<= '1';
			firefly_reset_go			<= '0';
			hidden_csr_on				<= '0';
		elsif (rising_edge(i_clk)) then
			if (avs_firefly_read = '1') then
				-- default
				avs_firefly_readdata		<= (others => '0');
				case to_integer(unsigned(avs_firefly_address)) is
					-- firefly 1
					when 0 => 
						avs_firefly_readdata(7 downto 0)		<= firefly_temp(7 downto 0);
						-- NOTE: hidden feature: the other bits in this location is used for csr information, only visible after address 2 is been reset
						-- register map:
						-- see below
						if (hidden_csr_on = '1') then 
							avs_firefly_readdata(24)		<= i_firefly_present_n(0);
							avs_firefly_readdata(25)		<= i_firefly_present_n(1);
							avs_firefly_readdata(26)		<= i_firefly_int_n(0);
							avs_firefly_readdata(27)		<= i_firefly_int_n(1);
						end if;
					when 1 => 
						avs_firefly_readdata(15 downto 0)		<= firefly_vcc(15 downto 0);
					when 2 => 
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(16*1-1 downto 16*0);
					when 3 => 
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(16*2-1 downto 16*1);
					when 4 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(16*3-1 downto 16*2);
					when 5 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(16*4-1 downto 16*3);
					when 6 =>
						avs_firefly_readdata					<= firefly_alarm(31 downto 0); -- i2c byte 3,4,6,7 respectively
					-- firefly 2
					when 0+7 =>
						avs_firefly_readdata(7 downto 0)		<= firefly_temp(15 downto 8);
					when 1+7 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_vcc(31 downto 16);
					when 2+7 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(64+16*1-1 downto 64+16*0);
					when 3+7 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(64+16*2-1 downto 64+16*1);
					when 4+7 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(64+16*3-1 downto 64+16*2);
					when 5+7 =>
						avs_firefly_readdata(15 downto 0)		<= firefly_pwr(64+16*4-1 downto 64+16*3);
					when 6+7 =>
						avs_firefly_readdata					<= firefly_alarm(63 downto 32); -- i2c byte 3,4,6,7 respectively
					when others => 
						avs_firefly_readdata					<= (others => '1');
				end case;
				-- ack the read, allow burst read
				avs_firefly_waitrequest						<= '0'; 
				
			elsif (avs_firefly_write = '1') then
				case to_integer(unsigned(avs_firefly_address)) is
					-- NOTE: hidden feature: 
					-- 1 ) write 0 to address 0 to disable the reading, while 1 to enable. reset to 1 (enable).
					-- i2c is using the VCC_3V3 power domain on FEB, which is used for firefly and DAB power. Disable reading may prevent crosstalk. 
					-- 2) write 1 to address 1 will trigger a long reset for firefly module
					-- 3) write 1 to address 2 will turn on hidden page of csr, which can be read in byte3 of address 0. 
					when 0 =>
						i2c_read_enable							<= avs_firefly_writedata(0);
					when 1 =>
						firefly_reset_go						<= avs_firefly_writedata(0);
					when 2 =>
						hidden_csr_on							<= avs_firefly_writedata(0);
					when others =>
						-- do nothing
				end case;
				-- ack the write, allow burst write 
				avs_firefly_waitrequest						<= '0'; 
			
			elsif (avs_firefly_write = '1' and avs_firefly_read = '1') then -- error: release the bus
				avs_firefly_waitrequest		<= '0';
			else -- idle
				avs_firefly_waitrequest		<= '1';
			end if;
			
			if (firefly_reset_done = '1') then -- complete the routine: ack the done 0->1
				firefly_reset_go		<= '0';
			end if;
		
		end if;
	
	
	end process proc_avs_interface;
	
	proc_reset_firefly : process(i_clk,i_rst,reset_cnt,firefly_reset_go)
	-- reset for 400 us once firefly_reset_go is asserted
	begin
		if (i_rst = '1') then 
			o_firefly_reset_n			<= (others => '1');
			reset_cnt					<= 0;
			firefly_reset_done			<= '0'; -- complete routine
		elsif (rising_edge(i_clk)) then
			if (firefly_reset_go = '1') then
				if (reset_cnt	< SYSTEM_CLK_FREQ) then
					o_firefly_reset_n		<= (others => '0');
					reset_cnt				<= reset_cnt + 1;
				else
					o_firefly_reset_n		<= (others => '1');
					reset_cnt				<= 0;
					firefly_reset_done		<= '1';
				end if;
			else
				o_firefly_reset_n			<= (others => '1');
				reset_cnt					<= 0;
				firefly_reset_done			<= '0'; -- complete routine: ack the go 1->0
			end if;	
		end if;
	end process;
	
	
	e_firefly_i2c : entity work.firefly_i2c
	generic map(
		I2C_BAUD_RATE	=> I2C_BAUD_RATE,
		g_DELAY_MS		=> 1000,
		CLK_FREQ 		=> SYSTEM_CLK_FREQ
	)
	port map(
		--I2C
		i_i2c_enable    => i2c_read_enable,
		o_Mod_Sel_n     => o_firefly_select_n,
		io_scl          => io_firefly_scl,
		io_sda          => io_firefly_sda,

		o_pwr           => firefly_pwr,
		o_temp          => firefly_temp,
		o_alarm         => firefly_alarm,
		o_vcc           => firefly_vcc,

		i_clk           => i_clk,
		i_reset_n       => not i_rst
	);





end architecture rtl;
	
 
