-- File name: ring_buffer_cam_v2_core.vhd
-- Derived from the active V2 Qsys-generated ring_buffer_cam source.
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Jul 4, 2024
-- Revision: 2.0 (functional verified)
--		Date: Jul 29, 2024
-- Revision: 2.1 (add profiling/debug interfaces)
--      Date: Mar 21, 2025
-- Revision: 2.2 (clean up csr)
--      Date: Mar 24, 2025
-- Revision: 2.3 (fixed bug of gts overflow due to casted int32 type)
--      Date: Aug 13, 2025
-- Revision: 2.4 (allow push writes while pop search/count is active; only pop erase stays exclusive)
--      Date: Apr 2, 2026
-- Revision: 2.5 (add common CSR identity header and metadata selector)
--      Date: Apr 2, 2026
-- Revision: 2.6 (fix PREP run-control decode to avoid stale IDLE ready ack)
--      Date: Apr 2, 2026
-- Revision: 2.7 (latch PREP flush completion so ready does not depend on a one-cycle overlap)
--      Date: Apr 2, 2026
-- Revision: 2.8 (use the live cam_clean register bank for PREP ready qualification)
--      Date: Apr 2, 2026
-- Revision: 2.9 (start dequeue sequencing at the exact expected-latency boundary so ts[11:4]=0 is emitted)
--      Date: Apr 2, 2026
-- Revision: 2.10 (use width-safe 48-bit zero compares in cam_clean / drain qualification)
--      Date: Apr 16, 2026
-- Revision: 2.11 (latch the just-written search key so same-key overwrite erase suppression is correct at burst tail)
--      Date: Apr 17, 2026
-- Revision: 2.12 (no RTL delta; metadata bump for the long-run scoreboard recovery checkpoint)
--      Date: Apr 17, 2026
-- Revision: 2.13 (no RTL delta; metadata bump for the nightly pressure-fingerprint / scoreboard-consistency checkpoint)
--      Date: Apr 17, 2026
-- Revision: 2.14 (no RTL delta; metadata bump for the durable DV evidence publisher and live-partition harness checkpoint)
--      Date: Apr 18, 2026
-- Revision: 2.15 (no RTL delta; metadata bump for the X019 boundary-driver and scoreboard epoch-reset harness fixes)
--      Date: Apr 19, 2026
-- Revision: 2.16 (no RTL delta; align the packaged build stamp to MMDD and bump the patch for a fresh Platform Designer pickup)
--      Date: Apr 19, 2026
-- Revision: 2.17 (no RTL delta; package the PROF multi-key closure and silent-key evidence refresh)
--      Date: Apr 20, 2026
-- Revision: 2.18 (no RTL delta; package the long-run fingerprint, explicit-seed, and calibrated PROF integrity refresh)
--      Date: Apr 20, 2026
-- Revision: 2.19 (no RTL delta; package the calibrated steady-state, overlap, and partition-profile PROF closure)
--      Date: Apr 20, 2026
-- Revision: 2.20 (gate descriptor issuance on pop_cmd_fifo_full and make soft_reset abort active state cleanly)
--      Date: Apr 20, 2026
-- Revision: 2.21 (no RTL logic delta; align delivered metadata with the staged late-arrival harness cleanup and PROF P041-P045 closure)
--      Date: Apr 20, 2026
-- Revision: 2.22 (no RTL logic delta; package the sustained-backpressure harness cleanup and active-build PROF P059/P060/P064 closure)
--      Date: Apr 20, 2026
-- Revision: 2.23 (advance the pop round-robin scheduler to the next pending partition when equal-load peers are waiting)
--      Date: Apr 20, 2026
-- Revision: 2.24 (no RTL logic delta; package the clean terminate/deassembly-drain harness fix and PROF P005/P006 closure)
--      Date: Apr 20, 2026
-- Revision: 2.25 (guard the unstable SEARCH window against cross-key overlap and keep the frozen SEARCH snapshot immutable at the write pointer)
--      Date: Apr 21, 2026
-- Revision: 2.26 (fix low-stage encoder variant build safety and wrap the live write pointer at the configured ring depth)
--      Date: Apr 21, 2026
-- Revision: 2.27 (wrap the overwrite erase address at the configured ring depth for non-power-of-two builds)
--      Date: Apr 21, 2026
-- Revision: 2.28 (carry the overwrite erase slot from push_write so the remaining CAM erase path closes the tightened standalone signoff clock)
--      Date: Apr 21, 2026
-- Revision: 2.29 (count frozen SEARCH snapshots by indexed chunks so COUNT no longer rewrites the full partition vectors every cycle)
--      Date: Apr 22, 2026
-- Revision: 2.30 (re-open settled SEARCH-tail overlap with a conservative overwrite-slot guard so standalone timing stays closed)
--      Date: Apr 22, 2026
-- Version : 26.2.6
-- Date    : 20260422
-- Change  : keep settled SEARCH-tail overlap safe without re-opening the standalone timing failure in 26.2.6.0422
--
-- =========
-- Description:	[Ring-buffer Shaped Content-Addressable-Memory (CAM)] 
--		This cam is implemented in a special shape of a ring-buffer, where write pointer (wr_ptr) is ever mono-increasing 
--		and the read pointer (rd_ptr) is controlled by the look-up result address. The look-up is supported by the CAM natively.
--
--		Functional Description: 

--			Push: Write-alike. The "Push Flow" is: (1) Check the targeted address, if free, skip step 2. (2) Erase that address 
--		
--			Pop: Read-alike. The "Pop Flow" is: (1) Look up the data in the CAM, if found, go to step 2 (2) Erase that address
--				and retrieve the stored data. 
--		
--		Functional Diagram:
--			
--
--
-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.std_logic_misc.or_reduce;

entity ring_buffer_cam_v2_core is 
generic(
	SEARCH_KEY_WIDTH	: natural := 8; -- = timestamp length (8ns) [11:4]
	RING_BUFFER_N_ENTRY	: natural := 512; -- = CAM size, can be tuned (TODO: debug N=768. N=512/1024 verified)
	SIDE_DATA_BITS		: natural := 31; -- type 1 has 39 bit, exclude the search key (8bit), resulting 31 bit
	--SEL_CHANNEL			: natural := 0; -- from 0 to 31 (the selected channel of avst input, other channels will be ignored) -- deprecated
	INTERLEAVING_FACTOR	: natural := 4; -- only power of 2 are allowed, this number multiple of ring buffer cam will be instantiated
	INTERLEAVING_INDEX	: natural := 0; -- assign an unique index for each ring buffer cam. 
	N_PARTITIONS		: natural := 4;
	ENCODER_LEAF_WIDTH	: natural := 16;
	ENCODER_PIPE_STAGES	: natural := 4;
	IP_UID				: natural := 1380074317;
	VERSION_MAJOR		: natural := 26;
	VERSION_MINOR		: natural := 2;
	VERSION_PATCH       : natural := 6;
	BUILD				: natural := 422;
	VERSION_DATE		: natural := 20260422;
	VERSION_GIT			: natural := 0;
	INSTANCE_ID			: natural := 0;
	DEBUG				: natural := 1
);
port(
	-- control and status registers interface
	avs_csr_readdata				: out std_logic_vector(31 downto 0);
	avs_csr_read					: in  std_logic;
	avs_csr_address					: in  std_logic_vector(4 downto 0);
	avs_csr_waitrequest				: out std_logic; 
	avs_csr_write					: in  std_logic;
	avs_csr_writedata				: in  std_logic_vector(31 downto 0);
	
	-- run control interface
	asi_ctrl_data					: in  std_logic_vector(8 downto 0); 
	asi_ctrl_valid					: in  std_logic;
	asi_ctrl_ready					: out std_logic;
	
	-- ============ INGRESS ==============
	-- input stream of processed hits 
	asi_hit_type1_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15 (same as asic index, span from 0 to 15)
	asi_hit_type1_startofpacket		: in  std_logic; -- packet is supported by upstream
	asi_hit_type1_endofpacket		: in  std_logic; -- processor use this to mark the start and end of run (sor/eor)
	asi_hit_type1_empty             : in  std_logic; -- lane-targeted close marker, must not be written into the deassembly fifo
	asi_hit_type1_data				: in  std_logic_vector(38 downto 0);
	asi_hit_type1_valid				: in  std_logic;
	asi_hit_type1_ready				: out std_logic; -- itself has fifo, so no backpressure is required for upstream, just check for fifo full. 
	asi_hit_type1_error             : in  std_logic_vector(0 downto 0); -- {"tserr"}
                                                                        -- timestamp error : this hit has timestamp out of range (0,2000) delay, so it is probably wrong
    
	-- ============ EGRESS ==============
	-- output stream of framed hits (aligned to word) (ts[3:0])
	aso_hit_type2_channel			: out std_logic_vector(3 downto 0); -- max_channel=15 (same as interleaving index, span from 0 to INTERLEAVING_FACTOR-1)
	aso_hit_type2_startofpacket		: out std_logic; -- sop at each subheader
	aso_hit_type2_endofpacket		: out std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	aso_hit_type2_data				: out std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	-- two cases for [31:0]
	-- 1) sub-header: [31:24]=ts[11:4], [23:16]=TBD, [15:8]=hit_cnt[7:0], [7:0]=K23.7(0xF7)
	-- 2) hit: [31:0]=specbook MuTRiG hit format
	aso_hit_type2_valid				: out std_logic;
	aso_hit_type2_ready				: in  std_logic;
    aso_hit_type2_error             : out std_logic_vector(0 downto 0); -- {"tsglitcherr"}
                                                                        -- timestamp glitch error : ts[12] read from side ram does not match with current header ts[12]
                                                                        --                          indicating this hit are assigned to a wrong header (delay or forward by an odd number of frames, ex: 1, 3, 5 ...)
                                                                        --                          this usually happens when you have tserr at the input and did not filter these hits away.
                                                                        --                          as the wrong hits are in, they occupy cam spaces for no good reason. they will be overwrote by push engine, if fill-level is high.
                                                                        --                          So, you need to check this is never asserted before dignosing the overwrite count of cam.
	
	
	aso_filllevel_valid             : out std_logic;
    aso_filllevel_data              : out std_logic_vector(15 downto 0);
    
    -- clock and reset interface
	i_rst							: in  std_logic;
	i_clk							: in  std_logic



);
end entity ring_buffer_cam_v2_core;

architecture rtl of ring_buffer_cam_v2_core is 
	function min_nat (
		lhs : natural;
		rhs : natural
	) return natural is
	begin
		if (lhs < rhs) then
			return lhs;
		end if;
		return rhs;
	end function;

	function ceil_div_nat (
		numer : natural;
		denom : natural
	) return natural is
	begin
		return (numer + denom - 1) / denom;
	end function;

	function slv_to_natural_clean (
		addr_v : std_logic_vector
	) return natural is
	begin
		if (is_x(addr_v)) then
			return 0;
		end if;
		return to_integer(unsigned(addr_v));
	end function;

	function clear_onehot_bit (
		vec_v   : std_logic_vector;
		bit_idx : natural
	) return std_logic_vector is
		variable next_v : std_logic_vector(vec_v'range);
	begin
		next_v := vec_v;
		if (bit_idx < vec_v'length) then
			next_v(bit_idx) := '0';
		end if;
		return next_v;
	end function;

	function count_ones_4 (
		vec_v : std_logic_vector(3 downto 0)
	) return unsigned is
		variable total_v : unsigned(2 downto 0);
	begin
		total_v := (others => '0');
		for i in 0 to 3 loop
			if (vec_v(i) = '1') then
				total_v := total_v + 1;
			end if;
		end loop;
		return total_v;
	end function;

	function count_ones_16 (
		vec_v : std_logic_vector(15 downto 0)
	) return natural is
		variable count0_v : unsigned(2 downto 0);
		variable count1_v : unsigned(2 downto 0);
		variable count2_v : unsigned(2 downto 0);
		variable count3_v : unsigned(2 downto 0);
		variable sum0_v   : unsigned(3 downto 0);
		variable sum1_v   : unsigned(3 downto 0);
		variable total_v  : unsigned(4 downto 0);
	begin
		count0_v := count_ones_4(vec_v(3 downto 0));
		count1_v := count_ones_4(vec_v(7 downto 4));
		count2_v := count_ones_4(vec_v(11 downto 8));
		count3_v := count_ones_4(vec_v(15 downto 12));
		sum0_v   := resize(count0_v, sum0_v'length) + resize(count1_v, sum0_v'length);
		sum1_v   := resize(count2_v, sum1_v'length) + resize(count3_v, sum1_v'length);
		total_v  := resize(sum0_v, total_v'length) + resize(sum1_v, total_v'length);
		return to_integer(total_v);
	end function;

	function snapshot_chunk_16 (
		vec_v   : std_logic_vector;
		chunk_v : natural
	) return std_logic_vector is
		variable chunk_vec_v : std_logic_vector(15 downto 0);
		variable src_idx_v   : natural;
	begin
		chunk_vec_v := (others => '0');
		for bit_idx in 0 to 15 loop
			src_idx_v := chunk_v * 16 + bit_idx;
			if (src_idx_v < vec_v'length) then
				chunk_vec_v(bit_idx) := vec_v(src_idx_v);
			end if;
		end loop;
		return chunk_vec_v;
	end function;

	function ring_ptr_inc (
		ptr_v : unsigned
	) return unsigned is
		variable next_v : unsigned(ptr_v'range);
	begin
		if (to_integer(ptr_v) >= RING_BUFFER_N_ENTRY-1) then
			next_v := (others => '0');
		else
			next_v := ptr_v + 1;
		end if;
		return next_v;
	end function;

	function ring_ptr_dec (
		ptr_v : unsigned
	) return unsigned is
		variable prev_v : unsigned(ptr_v'range);
	begin
		if (to_integer(ptr_v) = 0) then
			prev_v := to_unsigned(RING_BUFFER_N_ENTRY-1, ptr_v'length);
		else
			prev_v := ptr_v - 1;
		end if;
		return prev_v;
	end function;

	function pack_version_func (
		major_v : natural;
		minor_v : natural;
		patch_v : natural;
		build_v : natural
	) return std_logic_vector is
		variable version_v : std_logic_vector(31 downto 0);
	begin
		version_v := (others => '0');
		version_v(31 downto 24) := std_logic_vector(to_unsigned(major_v, 8));
		version_v(23 downto 16) := std_logic_vector(to_unsigned(minor_v, 8));
		version_v(15 downto 12) := std_logic_vector(to_unsigned(patch_v, 4));
		version_v(11 downto 0)  := std_logic_vector(to_unsigned(build_v, 12));
		return version_v;
	end function;
		
	-- universal 8b10b
	constant K285					: std_logic_vector(7 downto 0) := "10111100"; -- 16#BC#
	constant K284					: std_logic_vector(7 downto 0) := "10011100"; -- 16#9C#
	constant K237					: std_logic_vector(7 downto 0) := "11110111"; -- 16#F7#
	constant CSR_WORD_UID_CONST			: natural := 0;
	constant CSR_WORD_META_CONST		: natural := 1;
	constant CSR_WORD_CTRL_CONST		: natural := 2;
	constant CSR_WORD_EXPECTED_LAT_CONST	: natural := 3;
	constant CSR_WORD_FILL_LEVEL_CONST	: natural := 4;
	constant CSR_WORD_INERR_COUNT_CONST	: natural := 5;
	constant CSR_WORD_PUSH_COUNT_CONST	: natural := 6;
	constant CSR_WORD_POP_COUNT_CONST	: natural := 7;
	constant CSR_WORD_OVERWRITE_CONST	: natural := 8;
	constant CSR_WORD_CACHE_MISS_CONST	: natural := 9;
	constant META_SEL_VERSION_CONST		: std_logic_vector(1 downto 0) := "00";
	constant META_SEL_DATE_CONST		: std_logic_vector(1 downto 0) := "01";
	constant META_SEL_GIT_CONST			: std_logic_vector(1 downto 0) := "10";
	constant META_SEL_INSTANCE_CONST	: std_logic_vector(1 downto 0) := "11";
	-- input avst data format
	constant ASIC_HI				: natural := 38;
	constant ASIC_LO				: natural := 35; -- asic[3:0], span from 0 to 15
	constant CHANNEL_HI				: natural := 34;
	constant CHANNEL_LO				: natural := 30;
	constant TCC8N_HI				: natural := 29; -- 28
	constant TCC8N_LO				: natural := 17; -- 21
	constant TCC1n6_HI				: natural := 16; 
	constant TCC1n6_LO				: natural := 14; 
	constant TFINE_HI				: natural := 13;
	constant TFINE_LO				: natural := 9;
	constant ET1n6_HI				: natural := 8;
	constant ET1n6_LO				: natural := 0;
	-- search key range in data ts8n
	constant SK_RANGE_HI			: natural := 11; -- only this range of ts8n are treated as search key
	constant SK_RANGE_LO			: natural := 4;
	-- generic for main cam
	constant MAIN_CAM_SIZE			: natural := RING_BUFFER_N_ENTRY;
	constant MAIN_CAM_DATA_WIDTH	: natural := integer(ceil(real(SEARCH_KEY_WIDTH)/8.0)*8.0); -- TODO: adapt for true dpram
	constant MAIN_CAM_ADDR_WIDTH	: natural := integer(ceil(log2(real(RING_BUFFER_N_ENTRY)))); -- 9 bit(512 entry), 6 bit(64 entry)
	-- generic for side ram
	constant SRAM_DATA_WIDTH		: natural := 1 + SEARCH_KEY_WIDTH + SIDE_DATA_BITS; -- bit[39] = occupancy flag, bit[38:0] = hit_type1
	constant SRAM_ADDR_WIDTH		: natural := integer(ceil(log2(real(RING_BUFFER_N_ENTRY)))); -- 9 bit
	-- interleaving feature
	constant TCC8N_INTERLEAVING_BITS	: natural := integer(ceil(log2(real(INTERLEAVING_FACTOR)))); -- 2 bit for 4 copies
	constant TCC8N_INTERLEAVING_LO		: natural := TCC8N_LO + SK_RANGE_LO; -- 21 (offset to input avst data format)
	constant TCC8N_INTERLEAVING_HI		: natural := TCC8N_INTERLEAVING_LO + TCC8N_INTERLEAVING_BITS - 1; -- 22
	
	-- main cam
	signal cam_erase_en				: std_logic;
	signal cam_wr_en				: std_logic;
	signal cam_wr_data				: std_logic_vector(MAIN_CAM_DATA_WIDTH-1 downto 0);
	signal cam_wr_addr				: std_logic_vector(MAIN_CAM_ADDR_WIDTH-1 downto 0);
	signal cam_cmp_din				: std_logic_vector(MAIN_CAM_DATA_WIDTH-1 downto 0);
	signal cam_match_addr_oh		: std_logic_vector(MAIN_CAM_SIZE-1 downto 0);
	
	
	-- side ram
	signal side_ram_raddr			: std_logic_vector(SRAM_ADDR_WIDTH-1 downto 0);
	signal side_ram_raddr_nat		: natural range 0 to 2**SRAM_ADDR_WIDTH - 1;
	signal side_ram_dout			: std_logic_vector(SRAM_DATA_WIDTH-1 downto 0);
	signal side_ram_we				: std_logic;
	signal side_ram_waddr			: std_logic_vector(SRAM_ADDR_WIDTH-1 downto 0);
	signal side_ram_waddr_nat		: natural range 0 to 2**SRAM_ADDR_WIDTH - 1;
	signal side_ram_din				: std_logic_vector(SRAM_DATA_WIDTH-1 downto 0);
	signal dbg_side_ram_patch_we		: std_logic;
	signal dbg_side_ram_patch_addr		: std_logic_vector(SRAM_ADDR_WIDTH-1 downto 0);
	signal dbg_side_ram_patch_addr_nat	: natural range 0 to 2**SRAM_ADDR_WIDTH - 1;
	signal dbg_side_ram_patch_data		: std_logic_vector(SRAM_DATA_WIDTH-1 downto 0);
	
	-- pop command fifo 
	constant POP_CMD_FIFO_LPM_WIDTH	    : natural := 9; -- data width. ts[12:4]. only ts[11:4] is used for search key and subheader ts. ts[12] is used for ts glitch validation.
	constant POP_CMD_FIFO_LPM_WIDTHU	: natural := 4; -- used word width (note: 2 to power of <widthu> = fifo depth)
                                                        -- 2 (depth=4) will overflow at >500kHz rate/ch
                                                        -- 3 (depth=8) will overflow at >820kHz rate/ch
                                                        -- 4 (depth=16) should be the *default
                                                        --              will NOT overflow at 960kHz rate/ch, max fill-level < 11
                                                        -- TODO: in case of 16, the add-on delay of pop command is as high as 16*<pop_cycles>, which is minimum 16*8 = 128 cycles. 
                                                        --       you need to adapt the upstream fifo depth (input fifo of feb_frame_assembly) to account for this extra delay.
                                                        --       as other CAM ways might overflow while waiting for this way to execute its pop command.  
                                                        --       when depth=4, the up stream fifo depth of 256 has no overflow at near 1MHz rate/ch. 
                                                        --       *re-confirm this, when changing to higher depth of the command fifo.
	signal pop_cmd_fifo_rdack		: std_logic;
	signal pop_cmd_fifo_dout		: std_logic_vector(POP_CMD_FIFO_LPM_WIDTH-1 downto 0);
	signal pop_cmd_fifo_wrreq		: std_logic;
	signal pop_cmd_fifo_din			: std_logic_vector(POP_CMD_FIFO_LPM_WIDTH-1 downto 0);
	signal pop_cmd_fifo_empty		: std_logic;
	signal pop_cmd_fifo_full		: std_logic;
	signal pop_cmd_fifo_usedw		: std_logic_vector(POP_CMD_FIFO_LPM_WIDTHU-1 downto 0);
	signal pop_cmd_fifo_sclr		: std_logic;
	-- pop command fifo (cmp)
	component cmd_fifo
	port (
		clock		: in  std_logic;
		data		: in  std_logic_vector(POP_CMD_FIFO_LPM_WIDTH-1 downto 0);
		rdreq		: in  std_logic;
		sclr		: in  std_logic;
		wrreq		: in  std_logic;
		empty		: out std_logic;
		full		: out std_logic;
		q			: out std_logic_vector(POP_CMD_FIFO_LPM_WIDTH-1 downto 0);
		usedw		: out std_logic_vector(POP_CMD_FIFO_LPM_WIDTHU-1 downto 0)
	);
	end component;
	
	-- deassembly fifo
	constant DEASSEMBLY_FIFO_LPM_WIDTH	: natural := 40;
	constant DEASSEMBLY_FIFO_LPM_WIDTHU	: natural := 8;
	signal deassembly_fifo_rdack		: std_logic;
	signal deassembly_fifo_dout			: std_logic_vector(DEASSEMBLY_FIFO_LPM_WIDTH-1 downto 0);
	signal deassembly_fifo_wrreq		: std_logic;
	signal deassembly_fifo_din			: std_logic_vector(DEASSEMBLY_FIFO_LPM_WIDTH-1 downto 0);
	signal deassembly_fifo_empty		: std_logic;
	signal deassembly_fifo_full			: std_logic;
	signal deassembly_fifo_usedw		: std_logic_vector(DEASSEMBLY_FIFO_LPM_WIDTHU-1 downto 0);
	signal deassembly_fifo_sclr			: std_logic;
	-- deassembly fifo (cmp)
	component scfifo_w40d256
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (39 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (39 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
	end component;
	
	-- gts counter
	signal gts_8n					: unsigned(47 downto 0);
	signal gts_counter_rst			: std_logic;
	
	-- ------------------
	-- match encoder
	-- ------------------
	constant MATCH_ENCODER_PIPE_STAGES_CONST : natural := min_nat(ENCODER_PIPE_STAGES, 4);
	constant MATCH_PARTITION_SIZE_CONST      : natural := RING_BUFFER_N_ENTRY / N_PARTITIONS;
	constant MATCH_PARTITION_ADDR_W_CONST    : natural := integer(ceil(log2(real(MATCH_PARTITION_SIZE_CONST))));
	constant MATCH_COUNT_CHUNK_WIDTH_CONST   : natural := 16;
	constant MATCH_COUNT_CHUNKS_CONST        : natural := ceil_div_nat(MATCH_PARTITION_SIZE_CONST, MATCH_COUNT_CHUNK_WIDTH_CONST);
	type match_partition_onehot_t            is array (0 to N_PARTITIONS-1) of std_logic_vector(MATCH_PARTITION_SIZE_CONST-1 downto 0);
	type match_partition_binary_t            is array (0 to N_PARTITIONS-1) of std_logic_vector(MATCH_PARTITION_ADDR_W_CONST-1 downto 0);
	signal cam_match_addr_oh_partitioned_comb : match_partition_onehot_t;
	signal pop_partition_snapshot             : match_partition_onehot_t;
	signal pop_partition_load                 : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_advance              : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_pending              : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_result_valid         : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_flag                 : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_has_more             : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_eval_stage0_valid    : std_logic_vector(N_PARTITIONS-1 downto 0);
	signal pop_partition_addr_lsb             : match_partition_binary_t;
	signal pop_total_hits                     : unsigned(MAIN_CAM_ADDR_WIDTH downto 0);
	signal pop_last_hit_pending               : std_logic;
	signal pop_count_partition_idx            : natural range 0 to N_PARTITIONS-1;
	signal pop_count_chunk_idx                : natural range 0 to MATCH_COUNT_CHUNKS_CONST-1;
	signal pop_count_total_acc                : unsigned(MAIN_CAM_ADDR_WIDTH downto 0);
	signal pop_count_done                     : std_logic;
	signal pop_rr_idx                         : natural := 0;
	signal pop_load_idx                       : natural := 0;
	
	-- avmm (csr)
	type csr_t is record
		-- word 1
		meta_sel					: std_logic_vector(1 downto 0); -- (RW) VERSION/DATE/GIT/INSTANCE_ID select
		-- word 2
		go							: std_logic; -- (RW)
		soft_reset					: std_logic; -- (RW)
		filter_inerr					: std_logic; -- (RW)
		-- word 3
		expected_latency			: std_logic_vector(15 downto 0); -- (RW)
		-- word 4
		fill_level					: std_logic_vector(31 downto 0); -- (RO)
		-- word 8
		overwrite_cnt				: std_logic_vector(31 downto 0); -- (RO)
		overwrite_cnt_rst			: std_logic; -- (WO)
		overwrite_cnt_rst_done		: std_logic; -- (internal)
	end record; 
	signal csr						: csr_t;

	-- streaming input deassembly
	constant HIT_TYPE1_DATA_WIDTH			: natural := asi_hit_type1_data'length;
	constant HIT_TYPE1_TS8N_WIDTH			: natural := TCC8N_HI-TCC8N_LO+1;
	constant SK_WIDTH						: natural := SK_RANGE_HI-SK_RANGE_LO+1;
	signal in_payload_valid					: std_logic;
	signal in_hit_side						: std_logic_vector(HIT_TYPE1_DATA_WIDTH-1 downto 0);
	signal in_hit_ts8n						: std_logic_vector(HIT_TYPE1_TS8N_WIDTH-1 downto 0);
	signal in_hit_sk						: std_logic_vector(SK_WIDTH-1 downto 0); -- search key
	
	-- push engine
	type push_state_t is (ERASE, WRITE_AND_CHECK);
	signal push_state					: push_state_t;
	signal write_pointer				: unsigned(SRAM_ADDR_WIDTH-1 downto 0);
	signal push_erase_addr_reg			: unsigned(SRAM_ADDR_WIDTH-1 downto 0);
	signal push_erase_req				: std_logic;
	signal push_write_req				: std_logic;
	signal push_erase_grant				: std_logic;
	signal push_write_grant				: std_logic;
	signal push_write_grant_reg			: std_logic;
	signal push_write_sk_reg			: std_logic_vector(SK_WIDTH-1 downto 0);
	signal pop_current_sk				: std_logic_vector(8 downto 0); -- ts[12:4] (9bit)
	
	-- pop descriptor generator
	signal expected_latency_48b			: std_logic_vector(47 downto 0);
	signal read_time_ptr				: unsigned(47 downto 0);
    signal read_time_ptr_comb           : unsigned(47 downto 0);
	
	-- pop engine
	type pop_engine_state_t is (IDLE, SEARCH, LOAD, COUNT, DRAIN, RESET, FLUSHING, FLUSHING_RST);
	signal pop_engine_state							: pop_engine_state_t;
	signal pop_pipeline_start						: std_logic;
	signal pop_erase_req							: std_logic;
	signal pop_erase_grant							: std_logic;
	signal pop_hit_valid_comb						: std_logic;
	signal pop_hit_valid							: std_logic;
	signal pop_cache_miss_pulse						: std_logic;
	signal pop_issue_valid							: std_logic;
	signal pop_issue_partition_idx					: natural range 0 to N_PARTITIONS-1;
	signal pop_issue_addr							: std_logic_vector(MAIN_CAM_ADDR_WIDTH-1 downto 0);
	signal pop_cam_match_addr						: std_logic_vector(MAIN_CAM_ADDR_WIDTH-1 downto 0);
	signal pop_hits_count							: unsigned(MAIN_CAM_ADDR_WIDTH downto 0); -- + 1 bit
	signal pop_engine_match_exist					: std_logic;
	signal pop_search_wait_cnt						: unsigned(2 downto 0);
	-- pop engine (flushing)
	constant POP_FLUSH_CAM_DATA_MAX					: unsigned(MAIN_CAM_DATA_WIDTH-1 downto 0) := (others => '1'); -- for flushing
	constant POP_FLUSH_CAM_ADDR_MAX					: unsigned(MAIN_CAM_ADDR_WIDTH-1 downto 0) := (others => '1'); -- for flushing
	signal pop_flush_req							: std_logic;
	signal pop_flush_grant							: std_logic;
	signal pop_flush_ram_done						: std_logic;
	signal pop_flush_cam_done						: std_logic;
	signal flush_ram_wraddr							: unsigned(SRAM_ADDR_WIDTH-1 downto 0);
	signal flush_cam_wrdata							: unsigned(MAIN_CAM_DATA_WIDTH-1 downto 0);
	signal flush_cam_wraddr							: unsigned(MAIN_CAM_ADDR_WIDTH-1 downto 0);
	
	-- streaming output assembly
	signal subheader_gen_done				: std_logic;
	
	
	-- cam and ram arbiter
	signal decision,decision_reg			: natural range 0 to 4;
	signal req								: std_logic_vector(3 downto 0);
	
	-- memory out cleanup
	constant SK_BITS						: natural := SK_RANGE_HI-SK_RANGE_LO+1;
	signal addr_occupied					: std_logic;
	signal cam_erase_data					: std_logic_vector(SK_BITS-1 downto 0);
	signal hit_pop_data_comb				: std_logic_vector(HIT_TYPE1_DATA_WIDTH-1 downto 0);
	signal side_ram_dout_valid_comb			: std_logic;
	signal side_ram_dout_valid				: std_logic;
	
	-- fill level meter
	type debug_msg_t is record
		push_cnt					: unsigned(47 downto 0);
		pop_cnt						: unsigned(47 downto 0);
		overwrite_cnt				: unsigned(47 downto 0);
		cam_clean					: std_logic;
		cache_miss_cnt				: unsigned(47 downto 0);
        inerr_cnt                   : unsigned(47 downto 0);
	end record;
	signal debug_msg				: debug_msg_t;
	signal debug_msg2				: debug_msg_t;
	signal fill_level_tmp					: unsigned (47 downto 0);
	--signal ow_cnt_tmp						: unsigned(31 downto 0);
	
	-- run control management 
	type run_state_t is (IDLE, RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST, SYNC_TEST, RESET, OUT_OF_DAQ, ERROR);
	signal run_state_cmd					: run_state_t;
	signal endofrun_seen					: std_logic;
	signal gts_end_of_run					: unsigned(47 downto 0);
	signal run_mgmt_flush_memory_start		: std_logic;
	signal run_mgmt_flush_memory_done		: std_logic;
	signal terminating_drain_done				: std_logic;
	signal run_mgmt_flushed					: std_logic;
	signal dbg_run_state_code				: unsigned(3 downto 0);
	signal dbg_pop_engine_state_code		: unsigned(2 downto 0);
	signal dbg_push_state_code				: std_logic;
	signal dbg_pop_rr_idx					: unsigned(1 downto 0);
	signal dbg_pop_issue_partition_idx		: unsigned(1 downto 0);
	signal dbg_pop_count_partition_idx		: unsigned(1 downto 0);
	signal dbg_pop_partition_pending		: std_logic_vector(3 downto 0);
	signal dbg_pop_partition_load			: std_logic_vector(3 downto 0);
	signal dbg_pop_partition_advance		: std_logic_vector(3 downto 0);
	signal dbg_pop_partition_result_valid	: std_logic_vector(3 downto 0);
	signal dbg_pop_partition_flag			: std_logic_vector(3 downto 0);
	signal dbg_pop_partition_has_more		: std_logic_vector(3 downto 0);
	signal dbg_pop_partition_eval_stage0_valid : std_logic_vector(3 downto 0);

begin

	dbg_run_state_code <= to_unsigned(run_state_t'pos(run_state_cmd), dbg_run_state_code'length);
	dbg_pop_engine_state_code <= to_unsigned(pop_engine_state_t'pos(pop_engine_state), dbg_pop_engine_state_code'length);
	dbg_push_state_code <= '1' when push_state = ERASE else '0';
	dbg_pop_rr_idx <= to_unsigned(pop_rr_idx, dbg_pop_rr_idx'length);
	dbg_pop_issue_partition_idx <= to_unsigned(pop_issue_partition_idx, dbg_pop_issue_partition_idx'length);
	dbg_pop_count_partition_idx <= to_unsigned(pop_count_partition_idx, dbg_pop_count_partition_idx'length);
	dbg_pop_partition_pending <= std_logic_vector(resize(unsigned(pop_partition_pending), dbg_pop_partition_pending'length));
	dbg_pop_partition_load <= std_logic_vector(resize(unsigned(pop_partition_load), dbg_pop_partition_load'length));
	dbg_pop_partition_advance <= std_logic_vector(resize(unsigned(pop_partition_advance), dbg_pop_partition_advance'length));
	dbg_pop_partition_result_valid <= std_logic_vector(resize(unsigned(pop_partition_result_valid), dbg_pop_partition_result_valid'length));
	dbg_pop_partition_flag <= std_logic_vector(resize(unsigned(pop_partition_flag), dbg_pop_partition_flag'length));
	dbg_pop_partition_has_more <= std_logic_vector(resize(unsigned(pop_partition_has_more), dbg_pop_partition_has_more'length));
	dbg_pop_partition_eval_stage0_valid <= std_logic_vector(
		resize(unsigned(pop_partition_eval_stage0_valid), dbg_pop_partition_eval_stage0_valid'length));

	main_cam : entity work.cam_mem_a5 -- TODO: 1) improve timing of output <lut> address 2) add true-dp variant
	-- primitive cam construction
	generic map(
		CAM_SIZE 	    => MAIN_CAM_SIZE,
		CAM_WIDTH 	    => MAIN_CAM_DATA_WIDTH,
		WR_ADDR_WIDTH	=> MAIN_CAM_ADDR_WIDTH,
		RAM_TYPE 	    => "Simple Dual-Port RAM") -- currently only simple dp ram is supported
	port map(
		-- <mod_ctl> : Modifying control port ("Erase-Mode": erase=1, write=X; "Write-Mode": erase=0, write=1; "Idle-Mode": erase=0, write=0)
		i_erase_en		=> cam_erase_en, -- erase has higher priority than write
		i_wr_en			=> cam_wr_en,
		-- <mod_data> : Write port
		i_wr_data		=> cam_wr_data,
		i_wr_addr		=> cam_wr_addr,
		-- <lut> : Loop up port 
		i_cmp_din		=> cam_cmp_din,
		o_match_addr	=> cam_match_addr_oh,
		-- clock and reset interface
		i_rst			=> i_rst,
		i_clk			=> i_clk
	);
	
	side_ram : entity work.alt_simple_dpram
	-- Side ram stores the hit type 1 and occupancy flag with the same address as CAM
	-- used to indicate occupancy when write attemp is seen 
	-- RDW: "old data"
	generic map(
		DATA_WIDTH	=> SRAM_DATA_WIDTH,
		ADDR_WIDTH	=> SRAM_ADDR_WIDTH)
	port map(
		-- read port
		raddr	        => side_ram_raddr_nat,
		dbg_patch_addr  => dbg_side_ram_patch_addr_nat,
		q		=> side_ram_dout,
		-- write port
		we		=> side_ram_we,
		waddr	        => side_ram_waddr_nat,
		dbg_patch_data  => dbg_side_ram_patch_data,
		dbg_patch_we    => dbg_side_ram_patch_we,
		data	=> side_ram_din,
		-- clock interface
		clk		=> i_clk
	);

	side_ram_raddr_nat	<= slv_to_natural_clean(side_ram_raddr);
	side_ram_waddr_nat	<= slv_to_natural_clean(side_ram_waddr);
	dbg_side_ram_patch_addr_nat <= slv_to_natural_clean(dbg_side_ram_patch_addr);
	
	pop_cmd_fifo : cmd_fifo port map (
        -- write port
		wrreq	=> pop_cmd_fifo_wrreq,
		data	=> pop_cmd_fifo_din,
		-- read port
		rdreq	=> pop_cmd_fifo_rdack,
		q		=> pop_cmd_fifo_dout,
		-- status 
		empty	=> pop_cmd_fifo_empty,
		full	=> pop_cmd_fifo_full,
		usedw	=> pop_cmd_fifo_usedw,
		-- clock and reset interface
		sclr	=> pop_cmd_fifo_sclr,
		clock	=> i_clk
	);
	
	deassembly_fifo : scfifo_w40d256 PORT MAP (
		-- read port 
		rdreq	=> deassembly_fifo_rdack,
		q	 	=> deassembly_fifo_dout,
		-- write port
		wrreq	=> deassembly_fifo_wrreq,
		data	=> deassembly_fifo_din,
		-- status
		empty	=> deassembly_fifo_empty,
		full	=> deassembly_fifo_full,
		usedw	=> deassembly_fifo_usedw,
		-- clock and reset interface
		sclr	=> deassembly_fifo_sclr,
		clock	=> i_clk
	);

	proc_gts_counter : process (i_clk)
	-- counter of the global timestamp on the FPGA
		-- needs to be 48 bit at 125 MHz
	begin
		if rising_edge(i_clk) then
			if (gts_counter_rst = '1' or csr.soft_reset = '1') then 
				 -- reset counter
				gts_8n		<= (others => '0');
			else
				-- begin counter
				gts_8n		<= gts_8n + 1;
			end if;
		end if;
	end process;
	
	
	gen_addr_enc_logic : for i in 0 to N_PARTITIONS-1 generate
		e_enc_logic : entity work.addr_enc_logic_partitioned
		generic map(
			PARTITION_SIZE      => MATCH_PARTITION_SIZE_CONST,
			PARTITION_ADDR_BITS => MATCH_PARTITION_ADDR_W_CONST,
			LEAF_WIDTH          => ENCODER_LEAF_WIDTH,
			PIPE_STAGES         => MATCH_ENCODER_PIPE_STAGES_CONST
		)
		port map(
			i_clk                     => i_clk,
			i_rst                     => i_rst,
			i_load                    => pop_partition_load(i),
			i_advance                 => pop_partition_advance(i),
			i_cam_address_onehot      => pop_partition_snapshot(i),
			o_result_valid            => pop_partition_result_valid(i),
			o_cam_address_binary_lsb  => pop_partition_addr_lsb(i),
			o_cam_match_flag          => pop_partition_flag(i),
			o_cam_has_more_matches    => pop_partition_has_more(i),
			o_cam_match_count         => open,
			o_cam_address_onehot_next => open,
			o_dbg_eval_match_stage0_valid => pop_partition_eval_stage0_valid(i)
		);
	end generate gen_addr_enc_logic;
	
	proc_avmm_csr : process (i_rst, i_clk)
	-- avalon memory-mapped interface for accessing the control and status registers
	-- address map:
	-- 		0: UID
	-- 		1: metadata selector / readback mux
	-- 		2: control and status
	-- 		3: set read pointer latency
	-- 		4: fill level
	-- 		5..9: debug counters
	begin
		if (i_rst = '1') then 
			csr.meta_sel			<= META_SEL_VERSION_CONST;
			csr.go					<= '1'; -- default is "allowed to go"
			csr.soft_reset			<= '0';
			csr.fill_level			<= (others => '0');
			csr.expected_latency	<= std_logic_vector(to_unsigned(2000,csr.expected_latency'length)); -- this is the total latency of read pointer time respect to current gts
			csr.overwrite_cnt		<= (others => '0');
			csr.overwrite_cnt_rst	<= '1';
            csr.filter_inerr        <= '1'; -- *default is on
			fill_level_tmp          <= (others => '0');
            debug_msg2.inerr_cnt    <= (others => '0');
			avs_csr_waitrequest		<= '1';
		elsif (rising_edge(i_clk)) then 
			-- default
			avs_csr_readdata		<= (others => '0');
			if (csr.soft_reset = '1') then
				avs_csr_waitrequest		<= '1';
				csr.soft_reset			<= '0';
				fill_level_tmp			<= (others => '0');
				csr.fill_level			<= (others => '0');
				debug_msg2.inerr_cnt	<= (others => '0');
			else
				-- host read local
				if (avs_csr_read = '1') then 
					avs_csr_waitrequest		<= '0';
					case to_integer(unsigned(avs_csr_address)) is 
						when CSR_WORD_UID_CONST =>
							avs_csr_readdata		<= std_logic_vector(to_unsigned(IP_UID, avs_csr_readdata'length));
						when CSR_WORD_META_CONST =>
							case csr.meta_sel is
								when META_SEL_VERSION_CONST =>
									avs_csr_readdata	<= pack_version_func(VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, BUILD);
								when META_SEL_DATE_CONST =>
									avs_csr_readdata	<= std_logic_vector(to_unsigned(VERSION_DATE, avs_csr_readdata'length));
								when META_SEL_GIT_CONST =>
									avs_csr_readdata	<= std_logic_vector(to_unsigned(VERSION_GIT, avs_csr_readdata'length));
								when others =>
									avs_csr_readdata	<= std_logic_vector(to_unsigned(INSTANCE_ID, avs_csr_readdata'length));
							end case;
						when CSR_WORD_CTRL_CONST =>
							avs_csr_readdata(0)					<= csr.go;
							avs_csr_readdata(1)					<= csr.soft_reset;
							avs_csr_readdata(4)					<= csr.filter_inerr;
						when CSR_WORD_EXPECTED_LAT_CONST =>
							avs_csr_readdata(15 downto 0)		<= csr.expected_latency;
						when CSR_WORD_FILL_LEVEL_CONST =>
							avs_csr_readdata(31 downto 0)		<= csr.fill_level;
						-- below is for debug only (as the reading might overflow)
						when CSR_WORD_INERR_COUNT_CONST =>
							avs_csr_readdata(31 downto 0)		<= std_logic_vector(debug_msg2.inerr_cnt(31 downto 0));
						when CSR_WORD_PUSH_COUNT_CONST =>
							avs_csr_readdata(31 downto 0)		<= std_logic_vector(debug_msg2.push_cnt(31 downto 0));
						when CSR_WORD_POP_COUNT_CONST =>
							avs_csr_readdata(31 downto 0)		<= std_logic_vector(debug_msg2.pop_cnt(31 downto 0));
						when CSR_WORD_OVERWRITE_CONST =>
							avs_csr_readdata(31 downto 0)		<= std_logic_vector(debug_msg2.overwrite_cnt(31 downto 0));
						when CSR_WORD_CACHE_MISS_CONST =>
							avs_csr_readdata(31 downto 0)		<= std_logic_vector(debug_msg2.cache_miss_cnt(31 downto 0));
						when others =>
					end case;
				-- host write local
				elsif (avs_csr_write = '1') then 
					avs_csr_waitrequest		<= '0';
					case to_integer(unsigned(avs_csr_address)) is 
						when CSR_WORD_META_CONST =>
							csr.meta_sel				<= avs_csr_writedata(1 downto 0);
						when CSR_WORD_CTRL_CONST =>
							csr.go						<= avs_csr_writedata(0);
							csr.soft_reset				<= avs_csr_writedata(1);
							csr.filter_inerr			<= avs_csr_writedata(4);
						when CSR_WORD_EXPECTED_LAT_CONST =>
							csr.expected_latency		<= avs_csr_writedata(15 downto 0);
						when CSR_WORD_FILL_LEVEL_CONST => 
							-- do nothing
						when CSR_WORD_INERR_COUNT_CONST =>
							-- do nothing
						when CSR_WORD_PUSH_COUNT_CONST =>
							-- do nothing
						when CSR_WORD_POP_COUNT_CONST =>
							-- do nothing
						when CSR_WORD_OVERWRITE_CONST => -- write side effect: reset overwrite counter 
							-- csr.overwrite_cnt_rst		<= avs_csr_writedata(0);
						when CSR_WORD_CACHE_MISS_CONST =>
							-- do nothing
						when others =>
					end case;
				else -- idle, update the csr registers
					avs_csr_waitrequest		<= '1';
					csr.soft_reset			<= '0';
					-- fill level and ow cnt
					fill_level_tmp				<= debug_msg2.push_cnt - debug_msg2.pop_cnt - debug_msg2.overwrite_cnt;
					csr.fill_level				<= std_logic_vector(fill_level_tmp(31 downto 0)); -- direct mapped
					--csr.overwrite_cnt			<= std_logic_vector(debug_msg2.overwrite_cnt(31 downto 0) - ow_cnt_tmp); -- this only shows the incremental amount after csr reset
					--if (csr.overwrite_cnt_rst_done = '1' and csr.overwrite_cnt_rst = '1') then -- ack the agent
					--	csr.overwrite_cnt_rst			<= '0';
					--end if;
				end if;
				-- Keep INERR accounting independent from MM CSR bus traffic so a
				-- coincident read/write cannot mask an observed error beat.
	            if (csr.filter_inerr = '1' and asi_hit_type1_error(0) = '1') then 
	                debug_msg2.inerr_cnt            <= debug_msg2.inerr_cnt + 1;
	            end if;
	            if (decision_reg = 3 and run_state_cmd = RUN_PREPARE) then -- flushing 
	                debug_msg2.inerr_cnt            <= (others => '0');
	            end if;
			end if;
		end if;
	end process;
	
	
	
	proc_avst_input_deassembly_comb : process (all)
	-- The deassembly digest the streaming input in combinational logic
	-- Support backpressure internally, so no backpressure fifo in the upstream needed in normal operation. (TODO: add a monitor to detect missing hits at its input)
	-- Functional Description:
	--		Ignore other channels and only take in (write to deassembly_fifo) selected channel.
	--		(interlacer enabled) In this mode, further restriction on the input hit timestamp ts8n(11:4) is made. ts modulo <# interleaving ways> has remainder equal to this IP's index will be accepted.
        variable lane_match_v : boolean;
	begin		
        lane_match_v := false;
		-- fifo write port
		-- triming input stream 
		deassembly_fifo_din(asi_hit_type1_data'high downto 0)		<= asi_hit_type1_data;
		deassembly_fifo_din(39)									<= '0';
		-- write with validation 
		-- default
		deassembly_fifo_wrreq				<= '0';
		if ( (run_state_cmd = RUNNING or (run_state_cmd = TERMINATING and endofrun_seen = '0')) and csr.go = '1') then -- only in running, input are fully allowed. in TERMINATING, take in new hits, which remains in the processor fifo 
			if (asi_hit_type1_valid = '1') then 
                if (asi_hit_type1_empty = '1') then
                    lane_match_v := (to_integer(unsigned(asi_hit_type1_channel(1 downto 0))) = INTERLEAVING_INDEX);
                else
                    lane_match_v := (to_integer(unsigned(asi_hit_type1_data(TCC8N_INTERLEAVING_HI downto TCC8N_INTERLEAVING_LO))) = INTERLEAVING_INDEX);
                end if;
				if (lane_match_v and asi_hit_type1_empty = '0' and deassembly_fifo_full /= '1') then 
				-- only takes the ts modulo interleaving_factor = interleaving_index
				-- (deprecated) since the data streams are merged in mts_processor, ignore data from other non-selected channel
				-- Honor the local ready/valid contract: when the deassembly fifo
				-- is full the upstream source holds its beat until ready returns,
				-- so asserting wrreq here would duplicate that held beat.
                    if (csr.filter_inerr = '1') then 
                        -- filter the tserr from the processor 
                        if (asi_hit_type1_error(0) = '0') then 
                            deassembly_fifo_wrreq			<= '1';
                        end if;
                    else 
                        deassembly_fifo_wrreq			<= '1';
                    end if;
                end if;
			end if;
		end if;
		-- fifo read port
		if (deassembly_fifo_empty /= '1') then -- always latch data when fifo not empty
			in_payload_valid	<= '1';
			in_hit_side		<= deassembly_fifo_dout(in_hit_side'high downto 0);
			in_hit_ts8n		<= deassembly_fifo_dout(TCC8N_HI downto TCC8N_LO);
			in_hit_sk		<= deassembly_fifo_dout(SK_RANGE_HI+TCC8N_LO downto SK_RANGE_LO+TCC8N_LO);
		else -- if empty, the showahead data is not valid
			in_payload_valid				<= '0'; 
			in_hit_side						<= (others => '0');
			in_hit_ts8n						<= (others => '0');
			in_hit_sk						<= (others => '0');
		end if;
		-- fifo rdack 
		if (push_write_grant = '1') then -- only ack this fifo, show next word, if write is granted. derive in the same cycle, new word immediately.
			deassembly_fifo_rdack		<= '1';
		else
			deassembly_fifo_rdack		<= '0';
		end if;
		-- avst ready
		if (csr.soft_reset /= '1' and
			csr.go = '1' and
			(run_state_cmd = RUNNING or
			 (run_state_cmd = TERMINATING and endofrun_seen = '0')) and
			deassembly_fifo_full /= '1') then
			asi_hit_type1_ready			<= '1';
		else
			asi_hit_type1_ready			<= '0';
		end if;
		
	end process;
	
	
	
	
	proc_push_engine : process (i_clk,i_rst)
	-- The push engine has two states: write_and_check and erase
	-- during write_and_lookup, write cam for the input hit type 1 (only ts[11:4]) and write side ram for hit type 1 (all), 
	-- and check (read) the side ram for its old data and occupancy flag. (since RDW is "old-data", it is valid)
	-- If occupancy is high, jump to erase state. Else, stay in write_and_lookup state. 
	-- Throughput: 1 cycle (no overwrite), 2 cycle (overwrite). 
	begin
		if (i_rst = '1') then 
--			debug_msg.push_cnt			<= (others => '0');
--			debug_msg.overwrite_cnt		<= (others => '0');
			push_write_grant_reg	<= '0';
			push_write_sk_reg		<= (others => '0');
			write_pointer			<= (others => '0');
			push_erase_addr_reg		<= (others => '0');
		elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				push_write_grant_reg	<= '0';
				push_write_sk_reg		<= (others => '0');
				write_pointer			<= (others => '0');
				push_erase_addr_reg		<= (others => '0');
			else
				-- latch the grant comb for switching to erase
				push_write_grant_reg	<= push_write_grant;
				if (push_write_grant = '1') then
					push_write_sk_reg	<= in_hit_sk;
					push_erase_addr_reg	<= write_pointer;
				end if;
				case push_state is		
					when ERASE => -- erase
						if (push_erase_grant = '1') then -- this must be granted (highest priority after push_write)!
--							debug_msg.overwrite_cnt		<= debug_msg.overwrite_cnt + 1;
						end if;
					when WRITE_AND_CHECK => -- write 
						if (push_write_grant = '1') then -- incr ptr and cnt
							write_pointer				<= ring_ptr_inc(write_pointer); 
--							debug_msg.push_cnt			<= debug_msg.push_cnt + 1;
						elsif (pop_flush_cam_done = '1') then -- reset when pop has flushed
							-- reset in this push state, not in ERASE, because push should in this state while flush has been executed
--							debug_msg.push_cnt			<= (others => '0');
--							debug_msg.overwrite_cnt		<= (others => '0');
							write_pointer				<= (others => '0');
							push_erase_addr_reg		<= (others => '0');
						else -- maybe pop erase in action
							-- idle
						end if;
					when others =>
				end case;
			end if;
		end if;
	end process;
	
	
	proc_push_engine_comb : process (all)
	begin
		-- derive the state in comb 
		if (side_ram_dout_valid = '1' and addr_occupied = '1' and push_write_grant_reg = '1') then -- only when last state has written a hit
			push_state		<= ERASE;
		else
			push_state		<= WRITE_AND_CHECK;
		end if;
		-- NOTE: although the case flag is comb, valid and occupied are fresh reg out, minimizing the glitch.
		-- default
		push_erase_req 		<= '0';
		push_write_req 		<= '0';
		if (csr.soft_reset /= '1' and
			(run_state_cmd = RUNNING or run_state_cmd = TERMINATING)) then
			case push_state is		
				when ERASE => -- erase
					push_erase_req 		<= '1'; -- the grant is derived in comb
				when WRITE_AND_CHECK => -- write (write through while no show stopper (addr_occupied) is seen) 
					-- Keep draining already-buffered deassembly entries during
					-- TERMINATING after lane-local end-of-run, but do not reopen
					-- ingress acceptance; that contract is enforced by wrreq/ready.
					if (in_payload_valid = '1') then -- always ask for grant access when new data 
						push_write_req 		<= '1';
					else
						push_write_req 		<= '0';
					end if;
				when others =>
			end case;
		end if;
	end process;

	proc_pop_descriptor_generator : process (i_clk,i_rst)
	-- the pop descriptor generator will generate the 8 bit command ts[11:4] for the search key, 
	-- which is processed by the pop engine to pop out all match hits.
	begin
		if (i_rst = '1') then 
			pop_cmd_fifo_wrreq		<= '0';
			pop_cmd_fifo_din		<= (others => '0');
			read_time_ptr			<= (others => '0');
		elsif (rising_edge(i_clk)) then 
			-- default
			pop_cmd_fifo_wrreq		<= '0';
			pop_cmd_fifo_din		<= (others => '0');
			if (csr.soft_reset = '1') then
				read_time_ptr			<= (others => '0');
			else
				if (run_state_cmd = RUNNING) then -- normal pop
					if (pop_cmd_fifo_full /= '1' and
						read_time_ptr(3 downto 0) = "0000" and
						to_integer(unsigned(read_time_ptr(TCC8N_INTERLEAVING_BITS+3 downto 4))) = INTERLEAVING_INDEX) then -- generate read command every 16 cycle 
						-- only generate when interleaving condition is met (see input deassembly)
						pop_cmd_fifo_wrreq		<= '1';
						pop_cmd_fifo_din		<= std_logic_vector(read_time_ptr(SK_RANGE_HI+1 downto SK_RANGE_LO)); -- NOTE: search key also controls the subheader gen cmd
					end if;
				elsif (run_state_cmd = TERMINATING) then -- end of run pop 
					if (terminating_drain_done = '0') then -- keep walking descriptor time until every locally buffered hit has drained
						if (pop_cmd_fifo_full /= '1' and
							read_time_ptr(3 downto 0) = "0000" and
							to_integer(unsigned(read_time_ptr(TCC8N_INTERLEAVING_BITS+3 downto 4))) = INTERLEAVING_INDEX ) then -- generate read command every 16 cycle 
							pop_cmd_fifo_wrreq		<= '1';
							pop_cmd_fifo_din		<= std_logic_vector(read_time_ptr(SK_RANGE_HI+1 downto SK_RANGE_LO)); -- NOTE: search key also controls the subheader gen cmd
						end if;
					end if;
				end if;

	            read_time_ptr       <= read_time_ptr_comb;
			end if;
            
			
		end if;
	end process;
	
	proc_pop_descriptor_generator_comb : process (all)
	begin
    
        -- derive read time pointer (-2000 of current gts time)
    	-- if (to_integer(gts_8n) > to_integer(unsigned(expected_latency_48b))) then 	-- note : LINT_ERROR!!! very likely when comparing (int_48) with (int_16) only lower 32 bits are used, 
																						--        so when int_48 overflowed at 32=1 [31:0]=0, the comparison is wrong.
																						-- follow up : Integer range limits. Because to_integer() will convert into int_32, which is signed 32 bit,
																						--             with range of -2_147_483_648 to +2_147_483_647. 
		if (gts_8n >= unsigned(expected_latency_48b)) then -- start popping exactly at the latency boundary so the first ts[11:4]=0 bin is not skipped
            read_time_ptr_comb		<= gts_8n - unsigned(expected_latency_48b);
        else 
            read_time_ptr_comb       <= (0 => '1', others => '0'); -- avoid generate descriptor when run has just started
        end if;
		expected_latency_48b(csr.expected_latency'high downto 0)								<= csr.expected_latency; 
		expected_latency_48b(expected_latency_48b'high downto csr.expected_latency'length)		<= (others => '0'); -- pads 0 in msb
        
	end process;
	
	
	
	
	proc_pop_engine : process (i_clk,i_rst)
	-- The pop engine reads the pop command fifo for the descriptor/command of search key for a new sub-header (ts[11:4])
	-- Search results are staged into partition encoders, then drained round-robin.
		variable next_rr_idx_v	: natural;
		variable issue_next_rr_idx_v : natural;
		variable rr_scan_idx_v	: natural;
		variable next_pending_idx_v : natural;
		variable other_pending_v : boolean;
		variable all_ready_v	: boolean;
		variable total_hits_v	: unsigned(MAIN_CAM_ADDR_WIDTH downto 0);
			variable chunk_vec_v	: std_logic_vector(MATCH_COUNT_CHUNK_WIDTH_CONST-1 downto 0);
			variable chunk_hits_v	: natural;
	begin
		if (i_rst = '1') then 
			pop_engine_state			<= IDLE; --- TODO: think about it
			pop_flush_ram_done			<= '0';
			pop_flush_cam_done			<= '0';
--			debug_msg.pop_cnt			<= (others => '0');
			run_mgmt_flush_memory_done	<= '0';
			pop_pipeline_start			<= '0';
			pop_search_wait_cnt			<= (others => '0');
			pop_partition_snapshot		<= (others => (others => '0'));
			pop_partition_load			<= (others => '0');
			pop_partition_advance		<= (others => '0');
			pop_partition_pending		<= (others => '0');
			pop_total_hits				<= (others => '0');
			pop_last_hit_pending		<= '0';
				pop_count_partition_idx		<= 0;
				pop_count_chunk_idx			<= 0;
				pop_count_total_acc			<= (others => '0');
				pop_count_done				<= '0';
			pop_rr_idx					<= 0;
			pop_load_idx				<= 0;
			pop_hits_count				<= (others => '0');
			pop_issue_valid				<= '0';
			pop_issue_partition_idx		<= 0;
			pop_issue_addr				<= (others => '0');
			pop_cmd_fifo_rdack			<= '0';
			flush_ram_wraddr			<= (others => '0');
			flush_cam_wrdata			<= (others => '0');
			flush_cam_wraddr			<= (others => '0');
			pop_current_sk				<= (others => '0');
		elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				pop_engine_state			<= IDLE;
				pop_flush_ram_done			<= '0';
				pop_flush_cam_done			<= '0';
				run_mgmt_flush_memory_done	<= '0';
				pop_pipeline_start			<= '0';
				pop_search_wait_cnt			<= (others => '0');
				pop_partition_snapshot		<= (others => (others => '0'));
				pop_partition_load			<= (others => '0');
				pop_partition_advance		<= (others => '0');
				pop_partition_pending		<= (others => '0');
				pop_total_hits				<= (others => '0');
				pop_last_hit_pending		<= '0';
				pop_count_partition_idx		<= 0;
				pop_count_chunk_idx			<= 0;
				pop_count_total_acc			<= (others => '0');
				pop_count_done				<= '0';
				pop_rr_idx					<= 0;
				pop_load_idx				<= 0;
				pop_hits_count				<= (others => '0');
				pop_issue_valid				<= '0';
				pop_issue_partition_idx		<= 0;
				pop_issue_addr				<= (others => '0');
				pop_cmd_fifo_rdack			<= '0';
				flush_ram_wraddr			<= (others => '0');
				flush_cam_wrdata			<= (others => '0');
				flush_cam_wraddr			<= (others => '0');
				pop_current_sk				<= (others => '0');
			else
				pop_partition_load			<= (others => '0');
				pop_partition_advance		<= (others => '0');
				pop_cmd_fifo_rdack			<= '0';
				pop_last_hit_pending		<= '0';
				if (pop_rr_idx = N_PARTITIONS-1) then
					next_rr_idx_v			:= 0;
				else
					next_rr_idx_v			:= pop_rr_idx + 1;
				end if;
				if (pop_issue_partition_idx = N_PARTITIONS-1) then
					issue_next_rr_idx_v	:= 0;
				else
					issue_next_rr_idx_v	:= pop_issue_partition_idx + 1;
				end if;
				next_pending_idx_v	:= pop_issue_partition_idx;
				other_pending_v		:= false;
				for rr_offset in 1 to N_PARTITIONS-1 loop
					rr_scan_idx_v := pop_issue_partition_idx + rr_offset;
					if (rr_scan_idx_v >= N_PARTITIONS) then
						rr_scan_idx_v := rr_scan_idx_v - N_PARTITIONS;
					end if;
					if (pop_partition_pending(rr_scan_idx_v) = '1') then
						next_pending_idx_v	:= rr_scan_idx_v;
						other_pending_v		:= true;
						exit;
					end if;
				end loop;
				-- pop command executor
				case pop_engine_state is 
				-- ============= IDLE ==============
				when IDLE =>
					if ((run_state_cmd = RUNNING or run_state_cmd = TERMINATING) and
						pop_cmd_fifo_empty /= '1') then -- only pop descriptors while the DUT is in an active drain state
						pop_current_sk		<= pop_cmd_fifo_dout; -- latch pop search key for this round, ts[11:4]
						pop_engine_state	<= SEARCH;
						pop_total_hits			<= (others => '0');
						pop_hits_count			<= (others => '0');
						pop_partition_snapshot	<= (others => (others => '0'));
						pop_partition_pending	<= (others => '0');
						pop_count_partition_idx	<= 0;
						pop_count_chunk_idx		<= 0;
						pop_count_total_acc		<= (others => '0');
						pop_count_done			<= '0';
						pop_rr_idx				<= 0;
						pop_load_idx			<= 0;
						pop_issue_valid			<= '0';
					end if;
					-- inter-fsm communication (with run state mgmt)
					if (run_mgmt_flush_memory_start = '1' and run_mgmt_flush_memory_done = '0') then
						pop_engine_state	<= FLUSHING; -- start the sub-routine
					elsif (run_mgmt_flush_memory_start = '1' and run_mgmt_flush_memory_done = '1') then
						-- wait for host to ack
					elsif (run_mgmt_flush_memory_start = '0' and run_mgmt_flush_memory_done = '1') then
						run_mgmt_flush_memory_done		<= '0'; -- ack the host
					end if;
				-- ============= OP POP ==============
				when SEARCH =>	-- pop_current_sk was connected to the read port of cam
					if (to_integer(pop_search_wait_cnt)	< 3) then -- wait until the match fabric has settled before freezing this search snapshot
						pop_search_wait_cnt		<= pop_search_wait_cnt + 1;
					elsif (pop_search_wait_cnt = to_unsigned(3, pop_search_wait_cnt'length)) then -- freeze the snapshot, then hold SEARCH for two settled overlap cycles
						pop_partition_snapshot		<= cam_match_addr_oh_partitioned_comb;
						for i in 0 to N_PARTITIONS-1 loop
							if (or_reduce(cam_match_addr_oh_partitioned_comb(i)) = '1') then
								pop_partition_pending(i) <= '1';
							else
								pop_partition_pending(i) <= '0';
							end if;
						end loop;
						pop_search_wait_cnt			<= to_unsigned(4, pop_search_wait_cnt'length);
					elsif (pop_search_wait_cnt = to_unsigned(4, pop_search_wait_cnt'length)) then
						pop_search_wait_cnt			<= to_unsigned(5, pop_search_wait_cnt'length);
					else -- exit after the settled SEARCH tail
						pop_engine_state			<= LOAD;
						pop_search_wait_cnt			<= (others => '0');
						pop_load_idx				<= 0;
					end if;
				when LOAD =>
						pop_partition_load(pop_load_idx)	<= '1';
						if (pop_load_idx = N_PARTITIONS-1) then
							pop_engine_state			<= COUNT;
								pop_count_partition_idx		<= 0;
								pop_count_chunk_idx			<= 0;
								pop_count_total_acc			<= (others => '0');
								pop_count_done				<= '0';
								pop_rr_idx					<= 0;
						else
							pop_load_idx				<= pop_load_idx + 1;
						end if;
					when COUNT =>
						all_ready_v				:= true;
						for i in 0 to N_PARTITIONS-1 loop
							if (pop_partition_pending(i) = '1' and
								pop_partition_result_valid(i) /= '1') then
								all_ready_v	:= false;
							end if;
						end loop;
						if (pop_count_done /= '1') then
							chunk_vec_v := snapshot_chunk_16(
								pop_partition_snapshot(pop_count_partition_idx),
								pop_count_chunk_idx
							);
							chunk_hits_v := count_ones_16(chunk_vec_v);
							total_hits_v := pop_count_total_acc + to_unsigned(
								chunk_hits_v,
								total_hits_v'length
							);
							pop_count_total_acc <= total_hits_v;
							if (pop_count_chunk_idx = MATCH_COUNT_CHUNKS_CONST-1) then
								pop_count_chunk_idx <= 0;
								if (pop_count_partition_idx = N_PARTITIONS-1) then
									pop_count_done	<= '1';
								else
									pop_count_partition_idx <= pop_count_partition_idx + 1;
								end if;
							else
								pop_count_chunk_idx <= pop_count_chunk_idx + 1;
							end if;
						end if;
						if (pop_count_done = '1' and all_ready_v = true) then
							if (to_integer(pop_count_total_acc) = 0) then
								pop_cmd_fifo_rdack		<= '1';
								pop_engine_state		<= RESET;
							else
								pop_total_hits				<= pop_count_total_acc;
								pop_hits_count				<= pop_count_total_acc;
								pop_pipeline_start			<= '1';
								pop_rr_idx					<= 0;
								pop_issue_valid				<= '0';
								pop_engine_state			<= DRAIN;
							end if;
						end if;
					when DRAIN =>
						if (pop_issue_valid = '1') then
							if (pop_erase_grant = '1') then
								if (pop_partition_has_more(pop_issue_partition_idx) = '1') then
									pop_partition_advance(pop_issue_partition_idx) <= '1';
									pop_partition_pending(pop_issue_partition_idx) <= '1';
								else
									pop_partition_pending(pop_issue_partition_idx) <= '0';
								end if;
								if (pop_hits_count > 0) then
									pop_hits_count			<= pop_hits_count - 1;
								end if;
								if (pop_hits_count = 1) then
									pop_last_hit_pending	<= '1';
									pop_engine_state		<= RESET;
									pop_cmd_fifo_rdack		<= '1';
								elsif (pop_partition_has_more(pop_issue_partition_idx) = '1' and
									other_pending_v = true) then
									pop_rr_idx				<= next_pending_idx_v;
								elsif (pop_partition_has_more(pop_issue_partition_idx) = '0') then
									pop_rr_idx				<= issue_next_rr_idx_v;
								else
									pop_rr_idx				<= pop_issue_partition_idx;
								end if;
								pop_issue_valid			<= '0';
							end if;
						elsif (pop_partition_pending(pop_rr_idx) = '1') then
							-- Wait for the partition encoder to consume the advance pulse and
							-- present a refreshed address before issuing another pop.
							if (pop_partition_advance(pop_rr_idx) = '1' or
								pop_partition_load(pop_rr_idx) = '1') then
								pop_rr_idx				<= pop_rr_idx;
							elsif (pop_partition_result_valid(pop_rr_idx) = '1' and
								pop_partition_flag(pop_rr_idx) = '1') then
								pop_issue_valid			<= '1';
								pop_issue_partition_idx	<= pop_rr_idx;
								pop_issue_addr			<= std_logic_vector(to_unsigned(
									pop_rr_idx * MATCH_PARTITION_SIZE_CONST +
									to_integer(unsigned(pop_partition_addr_lsb(pop_rr_idx))),
									pop_issue_addr'length
								));
							elsif (pop_partition_result_valid(pop_rr_idx) = '0') then
								pop_rr_idx				<= pop_rr_idx;
							else
								pop_partition_pending(pop_rr_idx) <= '0';
								pop_rr_idx				<= next_rr_idx_v;
							end if;
						else
							pop_rr_idx					<= next_rr_idx_v;
						end if;
			
				when RESET =>
					-- reset for this sub-header scope
					pop_partition_snapshot		<= (others => (others => '0'));
					pop_partition_pending		<= (others => '0');
					pop_engine_state			<= IDLE;
					pop_pipeline_start			<= '0';
					pop_hits_count				<= (others => '0');
					pop_total_hits				<= (others => '0');
					pop_count_partition_idx		<= 0;
					pop_count_chunk_idx			<= 0;
					pop_count_total_acc			<= (others => '0');
					pop_count_done				<= '0';
					pop_rr_idx					<= 0;
					pop_load_idx				<= 0;
					pop_issue_valid				<= '0';
					pop_issue_addr				<= (others => '0');
				-- ============= OP FLUSHING ==============
				when FLUSHING =>
					-- flush ram
					if (pop_flush_ram_done = '0' and pop_flush_grant = '1') then -- grant should be true after write erase 
						flush_ram_wraddr			<= flush_ram_wraddr + 1;
					end if;
					if (to_integer(flush_ram_wraddr) = RING_BUFFER_N_ENTRY-1) then 
						pop_flush_ram_done				<= '1';
					end if;
					-- flush cam (2d flush, for each addr line, all data must be looped) 
					if (pop_flush_cam_done = '0' and pop_flush_grant = '1') then 
						if (flush_cam_wrdata = POP_FLUSH_CAM_DATA_MAX) then -- incr addr
							flush_cam_wraddr			<= flush_cam_wraddr + 1;
							if (flush_cam_wraddr = POP_FLUSH_CAM_ADDR_MAX) then -- exit condition
								pop_flush_cam_done			<= '1';
							end if;
						end if;
						flush_cam_wrdata			<= flush_cam_wrdata + 1; -- incr data
					end if;
					if (pop_flush_ram_done = '1' and pop_flush_cam_done = '1') then -- flushing is done, go back to idle
						pop_engine_state			<= FLUSHING_RST;
						run_mgmt_flush_memory_done	<= '1';
					end if;
				when FLUSHING_RST =>
					-- ===============================
					-- reset after flush
					-- flags
					pop_flush_ram_done				<= '0';
					pop_flush_cam_done				<= '0';
					-- pointer 
						-- write_pointer (by push engine)
					-- counters 
						-- push_cnt and erase_cnt (by push engine)
--					debug_msg.pop_cnt			<= (others => '0');
					pop_engine_state			<= IDLE;
					pop_partition_snapshot		<= (others => (others => '0'));
					pop_partition_pending		<= (others => '0');
					pop_total_hits				<= (others => '0');
					pop_count_partition_idx		<= 0;
					pop_count_chunk_idx			<= 0;
					pop_count_total_acc			<= (others => '0');
					pop_count_done				<= '0';
					pop_pipeline_start			<= '0';
					pop_issue_valid				<= '0';
					pop_issue_addr				<= (others => '0');
					flush_ram_wraddr			<= (others => '0');
					flush_cam_wrdata			<= (others => '0');
					flush_cam_wraddr			<= (others => '0');
					
				when others =>
				end case;
			end if;
		end if;
	end process;
	
	
	proc_pop_engine_comb : process (all)
	begin
		-- default
		pop_erase_req			<= '0';
		pop_flush_req			<= '0';
		pop_hit_valid_comb		<= '0';
		cam_cmp_din				<= pop_current_sk(7 downto 0); -- pop search key ts[11:4]
		pop_cam_match_addr		<= (others => '0');
		-- logic
		case pop_engine_state is 
			when DRAIN =>
				if (pop_issue_valid = '1') then
					pop_erase_req		<= '1';
					pop_cam_match_addr	<= pop_issue_addr;
				end if;
				-- if granted, the hit in the next cycle is valid for output (assembly)
				if (pop_erase_grant = '1') then
					pop_hit_valid_comb			<= '1';
				end if;
			when FLUSHING => 
				pop_flush_req		<= '1';
			when others =>
		end case;
		-- transformation cam_match_addr_oh to partitioned slices
		for i in 0 to N_PARTITIONS-1 loop
			cam_match_addr_oh_partitioned_comb(i)	<= cam_match_addr_oh((i+1)*MATCH_PARTITION_SIZE_CONST-1 downto i*MATCH_PARTITION_SIZE_CONST);
		end loop;
		
	end process;
	
	
	
	proc_memory_arbiter_comb : process (all)
	-- Combinational memory arbiter for access contention of cam and side ram from push and pop engine. (priority is demostrated in code)
	-- Note: push write is a later stage than push erase, so push write must be cleared first, otherwise push erase will overflow the push write stage. 
	-- pop_erase and push_write is interleaving. 
	begin
		-- arbiter for cam write
		req			<= (0 => push_write_req, 1 => push_erase_req, 2 => pop_erase_req, 3 => pop_flush_req);
		-- default decision (nothing is granted)
		decision	<= 4; -- idle
		
		if (req(3) = '1') then -- flush should be always ok
			decision		<= 3;
		elsif (req(1) = '1') then -- always grant erase even in pop phase (appear in the first cycle as last push write is just granted)
			decision		<= 1;
		elsif (pop_engine_state = SEARCH) then
			-- Keep the unstable pre-freeze SEARCH window on the same-key-only
			-- rule, then reopen limited cross-key overlap only in the settled
			-- tail when the observed overwrite slot is aligned and its old
			-- resident is provably not part of the frozen pop key set.
			if (req(2) = '1') then
				decision		<= 2;
			elsif (req(0) = '1' and
			       (in_hit_sk = pop_current_sk(7 downto 0) or
			        (pop_search_wait_cnt >= to_unsigned(5, pop_search_wait_cnt'length) and
			         push_write_grant_reg = '0' and
			         not (addr_occupied = '1' and
			              cam_erase_data = pop_current_sk(7 downto 0))))) then
				decision		<= 0;
			end if;
		elsif (pop_engine_state /= IDLE) then -- once DRAIN starts, preserve the frozen pop snapshot until retirement completes
			if (req(2) = '1') then
				decision		<= 2;
			end if;
		elsif (req(0) = '1') then -- grant push write
			decision		<= 0;
		end if;
		
		
		
--		case (decision_reg) is 
--			when 0 => -- last selected is push write, must grant push erase (data dependency)
--			
--				if (req(0) = '1') then
--					decision	<= 0;
--				end if;
--				if (req(2) = '1') then -- refine: pop is ahead of new push
--					decision	<= 2;
--				end if;
--				if (req(3) = '1') then
--					decision	<= 3;
--				end if;
--				if (req(1) = '1') then
--					decision	<= 1;
--				end if;
--			when 1 => -- bang-bang between push erase and pop erase, can grant pop erase
--				if (req(1) = '1') then
--					decision	<= 1;
--				end if;
--				if (req(0) = '1') then
--					decision	<= 0;
--				end if;
--				if (req(2) = '1') then
--					decision	<= 2;
--				end if;
--				if (req(3) = '1') then
--					decision	<= 3;
--				end if;
--			when 2 => -- always grant pop erase (lock), otherwise start write
--				if (req(1) = '1') then
--					decision	<= 1;
--				end if;
--				if (req(0) = '1') then
--					decision	<= 0;
--				end if;
--				if (req(2) = '1') then
--					decision	<= 2;
--				end if;
--				if (req(3) = '1') then
--					decision	<= 3;
--				end if;
--			when 3 => -- flushing has highest priority
--				if (req(1) = '1') then
--					decision	<= 1;
--				end if;
--				if (req(0) = '1') then
--					decision	<= 0;
--				end if;
--				if (req(2) = '1') then
--					decision	<= 2;
--				end if;
--				if (req(3) = '1') then
--					decision	<= 3;
--				end if;
--			when others => -- idle decision, grant flush > pop erase (lock) > start write
--				if (req(1) = '1') then
--					decision	<= 1;
--				end if;
--				if (req(0) = '1') then
--					decision	<= 0;
--				end if;
--				if (req(2) = '1') then
--					decision	<= 2;
--				end if;
--				if (req(3) = '1') then
--					decision	<= 3;
--				end if;
--		end case;
		
		push_write_grant			<= '0';
		push_erase_grant			<= '0';
		pop_erase_grant				<= '0';
		pop_flush_grant				<= '0';
		cam_wr_en					<= '0';
		cam_erase_en				<= '0';
		cam_wr_addr					<= std_logic_vector(write_pointer);
		cam_wr_data					<= in_hit_sk;
		side_ram_we					<= '0';
		side_ram_waddr				<= std_logic_vector(write_pointer);
		side_ram_din				<= '1' & in_hit_side;
		side_ram_raddr				<= std_logic_vector(write_pointer);
		side_ram_dout_valid_comb	<= '0';

		-- mux: grant the access based on the decision of the arbiter 
		case (decision) is 
			when 0 => -- grant push write
				push_write_grant	<= '1';
				-- put main cam into "Write-Mode"
				cam_wr_en		<= '1'; 
				-- write side-ram, of the current side data
				side_ram_we		<= '1';
				-- read side-ram, for occupancy of the next addr, NOTE: RDW must be "old-data"
				side_ram_dout_valid_comb		<= '1';
				
				
			when 1 => -- grant push erase
				push_erase_grant	<= '1';
				-- For same-key overwrites the CAM entry stays valid for the
				-- resident written in the previous cycle. Compare against the
				-- latched just-written key, not the current input beat, because
				-- the burst may end before this erase phase is reached.
				if (cam_erase_data /= push_write_sk_reg) then
					cam_erase_en	<= '1';
				else
					cam_erase_en	<= '0';
				end if;
				cam_wr_addr		<= std_logic_vector(push_erase_addr_reg); -- use the slot captured during push_write instead of recomputing write_pointer-1 here
				cam_wr_data		<= cam_erase_data; -- erase the search key that is occupying this location 
				-- do not write side-ram, since it has been written for new data in push_write
				side_ram_we		<= '0';
				side_ram_waddr	<= (others => '0');
				side_ram_din	<= (others => '0'); -- clear the occupancy flag
				-- read side ram, do nothing 
				side_ram_raddr	<= (others => '0');
				side_ram_dout_valid_comb		<= '0';
				
				
			when 2 =>  -- grant pop erase
				pop_erase_grant		<= '1';
				-- put the main cam into "Erase-Mode"
				cam_erase_en	<= '1';
				cam_wr_addr		<= pop_cam_match_addr; -- erase this consumed hit in cam
				cam_wr_data		<= pop_current_sk(7 downto 0); -- search key for this sub-header -- bug fixed
				-- write side-ram 
				side_ram_we		<= '1';
				side_ram_waddr	<= pop_cam_match_addr; -- erase this consumed hit in side ram
				side_ram_din	<= (others => '0'); -- note: clear the occupancy flag is enough
				-- read side ram (NOTE: RDW must be old-data)
				side_ram_raddr	<= pop_cam_match_addr;
				side_ram_dout_valid_comb		<= '1';
			
			when 3 => -- flushing the cam and ram 
				pop_flush_grant		<= '1';
				-- put main cam into "Erase-Mode"
				cam_erase_en		<= '1';
				cam_wr_addr			<= std_logic_vector(flush_cam_wraddr);
				cam_wr_data			<= std_logic_vector(flush_cam_wrdata);
				-- write side ram with empty
				side_ram_we			<= '1';
				side_ram_waddr		<= std_logic_vector(flush_ram_wraddr);
				side_ram_din		<= (others => '0');
				-- read side ram, do nothing 
				side_ram_raddr	<= (others => '0');
				side_ram_dout_valid_comb		<= '0';
				
			when others => -- idle
				null;
		end case;
	end process;
	
	proc_debug_counter : process (i_clk, i_rst)
	begin
		if (i_rst = '1') then
			debug_msg2.push_cnt         <= (others => '0');
			debug_msg2.overwrite_cnt    <= (others => '0');
			debug_msg2.pop_cnt          <= (others => '0');
			debug_msg2.cache_miss_cnt   <= (others => '0');
	        elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				debug_msg2.push_cnt         <= (others => '0');
				debug_msg2.overwrite_cnt    <= (others => '0');
				debug_msg2.pop_cnt          <= (others => '0');
				debug_msg2.cache_miss_cnt   <= (others => '0');
			else
				case decision_reg is 
					when 0 => -- push write
						debug_msg2.push_cnt			<= debug_msg2.push_cnt + 1;
					when 1 => -- push erase
						debug_msg2.overwrite_cnt	<= debug_msg2.overwrite_cnt + 1;
					when 2 => -- pop erase
						debug_msg2.pop_cnt			<= debug_msg2.pop_cnt + 1;
					when 3 => -- flushing
						if (run_state_cmd = RUN_PREPARE) then
							debug_msg2.push_cnt			<= (others => '0');
							debug_msg2.overwrite_cnt	<= (others => '0');
							debug_msg2.pop_cnt			<= (others => '0');
							debug_msg2.cache_miss_cnt	<= (others => '0');
						end if;
					when others =>
				end case;
				
				if (pop_cache_miss_pulse = '1') then -- cache miss aligned to output beat
					debug_msg2.cache_miss_cnt		<= debug_msg2.cache_miss_cnt + 1;
				end if;
			end if;
		end if;
	
	end process;
	
	proc_memory_arbiter : process (i_clk, i_rst)
	-- reg part of the memory arbiter, simply latch last decision for switching priority
	begin
		if (i_rst = '1') then 
			decision_reg		<= 4; -- reset the arbiter to idle
		elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				decision_reg	<= 4;
			else
				decision_reg	<= decision; -- latch the decision to do bang-bang
			end if;
		end if;
	end process;
	
	
	proc_memory_out_cleanup_comb : process (all)
	-- wire connected to the output port of ram, with derived valid signal. 
	begin
		-- flag signal for push_erase
		addr_occupied		<= side_ram_dout(side_ram_dout'high); 
		-- reg only valid after push_write, for the use in push_erase
		-- Derive the resident search key directly from the current side-ram
		-- read payload. Using an intermediate signal here lags the erase key by
		-- one delta cycle and can erase the previous occupant's CAM entry under
		-- sustained overwrite pressure.
		cam_erase_data		<= side_ram_dout(TCC8N_LO + SK_RANGE_HI downto TCC8N_LO + SK_RANGE_LO);
		-- assemble output hit
		hit_pop_data_comb	<= side_ram_dout(side_ram_dout'high-1 downto 0); -- simply strip the msb to get the hit type 1
	end process;
	
	proc_memory_out_cleanup : process (i_clk, i_rst)
	-- latch the data valid from side ram
	begin
		if (i_rst = '1') then 
			side_ram_dout_valid		<= '0';
		elsif (rising_edge(i_clk)) then -- 
			if (csr.soft_reset = '1') then
				side_ram_dout_valid	<= '0';
			else
				side_ram_dout_valid	<= side_ram_dout_valid_comb;
			end if;
		end if;
	end process;
	
	
	proc_avst_output_assembly : process (i_clk,i_rst)
	-- The streaming output assembly generates hit type 2 data replying on the pop engine state and other scattered data
	-- This assembly also support packetized transmission with sop/eop.
	begin
		if (i_rst = '1') then 
			-- it is handled by pop engine -> RESET
			subheader_gen_done			<= '0';
			pop_hit_valid				<= '0';
			aso_hit_type2_valid			<= '0';
			aso_hit_type2_data			<= (others => '0');
			aso_hit_type2_error(0)		<= '0';
			aso_hit_type2_startofpacket	<= '0';
			aso_hit_type2_endofpacket	<= '0';
			pop_cache_miss_pulse		<= '0';
		elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				pop_hit_valid				<= '0';
				subheader_gen_done			<= '0';
	            aso_hit_type2_error(0)      <= '0';
	            aso_hit_type2_valid			<= '0';
	            aso_hit_type2_data			<= (others => '0');
	            aso_hit_type2_startofpacket	<= '0';
				aso_hit_type2_endofpacket	<= '0';
				pop_cache_miss_pulse		<= '0';
			else
				pop_hit_valid		<= pop_hit_valid_comb; -- latched so, high in the cycle after DRAIN, come together with the cam/ram's q
				
	            -- 0) default 
	            aso_hit_type2_error(0)              <= '0';
	            aso_hit_type2_valid			        <= '0';
	            aso_hit_type2_data			        <= (others => '0');
	            aso_hit_type2_startofpacket	        <= '0';
				aso_hit_type2_endofpacket	        <= '0';
				pop_cache_miss_pulse		        <= '0';
	            -- 1) generate sub header (w/ sop or sop+eop)
				if ((pop_pipeline_start = '1' or pop_cmd_fifo_rdack = '1') and subheader_gen_done = '0') then 
	                -- 1) generate only one sub-header at the start of DRAIN or 2) generate sub-header for empty subframe
					-- Streaming
					aso_hit_type2_valid		<= '1';
					-- assemble sub-header
					aso_hit_type2_data(35 downto 32)	<= "0001"; -- byte is k
					aso_hit_type2_data(31 downto 24)	<= pop_current_sk(7 downto 0); -- this is ts[11:4] in the scope of this subheader
					aso_hit_type2_data(23 downto 16)	<= (others => '0'); -- free space, TBD
					aso_hit_type2_data(15 downto 8)		<= std_logic_vector(pop_total_hits(7 downto 0));
					aso_hit_type2_data(7 downto 0)		<= K237; -- identifier for sub-header (ref: specbook)
					-- misc.
					subheader_gen_done 					<= '1'; -- marks sop to avoid repetitive generation 
					-- channel 
					aso_hit_type2_channel				<= std_logic_vector(to_unsigned(INTERLEAVING_INDEX,aso_hit_type2_channel'length));
					-- packet
					aso_hit_type2_startofpacket			<= '1';
					if (to_integer(pop_total_hits) = 0) then -- gen eop for no hit scenario, or last hit
						aso_hit_type2_endofpacket			<= '1';
					end if;
	            -- 2) generate hits (w/ eop)
				elsif (pop_pipeline_start = '1' and subheader_gen_done = '1') then -- after DRAIN starts, hits should be available
					if (pop_hit_valid = '1') then -- pop_hit_valid is already aligned to the prior-cycle pop_erase grant
						-- Streaming
						aso_hit_type2_valid		<= '1';
						-- assemble hit type 2
						aso_hit_type2_data(35 downto 32)	<= (others => '0'); -- byte is k
						aso_hit_type2_data(31 downto 28)	<= hit_pop_data_comb(TCC8N_LO+3 downto TCC8N_LO); -- ts[3:0], check ts[12] below
						aso_hit_type2_data(27 downto 22)	<= "00" & hit_pop_data_comb(ASIC_HI downto ASIC_LO);
						aso_hit_type2_data(21 downto 17)	<= hit_pop_data_comb(CHANNEL_HI downto CHANNEL_LO);
						aso_hit_type2_data(16 downto 9)		<= hit_pop_data_comb(TCC1n6_HI downto TFINE_LO); -- tcc1.6(1.6ns) & tfine(50ps) = ts50p
						aso_hit_type2_data(8 downto 0)		<= hit_pop_data_comb(ET1n6_HI downto ET1n6_LO);
						-- channel
						aso_hit_type2_channel				<= std_logic_vector(to_unsigned(INTERLEAVING_INDEX,aso_hit_type2_channel'length)); -- re-assemble the channel
							-- equivalent alternative: hit_pop_data_comb(ASIC_HI downto ASIC_LO); 
						-- packet 
						if (pop_last_hit_pending = '1') then -- gen eop for last hit 
							aso_hit_type2_endofpacket			<= '1';
						end if;
	                    -- error {tsglitcherr}
	                    if (hit_pop_data_comb(TCC8N_LO+12) /= pop_current_sk(8)) then -- ts[12] from ram matches ts[12] from search key
	                        aso_hit_type2_error(0)              <= '1';
	                    end if;
						if (side_ram_dout(side_ram_dout'high) = '0') then
							pop_cache_miss_pulse		<= '1';
						end if;
					end if;
				elsif (pop_pipeline_start = '0') then 
					subheader_gen_done			<= '0';
				end if;
			end if;
	
		end if;
	end process;
	
	
	
	
	
	proc_fill_level_meter : process (i_clk,i_rst)
	-- fill level meter tracks the number of hits on the stack.
	-- the meter derive this by precisely counting the push and pop hits and over write.
	-- the dbg registers are always true, while the csr registers are inferred from it and can be sclr'd.
	-- 
	begin
		if (i_rst = '1') then 
--			ow_cnt_tmp					<= (others => '0');
		elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				debug_msg2.cam_clean				<= '1';
			else
			-- sclr the csr overwrite_cnt
--			if (csr.overwrite_cnt_rst = '1' and csr.overwrite_cnt_rst_done = '0') then -- latch the current value
--				ow_cnt_tmp					<= debug_msg2.overwrite_cnt(31 downto 0);
--				csr.overwrite_cnt_rst_done	<= '1';
--			elsif (csr.overwrite_cnt_rst = '1' and csr.overwrite_cnt_rst_done = '1') then
--				-- idle
--				ow_cnt_tmp					<= ow_cnt_tmp;
--			elsif (csr.overwrite_cnt_rst = '0' and csr.overwrite_cnt_rst_done = '1') then -- ack the host
--				csr.overwrite_cnt_rst_done	<= '0';
--			else
--				ow_cnt_tmp					<= ow_cnt_tmp;
--			end if;
			-- cam empty flag
			if (debug_msg2.push_cnt = to_unsigned(0, debug_msg2.push_cnt'length) and
				debug_msg2.pop_cnt = to_unsigned(0, debug_msg2.pop_cnt'length) and
				debug_msg2.overwrite_cnt = to_unsigned(0, debug_msg2.overwrite_cnt'length)) then -- very clean, no underflow
				debug_msg2.cam_clean				<= '1';
			else 
				debug_msg2.cam_clean				<= '0';
			end if;
			end if;
		end if;
	end process;
	
	terminating_drain_done <= '1' when (
		endofrun_seen = '1' and
		deassembly_fifo_empty = '1' and
		pop_cmd_fifo_empty = '1' and
		pop_engine_state = IDLE and
		debug_msg2.push_cnt = (debug_msg2.pop_cnt + debug_msg2.overwrite_cnt)
	) else '0';

	proc_run_control_mgmt : process (i_clk,i_rst)
	-- In mu3e run control system, each feb has a run control management host which runs in reset clock domain, while other IPs must feature
	-- run control management agent which listens the run state command to capture the transition.
	-- The state transition are only ack by the agent for as little as 1 cycle, but the host must assert the valid until all ack by the agents are received,
	-- during transitioning period. 
	-- The host should record the timestamps (clock cycle and phase) difference between the run command signal is received by its lvds_rx and 
	-- agents' ready signal. This should ensure all agents are running at the same time, despite there is phase uncertainty between the clocks, which 
	-- might results in 1 clock cycle difference and should be compensated offline. 
		variable run_state_cmd_next_v : run_state_t;
	begin 
		if (i_rst = '1') then 
			run_mgmt_flush_memory_start			<= '0';
			run_mgmt_flushed					<= '0';
			run_state_cmd						<= IDLE;
		elsif (rising_edge(i_clk)) then 
			if (csr.soft_reset = '1') then
				run_mgmt_flush_memory_start	<= '0';
				run_mgmt_flushed			<= '0';
				run_state_cmd				<= IDLE;
				gts_end_of_run				<= (others => '0');
				endofrun_seen				<= '0';
				pop_cmd_fifo_sclr			<= '1';
				deassembly_fifo_sclr		<= '1';
				gts_counter_rst				<= '1';
				asi_ctrl_ready				<= '0';
			else
				run_state_cmd_next_v := run_state_cmd;
				if (asi_ctrl_valid = '1') then 
					-- payload of run control to run cmd
					case asi_ctrl_data is 
						when "000000001" =>
							run_state_cmd_next_v := IDLE;
						when "000000010" => 
							run_state_cmd_next_v := RUN_PREPARE;
						when "000000100" =>
							run_state_cmd_next_v := SYNC;
						when "000001000" =>
							run_state_cmd_next_v := RUNNING;
						when "000010000" =>
							run_state_cmd_next_v := TERMINATING;
						when "000100000" => 
							run_state_cmd_next_v := LINK_TEST;
						when "001000000" =>
							run_state_cmd_next_v := SYNC_TEST;
						when "010000000" =>
							run_state_cmd_next_v := RESET;
						when "100000000" =>
							run_state_cmd_next_v := OUT_OF_DAQ;
						when others =>
							run_state_cmd_next_v := ERROR;
					end case;
				end if;
				run_state_cmd <= run_state_cmd_next_v;
				
				-- register the global timestamp when transition to TERMINATING
				if (run_state_cmd /= TERMINATING and run_state_cmd_next_v = TERMINATING) then 
					gts_end_of_run	<= gts_8n;
				else
					gts_end_of_run	<= gts_end_of_run;
				end if;
				
				-- packet support (hit type 1: mu3e run)
				if (asi_hit_type1_valid = '1' and asi_hit_type1_endofpacket = '1') then 
	                if (asi_hit_type1_empty = '1') then
	                    if (to_integer(unsigned(asi_hit_type1_channel(1 downto 0))) = INTERLEAVING_INDEX) then
						endofrun_seen 		<= '1';
	                    end if;
	                elsif (to_integer(unsigned(asi_hit_type1_data(TCC8N_INTERLEAVING_HI downto TCC8N_INTERLEAVING_LO))) = INTERLEAVING_INDEX) then
					endofrun_seen 		<= '1';
	                end if;
				elsif (run_state_cmd_next_v = IDLE or run_state_cmd_next_v = RUN_PREPARE) then -- reset it here
					endofrun_seen		<= '0';
				end if;
				
				pop_cmd_fifo_sclr			<= '0';
				deassembly_fifo_sclr		<= '0';
				gts_counter_rst				<= '0';
				asi_ctrl_ready				<= '0';
				
				-- mgmt main state machine
				case run_state_cmd_next_v is 
					when IDLE => -- this is the default state, after cmd=stop reset, you should end up here.
						run_mgmt_flush_memory_start	<= '0';
						run_mgmt_flushed			<= '0';
						if (asi_ctrl_valid = '1') then 
							asi_ctrl_ready			<= '1';
						else
							asi_ctrl_ready			<= '0';
						end if;
					when RUN_PREPARE =>
						-- flush the fifo
						pop_cmd_fifo_sclr		<= '1';
						deassembly_fifo_sclr	<= '1';
						-- Keep the flush request asserted until the pop engine reports
						-- completion. Then latch the flushed state so PREP ready stays
						-- visible even if cam_clean lags by a cycle.
						if (run_mgmt_flushed = '0') then
							if (run_mgmt_flush_memory_start = '0') then
								run_mgmt_flush_memory_start	<= '1';
							elsif (run_mgmt_flush_memory_done = '1') then
								run_mgmt_flush_memory_start	<= '0';
								run_mgmt_flushed			<= '1';
							end if;
						else
							run_mgmt_flush_memory_start	<= '0';
						end if;
						-- ack the run state 
						if (pop_cmd_fifo_empty = '1' and deassembly_fifo_empty = '1' and debug_msg2.cam_clean = '1' and run_mgmt_flushed = '1') then 
							asi_ctrl_ready			<= '1';
						else
							asi_ctrl_ready			<= '0';
						end if;
						-- counters were reset by pop engine
					when SYNC => 
						run_mgmt_flush_memory_start	<= '0';
						gts_counter_rst			<= '1';
						if (asi_ctrl_valid = '1') then -- ack the host immediately 
							asi_ctrl_ready			<= '1';
						else
							asi_ctrl_ready			<= '0';
						end if;
					when RUNNING =>
						-- release the reset and sclr
						run_mgmt_flush_memory_start	<= '0';
						gts_counter_rst			<= '0';
						pop_cmd_fifo_sclr		<= '0';
						deassembly_fifo_sclr	<= '0';
						if (asi_ctrl_valid = '1') then -- ack the host immediately 
							asi_ctrl_ready			<= '1';
						else
							asi_ctrl_ready			<= '0';
						end if;
						run_mgmt_flushed		<= '0'; -- unset this flag so flush must be once
					when TERMINATING => 
						run_mgmt_flush_memory_start	<= '0';
						if (terminating_drain_done = '1') then
							asi_ctrl_ready			<= '1';
						else
							asi_ctrl_ready			<= '0';
						end if;
						run_mgmt_flushed		<= '0'; -- unset this flag so flush must be once
	                when RESET => 
	                    run_mgmt_flush_memory_start <= '0';
	                    -- this is similar to flush everything, TODO: add also register clear here
	                    asi_ctrl_ready          <= '1'; -- for now just ack it. otherwise the swb can be stuck.
	                    
					when others =>
						run_mgmt_flush_memory_start	<= '0';
						pop_cmd_fifo_sclr		<= '0';
						deassembly_fifo_sclr	<= '0';
						asi_ctrl_ready			<= '0'; -- not supported yet
						run_mgmt_flushed		<= '0'; -- unset this flag so flush must be once
				end case;
			end if;
		end if;
		
	end process;
	
	-- /////////////////////////////////////////////
    -- @name            fillness interface
    --
    -- /////////////////////////////////////////////
    proc_filllevel_interface : process (i_clk)
    begin
        if rising_edge(i_clk) then 
            -- default
            aso_filllevel_valid         <= '0'; 
            -- main logic
            aso_filllevel_data          <= csr.fill_level(15 downto 0);
            if (i_rst = '0') then
                aso_filllevel_valid         <= '1';
            end if;
        
        end if;
    
    end process;
    
    
    



end architecture rtl;
