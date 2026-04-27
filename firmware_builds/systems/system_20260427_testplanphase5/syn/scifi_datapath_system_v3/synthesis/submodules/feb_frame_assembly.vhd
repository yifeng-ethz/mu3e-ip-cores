-- File name: feb_frame_assembly.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Aug 6, 2024
-- Revision: 1.1 (use pipeline search for subheader scheduler)
--      Date: May 5, 2025
-- Revision: 1.2 (add debug interfaces and refining read sub fifo switching speed)
--      Date: Jul 10, 2025
-- Revision: 1.3 (support 128/256 subheader packets between two header packets)
--      Date: Aug 13, 2025
-- =========
-- Description:	[Front-end Board Frame Assembly] 
--		This IP is generates the Mu3e standard data frame given input of sub-frames.
--
--		Note:
--			It includes input fifo for buffering input data stream from the stack cache ip.
--			It only de-assert ready when input fifo is full, in that case, the ring-buffer-cam ip 
--			needs to freeze the poping action until ready is asserted again. 
--			Reading at 1*156.25 MHz, which is higher than 1*125 MHz of the MuTRiG. So, overall it will never overflow.
--			But, in burst case (>256 time cluster of hits within sub-frame), this could result in a cam overwrite or 
--			input fifo overflow. (if observed, reduce stack-cache time interleaving factor or increase the cam depth and
--			increase the input fifo depth)
--		
--		Work flow:
--			Pack smallest ts sub-frames in order to form a complete frame, store-and-forware.
--			Issue 'ready' to win the arbitration against slow control packet. 
--			

-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;
use ieee.std_logic_misc.and_reduce;
use ieee.std_logic_misc.or_reduce;

entity feb_frame_assembly is
generic (
	INTERLEAVING_FACTOR				: natural := 4; -- set the same as upstream stack-cache 
    N_SHD                           : natural := 256; -- number of subheader, e.g., 256 
	DEBUG							: natural := 1
);
port (
    -- AVST <hit_type2_0>
	-- avst from the stack-cache 
	asi_hit_type2_0_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_0_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_0_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_0_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	-- two cases for [31:0]
	-- 1) sub-header: [31:24]=ts[11:4], [23:16]=TBD, [15:8]=hit_cnt[7:0], [7:0]=K23.7
	-- 2) hit: [31:0]=specbook MuTRiG hit format
	asi_hit_type2_0_valid			: in  std_logic;
	asi_hit_type2_0_ready			: out std_logic;
    asi_hit_type2_0_error			: in  std_logic; -- {tsglitcherr}
    
	-- AVST <hit_type2_1>
	asi_hit_type2_1_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_1_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_1_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_1_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	asi_hit_type2_1_valid			: in  std_logic;
	asi_hit_type2_1_ready			: out std_logic;
    asi_hit_type2_1_error			: in  std_logic; -- {tsglitcherr}
    
	-- AVST <hit_type2_2>
	asi_hit_type2_2_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_2_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_2_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_2_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	asi_hit_type2_2_valid			: in  std_logic;
	asi_hit_type2_2_ready			: out std_logic;
    asi_hit_type2_2_error			: in  std_logic; -- {tsglitcherr}
    
	-- AVST <hit_type2_3>
	asi_hit_type2_3_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_3_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_3_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_3_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	asi_hit_type2_3_valid			: in  std_logic;
	asi_hit_type2_3_ready			: out std_logic;
    asi_hit_type2_3_error			: in  std_logic; -- {tsglitcherr}
    
    
    
    -- AVST <hit_type3>
    aso_hit_type3_startofpacket     : out std_logic;
    aso_hit_type3_endofpacket       : out std_logic;
    aso_hit_type3_data              : out std_logic_vector(35 downto 0);
    aso_hit_type3_valid             : out std_logic;
    aso_hit_type3_ready             : in  std_logic;
    
    
    
    -- AVST <ctrl>
    -- run control management agent
    -- 1) datapath domain
	asi_ctrl_datapath_data			    : in  std_logic_vector(8 downto 0); 
	asi_ctrl_datapath_valid				: in  std_logic;
	asi_ctrl_datapath_ready				: out std_logic;
    -- 2) xcvr domain
	asi_ctrl_xcvr_data					: in  std_logic_vector(8 downto 0); 
	asi_ctrl_xcvr_valid					: in  std_logic;
	asi_ctrl_xcvr_ready					: out std_logic;
    
    
    -- AVMM <csr>
    avs_csr_readdata				    : out std_logic_vector(31 downto 0);
	avs_csr_read					    : in  std_logic;
	avs_csr_address					    : in  std_logic_vector(3 downto 0);
	avs_csr_waitrequest				    : out std_logic;
	avs_csr_write					    : in  std_logic;
	avs_csr_writedata				    : in  std_logic_vector(31 downto 0);
    
    -- AVST <debug_ts>
    -- 4 streams sort-merged to 1 stream of timestamp latency of hits for histogram IP
    -- latency := hit ts (48 bit) - current time stamp (48 bit). 
    -- long format to eliminate aliasing. 
    aso_debug_ts_data                   : out std_logic_vector(15 downto 0);
    aso_debug_ts_valid                  : out std_logic;
    
    -- AVST <debug_burst> 
    aso_debug_burst_valid		: out std_logic;
	aso_debug_burst_data		: out std_logic_vector(15 downto 0);

    -- AVST <ts_delta>
    aso_ts_delta_valid          : out std_logic;
    aso_ts_delta_data           : out std_logic_vector(15 downto 0);

    -- AVST <debug_filllevel>
    aso_debug_filllevel_valid	: out std_logic; -- always valid
    aso_debug_filllevel_data	: out std_logic_vector(15 downto 0); -- [8:0] sub_fifo used words (only subfifo 0)

    -- AVST <debug_loss8fill>
    aso_debug_loss8fill_valid	: out std_logic; -- only valid during mask state (packet dropped)
    aso_debug_loss8fill_data	: out std_logic_vector(15 downto 0); -- [8:0] sub_fifo used words (only subfifo 0)

    -- AVST <debug_delay8loss>
    aso_debug_delay8loss_valid	: out std_logic; -- only valid during mask state (packet dropped)
    aso_debug_delay8loss_data	: out std_logic_vector(15 downto 0); -- delay of hits or shd when dropped (only subfifo 0)
	
	-- clock and reset interface 
	i_clk_xcvr						: std_logic; -- xclk
	i_clk_datapath					: std_logic; -- dclk
	i_rst_xcvr						: std_logic;
	i_rst_datapath					: std_logic
);
end entity feb_frame_assembly;


architecture rtl of feb_frame_assembly is 
    function signmag_to_twos_comp16(
        signmag_in : std_logic_vector
    ) return std_logic_vector is
        variable magnitude_v : unsigned(14 downto 0) := (others => '0');
        variable signed_v    : signed(15 downto 0) := (others => '0');
    begin
        if signmag_in'length > 1 then
            magnitude_v := resize(unsigned(signmag_in(signmag_in'high - 1 downto 0)), magnitude_v'length);
        end if;

        if signmag_in(signmag_in'high) = '1' then
            signed_v := -resize(signed('0' & magnitude_v), signed_v'length);
        else
            signed_v := resize(signed('0' & magnitude_v), signed_v'length);
        end if;

        return std_logic_vector(signed_v);
    end function signmag_to_twos_comp16;

	-- ------------------------------------
	-- globle constant
	-- ------------------------------------
	-- universal 8b10b
	constant K285					: std_logic_vector(7 downto 0) := "10111100"; -- 16#BC#
	constant K284					: std_logic_vector(7 downto 0) := "10011100"; -- 16#9C#
	constant K237					: std_logic_vector(7 downto 0) := "11110111"; -- 16#F7#
	-- global
    constant GUARD_IN_FRAMES_CYCLES         : integer := 5;
	
    -- ------------------------------------
    -- csr_hub
    -- ------------------------------------
    signal declared_hit_cnt_all         : std_logic_vector(49 downto 0);
    signal actual_hit_cnt_all           : std_logic_vector(49 downto 0);
    signal missing_hit_cnt_all          : std_logic_vector(49 downto 0);
    
    component alt_parallel_add
	port (
		clock		: in  std_logic  := '0';
		data0x		: in  std_logic_vector (47 downto 0);
		data1x		: in  std_logic_vector (47 downto 0);
		data2x		: in  std_logic_vector (47 downto 0);
		data3x		: in  std_logic_vector (47 downto 0);
		result		: out std_logic_vector (49 downto 0) 
    );
    end component;
    
    
	
	-- ------------------------------------
	-- payload_offloader_avst
	-- ------------------------------------
	-- types
	type avst_input_t is record
		channel			: std_logic_vector(asi_hit_type2_0_channel'high downto 0);
		startofpacket	: std_logic;
		endofpacket		: std_logic;
		data			: std_logic_vector(asi_hit_type2_0_data'high downto 0);
		valid			: std_logic;
		ready			: std_logic;
	end record;
	type avst_inputs_t 				is array (0 to INTERLEAVING_FACTOR-1) of avst_input_t;
	
	-- signals
	signal avst_inputs				: avst_inputs_t;
	
	
	-- ---------------------------
	-- sub_frame_fifo
	-- ---------------------------
	-- constants
	constant SUB_FIFO_DATA_WIDTH			: natural := 40;
	constant SUB_FIFO_USEDW_WIDTH			: natural := 10; -- used one more bit for it
	constant SUB_FIFO_DEPTH					: natural := 512; -- does not overflow at 960kHz/ch (fillness < 220). no, at this rate, the fillness can be larger than 256... overflow
                                                              -- will overflow using new scheduler at rate = 5. enlarge to 1024
    constant SUB_FIFO_SOP_LOC				: natural := 37;
	constant SUB_FIFO_EOP_LOC				: natural := 36;
	
	-- types
	type sub_fifo_t is record
		wrreq		: std_logic;
		data		: std_logic_vector(SUB_FIFO_DATA_WIDTH-1 downto 0);
		wrempty		: std_logic;
		wrfull		: std_logic;
		wrusedw		: std_logic_vector(SUB_FIFO_USEDW_WIDTH-1 downto 0);
		rdreq		: std_logic;
		q			: std_logic_vector(SUB_FIFO_DATA_WIDTH-1 downto 0);
		rdempty		: std_logic;
		rdfull		: std_logic;
		rdusedw		: std_logic_vector(SUB_FIFO_USEDW_WIDTH-1 downto 0);
	end record;
	type sub_fifos_t				is array (0 to INTERLEAVING_FACTOR-1) of sub_fifo_t;
    type sub_fifo_data_arr_t         is array (0 to INTERLEAVING_FACTOR-1) of std_logic_vector(SUB_FIFO_DATA_WIDTH-1 downto 0);
    type sub_fifo_usedw_arr_t        is array (0 to INTERLEAVING_FACTOR-1) of std_logic_vector(SUB_FIFO_USEDW_WIDTH-1 downto 0);
	
	-- signals
	signal sub_fifos				: sub_fifos_t;
    signal sub_fifo_wrreq_s          : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal sub_fifo_rdreq_s          : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal sub_fifo_data_s           : sub_fifo_data_arr_t;
    signal sub_fifo_q_s              : sub_fifo_data_arr_t;
    signal sub_fifo_rdusedw_s        : sub_fifo_usedw_arr_t;
    signal sub_fifo_wrusedw_s        : sub_fifo_usedw_arr_t;
    signal sub_fifo_rdempty_s        : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal sub_fifo_rdfull_s         : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal sub_fifo_wrempty_s        : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal sub_fifo_wrfull_s         : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
	
	-- declaration
	component alt_dcfifo_w40d256_patched
	PORT
	(
		aclr		: IN STD_LOGIC := '0';
		data		: IN STD_LOGIC_VECTOR (SUB_FIFO_DATA_WIDTH-1 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (SUB_FIFO_DATA_WIDTH-1 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		rdfull		: OUT STD_LOGIC ;
		rdusedw		: OUT STD_LOGIC_VECTOR (SUB_FIFO_USEDW_WIDTH-1 DOWNTO 0);
		wrempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC ;
		wrusedw		: OUT STD_LOGIC_VECTOR (SUB_FIFO_USEDW_WIDTH-1 DOWNTO 0)
	);
	end component;

	
	-- ------------------------------------
	-- lane_scheduler (comb) TODO: test for 128
	-- ------------------------------------
	constant LANE_INDEX_WIDTH					: natural := integer(ceil(log2(real(INTERLEAVING_FACTOR)))); -- 2
	constant SUBHEADER_TIMESTAMP_WIDTH			: natural := 8;
    constant TIMESTAMP_WIDTH                   : natural := SUBHEADER_TIMESTAMP_WIDTH;
    -- constants
    constant N_LANE					    : natural := INTERLEAVING_FACTOR; -- 4
    -- types
    type timestamp_t				is array (0 to N_LANE-1) of unsigned(TIMESTAMP_WIDTH downto 0); -- + 1 bit
    type comp_tmp_t					is array (0 to N_LANE-2) of unsigned(TIMESTAMP_WIDTH downto 0); -- + 1 bit
    type index_tmp_t				is array (0 to N_LANE-2) of unsigned(LANE_INDEX_WIDTH-1 downto 0); 
    -- signals
    signal timestamp				: timestamp_t;
    signal comp_tmp				    : comp_tmp_t;
    signal index_tmp				: index_tmp_t;
    
	signal scheduler_selected_timestamp			: unsigned(SUBHEADER_TIMESTAMP_WIDTH-1 downto 0);
	signal scheduler_selected_lane_binary		: unsigned(LANE_INDEX_WIDTH-1 downto 0);
	signal scheduler_out_valid					: std_logic;
	signal scheduler_overflow_flags				: std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
	signal scheduler_selected_lane_onehot		: std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    
    -- use up for comb / use down for pipeline

    -- ------------------------------------
    -- search_for_extreme (pipeline)
    -- ------------------------------------
    constant SEARCH_MIN_N_ELEMENT               : natural := N_LANE;
    constant SEARCH_MIN_TIMESTAMP_WDITH         : natural := TIMESTAMP_WIDTH;
    constant SEARCH_MIN_ELEMENT_SZ_BITS         : natural := SEARCH_MIN_TIMESTAMP_WDITH + 1; -- 8 bits of data + 1 overflow flag
    constant SEARCH_MIN_ARRAY_SZ_BITS           : natural := SEARCH_MIN_N_ELEMENT * SEARCH_MIN_ELEMENT_SZ_BITS;
    constant SEARCH_MIN_ELEMENT_INDEX_BITS      : natural := integer(ceil(log2(real(SEARCH_MIN_N_ELEMENT)))); -- 2 for 4 lanes
    
    signal search_for_extreme_in_data           : std_logic_vector(SEARCH_MIN_ARRAY_SZ_BITS-1 downto 0);
    signal search_for_extreme_in_valid          : std_logic;
    signal search_for_extreme_in_ready          : std_logic;
    signal search_for_extreme_out_data          : std_logic_vector(SEARCH_MIN_ELEMENT_SZ_BITS+SEARCH_MIN_ELEMENT_INDEX_BITS-1 downto 0);
    signal search_for_extreme_out_valid         : std_logic;
    signal search_for_extreme_out_ready         : std_logic;

    -- ---------------------------------    
    -- search_for_extreme2 (not used)
    -- ---------------------------------
    -- constant SFE2_DATA_WIDTH        : natural := 9; -- width of each input value
    -- constant SFE2_ARRAY_SIZE        : natural := 4; -- number of input values (must be power of 2)
    -- constant SFE2_ARRAY_SIZE_BITS   : natural := integer(ceil(log2(real(SFE2_ARRAY_SIZE)))); -- log2 of array size

    -- component search_for_extreme2
	-- generic(
	-- 	ARRAY_SIZE              : natural := SFE2_ARRAY_SIZE;            -- Number of input values (must be power of 2)
    --     DATA_WIDTH              : natural := SFE2_DATA_WIDTH;            -- Width of each input value
    --     PIPELINE_STAGES         : natural := 4;             -- Number of pipeline stages
    --     INCLUDE_INDEX           : natural := 1              -- Include index of minimum value in output
	-- );
	-- port(
	-- 	clk                 : in  std_logic;                -- Clock signal
    --     rst_n               : in  std_logic;                -- Active low reset signal
    --     valid_in            : in  std_logic;                -- Input valid signal
    --     data_in             : in  std_logic_vector(SFE2_DATA_WIDTH*SFE2_ARRAY_SIZE-1 downto 0); -- Input data (concatenated values)
    
    --     valid_out           : out std_logic;               -- Output valid signal
    --     min_value           : out std_logic_vector(SFE2_DATA_WIDTH-1 downto 0); -- Minimum value found in the input
    --     min_index           : out std_logic_vector(SFE2_ARRAY_SIZE_BITS-1 downto 0); -- Index of the minimum value (if INCLUDE_INDEX=1)
    --     ready               : out std_logic                -- Output ready signal
	-- );
	-- end component;

    
	-- -------------------------------------
	-- sub_fifo_write_logic
	-- -------------------------------------
	-- types
	type subfifo_trans_status_single_t 		is (IDLE, TRANSMISSION, MASKED, RESET);
	type subfifo_trans_status_t				is array (0 to INTERLEAVING_FACTOR-1) of subfifo_trans_status_single_t;
	type subheader_hit_cnt_t				is array (0 to INTERLEAVING_FACTOR-1) of std_logic_vector(7 downto 0);
	type subfifo_counter_t					is array (0 to INTERLEAVING_FACTOR-1) of unsigned(47 downto 0);
	type debug_msg_t is record
		declared_hit_cnt			: subfifo_counter_t;
		actual_hit_cnt				: subfifo_counter_t;
		missing_hit_cnt				: subfifo_counter_t;
	end record;
	type word_is_subheader_t				is array (0 to INTERLEAVING_FACTOR-1) of std_logic;
	type word_is_subtrailer_t				is array (0 to INTERLEAVING_FACTOR-1) of std_logic;
	
	-- signals
	signal subfifo_trans_status				: subfifo_trans_status_t;
	signal subheader_hit_cnt				: subheader_hit_cnt_t;
	signal subheader_hit_cnt_comb			: subheader_hit_cnt_t;
	signal debug_msg						: debug_msg_t;
	signal word_is_subheader				: word_is_subheader_t;
	signal word_is_subtrailer				: word_is_subtrailer_t;
	
	
	-- ---------------------------
	-- frame_delimiter_marker
	-- ---------------------------
	-- types
	type showahead_timestamp_t				is array (0 to INTERLEAVING_FACTOR-1) of unsigned(TIMESTAMP_WIDTH-1 downto 0);
	type pipe_de2wr_t is record
		eop_all_valid			: std_logic;
		eop_all					: std_logic;
		eop_all_ack				: std_logic;
	end record;
	
	-- signals
	signal showahead_timestamp				: showahead_timestamp_t;
	signal showahead_timestamp_last			: showahead_timestamp_t;
	signal showahead_timestamp_d1			: showahead_timestamp_t;
	signal pipe_de2wr						: pipe_de2wr_t;
	signal xcvr_word_is_subheader			: word_is_subheader_t; -- same helper but in different clocks
	signal xcvr_word_is_subtrailer			: word_is_subtrailer_t;
    signal showahead_timestamp_valid        : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal showahead_timestamp_last_valid   : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    signal scheduler_overflow_latched      : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
	
	
	-- --------------------------------------------
	-- main_fifo_write_logic (storing Mu3e data frame)
	-- --------------------------------------------
	-- constants
	constant MAIN_FIFO_DATA_WIDTH			: natural := 40;
	constant MAIN_FIFO_USEDW_WIDTH			: natural := 13; -- do not use 1 more bit
	constant MAIN_FIFO_DEPTH				: natural := 8192; -- 40 M10K
	
	-- declaration
	component main_fifo
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (MAIN_FIFO_DATA_WIDTH-1 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (MAIN_FIFO_DATA_WIDTH-1 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (MAIN_FIFO_USEDW_WIDTH-1 DOWNTO 0)
	);
	end component;
	
	-- types
	type main_fifo_wr_status_t 		is (IDLE, START_OF_FRAME, LOOK_AROUND, TRANSMISSION, END_OF_FRAME, RESET);
	type csr_t is record
		feb_type			: std_logic_vector(5 downto 0); -- 6
		feb_id				: std_logic_vector(15 downto 0); -- 16
	end record;
--    type xcsr_t is record
--		feb_type			: std_logic_vector(5 downto 0); -- 6
--		feb_id				: std_logic_vector(15 downto 0); -- 16
--	end record;
    constant CSR_DEF            : csr_t := (
        feb_type            => "111000", -- type = scifi
        feb_id              => std_logic_vector(to_unsigned(2,16)) -- id = 2
    );
    
    
    type subfifo_msg_t is record
        subfifo_af_alert    : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
        subfifo_af_ack      : std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
    end record;
	
	-- signal 
	signal main_fifo_rdreq				: std_logic;
	signal main_fifo_wrreq				: std_logic;
	signal main_fifo_din				: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal main_fifo_dout				: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal main_fifo_empty				: std_logic;
	signal main_fifo_full				: std_logic;
	signal main_fifo_sclr				: std_logic;
	signal main_fifo_usedw				: std_logic_vector(MAIN_FIFO_USEDW_WIDTH-1 downto 0);
	signal sof_flow					    : unsigned(2 downto 0);
    --signal look_flow                    : unsigned(2 downto 0);
	signal main_fifo_decision			: std_logic_vector(LANE_INDEX_WIDTH-1 downto 0);
	signal main_fifo_wr_status			: main_fifo_wr_status_t;
	signal sub_dout						: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal sub_empty					: std_logic;
	signal sub_rdreq					: std_logic;
	signal sub_eop_is_seen				: std_logic;
	signal insert_trailer_done			: std_logic;
	signal main_fifo_wr_data			: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal main_fifo_wr_valid			: std_logic;
	signal csr							: csr_t := CSR_DEF;
    signal xcsr                         : csr_t := CSR_DEF;
    signal header_generated             : std_logic;
    signal subfifo_msg                  : subfifo_msg_t;
    signal trailer_generated            : std_logic;
    type search_flow_t is (IDLE,POST,POST_ACK,GET,GET_ACK);
    signal search_flow                  : search_flow_t;
    
    type main_fifo_log_t is record 
        subheader_cnt                   : unsigned(15 downto 0);
        hit_cnt                         : unsigned(15 downto 0);
    end record;
    signal main_fifo_log                : main_fifo_log_t;
   
	-- ----------------------------------------------
	-- transmission_timestamp_poster (datapath)
	-- ----------------------------------------------
	signal frame_cnt						: unsigned(43-TIMESTAMP_WIDTH downto 0);
    signal frame_cnt_d1                     : unsigned(43-TIMESTAMP_WIDTH downto 0);
	signal gts_8n_in_transmission			: std_logic_vector(47 downto 0);
    
    -- ------------------
    -- helper functions 
    -- ------------------
    -- word_is_header
    function word_is_header(iword : std_logic_vector(35 downto 0)) return std_logic is 
        variable k              : std_logic_vector(3 downto 0);
        variable data           : std_logic_vector(31 downto 0);
        variable header_flag   : std_logic;
    begin
        k       := iword(35 downto 32);
        data    := iword(31 downto 0);
        if (k = "0001" and data(7 downto 0) = K285) then 
            header_flag := '1';
        else 
            header_flag := '0';
        end if;
        return header_flag;
    end word_is_header;
    
    -- word_is_trailer
    function word_is_trailer(iword : std_logic_vector(35 downto 0)) return std_logic is 
        variable k              : std_logic_vector(3 downto 0);
        variable data           : std_logic_vector(31 downto 0);
        variable trailer_flag   : std_logic;
    begin
        k       := iword(35 downto 32);
        data    := iword(31 downto 0);
        if (k = "0001" and data(7 downto 0) = K284) then 
            trailer_flag := '1';
        else 
            trailer_flag := '0';
        end if;
        return trailer_flag;
    end word_is_trailer;
    
    -- fifo_usedw_check 
    function fifo_free_space_check (
        iframe_hitcnt   : integer; -- [word]
        ififo_usedw     : integer;
        ififo_maxw      : integer
    ) return std_logic is 
        variable fifo_freew     : integer;
        variable frame_length   : integer;
        variable ret            : std_logic; -- 0: bad; 1: ok
    begin
        fifo_freew      := ififo_maxw - ififo_usedw;
        frame_length    := iframe_hitcnt + 1; -- frame length = hitcnt+header
    
        if (frame_length > fifo_freew) then 
            ret         := '0';
        else 
            ret         := '1';
        end if;
        
        return ret;
    end function;
    
    
    
    -- ----------------------------------
    -- run state management
    -- ----------------------------------
    type run_state_t is (IDLE, RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST, SYNC_TEST, RESET, OUT_OF_DAQ, ERROR);
	signal d_run_state_cmd					: run_state_t;
    signal x_run_state_cmd					: run_state_t;
    
    -- -------------------------------
    -- debug_header_fifo
    -- -------------------------------
    constant DEBUG_HEADER_FIFO_DATA_W       : natural := 40;
    constant DEBUG_HEADER_FIFO_USEDW_W      : natural := 3;
    component alt_scfifo_w40d8
	port (
		clock		: in  std_logic;
		data		: in  std_logic_vector (DEBUG_HEADER_FIFO_DATA_W-1 downto 0);
		rdreq		: in  std_logic;
		sclr		: in  std_logic;
		wrreq		: in  std_logic;
		empty		: out std_logic;
		full		: out std_logic;
		q		    : out std_logic_vector (DEBUG_HEADER_FIFO_DATA_W-1 downto 0);
		usedw		: out std_logic_vector (DEBUG_HEADER_FIFO_USEDW_W-1 downto 0)
	);
    end component;
    -- port signals
    signal header_fifo_wrreq                : std_logic;
    signal header_fifo_rdreq                : std_logic;
    signal header_fifo_sclr                 : std_logic;
    signal header_fifo_data                 : std_logic_vector(DEBUG_HEADER_FIFO_DATA_W-1 downto 0);
    signal header_fifo_q                    : std_logic_vector(DEBUG_HEADER_FIFO_DATA_W-1 downto 0);
    
    -- -------------------------------
    -- dout_assembler (xcvr)
    -- -------------------------------
    type dout_assembler_t is (IDLE,TRANSMISSION,RESET);
    signal dout_assembler                       : dout_assembler_t;
    -- gts counter
    signal d_gts_counter                        : unsigned(47 downto 0);
    signal x_gts_counter                        : unsigned(47 downto 0);
    -- counters 
    signal read_frame_cnt                       : unsigned(35 downto 0);
    signal read_frame_cnt_d1                    : unsigned(35 downto 0);
    -- misc.
    signal main_fifo_pkt_ready                  : std_logic;
    signal main_fifo_pkt_count                  : unsigned(7 downto 0); -- has to be larger to hold GUARD_IN_FRAMES_CYCLES in bits -- TODO: add assertion
    signal main_fifo_pkt_count_en               : std_logic;
    -- sync stage
    component alt_dcfifo_w48d4
	port (
		aclr		: in  std_logic  := '0';
		data		: in  std_logic_vector (47 downto 0);
		rdclk		: in  std_logic;
		rdreq		: in  std_logic;
		wrclk		: in  std_logic;
		wrreq		: in  std_logic;
		q		    : out std_logic_vector (47 downto 0);
		rdempty		: out std_logic;
		wrfull		: out std_logic 
	);
    end component;
    -- port signals
    signal gts_sync_fifo_q                      : std_logic_vector(47 downto 0);
    signal dout_pad_flow                        : unsigned(15 downto 0); -- should be longer than TRANSMISSION period, otherwise overflow and trigger a read which consume the log fifo wrongly.
                                                                         -- note: equal or larger than MAIN_FIFO_USEDW_WIDTH is enough 
                                                                         
    -- -------------------------------
    -- csr_sync_fifo (d2x)    
    -- -------------------------------
    signal csr_sync_fifo_d      : std_logic_vector(47 downto 0);
    signal csr_sync_fifo_x      : std_logic_vector(47 downto 0);
    
    -- -------------------------------
    -- debug timestamp (debug_ts)
    -- -------------------------------
    signal debug_ts_valid           : std_logic;
    signal debug_ts_hdr             : std_logic_vector(35 downto 0);
    signal debug_ts_subh            : std_logic_vector(7 downto 0);
    signal debug_ts_hit             : std_logic_vector(3 downto 0);
    signal debug_ts_hit_global      : std_logic_vector(47 downto 0);
    
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
	
    -- -----------------------------------------------
    -- track_ingress_timestamp 
    -- -----------------------------------------------
    signal ingress_timestamp_valid         : std_logic_vector(1 downto 0); -- 0: hit, 1: shd
    signal ingress_timestamp               : std_logic_vector(47 downto 0); -- 48 bit timestamp, 12 bit for shd, 4 bit for hit
    signal ingress_delay_valid             : std_logic; -- valid if timestamp is valid
    signal ingress_delay_data              : std_logic_vector(47 downto 0); -- delay of hits or shd when dropped (only subfifo 0)
    signal ingress_data_masked             : std_logic; -- data is masked, i.e. dropped
    signal ingress_data_masked_d1          : std_logic; -- data is masked, i.e. dropped, delayed by 1 clock cycle

begin
    -- ////////////////////////////////////////////////////////
    -- debug 
    -- ////////////////////////////////////////////////////////
    proc_debug : process (all)
    begin
        -- filllevel
        aso_debug_filllevel_valid       <= '1';
        aso_debug_filllevel_data        <= std_logic_vector(to_unsigned(to_integer(unsigned(sub_fifo_wrusedw_s(0))), 16)); -- subfifo 0 only, used words in subfifo 0

        -- loss at filllevel
        if (subfifo_trans_status(0) = MASKED and asi_hit_type2_0_valid = '1') then 
            aso_debug_loss8fill_valid   <= '1';
        else 
            aso_debug_loss8fill_valid   <= '0';
        end if;
        aso_debug_loss8fill_data        <= std_logic_vector(to_unsigned(to_integer(unsigned(sub_fifo_wrusedw_s(0))), 16)); -- subfifo 0 only, used words in subfifo 0

        -- delay at loss
        if (ingress_delay_valid = '1' and ingress_data_masked_d1 = '1') then 
            aso_debug_delay8loss_valid   <= '1';
        else 
            aso_debug_delay8loss_valid   <= '0';
        end if;
        aso_debug_delay8loss_data    <= std_logic_vector(resize(unsigned(ingress_delay_data), 16)); -- subfifo 0 only, delay of hits or shd when dropped (only subfifo 0), truncate from 48 -> 16 bits

    end process;

    -- ////////////////////////////////////////////////////////
    -- track_ingress_timestamp
    -- ////////////////////////////////////////////////////////
    proc_track_ingress_timestamp : process (i_clk_datapath)
    begin
        if rising_edge(i_clk_datapath) then 
            if (i_rst_datapath = '1') then 
                -- bits
                ingress_timestamp_valid     <= (others => '0');
                ingress_delay_valid         <= '0'; 
                ingress_data_masked         <= '0'; 
                -- array
                ingress_timestamp           <= (others => '0');
            else 
                -- default 
                ingress_timestamp_valid         <= (others => '0');
                ingress_delay_valid             <= '0';
                ingress_data_masked             <= '0';

                -- cycle 1:
                -- =========================================
                -- track the timestamp and pad incoming shd and hit ts to 48 bits 
                if (asi_hit_type2_0_valid = '1') then -- track every data
                    if (asi_hit_type2_0_startofpacket = '1') then 
                        -- start of packet, reset timestamp
                        ingress_timestamp(11 downto 4)      <= asi_hit_type2_0_data(31 downto 24); -- update shd timestamp
                        if (to_integer(unsigned(ingress_timestamp(11 downto 4))) > to_integer(unsigned(asi_hit_type2_0_data(31 downto 24)))) then -- new shd is smaller than current, overturned, need to update hdr ts
                            ingress_timestamp(47 downto 12)     <= std_logic_vector(unsigned(ingress_timestamp(47 downto 12)) + 1); -- self-increment hdr ts
                        end if;
                        ingress_timestamp_valid(1)          <= '1'; -- valid timestamp for shd      
                    else
                        ingress_timestamp(3 downto 0)       <= asi_hit_type2_0_data(31 downto 28); -- update hit timestamp
                        ingress_timestamp_valid(0)          <= '1'; -- valid timestamp for hit
                    end if;
                end if;
                -- mark masked data
                if (subfifo_trans_status(0) = MASKED and asi_hit_type2_0_valid = '1') then 
                    ingress_data_masked         <= '1';
                end if;

                -- cycle 2:
                -- =========================================
                -- calculate the delay of shd and hit
                if (or_reduce(ingress_timestamp_valid) = '1') then 
                    ingress_delay_valid          <= '1';
                    ingress_delay_data           <= std_logic_vector(d_gts_counter - unsigned(ingress_timestamp));
                end if;
                ingress_data_masked_d1          <= ingress_data_masked; -- pipeline by 1 clock cycle
            end if;
        end if;



    end process;



    -- ////////////////////////////////////////////////////////
    -- csr_hub 
    -- ////////////////////////////////////////////////////////
    proc_csr_hub : process (i_clk_datapath)
    begin 
        if (rising_edge(i_clk_datapath)) then 
            if (i_rst_datapath = '1') then 
                csr             <= CSR_DEF;
            else 
                avs_csr_waitrequest     <= '1';
                avs_csr_readdata        <= (others => '0');
                -- ============================ read ================================
                if (avs_csr_read = '1') then 
                
                    avs_csr_waitrequest     <= '0';
                    case to_integer(unsigned(avs_csr_address)) is
                        -- capability
                        when 0 => 
                            avs_csr_readdata(csr.feb_type'high downto 0)        <= csr.feb_type; -- 6 bit
                        -- configuration 
                        when 1 => 
                            avs_csr_readdata(csr.feb_id'high downto 0)          <= csr.feb_id;
                        -- debug counters 
                        -- high 16 bit + low 32 bit. 
                        when 2 => -- declared - high
                            avs_csr_readdata(17 downto 0)       <= declared_hit_cnt_all(49 downto 32);
                        when 3 => -- declared - low
                            avs_csr_readdata                    <= declared_hit_cnt_all(31 downto 0);
                        when 4 => -- actual - high
                            avs_csr_readdata(17 downto 0)       <= actual_hit_cnt_all(49 downto 32);
                        when 5 => -- actual - low
                            avs_csr_readdata                    <= actual_hit_cnt_all(31 downto 0);
                        when 6 => -- missing - high
                            avs_csr_readdata(17 downto 0)       <= missing_hit_cnt_all(49 downto 32);
                        when 7 => -- missing - low
                            avs_csr_readdata                    <= missing_hit_cnt_all(31 downto 0);
                        when 8 => 
                            --avs_csr_readdata                    <= std_logic_vector(frame_cnt(31 downto 0)); -- TODO: handle CDC
                        when others =>
                            null;
                    end case;
                -- ============================= write ==============================    
                elsif (avs_csr_write = '1') then 
                    avs_csr_waitrequest     <= '0';
                    case to_integer(unsigned(avs_csr_address)) is
                        when 0 => 
                            csr.feb_type        <= avs_csr_writedata(csr.feb_type'high downto 0);
                        when 1 => 
                            csr.feb_id          <= avs_csr_writedata(csr.feb_id'high downto 0);
                        when others => 
                            null;
                    end case;
                else 
                    -- routine
                    

                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------
    -- sum subfifo write side statistics
    -- -------------------------------------
    lpm_adder_unit_0 : alt_parallel_add 
    port map (
        clock	 => i_clk_datapath,
        data0x	 => std_logic_vector(debug_msg.declared_hit_cnt(0)),
        data1x	 => std_logic_vector(debug_msg.declared_hit_cnt(1)),
        data2x	 => std_logic_vector(debug_msg.declared_hit_cnt(2)), 
        data3x	 => std_logic_vector(debug_msg.declared_hit_cnt(3)), -- 48
        result   => declared_hit_cnt_all -- 50
    );
    
    lpm_adder_unit_1 : alt_parallel_add 
    port map (
        clock	 => i_clk_datapath,
        data0x	 => std_logic_vector(debug_msg.actual_hit_cnt(0)),
        data1x	 => std_logic_vector(debug_msg.actual_hit_cnt(1)),
        data2x	 => std_logic_vector(debug_msg.actual_hit_cnt(2)), 
        data3x	 => std_logic_vector(debug_msg.actual_hit_cnt(3)), -- 48
        result   => actual_hit_cnt_all -- 50
    );
    
    lpm_adder_unit_2 : alt_parallel_add 
    port map (
        clock	 => i_clk_datapath,
        data0x	 => std_logic_vector(debug_msg.missing_hit_cnt(0)),
        data1x	 => std_logic_vector(debug_msg.missing_hit_cnt(1)),
        data2x	 => std_logic_vector(debug_msg.missing_hit_cnt(2)), 
        data3x	 => std_logic_vector(debug_msg.missing_hit_cnt(3)), -- 48
        result   => missing_hit_cnt_all -- 50
    );


    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @procName        payload_offloader_avst
    --
    -- @berief          map the avst <hit_type 2> interfaces to internal struct signals 
    -- @input           <hit_type2_n>, where n is lane index
    -- @output          <avst_inputs> -- struct <avst_inputs>
    --                  
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	proc_payload_offloader_avst : process (all)
	begin
		-- ** input **
		-- channel
		avst_inputs(0).channel				<= asi_hit_type2_0_channel;
		avst_inputs(1).channel				<= asi_hit_type2_1_channel;
		avst_inputs(2).channel				<= asi_hit_type2_2_channel;
		avst_inputs(3).channel				<= asi_hit_type2_3_channel;
		-- sop
		avst_inputs(0).startofpacket		<= asi_hit_type2_0_startofpacket;
		avst_inputs(1).startofpacket		<= asi_hit_type2_1_startofpacket;
		avst_inputs(2).startofpacket		<= asi_hit_type2_2_startofpacket;
		avst_inputs(3).startofpacket		<= asi_hit_type2_3_startofpacket;
		-- eop
		avst_inputs(0).endofpacket			<= asi_hit_type2_0_endofpacket;
		avst_inputs(1).endofpacket			<= asi_hit_type2_1_endofpacket;
		avst_inputs(2).endofpacket			<= asi_hit_type2_2_endofpacket;
		avst_inputs(3).endofpacket			<= asi_hit_type2_3_endofpacket;
		-- data
		avst_inputs(0).data					<= asi_hit_type2_0_data;
		avst_inputs(1).data					<= asi_hit_type2_1_data;
		avst_inputs(2).data					<= asi_hit_type2_2_data;
		avst_inputs(3).data					<= asi_hit_type2_3_data;
		-- valid
		avst_inputs(0).valid				<= asi_hit_type2_0_valid;
		avst_inputs(1).valid				<= asi_hit_type2_1_valid;
		avst_inputs(2).valid				<= asi_hit_type2_2_valid;
		avst_inputs(3).valid				<= asi_hit_type2_3_valid;

		-- ** output **
		-- ready
		asi_hit_type2_0_ready				<= avst_inputs(0).ready;
		asi_hit_type2_1_ready				<= avst_inputs(1).ready;
		asi_hit_type2_2_ready				<= avst_inputs(2).ready;
		asi_hit_type2_3_ready				<= avst_inputs(3).ready;
	end process;
	
	
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @moduleName      sub_frame_fifo
    --
    -- @berief          stores sub-frames from each lane in data clock, read by main_fifo_writer in xcvr 
    --                  clock. Show-ahead mode.
    -- @input           <sub_fifos.writes> @ i_clk_datapath -- write side controller by sub_fifo_writer
    -- @output          <sub_fifos.reads> @ i_clk_xcvr -- read side controlled by the main_fifo_writer
    --                  
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	-- ** instantiation **
	gen_sub_fifos : for i in 0 to INTERLEAVING_FACTOR-1 generate 
		-- used one more bit for the usedw
		sub_frame_fifo : alt_dcfifo_w40d256_patched PORT MAP (
			aclr	 => i_rst_datapath or i_rst_xcvr,
			-- write side (datapath clock)
			wrclk	 => i_clk_datapath,
			wrreq	 => sub_fifo_wrreq_s(i),
			data	 => sub_fifo_data_s(i),
			wrempty	 => sub_fifo_wrempty_s(i),
			wrfull	 => sub_fifo_wrfull_s(i),
			wrusedw	 => sub_fifo_wrusedw_s(i),
			-- read side (xcvr clock)
			rdclk	 => i_clk_xcvr,
			rdreq	 => sub_fifo_rdreq_s(i),
			q	 	 => sub_fifo_q_s(i),
			rdempty	 => sub_fifo_rdempty_s(i),
			rdfull	 => sub_fifo_rdfull_s(i),
			rdusedw	 => sub_fifo_rdusedw_s(i)
		);
		-- io mapping (expand 2d array to 1d list)
		--infifo_rd_engine_subheader_list(i)		<= sub_fifos(i).q(asi_hit_type2_0_data'high downto 0);
		--infifo_rd_engine_subheader_ts_list(i)	<= infifo_rd_engine_subheader_list(i)(31 downto 24); -- ts (11:4)
	end generate gen_sub_fifos;
	
	
	
	
	
	-- ----------------------------------------
	-- sub_fifo_write_logic [datapath clock]
	-- ----------------------------------------
    -- -> write to the sub_fifo once new subframe (subheader+hits) arrives
    -- -> mask the subframe if the sub_fifo is full (do not do this, instead dequeue the oldest subframe in the front)
    -- ==========================================================================
    -- -> IMPORTANT: currently does NOT support subfifo overflow. it might cause the read side to miss an overturn of timestamp such that the main fifo will 
    --               loss track of number of frame generated. as we use number of frame as the global timestamp, this will lead to shift to larger latency of the frame
    --               generated from this FEB. But, it is wrongly time stamped. So, MASK state is forbidden for now!
    --               TODO: fix this in the future. 
    -- ==========================================================================
	
	gen_sub_fifo_write_logic : for i in 0 to INTERLEAVING_FACTOR-1 generate 
		-- 3 counters to log on the subfifo write side
        -- ----------------------------------------------------
        -- decleared hit count: 
        --                          the number of hits decleared by the subheaders
        -- actual hit count:
        --                          the number of hits actually written to the subfifo. (we lose hit because 1) subheader was masked or 2) subfifo overflow during TRANSMISSION.)
        -- missing hit count:
        --                          the number of hits missing during 
		proc_sub_fifo_write : process (i_clk_datapath, i_rst_datapath) 
		begin
			if (rising_edge(i_clk_datapath)) then 
				if (i_rst_datapath = '1') then
					subfifo_trans_status(i)		<= RESET;
					subheader_hit_cnt(i)		<= (others => '0');
				else 
					case subfifo_trans_status(i) is 
						when IDLE =>
							if (word_is_subheader(i) = '1') then
								if (sub_fifo_wrfull_s(i) = '0') then -- subheader gets in the fifo
									debug_msg.declared_hit_cnt(i)	<= debug_msg.declared_hit_cnt(i) + unsigned(subheader_hit_cnt_comb(i)); -- record the declared hit count
									subheader_hit_cnt(i)			<= subheader_hit_cnt_comb(i); -- record for this subframe period
									if (word_is_subtrailer(i) = '1') then -- not hit in this subframe
										subfifo_trans_status(i)		<= IDLE; -- go back to idle
										subheader_hit_cnt(i)		<= (others => '0');
									else 
										subfifo_trans_status(i)		<= TRANSMISSION; -- go to collect hits
									end if;
								else -- subheader not in the fifo (because it is currently full) mask the subsequent hits until the next subheader
									subfifo_trans_status(i)		<= MASKED;
								end if;
							end if;  
						when TRANSMISSION =>
							if (sub_fifo_wrreq_s(i) = '1') then -- hits gets write to fifo
                                if (sub_fifo_wrfull_s(i) = '0') then -- ok 
                                    debug_msg.actual_hit_cnt(i)		<= debug_msg.actual_hit_cnt(i) + 1; -- incr actual hit counter
                                else -- overflow (fifo ov protection : enabled)
                                    debug_msg.missing_hit_cnt(i)	<= debug_msg.missing_hit_cnt(i) + 1; -- incr missing hit counter (2)
                                end if;
							end if;
							if (word_is_subtrailer(i) = '1') then -- go back to idle when eop of this subframe is seen
								subfifo_trans_status(i)		<= IDLE;
								subheader_hit_cnt(i)		<= (others => '0');
							end if;
						when MASKED =>
							if (avst_inputs(i).valid = '1') then -- attemps to write the subsequent hits, but they are masked by the fifo, as their subheader was ignored
								if (avst_inputs(i).endofpacket = '1') then -- go back to idle, end of subframe transaction
									subfifo_trans_status(i)		<= IDLE;
									subheader_hit_cnt(i)		<= (others => '0');
                                    -- record for a missing packet
                                    --debug_msg.missing_subpkt_cnt(i)     <= debug_msg.missing_subpkt_cnt(i) + 1;
								end if;
								-- record for a missing hit
								debug_msg.missing_hit_cnt(i)	<= debug_msg.missing_hit_cnt(i) + 1; -- incr missing hit counter (1)
							end if;
						when RESET =>
                            subfifo_trans_status(i)             <= IDLE;
							subheader_hit_cnt(i)				<= (others => '0');
							debug_msg.declared_hit_cnt(i)		<= (others => '0');
							debug_msg.actual_hit_cnt(i)			<= (others => '0');
							debug_msg.missing_hit_cnt(i)		<= (others => '0');
						when others => 
					end case;
                    -- run control (subfifo write fsm)
                    if (d_run_state_cmd = RUN_PREPARE) then 
                        subfifo_trans_status(i)     <= RESET;
                    end if;
                    
				end if;
			end if;
		end process;
		
		-- ** helpers **
		proc_word_is_subheader_subfifo_wr : process (all)
		begin
			word_is_subheader(i)		<= '0';
			subheader_hit_cnt_comb(i)	<= (others => '0');
			if (avst_inputs(i).valid = '1') then -- check with valid
				if (avst_inputs(i).startofpacket = '1') then
					word_is_subheader(i)		<= '1';
					subheader_hit_cnt_comb(i)	<= avst_inputs(i).data(15 downto 8); -- from 0 to 255, but it can actually be up to 512 ...
				end if;
			end if;
		end process;
		
		proc_word_is_subtrailer_subfifo_wr : process (all) -- unlike subheader contains info, the subtrail contains the last hit
		begin
			word_is_subtrailer(i)			<= '0';
			if (avst_inputs(i).valid = '1') then 
				if (avst_inputs(i).endofpacket = '1') then
					word_is_subtrailer(i)		<= '1';
				end if;
			end if;
		end process;
		
		-- ** combinational **
		proc_sub_fifo_write_comb : process (all)
		-- input direct drives the write port
		begin
			-- default
			sub_fifo_data_s(i)(avst_inputs(i).data'high downto 0)		<= avst_inputs(i).data; -- connect data input directly to fifo (35 downto 0)
			sub_fifo_data_s(i)(avst_inputs(i).data'high+1)				<= avst_inputs(i).endofpacket; -- bit 36
			sub_fifo_data_s(i)(avst_inputs(i).data'high+2)				<= avst_inputs(i).startofpacket; -- bit 37
			sub_fifo_data_s(i)(sub_fifo_data_s(i)'high downto avst_inputs(i).data'high+3)	<= (others => '0'); -- bit 38-39 (free to allocate, TDB)
			-- assert backpressure to the ring-buffer-cam, ready latency is 0
			if (subfifo_trans_status(i) /= MASKED) then 
				if (avst_inputs(i).valid = '1') then -- write if input is valid. if full, the fifo itself will take care (ignoring them)
					sub_fifo_wrreq_s(i)		<= '1';
				else
					sub_fifo_wrreq_s(i)		<= '0';
				end if;
			else -- fifo is full or hits are masked
				
				-- if the subheader is in, hits can be accepted (if not full). if subheader is not in, subsequent hits are ignored for sure. 
				sub_fifo_wrreq_s(i)		<= '0'; -- do not write
			end if;
            
            -- run control (flush subfifo (1))
            if (d_run_state_cmd = RUN_PREPARE) then 
                sub_fifo_wrreq_s(i)		<= '0';
            end if;
            
            
			-- derive the ready for the upstream
			--if (sub_fifos(i).wrusedw > 
			avst_inputs(i).ready		<= '1';
				--avst_inputs(i).ready		<= '0'; -- upstream sense it and halt the change of data immediately, or the data is ignored. 
		end process;
		
	end generate gen_sub_fifo_write_logic;
	
	
    
 
	
    
	proc_frame_delimiter_marker : process (i_clk_xcvr, i_rst_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
			if (i_rst_xcvr = '1' or x_run_state_cmd = RUN_PREPARE) then
                for i in 0 to INTERLEAVING_FACTOR-1 loop
                    showahead_timestamp(i)      <= (others => '0');
                    showahead_timestamp_last(i) <= (others => '0');
                    showahead_timestamp_d1(i)   <= (others => '0');
                    pipe_de2wr.eop_all_valid    <= '0';
                    showahead_timestamp_valid(i)        <= '0';
                    showahead_timestamp_last_valid(i)   <= '0';
                    scheduler_overflow_latched(i)      <= '0';
                end loop;
			else 
                -- default
                scheduler_out_valid         <= '1';
                
				for i in 0 to INTERLEAVING_FACTOR-1 loop
                    -- ------------------------------------------------------------------------
                    -- deassert valid of showahead timestamp of this lane when latched
                    -- ------------------------------------------------------------------------
                    if (main_fifo_wrreq = '1' and main_fifo_din(37) = '1' and to_integer(unsigned(search_for_extreme_out_data(main_fifo_decision'length-1 downto 0))) = i) then 
                        -- Preserve the previously scheduled head across an empty-cycle gap so
                        -- the next head can still detect timestamp wrap on this lane.
                        showahead_timestamp_last(i)         <= showahead_timestamp(i);
                        showahead_timestamp_last_valid(i)   <= showahead_timestamp_valid(i);
                        showahead_timestamp_valid(i)        <= '0';
                    end if;
                
                
                    -- ------------------------------------------------------------------------
					-- continuously latch the showahead subframe timestamp on the read side 
                    -- ------------------------------------------------------------------------
                    -- latch new sub-header from show-ahead fifo
                    -- -> the subheader
                    -- -> latch once (new ts)
                    -- -> not empty (fifo q is valid)
					if (xcvr_word_is_subheader(i) = '1' and
					    sub_fifo_rdempty_s(i) /= '1' and
					    (showahead_timestamp_valid(i) = '0' or
					     unsigned(sub_fifo_q_s(i)(24+TIMESTAMP_WIDTH-1 downto 24)) /= showahead_timestamp(i))) then
						showahead_timestamp(i)		    <= unsigned(sub_fifo_q_s(i)(24+TIMESTAMP_WIDTH-1 downto 24)); 
                        showahead_timestamp_valid(i)    <= '1';
                        -- pipeline 
						showahead_timestamp_last(i)	            <= showahead_timestamp(i); -- remember the last value
                        showahead_timestamp_last_valid(i)       <= showahead_timestamp_valid(i) or showahead_timestamp_last_valid(i);
					end if;
                    
                    -- clear last, so overflow flags will be clear
                    if (trailer_generated = '1') then 
                        showahead_timestamp_last(i)         <= (others => '0');
                        showahead_timestamp_last_valid(i)   <= '0';
                        scheduler_overflow_latched(i)      <= '0';
                    elsif (scheduler_overflow_flags(i) = '1') then
                        scheduler_overflow_latched(i)      <= '1';
                    end if;
                    
                    -- --------------------------------------
                    -- valid signal for the scheduler output
                    -- --------------------------------------
					showahead_timestamp_d1(i)		<= showahead_timestamp(i);
                    -- see comb: scheduler_timestamp_valid
                    
                    -- ---------------------
                    -- output valid
                    -- ---------------------
                    -- -> all fifo must be non-empty (at least a pending subframe inside) 
                    
                    if (sub_fifo_rdempty_s(i) = '1') then -- need to delay empty signal as the q has not been latched by scheduler
                        scheduler_out_valid     <= '0'; -- void it -> let main fifo write logic to wait until the selection_comb is valid
                    end if;
                    
				end loop; 
                
				-- -------------------------------------
				-- pipe with main fifo write logic
                -- -------------------------------------
                -- valid signal for pipe with writer
                if (and_reduce(showahead_timestamp_valid) = '1') then
                    pipe_de2wr.eop_all_valid		<= '1';
                else
                    pipe_de2wr.eop_all_valid		<= '0';
                end if;
                
			end if;
		end if;
	end process;
    
    proc_frame_delimiter_marker_comb : process (all)
    begin
        -- -----------------------------------------------------------------
        -- derive overflow flag of showahead timestamp snoop from subfifo
        -- -----------------------------------------------------------------
        for i in 0 to INTERLEAVING_FACTOR-1 loop
            if (showahead_timestamp_valid(i) = '1' and showahead_timestamp_last_valid(i) = '1' and showahead_timestamp(i) < showahead_timestamp_last(i)) then 
                scheduler_overflow_flags(i)     <= '1';
            else
                scheduler_overflow_flags(i)     <= '0';
            end if;
        end loop;
    
        -- -------------------------------------
        -- pipe with main fifo write logic
        -- -------------------------------------
        -- data 
        if (and_reduce(showahead_timestamp_valid) = '1' and and_reduce(scheduler_overflow_flags or scheduler_overflow_latched) = '1') then -- all lanes overflowed
            pipe_de2wr.eop_all		<= '1'; -- inter-fsm communication pipe, set by overflow flags are set for all lanes, enough for it to set
        else
            pipe_de2wr.eop_all		<= '0'; 
        end if;
    end process;
	
	
	-- ## helpers ##
	gen_helpers_xcvr : for i in 0 to INTERLEAVING_FACTOR-1 generate 
		proc_word_is_subheader_xcvr : process (all)
		begin
			xcvr_word_is_subheader(i)		<= '0';
			if (sub_fifo_rdempty_s(i) = '0') then -- check with valid
				if (sub_fifo_q_s(i)(SUB_FIFO_SOP_LOC) = '1') then 
					xcvr_word_is_subheader(i)		<= '1';
				end if;
			end if;
		end process;
	end generate gen_helpers_xcvr;
    
    
    
    
        
    -- ------------------------------------
    -- search_for_extreme
    -- ------------------------------------
    
    proc_search_for_extreme_comb : process (all)
    begin
        -- When a lane has no pending subframe head, mask it to the maximum
        -- search value so TERMINATING can continue with the remaining lanes.
        for i in 0 to N_LANE-1 loop
            if (showahead_timestamp_valid(i) = '1') then
                search_for_extreme_in_data((i+1)*SEARCH_MIN_ELEMENT_SZ_BITS-1 downto i*SEARCH_MIN_ELEMENT_SZ_BITS)   <= (scheduler_overflow_flags(i) or scheduler_overflow_latched(i)) & std_logic_vector(showahead_timestamp(i));
            else
                search_for_extreme_in_data((i+1)*SEARCH_MIN_ELEMENT_SZ_BITS-1 downto i*SEARCH_MIN_ELEMENT_SZ_BITS)   <= (others => '1');
            end if;
        end loop;
        
    end process;
    
    -- e_search_for_extreme : entity work.search_for_extreme
    -- generic map (
    --     SEARCH_TARGET       => "MIN",
    --     SEARCH_ARCH         => "LIN", -- QUAD is not supported yet
    --     N_ELEMENT           => SEARCH_MIN_N_ELEMENT,
    --     ELEMENT_SZ_BITS     => SEARCH_MIN_ELEMENT_SZ_BITS,
    --     ARRAY_SZ_BITS       => SEARCH_MIN_ARRAY_SZ_BITS,
    --     ELEMENT_INDEX_BITS  => SEARCH_MIN_ELEMENT_INDEX_BITS
    -- )
    -- port map (
    --     -- avst <ingress> : the input array to be searched on
    --     asi_ingress_data    => search_for_extreme_in_data,
    --     asi_ingress_valid   => search_for_extreme_in_valid,
    --     asi_ingress_ready   => search_for_extreme_in_ready,
    --     -- avst <result> : the output element find by the search
    --     aso_result_data     => search_for_extreme_out_data,
    --     aso_result_valid    => search_for_extreme_out_valid,
    --     aso_result_ready    => search_for_extreme_out_ready,
    --     -- clock and reset interfaces
    --     i_clk               => i_clk_xcvr,
    --     i_rst               => i_rst_xcvr
    -- );

    -- ------------------------------------
    -- search_for_extreme2
    -- ------------------------------------
    -- sfe2 : search_for_extreme2
	-- 	port map (
    --         clk                 => i_clk_xcvr,
    --         rst_n               => i_rst_xcvr,
    --         valid_in            => search_for_extreme_in_valid,
    --         data_in             => search_for_extreme_in_data,
        
    --         valid_out           => search_for_extreme_out_valid,
    --         min_value           => open,
    --         min_index           => search_for_extreme_out_data(main_fifo_decision'length-1 downto 0), -- Index of the minimum value found in the input
    --         ready               => open
	-- 	);
    
    -- ------------------------------------
    -- search_for_extreme3
    -- ------------------------------------

    e_search_for_extreme3 : entity work.search_for_extreme3
    generic map (
        N_ELEMENT           => SEARCH_MIN_N_ELEMENT,
        ELEMENT_SZ_BITS     => SEARCH_MIN_ELEMENT_SZ_BITS,
        ARRAY_SZ_BITS       => SEARCH_MIN_ARRAY_SZ_BITS,
        ELEMENT_INDEX_BITS  => SEARCH_MIN_ELEMENT_INDEX_BITS
    )
    port map (
        -- avst <ingress> : the input array to be searched on
        asi_ingress_data    => search_for_extreme_in_data,
        asi_ingress_valid   => search_for_extreme_in_valid,
        -- avst <result> : the output element find by the search
        aso_result_data     => search_for_extreme_out_data,
        aso_result_valid    => search_for_extreme_out_valid,
        -- clock and reset interfaces
        i_clk               => i_clk_xcvr,
        i_rst               => i_rst_xcvr
    );
    
    -- ------------------------------------
	-- lane_scheduler (for lane selection) (deprecated)
	-- -------------------------------------- 
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    -- @blockName       lane_scheduler 
    --
    -- @berief          select the lane with smallest timestamp
    -- @input           <timestamp> -- 1 bit (overflow) + 8 bits (ts[11:4]), where you get from subheader.
    --                  
    -- @output          <scheduler_out_valid> -- current selection is valid (if all subheaders are seen)
    --                  <scheduler_selected_lane_binary> -- selected lane (binary encoding)
    --                  <*scheduler_selected_timestamp> -- selected timestamp (not used)
    --                  <*scheduler_selected_lane_onehot> -- selected lane (onehot encoding)
    -- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    
	proc_lane_scheduler_comb : process (all)
	begin
		-- input timestamp
		for i in 0 to N_LANE-1 loop
			timestamp(i)		<= (scheduler_overflow_flags(i) or scheduler_overflow_latched(i)) & unsigned(showahead_timestamp(i)); -- the overflow lane will be always larger
		end loop;
		
		-- algorithm: finding the smallest element of an array 
		-- input comparator (input stage)
		if (timestamp(0) <= timestamp(1)) then 
			comp_tmp(0)		<= timestamp(0);
			index_tmp(0)	<= to_unsigned(0,LANE_INDEX_WIDTH);
		else
			comp_tmp(0)		<= timestamp(1);
			index_tmp(0)	<= to_unsigned(1,LANE_INDEX_WIDTH);
		end if;
		-- cascade comparator
		for i in 0 to N_LANE-3 loop -- preferr lane lsb
			if (comp_tmp(i) <= timestamp(i+2)) then 
				comp_tmp(i+1)		<= comp_tmp(i);
				index_tmp(i+1)		<= index_tmp(i);
			else
				comp_tmp(i+1)		<= timestamp(i+2);
				index_tmp(i+1)		<= to_unsigned(i+2,LANE_INDEX_WIDTH);
			end if;
		end loop;
		-- output comparator (last stage)
		scheduler_selected_timestamp		<= comp_tmp(N_LANE-2)(scheduler_selected_timestamp'high downto 0); -- trim out the upper bit (ov)
		scheduler_selected_lane_binary		<= index_tmp(N_LANE-2); 
		for i in 0 to N_LANE-1 loop
			if (i = to_integer(unsigned(index_tmp(N_LANE-2)))) then 
				scheduler_selected_lane_onehot(i)	<= '1';
			else 
				scheduler_selected_lane_onehot(i)	<= '0';
			end if;
		end loop;
        
	end process;
	
	
	-- ------------------------------------------------------------------------
	-- main_fifo_write_logic (storing Mu3e data frame) (show-ahead mode)
	-- ------------------------------------------------------------------------
	
	main_frame_fifo : main_fifo 
    port map (
		-- clock
		clock	 => i_clk_xcvr,
		-- write side
		wrreq	 => main_fifo_wrreq,
		data	 => main_fifo_din,
		-- read side
		rdreq	 => main_fifo_rdreq,
		q	 	 => main_fifo_dout,
		-- control and status 
		empty	 => main_fifo_empty,
		full	 => main_fifo_full,
		sclr	 => main_fifo_sclr,
		usedw	 => main_fifo_usedw
	);
	
	
    -- =============
    -- header           ---> 1)
    -- -------------
    -- sub-header       ---> 2)
    -- data 
    -- -------------
    -- sub-header       ---> 2)
    -- data
    -- -------------
    -- ...              ---> 2) ...
    -- -------------
    -- frame trailer    ---> 3)
    -- =============
    
    
    
	proc_main_fifo_wr : process (i_clk_xcvr, i_rst_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
			if (i_rst_xcvr = '1') then
                main_fifo_wr_status     <= RESET;
                main_fifo_sclr          <= '1';
                trailer_generated       <= '0';
			else 
				-- default
				main_fifo_wr_data			    <= (others => '0');
                main_fifo_wr_valid		        <= '0';
                header_fifo_data                <= (others => '0');
                header_fifo_wrreq               <= '0';
                search_for_extreme_out_ready    <= '0';

				case main_fifo_wr_status is
                    when LOOK_AROUND => 
                        -- [subroutine] ask search_for_extreme which lane is smallest
                        case search_flow is 
                            when IDLE =>
                                null;
                            when POST => -- post: post lanes subh ts and start the subroutine by itself once subfifo all not empty 
                                if ((x_run_state_cmd = RUNNING and and_reduce(showahead_timestamp_valid) = '1') or
                                    (x_run_state_cmd /= RUNNING and or_reduce(showahead_timestamp_valid) = '1')) then 
                                    search_flow                     <= POST_ACK;
                                    search_for_extreme_in_valid     <= '1';
                                end if;
                            when POST_ACK => -- post ack: lower valid to search engine
                                search_flow                         <= GET;
                                search_for_extreme_in_valid         <= '0';
                            when GET => -- get: the result (smallest subh ts lane index in binary) 
                                if (search_for_extreme_out_valid = '1') then -- it will take a few cycles depending on the number of lanes
                                    search_flow                         <= IDLE;
                                    main_fifo_wr_status                 <= TRANSMISSION;
                                    --search_for_extreme_out_ready        <= '1'; -- recv result 
                                    main_fifo_decision                  <= search_for_extreme_out_data(main_fifo_decision'length-1 downto 0); -- latch search result
                                end if;
                            when GET_ACK => -- not used...
                                search_flow                             <= IDLE;
                                main_fifo_wr_status                     <= TRANSMISSION;
                                search_for_extreme_out_ready            <= '0'; 
                                -- be mindful: you need to restore it back to IDLE 
                            when others => 
                                null; 
                        end case;
                    
					when IDLE =>
                        -- use the search engine result to grant the right lane and go to appropriate segment of the packet
                        if (header_generated = '0') then  
                            if ((x_run_state_cmd = RUNNING and and_reduce(showahead_timestamp_valid) = '1') or
                                (x_run_state_cmd /= RUNNING and or_reduce(showahead_timestamp_valid) = '1')) then
                                main_fifo_wr_status     <= START_OF_FRAME;
                            end if;
                        elsif (header_generated = '1' and trailer_generated = '0' and x_run_state_cmd /= RUNNING and or_reduce(showahead_timestamp_valid) = '0') then
                            main_fifo_wr_status     <= END_OF_FRAME;
                        elsif (pipe_de2wr.eop_all = '1' and trailer_generated = '0') then 
                            -- end of frame: stop read subfifo, go to eof
                            -- trailer_generated is to avoid deadlock between sof and eof
                            main_fifo_wr_status		<= END_OF_FRAME;
                        else 
                            -- between sof and eof: read subfifo for subheader + hits 
                            if ((x_run_state_cmd = RUNNING and and_reduce(showahead_timestamp_valid) = '1') or
                                (x_run_state_cmd /= RUNNING and or_reduce(showahead_timestamp_valid) = '1')) then -- RUNNING compares a full lane-set; TERMINATING drains whatever lanes still have heads.
                                main_fifo_wr_status             <= LOOK_AROUND;
                                search_flow                   <= POST;
                                --search_flow                     <= POST_ACK; -- jump to next state 
                                --search_for_extreme_in_valid     <= '1';
                            end if;
                        end if;
                        
--                        if (search_flow = GET_ACK) then -- search done, dangling, its your turn to decide which frame segment to go
--                            search_flow          <= POST; -- remember to restore the subroutine before next use
--                            if (header_generated = '0') then  
--                                -- start of frame: go to generate new frame header
--                                main_fifo_wr_status		<= START_OF_FRAME;
--                            elsif (pipe_de2wr.eop_all = '1' and trailer_generated = '0') then 
--                                -- end of frame: stop read subfifo, go to eof
--                                -- trailer_generated is to avoid deadlock between sof and eof
--                                main_fifo_wr_status		<= END_OF_FRAME;
--                            else  
--                                -- between sof and eof: read subfifo for subheader + hits 
--                                main_fifo_wr_status		        <= TRANSMISSION;
--                                search_for_extreme_out_ready    <= '1'; -- ack the search_for_extreme entity
--                            end if;
--                        end if;
                        
                        -- unset trailer_generated once all subfifo are recovered from ts overflow, this ensures no stuck at sof and eof deadloops
                        if (or_reduce(scheduler_overflow_flags or scheduler_overflow_latched) = '0') then -- all clear now
                            trailer_generated       <= '0';
                        end if;
                        
                    -- 1) frame header
					when START_OF_FRAME => -- [preamp + 2 header + 2 debug_header]
                        sof_flow		<= sof_flow + 1;
						case to_integer(sof_flow) is 
							when 0 => -- preamble
								main_fifo_wr_data(35 downto 32)		<= "0001";
								main_fifo_wr_data(31 downto 26)		<= xcsr.feb_type; -- [x] TODO: handle CDC
								main_fifo_wr_data(23 downto 8)		<= xcsr.feb_id;
								main_fifo_wr_data(7 downto 0)		<= K285;
								main_fifo_wr_valid					<= '1';
							when 1 => -- data header 0
                                      -- ts [47:16]
								main_fifo_wr_data(31 downto 0)		<= gts_8n_in_transmission(47 downto 16); -- header ts : only 47:12 is only. 11:0 here are "0"s. 
								main_fifo_wr_valid					<= '1';
							when 2 => -- data header 1
                                      -- ts [15:0] | package count [15:0]
                                      -- for 256 N_SHD, only [31:28] is unmasked. for 128 N_SHD, only [31:27] is unmasked
								main_fifo_wr_data(31 downto 16)		<= gts_8n_in_transmission(15 downto 0); -- gts[47:12] (frame_cnt) : leading gts for this frame. while subframe contains gts[11:4], hits contains gts[3:0]
								main_fifo_wr_data(20+TIMESTAMP_WIDTH-1 downto 16)          <= (others => '0'); -- explicitly mask to zeros (gts_8n_in_transmission is reference for its subheader and hits ts) 
                                                                                        -- ex: hit ts = gts_8n (ofst to mu3e global start-of-run) + subheader_ts (ofst to h.) + hit_ts (ofst to subh.)
                                main_fifo_wr_data(15 downto 0)		<= std_logic_vector(frame_cnt_d1(15 downto 0)); -- package_cnt [15:0] : if some main frames are skipped, the frame_cnt might mis-match with the gts_8n lower bits.
                                                                                                                 -- the up stream needs to log and handle this error. 
                                                                                                                 -- ex: try to grant more upload bandwidth (limit sc packet bandwidth) to prevent overflow of the main fifo.  
								main_fifo_wr_valid					<= '1';
							when 3 => -- debug header 0
                                      -- 0 | subheader count [14:0] | hit count [15:0]
                                      -- note: counts are for this main frame 
								main_fifo_wr_valid					<= '1'; 
							when 4 => -- debug header 1 
                                      -- generation time (timestamp of this main frame, loaded into main fifo) 
                                      -- be careful: read out of main frame is only after eop of this packet is seen
                                      -- -----------------------------------------------------------------------------------------------------------------------
                                      -- note: this field should be used as the TTL (Time-To-Live) on IP packet, indicating the life time of a data frame. 
                                      --       the later stage can, at its own discretion, discard or grant higher priority to this frame based on this info. 
                                      -- -----------------------------------------------------------------------------------------------------------------------  
								main_fifo_wr_data(30 downto 0)      <= gts_8n_in_transmission(30 downto 0); -- gts[30:0] : the current running gts (sync from data clock) for a sanity reference only. should be slightly larger than gts[47:12] + 1
                                main_fifo_wr_valid                  <= '1';
                            when 5 => -- slack state (so the debug header 1 can be written to main fifo)
                                main_fifo_wr_status					<= IDLE; -- go back to check which lane to read
                                sof_flow							<= (others => '0');
							when others =>
						end case;
                        header_generated        <= '1'; -- only send one header per frame
                    -- 2)
					when TRANSMISSION => -- [subheader + hits]
                        -- routine: write sub-header and hits 
                        --      see proc_main_fifo_wr_comb
                        
                        -- escape condition: 
						if (main_fifo_wrreq = '1' and main_fifo_din(SUB_FIFO_EOP_LOC) = '1') then
							main_fifo_wr_status		        <= IDLE; -- this subframe is read, we can start to calc the next frame in IDLE
                            -- log the subheader count in this main frame
                            main_fifo_log.subheader_cnt     <= main_fifo_log.subheader_cnt + 1;
						end if;
                        -- log the hit count in this main frame
                        if (main_fifo_wrreq = '1' and main_fifo_din(37) = '0') then -- write a hit from subheader (sub fifo -> main fifo)
                            main_fifo_log.hit_cnt           <= main_fifo_log.hit_cnt + 1;
                        end if;

                    -- 2.1)
--					when LOOK_AROUND => -- break: if all lane overflew, goto: trailer
--                        look_flow     <= look_flow + 1;
--                        -- this state will last 3 cycles, latch/exit when 2. 
--                        -- reason: after rdack, wait for the showahead_timestamp (1 cycle) and overflow_flag/eop_all (2 cycles) is settled
--                        case to_integer(look_flow) is 
--                            when 2 =>
--                                 main_fifo_wr_status		<= IDLE;
--                                -- reset counter 
--                                look_flow     <= (others => '0');
--                            when others => 
--                                null;
--                        end case;

                    -- 3) frame trailer
					when END_OF_FRAME => -- [trailer]
                    -- 2 cycles, write to main_fifo at the 2nd cycle
						if (insert_trailer_done = '0') then
                            -- write trailer -> main fifo
							insert_trailer_done		            <= '1';
							main_fifo_wr_data(35 downto 32)		<= "0001";
							main_fifo_wr_data(7 downto 0)		<= K284;
							main_fifo_wr_valid		            <= '1';
                            trailer_generated                   <= '1';
                            -- write log -> debug fifo
                            header_fifo_wrreq                   <= '1';
                            header_fifo_data(30 downto 16)      <= std_logic_vector(main_fifo_log.subheader_cnt(14 downto 0)); -- truncate out bit 15
                            header_fifo_data(15 downto 0)       <= std_logic_vector(main_fifo_log.hit_cnt);
                        else 
                            main_fifo_wr_status			        <= RESET;
						end if;
                        
					when RESET =>
						main_fifo_wr_status			<= IDLE;
                        search_flow                 <= IDLE;
                        sof_flow					<= (others => '0');
                        --look_flow                   <= (others => '0');
                        insert_trailer_done		    <= '0';
                        header_generated            <= '0';
                        search_for_extreme_in_valid <= '0';
                        search_for_extreme_out_ready<= '1'; -- clear the pending result from search engine
                        -- clear log
                        main_fifo_log.subheader_cnt         <= (others => '0');
                        main_fifo_log.hit_cnt               <= (others => '0');
                        
					when others =>
				end case;
                if (x_run_state_cmd = RUN_PREPARE) then 
                    main_fifo_wr_status         <= RESET;
                    trailer_generated           <= '0'; -- speical 
                    main_fifo_sclr              <= '1';
                else 
                    main_fifo_sclr              <= '0';
                end if;
                
                -- ---------------------------------
                -- almost full alert of subfifo
                -- ---------------------------------
                for i in 0 to INTERLEAVING_FACTOR-1 loop
                    if (SUB_FIFO_DEPTH - to_integer(unsigned(sub_fifo_rdusedw_s(i))) < 5) then 
                        -- criticl error: subfifo almost full
                        subfifo_msg.subfifo_af_alert(i)	    <= '1';
                    elsif (subfifo_msg.subfifo_af_ack(i) = '1') then 
                        -- ack: callback has taken care of this alert
                        subfifo_msg.subfifo_af_alert(i)	    <= '0';
                    end if;
                end loop;
                
                
                
			end if;
		end if;
	end process;
	
	
	proc_main_fifo_wr_comb : process (all)
    -- there are three input flow to the main fifo. 1) subheader 2) 
	begin
        -- ---------------------------------
        -- sub_dout <- sub_fifos
        -- ---------------------------------
		-- 2) hits from sub-frame
		-- default
		sub_dout				<= (others => '0');
        sub_empty               <= '0';
		for i in 0 to INTERLEAVING_FACTOR-1 loop
			sub_fifo_rdreq_s(i)		<= '0'; -- default
			if (main_fifo_wr_status = TRANSMISSION) then 
				if (to_integer(unsigned(main_fifo_decision)) = i) then -- if selected, connect this sub fifo to main fifo
					sub_fifo_rdreq_s(i)		<= sub_rdreq;
					sub_dout				<= sub_fifo_q_s(i);
					sub_empty				<= sub_fifo_rdempty_s(i);
				end if;
			end if;
            -- run control (flush subfifo (2))
            if (x_run_state_cmd = RUN_PREPARE) then 
                sub_fifo_rdreq_s(i)     <= '1';
            end if;
            
		end loop;
		
        -- ---------------------------------
        -- main_fifo_din <- sub_dout
        -- ---------------------------------
        -- 2) hits
		if (main_fifo_wr_status = TRANSMISSION) then 
			main_fifo_din			<= sub_dout; -- direct wire up the out of sub fifo to in of main fifo
        -- 1) or 3)
		elsif (main_fifo_wr_status = END_OF_FRAME or main_fifo_wr_status = START_OF_FRAME) then -- give control to the main fifo
			main_fifo_din			<= main_fifo_wr_data;
		else 
			main_fifo_din			<= (others => '0');
		end if;
        
        -- ---------------------------------
        -- main_fifo_wrreq <-> sub_rdreq
        -- ---------------------------------
        -- 2) hits
		if (sub_empty = '0' and main_fifo_wr_status = TRANSMISSION) then -- write normally when sub fifo's dout is valid, in comb
			main_fifo_wrreq		<= '1';
        -- 1) or 3) frame-header or trailer 
		elsif (main_fifo_wr_status = END_OF_FRAME or main_fifo_wr_status = START_OF_FRAME) then
			main_fifo_wrreq		<= 	main_fifo_wr_valid;
		else -- 2) in idle or others 
			main_fifo_wrreq		<= '0';
		end if;
        
        -- ---------------------------------
        -- subfifo rdreq 
        -- ---------------------------------
        if (sub_empty = '0' and main_fifo_wr_status = TRANSMISSION) then -- write normally when sub fifo's dout is valid, in comb
            sub_rdreq			<= '1'; -- write to the main fifo, at the same time ack the read 
        else 
            sub_rdreq			<= '0';
        end if;
        
		
		if (sub_empty = '0' and sub_dout(SUB_FIFO_EOP_LOC) = '1') then -- when eop is seen, alert main_fifo_wr_logic into finishing
			sub_eop_is_seen		<= '1';
		else
			sub_eop_is_seen		<= '0';
		end if;
        
        
	end process;
	
	
	-- ----------------------------------------------
	-- transmission_timestamp_poster 
	-- ----------------------------------------------
	
    -- track the number of frames written to main_fifo
	proc_transmission_timestamp_poster : process (i_clk_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
			if (i_rst_xcvr = '1' or x_run_state_cmd = RUN_PREPARE) then
				frame_cnt		<= (others => '0');
			else 
				if (main_fifo_wr_status = END_OF_FRAME and insert_trailer_done = '0') then -- the first cycle of frame trailer
					frame_cnt		<= frame_cnt + 1;
				end if;
                
			end if;
            gts_8n_in_transmission(4+TIMESTAMP_WIDTH-1 downto 4)		        <= std_logic_vector(x_gts_counter(4+TIMESTAMP_WIDTH-1 downto 4)); -- 11:4 for 8-bit subheader timestamp. this part is for TTL 
            -- Ensure unused fine timestamp bits are known (avoids X-propagation into debug header 1 in simulation).
            gts_8n_in_transmission(3 downto 0)                                  <= (others => '0');
            frame_cnt_d1                                                        <= frame_cnt; -- need for timing
            gts_8n_in_transmission(47 downto 4+TIMESTAMP_WIDTH)	                <= std_logic_vector(frame_cnt); -- 47:12 for 8-bit subheader timestamp. this part is used for main frame timestamp (reference point for its subframe and hits) 
                
        end if;
	end process;
	
	proc_transmission_timestamp_poster_comb : process (all)
	begin
        x_gts_counter                           <= unsigned(gts_sync_fifo_q);
	end process;
    
    
    proc_gts_counter : process (i_clk_datapath)
    begin
        if (rising_edge(i_clk_datapath)) then 
            if (i_rst_datapath = '1' or d_run_state_cmd = SYNC) then 
                d_gts_counter         <= (others => '0');
            else 
                d_gts_counter         <= d_gts_counter + 1;
            end if;
        end if;
    end process;
    
    
    -- -----------------------------
    -- dout_assembler
    -- -----------------------------
    gts_sync_fifo : alt_dcfifo_w48d4 
    port map (
        -- write side 
        wrreq	 => '1',
        data	 => std_logic_vector(d_gts_counter), -- 48
        wrclk	 => i_clk_datapath,
        -- read side
		rdreq	 => '1',
		q	     => gts_sync_fifo_q, -- 48
        rdclk	 => i_clk_xcvr,
        -- control and status
		aclr	 => i_rst_datapath,
		rdempty	 => open,
		wrfull	 => open
	);
    
    -- from d to x clock domain
    proc_csr_sync_fifo_dio_comb : process (all)
    begin
        csr_sync_fifo_d         <= (others => '0'); -- default
        csr_sync_fifo_d(csr.feb_type'length+csr.feb_id'length-1 downto 0)     <= csr.feb_type & csr.feb_id;
    end process;
    
    proc_csr_sync_fifo_xio_comb : process (all)
    begin
        xcsr.feb_type           <= csr_sync_fifo_x(21 downto 16);
        xcsr.feb_id             <= csr_sync_fifo_x(15 downto 0);
    end process;
    
    csr_sync_fifo : alt_dcfifo_w48d4 
    port map (
        -- write side 
        wrreq	 => '1',
        data	 => csr_sync_fifo_d, -- 6 & 16 bits
        wrclk	 => i_clk_datapath,
        -- read side
		rdreq	 => '1',
		q	     => csr_sync_fifo_x, -- 6 & 16 bits
        rdclk	 => i_clk_xcvr,
        -- control and status
		aclr	 => i_rst_datapath,
		rdempty	 => open,
		wrfull	 => open
	);
    
    
    
    -- this fifo contains the debug header (subheader count and hit count) written by the main fifo write side at END_OF_FRAME state
    -- the read side is main fifo read side, which will take this debug header to put it in the offset location during merger is read this frame
    debug_header_fifo : alt_scfifo_w40d8 
    port map (
        -- write side 
        wrreq		=> header_fifo_wrreq,
        data		=> header_fifo_data, -- 40 (frame count | hit count)
        -- read side
        rdreq		=> header_fifo_rdreq,
        q		    => header_fifo_q, -- 40 (frame count | hit count)
        -- control and status
        sclr		=> header_fifo_sclr,
        empty		=> open,
		full		=> open,
        usedw		=> open, -- 3
        -- clock 
		clock		=> i_clk_xcvr
	);                               
    
    
    
    proc_dout_assembler : process (i_clk_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
            -- start counter after eop is transmitted
            if (main_fifo_pkt_count_en = '1') then 
                if (main_fifo_pkt_count < GUARD_IN_FRAMES_CYCLES) then -- overflow prevention 
                    main_fifo_pkt_count         <= main_fifo_pkt_count + 1;
                end if;
            else -- reset counter
                main_fifo_pkt_count         <= (others => '0');
            end if;
        
            -- logic to add guard band in time between frames to cover up delay in read frame count, otherwise new unfinished frame could be transmitted in half
            -- TODO: replace internal main FIFO with an external store-and-forward FIFO. 
            if (word_is_trailer(main_fifo_dout(35 downto 0)) = '1' and aso_hit_type3_valid = '1' and aso_hit_type3_ready = '1') then -- need to deassert avst valid after eop as early as possible, the other frame is not ready in the main fifo (read_frame_cnt has delay)
                main_fifo_pkt_ready         <= '0';
                main_fifo_pkt_count_en      <= '1'; -- start counter
            -- this is the starting condition -> 1) 1st frame w/o counter started 2) start counter 3) mask ready 4) unmask after counter reached 5) 
            elsif (read_frame_cnt < frame_cnt and (main_fifo_pkt_count = GUARD_IN_FRAMES_CYCLES or main_fifo_pkt_count_en = '0')) then -- guard band in time, so no consequtive frame and prevent read_frame_cnt delay
                main_fifo_pkt_ready         <= '1';
                main_fifo_pkt_count_en      <= '0'; -- reset counter
            end if;
        
        
            if (i_rst_xcvr = '1' or x_run_state_cmd = RUN_PREPARE) then
                dout_assembler              <= RESET;
            else 
                read_frame_cnt_d1          <= read_frame_cnt; -- TODO: remove this line
                -- dout_assembler 
                -- ---------------------------------------------------------------------
                -- @berief : track the number of frames readout from main_fifo 
                -- ---------------------------------------------------------------------
                -- NOTE: 900kHz x 64 ch will trigger 'full' in for 2k entries. so 8k entries of main fifo will sustain the 1MHz x 128 ch rate (maximum rate).
                --       This has to be also verified in case of high flow of slow control packet, which might de-assert the 'ready' of the merger too long,
                --       inducing overflow of the main fifo. 
                --
                -- TODO: test the above case.
                -- default
                header_fifo_sclr            <= '0';
                
                case dout_assembler is 
                    when IDLE =>
                        -- sof is seen
                        if (word_is_header(main_fifo_dout(35 downto 0)) = '1' and aso_hit_type3_valid = '1' and aso_hit_type3_ready = '1') then 
                            dout_assembler      <= TRANSMISSION;
                        end if;
                        
                        dout_pad_flow           <= (others => '0');
                    when TRANSMISSION =>
                    
                        -- wrong: sof is seen again -> missing eof -> we need to infer a frame is already sent
                        if (word_is_header(main_fifo_dout(35 downto 0)) = '1' and aso_hit_type3_valid = '1' and aso_hit_type3_ready = '1') then 
                            dout_assembler      <= TRANSMISSION;
                            read_frame_cnt      <= read_frame_cnt + 1;
                        end if;
                        -- correct: eof is seen
                        if (word_is_trailer(main_fifo_dout(35 downto 0)) = '1' and aso_hit_type3_valid = '1' and aso_hit_type3_ready = '1') then 
                            dout_assembler      <= IDLE;
                            read_frame_cnt      <= read_frame_cnt + 1;
                        end if;
                        
                        -- pad debug header 0 at the right time
                        -- flow counter to sense the offset of this fragment
                        if (aso_hit_type3_valid = '1' and aso_hit_type3_ready = '1') then 
                            dout_pad_flow       <= dout_pad_flow + 1;
                        end if;
                        
                        
                    when RESET =>
                        read_frame_cnt      <= (others => '0');
                        dout_pad_flow       <= (others => '0');
                        header_fifo_sclr    <= '1';
                        dout_assembler      <= IDLE;
                        main_fifo_pkt_ready         <= '0';
                        main_fifo_pkt_count_en      <= '0'; -- stop counter by default
                    when others =>
                        null;
                end case;
                -- -------------------------------------
                -- The main fifo overflow behavior:
                -- -------------------------------------
                -- New packet will overwrite the old packet. so on the read side, the eop will not be seen, instead a sop will be seen.
                -- This above logic can compensate for a partial overwrite condition, such that the read packet count is still keeping track (= write count - 1)
                -- 
                -- ---------------
                -- Side effect:
                -- ---------------
                -- But, if the write side has overwritten more than a whole packet, the read side will lose track. This condition is not covered and will result in 
                -- showing an always hungry behavior to the up stream. After that incidence, the valid is only prevented by the non-empty flag (so no read underflow)
                -- This will subsequently stop the packet scheduling, such that the upload merger will grant this data packet during this packet is been generated by reading the subfifos.
                -- which is not compact, creating bubbles in the upload stream. Reducing the upload bandwidth efficiency. 
                --
                -- ------------------
                -- Considerations:
                -- ------------------
                -- we do not stop writing even if the main fifo is full. This is to control the delay of the main frames. Otherwise, this datapath with backlog will
                -- always generate too much delayed frame, which can be a burden to the upstream.
                --
                -- ------------------
                -- read needs to do:
                -- ------------------
                -- for error handling, the read side should fill in "header" and "debug word" field of the main frame during reading. 
                -- Explicitly, it needs to pad 
                --         1) packet counter with the packet read count, so the upstream can sense missing packets. 
                --         2) subheader count (get from the write side). it can be less than 256 in case of sub fifo overflow, which will mask incoming packet from ring-cam.
                --         3) hit count (get from the write side). it is for the upstream to sense a broken packet. 
                -- 
                -- ----------------------
                -- packet scheduling: 
                -- ----------------------
                -- Q: what is it?
                -- A: only a full packet (main frame) is inside the main fifo, the read valid will be asserted. If the upstream merger (dt+sc+rc) uses packet scheduling,
                --    such behavior will eliminate bubbles in the upstream. 
                
                -- ------------------
                -- Q: a better way?
                -- ------------------
                -- A: maybe we can scrollback. 
                -- for example, in case of main fifo overflow. 
                --         1) if read has not started, we block read side and free-up the oldest packet inside the main fifo, then continue write until full again. the freeing up needs a chunk movement of the write ptr
                --            which is only possible with a ram. and need dedicate management of the ptr of the all packet sop location. which is more like a producer-consumer queue
                --         2) if the read has started, we block the write attemption for its whole period. 
                --
                -- A: maybe we can block write.
                --    this can lead to delay of the main fifo. it is a bad practice overall.
                -- 
                -- A: maybe we can clean up / flush the main fifo.
                --    lead to huge packets loss. bad practice.
                --
                -- A: to refine the scrollback proposal.
                --    1) read not started, we can assert the start freeing up when almost full, until almost full flag is de-asserted and eop is seen. so the write side will not sense overflow.
                --       the merger will be blocked for read during this freeing up. but once the write is done (as the freeing is non-stop, while write has bubbles) the freeing up process will stop,
                --       giving the oppotunity for the merger to take over the read.
                --       However, the merger will only read fraction of all packet. and a lot of packet will be discarded for this mechanism, increasing the hit loss ratio.
                
                
                
            end if;
        end if;
    end process;
    
    
    
    proc_dout_assembler_comb : process (all)
    begin
        -- default 
        main_fifo_rdreq                 <= '0'; -- act as ack
        aso_hit_type3_valid             <= '0';
        aso_hit_type3_data              <= (others => '0');
        aso_hit_type3_startofpacket     <= '0';
        aso_hit_type3_endofpacket       <= '0';
        header_fifo_rdreq               <= '0';
        -- ----------------------
        -- rd side of main fifo
        -- ----------------------
        if (main_fifo_empty /= '1' and main_fifo_pkt_ready = '1') then 
            -- read when there is a complete frame in the main fifo (empty protection = sanity check)
            main_fifo_rdreq                 <= aso_hit_type3_ready;
        end if;
        
        -- ---------------
        -- <hit_type3>
        -- ---------------
        -- valid 
        if (main_fifo_pkt_ready = '1' and main_fifo_empty /= '1') then -- one or more complete mu3e data frame(s) in the main fifo 
            aso_hit_type3_valid             <= '1';
        end if;
        -- data
        aso_hit_type3_data                  <= main_fifo_dout(35 downto 0); -- discard: [36]=eop; [37]=sop for subframe
        -- packet signal 
        if (word_is_header(main_fifo_dout(35 downto 0)) = '1') then 
            aso_hit_type3_startofpacket     <= '1';
        end if;
        if (word_is_trailer(main_fifo_dout(35 downto 0)) = '1') then 
            aso_hit_type3_endofpacket       <= '1';
        end if;
        -- padding data 
        case to_integer(dout_pad_flow) is 
            when 2 => -- for debug header 0
                aso_hit_type3_data(30 downto 0)     <= header_fifo_q(30 downto 0); -- (frame count | hit count)
                if (aso_hit_type3_valid = '1' and aso_hit_type3_ready = '1') then 
                    header_fifo_rdreq               <= '1'; -- ack 
                end if;
            when others =>
                null;
        end case;

    end process;
    
    
    
    
    
    proc_run_control_mgmt_datapath : process (i_clk_datapath,i_rst_datapath)
	-- In mu3e run control system, each feb has a run control management host which runs in reset clock domain, while other IPs must feature
	-- run control management agent which listens the run state command to capture the transition.
	-- The state transition are only ack by the agent for as little as 1 cycle, but the host must assert the valid until all ack by the agents are received,
	-- during transitioning period. 
	-- The host should record the timestamps (clock cycle and phase) difference between the run command signal is received by its lvds_rx and 
	-- agents' ready signal. This should ensure all agents are running at the same time, despite there is phase uncertainty between the clocks, which 
	-- might results in 1 clock cycle difference and should be compensated offline. 
	begin 
        if (rising_edge(i_clk_datapath)) then 
            if (i_rst_datapath = '1') then 
                d_run_state_cmd       <= IDLE;
            else 
                -- valid
                if (asi_ctrl_datapath_valid = '1') then 
                    -- payload ->  run command
                    case asi_ctrl_datapath_data is 
                        when "000000001" =>
                            d_run_state_cmd		<= IDLE;
                        when "000000010" => 
                            d_run_state_cmd		<= RUN_PREPARE;
                        when "000000100" =>
                            d_run_state_cmd		<= SYNC;
                        when "000001000" =>
                            d_run_state_cmd		<= RUNNING;
                        when "000010000" =>
                            d_run_state_cmd		<= TERMINATING;
                        when "000100000" => 
                            d_run_state_cmd		<= LINK_TEST;
                        when "001000000" =>
                            d_run_state_cmd		<= SYNC_TEST;
                        when "010000000" =>
                            d_run_state_cmd		<= RESET;
                        when "100000000" =>
                            d_run_state_cmd		<= OUT_OF_DAQ;
                        when others =>
                            d_run_state_cmd		<= ERROR;
                    end case;
                end if;
                -- ready 
                asi_ctrl_datapath_ready     <= '1';
                
                -- TODO: add ready signal logics
                
            end if;
       end if;
   end process;
   
   
   
    proc_run_control_mgmt_xcvr : process (i_clk_xcvr,i_rst_xcvr)
    begin 
        if (rising_edge(i_clk_xcvr)) then 
            if (i_rst_xcvr = '1') then 
                x_run_state_cmd       <= IDLE;
            else 
                -- valid
                if (asi_ctrl_xcvr_valid = '1') then 
                    -- payload ->  run command
                    case asi_ctrl_xcvr_data is 
                        when "000000001" =>
                            x_run_state_cmd		<= IDLE;
                        when "000000010" => 
                            x_run_state_cmd		<= RUN_PREPARE;
                        when "000000100" =>
                            x_run_state_cmd		<= SYNC;
                        when "000001000" =>
                            x_run_state_cmd		<= RUNNING;
                        when "000010000" =>
                            x_run_state_cmd		<= TERMINATING;
                        when "000100000" => 
                            x_run_state_cmd		<= LINK_TEST;
                        when "001000000" =>
                            x_run_state_cmd		<= SYNC_TEST;
                        when "010000000" =>
                            x_run_state_cmd		<= RESET;
                        when "100000000" =>
                            x_run_state_cmd		<= OUT_OF_DAQ;
                        when others =>
                            x_run_state_cmd		<= ERROR;
                    end case;
                end if;
                -- ready 
                asi_ctrl_xcvr_ready         <= '1';
            end if;
        end if;
    end process;
    
    -- ////////////////////////////////////////////////////////
    -- debug timestamp (debug_ts)
    -- ////////////////////////////////////////////////////////
    -- work flow:
    -- 1) recalculate the global timestamp of each hit written to the main fifo
    -- 2) calculate the latency of such hit at this point
    -- 3) output to the debug_ts port for histogram IP
    proc_debug_ts : process (i_clk_xcvr,i_rst_xcvr)
    begin 
        if (rising_edge(i_clk_xcvr)) then 
            if (i_rst_xcvr = '1') then 
                aso_debug_ts_data       <= (others => '0');
                aso_debug_ts_valid      <= '0';
                debug_ts_valid          <= '0';
            else   
                -- default 
                debug_ts_valid      <= '0';
                aso_debug_ts_valid  <= '0';
                
                -- --------------------------------
                -- update header ts (47 downto 12) 
                -- --------------------------------
                if (main_fifo_wr_status = START_OF_FRAME) then 
                    debug_ts_hdr        <= gts_8n_in_transmission(47 downto 12);
                end if;
                
                
                -- ----------------------------------
                -- update subheader ts (11 downto 4)
                -- ----------------------------------
                -- ------------------------------
                -- update hit ts (3 downto 0)
                -- ------------------------------
                if (sub_empty = '0' and main_fifo_wr_status = TRANSMISSION) then -- 
                    if (main_fifo_din(37) = '0') then 
                        -- hits
                        debug_ts_valid          <= '1';
                        debug_ts_hit            <= main_fifo_din(31 downto 28);
                    else 
                        -- subheader
                        debug_ts_subh           <= main_fifo_din(31 downto 24);
                    end if;
                end if;
                
                -- compound the 48 ts for each hits
                if (debug_ts_valid = '1') then 
                    aso_debug_ts_valid      <= '1';
                    aso_debug_ts_data       <= std_logic_vector(resize(x_gts_counter - unsigned(debug_ts_hit_global), aso_debug_ts_data'length));
                end if;
                
             
            
            end if;
        
        end if;
    end process;
    
    proc_debug_ts_comb : process (all)
    begin
        debug_ts_hit_global       <= debug_ts_hdr & debug_ts_subh & debug_ts_hit;
    
    end process;
    
    
    -- ///////////////////////////////////////////////////////////////////////////////
    -- @name            debug_burst
    -- @brief           calculate the delta of timestamp and inter-arrival time
    --                  of adjacent hits. 
    --
    -- ///////////////////////////////////////////////////////////////////////////////
    
    proc_debug_burst : process (i_clk_xcvr) 
    begin 
        if rising_edge(i_clk_xcvr) then 
            if (i_rst_xcvr = '0' and x_run_state_cmd = RUNNING) then 
                -- default
                egress_valid                <= '0';
                delta_valid                 <= '0';
                aso_debug_burst_valid       <= '0';
                aso_ts_delta_valid          <= '0';
                -- --------------
                -- latch new 
                -- --------------
                if (debug_ts_valid = '1') then -- 48 bit - 48 bit
                    -- timestamp
                    egress_timestamp(0)         <= debug_ts_hit_global(egress_timestamp(0)'high downto 0);
                    egress_timestamp(1)         <= egress_timestamp(0);
                    -- arrival
                    egress_arrival(0)           <= std_logic_vector(x_gts_counter);
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
                        delta_timestamp(delta_timestamp'high)               <= '0';
                        delta_timestamp(delta_timestamp'high-1 downto 0)    <= std_logic_vector(resize(unsigned(egress_timestamp(0)) - unsigned(egress_timestamp(1)), delta_timestamp'length-1)); -- delta_timestamp = Hit_{t+1} - Hit_{t}
                    else 
                        -- unsorted
                        delta_timestamp(delta_timestamp'high)               <= '1';
                        delta_timestamp(delta_timestamp'high-1 downto 0)    <= std_logic_vector(resize(unsigned(egress_timestamp(1)) - unsigned(egress_timestamp(0)), delta_timestamp'length-1));
                    end if;
                    -- unsigned sub.
                    delta_arrival               <= std_logic_vector(resize(unsigned(egress_arrival(0)) - unsigned(egress_arrival(1)), delta_arrival'length)); -- delta_arrival = Hit_{t+1} - Hit_{t}
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
             else 
                -- default
                egress_valid                <= '0';
                delta_valid                 <= '0';
                aso_debug_burst_valid       <= '0';
                aso_ts_delta_valid          <= '0';
                egress_timestamp            <= (others => (others => '0'));
                egress_arrival              <= (others => (others => '0'));
                delta_timestamp             <= (others => '0');
                delta_arrival               <= (others => '0');
                aso_ts_delta_data           <= (others => '0');
             end if;
        end if;

    end process;


end architecture rtl;






