-- File name: sc_hub_pkg.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.6.1
-- Date    : 20260411
-- Change  : Release-align shared protocol helpers to v26.6.1 with explicit
--           M/S/T execution masks, spec-book reply-ack semantics, local FEB
--           type selection, and non-incrementing command helpers.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package sc_hub_pkg is
    constant K285_CONST                     : std_logic_vector(7 downto 0)  := x"BC";
    constant K284_CONST                     : std_logic_vector(7 downto 0)  := x"9C";
    constant SKIP_WORD_CONST                : std_logic_vector(31 downto 0) := x"000000BC";
    constant EMPTY_WORD40_CONST             : std_logic_vector(39 downto 0) := (others => '0');
    constant EMPTY_WORD32_CONST             : std_logic_vector(31 downto 0) := (others => '0');
    constant HUB_UID_CONST                   : std_logic_vector(31 downto 0) := x"53434842"; -- ASCII "SCHB"
    constant HUB_CSR_BASE_ADDR_CONST        : natural := 16#FE80#;
    constant HUB_CSR_WINDOW_WORDS_CONST     : natural := 32;
    constant MAX_BURST_WORDS_CONST          : natural := 256;
    constant DEFAULT_RD_TIMEOUT_CONST       : natural := 200;
    constant DEFAULT_WR_TIMEOUT_CONST       : natural := 200;
    constant DEFAULT_DL_FIFO_DEPTH_CONST    : natural := 256;
    constant DEFAULT_BP_FIFO_DEPTH_CONST    : natural := 512;
    constant DEFAULT_PKT_TIMEOUT_CONST      : natural := 64;

    constant HUB_CSR_WO_UID_CONST            : natural := 16#000#;
    constant HUB_CSR_WO_META_CONST          : natural := 16#001#;
    constant HUB_CSR_WO_CTRL_CONST          : natural := 16#002#;
    constant HUB_CSR_WO_STATUS_CONST        : natural := 16#003#;
    constant HUB_CSR_WO_ERR_FLAGS_CONST     : natural := 16#004#;
    constant HUB_CSR_WO_ERR_COUNT_CONST     : natural := 16#005#;
    constant HUB_CSR_WO_SCRATCH_CONST       : natural := 16#006#;
    constant HUB_CSR_WO_GTS_SNAP_LO_CONST   : natural := 16#007#;
    constant HUB_CSR_WO_GTS_SNAP_HI_CONST   : natural := 16#008#;
    constant HUB_CSR_WO_FIFO_CFG_CONST      : natural := 16#009#;
    constant HUB_CSR_WO_FIFO_STATUS_CONST   : natural := 16#00A#;
    constant HUB_CSR_WO_DOWN_PKT_CNT_CONST  : natural := 16#00B#;
    constant HUB_CSR_WO_UP_PKT_CNT_CONST    : natural := 16#00C#;
    constant HUB_CSR_WO_DOWN_USEDW_CONST    : natural := 16#00D#;
    constant HUB_CSR_WO_UP_USEDW_CONST      : natural := 16#00E#;
    constant HUB_CSR_WO_EXT_PKT_RD_CONST    : natural := 16#00F#;
    constant HUB_CSR_WO_EXT_PKT_WR_CONST    : natural := 16#010#;
    constant HUB_CSR_WO_EXT_WORD_RD_CONST   : natural := 16#011#;
    constant HUB_CSR_WO_EXT_WORD_WR_CONST   : natural := 16#012#;
    constant HUB_CSR_WO_LAST_RD_ADDR_CONST  : natural := 16#013#;
    constant HUB_CSR_WO_LAST_RD_DATA_CONST  : natural := 16#014#;
    constant HUB_CSR_WO_LAST_WR_ADDR_CONST  : natural := 16#015#;
    constant HUB_CSR_WO_LAST_WR_DATA_CONST  : natural := 16#016#;
    constant HUB_CSR_WO_PKT_DROP_CNT_CONST  : natural := 16#017#;
    constant HUB_CSR_WO_OOO_CTRL_CONST      : natural := 16#018#;
    constant HUB_CSR_WO_ORD_DRAIN_CNT_CONST : natural := 16#019#;
    constant HUB_CSR_WO_ORD_HOLD_CNT_CONST  : natural := 16#01A#;
    constant HUB_CSR_WO_DBG_DROP_DETAIL_CONST : natural := 16#01B#;
    constant HUB_CSR_WO_FEB_TYPE_CONST      : natural := 16#01C#;
    constant HUB_CSR_WO_HUB_CAP_CONST       : natural := 16#01F#;

    constant HUB_FEB_TYPE_ALL_CONST         : std_logic_vector(1 downto 0) := "00";
    constant HUB_FEB_TYPE_MUPIX_CONST       : std_logic_vector(1 downto 0) := "01";
    constant HUB_FEB_TYPE_SCIFI_CONST       : std_logic_vector(1 downto 0) := "10";
    constant HUB_FEB_TYPE_TILE_CONST        : std_logic_vector(1 downto 0) := "11";

    constant HUB_ERR_UP_FIFO_OVERFLOW_CONST   : natural := 0;
    constant HUB_ERR_DOWN_FIFO_OVERFLOW_CONST : natural := 1;
    constant HUB_ERR_INTERNAL_ADDR_CONST      : natural := 2;
    constant HUB_ERR_RD_TIMEOUT_CONST         : natural := 3;
    constant HUB_ERR_PKT_DROP_CONST           : natural := 4;
    constant HUB_ERR_SLVERR_CONST             : natural := 5;
    constant HUB_ERR_DECERR_CONST             : natural := 6;

    constant SC_RSP_OK_CONST                : std_logic_vector(1 downto 0) := "00";
    constant SC_RSP_SLVERR_CONST            : std_logic_vector(1 downto 0) := "10";
    constant SC_RSP_DECERR_CONST            : std_logic_vector(1 downto 0) := "11";
    constant SC_ORDER_RELAXED_CONST         : std_logic_vector(1 downto 0) := "00";
    constant SC_ORDER_RELEASE_CONST         : std_logic_vector(1 downto 0) := "01";
    constant SC_ORDER_ACQUIRE_CONST         : std_logic_vector(1 downto 0) := "10";
    constant SC_ORDER_RESERVED_CONST        : std_logic_vector(1 downto 0) := "11";

    type sc_pkt_info_t is record
        sc_type       : std_logic_vector(1 downto 0);
        fpga_id       : std_logic_vector(15 downto 0);
        start_address : std_logic_vector(23 downto 0);
        mask_m        : std_logic;
        mask_s        : std_logic;
        mask_t        : std_logic;
        mask_r        : std_logic;
        rw_length     : std_logic_vector(15 downto 0);
        order_mode    : std_logic_vector(1 downto 0);
        order_domain  : std_logic_vector(3 downto 0);
        order_epoch   : std_logic_vector(7 downto 0);
        order_scope   : std_logic_vector(1 downto 0);
        atomic_flag   : std_logic;
        atomic_mask   : std_logic_vector(31 downto 0);
        atomic_data   : std_logic_vector(31 downto 0);
    end record sc_pkt_info_t;

    constant SC_PKT_INFO_RESET_CONST : sc_pkt_info_t := (
        sc_type       => (others => '0'),
        fpga_id       => (others => '0'),
        start_address => (others => '0'),
        mask_m        => '0',
        mask_s        => '0',
        mask_t        => '0',
        mask_r        => '0',
        rw_length     => (others => '0'),
        order_mode    => SC_ORDER_RELAXED_CONST,
        order_domain  => (others => '0'),
        order_epoch   => (others => '0'),
        order_scope   => (others => '0'),
        atomic_flag   => '0',
        atomic_mask   => (others => '0'),
        atomic_data   => (others => '0')
    );

    function pack_version_func (
        version_yy    : natural;
        version_major : natural;
        version_pre   : natural;
        version_month : natural;
        version_day   : natural
    ) return std_logic_vector;

    function sat_inc32_func (
        value_in : unsigned(31 downto 0)
    ) return unsigned;

    function sat_inc16_func (
        value_in : unsigned(15 downto 0)
    ) return unsigned;

    function ceil_log2_func (
        value_in : positive
    ) return natural;

    function min_nat_func (
        lhs : natural;
        rhs : natural
    ) return natural;

    function pkt_is_read_func (
        pkt_info : sc_pkt_info_t
    ) return boolean;

    function pkt_reply_suppressed_func (
        pkt_info : sc_pkt_info_t
    ) return boolean;

    function pkt_locally_masked_func (
        pkt_info       : sc_pkt_info_t;
        local_feb_type : std_logic_vector(1 downto 0)
    ) return boolean;

    function pkt_has_download_words_func (
        pkt_info : sc_pkt_info_t
    ) return boolean;

    function pkt_is_atomic_func (
        pkt_info : sc_pkt_info_t
    ) return boolean;

    function pkt_is_nonincrementing_func (
        pkt_info : sc_pkt_info_t
    ) return boolean;
end package sc_hub_pkg;

package body sc_hub_pkg is
    function pack_version_func (
        version_yy    : natural;
        version_major : natural;
        version_pre   : natural;
        version_month : natural;
        version_day   : natural
    ) return std_logic_vector is
        variable version_v : unsigned(31 downto 0);
    begin
        version_v               := (others => '0');
        version_v(31 downto 24) := to_unsigned(version_yy, 8);
        version_v(23 downto 18) := to_unsigned(version_major, 6);
        version_v(17 downto 16) := to_unsigned(version_pre, 2);
        version_v(15 downto 8)  := to_unsigned(version_month, 8);
        version_v(7 downto 0)   := to_unsigned(version_day, 8);
        return std_logic_vector(version_v);
    end function pack_version_func;

    function sat_inc32_func (
        value_in : unsigned(31 downto 0)
    ) return unsigned is
        constant max_value_const : unsigned(value_in'range) := (others => '1');
    begin
        if (value_in = max_value_const) then
            return value_in;
        else
            return value_in + 1;
        end if;
    end function sat_inc32_func;

    function sat_inc16_func (
        value_in : unsigned(15 downto 0)
    ) return unsigned is
        constant max_value_const : unsigned(value_in'range) := (others => '1');
    begin
        if (value_in = max_value_const) then
            return value_in;
        else
            return value_in + 1;
        end if;
    end function sat_inc16_func;

    function ceil_log2_func (
        value_in : positive
    ) return natural is
        variable bit_count_v : natural := 0;
        variable span_v      : natural := 1;
    begin
        while (span_v < value_in) loop
            span_v      := span_v * 2;
            bit_count_v := bit_count_v + 1;
        end loop;
        return bit_count_v;
    end function ceil_log2_func;

    function min_nat_func (
        lhs : natural;
        rhs : natural
    ) return natural is
    begin
        if (lhs < rhs) then
            return lhs;
        else
            return rhs;
        end if;
    end function min_nat_func;

    function pkt_is_read_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
    begin
        return (pkt_info.sc_type(0) = '0');
    end function pkt_is_read_func;

    function pkt_reply_suppressed_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
    begin
        return (pkt_info.mask_r = '1');
    end function pkt_reply_suppressed_func;

    function pkt_locally_masked_func (
        pkt_info       : sc_pkt_info_t;
        local_feb_type : std_logic_vector(1 downto 0)
    ) return boolean is
    begin
        case local_feb_type is
            when HUB_FEB_TYPE_MUPIX_CONST =>
                return (pkt_info.mask_m = '1');
            when HUB_FEB_TYPE_SCIFI_CONST =>
                return (pkt_info.mask_s = '1');
            when HUB_FEB_TYPE_TILE_CONST =>
                return (pkt_info.mask_t = '1');
            when others =>
                return (pkt_info.mask_m = '1' or pkt_info.mask_s = '1' or pkt_info.mask_t = '1');
        end case;
    end function pkt_locally_masked_func;

    function pkt_has_download_words_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
    begin
        return (pkt_info.sc_type(0) = '1' or pkt_info.atomic_flag = '1');
    end function pkt_has_download_words_func;

    function pkt_is_atomic_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
    begin
        return (pkt_info.atomic_flag = '1');
    end function pkt_is_atomic_func;

    function pkt_is_nonincrementing_func (
        pkt_info : sc_pkt_info_t
    ) return boolean is
    begin
        return (pkt_info.sc_type(1) = '1');
    end function pkt_is_nonincrementing_func;
end package body sc_hub_pkg;
