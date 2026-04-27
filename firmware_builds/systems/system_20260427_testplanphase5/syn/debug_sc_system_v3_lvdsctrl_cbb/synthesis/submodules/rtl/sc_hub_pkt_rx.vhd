-- File name: sc_hub_pkt_rx.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.2.32
-- Date    : 20260414
-- Change  : Register the packet-type decode (`pkt_is_read` /
--           `pkt_has_download_words`) alongside the packet header so the
--           enqueue-stage control no longer closes through the live
--           `pkt_info_work.sc_type` fanout. Function stays unchanged; this
--           only shortens the enqueue timing cone.
-- =======================================
-- Version : 26.2.31
-- Date    : 20260412
-- Change  : WAITING_WRITE_SPACE now treats a held-stable repeat of the
--           already-latched word as a no-op instead of a drop. Avalon-style
--           upstream holds data stable across backpressured cycles and the
--           previous "drop on second non-idle" rule lost every long burst
--           that hit WAITING_WRITE_SPACE (e.g. back-to-back 255/256-beat
--           writes in the UVM burst_len_sweep).
-- =======================================
-- Version : 26.2.30
-- Date    : 20260411
-- Change  : Make WAITING_WRITE_SPACE recover instead of wedging when the
--           upstream ignores o_download_ready. Unexpected non-idle words now
--           drop the partial packet, and timeout handling also runs while
--           waiting for payload space.
-- =======================================
-- Version : 26.2.29
-- Date    : 20260406
-- Change  : Pre-compute payload_space_granted during LENGTHING state (1 cycle
--           earlier) so the grant is already registered when WAITING_WRITE_SPACE
--           begins. Fixes SC write drops when transceiver rate adaptation
--           deletes the idle word between LENGTH and DATA (back-to-back delivery).
--           Fully registered path -- no new combinational timing risk.
-- =======================================
-- Version : 26.2.28
-- Date    : 20260405
-- Change  : Add local reset register (rst_local) to reduce fanout from the
--           Qsys reset controller, fixing the -1.635 ns reset path violation.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_pkt_rx is
    generic(
        MAX_BURST_G        : positive := MAX_BURST_WORDS_CONST;
        EXT_PLD_DEPTH_G    : positive := DEFAULT_DL_FIFO_DEPTH_CONST;
        PKT_TIMEOUT_CYCLES : positive := DEFAULT_PKT_TIMEOUT_CONST;
        PKT_QUEUE_DEPTH_G  : positive := 16
    );
    port(
        i_clk                : in  std_logic;
        i_rst                : in  std_logic;
        i_soft_reset         : in  std_logic;
        i_download_data      : in  std_logic_vector(31 downto 0);
        i_download_datak     : in  std_logic_vector(3 downto 0);
        i_accept_new_pkt     : in  std_logic;
        i_allow_new_pkt      : in  std_logic;
        o_download_ready     : out std_logic;
        o_pkt_in_progress    : out std_logic;
        o_pkt_valid          : out std_logic;
        o_pkt_info           : out sc_pkt_info_t;
        o_pkt_is_internal    : out std_logic;
        o_soft_reset_pulse   : out std_logic;
        i_wr_data_rdreq      : in  std_logic;
        o_wr_data_q          : out std_logic_vector(31 downto 0);
        o_wr_data_empty      : out std_logic;
        o_pkt_drop_count     : out std_logic_vector(15 downto 0);
        o_pkt_drop_pulse     : out std_logic;
        -- Debug: 32-bit word with per-path drop detail
        -- bits 15:0  = restart_drop_count (premature preamble restart drops)
        -- bits 23:16 = ws_trailer_drop_count[7:0]
        --              (unexpected non-idle word in WAITING_WRITE_SPACE)
        -- bits 31:24 = idle_timeout_drop_count[7:0]
        o_debug_drop_detail  : out std_logic_vector(31 downto 0);
        o_fifo_usedw         : out std_logic_vector(9 downto 0);
        o_fifo_full          : out std_logic;
        o_fifo_overflow      : out std_logic;
        o_fifo_overflow_pulse: out std_logic
    );
end entity sc_hub_pkt_rx;

architecture rtl of sc_hub_pkt_rx is
    type rx_state_t is (
        IDLING,
        ADDRING,
        LENGTHING,
        ATOMIC_MASKING,
        ATOMIC_DATAING,
        WAITING_WRITE_SPACE,
        WRITING_DATA,
        WAITING_TRAILER
    );
    subtype pkt_queue_index_t is natural range 0 to PKT_QUEUE_DEPTH_G - 1;
    subtype write_word_count_t is natural range 0 to MAX_BURST_G;
    type pkt_queue_mem_t is array (pkt_queue_index_t) of sc_pkt_info_t;
    type pkt_queue_flag_mem_t is array (pkt_queue_index_t) of std_logic;
    constant ENQUEUE_STAGE_DEPTH_CONST : positive := 2;
    subtype enqueue_stage_index_t is natural range 0 to ENQUEUE_STAGE_DEPTH_CONST - 1;
    type enqueue_stage_mem_t is array (enqueue_stage_index_t) of sc_pkt_info_t;
    type enqueue_stage_flag_mem_t is array (enqueue_stage_index_t) of std_logic;

    signal rx_state              : rx_state_t := IDLING;
    signal pkt_info_work         : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal pkt_drop_count        : unsigned(15 downto 0) := (others => '0');
    signal pkt_drop_pulse        : std_logic := '0';
    signal fifo_overflow_sticky  : std_logic := '0';
    signal fifo_overflow_pulse   : std_logic := '0';
    signal fifo_capture_start    : std_logic := '0';
    signal fifo_write_en         : std_logic := '0';
    signal fifo_write_data       : std_logic_vector(31 downto 0) := (others => '0');
    signal fifo_commit           : std_logic := '0';
    signal fifo_rollback         : std_logic := '0';
    signal fifo_q                : std_logic_vector(31 downto 0);
    signal fifo_empty            : std_logic;
    signal fifo_full_int         : std_logic;
    signal fifo_usedw_raw        : std_logic_vector(ceil_log2_func(EXT_PLD_DEPTH_G + 1) - 1 downto 0);
    signal fifo_overflow_int     : std_logic;
    signal write_words_seen      : write_word_count_t := 0;
    signal idle_cycles           : natural range 0 to PKT_TIMEOUT_CYCLES := 0;
    signal first_write_word      : std_logic_vector(31 downto 0) := (others => '0');
    signal soft_reset_pulse      : std_logic := '0';
    signal pkt_queue_mem         : pkt_queue_mem_t := (others => SC_PKT_INFO_RESET_CONST);
    signal pkt_queue_is_internal : pkt_queue_flag_mem_t := (others => '0');
    signal pkt_queue_rd_ptr      : pkt_queue_index_t := 0;
    signal pkt_queue_wr_ptr      : pkt_queue_index_t := 0;
    signal pkt_queue_count       : natural range 0 to PKT_QUEUE_DEPTH_G := 0;
    signal enqueue_stage_mem     : enqueue_stage_mem_t := (others => SC_PKT_INFO_RESET_CONST);
    signal enqueue_stage_is_internal : enqueue_stage_flag_mem_t := (others => '0');
    signal enqueue_stage_allow_bypass : enqueue_stage_flag_mem_t := (others => '0');
    signal enqueue_stage_rd_ptr  : enqueue_stage_index_t := 0;
    signal enqueue_stage_wr_ptr  : enqueue_stage_index_t := 0;
    signal enqueue_stage_count   : natural range 0 to ENQUEUE_STAGE_DEPTH_CONST := 0;
    signal int_pkt_valid         : std_logic := '0';
    signal int_pkt_info          : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal int_pkt_is_internal   : std_logic := '0';
    signal out_pkt_valid         : std_logic := '0';
    signal out_pkt_info          : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal out_pkt_is_internal   : std_logic := '0';
    signal trailer_wait_committed: std_logic := '0';
    signal debug_enqueue_count   : unsigned(31 downto 0) := (others => '0');
    signal debug_restart_count   : unsigned(31 downto 0) := (others => '0');
    signal debug_ignored_preamble_count : unsigned(31 downto 0) := (others => '0');
    -- Per-path drop counters for debug
    signal debug_restart_drop_count     : unsigned(15 downto 0) := (others => '0');
    signal debug_ws_trailer_drop_count  : unsigned(7 downto 0) := (others => '0');
    signal debug_idle_timeout_drop_count: unsigned(7 downto 0) := (others => '0');
    signal payload_check_words   : write_word_count_t := 0;
    signal payload_space_granted : std_logic := '0';
    signal payload_space_ready   : std_logic := '1';
    signal pkt_info_is_internal  : std_logic := '0';
    signal pkt_is_read_reg       : std_logic := '1';
    signal pkt_len_is_one_reg    : std_logic := '0';
    signal pkt_has_download_words_reg : std_logic := '0';
    signal waiting_word_valid   : std_logic := '0';
    signal waiting_word_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal waiting_word_datak   : std_logic_vector(3 downto 0) := (others => '0');

    -- Local reset register to reduce fanout and routing delay from the
    -- Qsys reset controller.  The upstream r_sync_rst already provides a
    -- synchronised, deasserted-synchronously reset, so one extra register
    -- stage only adds a single cycle of reset release latency which is
    -- harmless (the link is idle during reset).
    -- Attribute keeps Quartus from merging it back into the global net.
    signal rst_local             : std_logic := '1';
    attribute preserve : boolean;
    attribute preserve of rst_local : signal is true;

    function is_sc_preamble_func (
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return (data_in(31 downto 26) = "000111" and data_in(7 downto 0) = K285_CONST and datak_in = "0001");
    end function is_sc_preamble_func;

    function is_trailer_func (
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return (data_in(7 downto 0) = K284_CONST and datak_in = "0001");
    end function is_trailer_func;

    function is_skip_func (
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return (data_in = SKIP_WORD_CONST and datak_in = "0001");
    end function is_skip_func;

    function is_idle_func (
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return (data_in = x"00000000" and datak_in = "0000");
    end function is_idle_func;

    function pkt_is_internal_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
        variable addr_v : natural;
    begin
        for idx in 15 downto 0 loop
            if (pkt_info.start_address(idx) /= '0' and pkt_info.start_address(idx) /= '1') then
                return false;
            end if;
        end loop;
        addr_v := to_integer(unsigned(pkt_info.start_address(15 downto 0)));
        return (addr_v >= HUB_CSR_BASE_ADDR_CONST and addr_v < HUB_CSR_BASE_ADDR_CONST + HUB_CSR_WINDOW_WORDS_CONST);
    end function pkt_is_internal_func;

    function addr_is_internal_func (
        addr_in : std_logic_vector(23 downto 0)
    ) return boolean is
        variable addr_v : natural;
    begin
        for idx in 15 downto 0 loop
            if (addr_in(idx) /= '0' and addr_in(idx) /= '1') then
                return false;
            end if;
        end loop;
        addr_v := to_integer(unsigned(addr_in(15 downto 0)));
        return (addr_v >= HUB_CSR_BASE_ADDR_CONST and addr_v < HUB_CSR_BASE_ADDR_CONST + HUB_CSR_WINDOW_WORDS_CONST);
    end function addr_is_internal_func;

    function next_pkt_queue_index_func (
        value_in : pkt_queue_index_t
    ) return pkt_queue_index_t is
    begin
        if (value_in = PKT_QUEUE_DEPTH_G - 1) then
            return 0;
        else
            return value_in + 1;
        end if;
    end function next_pkt_queue_index_func;

    function next_enqueue_stage_index_func (
        value_in : enqueue_stage_index_t
    ) return enqueue_stage_index_t is
    begin
        if (value_in = ENQUEUE_STAGE_DEPTH_CONST - 1) then
            return 0;
        else
            return value_in + 1;
        end if;
    end function next_enqueue_stage_index_func;

begin
    fifo_inst : entity work.sc_hub_fifo_sf
    generic map(
        WIDTH_G => 32,
        DEPTH_G => EXT_PLD_DEPTH_G
    )
    port map(
        csi_clk       => i_clk,
        rsi_reset     => i_rst,
        clear         => i_soft_reset,
        capture_start => fifo_capture_start,
        write_en      => fifo_write_en,
        write_data    => fifo_write_data,
        commit        => fifo_commit,
        rollback      => fifo_rollback,
        read_en       => i_wr_data_rdreq,
        read_data     => fifo_q,
        empty         => fifo_empty,
        full          => fifo_full_int,
        usedw         => fifo_usedw_raw,
        overflow      => fifo_overflow_int
    );

    o_wr_data_q           <= fifo_q;
    o_wr_data_empty       <= fifo_empty;
    o_pkt_in_progress     <= '1' when (rx_state /= IDLING) else '0';
    o_pkt_valid           <= out_pkt_valid;
    o_pkt_info            <= out_pkt_info;
    o_pkt_is_internal     <= out_pkt_is_internal;
    o_soft_reset_pulse    <= soft_reset_pulse;
    o_pkt_drop_count      <= std_logic_vector(pkt_drop_count);
    o_pkt_drop_pulse      <= pkt_drop_pulse;
    o_debug_drop_detail   <= std_logic_vector(debug_idle_timeout_drop_count)
                           & std_logic_vector(debug_ws_trailer_drop_count)
                           & std_logic_vector(debug_restart_drop_count);
    o_fifo_usedw          <= std_logic_vector(resize(unsigned(fifo_usedw_raw), o_fifo_usedw'length));
    o_fifo_full           <= fifo_full_int;
    o_fifo_overflow       <= fifo_overflow_sticky;
    o_fifo_overflow_pulse <= fifo_overflow_pulse;

    payload_space_ready <= '1'
        when (
            rx_state /= WAITING_WRITE_SPACE or
            payload_space_granted = '1'
        )
        else '0';

    o_download_ready <= '1'
        when (
            (rx_state = IDLING and enqueue_stage_count < ENQUEUE_STAGE_DEPTH_CONST) or
            (rx_state /= IDLING and payload_space_ready = '1')
        )
        else '0';

    -- Re-register the external reset locally to cut the long-wire fanout
    -- path from the Qsys reset controller (violation #1, -1.635 ns).
    rst_local_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            rst_local <= i_rst;
        end if;
    end process rst_local_reg;

    -- Pre-compute space check: starts evaluation during LENGTHING (1 cycle
    -- before WAITING_WRITE_SPACE) so the grant is already registered and
    -- ready when the first write data word arrives.  Fixes write packet drops
    -- when the transceiver rate adaptation deletes the idle word between
    -- LENGTH and DATA (back-to-back delivery).
    --
    -- During LENGTHING the length value sits on i_download_data(15:0); we
    -- use it directly for the space arithmetic.  The registered output is
    -- available the same cycle the state machine enters WAITING_WRITE_SPACE.
    -- During WAITING_WRITE_SPACE the check continues with the latched
    -- payload_check_words so subsequent burst words are still gated.
    payload_space_checker : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (rst_local = '1' or i_soft_reset = '1') then
                payload_space_granted <= '0';
            elsif (rx_state = LENGTHING and i_download_datak = "0000") then
                -- Pre-compute: use raw length from the bus during LENGTHING
                if (to_integer(unsigned(i_download_data(15 downto 0))) > 0 and
                    to_integer(unsigned(fifo_usedw_raw))
                        + to_integer(unsigned(i_download_data(15 downto 0)))
                        <= EXT_PLD_DEPTH_G) then
                    payload_space_granted <= '1';
                else
                    payload_space_granted <= '0';
                end if;
            elsif (rx_state = WAITING_WRITE_SPACE) then
                -- Continue monitoring with latched payload_check_words
                if (to_integer(unsigned(fifo_usedw_raw)) + payload_check_words
                        <= EXT_PLD_DEPTH_G) then
                    payload_space_granted <= '1';
                else
                    payload_space_granted <= '0';
                end if;
            else
                payload_space_granted <= '0';
            end if;
        end if;
    end process payload_space_checker;

    packet_receiver : process(i_clk)
        variable is_skip_v      : boolean;
        variable is_preamble_v  : boolean;
        variable is_trailer_v   : boolean;
        variable is_idle_v      : boolean;
        variable has_download_words_v : boolean;
        variable drop_packet_v       : boolean;
        variable commit_packet_v     : boolean;
        variable enqueue_queue_v     : boolean;
        variable enqueue_pkt_info_v : sc_pkt_info_t;
        variable enqueue_pkt_is_internal_v : std_logic;
        variable enqueue_allow_bypass_v : boolean;
        variable queue_rd_ptr_v   : pkt_queue_index_t;
        variable queue_wr_ptr_v   : pkt_queue_index_t;
        variable queue_count_v            : natural range 0 to PKT_QUEUE_DEPTH_G;
        variable enqueue_stage_rd_ptr_v   : enqueue_stage_index_t;
        variable enqueue_stage_wr_ptr_v   : enqueue_stage_index_t;
        variable enqueue_stage_count_v    : natural range 0 to ENQUEUE_STAGE_DEPTH_CONST;
        variable int_pkt_valid_v          : std_logic;
        variable int_pkt_info_v           : sc_pkt_info_t;
        variable int_pkt_is_internal_v    : std_logic;
        variable out_pkt_valid_v          : std_logic;
        variable out_pkt_info_v           : sc_pkt_info_t;
        variable out_pkt_is_internal_v    : std_logic;
        variable trailer_wait_committed_v : std_logic;
        variable pkt_info_complete_v      : sc_pkt_info_t;
    begin
        if rising_edge(i_clk) then
            if (rst_local = '1' or i_soft_reset = '1') then
                rx_state             <= IDLING;
                pkt_info_work        <= SC_PKT_INFO_RESET_CONST;
                pkt_drop_count       <= (others => '0');
                pkt_drop_pulse       <= '0';
                fifo_overflow_sticky <= '0';
                fifo_overflow_pulse  <= '0';
                fifo_capture_start   <= '0';
                fifo_write_en        <= '0';
                fifo_write_data      <= (others => '0');
                fifo_commit          <= '0';
                fifo_rollback        <= '0';
                write_words_seen     <= 0;
                idle_cycles          <= 0;
                first_write_word     <= (others => '0');
                soft_reset_pulse     <= '0';
                pkt_queue_mem        <= (others => SC_PKT_INFO_RESET_CONST);
                pkt_queue_is_internal <= (others => '0');
                pkt_queue_rd_ptr     <= 0;
                pkt_queue_wr_ptr     <= 0;
                pkt_queue_count      <= 0;
                enqueue_stage_mem    <= (others => SC_PKT_INFO_RESET_CONST);
                enqueue_stage_is_internal <= (others => '0');
                enqueue_stage_allow_bypass <= (others => '0');
                enqueue_stage_rd_ptr <= 0;
                enqueue_stage_wr_ptr <= 0;
                enqueue_stage_count  <= 0;
                int_pkt_valid        <= '0';
                int_pkt_info         <= SC_PKT_INFO_RESET_CONST;
                int_pkt_is_internal  <= '0';
                out_pkt_valid        <= '0';
                out_pkt_info         <= SC_PKT_INFO_RESET_CONST;
                out_pkt_is_internal  <= '0';
                debug_enqueue_count        <= (others => '0');
                debug_restart_count        <= (others => '0');
                debug_ignored_preamble_count <= (others => '0');
                debug_restart_drop_count   <= (others => '0');
                debug_ws_trailer_drop_count <= (others => '0');
                debug_idle_timeout_drop_count <= (others => '0');
                trailer_wait_committed     <= '0';
                payload_check_words        <= 0;
                pkt_info_is_internal       <= '0';
                pkt_is_read_reg            <= '1';
                pkt_len_is_one_reg         <= '0';
                pkt_has_download_words_reg <= '0';
                waiting_word_valid       <= '0';
                waiting_word_data        <= (others => '0');
                waiting_word_datak       <= (others => '0');
            else
                pkt_drop_pulse      <= '0';
                fifo_overflow_pulse <= '0';
                fifo_capture_start  <= '0';
                fifo_write_en       <= '0';
                fifo_write_data     <= (others => '0');
                fifo_commit         <= '0';
                fifo_rollback       <= '0';
                soft_reset_pulse    <= '0';
                enqueue_queue_v     := false;
                enqueue_pkt_info_v  := SC_PKT_INFO_RESET_CONST;
                enqueue_pkt_is_internal_v := '0';
                enqueue_allow_bypass_v := true;
                queue_rd_ptr_v      := pkt_queue_rd_ptr;
                queue_wr_ptr_v      := pkt_queue_wr_ptr;
                queue_count_v       := pkt_queue_count;
                enqueue_stage_rd_ptr_v := enqueue_stage_rd_ptr;
                enqueue_stage_wr_ptr_v := enqueue_stage_wr_ptr;
                enqueue_stage_count_v  := enqueue_stage_count;
                int_pkt_valid_v          := int_pkt_valid;
                int_pkt_info_v           := int_pkt_info;
                int_pkt_is_internal_v    := int_pkt_is_internal;
                out_pkt_valid_v          := out_pkt_valid;
                out_pkt_info_v           := out_pkt_info;
                out_pkt_is_internal_v    := out_pkt_is_internal;
                trailer_wait_committed_v := trailer_wait_committed;
                if (out_pkt_valid = '1' and i_allow_new_pkt = '1') then
                    out_pkt_valid_v       := '0';
                    out_pkt_info_v        := SC_PKT_INFO_RESET_CONST;
                    out_pkt_is_internal_v := '0';
                end if;

                is_skip_v            := is_skip_func(i_download_data, i_download_datak);
                is_preamble_v        := is_sc_preamble_func(i_download_data, i_download_datak);
                is_trailer_v         := is_trailer_func(i_download_data, i_download_datak);
                is_idle_v            := is_idle_func(i_download_data, i_download_datak);
                has_download_words_v := (pkt_has_download_words_reg = '1');
                drop_packet_v        := false;
                commit_packet_v      := false;

                if (fifo_overflow_int = '1') then
                    fifo_overflow_sticky <= '1';
                    fifo_overflow_pulse  <= '1';
                end if;

                if (enqueue_stage_count /= 0) then
                    if (
                        enqueue_stage_is_internal(enqueue_stage_rd_ptr) = '1' and
                        enqueue_stage_allow_bypass(enqueue_stage_rd_ptr) = '1' and
                        int_pkt_valid_v = '0'
                    ) then
                        int_pkt_info_v        := enqueue_stage_mem(enqueue_stage_rd_ptr);
                        int_pkt_is_internal_v := '1';
                        int_pkt_valid_v       := '1';
                        enqueue_stage_rd_ptr_v := next_enqueue_stage_index_func(enqueue_stage_rd_ptr_v);
                        enqueue_stage_count_v  := enqueue_stage_count_v - 1;
                    elsif (queue_count_v < PKT_QUEUE_DEPTH_G) then
                        pkt_queue_mem(queue_wr_ptr_v) <= enqueue_stage_mem(enqueue_stage_rd_ptr);
                        pkt_queue_is_internal(queue_wr_ptr_v) <= enqueue_stage_is_internal(enqueue_stage_rd_ptr);
                        queue_wr_ptr_v := next_pkt_queue_index_func(queue_wr_ptr_v);
                        queue_count_v  := queue_count_v + 1;
                        enqueue_stage_rd_ptr_v := next_enqueue_stage_index_func(enqueue_stage_rd_ptr_v);
                        enqueue_stage_count_v  := enqueue_stage_count_v - 1;
                    end if;
                end if;

                if (rx_state /= IDLING) then
                    if (
                        is_skip_v = true or
                        (is_idle_v = true and rx_state /= WRITING_DATA)
                    ) then
                        if (idle_cycles < PKT_TIMEOUT_CYCLES) then
                            idle_cycles <= idle_cycles + 1;
                        end if;
                    else
                        idle_cycles <= 0;
                    end if;

                    if (idle_cycles = PKT_TIMEOUT_CYCLES) then
                        drop_packet_v := true;
                        debug_idle_timeout_drop_count <= debug_idle_timeout_drop_count + 1;
                    end if;
                else
                    idle_cycles <= 0;
                end if;

                if (rx_state /= IDLING and is_preamble_v = true and i_accept_new_pkt = '1') then
                    debug_restart_count <= sat_inc32_func(debug_restart_count);
                    if (pkt_has_download_words_reg = '1') then
                        fifo_rollback  <= '1';
                        pkt_drop_pulse <= '1';
                        pkt_drop_count <= sat_inc16_func(pkt_drop_count);
                        debug_restart_drop_count <= sat_inc16_func(debug_restart_drop_count);
                    end if;
                    pkt_info_work.sc_type        <= i_download_data(25 downto 24);
                    pkt_info_work.fpga_id        <= i_download_data(23 downto 8);
                    pkt_info_work.start_address  <= (others => '0');
                    pkt_info_work.mask_m         <= '0';
                    pkt_info_work.mask_s         <= '0';
                    pkt_info_work.mask_t         <= '0';
                    pkt_info_work.mask_r         <= '0';
                    pkt_info_work.rw_length      <= (others => '0');
                    pkt_info_work.order_mode     <= SC_ORDER_RELAXED_CONST;
                    pkt_info_work.order_domain   <= (others => '0');
                    pkt_info_work.order_epoch    <= (others => '0');
                    pkt_info_work.order_scope    <= (others => '0');
                    pkt_info_work.atomic_flag    <= '0';
                    pkt_info_work.atomic_mask    <= (others => '0');
                    pkt_info_work.atomic_data    <= (others => '0');
                    pkt_is_read_reg             <= not i_download_data(24);
                    pkt_has_download_words_reg  <= i_download_data(24);
                    fifo_capture_start           <= '1';
                    write_words_seen            <= 0;
                    payload_check_words         <= 0;
                    idle_cycles                 <= 0;
                    trailer_wait_committed_v    := '0';
                    rx_state                    <= ADDRING;
                else
                    case rx_state is
                        when IDLING =>
                            if (enqueue_stage_count < ENQUEUE_STAGE_DEPTH_CONST and is_preamble_v = true) then
                                pkt_info_work.sc_type       <= i_download_data(25 downto 24);
                                pkt_info_work.fpga_id       <= i_download_data(23 downto 8);
                                pkt_info_work.start_address <= (others => '0');
                                pkt_info_work.mask_m        <= '0';
                                pkt_info_work.mask_s        <= '0';
                                pkt_info_work.mask_t        <= '0';
                                pkt_info_work.mask_r        <= '0';
                                pkt_info_work.rw_length     <= (others => '0');
                                pkt_info_work.order_mode    <= SC_ORDER_RELAXED_CONST;
                                pkt_info_work.order_domain  <= (others => '0');
                                pkt_info_work.order_epoch   <= (others => '0');
                                pkt_info_work.order_scope   <= (others => '0');
                                pkt_info_work.atomic_flag   <= '0';
                                pkt_info_work.atomic_mask   <= (others => '0');
                                pkt_info_work.atomic_data   <= (others => '0');
                                pkt_is_read_reg             <= not i_download_data(24);
                                pkt_has_download_words_reg  <= i_download_data(24);
                                fifo_capture_start          <= '1';
                                payload_check_words         <= 0;
                                pkt_info_is_internal        <= '0';
                                trailer_wait_committed_v    := '0';
                                rx_state                    <= ADDRING;
                            elsif (is_preamble_v = true) then
                                debug_ignored_preamble_count <= sat_inc32_func(debug_ignored_preamble_count);
                            end if;

                        when ADDRING =>
                            if (drop_packet_v = true) then
                                fifo_rollback <= '1';
                                rx_state      <= IDLING;
                            elsif (is_skip_v = false) then
                                if (is_trailer_v = true or is_preamble_v = true) then
                                    drop_packet_v := true;
                                else
                                    if (i_download_data(31 downto 30) = SC_ORDER_RESERVED_CONST) then
                                        pkt_info_work.order_mode <= SC_ORDER_RELAXED_CONST;
                                    else
                                        pkt_info_work.order_mode <= i_download_data(31 downto 30);
                                    end if;
                                    pkt_info_work.start_address <= i_download_data(23 downto 0);
                                    pkt_info_work.atomic_flag   <= i_download_data(28);
                                    pkt_info_work.mask_m        <= i_download_data(27);
                                    pkt_info_work.mask_s        <= i_download_data(26);
                                    pkt_info_work.mask_t        <= i_download_data(25);
                                    pkt_info_work.mask_r        <= i_download_data(24);
                                    pkt_has_download_words_reg  <= (not pkt_is_read_reg) or i_download_data(28);
                                    if (addr_is_internal_func(i_download_data(23 downto 0))) then
                                        pkt_info_is_internal <= '1';
                                    else
                                        pkt_info_is_internal <= '0';
                                    end if;
                                    rx_state                    <= LENGTHING;
                                end if;
                            end if;

                        when LENGTHING =>
                            if (drop_packet_v = true) then
                                fifo_rollback <= '1';
                                rx_state      <= IDLING;
                            elsif (is_skip_v = false) then
                                pkt_info_complete_v              := pkt_info_work;
                                pkt_info_complete_v.rw_length    := i_download_data(15 downto 0);
                                pkt_info_complete_v.order_domain := i_download_data(31 downto 28);
                                pkt_info_complete_v.order_epoch  := i_download_data(27 downto 20);
                                pkt_info_work.rw_length    <= i_download_data(15 downto 0);
                                pkt_info_work.order_domain <= i_download_data(31 downto 28);
                                pkt_info_work.order_epoch  <= i_download_data(27 downto 20);
                                if (unsigned(i_download_data(15 downto 0)) = 1) then
                                    pkt_len_is_one_reg <= '1';
                                else
                                    pkt_len_is_one_reg <= '0';
                                end if;
                                if (i_download_data(19 downto 18) = "11") then
                                    pkt_info_complete_v.order_scope := "00";
                                    pkt_info_work.order_scope <= "00";
                                else
                                    pkt_info_complete_v.order_scope := i_download_data(19 downto 18);
                                    pkt_info_work.order_scope <= i_download_data(19 downto 18);
                                end if;
                                if (unsigned(i_download_data(15 downto 0)) > MAX_BURST_G) then
                                    drop_packet_v := true;
                                elsif (pkt_info_work.atomic_flag = '1') then
                                    rx_state <= ATOMIC_MASKING;
                                elsif (has_download_words_v = false) then
                                    if (enqueue_stage_count_v < ENQUEUE_STAGE_DEPTH_CONST) then
                                        enqueue_pkt_info_v        := pkt_info_complete_v;
                                        enqueue_pkt_is_internal_v := pkt_info_is_internal;
                                        enqueue_allow_bypass_v    := false;
                                        enqueue_queue_v           := true;
                                        trailer_wait_committed_v  := '1';
                                        rx_state                  <= WAITING_TRAILER;
                                    else
                                        drop_packet_v := true;
                                    end if;
                                elsif (unsigned(i_download_data(15 downto 0)) = 0) then
                                    rx_state <= WAITING_TRAILER;
                                else
                                    payload_check_words <= to_integer(unsigned(i_download_data(15 downto 0)));
                                    waiting_word_valid  <= '0';
                                    waiting_word_data   <= (others => '0');
                                    waiting_word_datak  <= (others => '0');
                                    rx_state <= WAITING_WRITE_SPACE;
                                end if;
                            end if;

                        when WAITING_WRITE_SPACE =>
                            if (drop_packet_v = true) then
                                fifo_rollback      <= '1';
                                waiting_word_valid <= '0';
                                rx_state           <= IDLING;
                            elsif (payload_space_granted = '0') then
                                if (is_skip_v = true or is_idle_v = true) then
                                    null;
                                elsif (is_trailer_v = true or is_preamble_v = true) then
                                    drop_packet_v := true;
                                    debug_ws_trailer_drop_count <= debug_ws_trailer_drop_count + 1;
                                elsif (waiting_word_valid = '0') then
                                    waiting_word_valid <= '1';
                                    waiting_word_data  <= i_download_data;
                                    waiting_word_datak <= i_download_datak;
                                elsif (i_download_data = waiting_word_data and i_download_datak = waiting_word_datak) then
                                    -- Upstream is holding the same non-idle word stable across the
                                    -- backpressured window (valid Avalon-style handshake). Ignore
                                    -- it; granted-high will consume the already-latched copy.
                                    null;
                                else
                                    drop_packet_v := true;
                                    debug_ws_trailer_drop_count <= debug_ws_trailer_drop_count + 1;
                                end if;
                            else
                                if (waiting_word_valid = '1') then
                                    fifo_write_en      <= '1';
                                    fifo_write_data    <= waiting_word_data;
                                    first_write_word   <= waiting_word_data;
                                    waiting_word_valid <= '0';
                                elsif (is_skip_v = true) then
                                    null;
                                elsif (is_trailer_v = true or is_preamble_v = true) then
                                    drop_packet_v := true;
                                    debug_ws_trailer_drop_count <= debug_ws_trailer_drop_count + 1;
                                else
                                    fifo_write_en    <= '1';
                                    fifo_write_data  <= i_download_data;
                                    first_write_word <= i_download_data;
                                end if;

                                if (fifo_write_en = '1' or waiting_word_valid = '1' or (is_skip_v = false and is_trailer_v = false and is_preamble_v = false)) then
                                    if (pkt_len_is_one_reg = '1') then
                                        rx_state <= WAITING_TRAILER;
                                    else
                                        rx_state <= WRITING_DATA;
                                    end if;

                                    write_words_seen <= 1;
                                end if;
                            end if;
                        when ATOMIC_MASKING =>
                            if (drop_packet_v = true) then
                                fifo_rollback <= '1';
                                rx_state      <= IDLING;
                            elsif (is_skip_v = false) then
                                if (is_trailer_v = true or is_preamble_v = true) then
                                    drop_packet_v := true;
                                else
                                    pkt_info_work.atomic_mask <= i_download_data;
                                    rx_state                 <= ATOMIC_DATAING;
                                end if;
                            end if;

                        when ATOMIC_DATAING =>
                            if (drop_packet_v = true) then
                                fifo_rollback <= '1';
                                rx_state      <= IDLING;
                            elsif (is_skip_v = false) then
                                if (is_trailer_v = true or is_preamble_v = true) then
                                    drop_packet_v := true;
                                else
                                    pkt_info_work.atomic_data <= i_download_data;
                                    rx_state                 <= WAITING_TRAILER;
                                end if;
                            end if;

                        when WRITING_DATA =>
                            if (drop_packet_v = true) then
                                fifo_rollback <= '1';
                                rx_state      <= IDLING;
                            elsif (is_skip_v = true) then
                                null;
                            else
                                if (is_trailer_v = true) then
                                    drop_packet_v := true;
                                elsif (write_words_seen < to_integer(unsigned(pkt_info_work.rw_length))) then
                                    fifo_write_en   <= '1';
                                    fifo_write_data <= i_download_data;
                                    if (write_words_seen = 0) then
                                        first_write_word <= i_download_data;
                                    end if;
                                    if (fifo_full_int = '1') then
                                        drop_packet_v := true;
                                    end if;

                                    if (write_words_seen + 1 >= to_integer(unsigned(pkt_info_work.rw_length))) then
                                        rx_state <= WAITING_TRAILER;
                                    end if;

                                    write_words_seen <= write_words_seen + 1;
                                else
                                    drop_packet_v := true;
                                end if;
                            end if;

                        when WAITING_TRAILER =>
                            if (drop_packet_v = true) then
                                fifo_rollback <= '1';
                                rx_state      <= IDLING;
                            elsif (is_skip_v = false) then
                                if (is_trailer_v = true) then
                                    commit_packet_v := true;
                                elsif (is_idle_v = true) then
                                    null;
                                else
                                    drop_packet_v := true;
                                end if;
                            end if;
                    end case;

                    if (drop_packet_v = true) then
                        fifo_rollback  <= '1';
                        pkt_drop_pulse <= '1';
                        pkt_drop_count <= sat_inc16_func(pkt_drop_count);
                        rx_state         <= IDLING;
                        trailer_wait_committed_v := '0';
                        waiting_word_valid <= '0';
                        waiting_word_data  <= (others => '0');
                        waiting_word_datak <= (others => '0');
                    elsif (commit_packet_v = true) then
                        if (trailer_wait_committed_v = '1') then
                            rx_state                 <= IDLING;
                            write_words_seen         <= 0;
                            payload_check_words      <= 0;
                            trailer_wait_committed_v := '0';
                        elsif (
                            pkt_has_download_words_reg = '1' and
                            pkt_is_read_reg = '0' and
                            pkt_info_work.atomic_flag = '0' and
                            pkt_len_is_one_reg = '1' and
                            to_integer(unsigned(pkt_info_work.start_address(15 downto 0))) = HUB_CSR_BASE_ADDR_CONST + HUB_CSR_WO_CTRL_CONST and
                            first_write_word(2) = '1'
                        ) then
                            fifo_rollback    <= '1';
                            soft_reset_pulse <= '1';
                        elsif (pkt_has_download_words_reg = '0') then
                            if (enqueue_stage_count_v < ENQUEUE_STAGE_DEPTH_CONST) then
                                fifo_commit        <= '1';
                                enqueue_pkt_info_v := pkt_info_work;
                                enqueue_pkt_is_internal_v := pkt_info_is_internal;
                                enqueue_queue_v    := true;
                            else
                                pkt_drop_pulse <= '1';
                                pkt_drop_count <= sat_inc16_func(pkt_drop_count);
                            end if;
                        elsif (
                            pkt_info_is_internal = '1' and
                            pkt_is_read_reg = '0' and
                            pkt_info_work.atomic_flag = '0' and
                            pkt_len_is_one_reg = '1'
                        ) then
                            if (enqueue_stage_count_v < ENQUEUE_STAGE_DEPTH_CONST) then
                                fifo_rollback                <= '1';
                                enqueue_pkt_info_v           := pkt_info_work;
                                enqueue_pkt_info_v.atomic_data := first_write_word;
                                enqueue_pkt_is_internal_v    := pkt_info_is_internal;
                                enqueue_queue_v              := true;
                            else
                                fifo_rollback  <= '1';
                                pkt_drop_pulse <= '1';
                                pkt_drop_count <= sat_inc16_func(pkt_drop_count);
                            end if;
                        elsif (enqueue_stage_count_v < ENQUEUE_STAGE_DEPTH_CONST) then
                            fifo_commit        <= '1';
                            enqueue_pkt_info_v := pkt_info_work;
                            enqueue_pkt_is_internal_v := pkt_info_is_internal;
                            enqueue_queue_v    := true;
                        else
                            fifo_rollback  <= '1';
                            pkt_drop_pulse <= '1';
                            pkt_drop_count <= sat_inc16_func(pkt_drop_count);
                        end if;
                        rx_state         <= IDLING;
                        payload_check_words <= 0;
                        waiting_word_valid <= '0';
                        waiting_word_data  <= (others => '0');
                        waiting_word_datak <= (others => '0');
                    end if;

                    if (enqueue_queue_v = true) then
                        debug_enqueue_count <= sat_inc32_func(debug_enqueue_count);
                        if (enqueue_stage_count_v < ENQUEUE_STAGE_DEPTH_CONST) then
                            enqueue_stage_mem(enqueue_stage_wr_ptr_v) <= enqueue_pkt_info_v;
                            enqueue_stage_is_internal(enqueue_stage_wr_ptr_v) <= enqueue_pkt_is_internal_v;
                            if (enqueue_allow_bypass_v) then
                                enqueue_stage_allow_bypass(enqueue_stage_wr_ptr_v) <= '1';
                            else
                                enqueue_stage_allow_bypass(enqueue_stage_wr_ptr_v) <= '0';
                            end if;
                            enqueue_stage_wr_ptr_v := next_enqueue_stage_index_func(enqueue_stage_wr_ptr_v);
                            enqueue_stage_count_v  := enqueue_stage_count_v + 1;
                        end if;
                    end if;

                end if;

                if (out_pkt_valid_v = '0') then
                    -- Refill the publish head only from packets that were already
                    -- buffered before this cycle. Newly captured packets wait one
                    -- cycle, which breaks the RX-state to publish-head timing path.
                    if (int_pkt_valid = '1') then
                        out_pkt_valid_v       := '1';
                        out_pkt_info_v        := int_pkt_info;
                        out_pkt_is_internal_v := int_pkt_is_internal;
                        int_pkt_valid_v       := '0';
                        int_pkt_info_v        := SC_PKT_INFO_RESET_CONST;
                        int_pkt_is_internal_v := '0';
                    elsif (pkt_queue_count /= 0) then
                        out_pkt_valid_v       := '1';
                        out_pkt_info_v        := pkt_queue_mem(pkt_queue_rd_ptr);
                        out_pkt_is_internal_v := pkt_queue_is_internal(pkt_queue_rd_ptr);
                        queue_rd_ptr_v        := next_pkt_queue_index_func(pkt_queue_rd_ptr);
                        queue_count_v         := queue_count_v - 1;
                    end if;
                end if;

                pkt_queue_rd_ptr <= queue_rd_ptr_v;
                pkt_queue_wr_ptr <= queue_wr_ptr_v;
                pkt_queue_count  <= queue_count_v;
                enqueue_stage_rd_ptr <= enqueue_stage_rd_ptr_v;
                enqueue_stage_wr_ptr <= enqueue_stage_wr_ptr_v;
                enqueue_stage_count  <= enqueue_stage_count_v;
                int_pkt_valid    <= int_pkt_valid_v;
                int_pkt_info     <= int_pkt_info_v;
                int_pkt_is_internal <= int_pkt_is_internal_v;
                out_pkt_valid    <= out_pkt_valid_v;
                out_pkt_info     <= out_pkt_info_v;
                out_pkt_is_internal <= out_pkt_is_internal_v;
                trailer_wait_committed <= trailer_wait_committed_v;
            end if;
        end if;
    end process packet_receiver;
end architecture rtl;
