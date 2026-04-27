-- File name: mutrig_ctrl.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Feb 7, 2024
-- Revision: 2.0 (added TSA (tth scan automation) as the co-processer) 
--		Date: Mar 7, 2024
-- =========
-- Description:	[MuTRiG Controller]
--				This IP consists of two major routines, which are descriped below. 
--				The two routines also controls multiple sub-routines. The IRQ will be sent to the routines, if they are both idle.
--				In order to prevent contention (multiple driver), there are OR-logic implemented to resolve this. 
--
--				[MuTRiG Configuration Controller (MCC)] 
-- 				Handles mutrig configuration scheme. Data will be loaded in the scratch-pad ram by SWB and MIDAS should write to CSR to start this routine.
--				Work flow: 
--				1) commands the data mover to move the 
--				cfg bitstream from scratch-pad RAM to asic delicated cfg-mem RAM. 
--				2) cfg writer use the data from the cfg-mem perform SPI write
--				[TODO] 3) The cfg writer also checks the readback data to validate the SPI transation.
--
--				[MuTRiG TSA]
--				Automatically perform tth scan of the selected MuTRiG. MIDAS should write to CSR to start this routine.
--		======= Note!!! The TTH scan use the data from the last configuration as a template when incrementing the TTH value. So, you should at least config all MuTRiGs once.
--				Work flow: 1) Modify Content in the CFG RAM. 2) Config through the Config Writer 3) Collect rate from the counters and store it to result RAM

-- Ports: 
--			avmm(host) to qsys ram, 
--			avmm(agent) for csr. write to FC04(opcode)/FC05(data loc) is treated as the IRQ.
--			
--							...
-- 
-- Block Diagram: 
--                                                       +--+-------------+--+                                                                                                 
--                                                       |  | AVMM        |  |                                                                                                 
--                                                       |  | Agent       |  |                                                                                                 
--                                                       |  +-------------+  |                                                                                                 
--                                                       |                   |                                                                                                 
--                                                       |  Control and      |                                                                                                 
--                                                       |  Status Register  |                                                                                                 
--                                                       +-------+-----------+                                                                                                 
--                                                               |                                                                                                             
--                                                               |                                                                                                             
--                                                               | IRQ                                                                                                         
--                                                               |                                                                                                             
--                                                               v                                                                                                             
--                                                      +--------------------+                                                                                                 
--                                                      | Intruction         |                                                                                                 
--                                                      | Intepretor         |                                                                                                 
--                                                      +--------+-----------+                                                                                                 
--                                                             ^ |                                                                                                             
--                                                             | |                                                                                                             
--                                                             | | RPC handshakes                                                                                              
--                                                             | |                                                                                                             
--                                                             | |                                                                                                             
--                                                             | v                                                                                                             
--                                                    +--------+--------------+                                                                                                
--                                                    |                       |                                                                     |                          
--                                                    |   RPC contention      |                                                                     |                          
--                                                    +---+-----------------+-+                                                                     |                          
--                                                      ^ |               ^ |                                                                       |                          
--                                      RPC handshakes  | v               | v  RPC handshakes                                                       |                          
--                                      +---------------+----+        +---+----------------------+         +-----------------------+                |  +----------------------+
--                                      |                    |        |                          |         |                       |                |  |                      |
--                                      |   TSA (T-Threshold |        | MCC (Configuration       |Mover    |              +--------+                |  |                      |
--                                      |   Scan Automation) |        | Controller)              |Handshake|  Data Mover  | AVMM   |                |  | Scrach-pad RAM       |
--                                      |                    |        |                          |<--------+ (DMA Engine) | Host   +----------------+->|                      |
--                                      |                    |        |                          |-------->|              |        |                |  |                      |
--                                      |                    |        |                          |         |              +--------+                |  |                      |
--                                      |                    |        |                          |         |                       |                |  |                      |
--                                      +--+---------------+-+        +-------------------+------+         +-----------------------+                |  +----------------------+
--                                       ^ |             ^ |                            ^ |Config Writer                                            |                          
--                            Monitor    | |             | |    Config Writer           | v Handshakes                                              |                          
--                            Handshakes | v             | |    Handshakes       +------+-----+                                                     |                          
--              +------------------------+--+            | <--------------------^| CFG        |                                                     |                          
--              |    Rate Monitor           |            <-+---------------------+ contention |                                                     |                          
--              |                           |  Modifier  | |                     +----+---+---+                                                     |                          
--              |    +-------------+        |  Handshakes+-+---------------+          |   |CDC FIFO                 cclk (ctrl clock)               |                          
--              |    | Result      |        |           |                  |     +++++|+++|+++++++++++++++++++++++++++++++++++++++++++              |                          
--              |    | RAM         |        |           | Pattern          |     +    |   |                         sclk (spi clock) +              |                          
--              |    |             |        |           | Modifier         |     +    +---+                                          +              |                          
--              |    +-------------+        |           |                  |     +           +---------------------+                 +              |                          
--              |                ^          |           |                  |     +           |                     |                 +              |                          
--              |                | +------+ |           |                  |     +           |  Config Writer      |                 +              |                          
--              |  +------+      | |Timer | |           +---------------+--+     +           |                     |                 +              |                          
--              |  |Sclr  |      | |      | |            ^              | ^      +           |                     |                 +              |                          
--              |  |Issuer|      | +------+ |            |              v |      +           |                     |                 +              |                          
--              |  |      |      |          |          +-+------+ +-------++     +           |                     |                 +              |                          
--              |  |      |  +---+-----+    |          |        | |cntntion|<----------------+                     |                 +              |                          
--              |  +---+--+  | AVMM    |    |          | MOD    | +--------+     +           +---------------------+                 +              |                          
--              |      |     | Host    |    |          | RAM    | |        |     +++++++++++++++++++++++++++++++++++++++++++++++++++++                                         
--              +------+-----+-----+---+----+          |        | | CFG    |                           | ^                                                                     
--                     |           |                   |        | | RAM    |                           | |                                                                     
--                     |           |                   |        | |        |               ------------+-+----------------                                                     
--                     |           |                   +--------+ +--------+                           | | SPI                                                                 
--                     |           |                                                               +---v-+---+                                                                 
--                     |           |                                                               |         |                                                                 
--                     |           |                                                               | MuTRiG  |                                                                 
-- --------------------+-----------+---------------------------------------------------            |         |                                                                 
--                     |           |                                                               |         |                                                                 
--                     |           v                                                               |         |                                                                 
--                     |      +---------+                                                          |         |                                                                 
--                     |      |         |                                                          +---------+ x8                                                              
--                     +----->| Channel |                                                                                                                                      
--                            |  Rate   |                                                                                                                                      
--                            | Counters|                                                                                                                                      
--                            |         |                                                                                                                                      
--                            |         |                                                                                                                                      
--                            +---------+x32                                                                                                                                   

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

entity mutrig_ctrl is 
	generic( 
		N_MUTRIG											: natural := 4;
		-- BANK_INDEX										: natural := 0; -- it supports 8 asic in one controller, no need to seperate banks
		INTENDED_MUTRIG_VERSION								: string := "MuTRiG 3";
		MUTRIG_CFG_LENGTH_BIT								: natural := 2662; -- mutrig3 is 2662; mutrig2 is 2719; mutrig1 is 2358
		CPOL												: natural := 0;
		CPHA												: natural := 0;
		CLK_FREQUENCY										: natural range 0 to 10**9:= 156250000;
		COUNTER_MM_ADDR_OFFSET_WORD							: natural := 16#8000#;
		DEBUG												: natural := 1
	);
	port(
		-- clock and reset interface 
		i_clk								: std_logic; -- ideally should be 156.25MHz, you must also set the generic CLK_FREQUENCY to match it.
		i_rst								: std_logic; -- this reset is async assert, sync release to i_clk.
		
		i_clk_spi							: std_logic; -- use 40MHz clock
		i_rst_spi							: std_logic; -- reset for 40MHz clock
		-- TODO: add another dedicated spi reset
	
		-- [Avalom Memory-Mapped Master] exclusive access to scratchpad of mutrig config
		avm_schpad_address					: out std_logic_vector(9 downto 0); -- word addressing: (byte 0x0000 to 0x03ff)
		avm_schpad_read						: out std_logic;
		avm_schpad_readdata					: in  std_logic_vector(31 downto 0);
		avm_schpad_response					: in  std_logic_vector(1 downto 0);
		avm_schpad_waitrequest				: in  std_logic;
		avm_schpad_readdatavalid			: in  std_logic;
		avm_schpad_burstcount				: out std_logic_vector(8 downto 0); -- max burst 256 words (9-bit burstcount)
		
		-- [Avalon Memory-Mapped Slave] for access to its internal control and status register
		-- you must manually configure the qsys with base address of 0x0000FC04 (x4 for byte address)
		avs_csr_address						: in  std_logic_vector(1 downto 0); -- word addressing
		avs_csr_read						: in  std_logic;
		avs_csr_readdata					: out std_logic_vector(31 downto 0);
		avs_csr_write						: in  std_logic;
		avs_csr_writedata					: in  std_logic_vector(31 downto 0);
		avs_csr_waitrequest					: out std_logic;
		avs_csr_response					: out std_logic_vector(1 downto 0);
		
		-- [Avalon Memory-Mapped Master] exclusive access to counter values
		avm_cnt_address 					: out std_logic_vector(15 downto 0);-- 32*8=256 counters, so address bit should be at least 8 bit, if they are closly packed
		avm_cnt_read						: out std_logic;
		avm_cnt_readdata					: in  std_logic_vector(31 downto 0);
		avm_cnt_waitrequest					: in  std_logic;
		avm_cnt_burstcount 					: out std_logic_vector(8 downto 0); -- max burst is 2^<burstcount-1>=2^8=256
		avm_cnt_readdatavalid				: in  std_logic;
		avm_cnt_response					: in  std_logic_vector(1 downto 0);
		avm_cnt_flush						: out std_logic;
		
		-- [Avalon Memory-Mapped Slave] for access to the result ram
		avs_scanresult_address				: in  std_logic_vector(13 downto 0); -- 14 bit
		avs_scanresult_read					: in  std_logic;
		avs_scanresult_readdata				: out std_logic_vector(31 downto 0);
		avs_scanresult_waitrequest			: out std_logic;
		
		-- [conduit] counter control port -- TODO: CDC! use conduit or reset request?
		o_sclr_req							: out std_logic; 
		
		-- [conduit] spi_export2top
		spi_miso					: in  std_logic;
		spi_mosi					: out std_logic;
		spi_sclk					: out std_logic;
		spi_ssn						: out std_logic_vector(7 downto 0)
		
	);
end entity mutrig_ctrl;

-- Control and Status Registers map
-- 0x0	WO			opcode for the mutrig cfg
-- 0x1  RW			offset in the scratch-pad for the cfg bitstream


architecture rtl of mutrig_ctrl is 
	constant NCOUNTER_MM_ADDR_OFFSET_WORD	: std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(COUNTER_MM_ADDR_OFFSET_WORD,avm_cnt_address'length));
	constant RSP_GOOD			: std_logic_vector(1 downto 0) := "00";
	constant RSP_DECODEERR		: std_logic_vector(1 downto 0) := "10";
	constant RSP_SLVERR			: std_logic_vector(1 downto 0) := "11";
	constant CFG_MEM_PARTITION_SIZE_WORD			: integer := 128;
	constant CMD_MUTRIG_ASIC_CFG					: std_logic_vector(11 downto 0) := x"011";
	constant CMD_MUTRIG_ASIC_TTH_SCAN				: std_logic_vector(11 downto 0) := x"012"; -- TODO: new command!!! update this in Mutrig_FEB.cpp
	constant CMD_MUTRIG_ASIC_TTH_SCAN_ALL			: std_logic_vector(11 downto 0) := x"014"; -- TODO: new command!!! update this in Mutrig_FEB.cpp
	-- this does not matter with the physical configuration, it just decoder nicer on scope with byte boundary
	constant MUTRIG_CFG_LENGTH_BIT_ROUNDUP	 		: integer 		:= integer(ceil(real(MUTRIG_CFG_LENGTH_BIT)/32.0)*32.0); 
	
	-- calculate pattern bit sub-field
	-- header | ch x32 | tdc | footer
	constant CFG_HEADER_LENGTH						: integer := 34; -- bit
	constant CFG_SINGLE_CH_LENGTH					: integer := 71; -- bit
	constant CFG_SINGLE_CH_TTH_OFFSET				: integer := 24; -- bit
	constant CFG_N_CH								: integer := 32;
	constant CFG_TTH_SETTING_LENGTH					: integer := 6; -- bit
	
	-- constant integer arrays 
	type array_2d_t is array(0 to CFG_N_CH-1) of integer;
	signal derived_tth_location						: array_2d_t;
	signal derived_tth_location_end					: array_2d_t;
	signal derived_tth_location_word				: array_2d_t;
	signal derived_tth_location_word_end			: array_2d_t;
	signal derived_tth_read_word_cnt				: array_2d_t;
	signal derived_tth_bit_mod						: array_2d_t;
	signal derived_tth_bit_mod_end					: array_2d_t;
	signal derived_tth_bit_mod_enduf				: array_2d_t;
	
	type array_2d_mutrig_t is array (0 to N_MUTRIG-1) of integer;
	signal asic_cfg_bit_offset						: array_2d_mutrig_t;
	
	signal sclk, cclk	: std_logic;
	
	type csr_t is record
		opcode		: std_logic_vector(31 downto 0);
		offset		: std_logic_vector(31 downto 0);
		written		: std_logic;
		status		: std_logic_vector(15 downto 0);
        monitor_seconds : unsigned(15 downto 0);
	end record;
	signal csr 		: csr_t;
	
	type rpc_t is record
		command		: std_logic_vector(11 downto 0);
		asic_id		: std_logic_vector(3 downto 0);
		cfglen		: std_logic_vector(15 downto 0);
		start		: std_logic;
		done		: std_logic;
		done_0		: std_logic;
		done_1		: std_logic;
	end record;
	signal rpc		: rpc_t;
	signal srpc		: rpc_t;
	
	type controller_exception_t is record
		error			: std_logic;
		errcode			: std_logic_vector(2 downto 0);
	end record;
	signal controller_exception	: controller_exception_t;
	
	type config_state_t is record
		done			: std_logic;
		err				: std_logic;
		errinfo			: std_logic_vector(1 downto 0);
	end record;
	signal sconfig_state		: config_state_t; -- [spi clock domain]
	signal sconfig_state_d1		: config_state_t; -- [spi clock domaim]
	signal cconfig_state		: config_state_t; -- [ctrl clock domain]
	
	signal controller_busy			: std_logic;
	signal controller_busy_0		: std_logic;
	signal controller_busy_1		: std_logic;
	signal ccfg_writer_start_0		: std_logic; -- [ctrl clock domain] -- thread for cfg ctrl
	signal ccfg_writer_start_1		: std_logic; -- [ctrl clock domain] -- thread for tsa 
	signal ccfg_writer_start		: std_logic; -- [ctrl clock domain]
	signal ccfg_writer_start_d1		: std_logic; -- [ctrl clock domain]
	signal scfg_writer_start		: std_logic; -- [spi clock domain]
	signal move_data_done			: std_logic; -- [ctrl clock domain]
	signal data_mover_start			: std_logic; -- [...same as above...]
	signal data_mover_done			: std_logic;
	signal irq_start				: std_logic;
	
	type csr_state_t 	is (IDLE,READ_CSR,WRITE_CSR,CONFLICT);
	signal csr_state	: csr_state_t;
	
	type cfg_controller_state_t is (IDLE,EXCEPTION,MOVE_DATA,WRITE_CFG);
	signal cfg_controller_state			: cfg_controller_state_t;
	signal cfg_controller_state_next	: cfg_controller_state_t;
	
	type mover_avmm_rd_flow_t is (S1,S2,S3,S4,RESET,IDLE);
	signal mover_avmm_rd_flow			: mover_avmm_rd_flow_t;
	
	type cfg_writer_flow_t is (IDLE,INIT,WRITING,FINISHING,PAUSE);
	signal cfg_writer_flow				: cfg_writer_flow_t;
	
	type cfg_checker_flow_t is (IDLE,RESET,CHECKING,REPORTING);
	signal cfg_checker_flow				: cfg_checker_flow_t;
	
	type spi_writing_flow_t is (CLK_LOW,CLK_HIGH);
	signal spi_writing_flow				: spi_writing_flow_t;
	signal spi_checking_flow			: spi_writing_flow_t;
	
	type tth_scan_automation_state_t is (IDLE,MOD_TTH,CFG,MONITOR_RATE,EVALUATION);
	signal tth_scan_automation_state	: tth_scan_automation_state_t;
	
	type modifier_flow_t is (IDLE,READ32,MODIFY,WRITE32);
	signal modifier_flow				: modifier_flow_t;
	
	type monitor_flow_t is (IDLE,SCLR_COUNTERS,WAIT_FOR_COUNTERS,READ_RESULTS,FINISHING);
	signal monitor_flow			: monitor_flow_t;
	
	type avm2counter_flow_t is (POSTING_CMD,RECEIVING_READDATA,FINISHED);
	signal avm2counter_flow		: avm2counter_flow_t;
	
	signal spi_wr_bit_cnt		: std_logic_vector(15 downto 0);
	signal write_1st_done		: std_logic;
	signal write_2nd_done		: std_logic;

	component alt_dpram
	PORT
	(
		data			: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (13 DOWNTO 0);
		rdclock			: IN STD_LOGIC ;
		wraddress		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
		wrclock			: IN STD_LOGIC  := '1';
		wren			: IN STD_LOGIC  := '0';
		q				: OUT STD_LOGIC_VECTOR (0 DOWNTO 0)
	);
	end component;

	
	component alt_dcfifo_cdc
	PORT
	(
		aclr		: IN STD_LOGIC  := '0';
		data		: IN STD_LOGIC_VECTOR (4 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (4 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		rdfull		: OUT STD_LOGIC ;
		wrempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC 
	);
	end component;
	
	signal flag_spi2ctrl_din 		: std_logic_vector(4 downto 0);
	signal flag_spi2ctrl_wen 		: std_logic;
	signal flag_spi2ctrl_dout 		: std_logic_vector(4 downto 0);
	signal flag_spi2ctrl_rack		: std_logic;
	signal flag_spi2ctrl_wrempty	: std_logic;
	signal flag_spi2ctrl_rdempty	: std_logic;
	signal asic_id_update_req		: std_logic;
	signal asic_id_reset_req		: std_logic;
	
	signal flag_ctrl2spi_din 		: std_logic_vector(4 downto 0);
	signal flag_ctrl2spi_wen 		: std_logic;
	signal flag_ctrl2spi_dout 		: std_logic_vector(4 downto 0);
	signal flag_ctrl2spi_rack		: std_logic;
	signal flag_ctrl2spi_wrempty	: std_logic;
	signal flag_ctrl2spi_rdempty	: std_logic;
	
	signal cfg_mem_dinA			: std_logic_vector(31 downto 0);
	--signal cfg_mem_dinB		: std_logic;
	signal cfg_mem_addrA		: std_logic_vector(8 downto 0);
	signal cfg_mem_addrB		: std_logic_vector(13 downto 0);
	signal cfg_mem_wr_enA		: std_logic;
	--signal cfg_mem_wr_enB		: std_logic;
	--signal cfg_mem_doutA		: std_logic_vector(31 downto 0);
	signal cfg_mem_doutB		: std_logic;
	
	signal mover_trans_cnt	: std_logic_vector(7 downto 0);
	
	signal mod_mem_rdaddr,mod_mem_rdaddr_d1,mod_mem_wraddr		: std_logic_vector(cfg_mem_addrA'length -1 downto 0);
	signal mod_mem_din,mod_mem_dout				: std_logic_vector(31 downto 0);
	signal mod_mem_we							: std_logic;
	
	signal modifier_start,modifier_done			: std_logic;
	signal modifier_writeback_done				: std_logic;
	signal current_modifier_ch					: natural range 0 to 31; 
	signal modifier_read_word_cnt				: natural range 0 to 2;
	type original_data_t is array(0 to 1) of std_logic_vector(31 downto 0);
	signal original_data						: original_data_t;
	signal mod_mem_dout_ready					: std_logic;
	signal modifier_mod_done					: std_logic;
	
	signal current_tth,current_tth_flip			: std_logic_vector(5 downto 0);
	signal modifier_wr_back_data				: std_logic_vector(31 downto 0);
	signal modifier_wr_back_addr				: std_logic_vector(8 downto 0);
	signal modifier_wr_back_valid				: std_logic;
	signal modifier_wr_back_en					: std_logic;
	signal updated_ch							: std_logic;
	signal wb_word_cnt							: natural range 0 to 1;
	signal monitor_start, monitor_done			: std_logic;
	signal cmd_posted							: std_logic;
	signal monitor_asic_cnt						: natural range 0 to 15;
	signal cnt_ctrl_csr_reset_interval			: integer := 1000; -- ms -- TODO: allow to read back dynamically, so the user can set the monitor time
	signal sclr_timer_cnt						: natural range 0 to 5;
	signal wait_timer_cnt						: std_logic_vector(47 downto 0);
	signal monitor_read_word_cnt				: natural range 0 to 32*N_MUTRIG-1;
	signal monitor_tot_channel_cnt				: natural range 0 to 32*N_MUTRIG-1;
	signal slaveresponse_timeout_cnt			: natural range 0 to 500;
	signal slaveresponse_timeout				: std_logic;
	
	signal result_mem_rdaddr,result_mem_wraddr		: std_logic_vector(integer(ceil(log2(real(32*64*N_MUTRIG))))-1 downto 0);
	signal result_mem_din,result_mem_dout			: std_logic_vector(31 downto 0);
	signal result_mem_we							: std_logic;				
	signal avs_scanresult_address_d1				: std_logic_vector(avs_scanresult_address'length-1 downto 0); -- 14 bit
	signal result_ram_dout_valid					: std_logic;
	
	signal original_data_modified					: std_logic_vector(31 downto 0);
	signal wr_bk_mask_lsb_loc						: std_logic_vector(5 downto 0); -- signed -5 to 31
	signal modifier_write_word_cnt					: natural range 0 to 1;
	signal monitor_wait_cycles 						: std_logic_vector(31 downto 0) := conv_std_logic_vector(CLK_FREQUENCY,32);
    
    -- multiplier
	constant lpm_mult_pipe_latency		: natural := 10;
	component alt_lpm_mult
	PORT
	(
		clock		: IN STD_LOGIC ;
		dataa		: IN STD_LOGIC_VECTOR (19 DOWNTO 0);
		datab		: IN STD_LOGIC_VECTOR (19 DOWNTO 0);
		result		: OUT STD_LOGIC_VECTOR (39 DOWNTO 0)
	);
	end component;
	
	
begin

	gen_derived_tth_location : for i in 0 to CFG_N_CH-1 generate 
	-- derive the constants for the tth locations in cfg mem (counts from 0)
		derived_tth_location(i)				<= CFG_HEADER_LENGTH + CFG_SINGLE_CH_TTH_OFFSET + CFG_SINGLE_CH_LENGTH*i; -- 58, 129, 200 ...
		derived_tth_location_end(i)			<= CFG_HEADER_LENGTH + CFG_SINGLE_CH_TTH_OFFSET + CFG_SINGLE_CH_LENGTH*i + 5; -- 64 ...
		derived_tth_location_word(i)		<= ((derived_tth_location(i)) / 32); -- 58=>1 64=>1 65=>2 ...
		derived_tth_location_word_end(i)	<= ((derived_tth_location_end(i)) / 32); -- 64=>1 ...
		derived_tth_read_word_cnt(i)		<= derived_tth_location_word_end(i) - derived_tth_location_word(i) + 1; -- 1 or 2 words
		derived_tth_bit_mod(i)				<= ((derived_tth_location(i)) mod 32); -- (58-1)/32 = 1==25, so result is bit 25
		derived_tth_bit_mod_end(i)			<= (derived_tth_bit_mod(i)+5) mod 32; --(26+5)/32 = 0==30, so the result is bit 30
		derived_tth_bit_mod_enduf(i)		<= (derived_tth_bit_mod_end(i) - 5); -- for example, uf 1 bit, the lsb is -5 (only valid with modify_word>1)
	end generate gen_derived_tth_location;
	
	gen_constant_mutrig : for i in 0 to N_MUTRIG-1 generate
		asic_cfg_bit_offset(i)				<= i*CFG_MEM_PARTITION_SIZE_WORD*32;
	end generate gen_constant_mutrig;
	
	--=============================================================================================
	--   _____ _      ____   _____ _  __                  _   _____  ______  _____ ______ _______ 
	--  / ____| |    / __ \ / ____| |/ /                 | | |  __ \|  ____|/ ____|  ____|__   __|
	-- | |    | |   | |  | | |    | ' /    __ _ _ __   __| | | |__) | |__  | (___ | |__     | |   
	-- | |    | |   | |  | | |    |  <    / _` | '_ \ / _` | |  _  /|  __|  \___ \|  __|    | |  
	-- | |____| |___| |__| | |____| . \  | (_| | | | | (_| | | | \ \| |____ ____) | |____   | |   
	--  \_____|______\____/ \_____|_|\_\  \__,_|_| |_|\__,_| |_|  \_\______|_____/|______|  |_|   
    --
	--=============================================================================================                                                                                        
                                                                                           
	sclk		<= i_clk_spi;
	cclk		<= i_clk;
	
	
	--===============================================================================
	--	  _____            __  __                   _   ______ _____ ______ ____  
	--	 |  __ \     /\   |  \/  |                 | | |  ____|_   _|  ____/ __ \ 
	--	 | |__) |   /  \  | \  / |   __ _ _ __   __| | | |__    | | | |__ | |  | |
	--	 |  _  /   / /\ \ | |\/| |  / _` | '_ \ / _` | |  __|   | | |  __|| |  | |
	--	 | | \ \  / ____ \| |  | | | (_| | | | | (_| | | |     _| |_| |   | |__| |
	--	 |_|  \_\/_/    \_\_|  |_|  \__,_|_| |_|\__,_| |_|    |_____|_|    \____/ 
	--
	--===============================================================================                                                                          
                                                                          
	-- 32-bit write / 1-bit read simple dual port
	-- all input ports are registered, while the output ports are not registered
	cfg_mem : alt_dpram PORT MAP ( -- A is wr port, B is rd port
	-- large ram which holds the configuration of all mutrig
	-- the coherent cache for both modifier and writer
		data	 		=> cfg_mem_dinA,
		rdaddress		=> cfg_mem_addrB,
		rdclock	 		=> sclk,
		wraddress		=> cfg_mem_addrA,
		wrclock	 		=> cclk,
		wren	 		=> cfg_mem_wr_enA,
		q(0)	 		=> cfg_mem_doutB
	);
	
	mod_mem : entity work.simple_dual_port_ram_single_clock 
	-- large ram which holds the configuration of all mutrig
	-- the coherent cache for both modifier and mover
	-- the modifier read this ram and modify, then write back to the cfg_mem
	generic map (
		DATA_WIDTH		=> 32,
		ADDR_WIDTH		=> cfg_mem_addrA'length -- match with cfg_mem depth
	)
	port map(
		clk				=> cclk,
		raddr			=> to_integer(unsigned(mod_mem_rdaddr)),
		waddr			=> to_integer(unsigned(mod_mem_wraddr)),
		data			=> mod_mem_din,
		we				=> mod_mem_we,
		q				=> mod_mem_dout
	);
	
	
	result_mem : entity work.simple_dual_port_ram_single_clock 
	generic map (
		DATA_WIDTH		=> 32,
		ADDR_WIDTH		=> integer(ceil(log2(real(32*64*N_MUTRIG)))) -- for 32 channel, 64 tth, 8 mutrig. 64 BRAM in total. 14 bit
	)
	port map(
		clk				=> cclk,
		raddr			=> to_integer(unsigned(result_mem_rdaddr)),
		waddr			=> to_integer(unsigned(result_mem_wraddr)),
		data			=> result_mem_din,
		we				=> result_mem_we,
		q				=> result_mem_dout
	);
	

	
	-- 5 bit CDC fifo
	-- passing control bits from SPI clock domain (40 MHz) to the controller clock domain (156.25 MHz)
	spi2ctrl_dcfifo : alt_dcfifo_cdc PORT MAP (
		aclr	 		=> i_rst,
		data	 		=> flag_spi2ctrl_din,
		rdclk	 		=> cclk,
		rdreq	 		=> flag_spi2ctrl_rack,
		wrclk	 		=> sclk,
		wrreq	 		=> flag_spi2ctrl_wen,
		q	 			=> flag_spi2ctrl_dout,
		rdempty	 		=> flag_spi2ctrl_rdempty,
		rdfull	 		=> open,
		wrempty	 		=> flag_spi2ctrl_wrempty,
		wrfull	 		=> open
	);
	
	-- 5 bit CDC fifo
	-- passing control bits from controller clock domain (156.25 MHz) to SPI clock domain (40 MHz) 
	ctrl2spi_dcfifo : alt_dcfifo_cdc PORT MAP (
		aclr	 		=> i_rst,
		data	 		=> flag_ctrl2spi_din,
		rdclk	 		=> sclk,
		rdreq	 		=> flag_ctrl2spi_rack,
		wrclk	 		=> cclk,
		wrreq	 		=> flag_ctrl2spi_wen,
		q	 			=> flag_ctrl2spi_dout,
		rdempty	 		=> flag_ctrl2spi_rdempty,
		rdfull	 		=> open,
		wrempty	 		=> flag_ctrl2spi_wrempty,
		wrfull	 		=> open
	);
	
	gen_flip_tth_bits : for i in 0 to current_tth_flip'high generate
		current_tth_flip(i)		<= current_tth(current_tth_flip'high-i);
	end generate gen_flip_tth_bits;
	
	wr_bk_mask : entity work.write_mask_gen 
	port map(
		ingress			=> original_data(modifier_write_word_cnt),
		modifying_bits	=> current_tth_flip,
		selection		=> wr_bk_mask_lsb_loc,
		egress			=> original_data_modified
	);

	--============================================================================
	--  _______ _____           _____   ____  _    _ _______ _____ _   _ ______ 
	-- |__   __/ ____|  /\     |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|
	--    | | | (___   /  \    | |__) | |  | | |  | |  | |    | | |  \| | |__   
	--    | |  \___ \ / /\ \   |  _  /| |  | | |  | |  | |    | | | . ` |  __|  
	--    | |  ____) / ____ \  | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ 
	--    |_| |_____/_/    \_\ |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|
    --																		
	--=============================================================================																

	proc_tth_scan_automation : process (cclk,i_rst)
	-- the central state machine which performs the tthreshold scan automation routine
	-- it commands modifier, config writer and rate monitor in a given sequence. 
	begin
		if (i_rst = '1') then
			tth_scan_automation_state		<= IDLE;
			controller_busy_1				<= '0';
			current_tth						<= (others => '0');
			modifier_start					<= '0';
			ccfg_writer_start_1				<= '0';
			monitor_start					<= '0';
			csr.status						<= (others => '0');
			rpc.done_1						<= '0';
			asic_id_update_req				<= '0';
			asic_id_reset_req				<= '0';
		elsif (rising_edge(cclk)) then
			case tth_scan_automation_state is 
				when IDLE =>
					if (rpc.start = '1' and (rpc.command = CMD_MUTRIG_ASIC_TTH_SCAN or rpc.command = CMD_MUTRIG_ASIC_TTH_SCAN_ALL) and rpc.done_1 = '0') then
						tth_scan_automation_state		<= MOD_TTH; 
						controller_busy_1				<= '1';
						csr.status						<= conv_std_logic_vector(to_integer(unsigned(current_tth)), csr.status'length); -- init TSA progress bar
					else
						-- otherwise ignore
					end if;
				when MOD_TTH =>
					asic_id_update_req				<= '0';
					if (modifier_done = '0' and modifier_start = '0') then -- start modifier sub-routine
						modifier_start		<= '1';
					elsif (modifier_done = '0' and modifier_start = '1') then -- wait modifier to ack start signal
						-- wait
					elsif (modifier_done = '1' and modifier_start = '1') then -- task finished 
						modifier_start		<= '0';
						tth_scan_automation_state		<= CFG;
					else -- wait for modifier to ack the finish signal
						
					end if;
				when CFG =>
					if (cconfig_state.done = '0' and ccfg_writer_start_1 = '0') then -- start writer sub-routine
						ccfg_writer_start_1				<= '1';
					elsif (cconfig_state.done = '0' and ccfg_writer_start_1 = '1') then
						-- wait cfg done
					elsif (cconfig_state.done = '1' and ccfg_writer_start_1 = '1') then -- ack the cfg is done
						ccfg_writer_start_1 			<= '0'; -- TODO: get the error infos from config writer
						case rpc.command is -- add support for iterating the tth incr for all mutrigs
							when CMD_MUTRIG_ASIC_TTH_SCAN =>
								tth_scan_automation_state		<= MONITOR_RATE;
							when CMD_MUTRIG_ASIC_TTH_SCAN_ALL =>
								if (to_integer(unsigned(rpc.asic_id)) < N_MUTRIG) then
									asic_id_update_req				<= '1'; -- solves contention with intpr -- should be high for only 1 cycle!
									tth_scan_automation_state		<= MOD_TTH;
								else
									asic_id_reset_req				<= '1';
									tth_scan_automation_state		<= MONITOR_RATE;	
								end if;
							when others =>
						end case;
					else -- 1/0, config writer needs to ack, do nothing on this side
						
					end if;
						
				when MONITOR_RATE => 
					asic_id_reset_req				<= '0';
					if (monitor_done = '0' and monitor_start = '0') then -- start monitor sub-routine
						monitor_start		<= '1';
					elsif (monitor_done = '0' and monitor_start = '1') then
						-- wait monitor done
					elsif (monitor_done = '1' and monitor_start = '1') then -- ack the monitor
						monitor_start					<= '0';
						tth_scan_automation_state		<= EVALUATION;
					else -- monitor needs to ack, do nothing no this side
						
					end if;
				when EVALUATION =>
					csr.status				<= conv_std_logic_vector(to_integer(unsigned(current_tth)), csr.status'length); -- update TSA progress bar
					if (to_integer(unsigned(current_tth)) < 63) then 
						current_tth						<= conv_std_logic_vector(to_integer(unsigned(current_tth))+1, current_tth'length);
						tth_scan_automation_state		<= MOD_TTH;
					else -- =========== exit of TSA routine =============
						if (rpc.done_1 = '0' and rpc.start = '1') then -- send ack back to irq
							rpc.done_1			<= '1';
						elsif (rpc.done_1 = '1' and rpc.start = '0') then -- rpc ack it
							rpc.done_1					<= '0';
						elsif (rpc.done_1 = '1' and rpc.start = '1') then -- wait for rpc to ack
							-- do nothing on this side
						else 
							tth_scan_automation_state	<= IDLE; 
							-- reset everything here
							current_tth					<= (others => '0');
							controller_busy_1			<= '0';
							-- ...
						end if;
					end if;
				when others =>
					tth_scan_automation_state	<= IDLE; 
					controller_busy_1				<= '0';
					current_tth						<= (others => '0');
					modifier_start					<= '0';
					ccfg_writer_start_1				<= '0';
					monitor_start					<= '0';
					csr.status						<= (others => '0');
					rpc.done_1						<= '0';
			end case;
		end if;
	end process proc_tth_scan_automation;
	
	
	
	--====================================================================================================================================
	--  __  __  ____  _____ _____ ______ _____ ______ _____     _____ _    _ ____        _____   ____  _    _ _______ _____ _   _ ______ 
	-- |  \/  |/ __ \|  __ \_   _|  ____|_   _|  ____|  __ \   / ____| |  | |  _ \      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|
	-- | \  / | |  | | |  | || | | |__    | | | |__  | |__) | | (___ | |  | | |_) |_____| |__) | |  | | |  | |  | |    | | |  \| | |__   
	-- | |\/| | |  | | |  | || | |  __|   | | |  __| |  _  /   \___ \| |  | |  _ <______|  _  /| |  | | |  | |  | |    | | | . ` |  __|  
	-- | |  | | |__| | |__| || |_| |     _| |_| |____| | \ \   ____) | |__| | |_) |     | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ 
	-- |_|  |_|\____/|_____/_____|_|    |_____|______|_|  \_\ |_____/ \____/|____/      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|
	--                                                                                                                                   
    --===================================================================================================================================     
	
	proc_pattern_modifier : process (cclk,i_rst)
	-- perform the modified work flow (iterate for 32 channels):
	--	1) READ from cfg ram, which is temporary ram for DMA-ly get from the scratch-pad ram. Used by config writer. 
	--	2) MODIFY the appropriate bit field
	--	3) WRITE-BACK the changed data to the mod ram and cfg ram. (currently, mod ram is not used) 
	begin
		if (i_rst = '1') then
			modifier_flow			<= IDLE;
			current_modifier_ch		<= 0;
			updated_ch				<= '0';
			modifier_done			<= '0';
			modifier_mod_done		<= '0';
			modifier_writeback_done	<= '0';
			wb_word_cnt				<= 0;
			modifier_write_word_cnt	<= 0;
		elsif (rising_edge(cclk)) then
			mod_mem_rdaddr_d1		<= mod_mem_rdaddr;
			case modifier_flow is
				when IDLE =>
					if (modifier_start = '1' and modifier_done = '0') then -- start the task
						modifier_flow			<= READ32;
						updated_ch				<= '1'; -- NOTE: counting from 0 to 31, otherwise is 1 to 31
					elsif (modifier_start = '1' and modifier_done = '1') then -- wait control to ack
						-- wait
					elsif (modifier_start = '0' and modifier_done = '1') then -- reset things after the ack is received
						modifier_done			<= '0';
						-- reset
						current_modifier_ch		<= 0;
						updated_ch				<= '0';
					else -- idle 
						-- init
						current_modifier_ch		<= 0;
						updated_ch				<= '0'; -- NOTE: counting from 0 to 31, otherwise is 1 to 31
					end if;
				when READ32 =>
					-- update the current channel selection and tth value 
					if (current_modifier_ch < 32 and updated_ch = '0') then
						current_modifier_ch		<= current_modifier_ch + 1;
						updated_ch				<= '1';
					else
						current_modifier_ch		<= current_modifier_ch;
					end if;
					-- start read when the selected channel is correct
					if (updated_ch = '1') then
						if (derived_tth_read_word_cnt(current_modifier_ch) = modifier_read_word_cnt) then -- exit
							modifier_flow			<= MODIFY;
							-- reset
							updated_ch				<= '0';
							modifier_read_word_cnt	<= 0;
						elsif (modifier_read_word_cnt < derived_tth_read_word_cnt(current_modifier_ch)) then
						-- latch word 0 to 1
							if (mod_mem_dout_ready = '1') then -- latched data
								original_data(modifier_read_word_cnt)		<= mod_mem_dout;
								modifier_read_word_cnt						<= modifier_read_word_cnt + 1;
							else
								-- wait for address to settle
							end if;	
						end if;
					end if;
				when MODIFY	=>
					if (modifier_mod_done = '1') then -- exit
						modifier_flow		<= WRITE32;
						-- reset
						modifier_mod_done			<= '0';
						modifier_write_word_cnt		<= 0;
					else
						-- modify the words
						if (derived_tth_read_word_cnt(current_modifier_ch) = 1) then -- no crossing words
							original_data(0)		<= original_data_modified;
							modifier_mod_done		<= '1';
						else -- crossing two words
							if (modifier_write_word_cnt = 0) then
								original_data(0)			<= original_data_modified;
								modifier_write_word_cnt		<= modifier_write_word_cnt + 1;
							else
								modifier_mod_done			<= '1';
								original_data(1)			<= original_data_modified;
							end if;
							
						end if;
						
					end if;
				when WRITE32 =>
					if (modifier_writeback_done = '1') then -- exit
						modifier_writeback_done	<= '0';
						if (current_modifier_ch < 31) then -- loop back to READ32 for another channel, otherwise the modifier is done
							modifier_flow		<= READ32;
							-- reset ch related signals
							original_data		<= (others=>(others=>'0'));
						else -- =========== EXIT OF THE SUB-ROUTINE ================
							modifier_done		<= '1';
							-- reset all is in idle
							modifier_flow		<= IDLE;
						end if;
					else
						-- write back to the cfg_mem
						if (derived_tth_read_word_cnt(current_modifier_ch) = 1) then -- no crossing words
							modifier_writeback_done		<= '1';
						else -- crossing two words
							if (wb_word_cnt = 0) then
								wb_word_cnt				<= wb_word_cnt + 1;	
							else
								modifier_writeback_done	<= '1';
								-- reset
								wb_word_cnt				<= 0;
							end if;
						end if;
					end if;
				when others =>
					modifier_flow			<= IDLE;
					current_modifier_ch		<= 0;
					updated_ch				<= '0';
					modifier_done			<= '0';
					modifier_mod_done		<= '0';
					modifier_writeback_done	<= '0';
					wb_word_cnt				<= 0;
			end case;
		end if;
	end process proc_pattern_modifier;
	
	
	proc_pattern_modifier_comb : process (all)
	begin
		mod_mem_rdaddr				<= conv_std_logic_vector(derived_tth_location_word(current_modifier_ch) + modifier_read_word_cnt + to_integer(unsigned(rpc.asic_id))*CFG_MEM_PARTITION_SIZE_WORD, mod_mem_rdaddr'length); 
		if (mod_mem_rdaddr_d1 = mod_mem_rdaddr) then
			mod_mem_dout_ready		<= '1';
		else 
			mod_mem_dout_ready		<= '0';
		end if;
		case modifier_flow is 
			when WRITE32 =>
				if (modifier_writeback_done = '1') then
					modifier_wr_back_data	<= (others=>'0');
					modifier_wr_back_addr	<= (others=>'0');
					modifier_wr_back_valid	<= '0';
				else
					if (derived_tth_read_word_cnt(current_modifier_ch) = 1) then -- no crossing words
						modifier_wr_back_data	<= original_data(0);
						modifier_wr_back_addr	<= conv_std_logic_vector(derived_tth_location_word(current_modifier_ch)+to_integer(unsigned(rpc.asic_id))*CFG_MEM_PARTITION_SIZE_WORD,modifier_wr_back_addr'length);
						modifier_wr_back_valid	<= '1';
					else -- crossing two words
						if (wb_word_cnt = 0) then
							modifier_wr_back_data	<= original_data(0);
							modifier_wr_back_addr	<= conv_std_logic_vector(derived_tth_location_word(current_modifier_ch)+to_integer(unsigned(rpc.asic_id))*CFG_MEM_PARTITION_SIZE_WORD,modifier_wr_back_addr'length);
							modifier_wr_back_valid	<= '1';
						else 
							modifier_wr_back_data	<= original_data(1);
							modifier_wr_back_addr	<= conv_std_logic_vector(derived_tth_location_word(current_modifier_ch)+1+to_integer(unsigned(rpc.asic_id))*CFG_MEM_PARTITION_SIZE_WORD,modifier_wr_back_addr'length);
							modifier_wr_back_valid	<= '1';
						end if;
					end if;
				end if;
			when others =>
				modifier_wr_back_data	<= (others=>'0');
				modifier_wr_back_addr	<= (others=>'0');
				modifier_wr_back_valid	<= '0';
		end case;
		modifier_wr_back_en			<= modifier_wr_back_valid;
		
		if (modifier_write_word_cnt = 0) then
			wr_bk_mask_lsb_loc		<= std_logic_vector(to_signed(derived_tth_bit_mod(current_modifier_ch),wr_bk_mask_lsb_loc'length));
		else 
			wr_bk_mask_lsb_loc		<= std_logic_vector(to_signed(derived_tth_bit_mod_enduf(current_modifier_ch),wr_bk_mask_lsb_loc'length));
		end if;
	end process proc_pattern_modifier_comb;
	
	
	--=============================================================================================================================================================
	--  _____         _______ ______   __  __  ____  _   _ _____ _______ ____  _____     _____ _    _ ____        _____   ____  _    _ _______ _____ _   _ ______ 
	-- |  __ \     /\|__   __|  ____| |  \/  |/ __ \| \ | |_   _|__   __/ __ \|  __ \   / ____| |  | |  _ \      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|
	-- | |__) |   /  \  | |  | |__    | \  / | |  | |  \| | | |    | | | |  | | |__) | | (___ | |  | | |_) |_____| |__) | |  | | |  | |  | |    | | |  \| | |__   
	-- |  _  /   / /\ \ | |  |  __|   | |\/| | |  | | . ` | | |    | | | |  | |  _  /   \___ \| |  | |  _ <______|  _  /| |  | | |  | |  | |    | | | . ` |  __|  
	-- | | \ \  / ____ \| |  | |____  | |  | | |__| | |\  |_| |_   | | | |__| | | \ \   ____) | |__| | |_) |     | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ 
	-- |_|  \_\/_/    \_\_|  |______| |_|  |_|\____/|_| \_|_____|  |_|  \____/|_|  \_\ |_____/ \____/|____/      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|
	--                                                                                                                                                            
	--=============================================================================================================================================================
	
	proc_rate_monitor : process (cclk,i_rst)
	-- Perform the workflow of rate monitor: 
	--	1) issue sclr to the counters (not required to set the counter in 'READ_ON_THE_FLY' mode, as long as the monitor windows is larger than 1s)
	--	2) wait for counters to collect hits for 1s
	--	3) readback the hits in the last 1s window and store the infomation into result ram
	begin
		-- NOTE: for the sclr of counter, issue the sclr and wait for 1 second. This sclr will also reset the timer in the counter, and in 1s after this sclr
		-- the internal timer will sclr the counter itself. Because it is not in READ_ON_THE_FLY mode, the value is latched on this incidence.
		-- To make generalize, set the reset interval of the counter, and issue sclr, wait for such interval and readback.
			-- the readback value is valid within for another reset interval.
		-- NOTE: remember to set the counter reset interval back, after the monitor is done...
		if (i_rst = '1') then
			monitor_flow		<= IDLE;
			avm2counter_flow	<= POSTING_CMD;
			monitor_done		<= '0';
			avm_cnt_read		<= '0';
			cmd_posted			<= '0';
			o_sclr_req			<= '0';
			sclr_timer_cnt		<= 0;
			wait_timer_cnt		<= (others => '0');
			slaveresponse_timeout		<= '0';
			slaveresponse_timeout_cnt	<= 0;	
			monitor_asic_cnt			<= 0;
			avm_cnt_flush				<= '0';
		elsif (rising_edge(cclk)) then
			case monitor_flow is 
				when IDLE => 
					o_sclr_req			<= '0';
					if (monitor_start = '1') then
						monitor_flow		<= SCLR_COUNTERS;
					end if;
				when SCLR_COUNTERS => 
					sclr_timer_cnt		<= sclr_timer_cnt + 1;
					if (sclr_timer_cnt >= 5) then -- assert sclr of the channel counters
						o_sclr_req			<= '1';
						monitor_flow		<= WAIT_FOR_COUNTERS;
						sclr_timer_cnt		<= 0;
					end if;
				when WAIT_FOR_COUNTERS =>
					o_sclr_req			<= '0';
					wait_timer_cnt		<= conv_std_logic_vector(to_integer(unsigned(wait_timer_cnt)) + 1, wait_timer_cnt'length); -- wait time count is ticks for 1 s at this frequency
					if ((to_integer(unsigned(wait_timer_cnt))) >= to_integer(unsigned(monitor_wait_cycles)) + 5) then -- give 5 cycle of head room
					-- the counters are in 125MHz, this IP is in 156.25MHz
					-- for granularity of timer setting >1ms, this should be not a problem. 
						monitor_flow		<= READ_RESULTS;
						avm2counter_flow	<= POSTING_CMD;
						wait_timer_cnt		<= (others => '0');
					end if;
				when READ_RESULTS => 
					case avm2counter_flow is 
						when POSTING_CMD =>
							monitor_read_word_cnt	<= 0;
							-- post reading cmd to qsys
							avm_cnt_read			<= '1';
							avm_cnt_burstcount		<= conv_std_logic_vector(32, avm_cnt_burstcount'length); -- burst for one mutrig at each time,
							-- NOTE: Large burst across slave boundary will not be auto segmented into small burst, do it manually
							-- the second time entrance: do nothing for the count
							avm_cnt_address			<= conv_std_logic_vector(COUNTER_MM_ADDR_OFFSET_WORD+monitor_asic_cnt*32, avm_cnt_address'length);
							cmd_posted				<= '1'; -- post at least one cycle
							if (avm_cnt_waitrequest = '0' and cmd_posted = '1') then
								avm_cnt_read			<= '0';
								cmd_posted				<= '0';
								avm2counter_flow		<= RECEIVING_READDATA; 
							end if;
						when RECEIVING_READDATA => 
							-- receive the burst data
							if (monitor_read_word_cnt < 32 and monitor_asic_cnt < N_MUTRIG) then -- from 0 to 31
								if (avm_cnt_readdatavalid = '1') then 
									monitor_read_word_cnt		<= 	monitor_read_word_cnt + 1;
									slaveresponse_timeout_cnt	<= 0;
								else
									slaveresponse_timeout_cnt	<= slaveresponse_timeout_cnt + 1;
									if (slaveresponse_timeout_cnt >= 500) then 
										slaveresponse_timeout		<= '1';
										slaveresponse_timeout_cnt	<= 0;
										avm2counter_flow			<= FINISHED;
										avm_cnt_flush				<= '1';
									end if;
								end if;
							elsif (monitor_read_word_cnt = 32 and monitor_asic_cnt < N_MUTRIG-1) then  -- n_asic from 0 to 3
							-- post another cmd on avalon	
								monitor_asic_cnt			<= monitor_asic_cnt + 1;
								avm2counter_flow			<= POSTING_CMD;
							elsif (monitor_read_word_cnt = 32 and monitor_asic_cnt = N_MUTRIG-1) then
							-- exit condition: tot read cnt is fulfilled asic=3;word=32
								avm2counter_flow			<= FINISHED;
								slaveresponse_timeout_cnt	<= 0;
								monitor_read_word_cnt		<= 0;
							else
								slaveresponse_timeout_cnt	<= slaveresponse_timeout_cnt + 1;
								if (slaveresponse_timeout_cnt >= 500) then 
									slaveresponse_timeout		<= '1';
									slaveresponse_timeout_cnt	<= 0;
									avm2counter_flow			<= FINISHED;
									avm_cnt_flush				<= '1';
								end if;
							end if;
						when FINISHED	=> 
							if (slaveresponse_timeout = '1') then
								monitor_flow		<= FINISHING; -- TODO: rise some flag here
								avm_cnt_flush		<= '0';
							else
								monitor_flow		<= FINISHING;
							end if;
						when others =>
					end case;
				when FINISHING =>
					if (monitor_start = '1' and monitor_done = '0') then -- send done signal 
						monitor_done		<= '1';
					elsif (monitor_start = '1' and monitor_done = '1') then -- wait for TSA to ack
						
					elsif (monitor_start = '0' and monitor_done = '1') then -- TSA ack it
						monitor_done		<= '0';
					else -- TODO: reset everything here
						monitor_flow		<= IDLE;
						cmd_posted			<= '0';
						o_sclr_req			<= '0';
						sclr_timer_cnt		<= 0;
						wait_timer_cnt		<= (others => '0');
						slaveresponse_timeout		<= '0';
						slaveresponse_timeout_cnt	<= 0;	
						monitor_asic_cnt			<= 0;
						avm_cnt_flush				<= '0';
					end if;	
				when others =>
					monitor_flow		<= IDLE;
					avm2counter_flow	<= POSTING_CMD;
					avm_cnt_read		<= '0';
					monitor_done		<= '0';
					cmd_posted			<= '0';
					sclr_timer_cnt		<= 0;
					wait_timer_cnt		<= (others=>'0');
					slaveresponse_timeout		<= '0';
					slaveresponse_timeout_cnt	<= 0;	
			end case;
		end if;
	end process proc_rate_monitor;
	
	
	proc_rate_monitor_comb : process (all)
	begin
		-- write to the result ram 
		case monitor_flow is 
			-- receive the burst data
			when READ_RESULTS =>
				result_mem_wraddr	<= conv_std_logic_vector( ((monitor_read_word_cnt+32*monitor_asic_cnt)*64)+to_integer(unsigned(current_tth)), result_mem_wraddr'length); --to_integer(unsigned(current_tth))) * to_integer(unsigned(rpc.asic_id)
				result_mem_we		<= avm_cnt_readdatavalid;
				result_mem_din		<= avm_cnt_readdata;
			when others =>
				result_mem_wraddr	<= (others => '0');
				result_mem_we		<= '0';
				result_mem_din		<= (others => '0');
		end case;
	end process proc_rate_monitor_comb;
	
	
	--===================================================================================================
	--  _____  ______  _____ _    _ _   _______   _____            __  __       __      ____  __ __  __ 
	-- |  __ \|  ____|/ ____| |  | | | |__   __| |  __ \     /\   |  \/  |     /\ \    / /  \/  |  \/  |
	-- | |__) | |__  | (___ | |  | | |    | |    | |__) |   /  \  | \  / |    /  \ \  / /| \  / | \  / |
	-- |  _  /|  __|  \___ \| |  | | |    | |    |  _  /   / /\ \ | |\/| |   / /\ \ \/ / | |\/| | |\/| |
	-- | | \ \| |____ ____) | |__| | |____| |    | | \ \  / ____ \| |  | |  / ____ \  /  | |  | | |  | |
	-- |_|  \_\______|_____/ \____/|______|_|    |_|  \_\/_/    \_\_|  |_| /_/    \_\/   |_|  |_|_|  |_|
	--
    --===================================================================================================          
								 
	proc_result_ram_avmm : process (cclk,i_rst)
	begin
		if (i_rst = '1') then
			
		elsif (rising_edge(cclk)) then
			-- keep track of the address selection
			avs_scanresult_address_d1		<= avs_scanresult_address;
			if (avs_scanresult_read = '1') then 
				avs_scanresult_waitrequest		<= '0';
			else 
				avs_scanresult_waitrequest		<= '1';
			end if;
		end if;
	end process proc_result_ram_avmm;
	
	
	proc_result_ram_avmm_comb : process (all)
	-- this in principle supports burst read 
	begin
		result_mem_rdaddr			<= avs_scanresult_address(result_mem_rdaddr'high downto 0); -- truncate the avmm port to the result mem width
		avs_scanresult_readdata		<= result_mem_dout;
	end process proc_result_ram_avmm_comb;
	
	

	
	
	--========================
	--   _____  _____ _____  
	--  / ____|/ ____|  __ \ 
	-- | |    | (___ | |__) |
	-- | |     \___ \|  _  / 
	-- | |____ ____) | | \ \ 
	--  \_____|_____/|_|  \_\
	--                       
	--========================                       

	proc_csr_fsm	: process (all)
	-- Control and State Register (CSR) IRQ Issuer finite state machine
	-- change the csr state base on the avalon bus
	variable avs_csr_rw_cmd : std_logic_vector(1 downto 0);
	begin
		avs_csr_rw_cmd		:= avs_csr_read & avs_csr_write;
		case avs_csr_rw_cmd is 
			when "10" =>
				csr_state		<= READ_CSR;
			when "01" =>
				csr_state		<= WRITE_CSR;
			when "00" =>
				csr_state		<= IDLE;
			when others =>
				csr_state		<= CONFLICT;
		end case;
	end process proc_csr_fsm;
	
	proc_csr_irq	: process (cclk,i_rst) 
	-- Generate irq signal once the csr command has been written 
	begin
		if (i_rst = '1') then
			avs_csr_waitrequest			<= '1';
			avs_csr_readdata			<= (others=>'0');
			avs_csr_response			<= RSP_GOOD;
			csr.opcode					<= (others=>'0');
			csr.offset					<= (others=>'0');
            csr.monitor_seconds         <= to_unsigned(1,csr.monitor_seconds'length);
		elsif (rising_edge(cclk)) then
			case csr_state is
				when IDLE => 	
					avs_csr_waitrequest				<= '1';
					csr.written						<= '0'; --reset this irq signal				
				when READ_CSR => 
					avs_csr_readdata				<= (others => '0');
					case avs_csr_address is
						when conv_std_logic_vector(0,avs_csr_address'length) =>
							
							if (controller_busy = '1') then 
							-- MIDAS cpp software:
							-- the poll upper 16 bits is 0: finished; otherwise: ongoing/busy. 
							-- poll lower 16 bits: read back status for user
								--avs_csr_readdata			<= (others => '1');
								avs_csr_readdata(31 downto 16)	<= csr.opcode(31 downto 16);
								avs_csr_readdata(15 downto 0)	<= csr.status;
							else
								avs_csr_readdata			<= (others => '0');
							end if;
							avs_csr_waitrequest			<= '0';
							avs_csr_response			<= RSP_GOOD;
						when conv_std_logic_vector(1,avs_csr_address'length) =>
							avs_csr_readdata			<= csr.offset;
							avs_csr_waitrequest			<= '0';
							avs_csr_response			<= RSP_GOOD;
                        when conv_std_logic_vector(2,avs_csr_address'length) =>
                            avs_csr_readdata(15 downto 0)   <=  std_logic_vector(csr.monitor_seconds);
                            avs_csr_waitrequest         <= '0';
                            avs_csr_response			<= RSP_GOOD;
						when conv_std_logic_vector(3,avs_csr_address'length) =>
							avs_csr_readdata			<= (others => '0');
							avs_csr_waitrequest			<= '0';
							avs_csr_response			<= RSP_GOOD;
						when others =>
							avs_csr_readdata			<= (others=>'0');
							avs_csr_waitrequest			<= '0';
							avs_csr_response			<= RSP_DECODEERR;
					end case;
				when WRITE_CSR	=>
					case avs_csr_address is
						when conv_std_logic_vector(0,avs_csr_address'length) =>
							csr.opcode						<= avs_csr_writedata;
							csr.written						<= '1';
							avs_csr_waitrequest				<= '0';
							avs_csr_response				<= RSP_GOOD;
							irq_start						<= '1';
						when conv_std_logic_vector(1,avs_csr_address'length) =>
							csr.offset						<= avs_csr_writedata;
							avs_csr_waitrequest				<= '0';
							avs_csr_response				<= RSP_GOOD;
                        when conv_std_logic_vector(2,avs_csr_address'length) =>
                            csr.monitor_seconds             <= unsigned(avs_csr_writedata(15 downto 0));
							avs_csr_waitrequest				<= '0';
							avs_csr_response				<= RSP_GOOD;
						when conv_std_logic_vector(3,avs_csr_address'length) =>
							avs_csr_waitrequest				<= '0';
							avs_csr_response				<= RSP_GOOD;
						when others =>
							avs_csr_response				<= RSP_DECODEERR;
					end case;
				when others => -- illegal states, this should release the system bus from no-response
					avs_csr_waitrequest				<= '0';
					avs_csr_response					<= RSP_SLVERR;
			end case;
		end if;
	end process proc_csr_irq;
	
	
	-- ===========================================================================================================================================================
	--  _____ _   _  _____ _______ _____  _    _  _____ _______ _____ ____  _   _   _____ _   _ _______ ______ _____  _____  _____  ______ _______ ______ _____  
	-- |_   _| \ | |/ ____|__   __|  __ \| |  | |/ ____|__   __|_   _/ __ \| \ | | |_   _| \ | |__   __|  ____|  __ \|  __ \|  __ \|  ____|__   __|  ____|  __ \ 
	--   | | |  \| | (___    | |  | |__) | |  | | |       | |    | || |  | |  \| |   | | |  \| |  | |  | |__  | |__) | |__) | |__) | |__     | |  | |__  | |__) |
	--   | | | . ` |\___ \   | |  |  _  /| |  | | |       | |    | || |  | | . ` |   | | | . ` |  | |  |  __| |  _  /|  ___/|  _  /|  __|    | |  |  __| |  _  / 
	--  _| |_| |\  |____) |  | |  | | \ \| |__| | |____   | |   _| || |__| | |\  |  _| |_| |\  |  | |  | |____| | \ \| |    | | \ \| |____   | |  | |____| | \ \ 
	-- |_____|_| \_|_____/   |_|  |_|  \_\\____/ \_____|  |_|  |_____\____/|_| \_| |_____|_| \_|  |_|  |______|_|  \_\_|    |_|  \_\______|  |_|  |______|_|  \_\
	--                                                                                                                                                           
	-- ===========================================================================================================================================================  
	
	proc_INSTRUCTION_INTERPRETER : process(cclk,i_rst)
	-- Digest the command if there is irq signal, be careful the irq is as short as one cycle
	-- issues the digested command to the mutrig configuration controller
	begin
		if (i_rst = '1') then
			rpc.start		<= '0';
			rpc.command 	<= (others => '0');
			rpc.asic_id		<= (others => '0');
			rpc.cfglen		<= (others => '0');
		elsif (rising_edge(cclk)) then
			if (csr.written = '1' and rpc.done = '0' and controller_busy = '0') then -- start the main state machine
				rpc.command		<= csr.opcode(31 downto 20);
				rpc.asic_id		<= csr.opcode(19 downto 16);
				rpc.cfglen		<= csr.opcode(15 downto 0);
				rpc.start		<= '1';
			elsif (asic_id_update_req = '1') then  -- update asic_id (only for the tsa all cmd)
				rpc.asic_id		<= conv_std_logic_vector(to_integer(unsigned(rpc.asic_id)) + 1,rpc.asic_id'length);
			elsif (asic_id_reset_req = '1') then
				rpc.asic_id		<= (others => '0');
			end if;
			if (rpc.start = '1' and rpc.done = '0' and controller_busy = '0') then -- main state machine is processing
				rpc.start		<= '1'; -- TODO: when busy say something
			elsif (rpc.start = '1' and rpc.done = '1') then -- main state machine done, ack it, complete job
				rpc.start		<= '0';
			else
				-- idle, ignore command is either of the two routine is busy
			end if;
			if (rpc.start = '1' and rpc.command /= CMD_MUTRIG_ASIC_CFG and rpc.command /= CMD_MUTRIG_ASIC_TTH_SCAN) then
			-- terminate the rpc if the command is not found in the legal cmd list
				rpc.start	<= '0';
			end if;
		end if;
	end process proc_INSTRUCTION_INTERPRETER;
	
	
	proc_contention_rpc_done : process (all)
	begin
		rpc.done			<= rpc.done_0 or rpc.done_1;
		controller_busy		<= controller_busy_0 or controller_busy_1;
	end process proc_contention_rpc_done;
	
	
	-- =============================================================================================
	--   _____ ______ _____    _____ ____  _   _ _______ _____   ____  _      _      ______ _____  
	--  / ____|  ____/ ____|  / ____/ __ \| \ | |__   __|  __ \ / __ \| |    | |    |  ____|  __ \ 
	-- | |    | |__ | |  __  | |   | |  | |  \| |  | |  | |__) | |  | | |    | |    | |__  | |__) |
	-- | |    |  __|| | |_ | | |   | |  | | . ` |  | |  |  _  /| |  | | |    | |    |  __| |  _  / 
	-- | |____| |   | |__| | | |___| |__| | |\  |  | |  | | \ \| |__| | |____| |____| |____| | \ \ 
	--  \_____|_|    \_____|  \_____\____/|_| \_|  |_|  |_|  \_\\____/|______|______|______|_|  \_\
	--                                                                                             
	-- =============================================================================================                                                                                             

	proc_mutrig_cfg_ctrl_fsm_comb : process(all)
	-- Main state machine of the mutrig configuration controller (MCC)
	-- the next state is derived as combinational logic, the input flags must be reg to avoid glitches
	-- the reset will transit all states into IDLE, other exceptions are trapped in EXCEPTION state. 
	begin
		case cfg_controller_state is
			when IDLE =>
				if (rpc.start = '1' and rpc.command = CMD_MUTRIG_ASIC_CFG and rpc.done_0 = '0') then -- config command starting point
					cfg_controller_state_next		<= MOVE_DATA;
				else
					cfg_controller_state_next		<= IDLE;
				end if;
			when EXCEPTION =>
				if (i_rst = '1') then
					cfg_controller_state_next		<= IDLE;
				else
					cfg_controller_state_next		<= EXCEPTION; -- trap state for debug
				end if;
			when MOVE_DATA	=>
				if (i_rst = '1') then
					cfg_controller_state_next		<= IDLE;
				else
					if (move_data_done = '1') then
						cfg_controller_state_next		<= WRITE_CFG;
					else
						cfg_controller_state_next		<= MOVE_DATA;
					end if;
				end if;
			when WRITE_CFG =>
				if (i_rst = '1') then
					cfg_controller_state_next		<= IDLE;
				else
					if (cconfig_state.done = '0' and ccfg_writer_start_0 = '0') then
						cfg_controller_state_next		<= WRITE_CFG;
					elsif (cconfig_state.done = '0' and ccfg_writer_start_0 = '1') then
							-- wait cfg done
						cfg_controller_state_next		<= WRITE_CFG;
					elsif (cconfig_state.done = '1' and ccfg_writer_start_0 = '1') then -- ack the cfg is done
						cfg_controller_state_next		<= IDLE;
					else
						cfg_controller_state_next		<= EXCEPTION;			-- trap state
					end if;
				end if;
			when others =>
				cfg_controller_state_next		<= EXCEPTION; -- trap state
		end case;
	end process proc_mutrig_cfg_ctrl_fsm_comb;
	
	proc_mutrig_cfg_ctrl_fsm : process(cclk,i_rst)
	-- Main state machine of the mutrig configuration controller
	-- controls the data mover and config writer
	begin
		if (i_rst = '1') then -- reset all control signals, the state will go comb back to idle
			data_mover_start						<= '0';
			ccfg_writer_start_0						<= '0';
			move_data_done							<= '0';
			rpc.done_0								<= '0';
			controller_exception.error				<= '0';
			controller_exception.errcode			<= (others=>'0');
			controller_busy_0						<= '0';	
		elsif (rising_edge(cclk)) then
			cfg_controller_state	<= cfg_controller_state_next;
			case cfg_controller_state is
				when IDLE =>																		-- <- reset irq flags here
					-- clear the flag from irq
					if (rpc.start = '1' and rpc.done_0 = '1') then
					 -- job done from main side, wait for irq to ack
					elsif (rpc.start = '0' and rpc.done_0 = '1') then
					-- irq ack this done, release flags
						rpc.done_0					<= '0';
						move_data_done				<= '0';
						controller_busy_0			<= '0';
					elsif (rpc.start = '1' and rpc.done_0 = '0') then
					-- irq start signal received, start job
						if (rpc.command = CMD_MUTRIG_ASIC_CFG) then -- other commands are ignored
							controller_busy_0		<= '1';
						end if;
					else
					-- purely idle
						data_mover_start		<= '0'; -- reset this for now...
						--ccfg_writer_start_0		<= '0'; -- this let the TSA to access it
					end if;
				when MOVE_DATA =>
					if (data_mover_done = '0' and data_mover_start = '0') then 		-- <-start mover here
						data_mover_start		<= '1'; -- start
						
					elsif (data_mover_done = '1' and data_mover_start = '1') then
						data_mover_start		<= '0'; -- ack by the mover, terminate moving
						move_data_done			<= '1';
					elsif (data_mover_done = '0' and data_mover_start = '1') then
						-- mover in action, do nothing but wait for ack
					else
						-- wrong handshake signals, not started, but mover finished
						controller_exception.error		<= '1';
						controller_exception.errcode	<= "001"; -- state error
					end if;
				when WRITE_CFG => 																-- <- start writer here
					if (cconfig_state.done = '0' and ccfg_writer_start = '0') then
						ccfg_writer_start_0			<= '1';
					elsif (cconfig_state.done = '0' and ccfg_writer_start_0 = '1') then
						-- wait cfg done
					elsif (cconfig_state.done = '1' and ccfg_writer_start_0 = '1') then -- ack the cfg is done
						ccfg_writer_start_0 			<= '0'; -- TODO: get the error infos from config writer
						rpc.done_0						<= '1'; -- send ack back to irq
					else
						-- trap state
					end if;
				when others =>
			end case;
		end if;
	end process proc_mutrig_cfg_ctrl_fsm;
	

	
	--===================================================================
	--  _____       _______         __  __  ______      ________ _____  
	-- |  __ \   /\|__   __|/\     |  \/  |/ __ \ \    / /  ____|  __ \ 
	-- | |  | | /  \  | |  /  \    | \  / | |  | \ \  / /| |__  | |__) |
	-- | |  | |/ /\ \ | | / /\ \   | |\/| | |  | |\ \/ / |  __| |  _  / 
	-- | |__| / ____ \| |/ ____ \  | |  | | |__| | \  /  | |____| | \ \ 
	-- |_____/_/    \_\_/_/    \_\ |_|  |_|\____/   \/   |______|_|  \_\
	--                                                                  
	--=====================================================================                                                                  

	proc_data_mover : process (cclk,i_rst)
	begin
	-- Move the data from the scatchpad to cfg_mem (DMA engine)
	-- enabled by the "data_mover_start" signal and ack back with "data_mover_done" signal
		if (i_rst = '1') then
			mover_avmm_rd_flow		<= RESET;
			data_mover_done			<= '0';
			avm_schpad_read         <= '0';
			avm_schpad_address      <= (others => '0');
			avm_schpad_burstcount   <= (others => '0');
			mover_trans_cnt         <= (others => '0');
		elsif (rising_edge(cclk)) then
			case mover_avmm_rd_flow is 
				when S1 =>
					-- Arm the scratchpad read one cycle before avm_schpad_read so the
					-- translator sees a stable address/burstcount during waitrequest.
					avm_schpad_address		<= csr.offset(avm_schpad_address'length-1 downto 0);
					avm_schpad_read			<= '0';
					avm_schpad_burstcount	<= rpc.cfglen(avm_schpad_burstcount'length-1 downto 0);
					mover_avmm_rd_flow		<= S2;
				when S2 =>
					avm_schpad_read         <= '1';
					mover_avmm_rd_flow      <= S3;
				when S3 =>
					if (avm_schpad_waitrequest = '1') then
						avm_schpad_read     <= '1';
						mover_avmm_rd_flow  <= S3;
					else
						avm_schpad_read     <= '0';
						mover_avmm_rd_flow  <= S4;
					end if;
				when S4 =>
					if (to_integer(unsigned(mover_trans_cnt)) < to_integer(unsigned(rpc.cfglen))) then
						if (avm_schpad_readdatavalid = '1') then
							mover_trans_cnt	<= conv_std_logic_vector(to_integer(unsigned(mover_trans_cnt))+1,mover_trans_cnt'length);
						end if;
					else
						data_mover_done		<= '1';
						mover_avmm_rd_flow	<= RESET;
					end if;
				when RESET =>
					avm_schpad_read			<= '0';
					avm_schpad_address		<= (others => '0');
					avm_schpad_burstcount	<= (others => '0');
					mover_trans_cnt			<= (others => '0');
					if (data_mover_start	= '1' and data_mover_done = '1') then
						mover_avmm_rd_flow		<= RESET; -- wait for ctrl to ack the mover is done
					elsif (data_mover_start	= '0' and data_mover_done = '1') then
						mover_avmm_rd_flow		<= IDLE; -- ack by the ctrl
						data_mover_done			<= '0';
					else -- wrong control handshake signals: no start signal asserted, but goes back to IDLE
					-- maybe not all data has been written to cfg_mem as it is required to be asserted for the whole
					-- duration by the comb logic to dpram. 
						mover_avmm_rd_flow		<= IDLE; 
						data_mover_done			<= '0';
					end if;
				when IDLE => 
					if (data_mover_start	= '1') then
						mover_avmm_rd_flow		<= S1;
					end if;
				when others =>
					mover_avmm_rd_flow		<= RESET;
			end case;
		end if;
	end process proc_data_mover;
	
	
	
	proc_contention_cfg_mem : process(all)
	-- Comb logic to write to the cfg_mem and mod_mem (possible contention, priority rank 0-1)
	-- only when connected to the cfg_mem and mod_mem write port registers when mover is in writing state, otherwise go blank 
	begin
		if (data_mover_start = '1') then -- give control to data mover (priority 0)
			case mover_avmm_rd_flow is 
				when S4 => 
					if (to_integer(unsigned(mover_trans_cnt)) <= to_integer(unsigned(rpc.cfglen))) then
						if (avm_schpad_readdatavalid = '1') then
							cfg_mem_wr_enA		<= '1';
							mod_mem_we			<= '1';
							cfg_mem_addrA		<= conv_std_logic_vector(to_integer(unsigned(mover_trans_cnt)) + to_integer(unsigned(rpc.asic_id))*CFG_MEM_PARTITION_SIZE_WORD, cfg_mem_addrA'length);
							mod_mem_wraddr		<= conv_std_logic_vector(to_integer(unsigned(mover_trans_cnt)) + to_integer(unsigned(rpc.asic_id))*CFG_MEM_PARTITION_SIZE_WORD, cfg_mem_addrA'length);
							cfg_mem_dinA		<= avm_schpad_readdata;
							mod_mem_din			<= avm_schpad_readdata;
						else 
							cfg_mem_wr_enA		<= '0';
							mod_mem_we			<= '0';
							cfg_mem_addrA		<= (others=>'0');
							mod_mem_wraddr		<= (others=>'0');
							cfg_mem_dinA		<= (others=>'0');
							mod_mem_din			<= (others=>'0');
						end if;
					else 
						cfg_mem_wr_enA		<= '0';
						mod_mem_we			<= '0';
						cfg_mem_addrA		<= (others=>'0');
						mod_mem_wraddr		<= (others=>'0');
						cfg_mem_dinA		<= (others=>'0');
						mod_mem_din			<= (others=>'0');
					end if;
				when others =>
					cfg_mem_wr_enA		<= '0';
					mod_mem_we			<= '0';
					cfg_mem_addrA		<= (others=>'0');
					mod_mem_wraddr		<= (others=>'0');
					cfg_mem_dinA		<= (others=>'0');
					mod_mem_din			<= (others=>'0');
			end case;
		elsif (modifier_start = '1') then -- give control to the modifier (priority 1)
			cfg_mem_wr_enA		<= modifier_wr_back_en;
			mod_mem_we			<= '0';
			cfg_mem_addrA		<= modifier_wr_back_addr;
			mod_mem_wraddr		<= (others=>'0');
			cfg_mem_dinA		<= modifier_wr_back_data;
			mod_mem_din			<= (others=>'0');
		else
			cfg_mem_wr_enA		<= '0';
			mod_mem_we			<= '0';
			cfg_mem_addrA		<= (others=>'0');
			mod_mem_wraddr		<= (others=>'0');
			cfg_mem_dinA		<= (others=>'0');
			mod_mem_din			<= (others=>'0');
		end if;
	end process proc_contention_cfg_mem;
	
	
		
	--=========================================================================	
	--   _____ ______ _____  __          _______  _____ _______ ______ _____  
	--  / ____|  ____/ ____| \ \        / /  __ \|_   _|__   __|  ____|  __ \ 
	-- | |    | |__ | |  __   \ \  /\  / /| |__) | | |    | |  | |__  | |__) |
	-- | |    |  __|| | |_ |   \ \/  \/ / |  _  /  | |    | |  |  __| |  _  / 
	-- | |____| |   | |__| |    \  /\  /  | | \ \ _| |_   | |  | |____| | \ \ 
	--  \_____|_|    \_____|     \/  \/   |_|  \_\_____|  |_|  |______|_|  \_\
	--                                                                        
	--==========================================================================                                                                        

	proc_contention_cfg_writer : process (all)
	begin 
		ccfg_writer_start	<= ccfg_writer_start_0 or ccfg_writer_start_1;
	end process proc_contention_cfg_writer;
	
	proc_cfg_writer : process(sclk,i_rst_spi)
	-- Writer logic to the SPI wire
	-- CPOL = 0; CPHA = 0
	-- TODO: add offset for the mem cfg to read asic /=0 
	begin 
		if (i_rst_spi = '1') then
			cfg_writer_flow		<= IDLE;
			cfg_checker_flow	<= RESET;
			
		elsif (rising_edge(sclk)) then
--			case cfg_checker_flow is
--				when IDLE =>
--					spi_checking_flow	<= CLK_LOW;
--				when RESET => 
--					spi_checking_flow	<= CLK_LOW;
--				when CHECKING =>
--					case spi_checking_flow is
--						when CLK_LOW => -- latch miso data
--							cfg_checker_readback_din	<= spi_miso;
--							spi_checking_flow			<= CLK_HIGH;
--						when CLK_HIGH =>
--							spi_checking_flow			<= CLK_LOW;
--						when others =>
--					end case;
--				when others =>
--			end case;
			
			case cfg_writer_flow is 
				when INIT =>
					spi_sclk											<= '0';
					spi_ssn(to_integer(unsigned(srpc.asic_id)))			<= '0';
					sconfig_state.done									<= '0';
					sconfig_state.err									<= '0'; 
					sconfig_state.errinfo 								<= (others=>'0');
					cfg_writer_flow										<= WRITING;
					if (write_1st_done = '1' and write_2nd_done = '0') then
						cfg_checker_flow	<= CHECKING; -- check only in second time write
					else
						cfg_checker_flow	<= IDLE;
					end if;
				when WRITING =>
					case spi_writing_flow is 
					-- writing is from the LSB of all the bit stream, so the MSB will be shifted into the bit0 of MuTRiG
						when CLK_LOW =>
							spi_sclk				<= '1';
							spi_wr_bit_cnt		<= conv_std_logic_vector(to_integer(unsigned(spi_wr_bit_cnt))+1, spi_wr_bit_cnt'length);
							spi_writing_flow	<= CLK_HIGH;
						when CLK_HIGH => -- this way the mosi data and clk will change on the same clock edge by using reg out
							spi_sclk				<= '0';
							spi_writing_flow	<= CLK_LOW;
						when others => 
							-- trap state for debug
					end case;
					if (to_integer(unsigned(spi_wr_bit_cnt)) >= MUTRIG_CFG_LENGTH_BIT_ROUNDUP) then
						cfg_writer_flow	<= FINISHING;
					else
						cfg_writer_flow	<= WRITING;
					end if;
				when FINISHING =>
					spi_writing_flow		<= CLK_LOW;
					spi_sclk					<= '0';
					spi_ssn(to_integer(unsigned(srpc.asic_id)))	<= '1';
					if (write_1st_done = '0') then
						write_1st_done	<= '1';
					else
						write_2nd_done	<= '1';
					end if;
					cfg_writer_flow		<= PAUSE;
				when PAUSE =>
					if (write_1st_done = '1' and write_2nd_done = '0') then -- this is the first time write
						-- reset things and go second write
						spi_wr_bit_cnt		<= (others=>'0');
						spi_sclk				<= '0';
						spi_ssn				<= (others=>'1');
						cfg_writer_flow	<= INIT;
					elsif (write_1st_done = '1' and write_2nd_done = '1') then -- this is the second time write
						-- reset things and go IDLE
						spi_wr_bit_cnt				<= (others=>'0');
						spi_sclk						<= '0';
						spi_ssn						<= (others=>'1');
						cfg_writer_flow			<= IDLE;
						sconfig_state.done		<= '1';
						sconfig_state.err			<= '0'; -- TODO: add readback errors 1) bit wrong 2) all-zeros/all-ones 
						sconfig_state.errinfo 	<= (others=>'0');
					else -- trap state
					end if;
				when IDLE =>
					spi_writing_flow			<= CLK_LOW;
					write_1st_done				<= '0';
					write_2nd_done				<= '0';
					spi_ssn						<= (others=>'1');
					if (scfg_writer_start = '1' and sconfig_state.done = '0') then
						cfg_writer_flow		<= INIT; -- start signal received, goto INIT to start writing process
					elsif (scfg_writer_start = '1' and sconfig_state.done = '1') then -- done, wait until controller ack
						cfg_writer_flow		<= IDLE;
					elsif (scfg_writer_start = '0' and sconfig_state.done = '1') then -- lower flag -- done is ack by the controller
						sconfig_state.done		<= '0';
						-- do not clear the error flags yet
					else 
						-- pure idle
					end if;
				when others =>
			end case;
		end if;
	end process proc_cfg_writer;
	
	proc_cfg_writer_comb	: process(all)
	-- cfg writer side access to the cfg_mem, derive address for the 1 bit data 
	begin
		if (cfg_writer_flow /= IDLE) then 
			cfg_mem_addrB			<= conv_std_logic_vector(asic_cfg_bit_offset(to_integer(unsigned(srpc.asic_id))) + MUTRIG_CFG_LENGTH_BIT_ROUNDUP - 1 - to_integer(unsigned(spi_wr_bit_cnt)), cfg_mem_addrB'length);
			spi_mosi				<= cfg_mem_doutB;
		else
			cfg_mem_addrB			<= conv_std_logic_vector(asic_cfg_bit_offset(to_integer(unsigned(srpc.asic_id))) + MUTRIG_CFG_LENGTH_BIT_ROUNDUP - 1, cfg_mem_addrB'length);
			spi_mosi				<= '0';
		end if;
	end process proc_cfg_writer_comb;
	
	
	--============================================================================
	--   _____ _____   _____   __  __  ____  _____  _    _ _      ______  _____ 
	--  / ____|  __ \ / ____| |  \/  |/ __ \|  __ \| |  | | |    |  ____|/ ____|
	-- | |    | |  | | |      | \  / | |  | | |  | | |  | | |    | |__  | (___  
	-- | |    | |  | | |      | |\/| | |  | | |  | | |  | | |    |  __|  \___ \ 
	-- | |____| |__| | |____  | |  | | |__| | |__| | |__| | |____| |____ ____) |
	--  \_____|_____/ \_____| |_|  |_|\____/|_____/ \____/|______|______|_____/ 
	--                                                                          
	--============================================================================                                                                          

	proc_spi2ctrl_cdc_comb : process (all)
	begin
	-- a pulsed when data is changing, thus fifo is written
		flag_spi2ctrl_wen		<= sconfig_state_d1.done xor sconfig_state.done;
		flag_spi2ctrl_din		<= '0' & sconfig_state.err & sconfig_state.errinfo & sconfig_state.done;
		-- generate read once the ctrl domain sense not empty
		if (flag_spi2ctrl_rdempty /= '1') then
			flag_spi2ctrl_rack		<= '1';
		else
			flag_spi2ctrl_rack		<= '0';
		end if;
	end process proc_spi2ctrl_cdc_comb; 
	
	
	proc_spi2ctrl_cdc_sclk : process (sclk)
	begin
		if (rising_edge(sclk)) then
			sconfig_state_d1.done	<= sconfig_state.done;
			-- TODO: if full?
		end if;
	end process proc_spi2ctrl_cdc_sclk;
	
	
	proc_spi2ctrl_cdc_cclk : process (cclk,i_rst)
	begin
		if (i_rst = '1') then
			cconfig_state.done		<= '0';
			cconfig_state.errinfo	<= (others=>'0');
			cconfig_state.err			<= '0';
		elsif (rising_edge(cclk)) then
			if (flag_spi2ctrl_rdempty /= '1') then -- if not empty, continuesly updating
				cconfig_state.done		<= flag_spi2ctrl_dout(0);
				cconfig_state.errinfo	<= flag_spi2ctrl_dout(2 downto 1);
				cconfig_state.err		<= flag_spi2ctrl_dout(3);
			else
				cconfig_state.done		<= '0';
				cconfig_state.errinfo	<= (others=>'0');
				cconfig_state.err		<= '0';
			end if;
		end if;
	end process proc_spi2ctrl_cdc_cclk;
	
	
	proc_ctrl2spi_cdc_comb : process (all)
	begin -- edge detector for the flag bits sending from controller to spi writer
		flag_ctrl2spi_wen						<= ccfg_writer_start xor ccfg_writer_start_d1;
		flag_ctrl2spi_din(0)					<= ccfg_writer_start;
		flag_ctrl2spi_din(4 downto 1)			<= rpc.asic_id;
		if (flag_ctrl2spi_rdempty /= '1') then
			flag_ctrl2spi_rack		<= '1';
		else
			flag_ctrl2spi_rack		<= '0';
		end if;
	
	end process proc_ctrl2spi_cdc_comb;
	
	
	proc_ctrl2spi_cdc_cclk : process (cclk,i_rst)
	begin
		if (i_rst = '1') then
			
		elsif (rising_edge(cclk)) then
			ccfg_writer_start_d1		<= ccfg_writer_start;
		end if;
	end process proc_ctrl2spi_cdc_cclk;
	
	
	proc_ctrl2spi_cdc_sclk : process (sclk,i_rst_spi)
	begin
		if (i_rst_spi = '1') then
			scfg_writer_start	<= '0';
			srpc.asic_id		<= (others => '0');
		elsif (rising_edge(sclk)) then
			if (flag_ctrl2spi_rdempty /= '1') then -- if not empty, continuesly updating
				scfg_writer_start		<= flag_ctrl2spi_dout(0);
				srpc.asic_id			<= flag_ctrl2spi_dout(4 downto 1);
			end if;
		end if;
	end process proc_ctrl2spi_cdc_sclk;
--    
--    mult_interval2tick : alt_lpm_mult PORT MAP (
--		clock	 => i_clk,
--		dataa	 => csr.monitor_seconds,
--		datab	 => std_logic_vector(to_unsigned(CLK_FREQUENCY/1000,20)),
--		result	 => timer_rst_tick_cnt
--	);
	--
	
end architecture rtl;


		
		
		
		
		
		
		
		
		
		
		
		
