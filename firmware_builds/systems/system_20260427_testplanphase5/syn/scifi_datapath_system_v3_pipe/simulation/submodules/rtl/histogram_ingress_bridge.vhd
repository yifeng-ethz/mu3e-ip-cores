-- File name: histogram_ingress_bridge.vhd
-- Author: OpenAI Codex
-- =======================================
-- Revision: 26.0.2
--     Date: 20260425
--     Change: Add optional post-hit-stack hit-word filtering so frame
--             protocol words are drained locally and not counted by the
--             histogram tap.
-- =========
-- Description:
--     This bridge replaces the previous "duplicate the datapath into two histogram
--     instances" topology with one explicit tap/selector stage:
--       - pre_in  -> pre_out  (always forwarded to hit_stack_subsystem)
--       - post_in -> post_out (forwarded when ENABLE_POST_FORWARD = 1)
--       - hist_out receives either pre_in or post_in, selected by CSR
--
--     The requested source selection is software-controlled. A change is applied
--     only when both packetized inputs are idle, so the histogram tap never
--     switches in the middle of an observed packet.
--     When ENABLE_POST_FORWARD = 0, the post input becomes a histogram tap only:
--     it drains idle packets locally when the pre path is selected, so a split
--     copy of the post stream does not backpressure the primary datapath.
--     When FILTER_POST_HIT_WORDS = 1, the selected post tap only forwards
--     real hit words after a K23.7 subheader. Frame headers, debug words,
--     zero-hit subheaders, and trailers are consumed without asserting
--     hist_out.valid.
--
-- ================ synthesizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity histogram_ingress_bridge is
    generic (
        VERSION_MAJOR    : natural := 26;
        VERSION_MINOR    : natural := 0;
        VERSION_PATCH    : natural := 2;
        BUILD    : natural := 425;
        IP_UID    : natural := 1212764994;  -- ASCII "HISB"
        VERSION_DATE    : natural := 20260425;
        VERSION_GIT    : natural := 481097348;
        INSTANCE_ID    : natural := 0;
        DEFAULT_SELECT_POST    : natural := 0;
        ENABLE_POST_FORWARD    : natural := 1;
        FILTER_POST_HIT_WORDS    : natural := 0
    );
    port (
        avs_csr_address    : in  std_logic_vector(1 downto 0);
        avs_csr_read    : in  std_logic;
        avs_csr_write    : in  std_logic;
        avs_csr_writedata    : in  std_logic_vector(31 downto 0);
        avs_csr_readdata    : out std_logic_vector(31 downto 0);
        avs_csr_waitrequest    : out std_logic;

        asi_pre_data    : in  std_logic_vector(38 downto 0);
        asi_pre_valid    : in  std_logic;
        asi_pre_ready    : out std_logic;
        asi_pre_startofpacket    : in  std_logic;
        asi_pre_endofpacket    : in  std_logic;
        asi_pre_channel    : in  std_logic_vector(3 downto 0);
        asi_pre_empty    : in  std_logic;
        asi_pre_error    : in  std_logic;

        aso_pre_data    : out std_logic_vector(38 downto 0);
        aso_pre_valid    : out std_logic;
        aso_pre_ready    : in  std_logic;
        aso_pre_startofpacket    : out std_logic;
        aso_pre_endofpacket    : out std_logic;
        aso_pre_channel    : out std_logic_vector(3 downto 0);
        aso_pre_empty    : out std_logic;
        aso_pre_error    : out std_logic;

        asi_post_data    : in  std_logic_vector(35 downto 0);
        asi_post_valid    : in  std_logic;
        asi_post_ready    : out std_logic;
        asi_post_startofpacket    : in  std_logic;
        asi_post_endofpacket    : in  std_logic;

        aso_post_data    : out std_logic_vector(35 downto 0);
        aso_post_valid    : out std_logic;
        aso_post_ready    : in  std_logic;
        aso_post_startofpacket    : out std_logic;
        aso_post_endofpacket    : out std_logic;

        aso_hist_data    : out std_logic_vector(38 downto 0);
        aso_hist_valid    : out std_logic;
        aso_hist_ready    : in  std_logic;
        aso_hist_startofpacket    : out std_logic;
        aso_hist_endofpacket    : out std_logic;
        aso_hist_channel    : out std_logic_vector(3 downto 0);

        rsi_reset_reset    : in  std_logic;
        csi_clock_clk    : in  std_logic
    );
end entity histogram_ingress_bridge;

architecture rtl of histogram_ingress_bridge is

    function enable_bit(value : natural) return std_logic is
    begin
        if value = 0 then
            return '0';
        end if;
        return '1';
    end function enable_bit;

    constant UID_WORD_CONST    : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_unsigned(IP_UID, 32));
    constant META_VERSION_WORD_CONST    : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_unsigned(VERSION_MAJOR, 8)) &
        std_logic_vector(to_unsigned(VERSION_MINOR, 8)) &
        std_logic_vector(to_unsigned(VERSION_PATCH, 4)) &
        std_logic_vector(to_unsigned(BUILD, 12));
    constant META_DATE_WORD_CONST    : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_unsigned(VERSION_DATE, 32));
    constant META_GIT_WORD_CONST    : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_unsigned(VERSION_GIT, 32));
    constant META_INSTANCE_WORD_CONST    : std_logic_vector(31 downto 0) :=
        std_logic_vector(to_unsigned(INSTANCE_ID, 32));
    constant POST_CHANNEL_CONST    : std_logic_vector(3 downto 0) := (others => '0');
    constant POST_FORWARD_ENABLED_CONST    : boolean := ENABLE_POST_FORWARD /= 0;
    constant POST_HIT_FILTER_ENABLED_CONST    : boolean := FILTER_POST_HIT_WORDS /= 0;
    constant POST_HIT_FILTER_ENABLED_BIT_CONST    : std_logic := enable_bit(FILTER_POST_HIT_WORDS);
    constant K_FLAG_CONST    : std_logic_vector(3 downto 0) := "0001";
    constant K237_CONST    : std_logic_vector(7 downto 0) := x"F7";
    constant K284_CONST    : std_logic_vector(7 downto 0) := x"9C";
    constant K285_CONST    : std_logic_vector(7 downto 0) := x"BC";

    signal csr_meta_sel    : std_logic_vector(1 downto 0) := (others => '0');
    signal csr_select_post_req    : std_logic := '0';
    signal csr_select_post_live    : std_logic := '0';
    signal pre_packet_active    : std_logic := '0';
    signal post_packet_active    : std_logic := '0';
    signal post_hit_region    : std_logic := '0';

    signal pre_handshake    : std_logic;
    signal post_handshake    : std_logic;
    signal switch_pending    : std_logic;
    signal switch_safe    : std_logic;

    signal meta_word    : std_logic_vector(31 downto 0);
    signal control_word    : std_logic_vector(31 downto 0);
    signal status_word    : std_logic_vector(31 downto 0);
    signal hist_post_data    : std_logic_vector(38 downto 0);
    signal post_hist_ready    : std_logic;
    signal post_word_is_k    : std_logic;
    signal post_word_is_subheader    : std_logic;
    signal post_word_is_frame_header    : std_logic;
    signal post_word_is_frame_trailer    : std_logic;
    signal post_hist_word_accept    : std_logic;

begin

    avs_csr_waitrequest    <= '0';

    aso_pre_data    <= asi_pre_data;
    aso_pre_valid    <= asi_pre_valid;
    aso_pre_startofpacket    <= asi_pre_startofpacket;
    aso_pre_endofpacket    <= asi_pre_endofpacket;
    aso_pre_channel    <= asi_pre_channel;
    aso_pre_empty    <= asi_pre_empty;
    aso_pre_error    <= asi_pre_error;

    hist_post_data    <= "000" & asi_post_data;
    post_word_is_k    <= '1' when asi_post_data(35 downto 32) = K_FLAG_CONST else '0';
    post_word_is_subheader <= '1' when post_word_is_k = '1' and asi_post_data(7 downto 0) = K237_CONST else '0';
    post_word_is_frame_header <= '1' when post_word_is_k = '1' and asi_post_data(7 downto 0) = K285_CONST else '0';
    post_word_is_frame_trailer <= '1' when post_word_is_k = '1' and asi_post_data(7 downto 0) = K284_CONST else '0';
    post_hist_word_accept <= '1' when not POST_HIT_FILTER_ENABLED_CONST else
        '1' when post_hit_region = '1' and post_word_is_k = '0' else '0';

    asi_pre_ready    <= aso_pre_ready and (aso_hist_ready or csr_select_post_live);

    aso_hist_valid    <= asi_pre_valid when csr_select_post_live = '0' else asi_post_valid and post_hist_word_accept;
    aso_hist_data    <= asi_pre_data when csr_select_post_live = '0' else hist_post_data;
    aso_hist_startofpacket <= asi_pre_startofpacket when csr_select_post_live = '0' else '0';
    aso_hist_endofpacket    <= asi_pre_endofpacket when csr_select_post_live = '0' else '0';
    aso_hist_channel    <= asi_pre_channel when csr_select_post_live = '0' else POST_CHANNEL_CONST;

    gen_post_forward_enabled : if POST_FORWARD_ENABLED_CONST generate
    begin
        aso_post_data    <= asi_post_data;
        aso_post_valid    <= asi_post_valid;
        aso_post_startofpacket <= asi_post_startofpacket;
        aso_post_endofpacket    <= asi_post_endofpacket;

        post_hist_ready    <= aso_hist_ready or not csr_select_post_live or not post_hist_word_accept;
        asi_post_ready    <= aso_post_ready and post_hist_ready;
    end generate gen_post_forward_enabled;

    gen_post_forward_disabled : if not POST_FORWARD_ENABLED_CONST generate
    begin
        aso_post_data    <= (others => '0');
        aso_post_valid    <= '0';
        aso_post_startofpacket <= '0';
        aso_post_endofpacket    <= '0';

        post_hist_ready    <= '1' when csr_select_post_live = '0' else aso_hist_ready or not post_hist_word_accept;
        asi_post_ready    <= post_hist_ready;
    end generate gen_post_forward_disabled;

    pre_handshake    <= asi_pre_valid and asi_pre_ready;
    post_handshake    <= asi_post_valid and asi_post_ready;

    switch_pending    <= csr_select_post_req xor csr_select_post_live;
    switch_safe    <= '1' when
        pre_packet_active = '0' and
        post_packet_active = '0' and
        asi_pre_valid = '0' and
        asi_post_valid = '0'
        else '0';

    proc_csr_and_packet_state : process (csi_clock_clk)
    begin
        if rising_edge(csi_clock_clk) then
            if rsi_reset_reset = '1' then
                csr_meta_sel <= (others => '0');
                if DEFAULT_SELECT_POST = 0 then
                    csr_select_post_req    <= '0';
                    csr_select_post_live <= '0';
                else
                    csr_select_post_req    <= '1';
                    csr_select_post_live <= '1';
                end if;
                pre_packet_active    <= '0';
                post_packet_active <= '0';
                post_hit_region <= '0';
            else
                if avs_csr_write = '1' then
                    case to_integer(unsigned(avs_csr_address)) is
                        when 1 =>
                            csr_meta_sel <= avs_csr_writedata(1 downto 0);
                        when 2 =>
                            csr_select_post_req <= avs_csr_writedata(0);
                        when others =>
                            null;
                    end case;
                end if;

                if pre_handshake = '1' then
                    if asi_pre_endofpacket = '1' then
                        pre_packet_active <= '0';
                    elsif asi_pre_startofpacket = '1' then
                        pre_packet_active <= '1';
                    end if;
                end if;

                if post_handshake = '1' then
                    if asi_post_endofpacket = '1' then
                        post_packet_active <= '0';
                    elsif asi_post_startofpacket = '1' then
                        post_packet_active <= '1';
                    end if;

                    if asi_post_startofpacket = '1' or
                       post_word_is_frame_header = '1' or
                       post_word_is_frame_trailer = '1' then
                        post_hit_region <= '0';
                    elsif post_word_is_subheader = '1' then
                        post_hit_region <= '1';
                    end if;
                end if;

                if switch_pending = '1' and switch_safe = '1' then
                    csr_select_post_live <= csr_select_post_req;
                end if;
            end if;
        end if;
    end process proc_csr_and_packet_state;

    with csr_meta_sel select meta_word <=
        META_VERSION_WORD_CONST  when "00",
        META_DATE_WORD_CONST     when "01",
        META_GIT_WORD_CONST      when "10",
        META_INSTANCE_WORD_CONST when others;

    control_word    <=
        (31 downto 1 => '0') &
        csr_select_post_req;

    status_word    <=
        (31 downto 12 => '0') &
        post_hit_region &
        POST_HIT_FILTER_ENABLED_BIT_CONST &
        post_packet_active &
        pre_packet_active &
        "00000" &
        switch_pending &
        csr_select_post_req &
        csr_select_post_live;

    proc_csr_read : process (all)
    begin
        avs_csr_readdata <= (others => '0');
        if avs_csr_read = '1' then
            case to_integer(unsigned(avs_csr_address)) is
                when 0 =>
                    avs_csr_readdata <= UID_WORD_CONST;
                when 1 =>
                    avs_csr_readdata <= meta_word;
                when 2 =>
                    avs_csr_readdata <= control_word;
                when 3 =>
                    avs_csr_readdata <= status_word;
                when others =>
                    null;
            end case;
        end if;
    end process proc_csr_read;

end architecture rtl;
