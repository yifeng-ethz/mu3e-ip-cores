-- File name: sc_hub_axi4_core.vhd
-- Author: OpenAI Codex
-- =======================================
-- Version : 26.6.9
-- Date    : 20260414
-- Change  : Release-align the AXI4 core to v26.6.9 while keeping the shared
--           protocol metadata and CSR identity defaults consistent with the
--           packaged release.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_axi4_core is
    generic(
        DEBUG_G                    : natural := 1;
        OOO_ENABLE_G               : boolean := true;
        ORD_ENABLE_G               : boolean := true;
        ATOMIC_ENABLE_G            : boolean := true;
        HUB_CAP_ENABLE_G           : boolean := true;
        OOO_SLOT_COUNT_G           : positive := 4;
        OUTSTANDING_INT_RESERVED_G : positive := 2;
        -- Identity generics (standard CSR header at words 0-1)
        IP_UID_G                   : natural := 16#53434842#; -- ASCII "SCHB"
        VERSION_MAJOR_G            : natural := 26;
        VERSION_MINOR_G            : natural := 6;
        VERSION_PATCH_G            : natural := 9;
        BUILD_G                    : natural := 16#0414#;
        VERSION_DATE_G             : natural := 16#20260414#;
        VERSION_GIT_G              : natural := 0;
        INSTANCE_ID_G              : natural := 0
    );
    port(
        i_clk                    : in  std_logic;
        i_rst                    : in  std_logic;
        i_pkt_valid              : in  std_logic;
        i_pkt_info               : in  sc_pkt_info_t;
        o_rx_ready               : out std_logic;
        o_soft_reset_pulse       : out std_logic;
        o_wr_data_rdreq          : out std_logic;
        i_wr_data_q              : in  std_logic_vector(31 downto 0);
        i_wr_data_empty          : in  std_logic;
        i_pkt_drop_count         : in  std_logic_vector(15 downto 0);
        i_pkt_drop_pulse         : in  std_logic;
        i_dl_fifo_usedw          : in  std_logic_vector(9 downto 0);
        i_dl_fifo_full           : in  std_logic;
        i_dl_fifo_overflow       : in  std_logic;
        i_dl_fifo_overflow_pulse : in  std_logic;
        i_bp_usedw               : in  std_logic_vector(ceil_log2_func(DEFAULT_BP_FIFO_DEPTH_CONST + 1) - 1 downto 0);
        i_bp_full                : in  std_logic;
        i_bp_overflow            : in  std_logic;
        i_bp_overflow_pulse      : in  std_logic;
        i_bp_pkt_count           : in  std_logic_vector(ceil_log2_func(DEFAULT_BP_FIFO_DEPTH_CONST + 1) - 1 downto 0);
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
        o_bus_ooo_enable         : out std_logic;
        o_bus_rd_cmd_valid       : out std_logic;
        o_bus_rd_cmd_address     : out std_logic_vector(17 downto 0);
        o_bus_rd_cmd_length      : out std_logic_vector(15 downto 0);
        o_bus_rd_cmd_nonincrement : out std_logic;
        o_bus_rd_cmd_tag         : out std_logic_vector(3 downto 0);
        o_bus_rd_cmd_lock        : out std_logic;
        i_bus_rd_cmd_ready       : in  std_logic;
        i_bus_rd_data_valid      : in  std_logic;
        i_bus_rd_data            : in  std_logic_vector(31 downto 0);
        i_bus_rd_data_tag        : in  std_logic_vector(3 downto 0);
        i_bus_rd_done            : in  std_logic;
        i_bus_rd_done_tag        : in  std_logic_vector(3 downto 0);
        i_bus_rd_response        : in  std_logic_vector(1 downto 0);
        i_bus_rd_timeout_pulse   : in  std_logic;
        o_bus_wr_cmd_valid       : out std_logic;
        o_bus_wr_cmd_address     : out std_logic_vector(17 downto 0);
        o_bus_wr_cmd_length      : out std_logic_vector(15 downto 0);
        o_bus_wr_cmd_nonincrement : out std_logic;
        o_bus_wr_cmd_lock        : out std_logic;
        i_bus_wr_cmd_ready       : in  std_logic;
        o_bus_wr_data_valid      : out std_logic;
        o_bus_wr_data            : out std_logic_vector(31 downto 0);
        i_bus_wr_data_ready      : in  std_logic;
        i_bus_wr_done            : in  std_logic;
        i_bus_wr_response        : in  std_logic_vector(1 downto 0);
        i_bus_wr_timeout_pulse   : in  std_logic;
        i_bus_busy               : in  std_logic
    );
end entity sc_hub_axi4_core;

architecture rtl of sc_hub_axi4_core is
    type ext_slot_state_t is (SLOT_FREE, SLOT_WAIT_ISSUE, SLOT_WAIT_DATA, SLOT_READY);
    type tx_state_t is (TX_IDLE, TX_SELECTING, TX_PRIMING, TX_STREAMING, TX_WAIT_DONE);
    type tx_source_t is (TX_SRC_NONE, TX_SRC_EXT_READ, TX_SRC_INT_READ, TX_SRC_WRITE);
    type write_state_t is (
        WR_IDLE,
        WR_INT_DRAINING,
        WR_INT_COMMIT,
        WR_EXT_WAIT_CMD,
        WR_EXT_RUNNING,
        WR_ATOMIC_RD_WAIT_CMD,
        WR_ATOMIC_RD_WAIT_DATA,
        WR_ATOMIC_WR_WAIT_CMD,
        WR_ATOMIC_WR_RUNNING
    );
    type ext_slot_state_array_t is array (natural range <>) of ext_slot_state_t;
    type slot_data_array_t is array (natural range <>) of std_logic_vector(31 downto 0);
    type slot_addr_array_t is array (natural range <>) of natural range 0 to MAX_BURST_WORDS_CONST - 1;
    type slot_pkt_info_array_t is array (natural range <>) of sc_pkt_info_t;
    type slot_rsp_array_t is array (natural range <>) of std_logic_vector(1 downto 0);
    type slot_unsigned16_array_t is array (natural range <>) of unsigned(15 downto 0);
    type slot_unsigned8_array_t is array (natural range <>) of unsigned(7 downto 0);

    -- Quartus Prime 18.1 Standard Edition does not ship to_hstring in its
    -- VHDL-2008 std_logic_1164 package, so the `report ... to_hstring(...)`
    -- debug statements below need a locally defined helper. Report bodies
    -- are simulation-only, so this function is stripped at synthesis.
    function to_hstring(value : std_logic_vector) return string is
        constant NIBBLES_C : positive := (value'length + 3) / 4;
        variable padded_v  : std_logic_vector(NIBBLES_C * 4 - 1 downto 0) := (others => '0');
        variable nibble_v  : std_logic_vector(3 downto 0);
        variable ret_v     : string(1 to NIBBLES_C);
    begin
        padded_v(value'length - 1 downto 0) := value;
        for i in 0 to NIBBLES_C - 1 loop
            nibble_v := padded_v((NIBBLES_C - 1 - i) * 4 + 3 downto (NIBBLES_C - 1 - i) * 4);
            case nibble_v is
                when "0000" => ret_v(i + 1) := '0';
                when "0001" => ret_v(i + 1) := '1';
                when "0010" => ret_v(i + 1) := '2';
                when "0011" => ret_v(i + 1) := '3';
                when "0100" => ret_v(i + 1) := '4';
                when "0101" => ret_v(i + 1) := '5';
                when "0110" => ret_v(i + 1) := '6';
                when "0111" => ret_v(i + 1) := '7';
                when "1000" => ret_v(i + 1) := '8';
                when "1001" => ret_v(i + 1) := '9';
                when "1010" => ret_v(i + 1) := 'A';
                when "1011" => ret_v(i + 1) := 'B';
                when "1100" => ret_v(i + 1) := 'C';
                when "1101" => ret_v(i + 1) := 'D';
                when "1110" => ret_v(i + 1) := 'E';
                when "1111" => ret_v(i + 1) := 'F';
                when others => ret_v(i + 1) := 'X';
            end case;
        end loop;
        return ret_v;
    end function;

    constant PAYLOAD_ADDR_WIDTH_CONST : positive := ceil_log2_func(MAX_BURST_WORDS_CONST);

    signal ext_slot_state          : ext_slot_state_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => SLOT_FREE);
    signal ext_slot_pkt_info       : slot_pkt_info_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => SC_PKT_INFO_RESET_CONST);
    signal ext_slot_reply_suppress : std_logic_vector(0 to OOO_SLOT_COUNT_G - 1) := (others => '0');
    signal ext_slot_response       : slot_rsp_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => SC_RSP_OK_CONST);
    signal ext_slot_words_received : slot_unsigned16_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => (others => '0'));
    signal ext_slot_issue_seq      : slot_unsigned8_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => (others => '0'));
    signal ext_slot_complete_seq   : slot_unsigned8_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => (others => '0'));
    signal ext_slot_payload_q      : slot_data_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => (others => '0'));
    signal ext_slot_payload_wr_en  : std_logic_vector(0 to OOO_SLOT_COUNT_G - 1) := (others => '0');
    signal ext_slot_payload_wr_addr: slot_addr_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => 0);
    signal ext_slot_payload_wr_data: slot_data_array_t(0 to OOO_SLOT_COUNT_G - 1) := (others => (others => '0'));

    signal int_slot_valid          : std_logic_vector(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => '0');
    signal int_slot_pkt_info       : slot_pkt_info_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => SC_PKT_INFO_RESET_CONST);
    signal int_slot_reply_suppress : std_logic_vector(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => '0');
    signal int_slot_response       : slot_rsp_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => SC_RSP_OK_CONST);
    signal int_slot_issue_seq      : slot_unsigned8_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => (others => '0'));
    signal int_slot_complete_seq   : slot_unsigned8_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => (others => '0'));
    signal int_slot_payload_q      : slot_data_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => (others => '0'));
    signal int_slot_payload_wr_en  : std_logic_vector(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => '0');
    signal int_slot_payload_wr_addr: slot_addr_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => 0);
    signal int_slot_payload_wr_data: slot_data_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1) := (others => (others => '0'));
    signal int_fill_active         : std_logic := '0';
    signal int_fill_slot           : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1 := 0;
    signal int_fill_pkt_info       : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal int_fill_csr_offset     : natural range 0 to HUB_CSR_WINDOW_WORDS_CONST + MAX_BURST_WORDS_CONST - 1 := 0;
    signal int_fill_index          : natural range 0 to MAX_BURST_WORDS_CONST - 1 := 0;
    signal int_fill_wr_pending     : std_logic := '0';
    signal int_fill_wr_slot        : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1 := 0;
    signal int_fill_wr_addr        : natural range 0 to MAX_BURST_WORDS_CONST - 1 := 0;
    signal int_fill_wr_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal int_fill_wr_last        : std_logic := '0';

    signal rd_issue_valid          : std_logic := '0';
    signal rd_issue_slot           : natural range 0 to OOO_SLOT_COUNT_G - 1 := 0;
    signal rd_issue_live           : std_logic := '0';
    signal rd_cmd_pending_valid    : std_logic := '0';
    signal rd_cmd_pending_slot     : natural range 0 to OOO_SLOT_COUNT_G - 1 := 0;
    signal rd_cmd_pending_live     : std_logic := '0';

    signal tx_state                : tx_state_t := TX_IDLE;
    signal tx_source               : tx_source_t := TX_SRC_NONE;
    signal tx_slot_index           : natural := 0;
    signal tx_word_index           : unsigned(15 downto 0) := (others => '0');
    signal tx_payload_rd_addr      : natural range 0 to MAX_BURST_WORDS_CONST - 1 := 0;
    signal tx_launch_info          : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal tx_launch_response      : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal tx_launch_has_data      : std_logic := '0';
    signal tx_launch_suppress      : std_logic := '0';
    signal tx_reply_info_reg       : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal tx_reply_response_reg   : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal tx_reply_has_data_reg   : std_logic := '0';
    signal tx_reply_suppress_reg   : std_logic := '0';
    signal tx_reply_start_pulse    : std_logic := '0';
    signal tx_ooo_int_ready_valid  : std_logic := '0';
    signal tx_ooo_int_ready_slot   : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1 := 0;
    signal tx_ooo_int_ready_seq    : unsigned(7 downto 0) := (others => '0');
    signal tx_ooo_ext_ready_valid  : std_logic := '0';
    signal tx_ooo_ext_ready_slot   : natural range 0 to OOO_SLOT_COUNT_G - 1 := 0;
    signal tx_ooo_ext_ready_seq    : unsigned(7 downto 0) := (others => '0');
    signal tx_issue_int_ready_valid: std_logic := '0';
    signal tx_issue_int_ready_slot : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1 := 0;
    signal tx_issue_int_ready_seq  : unsigned(7 downto 0) := (others => '0');
    signal tx_issue_ext_ready_valid: std_logic := '0';
    signal tx_issue_ext_ready_slot : natural range 0 to OOO_SLOT_COUNT_G - 1 := 0;
    signal tx_issue_ext_ready_seq  : unsigned(7 downto 0) := (others => '0');
    signal tx_ext_words_remaining  : unsigned(15 downto 0) := (others => '0');
    signal tx_words_remaining      : unsigned(15 downto 0) := (others => '0');
    signal tx_ext_word_present     : std_logic := '0';

    signal write_state             : write_state_t := WR_IDLE;
    signal write_pkt_info          : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal write_reply_info        : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal write_reply_suppress    : std_logic := '0';
    signal write_is_internal       : std_logic := '0';
    signal write_csr_offset        : natural range 0 to HUB_CSR_WINDOW_WORDS_CONST - 1 := 0;
    signal write_csr_word          : std_logic_vector(31 downto 0) := (others => '0');
    signal write_issue_seq         : unsigned(7 downto 0) := (others => '0');
    signal write_complete_seq      : unsigned(7 downto 0) := (others => '0');
    signal write_response_reg      : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal write_drain_remaining   : unsigned(15 downto 0) := (others => '0');
    signal write_stream_index      : unsigned(15 downto 0) := (others => '0');
    signal write_ignore_drain      : std_logic := '0';
    signal wr_data_valid_reg       : std_logic := '0';
    signal wr_data_word_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal wr_data_reload_pending  : std_logic := '0';
    signal write_reply_pending     : std_logic := '0';
    signal write_reply_has_data    : std_logic := '0';
    signal write_reply_data_word   : std_logic_vector(31 downto 0) := (others => '0');
    signal atomic_read_data_reg    : std_logic_vector(31 downto 0) := (others => '0');
    signal atomic_write_data_reg   : std_logic_vector(31 downto 0) := (others => '0');

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
    signal ext_pkt_read_count        : unsigned(31 downto 0) := (others => '0');
    signal ext_pkt_write_count       : unsigned(31 downto 0) := (others => '0');
    signal ext_word_read_count       : unsigned(31 downto 0) := (others => '0');
    signal ext_word_write_count      : unsigned(31 downto 0) := (others => '0');
    signal last_ext_read_addr        : std_logic_vector(31 downto 0) := (others => '0');
    signal last_ext_read_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal last_ext_write_addr       : std_logic_vector(31 downto 0) := (others => '0');
    signal last_ext_write_data       : std_logic_vector(31 downto 0) := (others => '0');
    signal diag_clear_pending        : std_logic := '0';
    signal err_count_inc_pending     : std_logic := '0';
    signal soft_reset_pulse          : std_logic := '0';

    signal issue_seq_counter         : unsigned(7 downto 0) := (others => '0');
    signal complete_seq_counter      : unsigned(7 downto 0) := (others => '0');
    signal rx_ready_int              : std_logic := '0';

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
        addr_v := to_integer(unsigned(pkt_info.start_address(17 downto 0)));
        return (addr_v >= HUB_CSR_BASE_ADDR_CONST and addr_v < HUB_CSR_BASE_ADDR_CONST + HUB_CSR_WINDOW_WORDS_CONST);
    end function internal_hit_func;

    function effective_ooo_func (
        ctrl_enable : std_logic
    ) return boolean is
    begin
        if (OOO_ENABLE_G and ctrl_enable = '1') then
            return true;
        else
            return false;
        end if;
    end function effective_ooo_func;

    function wrap_inc32_func (
        value_in : unsigned(31 downto 0)
    ) return unsigned is
    begin
        return value_in + 1;
    end function wrap_inc32_func;

    function seq_precedes_func (
        lhs : unsigned(7 downto 0);
        rhs : unsigned(7 downto 0)
    ) return boolean is
    begin
        return (lhs /= rhs and signed(lhs - rhs) < 0);
    end function seq_precedes_func;

    function any_ext_busy_func (
        state_in : ext_slot_state_array_t
    ) return boolean is
    begin
        for idx in state_in'range loop
            if (state_in(idx) /= SLOT_FREE) then
                return true;
            end if;
        end loop;
        return false;
    end function any_ext_busy_func;

    function any_int_busy_func (
        valid_in : std_logic_vector
    ) return boolean is
    begin
        for idx in valid_in'range loop
            if (valid_in(idx) = '1') then
                return true;
            end if;
        end loop;
        return false;
    end function any_int_busy_func;
begin
    assert OOO_SLOT_COUNT_G <= 16
        report "sc_hub_axi4_core: OOO_SLOT_COUNT_G > 16 is unsupported with 4-bit AXI4 tags"
        severity failure;

    o_soft_reset_pulse  <= soft_reset_pulse;
    o_tx_reply_start    <= tx_reply_start_pulse;
    o_tx_reply_info     <= tx_reply_info_reg;
    o_tx_reply_response <= tx_reply_response_reg;
    o_tx_reply_has_data <= tx_reply_has_data_reg;
    o_tx_reply_suppress <= tx_reply_suppress_reg;
    o_tx_data_valid     <= '1'
        when (
            tx_state = TX_STREAMING and
            tx_words_remaining /= 0 and
            (
                tx_source = TX_SRC_EXT_READ or
                tx_source = TX_SRC_INT_READ or
                (tx_source = TX_SRC_WRITE and tx_reply_has_data_reg = '1')
            )
        )
        else '0';
    o_bus_ooo_enable    <= '1' when effective_ooo_func(ooo_ctrl_enable) else '0';
    rd_issue_live <= '1'
        when (
            rd_issue_valid = '1' and
            ext_slot_state(rd_issue_slot) = SLOT_WAIT_ISSUE
        )
        else '0';
    rd_cmd_pending_live <= '1'
        when (
            rd_cmd_pending_valid = '1' and
            ext_slot_state(rd_cmd_pending_slot) = SLOT_WAIT_ISSUE and
            not (write_state = WR_ATOMIC_RD_WAIT_DATA and rd_cmd_pending_slot = 0)
        )
        else '0';

    o_bus_rd_cmd_valid  <= '1' when (write_state = WR_ATOMIC_RD_WAIT_CMD) else rd_cmd_pending_live;
    o_bus_rd_cmd_address <= write_pkt_info.start_address(17 downto 0)
        when (write_state = WR_ATOMIC_RD_WAIT_CMD)
        else ext_slot_pkt_info(rd_cmd_pending_slot).start_address(17 downto 0);
    o_bus_rd_cmd_length  <= std_logic_vector(to_unsigned(1, o_bus_rd_cmd_length'length))
        when (write_state = WR_ATOMIC_RD_WAIT_CMD)
        else ext_slot_pkt_info(rd_cmd_pending_slot).rw_length;
    o_bus_rd_cmd_nonincrement <= '0'
        when (write_state = WR_ATOMIC_RD_WAIT_CMD)
        else '1' when pkt_is_nonincrementing_func(ext_slot_pkt_info(rd_cmd_pending_slot))
        else '0';
    o_bus_rd_cmd_tag     <= (others => '0')
        when (write_state = WR_ATOMIC_RD_WAIT_CMD or OOO_ENABLE_G = false)
        else std_logic_vector(to_unsigned(rd_cmd_pending_slot, 4));
    o_bus_rd_cmd_lock    <= write_pkt_info.atomic_flag
        when (write_state = WR_ATOMIC_RD_WAIT_CMD)
        else ext_slot_pkt_info(rd_cmd_pending_slot).atomic_flag;
    o_bus_wr_cmd_valid   <= '1'
        when (write_state = WR_EXT_WAIT_CMD or write_state = WR_ATOMIC_WR_WAIT_CMD)
        else '0';
    o_bus_wr_cmd_address <= write_pkt_info.start_address(17 downto 0);
    o_bus_wr_cmd_length  <= write_pkt_info.rw_length;
    o_bus_wr_cmd_nonincrement <= '1' when pkt_is_nonincrementing_func(write_pkt_info) else '0';
    o_bus_wr_cmd_lock    <= write_pkt_info.atomic_flag;
    o_bus_wr_data_valid  <= '1'
        when (
            write_state = WR_ATOMIC_WR_RUNNING or
            (write_state = WR_EXT_RUNNING and wr_data_valid_reg = '1')
        )
        else '0';
    o_bus_wr_data        <= atomic_write_data_reg when (write_state = WR_ATOMIC_WR_RUNNING) else
                           i_wr_data_q when (wr_data_reload_pending = '1') else
                           wr_data_word_reg;
    o_wr_data_rdreq      <= '1'
        when (
            (
                write_state = WR_INT_DRAINING and
                write_drain_remaining > 0 and
                i_wr_data_empty = '0'
            ) or
            (write_state = WR_EXT_RUNNING and i_bus_wr_data_ready = '1' and wr_data_valid_reg = '1')
        )
        else '0';
    o_rx_ready           <= rx_ready_int;
    tx_ext_word_present  <= '1' when (tx_ext_words_remaining /= 0) else '0';
    tx_payload_rd_addr   <= to_integer(tx_word_index(PAYLOAD_ADDR_WIDTH_CONST - 1 downto 0))
        when (
            tx_state = TX_PRIMING and
            tx_words_remaining /= 0 and
            to_integer(tx_word_index) < MAX_BURST_WORDS_CONST
        )
        else to_integer(resize(tx_word_index + 1, PAYLOAD_ADDR_WIDTH_CONST))
        when (
            tx_state = TX_STREAMING and
            i_tx_data_ready = '1' and
            tx_words_remaining > 1 and
            to_integer(tx_word_index) + 1 < MAX_BURST_WORDS_CONST
        )
        else to_integer(tx_word_index(PAYLOAD_ADDR_WIDTH_CONST - 1 downto 0))
        when (
            tx_state = TX_STREAMING and
            tx_words_remaining /= 0 and
            to_integer(tx_word_index) < MAX_BURST_WORDS_CONST
        )
        else 0;

    ext_payload_ram_gen : for idx in 0 to OOO_SLOT_COUNT_G - 1 generate
    begin
        ext_payload_ram_inst : entity work.sc_hub_payload_ram
        generic map(
            DATA_WIDTH_G => 32,
            ADDR_WIDTH_G => PAYLOAD_ADDR_WIDTH_CONST
        )
        port map(
            i_clk     => i_clk,
            i_rd_addr => tx_payload_rd_addr,
            i_wr_addr => ext_slot_payload_wr_addr(idx),
            i_wr_data => ext_slot_payload_wr_data(idx),
            i_wr_en   => ext_slot_payload_wr_en(idx),
            o_rd_data => ext_slot_payload_q(idx)
        );
    end generate ext_payload_ram_gen;

    int_payload_ram_gen : for idx in 0 to OUTSTANDING_INT_RESERVED_G - 1 generate
    begin
        int_payload_ram_inst : entity work.sc_hub_payload_ram
        generic map(
            DATA_WIDTH_G => 32,
            ADDR_WIDTH_G => PAYLOAD_ADDR_WIDTH_CONST
        )
        port map(
            i_clk     => i_clk,
            i_rd_addr => tx_payload_rd_addr,
            i_wr_addr => int_slot_payload_wr_addr(idx),
            i_wr_data => int_slot_payload_wr_data(idx),
            i_wr_en   => int_slot_payload_wr_en(idx),
            o_rd_data => int_slot_payload_q(idx)
        );
    end generate int_payload_ram_gen;

    tx_data_mux : process(tx_source, tx_slot_index, tx_word_index, tx_words_remaining, ext_slot_payload_q, int_slot_payload_q, tx_ext_word_present, write_reply_data_word)
        variable tx_word_index_v : natural;
    begin
        o_tx_data_word <= (others => '0');
        tx_word_index_v := to_integer(tx_word_index);
        if (tx_words_remaining /= 0 and tx_word_index_v < MAX_BURST_WORDS_CONST) then
            if (tx_source = TX_SRC_EXT_READ) then
                if (tx_ext_word_present = '1') then
                    o_tx_data_word <= ext_slot_payload_q(tx_slot_index);
                else
                    o_tx_data_word <= x"EEEEEEEE";
                end if;
            elsif (tx_source = TX_SRC_INT_READ) then
                o_tx_data_word <= int_slot_payload_q(tx_slot_index);
            elsif (tx_source = TX_SRC_WRITE) then
                o_tx_data_word <= write_reply_data_word;
            end if;
        end if;
    end process tx_data_mux;

    rx_ready_select : process(
        i_pkt_valid,
        i_pkt_info,
        hub_enable,
        ooo_ctrl_enable,
        ext_slot_state,
        int_slot_valid,
        int_fill_active,
        write_state,
        write_reply_pending,
        tx_state
    )
        variable allow_ooo_v      : boolean;
        variable ext_busy_v       : boolean;
        variable int_busy_v       : boolean;
        variable busy_for_order_v : boolean;
        variable internal_pkt_v   : boolean;
        variable read_pkt_v       : boolean;
        variable have_free_ext_v  : boolean;
        variable have_free_int_v  : boolean;
    begin
        rx_ready_int     <= '0';
        allow_ooo_v      := effective_ooo_func(ooo_ctrl_enable);
        ext_busy_v       := any_ext_busy_func(ext_slot_state);
        int_busy_v       := any_int_busy_func(int_slot_valid);
        busy_for_order_v := ext_busy_v or int_busy_v or int_fill_active = '1' or write_state /= WR_IDLE or
                            write_reply_pending = '1' or tx_state /= TX_IDLE;
        internal_pkt_v   := internal_hit_func(i_pkt_info);
        read_pkt_v       := pkt_is_read_func(i_pkt_info);
        have_free_ext_v  := false;
        have_free_int_v  := false;

        if (i_pkt_valid = '1' and hub_enable = '1') then
            for idx in 0 to OOO_SLOT_COUNT_G - 1 loop
                if (ext_slot_state(idx) = SLOT_FREE) then
                    have_free_ext_v := true;
                end if;
            end loop;

            for idx in 0 to OUTSTANDING_INT_RESERVED_G - 1 loop
                if (int_slot_valid(idx) = '0') then
                    have_free_int_v := true;
                end if;
            end loop;

            if (read_pkt_v) then
                if (internal_pkt_v) then
                    if (have_free_int_v and int_fill_active = '0' and (allow_ooo_v or busy_for_order_v = false)) then
                        rx_ready_int <= '1';
                    end if;
                else
                    if (pkt_is_atomic_func(i_pkt_info)) then
                        if (busy_for_order_v = false and write_state = WR_IDLE) then
                            rx_ready_int <= '1';
                        end if;
                    elsif (have_free_ext_v and (allow_ooo_v or busy_for_order_v = false)) then
                        rx_ready_int <= '1';
                    end if;
                end if;
            else
                if (write_state = WR_IDLE and write_reply_pending = '0') then
                    if (internal_pkt_v) then
                        if (allow_ooo_v or busy_for_order_v = false) then
                            rx_ready_int <= '1';
                        end if;
                    else
                        if (busy_for_order_v = false) then
                            rx_ready_int <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process rx_ready_select;

    core_ctrl : process(i_clk)
        variable err_pulse_v            : boolean;
        variable internal_addr_error_v  : boolean;
        variable soft_reset_request_v   : boolean;
        variable pkt_len_v              : unsigned(15 downto 0);
        variable csr_word_v             : std_logic_vector(31 downto 0);
        variable status_word_v          : std_logic_vector(31 downto 0);
        variable fifo_status_word_v     : std_logic_vector(31 downto 0);
        variable version_local_v        : std_logic_vector(31 downto 0);
        variable meta_local_v           : std_logic_vector(31 downto 0);
        variable offset_v               : natural;
        variable bus_tag_v              : natural;
        variable done_words_v           : unsigned(15 downto 0);
        variable next_read_addr_v       : unsigned(31 downto 0);
        variable selected_valid_v       : boolean;
        variable selected_from_write_v  : boolean;
        variable selected_internal_v    : boolean;
        variable selected_slot_v        : natural;
        variable best_complete_seq_v    : unsigned(7 downto 0);
        variable best_issue_seq_v       : unsigned(7 downto 0);
        variable ext_busy_v             : boolean;
        variable int_busy_v             : boolean;
        variable read_pkt_v             : boolean;
        variable internal_pkt_v         : boolean;
        variable allow_ooo_v            : boolean;
        variable have_free_ext_v        : boolean;
        variable have_free_int_v        : boolean;
        variable free_ext_slot_v        : natural range 0 to OOO_SLOT_COUNT_G - 1;
        variable free_int_slot_v        : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1;
        variable busy_for_order_v       : boolean;
        variable ready_internal_write_v : boolean;
        variable ready_external_write_v : boolean;
        variable unsupported_feature_v  : boolean;
        variable unsupported_order_v    : boolean;
        variable unsupported_atomic_v   : boolean;
        variable accepted_pkt_ignore_v  : boolean;
        variable hub_cap_word_v         : std_logic_vector(31 downto 0);
        variable accepted_pkt_info_v    : sc_pkt_info_t;
        variable int_slot_valid_v       : std_logic_vector(0 to OUTSTANDING_INT_RESERVED_G - 1);
        variable int_slot_issue_seq_v   : slot_unsigned8_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1);
        variable int_slot_complete_seq_v : slot_unsigned8_array_t(0 to OUTSTANDING_INT_RESERVED_G - 1);
        variable ext_slot_state_v       : ext_slot_state_array_t(0 to OOO_SLOT_COUNT_G - 1);
        variable ext_slot_words_received_v : slot_unsigned16_array_t(0 to OOO_SLOT_COUNT_G - 1);
        variable ext_slot_issue_seq_v   : slot_unsigned8_array_t(0 to OOO_SLOT_COUNT_G - 1);
        variable ext_slot_complete_seq_v : slot_unsigned8_array_t(0 to OOO_SLOT_COUNT_G - 1);
        variable tx_ooo_int_ready_live_v   : boolean;
        variable tx_ooo_ext_ready_live_v   : boolean;
        variable tx_issue_int_ready_live_v : boolean;
        variable tx_issue_ext_ready_live_v : boolean;
        variable rd_cmd_pending_valid_v    : std_logic;
        variable rd_cmd_pending_slot_v     : natural range 0 to OOO_SLOT_COUNT_G - 1;
        variable rd_cmd_accepted_v         : boolean;
        variable diag_clear_pending_v      : std_logic;
        variable err_count_inc_pending_v   : std_logic;
        variable ext_write_word_v          : std_logic_vector(31 downto 0);
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                ext_slot_state            <= (others => SLOT_FREE);
                ext_slot_pkt_info         <= (others => SC_PKT_INFO_RESET_CONST);
                ext_slot_reply_suppress   <= (others => '0');
                ext_slot_response         <= (others => SC_RSP_OK_CONST);
                ext_slot_words_received   <= (others => (others => '0'));
                ext_slot_issue_seq        <= (others => (others => '0'));
                ext_slot_complete_seq     <= (others => (others => '0'));
                ext_slot_payload_wr_en    <= (others => '0');
                ext_slot_payload_wr_addr  <= (others => 0);
                ext_slot_payload_wr_data  <= (others => (others => '0'));
                int_slot_valid            <= (others => '0');
                int_slot_pkt_info         <= (others => SC_PKT_INFO_RESET_CONST);
                int_slot_reply_suppress   <= (others => '0');
                int_slot_response         <= (others => SC_RSP_OK_CONST);
                int_slot_issue_seq        <= (others => (others => '0'));
                int_slot_complete_seq     <= (others => (others => '0'));
                int_slot_payload_wr_en    <= (others => '0');
                int_slot_payload_wr_addr  <= (others => 0);
                int_slot_payload_wr_data  <= (others => (others => '0'));
                int_fill_active           <= '0';
                int_fill_slot             <= 0;
                int_fill_pkt_info         <= SC_PKT_INFO_RESET_CONST;
                int_fill_csr_offset       <= 0;
                int_fill_index            <= 0;
                int_fill_wr_pending       <= '0';
                int_fill_wr_slot          <= 0;
                int_fill_wr_addr          <= 0;
                int_fill_wr_data          <= (others => '0');
                int_fill_wr_last          <= '0';
                rd_cmd_pending_valid      <= '0';
                rd_cmd_pending_slot       <= 0;
                tx_state                  <= TX_IDLE;
                tx_source                 <= TX_SRC_NONE;
                tx_slot_index             <= 0;
                tx_word_index             <= (others => '0');
                tx_launch_info            <= SC_PKT_INFO_RESET_CONST;
                tx_launch_response        <= SC_RSP_OK_CONST;
                tx_launch_has_data        <= '0';
                tx_launch_suppress        <= '0';
                tx_ext_words_remaining    <= (others => '0');
                tx_words_remaining        <= (others => '0');
                tx_reply_info_reg         <= SC_PKT_INFO_RESET_CONST;
                tx_reply_response_reg     <= SC_RSP_OK_CONST;
                tx_reply_has_data_reg     <= '0';
                tx_reply_suppress_reg     <= '0';
                tx_reply_start_pulse      <= '0';
                write_state               <= WR_IDLE;
                write_pkt_info            <= SC_PKT_INFO_RESET_CONST;
                write_reply_info          <= SC_PKT_INFO_RESET_CONST;
                write_reply_suppress      <= '0';
                write_is_internal         <= '0';
                write_csr_offset          <= 0;
                write_csr_word            <= (others => '0');
                write_issue_seq           <= (others => '0');
                write_complete_seq        <= (others => '0');
                write_response_reg        <= SC_RSP_OK_CONST;
                write_drain_remaining     <= (others => '0');
                write_stream_index        <= (others => '0');
                write_ignore_drain       <= '0';
                wr_data_valid_reg         <= '0';
                wr_data_word_reg          <= (others => '0');
                wr_data_reload_pending    <= '0';
                write_reply_pending       <= '0';
                write_reply_has_data      <= '0';
                write_reply_data_word     <= (others => '0');
                atomic_read_data_reg      <= (others => '0');
                atomic_write_data_reg     <= (others => '0');
                hub_enable                <= '1';
                meta_page_sel             <= "00";
                hub_scratch               <= (others => '0');
                hub_err_flags             <= (others => '0');
                hub_err_count             <= (others => '0');
                hub_gts_counter           <= (others => '0');
                hub_gts_snapshot          <= (others => '0');
                hub_upload_store_forward  <= '1';
                local_feb_type            <= HUB_FEB_TYPE_ALL_CONST;
                ooo_ctrl_enable           <= '0';
                ext_pkt_read_count        <= (others => '0');
                ext_pkt_write_count       <= (others => '0');
                ext_word_read_count       <= (others => '0');
                ext_word_write_count      <= (others => '0');
                last_ext_read_addr        <= (others => '0');
                last_ext_read_data        <= (others => '0');
                last_ext_write_addr       <= (others => '0');
                last_ext_write_data       <= (others => '0');
                diag_clear_pending        <= '0';
                err_count_inc_pending     <= '0';
                soft_reset_pulse          <= '0';
                issue_seq_counter         <= (others => '0');
                complete_seq_counter      <= (others => '0');
            else
                tx_reply_start_pulse   <= '0';
                soft_reset_pulse       <= '0';
                err_pulse_v            := false;
                internal_addr_error_v  := false;
                soft_reset_request_v   := false;
                unsupported_feature_v  := false;
                unsupported_order_v    := false;
                unsupported_atomic_v   := false;
                int_slot_valid_v       := int_slot_valid;
                int_slot_issue_seq_v   := int_slot_issue_seq;
                int_slot_complete_seq_v := int_slot_complete_seq;
                ext_slot_state_v       := ext_slot_state;
                ext_slot_words_received_v := ext_slot_words_received;
                ext_slot_issue_seq_v   := ext_slot_issue_seq;
                ext_slot_complete_seq_v := ext_slot_complete_seq;
                rd_cmd_pending_valid_v := rd_cmd_pending_valid;
                rd_cmd_pending_slot_v  := rd_cmd_pending_slot;
                rd_cmd_accepted_v      := false;
                diag_clear_pending_v   := diag_clear_pending;
                err_count_inc_pending_v := err_count_inc_pending;
                ext_write_word_v       := wr_data_word_reg;
                ext_slot_payload_wr_en <= (others => '0');
                int_slot_payload_wr_en <= (others => '0');
                allow_ooo_v            := effective_ooo_func(ooo_ctrl_enable);
                ext_busy_v             := any_ext_busy_func(ext_slot_state);
                int_busy_v             := any_int_busy_func(int_slot_valid);
                busy_for_order_v       := ext_busy_v or int_busy_v or int_fill_active = '1' or write_state /= WR_IDLE or
                                          write_reply_pending = '1' or tx_state /= TX_IDLE;
                hub_cap_word_v         := (others => '0');
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
                hub_gts_counter        <= hub_gts_counter + 1;

                if (wr_data_reload_pending = '1') then
                    wr_data_word_reg       <= i_wr_data_q;
                    wr_data_reload_pending <= '0';
                    ext_write_word_v       := i_wr_data_q;
                end if;

                if (diag_clear_pending = '1') then
                    hub_err_flags        <= (others => '0');
                    hub_err_count        <= (others => '0');
                    ext_pkt_read_count   <= (others => '0');
                    ext_pkt_write_count  <= (others => '0');
                    ext_word_read_count  <= (others => '0');
                    ext_word_write_count <= (others => '0');
                    last_ext_read_addr   <= (others => '0');
                    last_ext_read_data   <= (others => '0');
                    last_ext_write_addr  <= (others => '0');
                    last_ext_write_data  <= (others => '0');
                    diag_clear_pending_v := '0';
                    err_count_inc_pending_v := '0';
                elsif (err_count_inc_pending = '1') then
                    if (hub_err_count(7 downto 0) /= to_unsigned(16#FF#, 8)) then
                        hub_err_count <= resize(hub_err_count(7 downto 0) + 1, hub_err_count'length);
                    end if;
                    err_count_inc_pending_v := '0';
                end if;

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

                if (i_bus_rd_timeout_pulse = '1' or i_bus_wr_timeout_pulse = '1') then
                    hub_err_flags(HUB_ERR_RD_TIMEOUT_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                if (
                    write_state /= WR_ATOMIC_RD_WAIT_CMD and
                    rd_cmd_pending_live = '1' and
                    i_bus_rd_cmd_ready = '1'
                ) then
                    ext_slot_state(rd_cmd_pending_slot) <= SLOT_WAIT_DATA;
                    ext_slot_state_v(rd_cmd_pending_slot) := SLOT_WAIT_DATA;
                    rd_cmd_pending_valid_v := '0';
                    rd_cmd_accepted_v      := true;
                end if;

                if (i_bus_rd_data_valid = '1') then
                    bus_tag_v := to_integer(unsigned(i_bus_rd_data_tag));
                    if (bus_tag_v < OOO_SLOT_COUNT_G and ext_slot_state_v(bus_tag_v) = SLOT_WAIT_DATA) then
                        ext_slot_payload_wr_en(bus_tag_v)   <= '1';
                        ext_slot_payload_wr_addr(bus_tag_v) <= to_integer(ext_slot_words_received_v(bus_tag_v)(PAYLOAD_ADDR_WIDTH_CONST - 1 downto 0));
                        ext_slot_payload_wr_data(bus_tag_v) <= i_bus_rd_data;
                        if ((ext_slot_pkt_info(bus_tag_v).start_address = x"0012E0") or
                            (ext_slot_pkt_info(bus_tag_v).start_address = x"001AC0") or
                            (ext_slot_pkt_info(bus_tag_v).start_address = x"001E20")) then
                            report "DBG_RD_DATA slot=" & integer'image(bus_tag_v) &
                                   " addr=0x" & to_hstring(ext_slot_pkt_info(bus_tag_v).start_address) &
                                   " wr_idx=" & integer'image(to_integer(ext_slot_words_received_v(bus_tag_v))) &
                                   " data=0x" & to_hstring(i_bus_rd_data);
                        end if;
                        next_read_addr_v := resize(unsigned(ext_slot_pkt_info(bus_tag_v).start_address(17 downto 0)), 32);
                        if (pkt_is_nonincrementing_func(ext_slot_pkt_info(bus_tag_v)) = false) then
                            next_read_addr_v := next_read_addr_v + resize(ext_slot_words_received_v(bus_tag_v), 32);
                        end if;
                        last_ext_read_addr   <= std_logic_vector(next_read_addr_v);
                        last_ext_read_data   <= i_bus_rd_data;
                        ext_word_read_count  <= wrap_inc32_func(ext_word_read_count);
                        ext_slot_words_received_v(bus_tag_v) := ext_slot_words_received_v(bus_tag_v) + 1;
                    end if;
                end if;

                if (i_bus_rd_done = '1') then
                    bus_tag_v := to_integer(unsigned(i_bus_rd_done_tag));
                    if (bus_tag_v < OOO_SLOT_COUNT_G and ext_slot_state_v(bus_tag_v) = SLOT_WAIT_DATA) then
                        done_words_v := ext_slot_words_received_v(bus_tag_v);

                        ext_slot_words_received_v(bus_tag_v) := done_words_v;
                        ext_slot_response(bus_tag_v)       <= i_bus_rd_response;
                        if (i_bus_rd_response = SC_RSP_SLVERR_CONST) then
                            hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                            err_pulse_v := true;
                        elsif (i_bus_rd_response = SC_RSP_DECERR_CONST) then
                            hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                            err_pulse_v := true;
                        end if;
                        if ((ext_slot_pkt_info(bus_tag_v).start_address = x"0012E0") or
                            (ext_slot_pkt_info(bus_tag_v).start_address = x"001AC0") or
                            (ext_slot_pkt_info(bus_tag_v).start_address = x"001E20")) then
                            report "DBG_RD_DONE slot=" & integer'image(bus_tag_v) &
                                   " addr=0x" & to_hstring(ext_slot_pkt_info(bus_tag_v).start_address) &
                                   " done_words=" & integer'image(to_integer(done_words_v)) &
                                   " rsp=" & to_hstring(i_bus_rd_response);
                        end if;
                        ext_slot_state(bus_tag_v)      <= SLOT_READY;
                        ext_slot_complete_seq(bus_tag_v) <= complete_seq_counter;
                        ext_slot_state_v(bus_tag_v)      := SLOT_READY;
                        ext_slot_complete_seq_v(bus_tag_v) := complete_seq_counter;
                        complete_seq_counter           <= complete_seq_counter + 1;
                    end if;
                end if;

                case write_state is
                    when WR_IDLE =>
                        null;

                    when WR_INT_DRAINING =>
                        if (i_wr_data_empty = '0' and write_drain_remaining > 0) then
                            if (write_ignore_drain = '0' and write_drain_remaining = pkt_length_func(write_pkt_info)) then
                                write_response_reg    <= SC_RSP_SLVERR_CONST;
                                internal_addr_error_v := true;
                            end if;

                            write_drain_remaining <= write_drain_remaining - 1;
                            if (write_drain_remaining = 1) then
                                if (write_reply_suppress = '0') then
                                    write_reply_has_data  <= '0';
                                    write_reply_pending   <= '1';
                                    write_complete_seq    <= complete_seq_counter;
                                    complete_seq_counter  <= complete_seq_counter + 1;
                                end if;
                                write_ignore_drain <= '0';
                                write_state <= WR_IDLE;
                            end if;
                        end if;

                    when WR_INT_COMMIT =>
                        case write_csr_offset is
                            when HUB_CSR_WO_UID_CONST =>
                                null; -- UID is read-only

                            when HUB_CSR_WO_META_CONST =>
                                meta_page_sel <= write_csr_word(1 downto 0);

                            when HUB_CSR_WO_CTRL_CONST =>
                                hub_enable <= write_csr_word(0);
                                if (write_csr_word(1) = '1' or write_csr_word(2) = '1') then
                                    diag_clear_pending_v := '1';
                                end if;
                                if (write_csr_word(2) = '1') then
                                    soft_reset_request_v := true;
                                end if;

                            when HUB_CSR_WO_ERR_FLAGS_CONST =>
                                hub_err_flags <= hub_err_flags and not write_csr_word;

                            when HUB_CSR_WO_SCRATCH_CONST =>
                                hub_scratch <= write_csr_word;

                            when HUB_CSR_WO_FIFO_CFG_CONST =>
                                hub_upload_store_forward <= write_csr_word(1);

                            when HUB_CSR_WO_FEB_TYPE_CONST =>
                                local_feb_type <= write_csr_word(1 downto 0);

                            when HUB_CSR_WO_OOO_CTRL_CONST =>
                                if (OOO_ENABLE_G = true) then
                                    ooo_ctrl_enable <= write_csr_word(0);
                                else
                                    ooo_ctrl_enable <= '0';
                                end if;

                            when others =>
                                write_response_reg    <= SC_RSP_SLVERR_CONST;
                                internal_addr_error_v := true;
                        end case;

                        if (write_reply_suppress = '0') then
                            write_reply_has_data  <= '0';
                            write_reply_pending   <= '1';
                            write_complete_seq    <= complete_seq_counter;
                            complete_seq_counter  <= complete_seq_counter + 1;
                        end if;
                        write_state <= WR_IDLE;

                    when WR_EXT_WAIT_CMD =>
                        if (i_bus_wr_cmd_ready = '1') then
                            write_state            <= WR_EXT_RUNNING;
                            write_stream_index     <= (others => '0');
                            wr_data_word_reg       <= i_wr_data_q;
                            wr_data_valid_reg      <= '1';
                            wr_data_reload_pending <= '0';
                        end if;

                    when WR_EXT_RUNNING =>
                        if (wr_data_reload_pending = '1') then
                            ext_write_word_v := i_wr_data_q;
                        end if;

                        if (i_bus_wr_data_ready = '1' and wr_data_valid_reg = '1') then
                            last_ext_write_addr  <= std_logic_vector(resize(unsigned(write_pkt_info.start_address(17 downto 0)), 32));
                            if (pkt_is_nonincrementing_func(write_pkt_info) = false) then
                                last_ext_write_addr <= std_logic_vector(resize(unsigned(write_pkt_info.start_address(17 downto 0)), 32) +
                                                                        resize(write_stream_index, 32));
                            end if;
                            last_ext_write_data  <= ext_write_word_v;
                            ext_word_write_count <= wrap_inc32_func(ext_word_write_count);
                            write_stream_index   <= write_stream_index + 1;
                            if (write_stream_index + 1 >= pkt_length_func(write_pkt_info)) then
                                wr_data_valid_reg      <= '0';
                                wr_data_reload_pending <= '0';
                            else
                                wr_data_valid_reg      <= '1';
                                wr_data_reload_pending <= '1';
                            end if;
                        end if;

                        if (i_bus_wr_done = '1') then
                            write_response_reg <= i_bus_wr_response;
                            if (i_bus_wr_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_wr_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;
                            if (write_reply_suppress = '0') then
                                write_reply_has_data  <= '0';
                                write_reply_pending   <= '1';
                                write_complete_seq    <= complete_seq_counter;
                                complete_seq_counter  <= complete_seq_counter + 1;
                            end if;
                            wr_data_valid_reg      <= '0';
                            wr_data_reload_pending <= '0';
                            write_state <= WR_IDLE;
                        end if;

                    when WR_ATOMIC_RD_WAIT_CMD =>
                        if (i_bus_rd_cmd_ready = '1') then
                            write_state <= WR_ATOMIC_RD_WAIT_DATA;
                        end if;

                    when WR_ATOMIC_RD_WAIT_DATA =>
                        if (i_bus_rd_data_valid = '1') then
                            atomic_read_data_reg <= i_bus_rd_data;
                            last_ext_read_addr   <= std_logic_vector(resize(unsigned(write_pkt_info.start_address(17 downto 0)), 32));
                            last_ext_read_data   <= i_bus_rd_data;
                            ext_word_read_count  <= wrap_inc32_func(ext_word_read_count);
                        end if;

                        if (i_bus_rd_done = '1') then
                            write_response_reg <= i_bus_rd_response;
                            if (i_bus_rd_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_rd_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;

                            if (i_bus_rd_response = SC_RSP_OK_CONST and i_bus_rd_data_valid = '1') then
                                atomic_write_data_reg <= (i_bus_rd_data and not write_pkt_info.atomic_mask) or
                                                         (write_pkt_info.atomic_data and write_pkt_info.atomic_mask);
                                write_state           <= WR_ATOMIC_WR_WAIT_CMD;
                                write_stream_index    <= (others => '0');
                            else
                                if (write_reply_suppress = '0') then
                                    write_reply_has_data  <= '0';
                                    write_reply_pending   <= '1';
                                    write_complete_seq    <= complete_seq_counter;
                                    complete_seq_counter  <= complete_seq_counter + 1;
                                end if;
                                write_state <= WR_IDLE;
                            end if;
                        end if;

                    when WR_ATOMIC_WR_WAIT_CMD =>
                        if (i_bus_wr_cmd_ready = '1') then
                            write_state        <= WR_ATOMIC_WR_RUNNING;
                            write_stream_index <= (others => '0');
                        end if;

                    when WR_ATOMIC_WR_RUNNING =>
                        if (i_bus_wr_data_ready = '1') then
                            last_ext_write_addr  <= std_logic_vector(resize(unsigned(write_pkt_info.start_address(17 downto 0)), 32));
                            if (pkt_is_nonincrementing_func(write_pkt_info) = false) then
                                last_ext_write_addr <= std_logic_vector(resize(unsigned(write_pkt_info.start_address(17 downto 0)), 32) +
                                                                        resize(write_stream_index, 32));
                            end if;
                            last_ext_write_data  <= atomic_write_data_reg;
                            ext_word_write_count <= wrap_inc32_func(ext_word_write_count);
                            write_stream_index   <= write_stream_index + 1;
                        end if;

                        if (i_bus_wr_done = '1') then
                            write_response_reg <= i_bus_wr_response;
                            if (i_bus_wr_response = SC_RSP_SLVERR_CONST) then
                                hub_err_flags(HUB_ERR_SLVERR_CONST) <= '1';
                                err_pulse_v := true;
                            elsif (i_bus_wr_response = SC_RSP_DECERR_CONST) then
                                hub_err_flags(HUB_ERR_DECERR_CONST) <= '1';
                                err_pulse_v := true;
                            end if;
                            if (write_reply_suppress = '0') then
                                write_reply_has_data  <= '1';
                                write_reply_data_word <= atomic_read_data_reg;
                                write_reply_pending   <= '1';
                                write_complete_seq    <= complete_seq_counter;
                                complete_seq_counter  <= complete_seq_counter + 1;
                            end if;
                            write_state <= WR_IDLE;
                        end if;
                end case;

                if (int_fill_wr_pending = '1') then
                    int_slot_payload_wr_en(int_fill_wr_slot)   <= '1';
                    int_slot_payload_wr_addr(int_fill_wr_slot) <= int_fill_wr_addr;
                    int_slot_payload_wr_data(int_fill_wr_slot) <= int_fill_wr_data;
                    int_fill_wr_pending                        <= '0';
                    if (int_fill_wr_last = '1') then
                        int_fill_active <= '0';
                        if (int_slot_reply_suppress(int_fill_wr_slot) = '0') then
                            int_slot_valid(int_fill_wr_slot)          <= '1';
                            int_slot_complete_seq(int_fill_wr_slot)   <= complete_seq_counter;
                            int_slot_valid_v(int_fill_wr_slot)        := '1';
                            int_slot_complete_seq_v(int_fill_wr_slot) := complete_seq_counter;
                            complete_seq_counter                      <= complete_seq_counter + 1;
                        end if;
                    else
                        if (pkt_is_nonincrementing_func(int_fill_pkt_info) = false) then
                            int_fill_csr_offset <= int_fill_csr_offset + 1;
                        end if;
                        int_fill_index <= int_fill_index + 1;
                    end if;
                elsif (int_fill_active = '1') then
                    status_word_v      := (others => '0');
                    fifo_status_word_v := (others => '0');
                    if (busy_for_order_v) then
                        status_word_v(0) := '1';
                    else
                        status_word_v(0) := '0';
                    end if;
                    if (hub_err_flags /= std_logic_vector(to_unsigned(0, hub_err_flags'length))) then
                        status_word_v(1) := '1';
                    else
                        status_word_v(1) := '0';
                    end if;
                    status_word_v(2) := i_dl_fifo_full;
                    status_word_v(3) := i_bp_full;
                    status_word_v(4) := hub_enable;
                    status_word_v(5) := i_bus_busy;

                    fifo_status_word_v(0) := i_dl_fifo_full;
                    fifo_status_word_v(1) := i_bp_full;
                    fifo_status_word_v(2) := i_dl_fifo_overflow;
                    fifo_status_word_v(3) := i_bp_overflow;
                    fifo_status_word_v(5) := '1';

                    offset_v   := int_fill_csr_offset;
                    csr_word_v := (others => '0');

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

                    case offset_v is
                        when HUB_CSR_WO_UID_CONST =>
                            csr_word_v := std_logic_vector(to_unsigned(IP_UID_G, 32));
                        when HUB_CSR_WO_META_CONST =>
                            csr_word_v := meta_local_v;
                        when HUB_CSR_WO_CTRL_CONST =>
                            csr_word_v(0) := hub_enable;
                        when HUB_CSR_WO_STATUS_CONST =>
                            csr_word_v := status_word_v;
                        when HUB_CSR_WO_ERR_FLAGS_CONST =>
                            csr_word_v := hub_err_flags;
                        when HUB_CSR_WO_ERR_COUNT_CONST =>
                            csr_word_v := std_logic_vector(hub_err_count);
                        when HUB_CSR_WO_SCRATCH_CONST =>
                            csr_word_v := hub_scratch;
                        when HUB_CSR_WO_GTS_SNAP_LO_CONST =>
                            csr_word_v := std_logic_vector(hub_gts_snapshot(31 downto 0));
                        when HUB_CSR_WO_GTS_SNAP_HI_CONST =>
                            csr_word_v(15 downto 0) := std_logic_vector(hub_gts_snapshot(47 downto 32));
                            hub_gts_snapshot        <= hub_gts_counter;
                        when HUB_CSR_WO_FIFO_CFG_CONST =>
                            csr_word_v(0) := '1';
                            csr_word_v(1) := hub_upload_store_forward;
                        when HUB_CSR_WO_FIFO_STATUS_CONST =>
                            csr_word_v := fifo_status_word_v;
                        when HUB_CSR_WO_DOWN_PKT_CNT_CONST =>
                            if (busy_for_order_v) then
                                csr_word_v(0) := '1';
                            end if;
                        when HUB_CSR_WO_UP_PKT_CNT_CONST =>
                            csr_word_v(9 downto 0) := i_bp_pkt_count;
                        when HUB_CSR_WO_DOWN_USEDW_CONST =>
                            csr_word_v(9 downto 0) := i_dl_fifo_usedw;
                        when HUB_CSR_WO_UP_USEDW_CONST =>
                            csr_word_v(9 downto 0) := i_bp_usedw;
                        when HUB_CSR_WO_EXT_PKT_RD_CONST =>
                            csr_word_v := std_logic_vector(ext_pkt_read_count);
                        when HUB_CSR_WO_EXT_PKT_WR_CONST =>
                            csr_word_v := std_logic_vector(ext_pkt_write_count);
                        when HUB_CSR_WO_EXT_WORD_RD_CONST =>
                            csr_word_v := std_logic_vector(ext_word_read_count);
                        when HUB_CSR_WO_EXT_WORD_WR_CONST =>
                            csr_word_v := std_logic_vector(ext_word_write_count);
                        when HUB_CSR_WO_LAST_RD_ADDR_CONST =>
                            csr_word_v := last_ext_read_addr;
                        when HUB_CSR_WO_LAST_RD_DATA_CONST =>
                            csr_word_v := last_ext_read_data;
                        when HUB_CSR_WO_LAST_WR_ADDR_CONST =>
                            csr_word_v := last_ext_write_addr;
                        when HUB_CSR_WO_LAST_WR_DATA_CONST =>
                            csr_word_v := last_ext_write_data;
                        when HUB_CSR_WO_PKT_DROP_CNT_CONST =>
                            csr_word_v(15 downto 0) := i_pkt_drop_count;
                        when HUB_CSR_WO_FEB_TYPE_CONST =>
                            csr_word_v(1 downto 0) := local_feb_type;
                        when HUB_CSR_WO_OOO_CTRL_CONST =>
                            if (OOO_ENABLE_G = true) then
                                csr_word_v(0) := ooo_ctrl_enable;
                            else
                                csr_word_v(0) := '0';
                            end if;
                        when HUB_CSR_WO_HUB_CAP_CONST =>
                            if (HUB_CAP_ENABLE_G = true) then
                                csr_word_v := hub_cap_word_v;
                            end if;
                        when others =>
                            csr_word_v := x"EEEEEEEE";
                            int_slot_response(int_fill_slot) <= SC_RSP_SLVERR_CONST;
                            internal_addr_error_v := true;
                    end case;

                    int_fill_wr_pending <= '1';
                    int_fill_wr_slot    <= int_fill_slot;
                    int_fill_wr_addr    <= int_fill_index;
                    int_fill_wr_data    <= csr_word_v;
                    if (int_fill_index + 1 >= to_integer(unsigned(int_fill_pkt_info.rw_length))) then
                        int_fill_wr_last <= '1';
                    else
                        int_fill_wr_last <= '0';
                    end if;
                end if;

                if (tx_state = TX_IDLE) then
                    selected_valid_v      := false;
                    selected_from_write_v := false;
                    selected_internal_v   := false;
                    selected_slot_v       := 0;
                    tx_ooo_int_ready_live_v   := (tx_ooo_int_ready_valid = '1' and int_slot_valid(tx_ooo_int_ready_slot) = '1');
                    tx_ooo_ext_ready_live_v   := (tx_ooo_ext_ready_valid = '1' and ext_slot_state(tx_ooo_ext_ready_slot) = SLOT_READY);
                    tx_issue_int_ready_live_v := (tx_issue_int_ready_valid = '1' and int_slot_valid(tx_issue_int_ready_slot) = '1');
                    tx_issue_ext_ready_live_v := (tx_issue_ext_ready_valid = '1' and ext_slot_state(tx_issue_ext_ready_slot) = SLOT_READY);

                    ready_internal_write_v := (write_reply_pending = '1' and write_is_internal = '1');
                    ready_external_write_v := (write_reply_pending = '1' and write_is_internal = '0');

                    if (allow_ooo_v) then
                        if (ready_internal_write_v or tx_ooo_int_ready_live_v) then
                            selected_valid_v    := true;
                            selected_internal_v := true;
                            if (
                                ready_internal_write_v and
                                (
                                    tx_ooo_int_ready_live_v = false or
                                    write_complete_seq <= tx_ooo_int_ready_seq
                                )
                            ) then
                                selected_from_write_v := true;
                                selected_slot_v       := 0;
                            else
                                selected_from_write_v := false;
                                selected_slot_v       := tx_ooo_int_ready_slot;
                            end if;
                        elsif (ready_external_write_v or tx_ooo_ext_ready_live_v) then
                            selected_valid_v    := true;
                            selected_internal_v := false;
                            if (
                                ready_external_write_v and
                                (
                                    tx_ooo_ext_ready_live_v = false or
                                    write_complete_seq <= tx_ooo_ext_ready_seq
                                )
                            ) then
                                selected_from_write_v := true;
                                selected_slot_v       := 0;
                            else
                                selected_from_write_v := false;
                                selected_slot_v       := tx_ooo_ext_ready_slot;
                            end if;
                        end if;
                    else
                        if (write_reply_pending = '1') then
                            selected_valid_v      := true;
                            selected_from_write_v := true;
                            selected_internal_v   := (write_is_internal = '1');
                            selected_slot_v       := 0;
                        elsif (tx_issue_int_ready_live_v) then
                            selected_valid_v      := true;
                            selected_from_write_v := false;
                            selected_internal_v   := true;
                            selected_slot_v       := tx_issue_int_ready_slot;
                        elsif (tx_issue_ext_ready_live_v) then
                            selected_valid_v      := true;
                            selected_from_write_v := false;
                            selected_internal_v   := false;
                            selected_slot_v       := tx_issue_ext_ready_slot;
                        end if;
                    end if;

                    if (selected_valid_v) then
                        tx_slot_index          <= selected_slot_v;
                        tx_word_index          <= (others => '0');
                        tx_ext_words_remaining <= (others => '0');
                        tx_words_remaining     <= (others => '0');
                        if (selected_from_write_v) then
                            tx_source <= TX_SRC_WRITE;
                            tx_launch_info     <= write_reply_info;
                            tx_launch_response <= write_response_reg;
                            tx_launch_has_data <= write_reply_has_data;
                            tx_launch_suppress <= write_reply_suppress;
                        elsif (selected_internal_v) then
                            tx_source <= TX_SRC_INT_READ;
                            tx_launch_info     <= int_slot_pkt_info(selected_slot_v);
                            tx_launch_response <= int_slot_response(selected_slot_v);
                            tx_launch_has_data <= '1';
                            tx_launch_suppress <= int_slot_reply_suppress(selected_slot_v);
                        else
                            tx_source              <= TX_SRC_EXT_READ;
                            tx_launch_info         <= ext_slot_pkt_info(selected_slot_v);
                            tx_launch_response     <= ext_slot_response(selected_slot_v);
                            tx_launch_has_data     <= '1';
                            tx_launch_suppress     <= ext_slot_reply_suppress(selected_slot_v);
                            tx_ext_words_remaining <= ext_slot_words_received(selected_slot_v);
                        end if;
                        tx_state <= TX_SELECTING;
                    end if;
                elsif (tx_state = TX_SELECTING) then
                    if (i_tx_reply_ready = '1') then
                        if (tx_source = TX_SRC_EXT_READ and ((tx_launch_info.start_address = x"0012E0") or
                            (tx_launch_info.start_address = x"001AC0") or
                            (tx_launch_info.start_address = x"001E20"))) then
                            report "DBG_TX_START slot=" & integer'image(tx_slot_index) &
                                   " addr=0x" & to_hstring(tx_launch_info.start_address) &
                                   " len=" & integer'image(to_integer(unsigned(tx_launch_info.rw_length))) &
                                   " ext_words=" & integer'image(to_integer(tx_ext_words_remaining)) &
                                   " q0=0x" & to_hstring(ext_slot_payload_q(tx_slot_index));
                        end if;
                        tx_reply_start_pulse <= '1';
                        tx_reply_info_reg     <= tx_launch_info;
                        tx_reply_response_reg <= tx_launch_response;
                        tx_reply_has_data_reg <= tx_launch_has_data;
                        tx_reply_suppress_reg <= tx_launch_suppress;
                        tx_words_remaining    <= unsigned(tx_launch_info.rw_length);
                        case tx_source is
                            when TX_SRC_WRITE =>
                                if (tx_launch_has_data = '1' and unsigned(tx_launch_info.rw_length) /= 0) then
                                    tx_state <= TX_STREAMING;
                                else
                                    tx_state <= TX_WAIT_DONE;
                                end if;
                            when TX_SRC_INT_READ | TX_SRC_EXT_READ =>
                                if (tx_launch_suppress = '1' or unsigned(tx_launch_info.rw_length) = 0) then
                                    tx_state <= TX_WAIT_DONE;
                                else
                                    tx_state <= TX_PRIMING;
                                end if;
                            when others =>
                                tx_reply_info_reg     <= SC_PKT_INFO_RESET_CONST;
                                tx_reply_response_reg <= SC_RSP_OK_CONST;
                                tx_reply_has_data_reg <= '0';
                                tx_reply_suppress_reg <= '0';
                                tx_words_remaining    <= (others => '0');
                                tx_state              <= TX_IDLE;
                        end case;
                    end if;
                elsif (tx_state = TX_PRIMING) then
                    tx_state <= TX_STREAMING;
                elsif (tx_state = TX_STREAMING) then
                    if (i_tx_data_ready = '1') then
                        if (tx_source = TX_SRC_EXT_READ and ((tx_reply_info_reg.start_address = x"0012E0") or
                            (tx_reply_info_reg.start_address = x"001AC0") or
                            (tx_reply_info_reg.start_address = x"001E20"))) then
                            report "DBG_TX_WORD slot=" & integer'image(tx_slot_index) &
                                   " addr=0x" & to_hstring(tx_reply_info_reg.start_address) &
                                   " idx=" & integer'image(to_integer(tx_word_index)) &
                                   " data=0x" & to_hstring(ext_slot_payload_q(tx_slot_index)) &
                                   " words_left=" & integer'image(to_integer(tx_words_remaining)) &
                                   " ext_left=" & integer'image(to_integer(tx_ext_words_remaining));
                        end if;
                        if (tx_source = TX_SRC_EXT_READ and tx_ext_words_remaining /= 0) then
                            tx_ext_words_remaining <= tx_ext_words_remaining - 1;
                        end if;
                        if (tx_words_remaining <= 1) then
                            tx_state <= TX_WAIT_DONE;
                        end if;
                        if (tx_words_remaining /= 0) then
                            tx_words_remaining <= tx_words_remaining - 1;
                        end if;
                        tx_word_index <= tx_word_index + 1;
                    end if;
                elsif (tx_state = TX_WAIT_DONE) then
                    if (i_tx_reply_done = '1') then
                        case tx_source is
                            when TX_SRC_WRITE =>
                                write_reply_pending   <= '0';
                                write_reply_has_data  <= '0';
                            when TX_SRC_INT_READ =>
                                int_slot_valid(tx_slot_index) <= '0';
                                int_slot_valid_v(tx_slot_index) := '0';
                            when TX_SRC_EXT_READ =>
                                ext_slot_state(tx_slot_index) <= SLOT_FREE;
                                ext_slot_state_v(tx_slot_index) := SLOT_FREE;
                                ext_slot_words_received_v(tx_slot_index) := (others => '0');
                            when others =>
                                null;
                        end case;
                        tx_source              <= TX_SRC_NONE;
                        tx_ext_words_remaining <= (others => '0');
                        tx_words_remaining     <= (others => '0');
                        tx_state               <= TX_IDLE;
                    end if;
                end if;

                if (i_pkt_valid = '1' and hub_enable = '1' and rx_ready_int = '1') then
                    pkt_len_v             := pkt_length_func(i_pkt_info);
                    internal_pkt_v        := internal_hit_func(i_pkt_info);
                    read_pkt_v            := pkt_is_read_func(i_pkt_info);
                    accepted_pkt_info_v   := i_pkt_info;
                    unsupported_order_v   := (ORD_ENABLE_G = false and i_pkt_info.order_mode /= SC_ORDER_RELAXED_CONST);
                    unsupported_atomic_v  := (pkt_is_atomic_func(i_pkt_info) and (ATOMIC_ENABLE_G = false or internal_pkt_v));
                    unsupported_feature_v := unsupported_order_v or unsupported_atomic_v;
                    accepted_pkt_ignore_v := pkt_locally_masked_func(i_pkt_info, local_feb_type);
                    if (unsupported_feature_v) then
                        accepted_pkt_info_v.rw_length := (others => '0');
                    end if;
                    have_free_ext_v := false;
                    have_free_int_v := false;
                    free_ext_slot_v := 0;
                    free_int_slot_v := 0;

                    for idx in 0 to OOO_SLOT_COUNT_G - 1 loop
                        if (have_free_ext_v = false and ext_slot_state_v(idx) = SLOT_FREE) then
                            have_free_ext_v := true;
                            free_ext_slot_v := idx;
                        end if;
                    end loop;

                    for idx in 0 to OUTSTANDING_INT_RESERVED_G - 1 loop
                        if (have_free_int_v = false and int_slot_valid_v(idx) = '0') then
                            have_free_int_v := true;
                            free_int_slot_v := idx;
                        end if;
                    end loop;

                    if (accepted_pkt_ignore_v = true) then
                        if (read_pkt_v = false and pkt_is_atomic_func(i_pkt_info) = false and pkt_len_v /= 0 and write_state = WR_IDLE and write_reply_pending = '0') then
                            write_pkt_info        <= accepted_pkt_info_v;
                            write_reply_info      <= accepted_pkt_info_v;
                            write_reply_suppress  <= '1';
                            write_reply_has_data  <= '0';
                            write_is_internal     <= '0';
                            write_issue_seq       <= issue_seq_counter;
                            write_response_reg    <= SC_RSP_OK_CONST;
                            write_drain_remaining <= pkt_len_v;
                            write_stream_index    <= (others => '0');
                            write_ignore_drain    <= '1';
                            issue_seq_counter     <= issue_seq_counter + 1;
                            write_state           <= WR_INT_DRAINING;
                        end if;
                    elsif (read_pkt_v) then
                        if (internal_pkt_v) then
                            if (have_free_int_v and int_fill_active = '0' and (allow_ooo_v or busy_for_order_v = false)) then
                                int_slot_pkt_info(free_int_slot_v)       <= accepted_pkt_info_v;
                                if (pkt_reply_suppressed_func(i_pkt_info)) then
                                    int_slot_reply_suppress(free_int_slot_v) <= '1';
                                else
                                    int_slot_reply_suppress(free_int_slot_v) <= '0';
                                end if;
                                if (unsupported_feature_v) then
                                    int_slot_response(free_int_slot_v)   <= SC_RSP_SLVERR_CONST;
                                else
                                    int_slot_response(free_int_slot_v)   <= SC_RSP_OK_CONST;
                                end if;
                                int_slot_issue_seq(free_int_slot_v)      <= issue_seq_counter;
                                int_slot_issue_seq_v(free_int_slot_v)    := issue_seq_counter;
                                issue_seq_counter                        <= issue_seq_counter + 1;
                                if (pkt_reply_suppressed_func(i_pkt_info)) then
                                    int_slot_valid(free_int_slot_v) <= '0';
                                    int_slot_valid_v(free_int_slot_v) := '0';
                                elsif (unsupported_feature_v or pkt_len_v = 0) then
                                    int_slot_valid(free_int_slot_v)      <= '1';
                                    int_slot_complete_seq(free_int_slot_v) <= complete_seq_counter;
                                    int_slot_valid_v(free_int_slot_v)      := '1';
                                    int_slot_complete_seq_v(free_int_slot_v) := complete_seq_counter;
                                    complete_seq_counter                 <= complete_seq_counter + 1;
                                else
                                    int_slot_valid(free_int_slot_v) <= '0';
                                    int_slot_valid_v(free_int_slot_v) := '0';
                                    int_fill_active                  <= '1';
                                    int_fill_slot                    <= free_int_slot_v;
                                    int_fill_pkt_info                <= accepted_pkt_info_v;
                                    int_fill_csr_offset              <= to_integer(unsigned(accepted_pkt_info_v.start_address(15 downto 0))) -
                                                                       HUB_CSR_BASE_ADDR_CONST;
                                    int_fill_index                   <= 0;
                                end if;
                            end if;
                        else
                            if (pkt_is_atomic_func(i_pkt_info)) then
                                if (busy_for_order_v = false and write_state = WR_IDLE) then
                                    write_pkt_info        <= accepted_pkt_info_v;
                                    write_reply_info      <= accepted_pkt_info_v;
                                    if (pkt_reply_suppressed_func(i_pkt_info)) then
                                        write_reply_suppress <= '1';
                                    else
                                        write_reply_suppress <= '0';
                                    end if;
                                    write_is_internal     <= '0';
                                    write_issue_seq       <= issue_seq_counter;
                                    if (unsupported_feature_v) then
                                        write_response_reg <= SC_RSP_SLVERR_CONST;
                                    else
                                        write_response_reg <= SC_RSP_OK_CONST;
                                    end if;
                                    issue_seq_counter     <= issue_seq_counter + 1;
                                    write_reply_has_data  <= '0';
                                    write_stream_index    <= (others => '0');
                                    if (unsupported_feature_v = false) then
                                        ext_pkt_read_count  <= wrap_inc32_func(ext_pkt_read_count);
                                        ext_pkt_write_count <= wrap_inc32_func(ext_pkt_write_count);
                                    end if;

                                    if (unsupported_feature_v or pkt_len_v = 0) then
                                        if (pkt_reply_suppressed_func(i_pkt_info) = false) then
                                            write_reply_pending   <= '1';
                                            write_complete_seq    <= complete_seq_counter;
                                            complete_seq_counter  <= complete_seq_counter + 1;
                                        end if;
                                    else
                                        write_state <= WR_ATOMIC_RD_WAIT_CMD;
                                    end if;
                                end if;
                            elsif (have_free_ext_v and (allow_ooo_v or busy_for_order_v = false)) then
                                ext_slot_pkt_info(free_ext_slot_v)        <= accepted_pkt_info_v;
                                if (pkt_reply_suppressed_func(i_pkt_info)) then
                                    ext_slot_reply_suppress(free_ext_slot_v) <= '1';
                                else
                                    ext_slot_reply_suppress(free_ext_slot_v) <= '0';
                                end if;
                                if (unsupported_feature_v) then
                                    ext_slot_response(free_ext_slot_v)    <= SC_RSP_SLVERR_CONST;
                                else
                                    ext_slot_response(free_ext_slot_v)    <= SC_RSP_OK_CONST;
                                end if;
                                ext_slot_issue_seq(free_ext_slot_v)       <= issue_seq_counter;
                                ext_slot_issue_seq_v(free_ext_slot_v)     := issue_seq_counter;
                                issue_seq_counter                         <= issue_seq_counter + 1;
                                ext_slot_words_received_v(free_ext_slot_v) := (others => '0');

                                if (unsupported_feature_v = false) then
                                    ext_pkt_read_count <= wrap_inc32_func(ext_pkt_read_count);
                                end if;

                                if (unsupported_feature_v or pkt_len_v = 0) then
                                    if (pkt_reply_suppressed_func(i_pkt_info)) then
                                        ext_slot_state(free_ext_slot_v) <= SLOT_FREE;
                                        ext_slot_state_v(free_ext_slot_v) := SLOT_FREE;
                                        ext_slot_words_received_v(free_ext_slot_v) := (others => '0');
                                    else
                                        ext_slot_state(free_ext_slot_v)      <= SLOT_READY;
                                        ext_slot_complete_seq(free_ext_slot_v) <= complete_seq_counter;
                                        ext_slot_state_v(free_ext_slot_v)      := SLOT_READY;
                                        ext_slot_complete_seq_v(free_ext_slot_v) := complete_seq_counter;
                                        complete_seq_counter                 <= complete_seq_counter + 1;
                                    end if;
                                else
                                    ext_slot_state(free_ext_slot_v) <= SLOT_WAIT_ISSUE;
                                    ext_slot_state_v(free_ext_slot_v) := SLOT_WAIT_ISSUE;
                                end if;
                            end if;
                        end if;
                    else
                        if (write_state = WR_IDLE and write_reply_pending = '0') then
                            if (internal_pkt_v) then
                                if (allow_ooo_v or busy_for_order_v = false) then
                                    write_pkt_info        <= accepted_pkt_info_v;
                                    write_reply_info      <= accepted_pkt_info_v;
                                    if (pkt_reply_suppressed_func(i_pkt_info)) then
                                        write_reply_suppress <= '1';
                                    else
                                        write_reply_suppress <= '0';
                                    end if;
                                    write_is_internal     <= '1';
                                    write_issue_seq       <= issue_seq_counter;
                                    if (unsupported_feature_v) then
                                        write_response_reg <= SC_RSP_SLVERR_CONST;
                                    else
                                        write_response_reg <= SC_RSP_OK_CONST;
                                    end if;
                                    issue_seq_counter     <= issue_seq_counter + 1;
                                    write_reply_has_data  <= '0';
                                    write_ignore_drain    <= '0';

                                    if (unsupported_feature_v or pkt_len_v = 0) then
                                        if (pkt_reply_suppressed_func(i_pkt_info) = false) then
                                            write_reply_pending   <= '1';
                                            write_complete_seq    <= complete_seq_counter;
                                            complete_seq_counter  <= complete_seq_counter + 1;
                                        end if;
                                    elsif (pkt_len_v = 1) then
                                        write_csr_offset      <= to_integer(unsigned(accepted_pkt_info_v.start_address(15 downto 0))) -
                                                                 HUB_CSR_BASE_ADDR_CONST;
                                        write_csr_word        <= accepted_pkt_info_v.atomic_data;
                                        write_state           <= WR_INT_COMMIT;
                                    else
                                        write_state <= WR_INT_DRAINING;
                                        write_drain_remaining <= unsigned(accepted_pkt_info_v.rw_length);
                                    end if;
                                end if;
                            else
                                if (busy_for_order_v = false) then
                                    write_pkt_info        <= accepted_pkt_info_v;
                                    write_reply_info      <= accepted_pkt_info_v;
                                    if (pkt_reply_suppressed_func(i_pkt_info)) then
                                        write_reply_suppress <= '1';
                                    else
                                        write_reply_suppress <= '0';
                                    end if;
                                    write_is_internal     <= '0';
                                    write_issue_seq       <= issue_seq_counter;
                                    if (unsupported_feature_v) then
                                        write_response_reg <= SC_RSP_SLVERR_CONST;
                                    else
                                        write_response_reg <= SC_RSP_OK_CONST;
                                    end if;
                                    issue_seq_counter     <= issue_seq_counter + 1;
                                    write_reply_has_data  <= '0';
                                    write_ignore_drain    <= '0';
                                    if (unsupported_feature_v = false) then
                                        ext_pkt_write_count <= wrap_inc32_func(ext_pkt_write_count);
                                        if (pkt_is_atomic_func(i_pkt_info)) then
                                            ext_pkt_read_count <= wrap_inc32_func(ext_pkt_read_count);
                                        end if;
                                    end if;

                                    if (unsupported_feature_v or pkt_len_v = 0) then
                                        if (pkt_reply_suppressed_func(i_pkt_info) = false) then
                                            write_reply_pending   <= '1';
                                            write_complete_seq    <= complete_seq_counter;
                                            complete_seq_counter  <= complete_seq_counter + 1;
                                        end if;
                                    elsif (pkt_is_atomic_func(i_pkt_info)) then
                                        write_state            <= WR_ATOMIC_RD_WAIT_CMD;
                                        write_stream_index     <= (others => '0');
                                    else
                                        write_state            <= WR_EXT_WAIT_CMD;
                                        write_drain_remaining  <= pkt_len_v;
                                        write_stream_index     <= (others => '0');
                                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                end if;

                if (
                    write_state /= WR_ATOMIC_RD_WAIT_CMD and
                    rd_cmd_pending_valid_v = '0' and
                    rd_issue_live = '1' and
                    rd_cmd_accepted_v = false
                ) then
                    rd_cmd_pending_valid_v := '1';
                    rd_cmd_pending_slot_v  := rd_issue_slot;
                end if;

                if (internal_addr_error_v = true) then
                    hub_err_flags(HUB_ERR_INTERNAL_ADDR_CONST) <= '1';
                    err_pulse_v := true;
                end if;

                if (err_pulse_v = true) then
                    err_count_inc_pending_v := '1';
                end if;

                if (soft_reset_request_v = true) then
                    ext_slot_state            <= (others => SLOT_FREE);
                    ext_slot_pkt_info         <= (others => SC_PKT_INFO_RESET_CONST);
                    ext_slot_reply_suppress   <= (others => '0');
                    ext_slot_response         <= (others => SC_RSP_OK_CONST);
                    ext_slot_words_received   <= (others => (others => '0'));
                    ext_slot_issue_seq        <= (others => (others => '0'));
                    ext_slot_complete_seq     <= (others => (others => '0'));
                    ext_slot_state_v          := (others => SLOT_FREE);
                    ext_slot_words_received_v := (others => (others => '0'));
                    ext_slot_issue_seq_v      := (others => (others => '0'));
                    ext_slot_complete_seq_v   := (others => (others => '0'));
                    ext_slot_payload_wr_en    <= (others => '0');
                    ext_slot_payload_wr_addr  <= (others => 0);
                    ext_slot_payload_wr_data  <= (others => (others => '0'));
                    int_slot_valid            <= (others => '0');
                    int_slot_pkt_info         <= (others => SC_PKT_INFO_RESET_CONST);
                    int_slot_reply_suppress   <= (others => '0');
                    int_slot_response         <= (others => SC_RSP_OK_CONST);
                    int_slot_issue_seq        <= (others => (others => '0'));
                    int_slot_complete_seq     <= (others => (others => '0'));
                    int_slot_valid_v          := (others => '0');
                    int_slot_issue_seq_v      := (others => (others => '0'));
                    int_slot_complete_seq_v   := (others => (others => '0'));
                    int_slot_payload_wr_en    <= (others => '0');
                    int_slot_payload_wr_addr  <= (others => 0);
                    int_slot_payload_wr_data  <= (others => (others => '0'));
                    int_fill_active           <= '0';
                    int_fill_slot             <= 0;
                    int_fill_pkt_info         <= SC_PKT_INFO_RESET_CONST;
                    int_fill_csr_offset       <= 0;
                    int_fill_index            <= 0;
                    int_fill_wr_pending       <= '0';
                    int_fill_wr_slot          <= 0;
                    int_fill_wr_addr          <= 0;
                    int_fill_wr_data          <= (others => '0');
                    int_fill_wr_last          <= '0';
                    tx_state                  <= TX_IDLE;
                    tx_source                 <= TX_SRC_NONE;
                    tx_slot_index             <= 0;
                    tx_word_index             <= (others => '0');
                    tx_launch_info            <= SC_PKT_INFO_RESET_CONST;
                    tx_launch_response        <= SC_RSP_OK_CONST;
                    tx_launch_has_data        <= '0';
                    tx_launch_suppress        <= '0';
                    tx_ext_words_remaining    <= (others => '0');
                    tx_words_remaining        <= (others => '0');
                    tx_reply_info_reg         <= SC_PKT_INFO_RESET_CONST;
                    tx_reply_response_reg     <= SC_RSP_OK_CONST;
                    tx_reply_has_data_reg     <= '0';
                    tx_reply_suppress_reg     <= '0';
                    write_state               <= WR_IDLE;
                    write_pkt_info            <= SC_PKT_INFO_RESET_CONST;
                    write_reply_info          <= SC_PKT_INFO_RESET_CONST;
                    write_reply_suppress      <= '0';
                    write_is_internal         <= '0';
                    write_csr_offset          <= 0;
                    write_csr_word            <= (others => '0');
                    write_issue_seq           <= (others => '0');
                    write_complete_seq        <= (others => '0');
                    write_response_reg        <= SC_RSP_OK_CONST;
                    write_drain_remaining     <= (others => '0');
                    write_stream_index        <= (others => '0');
                    write_ignore_drain       <= '0';
                    wr_data_valid_reg         <= '0';
                    wr_data_word_reg          <= (others => '0');
                    wr_data_reload_pending    <= '0';
                    write_reply_pending       <= '0';
                    write_reply_has_data      <= '0';
                    write_reply_data_word     <= (others => '0');
                    atomic_read_data_reg      <= (others => '0');
                    atomic_write_data_reg     <= (others => '0');
                    hub_enable                <= '1';
                    meta_page_sel             <= "00";
                    hub_scratch               <= (others => '0');
                    hub_err_flags             <= (others => '0');
                    hub_err_count             <= (others => '0');
                    hub_gts_counter           <= (others => '0');
                    hub_gts_snapshot          <= (others => '0');
                    hub_upload_store_forward  <= '1';
                    local_feb_type            <= HUB_FEB_TYPE_ALL_CONST;
                    ooo_ctrl_enable           <= '0';
                    ext_pkt_read_count        <= (others => '0');
                    ext_pkt_write_count       <= (others => '0');
                    ext_word_read_count       <= (others => '0');
                    ext_word_write_count      <= (others => '0');
                    last_ext_read_addr        <= (others => '0');
                    last_ext_read_data        <= (others => '0');
                    last_ext_write_addr       <= (others => '0');
                    last_ext_write_data       <= (others => '0');
                    diag_clear_pending_v      := '0';
                    err_count_inc_pending_v   := '0';
                    issue_seq_counter         <= (others => '0');
                    complete_seq_counter      <= (others => '0');
                    soft_reset_pulse          <= '1';
                    rd_cmd_pending_valid_v    := '0';
                    rd_cmd_pending_slot_v     := 0;
                end if;

                ext_slot_words_received <= ext_slot_words_received_v;
                rd_cmd_pending_valid <= rd_cmd_pending_valid_v;
                rd_cmd_pending_slot  <= rd_cmd_pending_slot_v;
                diag_clear_pending   <= diag_clear_pending_v;
                err_count_inc_pending <= err_count_inc_pending_v;

            end if;
        end if;
    end process core_ctrl;

    rd_issue_head_reg : process(i_clk)
        variable rd_issue_valid_v      : boolean;
        variable rd_issue_slot_v       : natural range 0 to OOO_SLOT_COUNT_G - 1;
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                rd_issue_valid <= '0';
                rd_issue_slot  <= 0;
            else
                rd_issue_valid_v  := false;
                rd_issue_slot_v   := 0;

                for idx in 0 to OOO_SLOT_COUNT_G - 1 loop
                    if (
                        ext_slot_state(idx) = SLOT_WAIT_ISSUE and
                        not (rd_cmd_pending_valid = '1' and idx = rd_cmd_pending_slot) and
                        not (write_state = WR_ATOMIC_RD_WAIT_DATA and idx = 0)
                    ) then
                        rd_issue_valid_v := true;
                        rd_issue_slot_v  := idx;
                        exit;
                    end if;
                end loop;

                if (rd_issue_valid_v) then
                    rd_issue_valid <= '1';
                    rd_issue_slot  <= rd_issue_slot_v;
                else
                    rd_issue_valid <= '0';
                    rd_issue_slot  <= 0;
                end if;
            end if;
        end if;
    end process rd_issue_head_reg;

    tx_ready_head_reg : process(i_clk)
        variable tx_ooo_int_ready_valid_v : boolean;
        variable tx_ooo_int_ready_slot_v  : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1;
        variable tx_ooo_int_ready_seq_v   : unsigned(7 downto 0);
        variable tx_ooo_ext_ready_valid_v : boolean;
        variable tx_ooo_ext_ready_slot_v  : natural range 0 to OOO_SLOT_COUNT_G - 1;
        variable tx_ooo_ext_ready_seq_v   : unsigned(7 downto 0);
        variable tx_issue_int_ready_valid_v : boolean;
        variable tx_issue_int_ready_slot_v  : natural range 0 to OUTSTANDING_INT_RESERVED_G - 1;
        variable tx_issue_int_ready_seq_v   : unsigned(7 downto 0);
        variable tx_issue_ext_ready_valid_v : boolean;
        variable tx_issue_ext_ready_slot_v  : natural range 0 to OOO_SLOT_COUNT_G - 1;
        variable tx_issue_ext_ready_seq_v   : unsigned(7 downto 0);
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                tx_ooo_int_ready_valid <= '0';
                tx_ooo_int_ready_slot  <= 0;
                tx_ooo_int_ready_seq   <= (others => '0');
                tx_ooo_ext_ready_valid <= '0';
                tx_ooo_ext_ready_slot  <= 0;
                tx_ooo_ext_ready_seq   <= (others => '0');
                tx_issue_int_ready_valid <= '0';
                tx_issue_int_ready_slot  <= 0;
                tx_issue_int_ready_seq   <= (others => '0');
                tx_issue_ext_ready_valid <= '0';
                tx_issue_ext_ready_slot  <= 0;
                tx_issue_ext_ready_seq   <= (others => '0');
            else
                tx_ooo_int_ready_valid_v := false;
                tx_ooo_int_ready_slot_v  := 0;
                tx_ooo_int_ready_seq_v   := (others => '0');
                for idx in 0 to OUTSTANDING_INT_RESERVED_G - 1 loop
                    if (int_slot_valid(idx) = '1') then
                        if (
                            tx_ooo_int_ready_valid_v = false or
                            seq_precedes_func(int_slot_complete_seq(idx), tx_ooo_int_ready_seq_v)
                        ) then
                            tx_ooo_int_ready_valid_v := true;
                            tx_ooo_int_ready_slot_v  := idx;
                            tx_ooo_int_ready_seq_v   := int_slot_complete_seq(idx);
                        end if;
                    end if;
                end loop;

                tx_ooo_ext_ready_valid_v := false;
                tx_ooo_ext_ready_slot_v  := 0;
                tx_ooo_ext_ready_seq_v   := (others => '0');
                for idx in 0 to OOO_SLOT_COUNT_G - 1 loop
                    if (ext_slot_state(idx) = SLOT_READY) then
                        if (
                            tx_ooo_ext_ready_valid_v = false or
                            seq_precedes_func(ext_slot_complete_seq(idx), tx_ooo_ext_ready_seq_v)
                        ) then
                            tx_ooo_ext_ready_valid_v := true;
                            tx_ooo_ext_ready_slot_v  := idx;
                            tx_ooo_ext_ready_seq_v   := ext_slot_complete_seq(idx);
                        end if;
                    end if;
                end loop;

                tx_issue_int_ready_valid_v := false;
                tx_issue_int_ready_slot_v  := 0;
                tx_issue_int_ready_seq_v   := (others => '0');
                for idx in 0 to OUTSTANDING_INT_RESERVED_G - 1 loop
                    if (int_slot_valid(idx) = '1') then
                        if (
                            tx_issue_int_ready_valid_v = false or
                            seq_precedes_func(int_slot_issue_seq(idx), tx_issue_int_ready_seq_v)
                        ) then
                            tx_issue_int_ready_valid_v := true;
                            tx_issue_int_ready_slot_v  := idx;
                            tx_issue_int_ready_seq_v   := int_slot_issue_seq(idx);
                        end if;
                    end if;
                end loop;
                tx_issue_ext_ready_valid_v := false;
                tx_issue_ext_ready_slot_v  := 0;
                tx_issue_ext_ready_seq_v   := (others => '0');
                for idx in 0 to OOO_SLOT_COUNT_G - 1 loop
                    if (ext_slot_state(idx) = SLOT_READY) then
                        if (
                            tx_issue_ext_ready_valid_v = false or
                            seq_precedes_func(ext_slot_issue_seq(idx), tx_issue_ext_ready_seq_v)
                        ) then
                            tx_issue_ext_ready_valid_v := true;
                            tx_issue_ext_ready_slot_v  := idx;
                            tx_issue_ext_ready_seq_v   := ext_slot_issue_seq(idx);
                        end if;
                    end if;
                end loop;

                if (tx_ooo_int_ready_valid_v) then
                    tx_ooo_int_ready_valid <= '1';
                    tx_ooo_int_ready_slot  <= tx_ooo_int_ready_slot_v;
                    tx_ooo_int_ready_seq   <= tx_ooo_int_ready_seq_v;
                else
                    tx_ooo_int_ready_valid <= '0';
                    tx_ooo_int_ready_slot  <= 0;
                    tx_ooo_int_ready_seq   <= (others => '0');
                end if;

                if (tx_ooo_ext_ready_valid_v) then
                    tx_ooo_ext_ready_valid <= '1';
                    tx_ooo_ext_ready_slot  <= tx_ooo_ext_ready_slot_v;
                    tx_ooo_ext_ready_seq   <= tx_ooo_ext_ready_seq_v;
                else
                    tx_ooo_ext_ready_valid <= '0';
                    tx_ooo_ext_ready_slot  <= 0;
                    tx_ooo_ext_ready_seq   <= (others => '0');
                end if;

                if (tx_issue_int_ready_valid_v) then
                    tx_issue_int_ready_valid <= '1';
                    tx_issue_int_ready_slot  <= tx_issue_int_ready_slot_v;
                    tx_issue_int_ready_seq   <= tx_issue_int_ready_seq_v;
                else
                    tx_issue_int_ready_valid <= '0';
                    tx_issue_int_ready_slot  <= 0;
                    tx_issue_int_ready_seq   <= (others => '0');
                end if;

                if (tx_issue_ext_ready_valid_v) then
                    tx_issue_ext_ready_valid <= '1';
                    tx_issue_ext_ready_slot  <= tx_issue_ext_ready_slot_v;
                    tx_issue_ext_ready_seq   <= tx_issue_ext_ready_seq_v;
                else
                    tx_issue_ext_ready_valid <= '0';
                    tx_issue_ext_ready_slot  <= 0;
                    tx_issue_ext_ready_seq   <= (others => '0');
                end if;
            end if;
        end if;
    end process tx_ready_head_reg;
end architecture rtl;
