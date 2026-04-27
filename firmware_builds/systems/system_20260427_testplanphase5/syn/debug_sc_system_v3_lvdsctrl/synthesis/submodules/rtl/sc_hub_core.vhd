-- File name: sc_hub_core.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.6.11
-- Date    : 20260421
-- Change  : Latch the current packet's internal/external classification in
--           DISPATCH_CAPTURING and reuse that registered bit in the decode and
--           write-drain paths so start_address no longer fans into the
--           ext_pkt_write_count / INT_WR_DRAINING timing cones.
-- Version : 26.6.10
-- Date    : 20260415
-- Change  : Stage the core soft-reset clears through a dedicated CORE_RESETTING
--           FSM state walked by a 4-bucket counter. The previous in-place
--           ~70-register clear in one cycle let Quartus merge the synchronous
--           clear (|sclr) enable cone with the FSM combinational variables
--           (response_reg_v, drain_remaining, ext_pkt_write_count, ...) and
--           pulled a 6-LUT-deep cone through last_ext_read_data[*]|sclr,
--           failing setup at Slow 85C / Slow 0C. The new flow transitions to
--           CORE_RESETTING, walks core_reset_bucket = 0..3, and clears one
--           bucket per cycle. Each register's |sclr enable is now a small
--           compare on registered state ({core_state, core_reset_bucket}),
--           breaking the cone by construction.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_core is
    generic(
        DEBUG_G                    : natural := 1;
        OOO_ENABLE_G               : boolean := false;
        ORD_ENABLE_G               : boolean := true;
        ATOMIC_ENABLE_G            : boolean := true;
        HUB_CAP_ENABLE_G           : boolean := true;
        BP_FIFO_DEPTH_G            : positive := DEFAULT_BP_FIFO_DEPTH_CONST;
        OUTSTANDING_LIMIT_G        : positive := 8;
        OUTSTANDING_INT_RESERVED_G : natural := 2;
        -- Identity generics (standard CSR header at words 0-1)
        IP_UID_G                   : natural := 16#53434842#; -- ASCII "SCHB"
        VERSION_MAJOR_G            : natural := 26;
        VERSION_MINOR_G            : natural := 6;
        VERSION_PATCH_G            : natural := 11;
        BUILD_G                    : natural := 16#0415#;
        VERSION_DATE_G             : natural := 16#20260415#;
        VERSION_GIT_G              : natural := 0;
        INSTANCE_ID_G              : natural := 0
    );
    port(
        i_clk                    : in  std_logic;
        i_rst                    : in  std_logic;
        i_pkt_valid              : in  std_logic;
        i_pkt_info               : in  sc_pkt_info_t;
        i_pkt_is_internal        : in  std_logic;
        o_rx_ready               : out std_logic;
        o_soft_reset_pulse       : out std_logic;
        o_wr_data_rdreq          : out std_logic;
        i_wr_data_q              : in  std_logic_vector(31 downto 0);
        i_wr_data_empty          : in  std_logic;
        i_pkt_drop_count         : in  std_logic_vector(15 downto 0);
        i_pkt_drop_pulse         : in  std_logic;
        i_debug_drop_detail      : in  std_logic_vector(31 downto 0) := (others => '0');
        i_dl_fifo_usedw          : in  std_logic_vector(9 downto 0);
        i_dl_fifo_full           : in  std_logic;
        i_dl_fifo_overflow       : in  std_logic;
        i_dl_fifo_overflow_pulse : in  std_logic;
        i_bp_usedw               : in  std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH_G + 1) - 1 downto 0);
        i_bp_full                : in  std_logic;
        i_bp_overflow            : in  std_logic;
        i_bp_overflow_pulse      : in  std_logic;
        i_bp_pkt_count           : in  std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH_G + 1) - 1 downto 0);
        o_tx_reply_start         : out std_logic;
        o_tx_reply_info          : out sc_pkt_info_t;
        o_tx_reply_response      : out std_logic_vector(1 downto 0);
        o_tx_reply_has_data      : out std_logic;
        o_tx_reply_suppress      : out std_logic;
        i_tx_reply_ready         : in  std_logic;
        i_tx_reply_done          : in  std_logic;
        o_tx_data_valid          : out std_logic;
        o_tx_data_word           : out std_logic_vector(31 downto 0);
        i_tx_data_ready          : in  std_logic;
        o_bus_cmd_valid          : out std_logic;
        o_bus_cmd_is_read        : out std_logic;
        o_bus_cmd_nonincrement   : out std_logic;
        o_bus_cmd_address        : out std_logic_vector(17 downto 0);
        o_bus_cmd_length         : out std_logic_vector(15 downto 0);
        i_bus_cmd_ready          : in  std_logic;
        o_bus_wr_data_valid      : out std_logic;
        o_bus_wr_data            : out std_logic_vector(31 downto 0);
        i_bus_wr_data_ready      : in  std_logic;
        i_bus_wr_accept_pulse    : in  std_logic;
        i_bus_wr_accept_address  : in  std_logic_vector(17 downto 0);
        i_bus_wr_accept_data     : in  std_logic_vector(31 downto 0);
        i_bus_rd_data_valid      : in  std_logic;
        i_bus_rd_data            : in  std_logic_vector(31 downto 0);
        i_bus_done               : in  std_logic;
        i_bus_response           : in  std_logic_vector(1 downto 0);
        i_bus_busy               : in  std_logic;
        i_bus_timeout_pulse      : in  std_logic;
        avs_csr_address          : in  std_logic_vector(ceil_log2_func(HUB_CSR_WINDOW_WORDS_CONST) - 1 downto 0);
        avs_csr_read             : in  std_logic;
        avs_csr_write            : in  std_logic;
        avs_csr_writedata        : in  std_logic_vector(31 downto 0);
        avs_csr_readdata         : out std_logic_vector(31 downto 0);
        avs_csr_readdatavalid    : out std_logic;
        avs_csr_waitrequest      : out std_logic
    );
end entity sc_hub_core;

architecture rtl of sc_hub_core is
    type core_state_t is (
        IDLING,
        DISPATCH_CAPTURING,
        DISPATCH_DECODING,
        INT_RD_OFFSETING,
        INT_RD_FILLING,
        INT_RD_PUSHING,
        EXT_RD_RUNNING,
        ATOMIC_EXT_RD_RUNNING,
        ATOMIC_EXT_WR_ARMING,
        ATOMIC_EXT_WR_RUNNING,
        RD_PADDING,
        RD_REPLY_PREP,
        RD_REPLY_ARMING,
        RD_REPLY_STREAMING,
        INT_WR_DRAINING,
        EXT_WR_ARMING,
        EXT_WR_RUNNING,
        WR_REPLY_ARMING,
        WAITING_REPLY,
        -- Multi-cycle soft-reset: a 4-bucket counter walks the staged clears so
        -- the |sclr enable on every cleared register is a small compare on the
        -- registered {core_state, core_reset_bucket} pair, never a process
        -- combinational cone. See CLAUDE.md "Staged Reset Trick".
        CORE_RESETTING
    );
    subtype pending_queue_index_t is natural range 0 to OUTSTANDING_LIMIT_G - 1;
    type pending_pkt_mem_t is array (pending_queue_index_t) of sc_pkt_info_t;

    signal core_state                : core_state_t := IDLING;
    -- Bucket walker for CORE_RESETTING. 2 bits = 4 staged clear cycles. The
    -- |sclr enable for every register cleared inside CORE_RESETTING is a tiny
    -- compare on (core_state = CORE_RESETTING and core_reset_bucket = N), so
    -- Quartus cannot fold the FSM combinational cone into the clear net.
    signal core_reset_bucket         : unsigned(1 downto 0) := (others => '0');
    signal pkt_info_reg              : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal pkt_is_internal_reg       : std_logic := '0';
    signal reply_suppress_reg        : std_logic := '0';
    signal pkt_ignore_reg            : std_logic := '0';
    signal reply_has_data_reg        : std_logic := '0';
    signal reply_is_internal_reg     : std_logic := '0';
    signal response_reg              : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal hub_enable                : std_logic := '1';
    signal meta_page_sel             : std_logic_vector(1 downto 0) := "00";
    signal hub_scratch               : std_logic_vector(31 downto 0) := (others => '0');
    signal hub_err_flags             : std_logic_vector(31 downto 0) := (others => '0');
    signal hub_err_count             : unsigned(31 downto 0) := (others => '0');
    signal hub_gts_counter           : unsigned(47 downto 0) := (others => '0');
    signal hub_gts_snapshot          : unsigned(47 downto 0) := (others => '0');
    signal hub_upload_store_forward  : std_logic := '1';
    signal local_feb_type            : std_logic_vector(1 downto 0) := HUB_FEB_TYPE_ALL_CONST;
    signal ooo_ctrl_enable           : std_logic := '0';
    signal ord_drain_count           : unsigned(31 downto 0) := (others => '0');
    signal ord_hold_count            : unsigned(31 downto 0) := (others => '0');
    signal ext_pkt_read_count        : unsigned(31 downto 0) := (others => '0');
    signal ext_pkt_write_count       : unsigned(31 downto 0) := (others => '0');
    signal ext_word_read_count       : unsigned(31 downto 0) := (others => '0');
    signal ext_word_write_count      : unsigned(31 downto 0) := (others => '0');
    signal last_ext_read_addr        : std_logic_vector(31 downto 0) := (others => '0');
    signal last_ext_read_data        : std_logic_vector(31 downto 0) := (others => '0');
    -- Pipeline shadow: break the deep combinational enable cone that fans out to
    -- last_ext_read_data[*]|ena. Captured value is 1 cycle delayed; CSR readback
    -- via AVMM tolerates the shift trivially.
    signal last_ext_read_data_capture : std_logic := '0';
    signal i_bus_rd_data_r            : std_logic_vector(31 downto 0) := (others => '0');
    -- Dedicated clear pulse from the main FSM. Drives a dedicated
    -- last_ext_read_data_proc process so the register's |sclr enable is a
    -- single-flop compare instead of the merged FSM cone that pulled
    -- drain_remaining[6] through a 6-LUT path at Slow-85C setup.
    signal last_ext_read_data_clear_pulse : std_logic := '0';
    signal last_ext_write_addr       : std_logic_vector(31 downto 0) := (others => '0');
    signal last_ext_write_data       : std_logic_vector(31 downto 0) := (others => '0');
    signal read_fill_index           : unsigned(15 downto 0) := (others => '0');
    signal int_rd_last_fill_q        : std_logic := '0';
    signal reply_stream_index        : unsigned(15 downto 0) := (others => '0');
    signal reply_words_remaining     : unsigned(15 downto 0) := (others => '0');
    signal reply_arm_pending         : std_logic := '0';
    signal reply_arm_use_fifo_usedw  : std_logic := '0';
    signal write_stream_index        : unsigned(15 downto 0) := (others => '0');
    signal drain_remaining           : unsigned(15 downto 0) := (others => '0');
    signal atomic_read_data_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal atomic_write_data_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal deferred_atomic_pending   : std_logic := '0';
    signal deferred_atomic_pkt_info  : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal deferred_atomic_response  : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal deferred_atomic_has_data  : std_logic := '0';
    signal deferred_atomic_suppress  : std_logic := '0';
    signal deferred_atomic_data_word : std_logic_vector(31 downto 0) := (others => '0');
    signal bus_cmd_issued            : std_logic := '0';
    signal rd_fifo_clear             : std_logic := '0';
    signal rd_fifo_write_en          : std_logic := '0';
    signal rd_fifo_write_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal int_read_offset_reg       : unsigned(15 downto 0) := (others => '0');
    signal int_read_word_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal rd_fifo_read_en           : std_logic := '0';
    signal rd_fifo_q                 : std_logic_vector(31 downto 0);
    signal rd_fifo_empty             : std_logic;
    signal rd_fifo_full              : std_logic;
    signal rd_fifo_usedw             : std_logic_vector(8 downto 0);
    signal tx_reply_start_pulse      : std_logic := '0';
    signal soft_reset_pulse          : std_logic := '0';
    signal bus_cmd_valid_pulse       : std_logic := '0';
    signal bus_cmd_is_read_reg       : std_logic := '0';
    signal bus_cmd_nonincrement_reg  : std_logic := '0';
    signal bus_cmd_address_reg       : std_logic_vector(17 downto 0) := (others => '0');
    signal bus_cmd_length_reg        : std_logic_vector(15 downto 0) := (others => '0');
    signal pending_pkt_mem           : pending_pkt_mem_t := (others => SC_PKT_INFO_RESET_CONST);
    signal pending_pkt_rd_ptr        : pending_queue_index_t := 0;
    signal pending_pkt_wr_ptr        : pending_queue_index_t := 0;
    signal pending_pkt_count         : natural range 0 to OUTSTANDING_LIMIT_G := 0;
    signal pending_ext_count         : natural range 0 to OUTSTANDING_LIMIT_G := 0;
    signal active_pkt_slots          : natural range 0 to 1 := 0;
    signal active_ext_slots          : natural range 0 to 1 := 0;
    signal tracked_pkt_count         : natural range 0 to OUTSTANDING_LIMIT_G + 1 := 0;
    signal tracked_ext_count         : natural range 0 to OUTSTANDING_LIMIT_G + 1 := 0;
    signal barrier_guard_counter     : natural range 0 to 15 := 0;
    signal wr_data_valid_reg         : std_logic := '0';
    signal wr_data_word_reg          : std_logic_vector(31 downto 0) := (others => '0');
    signal wr_data_reload_pending    : std_logic := '0';
    signal dispatch_pkt_reg          : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal dispatch_queue_idx_reg    : pending_queue_index_t := 0;
    signal err_count_pulse_q         : std_logic := '0';
    signal tx_reply_ready_q          : std_logic := '0';
    signal soft_reset_pending        : std_logic := '0';
    signal avs_csr_readdata_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal avs_csr_readdatavalid_reg : std_logic := '0';
    signal avs_csr_write_ready       : std_logic := '0';
    signal ext_write_diag_pending    : std_logic := '0';
    signal ext_write_diag_addr_hold  : std_logic_vector(31 downto 0) := (others => '0');
    signal ext_write_diag_data_hold  : std_logic_vector(31 downto 0) := (others => '0');
    signal ext_write_diag_clear_pulse : std_logic := '0';

    -- Pre-computed dispatch eligibility flags (registered, 1-cycle lookahead)
    signal bp_usedw_q              : std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH_G + 1) - 1 downto 0) := (others => '0');
    signal slot_is_internal_q      : std_logic_vector(OUTSTANDING_LIMIT_G - 1 downto 0) := (others => '0');
    signal slot_credit_ok_q        : std_logic_vector(OUTSTANDING_LIMIT_G - 1 downto 0) := (others => '0');
    signal slot_prefer_relaxed_q   : std_logic_vector(OUTSTANDING_LIMIT_G - 1 downto 0) := (others => '0');
    signal slot_domain_blocked_q   : std_logic_vector(OUTSTANDING_LIMIT_G - 1 downto 0) := (others => '0');
    signal slot_count_valid_q      : std_logic_vector(OUTSTANDING_LIMIT_G - 1 downto 0) := (others => '0');
    -- Stage 1 pipeline registers for core_fsm signals used in Stage 2
    signal hub_enable_s1_q         : std_logic := '1';
    signal deferred_atomic_s1_q    : std_logic := '0';
    -- Stage 2: pre-computed dispatch winner (from registered per-slot flags)
    signal dispatch_winner_valid_q : std_logic := '0';
    signal dispatch_winner_idx_q   : pending_queue_index_t := 0;
    -- Pre-registered packet-length-is-one flag (set in DISPATCH_CAPTURING,
    -- removes the rw_length comparison from INT_WR_DRAINING critical path)
    signal pkt_len_is_one_q        : std_logic := '0';
    -- Pre-registered CSR write offset (set in DISPATCH_DECODING, removes
    -- the start_address subtraction from the INT_WR_DRAINING critical path
    -- that was violating timing to ext_word_read_count)
    signal pkt_csr_write_offset_q  : natural range 0 to HUB_CSR_WINDOW_WORDS_CONST - 1 := 0;

    function pkt_length_func (
        pkt_info : sc_pkt_info_t
    ) return unsigned is
    begin
        return unsigned(pkt_info.rw_length);
    end function pkt_length_func;

    function internal_hit_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
        variable addr_v : natural;
    begin
        addr_v := to_integer(unsigned(pkt_info.start_address(15 downto 0)));
        return (addr_v >= HUB_CSR_BASE_ADDR_CONST and addr_v < HUB_CSR_BASE_ADDR_CONST + HUB_CSR_WINDOW_WORDS_CONST);
    end function internal_hit_func;

    function pkt_is_internal_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
    begin
        for idx in 15 downto 0 loop
            if (pkt_info.start_address(idx) /= '0' and pkt_info.start_address(idx) /= '1') then
                return false;
            end if;
        end loop;
        return internal_hit_func(pkt_info);
    end function pkt_is_internal_func;

    function next_pending_index_func (
        value_in : pending_queue_index_t
    ) return pending_queue_index_t is
    begin
        if (value_in = OUTSTANDING_LIMIT_G - 1) then
            return 0;
        else
            return value_in + 1;
        end if;
    end function next_pending_index_func;

    function ext_track_limit_func (
        outstanding_limit_in : positive;
        int_reserved_in      : natural
    ) return natural is
    begin
        if (int_reserved_in >= outstanding_limit_in) then
            return 0;
        else
            return outstanding_limit_in - int_reserved_in;
        end if;
    end function ext_track_limit_func;

    function pkt_requires_reply_payload_credit_func (
        pkt_info       : sc_pkt_info_t;
        local_feb_type_in : std_logic_vector(1 downto 0)
    ) return boolean is
    begin
        return (
            pkt_is_internal_func(pkt_info) = false and
            pkt_locally_masked_func(pkt_info, local_feb_type_in) = false and
            pkt_reply_suppressed_func(pkt_info) = false and
            to_integer(unsigned(pkt_info.rw_length)) /= 0 and
            (pkt_is_read_func(pkt_info) or pkt_is_atomic_func(pkt_info))
        );
    end function pkt_requires_reply_payload_credit_func;

    function reply_payload_credit_ready_func (
        pkt_info           : sc_pkt_info_t;
        local_feb_type_in  : std_logic_vector(1 downto 0);
        bp_usedw           : std_logic_vector
    ) return boolean is
    begin
        if (pkt_requires_reply_payload_credit_func(pkt_info, local_feb_type_in) = false) then
            return true;
        else
            return (to_integer(unsigned(bp_usedw)) + to_integer(unsigned(pkt_info.rw_length)) <= BP_FIFO_DEPTH_G);
        end if;
    end function reply_payload_credit_ready_func;

begin
    -- Registered active-slot counters: breaks the combinational feedback
    -- pkt_info_reg -> pkt_is_internal_reg -> active_ext_slots -> o_rx_ready
    -- -> core_fsm -> pkt_info_reg. One-cycle latency on backpressure is
    -- acceptable for slow-control traffic.
    active_slots_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                active_pkt_slots <= 0;
                active_ext_slots <= 0;
            else
                if (core_state = IDLING and deferred_atomic_pending = '0') then
                    active_pkt_slots <= 0;
                else
                    active_pkt_slots <= 1;
                end if;
                if (
                    (core_state /= IDLING and pkt_is_internal_reg = '0') or
                    (
                        core_state = IDLING and
                        deferred_atomic_pending = '1'
                    )
                ) then
                    active_ext_slots <= 1;
                else
                    active_ext_slots <= 0;
                end if;
            end if;
        end if;
    end process active_slots_reg;
    tracked_pkt_count <= pending_pkt_count + active_pkt_slots;
    tracked_ext_count <= pending_ext_count + active_ext_slots;

    rd_fifo_inst : entity work.sc_hub_fifo_sc
    generic map(
        WIDTH_G => 32,
        DEPTH_G => MAX_BURST_WORDS_CONST
    )
    port map(
        csi_clk    => i_clk,
        rsi_reset  => i_rst,
        clear      => rd_fifo_clear,
        write_en   => rd_fifo_write_en,
        write_data => rd_fifo_write_data,
        read_en    => rd_fifo_read_en,
        read_data  => rd_fifo_q,
        empty      => rd_fifo_empty,
        full       => rd_fifo_full,
        usedw      => rd_fifo_usedw
    );

    -- Stage 1: Pre-compute per-slot dispatch eligibility flags.
    -- Moves the expensive credit-check addition/comparison and address-range
    -- decode out of the IDLING dispatch critical path.
    dispatch_precomp_s1 : process(i_clk)
        variable domain_hit_v : boolean;
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                bp_usedw_q            <= (others => '0');
                slot_count_valid_q    <= (others => '0');
                slot_is_internal_q    <= (others => '0');
                slot_credit_ok_q      <= (others => '0');
                slot_prefer_relaxed_q <= (others => '0');
                slot_domain_blocked_q <= (others => '0');
                hub_enable_s1_q       <= '1';
                deferred_atomic_s1_q  <= '0';
            else
                bp_usedw_q           <= i_bp_usedw;
                hub_enable_s1_q      <= hub_enable;
                deferred_atomic_s1_q <= deferred_atomic_pending;
                for i in 0 to OUTSTANDING_LIMIT_G - 1 loop
                    -- Slot validity mask (pre-computes the count comparison
                    -- so Stage 2 never reads pending_pkt_count directly)
                    if (i < pending_pkt_count) then
                        slot_count_valid_q(i) <= '1';
                    else
                        slot_count_valid_q(i) <= '0';
                    end if;
                    if (pkt_is_internal_func(pending_pkt_mem(i))) then
                        slot_is_internal_q(i) <= '1';
                    else
                        slot_is_internal_q(i) <= '0';
                    end if;
                    if (reply_payload_credit_ready_func(pending_pkt_mem(i), local_feb_type, bp_usedw_q)) then
                        slot_credit_ok_q(i) <= '1';
                    else
                        slot_credit_ok_q(i) <= '0';
                    end if;
                    if (pkt_is_internal_func(pending_pkt_mem(i)) or
                        pending_pkt_mem(i).order_mode = SC_ORDER_RELAXED_CONST) then
                        slot_prefer_relaxed_q(i) <= '1';
                    else
                        slot_prefer_relaxed_q(i) <= '0';
                    end if;
                    domain_hit_v := false;
                    for j in 0 to OUTSTANDING_LIMIT_G - 1 loop
                        if (j < i and j < pending_pkt_count and i < pending_pkt_count) then
                            if (pending_pkt_mem(j).order_domain = pending_pkt_mem(i).order_domain) then
                                domain_hit_v := true;
                            end if;
                        end if;
                    end loop;
                    if (domain_hit_v) then
                        slot_domain_blocked_q(i) <= '1';
                    else
                        slot_domain_blocked_q(i) <= '0';
                    end if;
                end loop;
            end if;
        end if;
    end process dispatch_precomp_s1;

    -- Stage 2: Find the dispatch winner from registered per-slot flags.
    -- This runs one cycle after Stage 1. The priority search (~5-6 LUT
    -- levels) is well within the timing budget from registered inputs.
    dispatch_precomp_s2 : process(i_clk)
        variable winner_found_v : boolean;
        variable winner_idx_v   : pending_queue_index_t;
        variable allow_ooo_v    : boolean;
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                dispatch_winner_valid_q <= '0';
                dispatch_winner_idx_q   <= 0;
            else
                winner_found_v := false;
                winner_idx_v   := 0;
                allow_ooo_v := (OOO_ENABLE_G and ooo_ctrl_enable = '1');
                if (allow_ooo_v = false) then
                    if (
                        slot_count_valid_q(0) = '1' and
                        slot_domain_blocked_q(0) = '0' and
                        (hub_enable_s1_q = '1' or slot_is_internal_q(0) = '1') and
                        not (deferred_atomic_s1_q = '1' and slot_is_internal_q(0) = '0') and
                        slot_credit_ok_q(0) = '1'
                    ) then
                        winner_found_v := true;
                        winner_idx_v   := 0;
                    end if;
                else
                    for pass_idx in 0 to 1 loop
                        exit when winner_found_v;
                        for queue_idx in 0 to OUTSTANDING_LIMIT_G - 1 loop
                            if (
                                slot_count_valid_q(queue_idx) = '1' and
                                slot_domain_blocked_q(queue_idx) = '0' and
                                (hub_enable_s1_q = '1' or slot_is_internal_q(queue_idx) = '1') and
                                not (deferred_atomic_s1_q = '1' and slot_is_internal_q(queue_idx) = '0') and
                                slot_credit_ok_q(queue_idx) = '1' and
                                ((pass_idx = 0 and slot_prefer_relaxed_q(queue_idx) = '1') or pass_idx = 1)
                            ) then
                                winner_found_v := true;
                                winner_idx_v   := queue_idx;
                                exit;
                            end if;
                        end loop;
                    end loop;
                end if;
                if (winner_found_v) then
                    dispatch_winner_valid_q <= '1';
                    dispatch_winner_idx_q   <= winner_idx_v;
                else
                    dispatch_winner_valid_q <= '0';
                end if;
            end if;
        end if;
    end process dispatch_precomp_s2;

    o_rx_ready <= '1'
        when (
            tracked_pkt_count < OUTSTANDING_LIMIT_G and
            (
                i_pkt_is_internal = '1' or
                tracked_ext_count < ext_track_limit_func(OUTSTANDING_LIMIT_G, OUTSTANDING_INT_RESERVED_G)
            )
        )
        else '0';
    o_soft_reset_pulse  <= soft_reset_pulse;
    o_wr_data_rdreq     <= '1'
        when (
            (
                core_state = INT_WR_DRAINING and
                drain_remaining > 0 and
                not (
                    pkt_is_internal_reg = '1' and
                    pkt_is_read_func(pkt_info_reg) = false and
                    pkt_info_reg.atomic_flag = '0' and
                    unsigned(pkt_info_reg.rw_length) = 1
                ) and
                i_wr_data_empty = '0'
            ) or
            (core_state = EXT_WR_RUNNING and i_bus_wr_data_ready = '1' and wr_data_valid_reg = '1')
        )
        else '0';
    o_tx_reply_start    <= tx_reply_start_pulse;
    o_tx_reply_info     <= pkt_info_reg;
    o_tx_reply_response <= response_reg;
    o_tx_reply_has_data <= reply_has_data_reg;
    o_tx_reply_suppress <= reply_suppress_reg;
    o_tx_data_valid     <= '1' when (core_state = RD_REPLY_STREAMING and rd_fifo_empty = '0') else '0';
    o_tx_data_word      <= rd_fifo_q;
    o_bus_cmd_valid     <= bus_cmd_valid_pulse;
    o_bus_cmd_is_read   <= bus_cmd_is_read_reg;
    o_bus_cmd_nonincrement <= bus_cmd_nonincrement_reg;
    o_bus_cmd_address   <= bus_cmd_address_reg;
    o_bus_cmd_length    <= bus_cmd_length_reg;
    o_bus_wr_data_valid <= '1'
        when (
            (core_state = EXT_WR_RUNNING and wr_data_valid_reg = '1') or
            (core_state = ATOMIC_EXT_WR_RUNNING)
        )
        else '0';
    o_bus_wr_data       <= atomic_write_data_reg when (core_state = ATOMIC_EXT_WR_RUNNING) else
                           i_wr_data_q when (wr_data_reload_pending = '1') else
                           wr_data_word_reg;
    avs_csr_readdata    <= avs_csr_readdata_reg;
    avs_csr_readdatavalid <= avs_csr_readdatavalid_reg;
    avs_csr_write_ready <= '1'
        when (
            core_state = IDLING and
            deferred_atomic_pending = '0' and
            soft_reset_pending = '0' and
            i_bp_overflow_pulse = '0' and
            i_dl_fifo_overflow_pulse = '0' and
            i_pkt_drop_pulse = '0' and
            i_bus_timeout_pulse = '0' and
            err_count_pulse_q = '0'
        )
        else '0';
    avs_csr_waitrequest <= '1'
        when (avs_csr_write = '1' and avs_csr_write_ready = '0')
        else '0';
    rd_fifo_read_en     <= '1' when (core_state = RD_REPLY_STREAMING and i_tx_data_ready = '1' and rd_fifo_empty = '0') else '0';

    core_fsm : process(i_clk)
        procedure load_csr_read_word_proc (
            constant offset_in              : in natural;
            constant hide_busy_in           : in boolean;
            variable csr_word_out           : out std_logic_vector(31 downto 0);
            variable response_out           : inout std_logic_vector(1 downto 0);
            variable internal_addr_error_out : inout boolean
        ) is
            variable status_word_local_v      : std_logic_vector(31 downto 0);
            variable fifo_status_word_local_v : std_logic_vector(31 downto 0);
            variable hub_cap_word_local_v     : std_logic_vector(31 downto 0);
            variable version_local_v          : std_logic_vector(31 downto 0);
            variable meta_local_v             : std_logic_vector(31 downto 0);
        begin
            csr_word_out              := (others => '0');
            status_word_local_v       := (others => '0');
            fifo_status_word_local_v  := (others => '0');
            hub_cap_word_local_v      := (others => '0');

            -- Pre-compute META read-mux value
            version_local_v               := (others => '0');
            version_local_v(31 downto 24) := std_logic_vector(to_unsigned(VERSION_MAJOR_G, 8));
            version_local_v(23 downto 16) := std_logic_vector(to_unsigned(VERSION_MINOR_G, 8));
            version_local_v(15 downto 12) := std_logic_vector(to_unsigned(VERSION_PATCH_G, 4));
            version_local_v(11 downto 0)  := std_logic_vector(to_unsigned(BUILD_G, 12));
            case meta_page_sel is
                when "00"   => meta_local_v := version_local_v;
                when "01"   => meta_local_v := std_logic_vector(to_unsigned(VERSION_DATE_G, 32));
                when "10"   => meta_local_v := std_logic_vector(to_unsigned(VERSION_GIT_G, 32));
                when others => meta_local_v := std_logic_vector(to_unsigned(INSTANCE_ID_G, 32));
            end case;

            if (core_state /= IDLING or pending_pkt_count /= 0 or deferred_atomic_pending = '1') then
                status_word_local_v(0) := '1';
            else
                status_word_local_v(0) := '0';
            end if;

            if (hide_busy_in = true and offset_in = HUB_CSR_WO_STATUS_CONST) then
                status_word_local_v(0) := '0';
            end if;

            if (hub_err_flags /= std_logic_vector(to_unsigned(0, hub_err_flags'length))) then
                status_word_local_v(1) := '1';
            else
                status_word_local_v(1) := '0';
            end if;

            status_word_local_v(2) := i_dl_fifo_full;
            status_word_local_v(3) := i_bp_full;
            status_word_local_v(4) := hub_enable;
            status_word_local_v(5) := i_bus_busy;

            fifo_status_word_local_v(0) := i_dl_fifo_full;
            fifo_status_word_local_v(1) := i_bp_full;
            fifo_status_word_local_v(2) := i_dl_fifo_overflow;
            fifo_status_word_local_v(3) := i_bp_overflow;
            fifo_status_word_local_v(4) := rd_fifo_full;
            fifo_status_word_local_v(5) := rd_fifo_empty;

            if (OOO_ENABLE_G) then
                hub_cap_word_local_v(0) := '1';
            end if;
            if (ORD_ENABLE_G) then
                hub_cap_word_local_v(1) := '1';
            end if;
            if (ATOMIC_ENABLE_G) then
                hub_cap_word_local_v(2) := '1';
            end if;
            hub_cap_word_local_v(3) := '1';

            case offset_in is
                when HUB_CSR_WO_UID_CONST =>
                    csr_word_out := std_logic_vector(to_unsigned(IP_UID_G, 32));
                when HUB_CSR_WO_META_CONST =>
                    csr_word_out := meta_local_v;
                when HUB_CSR_WO_CTRL_CONST =>
                    csr_word_out(0) := hub_enable;
                when HUB_CSR_WO_STATUS_CONST =>
                    csr_word_out := status_word_local_v;
                when HUB_CSR_WO_ERR_FLAGS_CONST =>
                    csr_word_out := hub_err_flags;
                when HUB_CSR_WO_ERR_COUNT_CONST =>
                    csr_word_out := std_logic_vector(hub_err_count);
                when HUB_CSR_WO_SCRATCH_CONST =>
                    csr_word_out := hub_scratch;
                when HUB_CSR_WO_GTS_SNAP_LO_CONST =>
                    csr_word_out := std_logic_vector(hub_gts_snapshot(31 downto 0));
                when HUB_CSR_WO_GTS_SNAP_HI_CONST =>
                    csr_word_out(15 downto 0) := std_logic_vector(hub_gts_snapshot(47 downto 32));
                    hub_gts_snapshot          <= hub_gts_counter;
                when HUB_CSR_WO_FIFO_CFG_CONST =>
                    csr_word_out(0) := '1';
                    csr_word_out(1) := hub_upload_store_forward;
                when HUB_CSR_WO_FIFO_STATUS_CONST =>
                    csr_word_out := fifo_status_word_local_v;
                when HUB_CSR_WO_DOWN_PKT_CNT_CONST =>
                    if (core_state /= IDLING or pending_pkt_count /= 0 or deferred_atomic_pending = '1') then
                        csr_word_out(0) := '1';
                    else
                        csr_word_out(0) := '0';
                    end if;
                when HUB_CSR_WO_UP_PKT_CNT_CONST =>
                    csr_word_out(9 downto 0) := std_logic_vector(resize(unsigned(i_bp_pkt_count), 10));
                when HUB_CSR_WO_DOWN_USEDW_CONST =>
                    csr_word_out(9 downto 0) := i_dl_fifo_usedw;
                when HUB_CSR_WO_UP_USEDW_CONST =>
                    csr_word_out(9 downto 0) := std_logic_vector(resize(unsigned(i_bp_usedw), 10));
                when HUB_CSR_WO_EXT_PKT_RD_CONST =>
                    csr_word_out := std_logic_vector(ext_pkt_read_count);
                when HUB_CSR_WO_EXT_PKT_WR_CONST =>
                    csr_word_out := std_logic_vector(ext_pkt_write_count);
                when HUB_CSR_WO_EXT_WORD_RD_CONST =>
                    csr_word_out := std_logic_vector(ext_word_read_count);
                when HUB_CSR_WO_EXT_WORD_WR_CONST =>
                    csr_word_out := std_logic_vector(ext_word_write_count);
                when HUB_CSR_WO_LAST_RD_ADDR_CONST =>
                    csr_word_out := last_ext_read_addr;
                when HUB_CSR_WO_LAST_RD_DATA_CONST =>
                    csr_word_out := last_ext_read_data;
                when HUB_CSR_WO_LAST_WR_ADDR_CONST =>
                    csr_word_out := last_ext_write_addr;
                when HUB_CSR_WO_LAST_WR_DATA_CONST =>
                    csr_word_out := last_ext_write_data;
                when HUB_CSR_WO_PKT_DROP_CNT_CONST =>
                    csr_word_out(15 downto 0) := i_pkt_drop_count;
                when HUB_CSR_WO_DBG_DROP_DETAIL_CONST =>
                    csr_word_out := i_debug_drop_detail;
                when HUB_CSR_WO_FEB_TYPE_CONST =>
                    csr_word_out(1 downto 0) := local_feb_type;
                when HUB_CSR_WO_OOO_CTRL_CONST =>
                    if (OOO_ENABLE_G) then
                        csr_word_out(0) := ooo_ctrl_enable;
                    end if;
                when HUB_CSR_WO_ORD_DRAIN_CNT_CONST =>
                    csr_word_out := std_logic_vector(ord_drain_count);
                when HUB_CSR_WO_ORD_HOLD_CNT_CONST =>
                    csr_word_out := std_logic_vector(ord_hold_count);
                when HUB_CSR_WO_HUB_CAP_CONST =>
                    if (HUB_CAP_ENABLE_G) then
                        csr_word_out := hub_cap_word_local_v;
                    end if;
                when others =>
                    csr_word_out              := x"EEEEEEEE";
                    response_out              := SC_RSP_SLVERR_CONST;
                    internal_addr_error_out   := true;
            end case;
        end procedure load_csr_read_word_proc;

        procedure apply_csr_write_proc (
            constant offset_in              : in natural;
            constant write_word_in          : in std_logic_vector(31 downto 0);
            variable response_out           : inout std_logic_vector(1 downto 0);
            variable internal_addr_error_out : inout boolean
        ) is
        begin
            case offset_in is
                when HUB_CSR_WO_UID_CONST =>
                    null; -- UID is read-only
                when HUB_CSR_WO_META_CONST =>
                    meta_page_sel <= write_word_in(1 downto 0);
                when HUB_CSR_WO_CTRL_CONST =>
                    hub_enable <= write_word_in(0);
                    if (write_word_in(1) = '1' or write_word_in(2) = '1') then
                        hub_err_flags             <= (others => '0');
                        hub_err_count             <= (others => '0');
                        ext_pkt_read_count        <= (others => '0');
                        ext_pkt_write_count       <= (others => '0');
                        ext_word_read_count       <= (others => '0');
                        last_ext_read_addr        <= (others => '0');
                        last_ext_read_data_clear_pulse <= '1';
                        ext_write_diag_clear_pulse <= '1';
                    end if;
                    if (write_word_in(2) = '1') then
                        soft_reset_pending <= '1';
                    end if;
                when HUB_CSR_WO_ERR_FLAGS_CONST =>
                    hub_err_flags <= hub_err_flags and not write_word_in;
                when HUB_CSR_WO_SCRATCH_CONST =>
                    hub_scratch <= write_word_in;
                when HUB_CSR_WO_FIFO_CFG_CONST =>
                    hub_upload_store_forward <= write_word_in(1);
                when HUB_CSR_WO_FEB_TYPE_CONST =>
                    local_feb_type <= write_word_in(1 downto 0);
                when HUB_CSR_WO_OOO_CTRL_CONST =>
                    if (OOO_ENABLE_G) then
                        ooo_ctrl_enable <= write_word_in(0);
                    else
                        ooo_ctrl_enable <= '0';
                    end if;
                when others =>
                    response_out            := SC_RSP_SLVERR_CONST;
                    internal_addr_error_out := true;
            end case;
        end procedure apply_csr_write_proc;

        variable csr_word_v             : std_logic_vector(31 downto 0);
        variable offset_v               : natural;
        variable pkt_len_v              : unsigned(15 downto 0);
        variable err_pulse_v            : boolean;
        variable internal_addr_error_v  : boolean;
        variable soft_reset_request_v   : boolean;
        variable unsupported_feature_v  : boolean;
        variable unsupported_order_v    : boolean;
        variable unsupported_atomic_v   : boolean;
        variable csr_write_offset_v     : natural;
        variable next_read_addr_v       : unsigned(31 downto 0);
        variable hub_cap_word_v         : std_logic_vector(31 downto 0);
        variable atomic_read_word_v     : std_logic_vector(31 downto 0);
        variable done_read_fill_v       : unsigned(15 downto 0);
        variable queue_mem_v            : pending_pkt_mem_t;
        variable queue_rd_ptr_v         : pending_queue_index_t;
        variable queue_wr_ptr_v         : pending_queue_index_t;
        variable queue_count_v          : natural range 0 to OUTSTANDING_LIMIT_G;
        variable queue_ext_count_v      : natural range 0 to OUTSTANDING_LIMIT_G;
        variable dispatch_pkt_valid_v   : boolean;
        variable dispatch_queue_idx_v   : pending_queue_index_t;
        variable barrier_guard_v        : natural range 0 to 15;
        variable int_sideband_write_v   : boolean;
        variable write_word_v           : std_logic_vector(31 downto 0);
        variable ext_write_word_v       : std_logic_vector(31 downto 0);
        variable response_reg_v         : std_logic_vector(1 downto 0);
        variable avs_csr_response_v     : std_logic_vector(1 downto 0);
        variable pkt_csr_write_valid_v  : boolean;
        variable pkt_csr_write_offset_v : natural range 0 to HUB_CSR_WINDOW_WORDS_CONST - 1;
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                core_state               <= IDLING;
                core_reset_bucket        <= (others => '0');
                pkt_info_reg             <= SC_PKT_INFO_RESET_CONST;
                pkt_is_internal_reg      <= '0';
                reply_suppress_reg       <= '0';
                pkt_ignore_reg           <= '0';
                reply_has_data_reg       <= '0';
                reply_is_internal_reg    <= '0';
                response_reg             <= SC_RSP_OK_CONST;
                hub_enable               <= '1';
                meta_page_sel            <= "00";
                hub_scratch              <= (others => '0');
                hub_err_flags            <= (others => '0');
                hub_err_count            <= (others => '0');
                hub_gts_counter          <= (others => '0');
                hub_gts_snapshot         <= (others => '0');
                hub_upload_store_forward <= '1';
                local_feb_type           <= HUB_FEB_TYPE_ALL_CONST;
                ooo_ctrl_enable          <= '0';
                ord_drain_count          <= (others => '0');
                ord_hold_count           <= (others => '0');
                ext_pkt_read_count       <= (others => '0');
                ext_pkt_write_count      <= (others => '0');
                ext_word_read_count      <= (others => '0');
                last_ext_read_addr       <= (others => '0');
                last_ext_read_data_clear_pulse <= '0';
                last_ext_read_data_capture <= '0';
                i_bus_rd_data_r          <= (others => '0');
                read_fill_index          <= (others => '0');
                int_rd_last_fill_q       <= '0';
                reply_stream_index       <= (others => '0');
                reply_words_remaining    <= (others => '0');
                reply_arm_pending        <= '0';
                reply_arm_use_fifo_usedw <= '0';
                write_stream_index       <= (others => '0');
                drain_remaining          <= (others => '0');
                atomic_read_data_reg     <= (others => '0');
                atomic_write_data_reg    <= (others => '0');
                deferred_atomic_pending  <= '0';
                deferred_atomic_pkt_info <= SC_PKT_INFO_RESET_CONST;
                deferred_atomic_response <= SC_RSP_OK_CONST;
                deferred_atomic_has_data <= '0';
                deferred_atomic_suppress <= '0';
                deferred_atomic_data_word <= (others => '0');
                bus_cmd_issued           <= '0';
                rd_fifo_clear            <= '0';
                rd_fifo_write_en         <= '0';
                rd_fifo_write_data       <= (others => '0');
                int_read_offset_reg      <= (others => '0');
                int_read_word_reg        <= (others => '0');
                tx_reply_start_pulse     <= '0';
                soft_reset_pulse         <= '0';
                bus_cmd_valid_pulse      <= '0';
                bus_cmd_is_read_reg      <= '0';
                bus_cmd_nonincrement_reg <= '0';
                bus_cmd_address_reg      <= (others => '0');
                bus_cmd_length_reg       <= (others => '0');
                pending_pkt_mem          <= (others => SC_PKT_INFO_RESET_CONST);
                pending_pkt_rd_ptr       <= 0;
                pending_pkt_wr_ptr       <= 0;
                pending_pkt_count        <= 0;
                pending_ext_count        <= 0;
                barrier_guard_counter    <= 0;
                wr_data_valid_reg        <= '0';
                wr_data_word_reg         <= (others => '0');
                wr_data_reload_pending   <= '0';
                dispatch_pkt_reg         <= SC_PKT_INFO_RESET_CONST;
                dispatch_queue_idx_reg   <= 0;
                err_count_pulse_q        <= '0';
                tx_reply_ready_q         <= '0';
                pkt_len_is_one_q         <= '0';
                pkt_csr_write_offset_q   <= 0;
                soft_reset_pending       <= '0';
                avs_csr_readdata_reg     <= (others => '0');
                avs_csr_readdatavalid_reg <= '0';
                ext_write_diag_clear_pulse <= '0';
            else
                tx_reply_start_pulse <= '0';
                soft_reset_pulse     <= '0';
                bus_cmd_valid_pulse  <= '0';
                rd_fifo_clear        <= '0';
                rd_fifo_write_en     <= '0';
                avs_csr_readdatavalid_reg <= '0';
                ext_write_diag_clear_pulse <= '0';
                last_ext_read_data_capture <= '0';
                last_ext_read_data_clear_pulse <= '0';
                i_bus_rd_data_r            <= i_bus_rd_data;
                err_pulse_v          := false;
                internal_addr_error_v := false;
                soft_reset_request_v := false;
                unsupported_feature_v := false;
                unsupported_order_v   := false;
                unsupported_atomic_v  := false;
                pkt_len_v            := pkt_length_func(pkt_info_reg);
                hub_cap_word_v       := (others => '0');
                atomic_read_word_v   := atomic_read_data_reg;
                done_read_fill_v     := read_fill_index;
                queue_mem_v          := pending_pkt_mem;
                queue_rd_ptr_v       := 0;
                queue_wr_ptr_v       := 0;
                queue_count_v        := pending_pkt_count;
                queue_ext_count_v    := pending_ext_count;
                dispatch_pkt_valid_v := false;
                dispatch_queue_idx_v := 0;
                barrier_guard_v      := barrier_guard_counter;
                int_sideband_write_v := false;
                write_word_v         := i_wr_data_q;
                ext_write_word_v     := wr_data_word_reg;
                response_reg_v       := response_reg;
                avs_csr_response_v   := SC_RSP_OK_CONST;
                pkt_csr_write_valid_v := false;
                pkt_csr_write_offset_v := 0;
                if (barrier_guard_v /= 0) then
                    barrier_guard_v := barrier_guard_v - 1;
                end if;
                tx_reply_ready_q <= i_tx_reply_ready;
                if (soft_reset_pending = '1') then
                    soft_reset_request_v := true;
                    soft_reset_pending   <= '0';
                end if;
                if (err_count_pulse_q = '1') then
                    if (hub_err_count(7 downto 0) /= to_unsigned(16#FF#, 8)) then
                        hub_err_count <= resize(hub_err_count(7 downto 0) + 1, hub_err_count'length);
                    end if;
                end if;
                if (wr_data_reload_pending = '1') then
                    wr_data_word_reg       <= i_wr_data_q;
                    wr_data_reload_pending <= '0';
                    ext_write_word_v       := i_wr_data_q;
                end if;
                if (OOO_ENABLE_G) then
                    hub_cap_word_v(0) := '1';
                end if;
                if (ORD_ENABLE_G) then
                    hub_cap_word_v(1) := '1';
                end if;
                if (ATOMIC_ENABLE_G) then
                    hub_cap_word_v(2) := '1';
                end if;
                hub_cap_word_v(3) := '1';

                hub_gts_counter <= hub_gts_counter + 1;

                if (i_bp_overflow_pulse = '1') then
                    hub_err_flags(HUB_ERR_UP_FIFO_OVERFLOW_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                if (i_dl_fifo_overflow_pulse = '1') then
                    hub_err_flags(HUB_ERR_DOWN_FIFO_OVERFLOW_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                if (i_pkt_drop_pulse = '1') then
                    hub_err_flags(HUB_ERR_PKT_DROP_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                if (i_bus_timeout_pulse = '1') then
                    hub_err_flags(HUB_ERR_RD_TIMEOUT_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                -- Dispatch decision: read the pre-computed winner from the
                -- registered Stage 2 pipeline. This is ~2-3 LUT levels
                -- (registered flag read + state decode), vs the original
                -- ~19-level combinational cascade.
                if (core_state = IDLING) then
                    if (dispatch_winner_valid_q = '1') then
                        dispatch_pkt_valid_v   := true;
                        dispatch_queue_idx_v   := dispatch_winner_idx_q;
                        if (
                            dispatch_queue_idx_v >= queue_count_v or
                            (
                                deferred_atomic_pending = '1' and
                                pkt_is_internal_func(queue_mem_v(dispatch_queue_idx_v)) = false
                            )
                        ) then
                            dispatch_pkt_valid_v := false;
                        end if;
                    end if;
                end if;

                if (i_pkt_valid = '1' and o_rx_ready = '1') then
                    if (queue_count_v < OUTSTANDING_LIMIT_G) then
                        if (
                            queue_count_v = 0 and
                            i_pkt_is_internal = '0' and
                            i_pkt_info.order_mode /= SC_ORDER_RELAXED_CONST
                        ) then
                            barrier_guard_v := 8;
                        end if;
                        queue_mem_v(queue_count_v) := i_pkt_info;
                        queue_count_v              := queue_count_v + 1;
                        if (i_pkt_is_internal = '0') then
                            queue_ext_count_v := queue_ext_count_v + 1;
                        end if;
                    end if;
                end if;

                case core_state is
                    when IDLING =>
                        bus_cmd_issued <= '0';
                        if (deferred_atomic_pending = '1' and dispatch_pkt_valid_v = false) then
                            pkt_info_reg          <= deferred_atomic_pkt_info;
                            pkt_is_internal_reg   <= '0';
                            reply_suppress_reg    <= deferred_atomic_suppress;
                            reply_has_data_reg    <= deferred_atomic_has_data;
                            reply_is_internal_reg <= '0';
                            response_reg_v        := deferred_atomic_response;
                            read_fill_index       <= (others => '0');
                            int_rd_last_fill_q    <= '0';
                            reply_stream_index    <= (others => '0');
                            reply_words_remaining <= (others => '0');
                            write_stream_index    <= (others => '0');
                            drain_remaining       <= unsigned(deferred_atomic_pkt_info.rw_length);
                            deferred_atomic_pending <= '0';
                            if (deferred_atomic_suppress = '1') then
                                core_state <= IDLING;
                            elsif (deferred_atomic_has_data = '1') then
                                rd_fifo_write_en   <= '1';
                                rd_fifo_write_data <= deferred_atomic_data_word;
                                read_fill_index          <= to_unsigned(1, read_fill_index'length);
                                reply_arm_pending        <= '1';
                                reply_arm_use_fifo_usedw <= '0';
                                core_state               <= RD_REPLY_ARMING;
                            else
                                core_state <= WR_REPLY_ARMING;
                            end if;
                        elsif (dispatch_pkt_valid_v = true) then
                            dispatch_queue_idx_reg <= dispatch_queue_idx_v;
                            core_state             <= DISPATCH_CAPTURING;
                        end if;

                    when DISPATCH_CAPTURING =>
                        -- Read the selected packet directly from the registered
                        -- queue memory (8:1 mux, ~3 LUT levels). The wide mux
                        -- that was formerly in IDLING is now here, separated from
                        -- the dispatch search logic by a full clock cycle.
                        pkt_info_reg <= pending_pkt_mem(dispatch_queue_idx_reg);
                        pkt_is_internal_reg <= slot_is_internal_q(dispatch_queue_idx_reg);
                        if (pkt_reply_suppressed_func(pending_pkt_mem(dispatch_queue_idx_reg))) then
                            reply_suppress_reg <= '1';
                        else
                            reply_suppress_reg <= '0';
                        end if;
                        if (pkt_locally_masked_func(pending_pkt_mem(dispatch_queue_idx_reg), local_feb_type)) then
                            pkt_ignore_reg <= '1';
                        else
                            pkt_ignore_reg <= '0';
                        end if;
                        reply_is_internal_reg <= '0';
                        read_fill_index       <= (others => '0');
                        int_rd_last_fill_q    <= '0';
                        reply_stream_index    <= (others => '0');
                        reply_words_remaining <= (others => '0');
                        write_stream_index    <= (others => '0');
                        wr_data_valid_reg     <= '0';
                        wr_data_word_reg      <= (others => '0');
                        wr_data_reload_pending <= '0';
                        if (unsigned(pending_pkt_mem(dispatch_queue_idx_reg).rw_length) = 1) then
                            pkt_len_is_one_q <= '1';
                        else
                            pkt_len_is_one_q <= '0';
                        end if;
                        if (slot_is_internal_q(dispatch_queue_idx_reg) = '0' and queue_ext_count_v /= 0) then
                            queue_ext_count_v := queue_ext_count_v - 1;
                        end if;
                        if (queue_count_v > 1) then
                            for shift_idx in 0 to OUTSTANDING_LIMIT_G - 2 loop
                                if (shift_idx >= dispatch_queue_idx_reg and shift_idx + 1 < queue_count_v) then
                                    queue_mem_v(shift_idx) := queue_mem_v(shift_idx + 1);
                                end if;
                            end loop;
                        end if;
                        if (queue_count_v /= 0) then
                            if (queue_count_v = 1) then
                                barrier_guard_v := 0;
                            end if;
                            queue_count_v := queue_count_v - 1;
                        end if;
                        core_state            <= DISPATCH_DECODING;

                    when DISPATCH_DECODING =>
                        response_reg_v        := SC_RSP_OK_CONST;
                        drain_remaining       <= unsigned(pkt_info_reg.rw_length);
                        bus_cmd_is_read_reg   <= '0';
                        bus_cmd_nonincrement_reg <= '0';
                        bus_cmd_address_reg   <= pkt_info_reg.start_address(17 downto 0);
                        bus_cmd_length_reg    <= pkt_info_reg.rw_length;
                        rd_fifo_clear         <= '1';
                        -- Pre-register CSR write offset (masks to 5 bits so the
                        -- subtraction is safe even for non-internal addresses;
                        -- the value is only consumed when the packet is internal).
                        pkt_csr_write_offset_q <= to_integer(
                            resize(unsigned(pkt_info_reg.start_address(15 downto 0))
                                   - to_unsigned(HUB_CSR_BASE_ADDR_CONST, 16), 5));
                        unsupported_order_v   := (ORD_ENABLE_G = false and pkt_info_reg.order_mode /= SC_ORDER_RELAXED_CONST);
                        unsupported_atomic_v  := (pkt_info_reg.atomic_flag = '1' and (ATOMIC_ENABLE_G = false or pkt_is_internal_reg = '1'));
                        unsupported_feature_v := unsupported_order_v or unsupported_atomic_v;

                        if (pkt_info_reg.order_mode = SC_ORDER_RELEASE_CONST) then
                            ord_drain_count <= sat_inc32_func(ord_drain_count);
                        elsif (pkt_info_reg.order_mode = SC_ORDER_ACQUIRE_CONST) then
                            ord_hold_count <= sat_inc32_func(ord_hold_count);
                        end if;

                        if (pkt_ignore_reg = '1') then
                            reply_has_data_reg <= '0';
                            if (
                                pkt_is_read_func(pkt_info_reg) = false and
                                pkt_info_reg.atomic_flag = '0' and
                                unsigned(pkt_info_reg.rw_length) /= 0
                            ) then
                                reply_suppress_reg <= '1';
                                core_state         <= INT_WR_DRAINING;
                            else
                                core_state         <= IDLING;
                            end if;
                        elsif (unsupported_feature_v = true) then
                            response_reg_v     := SC_RSP_SLVERR_CONST;
                            reply_has_data_reg <= '0';
                            if (reply_suppress_reg = '1') then
                                core_state <= IDLING;
                            else
                                core_state <= WR_REPLY_ARMING;
                            end if;
                        elsif (pkt_is_atomic_func(pkt_info_reg)) then
                            reply_has_data_reg  <= '1';
                            ext_pkt_read_count  <= sat_inc32_func(ext_pkt_read_count);
                            bus_cmd_is_read_reg <= '1';
                            bus_cmd_length_reg  <= std_logic_vector(to_unsigned(1, bus_cmd_length_reg'length));
                            core_state          <= ATOMIC_EXT_RD_RUNNING;
                        elsif (pkt_is_read_func(pkt_info_reg)) then
                            reply_has_data_reg <= '1';
                            if (pkt_is_nonincrementing_func(pkt_info_reg)) then
                                bus_cmd_nonincrement_reg <= '1';
                            end if;
                            if (unsigned(pkt_info_reg.rw_length) = 0) then
                                if (pkt_is_internal_reg = '0') then
                                    ext_pkt_read_count <= sat_inc32_func(ext_pkt_read_count);
                                end if;

                                if (reply_suppress_reg = '1') then
                                    core_state <= IDLING;
                                else
                                    core_state <= RD_REPLY_ARMING;
                                end if;
                            elsif (pkt_is_internal_reg = '1') then
                                reply_is_internal_reg <= '1';
                                core_state            <= INT_RD_OFFSETING;
                            else
                                ext_pkt_read_count  <= sat_inc32_func(ext_pkt_read_count);
                                bus_cmd_is_read_reg <= '1';
                                core_state          <= EXT_RD_RUNNING;
                            end if;
                        else
                            reply_has_data_reg <= '0';
                            if (unsigned(pkt_info_reg.rw_length) = 0) then
                                if (pkt_is_internal_reg = '0') then
                                    ext_pkt_write_count <= sat_inc32_func(ext_pkt_write_count);
                                end if;

                                if (reply_suppress_reg = '1') then
                                    core_state <= IDLING;
                                else
                                    core_state <= WR_REPLY_ARMING;
                                end if;
                            elsif (pkt_is_internal_reg = '1') then
                                core_state <= INT_WR_DRAINING;
                            else
                                ext_pkt_write_count <= sat_inc32_func(ext_pkt_write_count);
                                if (pkt_is_nonincrementing_func(pkt_info_reg)) then
                                    bus_cmd_nonincrement_reg <= '1';
                                end if;
                                core_state         <= EXT_WR_ARMING;
                            end if;
                        end if;

                    when INT_RD_OFFSETING =>
                        int_read_offset_reg <= resize(unsigned(pkt_info_reg.start_address(15 downto 0)), int_read_offset_reg'length) -
                                               to_unsigned(HUB_CSR_BASE_ADDR_CONST, int_read_offset_reg'length);
                        if (pkt_is_nonincrementing_func(pkt_info_reg) = false) then
                            int_read_offset_reg <= resize(unsigned(pkt_info_reg.start_address(15 downto 0)), int_read_offset_reg'length) -
                                                   to_unsigned(HUB_CSR_BASE_ADDR_CONST, int_read_offset_reg'length) +
                                                   resize(read_fill_index, int_read_offset_reg'length);
                        end if;
                        core_state          <= INT_RD_FILLING;

                    when INT_RD_FILLING =>
                        offset_v := to_integer(int_read_offset_reg);
                        if (read_fill_index + 1 >= pkt_len_v) then
                            int_rd_last_fill_q <= '1';
                        else
                            int_rd_last_fill_q <= '0';
                        end if;
                        load_csr_read_word_proc(
                            offset_in               => offset_v,
                            hide_busy_in            => (reply_is_internal_reg = '1'),
                            csr_word_out            => csr_word_v,
                            response_out            => response_reg_v,
                            internal_addr_error_out => internal_addr_error_v
                        );
                        int_read_word_reg <= csr_word_v;
                        core_state        <= INT_RD_PUSHING;

                    when INT_RD_PUSHING =>
                        if (reply_suppress_reg = '0') then
                            rd_fifo_write_en   <= '1';
                            rd_fifo_write_data <= int_read_word_reg;
                        end if;

                        if (int_rd_last_fill_q = '1') then
                            if (reply_suppress_reg = '1') then
                                core_state <= IDLING;
                            else
                                reply_stream_index       <= (others => '0');
                                reply_arm_pending        <= '1';
                                reply_arm_use_fifo_usedw <= '0';
                                core_state               <= RD_REPLY_ARMING;
                            end if;
                        else
                            core_state <= INT_RD_OFFSETING;
                        end if;

                        read_fill_index <= read_fill_index + 1;

                    when EXT_RD_RUNNING =>
                        if (bus_cmd_issued = '0' and i_bus_cmd_ready = '1') then
                            bus_cmd_valid_pulse <= '1';
                            bus_cmd_issued      <= '1';
                        end if;

                        done_read_fill_v := read_fill_index;
                        if (i_bus_rd_data_valid = '1') then
                            if (reply_suppress_reg = '0') then
                                rd_fifo_write_en   <= '1';
                                rd_fifo_write_data <= i_bus_rd_data;
                            end if;
                            ext_word_read_count <= sat_inc32_func(ext_word_read_count);
                            next_read_addr_v    := resize(unsigned(pkt_info_reg.start_address(15 downto 0)), 32);
                            if (pkt_is_nonincrementing_func(pkt_info_reg) = false) then
                                next_read_addr_v := next_read_addr_v + resize(read_fill_index, 32);
                            end if;
                            last_ext_read_addr  <= std_logic_vector(next_read_addr_v);
                            last_ext_read_data_capture <= '1';
                            read_fill_index     <= read_fill_index + 1;
                            done_read_fill_v    := read_fill_index + 1;
                        end if;

                        if (i_bus_done = '1') then
                            response_reg_v := i_bus_response;
                            if (i_bus_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;
                            if (done_read_fill_v < pkt_len_v) then
                                if (reply_suppress_reg = '1') then
                                    core_state <= IDLING;
                                else
                                    core_state <= RD_PADDING;
                                end if;
                            elsif (reply_suppress_reg = '1') then
                                core_state <= IDLING;
                            else
                                reply_stream_index       <= (others => '0');
                                reply_arm_pending        <= '1';
                                reply_arm_use_fifo_usedw <= '0';
                                core_state               <= RD_REPLY_ARMING;
                            end if;
                        end if;

                    when ATOMIC_EXT_RD_RUNNING =>
                        if (bus_cmd_issued = '0' and i_bus_cmd_ready = '1') then
                            bus_cmd_valid_pulse <= '1';
                            bus_cmd_issued      <= '1';
                        end if;

                        if (i_bus_rd_data_valid = '1') then
                            atomic_read_word_v  := i_bus_rd_data;
                            atomic_read_data_reg <= i_bus_rd_data;
                            ext_word_read_count  <= sat_inc32_func(ext_word_read_count);
                            next_read_addr_v     := resize(unsigned(pkt_info_reg.start_address(15 downto 0)), 32);
                            last_ext_read_addr   <= std_logic_vector(next_read_addr_v);
                            last_ext_read_data_capture <= '1';
                            read_fill_index      <= to_unsigned(1, read_fill_index'length);
                        end if;

                        if (i_bus_done = '1') then
                            response_reg_v := i_bus_response;
                            bus_cmd_issued <= '0';
                            if (i_bus_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;
                            if (i_bus_response = SC_RSP_OK_CONST and (i_bus_rd_data_valid = '1' or read_fill_index /= 0)) then
                                atomic_write_data_reg <= (atomic_read_word_v and not pkt_info_reg.atomic_mask) or
                                                         (pkt_info_reg.atomic_data and pkt_info_reg.atomic_mask);
                                bus_cmd_is_read_reg   <= '0';
                                bus_cmd_length_reg    <= std_logic_vector(to_unsigned(1, bus_cmd_length_reg'length));
                                core_state            <= ATOMIC_EXT_WR_ARMING;
                            else
                                reply_has_data_reg <= '0';
                                if (reply_suppress_reg = '1') then
                                    core_state <= IDLING;
                                else
                                    deferred_atomic_pending   <= '1';
                                    deferred_atomic_pkt_info  <= pkt_info_reg;
                                    deferred_atomic_response  <= i_bus_response;
                                    deferred_atomic_has_data  <= '0';
                                    deferred_atomic_suppress  <= reply_suppress_reg;
                                    deferred_atomic_data_word <= (others => '0');
                                    core_state                <= IDLING;
                                end if;
                            end if;
                        end if;

                    when ATOMIC_EXT_WR_ARMING =>
                        if (i_bus_cmd_ready = '1') then
                            bus_cmd_valid_pulse <= '1';
                            write_stream_index  <= (others => '0');
                            core_state          <= ATOMIC_EXT_WR_RUNNING;
                        end if;

                    when ATOMIC_EXT_WR_RUNNING =>
                        if (i_bus_wr_data_ready = '1') then
                        end if;

                        if (i_bus_done = '1') then
                            response_reg_v := i_bus_response;
                            if (i_bus_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;
                            if (reply_suppress_reg = '1') then
                                core_state <= IDLING;
                            else
                                deferred_atomic_pending   <= '1';
                                deferred_atomic_pkt_info  <= pkt_info_reg;
                                deferred_atomic_response  <= i_bus_response;
                                deferred_atomic_has_data  <= '1';
                                deferred_atomic_suppress  <= reply_suppress_reg;
                                deferred_atomic_data_word <= atomic_read_data_reg;
                                core_state                <= IDLING;
                            end if;
                        end if;

                    when RD_PADDING =>
                        rd_fifo_write_en   <= '1';
                        rd_fifo_write_data <= x"EEEEEEEE";
                        read_fill_index    <= read_fill_index + 1;

                        if (read_fill_index + 1 >= pkt_len_v) then
                            if (reply_suppress_reg = '1') then
                                core_state <= IDLING;
                            else
                                reply_stream_index       <= (others => '0');
                                core_state               <= RD_REPLY_PREP;
                            end if;
                        end if;

                    when RD_REPLY_PREP =>
                        reply_arm_pending        <= '1';
                        reply_arm_use_fifo_usedw <= '0';
                        core_state               <= RD_REPLY_ARMING;

                    when RD_REPLY_ARMING =>
                        if (reply_arm_pending = '1') then
                            if (reply_arm_use_fifo_usedw = '1') then
                                reply_words_remaining <= resize(unsigned(rd_fifo_usedw), reply_words_remaining'length);
                            else
                                reply_words_remaining <= pkt_len_v;
                            end if;
                            reply_arm_pending        <= '0';
                            reply_arm_use_fifo_usedw <= '0';
                        elsif (tx_reply_ready_q = '1') then
                            tx_reply_start_pulse <= '1';
                            core_state           <= RD_REPLY_STREAMING;
                        end if;

                    when RD_REPLY_STREAMING =>
                        if (i_tx_data_ready = '1' and rd_fifo_empty = '0') then
                            if (reply_words_remaining <= 1) then
                                core_state <= WAITING_REPLY;
                            end if;
                            if (reply_words_remaining /= 0) then
                                reply_words_remaining <= reply_words_remaining - 1;
                            end if;
                        end if;

                    when INT_WR_DRAINING =>
                        int_sideband_write_v := (
                            pkt_is_internal_reg = '1' and
                            pkt_is_read_func(pkt_info_reg) = false and
                            pkt_info_reg.atomic_flag = '0' and
                            pkt_len_is_one_q = '1'
                        );
                        if (int_sideband_write_v = true) then
                            write_word_v := pkt_info_reg.atomic_data;
                        else
                            write_word_v := i_wr_data_q;
                        end if;

                        if (((int_sideband_write_v = true) or i_wr_data_empty = '0') and drain_remaining > 0) then
                            if (drain_remaining = pkt_len_v) then
                                if (pkt_len_is_one_q = '0') then
                                    response_reg_v        := SC_RSP_SLVERR_CONST;
                                    internal_addr_error_v := true;
                                else
                                    csr_write_offset_v := pkt_csr_write_offset_q;
                                    apply_csr_write_proc(
                                        offset_in               => csr_write_offset_v,
                                        write_word_in           => write_word_v,
                                        response_out            => response_reg_v,
                                        internal_addr_error_out => internal_addr_error_v
                                    );
                                    pkt_csr_write_valid_v  := true;
                                    pkt_csr_write_offset_v := csr_write_offset_v;
                                end if;
                            end if;

                            drain_remaining <= drain_remaining - 1;
                            if (drain_remaining = 1) then
                                if (reply_suppress_reg = '1') then
                                    core_state <= IDLING;
                                else
                                    core_state <= WR_REPLY_ARMING;
                                end if;
                            end if;
                        end if;

                    when EXT_WR_ARMING =>
                        if (i_bus_cmd_ready = '1') then
                            bus_cmd_valid_pulse <= '1';
                            write_stream_index  <= (others => '0');
                            wr_data_word_reg    <= i_wr_data_q;
                            wr_data_valid_reg   <= '1';
                            wr_data_reload_pending <= '0';
                            core_state          <= EXT_WR_RUNNING;
                        end if;

                    when EXT_WR_RUNNING =>
                        ext_write_word_v := wr_data_word_reg;
                        if (wr_data_reload_pending = '1') then
                            ext_write_word_v := i_wr_data_q;
                        end if;

                        if (i_bus_wr_data_ready = '1' and wr_data_valid_reg = '1') then
                            write_stream_index       <= write_stream_index + 1;
                            if (write_stream_index + 1 >= pkt_len_v) then
                                wr_data_valid_reg      <= '0';
                                wr_data_reload_pending <= '0';
                            else
                                wr_data_valid_reg      <= '1';
                                wr_data_reload_pending <= '1';
                            end if;
                        end if;

                        if (i_bus_done = '1') then
                            response_reg_v := i_bus_response;
                            if (i_bus_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;
                            if (reply_suppress_reg = '1') then
                                core_state <= IDLING;
                            else
                                core_state <= WR_REPLY_ARMING;
                            end if;
                            wr_data_valid_reg      <= '0';
                            wr_data_reload_pending <= '0';
                        end if;

                    when WR_REPLY_ARMING =>
                        if (tx_reply_ready_q = '1') then
                            tx_reply_start_pulse <= '1';
                            core_state           <= WAITING_REPLY;
                        end if;

                    when WAITING_REPLY =>
                        if (i_tx_reply_done = '1') then
                            rd_fifo_clear <= '1';
                            core_state    <= IDLING;
                        elsif (
                            tx_reply_ready_q = '1' and
                            reply_has_data_reg = '1' and
                            reply_suppress_reg = '0' and
                            rd_fifo_empty = '0'
                        ) then
                            reply_stream_index       <= (others => '0');
                            reply_arm_pending        <= '1';
                            reply_arm_use_fifo_usedw <= '1';
                            core_state               <= RD_REPLY_ARMING;
                        end if;

                    when CORE_RESETTING =>
                        -- Staged soft-reset: walk core_reset_bucket = 0..3 and
                        -- clear ~17 registers per bucket. Each cleared register
                        -- gets a |sclr enable of
                        --   core_state = CORE_RESETTING and core_reset_bucket = N
                        -- which is a tiny compare on registered state — no FSM
                        -- combinational cone, no process-variable entanglement.
                        -- Total soft-reset latency: 4 cycles + 1 transition.
                        if (core_reset_bucket = "00") then
                            -- Bucket 0: pkt/reply control + hub status
                            pkt_info_reg             <= SC_PKT_INFO_RESET_CONST;
                            pkt_is_internal_reg      <= '0';
                            reply_suppress_reg       <= '0';
                            pkt_ignore_reg           <= '0';
                            reply_has_data_reg       <= '0';
                            reply_is_internal_reg    <= '0';
                            response_reg_v           := SC_RSP_OK_CONST;
                            hub_enable               <= '1';
                            meta_page_sel            <= "00";
                            hub_scratch              <= (others => '0');
                            hub_err_flags            <= (others => '0');
                            hub_err_count            <= (others => '0');
                            hub_gts_counter          <= (others => '0');
                            hub_gts_snapshot         <= (others => '0');
                            hub_upload_store_forward <= '1';
                            local_feb_type           <= HUB_FEB_TYPE_ALL_CONST;
                            ooo_ctrl_enable          <= '0';
                            core_reset_bucket        <= "01";

                        elsif (core_reset_bucket = "01") then
                            -- Bucket 1: ord/ext counters + last_ext_read diag
                            ord_drain_count          <= (others => '0');
                            ord_hold_count           <= (others => '0');
                            ext_pkt_read_count       <= (others => '0');
                            ext_pkt_write_count      <= (others => '0');
                            ext_word_read_count      <= (others => '0');
                            last_ext_read_addr       <= (others => '0');
                            last_ext_read_data_clear_pulse <= '1';
                            last_ext_read_data_capture <= '0';
                            i_bus_rd_data_r          <= (others => '0');
                            read_fill_index          <= (others => '0');
                            int_rd_last_fill_q       <= '0';
                            reply_stream_index       <= (others => '0');
                            reply_words_remaining    <= (others => '0');
                            reply_arm_pending        <= '0';
                            reply_arm_use_fifo_usedw <= '0';
                            write_stream_index       <= (others => '0');
                            drain_remaining          <= (others => '0');
                            core_reset_bucket        <= "10";

                        elsif (core_reset_bucket = "10") then
                            -- Bucket 2: atomic + bus_cmd + rd_fifo controls
                            atomic_read_data_reg     <= (others => '0');
                            atomic_write_data_reg    <= (others => '0');
                            deferred_atomic_pending  <= '0';
                            deferred_atomic_pkt_info <= SC_PKT_INFO_RESET_CONST;
                            deferred_atomic_response <= SC_RSP_OK_CONST;
                            deferred_atomic_has_data <= '0';
                            deferred_atomic_suppress <= '0';
                            deferred_atomic_data_word <= (others => '0');
                            bus_cmd_issued           <= '0';
                            rd_fifo_clear            <= '1';
                            rd_fifo_write_en         <= '0';
                            rd_fifo_write_data       <= (others => '0');
                            tx_reply_start_pulse     <= '0';
                            bus_cmd_valid_pulse      <= '0';
                            bus_cmd_is_read_reg      <= '0';
                            bus_cmd_nonincrement_reg <= '0';
                            bus_cmd_address_reg      <= (others => '0');
                            bus_cmd_length_reg       <= (others => '0');
                            core_reset_bucket        <= "11";

                        else  -- "11"
                            -- Bucket 3: queue/dispatch + misc + return to IDLING.
                            -- The queue state (pending_pkt_mem, pending_pkt_count,
                            -- pending_ext_count, barrier_guard_counter) is mirrored
                            -- by variables that the post-case unconditional copies
                            -- back into the signals at the end of the cycle, so
                            -- direct signal assignments here would be overwritten.
                            -- Drive the variables instead.
                            queue_mem_v              := (others => SC_PKT_INFO_RESET_CONST);
                            queue_count_v            := 0;
                            queue_ext_count_v        := 0;
                            barrier_guard_v          := 0;
                            wr_data_valid_reg        <= '0';
                            wr_data_word_reg         <= (others => '0');
                            wr_data_reload_pending   <= '0';
                            dispatch_pkt_reg         <= SC_PKT_INFO_RESET_CONST;
                            dispatch_queue_idx_reg   <= 0;
                            err_count_pulse_q        <= '0';
                            tx_reply_ready_q         <= '0';
                            pkt_len_is_one_q         <= '0';
                            pkt_csr_write_offset_q   <= 0;
                            soft_reset_pending       <= '0';
                            avs_csr_readdata_reg     <= (others => '0');
                            avs_csr_readdatavalid_reg <= '0';
                            ext_write_diag_clear_pulse <= '0';
                            core_reset_bucket        <= "00";
                            core_state               <= IDLING;
                        end if;
                end case;

                if (avs_csr_read = '1') then
                    offset_v := to_integer(unsigned(avs_csr_address));
                    load_csr_read_word_proc(
                        offset_in               => offset_v,
                        hide_busy_in            => false,
                        csr_word_out            => csr_word_v,
                        response_out            => avs_csr_response_v,
                        internal_addr_error_out => internal_addr_error_v
                    );
                    avs_csr_readdata_reg      <= csr_word_v;
                    avs_csr_readdatavalid_reg <= '1';
                end if;

                if (avs_csr_write = '1' and avs_csr_write_ready = '1') then
                    csr_write_offset_v := to_integer(unsigned(avs_csr_address));
                    if (pkt_csr_write_valid_v = false or csr_write_offset_v /= pkt_csr_write_offset_v) then
                        apply_csr_write_proc(
                            offset_in               => csr_write_offset_v,
                            write_word_in           => avs_csr_writedata,
                            response_out            => avs_csr_response_v,
                            internal_addr_error_out => internal_addr_error_v
                        );
                    end if;
                end if;

                if (internal_addr_error_v = true) then
                    hub_err_flags(HUB_ERR_INTERNAL_ADDR_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                if (err_pulse_v = true) then
                    err_count_pulse_q <= '1';
                else
                    err_count_pulse_q <= '0';
                end if;

                response_reg         <= response_reg_v;
                pending_pkt_mem      <= queue_mem_v;
                pending_pkt_rd_ptr   <= 0;
                pending_pkt_wr_ptr   <= 0;
                pending_pkt_count    <= queue_count_v;
                pending_ext_count    <= queue_ext_count_v;
                barrier_guard_counter <= barrier_guard_v;

                if (soft_reset_request_v = true) then
                    -- Trigger only: transition into the dedicated CORE_RESETTING
                    -- state; the staged clears live in the case arm above. This
                    -- keeps the tx_reply / soft_reset / fifo pulse defaults in
                    -- effect for this cycle without re-entering the wide clear
                    -- block that used to fold the FSM cone into every |sclr.
                    core_state        <= CORE_RESETTING;
                    core_reset_bucket <= (others => '0');
                    soft_reset_pulse  <= '1';
                end if;
            end if;
        end if;
    end process core_fsm;

    -- Dedicated register for last_ext_read_data. Isolating this flop from the
    -- main FSM process collapses its |sclr enable cone from the merged 6-LUT
    -- FSM cloud (drain_remaining[6] -> core_state -> LessThan22 -> Selector2011
    -- -> hub_err_flags~1 -> ext_word_read_count -> ext_pkt_read_count -> sclr)
    -- down to a single-flop compare on last_ext_read_data_clear_pulse /
    -- last_ext_read_data_capture. Drove -0.411 slack at Slow 85C in round-8.
    last_ext_read_data_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                last_ext_read_data <= (others => '0');
            elsif (last_ext_read_data_clear_pulse = '1') then
                last_ext_read_data <= (others => '0');
            elsif (last_ext_read_data_capture = '1') then
                last_ext_read_data <= i_bus_rd_data_r;
            end if;
        end if;
    end process last_ext_read_data_reg;

    ext_write_diag_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                ext_word_write_count   <= (others => '0');
                last_ext_write_addr    <= (others => '0');
                last_ext_write_data    <= (others => '0');
                ext_write_diag_pending <= '0';
                ext_write_diag_addr_hold <= (others => '0');
                ext_write_diag_data_hold <= (others => '0');
            else
                if (ext_write_diag_clear_pulse = '1') then
                    ext_word_write_count   <= (others => '0');
                    last_ext_write_addr    <= (others => '0');
                    last_ext_write_data    <= (others => '0');
                    ext_write_diag_pending <= '0';
                    ext_write_diag_addr_hold <= (others => '0');
                    ext_write_diag_data_hold <= (others => '0');
                else
                    if (ext_write_diag_pending = '1') then
                        ext_word_write_count   <= sat_inc32_func(ext_word_write_count);
                        last_ext_write_addr    <= ext_write_diag_addr_hold;
                        last_ext_write_data    <= ext_write_diag_data_hold;
                        ext_write_diag_pending <= '0';
                    end if;

                    if (
                        i_bus_wr_accept_pulse = '1' and
                        (core_state = ATOMIC_EXT_WR_RUNNING or core_state = EXT_WR_RUNNING)
                    ) then
                        ext_write_diag_pending   <= '1';
                        ext_write_diag_addr_hold <= std_logic_vector(resize(unsigned(i_bus_wr_accept_address), 32));
                        ext_write_diag_data_hold <= i_bus_wr_accept_data;
                    end if;
                end if;
            end if;
        end if;
    end process ext_write_diag_reg;
end architecture rtl;
