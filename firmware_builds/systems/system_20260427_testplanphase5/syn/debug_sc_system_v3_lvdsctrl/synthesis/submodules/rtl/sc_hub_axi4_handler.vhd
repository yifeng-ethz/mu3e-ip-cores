-- File name: sc_hub_axi4_handler.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.2.0
-- Date    : 20260331
-- Change  : Add the AXI4 master transaction handler for sc_hub v2.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_axi4_handler is
    generic(
        RD_TIMEOUT_CYCLES_G : positive := DEFAULT_RD_TIMEOUT_CONST
    );
    port(
        i_clk               : in  std_logic;
        i_rst               : in  std_logic;
        i_cmd_valid         : in  std_logic;
        o_cmd_ready         : out std_logic;
        i_cmd_is_read       : in  std_logic;
        i_cmd_address       : in  std_logic_vector(17 downto 0);
        i_cmd_length        : in  std_logic_vector(15 downto 0);
        i_wr_data_valid     : in  std_logic;
        i_wr_data           : in  std_logic_vector(31 downto 0);
        o_wr_data_ready     : out std_logic;
        o_rd_data_valid     : out std_logic;
        o_rd_data           : out std_logic_vector(31 downto 0);
        o_rd_data_last      : out std_logic;
        o_done              : out std_logic;
        o_response          : out std_logic_vector(1 downto 0);
        o_busy              : out std_logic;
        o_timeout_pulse     : out std_logic;
        m_axi_awid          : out std_logic_vector(3 downto 0);
        m_axi_awaddr        : out std_logic_vector(17 downto 0);
        m_axi_awlen         : out std_logic_vector(7 downto 0);
        m_axi_awsize        : out std_logic_vector(2 downto 0);
        m_axi_awburst       : out std_logic_vector(1 downto 0);
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
        m_axi_arvalid       : out std_logic;
        m_axi_arready       : in  std_logic;
        m_axi_rid           : in  std_logic_vector(3 downto 0);
        m_axi_rdata         : in  std_logic_vector(31 downto 0);
        m_axi_rresp         : in  std_logic_vector(1 downto 0);
        m_axi_rlast         : in  std_logic;
        m_axi_rvalid        : in  std_logic;
        m_axi_rready        : out std_logic
    );
end entity sc_hub_axi4_handler;

architecture rtl of sc_hub_axi4_handler is
    type axi_state_t is (IDLING, SEND_AR, READING_DATA, SEND_AW, WRITING_DATA, WAITING_B);

    signal axi_state           : axi_state_t := IDLING;
    signal cmd_address_reg     : std_logic_vector(17 downto 0) := (others => '0');
    signal cmd_length_reg      : unsigned(15 downto 0) := (others => '0');
    signal words_seen          : unsigned(15 downto 0) := (others => '0');
    signal timeout_counter     : natural range 0 to RD_TIMEOUT_CYCLES_G := 0;
    signal response_reg        : std_logic_vector(1 downto 0) := SC_RSP_OK_CONST;
    signal rd_data_valid_pulse : std_logic := '0';
    signal rd_data_reg         : std_logic_vector(31 downto 0) := (others => '0');
    signal rd_data_last_pulse  : std_logic := '0';
    signal done_pulse          : std_logic := '0';
    signal timeout_pulse       : std_logic := '0';

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
begin
    m_axi_awid    <= (others => '0');
    m_axi_awaddr  <= cmd_address_reg;
    m_axi_awlen   <= std_logic_vector(resize(cmd_length_reg - 1, m_axi_awlen'length));
    m_axi_awsize  <= "010";
    m_axi_awburst <= "01";
    m_axi_awvalid <= '1' when (axi_state = SEND_AW) else '0';

    m_axi_wdata  <= i_wr_data;
    m_axi_wstrb  <= (others => '1');
    m_axi_wlast  <= '1' when (words_seen + 1 >= cmd_length_reg) else '0';
    m_axi_wvalid <= '1' when (axi_state = WRITING_DATA and i_wr_data_valid = '1') else '0';
    m_axi_bready <= '1' when (axi_state = WAITING_B) else '0';

    m_axi_arid    <= (others => '0');
    m_axi_araddr  <= cmd_address_reg;
    m_axi_arlen   <= std_logic_vector(resize(cmd_length_reg - 1, m_axi_arlen'length));
    m_axi_arsize  <= "010";
    m_axi_arburst <= "01";
    m_axi_arvalid <= '1' when (axi_state = SEND_AR) else '0';
    m_axi_rready  <= '1' when (axi_state = READING_DATA) else '0';

    o_cmd_ready     <= '1' when (axi_state = IDLING) else '0';
    o_wr_data_ready <= '1' when (axi_state = WRITING_DATA and m_axi_wready = '1') else '0';
    o_rd_data_valid <= rd_data_valid_pulse;
    o_rd_data       <= rd_data_reg;
    o_rd_data_last  <= rd_data_last_pulse;
    o_done          <= done_pulse;
    o_response      <= response_reg;
    o_busy          <= '0' when (axi_state = IDLING) else '1';
    o_timeout_pulse <= timeout_pulse;

    bus_handler : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                axi_state           <= IDLING;
                cmd_address_reg     <= (others => '0');
                cmd_length_reg      <= (others => '0');
                words_seen          <= (others => '0');
                timeout_counter     <= 0;
                response_reg        <= SC_RSP_OK_CONST;
                rd_data_valid_pulse <= '0';
                rd_data_reg         <= (others => '0');
                rd_data_last_pulse  <= '0';
                done_pulse          <= '0';
                timeout_pulse       <= '0';
            else
                rd_data_valid_pulse <= '0';
                rd_data_last_pulse  <= '0';
                done_pulse          <= '0';
                timeout_pulse       <= '0';

                case axi_state is
                    when IDLING =>
                        timeout_counter <= 0;
                        words_seen      <= (others => '0');
                        if (i_cmd_valid = '1') then
                            cmd_address_reg <= i_cmd_address;
                            cmd_length_reg  <= unsigned(i_cmd_length);
                            response_reg    <= SC_RSP_OK_CONST;
                            if (i_cmd_is_read = '1') then
                                axi_state <= SEND_AR;
                            else
                                axi_state <= SEND_AW;
                            end if;
                        end if;

                    when SEND_AR =>
                        if (m_axi_arready = '1') then
                            timeout_counter <= 0;
                            axi_state       <= READING_DATA;
                        end if;

                    when READING_DATA =>
                        if (m_axi_rvalid = '1') then
                            rd_data_valid_pulse <= '1';
                            rd_data_last_pulse  <= m_axi_rlast;
                            timeout_counter     <= 0;

                            if (axi_rsp_map_func(m_axi_rresp) = SC_RSP_SLVERR_CONST) then
                                rd_data_reg  <= x"BBADBEEF";
                                response_reg <= axi_rsp_map_func(m_axi_rresp);
                            elsif (axi_rsp_map_func(m_axi_rresp) = SC_RSP_DECERR_CONST) then
                                rd_data_reg  <= x"DEADBEEF";
                                response_reg <= axi_rsp_map_func(m_axi_rresp);
                            else
                                rd_data_reg <= m_axi_rdata;
                            end if;

                            if (m_axi_rresp /= "00") then
                                response_reg <= axi_rsp_map_func(m_axi_rresp);
                            end if;

                            if (m_axi_rlast = '1' or words_seen + 1 >= cmd_length_reg) then
                                done_pulse <= '1';
                                axi_state  <= IDLING;
                            end if;

                            words_seen <= words_seen + 1;
                        elsif (timeout_counter + 1 >= RD_TIMEOUT_CYCLES_G) then
                            response_reg    <= SC_RSP_DECERR_CONST;
                            done_pulse      <= '1';
                            timeout_pulse   <= '1';
                            timeout_counter <= 0;
                            axi_state       <= IDLING;
                        else
                            timeout_counter <= timeout_counter + 1;
                        end if;

                    when SEND_AW =>
                        if (m_axi_awready = '1') then
                            axi_state <= WRITING_DATA;
                        end if;

                    when WRITING_DATA =>
                        if (i_wr_data_valid = '1' and m_axi_wready = '1') then
                            if (words_seen + 1 >= cmd_length_reg) then
                                axi_state       <= WAITING_B;
                                timeout_counter <= 0;
                            end if;
                            words_seen <= words_seen + 1;
                        end if;

                    when WAITING_B =>
                        if (m_axi_bvalid = '1') then
                            response_reg <= axi_rsp_map_func(m_axi_bresp);
                            done_pulse   <= '1';
                            axi_state    <= IDLING;
                        elsif (timeout_counter + 1 >= RD_TIMEOUT_CYCLES_G) then
                            response_reg    <= SC_RSP_DECERR_CONST;
                            done_pulse      <= '1';
                            timeout_counter <= 0;
                            axi_state       <= IDLING;
                        else
                            timeout_counter <= timeout_counter + 1;
                        end if;
                end case;
            end if;
        end if;
    end process bus_handler;
end architecture rtl;
