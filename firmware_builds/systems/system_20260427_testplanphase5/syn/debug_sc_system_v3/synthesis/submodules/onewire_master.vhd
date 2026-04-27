-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             onewire_master
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- Revision:            1.0
-- Date:                Aug 29, 2024 (file created)
-- Description:         Perform 1-Wire data rx/tx transmission in link and physical layer. 
-- Usage:                
-- 		                [RX flow]: 
--                      Master needs to specify the number of bits to receive with avmm <ctrl> port.
--                      Master receives the interrupt signal to indicate data transmission is completed.
-- 		                Master asserts ready in the avst port <rx> to receive the rx data.
--
--                      [TX flow]:
--                      Master needs to specify the number of bits to transmit with avmm <ctrl> port.
--                      Master asserts valid in the avst port <tx> to transmit the tx data.
--                      Master waits for the interrupt or check the avmm <ctrl> to sense the completion. 
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
-- altera-specific
LIBRARY altera_mf;
USE altera_mf.all;

entity onewire_master is
generic (
	-- +--------------------------------+
	-- | transmission timing parameters |
	-- +--------------------------------+
	-- init
	MASTER_INIT_RESET_US					: natural   := 500; -- must be larger than 480 us.
	MASTER_WAIT_PRESENCE_US		    		: natural   := 45; -- between 15-60 us, wait for cable to pull-up.
	MASTER_SAMPLE_PRESENCE_TIMEOUT_US		: natural   := 1000; -- must be larger than 480 us. 
	-- rx/tx
	SLOTS_SEPERATION_US				: natural   := 5; -- must be larger than 1 us.
	-- rx
	RX_SLOT_US						: natural   := 90; -- must be larger than 60 us.
	RX_PULL_LOW_US					: natural	:= 5; -- pull low to start rx a bit
	RX_MASTER_SAMPLE_US				: natural   := 10; -- data is valid for 15 us after the falling edge (<15 us, not smaller, you need to check the pull-up resistor value)
	-- tx
	TX_SLOT_US 						: natural 	:= 90; -- same as rx slot
	TX_PULL_LOW_US					: natural   := 5; -- must be smaller than 15
	-- +------------------------------+
	-- | periphial circuitry settings |
	-- +------------------------------+
	PARACITIC_POWERING 				: boolean 	:= true; -- if true, a strong pull up will be used for dq idle. Otherwise, high-Z.
	-- +-------------+
	-- | IP settings |
	-- +-------------+
	REF_CLOCK_RATE					: natural   := 156250000; -- it will internally down-convert to a slow clock of 1 MHz
	AVST_DATA_WIDTH					: natural	:= 8; -- rx/tx data bit width, usually it is a byte
	AVMM_DATA_WIDTH					: natural   := 32;
	N_DQ_LINES						: natural   := 6; -- >1: allows to connect n 1-Wire modules on n dq line, select with channel. NOTE: this is different from m modules on the a single dq line.
	AVST_CHANNEL_WIDTH				: natural	:= 3; -- log2 of (N_DQ_LINES)
	RX_BUFFER_DEPTH					: natural   := 16; -- the fifo depth of received data, 9-byte read ROM is the longest to receive
	TX_BUFFER_DEPTH					: natural   := 8; -- the fifo depth of transmitting data, 64-bit ROM is the longest to send
	VARIANT							: string	:= "lite"; -- 0: lite (w/o sensor ROM auto-discovery, user either record it before or skip_rom when one sensor on a dq line). 1: full (w/ sensor ROM auto-discovery)
	DEBUG_LV						: natural   := 2;
	-- hidden
	RX_FIFO_TYPE					: string	:= "MLAB"; -- M10K, MLAB, M20K
	TX_FIFO_TYPE					: string	:= "MLAB"; -- M10K, MLAB, M20K
	MAX_BUFFER_DEPTH				: natural	:= 16
);
port (
	-- avmm (ctrl)
	avs_ctrl_read					: in  std_logic;
	avs_ctrl_readdata				: out std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
	avs_ctrl_write					: in  std_logic;
	avs_ctrl_writedata				: in  std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
	avs_ctrl_address				: in  std_logic_vector(3 downto 0);
	avs_ctrl_waitrequest			: out std_logic;
	
	-- avst (rx)
	-- receiving data from sensor
	aso_rx_data						: out std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
	aso_rx_valid					: out std_logic;
	aso_rx_ready					: in  std_logic;
	aso_rx_channel					: out std_logic_vector(AVST_CHANNEL_WIDTH-1 downto 0); -- 3 bit for 8 dq lines
	
	-- avst (tx)
	-- sending data to sensor
	asi_tx_data						: in  std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
	asi_tx_valid					: in  std_logic;
	asi_tx_ready					: out std_logic;
	asi_tx_channel					: in  std_logic_vector(AVST_CHANNEL_WIDTH-1 downto 0);
	
	-- irq of transaction completion
	ins_complete_irq				: out std_logic;

	-- 1-Wire port (tri-state) (with n (max_sensor) lines)
	-- please connect all these manually altiobuf ip in top, to prevent this entity been forced to pushed to top. 
	-- this will help you in drawing boundaries for design partition.
	coe_sense_dq_in							: in  std_logic_vector(N_DQ_LINES-1 downto 0);
	coe_sense_dq_out						: out std_logic_vector(N_DQ_LINES-1 downto 0);
	coe_sense_dq_oe							: out std_logic_vector(N_DQ_LINES-1 downto 0); -- 1: output enable, 0: high-Z
	
	-- clock and reset interface
	rsi_reset_reset							: in  std_logic;
	csi_clock_clk							: in  std_logic
);
end entity onewire_master;
	

architecture rtl of onewire_master is
	-- **global**
	-- constants
	constant MAX_RXTX_BYTES		: natural := MAX_BUFFER_DEPTH; -- not supported: maximum(RX_BUFFER_DEPTH,TX_BUFFER_DEPTH);
	-- need to convert natural into unsigned, otherwise integer comparision in vhdl does not work correctly.
	constant MASTER_INIT_RESET_US_U					: unsigned(15 downto 0) := to_unsigned(MASTER_INIT_RESET_US,16);
	constant MASTER_WAIT_PRESENCE_US_U				: unsigned(15 downto 0) := to_unsigned(MASTER_WAIT_PRESENCE_US,16);
	constant MASTER_SAMPLE_PRESENCE_TIMEOUT_US_U	: unsigned(15 downto 0) := to_unsigned(MASTER_SAMPLE_PRESENCE_TIMEOUT_US,16);
	constant SLOTS_SEPERATION_US_U					: unsigned(15 downto 0) := to_unsigned(SLOTS_SEPERATION_US,16);
	constant RX_SLOT_US_U							: unsigned(15 downto 0) := to_unsigned(RX_SLOT_US,16);
	constant RX_PULL_LOW_US_U						: unsigned(15 downto 0) := to_unsigned(RX_PULL_LOW_US,16);
	constant RX_MASTER_SAMPLE_US_U					: unsigned(15 downto 0) := to_unsigned(RX_MASTER_SAMPLE_US,16);
	constant TX_SLOT_US_U							: unsigned(15 downto 0) := to_unsigned(TX_SLOT_US,16);
	constant TX_PULL_LOW_US_U						: unsigned(15 downto 0) := to_unsigned(TX_PULL_LOW_US,16);
	
	-- ---------------------------------
	-- slow_clock_convertor
	-- ---------------------------------
	signal pseudo_clk_slow		: std_logic;
	signal slow_tick			: std_logic;
	
	-- ------------------------------------
	-- slow_timer
	-- ------------------------------------
	signal slow_timer_on			: std_logic;
	signal slow_timer_cnt_unsigned	: unsigned(15 downto 0); -- overflow at 65536, which gives max timing table up to 65ms. 
	--signal slow_timer_cnt			: integer range 0 to 2*15-1;
	
	-- ---------------------------
	-- tx_fifo
	-- ---------------------------
	-- constants
	constant TX_FIFO_WIDTHU		: natural := integer(ceil(log2(real(TX_BUFFER_DEPTH))));
	constant RX_FIFO_WIDTHU		: natural := integer(ceil(log2(real(RX_BUFFER_DEPTH))));
	
	-- decleration
	component scfifo -- copy from "altera_mf_components"
	generic (
		add_ram_output_register	:	string := "OFF";
		allow_rwcycle_when_full	:	string := "OFF";
		almost_empty_value	:	natural := 0;
		almost_full_value	:	natural := 0;
		intended_device_family	:	string := "unused";
		enable_ecc	:	string := "FALSE";
		lpm_numwords	:	natural;
		lpm_showahead	:	string := "ON";
		lpm_width	:	natural;
		lpm_widthu	:	natural := 1;
		overflow_checking	:	string := "ON";
		ram_block_type	:	string := "AUTO";
		underflow_checking	:	string := "ON";
		use_eab	:	string := "ON";
		lpm_hint	:	string := "UNUSED";
		lpm_type	:	string := "scfifo"
	);
	port(
		--aclr	:	in std_logic := '0';
		--almost_empty	:	out std_logic;
		--almost_full	:	out std_logic;
		clock	:	in std_logic;
		data	:	in std_logic_vector(lpm_width-1 downto 0);
		--eccstatus	:	out std_logic_vector(1 downto 0);
		empty	:	out std_logic;
		full	:	out std_logic;
		q	:	out std_logic_vector(lpm_width-1 downto 0);
		rdreq	:	in std_logic;
		sclr	:	in std_logic := '0';
		usedw	:	out std_logic_vector(lpm_widthu-1 downto 0);
		wrreq	:	in std_logic
	);
	end component;
	
	-- records
	type tx_fifo_t is record
		-- write port
		wrreq				: std_logic;
		data				: std_logic_vector(AVST_DATA_WIDTH+AVST_CHANNEL_WIDTH-1 downto 0);
		-- read port		
		rdreq				: std_logic;
		q					: std_logic_vector(AVST_DATA_WIDTH+AVST_CHANNEL_WIDTH-1 downto 0);
		-- control port
		sclr				: std_logic;
		-- status port
		empty				: std_logic;
		full				: std_logic;
		usedw				: std_logic_vector(TX_FIFO_WIDTHU-1 downto 0);
	end record;
	
	-- signals
	signal tx_fifo				: tx_fifo_t;
	
	
	-- -----------------------------
	-- rx_fifo
	-- -----------------------------
	-- records
	type rx_fifo_t is record
		-- write port
		wrreq				: std_logic;
		data				: std_logic_vector(AVST_DATA_WIDTH+AVST_CHANNEL_WIDTH-1 downto 0);
		-- read port		
		rdreq				: std_logic;
		q					: std_logic_vector(AVST_DATA_WIDTH+AVST_CHANNEL_WIDTH-1 downto 0);
		-- control port
		sclr				: std_logic;
		-- status port
		empty				: std_logic;
		full				: std_logic;
		usedw				: std_logic_vector(RX_FIFO_WIDTHU-1 downto 0);
	end record;
	-- signals
	signal rx_fifo				: rx_fifo_t;
	
	
	-- ---------------------------------
	-- interface_hub
	-- ---------------------------------
	-- types
	type interface_hub_flow_t is (IDLE,STARTING,ENDING);
	type pipe_handler_t is (IDLE,TX_ACK,RX_ACK);
	type interface_hub_t is record
		read_one_done			: std_logic;
		write_one_done			: std_logic;
		flow					: interface_hub_flow_t;
		pipe_handler			: pipe_handler_t;
		rx_rdreq				: std_logic;
		tx_wrreq				: std_logic;
		tx_data					: std_logic_vector(AVST_DATA_WIDTH+AVST_CHANNEL_WIDTH-1 downto 0);
	end record;
	
	type csrerror_t is record
		out_of_range			: std_logic;
		init_fail				: std_logic;
	end record;
	type csr_t is record
		commit					: std_logic;
		busy					: std_logic; -- polling for completion
		direction				: std_logic; -- 1:TX, 0:RX
		tot_bytes				: natural range 0 to MAX_RXTX_BYTES; -- default: up to 16 
		usewire_id				: std_logic;
		wire_id					: natural range 0 to N_DQ_LINES-1; -- select the dq line index
		error					: csrerror_t;
		init					: std_logic;
		paracitic_pw			: std_logic;
	end record;
	
	-- signals and resets
	signal interface_hub		: interface_hub_t;
	constant csrerror_rst		: csrerror_t := (out_of_range => '0', init_fail => '0');
	constant csr_rst			: csr_t :=(
		commit					=> '0',
		busy					=> '0',
		direction				=> '0',
		tot_bytes				=> 0,
		usewire_id				=> '0',
		wire_id					=> 0,
		error					=> csrerror_rst,
		init					=> '0',
		paracitic_pw			=> '0' -- here default is false, set it later
	);
	signal csr					: csr_t := csr_rst;
	
	-- ----------------------------------
	-- bidir_hal
	-- ----------------------------------
	type sense_bidir_io_t is (PULL_HIGH,PULL_LOW,HIGH_Z);
	type sense_bidir_io_group_t is array (0 to N_DQ_LINES-1) of sense_bidir_io_t;
	
	signal sense_bidir_io_group		: sense_bidir_io_group_t;
	constant dq_rst_0				: sense_bidir_io_group_t := (others => HIGH_Z);
	constant dq_rst_1				: sense_bidir_io_group_t := (others => PULL_HIGH);
	
	
	-- -----------------------------------
	-- tx_engine
	-- -----------------------------------
	-- types 
	type tx_flow_t is (IDLE,LOAD_TX_DATA,SEND_INIT,SEND_BIT,EVAL,ACK,RESET);
	type init_timing_t is (MASTER_TX_RESET,MASTER_RELEASE,MASTER_SENSE_PRESENCE,MASTER_EVAL);
	type tx_bit_timing_t is (MASTER_PULL_LOW,MASTER_SEND_BIT,MASTER_IDLE,MASTER_EVAL);
	type tx_engine_t is record
		flow					: tx_flow_t;
		init_timing				: init_timing_t;
		bit_timing				: tx_bit_timing_t;
		slow_timer_on			: std_logic;
		tx_data					: std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
		bit_cnt					: natural range 0 to AVST_DATA_WIDTH; -- up to 8 
		byte_cnt				: natural range 0 to MAX_RXTX_BYTES;
		updated					: std_logic;
		wire_id					: natural range 0 to N_DQ_LINES-1; -- select the dq line index
		dq						: sense_bidir_io_group_t;
		error_init_fail			: std_logic;
		error_fifo_empty		: std_logic;
	end record;
	
	-- signals
	signal tx_engine			: tx_engine_t;
	
	-- ----------------------------------
	-- rx_engine
	-- ----------------------------------
	type rx_flow_t is (IDLE,EVAL_CMD,RECV_BIT,STORE_RX_DATA,ACK,RESET);
	type rx_bit_timing_t is (MASTER_PULL_LOW,MASTER_RELEASE,MASTER_SAMPLE_BIT,MASTER_IDLE,MASTER_EVAL);
	type rx_engine_t is record
		flow					: rx_flow_t;
		bit_timing				: rx_bit_timing_t;
		slow_timer_on			: std_logic;
		rx_data					: std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
		bit_cnt					: natural range 0 to AVST_DATA_WIDTH;
		byte_cnt				: natural range 0 to MAX_RXTX_BYTES;
		dq						: sense_bidir_io_group_t;
		updated					: std_logic;
		error_fifo_full			: std_logic;
	end record;
	
	-- signals
	signal rx_engine			: rx_engine_t;

	
	
	-- ---------------------
	-- memory map info (mmio)
	-- ---------------------
	-- records
	-- ======================
	-- begin CSR
	-- word 0
	type csr_w_0_t is record
		commit					: std_logic_vector(0 downto 0);
		busy					: std_logic_vector(0 downto 0);
	end record;
	-- word 1
	type csr_w_1_t is record
		direction				: std_logic_vector(0 downto 0); -- direction, '1': tx, '0': rx 
		init					: std_logic_vector(1 downto 1); -- send init pulse, if '1', other fields are ignored
		paracitic_pw			: std_logic_vector(2 downto 2); -- power scheme, if '1', strong pull high during dq IDLE. 
		usewire_id				: std_logic_vector(3 downto 3); 
		tot_bytes				: std_logic_vector(15 downto 8);
		wire_id					: std_logic_vector(23 downto 16);
	end record;
	-- word 2
	type csr_w_2_t is record
		txfifo_usedw			: std_logic_vector(TX_FIFO_WIDTHU-1 downto 0);
		rxfifo_usedw			: std_logic_vector(RX_FIFO_WIDTHU-1+16 downto 16);
	end record;
	-- end CSR
	-- =======================
	
	-- memory-mapping pack
	type mmap_t is record
		csr_w_0				: csr_w_0_t;
		csr_w_1				: csr_w_1_t;
		csr_w_2				: csr_w_2_t;
	end record;
	
	-- signals
	signal mmap					: mmap_t;
	
	-- ---------------------------------
	-- pipes
	-- ---------------------------------
	-- records
	type simple_coroutine_pipe_t is record
		start					: std_logic;
		done					: std_logic;
	end record;
	type pipe_t is record
		tx						: simple_coroutine_pipe_t;
		rx						: simple_coroutine_pipe_t;
	end record;
	
	-- signals
	signal pipe					: pipe_t;
	
	
	
	-- ---------------------------
	-- (helper) range_checker
	-- ---------------------------
	type check_list_t is record -- only valid when it is called
		tot_bytes				: integer range 0 to integer(2**8-1);
		wire_id					: integer range 0 to integer(2**8-1);
		result					: std_logic;
	end record;
	signal check_list			: check_list_t;
	

begin

	-- ---------------------------------
	-- slow_clock_convertor
	-- ---------------------------------
	-- checks
	assert REF_CLOCK_RATE >= 1000_000 report "reference clock rate must be larger than 1MHz!" severity error;
	assert MAX_RXTX_BYTES < 2**16 report "RX or TX fifo depth too large, csr might not be able to display it properly! (you may overwrite it)" severity error;
	
	-- instantiation
	e_sensor_slow_clock : entity work.pseudo_clock_down_convertor
		-- down convert ref clock to sensor link layer clock rate (1 MHz)
	generic map ( 
		CLK_DOWN_FACTOR => REF_CLOCK_RATE / 1000000 -- NOTE: ref clock must be larger than 1MHz
	)
	port map ( 
		-- input fast clock and reset interface
		i_clk 			=> csi_clock_clk, -- input clock
		i_reset_n 		=> not rsi_reset_reset,	-- input reset
		-- pseudo slow clock
		o_clk		 	=> pseudo_clk_slow, -- so far not used, can be slow down the overall state machine to release more timing slack
		-- slow tick (active for one fast cycle at the rising edge of the slow clock)
		o_tick			=> slow_tick
	);
	
	-- ------------------------------------
	-- slow_timer
	-- ------------------------------------
	proc_slow_timer : process(rsi_reset_reset,csi_clock_clk)
		-- a counter synchronized in master clock domain, for the link layer signal formation of 1-Wire protocol
	begin
		if rising_edge(csi_clock_clk) then
			if (rsi_reset_reset = '1' or slow_timer_on = '0') then
				slow_timer_cnt_unsigned 	<= (others => '0'); -- reset the count when off
			else
				if (slow_tick = '1') then -- count up at 1 MHz rate
					slow_timer_cnt_unsigned 	<= slow_timer_cnt_unsigned + 1; -- NOTE: pls ensure it is only high for 1 cycle
				end if;
			end if;
		end if;
	end process;
	
--	proc_slow_timer_comb : process (all)
--	begin
--		slow_timer_cnt		<= to_integer(slow_timer_cnt_unsigned);
--	end process;
	
	-- ----------------------------
	-- arbiter 
	-- ----------------------------
	proc_arbiter : process (all)
		-- arbiter for signals with contention
	begin
		-- for setting the slow timer, in principle, there is no contention as at one time only rx or tx can be running. so a simple "OR" is used.
		slow_timer_on		<= tx_engine.slow_timer_on or rx_engine.slow_timer_on;
	end process;

	-- ----------------------------
	-- tx_fifo
	-- ----------------------------
	e_tx_fifo : scfifo
	generic map (
		add_ram_output_register	 	=> "ON",
		intended_device_family 		=> "Arria V",
		lpm_numwords 				=> TX_BUFFER_DEPTH,
		lpm_type 					=> "scfifo",
		lpm_width 					=> AVST_CHANNEL_WIDTH + AVST_DATA_WIDTH, -- msb are wire_id
		lpm_widthu 					=> TX_FIFO_WIDTHU,
		ram_block_type				=> TX_FIFO_TYPE,
		overflow_checking 			=> "ON",
		underflow_checking 			=> "ON",
		use_eab 					=> "ON"
	)
	port map (
		-- clock port
		clock 	=> csi_clock_clk,
		-- write port
		wrreq 	=> tx_fifo.wrreq,
		data 	=> tx_fifo.data, -- msb are the channel id from avalon
		-- read port
		rdreq 	=> tx_fifo.rdreq,
		q 		=> tx_fifo.q,
		-- control port
		sclr 	=> tx_fifo.sclr,
		-- status port
		empty 	=> tx_fifo.empty,
		full 	=> tx_fifo.full,
		usedw 	=> tx_fifo.usedw
	);
	
	proc_tx_fifo : process (csi_clock_clk,rsi_reset_reset)
	begin
		if rising_edge(csi_clock_clk) then 
			-- ==================== sync reset =======================
			if (rsi_reset_reset = '1') then 
				tx_fifo.sclr			<= '1';
			else
				-- user may start another command only even if fifo is not empty, but it is the user's resbonsibility to prevent fifo overflow. In such event, all data will be flushed.
				if (tx_fifo.full = '1') then -- triggered by full
					tx_fifo.sclr			<= '1';
				elsif (tx_fifo.empty = '1') then -- stop flush after empty is hit
					tx_fifo.sclr			<= '0';
				end if;
			
			end if;
		
		end if;
	end process;
	

	
	-- -----------------------------
	-- rx_fifo
	-- -----------------------------
	e_rx_fifo : scfifo
	generic map (
		add_ram_output_register	 	=> "ON",
		intended_device_family 		=> "Arria V",
		--lpm_hint					=> "RAM_BLOCK_TYPE=MLAB",
		lpm_numwords 				=> RX_BUFFER_DEPTH,
		lpm_type 					=> "scfifo",
		lpm_width 					=> AVST_CHANNEL_WIDTH + AVST_DATA_WIDTH, -- msb are wire_id
		lpm_widthu 					=> RX_FIFO_WIDTHU,
		ram_block_type				=> RX_FIFO_TYPE,
		overflow_checking 			=> "ON",
		underflow_checking 			=> "ON",
		use_eab 					=> "ON"
	)
	port map (
		-- clock port
		clock 	=> csi_clock_clk,
		-- write port
		wrreq 	=> rx_fifo.wrreq,
		data 	=> rx_fifo.data,
		-- read port
		rdreq 	=> rx_fifo.rdreq,
		q 		=> rx_fifo.q,
		-- control port
		sclr 	=> rx_fifo.sclr,
		-- status port
		empty 	=> rx_fifo.empty,
		full 	=> rx_fifo.full,
		usedw 	=> rx_fifo.usedw
	);
	
	proc_rx_fifo : process (csi_clock_clk,rsi_reset_reset)
	begin
		if rising_edge(csi_clock_clk) then 
			if (rsi_reset_reset = '1') then 
				rx_fifo.sclr			<= '1';
			else
				-- user may start another command only if fifo is not empty, but it is the user's resbonsibility to prevent fifo overflow. 
				-- In overflow event, all data will be flushed. (DEBUG)
				if (DEBUG_LV > 0) then 
					if (rx_fifo.full = '1') then -- triggered by full
						rx_fifo.sclr			<= '1';
					elsif (rx_fifo.empty = '1') then -- stop flush after empty is hit
						rx_fifo.sclr			<= '0';
					end if;
				else -- in overflow event, data are kept in the fifo and command will be ack'd early. 
					rx_fifo.sclr			<= '0';
				end if;
				-- TODO: add avst read port 
				
			end if;
		end if;
	end process;
	
	
	-- ------------------------
	-- interface_hub
	-- ------------------------
	proc_interface_hub : process (csi_clock_clk,rsi_reset_reset)
	begin
		if rising_edge(csi_clock_clk) then 
			if (rsi_reset_reset = '1') then 
				csr						<= csr_rst;
				if (PARACITIC_POWERING) then 
					csr.paracitic_pw		<= '1';
				else
					csr.paracitic_pw		<= '0';
				end if;
				pipe.tx.start			<= '0';
				pipe.rx.start			<= '0';
			else 
				-- interface logic
				-- +-------------------------------------------------------------------------------------------+
				-- | Input        :    csr.busy                                                                |
				-- | ========================================================================================= |
				-- | Routine type :    memory-mapped interface (mmio)                                          |
				-- | Routine name :    Control and Status Register Hub                                         |
				-- |                                                                                           |
				-- | Description  :    As an avalon memory-mapped slave, provide access service to the masters.|                                              |
				-- |                   Mapping register access to its internal registers array (CSR), with     |
				-- |                   basic input validation.                                                 |
				-- |                   Maintaining memory **protection** of the mapping.                       |
				-- |                                                                                           |
				-- | Address map  :    (32b word addressing)                                                   |
				-- |                   0: control and status                                                   |
				-- |                       [??][??][?E][?C]                                                    |
				-- |                       E: error sympton                                                    | 
				-- |                           2: rx_fifo_empty                                                |
				-- |                           1: out_of_range                                                 |
				-- |                           0: init_fail                                                    |
				-- |                       C: commit/busyeted. write '1' to commit, read/polling               |
				-- |                          '0' to sense completion.                                         |
				-- |                                                                                           |
				-- |                   1: transfer command descriptor                                          |
				-- |                       [??][WW][BB][?C]                                                    |
				-- |                       W: wire index, select which dq line to use. (8 bits)                |
				-- |                       B: total bytes to send or receive. (8 bits)                         |
				-- |                       C: bit field:                                                       |
				-- |                           0: direction. '1': tx, '0': rx                                  |
				-- |                           1: init. '1': send init pulse before data, '0': just send data. |
				-- |                           2: paracitic powering. '1': strong pull up during link IDLE.    |
				-- |                           3: use wire id. '1': override the streaming channel id.         |
				-- |                              '0': use the streaming channel id as wire index instead.     |
				-- |                   2: fillness of rx/tx fifo                                               |
				-- |                       [RR][RR][TT][TT]                                                    |
				-- |                       R: RX fifo fillness in byte/symbol. (16 bit)                        |
				-- |                       T: TX fifo fillness in byte/symbol. (16 bit)                        |
				-- |                                                                                           |
				-- | ========================================================================================= |
				-- | Output       :    csr.commit                                                              |
				-- +-------------------------------------------------------------------------------------------+
				-- routine_mmio_csr_hub 
				-- default
				avs_ctrl_readdata				<= (others => '0');
				avs_ctrl_waitrequest			<= '1';
				-- logic
				if (avs_ctrl_read = '1') then -- read
					ins_complete_irq			<= '0'; -- clear the irq once read is performed
					avs_ctrl_waitrequest		<= '0';
					case to_integer(unsigned(avs_ctrl_address)) is
						when 0 =>
							avs_ctrl_readdata(0)			<= csr.busy;
							avs_ctrl_readdata(8)			<= csr.error.out_of_range;
							avs_ctrl_readdata(9)			<= csr.error.init_fail;
							avs_ctrl_readdata(10)			<= tx_engine.error_fifo_empty;
							avs_ctrl_readdata(11)			<= rx_engine.error_fifo_full;
						when 1 => 
							avs_ctrl_readdata(mmap.csr_w_1.direction'range)(0)									<= csr.direction;
							avs_ctrl_readdata(mmap.csr_w_1.init'range)(mmap.csr_w_1.init'low)					<= csr.init;
							avs_ctrl_readdata(mmap.csr_w_1.paracitic_pw'range)(mmap.csr_w_1.paracitic_pw'low)	<= csr.paracitic_pw;
							avs_ctrl_readdata(mmap.csr_w_1.usewire_id'range)(mmap.csr_w_1.usewire_id'low)		<= csr.usewire_id;
							avs_ctrl_readdata(mmap.csr_w_1.tot_bytes'range)			<= std_logic_vector(to_unsigned(csr.tot_bytes,mmap.csr_w_1.tot_bytes'length));
							avs_ctrl_readdata(mmap.csr_w_1.wire_id'range)			<= std_logic_vector(to_unsigned(csr.wire_id,mmap.csr_w_1.wire_id'length));
						when 2 => -- poll the fifo fillness. user may start another command only even if fifo is not empty, but it is the user's resbonsibility to prevent fifo overflow. In such event, all data will be flushed.
							avs_ctrl_readdata(mmap.csr_w_2.rxfifo_usedw'range)		<= rx_fifo.usedw;
							avs_ctrl_readdata(mmap.csr_w_2.txfifo_usedw'range)		<= tx_fifo.usedw;
						when 3 => -- read from the rx fifo (bypassing the rx interface)
							if (interface_hub.rx_rdreq = '0') then 
								avs_ctrl_waitrequest		<= '0';
								if (interface_hub.read_one_done = '0') then -- if this command is not digested
									interface_hub.read_one_done	<= '1';
									if (rx_fifo.empty = '0') then -- some fifo empty indication
										avs_ctrl_readdata(rx_fifo.q'high downto 0)			<= rx_fifo.q; -- ch + data portion
										interface_hub.rx_rdreq			<= '1';
									end if;
								end if;
							else
								interface_hub.rx_rdreq		<= '0';
								avs_ctrl_waitrequest		<= '1';
								avs_ctrl_readdata			<= (others => '0');
							end if;
						when others =>
							null;
					end case;
				elsif (avs_ctrl_write = '1') then -- write
					ins_complete_irq			<= '0'; -- clear the irq once write is performed
					avs_ctrl_waitrequest		<= '0';
					case to_integer(unsigned(avs_ctrl_address)) is
						when 0 =>
							csr.commit						<= avs_ctrl_writedata(mmap.csr_w_0.commit'range)(0);
						when 1 => -- descriptor of master transaction
							if (csr.busy = '1') then 
								-- refuse the write to the descriptor, as it is protected for the exclusive use for the rx and tx engine
							else 
								csr.direction					<= avs_ctrl_writedata(mmap.csr_w_1.direction'range)(0);
								csr.init						<= avs_ctrl_writedata(mmap.csr_w_1.init'range)(mmap.csr_w_1.init'low);
								if (not PARACITIC_POWERING) then -- only writtable when not set by generic
									csr.paracitic_pw				<= avs_ctrl_writedata(mmap.csr_w_1.paracitic_pw'range)(mmap.csr_w_1.paracitic_pw'low);
								end if;
								csr.usewire_id					<= avs_ctrl_writedata(mmap.csr_w_1.usewire_id'range)(mmap.csr_w_1.usewire_id'low);
								if (check_list.result = '0') then -- validate input range 
									csr.tot_bytes					<= to_integer(unsigned(avs_ctrl_writedata(mmap.csr_w_1.tot_bytes'range)));
									csr.wire_id						<= to_integer(unsigned(avs_ctrl_writedata(mmap.csr_w_1.wire_id'range)));
								else
									csr.error.out_of_range			<= '1';
								end if;
							end if;
						when 2 => -- flush the fifo
							-- TODO: add flushing logic, so far user could also flush by issuing empty command.
						when 4 => -- write to the tx fifo (bypassing the tx interface)
							if (interface_hub.tx_wrreq = '0') then 
								if (interface_hub.write_one_done = '0') then
									interface_hub.tx_wrreq			<= '1';
									interface_hub.write_one_done	<= '1';
								end if;
								interface_hub.tx_data	<= avs_ctrl_writedata(tx_fifo.data'high downto 0); -- ch + data
								avs_ctrl_waitrequest	<= '1';
							else
								interface_hub.tx_wrreq	<= '0';
								avs_ctrl_waitrequest	<= '0';
							end if;
						when others =>
							null;
					end case;
				else -- routine pipe handler
					-- +-------------------------------------------------------------------------------------------+
					-- | Input        :    csr.commit                                                              |
					-- | ========================================================================================= |
					-- | Routine type :    Inter-process Communication (IPC)                                       |
					-- | Routine name :    pipe_handler (parent)                                                   |
					-- |                                                                                           |
					-- | Direction    :    (**parent**) interface_hub <==  (child) tx_engine                       |
					-- | Pipe name    :    "tx"                                                                    |
					-- | Pipe signals :    'start` 'done`                                                          | 
					-- | ========================================================================================= |
					-- | Output       :    csr.busy                                                                |
					-- +-------------------------------------------------------------------------------------------+
					-- routine_ipc_pipe_handler_parent
					case interface_hub.pipe_handler is 
						when IDLE => -- listen on the csr register change
							if (csr.commit = '1') then 
								if (csr.direction = '1') then -- this is tx command
									interface_hub.pipe_handler				<= TX_ACK;
									pipe.tx.start							<= '1';  
								else 
									interface_hub.pipe_handler				<= RX_ACK;
									pipe.rx.start							<= '1'; 
								end if;
								csr.busy							<= '1'; -- unset the finish marker, so polling is valid
								-- NOTE: during handshaking, user may assert commit for a new write (ignored), and the descriptor cannot be set (protected).
							end if;
						when TX_ACK => -- hanshake on the pipe
							if (pipe.tx.start = '1' and pipe.tx.done = '0') then 
								-- wait for child
							elsif (pipe.tx.start = '1' and pipe.tx.done = '1') then 
								pipe.tx.start 							<= '0';
							elsif (pipe.tx.start = '0' and pipe.tx.done = '1') then 
								-- wait for child to ack
							else -- handshake ok, done, some modification of the csr
								csr.busy								<= '0'; -- mark the job is ACK
								csr.commit								<= '0'; -- unset the commit, ready for a new commit
								interface_hub.pipe_handler				<= IDLE; -- go to idle and ready for another csr change
								ins_complete_irq						<= '1'; -- raise irq to inform completion 
							end if;
						when RX_ACK => 
							if (pipe.rx.start = '1' and pipe.rx.done = '0') then 
								-- wait for child
							elsif (pipe.rx.start = '1' and pipe.rx.done = '1') then 
								pipe.rx.start 							<= '0';
							elsif (pipe.rx.start = '0' and pipe.rx.done = '1') then 
								-- wait for child to ack
							else -- handshake ok, done, some modification of the csr
								csr.busy								<= '0'; -- mark the job is ACK
								csr.commit								<= '0'; -- unset the commit, ready for a new commit
								interface_hub.pipe_handler				<= IDLE; -- go to idle and ready for another csr change
								ins_complete_irq						<= '1';
							end if;
							
						when others => 
							null;
					end case;
					
					-- reset signals for itself 
					interface_hub.read_one_done			<= '0';
					interface_hub.write_one_done		<= '0';
					interface_hub.tx_wrreq				<= '0';
					interface_hub.rx_rdreq				<= '0';
					if (DEBUG_LV > 0) then 
						interface_hub.tx_data				<= (others => '0');
					end if;
					-- routine to latch other signals
					csr.error.init_fail					<= tx_engine.error_init_fail;
				end if;
				
			end if;
		end if;
	end process;
	
	proc_interface_hub_comb : process (all)
	begin
		-- default
		rx_fifo.rdreq		<= '0';
		tx_fifo.data		<= (others => '0');
		tx_fifo.wrreq		<= '0';
		aso_rx_valid		<= '0';
		aso_rx_data			<= (others => '0');
		aso_rx_channel		<= (others => '0');
		asi_tx_ready		<= '0'; -- disable tx port during memory-mapped access -- TODO: debug this corner case when switching

		-- resolve the contention 
		if (avs_ctrl_read = '1') then 
			rx_fifo.rdreq		<= interface_hub.rx_rdreq; -- wire connection to a register
		elsif (avs_ctrl_write = '1') then 
			tx_fifo.wrreq		<= interface_hub.tx_wrreq; -- wire connection to a register
			tx_fifo.data		<= interface_hub.tx_data;
		else
			-- routine to avst tx port
			-- write to tx fifo and input through avst tx port
			if (asi_tx_valid = '1' and tx_fifo.full /= '1') then 
				tx_fifo.wrreq	<= '1';
				tx_fifo.data(asi_tx_data'high downto 0)		<= asi_tx_data;
				tx_fifo.data(asi_tx_channel'high+asi_tx_data'high+1 downto asi_tx_data'high+1)	<= asi_tx_channel;
			else
				tx_fifo.wrreq	<= '0';
			end if;
			
			if (tx_fifo.full /= '1') then 
				asi_tx_ready	<= '1'; -- drive ready when not full
			else
				asi_tx_ready	<= '0';
			end if;
			
			if (rx_fifo.empty /= '1') then 
				aso_rx_valid	<= '1'; -- pull high if not empty
			else
				aso_rx_valid	<= '0';
			end if;
			
			-- routine to avst rx port
			-- read from rx fifo and output through avst rx port 
			if (aso_rx_ready = '1' and rx_fifo.empty = '0') then -- direct comb connection
				rx_fifo.rdreq	<= '1'; -- read fifo
				aso_rx_data		<= rx_fifo.q(aso_rx_data'high downto 0); 
				aso_rx_channel	<= rx_fifo.q(aso_rx_channel'high+aso_rx_data'high+1 downto aso_rx_data'high+1);
			else 
				rx_fifo.rdreq	<= '0';
				aso_rx_valid	<= '0';
			end if;
		end if;
	
	end process;
	

	
	-- --------------------------------
	-- tx_engine
	-- --------------------------------
	proc_tx_engine : process (csi_clock_clk,rsi_reset_reset) 
	begin
		if rising_edge(csi_clock_clk) then 
			if (rsi_reset_reset = '1') then 
				tx_engine.flow			<= RESET;
			else 
				-- +-------------------------------------------------------------------------------------------+
				-- | Input        :    [pipe_handler] 'tx_engine.go` =>                                        |
				-- | ========================================================================================= |
				-- | Routine type :    state machine (FSM)                                                     |
				-- | Routine name :    tx_flow                                                                 |
				-- |                                                                                           | 
				-- | Description  :    Controls the precise timing of master tx for a bit, repeat this process |
				-- |			       for the whole symbol (byte) until finish.                               | 
				-- |                   Initiated by the tx_pipe, then send finish signal to tx_pipe.           |
				-- | ========================================================================================= |
				-- | Output       :    => [bidir_hal] '(array) sense_bidir_io_group`                           |
				-- +-------------------------------------------------------------------------------------------+
				-- routine_fsm_tx_flow 
				case tx_engine.flow is
					when IDLE =>
						if (pipe.tx.start = '1') then -- listen to the pipe child side
							tx_engine.flow			<= LOAD_TX_DATA;
						end if;
					when LOAD_TX_DATA => -- read the fifo and latch a symbol (byte), 2 cycles
						if (tx_fifo.rdreq = '0') then 
							if (tx_fifo.empty = '1') then -- danger, rx fifo empty (underflow), escape
								tx_engine.flow				<= ACK;
								tx_engine.error_fifo_empty	<= '1';
							else -- rx fifo is not empty, we continue
								tx_fifo.rdreq				<= '1';
								tx_engine.error_fifo_empty	<= '0'; -- clear the fifo flag
							end if;
						elsif (tx_fifo.rdreq = '1') then
							if (csr.init = '0') then  -- skip init pulse or not
								tx_engine.flow				<= SEND_BIT;
							else
								tx_engine.flow				<= SEND_INIT;
							end if;
							tx_fifo.rdreq				<= '0';
							-- channel
							if (csr.usewire_id = '1') then 
								tx_engine.wire_id			<= csr.wire_id;
							else -- use avst channel to select dq
								tx_engine.wire_id			<= to_integer(unsigned(tx_fifo.q(tx_fifo.q'high downto AVST_DATA_WIDTH))); -- checked by maxChannel
							end if;
							-- data
							tx_engine.tx_data			<= tx_fifo.q(AVST_DATA_WIDTH-1 downto 0);
						end if; 
						-- TODO: add fifo underflow alert
					when SEND_INIT =>
						case tx_engine.init_timing is
							when MASTER_TX_RESET =>
								tx_engine.dq(tx_engine.wire_id)			<= PULL_LOW;
								tx_engine.slow_timer_on					<= '1'; -- start timer, so this timing state is moving forward
							when MASTER_RELEASE =>
								tx_engine.dq(tx_engine.wire_id)			<= HIGH_Z;
								tx_engine.error_init_fail				<= '1'; -- set the error flag, so by default the slave is not present
							when MASTER_SENSE_PRESENCE =>
								tx_engine.dq(tx_engine.wire_id)			<= HIGH_Z;
								if (coe_sense_dq_in(tx_engine.wire_id) = '0') then 
									tx_engine.error_init_fail			<= '0'; -- clear error
								end if;
							when MASTER_EVAL => -- only 1 cycle
								tx_engine.slow_timer_on								<= '0'; -- stop timer and reset it
								-- depending on if there is an error in the init_timing, go to next state
								if (tx_engine.error_init_fail = '1' or csr.tot_bytes = 0) then -- failed or empty cmd 
									tx_engine.flow								<= ACK;
								else -- if an error, skip this tx byte, go to last state and report error 
									tx_engine.flow								<= SEND_BIT;
								end if;
								-- restore the idle state of the dq line
								if (csr.paracitic_pw = '1') then
									tx_engine.dq(tx_engine.wire_id)			<= PULL_HIGH;
								else 
									tx_engine.dq(tx_engine.wire_id)			<= HIGH_Z;
								end if;
							when others =>
								null;
						end case;
					when SEND_BIT => -- send a full bit with detailed timing
						case tx_engine.bit_timing is 
							when MASTER_PULL_LOW => 
								tx_engine.dq(tx_engine.wire_id)				<= PULL_LOW;
								tx_engine.slow_timer_on							<= '1'; -- start timer
							when MASTER_SEND_BIT =>
								if (tx_engine.tx_data(tx_engine.bit_cnt) = '1') then
									tx_engine.dq(tx_engine.wire_id)			<= PULL_HIGH;
								else
									tx_engine.dq(tx_engine.wire_id)			<= PULL_LOW;
								end if;
							when MASTER_IDLE => 
								if (tx_engine.updated = '0') then 
									tx_engine.bit_cnt							<= tx_engine.bit_cnt + 1;
									tx_engine.updated							<= '1';
								end if;
								-- restore the idle state of the dq line
								if (csr.paracitic_pw = '1') then
									tx_engine.dq(tx_engine.wire_id)			<= PULL_HIGH;
								else 
									tx_engine.dq(tx_engine.wire_id)			<= HIGH_Z;
								end if;
							when MASTER_EVAL => -- only 1 cycle
								tx_engine.slow_timer_on					<= '0'; -- stop timer and reset it
								tx_engine.updated						<= '0'; -- reset for this bit
								if (tx_engine.bit_cnt = AVST_DATA_WIDTH) then -- end of one byte, incr byte count. default: 8
									tx_engine.bit_cnt						<= 0;
									tx_engine.byte_cnt						<= tx_engine.byte_cnt + 1;
									tx_engine.flow							<= EVAL;
									-- reset for this byte
									tx_engine.bit_cnt						<= 0;
								else -- cont. another bit
									-- as the timer is reset, bit_timing will move to starting point
								end if;
							when others =>
								null;
						end case;
					when EVAL =>
						if (tx_engine.byte_cnt = csr.tot_bytes) then -- finish the tx
							tx_engine.flow								<= ACK;
							tx_engine.byte_cnt							<= 0;
						else -- cont. another byte
							tx_engine.flow								<= LOAD_TX_DATA;
						end if; 
						
					when ACK => -- handshake on the pipe
						if (pipe.tx.start = '1' and pipe.tx.done = '0') then -- send to parent
							pipe.tx.done				<= '1';
						elsif (pipe.tx.start = '1' and pipe.tx.done = '1') then 
							-- wait for parent
						elsif (pipe.tx.start = '0' and pipe.tx.done = '1') then 
							pipe.tx.done				<= '0'; -- ack the handler 
						else -- handshake ok, done
							tx_engine.flow				<= IDLE; -- go to idle and ready for another tx command 
						end if;
					when RESET =>
						-- reset pipes
						pipe.tx.done					<= '0';
						-- reset local registers
						tx_engine.slow_timer_on			<= '0';
						tx_engine.bit_cnt				<= 0;
						tx_engine.byte_cnt				<= 0;
						tx_engine.tx_data				<= (others => '0');
						tx_engine.updated				<= '0';
						tx_engine.error_init_fail		<= '0';
						tx_engine.error_fifo_empty		<= '0';
						-- reset remote registers
						tx_fifo.rdreq					<= '0';
						-- export signals
						-- restore the idle state of the dq lines
						if (PARACITIC_POWERING) then
							tx_engine.dq			<= dq_rst_1;
						else 
							tx_engine.dq			<= dq_rst_0;
						end if;
						-- state transition prep.
						tx_engine.flow					<= IDLE; -- entering idle state upon release
						
					when others =>
				
				end case;
				
				-- +-------------------------------------------------------------------------------------------+
				-- | Input        :    [tx_flow] 'tx_engine.flow`, [slow_timer] 'slow_timer_cnt `=>            |
				-- | ========================================================================================= |
				-- | Routine type :    state machine control logic (fsm_next)                                  |
				-- | Routine name :    tx_flow_next                                                            |
				-- |                                                                                           | 
				-- | Description  :    Derive the next state of the tx_flow state machine sync to slow clock.  |
				-- | ========================================================================================= |
				-- | Output       :    => [tx_flow] 'tx_engine.init_timing`, 'tx_engine.bit_timing`            |
				-- +-------------------------------------------------------------------------------------------+
				-- timings as set by the generic parameters
				-- for init_timing
				if (tx_engine.flow = SEND_INIT) then 
					if (slow_timer_cnt_unsigned < MASTER_INIT_RESET_US_U) then 
						tx_engine.init_timing		<= MASTER_TX_RESET;
					elsif(slow_timer_cnt_unsigned = MASTER_INIT_RESET_US_U) then 
						tx_engine.init_timing		<= MASTER_RELEASE;
					elsif(slow_timer_cnt_unsigned = MASTER_INIT_RESET_US_U + MASTER_WAIT_PRESENCE_US_U) then 
						tx_engine.init_timing		<= MASTER_SENSE_PRESENCE;
					elsif (slow_timer_cnt_unsigned = MASTER_INIT_RESET_US_U + MASTER_WAIT_PRESENCE_US_U + MASTER_SAMPLE_PRESENCE_TIMEOUT_US_U) then -- timeout to detect slave pulse
						tx_engine.init_timing		<= MASTER_EVAL;
					end if;
					tx_engine.bit_timing			<= MASTER_PULL_LOW; -- starting point
				-- for bit_timing
				elsif (tx_engine.flow = SEND_BIT) then
					if (slow_timer_cnt_unsigned < TX_PULL_LOW_US_U) then
						tx_engine.bit_timing		<= MASTER_PULL_LOW;
					elsif (slow_timer_cnt_unsigned = TX_PULL_LOW_US_U) then
						tx_engine.bit_timing		<= MASTER_SEND_BIT;
					elsif (slow_timer_cnt_unsigned = TX_PULL_LOW_US_U + TX_SLOT_US_U) then 
						tx_engine.bit_timing		<= MASTER_IDLE;
					elsif (slow_timer_cnt_unsigned = TX_PULL_LOW_US_U + TX_SLOT_US_U + SLOTS_SEPERATION_US_U) then 
						tx_engine.bit_timing		<= MASTER_EVAL;
					end if;
					tx_engine.init_timing			<= MASTER_TX_RESET; -- starting point
				else -- during other state, pull the small timing state into default starting point
					tx_engine.init_timing			<= MASTER_TX_RESET; -- starting point
					tx_engine.bit_timing			<= MASTER_PULL_LOW; -- starting point
				end if;
				
			end if;
		end if;
	end process;
	
	
	-- ------------------------
	-- rx_engine
	-- ------------------------
	proc_rx_engine : process (csi_clock_clk,rsi_reset_reset)
	begin
		if rising_edge(csi_clock_clk) then 
			-- == sync reset ==
			if (rsi_reset_reset = '1') then
				rx_engine.flow		<= RESET;
			else 
				case rx_engine.flow is 
					when IDLE => 
						if (pipe.rx.start = '1') then 
							rx_engine.flow			<= EVAL_CMD;
						end if;
					when EVAL_CMD => 
						if (csr.tot_bytes = 0) then -- empty cmd (meaningless, maybe user wants to clear the rx_fifo?)
							rx_engine.flow			<= ACK;
						else
							rx_engine.flow			<= RECV_BIT;
						end if;
					when RECV_BIT =>
						case rx_engine.bit_timing is 
							when MASTER_PULL_LOW =>
								rx_engine.dq(csr.wire_id)				<= PULL_LOW;
								rx_engine.slow_timer_on					<= '1'; -- start timer
							when MASTER_RELEASE =>
								rx_engine.dq(csr.wire_id)				<= HIGH_Z;
							when MASTER_SAMPLE_BIT =>
								-- this sample is 1 us, so TODO: add debounce for the rx data
								rx_engine.dq(csr.wire_id)				<= HIGH_Z;
								-- get the 1-bit data from the dq line, if pull down by slave, then it is '0'. 
								rx_engine.rx_data(rx_engine.bit_cnt)	<= coe_sense_dq_in(csr.wire_id);
							when MASTER_IDLE =>
								-- restore the idle state of the dq line
								if (csr.paracitic_pw = '1') then
									rx_engine.dq(csr.wire_id)			<= PULL_HIGH;
								else 
									rx_engine.dq(csr.wire_id)			<= HIGH_Z;
								end if;
								if (rx_engine.updated = '0') then -- update the bit counter
									rx_engine.bit_cnt					<= rx_engine.bit_cnt + 1;
									rx_engine.updated					<= '1';
								end if;
							when MASTER_EVAL => -- only one cycle
								rx_engine.slow_timer_on							<= '0'; -- stop timer and reset it, so immediate go back
								rx_engine.updated								<= '0';
								if (rx_engine.bit_cnt = AVST_DATA_WIDTH) then -- end of one byte, incr byte count. default: 8
									rx_engine.bit_cnt							<= 0;
									rx_engine.byte_cnt							<= rx_engine.byte_cnt + 1;
									rx_engine.flow								<= STORE_RX_DATA; -- inform the later state to load data
									rx_engine.bit_cnt							<= 0;
								else -- cont. another bit
									-- as the timer is reset, bit_timing will move to starting point
								end if;
							when others =>
								null;
						end case;
					when STORE_RX_DATA => -- actually only store a symbol (byte)
						if (rx_fifo.wrreq = '0') then 
							-- fifo full protection
							if (rx_fifo.full = '1') then -- TODO: abort or continue?
								rx_engine.error_fifo_full	<= '1';
								rx_engine.flow				<= ACK; -- abort here, as the data maybe corrupted
							else 
								rx_engine.error_fifo_full	<= '0'; -- clear the error flag
								rx_fifo.wrreq				<= '1';
								rx_fifo.data				<= std_logic_vector(to_unsigned(csr.wire_id,AVST_CHANNEL_WIDTH)) & rx_engine.rx_data;
							end if;
						elsif (rx_fifo.wrreq = '1') then
							rx_fifo.wrreq				<= '0';
							if (rx_engine.byte_cnt = csr.tot_bytes) then 
								rx_engine.byte_cnt			<= 0;
								rx_engine.flow				<= ACK; -- exit
							else
								rx_engine.flow				<= RECV_BIT; -- continue with another byte
							end if;
						end if; 
						-- TODO: add fifo overflow alert
					when ACK => 
						if (pipe.rx.start = '1' and pipe.rx.done = '0') then -- send to parent
							pipe.rx.done				<= '1';
						elsif (pipe.rx.start = '1' and pipe.rx.done = '1') then 
							-- wait for parent
						elsif (pipe.rx.start = '0' and pipe.rx.done = '1') then 
							pipe.rx.done				<= '0'; -- ack the handler 
						else -- handshake ok, done
							rx_engine.flow				<= IDLE; -- go to idle and ready for another tx command 
						end if;
					when RESET =>
						-- reset pipes
						pipe.rx.done					<= '0';
						-- reset local registers
						rx_engine.updated				<= '0';
						rx_engine.slow_timer_on			<= '0';
						rx_engine.bit_cnt				<= 0;
						rx_engine.byte_cnt				<= 0;
						rx_engine.rx_data				<= (others => '0');
						rx_engine.error_fifo_full		<= '0';
						-- reset remote registers
						rx_fifo.wrreq					<= '0';
						rx_fifo.data					<= (others => '0');
						-- export signals
						-- restore the idle state of the dq lines
						if (PARACITIC_POWERING) then
							rx_engine.dq			<= dq_rst_1;
						else 
							rx_engine.dq			<= dq_rst_0;
						end if;
						-- state transition prep.
						rx_engine.flow						<= IDLE; -- entering idle state upon release
					when others =>
						null;
				end case;
			end if;	
			-- == no reset ==
			-- +-------------------------------------------------------------------------------------------+
			-- | Input        :    [rx_engine] 'rx_engine.flow`, [slow_timer] 'slow_timer_cnt `=>          |
			-- | ========================================================================================= |
			-- | Routine type :    state machine control logic (fsm_next)                                  |
			-- | Routine name :    rx_flow_next                                                            |
			-- |                                                                                           | 
			-- | Description  :    Derive the next state of the rx_engine state machine sync to slow clock.|
			-- | ========================================================================================= |
			-- | Output       :    => [rx_engine] 'rx_engine.bit_timing`                                   |
			-- +-------------------------------------------------------------------------------------------+
			if (rx_engine.flow = RECV_BIT) then 
				if (slow_timer_cnt_unsigned < RX_PULL_LOW_US_U) then 
					rx_engine.bit_timing		<= MASTER_PULL_LOW;
				elsif (slow_timer_cnt_unsigned = RX_PULL_LOW_US_U) then 
					rx_engine.bit_timing		<= MASTER_RELEASE;
				elsif (slow_timer_cnt_unsigned = RX_MASTER_SAMPLE_US_U) then 
					rx_engine.bit_timing		<= MASTER_SAMPLE_BIT;
				elsif (slow_timer_cnt_unsigned = RX_MASTER_SAMPLE_US_U+1) then 
					rx_engine.bit_timing		<= MASTER_IDLE;
				elsif (slow_timer_cnt_unsigned = RX_SLOT_US_U) then 
					rx_engine.bit_timing		<= MASTER_EVAL;
				end if;
			else -- default
				rx_engine.bit_timing			<= MASTER_PULL_LOW; -- starting point
			end if;
		end if;
	end process;
	
	
	
	-- -------------------------
	-- bidir_hal
	-- -------------------------
	gen_bidir_hal : for i in 0 to N_DQ_LINES-1 generate 
		-- +-------------------------------------------------------------------------------------------+
		-- | Input        :    [tx_engine] '(array) tx_engine.dq` =>                                   |
		-- |                   [rx_engine] '(array) rx_engine.dq` =>                                   |
		-- | ========================================================================================= |
		-- | Process type :    io abstraction (io)                                                     |
		-- | Process name :    (combinational) bidir_hal                                               |
		-- |                                                                                           |
		-- | Description  :    Hardware Abstraction Layer (HAL) of bi-directional IO port of the FPGA. |
		-- |                   Wrapping bi-dir IO into 3 states: during HIGH_Z, input is valid.        |
		-- | ========================================================================================= |
		-- | Output       :    => [*export*] '(array) coe_sense_dq_out`, `(array) coe_sense_dq_oe'     |
		-- +-------------------------------------------------------------------------------------------+
		proc_io_bidir_hal_comb : process (all)
		begin
			
			case sense_bidir_io_group(i) is -- bundling these two signals (output and enable)
				when PULL_HIGH => 
					coe_sense_dq_out(i)		<= '1';
					coe_sense_dq_oe(i)		<= '1';
				when PULL_LOW => 
					coe_sense_dq_out(i)		<= '0';
					coe_sense_dq_oe(i)		<= '1';
				when HIGH_Z => -- dq_in is valid here
					coe_sense_dq_out(i)		<= 'X'; -- don't care
					coe_sense_dq_oe(i)		<= '0';
				when others => 
					null;
			end case;
		end process;
	end generate gen_bidir_hal;
	
	proc_hal : process (all)
	begin
		-- simple arbiter
		if (rx_engine.flow = RECV_BIT) then 
			sense_bidir_io_group		<= rx_engine.dq;
		else
			sense_bidir_io_group		<= tx_engine.dq;
		end if;
	
	end process;
	

	
	
	
	
	-- ---------------------------
	-- (helper) range_checker
	-- ---------------------------
	-- wire conn.
	check_list.tot_bytes			<= to_integer(unsigned(avs_ctrl_writedata(mmap.csr_w_1.tot_bytes'range)));
	check_list.wire_id				<= to_integer(unsigned(avs_ctrl_writedata(mmap.csr_w_1.wire_id'range)));
	
	proc_helper_range_checker : process (all)
		variable out_of_range_error : std_logic;
	begin
		out_of_range_error		:= '0';
		
		if (check_list.tot_bytes > MAX_RXTX_BYTES) then 
			out_of_range_error		:= '1';
		end if;
		if (check_list.wire_id > N_DQ_LINES-1) then
			out_of_range_error		:= '1';
		end if;
		
		check_list.result			<= out_of_range_error;
	
	end process;


end architecture rtl;
















