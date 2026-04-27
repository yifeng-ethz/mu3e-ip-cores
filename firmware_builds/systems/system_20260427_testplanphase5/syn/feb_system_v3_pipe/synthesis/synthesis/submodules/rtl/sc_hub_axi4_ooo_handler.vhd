-- File name: sc_hub_axi4_ooo_handler.vhd
-- Author: OpenAI Codex
-- =======================================
-- Version : 26.3.0
-- Date    : 20260331
-- Change  : Add an AXI4 handler with configurable multi-outstanding reads
--           and the legacy single-write path for verification-oriented OoO.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_axi4_ooo_handler is
    generic(
        OOO_CFG_ENABLE_G          : boolean := true;
        RD_TIMEOUT_CYCLES_G       : positive := DEFAULT_RD_TIMEOUT_CONST;
        WR_TIMEOUT_CYCLES_G       : positive := DEFAULT_WR_TIMEOUT_CONST;
        MAX_READ_OUTSTANDING_G    : positive := 4
    );
    port(
        i_clk               : in  std_logic;
        i_rst               : in  std_logic;
        i_ooo_enable        : in  std_logic;
        i_rd_cmd_valid      : in  std_logic;
        o_rd_cmd_ready      : out std_logic;
        i_rd_cmd_address    : in  std_logic_vector(17 downto 0);
        i_rd_cmd_length     : in  std_logic_vector(15 downto 0);
        i_rd_cmd_nonincrement : in  std_logic;
        i_rd_cmd_tag        : in  std_logic_vector(3 downto 0);
        i_rd_cmd_lock       : in  std_logic;
        o_rd_data_valid     : out std_logic;
        o_rd_data           : out std_logic_vector(31 downto 0);
        o_rd_data_tag       : out std_logic_vector(3 downto 0);
        o_rd_done           : out std_logic;
        o_rd_done_tag       : out std_logic_vector(3 downto 0);
        o_rd_response       : out std_logic_vector(1 downto 0);
        o_rd_timeout_pulse  : out std_logic;
        i_wr_cmd_valid      : in  std_logic;
        o_wr_cmd_ready      : out std_logic;
        i_wr_cmd_address    : in  std_logic_vector(17 downto 0);
        i_wr_cmd_length     : in  std_logic_vector(15 downto 0);
        i_wr_cmd_nonincrement : in  std_logic;
        i_wr_cmd_lock       : in  std_logic;
        i_wr_data_valid     : in  std_logic;
        i_wr_data           : in  std_logic_vector(31 downto 0);
        o_wr_data_ready     : out std_logic;
        o_wr_done           : out std_logic;
        o_wr_response       : out std_logic_vector(1 downto 0);
        o_wr_timeout_pulse  : out std_logic;
        o_busy              : out std_logic;
        m_axi_awid          : out std_logic_vector(3 downto 0);
        m_axi_awaddr        : out std_logic_vector(17 downto 0);
        m_axi_awlen         : out std_logic_vector(7 downto 0);
        m_axi_awsize        : out std_logic_vector(2 downto 0);
        m_axi_awburst       : out std_logic_vector(1 downto 0);
        m_axi_awlock        : out std_logic;
        m_axi_awvalid       : out std_logic;
        m_axi_awready       : in  std_logic;
        m_axi_wdata         : out std_logic_vector(31 downto 0);
        m_axi_wstrb         : out std_logic_vector(3 downto 0);
        m_axi_wlast         : out std_logic;
        m_axi_wvalid        : out std_logic;
        m_axi_wready        : in  std_logic;
        m_axi_bid           : in  std_logic_vector(3 downto 0);
        m_axi_bresp         : in  std_logic_vector(1 downto 0);
        m_axi_bvalid        : in  std_logic;
        m_axi_bready        : out std_logic;
        m_axi_arid          : out std_logic_vector(3 downto 0);
        m_axi_araddr        : out std_logic_vector(17 downto 0);
        m_axi_arlen         : out std_logic_vector(7 downto 0);
        m_axi_arsize        : out std_logic_vector(2 downto 0);
        m_axi_arburst       : out std_logic_vector(1 downto 0);
        m_axi_arlock        : out std_logic;
        m_axi_arvalid       : out std_logic;
        m_axi_arready       : in  std_logic;
        m_axi_rid           : in  std_logic_vector(3 downto 0);
        m_axi_rdata         : in  std_logic_vector(31 downto 0);
        m_axi_rresp         : in  std_logic_vector(1 downto 0);
        m_axi_rlast         : in  std_logic;
        m_axi_rvalid        : in  std_logic;
        m_axi_rready        : out std_logic
    );
end entity sc_hub_axi4_ooo_handler;

architecture rtl of sc_hub_axi4_ooo_handler is
    type wr_state_t is (WR_IDLE, WR_SEND_AW, WR_STREAM_DATA, WR_WAIT_B);
    type beats_array_t is array (natural range <>) of unsigned(15 downto 0);
    type rsp_array_t is array (natural range <>) of std_logic_vector(1 downto 0);
    type nat_array_t is array (natural range <>) of natural range 0 to RD_TIMEOUT_CYCLES_G;
    type bool_array_t is array (natural range <>) of boolean;

    signal ar_pending_valid      : std_logic := '0';
    signal ar_pending_address    : std_logic_vector(17 downto 0) := (others => '0');
    signal ar_pending_length     : unsigned(15 downto 0) := (others => '0');
    signal ar_pending_nonincrement : std_logic := '0';
    signal ar_pending_tag        : std_logic_vector(3 downto 0) := (others => '0');
    signal ar_pending_lock       : std_logic := '0';
    signal rd_active             : std_logic_vector(0 to MAX_READ_OUTSTANDING_G - 1) := (others => '0');
    signal rd_beats_remaining    : beats_array_t(0 to MAX_READ_OUTSTANDING_G - 1) := (others => (others => '0'));
    signal rd_timeout_counter    : nat_array_t(0 to MAX_READ_OUTSTANDING_G - 1) := (others => 0);
    signal rd_response_accum     : rsp_array_t(0 to MAX_READ_OUTSTANDING_G - 1) := (others => SC_RSP_OK_CONST);
    signal rd_data_valid_pulse   : std_logic := '0';
    signal rd_data_reg           : std_logic_vector(31 downto 0) := (others => '0');
    signal rd_data_tag_reg       : std_logic_vector(3 downto 0) := (others => '0');
    signal rd_done_pulse         : std_logic := '0';
    signal rd_done_tag_reg       : std_logic_vector(3 downto 0) := (others => '0');
    signal rd_response_reg       : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal rd_timeout_pulse      : std_logic := '0';
    signal ar_reuse_hold         : std_logic := '0';

    signal wr_state              : wr_state_t := WR_IDLE;
    signal wr_address_reg        : std_logic_vector(17 downto 0) := (others => '0');
    signal wr_length_reg         : unsigned(15 downto 0) := (others => '0');
    signal wr_nonincrement_reg   : std_logic := '0';
    signal wr_words_seen         : unsigned(15 downto 0) := (others => '0');
    signal wr_timeout_counter    : natural range 0 to WR_TIMEOUT_CYCLES_G := 0;
    signal wr_done_pulse         : std_logic := '0';
    signal wr_response_reg       : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal wr_timeout_pulse      : std_logic := '0';
    signal wr_lock_reg           : std_logic := '0';

    function axi_rsp_map_func (
        axi_rsp : std_logic_vector(1 downto 0)
    ) return std_logic_vector is
    begin
        case axi_rsp is
            when "00" =>
                return SC_RSP_OK_CONST;
            when "10" =>
                return SC_RSP_SLVERR_CONST;
            when others =>
                return SC_RSP_DECERR_CONST;
        end case;
    end function axi_rsp_map_func;

    function count_active_reads_func (
        active_in : std_logic_vector
    ) return natural is
        variable count_v : natural := 0;
    begin
        for idx in active_in'range loop
            if (active_in(idx) = '1') then
                count_v := count_v + 1;
            end if;
        end loop;
        return count_v;
    end function count_active_reads_func;
begin
    assert MAX_READ_OUTSTANDING_G <= 16
        report "sc_hub_axi4_ooo_handler: MAX_READ_OUTSTANDING_G > 16 is unsupported with 4-bit AXI4 IDs"
        severity failure;

    m_axi_awid    <= (others => '0');
    m_axi_awaddr  <= wr_address_reg;
    m_axi_awlen   <= std_logic_vector(resize(wr_length_reg - 1, m_axi_awlen'length));
    m_axi_awsize  <= "010";
    m_axi_awburst <= "00" when (wr_nonincrement_reg = '1') else "01";
    m_axi_awlock  <= wr_lock_reg;
    m_axi_awvalid <= '1' when (wr_state = WR_SEND_AW) else '0';

    m_axi_wdata  <= i_wr_data;
    m_axi_wstrb  <= (others => '1');
    m_axi_wlast  <= '1' when (wr_words_seen + 1 >= wr_length_reg) else '0';
    m_axi_wvalid <= '1' when (wr_state = WR_STREAM_DATA and i_wr_data_valid = '1') else '0';
    m_axi_bready <= '1' when (wr_state = WR_WAIT_B) else '0';

    m_axi_arid    <= ar_pending_tag when OOO_CFG_ENABLE_G else (others => '0');
    m_axi_araddr  <= ar_pending_address;
    m_axi_arlen   <= std_logic_vector(resize(ar_pending_length - 1, m_axi_arlen'length));
    m_axi_arsize  <= "010";
    m_axi_arburst <= "00" when (ar_pending_nonincrement = '1') else "01";
    m_axi_arlock  <= ar_pending_lock;
    m_axi_arvalid <= ar_pending_valid and not ar_reuse_hold;
    m_axi_rready  <= '1';

    ar_reuse_hold <= '1'
        when (
            OOO_CFG_ENABLE_G and
            ar_pending_valid = '1' and
            m_axi_rvalid = '1' and
            m_axi_rlast = '1' and
            unsigned(m_axi_rid) < MAX_READ_OUTSTANDING_G and
            rd_active(to_integer(unsigned(m_axi_rid))) = '1' and
            m_axi_rid = ar_pending_tag
        )
        else '0';

    o_rd_cmd_ready <= '1'
        when (
            ar_pending_valid = '0' and
            (
                (i_ooo_enable = '1' and count_active_reads_func(rd_active) < MAX_READ_OUTSTANDING_G) or
                (i_ooo_enable = '0' and count_active_reads_func(rd_active) = 0)
            )
        )
        else '0';

    o_wr_cmd_ready <= '1' when (wr_state = WR_IDLE) else '0';
    o_wr_data_ready <= '1' when (wr_state = WR_STREAM_DATA and m_axi_wready = '1') else '0';

    o_rd_data_valid    <= rd_data_valid_pulse;
    o_rd_data          <= rd_data_reg;
    o_rd_data_tag      <= rd_data_tag_reg;
    o_rd_done          <= rd_done_pulse;
    o_rd_done_tag      <= rd_done_tag_reg;
    o_rd_response      <= rd_response_reg;
    o_rd_timeout_pulse <= rd_timeout_pulse;
    o_wr_done          <= wr_done_pulse;
    o_wr_response      <= wr_response_reg;
    o_wr_timeout_pulse <= wr_timeout_pulse;
    o_busy             <= '1'
        when (
            ar_pending_valid = '1' or
            count_active_reads_func(rd_active) /= 0 or
            wr_state /= WR_IDLE
        )
        else '0';

    bus_handler : process(i_clk)
        variable rid_idx_v             : natural;
        variable timeout_done_v        : boolean;
        variable read_done_seen_v      : boolean;
        variable beat_seen_v           : bool_array_t(0 to MAX_READ_OUTSTANDING_G - 1);
        variable rsp_v                 : std_logic_vector(1 downto 0);
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                ar_pending_valid    <= '0';
                ar_pending_address  <= (others => '0');
                ar_pending_length   <= (others => '0');
                ar_pending_nonincrement <= '0';
                ar_pending_tag      <= (others => '0');
                ar_pending_lock     <= '0';
                rd_active           <= (others => '0');
                rd_beats_remaining  <= (others => (others => '0'));
                rd_timeout_counter  <= (others => 0);
                rd_response_accum   <= (others => SC_RSP_OK_CONST);
                rd_data_valid_pulse <= '0';
                rd_data_reg         <= (others => '0');
                rd_data_tag_reg     <= (others => '0');
                rd_done_pulse       <= '0';
                rd_done_tag_reg     <= (others => '0');
                rd_response_reg     <= SC_RSP_OK_CONST;
                rd_timeout_pulse    <= '0';
                wr_state            <= WR_IDLE;
                wr_address_reg      <= (others => '0');
                wr_length_reg       <= (others => '0');
                wr_nonincrement_reg <= '0';
                wr_words_seen       <= (others => '0');
                wr_timeout_counter  <= 0;
                wr_done_pulse       <= '0';
                wr_response_reg     <= SC_RSP_OK_CONST;
                wr_timeout_pulse    <= '0';
                wr_lock_reg         <= '0';
            else
                rd_data_valid_pulse <= '0';
                rd_done_pulse       <= '0';
                rd_timeout_pulse    <= '0';
                wr_done_pulse       <= '0';
                wr_timeout_pulse    <= '0';
                timeout_done_v      := false;
                read_done_seen_v    := false;
                beat_seen_v         := (others => false);

                if (m_axi_rvalid = '1') then
                    if (OOO_CFG_ENABLE_G) then
                        rid_idx_v := to_integer(unsigned(m_axi_rid));
                    else
                        rid_idx_v := 0;
                    end if;
                    if (rid_idx_v < MAX_READ_OUTSTANDING_G and rd_active(rid_idx_v) = '1') then
                        beat_seen_v(rid_idx_v) := true;
                        rsp_v                  := axi_rsp_map_func(m_axi_rresp);
                        rd_data_valid_pulse    <= '1';
                        rd_data_tag_reg        <= m_axi_rid;

                        if (rsp_v = SC_RSP_SLVERR_CONST) then
                            rd_data_reg <= x"BBADBEEF";
                        elsif (rsp_v = SC_RSP_DECERR_CONST) then
                            rd_data_reg <= x"DEADBEEF";
                        else
                            rd_data_reg <= m_axi_rdata;
                        end if;

                        if (rsp_v /= SC_RSP_OK_CONST) then
                            rd_response_accum(rid_idx_v) <= rsp_v;
                        end if;

                        if (m_axi_rlast = '1' or rd_beats_remaining(rid_idx_v) = 1) then
                            rd_done_pulse              <= '1';
                            rd_done_tag_reg            <= m_axi_rid;
                            if (rsp_v /= SC_RSP_OK_CONST) then
                                rd_response_reg <= rsp_v;
                            else
                                rd_response_reg <= rd_response_accum(rid_idx_v);
                            end if;
                            read_done_seen_v           := true;
                            rd_active(rid_idx_v)          <= '0';
                            rd_beats_remaining(rid_idx_v) <= (others => '0');
                            rd_timeout_counter(rid_idx_v) <= 0;
                        else
                            rd_beats_remaining(rid_idx_v) <= rd_beats_remaining(rid_idx_v) - 1;
                        end if;
                    end if;
                end if;

                if (i_rd_cmd_valid = '1' and o_rd_cmd_ready = '1') then
                    ar_pending_valid   <= '1';
                    ar_pending_address <= i_rd_cmd_address;
                    ar_pending_length  <= unsigned(i_rd_cmd_length);
                    ar_pending_nonincrement <= i_rd_cmd_nonincrement;
                    ar_pending_lock    <= i_rd_cmd_lock;
                    if (OOO_CFG_ENABLE_G) then
                        ar_pending_tag <= i_rd_cmd_tag;
                    else
                        ar_pending_tag <= (others => '0');
                    end if;
                elsif (ar_pending_valid = '1' and ar_reuse_hold = '0' and m_axi_arready = '1') then
                    if (OOO_CFG_ENABLE_G) then
                        rid_idx_v := to_integer(unsigned(ar_pending_tag));
                    else
                        rid_idx_v := 0;
                    end if;
                    if (rid_idx_v < MAX_READ_OUTSTANDING_G) then
                        assert rd_active(rid_idx_v) = '0'
                            report "sc_hub_axi4_ooo_handler: AR tag reused while prior read is still active"
                            severity error;
                        rd_active(rid_idx_v)          <= '1';
                        rd_beats_remaining(rid_idx_v) <= unsigned(ar_pending_length);
                        rd_timeout_counter(rid_idx_v) <= 0;
                        rd_response_accum(rid_idx_v)  <= SC_RSP_OK_CONST;
                    end if;
                    ar_pending_valid <= '0';
                    ar_pending_lock  <= '0';
                    ar_pending_nonincrement <= '0';
                end if;

                for idx in 0 to MAX_READ_OUTSTANDING_G - 1 loop
                    if (rd_active(idx) = '1') then
                        if (beat_seen_v(idx)) then
                            rd_timeout_counter(idx) <= 0;
                        elsif (timeout_done_v = false and read_done_seen_v = false) then
                            if (rd_timeout_counter(idx) + 1 >= RD_TIMEOUT_CYCLES_G) then
                                rd_done_pulse              <= '1';
                                rd_done_tag_reg            <= std_logic_vector(to_unsigned(idx, 4));
                                rd_response_reg            <= SC_RSP_DECERR_CONST;
                                rd_timeout_pulse           <= '1';
                                rd_active(idx)             <= '0';
                                rd_beats_remaining(idx)    <= (others => '0');
                                rd_timeout_counter(idx)    <= 0;
                                rd_response_accum(idx)     <= SC_RSP_OK_CONST;
                                timeout_done_v             := true;
                            else
                                rd_timeout_counter(idx) <= rd_timeout_counter(idx) + 1;
                            end if;
                        end if;
                    end if;
                end loop;

                case wr_state is
                    when WR_IDLE =>
                        wr_words_seen      <= (others => '0');
                        wr_timeout_counter <= 0;
                        if (i_wr_cmd_valid = '1') then
                            wr_address_reg     <= i_wr_cmd_address;
                            wr_length_reg      <= unsigned(i_wr_cmd_length);
                            wr_nonincrement_reg <= i_wr_cmd_nonincrement;
                            wr_response_reg    <= SC_RSP_OK_CONST;
                            wr_lock_reg        <= i_wr_cmd_lock;
                            wr_state           <= WR_SEND_AW;
                        end if;

                    when WR_SEND_AW =>
                        if (m_axi_awready = '1') then
                            wr_state <= WR_STREAM_DATA;
                        end if;

                    when WR_STREAM_DATA =>
                        if (i_wr_data_valid = '1' and m_axi_wready = '1') then
                            if (wr_words_seen + 1 >= wr_length_reg) then
                                wr_state          <= WR_WAIT_B;
                                wr_timeout_counter <= 0;
                            end if;
                            wr_words_seen <= wr_words_seen + 1;
                        end if;

                    when WR_WAIT_B =>
                        if (m_axi_bvalid = '1') then
                            wr_response_reg <= axi_rsp_map_func(m_axi_bresp);
                            wr_done_pulse   <= '1';
                            wr_lock_reg     <= '0';
                            wr_state        <= WR_IDLE;
                        elsif (wr_timeout_counter + 1 >= WR_TIMEOUT_CYCLES_G) then
                            wr_response_reg   <= SC_RSP_DECERR_CONST;
                            wr_done_pulse     <= '1';
                            wr_timeout_pulse  <= '1';
                            wr_timeout_counter <= 0;
                            wr_lock_reg       <= '0';
                            wr_state          <= WR_IDLE;
                        else
                            wr_timeout_counter <= wr_timeout_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process bus_handler;
end architecture rtl;
