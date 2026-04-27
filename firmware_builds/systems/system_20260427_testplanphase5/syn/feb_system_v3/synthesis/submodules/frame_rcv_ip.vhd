----------------------------------------------------------------------------------
-- Company:
-- Engineer: Huangshan Chen (chen@kip.uni-heidelberg.de)
-- Engineer2: Yifeng Wang (yifenwan@phys.ethz.ch)
--
-- Create Date: 16.05.2016 (IP packeged on 20.02.2024)
-- Design Name:
-- Module Name: frame receiver module
-- Project Name:
-- Target Devices: Arria V (Intel FPGA)
-- Tool versions: Quartus 18.1, Platform Designer 16.1
-- Description:
--
--      taking data from deserialzer, and form event data (YW: see more comments below for ip packaging)
--
-- Dependencies: crc16_calc.vhd (submodule)
--
-- Revision:
-- Revision 0.01 - File Created
-- Revision 1.00 - adpated to MuTRiG frame structure
-- Revision 1.10 - KB: Preparations for datapath_v2: Use record types, conversion of data depending on hit type
-- Revision 1.20 - YW: Adaptations/wrapping for IP packaging. (support stream data and avmm config)
-- Revision 1.21 - YW: Corrected the sop/eop to the first/last hit valid cycles. 
-- Revision 1.30 - YW: Fixed E-Flag field as the name suggests. The field was E-BadHit. Move T/E-BadHit to aso_error(0).
-- Revision 1.31 - YW: Correct long-hit compaction to drop only E_BadHit and E_fine.
-- Revision 1.33 - YW: Keep header detection alive during TERMINATING so delayed final drain frames are parsed.
-- Revision 1.34 - YW: Replace synthetic idle EOP with a dedicated end-of-run pulse after the final drain frame.
-- Revision 1.35 - YW: Guard TERMINATING idle-close until the upstream byte lane stays quiet long enough for a delayed final frame.
-- Revision 1.36 - YW: Close TERMINATING on the first empty frame and keep the idle guard only as a fallback.
-- Revision 1.37 - YW: Keep the dedicated CRC_CHECK cycle alive on idle-BC return so bad-CRC frames retire the sideband pulse and counter coherently.
-- Version : 26.0.6
-- Date    : 20260418
-- Change  : Keep CRC_CHECK alive on idle-BC return for bad-CRC accounting, then refresh the packaging/formal metadata around the verified fix batch.

-- Additional Comments:
--      IP wrapper layer: 
--              Input: lvds 8b1k data, forms packet of hits. 
--              Output: 1) mutrig packets in avst frame, 2) header info in avst.
--      Controlled by: 1) avst enable signal (standard RUN_SEQUENCE) 2) avmm CSR (debug mode to bypass/ignore errors/exceptions)
----------------------------------------------------------------------------------

-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;

entity frame_rcv_ip is
generic (
    -- +------------+
    -- | IP setting |
    -- +------------+
	CHANNEL_WIDTH           : natural := 4; -- width of the avst <channel> signal 
    CSR_ADDR_WIDTH          : natural := 2; -- width of the avmm csr <address> signal
    -- +----------------+
    -- | Error Handling |
    -- +----------------+
    MODE_HALT               : natural := 0; -- error handling of "frame_rcv" in lane corrupt incidence; 
                                            -- 1: ("IDLE" mode) do not resume frame parsing after corrupt. 0: ("HALT" mode) resume parsing after corrupt.
	-- +--------------------+
    -- | Generation setting |
    -- +--------------------+
    DEBUG_LV			    : natural := 0  -- debug level; 0: no debug. 1: syn and sim. 2: sim-only
);
port(
	-- AVST sink [rx8b1k]
    -- (input stream of 8b1k from lvds receiver)
	asi_rx8b1k_data					: in  std_logic_vector(8 downto 0);
	asi_rx8b1k_valid				: in  std_logic;
	asi_rx8b1k_error				: in  std_logic_vector(2 downto 0); 
    -- =============================================================
    -- <errorDescriptor>
    --      <bit2>                  <bit1>          <bit0>
    -- =============================================================
    -- old: disperr & decerr & lane_training_fail;
    -- new: "loss_sync_pattern"     "parity_error"  "decode_error"
	asi_rx8b1k_channel 				: in  std_logic_vector(CHANNEL_WIDTH-1 downto 0); -- the output channel is set by it
    -- NOTE: there is no pipeline for the channel signal along data path, so dynamic changing the channel is NOT supported yet. 
    -- TODO: you can implement this 
     
    -- AVST source [hit_type0]
	aso_hit_type0_channel			: out std_logic_vector(CHANNEL_WIDTH-1 downto 0); -- for asic 0-15
	aso_hit_type0_startofpacket		: out std_logic;
	aso_hit_type0_endofpacket		: out std_logic;
	aso_hit_type0_endofrun			: out std_logic;
	aso_hit_type0_error				: out std_logic_vector(2 downto 0); 
    -- =============================================================
    -- <errorDescriptor>
    -- <bit2>           <bit1>      <bit0>
    -- =============================================================
	-- "frame_corrupt" "crc_error" "hit_error"
    -- crc_error available as a post-frame sideband pulse
	-- hit_error available at "valid"
	aso_hit_type0_data				: out std_logic_vector(44 downto 0); -- valid is a seperate signal below
	aso_hit_type0_valid 			: out std_logic;

    -- AVST source [headerinfo]
    -- (header information)
	aso_headerinfo_data				: out std_logic_vector(41 downto 0);
	aso_headerinfo_valid			: out std_logic;
	aso_headerinfo_channel			: out std_logic_vector(CHANNEL_WIDTH-1 downto 0);

	-- AVMM slave [csr]
	-- (control and status registers)
	avs_csr_readdata				: out std_logic_vector(31 downto 0);
	avs_csr_read					: in  std_logic;
	avs_csr_address					: in  std_logic_vector(CSR_ADDR_WIDTH-1 downto 0);
	avs_csr_waitrequest				: out std_logic;
	avs_csr_write					: in  std_logic;
	avs_csr_writedata				: in  std_logic_vector(31 downto 0);
	
    -- AVST sink [ctrl]
	-- (management interface of run control timing)
	-- this signal is time critical and must be synchronzed for all datapath modules
	asi_ctrl_data			: in  std_logic_vector(8 downto 0); 
	asi_ctrl_valid			: in  std_logic;
	asi_ctrl_ready			: out std_logic;
	
    -- clock and reset interface 
    -- [data_reset] (data plane reset)
    i_rst                   : in std_logic; -- async reset assertion, sync reset release
    -- [data_clock] (data plane clock)
    i_clk                   : in std_logic -- clock should match the input lvds parallel clock

);
end entity frame_rcv_ip;

architecture rtl of frame_rcv_ip is

	constant TERMINATING_IDLE_GUARD_CONST : natural := 2048;

	-- Hit type (long) before sorter, before TCC division
	-- ==================================================================
    constant len_hit_presort : natural := 4 + 5 + 15 + 5 + 15 + 1 + 1; -- 46 bits (1bit for valid)
    type t_hit_presort is record
        asic            : std_logic_vector(3 downto 0);  -- ASIC ID
        channel         : std_logic_vector(4 downto 0);  -- Channel number
        T_CC            : std_logic_vector(14 downto 0); -- T-Trigger coarse time value (1.6ns)
        T_Fine          : std_logic_vector(4 downto 0);  -- T-Trigger fine time value
        T_BadHit        : std_logic;                     -- indicates CC is has bubble
        E_CC            : std_logic_vector(14 downto 0); -- Energy coarse time value (in units of 1.6ns)
        E_fine          : std_logic_vector(4 downto 0);
        E_BadHit        : std_logic;
        E_Flag          : std_logic;                     -- E-Flag valid flag
        valid           : std_logic;                     -- data word valid flag
		hiterr			: std_logic;
    end record;
    --type t_v_hit_presort is array (natural range <>) of t_hit_presort;
	
	-- 8b/10b symbols
	constant k28_0					: integer := 16#1C#; -- header
	constant k28_4					: integer := 16#9C#; -- trailer
	constant k28_5					: integer := 16#BC#; -- filler
	constant c_header				: std_logic_vector := std_logic_vector(to_unsigned(k28_0, 8));

    constant EVENT_DATA_WIDTH        : positive := 48;
    constant N_BYTES_PER_WORD        : positive := 6;
    constant N_BYTES_PER_WORD_SHORT  : positive := 3;

    signal s_o_word                     : std_logic_vector(EVENT_DATA_WIDTH-1 downto 0);
    signal p_word, n_word               : std_logic_vector(N_BYTES_PER_WORD*8 -1 downto 0);
    signal p_word_extra, n_word_extra   : std_logic_vector(3 downto 0);
    signal p_new_word, n_new_word       : std_logic;

    -- CRC specific signals
    signal s_crc_result                     : std_logic_vector(15 downto 0);
    -- start of a new CRC calculation
    signal p_crc_din_valid, n_crc_din_valid : std_logic;
    signal p_crc_rst, n_crc_rst             : std_logic;
    signal p_crc_err_count, n_crc_err_count : std_logic_vector(31 downto 0);
    signal p_crc_error, n_crc_error         : std_logic;
    signal p_end_of_frame, n_end_of_frame   : std_logic;
    signal s_o_frame_info                   : std_logic_vector(15 downto 0);

    -- frame information signals
    -- indicates a new frame
    signal p_new_frame, n_new_frame         : std_logic;
    signal p_frame_number, n_frame_number   : std_logic_vector(15 downto 0);
    signal p_word_cnt, n_word_cnt           : unsigned(9 downto 0);
    signal p_frame_len, n_frame_len         : std_logic_vector(9 downto 0);
     -- frame_flags : | i_SC_gen_idle_sig | i_SC_fast_mode | i_SC_prbs_debug | i_SC_single_prbs | p_fifo_full | '0' |
    signal p_frame_flags, n_frame_flags     : std_logic_vector(5 downto 0);
    signal p_frame_info_ready, n_frame_info_ready, enable : std_logic;
	signal hit_err							: std_logic;
	signal sop_comb,eop_comb				: std_logic;

    -- FSM states
    type FSM_states is (
        FS_IDLE,
        FS_FRAME_COUNTER,
        FS_EVENT_COUNTER,
        FS_UNPACK,
        FS_UNPACK_EXTRA,
        FS_CRC_CALC,
        FS_CRC_CHECK,
        FS_ERROR
    );
    signal p_state, n_state : FSM_states;
    signal p_state_wait_cnt, n_state_wait_cnt : natural range 7 downto 0; --cnt to wait withiin state


    signal p_txflag_isShort : std_logic;
    signal p_txflag_isCEC   : std_logic;
	 
	-- some depreciated io port signal are downgraded as internal signal
	-- data from lvds receiver
	signal i_data                  		: std_logic_vector(7 downto 0);
	signal i_byteisk               		: std_logic;
	
	-- header information
	signal o_hits						: t_hit_presort;
	signal o_frame_number				: std_logic_vector(15 downto 0);
	signal o_frame_info					: std_logic_vector(15 downto 0);
	signal o_frame_info_ready			: std_logic;
	signal o_new_frame					: std_logic;
	signal o_busy						: std_logic;
	 
	-- trailer information
	signal o_end_of_frame          		: std_logic;
	signal o_crc_error             		: std_logic;
	signal o_crc_err_count         		: std_logic_vector(31 downto 0);
	signal o_cec_flag              		: std_logic;
	signal o_cec_data              		: std_logic_vector(12*32-1 downto 0);
	
	-- control signal
	signal receiver_go						: std_logic; -- register record the setting, set by avst/avmm. 
	signal receiver_force_go				: std_logic;
	
	signal n_frame_info_ready_d1		: std_logic;
	signal aso_headerinfo_valid_comb	: std_logic;
	
	
	
	
	-- run control mgmt
	type run_state_t is (IDLE, RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST, SYNC_TEST, RESET, OUT_OF_DAQ, ERROR);
	signal run_state_cmd				: run_state_t;
	signal terminating_pending			: std_logic;
	signal terminating_endofrun_pulse	: std_logic;
	signal terminating_idle_guard_cnt	: natural range 0 to TERMINATING_IDLE_GUARD_CONST;
	signal terminating_empty_frame_done : std_logic;
	signal terminating_frame_start_seen : std_logic;
	signal ctrl_ready_comb				: std_logic;
    
    -- //////////////////////////////////////////////////
    -- avmm_slave_csr
    -- //////////////////////////////////////////////////
	type csr_t is record
		error_cnt		: std_logic_vector(31 downto 0);
		status			: std_logic_vector(7 downto 0); -- bit[5:0]: current frame flag
		control			: std_logic_vector(7 downto 0); -- bit 0: set to run(1)/set to stop(0)
		-- "running" is generate new frame, "idle" is finishing current frame and do not generate new frame
		-- "set to run" is enable, "set to stop" is enable_n (do not generate new frame). 
		-- exception to be implemented
        frame_counter       : std_logic_vector(31 downto 0);
        frame_counter_tail  : std_logic_vector(31 downto 0);
        frame_counter_head  : std_logic_vector(31 downto 0);
        crc_err_counter : std_logic_vector(31 downto 0);
	end record;
	signal csr 		: csr_t;
	 
begin

	aso_hit_type0_endofrun <= terminating_endofrun_pulse;
	asi_ctrl_ready <= ctrl_ready_comb;
	terminating_frame_start_seen <= '1' when (
		p_state = FS_IDLE and enable = '1' and i_byteisk = '1' and i_data = c_header
	) else '0';
	terminating_empty_frame_done <= '1' when (
		run_state_cmd = TERMINATING and p_state = FS_CRC_CHECK and unsigned(p_frame_len) = 0
	) else '0';
	ctrl_ready_comb <= '0' when i_rst = '1' else
	                  '1' when (
	                      ((run_state_cmd = IDLE) or (run_state_cmd = RUN_PREPARE) or (run_state_cmd = SYNC))
	                      and p_state = FS_IDLE
	                      and terminating_pending = '0'
	                  ) else
	                  '1' when run_state_cmd = RUNNING else
	                  '1' when (
	                      run_state_cmd = TERMINATING
	                      and p_state = FS_IDLE
	                      and terminating_pending = '0'
	                  ) else
	                  '0';

    -- ====================================================================================================
    -- @commentName     Recovery of bad frame for the downstream 
	-- 
    -- @comment         1) missing eop (sop-...-sop-eop) => frame corrupted
    --                          Pessimistic: Use a fifo to hold/discard the frame until the eop is seen.
    --                          Optimistic: Continuously process the event even if the eop is missing.
    --                  2) missing sop (...-eop-sop-eop) => frame corrupted
    --                          "IDLE" mode: Not possible.
    --                          "HALT" mode: The downstream can process the remaining events.
    -- ==================================================================================================== 
	
	
	-- ==================================================================================================== 
	-- @commentName     MuTRiG frame tx flags
    --
    -- @comment         0b000: Long event transmission
    --                  0b001: PRBS transmission, single event
    --                  0b010: PRBS transmission, saturating link
    --                  0b100: Short event transmission
    --                  0b110: Channel event counter data trans
	-- ====================================================================================================


    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       input_wrapper
    --
    -- @berief          mapping of the new avalon signal to the internal old signals of frame_rcv
    -- @input           <asi_rx8b1k_error(2)> -- "loss_sync_pattern" error
    --                  <asi_rx8b1k_data> -- from LVDS RX IP
    -- @output          <i_data> -- data to feed to "frame_rcv"
    --                  <i_byteisk> -- validate the <i_data>
    -- @note            The halt condition for the frame rcv fsm is [data=BC,byteisk=1].
	--                  Halt the fsm if the input is not valid, which should not happen unless the LVDS RX IP
    --                  is not in OK state.
	--                  Preventing it from parsing corrupted random digital lvds noise as hits. 
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	-- 
	proc_input_wrapper_comb : process (all)
	begin
        -- -----------------------------------------------
        -- connect the 8b data to frame_rcv entry point
        -- -----------------------------------------------
		if (asi_rx8b1k_error(2) = '0' and asi_rx8b1k_valid = '1') then
			i_data				<= asi_rx8b1k_data(7 downto 0);
			i_byteisk			<= asi_rx8b1k_data(8);
		else -- halt on invalid input or mask if "loss_sync_pattern" error is present
			i_data				<= x"BC";
			i_byteisk			<= '1';
		end if;
	end process proc_input_wrapper_comb;
	
	
	
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       output_header_info
    --
    -- @berief          avalon streaming interface for generate a "headerinfo" information
    -- @input           <n_frame_flags> - comb of the frame flags (gen_idle fast_mode prbs_debug single_prbs fifo_full pll_lol_n)
    --                  <n_frame_len> - frame length in number of events
    --                  <n_word_cnt> - number of event (runnnig index, incr. as the events are coming. Now at the sop should be '0')
    --                  <n_frame_number> - current frame number, aka "index"
    --                  <n_frame_info_ready> - ready signal, assert after the header is been decoded, deassert during frame idle
    -- @output          <aso_headerinfo_*> - interface signals
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	proc_output_header_info : process (i_clk,i_rst)
	begin
		if (i_rst = '1' ) then 
			aso_headerinfo_valid				<= '0';
		elsif rising_edge(i_clk) then
            -- ---------------------------
            -- packing interface signals 
            -- ---------------------------
            -- data
			aso_headerinfo_data(5 downto 0)		<= n_frame_flags;
			aso_headerinfo_data(15 downto 6)	<= n_frame_len;
			aso_headerinfo_data(25 downto 16)	<= std_logic_vector(n_word_cnt);
			aso_headerinfo_data(41 downto 26)	<= n_frame_number;
            -- valid
			aso_headerinfo_valid				<= aso_headerinfo_valid_comb;
            -- channel 
            aso_headerinfo_channel				<= asi_rx8b1k_channel;
            -- -------------
            -- pipeline 
            -- -------------
			n_frame_info_ready_d1				<= n_frame_info_ready;
		end if;
	end process proc_output_header_info;
    
    proc_output_header_info_comb : process (all)
	begin
        -- -----------------------------
        -- latch pulse for frame info
        -- -----------------------------
		if (n_frame_info_ready_d1 = '0') then
			aso_headerinfo_valid_comb		<= n_frame_info_ready_d1 xor n_frame_info_ready;
		else
			aso_headerinfo_valid_comb		<= '0';
		end if;
	end process proc_output_header_info_comb;
	

    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       avmm_slave_csr 
    --
    -- @berief          avalon memory-mapped interface for accessing the control and status registers
    -- @input           <avs_csr_*> - interface of avmm csr
    -- @output          <csr.*> - csr register pack
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    
    -- ====================================================================================================
	-- @tableName       csr address map
    -- 
    -- @offset_step     32 bit word
    -- @size            4
    -- ----------------------------------------------------------------------------------------------------
    -- <offset>         <name>              <access>    <description>
    -- ====================================================================================================
	-- 0                csr      
    -- ├── [7:0]            control         rw          [0]: '1/0'=enable/disable  
    -- └── [31:24]          status          ro          [5:0]: frame flag (gen_idle fast_mode prbs_debug single_prbs fifo_full pll_lol_n)
    --
	-- 1                error counter
    -- └── [31:0]           crc errors      ro          the number of frames with crc validation error, possibly corrupted
    --
	-- 2                frame counter
    -- └── [31:0]           total frames    ro          the number of total frames (only header and trailer are both seen is count as frame)
    -- ====================================================================================================
	proc_avmm_slave_csr : process (i_clk,i_rst)
	begin
		if rising_edge(i_clk) then
            if (i_rst = '0') then 
                -- default
                avs_csr_readdata			<= (others => '0');
                avs_csr_waitrequest		    <= '1';
                -- ---------------
                -- routine 
                -- ---------------
                -- head
                if (aso_hit_type0_startofpacket = '1') then 
                    csr.frame_counter_head          <= std_logic_vector(unsigned(csr.frame_counter_head) + 1);
                end if;
                
                -- tail
                if (aso_hit_type0_endofpacket = '1') then 
                    csr.frame_counter_tail          <= std_logic_vector(unsigned(csr.frame_counter_tail) + 1);
                end if; 
                
                -- head - tail = bad frame count, calculated at eop
                if (aso_hit_type0_endofpacket = '1') then 
                    csr.frame_counter               <= std_logic_vector(unsigned(csr.frame_counter_head) - unsigned(csr.frame_counter_tail));
                end if; 
                
                -- runctl reset
                if (run_state_cmd = RUN_PREPARE) then 
                    csr.frame_counter_head          <= (others => '0');
                    csr.frame_counter_tail          <= (others => '0');
                end if;
                -- ------------------
                -- avalon read
                -- ------------------
                if (avs_csr_read = '1') then
                    avs_csr_waitrequest		<= '0';
                    case (to_integer(unsigned(avs_csr_address))) is 
                        when 0 =>
                            avs_csr_readdata(31 downto 24)		<= csr.status;
                            avs_csr_readdata(7 downto 0)		<= csr.control;
                        when 1 =>
                            avs_csr_readdata					<= csr.crc_err_counter;
                        when 2 =>
                            avs_csr_readdata                    <= csr.frame_counter;
                        when others =>
                    end case;
                elsif (avs_csr_write = '1') then
                    avs_csr_waitrequest		<= '0';
                    case (to_integer(unsigned(avs_csr_address))) is
                        when 0 =>
                            csr.control		<= avs_csr_writedata(7 downto 0); 
                        when others =>
                    end case;	
                else -- idle, update values to/from agent
                    avs_csr_waitrequest		<= '1';
                    -- ------------------
                    -- update crc error
                    -- ------------------
                    csr.crc_err_counter		<= p_crc_err_count; -- continuously update crc error count
                    -- ------------------
                    -- update frame flag 
                    -- ------------------
                    if (n_frame_info_ready = '1') then 
                        csr.status(5 downto 0)		<= n_frame_flags;
                    end if;
                end if;
            else 
                csr.control		                <= (0 => '1', others => '0');
                csr.status		                <= (others => '0');
                csr.crc_err_counter	            <= (others => '0');
                csr.frame_counter               <= (others => '0');
                csr.frame_counter_head          <= (others => '0');
                csr.frame_counter_tail          <= (others => '0');
                avs_csr_waitrequest	            <= '0'; -- release the bus
            end if;
		end if;

	end process proc_avmm_slave_csr;
	

	-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       enable_ctrl 
    --
    -- @berief          controls whether "frame_rcv" can start parsing new frame or not
    -- @input           <receiver_force_go> - signal from "run_control_mgmt_agent", forcing it to run in 
    --                                        any run state
    --                  <receiver_go> - signal from "run_control_mgmt_agent", depending on the run state
    --                                  grant the right to run
    --                  <csr.control(0)> - signal from "avmm_slave_csr", control bit. masking the fsm, 
    --                                     if the user do not wish to parse this lane/mutrig. 
    -- @output          <enable> - control bit of "frame_rcv" to pick up new frame by detecting header
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	proc_enable_ctrl : process (all)
	begin
		enable <= '0';
		if (receiver_force_go = '1') then
			enable <= '1';
		elsif (receiver_go = '1' and csr.control(0) = '1') then
			enable <= '1';
		elsif (run_state_cmd = TERMINATING and terminating_pending = '1' and csr.control(0) = '1') then
			-- During TERMINATING, keep frame-start permission only until the
			-- first empty frame closes the run. This still allows a delayed
			-- final payload frame to start, but stops parsing fresh idle frames
			-- once the run-local close marker has been emitted.
			enable <= '1';
		end if;
	end process proc_enable_ctrl;
	
	
    
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       output_pkt_hits 
    --
    -- @berief          assemble the avalon-streaming interface for outputing parsed events
    -- @input           <asi_rx8b1k_channel> -- asic id 
    --                  <s_o_word> -- register of the new event (short/long) 
    --                  <p_new_word> -- register valid flag of the new event (validate <s_o_word>)
    --                  <n_new_word> -- comb of valid flag of the new event (for latching sop/eop)
    -- @output          <o_hits.*> -- output hits structure, also called "event"
    --                  <aso_hit_type0_*> -- hit_type0 streaming interface signals
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	proc_output_pkt_hits_comb : process(all)
	begin
        -- ---------------------------------------
        -- assemble record from frame_rcv fsm 
        -- ---------------------------------------
        -- @note        taking care of the long event word and short event word
        -- 
        --              1) 48-bit word: send out s_o_word
        --              2) 27-bit word: the data are at highest 27 bits
        --              re-arrange the bit:
        --                      put the E_flag ( s_o_word(48-27) ) to bit(0)
        --                      fill the bit( 48-27 downto 1) with '0'
        --              bits not carried in record: (note: no longer true)
        --                      T_bad_hit, E_bad_hit, E_fine
        -- Keep the packed hit word's ASIC field at 4 bits while allowing
        -- narrower or wider CHANNEL_WIDTH generics on the stream interface.
        o_hits.asic     <= std_logic_vector(resize(unsigned(asi_rx8b1k_channel), o_hits.asic'length));
        o_hits.channel  <= s_o_word(47 downto 43);
        o_hits.T_BadHit <= s_o_word(42);
        o_hits.T_CC     <= s_o_word(41 downto 27);
        o_hits.T_Fine   <= s_o_word(26 downto 22);
        case p_frame_flags(4) is 
            when '0' =>
                -- Long-mode raw word keeps E_BadHit at bit 21, E_Flag at bit 20,
                -- ECC at bits 19:5, and E_fine at bits 4:0. hit_type0 carries
                -- only {ECC, E_Flag}, so compact from the raw word explicitly.
                o_hits.E_BadHit <= s_o_word(21);
                o_hits.E_CC     <= s_o_word(19 downto 5);
                o_hits.E_fine   <= s_o_word(4 downto 0);
                o_hits.E_Flag   <= s_o_word(20);
            when others => 
                o_hits.E_BadHit <= '0';
                o_hits.E_CC     <= (others => '0');
                o_hits.E_fine   <= (others => '0');
                o_hits.E_Flag   <= s_o_word(0);
        end case;
        o_hits.valid   <= p_new_word;
        -- ---------------------------------
        -- avst data interface (hit_type0)
        -- ---------------------------------
        -- channel 
		aso_hit_type0_channel					<= asi_rx8b1k_channel;
        -- data 
		aso_hit_type0_data(44 downto 41)		<= o_hits.asic;
		aso_hit_type0_data(40 downto 36)		<= o_hits.channel;
		aso_hit_type0_data(35 downto 21)		<= o_hits.T_CC;
		aso_hit_type0_data(20 downto 16)		<= o_hits.T_Fine;
		aso_hit_type0_data(15 downto 1)			<= o_hits.E_CC;
		aso_hit_type0_data(0)					<= o_hits.E_Flag;
        -- valid
		aso_hit_type0_valid						<= o_hits.valid;
    end process;
    
    proc_output_pkt_hits : process (i_clk)
    begin 
        if rising_edge(i_clk) then 
            if (i_rst = '0') then 
                -- --------------------------
                -- sop / eop generation 
                -- --------------------------
                -- default 
                aso_hit_type0_startofpacket     <= '0';
                aso_hit_type0_endofpacket	    <= '0';
	                if (n_new_word = '1') then
	                    if (to_integer(n_word_cnt) = 1) then -- sop
	                        aso_hit_type0_startofpacket <= '1';
	                    end if;
	                    if (to_integer(n_word_cnt) = to_integer(unsigned(n_frame_len))) then -- eop
	                        aso_hit_type0_endofpacket	<= '1';
	                    end if;
	                end if;
                -- -----------------------
                -- derive the hit error
                -- -----------------------
                -- default
                aso_hit_type0_error 			<= (others => '0');
                hit_err							<= '0';
                if (p_state = FS_UNPACK or p_state = FS_UNPACK_EXTRA) then -- in receiving hits state
                    if (asi_rx8b1k_error(1) = '1' or asi_rx8b1k_error(0) = '1') then -- any byte error within the hit
                        hit_err				<= '1'; -- set hit error
                    end if;
                    if (n_new_word = '1') then
                        aso_hit_type0_error(0) 		<= hit_err; -- latch the hit error based on any byte error
                        if (o_hits.E_BadHit = '1' or o_hits.T_BadHit = '1') then 
                            aso_hit_type0_error(0)      <= '1'; -- raise error-0 when CC has bubble. note: you may choose to not trim it, but it is rather rarely, only if the hitlogic has glitches.
                        end if;
                        hit_err						<= '0'; -- unset hit error
                    end if; 
                end if;
                -- derive lane_training error, span the whole frame
                aso_hit_type0_error(2)		    <= asi_rx8b1k_error(2);
                -- derive the crc error
                if (to_integer(n_word_cnt) = to_integer(unsigned(n_frame_len))) then -- eop
                    aso_hit_type0_error(1)		<= n_crc_error;
                end if;

            else -- reset
                aso_hit_type0_startofpacket <= '0';
                aso_hit_type0_endofpacket	<= '0';
                aso_hit_type0_error 			<= (others => '0');
                hit_err							<= '0';
            end if;
        end if;
    end process;
    
     
    
    -- -----------------------------------------------------------
    -- some plain combinational logic for "frame_rcv" fsm
    -- -----------------------------------------------------------
    -- derive the tx flag
    -- --------------------
    p_txflag_isShort <= '1' when p_frame_flags(4 downto 2) = "100" else '0';
    p_txflag_isCEC   <= '1' when p_frame_flags(4 downto 2) = "101" else '0'; -- not used anywhere
  
    -- ==================================================================================================== 
    -- @moduleName      crc16_calc 
    -- 
    -- @berief          calculate the crc for the whole frame, result available at eop
    -- @input           <n_crc_din_valid> -- data is valid 
    --                  <i_data> -- crc data to roll
    -- @output          <s_crc_result> -- the crc output register pack
    -- ==================================================================================================== 
    u_crc16 : entity work.crc16_calc
    port map (
    --  <port>          <signal>            <width>         
        i_clk           => i_clk,           -- 1 bit
        i_rst           => n_crc_rst,       -- 1 bit
        i_d_valid       => n_crc_din_valid, -- 1 bit
        i_din           => i_data,          -- 8 bits
        o_crc_reg       => s_crc_result,    -- 16 bits 
        o_crc_8         => open             -- 8 bits
    );
    
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       frame_rcv 
    --
    -- @berief          parse the MuTRiG frame
    -- @input           
    -- @output          <o_hits.*> -- output hits structure, also called "event"
    --                  <aso_hit_type0_*> -- hit_type0 streaming interface signals
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    proc_frame_rcv : process (i_clk)
    begin
        if rising_edge(i_clk) then
            -- -----------------
            -- critical reset
            -- -----------------
            if (i_rst = '1' or run_state_cmd = RUN_PREPARE) then
                p_state             <= FS_IDLE; -- in this state most things will be reset
                p_frame_number      <= (others => '0');
                p_crc_err_count     <= (others => '0');
            else
                -- state signals --                         <reset trigger>
                p_state             <= n_state;             -- i_rst | run_state_cmd.RUN_PREPARE
                p_state_wait_cnt    <= n_state_wait_cnt;    -- p_state.FS_IDLE
                -- state counters --
                p_word              <= n_word;              -- p_state.FS_IDLE
                p_word_extra        <= n_word_extra;        -- p_state.FS_IDLE, TODO: re-check it
                p_new_word          <= n_new_word;          -- *not used 
                -- header info registers --
                p_new_frame         <= n_new_frame;         -- p_state.FS_IDLE
                p_frame_number      <= n_frame_number;      -- i_rst | run_state_cmd.RUN_PREPARE
                p_frame_len         <= n_frame_len;         -- p_state.FS_IDLE
                p_frame_flags       <= n_frame_flags;       -- p_state.FS_IDLE
                -- miscellaneous registers --
                p_word_cnt          <= n_word_cnt;
                p_crc_err_count     <= n_crc_err_count;     -- i_rst | run_state_cmd.RUN_PREPARE
                p_crc_din_valid     <= n_crc_din_valid;     -- p_state.FS_IDLE
                p_crc_rst           <= n_crc_rst;           -- p_state.FS_IDLE (high)
                p_crc_error         <= n_crc_error;         -- *default to zero
                p_end_of_frame      <= n_end_of_frame;      -- *default to zero
                p_frame_info_ready  <= n_frame_info_ready;  -- p_state.FS_IDLE
                -- indicator --
                if n_new_word = '1' then
                    s_o_word <= n_word; -- latch the new word (maybe a bit unnecessary to choose a specific time point)
                end if;
            end if;
            
			
        end if;
    end process;
	

    proc_frame_rcv_comb : process(all)
--        i_data, i_byteisk,
--        p_state, p_state_wait_cnt, p_crc_err_count, p_crc_din_valid, p_word_cnt, p_new_frame, p_frame_number, p_frame_len,
--        n_word_cnt, s_crc_result, p_word, p_word_extra, p_crc_rst, enable, p_frame_flags, p_txflag_isShort
--    ) -- !!!!!!!!! MISSING SENSITIVITY LIST "p_txflag_isShort" TODO change to all
    begin
        --DEFAULT SIGNAL ASSIGNMENTS
        o_busy              <= '1';
        n_state             <= p_state;
        n_state_wait_cnt    <= p_state_wait_cnt;

        n_word              <= p_word;
        n_word_extra        <= p_word_extra;
        n_new_word          <= '0';
        n_word_cnt          <= p_word_cnt;

        n_crc_error         <= '0';
        n_crc_err_count     <= p_crc_err_count;
        n_crc_din_valid     <= p_crc_din_valid;
        n_crc_rst           <= p_crc_rst;
        n_end_of_frame      <= '0';

        n_new_frame         <= '0';
        n_frame_len         <= p_frame_len;
        n_frame_number      <= p_frame_number;
        n_frame_flags       <= p_frame_flags;
        n_frame_info_ready  <= '0';
		
		sop_comb			<= '0';
		eop_comb			<= '0';

        if ( i_byteisk = '1' and i_data = x"BC" and p_state /= FS_CRC_CHECK ) then
            -- ---------------------------------------
            -- YW: restore to idle in the next cycle
            -- ---------------------------------------
            -- NOTE:    this is not a valid condition to happen during a frame transmission
            --          you must capture the exception yourself
            --          Keep the dedicated CRC_CHECK cycle alive even if the
            --          source has already returned to idle BC so the bad-CRC
            --          flag and counter update can retire coherently.
            -- --------------
            -- "IDLE" mode
            -- --------------
            if (MODE_HALT = 0) then
                n_state         <= FS_IDLE;
            else
            -- --------------
            -- "HALT" mode
            -- --------------
                -- halt
            end if;
        else
            case p_state is
            when FS_IDLE =>
				n_frame_info_ready	<= '0';
                o_busy           <= '0';
                --Initialize the frame len meta information
                n_frame_len      <= (others => '0');
                n_frame_flags    <= (others => '0');
                n_word_cnt       <= (others => '0');

                n_state_wait_cnt <= 0;
                n_crc_din_valid  <= '0';
                n_crc_rst        <= '1';
                n_new_frame      <= '0';
                
                n_word_extra     <= (others => '0');

                --state transition
                -- detect frame_header, go to FS_FRAME_COUNTER
                if ( enable = '1' and i_byteisk = '1' and i_data = c_header ) then -- start condition
                    n_new_frame         <= '1'; -- flag the sof for 1 cycle
                    n_state             <= FS_FRAME_COUNTER;
                    n_state_wait_cnt    <= 2;
                end if;

            when FS_FRAME_COUNTER => -- 2 cycles
                n_crc_din_valid <= '1'; -- start the crc engine
                n_crc_rst       <= '0'; -- deassert crc engine reset
                n_frame_number(p_state_wait_cnt*8-1 downto (p_state_wait_cnt-1)*8) <= i_data;
                n_state_wait_cnt <= p_state_wait_cnt - 1;
                if ( p_state_wait_cnt = 1 ) then
                    n_state             <= FS_EVENT_COUNTER;
                    n_state_wait_cnt    <= 2;
                end if;

            when FS_EVENT_COUNTER => -- 2 cycles
                n_state_wait_cnt <= p_state_wait_cnt - 1;
                if ( p_state_wait_cnt = 2 ) then
                    n_frame_flags           <= i_data(7 downto 2);
                    n_frame_len(9 downto 8) <= i_data(1 downto 0);
                elsif ( p_state_wait_cnt = 1 ) then
                    n_frame_len(7 downto 0) <= i_data;
                    n_frame_info_ready      <= '1';
                    -- indicate the start of the new frame
                    if ( p_frame_len(9 downto 8) = "00" and i_data = std_logic_vector(to_unsigned(0,8)) ) then
                        n_state             <= FS_CRC_CALC; -- no hit in this frame
                        n_state_wait_cnt    <= 2;
                    else -- there are hits in this frame
                        n_state <= FS_UNPACK;
						-- derive the hit mode from frame flag which determines op mode of this state machine
                        if ( p_txflag_isShort = '0' ) then 
                            n_state_wait_cnt <= N_BYTES_PER_WORD;
                        else -- interleaving/bang-bang between UNPACK and UNPACK_EXTRA 
                            n_state_wait_cnt <= N_BYTES_PER_WORD_SHORT;
                            n_word           <= (others => '0');
                        end if;
                    end if;
                end if;

            when FS_UNPACK => -- 3 cycles
                -- ------------------
                -- normal mode
                -- ------------------
                if ( p_txflag_isShort = '0' ) then
					-- collect 6 bytes data of all hits
                    n_word(p_state_wait_cnt*8-1 downto (p_state_wait_cnt-1)*8) <= i_data;
                    n_state_wait_cnt        <= p_state_wait_cnt - 1;
                    if ( p_state_wait_cnt = 1 ) then
						-- assert the hit is valid
                        n_new_word          <= '1';
                        n_word_cnt          <= p_word_cnt + 1;
                        n_state_wait_cnt    <= N_BYTES_PER_WORD;
                        if ( p_word_cnt = unsigned(p_frame_len(9 downto 0)) - 1 ) then -- exit condition
                            n_state         <= FS_CRC_CALC;
                            n_state_wait_cnt<= 2;
							n_word_cnt          <= p_word_cnt + 1; -- YW: need for gen eop
                        end if;
                    end if;
                -- ------------------
                -- fast mode
                -- ------------------
				-- bang-bang between UNPACK_EXTRA and UNPACK state for even and odd number of hits in short mode
                else
                    n_state_wait_cnt <= p_state_wait_cnt - 1;
                    if ( p_word_cnt(0) = '0' ) then -- current is even number of hits
                        -- collect 3 bytes here
						n_word(n_word'high-(N_BYTES_PER_WORD_SHORT-p_state_wait_cnt)*8 downto n_word'high-(N_BYTES_PER_WORD_SHORT-p_state_wait_cnt+1)*8+1) <= i_data;
                        -- collect the half byte in UNPACK_EXTRA
						if ( p_state_wait_cnt = 1 ) then
                            n_state <= FS_UNPACK_EXTRA; -- go to UNPACK_EXTRA
                        end if;
                    else -- current is odd number of hits, just coming back from UNPACK_EXTRA
                        if ( p_state_wait_cnt = N_BYTES_PER_WORD_SHORT ) then -- coming back from UNPACK_EXTRA state
                            n_word(n_word'high downto n_word'high-3) <= p_word_extra; -- receive 4 bit extra (half-byte) for odd hit, MSB
                        end if;
						-- collect 3 bytes for the odd hit
                        n_word(n_word'high-(N_BYTES_PER_WORD_SHORT-p_state_wait_cnt)*8-4 downto n_word'high-(N_BYTES_PER_WORD_SHORT-p_state_wait_cnt+1)*8-3) <= i_data; -- collect bytes to establish a hit
                        if ( p_state_wait_cnt = 1 ) then -- assert new word to indicate a hit valid when byte counter is at 1
                            n_new_word <= '1';
                            if ( p_word_cnt = unsigned(p_frame_len) - 1 ) then -- exit condition: last hit of this frame
                                n_state             <= FS_CRC_CALC;
                                n_state_wait_cnt    <= 2;
								n_word_cnt          <= p_word_cnt + 1; -- YW: need for gen eop
                            else
                                n_word_cnt          <= p_word_cnt + 1;
                                n_state_wait_cnt    <= N_BYTES_PER_WORD_SHORT;
                            end if;
                        end if;
                    end if;
                end if;

            when FS_UNPACK_EXTRA => -- 1 cycle
                if ( p_word_cnt(0) = '0' ) then -- current is even number of hits (bull-shitting)
					-- collect the half byte to the past even hit, LSB
                    n_word(n_word'high-N_BYTES_PER_WORD_SHORT*8 downto n_word'high-N_BYTES_PER_WORD_SHORT*8-3) <= i_data(7 downto 4);
					-- pass the half byte for the coming odd hit, MSB
                    n_word_extra    <= i_data(3 downto 0);
					-- assert for the even hit
                    n_new_word      <= '1';
                    if ( p_word_cnt = unsigned(p_frame_len) - 1 ) then -- exit condition: last hit of this frame
                        n_state             <= FS_CRC_CALC;
                        n_state_wait_cnt    <= 2;
						n_word_cnt          <= p_word_cnt + 1; -- YW: need for gen eop
                    else
                        n_state             <= FS_UNPACK; -- bang-bang
                        n_word_cnt          <= p_word_cnt + 1;
                        n_state_wait_cnt    <= N_BYTES_PER_WORD_SHORT;
                    end if;
                end if;

            when FS_CRC_CALC => -- 2 cycles
                n_state_wait_cnt <= p_state_wait_cnt -1;
                if ( p_state_wait_cnt = 1 ) then
        --  if i_byteisk = '1' and i_data = c_trailer(31 downto 24) then
                    n_state <= FS_CRC_CHECK;
        --   n_new_frame <= '0';
        --   n_state_wait_cnt <= 2;
        -- else
        --   n_state <= FS_IDLE;
        --   n_crc_err_count <= std_logic_vector(unsigned(p_crc_err_count)+1);
        -- end if;
                end if;

            when FS_CRC_CHECK => -- 1 cycle
                n_crc_din_valid <= '0'; -- stop the crc engine 
                n_crc_rst       <= '1'; -- reset the crc engine
                n_end_of_frame  <= '1'; -- flag eof for 1 cycle
        --      n_state_wait_cnt <= p_state_wait_cnt -1;
        --      if p_state_wait_cnt = 1 then
                if s_crc_result /= X"7FF2" then  -- CORRECT magic number
                --if s_crc_result /= X"FFFF" then  -- WRONG result, to test if crc works
                    n_crc_err_count <= std_logic_vector(unsigned(p_crc_err_count)+1);
                    n_crc_error <= '1';
                end if;
                
                n_state <= FS_IDLE;
        --  end if;

            when others => null;
        end case;
        end if;
    end process;
    
    -- ==================================================================================================== 
	-- @commentName     Mu3e "Run Control" host-agent (h2a) handshake 
    --
    -- @comment             In mu3e run control system, each feb has a run control management host which runs 
    --                  in reset clock domain, while other IPs must feature run control management agent 
    --                  which listens the run state command to capture the transition. The state transition
    --                  are only ack by the agent for as little as 1 cycle, but the host must assert the 
    --                  valid until all ack by the agents are received, during transitioning period. 
	--                      The host should record the timestamps (clock cycle and phase) difference between
    --                  the run command signal is received by its lvds_rx and agents' ready signal. 
    --                      This should ensure all agents are running at the same time, despite there is 
    --                  phase uncertainty between the clocks, which might results in 1 clock cycle 
    --                  difference and should be compensated offline. 
	-- ====================================================================================================
    
    
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       run_control_mgmt_agent 
    --
    -- @berief          handshake with run control host and change its state
    -- @input           <asi_ctrl_valid/data> -- run command sent by host
    -- @output          <run_state_cmd> -- decoded run command 
    --                  <asi_ctrl_ready> -- handshake with host
    --                  <receiver_force_go/receiver_go> -- control signals to "frame_rcv"
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	proc_run_control_mgmt_agent : process (i_clk,i_rst)
		variable decoded_run_state_v : run_state_t;
	begin
		if (i_rst = '1') then 
			receiver_force_go			<= '0';
			receiver_go					<= '0';
			run_state_cmd				<= IDLE;
			terminating_pending			<= '0';
			terminating_endofrun_pulse	<= '0';
			terminating_idle_guard_cnt	<= 0;
		elsif (rising_edge(i_clk)) then 
			decoded_run_state_v := run_state_cmd;
			terminating_endofrun_pulse <= '0';

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

			if (decoded_run_state_v /= TERMINATING) then
				terminating_pending <= '0';
				terminating_idle_guard_cnt <= 0;
			elsif (run_state_cmd /= TERMINATING) then
				terminating_pending <= '1';
				terminating_idle_guard_cnt <= 0;
			elsif (terminating_pending = '1') then
				if (terminating_empty_frame_done = '1') then
					terminating_pending <= '0';
					terminating_idle_guard_cnt <= TERMINATING_IDLE_GUARD_CONST;
					terminating_endofrun_pulse <= '1';
				elsif (p_state /= FS_IDLE or terminating_frame_start_seen = '1') then
					terminating_idle_guard_cnt <= 0;
				elsif (terminating_idle_guard_cnt >= TERMINATING_IDLE_GUARD_CONST - 1) then
					terminating_pending <= '0';
					terminating_idle_guard_cnt <= TERMINATING_IDLE_GUARD_CONST;
					terminating_endofrun_pulse <= '1';
				else
					terminating_idle_guard_cnt <= terminating_idle_guard_cnt + 1;
				end if;
			else
				terminating_idle_guard_cnt <= 0;
			end if;
			
			case decoded_run_state_v is 
				when IDLE =>
					receiver_force_go		<= '0';
					receiver_go				<= '0';
				when RUN_PREPARE =>
					receiver_force_go		<= '0';
					receiver_go				<= '0';
				when SYNC => 
					receiver_force_go		<= '0';
					receiver_go				<= '0';
				when RUNNING =>
					receiver_force_go		<= '0';
					receiver_go				<= '1';
				when TERMINATING => 
					receiver_force_go		<= '0';
					receiver_go				<= '0';
				when others =>
					receiver_force_go		<= '0';
					receiver_go				<= '0';
			end case;
		end if;
	end process;
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

end architecture;
