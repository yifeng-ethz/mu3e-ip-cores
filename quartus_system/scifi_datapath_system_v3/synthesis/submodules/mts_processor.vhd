-- File name: mts_processor.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 25, 2024
-- Revision: 2.0 (seperate long/short data paths into individual entities; avoid input contention with skid-buffer;
--		collects hit loss in data path switching and input flow congestion)
--		Date: Mar 28, 2024 
-- Revision: 3.0 (clean up)
--		Date: Jun 26, 2024
-- Revision: 4.0 (Re-write)
--		Date: Jul 2, 2024
-- Revision: 5.0 (Support new hit type0b with same throughput as type0a)
--      Date: Sep 24, 2025 
-- Revision: 5.1 (Drive terminating end-of-run EOP on the final payload beat)
--      Date: Mar 30, 2026
-- Revision: 5.2 (Restore divider launch from hit_padding and reset bypass_lapse)
--      Date: Apr 2, 2026
-- Revision: 5.3 (Revert divider datapath to committed form and keep terminating EOP support)
--      Date: Apr 2, 2026
-- Revision: 5.4 (Drive hit_type1 sideband channel from ts interleaving for hit-stack routing)
--      Date: Apr 2, 2026
-- Revision: 5.5 (Keep shallow divider/EOP delay lines in FFs to close standalone timing)
--      Date: Apr 13, 2026
-- Revision: 5.6 (Stabilize white-timestamp simulation math and clamp negative ToT)
--      Date: Apr 14, 2026
-- Revision: 5.7 (Make run-control ready stateful and preserve terminate markers through idle drain)
--      Date: Apr 15, 2026
-- Revision: 5.8 (Wait for explicit upstream end-of-run before emitting lane-close markers)
--      Date: Apr 16, 2026
-- Version : 26.0.2
-- Date    : 20260416
-- Change  : Consume a dedicated hit_type0_endofrun sideband from frame_rcv_ip and emit lane-close markers
--           only after the upstream run tail and the local divider pipeline are both fully drained.
-- =========
-- Description:	[MuTRiG Timestamp Processor] 
    -- Processes the Timestamp TCC (15 bit)(1.6 ns) into TCC_8n (13 bit) and TCC_1n6 (3 bit).:
    -- 		1) decode the TCC_s from FLSR state symbol into unsigned binary of incresing TCC_b
    --		2) devide by 5 to calculate remainder and divison
    --		3) (optional) do this also for ECC
    --		4) (optional) calculate: ECC_1n6 - TCC_1n6 = ET_1n6 (9 bit)
    -- Integrity validation (optional):
    -- 		1) Filter hits with hiterr from assembly. 
    --		2) Ignore frame with crcerr from assembly. (this needs pre-buffer of a whole packet in the input FIFO, undetermistic delay)
    --		3) Ignore links with frame_corrupt from assembly. (this masks the links in error state)
    -- 
    -- Data type:
    --	Input [hit type 0]:
    --		asic	4
    --		ch		5
    --		TCC		15
    --		TFine	5
    --		ECC		15
    --		EFlag	1
    -- =================
    --		Total	45
    --
    -- Output [hit type 1a/b] (a=short/scifi mode; b=long/tile mode) :
    --		asic	4
    --		ch		5
    --		TCC_8n	13
    --		TCC_1n6	3
    --		TFine	5
    --		ET_1n6	9	(for type 1b, E-T; for type 1a, =all "0"s while EFlag=0 / =all "1"s while EFlag=1)
    -- ==================
    --		Total	39
    -- (a and b are automatically switch over, depending on the current hit flag from the upstream mutrig_frame_assembly. 
    
    -- Latency: 
    -- 		
    --
    -- Throughput: (f_clk=125 MHz)
    --		Hit type 0a (short) (4 links in / 1 ROM port)			 1 * f_clk   		< 4 * f_clk / 3.5 	(expected)
    --		Hit type 0b (long)  (4 links in / 2 ROM port)		     1 * f_clk   		> 4 * f_clk / 6 	(expected)
    -- 
    -- Comments: 
    --		1) Use Simple-DP ROM, with pre-calculated LUT, rather than True-DP RAM, with on-the-fly LUT calculation,
    --		reduces the RAM usage by half.
    --		2) For scifi (short hit), it connects 4 frame_assembly, from the same bank. This will not induce time-stamp re-order.
    --		This will not induce backpressure.
    --		3) For tile (long hit), it connects 4 frame_assembly, from four different banks. This will not induce time-stamp re-order.
    --		This will not induce backpressure.
    --		4) Always in-order processing per link, i.e. no pre-fetch of a link. First decode link 0-1, then decode link 2-3, in total 2 cycles.
    --		If there is no hit in that link, go idle, do not pre-fetch other links. The hits are expect to appear in the next 3.5-6 cycles, so
    --		the buffer depth is 2, 
    --		5) Arbitration is required to combinationally, decide which hits gets looked up and sequently in the pipeline 
    -- Resource usage:
    --		1) 1 DP-RAM for symbol decode. 
    
-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;

LIBRARY lpm; 
USE lpm.lpm_components.all;

entity mts_processor is 
generic (
    FRAME_CORRPT_BIT_LOC	: natural := 2; -- error channel descriptor bit locations of sink streaming interface
    CRCERR_BIT_LOC			: natural := 1;
    HITERR_BIT_LOC			: natural := 0;
    BANK					: string := "UP"; -- not used, output asic id is set by input asic id
    ENABLED_CHANNEL_HI		: natural := 3; -- must be within 0-15, used for generate eop for enabled channels
    ENABLED_CHANNEL_LO		: natural := 0;
    PADDING_EOP_WAIT_CYCLE	: natural := 512; -- set the wait grace period to generating eop of each link at end of run. note: backpressure fifo depth (128) x enabled_channel (4)
    LPM_DIV_PIPELINE		: natural := 4;
    MUTRIG_BUFFER_EXPECTED_LATENCY_8N		: natural := 2000; -- affects the error signal on <hit_type1>
    DEBUG					: natural := 1
);
port (

    -- avmm-slave
    -- CSR 
    avs_csr_readdata				: out std_logic_vector(31 downto 0);
    avs_csr_read					: in  std_logic;
    avs_csr_address					: in  std_logic_vector(2 downto 0);
    avs_csr_waitrequest				: out std_logic; 
    avs_csr_write					: in  std_logic;
    avs_csr_writedata				: in  std_logic_vector(31 downto 0);
    
    -- ============ INPUT ==============
    -- input stream of raw hits
    asi_hit_type0_channel			: in  std_logic_vector(5 downto 0); -- for asic 0-15 (4 bit) + 2 msb for mux sel channel (binary, redundant)
    asi_hit_type0_startofpacket		: in  std_logic; -- mutrig frame
    asi_hit_type0_endofpacket		: in  std_logic;
    asi_hit_type0_endofrun			: in  std_logic;
    asi_hit_type0_error				: in  std_logic_vector(2 downto 0); 
    -- frame_corrupt & crcerr & hiterr
        -- crcerr available at "eop"
        -- hiterr available at "valid"
    asi_hit_type0_data				: in  std_logic_vector(44 downto 0); -- valid is a seperate signal below
    asi_hit_type0_valid 			: in  std_logic;
    asi_hit_type0_ready				: out std_logic;
    
    -- ============ OUTPUT ==============
    -- output stream of processed hits (TODO: add back-pressure)
    aso_hit_type1_channel			: out  std_logic_vector(3 downto 0); -- routing index for downstream hit-stack splitter; ASIC ID stays in data[38:35]
    aso_hit_type1_startofpacket		: out  std_logic; -- marks the start and end of run
    aso_hit_type1_endofpacket		: out  std_logic;
    aso_hit_type1_data				: out  std_logic_vector(38 downto 0);
    aso_hit_type1_valid				: out  std_logic; 
    aso_hit_type1_ready				: in   std_logic; 
    aso_hit_type1_empty				: out  std_logic; -- TODO: marks the eor of this mutrig link (avst-channel), if theeor cycle does not contain hit.
    -- add an individual fifo for each channel, give an option to release last packet when next sop is seen
    -- the cache stack will not deassert ready, since it has input fifo (with 1 pop head, write is always possible, only when really full, overwrite takes 2 cycle and pop takes 1 cycle, ov can happen), 
    -- in case of overflow, such information should be collected by upstream, such as this mts processor
    aso_hit_type1_error             : out std_logic; -- { tserr : possible wrong timestamp }
                                                                        -- tserr is asserted to indicate this hit timestamp is not within the range of (0-2000 cycles delay)
                                                                        -- the upstream (ring-buffer cam) should ignore this hit as it is not meaningful. 
    

    -- input stream of control signal (enable)
    -- this signal is time critical and must be synchronzed for all datapath modules
    asi_ctrl_data			: in  std_logic_vector(8 downto 0); 
    -- ====================================
    -- Command				Code	Payload 
    -- ====================================
    -- Run Prepare			0x10	32 bit run number
    -- Sync					0x11	-
    -- Start Run			0x12	-
    -- End Run				0x13	-
    -- Abort Run			0x14	-
    -- ____________________________________
    -- Start Link Test		0x20
    -- Stop Link Test		0x21	-
    -- Start Sync Test 		0x24
    -- Stop Sync Test		0x25	-
    -- Test Sync			0x26
    -- ____________________________________
    -- Reset				0x30	16 bit mask
    -- Stop Reset			0x31	16 bit mask
    -- Enable 				0x32	
    -- Disable				0x33
    -- ____________________________________
    -- Address				0x40	16 bit address
    
    -- ===============================
    -- #: State  (9 states)
    -- ===============================
    -- 0: IDLE						
    -- 1: RUN_PREPARE				
    -- 2: SYNC (reset active)		
    -- 3: RUNNING					
    -- 4: TERMINATING
    -- 5: LINK_TEST
    -- 6: SYNC_TEST
    -- 7: RESET
    -- 8: OUT_OF_DAQ
    asi_ctrl_valid			: in  std_logic;
    asi_ctrl_ready			: out std_logic;
    
    -- AVST <debug_ts> 
    -- debug port (showing the time difference of gts - mts)
    aso_debug_ts_valid		: out std_logic;
    aso_debug_ts_data		: out std_logic_vector(15 downto 0);
    
    -- AVST <debug_burst> 
    aso_debug_burst_valid		: out std_logic;
    aso_debug_burst_data		: out std_logic_vector(15 downto 0);

    -- AVST <ts_delta>
    -- signed delta timestamp between adjacent accepted hits
    aso_ts_delta_valid          : out std_logic;
    aso_ts_delta_data           : out std_logic_vector(15 downto 0);

    -- clock and reset interface
    i_rst                   : in std_logic; -- async reset assertion, sync reset release
    i_clk                   : in std_logic -- clock should match the lvds parallel clock (125MHz)
);
end entity mts_processor;

architecture rtl of mts_processor is
    
    -- constants
    constant OP_MODE_HI             : natural := 30;
    constant OP_MODE_LO             : natural := 28;
    constant I_ASIC_HI				: natural := 44;
    constant I_ASIC_LO				: natural := 41;
    constant I_CHANNEL_HI			: natural := 40;
    constant I_CHANNEL_LO			: natural := 36;
    constant I_TCC_HI				: natural := 35;
    constant I_TCC_LO				: natural := 21;
    constant I_TFINE_HI				: natural := 20;
    constant I_TFINE_LO				: natural := 16;
    constant I_ECC_HI				: natural := 15;
    constant I_ECC_LO				: natural := 1;
    constant I_EFLAG_BIT_LOC		: natural := 0;
    constant O_ASIC_HI				: natural := 38;
    constant O_ASIC_LO				: natural := 35;
    constant O_CHANNEL_HI			: natural := 34;
    constant O_CHANNEL_LO			: natural := 30;
    constant O_TCC8N_HI				: natural := 29;
    constant O_TCC8N_LO				: natural := 17;
    constant O_TCC1n6_HI			: natural := 16;
    constant O_TCC1n6_LO			: natural := 14;
    constant O_TFINE_HI				: natural := 13;
    constant O_TFINE_LO				: natural := 9;
    constant O_ET1n6_HI				: natural := 8;
    constant O_ET1n6_LO				: natural := 0;
    

    -- global control signals 
    -- type mutrig_hit_mode_t is (SHORT, LONG, PRBS);
    -- signal mutrig_hit_mode			: mutrig_hit_mode_t := SHORT;
    
    -- hit record types
    type hit_type0_t is record -- total 45 bits + etc
        asic            : std_logic_vector(3 downto 0);  --ASIC ID
        channel         : std_logic_vector(4 downto 0);  --Channel number
        t_cc            : std_logic_vector(14 downto 0); --T-Trigger coarse time value (1.6ns)
        t_fine          : std_logic_vector(4 downto 0);  --T-Trigger fine time value
        e_cc            : std_logic_vector(14 downto 0); --Energy coarse time value (in units of 1.6ns)
        e_flag          : std_logic;                     --E-Flag valid flag
        valid           : std_logic;                     --data word valid flag
        hiterr			: std_logic;
    end record;
    signal hit_in		: hit_type0_t;
    
    type hit_padding_t is record -- total 45 bits + etc
        asic            : std_logic_vector(3 downto 0);  --ASIC ID
        channel         : std_logic_vector(4 downto 0);  --Channel number
        cc_out          : std_logic_vector(14 downto 0); --###Decoded from LUT RAM###
        ecc_out			: std_logic_vector(14 downto 0); --###Decoded from LUT RAM###
        tot_t_adjust    : std_logic;                     --Latched overflow-window correction for T path
        tot_e_adjust    : std_logic;                     --Latched overflow-window correction for E path
        t_fine          : std_logic_vector(4 downto 0);  --T-Trigger fine time value
        e_cc            : std_logic_vector(14 downto 0); --Energy coarse time value (in units of 1.6ns)
        e_flag          : std_logic;                     --E-Flag valid flag
        valid           : std_logic;                     --data word valid flag
        hiterr			: std_logic;
    end record;
    signal hit_padding	: hit_padding_t;
    
    type div_pipeline_stage_t is record -- total 45 bits + etc
        asic            : std_logic_vector(3 downto 0);  --ASIC ID
        channel         : std_logic_vector(4 downto 0);  --Channel number
        --t_cc            : std_logic_vector(14 downto 0); --T-Trigger coarse time value (1.6ns) -- this part is seperated pipelined by lpm_div
        t_fine          : std_logic_vector(4 downto 0);  --T-Trigger fine time value
        e_cc            : std_logic_vector(14 downto 0); --Energy coarse time value (in units of 1.6ns)
        et_1n6			: std_logic_vector(8 downto 0); -- E-T part (calculated with 50 bits)
        e_flag          : std_logic;                     --E-Flag valid flag
        valid           : std_logic;                     --data word valid flag
        hiterr			: std_logic;
    end record;
    type div_pipeline_t is array (0 to LPM_DIV_PIPELINE) of div_pipeline_stage_t;
    signal hit_div		: div_pipeline_t;
    
    type hit_type1_t is record -- total 39 bits + xx.int
        asic            : std_logic_vector(3 downto 0);  	-- ASIC ID
        channel         : std_logic_vector(4 downto 0);  	-- Channel number
        tcc_8n          : std_logic_vector(12 downto 0); 	-- 8n
        tcc_1n6         : std_logic_vector(2 downto 0);  	-- 1.6ns	
        tfine			: std_logic_vector(4 downto 0);		-- 50ps
        et_1n6			: std_logic_vector(8 downto 0); 	-- E-T (for type 1b, E-T; for type 1a, =all "0"s while EFlag=0 / =all "1"s while EFlag=1)
        valid			: std_logic;
        hiterr			: std_logic;
    end record;
    signal hit_out		: hit_type1_t;

    -- run state signals
    -- type running_hit_mode_t is (SHORT,LONG,PRBS,UNKNOWN);
    -- signal running_hit_mode			: running_hit_mode_t;
    
    type processor_state_t is (RUNNING, RESET, IDLE, FLUSHING, ERROR);
    signal processor_state		: processor_state_t;
    
    type reset_flow_t is (SCLR,SYNC,DONE);
    signal reset_flow 			: reset_flow_t;
    
    type run_state_t is (IDLE, RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST, SYNC_TEST, RESET, OUT_OF_DAQ, ERROR);
    signal run_state_cmd	: run_state_t;
    signal terminating_done : std_logic;
    signal ctrl_ready_comb  : std_logic;
    
    -- processor
    constant ROUTE_LANE_COUNT_CONST      : natural := 4;
    constant ROUTE_LANE_BITS_CONST       : natural := 2;
    constant ROUTE_TERMINATED_ALL_CONST  : std_logic_vector(ROUTE_LANE_COUNT_CONST - 1 downto 0) := (others => '1');
    signal route_startofrun_sent         : std_logic_vector(ROUTE_LANE_COUNT_CONST - 1 downto 0);
    signal route_terminate_sent          : std_logic_vector(ROUTE_LANE_COUNT_CONST - 1 downto 0);
    signal hit_in_ok						: std_logic;
    signal processor_allow_input			: std_logic;
    signal upstream_endofrun_seen        : std_logic;
    
    -- data and control path signals 
    type csr_t is record 
        go                      : std_logic;
        force_stop              : std_logic;
        soft_reset              : std_logic;
        derive_tot              : std_logic;
        delay_ts_field_use_t    : std_logic;
        bypass_lapse            : std_logic;
        discard_hiterr          : std_logic;
        expected_latency        : std_logic_vector(31 downto 0);
    end record;
    signal csr                  : csr_t;
    
    type debug_msg_t is record
        discard_hit_cnt		: unsigned(31 downto 0);
        total_hit_cnt		: unsigned(47 downto 0);
    end record;
    signal debug_msg		: debug_msg_t;
    
    -- dual port rom (2^15 depth - 15 bit wide)
    component dual_port_rom
    generic (
        DATA_WIDTH	: natural := 15;
        ADDR_WIDTH	: natural := 15
    );	
    port (
        addr_a		: in  std_logic_vector(14 downto 0);
        q_a			: out std_logic_vector(14 downto 0);
        addr_b		: in  std_logic_vector(14 downto 0);
        q_b			: out std_logic_vector(14 downto 0);
        clk			: in  std_logic
    );
    end component dual_port_rom;
    signal cc_in,cc_out			: std_logic_vector(14 downto 0);
    signal ecc_in,ecc_out		: std_logic_vector(14 downto 0);
    
    
    
    -- counter (gts)
    component LPM_COUNTER
    generic ( 
        LPM_WIDTH 		: natural; 
        LPM_MODULUS 	: natural := 0;
        LPM_DIRECTION 	: string := "UNUSED";
        LPM_AVALUE 		: string := "UNUSED";
        LPM_SVALUE 		: string := "UNUSED";
        LPM_PORT_UPDOWN : string := "PORT_CONNECTIVITY";
        LPM_PVALUE 		: string := "UNUSED";
        LPM_TYPE 		: string := L_COUNTER;
        LPM_HINT 		: string := "UNUSED");
    port (
        DATA 	: in std_logic_vector(LPM_WIDTH-1 downto 0):= (OTHERS => '0');
        CLOCK 	: in std_logic ;
        CLK_EN 	: in std_logic := '1';
        CNT_EN 	: in std_logic := '1';
        UPDOWN 	: in std_logic := '1';
        SLOAD 	: in std_logic := '0';
        SSET 	: in std_logic := '0';
        SCLR 	: in std_logic := '0';
        ALOAD 	: in std_logic := '0';
        ASET 	: in std_logic := '0';
        ACLR 	: in std_logic := '0';
        CIN 	: in std_logic := '1';
        COUT 	: out std_logic := '0';
        Q 		: out std_logic_vector(LPM_WIDTH-1 downto 0);
        EQ 		: out std_logic_vector(15 downto 0));
    end component;
    
    -- multiplier
    component LPM_MULT
    generic ( 	
        LPM_WIDTHA 		: natural; 
        LPM_WIDTHB 		: natural;
        LPM_WIDTHS 		: natural := 1;
        LPM_WIDTHP 		: natural;
        LPM_REPRESENTATION 	: string := "UNSIGNED";
        LPM_PIPELINE 	: natural := 0;
        LPM_TYPE		: string := L_MULT;
        LPM_HINT 		: string := "UNUSED"
    );
    port (
        DATAA 	: in std_logic_vector(LPM_WIDTHA-1 downto 0);
        DATAB 	: in std_logic_vector(LPM_WIDTHB-1 downto 0);
        ACLR 	: in std_logic := '0';
        CLOCK 	: in std_logic := '0';
        CLKEN 	: in std_logic := '1';
        SUM 	: in std_logic_vector(LPM_WIDTHS-1 downto 0) := (OTHERS => '0');
        RESULT 	: out std_logic_vector(LPM_WIDTHP-1 downto 0)
    );
    end component;
    
    -- multiplier	
    constant LPM_MULT_PIPELINE			: natural := 10;
    -- padding_logic_comb (tcc (15bit) -> cc_gts_1n6_slv50 (50bit))
    constant OVERFLOW_1N6				: integer := 32766;
    constant OVERFLOW_TIME_1N6			: integer := OVERFLOW_1N6 + 1; 
    -- NOTE: mutrig overflow at 2^15-2=32766 (counting from 0), but takes 2^15-1=32767 * 1.6ns. So we plus 1 here.
    --		 when calculating the time, we use OVERFLOW_TIME_1N6.
    --		 when count up, we use OVERFLOW_1N6.
    constant UPPER						: integer := OVERFLOW_1N6 - MUTRIG_BUFFER_EXPECTED_LATENCY_8N*5; -- 2000 (deprecated)
    signal expected_latency_1n6         : unsigned(31 downto 0);
    signal padding_upper                : unsigned(14 downto 0); -- adjustable by csr, in 1.6 ns ticks
    signal padding_logic_gray_ts		: unsigned(14 downto 0);
    signal padding_logic_gray_ts_e		: unsigned(14 downto 0);
    signal padding_logic_white_ts		: unsigned(49 downto 0);
    signal padding_logic_white_ts_e		: unsigned(49 downto 0);
    signal cc_gts_1n6_slv50				: std_logic_vector(49 downto 0);
    signal ecc_gts_1n6_slv50			: std_logic_vector(49 downto 0);
    signal padding_logic_gts_product	: std_logic_vector(49 downto 0);
    
    -- divider 
    component LPM_DIVIDE
    generic (
        LPM_WIDTHN 			: natural;
        LPM_WIDTHD 			: natural;
        LPM_NREPRESENTATION : string := "UNSIGNED";
        LPM_DREPRESENTATION : string := "UNSIGNED";
        LPM_PIPELINE 		: natural := 0;
        LPM_TYPE 			: string := L_DIVIDE;
        LPM_HINT 			: string := "LPM_REMAINDERPOSITIVE=TRUE"
    );
    port (
        NUMER 			: in  std_logic_vector(LPM_WIDTHN-1 downto 0);
        DENOM 			: in  std_logic_vector(LPM_WIDTHD-1 downto 0);
        ACLR 			: in  std_logic := '0';
        CLOCK 			: in  std_logic := '0';
        CLKEN 			: in  std_logic := '1';
        QUOTIENT 		: out std_logic_vector(LPM_WIDTHN-1 downto 0);
        REMAIN 			: out std_logic_vector(LPM_WIDTHD-1 downto 0)
    );
    end component LPM_DIVIDE; 
    constant LPM_DIV_WIDTHN : natural := 50;
    signal tcc_div_numer    : std_logic_vector(LPM_DIV_WIDTHN-1 downto 0);
    signal ecc_div_numer    : std_logic_vector(LPM_DIV_WIDTHN-1 downto 0); 
    signal tcc_div_quotient : std_logic_vector(LPM_DIV_WIDTHN-1 downto 0);
    signal ecc_div_quotient : std_logic_vector(LPM_DIV_WIDTHN-1 downto 0);
    signal tcc_div_remain   : std_logic_vector(2 downto 0);
    signal ecc_div_remain   : std_logic_vector(2 downto 0);

    type prediv_stage_t is record
        asic            : std_logic_vector(3 downto 0);
        channel         : std_logic_vector(4 downto 0);
        t_fine          : std_logic_vector(4 downto 0);
        e_flag          : std_logic;
        hiterr          : std_logic;
        valid           : std_logic;
        t_gray_corr     : signed(16 downto 0);
        e_gray_corr     : signed(16 downto 0);
        tcc_div_numer   : std_logic_vector(LPM_DIV_WIDTHN-1 downto 0);
        ecc_div_numer   : std_logic_vector(LPM_DIV_WIDTHN-1 downto 0);
    end record;
    signal hit_prediv    : prediv_stage_t;
    

    
    -- counter mts
    signal counter_mts_1n6			: unsigned(14 downto 0);
    signal counter_ov_cnt			: unsigned(31 downto 0); -- can be tuned
    signal counter_ov_cnt_reg		: unsigned(31 downto 0);
    signal fpga_overflow_happened			: std_logic;
    signal fpga_overflow_lookback_cnt		: unsigned(31 downto 0);
    signal lpm_multi_valid_cnt              : unsigned(15 downto 0);
    signal overflow_adjust_active           : std_logic;
    -- counter gts 
    signal counter_gts_8n					: unsigned(47 downto 0); -- can be tuned
    
    -- terminate / per-run close markers
    constant N_ENABLED_CHANNEL          : natural := ENABLED_CHANNEL_HI - ENABLED_CHANNEL_LO + 1;
    signal packet_in_transaction        : std_logic_vector(N_ENABLED_CHANNEL-1 downto 0);
    signal hit_div_busy                 : std_logic;
    signal input_pipeline_busy          : std_logic;
    signal terminating_marker_valid     : std_logic;
    signal terminating_marker_lane      : std_logic_vector(ROUTE_LANE_BITS_CONST - 1 downto 0);
    signal terminating_marker_sop       : std_logic;

    attribute altera_attribute : string;
    -- Keep the short divider pipeline in FFs; MLAB shift inference hurts the
    -- standalone timing of the signoff bench.
    attribute altera_attribute of hit_div : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
    
    
    -- debug_ts 
    signal int_aso_debug_ts_valid   : std_logic; -- delay 1 cycle for valid signal 
    signal int_aso_debug_ts_data    : std_logic_vector(aso_debug_ts_data'high downto 0); -- for read internally. note: you could also use "buffer" instead of "out" of this port, but its support is poor across platform.
    
    -- ///////////////////////////////////////////////////////////////////////////////
    -- debug_burst
    -- ///////////////////////////////////////////////////////////////////////////////
    signal egress_valid             : std_logic;
    signal delta_valid              : std_logic;
    
    type egress_regs_t is array(0 to 1) of std_logic_vector(47 downto 0);
    signal egress_timestamp         : egress_regs_t;
    signal egress_arrival           : egress_regs_t;
    
    constant DELTA_TIMESTAMP_WIDTH            : natural := 12; -- ex: 10 bit, range is -512 to 511, triming 2 bits yields -> -128 to 127
    constant DELTA_ARRIVAL_WIDTH              : natural := 12; -- ex: 10 bit, range is 0 to 1023, triming 2 bits yields -> 0 to 255
    signal delta_timestamp          : std_logic_vector(DELTA_TIMESTAMP_WIDTH-1 downto 0);
    signal delta_arrival            : std_logic_vector(DELTA_ARRIVAL_WIDTH-1 downto 0);

    function signmag_to_twos_comp16(
        signmag_value : std_logic_vector
    ) return std_logic_vector is
        variable magnitude_v : signed(15 downto 0) := (others => '0');
        variable result_v    : std_logic_vector(15 downto 0) := (others => '0');
    begin
        if signmag_value'length > 1 then
            magnitude_v := resize(
                signed('0' & signmag_value(signmag_value'high - 1 downto 0)),
                magnitude_v'length
            );
            if signmag_value(signmag_value'high) = '1' then
                return std_logic_vector(-magnitude_v);
            end if;
            return std_logic_vector(magnitude_v);
        end if;
        return result_v;
    end function signmag_to_twos_comp16;
    
    
    
    -- ----------------------------
    -- data flow chart
    -- ----------------------------
    -- Legend:
    --		Dark TS: non yet decoded, the lfsr output raw symbol of MuTRiG
    --		Gray TS: decoded, the lfsr cycle of MuTRiG, so called MuTRiG timestamp (mts)
    --		White TS: padded to 50 bit according to global timestamp counter (overflow round)
    --		TS 8n: mu3e global timestamp (gts) with 8ns step, to be output to the hit cache. 
    
    -- mts -> gts mapping: 
    --		1) Padding 2) Divide by 5
    
    

begin

    -- Carry the overflow-correction window alongside the hit so late ToT
    -- arithmetic no longer depends directly on the live overflow counter.
    -- The multiplier output becomes valid on the cycle where the countdown
    -- reaches 1, while a hit captured on that same edge still sees the
    -- pre-update register value. Accept the final countdown cycle here so the
    -- first post-product hit also latches the overflow adjustment.
    overflow_adjust_active <= '1' when (
        fpga_overflow_lookback_cnt /= to_unsigned(0, fpga_overflow_lookback_cnt'length)
        and lpm_multi_valid_cnt <= to_unsigned(1, lpm_multi_valid_cnt'length)
    ) else '0';

    asi_ctrl_ready <= ctrl_ready_comb;
    ctrl_ready_comb <= '0' when i_rst = '1' else
                      '1' when (run_state_cmd = IDLE and processor_state = IDLE) else
                      '1' when (run_state_cmd = RUN_PREPARE and processor_state = RESET and reset_flow = SCLR) else
                      '1' when (run_state_cmd = SYNC and processor_state = RESET and reset_flow = SYNC) else
                      '1' when (run_state_cmd = RUNNING and processor_state = RUNNING) else
                      '1' when (run_state_cmd = TERMINATING and processor_state = FLUSHING and terminating_done = '1') else
                      '0';

    proc_terminating_marker_comb : process (all)
        variable div_busy_v        : std_logic;
        variable pipeline_busy_v   : std_logic;
        variable marker_found_v    : std_logic;
        variable marker_lane_v     : std_logic_vector(ROUTE_LANE_BITS_CONST - 1 downto 0);
    begin
        div_busy_v      := '0';
        pipeline_busy_v := '0';
        marker_found_v  := '0';
        marker_lane_v   := (others => '0');

        for i in 0 to LPM_DIV_PIPELINE loop
            if (hit_div(i).valid = '1') then
                div_busy_v := '1';
            end if;
        end loop;

        if (
            asi_hit_type0_valid = '1'
            or hit_in.valid = '1'
            or hit_padding.valid = '1'
            or hit_prediv.valid = '1'
            or div_busy_v = '1'
            or hit_out.valid = '1'
            or packet_in_transaction /= (packet_in_transaction'range => '0')
        ) then
            pipeline_busy_v := '1';
        end if;

        hit_div_busy <= div_busy_v;
        input_pipeline_busy <= pipeline_busy_v;

        if (processor_state = FLUSHING and upstream_endofrun_seen = '1' and pipeline_busy_v = '0') then
            for lane in 0 to ROUTE_LANE_COUNT_CONST - 1 loop
                if (marker_found_v = '0' and route_terminate_sent(lane) = '0') then
                    marker_found_v := '1';
                    marker_lane_v  := std_logic_vector(to_unsigned(lane, ROUTE_LANE_BITS_CONST));
                end if;
            end loop;
        end if;

        terminating_marker_valid <= marker_found_v;
        terminating_marker_lane  <= marker_lane_v;
        if (marker_found_v = '1' and route_startofrun_sent(to_integer(unsigned(marker_lane_v))) = '0') then
            terminating_marker_sop <= '1';
        else
            terminating_marker_sop <= '0';
        end if;

        if (
            processor_state = FLUSHING
            and upstream_endofrun_seen = '1'
            and pipeline_busy_v = '0'
            and route_terminate_sent = ROUTE_TERMINATED_ALL_CONST
        ) then
            terminating_done <= '1';
        else
            terminating_done <= '0';
        end if;
    end process;

    -- debug
    --asi_hit_type0_ready		<= i_issp_ready;
    
    cc_lut : dual_port_rom
    -- input: dark ts (asi_hit_type0_data(I_TCC_HI downto I_TCC_LO)
    -- output: gray ts (cc_out from lut_ram)	
    port map(
        addr_a		=> cc_in,
        q_a			=> cc_out,
        addr_b		=> ecc_in,
        q_b			=> ecc_out,
        clk			=> i_clk
    );
    
    tcc_div : LPM_DIVIDE
    -- input: white tts 
    -- output: white tts 8n
    generic map (
        LPM_WIDTHN				=> LPM_DIV_WIDTHN,
        LPM_WIDTHD				=> 3,
        LPM_NREPRESENTATION		=> "UNSIGNED",
        LPM_DREPRESENTATION		=> "UNSIGNED",
        LPM_PIPELINE			=> LPM_DIV_PIPELINE,
        LPM_TYPE				=> "L_DIVIDE"
    )
    port map (
        CLOCK 				=> i_clk,
        NUMER				=> tcc_div_numer,
        DENOM				=> std_logic_vector(to_unsigned(5,3)),
        QUOTIENT			=> tcc_div_quotient,
        REMAIN				=> tcc_div_remain
    );

    ecc_div : LPM_DIVIDE
    -- input: white ets 
    -- output: white ets 8n
    generic map (
        LPM_WIDTHN				=> LPM_DIV_WIDTHN,
        LPM_WIDTHD				=> 3,
        LPM_NREPRESENTATION		=> "UNSIGNED",
        LPM_DREPRESENTATION		=> "UNSIGNED",
        LPM_PIPELINE			=> LPM_DIV_PIPELINE,
        LPM_TYPE				=> "L_DIVIDE"
    )
    port map (
        CLOCK 				=> i_clk,
        NUMER				=> ecc_div_numer,
        DENOM				=> std_logic_vector(to_unsigned(5,3)),
        QUOTIENT			=> ecc_div_quotient, -- used for delay calculation only if csr.delay_ts_field_use_t=0
        REMAIN				=> ecc_div_remain
    );
    
    of2gts_mult : LPM_MULT
    generic map ( 	
        LPM_WIDTHA 		=> 32, -- counter_ov_cnt
        LPM_WIDTHB 		=> 15, -- OVERFLOW_TIME_1N6
        LPM_WIDTHS 		=> 15, -- hit_padding.cc_out
        LPM_WIDTHP 		=> 50, -- cc_gts_1n6_slv50
        LPM_REPRESENTATION 	=> "UNSIGNED",
        LPM_PIPELINE 	=> LPM_MULT_PIPELINE
    )
    port map (
        DATAA 		=> std_logic_vector(counter_ov_cnt),
        DATAB 		=> std_logic_vector(to_unsigned(OVERFLOW_TIME_1N6,15)), 
        ACLR 		=> i_rst,
        CLOCK 		=> i_clk,
        CLKEN 		=> '1',
        SUM 		=> (14 downto 0 => '0'),
        RESULT 		=> padding_logic_gts_product
    );
    
    proc_run_control_mgmt_agent : process (i_rst, i_clk)
        variable decoded_run_state_v : run_state_t;
    begin
        if (i_rst = '1') then 
            run_state_cmd		<= IDLE;
        elsif (rising_edge(i_clk)) then
            decoded_run_state_v := run_state_cmd;
            if (asi_ctrl_valid = '1') then 
                case asi_ctrl_data is 
                    when "000000001" =>
                        decoded_run_state_v := IDLE;
                    when "000000010" => 
                        decoded_run_state_v := RUN_PREPARE;
                    when "000000100" =>
                        decoded_run_state_v := SYNC;
                    when "000001000" =>
                        decoded_run_state_v := RUNNING;
                    when "000010000" =>
                        decoded_run_state_v := TERMINATING;
                    when "000100000" => 
                        decoded_run_state_v := LINK_TEST;
                    when "001000000" =>
                        decoded_run_state_v := SYNC_TEST;
                    when "010000000" =>
                        decoded_run_state_v := RESET;
                    when "100000000" =>
                        decoded_run_state_v := OUT_OF_DAQ;
                    when others =>
                        decoded_run_state_v := ERROR;
                end case;
            end if;
            run_state_cmd <= decoded_run_state_v;
        end if;
    end process;
        
    
    
    proc_avmm_csr : process (i_rst,i_clk)
        variable csr_v_expected_latency_1n6 : unsigned(expected_latency_1n6'range);
    -- avalon memory-mapped interface for accessing the control and status registers
    -- address map:
    -- 		0: control and status 
    --		1: discard hits count
    --		2: expected mutrig buffering latency in 8ns 
    --		3: total hits count (H) (incl. errors)
    --		4: total hits count (L)
    begin
        if (i_rst = '1') then 
            csr.go                      <= '1'; -- NOTE: default is go. If go is low, cmd from run_state_controller cannot send processor to run state.
            csr.force_stop              <= '0';
            csr.soft_reset              <= '0'; -- only reset counters for now
            csr.derive_tot              <= '0';
            csr.delay_ts_field_use_t    <= '1';
            csr.bypass_lapse            <= '0';
            csr.expected_latency        <= std_logic_vector(to_unsigned(MUTRIG_BUFFER_EXPECTED_LATENCY_8N, csr.expected_latency'length));
            expected_latency_1n6        <= to_unsigned(MUTRIG_BUFFER_EXPECTED_LATENCY_8N * 5, expected_latency_1n6'length);
            padding_upper               <= to_unsigned(OVERFLOW_1N6 - (MUTRIG_BUFFER_EXPECTED_LATENCY_8N * 5), padding_upper'length);
            csr.discard_hiterr          <= '1'; -- NOTE: default is discard hiterr
        elsif (rising_edge(i_clk)) then
            -- default
            avs_csr_waitrequest         <= '1'; 
            avs_csr_readdata            <= (others => '0');
            -- write logic
            if (avs_csr_write = '1') then 
                avs_csr_waitrequest             <= '0'; -- ack 
                case to_integer(unsigned(avs_csr_address)) is -- addr map
                    when 0 =>
                        csr.go                  <= 	avs_csr_writedata(0);
                        csr.force_stop          <=  avs_csr_writedata(1);
                        csr.soft_reset          <=	avs_csr_writedata(2);
                        csr.bypass_lapse        <=  avs_csr_writedata(3);
                        csr.discard_hiterr      <= 	avs_csr_writedata(4);
                        -- 3-bit of op mode 
                        -- [2] derive tot : 1=long, 0=short (def). Decode E branch and validate E-BadHit. Output format go to type1b.
                        csr.derive_tot        <= avs_csr_writedata(OP_MODE_LO + 2);
                        -- [1] delay ts field : 1=use T (def), 0=use E. Calc delay using T or E timestamp. Used when hit tuple has different meanings. 
                        --                      ref to https://bitbucket.org/mu3e/online/wiki/mutrig_hitTx
                        --
                        -- Note : mutrig hit format and e-branch on this setting
                        -- Using TDC injection: 
                        --      In short mode and recv_all=1, use T. 
                        --      In long mode and recv_all=1, use E (hit will be tuple of last crossing, as no e branch, hit[i].ets is hit[i].injt and hit[i].tts is hit[i-1].injt, so you should use hit[i].ets).       
                        -- Using analog FE: 
                        --      In short mode and recv_all=1, use T. 
                        --      In long mode and recv_all=0, use T (with energy branch).
                        csr.delay_ts_field_use_t        <= avs_csr_writedata(OP_MODE_LO + 1);
                        -- ... [0] : not used 
                    when 1 => 
                        
                    when 2 =>
                        csr_v_expected_latency_1n6 := resize(unsigned(avs_csr_writedata), expected_latency_1n6'length);
                        csr_v_expected_latency_1n6 := csr_v_expected_latency_1n6 + shift_left(csr_v_expected_latency_1n6, 2);
                        csr.expected_latency       <= avs_csr_writedata;
                        expected_latency_1n6       <= csr_v_expected_latency_1n6;
                        padding_upper              <= to_unsigned(OVERFLOW_1N6, padding_upper'length) - resize(csr_v_expected_latency_1n6, padding_upper'length);
                    when others =>
                        null;
                end case;
            -- read logic
            elsif (avs_csr_read = '1') then 
                avs_csr_waitrequest     <= '0'; -- ack
                case to_integer(unsigned(avs_csr_address)) is -- addr map
                    when 0 =>
                        if (processor_state = RUNNING) then -- show current state 
                            avs_csr_readdata(0)     <= '1' ; 
                        else
                            avs_csr_readdata(0)     <= '0';
                        end if;
                        avs_csr_readdata(1)     <= csr.force_stop;
                        avs_csr_readdata(2)     <= csr.soft_reset;
                        avs_csr_readdata(3)     <= csr.bypass_lapse;
                        avs_csr_readdata(4)     <= csr.discard_hiterr;
                        avs_csr_readdata(OP_MODE_LO + 2)                <= csr.derive_tot;
                        avs_csr_readdata(OP_MODE_LO + 1)                <= csr.delay_ts_field_use_t;
                    when 1 => 
                        avs_csr_readdata        <= std_logic_vector(debug_msg.discard_hit_cnt);
                    when 2 =>
                        avs_csr_readdata        <= csr.expected_latency;
                    when 3 =>
                        avs_csr_readdata(15 downto 0)       <= std_logic_vector(debug_msg.total_hit_cnt(47 downto 32));
                    when 4 =>
                        avs_csr_readdata                    <= std_logic_vector(debug_msg.total_hit_cnt(31 downto 0));
                    when others => 
                        null;
                end case;
            -- contention with other state machines
            else 
                -- release reset by csr
                if (csr.soft_reset = '1') then 
                    csr.soft_reset          <= '0';
                end if;
            
            end if;
        end if;
    end process;
    
    
    proc_processor_fsm : process (i_rst, i_clk)
    -- IDLE: write ok, read no. FIFO can overflow. 
    -- RUN_PREP: write no, read ok. FIFO is flushed until empty.
    -- SYNC: write no, read no. FIFO should already be emptied
    -- RUNNING: write ok, read ok. FIFO is in normal op.
    -- TERMINATING: write ok (do not gen new frame), read ok. FIFO is flushed empty. 
    -- OTHERS: same as IDLE. 
    begin
        if (i_rst = '1') then 
            processor_state		<= IDLE;
            reset_flow			<= DONE;
        
        elsif (rising_edge(i_clk)) then
            processor_allow_input		<= '0';
            
            case processor_state is 
                when IDLE => -- do not read fifo
                    if (csr.go = '1' and run_state_cmd = RUNNING) then -- !not standard run sequence, but allowed
                        processor_state		<= RUNNING; 
                        reset_flow			<= DONE;
                    elsif (run_state_cmd = RUN_PREPARE) then -- standard sequence
                        processor_state		<= RESET; 
                        reset_flow			<= SCLR;
                    elsif (run_state_cmd = SYNC) then -- !not standard sequence, skipped sclr counters
                        processor_state		<= RESET;
                        reset_flow			<= SYNC;
                    end if;
                    
                when RESET =>	-- in this state, the mts->gts is reset, the fifo of assembly is flushed until empty (assembly should no generate until RUNNING)
                    case reset_flow is
                        when SCLR => 
                            -- sclr all counters and fifos 
                            processor_allow_input		<= '1';
                        when SYNC =>
                            -- hold mts->gts 
                        when DONE =>
                            -- normal op
                        when others => 
                    end case;
                    if (csr.go = '1' and run_state_cmd = RUNNING) then -- standard sequence 2 
                        processor_state		<= RUNNING;
                        reset_flow			<= DONE;
                    elsif (run_state_cmd = SYNC) then -- standard sequence 1 
                        reset_flow			<= SYNC;
                    elsif (run_state_cmd = IDLE) then -- abort
                        processor_state		<= IDLE;
                        reset_flow			<= DONE;
                    end if;
                
                when RUNNING =>
                    processor_allow_input		<= '1';
                    if (run_state_cmd = TERMINATING) then -- standard sequence
                        processor_state		<= FLUSHING;
                    elsif (run_state_cmd = IDLE) then -- abort
                        processor_state		<= IDLE; 
                    end if;
                    
                when FLUSHING => -- drain accepted payload and wait for the explicit upstream end-of-run pulse
                    if (upstream_endofrun_seen = '0') then
                        processor_allow_input        <= '1';
                    else
                        processor_allow_input        <= '0';
                    end if;
                    if (run_state_cmd = IDLE) then -- standard sequence
                        processor_state		<= IDLE;
                    end if;
                when others => 
            end case;
            
            -- manual force stop by csr control 
            if (csr.force_stop = '1') then 
                processor_allow_input       <= '0';
            end if;
        
        end if;
    end process;
    
    proc_in_ready : process (i_rst, i_clk)
    begin
        if (i_rst = '1') then 
        
        elsif (rising_edge(i_clk)) then 
            -- default 
            asi_hit_type0_ready			<= '0';	
            case processor_state is 
                when IDLE => 
                    asi_hit_type0_ready			<= '0';
                when RESET =>
                    case reset_flow is 
                        when SCLR => 
                            asi_hit_type0_ready			<= '1'; -- flushing fifo
                        when SYNC =>
                            asi_hit_type0_ready			<= '0';
                        when DONE =>
                            asi_hit_type0_ready			<= '0';
                        when others =>
                    end case;
                when RUNNING =>
                    asi_hit_type0_ready			<= '1'; -- accepting input hits
                when FLUSHING =>
                    if (upstream_endofrun_seen = '0') then
                        asi_hit_type0_ready         <= '1'; -- flushing until upstream reports end-of-run
                    else
                        asi_hit_type0_ready         <= '0';
                    end if;
                when others =>
            end case;
        end if;
    
    end process;
    
    proc_mts_counter : process (i_rst, i_clk)
    -- counter of the mutrig timestamp on the FPGA
    begin
        if (i_rst = '1') then
            counter_mts_1n6              <= (others => '0');
            counter_ov_cnt               <= (others => '0');
            counter_ov_cnt_reg           <= (others => '0');
            fpga_overflow_lookback_cnt   <= (others => '0');
            lpm_multi_valid_cnt          <= (others => '0');
        elsif rising_edge(i_clk) then
            if (processor_state = RESET and reset_flow = SYNC) then 
                 -- reset counter
                counter_mts_1n6		<= (others => '0');
                counter_ov_cnt		<= (others => '0');
                counter_ov_cnt_reg  <= (others => '0');
                fpga_overflow_lookback_cnt		<= (others => '0');
                lpm_multi_valid_cnt     <= (others => '0');
            else
                -- begin counter
                case counter_mts_1n6 is -- overflow at (32766 - 0 - 1 - 2 - 3 - 4)
                    when to_unsigned(32766,15) =>
                        counter_mts_1n6		<= to_unsigned(4,15);
                        counter_ov_cnt		<= counter_ov_cnt + to_unsigned(1,counter_ov_cnt'length);
                    when to_unsigned(32765,15) =>
                        counter_mts_1n6		<= to_unsigned(3,15);
                        counter_ov_cnt		<= counter_ov_cnt + to_unsigned(1,counter_ov_cnt'length);
                    when to_unsigned(32764,15) =>
                        counter_mts_1n6		<= to_unsigned(2,15);
                        counter_ov_cnt		<= counter_ov_cnt + to_unsigned(1,counter_ov_cnt'length);
                    when to_unsigned(32763,15) =>
                        counter_mts_1n6		<= to_unsigned(1,15);
                        counter_ov_cnt		<= counter_ov_cnt + to_unsigned(1,counter_ov_cnt'length);
                    when to_unsigned(32762,15) =>
                        counter_mts_1n6		<= to_unsigned(0,15);
                        counter_ov_cnt		<= counter_ov_cnt + to_unsigned(1,counter_ov_cnt'length);
                    when others => -- bullshit
                        counter_mts_1n6		<= counter_mts_1n6 + to_unsigned(5,15);
                        counter_ov_cnt		<= counter_ov_cnt;
                end case;
                
                counter_ov_cnt_reg	<= counter_ov_cnt;
                if (fpga_overflow_happened = '1') then -- set counter
                    fpga_overflow_lookback_cnt      <= expected_latency_1n6;
                elsif (fpga_overflow_lookback_cnt <= expected_latency_1n6 and fpga_overflow_lookback_cnt /= to_unsigned(0, fpga_overflow_lookback_cnt'length)) then
                    fpga_overflow_lookback_cnt      <= fpga_overflow_lookback_cnt - 5; -- with underflow protection
                else
                    fpga_overflow_lookback_cnt		<= (others => '0');
                end if;
                
                if (fpga_overflow_happened = '1') then 
                    lpm_multi_valid_cnt             <= to_unsigned(LPM_MULT_PIPELINE-1,lpm_multi_valid_cnt'length);
                elsif (lpm_multi_valid_cnt /= to_unsigned(0,lpm_multi_valid_cnt'length)) then 
                    lpm_multi_valid_cnt             <= lpm_multi_valid_cnt - 1;
                end if;
                
            end if;
        end if;
    end process;
    
    proc_gts_counter : process (i_rst, i_clk)
    -- counter of the global timestamp on the FPGA
        -- needs to be 48 bit at 125 MHz
    begin
        if (i_rst = '1') then
            counter_gts_8n <= (others => '0');
        elsif rising_edge(i_clk) then
            if (processor_state = RESET and reset_flow = SYNC) then 
                 -- reset counter
                counter_gts_8n		<= (others => '0');
            else
                -- begin counter
                counter_gts_8n		<= counter_gts_8n + to_unsigned(1,counter_gts_8n'length);
            end if;
        end if;
    end process;
    
    
    
    proc_padding_logic_comb : process (all)
    -- input: gray ts (cc_out from lut_ram)
    -- output: white ts (cc_gts_1n6_slv50), latch at the input stage of lpm div pipeline
        --variable cc_mts_1n6			: unsigned(14 downto 0); -- input 15 bit 
        --variable cc_gts_1n6			: unsigned(49 downto 0); -- padded to 50 bit
        variable padding_logic_gray_ts_v   : unsigned(14 downto 0);
        variable padding_logic_gray_ts_e_v : unsigned(14 downto 0);
        variable padding_logic_white_ts_v  : unsigned(49 downto 0);
        variable padding_logic_white_ts_e_v: unsigned(49 downto 0);
        variable padding_logic_gts_product_v : unsigned(49 downto 0);
    begin
        if (counter_ov_cnt_reg /= counter_ov_cnt) then -- generate a pulse when overflow happened on fpga
            fpga_overflow_happened 	<= '1'; -- after reset it should be ok 
        else
            fpga_overflow_happened 	<= '0';
        end if;

        padding_logic_gray_ts_v      := unsigned(hit_padding.cc_out);
        padding_logic_gray_ts_e_v    := unsigned(hit_padding.ecc_out);
        padding_logic_gts_product_v  := unsigned(padding_logic_gts_product);

        -- mts_1n6 (FPGA) will be faster/larger than receiving cc_mts_1n6 (MuTRiG), because of buffering, which is maximum two frame length (short=910 cycle, long = 1550 cycle; cycle=8ns)
        -- plus, a bit of cycles inside FPGA. 
        -- As a result, for small incoming hits, it is correct.
        -- For large incoming hits, the fpga counter might already overflowed, so we subtract 1 in overflow counter during this calculation.
        -- We set a fpga local time window. Only within this window, the subtraction is needed.

        -- Use the per-hit latched overflow-window decision here so the white
        -- timestamp adder no longer depends on the live lookback counter.
        if (padding_logic_gray_ts_v > padding_upper and hit_padding.tot_t_adjust = '1') then 
            --cc_gts_1n6		:= to_unsigned(cc_mts_1n6 + (to_integer(counter_ov_cnt)-1) * OVERFLOW_1N6, cc_gts_1n6'length);
            padding_logic_white_ts_v := resize(padding_logic_gray_ts_v, padding_logic_white_ts_v'length) + padding_logic_gts_product_v - to_unsigned(OVERFLOW_TIME_1N6, padding_logic_white_ts_v'length);
        else 
            --cc_gts_1n6		:= to_unsigned(cc_mts_1n6 + to_integer(counter_ov_cnt) * OVERFLOW_1N6, cc_gts_1n6'length);
            padding_logic_white_ts_v := resize(padding_logic_gray_ts_v, padding_logic_white_ts_v'length) + padding_logic_gts_product_v;
        end if;

        if (padding_logic_gray_ts_e_v > padding_upper and hit_padding.tot_e_adjust = '1') then 
            padding_logic_white_ts_e_v := resize(padding_logic_gray_ts_e_v, padding_logic_white_ts_e_v'length) + padding_logic_gts_product_v - to_unsigned(OVERFLOW_TIME_1N6, padding_logic_white_ts_e_v'length);
        else 
            padding_logic_white_ts_e_v := resize(padding_logic_gray_ts_e_v, padding_logic_white_ts_e_v'length) + padding_logic_gts_product_v;
        end if;

        padding_logic_gray_ts      <= padding_logic_gray_ts_v;
        padding_logic_gray_ts_e    <= padding_logic_gray_ts_e_v;
        padding_logic_white_ts     <= padding_logic_white_ts_v;
        padding_logic_white_ts_e   <= padding_logic_white_ts_e_v;

        -- output
        cc_gts_1n6_slv50		<= std_logic_vector(padding_logic_white_ts_v);
        ecc_gts_1n6_slv50		<= std_logic_vector(padding_logic_white_ts_e_v);
    
    end process;
    
    proc_avst2payload_comb : process (all)
    -- input validation from avst to the datapath
        variable allow_input_v : std_logic;
    begin
        -- default
        hit_in_ok        <= '0';
        allow_input_v    := '0';
        if (processor_allow_input = '1') then
            -- During FLUSHING we still accept buffered tail packets from
            -- frame_rcv_ip. Dedicated close markers are emitted only after
            -- the input/pipeline fully drains, so packet starts that arrive
            -- after the TERMINATING edge still belong to the draining run.
            allow_input_v := '1';
            if (allow_input_v = '1' and (asi_hit_type0_error(HITERR_BIT_LOC) = '0' or csr.discard_hiterr = '0')) then -- disable check or no error
                hit_in_ok        <= '1'; -- in comb with avst valid
            end if;
        end if;
    
    end process;
    
    proc_discard_hit_cnt : process (i_rst, i_clk)
    -- count the hits discard by 1) hit error (if csr.discard_hiterr setting is enabled) 2) in wrong run state (e.g. idle (continue up), sync (something is wrong)
    -- , other state (TODO: add after term)) 
    begin
        if (i_rst = '1') then 
            debug_msg.discard_hit_cnt		<= (others => '0');
            debug_msg.total_hit_cnt			<= (others => '0');
        elsif (rising_edge(i_clk)) then 
            
            if (asi_hit_type0_valid = '1' and hit_in_ok = '0') then -- capture invalid error
                debug_msg.discard_hit_cnt		<= debug_msg.discard_hit_cnt + 1;
            elsif (reset_flow = SYNC or csr.soft_reset = '1') then -- soft reset by csr
                debug_msg.discard_hit_cnt		<= (others => '0'); -- sclr the counter
            end if;
            
            if (asi_hit_type0_valid = '1') then -- including errors
                debug_msg.total_hit_cnt			<= debug_msg.total_hit_cnt + 1;
            elsif (reset_flow = SYNC or csr.soft_reset = '1') then -- soft reset by csr
                debug_msg.total_hit_cnt			<= (others => '0');
            end if;
            

        end if;
    end process;
    
    proc_datapath_comb : process (all)
    begin
        cc_in			<= asi_hit_type0_data(I_TCC_HI downto I_TCC_LO); -- decode tcc
        ecc_in			<= asi_hit_type0_data(I_ECC_HI downto I_ECC_LO); -- decode ecc
    end process;
    
    proc_datapath : process (i_rst, i_clk) 
    --	
        variable et_delta_v : unsigned(49 downto 0);
    begin
        if (i_rst = '1') then 
            hit_in.asic     <= (others => '0');
            hit_in.channel  <= (others => '0');
            hit_in.t_cc     <= (others => '0');
            hit_in.t_fine   <= (others => '0');
            hit_in.e_cc     <= (others => '0');
            hit_in.e_flag   <= '0';
            hit_in.valid    <= '0';
            hit_in.hiterr   <= '0';

            hit_padding.asic         <= (others => '0');
            hit_padding.channel      <= (others => '0');
            hit_padding.cc_out       <= (others => '0');
            hit_padding.ecc_out      <= (others => '0');
            hit_padding.tot_t_adjust <= '0';
            hit_padding.tot_e_adjust <= '0';
            hit_padding.t_fine       <= (others => '0');
            hit_padding.e_cc         <= (others => '0');
            hit_padding.e_flag       <= '0';
            hit_padding.valid        <= '0';
            hit_padding.hiterr       <= '0';

            hit_prediv.asic          <= (others => '0');
            hit_prediv.channel       <= (others => '0');
            hit_prediv.t_fine        <= (others => '0');
            hit_prediv.e_flag        <= '0';
            hit_prediv.hiterr        <= '0';
            hit_prediv.valid         <= '0';
            hit_prediv.t_gray_corr   <= (others => '0');
            hit_prediv.e_gray_corr   <= (others => '0');
            hit_prediv.tcc_div_numer <= (others => '0');
            hit_prediv.ecc_div_numer <= (others => '0');

            tcc_div_numer            <= (others => '0');
            ecc_div_numer            <= (others => '0');

            for i in 0 to LPM_DIV_PIPELINE loop
                hit_div(i).asic    <= (others => '0');
                hit_div(i).channel <= (others => '0');
                hit_div(i).t_fine  <= (others => '0');
                hit_div(i).e_cc    <= (others => '0');
                hit_div(i).et_1n6  <= (others => '0');
                hit_div(i).e_flag  <= '0';
                hit_div(i).valid   <= '0';
                hit_div(i).hiterr  <= '0';
            end loop;

            hit_out.asic    <= (others => '0');
            hit_out.channel <= (others => '0');
            hit_out.tcc_8n  <= (others => '0');
            hit_out.tcc_1n6 <= (others => '0');
            hit_out.tfine   <= (others => '0');
            hit_out.et_1n6  <= (others => '0');
            hit_out.valid   <= '0';
            hit_out.hiterr  <= '0';
        
        elsif (rising_edge(i_clk)) then
            -- default 
            hit_in.asic		<= (others => '0');
            hit_in.channel	<= (others => '0');
            hit_in.t_cc		<= (others => '0');
            hit_in.t_fine	<= (others => '0');
            hit_in.e_cc		<= (others => '0');
            hit_in.e_flag	<= '0';
            hit_in.valid	<= '0';
            hit_in.hiterr	<= '0';
            
            hit_padding.asic	<= (others => '0');
            hit_padding.channel	<= (others => '0');
            hit_padding.cc_out	<= (others => '0');
            hit_padding.ecc_out	<= (others => '0');
            hit_padding.tot_t_adjust <= '0';
            hit_padding.tot_e_adjust <= '0';
            hit_padding.t_fine	<= (others => '0');
            hit_padding.e_cc	<= (others => '0');
            hit_padding.e_flag	<= '0';
            hit_padding.valid	<= '0';
            hit_padding.hiterr	<= '0';

            hit_prediv.asic       <= (others => '0');
            hit_prediv.channel    <= (others => '0');
            hit_prediv.t_fine     <= (others => '0');
            hit_prediv.e_flag     <= '0';
            hit_prediv.hiterr     <= '0';
            hit_prediv.valid      <= '0';
            hit_prediv.t_gray_corr <= (others => '0');
            hit_prediv.e_gray_corr <= (others => '0');
            hit_prediv.tcc_div_numer <= (others => '0');
            hit_prediv.ecc_div_numer <= (others => '0');
            
            tcc_div_numer		<= (others => '0');
            ecc_div_numer       <= (others => '0');
            -- Single-owner divider pipeline: stage 0 is cleared/loaded here and
            -- older stages are shifted forward in this same process.
            for i in 0 to 0 loop
                hit_div(i).asic			<= (others => '0');
                hit_div(i).channel		<= (others => '0');
                hit_div(i).t_fine		<= (others => '0');
                hit_div(i).e_cc			<= (others => '0');
                hit_div(i).et_1n6       <= (others => '0');
                hit_div(i).e_flag		<= '0';
                hit_div(i).valid		<= '0';
                hit_div(i).hiterr		<= '0';
            end loop;
            for i in 1 to LPM_DIV_PIPELINE loop
                hit_div(i)             <= hit_div(i - 1);
            end loop;
            
            hit_out.asic		<= (others => '0');
            hit_out.channel		<= (others => '0');
            hit_out.tcc_8n		<= (others => '0');
            hit_out.tcc_1n6		<= (others => '0');
            hit_out.tfine		<= (others => '0');
            hit_out.et_1n6		<= (others => '0');
            hit_out.valid		<= '0';
            hit_out.hiterr		<= '0';

            -- input stage
            if (asi_hit_type0_valid = '1' and hit_in_ok = '1') then 
                hit_in.asic		<= asi_hit_type0_data(I_ASIC_HI downto I_ASIC_LO);
                hit_in.channel	<= asi_hit_type0_data(I_CHANNEL_HI downto I_CHANNEL_LO);
                hit_in.t_fine	<= asi_hit_type0_data(I_TFINE_HI downto I_TFINE_LO);
                hit_in.e_flag   <= asi_hit_type0_data(I_EFLAG_BIT_LOC);
                hit_in.valid	<= '1';
                hit_in.hiterr	<= asi_hit_type0_error(HITERR_BIT_LOC);
            end if;
            
            -- pipeline for lut ram
            if (hit_in.valid = '1') then 
                hit_padding.asic		<= hit_in.asic;
                hit_padding.channel		<= hit_in.channel;
                hit_padding.cc_out		<= cc_out; -- decoded
                hit_padding.ecc_out		<= ecc_out; -- decoded
                hit_padding.tot_t_adjust <= overflow_adjust_active;
                hit_padding.tot_e_adjust <= overflow_adjust_active;
                hit_padding.e_flag		<= hit_in.e_flag;
                hit_padding.t_fine		<= hit_in.t_fine;
                hit_padding.valid		<= '1';
                hit_padding.hiterr		<= hit_in.hiterr;
            end if;
            
            if (hit_padding.valid = '1') then 
                if (DEBUG /= 0) then
                    report "MTS_STAGE[" & BANK & "] div_load ch="
                        & integer'image(to_integer(unsigned(hit_padding.channel)))
                        severity note;
                end if;
                hit_div(0).asic         <= hit_padding.asic;
                hit_div(0).channel      <= hit_padding.channel;
                if (csr.bypass_lapse = '0') then  -- mts -> gts transformation enable 
                    tcc_div_numer                                       <= cc_gts_1n6_slv50;
                    ecc_div_numer                                       <= ecc_gts_1n6_slv50;
                else -- mts -> gts transformation disable (this would result in random dist., which is simply for sanity check.) 
                    tcc_div_numer(hit_padding.cc_out'high downto 0)     <= hit_padding.cc_out;
                    ecc_div_numer(hit_padding.ecc_out'high downto 0)    <= hit_padding.ecc_out;
                end if;

                -- eflag[8] + ToT[8:0]
                -- Q: seems eflag=1 is bad, which is inverted? A: no, flag=1 is good, it was a misunderstanding with BadHit bit
                if csr.derive_tot = '1' then
                    if (hit_padding.e_flag = '0') then -- if no eflag, mask the ToT value to 0 (dec)
                        hit_div(0).et_1n6       <= (others => '0');
                    elsif (unsigned(ecc_gts_1n6_slv50) < unsigned(cc_gts_1n6_slv50)) then -- if negative, underflow, mask the ToT to 0 (dec)
                        hit_div(0).et_1n6       <= (others => '0');
                    else
                        et_delta_v := unsigned(ecc_gts_1n6_slv50) - unsigned(cc_gts_1n6_slv50);
                        hit_div(0).et_1n6       <= std_logic_vector(resize(et_delta_v, hit_div(0).et_1n6'length));
                        if (et_delta_v > to_unsigned(511, et_delta_v'length)) then -- if too large, overflow, mask the ToT to 511 (dec)
                            hit_div(0).et_1n6       <= (others => '1');
                        end if;
                    end if;
                else
                    hit_div(0).et_1n6       <= (others => '0');
                end if;
                hit_div(0).t_fine		<= hit_padding.t_fine;
                hit_div(0).valid		<= '1';
                hit_div(0).hiterr		<= hit_padding.hiterr;
            end if;
            
            -- lpm div pipeline output reg
            if (hit_div(LPM_DIV_PIPELINE).valid = '1') then -- assemble the hit_out 
                hit_out.asic		<= hit_div(LPM_DIV_PIPELINE).asic;
                hit_out.channel		<= hit_div(LPM_DIV_PIPELINE).channel;
                hit_out.tcc_8n		<= tcc_div_quotient(hit_out.tcc_8n'high downto 0); -- latch div result (quotient)
                hit_out.tcc_1n6		<= tcc_div_remain(hit_out.tcc_1n6'high downto 0); -- latch div result (remainder)
                hit_out.tfine		<= hit_div(LPM_DIV_PIPELINE).t_fine;
                hit_out.et_1n6		<= hit_div(LPM_DIV_PIPELINE).et_1n6;
                hit_out.valid		<= '1';
                hit_out.hiterr		<= hit_div(LPM_DIV_PIPELINE).hiterr;
            end if;

        end if;
    
    end process;

    proc_debug_stage_trace : process (i_clk)
    begin
        if (rising_edge(i_clk)) then
            if (DEBUG /= 0 and i_rst = '0') then
                if (hit_in.valid = '1') then
                    report "MTS_STAGE[" & BANK & "] hit_in ch="
                        & integer'image(to_integer(unsigned(hit_in.channel)))
                        & " hiterr=" & std_logic'image(hit_in.hiterr)
                        severity note;
                end if;
                if (hit_padding.valid = '1') then
                    report "MTS_STAGE[" & BANK & "] hit_padding ch="
                        & integer'image(to_integer(unsigned(hit_padding.channel)))
                        & " cc=" & integer'image(to_integer(unsigned(hit_padding.cc_out)))
                        & " ecc=" & integer'image(to_integer(unsigned(hit_padding.ecc_out)))
                        & " t_adj=" & std_logic'image(hit_padding.tot_t_adjust)
                        & " e_adj=" & std_logic'image(hit_padding.tot_e_adjust)
                        severity note;
                end if;
                if (hit_div(0).valid = '1') then
                    report "MTS_STAGE[" & BANK & "] hit_div0 ch="
                        & integer'image(to_integer(unsigned(hit_div(0).channel)))
                        & " et=" & integer'image(to_integer(unsigned(hit_div(0).et_1n6)))
                        severity note;
                end if;
                if (hit_div(LPM_DIV_PIPELINE).valid = '1') then
                    report "MTS_STAGE[" & BANK & "] hit_divN ch="
                        & integer'image(to_integer(unsigned(hit_div(LPM_DIV_PIPELINE).channel)))
                        severity note;
                end if;
                if (hit_out.valid = '1') then
                    report "MTS_STAGE[" & BANK & "] hit_out ch="
                        & integer'image(to_integer(unsigned(hit_out.channel)))
                        & " tcc_8n=" & integer'image(to_integer(unsigned(hit_out.tcc_8n)))
                        & " tcc_1n6=" & integer'image(to_integer(unsigned(hit_out.tcc_1n6)))
                        severity note;
                end if;
            end if;
        end if;
    end process;

    proc_payload2avst : process (i_rst, i_clk)
    -- assembly of avst (hit type 1) and per-run close markers
        variable route_lane_v     : natural;
        variable input_lane_v     : natural;
        variable input_slot_v     : natural;
        variable terminate_lane_v : natural;
    begin
        if (i_rst = '1') then 
            route_startofrun_sent         <= (others => '0');
            route_terminate_sent          <= (others => '0');
            upstream_endofrun_seen        <= '0';
            packet_in_transaction         <= (others => '0');
            aso_hit_type1_data            <= (others => '0');
            aso_hit_type1_valid           <= '0';
            aso_hit_type1_channel         <= (others => '0');
            aso_hit_type1_startofpacket   <= '0';
            aso_hit_type1_endofpacket     <= '0';
            aso_hit_type1_empty           <= '0';
        
        elsif (rising_edge(i_clk)) then
            aso_hit_type1_data            <= (others => '0');
            aso_hit_type1_valid           <= '0';
            aso_hit_type1_channel         <= (others => '0');
            aso_hit_type1_startofpacket   <= '0';
            aso_hit_type1_endofpacket     <= '0';
            aso_hit_type1_empty           <= '0';

            if (processor_state = RESET or processor_state = IDLE) then
                route_startofrun_sent     <= (others => '0');
                route_terminate_sent      <= (others => '0');
                upstream_endofrun_seen    <= '0';
                packet_in_transaction     <= (others => '0');
            elsif (
                asi_hit_type0_endofrun = '1'
                and processor_state /= RESET
                and processor_state /= IDLE
            ) then
                -- Retain the upstream close pulse even if it lands on the
                -- RUNNING->FLUSHING transition cycle. This removes the idle
                -- terminate race where the pulse arrived before FLUSHING was
                -- visible to this process.
                upstream_endofrun_seen    <= '1';
            end if;

            if (processor_state = RUNNING or processor_state = FLUSHING) then 
                if (hit_out.valid = '1') then
                    route_lane_v := to_integer(unsigned(hit_out.tcc_8n(5 downto 4)));
                    aso_hit_type1_data(O_ASIC_HI downto O_ASIC_LO)               <= hit_out.asic;
                    aso_hit_type1_data(O_CHANNEL_HI downto O_CHANNEL_LO)         <= hit_out.channel;
                    aso_hit_type1_data(O_TCC8N_HI downto O_TCC8N_LO)             <= hit_out.tcc_8n;
                    aso_hit_type1_data(O_TCC1N6_HI downto O_TCC1N6_LO)           <= hit_out.tcc_1n6;
                    aso_hit_type1_data(O_TFINE_HI downto O_TFINE_LO)             <= hit_out.tfine;
                    aso_hit_type1_data(O_ET1N6_HI downto O_ET1N6_LO)             <= hit_out.et_1n6;
                    aso_hit_type1_valid                                          <= '1';
                    aso_hit_type1_channel                                        <= "00" & hit_out.tcc_8n(5 downto 4);
                    if (route_startofrun_sent(route_lane_v) = '0') then
                        route_startofrun_sent(route_lane_v)                      <= '1';
                        aso_hit_type1_startofpacket                             <= '1';
                    end if;
                elsif (terminating_marker_valid = '1') then
                    terminate_lane_v := to_integer(unsigned(terminating_marker_lane));
                    aso_hit_type1_valid                                          <= '1';
                    aso_hit_type1_channel                                        <= "00" & terminating_marker_lane;
                    aso_hit_type1_startofpacket                                  <= terminating_marker_sop;
                    aso_hit_type1_endofpacket                                    <= '1';
                    aso_hit_type1_empty                                          <= '1';
                    route_terminate_sent(terminate_lane_v)                       <= '1';
                    if (route_startofrun_sent(terminate_lane_v) = '0') then
                        route_startofrun_sent(terminate_lane_v)                  <= '1';
                    end if;
                end if;
            end if;

            if (processor_state = RUNNING or processor_state = FLUSHING) then
                if (asi_hit_type0_valid = '1' and hit_in_ok = '1') then
                    input_lane_v := to_integer(unsigned(asi_hit_type0_channel));
                    if (input_lane_v >= ENABLED_CHANNEL_LO and input_lane_v <= ENABLED_CHANNEL_HI) then
                        input_slot_v := input_lane_v - ENABLED_CHANNEL_LO;
                        if (asi_hit_type0_endofpacket = '1') then
                            packet_in_transaction(input_slot_v)                  <= '0';
                        elsif (asi_hit_type0_startofpacket = '1') then
                            packet_in_transaction(input_slot_v)                  <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    proc_debug_ts_comb : process (all) -- need to delay 1 cycle to match with normal hit data
    begin
        if (rising_edge(i_clk)) then
            aso_debug_ts_data           <= int_aso_debug_ts_data;
            aso_debug_ts_valid          <= int_aso_debug_ts_valid;
        end if;
    end process;
    
    proc_debug_ts : process (i_clk)
    begin
        if (rising_edge(i_clk)) then
            if (hit_div(LPM_DIV_PIPELINE).valid = '1') then -- 48 bit - 48 bit (no of/df)
                if (csr.delay_ts_field_use_t = '1') then  
                    int_aso_debug_ts_data	<= std_logic_vector(to_signed(to_integer(counter_gts_8n) - to_integer(unsigned(tcc_div_quotient)),aso_debug_ts_data'length));
                else 
                    int_aso_debug_ts_data	<= std_logic_vector(to_signed(to_integer(counter_gts_8n) - to_integer(unsigned(ecc_div_quotient)),aso_debug_ts_data'length));
                end if;
                int_aso_debug_ts_valid  <= '1';
            else 
                int_aso_debug_ts_valid  <= '0';
            end if;
            
            -- --------------------------------------------
            -- derive the error signals of the datapath
            -- --------------------------------------------
            -- default 
            aso_hit_type1_error              <= '0'; -- timing aligned with <hit_type1> valid
            if (int_aso_debug_ts_valid = '1') then 
                -- ok: ts within range of (0,2000)
                if (signed(int_aso_debug_ts_data) > to_signed(0, int_aso_debug_ts_data'length) and unsigned(int_aso_debug_ts_data) < unsigned(csr.expected_latency)) then -- refactor : use csr and better lint 
                    aso_hit_type1_error         <= '0';
                -- error: ts out of range of (0,2000). possible pll unlocked or cml logic recv side is too low (generate a bit of side noise)
                else 
                    aso_hit_type1_error         <= '1';
                end if;
            end if;
        end if;
    end process;
    
    
    -- ///////////////////////////////////////////////////////////////////////////////
    -- @name            debug_burst
    -- @brief           calculate the delta of timestamp and inter-arrival time
    --                  of adjacent hits. 
    --
    -- ///////////////////////////////////////////////////////////////////////////////
    proc_debug_burst : process (i_clk)
    -- 3 pipeline stages
        variable burst_v_timestamp_delta : unsigned(egress_timestamp(0)'range);
        variable burst_v_arrival_delta   : unsigned(egress_arrival(0)'range);
    begin
        if (rising_edge(i_clk)) then 
            if (processor_state = RUNNING and i_rst = '0') then 
                -- default
                egress_valid                <= '0';
                delta_valid                 <= '0';
                aso_debug_burst_valid       <= '0';
                aso_ts_delta_valid          <= '0';
                -- --------------
                -- latch new 
                -- --------------
                if (hit_div(LPM_DIV_PIPELINE).valid = '1') then -- 48 bit - 48 bit
                    -- timestamp
                    if (csr.delay_ts_field_use_t = '1') then  
                        egress_timestamp(0)         <= tcc_div_quotient(egress_timestamp(0)'high downto 0);
                    else 
                        egress_timestamp(0)         <= ecc_div_quotient(egress_timestamp(0)'high downto 0);
                    end if;
                    egress_timestamp(1)         <= egress_timestamp(0);
                    -- arrival
                    egress_arrival(0)           <= std_logic_vector(counter_gts_8n);
                    egress_arrival(1)           <= egress_arrival(0);
                    --
                    egress_valid                <= '1';
                end if;
             
                -- -------------------
                -- calculate deltas
                -- -------------------
                if (egress_valid = '1') then 
                    -- signed magnitude substraction (take care of underflow)
                    if (egress_timestamp(0) >= egress_timestamp(1)) then 
                        -- sorted
                        burst_v_timestamp_delta                       := unsigned(egress_timestamp(0)) - unsigned(egress_timestamp(1));
                        delta_timestamp(delta_timestamp'high)               <= '0';
                        delta_timestamp(delta_timestamp'high-1 downto 0)    <= std_logic_vector(burst_v_timestamp_delta(delta_timestamp'high-1 downto 0)); -- delta_timestamp = Hit_{t+1} - Hit_{t}
                    else 
                        -- unsorted
                        burst_v_timestamp_delta                       := unsigned(egress_timestamp(1)) - unsigned(egress_timestamp(0));
                        delta_timestamp(delta_timestamp'high)               <= '1';
                        delta_timestamp(delta_timestamp'high-1 downto 0)    <= std_logic_vector(burst_v_timestamp_delta(delta_timestamp'high-1 downto 0));
                    end if;
                    -- unsigned sub.
                    burst_v_arrival_delta       := unsigned(egress_arrival(0)) - unsigned(egress_arrival(1));
                    delta_arrival               <= std_logic_vector(burst_v_arrival_delta(delta_arrival'high downto 0)); -- delta_arrival = Hit_{t+1} - Hit_{t}
                    --
                    delta_valid                 <= '1';
                end if;
                
                -- -------
                -- trim
                -- -------
                if (delta_valid = '1') then 
                    -- [XX] [YY]
                    -- XX := timestamp (higher 8 bit). ex: 10 bit, range is -512 to 511, triming 2 bits yields -> -128 to 127
                    -- YY := interarrival time (higher 8 bit). ex 10 bit, range is 0 to 1023, triming 2 bits yields -> 0 to 255
                    aso_debug_burst_data(15 downto 8)           <= delta_timestamp(delta_timestamp'high downto delta_timestamp'high-7);
                    aso_debug_burst_data(7 downto 0)            <= delta_arrival(delta_arrival'high downto delta_arrival'high-7);
                    --
                    aso_debug_burst_valid                       <= '1';
                    aso_ts_delta_data                           <= signmag_to_twos_comp16(delta_timestamp);
                    aso_ts_delta_valid                          <= '1';
                end if;
            else -- reset
                -- default
                egress_valid                <= '0';
                delta_valid                 <= '0';
                aso_debug_burst_valid       <= '0';
                aso_ts_delta_valid          <= '0';
                aso_ts_delta_data           <= (others => '0');
                egress_timestamp            <= (others => (others => '0'));
                egress_arrival              <= (others => (others => '0'));
                delta_timestamp             <= (others => '0');
                delta_arrival               <= (others => '0');
            end if;
        end if;
    
    
    end process;
    
    


    
    
    
end architecture rtl;
