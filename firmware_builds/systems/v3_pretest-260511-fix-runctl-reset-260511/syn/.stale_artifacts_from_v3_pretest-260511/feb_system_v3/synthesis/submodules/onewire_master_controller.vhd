-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             onewire_master_controller
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- Revision:            26.2.1
-- Date:                20260428
-- Change:              Add common UID/META CSR header, sample-valid guard, and 125 MHz odd-divider repair.
-- Description:         Host transaction layer issues by process data from/into the onewire master IP.
--						It wraps around the link layer by automatically perform functional commands on a specific 1-Wire device.
-- Usage:               
--						Help:
--								Use ::onewire::bsp::cget(option) to list all available functions. 
--
--						Capability: 
--								Use ::onewire::bsp::cget() to get n_dq_lines and n_sensors on-lines. 
--								(only in advanced IP) Use ::onewire::bsp::probe() to list all sensors and their factory ROM code. 
--
--						CSR:
--								Use ::onewire::bsp::proc_control(line_idx,start), where line_index is the line number 
--								and start=1 for starting the thread and start=0 for stopping the thread.

--								Use ::onewire::bsp::proc_status(line_idx), the return will be error_crc | error_init.
--
--						Temperature:
--								Use ::onewire::bsp::get_temp(sensor_idx), where sensor_idx is directly mapped to line_idx. 
--					
-- ------------------------------------------------------------------------------------------------------------

-- ================ synthsizer configuration =================== 	
-- altera vhdl_input_version vhdl_2008 
-- ============================================================= 

-- general 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.and_reduce;
-- altera-specific
LIBRARY altera_mf;
USE altera_mf.all;

entity onewire_master_controller is 
generic (
	-- +-------------+
	-- | IP settings |
	-- +-------------+
	REF_CLOCK_RATE			: natural	:= 156_250_000;
	AVST_DATA_WIDTH			: natural	:= 8;
	AVMM_DATA_WIDTH			: natural	:= 32;
	AVST_CHANNEL_WIDTH		: natural	:= 3;
	N_DQ_LINES				: natural   := 6;
	SENSOR_TYPE				: string := "DS18B20";
	DEBUG_LV				: natural := 0;
	IP_UID					: natural := 16#4F574D43#; -- ASCII "OWMC"
	VERSION_MAJOR			: natural := 26;
	VERSION_MINOR			: natural := 2;
	VERSION_PATCH			: natural := 1;
	BUILD					: natural := 428;
	VERSION_DATE			: natural := 20260428;
	VERSION_GIT				: natural := 0;
	INSTANCE_ID				: natural := 0
);
port (
	-- avmm (ctrl)
	avm_ctrl_read					: out std_logic;
	avm_ctrl_readdata				: in  std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
	avm_ctrl_write					: out std_logic;
	avm_ctrl_writedata				: out std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
	avm_ctrl_address				: out std_logic_vector(3 downto 0);
	avm_ctrl_waitrequest			: in  std_logic;
	
	-- avmm (csr)
	avs_csr_read					: in  std_logic;
	avs_csr_readdata				: out std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
	avs_csr_write					: in  std_logic;
	avs_csr_writedata				: in  std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
	avs_csr_address					: in  std_logic_vector(3 downto 0);
	avs_csr_waitrequest				: out std_logic;
	
	-- avst (rx)
	-- receiving data from sensor
	asi_rx_data						: in  std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
	asi_rx_valid					: in  std_logic;
	asi_rx_ready					: out std_logic;
	asi_rx_channel					: in  std_logic_vector(AVST_CHANNEL_WIDTH-1 downto 0); -- 3 bit for 8 dq lines
	
	-- avst (tx)
	-- sending data to sensor
	aso_tx_data						: out std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
	aso_tx_valid					: out std_logic;
	aso_tx_ready					: in  std_logic;
	aso_tx_channel					: out std_logic_vector(AVST_CHANNEL_WIDTH-1 downto 0);
	
	-- irq of transaction completion
	inr_complete_irq				: in  std_logic;
	
	-- clock and reset interface
	rsi_reset_reset					: in  std_logic;
	csi_clock_clk					: in  std_logic

);
end entity onewire_master_controller;

architecture rtl of onewire_master_controller is 
	-- -----------------------------------
	-- global constant
	-- -----------------------------------
	constant CMD_ROM_SKIP			: integer := 16#CC#;
	constant CMD_CONVT				: integer := 16#44#;
	constant CMD_READM				: integer := 16#BE#;
	constant CSR_WORD_UID_CONST			: natural := 0;
	constant CSR_WORD_META_CONST		: natural := 1;
	constant CSR_WORD_SCRATCH_CONST		: natural := 2;
	constant CSR_WORD_CAPABILITY_CONST	: natural := 3;
	constant CSR_WORD_STATUS_CONST		: natural := 4;
	constant CSR_WORD_TEMP_BASE_CONST	: natural := 5;
	constant META_SEL_VERSION_CONST		: std_logic_vector(1 downto 0) := "00";
	constant META_SEL_DATE_CONST		: std_logic_vector(1 downto 0) := "01";
	constant META_SEL_GIT_CONST			: std_logic_vector(1 downto 0) := "10";
	constant META_SEL_INSTANCE_CONST	: std_logic_vector(1 downto 0) := "11";

	function pack_version_func(
		constant major		: natural;
		constant minor		: natural;
		constant patch		: natural;
		constant build		: natural
	) return std_logic_vector is
		variable version_word	: std_logic_vector(31 downto 0);
	begin
		version_word(31 downto 24)	:= std_logic_vector(to_unsigned(major, 8));
		version_word(23 downto 16)	:= std_logic_vector(to_unsigned(minor, 8));
		version_word(15 downto 12)	:= std_logic_vector(to_unsigned(patch, 4));
		version_word(11 downto 0)	:= std_logic_vector(to_unsigned(build, 12));
		return version_word;
	end function;

	-- ------------------------------------
	-- slow_timer
	-- ------------------------------------
	signal slow_tick				: std_logic_vector(N_DQ_LINES-1 downto 0);
	signal slow_timer_on			: std_logic_vector(N_DQ_LINES-1 downto 0);
	type slow_timer_cnt_unsigned_t is array (0 to N_DQ_LINES-1) of unsigned(31 downto 0);
	signal slow_timer_cnt_unsigned	: slow_timer_cnt_unsigned_t; -- overflow at 2^32-1, which gives max timing table > 1s. 
	
	-- ------------------------------------
	-- processor
	-- ------------------------------------
	type rx_flow_byte_cnt_t	is array (0 to N_DQ_LINES-1) of unsigned(7 downto 0);
	signal rx_flow_byte_cnt			: rx_flow_byte_cnt_t;
	
	-- scratch pad of the ds18b20 sensor 
	type sensor_data_t is array (0 to 8) of std_logic_vector(7 downto 0);
	type sensor_data_array_t is array (0 to N_DQ_LINES-1) of sensor_data_t;
	signal sensor_data				: sensor_data_array_t;
	signal sensor_sample_valid		: std_logic_vector(N_DQ_LINES-1 downto 0);
	
	-- error report
	-- E: error sympton                                                    
		-- 2: rx_fifo_empty                                                
		-- 1: out_of_range                                                 
		-- 0: init_fail  
	type error_descriptor_t is record 
		rx_fifo_empty		: std_logic; -- ignored
		out_of_range		: std_logic; -- ignored
		init_fail			: std_logic; -- captured 
	end record;
	
	type sensor_error_t is array (0 to N_DQ_LINES-1) of error_descriptor_t;
	signal sensor_error				: sensor_error_t;
	
	type processor_flow_t is (SEND_CONVT,SEND_READT,RECV_BYTES,RESET);
	type processor_flow_array_t is array (0 to N_DQ_LINES-1) of processor_flow_t;
	signal processor_flow		: processor_flow_array_t;
	
	signal processor_req		: std_logic_vector(N_DQ_LINES-1 downto 0);
	signal processor_req_d1		: std_logic_vector(N_DQ_LINES-1 downto 0);
	
	signal processor_grant		: std_logic_vector(N_DQ_LINES-1 downto 0);
	
	-- ------------------------------------
	-- pipes 
	-- ------------------------------------
	type simple_coroutine_pipe_t is record
		start					: std_logic;
		done					: std_logic;
	end record;
	type simple_coroutine_pipe_array_t is array (0 to N_DQ_LINES-1) of simple_coroutine_pipe_t;
	type pipe_t is record 
		main2tx			: simple_coroutine_pipe_array_t;
		main2rx			: simple_coroutine_pipe_array_t;
		tx2flow			: simple_coroutine_pipe_array_t;
		rx2flow			: simple_coroutine_pipe_array_t;
	end record;
	signal pipe			: pipe_t;
	
	-- ------------------------------------
	-- states 
	-- ------------------------------------
	-- core_state
	type core_state_t is (SEND_CONVT,WAITING,JOINING,SEND_READT,RECV_BYTES,ERROR,IDLE,RESET);
	type core_state_array_t is array (0 to N_DQ_LINES-1) of core_state_t;
	signal core_state		: core_state_array_t;
	-- core_tx_state
	type core_tx_state_t is (TX_ROM_SKIP,TX_FUNC_CMD,IDLE,RESET);
	type core_tx_state_array_t is array (0 to N_DQ_LINES-1) of core_tx_state_t;
	signal core_tx_state	: core_tx_state_array_t;
	-- core_rx_state
	type core_rx_state_t is (RX_BYTES,IDLE,RESET);
	type core_rx_state_array_t is array (0 to N_DQ_LINES-1) of core_rx_state_t;
	signal core_rx_state	: core_rx_state_array_t;
	-- tx_flow
	type tx_flow_t is (MM_CONFIG,ST_SEND_DATA,READBACK,MM_COMMIT,WAITING,IDLE,RESET);
	type tx_flow_array_t is array (0 to N_DQ_LINES-1) of tx_flow_t;
	signal tx_flow			: tx_flow_array_t;
	-- rx_flow
	type rx_flow_t is (MM_CONFIG,MM_GUARD,ST_GET_DATA,WAITING,MM_COMMIT,IDLE,RESET);
	type rx_flow_array_t is array (0 to N_DQ_LINES-1) of rx_flow_t;
	signal rx_flow			: rx_flow_array_t;
	
	-- --------------------------------
	-- csr
	-- --------------------------------
	type temp_f32_t is array (0 to N_DQ_LINES-1) of std_logic_vector(31 downto 0);
	type csr_t is record
		meta_sel			: std_logic_vector(1 downto 0);
		scratch				: std_logic_vector(31 downto 0);
		processor_go		: std_logic_vector(N_DQ_LINES-1 downto 0);
		crc_err				: std_logic_vector(N_DQ_LINES-1 downto 0);
		init_err			: std_logic_vector(N_DQ_LINES-1 downto 0);
		sense_temp			: temp_f32_t;
		sel_line			: std_logic_vector(15 downto 0);
	end record;
	signal csr				: csr_t;
	
	-- --------------------------------------------------
	-- mm (resolve contention for memory-mapped)
	-- --------------------------------------------------
	-- read
	type mm_read_array_t is array (0 to N_DQ_LINES-1) of std_logic;
	type mm_read_t is record
		tx					: mm_read_array_t;
	end record;
	signal mm_read			: mm_read_t;
	-- write
	type mm_write_array_t is array (0 to N_DQ_LINES-1) of std_logic;
	type mm_write_t is record 
		tx 					: mm_write_array_t;
		rx					: mm_write_array_t;
	end record;
	signal mm_write			: mm_write_t;
	-- address 
	type mm_address_array_t is array (0 to N_DQ_LINES-1) of std_logic_vector(avm_ctrl_address'high downto 0);
	type mm_address_t is record 
		tx 					: mm_address_array_t;
		rx					: mm_address_array_t;
	end record;
	signal mm_address		: mm_address_t;
	-- data 
	type mm_data_array_t is array (0 to N_DQ_LINES-1) of std_logic_vector(avm_ctrl_writedata'high downto 0);
	type mm_data_t is record 
		tx					: mm_data_array_t;
		rx					: mm_data_array_t;
	end record;
	signal mm_data			: mm_data_t;
	
	-- --------------------------------------------
	-- st (resolve contention for streaming)
	-- --------------------------------------------
	signal st_ready			: std_logic_vector(N_DQ_LINES-1 downto 0);
	signal st_valid			: std_logic_vector(N_DQ_LINES-1 downto 0);
	type st_data_t is array (0 to N_DQ_LINES-1) of std_logic_vector(aso_tx_data'high downto 0);
	signal st_data			: st_data_t;
	
	-- -------------------------------------------
	-- ticket_lock  
	-- -------------------------------------------
	type ticket_lock_t is record 
		lock_req			: std_logic_vector(N_DQ_LINES-1 downto 0);
		unlock_req			: std_logic_vector(N_DQ_LINES-1 downto 0);
		req					: std_logic_vector(N_DQ_LINES-1 downto 0);
		grant_comb			: std_logic_vector(N_DQ_LINES-1 downto 0);
		gnt					: std_logic_vector(N_DQ_LINES-1 downto 0);
		priority			: std_logic_vector(N_DQ_LINES-1 downto 0);
	end record;
	signal ticket_lock		: ticket_lock_t;
	type ticket_lock_state_t is (DECIDING,LOCKED,IDLE,RESET);
	signal ticket_lock_state	: ticket_lock_state_t;
	
	-- -------------------------------------------
	-- format_convertor
	-- -------------------------------------------
	type sense_temp_comb_t is array (0 to N_DQ_LINES-1) of std_logic_vector(31 downto 0);
	signal sense_temp_comb			: sense_temp_comb_t;
	
begin

	-- ------------------------------------
	-- slow_timer
	-- ------------------------------------
	gen_timer : for i in 0 to N_DQ_LINES-1 generate 
		-- instantiation
		e_sensor_slow_clock : entity work.pseudo_clock_down_convertor
			-- down convert ref clock to sensor link layer clock rate (1 MHz)
		generic map ( 
			CLK_DOWN_FACTOR => REF_CLOCK_RATE / 1_000_000 -- NOTE: ref clock must be larger than 1MHz
		)
		port map ( 
			-- input fast clock and reset interface
			clk 			=> csi_clock_clk, -- input clock
			reset_n 		=> not rsi_reset_reset,	-- input reset
			-- pseudo slow clock
			pseudo_clk	 	=> open, -- so far not used, can be slow down the overall state machine to release more timing slack
			-- slow tick (active for one fast cycle at the rising edge of the slow clock)
			tick			=> slow_tick(i)
		);
	
		proc_slow_timer : process(rsi_reset_reset,csi_clock_clk)
		-- a counter synchronized in master clock domain, for the link layer signal formation of 1-Wire protocol
		begin
			if rising_edge(csi_clock_clk) then
				if (rsi_reset_reset = '1' or slow_timer_on(i) = '0') then
					slow_timer_cnt_unsigned(i) 	<= (others => '0'); -- reset the count when off
				else
					if (slow_tick(i) = '1') then -- count up at 1 MHz rate
						slow_timer_cnt_unsigned(i) 	<= slow_timer_cnt_unsigned(i) + 1; -- NOTE: pls ensure it is only high for 1 cycle
					end if;
				end if;
			end if;
		end process;
	end generate;
	

	
	-- -----------------------------------
	-- processor 
	-- -----------------------------------
	-- functional description: 
	--     send rom command (w/ init), followed by functional command
	--     wait 850 ms. Another process may start 
	--     send rom command (w/ init), followed by functional command
	-- 
	-- RTL implementation:
	--     processor number equal to the N_DQ_LINES
	--     each may start if the onewire master IP is free
	--     output is converted and crc checked
	gen_processor : for i in 0 to N_DQ_LINES-1 generate 
		proc_processor : process (rsi_reset_reset,csi_clock_clk) 
		begin
			if (rising_edge(csi_clock_clk)) then -- clock begin
				if (rsi_reset_reset = '1') then -- sync reset begin
					-- reset
					core_state(i)		<= RESET;
					processor_flow(i)	<= RESET;
					core_tx_state(i)	<= RESET;
					tx_flow(i)			<= RESET;
					core_rx_state(i)	<= RESET;
					rx_flow(i)			<= RESET;
					processor_req(i)	<= '0'; -- release semaphore
				else -- sync reset clock begin
					-- -------------------------------------------------
					-- pipeline the req to generate the edge trigger
					-- -- ----------------------------------------------
					processor_req_d1(i)		<= processor_req(i);
					
					-- -----------------------
					-- core_state
					-- -----------------------
					case core_state(i) is 
						when SEND_CONVT =>
							-- handshake with tx_state
							if (pipe.main2tx(i).start = '0' and pipe.main2tx(i).done = '0') then -- start the sub-routine
								if (processor_flow(i) = SEND_CONVT) then 
									pipe.main2tx(i).start	<= '1';
								else
									-- idle
								end if;
							elsif (pipe.main2tx(i).start = '1' and pipe.main2tx(i).done = '0') then 
								-- wait for slave to finish
							elsif (pipe.main2tx(i).start = '1' and pipe.main2tx(i).done = '1') then -- slave done
								pipe.main2tx(i).start	<= '0'; -- ack the slave
								if (sensor_error(i).init_fail = '1') then -- capture the exception
									core_state(i)				<= ERROR; -- terminate the process early
								end if;
							elsif (pipe.main2tx(i).start = '0' and pipe.main2tx(i).done = '1') then -- wait for slave to ack
								processor_flow(i)		<= SEND_READT; -- so we don't start again
								core_state(i)				<= WAITING;
							end if;
						when WAITING => -- wait for 850 ms
							slow_timer_on(i)		<= '1'; -- start timer
							-- release semaphore, it is a ticket logic queue
							processor_req(i)		<= '0';
							-- exit
							if (slow_timer_cnt_unsigned(i) > 850_000) then 
								core_state(i)		<= JOINING;
								slow_timer_on(i)	<= '0'; -- reset timer
							end if;
						when JOINING => -- try to win the share to send 
							processor_req(i)	<= '1'; -- try to win the entry with the ticket
							if (processor_grant(i) = '1') then 
								core_state(i)			<= SEND_READT;
							end if;
						when SEND_READT => 
							-- handshake with tx_state
							if (pipe.main2tx(i).start = '0' and pipe.main2tx(i).done = '0') then -- start the sub-routine
								if (processor_flow(i) = SEND_READT) then 
									pipe.main2tx(i).start	<= '1';
								else 
									-- idle
								end if;
							elsif (pipe.main2tx(i).start = '1' and pipe.main2tx(i).done = '0') then 
								-- wait for slave to finish
							elsif (pipe.main2tx(i).start = '1' and pipe.main2tx(i).done = '1') then -- slave done
								pipe.main2tx(i).start	<= '0'; -- ack the slave
							elsif (pipe.main2tx(i).start = '0' and pipe.main2tx(i).done = '1') then -- wait for slave to ack
								-- idle 
								processor_flow(i)			<= RECV_BYTES;
								core_state(i)				<= RECV_BYTES;
							end if;
						when RECV_BYTES =>
							-- handshake with rx_state
							if (pipe.main2rx(i).start = '0' and pipe.main2rx(i).done = '0') then -- start the sub-routine
								if (processor_flow(i) = RECV_BYTES) then 
									pipe.main2rx(i).start	<= '1';
								else -- start again
									core_state(i)			<= IDLE;
								end if;
							elsif (pipe.main2rx(i).start = '1' and pipe.main2rx(i).done = '0') then -- wait for slave to finish
								-- idle
							elsif (pipe.main2rx(i).start = '1' and pipe.main2rx(i).done = '1') then -- slave done
								pipe.main2rx(i).start 	<= '0'; -- ack the slave
								processor_req(i)		<= '0'; -- release the semaphore, obtain it again in idle
								-- NOTE: the ticket_lock might need 2 cycles to unlock. test if this works
							elsif (pipe.main2rx(i).start = '0' and pipe.main2rx(i).done = '1') then -- wait for slave to ack
								-- idle
								processor_flow(i)		<= RESET; -- start again
							end if;	
						when ERROR => -- capture state of init fail
							-- wait for 1s and 
							slow_timer_on(i)		<= '1'; -- start timer
							-- release semaphore, so other process can proceed 
							processor_req(i)		<= '0';
							-- exit
							if (slow_timer_cnt_unsigned(i) > 1_000_000) then -- re-try
								core_state(i)		<= IDLE;
								slow_timer_on(i)	<= '0'; -- reset timer
							end if;
							-- TODO: reset
						when IDLE =>
							if (csr.processor_go(i) = '1') then -- may start the routine
								processor_req(i)	<= '1'; -- try to win the entry with the ticket
								if (processor_grant(i) = '1') then 
									core_state(i)			<= SEND_CONVT;
									processor_flow(i) 		<= SEND_CONVT;
								end if;
							end if;
						when RESET =>
							slow_timer_on(i)		<= '0'; -- reset timer
							pipe.main2tx(i).start	<= '0'; -- reset pipe
							pipe.main2rx(i).start	<= '0'; -- reset pipe
							core_state(i)			<= IDLE; -- enter the normal state 
						when others =>
							null;
					end case;
					
					
					-- -------------------------
					-- core_tx_state
					-- -------------------------
					case core_tx_state(i) is
						when TX_ROM_SKIP =>
							-- handshake with tx_flow
							if (pipe.tx2flow(i).start = '0' and pipe.tx2flow(i).done = '0') then -- start the sub-routine
								pipe.tx2flow(i).start	<= '1';
							elsif (pipe.tx2flow(i).start = '1' and pipe.tx2flow(i).done = '0') then 
								-- wait for slave to finish
							elsif (pipe.tx2flow(i).start = '1' and pipe.tx2flow(i).done = '1') then -- slave done
								pipe.tx2flow(i).start	<= '0'; -- ack the slave
								if (sensor_error(i).init_fail = '1') then -- capture the exception
									core_tx_state(i)		<= IDLE;
									pipe.main2tx(i).done	<= '1'; -- terminate the process early 
								end if;
							elsif (pipe.tx2flow(i).start = '0' and pipe.tx2flow(i).done = '1') then -- finished jump to next state
								-- idle 
								core_tx_state(i)		<= TX_FUNC_CMD;
							end if;
						when TX_FUNC_CMD => 
							-- handshake with tx_flow
							if (pipe.tx2flow(i).start = '0' and pipe.tx2flow(i).done = '0') then -- start the sub-routine
								pipe.tx2flow(i).start	<= '1';
							elsif (pipe.tx2flow(i).start = '1' and pipe.tx2flow(i).done = '0') then 
								-- wait for slave to finish
							elsif (pipe.tx2flow(i).start = '1' and pipe.tx2flow(i).done = '1') then -- slave done
								pipe.tx2flow(i).start	<= '0';
							elsif (pipe.tx2flow(i).start = '0' and pipe.tx2flow(i).done = '1') then -- wait for slave to ack
								-- idle 
								core_tx_state(i)		<= IDLE;
								pipe.main2tx(i).done	<= '1';
							end if;
						when IDLE =>
							if (pipe.main2tx(i).start = '1' and pipe.main2tx(i).done = '0') then -- initiated 
								core_tx_state(i)		<= TX_ROM_SKIP;
							elsif (pipe.main2tx(i).start = '1' and pipe.main2tx(i).done = '1') then -- wait for master to ack
								-- idle
							elsif (pipe.main2tx(i).start = '0' and pipe.main2tx(i).done = '1') then -- master ack
								pipe.main2tx(i).done	<= '0'; -- ack back to master
							else
								-- pure idle
							end if;
						when RESET =>
							pipe.tx2flow(i).start		<= '0'; -- reset pipe
							pipe.main2tx(i).done		<= '0'; -- reset pipe
							core_tx_state(i)			<= IDLE; -- enter normal state 
						when others =>
							null;
					end case;
					
					
					-- ----------------------
					-- tx_flow
					-- ----------------------
					case tx_flow(i) is -- TODO: resolve contention with other sub-routine
						when MM_CONFIG =>
							-- drive the command ticket
							mm_write.tx(i)		<= '1';
							mm_address.tx(i)	<= std_logic_vector(to_unsigned(1,mm_address.tx(i)'length));
							mm_data.tx(i)(23 downto 16)		<= std_logic_vector(to_unsigned(i,8)); -- wire_id
							mm_data.tx(i)(15 downto 8)		<= std_logic_vector(to_unsigned(1,8)); -- tot_bytes
							mm_data.tx(i)(3)		<= '1'; -- use_wire_id, override the streaming id 
							mm_data.tx(i)(2)		<= '0'; -- paracitic powering
							if (core_tx_state(i) = TX_ROM_SKIP) then -- selected whether to init
								mm_data.tx(i)(1)		<= '1'; -- init
							else
								mm_data.tx(i)(1)		<= '0'; -- init
							end if;
							mm_data.tx(i)(0)		<= '1'; -- direction (tx)
							if (avm_ctrl_waitrequest = '0') then -- ack by the bus
								mm_write.tx(i)		<= '0'; -- ack the bus
								tx_flow(i)			<= ST_SEND_DATA;-- jump to next state
							end if;
						when ST_SEND_DATA => -- transmitting
							-- drive the data packet
							if (aso_tx_ready = '1' and st_valid(i) = '1') then -- data is successfully transmitted
								st_valid(i)		<= '0';
								tx_flow(i)		<= MM_COMMIT;-- jump to next state
							else
								st_valid(i)		<= '1';
								if (core_tx_state(i) = TX_ROM_SKIP) then -- select the data depending on the state
									st_data(i)		<= std_logic_vector(to_unsigned(CMD_ROM_SKIP,st_data(i)'length)); 
								else -- functional command 
									if (core_state(i) = SEND_CONVT) then 
										st_data(i)		<= std_logic_vector(to_unsigned(CMD_CONVT,st_data(i)'length));
									else 
										st_data(i)		<= std_logic_vector(to_unsigned(CMD_READM,st_data(i)'length));
									end if;
								end if;
								-- channel is ignored at this moment.
							end if;
						when MM_COMMIT =>
							mm_write.tx(i)		<= '1';
							mm_address.tx(i)	<= std_logic_vector(to_unsigned(0,mm_address.tx(i)'length));
							mm_data.tx(i)(31 downto 1)	<= (others => '0');
							mm_data.tx(i)(0)	<= '1'; -- commit
							if (avm_ctrl_waitrequest = '0') then -- ack by the bus
								mm_write.tx(i)		<= '0'; -- ack the bus
								tx_flow(i)			<= WAITING;-- jump to next state
							end if;
						when WAITING =>
							if (inr_complete_irq = '1') then 
								tx_flow(i)				<= READBACK;
							end if;
						when READBACK => -- need to readback the error symdrome
							-- drive a read cmd
							mm_read.tx(i)			<= '1';
							mm_address.tx(i)		<= std_logic_vector(to_unsigned(0,mm_address.tx(i)'length));
							if (avm_ctrl_waitrequest = '0') then -- readdata is back
								mm_read.tx(i)					<= '0'; -- ack the bus
								sensor_error(i).init_fail		<= avm_ctrl_readdata(9); -- throw an exception
								tx_flow(i)						<= IDLE;
								pipe.tx2flow(i).done			<= '1'; -- ack the upper level (core_tx_state)
							end if;
						when IDLE =>
							if (pipe.tx2flow(i).start = '1' and pipe.tx2flow(i).done = '0') then -- start initiated
								tx_flow(i)		<= MM_CONFIG;
							elsif (pipe.tx2flow(i).start = '1' and pipe.tx2flow(i).done = '1') then 
								-- wait for master to ack
							elsif (pipe.tx2flow(i).start = '0' and pipe.tx2flow(i).done = '1') then 
								pipe.tx2flow(i).done	<= '0'; -- ack back to master 
							else
								-- pure idle 
							end if;
						when RESET => 
							-- reset interface 
							mm_write.tx(i)		<= '0';
							mm_address.tx(i)	<= (others => '0'); -- [PPA]
							mm_data.tx(i)		<= (others => '0'); -- [PPA]
							st_valid(i)			<= '0';
							st_data(i)			<= (others => '0'); -- [PPA]
							-- pipes
							pipe.tx2flow(i).done	<= '0';
							-- error descriptor
							sensor_error(i).init_fail	<= '0';
							tx_flow(i)			<= IDLE;
						when others =>
							null;
					end case;
					
					
					-- -----------------------
					-- core_rx_state
					-- -----------------------
					case core_rx_state(i) is
						when RX_BYTES => 
							-- handshake with rx_flow
							if (pipe.rx2flow(i).start = '0' and pipe.rx2flow(i).done = '0') then -- start the sub-routine
								pipe.rx2flow(i).start	<= '1';
							elsif (pipe.rx2flow(i).start = '1' and pipe.rx2flow(i).done = '0') then 
								-- wait for slave to finish
							elsif (pipe.rx2flow(i).start = '1' and pipe.rx2flow(i).done = '1') then -- slave done
								pipe.rx2flow(i).start	<= '0';
							elsif (pipe.rx2flow(i).start = '0' and pipe.rx2flow(i).done = '1') then -- wait for slave to ack
								-- idle 
								core_rx_state(i)		<= IDLE;
								pipe.main2rx(i).done	<= '1';
							end if;
						when IDLE =>
							if (pipe.main2rx(i).start = '1' and pipe.main2rx(i).done = '0') then -- handshake with upper-level
								core_rx_state(i)		<= RX_BYTES;
							elsif (pipe.main2rx(i).start = '1' and pipe.main2rx(i).done = '1') then -- done, wait for master 
								-- idle
							elsif (pipe.main2rx(i).start = '0' and pipe.main2rx(i).done = '1') then -- master ack
								pipe.main2rx(i).done 	<= '0'; -- ack the master
							else -- pure idle
								-- idle
							end if;
						when RESET => 
							pipe.rx2flow(i).start		<= '0'; -- reset pipe
							pipe.main2rx(i).done		<= '0'; -- reset pipe
							core_rx_state(i)			<= IDLE;
						when others =>
							null;
					end case;
					
					-- -----------------------
					-- rx_flow
					-- -----------------------
					case rx_flow(i) is 
						when MM_CONFIG =>
							-- drive the command ticket
							sensor_sample_valid(i)	<= '0';
							mm_write.rx(i)			<= '1';
							mm_address.rx(i)		<= std_logic_vector(to_unsigned(1,mm_address.rx(i)'length));
							mm_data.rx(i)(23 downto 16)	<= std_logic_vector(to_unsigned(i,8)); -- wire_id
							mm_data.rx(i)(15 downto 8)		<= std_logic_vector(to_unsigned(9,8)); -- tot_bytes (9 bytes)
							mm_data.rx(i)(3)		<= '1'; -- use_wire_id, override the streaming id 
							mm_data.rx(i)(2)		<= '0'; -- paracitic powering
							mm_data.rx(i)(1)		<= '0'; -- init
							mm_data.rx(i)(0)		<= '0'; -- direction (rx)
							if (avm_ctrl_waitrequest = '0') then -- ack by the bus
								mm_write.rx(i)		<= '0'; -- ack the bus
								rx_flow(i)			<= MM_GUARD;-- jump to next state
							end if;
						when MM_GUARD =>
							-- to prevent the bus is not recovered from last command, add idle state confirmation
							if (avm_ctrl_waitrequest = '1') then 
								rx_flow(i)		<= MM_COMMIT;
							end if;
						when MM_COMMIT =>
							mm_write.rx(i)		<= '1';
							mm_address.rx(i)	<= std_logic_vector(to_unsigned(0,mm_address.rx(i)'length));
							mm_data.rx(i)(31 downto 1)	<= (others => '0');
							mm_data.rx(i)(0)	<= '1'; -- commit
							if (avm_ctrl_waitrequest = '0') then -- ack by the bus
								mm_write.rx(i)		<= '0'; -- ack the bus
								rx_flow(i)			<= WAITING;-- jump to next state
							end if;
						when WAITING => -- wait for the onewire master IP to complete
							if (inr_complete_irq = '1') then 
								rx_flow(i)				<= ST_GET_DATA;
								st_ready(i)				<= '1'; -- receive data in the next cycle
							end if;
						when ST_GET_DATA => -- receive
							if (asi_rx_valid = '1') then -- tick in data
								for j in 0 to sensor_data(i)'length-1 loop
									if (to_integer(rx_flow_byte_cnt(i)) = j) then 
										sensor_data(i)(j)	<= asi_rx_data;
									end if;
								end loop;
								rx_flow_byte_cnt(i)			<= rx_flow_byte_cnt(i) + 1; -- incr byte counter
								if (rx_flow_byte_cnt(i) = 8) then -- at end of 8th byte
									st_ready(i)				<= '0'; -- stop receiving data
									rx_flow(i)				<= IDLE; -- exit
									rx_flow_byte_cnt(i)		<= (others => '0');	-- reset byte counter
									sensor_sample_valid(i)	<= '1';
									pipe.rx2flow(i).done	<= '1';	-- ack the master through pipe
								end if;
							end if;
						when IDLE =>
							if (pipe.rx2flow(i).start = '1' and pipe.rx2flow(i).done = '0') then -- initiated 
								rx_flow(i)		<= MM_CONFIG;
							elsif (pipe.rx2flow(i).start = '1' and pipe.rx2flow(i).done = '1') then -- wait for master to ack
								-- idle
							elsif (pipe.rx2flow(i).start = '0' and pipe.rx2flow(i).done = '1') then -- master ack
								pipe.rx2flow(i).done	<= '0'; -- ack the master
							else -- pure idle
								-- idle 
							end if;
						when RESET => 
							-- reset interface
							mm_write.rx(i)		<= '0';
							mm_address.rx(i)	<= (others => '0');
							mm_data.rx(i)		<= (others => '0');
							st_ready(i)			<= '0';
							-- reset local signals
							sensor_data(i)		<= (others => (others => '0'));
							sensor_sample_valid(i)	<= '0';
							rx_flow_byte_cnt(i)	<= (others => '0');
							-- reset pipe
							pipe.rx2flow(i).done	<= '0';
							-- reset fsm
							rx_flow(i)			<= IDLE;
						when others =>
							null;
					end case;
				end if; -- sync reset clock end
				
				
				
			end if; -- clock end 
		end process;

	end generate gen_processor;
	
	proc_processor_comb : process (all)
	begin
		-- -------------------------------------------------
		-- latch the grant signal 
		-- -------------------------------------------------
		processor_grant		<= ticket_lock.gnt;
	end process;
	
	-- ===============================
	-- ticket_lock
	-- ===============================
	-- -----------------------------------------------------------------------------------------------------------------
	-- Get the lock request from the processors and generate the grant signal to ack their lock request. 
	-- Maintain the atomic property of the i/o resource, resolving such contention. 
	-- Maintain a pool of request and grant based on a round-robin arbitration scheme, which select the next grant
	-- given the current grant. 
	-- 
	-- It borrows the concept from software programming (https://en.wikipedia.org/wiki/Ticket_lock).
	-- However, the implementationtation is absolutely not relavent. 
	--
	-- Work flow: 
	-- ==========
	-- 1) To LOCK
	-- Edge triggered lock from processor request
	-- Change state to DECIDING and latch the calculated grant, meanwhile inform the processor of grantation
	-- Mux wire-level connections between the granted processor and the resource
	-- 
	-- 2) To UNLOCK
	-- Edge triggered unlock from de-assertion of processor request
	-- Jump to IDLE state and wait for the next request to come
	-- -----------------------------------------------------------------------------------------------------------------
	proc_ticket_lock : process (rsi_reset_reset,csi_clock_clk) 
	begin
		if (rising_edge(csi_clock_clk)) then 
			if (rsi_reset_reset = '1') then 
				-- reset the state
				ticket_lock_state		<= RESET;
				-- reset 
				ticket_lock.req			<= (others => '0');
			else
				-- -----------------------------------
				-- latch the lock request to request
				-- -----------------------------------
				for i in 0 to N_DQ_LINES-1 loop
					if (ticket_lock.lock_req(i) = '1') then 
						ticket_lock.req(i)		<= '1';
					elsif (ticket_lock.gnt(i) = '1') then -- de-assert the req
						ticket_lock.req(i)		<= '0';
					end if;
				end loop;
				
				-- -----------------------------------------------------------------------------------------------
				-- main state machine to manage the lock status by detecting the request/nrequest each lane
				-- -----------------------------------------------------------------------------------------------
				case ticket_lock_state is 
					when DECIDING => -- find the next grant, given the currrent cycle request
						ticket_lock.gnt			<= ticket_lock.grant_comb; -- latch the calculated decision
						ticket_lock.priority	<= ticket_lock.grant_comb(N_DQ_LINES-2 downto 0) & ticket_lock.grant_comb(N_DQ_LINES-1); -- update the priority
						ticket_lock_state		<= LOCKED;
					when LOCKED => -- the semaphore is been used, wait for unlock
						if (or_reduce(ticket_lock.unlock_req) = '1') then -- unlock is present
							ticket_lock.gnt			<= (others => '0'); -- clear the current grant
							ticket_lock_state		<= IDLE; -- jump to idle state
						end if;
						when IDLE => -- no request is present (normal state)
							if (or_reduce(ticket_lock.req) = '1') then -- there is request in the queue
								ticket_lock_state		<= DECIDING; -- jump to deciding state to calculate the next grant
							end if;
						when RESET => -- reset the current selection
							ticket_lock.priority		<= std_logic_vector(to_unsigned(1,ticket_lock.priority'length)); -- reset priority
							ticket_lock.gnt				<= (others => '0'); -- reset the current grant
							ticket_lock_state			<= IDLE; -- wait in idle state 
					when others =>
						null;
				end case;
			
			end if; -- sync reset end 
		end if; -- clock end 
	end process;
	
	proc_ticket_lock_comb : process (all)
		variable result0		: std_logic_vector(N_DQ_LINES*2-1 downto 0);
		variable result0p5		: std_logic_vector(N_DQ_LINES*2-1 downto 0);
		variable result1		: std_logic_vector(N_DQ_LINES*2-1 downto 0);
		variable result2		: std_logic_vector(N_DQ_LINES*2-1 downto 0);
	begin
		-- --------------------------------
		-- lock detection (rising edge) 
		-- --------------------------------
		for i in 0 to N_DQ_LINES-1 loop
			if (processor_req(i) = '1' and processor_req_d1(i) = '0') then 
				ticket_lock.lock_req(i)		<= '1';
			else
				ticket_lock.lock_req(i)		<= '0';
			end if;
		end loop;
		
		-- --------------------------------
		-- unlock detection (falling edge)
		-- --------------------------------
		for i in 0 to N_DQ_LINES-1 loop
			if (processor_req(i) = '0' and processor_req_d1(i) = '1') then 
				ticket_lock.unlock_req(i)		<= '1';
			else 
				ticket_lock.unlock_req(i)		<= '0';
			end if;
		end loop;
		
		-- --------------------------------
		-- next decision calculation
		-- --------------------------------
		-- +------------------------------------------------------------------------------------+
		-- | Concept borrowed from 'altera_merlin_std_arbitrator_core.sv`                       |
		-- |                                                                                    |
		-- | Example:                                                                           |
		-- |                                                                                    |
		-- | top_priority                        =        010000                                |
		-- | {request, request}                  = 001001 001001  (result0)                     |
		-- | {~request, ~request} + top_priority = 110111 000110  (result1)                     |
		-- | result of & operation               = 000001 000000  (result2)                     |
		-- | next_grant                          =        000001  (grant_comb)                  |
		-- +------------------------------------------------------------------------------------+
		result0		:= ticket_lock.req & ticket_lock.req;
		result0p5	:= not ticket_lock.req & not ticket_lock.req;
		result1		:= std_logic_vector(unsigned(result0p5) + unsigned(ticket_lock.priority));
		result2		:= result0 and result1;
		if (or_reduce(result2(N_DQ_LINES-1 downto 0)) = '0') then 
			ticket_lock.grant_comb		<= result2(N_DQ_LINES*2-1 downto N_DQ_LINES);
		else
			ticket_lock.grant_comb		<= result2(N_DQ_LINES-1 downto 0);
		end if;
		
	end process;

	-- ===============================
	-- port_mux
	-- ===============================
	-- connect the processors to the input and output ports, depending on the current grant
	proc_port_mux_comb : process (all)
	begin
		-- --------------------------------
		-- default connection
		-- --------------------------------
		avm_ctrl_write		<= '0';
		avm_ctrl_address	<= (others => '0');
		avm_ctrl_writedata	<= (others => '0');
		asi_rx_ready		<= '0';
		aso_tx_valid		<= '0';
		aso_tx_channel		<= (others => '0'); 
		aso_tx_data			<= (others => '0');
		avm_ctrl_read		<= '0';
		-- --------------------------------
		-- cascade of selection
		-- --------------------------------
		for i in 0 to N_DQ_LINES-1 loop
			if (ticket_lock.gnt(i) = '1') then -- if this processor is selected by the ticket_lock in this period
				-- flow-dependent
				if (core_rx_state(i) = IDLE) then -- during tx flow
					avm_ctrl_write		<= mm_write.tx(i);
					avm_ctrl_address	<= mm_address.tx(i);
					avm_ctrl_writedata	<= mm_data.tx(i);
				else -- during rx flow
					avm_ctrl_write		<= mm_write.rx(i);
					avm_ctrl_address	<= mm_address.rx(i);
					avm_ctrl_writedata	<= mm_data.rx(i);
				end if;
				-- flow-independent
				avm_ctrl_read	<= mm_read.tx(i);
				asi_rx_ready	<= st_ready(i);
				aso_tx_valid	<= st_valid(i);
				aso_tx_data		<= st_data(i);
				aso_tx_channel	<= std_logic_vector(to_unsigned(i,aso_tx_channel'length));
			end if;
		end loop;
	end process;
	
	
	-- ===============================
	-- csr_hub
	-- ===============================
	-- host the memory access from qsys into the csr register pack
	-- update the csr during idle
	
	-- example tree:
	-- mu3e-ip-cores
    -- ├── alt_temp_sense_controller
    -- │   ├── altera_temp_sense_ctrl_hw.tcl
    -- │   └── altera_temp_sense_ctrl.vhd
	-- ...
	--
	-- memory-map:
	-- +-------------------------------------------------------------------------------------------------+
	-- |address              register name          access             function                          |
	-- +-------------------------------------------------------------------------------------------------+
-- word 0				UID
-- └── byte 3-0			└──	IP_UID					ro				common Mu3e IP identifier
-- 
-- word 1				META
-- ├── write 0			├──	VERSION					rw/ro			major/minor/patch/build
-- ├── write 1			├──	VERSION_DATE			rw/ro			YYYYMMDD
-- ├── write 2			├──	VERSION_GIT				rw/ro			truncated git stamp
-- └── write 3			└──	INSTANCE_ID				rw/ro			integrator instance id
--
-- word 2				SCRATCH					rw				host scratchpad/readback word
--
-- word 3				capability
-- ├── byte 1-0			├──	n_dq_lines				ro				the hardset number of dq lines
-- └── byte 3-2 		└──	n_sensors				ro				(not implemented yet)
-- 
-- word 4				control and status
-- ├── byte 1-0			├── sel_line				rw				select the line to access control code
-- ├── byte 2			├── line_ctrl			
-- │   └── bit 0		│   └── processor_go		rw 				enable or disable the processor 
-- └── byte 3			└── line_status	
	--     ├── bit 0			├── crc_err				ro				crc error from the reading 
	--	   ├── bit 1			├── init_err			ro				initilization error (sensor not detected/powered)
	--	   └── bit 2			└── sample_valid		ro				full scratchpad has been captured after reset/latest read
	-- 
-- word 5 				sense_temp (sensor 0)		ro				floating-point temperature read from the sensor
--
-- word 6+				sense_temp (sensor 1+)		ro				reading from 2nd sensors and onward...
	-- 													
	proc_csr_hub : process (rsi_reset_reset,csi_clock_clk) 
	begin
		if (rising_edge(csi_clock_clk)) then -- clocked begin
			if (rsi_reset_reset = '1') then 
				-- reset
				avs_csr_waitrequest		<= '0'; -- release the qsys bus
				avs_csr_readdata		<= (others => '0');
				csr.meta_sel			<= META_SEL_VERSION_CONST;
				csr.scratch				<= (others => '0');
				csr.sel_line			<= (others => '0');
				csr.processor_go		<= (others => '0');
				csr.crc_err				<= (others => '0');
			else -- sync reset begin
				-- -------------------
				-- default
				-- -------------------
				avs_csr_waitrequest		<= '1';
				avs_csr_readdata		<= (others => '0');
				
				-- -------------------
				-- interface logic
				-- -------------------
				if (avs_csr_read = '1') then 
					avs_csr_waitrequest	<= '0'; -- ack the qsys bus
					case to_integer(unsigned(avs_csr_address)) is -- address map
						when CSR_WORD_UID_CONST =>
							avs_csr_readdata		<= std_logic_vector(to_unsigned(IP_UID, AVMM_DATA_WIDTH));
						when CSR_WORD_META_CONST =>
							case csr.meta_sel is
								when META_SEL_VERSION_CONST =>
									avs_csr_readdata	<= pack_version_func(VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, BUILD);
								when META_SEL_DATE_CONST =>
									avs_csr_readdata	<= std_logic_vector(to_unsigned(VERSION_DATE, AVMM_DATA_WIDTH));
								when META_SEL_GIT_CONST =>
									avs_csr_readdata	<= std_logic_vector(to_unsigned(VERSION_GIT, AVMM_DATA_WIDTH));
								when META_SEL_INSTANCE_CONST =>
									avs_csr_readdata	<= std_logic_vector(to_unsigned(INSTANCE_ID, AVMM_DATA_WIDTH));
								when others =>
									avs_csr_readdata	<= (others => '0');
							end case;
						when CSR_WORD_SCRATCH_CONST =>
							avs_csr_readdata		<= csr.scratch;
						when CSR_WORD_CAPABILITY_CONST =>
							avs_csr_readdata(15 downto 0)	<= std_logic_vector(to_unsigned(N_DQ_LINES,16));
							avs_csr_readdata(31 downto 16)	<= (others => '0');
						when CSR_WORD_STATUS_CONST =>
							avs_csr_readdata(15 downto 0)	<= csr.sel_line;
							for i in 0 to N_DQ_LINES-1 loop
								if (to_integer(unsigned(csr.sel_line)) = i) then 
									avs_csr_readdata(16)			<= csr.processor_go(i);
									avs_csr_readdata(24)			<= csr.crc_err(i);
									avs_csr_readdata(25)			<= csr.init_err(i);
									avs_csr_readdata(26)			<= sensor_sample_valid(i);
								end if;
							end loop;
						when others => -- temperature 
							-- WARNING: no range check here
							for i in 0 to N_DQ_LINES-1 loop
								if (to_integer(unsigned(avs_csr_address))-CSR_WORD_TEMP_BASE_CONST = i) then
									if (sensor_sample_valid(i) = '1') then
										avs_csr_readdata		<= csr.sense_temp(i);
									else
										avs_csr_readdata		<= (others => '0');
									end if;
								end if;
							end loop;
						end case;
				elsif (avs_csr_write = '1') then 
					avs_csr_waitrequest	<= '0'; -- ack the qsys bus
					case to_integer(unsigned(avs_csr_address)) is -- address map
						when CSR_WORD_UID_CONST =>
							null; -- NOTE: read-only
						when CSR_WORD_META_CONST =>
							csr.meta_sel		<= avs_csr_writedata(1 downto 0);
						when CSR_WORD_SCRATCH_CONST =>
							csr.scratch			<= avs_csr_writedata;
						when CSR_WORD_CAPABILITY_CONST =>
							null; -- NOTE: read-only
						when CSR_WORD_STATUS_CONST =>
							csr.sel_line		<= avs_csr_writedata(15 downto 0);
							for i in 0 to N_DQ_LINES-1 loop -- NOTE: the processor_go will set the CURRENT sel_line 
								if (to_integer(unsigned(avs_csr_writedata(15 downto 0))) = i) then 
									csr.processor_go(i)			<= avs_csr_writedata(16);
								end if;
							end loop;
						when others => 
							null; -- read-only for now, TODO: you may reset the line if you attempt to write
					end case;
				-- -----------------------
				-- hub logic
				-- -----------------------
				else 
					
					
				end if;
			end if; -- sync reset end
			
			
			
		
			for i in 0 to N_DQ_LINES-1 loop
				csr.sense_temp(i)		<= sense_temp_comb(i); -- latch converted temperature 
				csr.init_err(i)			<= sensor_error(i).init_fail; -- latch error descriptor 
			end loop;
			
		end if; -- clocked end
	end process;
	
	-- ==========================
	-- crc_checker
	-- ==========================
	
	
	
	-- ==========================
	-- format_convertor
	-- ==========================
	
	-- converting from DS18B20 reading to float-32 (IEEE754-Single Precision Binary32 Floating Point)
	--
	-- the sensor temperature raw format consists of a sign and a fraction field, starting from 2^6 to 2^-4. 
	-- so, we need to calculate the sign exponent field when converting to float-32
	-- 
	-- formula of ieee float-32: 
	--
	-- value = (-1)^sign x 2^(E-127) x [1 + sum{i=1~23} b_{32-i}*2^(-i)]
	gen_format_convertor : for i in 0 to N_DQ_LINES-1 generate 
		proc_format_convertor_comb : process (all)
			variable temp_sign		: std_logic_vector(4 downto 0);
			variable temp_frac		: std_logic_vector(10 downto 0);
			variable f32_sign		: std_logic;
			variable f32_expo		: std_logic_vector(7 downto 0);
			variable f32_frac		: std_logic_vector(22 downto 0);
		begin
			-- input
			temp_sign		:= sensor_data(i)(1)(7 downto 3); -- S=0 positive, S=1 negative
			temp_frac		:= sensor_data(i)(1)(2 downto 0) & sensor_data(i)(0);
			
			-- default
			f32_sign		:= and_reduce(temp_sign); -- NOTE: more likely to be positive, in case of error, so more prune to report overheat 
			f32_expo		:= std_logic_vector(to_unsigned(127,f32_expo'length));
			f32_frac		:= (others => '0');
			-- convert
			if (unsigned(temp_frac) = 0) then
				f32_sign		:= '0';
				f32_expo		:= (others => '0');
				f32_frac		:= (others => '0');
			else
				for j in 0 to 10 loop 
					if (temp_frac(j) = '1') then -- detect the position of leading '1' 
						f32_expo				:= std_logic_vector(to_unsigned(j-4+127,f32_expo'length));
						f32_frac(22 downto 12)	:= std_logic_vector(shift_left(unsigned(temp_frac),11-j)); -- shift the remaining bit as fraction
						-- for example for raw of +4=2^2, bit 6 is '1', others are '0'. 
						-- exponent part is 2^2, where 2 is from 6-4. 
						-- fraction part is just the remaining bit, shifted to fill the fraction from msb
					end if;
				end loop;
			end if;
			
			-- output 
			sense_temp_comb(i)	<= f32_sign & f32_expo & f32_frac;
		end process;
	end generate;


end architecture rtl;
