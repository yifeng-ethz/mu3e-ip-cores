-- ------------------------------------------------------------------------------------------------------------
-- IP Name:             lvds_rx_controller_pro
-- Author:              Yifeng Wang (yifenwan@phys.ethz.ch)
-- =========================================================================
-- Revision:            1.0
-- Date:                Oct 14, 2024 (file created)
-- +-----------------------------------------------------------------------+
-- Revision:            1.1
-- Date:                Oct 21, 2024 (control plane verified)
-- +-----------------------------------------------------------------------+
-- Revision:            1.2
-- Date:                Nov 5, 2024 (data plane verified; refine lane selection with sticky)
-- +-----------------------------------------------------------------------+
-- Revision:            1.3
-- Date:                Mar 3, 2025 (fulfill CDC)
-- +-----------------------------------------------------------------------+
-- Revision:            1.4
-- Date:                Mar 24, 2025 (wrap more CDCs)
-- =========================================================================
-- Description:         Controls and decodes data from 'altera_lvds_rx_28nm` IP. 
-- Usage:                
-- 		                [Control flow]: (training)
--							Operates in free-running clock. Monitors DPA phase locking, DPA fifo reset.
--
--                      [Data flow]: (boundary-search)
--                      	Operates in outclock clock. Decodes the 10b into 8b data + 1b control (8b1k). 
--							Word alignment modes: 
--								1) "bit slip': takes a tens of thousands cycles to realign after bitslip incidence.
--									slow and error-prone but requires less resources (ALM). 
--								2) adaptive selection: tracking boundary by parallel monitoring 10 combinations.
--									ultra-fast and robust but requires more resources (ALM).
--
-- ------------------------------------------------------------------------------------------------------------
--	
-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.and_reduce;
-- get params from hls* macro


entity scifi_datapath_system_v3_pipe_lvds_rx_controller_pro_0 is 
generic (
	-- +-------------+
	-- | IP settings |
	-- +-------------+
	AVMM_ADDR_W				: natural   := 4;
	N_LANE					: natural   := 9; -- up to 32
	DECODED_USE_CHANNEL		: natural   := 1;
	DECODED_CHANNEL_WIDTH	: natural   := 4; -- ceil(log2(N_LANE))
    SYNC_PATTERN            : std_logic_vector := "0011111010";
	DEBUG_LV				: natural   := 0
);
port (

	-- CONDUIT [ctrl]
	-- pll-related
	coe_ctrl_pllrst					: out std_logic;
	coe_ctrl_plllock				: in  std_logic;
	-- dpa circuitry
	coe_ctrl_dparst					: out std_logic_vector(N_LANE-1 downto 0);
	coe_ctrl_lockrst				: out std_logic_vector(N_LANE-1 downto 0);
	coe_ctrl_dpahold				: out std_logic_vector(N_LANE-1 downto 0);
	coe_ctrl_dpalock				: in  std_logic_vector(N_LANE-1 downto 0);
	-- dpa fifo
	coe_ctrl_fiforst				: out std_logic_vector(N_LANE-1 downto 0);
	-- bit-slip logic
	coe_ctrl_bitslip				: out std_logic_vector(N_LANE-1 downto 0);
	coe_ctrl_rollover				: in  std_logic_vector(N_LANE-1 downto 0);
	
	-- AVMM SLAVE [csr]
	avs_csr_read					: in  std_logic;
	avs_csr_readdata				: out std_logic_vector(31 downto 0);
	avs_csr_write					: in  std_logic;
	avs_csr_writedata				: in  std_logic_vector(31 downto 0);
	avs_csr_address					: in  std_logic_vector(AVMM_ADDR_W-1 downto 0);
	avs_csr_waitrequest				: out std_logic;
	
	-- CONDUIT [parallel]
	coe_parallel_data				: in  std_logic_vector(N_LANE*10-1 downto 0);
	
	-- AVST SOURCE [decoded]
    -- error descriptor = {"loss_sync_pattern" "parity_error" "decode_error"}
    -- use seperate interfaces for decoded data 
    -- interface index_0
	aso_decoded0_data			: out std_logic_vector(8 downto 0);
	--aso_decoded0_valid			: out std_logic;
	--aso_decoded0_ready			: in  std_logic;
    aso_decoded0_error           : out std_logic_vector(2 downto 0);
    aso_decoded0_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_1
	aso_decoded1_data			: out std_logic_vector(8 downto 0);
	--aso_decoded1_valid			: out std_logic;
	--aso_decoded1_ready			: in  std_logic;
    aso_decoded1_error           : out std_logic_vector(2 downto 0);
    aso_decoded1_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_2
	aso_decoded2_data			: out std_logic_vector(8 downto 0);
	--aso_decoded2_valid			: out std_logic;
	--aso_decoded2_ready			: in  std_logic;
    aso_decoded2_error           : out std_logic_vector(2 downto 0);
    aso_decoded2_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_3
	aso_decoded3_data			: out std_logic_vector(8 downto 0);
	--aso_decoded3_valid			: out std_logic;
	--aso_decoded3_ready			: in  std_logic;
    aso_decoded3_error           : out std_logic_vector(2 downto 0);
    aso_decoded3_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_4
	aso_decoded4_data			: out std_logic_vector(8 downto 0);
	--aso_decoded4_valid			: out std_logic;
	--aso_decoded4_ready			: in  std_logic;
    aso_decoded4_error           : out std_logic_vector(2 downto 0);
    aso_decoded4_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_5
	aso_decoded5_data			: out std_logic_vector(8 downto 0);
	--aso_decoded5_valid			: out std_logic;
	--aso_decoded5_ready			: in  std_logic;
    aso_decoded5_error           : out std_logic_vector(2 downto 0);
    aso_decoded5_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_6
	aso_decoded6_data			: out std_logic_vector(8 downto 0);
	--aso_decoded6_valid			: out std_logic;
	--aso_decoded6_ready			: in  std_logic;
    aso_decoded6_error           : out std_logic_vector(2 downto 0);
    aso_decoded6_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_7
	aso_decoded7_data			: out std_logic_vector(8 downto 0);
	--aso_decoded7_valid			: out std_logic;
	--aso_decoded7_ready			: in  std_logic;
    aso_decoded7_error           : out std_logic_vector(2 downto 0);
    aso_decoded7_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    -- interface index_8
	aso_decoded8_data			: out std_logic_vector(8 downto 0);
	--aso_decoded8_valid			: out std_logic;
	--aso_decoded8_ready			: in  std_logic;
    aso_decoded8_error           : out std_logic_vector(2 downto 0);
    aso_decoded8_channel         : out std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
    
    -- NOTE: in case of control plane error, the word boundary will assert error[2]. add support in downstream (MuTRiG frame deassembly IP) 
    -- to assert error signal for the whole packet to let the further downstream to discard it. just to do not let a single broken packet to pass. 
    -- NOTE: the frame deassembly IP should also pull to IDLE state and try to capture new frame header once the error[2] is recovered.

    -- <- this is done!
    
    -- CONDUIT [redriver]
    coe_redriver_losn               : in  std_logic_vector(N_LANE-1 downto 0); -- pull high if you dont need this
	
	-- clock and reset interface
	-- [data]
	rsi_data_reset					: in  std_logic;
	csi_data_clk					: in  std_logic;
	-- [control]
	rsi_control_reset				: in  std_logic;
	csi_control_clk					: in  std_logic

);
end entity scifi_datapath_system_v3_pipe_lvds_rx_controller_pro_0;

architecture rtl of scifi_datapath_system_v3_pipe_lvds_rx_controller_pro_0 is 

    
    -- //////////////////////////////////////////////////
    -- csr_interface
    -- //////////////////////////////////////////////////
    -- 8b10b symbols (ref: https://docs.amd.com/r/en-US/am002-versal-gty-transceivers/8B/10B-Valid-Characters)
    -- =======================================================================
    -- code name            Bits HGF EDCBA          symbol RD- abcdei fghj
    -- =======================================================================
    -- K28.5                101 11100               001111 1010
    -- K28.0                000 11100               001111 0100
    -- K23.7                111 10111               111010 1000
    
    constant K28_5          : std_logic_vector(9 downto 0) := "0011111010";
    constant K28_0          : std_logic_vector(9 downto 0) := "0011110100";
    constant K23_7          : std_logic_vector(9 downto 0) := "1110101000";
  
    
    type symbol_errors_t is array (0 to N_LANE-1) of std_logic_vector(31 downto 0);
    type dpa_unlocks_t is array (0 to N_LANE-1) of std_logic_vector(31 downto 0);
    type rollover_errors_t is array (0 to N_LANE-1) of unsigned(31 downto 0);
    type csr_t is record
        sync_pattern        : std_logic_vector(9 downto 0);
        mode_mask           : std_logic_vector(N_LANE-1 downto 0);
        soft_reset_req      : std_logic_vector(N_LANE-1 downto 0);
        dpa_hold            : std_logic_vector(N_LANE-1 downto 0);
        lane_go             : std_logic_vector(N_LANE-1 downto 0);
        symbol_errors       : symbol_errors_t;
        dpa_unlocks         : dpa_unlocks_t;
        lane_selection      : std_logic_vector(DECODED_CHANNEL_WIDTH-1 downto 0);
        rollover_errors     : rollover_errors_t;
    end record;
    constant CSR_INIT       : csr_t := (
        sync_pattern        => SYNC_PATTERN,
        mode_mask           => (others => '1'),
        soft_reset_req      => (others => '0'),
        dpa_hold            => (others => '0'),
        lane_go             => (others => '1'),
        symbol_errors       => (others => (others => '0')),
        dpa_unlocks         => (others => (others => '0')),
        lane_selection      => (others => '0'),
        rollover_errors     => (others => (others => '0'))
    );
    signal csr              : csr_t := CSR_INIT;
    signal dcsr             : csr_t := CSR_INIT;
    
    -- //////////////////////////////////////////////////
    -- cdc_fifo
    -- //////////////////////////////////////////////////
    signal locking_monitor_ok               : std_logic_vector(N_LANE-1 downto 0) := (others => '0'); -- translate locking_monitor.OK -> binary; 1=ok, 0=bad
    signal dlocking_monitor_ok              : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    constant CDC_C2D_WIDTH          : natural := csr.sync_pattern'length + csr.mode_mask'length + csr.soft_reset_req'length + locking_monitor_ok'length + 1; -- pipe=1
    signal cdc_fifo_cdata           : std_logic_vector(39 downto 0) := (others => '0');
    signal cdc_fifo_ddata           : std_logic_vector(39 downto 0) := (others => '0');
    signal cdc_fifo_cq              : std_logic_vector(39 downto 0) := (others => '0');
    signal cdc_fifo_dq              : std_logic_vector(39 downto 0) := (others => '0');
    signal clane_error              : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    signal ccoe_ctrl_dpalock        : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    
    component cdc_fifo
	port (
		aclr		: in  std_logic  := '0';
		data		: in  std_logic_vector(39 downto 0);
		rdclk		: in  std_logic;
		rdreq		: in  std_logic;
		wrclk		: in  std_logic;
		wrreq		: in  std_logic;
		q		    : out std_logic_vector(39 downto 0)
    );
    end component;
    
    -- //////////////////////////////////////////////////
    --  locking_monitor  
    -- //////////////////////////////////////////////////
    constant locking_monitor_state_transition_cycles        : natural := 5; -- < 2**8-1
    constant locking_monitor_dpa_rst_interval               : natural := 10000; -- < 2**32-1
    constant locking_monitor_dpa_fail_cycles                : natural := 1000; -- < 2**16-1
    
    type locking_monitor_states_t is (IDLE, PLL_LOCKING, DPA_LOCKING, DPA_DETECTOR_LOCKING, FIFO_RESET, OK, HARD_RESET);
    type locking_monitors_states_t is array (0 to N_LANE-1) of locking_monitor_states_t;
    signal locking_monitor          : locking_monitors_states_t := (others => HARD_RESET);
    signal locking_monitor_next     : locking_monitors_states_t := (others => HARD_RESET);
    
    type locking_monitor_dpa_recheck_states_t is (CHECKING, OK, FAIL, IDLE);
    type locking_monitor_dpa_rechecks_states_t is array (0 to N_LANE-1) of locking_monitor_dpa_recheck_states_t;
    signal locking_monitor_dpa_recheck  : locking_monitor_dpa_rechecks_states_t := (others => IDLE);
    
    type grace_counters_t is array (0 to N_LANE-1) of unsigned(7 downto 0);
    signal grace_counter            : grace_counters_t := (others => (others => '0'));
    
    type dparsh_counters_t is array (0 to N_LANE-1) of unsigned(31 downto 0);
    signal dparsh_counter           : dparsh_counters_t := (others => (others => '0'));
    
    type dpafail_counters_t is array (0 to N_LANE-1) of unsigned(15 downto 0);
    signal dpafail_counter          : dpafail_counters_t := (others => (others => '0'));
    
    type locking_monitor_dpa_unlock_cnts_t is array (0 to N_LANE-1) of unsigned(31 downto 0);
    signal locking_monitor_dpa_unlock_cnt   : locking_monitor_dpa_unlock_cnts_t := (others => (others => '0'));
    
    -- //////////////////////////////////////////////////
    -- line_code_decoder_8b10b 
    -- //////////////////////////////////////////////////
    -- decoder
    type decoder_din_t is array (0 to 9) of std_logic_vector(9 downto 0);
    type decoder_dins_t is array (0 to N_LANE-1) of decoder_din_t;
    signal decoder_din              : decoder_dins_t;
    
    type decoder_dispi_t is array(0 to 9) of std_logic_vector(9 downto 0);
    signal decoder_dispi            : decoder_dispi_t;
    signal decoder_dispo            : decoder_dispi_t;
    signal decoder_coderr           : decoder_dispi_t;
    signal decoder_disperr          : decoder_dispi_t;
    
    type decoder_dout_t is array (0 to 9) of std_logic_vector(8 downto 0);
    type decoder_douts_t is array (0 to N_LANE-1) of decoder_dout_t;
    signal decoder_dout             : decoder_douts_t;
    
    -- word_aligner 
    type word_aligner_din_t is array (0 to N_LANE-1) of std_logic_vector(19 downto 0);
    signal word_aligner_din             : word_aligner_din_t;
    
    signal word_aligner_dout            : decoder_dins_t;
    
    type word_aligner_score_t is array (0 to 9) of unsigned(7 downto 0);
    type word_aligner_scores_t is array (0 to N_LANE-1) of word_aligner_score_t;
    signal word_aligner_score           : word_aligner_scores_t; -- this is 10 per lane
    
    type word_aligner_chosen_t is array (0 to N_LANE-1) of unsigned(DECODED_CHANNEL_WIDTH downto 0); -- one more bit here
    signal word_aligner_chosen          : word_aligner_chosen_t;
    signal word_aligner_chosen_reflect  : word_aligner_chosen_t;
    
    -- bit_sliper 
    type bit_sliper_t is (SLIP, MONITOR, OK, FAIL, IDLE);
    type bit_slipers_t is array (0 to N_LANE-1) of bit_sliper_t;
    signal bit_sliper                   : bit_slipers_t := (others => IDLE);
    signal bit_sliper_counter_en        : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    
    type bit_sliper_counter_t is array (0 to N_LANE-1) of unsigned(15 downto 0);
    signal bit_sliper_counter           : bit_sliper_counter_t := (others => (others => '0'));
    
    type bit_sliper_sync_cnt_t is array (0 to N_LANE-1) of unsigned(15 downto 0);
    signal bit_sliper_sync_cnt          : bit_sliper_sync_cnt_t := (others => (others => '0'));
    
    signal bit_sliper_valid             : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    
    signal bit_sliper_trained           : std_logic_vector(N_LANE-1 downto 0) := (others => '0');
    
    -- adaptive_aligner 
    type adaptive_aligner_t is (IDLE,DECIDING,LOCKING,LOCKED,RESET);
    type adaptive_aligners_t is array (0 to N_LANE-1) of adaptive_aligner_t;
    signal adaptive_aligner             : adaptive_aligners_t := (others => RESET);
    
    type adaptive_aligner_priority_t is array (0 to N_LANE-1) of std_logic_vector(9 downto 0);
    signal adaptive_aligner_priority    : adaptive_aligner_priority_t := (others => (0 => '1', others => '0'));
    
    signal adaptive_aligner_chosen       : adaptive_aligner_priority_t := (others => (others => '0'));
    signal word_aligner_next_grant_comb : adaptive_aligner_priority_t := (others => (others => '0'));
    signal adative_aligner_good_lanes_map   : adaptive_aligner_priority_t := (others => (others => '0'));
    
    type adaptive_aligner_score_t is array (0 to N_LANE-1) of unsigned(7 downto 0);
    signal adaptive_aligner_score        : adaptive_aligner_score_t := (others => (others => '0')); 

    
    
    
    -- ----------------------------------------------------------------------------------
    -- borrow from http://asics.chuckbenz.com/#My_open_source_8b10b_encoderdecoder
    -- > implemented in verilog
    -- > 20 years experience in asic/fpga design
    -- > compact and verified logics
    -- ----------------------------------------------------------------------------------
    component line_code_decoder_8b10b 
    port (
        datain      : in  std_logic_vector(9 downto 0);
        dispin      : in  std_logic;
        dataout     : out std_logic_vector(8 downto 0);
        dispout     : out std_logic;
        code_err    : out std_logic;
        disp_err    : out std_logic
    );
    end component line_code_decoder_8b10b;
    
    -- //////////////////////////////////////////////////
    -- assembler
    -- //////////////////////////////////////////////////
    type assembler_symbol_errors_t is array (0 to N_LANE-1) of unsigned(31 downto 0);
    signal assembler_symbol_errors             : assembler_symbol_errors_t := (others => (others => '0'));
    
    
    -- //////////////////////////////////////////////////
    -- ipc
    -- //////////////////////////////////////////////////
    type pipe_t is record
        start       : std_logic;
        done        : std_logic;
    end record;
    type pipes_t is record
        sliper2csr  : pipe_t;
    end record;
    --signal pipe     : pipes_t;
    signal dpipe    : pipes_t;
    signal cpipe    : pipes_t;
    
    
    
    
    
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
    function word_aligner_next_grant(
        imap        : std_logic_vector(9 downto 0);
        ipriority   : std_logic_vector(9 downto 0)
    ) return std_logic_vector is 
        variable result0        : std_logic_vector(19 downto 0);
        variable result0p5      : std_logic_vector(19 downto 0);
        variable result1        : std_logic_vector(19 downto 0);
        variable result2        : std_logic_vector(19 downto 0);
        variable next_grant     : std_logic_vector(9 downto 0);      
    begin
        result0		:= imap & imap;
        result0p5   := not imap & not imap;
        result1     := std_logic_vector(unsigned(result0p5) + unsigned(ipriority));
        result2     := result0 and result1;
        
        if (or_reduce(result2(9 downto 0)) = '0') then 
			next_grant		:= result2(19 downto 10);
		else
			next_grant		:= result2(9 downto 0);
		end if;

        return next_grant;
    end function;
    
    
    
begin
    -- //////////////////////////////////////////////////
    -- generic_checks
    -- //////////////////////////////////////////////////
    assert N_LANE <= 32 report "N_LANE must be smaller than or equal to 32" severity error;
    assert SYNC_PATTERN = "0011111010" report "SYNC PATTERN is not set to default, not k28.5" severity warning;
    assert CDC_C2D_WIDTH <= cdc_fifo_cdata'length report "CDC FIFO is not wide enough" severity error;

    -- //////////////////////////////////////////////////
    -- csr_interface
    -- //////////////////////////////////////////////////
    proc_csr_interface : process (csi_control_clk, rsi_control_reset)
    begin
        if rising_edge(csi_control_clk) then 
            if (rsi_control_reset = '1') then 
                avs_csr_waitrequest     <= '0'; -- release bus
                csr.sync_pattern        <= SYNC_PATTERN;
                csr.mode_mask           <= (others => '1');
                csr.soft_reset_req      <= (others => '0');
                csr.dpa_hold            <= (others => '0');
                csr.lane_go             <= (others => '1');
                csr.symbol_errors       <= (others => (others => '0'));
                csr.dpa_unlocks         <= (others => (others => '0'));
                csr.lane_selection      <= (others => '0');
                csr.rollover_errors     <= (others => (others => '0'));
            else
                -- default
                avs_csr_waitrequest     <= '1';
                avs_csr_readdata        <= (others => '0');
                -- ----------------
                -- 1) avalon read
                -- ----------------
                if (avs_csr_read = '1') then 
                    avs_csr_waitrequest     <= '0';
                    case to_integer(unsigned(avs_csr_address)) is 
                        when 0 => -- capability (sync_pattern|n_lanes)
                            avs_csr_readdata(25 downto 16)      <= csr.sync_pattern;
                            avs_csr_readdata(7 downto 0)        <= std_logic_vector(to_unsigned(N_LANE,8));
                        when 1 => -- control (mode_mask(0=bit_slip;1=adaptive_selection)) 
                            avs_csr_readdata(csr.mode_mask'high downto 0)       <= csr.mode_mask;
                        when 2 => -- control (soft_reset_req(0=done;1=request))
                            avs_csr_readdata(csr.soft_reset_req'high downto 0)  <= csr.soft_reset_req;
                        when 3 => -- control (dpa_hold(0=disable;1=enable))
                            avs_csr_readdata(csr.dpa_hold'high downto 0)        <= csr.dpa_hold;
                        when 4 => -- control (lane_go(0=disable;1=enable))
                            avs_csr_readdata(csr.lane_go'high downto 0)         <= csr.lane_go;
                        -- lane error counts
                        when 0+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(0)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(0) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 1+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(1)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(1) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 2+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(2)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(2) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 3+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(3)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(3) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 4+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(4)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(4) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 5+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(5)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(5) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 6+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(6)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(6) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 7+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(7)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(7) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        when 8+5 => 
                            -- good: training ok
                            avs_csr_readdata(31 downto 0)       <= csr.symbol_errors(8)(31 downto 0);
                            -- fatal error: training fail (mask error counter to 0xFFFFFFFF) 
                            if (clane_error(8) = '1') then 
                                avs_csr_readdata(31 downto 0)   <= (others => '1');
                            end if;
                        -- debug registers (port-mapped)
                        when N_LANE+5 => -- port selection
                            avs_csr_readdata(csr.lane_selection'high downto 0)  <= csr.lane_selection;
                        when N_LANE+6 => -- lane dpa unlocks
                            for i in 0 to N_LANE-1 loop
                                if (csr.lane_selection = std_logic_vector(to_unsigned(i,csr.lane_selection'length))) then 
                                    avs_csr_readdata  <= csr.dpa_unlocks(i);
                                end if;
                            end loop;
                        when N_LANE+7 => -- lane word aligner chosen (if in adaptive selection mode)
                             for i in 0 to N_LANE-1 loop
                                if (csr.lane_selection = std_logic_vector(to_unsigned(i,csr.lane_selection'length))) then 
                                    avs_csr_readdata(adaptive_aligner_chosen(i)'high downto 0)  <=  std_logic_vector(adaptive_aligner_chosen(i));
                                end if;
                             end loop;
                        
              
                        when others =>
                            null;
                    end case;
                -- ------------------
                -- 2) avalon write
                -- ------------------
                elsif (avs_csr_write = '1') then 
                    avs_csr_waitrequest     <= '0';
                    case to_integer(unsigned(avs_csr_address)) is 
                        when 0 => -- capability (sync_pattern|n_lanes)
                            csr.sync_pattern        <= avs_csr_writedata(25 downto 16);
                        when 1 => -- control (mode_mask(0=bit_slip;1=adaptive_selection)) 
                            csr.mode_mask           <= avs_csr_writedata(csr.mode_mask'high downto 0);
                        when 2 => -- control (soft_reset_req(0=done;1=request))
                            csr.soft_reset_req      <= avs_csr_writedata(csr.soft_reset_req'high downto 0);
                        when 3 => -- control (dpa_hold(0=disable;1=enable))
                            csr.dpa_hold            <= avs_csr_writedata(csr.dpa_hold'high downto 0);
                        when 4 => -- control (lane_go(0=disable;1=enable))
                            csr.lane_go             <= avs_csr_writedata(csr.lane_go'high downto 0);
                        -- TODO: implement the 8b10b error counts
                        when N_LANE+5 => -- port selection
                            csr.lane_selection      <= avs_csr_writedata(csr.lane_selection'high downto 0);
                        when others =>  
                    end case;
                -- --------------------------------
                -- 3) routine to update registers
                -- --------------------------------
                else 
                    -- handler for the pipe sliper -> csr
                    for i in 0 to N_LANE-1 loop
                        -- update the dpa_unlocks counters
                        csr.dpa_unlocks(i)     <= std_logic_vector(locking_monitor_dpa_unlock_cnt(i));
                        
                        -- -> update the rollover_errors counters
                        if (cpipe.sliper2csr.start = '1' and cpipe.sliper2csr.done = '0') then -- update request from sliper2csr
                            csr.rollover_errors(i)      <= csr.rollover_errors(i) + 1;
                            cpipe.sliper2csr.done        <= '1'; -- ack the sliper
                        elsif (cpipe.sliper2csr.start = '1' and cpipe.sliper2csr.done = '1') then -- wait for sliper to ack back
                            -- wait
                        elsif (cpipe.sliper2csr.start = '0' and cpipe.sliper2csr.done = '1') then -- sliper ack'd
                            cpipe.sliper2csr.done        <= '0'; -- finish the routine
                        else
                            -- idle
                        end if;
                        
                        -- unset the reset request
                        if (csr.soft_reset_req(i) = '1') then 
                            if (locking_monitor(i) = IDLE) then 
                                csr.soft_reset_req(i)       <= '0';
                            end if;
                        end if;
                        
                        -- update error registers 
                        csr.symbol_errors(i)        <= std_logic_vector(assembler_symbol_errors(i)); -- TODOL handle CDC here
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
    --
    
    proc_cdc_fifo_comb : process (all)
    begin
        -- default
        cdc_fifo_cdata       <= (others => '0'); -- 40 bit
        for i in 0 to N_LANE-1 loop 
            if (locking_monitor(i) = OK) then 
                locking_monitor_ok(i)       <= '1';
            else 
                locking_monitor_ok(i)       <= '0';
            end if;
        end loop;
        -- connect
        -- -- c2d (control to data)
        -- -- -- sync_pattern
        cdc_fifo_cdata(9 downto 0)      <= csr.sync_pattern;
        dcsr.sync_pattern               <= cdc_fifo_dq(9 downto 0);
        -- -- -- mode_mask
        cdc_fifo_cdata(N_LANE+9 downto 10)      <= csr.mode_mask;
        dcsr.mode_mask                          <= cdc_fifo_dq(N_LANE+9 downto 10);
        -- -- -- soft_reset_req                 
        cdc_fifo_cdata(2*N_LANE+9 downto N_LANE+10)     <= csr.soft_reset_req;
        dcsr.soft_reset_req                             <= cdc_fifo_dq(2*N_LANE+9 downto N_LANE+10);
        -- -- -- locking_monitor
        cdc_fifo_cdata(3*N_LANE+9 downto 2*N_LANE+10)   <= locking_monitor_ok;
        dlocking_monitor_ok                             <= cdc_fifo_dq(3*N_LANE+9 downto 2*N_LANE+10);
        -- -- -- pipe
        cdc_fifo_cdata(3*N_LANE+10)                     <= cpipe.sliper2csr.done;
        dpipe.sliper2csr.done                           <= cdc_fifo_dq(3*N_LANE+10);
        -- =======================
        -- -- d2c (data to control)
        -- -- -- pipe
        cdc_fifo_ddata(0)                               <= dpipe.sliper2csr.start;
        cpipe.sliper2csr.start                          <= cdc_fifo_cq(0);
        -- -- -- symbol_errors
        cdc_fifo_ddata(0+1)                          <= aso_decoded0_error(2);
        cdc_fifo_ddata(1+1)                          <= aso_decoded1_error(2);
        cdc_fifo_ddata(2+1)                          <= aso_decoded2_error(2);
        cdc_fifo_ddata(3+1)                          <= aso_decoded3_error(2);
        cdc_fifo_ddata(4+1)                          <= aso_decoded4_error(2);
        cdc_fifo_ddata(5+1)                          <= aso_decoded5_error(2);
        cdc_fifo_ddata(6+1)                          <= aso_decoded6_error(2);
        cdc_fifo_ddata(7+1)                          <= aso_decoded7_error(2);
        cdc_fifo_ddata(8+1)                          <= aso_decoded8_error(2);
        cdc_fifo_ddata(2*N_LANE downto N_LANE+1)        <= coe_ctrl_dpalock;
        ccoe_ctrl_dpalock                               <= cdc_fifo_cq(2*N_LANE downto N_LANE+1);
        
        
        clane_error                                     <= cdc_fifo_cq(N_LANE downto 1);
        -- TODO...
    end process;
    
    
    
    cdc_fifo_unit_c2d : cdc_fifo -- control to data 
	port map (
		aclr		=> rsi_control_reset,
		data		=> cdc_fifo_cdata, -- 40 bit 
		rdclk		=> csi_data_clk,
		rdreq		=> '1',
		wrclk		=> csi_control_clk,
		wrreq		=> '1',
		q		    => cdc_fifo_dq
    );
    
    cdc_fifo_unit_d2c : cdc_fifo -- data to control
	port map (
		aclr		=> rsi_control_reset,
		data		=> cdc_fifo_ddata, -- 40 bit 
		rdclk		=> csi_control_clk,
		rdreq		=> '1',
		wrclk		=> csi_data_clk,
		wrreq		=> '1',
		q		    => cdc_fifo_cq
    );
    
    
    
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @name        locking_monitor  
    --
    -- @berief      Performs the locking sequence for the LVDS_RX IP. Continuously monitors dpa locking status.
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    proc_locking_monitor : process (csi_control_clk, rsi_control_reset)
    begin
        if rising_edge(csi_control_clk) then 
            if (rsi_control_reset = '1') then 
                locking_monitor         <= (others => HARD_RESET);
                locking_monitor_next    <= (others => HARD_RESET);
                coe_ctrl_pllrst         <= '0';
                coe_ctrl_dparst         <= (others => '0');
                coe_ctrl_lockrst        <= (others => '0');
                coe_ctrl_dpahold        <= (others => '0');
                coe_ctrl_fiforst        <= (others => '0');
            else 
                for i in 0 to N_LANE-1 loop
                    
                    -- -------------------------------
                    -- state transition delay logic
                    -- -------------------------------
                    if (locking_monitor_next(i) /= locking_monitor(i)) then 
                        grace_counter(i)    <= grace_counter(i) + 1;
                    else
                        grace_counter(i)    <= (others => '0');
                    end if;
                    if (grace_counter(i) = locking_monitor_state_transition_cycles) then 
                        locking_monitor(i)     <= locking_monitor_next(i);
                    end if;
                    -- ---------------------
                    -- dpa refresh counter
                    -- ---------------------
                    if (locking_monitor(i) = OK and csr.dpa_hold(i) = '0' and locking_monitor_dpa_recheck(i) = OK) then -- counter starts in OK state and dpa not in-hold
                        dparsh_counter(i)   <= dparsh_counter(i) + 1;
                    else 
                        dparsh_counter(i)   <= (others => '0');
                    end if;
                    -- ------------------------------
                    -- dpa locking failure counter
                    -- ------------------------------
                    if (locking_monitor_dpa_recheck(i) = CHECKING) then 
                        dpafail_counter(i)  <= dpafail_counter(i) + 1;
                    else
                        dpafail_counter(i)  <= (others => '0');
                    end if;
                        
                    -- ------------------    
                    -- main fsm logic
                    -- ------------------
                    -- TODO: handle CDC from lvds_rx signal (data) to this fsm (control)
                    case locking_monitor(i) is
                        -- idle until this monitor of the lane is enabled
                        when IDLE =>
                            coe_ctrl_pllrst                 <= '0';
                            coe_ctrl_dparst(i)              <= '0';
                            coe_ctrl_lockrst(i)             <= '0';
                            coe_ctrl_fiforst(i)             <= '0';
                            locking_monitor_dpa_recheck(i)  <= IDLE;
                            if (csr.lane_go(i)) then 
                                locking_monitor_next(i)     <= PLL_LOCKING;
                            end if;
                        -- confirm iopll is locked (it must be, unless there was a power-up or hard-reset event)
                        when PLL_LOCKING =>
                            if (coe_ctrl_plllock = '1') then 
                                locking_monitor_next(i)     <= DPA_LOCKING;
                                coe_ctrl_dparst(i)          <= '1';
                            end if;
                        -- confirm dpa circuitry has locked to the optimal 45?? phase to the incoming data
                        when DPA_LOCKING => 
                            coe_ctrl_dparst(i)      <= '0';
                            if (ccoe_ctrl_dpalock(i) = '1') then 
                                locking_monitor_next(i)     <= DPA_DETECTOR_LOCKING;
                                coe_ctrl_lockrst(i)         <= '1';
                            end if; 
                        -- re-confirm by reset the lock circuitry to re-examine the lock status
                        when DPA_DETECTOR_LOCKING => -- you may enable dpll_hold at end of this stage
                            coe_ctrl_lockrst(i)     <= '0'; -- confirm it is really locked, you must assert this from time to time to re-confirm the locking status
                            if (ccoe_ctrl_dpalock(i) = '1') then 
                                locking_monitor_next(i)      <= FIFO_RESET;
                                coe_ctrl_fiforst(i)          <= '1';
                            end if;
                        -- reset the fifo for data stream correctness, only 6-bit deep, so not really necessary
                        when FIFO_RESET =>
                            coe_ctrl_fiforst(i)         <= '0';
                            locking_monitor_next(i)     <= OK;
                        -- normal functional state, checks the dpa locking or hold the dpa. 
                        -- NOTE: the rx_dpa_locked signal is asserted after the DPA circuitry acquires an initial lock to the optimum phase
                        when OK =>
                            -- -----------------------
                            -- hold dpa upon request
                            -- -----------------------
                            if (csr.dpa_hold(i)) then 
                                coe_ctrl_dpahold(i)     <= '1';
                            else 
                                coe_ctrl_dpahold(i)     <= '0';
                            end if;
                            -- (only when dpa_hold is false)
                            -- check dpa lock 
                            -- ---------------------
                            -- 1) reset dpa lock
                            -- ---------------------
                            if (dparsh_counter(i) > locking_monitor_dpa_rst_interval-5 and dparsh_counter(i) < locking_monitor_dpa_rst_interval) then -- triggered by the counter
                                coe_ctrl_lockrst(i)      <= '0'; -- this lock reset requres 2 cycles to propergate
                                -- NOTE: on this device family (arria V) do not assert this. -> it might generate a few bytes errors.
                                -- however, this monitor is no longer meaningful. (as it will keep locked)
                            elsif (dparsh_counter(i) = locking_monitor_dpa_rst_interval) then 
                                locking_monitor_dpa_recheck(i)      <= CHECKING;
                            else 
                                coe_ctrl_lockrst(i)      <= '0';
                            end if;
                            -- ---------------------------------
                            -- 2) check after 200~300 cycles
                            -- ---------------------------------
                            case locking_monitor_dpa_recheck(i) is 
                                when CHECKING => 
                                    if (dpafail_counter(i)  < locking_monitor_dpa_fail_cycles) then 
                                        if (ccoe_ctrl_dpalock(i) = '1') then 
                                            locking_monitor_dpa_recheck(i)      <= OK;
                                        end if;
                                    else 
                                        locking_monitor_dpa_recheck(i)          <= FAIL;
                                        locking_monitor_dpa_unlock_cnt(i)       <= locking_monitor_dpa_unlock_cnt(i) + 1;
                                    end if;
                                when OK => -- 3.0) loop to check
                                    -- triggered to by dparst 
                                    if (coe_ctrl_lockrst(i) = '1') then 
                                        locking_monitor_dpa_recheck(i)      <= CHECKING;
                                    end if;
                                    -- can be soft reset by csr or datapath critical error
                                when FAIL => -- (trap state) report error and init soft reset 
                                    -- 3.1) start soft-reset sequence
                                    locking_monitor_next(i)             <= IDLE;
                                when IDLE =>
                                    locking_monitor_dpa_recheck(i)      <= OK;
                                when others =>
                                    null;
                            end case;
                            
                        when HARD_RESET => -- triggers a reset also in the datapath
                            locking_monitor_dpa_recheck(i)      <= IDLE;
                            locking_monitor_dpa_unlock_cnt(i)   <= (others => '0'); -- reset the counter here
                            coe_ctrl_pllrst                     <= '0'; -- keep the LVDS PLL clock running through controller reset
                            locking_monitor_next(i)             <= IDLE;
                            coe_ctrl_dparst(i)                  <= '1';
                            coe_ctrl_lockrst(i)                 <= '1';
                            coe_ctrl_fiforst(i)                 <= '1';
                        when others =>
                            null;
                    end case;
                    -- --------------------------------------------------
                    -- reset if loss-of-signal reported by the re-driver
                    -- --------------------------------------------------
                    if (coe_redriver_losn(i) = '0') then 
                        locking_monitor_next(i)         <= IDLE;
                    end if;
                    -- -----------------------------------
                    -- handle the reset request from csr
                    -- -----------------------------------
                    if (csr.soft_reset_req(i) = '1') then 
                        locking_monitor_next(i)         <= IDLE;
                        locking_monitor_dpa_recheck(i)  <= IDLE;
                    end if;
            end loop;
            end if;
        end if;
    end process;
    
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @name         symbol_decoder
    --
    -- @brief        Decodes the line code from symbol (10b) into word (8b+1k). 
    -- @input        <jhgfiedcba> - the raw 10b symbol
    -- @output       <khgfedcba> - the decoded word, with <k> as the control "K" flag bit 
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- Note: the LVDS RX IP from altera should follow this convention of <abcdei fghj>, so we need to reverse the symbol in bit ordering.
    gen_decoder_per_lane : for i in 0 to N_LANE-1 generate
        gen_decoder_per_choice : for j in 0 to 9 generate 
            c_line_code_decoder : component line_code_decoder_8b10b
            port map (
            -- ---------------------------------------------------
            --  <int sig>        <ext sig>              <width>
            -- ---------------------------------------------------
                datain      => decoder_din(i)(j),       -- 10
                dispin      => decoder_dispi(i)(j),     -- 1
                dataout     => decoder_dout(i)(j),      -- 9
                dispout     => decoder_dispo(i)(j),     -- 1
                code_err    => decoder_coderr(i)(j),    -- 1
                disp_err    => decoder_disperr(i)(j)    -- 1
            );
        end generate;
    end generate;
    
    proc_word_boundary_aligner_comb : process(all)
    begin
        for i in 0 to N_LANE-1 loop
           -- protect when IDLE -> DECIDING, good_lanes_map has changed back to zeros. (this shouldn't happen. TODO: debug this)
           word_aligner_next_grant_comb(i)     <= word_aligner_next_grant(adative_aligner_good_lanes_map(i), adaptive_aligner_priority(i));
        end loop;
    end process;
    
    -- both control plane failure or soft reset req by csr can trigger it going in reset state.
    -- the downstream should raise error bit[2] to indicate lane training error. 
    proc_word_boundary_aligner : process (rsi_data_reset, csi_data_clk) 
    begin
        if rising_edge(csi_data_clk) then 
            if (rsi_data_reset = '1') then 
                bit_sliper          <= (others => IDLE);
                adaptive_aligner    <= (others => RESET);
                coe_ctrl_bitslip    <= (others => '0');
            else 
                -- ---------------------------
                -- word aliger main logic
                -- ---------------------------
                for i in 0 to N_LANE-1 loop
                    -- ------------------------------------------------------
                    -- form 10 possbilities of boundary alignments
                    -- ------------------------------------------------------
                    word_aligner_din(i)(9 downto 0)     <= coe_parallel_data(10*i+9 downto 10*i);
                    word_aligner_din(i)(19 downto 10)   <= word_aligner_din(i)(9 downto 0);
                    for j in 0 to 9 loop
                        word_aligner_dout(i)(j)             <= word_aligner_din(i)(19-j downto 10-j); -- word_aligner_dout -> [ decoder ] -> errors -> scores (we examine this)
                    end loop;
                    
                    case dcsr.mode_mask(i) is 
                        -- ------------------------------
                        -- -- 1) adaptive selection mode
                        -- ------------------------------
                        -- @berief      Use two-column registers with height of 10 bits to form 10 choices.
                        --              Select the choice with least error. 
                        -- @input       <coe_parallel_data> - parallel 10b data from LVDS_RX IP
                        -- @output      <word_aligner_chosen> - the chosen lane (0xff... = bad choice)
                        --              <adaptive_aligner> - state of the lane (LOCKED = good boundary)
                        when '1' => 
                            -- ------------------------------------------------------
                            -- tracking quality score of each choice
                            -- ------------------------------------------------------
                            for j in 0 to 9 loop
                                if (decoder_coderr(i)(j) = '1' or decoder_disperr(i)(j) = '1') then 
                                    if (word_aligner_score(i)(j) /= 0) then -- prevent underflow 
                                        word_aligner_score(i)(j)    <= word_aligner_score(i)(j) - 1;
                                    end if; 
                                else
                                    if (word_aligner_score(i)(j) /= 150) then -- TODO: set this threshold
                                        word_aligner_score(i)(j)        <= word_aligner_score(i)(j) + 1;
                                    end if;
                                end if;
                            end loop;
                            -- ------------------------------------------------------
                            -- select the lane with score larger than a threshold. TODO: use a sorter to find the max score
                            -- ------------------------------------------------------
                            -- default 
                            word_aligner_chosen(i)          <= (others => '1'); -- -1 (signed) or 32 (unsigned)
                            word_aligner_chosen_reflect(i)  <= (word_aligner_chosen_reflect(i)'high => '1', others => '0'); -- -16 (signed) or 16 (unsigned)
                            -- note: both are not possible in legal selection range of [0 9]; their defaults should be unequal.
                            
                            -- good score from lsb to msb
                            for j in 0 to 9 loop
                                if (word_aligner_score(i)(j) > 100) then -- TODO: set the threshold
                                    word_aligner_chosen(i)      <= to_unsigned(j,word_aligner_chosen(i)'length);
                                end if;
                            end loop;
                            -- good score from msb to lsb
                            for j in 9 downto 0 loop
                                if (word_aligner_score(i)(j) > 100) then 
                                    word_aligner_chosen_reflect(i)      <= to_unsigned(j,word_aligner_chosen_reflect(i)'length);
                                end if;
                            end loop;
                            
                            
                            case adaptive_aligner(i) is 
                                when IDLE => -- find good choice(s) and iterate through all good choices
                                    for j in 0 to 9 loop
                                        if (word_aligner_score(i)(j) > 100) then 
                                            adative_aligner_good_lanes_map(i)(j)   <= '1';
                                             -- if there is any good choice, goto deciding 
                                            adaptive_aligner(i)                    <= DECIDING;
                                        else 
                                            adative_aligner_good_lanes_map(i)(j)   <= '0';
                                        end if;
                                    end loop;
                                when DECIDING => -- choose the next choice 
                                    -- update priority (<=====) (for the sake of next time you visit this)
                                    adaptive_aligner_priority(i)        <= word_aligner_next_grant_comb(i)(8 downto 0) & word_aligner_next_grant_comb(i)(9);
                                    -- latch grant 
                                    adaptive_aligner_chosen(i)          <= word_aligner_next_grant_comb(i);
                                    -- jump to normal op state
                                    adaptive_aligner(i)                 <= LOCKING;
                                when LOCKING => 
                                    -- get the score 
                                    for j in 0 to 9 loop 
                                        if (adaptive_aligner_chosen(i)(j) = '1') then 
                                            adaptive_aligner_score(i)        <= word_aligner_score(i)(j);
                                        end if;
                                    end loop;
                                    adaptive_aligner(i)                 <= LOCKED;
                                when LOCKED => -- monitor the score
                                    -- get the score 
                                    for j in 0 to 9 loop 
                                        if (adaptive_aligner_chosen(i)(j) = '1') then 
                                            adaptive_aligner_score(i)        <= word_aligner_score(i)(j);
                                        end if;
                                    end loop;
                                    -- escape condition: error due to not enough score -> choose another choice and do it again
                                    if (adaptive_aligner_score(i) < 100) then 
                                        adaptive_aligner(i)         <= IDLE;
                                    end if;
                                    
                                    
                                when RESET =>
                                    if (dlocking_monitor_ok(i) = '1') then 
                                        adaptive_aligner(i)                 <= IDLE;
                                    end if;
                                    adaptive_aligner_priority(i)        <= (0 => '1', others => '0');
                                    adaptive_aligner_score(i)           <= (others => '0');
                                    adaptive_aligner_chosen(i)          <= (others => '0');
                                    adative_aligner_good_lanes_map(i)   <= (others => '0');
                            
                                when others =>  
                                    null;
                            end case;

         
                            -- handle the reset request from csr
                            if (dcsr.soft_reset_req(i) = '1' or dlocking_monitor_ok(i) /= '1' or or_reduce(adaptive_aligner_priority(i)) = '0') then -- bad signal from control plane
                                word_aligner_din(i)         <= (others => '0'); -- this should be enough
                                adaptive_aligner(i)         <= RESET; -- need for priority all zeros. TODO: debug this?
                            end if;
                            
                            -- turn off the other mode
                            bit_sliper(i)       <= IDLE;
                            
                           
                        -- ------------------------------    
                        -- -- 2) bit slip mode
                        -- ------------------------------
                        -- @berief      Slips the bit until the correct word boundary is found. Monitor after found.
                        --
                        -- @input       <coe_parallel_data> - parallel 10b data from LVDS_RX IP
                        --              <dlocking_monitor_ok> - parallel 10b data is valid
                        -- @output      <bit_sliper_valid> - flag to indicate the 10b data from LVDS_RX IP is well-aligned.
                        --              <pipe.sliper2csr.start> - if rollover is reached and no boundary can be found. 
                        --                                        this will trigger one update of the counter in csr. 
                        when '0' => -- bit slip
                            case bit_sliper(i) is 
                                when SLIP => -- slip for one bit
                                    if (bit_sliper_counter(i) < 5) then -- at least 1 cycle
                                        bit_sliper_counter_en(i)    <= '1';
                                        coe_ctrl_bitslip(i)         <= '1';
                                    elsif (bit_sliper_counter(i) < 10) then -- at least 3 cycles
                                        coe_ctrl_bitslip(i)         <= '0';
                                    else 
                                        bit_sliper_counter_en(i)    <= '0';
                                        bit_sliper(i)               <= MONITOR;
                                    end if;
                                when MONITOR => -- monitor 
                                    if (bit_sliper_counter(i) < 4000) then -- TODO: tune this
                                        bit_sliper_counter_en(i)    <= '1';
                                        if (coe_parallel_data(10*i+9 downto 10*i) = dcsr.sync_pattern or coe_parallel_data(10*i+9 downto 10*i) = not dcsr.sync_pattern) then 
                                            bit_sliper_sync_cnt(i)  <= bit_sliper_sync_cnt(i) + 1;
                                        end if;
                                    elsif (bit_sliper_counter(i) = 4000) then
                                        bit_sliper_counter_en(i)    <= '0';
                                    else -- evaluation (4001+)
                                        bit_sliper_counter_en(i)    <= '0';
                                        bit_sliper_sync_cnt(i)      <= (others => '0');
                                        if (bit_sliper_sync_cnt(i) > 4) then -- requires 4 sync pattern in 2000 cycles, TODO: tune this
                                            bit_sliper(i)           <= OK;
                                        else 
                                            if (coe_ctrl_rollover(i) = '0') then -- not reaching the max yet, slip for another bit
                                                bit_sliper(i)           <= SLIP;
                                            else 
                                                bit_sliper(i)           <= FAIL;
                                            end if;
                                        end if;
                                    end if;
                                    -- handle the reset request from csr or error from control block
                                    if (dcsr.soft_reset_req(i) = '1' or dlocking_monitor_ok(i) /= '1') then 
                                        -- reset counters 
                                        bit_sliper(i)               <= IDLE;
                                        dpipe.sliper2csr.start      <= '0';
                                        bit_sliper_counter_en(i)    <= '0';
                                        bit_sliper_sync_cnt(i)      <= (others => '0');
                                        -- note: don't worry about current unfinished bit slips or early rollover, as the bitslip fifo should also be reset. 
                                        -- TODO: confirm the above
                                    end if;
                                when OK =>
                                    -- continuously monitor, tracking the boundary
                                    bit_sliper_trained(i)   <= '1'; -- status flag of lane trained 
                                    bit_sliper(i)           <= MONITOR;
                                    bit_sliper_valid(i)     <= '1'; -- raise this flag to indicate the parallel data is aligned and safe to use
                                when FAIL =>
                                    bit_sliper_trained(i)   <= '0';
                                    bit_sliper_valid(i)     <= '0'; -- lower this flag to indicate the parallel data is corrupt and re-alignment is in process
                                    -- 1) report error to csr
                                    if (dpipe.sliper2csr.start = '0' and dpipe.sliper2csr.done = '0') then 
                                        dpipe.sliper2csr.start      <= '1';
                                    elsif (dpipe.sliper2csr.start = '1' and dpipe.sliper2csr.done = '0') then -- wait for csr to ack
                                        -- idle
                                    elsif (dpipe.sliper2csr.start = '1' and dpipe.sliper2csr.done = '1') then -- csr ack'd it
                                        dpipe.sliper2csr.start      <= '0'; -- ack back
                                    else -- wait for csr to ack, escape early to prevent dead-lock 
                                    -- 2) slip again 
                                        bit_sliper(i)           <= SLIP;
                                    end if;
                                when IDLE =>
                                    bit_sliper_counter_en(i)    <= '0';
                                    bit_sliper_trained(i)       <= '0';
                                    if (dlocking_monitor_ok(i) = '1') then -- block until control block is ready 
                                        bit_sliper(i)       <= SLIP;
                                    end if;
                                when others =>
                                    null;
                            end case;
                            
                            -- turn off the other mode
                            adaptive_aligner(i)     <= RESET;
                        when others =>
                            null;
                    end case;
                    -- -------------------
                    -- sync counter 
                    -- -------------------
                    if (bit_sliper_counter_en(i) = '1') then 
                        bit_sliper_counter(i)       <= bit_sliper_counter(i) + 1;
                    else 
                        bit_sliper_counter(i)       <= (others => '0');
                    end if;
                    
                    -- block the word boundary alignment routine if the upstream control block failed to train the lane
                end loop;
            end if;
        end if;
    end process;
    
    
    proc_symbol_decoder : process (rsi_data_reset, csi_data_clk) 
    begin
        if rising_edge(csi_data_clk) then 
            if (rsi_data_reset = '1') then 
                decoder_dispi        <= (others => (others => '0'));
            else 
                -- connect the decoders 
                for i in 0 to N_LANE-1 loop -- per lane
                    for j in 0 to 9 loop -- per choice
                        for k in 0 to 9 loop -- per bit (reversal), NOTE: see above the reason why we need reversal
                            decoder_din(i)(j)(9-k)   <= word_aligner_dout(i)(j)(k);
                        end loop;
                        if (dlocking_monitor_ok(i) = '1') then -- unblock the decoder parity input if the dpa is locked 
                            decoder_dispi(i)(j)    <= decoder_dispo(i)(j);
                        else
                            decoder_dispi(i)(j)    <= '0';
                        end if;
                    end loop;
                end loop;
            end if;
        end if;
    end process;
    
    proc_dout_assembler : process (rsi_data_reset, csi_data_clk) 
    begin
        if rising_edge(csi_data_clk) then 
            if (rsi_data_reset = '1') then 
                assembler_symbol_errors     <= (others => (others => '0'));
            else 
                -- #########################################
                -- constructing interface <decoded0>
                -- #########################################
                aso_decoded0_channel     <= std_logic_vector(to_unsigned(0,aso_decoded0_channel'length));
                case dcsr.mode_mask(0) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(0) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(0)(j) = '1') then
                                    aso_decoded0_data      <= decoder_dout(0)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded0_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded0_error(1)              <= decoder_disperr(0)(j);
                                    -- error bit [0]
                                    aso_decoded0_error(0)              <= decoder_coderr(0)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded0_error(2)                <= '1';
                            aso_decoded0_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded0_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded0_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(0) = '1') then 
                            aso_decoded0_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded0_error(1)            <= decoder_disperr(0)(0); -- parity error
                            aso_decoded0_error(0)            <= decoder_coderr(0)(0); -- decode error
                        end if;
                        
                        aso_decoded0_data                <= decoder_dout(0)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(0) = '1') then 
                    assembler_symbol_errors(0)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded0_error(1) or aso_decoded0_error(0)) then 
                    assembler_symbol_errors(0)         <= assembler_symbol_errors(0) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded1>
                -- #########################################
                aso_decoded1_channel     <= std_logic_vector(to_unsigned(1,aso_decoded1_channel'length));
                case dcsr.mode_mask(1) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(1) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(1)(j) = '1') then
                                    aso_decoded1_data      <= decoder_dout(1)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded1_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded1_error(1)              <= decoder_disperr(1)(j);
                                    -- error bit [0]
                                    aso_decoded1_error(0)              <= decoder_coderr(1)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded1_error(2)                <= '1';
                            aso_decoded1_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded1_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded1_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(1) = '1') then 
                            aso_decoded1_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded1_error(1)            <= decoder_disperr(1)(0); -- parity error
                            aso_decoded1_error(0)            <= decoder_coderr(1)(0); -- decode error
                        end if;
                        
                        aso_decoded1_data                <= decoder_dout(1)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(1) = '1') then 
                    assembler_symbol_errors(1)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded1_error(1) or aso_decoded1_error(0)) then 
                    assembler_symbol_errors(1)         <= assembler_symbol_errors(1) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded2>
                -- #########################################
                aso_decoded2_channel     <= std_logic_vector(to_unsigned(2,aso_decoded2_channel'length));
                case dcsr.mode_mask(2) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(2) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(2)(j) = '1') then
                                    aso_decoded2_data      <= decoder_dout(2)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded2_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded2_error(1)              <= decoder_disperr(2)(j);
                                    -- error bit [0]
                                    aso_decoded2_error(0)              <= decoder_coderr(2)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded2_error(2)                <= '1';
                            aso_decoded2_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded2_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded2_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(2) = '1') then 
                            aso_decoded2_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded2_error(1)            <= decoder_disperr(2)(0); -- parity error
                            aso_decoded2_error(0)            <= decoder_coderr(2)(0); -- decode error
                        end if;
                        
                        aso_decoded2_data                <= decoder_dout(2)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(2) = '1') then 
                    assembler_symbol_errors(2)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded2_error(1) or aso_decoded2_error(0)) then 
                    assembler_symbol_errors(2)         <= assembler_symbol_errors(2) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded3>
                -- #########################################
                aso_decoded3_channel     <= std_logic_vector(to_unsigned(3,aso_decoded3_channel'length));
                case dcsr.mode_mask(3) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(3) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(3)(j) = '1') then
                                    aso_decoded3_data      <= decoder_dout(3)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded3_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded3_error(1)              <= decoder_disperr(3)(j);
                                    -- error bit [0]
                                    aso_decoded3_error(0)              <= decoder_coderr(3)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded3_error(2)                <= '1';
                            aso_decoded3_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded3_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded3_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(3) = '1') then 
                            aso_decoded3_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded3_error(1)            <= decoder_disperr(3)(0); -- parity error
                            aso_decoded3_error(0)            <= decoder_coderr(3)(0); -- decode error
                        end if;
                        
                        aso_decoded3_data                <= decoder_dout(3)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(3) = '1') then 
                    assembler_symbol_errors(3)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded3_error(1) or aso_decoded3_error(0)) then 
                    assembler_symbol_errors(3)         <= assembler_symbol_errors(3) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded4>
                -- #########################################
                aso_decoded4_channel     <= std_logic_vector(to_unsigned(4,aso_decoded4_channel'length));
                case dcsr.mode_mask(4) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(4) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(4)(j) = '1') then
                                    aso_decoded4_data      <= decoder_dout(4)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded4_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded4_error(1)              <= decoder_disperr(4)(j);
                                    -- error bit [0]
                                    aso_decoded4_error(0)              <= decoder_coderr(4)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded4_error(2)                <= '1';
                            aso_decoded4_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded4_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded4_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(4) = '1') then 
                            aso_decoded4_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded4_error(1)            <= decoder_disperr(4)(0); -- parity error
                            aso_decoded4_error(0)            <= decoder_coderr(4)(0); -- decode error
                        end if;
                        
                        aso_decoded4_data                <= decoder_dout(4)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(4) = '1') then 
                    assembler_symbol_errors(4)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded4_error(1) or aso_decoded4_error(0)) then 
                    assembler_symbol_errors(4)         <= assembler_symbol_errors(4) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded5>
                -- #########################################
                aso_decoded5_channel     <= std_logic_vector(to_unsigned(5,aso_decoded5_channel'length));
                case dcsr.mode_mask(5) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(5) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(5)(j) = '1') then
                                    aso_decoded5_data      <= decoder_dout(5)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded5_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded5_error(1)              <= decoder_disperr(5)(j);
                                    -- error bit [0]
                                    aso_decoded5_error(0)              <= decoder_coderr(5)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded5_error(2)                <= '1';
                            aso_decoded5_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded5_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded5_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(5) = '1') then 
                            aso_decoded5_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded5_error(1)            <= decoder_disperr(5)(0); -- parity error
                            aso_decoded5_error(0)            <= decoder_coderr(5)(0); -- decode error
                        end if;
                        
                        aso_decoded5_data                <= decoder_dout(5)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(5) = '1') then 
                    assembler_symbol_errors(5)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded5_error(1) or aso_decoded5_error(0)) then 
                    assembler_symbol_errors(5)         <= assembler_symbol_errors(5) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded6>
                -- #########################################
                aso_decoded6_channel     <= std_logic_vector(to_unsigned(6,aso_decoded6_channel'length));
                case dcsr.mode_mask(6) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(6) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(6)(j) = '1') then
                                    aso_decoded6_data      <= decoder_dout(6)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded6_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded6_error(1)              <= decoder_disperr(6)(j);
                                    -- error bit [0]
                                    aso_decoded6_error(0)              <= decoder_coderr(6)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded6_error(2)                <= '1';
                            aso_decoded6_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded6_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded6_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(6) = '1') then 
                            aso_decoded6_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded6_error(1)            <= decoder_disperr(6)(0); -- parity error
                            aso_decoded6_error(0)            <= decoder_coderr(6)(0); -- decode error
                        end if;
                        
                        aso_decoded6_data                <= decoder_dout(6)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(6) = '1') then 
                    assembler_symbol_errors(6)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded6_error(1) or aso_decoded6_error(0)) then 
                    assembler_symbol_errors(6)         <= assembler_symbol_errors(6) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded7>
                -- #########################################
                aso_decoded7_channel     <= std_logic_vector(to_unsigned(7,aso_decoded7_channel'length));
                case dcsr.mode_mask(7) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(7) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(7)(j) = '1') then
                                    aso_decoded7_data      <= decoder_dout(7)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded7_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded7_error(1)              <= decoder_disperr(7)(j);
                                    -- error bit [0]
                                    aso_decoded7_error(0)              <= decoder_coderr(7)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded7_error(2)                <= '1';
                            aso_decoded7_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded7_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded7_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(7) = '1') then 
                            aso_decoded7_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded7_error(1)            <= decoder_disperr(7)(0); -- parity error
                            aso_decoded7_error(0)            <= decoder_coderr(7)(0); -- decode error
                        end if;
                        
                        aso_decoded7_data                <= decoder_dout(7)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(7) = '1') then 
                    assembler_symbol_errors(7)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded7_error(1) or aso_decoded7_error(0)) then 
                    assembler_symbol_errors(7)         <= assembler_symbol_errors(7) + 1;
                end if;
                
                -- #########################################
                -- constructing interface <decoded8>
                -- #########################################
                aso_decoded8_channel     <= std_logic_vector(to_unsigned(8,aso_decoded8_channel'length));
                case dcsr.mode_mask(8) is 
                    when '1' => 
                        -- -------------------
                        -- for adaptive mode
                        -- -------------------
                        if (adaptive_aligner(8) = LOCKED) then 
                            -- -----------------------------
                            -- sync pattern found: YES
                            -- -----------------------------
                            for j in 0 to 9 loop 
                                -- connect the data and errors to the chosen decoder out of 10 possibilities
                                if (adaptive_aligner_chosen(8)(j) = '1') then
                                    aso_decoded8_data      <= decoder_dout(8)(j);
                                    -- ====================================================
                                    -- "loss_sync_pattern" "parity_error" "decode_error"
                                    -- ====================================================
                                    aso_decoded8_error(2)              <= '0';
                                    -- error bit [1]
                                    aso_decoded8_error(1)              <= decoder_disperr(8)(j);
                                    -- error bit [0]
                                    aso_decoded8_error(0)              <= decoder_coderr(8)(j);
                                    
                                end if;
                            end loop;
                        else 
                            -- -----------------------------
                            -- sync pattern found: NO
                            -- -----------------------------
                            -- in case of multiple choices are presented
                            -- error bit [2]
                            aso_decoded8_error(2)                <= '1';
                            aso_decoded8_error(1)                <= '0'; -- void the lower bits errors 
                            aso_decoded8_error(0)                <= '0'; -- void the lower bits errors 
                        end if;
                    
                    when '0' => 
                        -- -------------------
                        -- for slip mode
                        -- -------------------
                        -- default
                        aso_decoded8_error(2 downto 0)   <= "100"; -- untrained, so top bit has error 
                        
                        if (bit_sliper_trained(8) = '1') then 
                            aso_decoded8_error(2)            <= '0'; -- trained, so no training error, showing the lower bits as minor errors
                            aso_decoded8_error(1)            <= decoder_disperr(8)(0); -- parity error
                            aso_decoded8_error(0)            <= decoder_coderr(8)(0); -- decode error
                        end if;
                        
                        aso_decoded8_data                <= decoder_dout(8)(0);
                        
                    when others =>
                        null;
                end case;
                -- generate error register
                -- reset 
                if (dcsr.soft_reset_req(8) = '1') then 
                    assembler_symbol_errors(8)       <= (others => '0');
                end if;
                -- 1) decode + parity
                if (aso_decoded8_error(1) or aso_decoded8_error(0)) then 
                    assembler_symbol_errors(8)         <= assembler_symbol_errors(8) + 1;
                end if;
                
                
            end if;
        end if;
    
    end process;
    
    
   

end architecture rtl;

