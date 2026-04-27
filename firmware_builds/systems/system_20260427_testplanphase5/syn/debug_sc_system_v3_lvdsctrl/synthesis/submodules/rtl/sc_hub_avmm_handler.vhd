-- File name: sc_hub_avmm_handler.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.2.8
-- Date    : 20260414
-- Change  : Unconditionally clock launch_stage_data_reg/response_reg so their
--           CE is no longer gated on launch_accept_comb (which contains
--           avm_hub_waitrequest). The Qsys interconnect contributes ~5 LUT
--           levels between avm_hub_write and avm_hub_waitrequest; leaving
--           34 data/response bits enabled by that feedback cone kept the
--           transceiver_pll_clock[0] path failing by -1.206 ns after the
--           reissue_armed_reg staging. Capturing avm_hub_readdata/response
--           every cycle is safe: launch_stage_valid (still gated on accept)
--           fences consumption, and VHDL pre-edge reads ensure the handler
--           branch sees the value latched on the accept cycle.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_avmm_handler is
    generic(
        RD_TIMEOUT_CYCLES_G : positive := DEFAULT_RD_TIMEOUT_CONST;
        WR_TIMEOUT_CYCLES_G : positive := DEFAULT_WR_TIMEOUT_CONST
    );
    port(
        i_clk               : in  std_logic;
        i_rst               : in  std_logic;
        i_cmd_valid         : in  std_logic;
        o_cmd_ready         : out std_logic;
        i_cmd_is_read       : in  std_logic;
        i_cmd_nonincrement  : in  std_logic;
        i_cmd_address       : in  std_logic_vector(17 downto 0);
        i_cmd_length        : in  std_logic_vector(15 downto 0);
        i_wr_data_valid     : in  std_logic;
        i_wr_data           : in  std_logic_vector(31 downto 0);
        o_wr_data_ready     : out std_logic;
        o_wr_accept_pulse   : out std_logic;
        o_wr_accept_address : out std_logic_vector(17 downto 0);
        o_wr_accept_data    : out std_logic_vector(31 downto 0);
        o_rd_data_valid     : out std_logic;
        o_rd_data           : out std_logic_vector(31 downto 0);
        o_rd_data_last      : out std_logic;
        o_done              : out std_logic;
        o_response          : out std_logic_vector(1 downto 0);
        o_busy              : out std_logic;
        o_timeout_pulse     : out std_logic;
        avm_hub_address      : out std_logic_vector(17 downto 0);
        avm_hub_read         : out std_logic;
        avm_hub_readdata     : in  std_logic_vector(31 downto 0);
        avm_hub_writeresponsevalid : in  std_logic;
        avm_hub_response     : in  std_logic_vector(1 downto 0);
        avm_hub_write        : out std_logic;
        avm_hub_writedata    : out std_logic_vector(31 downto 0);
        avm_hub_waitrequest  : in  std_logic;
        avm_hub_readdatavalid: in  std_logic;
        avm_hub_burstcount   : out std_logic_vector(8 downto 0)
    );
end entity sc_hub_avmm_handler;

architecture rtl of sc_hub_avmm_handler is
    type avmm_state_t is (IDLING, LAUNCHING_READ, READING_DATA, WRITING_DATA, WAITING_WRITE_RSP);

    function max_pos_func (
        lhs : positive;
        rhs : positive
    ) return positive is
    begin
        if (lhs >= rhs) then
            return lhs;
        else
            return rhs;
        end if;
    end function max_pos_func;

    constant TIMEOUT_COUNTER_MAX_C : positive := max_pos_func(RD_TIMEOUT_CYCLES_G, WR_TIMEOUT_CYCLES_G);
    subtype timeout_counter_t is natural range 0 to TIMEOUT_COUNTER_MAX_C;

    signal avmm_state          : avmm_state_t := IDLING;
    signal cmd_address_reg     : std_logic_vector(17 downto 0) := (others => '0');
    signal cmd_nonincrement_reg : std_logic := '0';
    signal cmd_length_reg      : unsigned(15 downto 0) := (others => '0');
    signal words_seen          : unsigned(15 downto 0) := (others => '0');
    signal wr_addr_cursor_reg  : std_logic_vector(17 downto 0) := (others => '0');
    signal wr_words_remaining_reg : unsigned(15 downto 0) := (others => '0');
    signal timeout_counter     : timeout_counter_t := 0;
    signal response_reg        : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal launch_stage_valid  : std_logic := '0';
    signal launch_stage_data_valid : std_logic := '0';
    signal launch_stage_data_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal launch_stage_response_reg : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal reissue_armed_reg   : std_logic := '0';
    signal launch_reissue_read : std_logic;
    signal launch_read_comb    : std_logic;
    signal launch_accept_comb  : std_logic;
    signal write_accept_comb   : std_logic;
    signal rd_data_valid_pulse : std_logic := '0';
    signal rd_data_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal rd_data_last_pulse  : std_logic := '0';
    signal done_pulse          : std_logic := '0';
    signal timeout_pulse       : std_logic := '0';
    signal wr_accept_pulse     : std_logic := '0';
    signal wr_accept_address_reg : std_logic_vector(17 downto 0) := (others => '0');
    signal wr_accept_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
begin
    avm_hub_address    <= cmd_address_reg;
    avm_hub_burstcount <= std_logic_vector(to_unsigned(1, avm_hub_burstcount'length))
        when (cmd_nonincrement_reg = '1')
        else std_logic_vector(resize(cmd_length_reg(8 downto 0), avm_hub_burstcount'length));
    avm_hub_writedata  <= i_wr_data;

    -- Keep the launch pulse combinational, but only let the staged acceptance
    -- result drive the next state/timeout logic on the following cycle.
    launch_reissue_read <= '1' when (
        avmm_state = LAUNCHING_READ and
        launch_stage_valid = '1' and
        launch_stage_data_valid = '1' and
        reissue_armed_reg = '1'
    ) else '0';
    launch_read_comb <= '1' when (
        avmm_state = LAUNCHING_READ and
        (launch_stage_valid = '0' or launch_reissue_read = '1')
    ) else '0';
    launch_accept_comb <= '1' when (
        launch_read_comb = '1' and avm_hub_waitrequest = '0'
    ) else '0';
    write_accept_comb <= '1' when (
        avmm_state = WRITING_DATA and
        i_wr_data_valid = '1' and
        avm_hub_waitrequest = '0'
    ) else '0';

    avm_hub_read  <= launch_read_comb;
    avm_hub_write <= '1' when (avmm_state = WRITING_DATA and i_wr_data_valid = '1') else '0';

    o_cmd_ready     <= '1' when (avmm_state = IDLING) else '0';
    o_wr_data_ready <= '1' when (avmm_state = WRITING_DATA and avm_hub_waitrequest = '0') else '0';
    o_wr_accept_pulse <= wr_accept_pulse;
    o_wr_accept_address <= wr_accept_address_reg;
    o_wr_accept_data <= wr_accept_data_reg;
    o_rd_data_valid <= rd_data_valid_pulse;
    o_rd_data       <= rd_data_reg;
    o_rd_data_last  <= rd_data_last_pulse;
    o_done          <= done_pulse;
    o_response      <= response_reg;
    o_busy          <= '0' when (avmm_state = IDLING) else '1';
    o_timeout_pulse <= timeout_pulse;

    bus_handler : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                avmm_state          <= IDLING;
                cmd_address_reg     <= (others => '0');
                cmd_nonincrement_reg <= '0';
                cmd_length_reg      <= (others => '0');
                words_seen          <= (others => '0');
                wr_addr_cursor_reg  <= (others => '0');
                wr_words_remaining_reg <= (others => '0');
                timeout_counter     <= 0;
                response_reg        <= SC_RSP_OK_CONST;
                launch_stage_valid  <= '0';
                launch_stage_data_valid <= '0';
                launch_stage_data_reg <= (others => '0');
                launch_stage_response_reg <= SC_RSP_OK_CONST;
                reissue_armed_reg   <= '0';
                rd_data_valid_pulse <= '0';
                rd_data_reg         <= (others => '0');
                rd_data_last_pulse  <= '0';
                done_pulse          <= '0';
                timeout_pulse       <= '0';
                wr_accept_pulse     <= '0';
                wr_accept_address_reg <= (others => '0');
                wr_accept_data_reg  <= (others => '0');
            else
                rd_data_valid_pulse <= '0';
                rd_data_last_pulse  <= '0';
                done_pulse          <= '0';
                timeout_pulse       <= '0';
                wr_accept_pulse     <= '0';

                -- Unconditional capture: decouples launch_stage_data_reg and
                -- launch_stage_response_reg CE from avm_hub_waitrequest, lifting
                -- 34 bits out of the interconnect feedback cone. Consumption is
                -- still fenced by launch_stage_valid, so only the value latched
                -- on the accept cycle is ever observed.
                launch_stage_data_reg <= avm_hub_readdata;
                launch_stage_response_reg <= avm_hub_response;

                case avmm_state is
                    when IDLING =>
                        timeout_counter <= 0;
                        words_seen      <= (others => '0');
                        wr_addr_cursor_reg <= (others => '0');
                        wr_words_remaining_reg <= (others => '0');
                        launch_stage_valid <= '0';
                        launch_stage_data_valid <= '0';
                        reissue_armed_reg <= '0';
                        if (i_cmd_valid = '1') then
                            cmd_address_reg <= i_cmd_address;
                            cmd_nonincrement_reg <= i_cmd_nonincrement;
                            cmd_length_reg  <= unsigned(i_cmd_length);
                            wr_addr_cursor_reg <= i_cmd_address;
                            wr_words_remaining_reg <= unsigned(i_cmd_length);
                            response_reg    <= SC_RSP_OK_CONST;
                            if (i_cmd_is_read = '1') then
                                avmm_state <= LAUNCHING_READ;
                                if (i_cmd_nonincrement = '1' and
                                    unsigned(i_cmd_length) > to_unsigned(1, i_cmd_length'length)) then
                                    reissue_armed_reg <= '1';
                                else
                                    reissue_armed_reg <= '0';
                                end if;
                            else
                                avmm_state <= WRITING_DATA;
                            end if;
                        end if;

                    when LAUNCHING_READ =>
                        timeout_counter <= 0;
                        if (launch_stage_valid = '1') then
                            launch_stage_valid <= '0';
                            launch_stage_data_valid <= '0';

                            if (launch_stage_data_valid = '1') then
                                rd_data_valid_pulse <= '1';

                                if (launch_stage_response_reg = SC_RSP_SLVERR_CONST) then
                                    rd_data_reg  <= x"BBADBEEF";
                                    response_reg <= launch_stage_response_reg;
                                elsif (launch_stage_response_reg = SC_RSP_DECERR_CONST) then
                                    rd_data_reg  <= x"DEADBEEF";
                                    response_reg <= launch_stage_response_reg;
                                else
                                    rd_data_reg <= launch_stage_data_reg;
                                end if;

                                if (launch_stage_response_reg /= SC_RSP_OK_CONST) then
                                    response_reg <= launch_stage_response_reg;
                                end if;

                                if (words_seen + to_unsigned(1, words_seen'length) >= cmd_length_reg) then
                                    rd_data_last_pulse <= '1';
                                    done_pulse         <= '1';
                                    avmm_state         <= IDLING;
                                elsif (cmd_nonincrement_reg = '1') then
                                    avmm_state <= LAUNCHING_READ;
                                else
                                    avmm_state <= READING_DATA;
                                end if;

                                words_seen <= words_seen + to_unsigned(1, words_seen'length);
                                if (cmd_nonincrement_reg = '1' and
                                    (words_seen + to_unsigned(2, words_seen'length) < cmd_length_reg)) then
                                    reissue_armed_reg <= '1';
                                else
                                    reissue_armed_reg <= '0';
                                end if;
                            else
                                avmm_state <= READING_DATA;
                            end if;
                        end if;

                        if (launch_accept_comb = '1') then
                            launch_stage_valid <= '1';
                            launch_stage_data_valid <= avm_hub_readdatavalid;
                        end if;

                    when READING_DATA =>
                        if (avm_hub_readdatavalid = '1') then
                            rd_data_valid_pulse <= '1';
                            timeout_counter     <= 0;

                            if (avm_hub_response = SC_RSP_SLVERR_CONST) then
                                rd_data_reg  <= x"BBADBEEF";
                                response_reg <= avm_hub_response;
                            elsif (avm_hub_response = SC_RSP_DECERR_CONST) then
                                rd_data_reg  <= x"DEADBEEF";
                                response_reg <= avm_hub_response;
                            else
                                rd_data_reg <= avm_hub_readdata;
                            end if;

                            if (avm_hub_response /= SC_RSP_OK_CONST) then
                                response_reg <= avm_hub_response;
                            end if;

                            if (words_seen + 1 >= cmd_length_reg) then
                                rd_data_last_pulse <= '1';
                                done_pulse         <= '1';
                                avmm_state         <= IDLING;
                            elsif (cmd_nonincrement_reg = '1') then
                                avmm_state <= LAUNCHING_READ;
                            end if;

                            words_seen <= words_seen + 1;
                            if (cmd_nonincrement_reg = '1' and
                                (words_seen + to_unsigned(2, words_seen'length) < cmd_length_reg)) then
                                reissue_armed_reg <= '1';
                            else
                                reissue_armed_reg <= '0';
                            end if;
                        elsif (timeout_counter + 1 >= RD_TIMEOUT_CYCLES_G) then
                            response_reg    <= SC_RSP_DECERR_CONST;
                            done_pulse      <= '1';
                            timeout_pulse   <= '1';
                            timeout_counter <= 0;
                            avmm_state      <= IDLING;
                        else
                            timeout_counter <= timeout_counter + 1;
                        end if;

                    when WRITING_DATA =>
                        if (write_accept_comb = '1') then
                            wr_accept_pulse <= '1';
                            wr_accept_data_reg <= i_wr_data;
                            wr_accept_address_reg <= wr_addr_cursor_reg;

                            if (cmd_nonincrement_reg = '0') then
                                wr_addr_cursor_reg <= std_logic_vector(unsigned(wr_addr_cursor_reg) + 1);
                            end if;

                            if (wr_words_remaining_reg > 0) then
                                wr_words_remaining_reg <= wr_words_remaining_reg - 1;
                            end if;

                            if (
                                cmd_nonincrement_reg = '1' or
                                wr_words_remaining_reg <= to_unsigned(1, wr_words_remaining_reg'length)
                            ) then
                                timeout_counter <= 0;
                                avmm_state      <= WAITING_WRITE_RSP;
                            end if;
                        end if;

                    when WAITING_WRITE_RSP =>
                        if (avm_hub_writeresponsevalid = '1') then
                            if (avm_hub_response /= SC_RSP_OK_CONST) then
                                response_reg <= avm_hub_response;
                            end if;
                            if (cmd_nonincrement_reg = '1' and wr_words_remaining_reg > 0) then
                                timeout_counter <= 0;
                                avmm_state      <= WRITING_DATA;
                            else
                                done_pulse <= '1';
                                avmm_state <= IDLING;
                            end if;
                        elsif (timeout_counter + 1 >= WR_TIMEOUT_CYCLES_G) then
                            response_reg    <= SC_RSP_DECERR_CONST;
                            done_pulse      <= '1';
                            timeout_pulse   <= '1';
                            timeout_counter <= 0;
                            avmm_state      <= IDLING;
                        else
                            timeout_counter <= timeout_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process bus_handler;
end architecture rtl;
