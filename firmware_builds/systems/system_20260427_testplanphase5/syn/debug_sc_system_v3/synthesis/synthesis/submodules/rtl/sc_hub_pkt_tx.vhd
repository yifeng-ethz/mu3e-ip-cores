-- File name: sc_hub_pkt_tx.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.6.1
-- Date    : 20260411
-- Change  : Restore the spec-book reply acknowledge marker on bit 16 while
--           keeping the v2 response code in surrounding reserved bits.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_pkt_tx is
    generic(
        BP_FIFO_DEPTH_G : positive := DEFAULT_BP_FIFO_DEPTH_CONST
    );
    port(
        i_clk                       : in  std_logic;
        i_rst                       : in  std_logic;
        i_soft_reset                : in  std_logic;
        i_reply_start               : in  std_logic;
        i_reply_info                : in  sc_pkt_info_t;
        i_reply_response            : in  std_logic_vector(1 downto 0);
        i_reply_has_data            : in  std_logic;
        i_reply_suppress            : in  std_logic;
        o_reply_ready               : out std_logic;
        o_reply_done                : out std_logic;
        i_data_valid                : in  std_logic;
        i_data_word                 : in  std_logic_vector(31 downto 0);
        o_data_ready                : out std_logic;
        aso_upload_data             : out std_logic_vector(35 downto 0);
        aso_upload_valid            : out std_logic;
        aso_upload_ready            : in  std_logic;
        aso_upload_startofpacket    : out std_logic;
        aso_upload_endofpacket      : out std_logic;
        o_bp_usedw                  : out std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH_G + 1) - 1 downto 0);
        o_bp_full                   : out std_logic;
        o_bp_half_full              : out std_logic;
        o_bp_overflow               : out std_logic;
        o_bp_overflow_pulse         : out std_logic;
        o_pkt_count                 : out std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH_G + 1) - 1 downto 0)
    );
end entity sc_hub_pkt_tx;

architecture rtl of sc_hub_pkt_tx is
    type tx_state_t is (IDLING, EMITTING_PREAMBLE, EMITTING_ADDRESS, EMITTING_HEADER, EMITTING_DATA, EMITTING_TRAILER);

    signal tx_state             : tx_state_t := IDLING;
    signal reply_info_reg       : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal reply_response_reg   : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal reply_has_data_reg   : std_logic := '0';
    signal words_remaining      : unsigned(15 downto 0) := (others => '0');
    signal bp_fifo_write_en     : std_logic := '0';
    signal bp_fifo_write_data   : std_logic_vector(39 downto 0) := (others => '0');
    signal bp_fifo_read_en      : std_logic := '0';
    signal bp_fifo_read_data    : std_logic_vector(39 downto 0);
    signal bp_fifo_empty        : std_logic;
    signal bp_fifo_full         : std_logic;
    signal bp_fifo_half_full    : std_logic;
    signal bp_fifo_usedw        : std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH_G + 1) - 1 downto 0);
    signal reply_done_pulse     : std_logic := '0';
    signal bp_overflow_sticky   : std_logic := '0';
    signal bp_overflow_pulse    : std_logic := '0';
    signal pkt_count            : natural range 0 to BP_FIFO_DEPTH_G := 0;
    signal pkt_inc_pending      : std_logic := '0';
    signal data_stage_valid     : std_logic := '0';
    signal data_stage_word      : std_logic_vector(31 downto 0) := (others => '0');

    function required_words_func (
        reply_has_data : std_logic;
        reply_length   : std_logic_vector(15 downto 0)
    ) return natural is
    begin
        if (reply_has_data = '1') then
            return 4 + to_integer(unsigned(reply_length));
        else
            return 4;
        end if;
    end function required_words_func;
begin
    bp_fifo_inst : entity work.sc_hub_fifo_bp
    generic map(
        DEPTH_G => BP_FIFO_DEPTH_G
    )
    port map(
        csi_clk    => i_clk,
        rsi_reset  => i_rst,
        clear      => i_soft_reset,
        write_en   => bp_fifo_write_en,
        write_data => bp_fifo_write_data,
        read_en    => bp_fifo_read_en,
        read_data  => bp_fifo_read_data,
        empty      => bp_fifo_empty,
        full       => bp_fifo_full,
        half_full  => bp_fifo_half_full,
        usedw      => bp_fifo_usedw
    );

    aso_upload_data(31 downto 0)  <= bp_fifo_read_data(31 downto 0);
    aso_upload_data(35 downto 32) <= bp_fifo_read_data(35 downto 32);
    aso_upload_valid              <= not bp_fifo_empty;
    aso_upload_startofpacket      <= bp_fifo_read_data(36);
    aso_upload_endofpacket        <= bp_fifo_read_data(37);

    bp_fifo_read_en <= '1' when (bp_fifo_empty = '0' and aso_upload_ready = '1') else '0';

    o_bp_usedw          <= bp_fifo_usedw;
    o_bp_full           <= bp_fifo_full;
    o_bp_half_full      <= bp_fifo_half_full;
    o_bp_overflow       <= bp_overflow_sticky;
    o_bp_overflow_pulse <= bp_overflow_pulse;
    o_pkt_count         <= std_logic_vector(to_unsigned(pkt_count, o_pkt_count'length));
    o_reply_done        <= reply_done_pulse;

    o_reply_ready <= '1'
        when (
            tx_state = IDLING and (
                i_reply_suppress = '1' or
                (BP_FIFO_DEPTH_G - to_integer(unsigned(bp_fifo_usedw))) >= required_words_func(i_reply_has_data, i_reply_info.rw_length)
            )
        )
        else '0';

    o_data_ready <= '1'
        when (
            tx_state = EMITTING_DATA and
            (data_stage_valid = '0' or bp_fifo_full = '0')
        )
        else '0';

    reply_formatter : process(i_clk)
        variable packet_word_v : std_logic_vector(39 downto 0);
        variable start_pkt_v   : boolean;
        variable wrote_word_v  : boolean;
        variable pkt_count_v   : natural range 0 to BP_FIFO_DEPTH_G;
        variable emit_stage_v  : boolean;
        variable stage_valid_v : std_logic;
        variable stage_word_v  : std_logic_vector(31 downto 0);
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1' or i_soft_reset = '1') then
                tx_state           <= IDLING;
                reply_info_reg     <= SC_PKT_INFO_RESET_CONST;
                reply_response_reg <= SC_RSP_OK_CONST;
                reply_has_data_reg <= '0';
                words_remaining    <= (others => '0');
                bp_fifo_write_en   <= '0';
                bp_fifo_write_data <= (others => '0');
                reply_done_pulse   <= '0';
                bp_overflow_sticky <= '0';
                bp_overflow_pulse  <= '0';
                pkt_count          <= 0;
                pkt_inc_pending    <= '0';
                data_stage_valid   <= '0';
                data_stage_word    <= (others => '0');
            else
                bp_fifo_write_en   <= '0';
                bp_fifo_write_data <= (others => '0');
                reply_done_pulse   <= '0';
                bp_overflow_pulse  <= '0';
                start_pkt_v        := false;
                wrote_word_v       := false;
                packet_word_v      := (others => '0');
                pkt_count_v        := pkt_count;
                emit_stage_v       := false;
                stage_valid_v      := data_stage_valid;
                stage_word_v       := data_stage_word;

                if (bp_fifo_read_en = '1' and bp_fifo_read_data(37) = '1' and pkt_count_v > 0) then
                    pkt_count_v := pkt_count_v - 1;
                end if;

                if (pkt_inc_pending = '1' and pkt_count_v < BP_FIFO_DEPTH_G) then
                    pkt_count_v := pkt_count_v + 1;
                end if;

                pkt_inc_pending <= '0';

                if (i_reply_start = '1') then
                    if (i_reply_suppress = '1') then
                        reply_done_pulse <= '1';
                        tx_state         <= IDLING;
                    else
                        reply_info_reg     <= i_reply_info;
                        reply_response_reg <= i_reply_response;
                        reply_has_data_reg <= i_reply_has_data;
                        words_remaining    <= unsigned(i_reply_info.rw_length);
                        tx_state           <= EMITTING_PREAMBLE;
                        start_pkt_v        := true;
                        pkt_inc_pending    <= '1';
                        stage_valid_v      := '0';
                        stage_word_v       := (others => '0');
                    end if;
                end if;

                case tx_state is
                    when IDLING =>
                        null;

                    when EMITTING_PREAMBLE =>
                        packet_word_v(31 downto 0) := "000111" & reply_info_reg.sc_type & reply_info_reg.fpga_id & K285_CONST;
                        packet_word_v(35 downto 32) := "0001";
                        packet_word_v(36) := '1';
                        wrote_word_v      := true;
                        tx_state          <= EMITTING_ADDRESS;

                    when EMITTING_ADDRESS =>
                        packet_word_v(31 downto 30) := reply_info_reg.order_mode;
                        packet_word_v(29)           := '0';
                        packet_word_v(28)           := reply_info_reg.atomic_flag;
                        packet_word_v(27)           := reply_info_reg.mask_m;
                        packet_word_v(26)           := reply_info_reg.mask_s;
                        packet_word_v(25)           := reply_info_reg.mask_t;
                        packet_word_v(24)           := reply_info_reg.mask_r;
                        packet_word_v(23 downto 0) := reply_info_reg.start_address;
                        wrote_word_v               := true;
                        tx_state                   <= EMITTING_HEADER;

                    when EMITTING_HEADER =>
                        -- Keep the chapter 4.7 acknowledge marker on bit 16.
                        -- Any v2-only metadata must stay in the surrounding reserved bits.
                        packet_word_v(31 downto 28) := reply_info_reg.order_domain;
                        packet_word_v(27 downto 20) := reply_info_reg.order_epoch;
                        packet_word_v(19 downto 18) := reply_response_reg;
                        packet_word_v(17)           := '0';
                        packet_word_v(16)           := '1';
                        packet_word_v(15 downto 0)  := reply_info_reg.rw_length;
                        wrote_word_v                := true;
                        if (reply_has_data_reg = '1' and unsigned(reply_info_reg.rw_length) /= 0) then
                            tx_state <= EMITTING_DATA;
                        else
                            tx_state <= EMITTING_TRAILER;
                        end if;

                    when EMITTING_DATA =>
                        if (data_stage_valid = '1' and bp_fifo_full = '0') then
                            packet_word_v(31 downto 0) := data_stage_word;
                            wrote_word_v               := true;
                            emit_stage_v               := true;
                            if (words_remaining > 0) then
                                words_remaining <= words_remaining - 1;
                            end if;

                            if (words_remaining = 1) then
                                tx_state <= EMITTING_TRAILER;
                            end if;
                        end if;

                    when EMITTING_TRAILER =>
                        packet_word_v(7 downto 0)  := K284_CONST;
                        packet_word_v(35 downto 32) := "0001";
                        packet_word_v(37)          := '1';
                        wrote_word_v               := true;
                        tx_state                   <= IDLING;
                        reply_done_pulse           <= '1';
                end case;

                if (tx_state = EMITTING_DATA) then
                    if (i_data_valid = '1' and (data_stage_valid = '0' or bp_fifo_full = '0')) then
                        stage_valid_v := '1';
                        stage_word_v  := i_data_word;
                    elsif (emit_stage_v = true) then
                        stage_valid_v := '0';
                        stage_word_v  := (others => '0');
                    end if;
                end if;

                if (wrote_word_v = true) then
                    if (bp_fifo_full = '0') then
                        bp_fifo_write_en   <= '1';
                        bp_fifo_write_data <= packet_word_v;
                    else
                        bp_overflow_sticky <= '1';
                        bp_overflow_pulse  <= '1';
                    end if;
                end if;

                pkt_count <= pkt_count_v;
                data_stage_valid <= stage_valid_v;
                data_stage_word  <= stage_word_v;
            end if;
        end if;
    end process reply_formatter;
end architecture rtl;
