-- File name: sc_hub_top_axi4.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.6.9
-- Date    : 20260414
-- Change  : Release-align the AXI4 wrapper to v26.6.9 so the exported
--           identity defaults match the packaged release metadata used by the
--           shared CSR/meta readback tests.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;

use work.sc_hub_pkg.all;

entity sc_hub_top_axi4 is
    generic(
        BACKPRESSURE               : boolean := true;
        SCHEDULER_USE_PKT_TRANSFER : boolean := true;
        INVERT_RD_SIG              : boolean := true;
        DEBUG                      : natural := 1;
        OOO_ENABLE                 : boolean := true;
        ORD_ENABLE                 : boolean := true;
        ATOMIC_ENABLE              : boolean := true;
        HUB_CAP_ENABLE             : boolean := true;
        OOO_SLOT_COUNT             : positive := 4;
        OUTSTANDING_INT_RESERVED   : positive := 2;
        RD_TIMEOUT_CYCLES          : positive := DEFAULT_RD_TIMEOUT_CONST;
        WR_TIMEOUT_CYCLES          : positive := DEFAULT_WR_TIMEOUT_CONST;
        -- Identity generics (standard CSR header at words 0-1)
        IP_UID                     : natural := 16#53434842#; -- ASCII "SCHB"
        VERSION_MAJOR              : natural := 26;
        VERSION_MINOR              : natural := 6;
        VERSION_PATCH              : natural := 9;
        BUILD                      : natural := 16#0414#;
        VERSION_DATE               : natural := 16#20260414#;
        VERSION_GIT                : natural := 0;
        INSTANCE_ID                : natural := 0
    );
    port(
        i_clk                       : in  std_logic;
        i_rst                       : in  std_logic;
        i_download_data             : in  std_logic_vector(31 downto 0);
        i_download_datak            : in  std_logic_vector(3 downto 0);
        o_download_ready            : out std_logic;
        aso_upload_data             : out std_logic_vector(35 downto 0);
        aso_upload_valid            : out std_logic;
        aso_upload_ready            : in  std_logic;
        aso_upload_startofpacket    : out std_logic;
        aso_upload_endofpacket      : out std_logic;
        m_axi_awid                  : out std_logic_vector(3 downto 0);
        m_axi_awaddr                : out std_logic_vector(17 downto 0);
        m_axi_awlen                 : out std_logic_vector(7 downto 0);
        m_axi_awsize                : out std_logic_vector(2 downto 0);
        m_axi_awburst               : out std_logic_vector(1 downto 0);
        m_axi_awlock                : out std_logic;
        m_axi_awvalid               : out std_logic;
        m_axi_awready               : in  std_logic;
        m_axi_wdata                 : out std_logic_vector(31 downto 0);
        m_axi_wstrb                 : out std_logic_vector(3 downto 0);
        m_axi_wlast                 : out std_logic;
        m_axi_wvalid                : out std_logic;
        m_axi_wready                : in  std_logic;
        m_axi_bid                   : in  std_logic_vector(3 downto 0);
        m_axi_bresp                 : in  std_logic_vector(1 downto 0);
        m_axi_bvalid                : in  std_logic;
        m_axi_bready                : out std_logic;
        m_axi_arid                  : out std_logic_vector(3 downto 0);
        m_axi_araddr                : out std_logic_vector(17 downto 0);
        m_axi_arlen                 : out std_logic_vector(7 downto 0);
        m_axi_arsize                : out std_logic_vector(2 downto 0);
        m_axi_arburst               : out std_logic_vector(1 downto 0);
        m_axi_arlock                : out std_logic;
        m_axi_arvalid               : out std_logic;
        m_axi_arready               : in  std_logic;
        m_axi_rid                   : in  std_logic_vector(3 downto 0);
        m_axi_rdata                 : in  std_logic_vector(31 downto 0);
        m_axi_rresp                 : in  std_logic_vector(1 downto 0);
        m_axi_rlast                 : in  std_logic;
        m_axi_rvalid                : in  std_logic;
        m_axi_rready                : out std_logic
    );
end entity sc_hub_top_axi4;

architecture rtl of sc_hub_top_axi4 is
    signal uplink_ready_int        : std_logic;
    signal download_ready_int      : std_logic;
    signal accept_new_pkt_int      : std_logic;
    signal pkt_in_progress         : std_logic;
    signal pkt_valid               : std_logic := '0';
    signal pkt_info                : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal pkt_rx_valid            : std_logic;
    signal pkt_rx_info             : sc_pkt_info_t;
    signal wr_data_rdreq           : std_logic;
    signal wr_data_q               : std_logic_vector(31 downto 0);
    signal wr_data_empty           : std_logic;
    signal pkt_drop_count          : std_logic_vector(15 downto 0);
    signal pkt_drop_pulse          : std_logic;
    signal dl_fifo_usedw           : std_logic_vector(9 downto 0);
    signal dl_fifo_full            : std_logic;
    signal dl_fifo_overflow        : std_logic;
    signal dl_fifo_overflow_pulse  : std_logic;
    signal bp_usedw                : std_logic_vector(ceil_log2_func(DEFAULT_BP_FIFO_DEPTH_CONST + 1) - 1 downto 0);
    signal bp_full                 : std_logic;
    signal bp_half_full            : std_logic;
    signal bp_overflow             : std_logic;
    signal bp_overflow_pulse       : std_logic;
    signal bp_pkt_count            : std_logic_vector(ceil_log2_func(DEFAULT_BP_FIFO_DEPTH_CONST + 1) - 1 downto 0);
    signal tx_reply_start          : std_logic;
    signal tx_reply_info           : sc_pkt_info_t;
    signal tx_reply_response       : std_logic_vector(1 downto 0);
    signal tx_reply_has_data       : std_logic;
    signal tx_reply_suppress       : std_logic;
    signal tx_reply_ready          : std_logic;
    signal tx_reply_done           : std_logic;
    signal tx_data_valid           : std_logic;
    signal tx_data_word            : std_logic_vector(31 downto 0);
    signal tx_data_ready           : std_logic;
    signal bus_ooo_enable          : std_logic;
    signal bus_rd_cmd_valid        : std_logic;
    signal bus_rd_cmd_address      : std_logic_vector(17 downto 0);
    signal bus_rd_cmd_length       : std_logic_vector(15 downto 0);
    signal bus_rd_cmd_nonincrement : std_logic;
    signal bus_rd_cmd_tag          : std_logic_vector(3 downto 0);
    signal bus_rd_cmd_lock         : std_logic;
    signal bus_rd_cmd_ready        : std_logic;
    signal bus_rd_data_tag         : std_logic_vector(3 downto 0);
    signal bus_rd_done             : std_logic;
    signal bus_rd_done_tag         : std_logic_vector(3 downto 0);
    signal bus_rd_timeout_pulse    : std_logic;
    signal bus_wr_data_valid       : std_logic;
    signal bus_wr_data             : std_logic_vector(31 downto 0);
    signal bus_wr_data_ready       : std_logic;
    signal bus_wr_cmd_valid        : std_logic;
    signal bus_wr_cmd_address      : std_logic_vector(17 downto 0);
    signal bus_wr_cmd_length       : std_logic_vector(15 downto 0);
    signal bus_wr_cmd_nonincrement : std_logic;
    signal bus_wr_cmd_lock         : std_logic;
    signal bus_wr_cmd_ready        : std_logic;
    signal bus_wr_done             : std_logic;
    signal bus_wr_response         : std_logic_vector(1 downto 0);
    signal bus_wr_timeout_pulse    : std_logic;
    signal bus_rd_data_valid       : std_logic;
    signal bus_rd_data             : std_logic_vector(31 downto 0);
    signal bus_rd_response         : std_logic_vector(1 downto 0);
    signal bus_busy                : std_logic;
    signal rx_ready                : std_logic;
    signal core_rx_ready           : std_logic;
    signal core_soft_reset_pulse   : std_logic;
    signal rx_soft_reset_pulse     : std_logic;
    signal soft_reset_pulse        : std_logic;
    signal hub_reset_int           : std_logic;
begin
    gen_invert_ready : if INVERT_RD_SIG generate
        uplink_ready_int <= not aso_upload_ready;
    end generate;

    gen_direct_ready : if not INVERT_RD_SIG generate
        uplink_ready_int <= aso_upload_ready;
    end generate;

    pkt_rx_inst : entity work.sc_hub_pkt_rx
    port map(
        i_clk                 => i_clk,
        i_rst                 => i_rst,
        i_soft_reset          => soft_reset_pulse,
        i_download_data       => i_download_data,
        i_download_datak      => i_download_datak,
        i_accept_new_pkt      => accept_new_pkt_int,
        i_allow_new_pkt       => rx_ready,
        o_download_ready      => download_ready_int,
        o_pkt_in_progress     => pkt_in_progress,
        o_pkt_valid           => pkt_rx_valid,
        o_pkt_info            => pkt_rx_info,
        o_soft_reset_pulse    => rx_soft_reset_pulse,
        i_wr_data_rdreq       => wr_data_rdreq,
        o_wr_data_q           => wr_data_q,
        o_wr_data_empty       => wr_data_empty,
        o_pkt_drop_count      => pkt_drop_count,
        o_pkt_drop_pulse      => pkt_drop_pulse,
        o_fifo_usedw          => dl_fifo_usedw,
        o_fifo_full           => dl_fifo_full,
        o_fifo_overflow       => dl_fifo_overflow,
        o_fifo_overflow_pulse => dl_fifo_overflow_pulse
    );

    rx_ready <= '1' when (pkt_valid = '0') else '0';

    rx_pkt_stage : process(i_clk)
        variable pkt_valid_v : std_logic;
        variable pkt_info_v  : sc_pkt_info_t;
    begin
        if rising_edge(i_clk) then
            if (hub_reset_int = '1') then
                pkt_valid <= '0';
                pkt_info  <= SC_PKT_INFO_RESET_CONST;
            else
                pkt_valid_v := pkt_valid;
                pkt_info_v  := pkt_info;

                if (pkt_rx_valid = '1' and pkt_valid = '0') then
                    pkt_valid_v := '1';
                    pkt_info_v  := pkt_rx_info;
                elsif (pkt_valid = '1' and core_rx_ready = '1') then
                    pkt_valid_v := '0';
                    pkt_info_v  := SC_PKT_INFO_RESET_CONST;
                end if;

                pkt_valid <= pkt_valid_v;
                pkt_info  <= pkt_info_v;
            end if;
        end if;
    end process rx_pkt_stage;

    pkt_tx_inst : entity work.sc_hub_pkt_tx
    port map(
        i_clk                       => i_clk,
        i_rst                       => hub_reset_int,
        i_soft_reset                => soft_reset_pulse,
        i_reply_start               => tx_reply_start,
        i_reply_info                => tx_reply_info,
        i_reply_response            => tx_reply_response,
        i_reply_has_data            => tx_reply_has_data,
        i_reply_suppress            => tx_reply_suppress,
        o_reply_ready               => tx_reply_ready,
        o_reply_done                => tx_reply_done,
        i_data_valid                => tx_data_valid,
        i_data_word                 => tx_data_word,
        o_data_ready                => tx_data_ready,
        aso_upload_data             => aso_upload_data,
        aso_upload_valid            => aso_upload_valid,
        aso_upload_ready            => uplink_ready_int,
        aso_upload_startofpacket    => aso_upload_startofpacket,
        aso_upload_endofpacket      => aso_upload_endofpacket,
        o_bp_usedw                  => bp_usedw,
        o_bp_full                   => bp_full,
        o_bp_half_full              => bp_half_full,
        o_bp_overflow               => bp_overflow,
        o_bp_overflow_pulse         => bp_overflow_pulse,
        o_pkt_count                 => bp_pkt_count
    );

    core_inst : entity work.sc_hub_axi4_core
    generic map(
        DEBUG_G                    => DEBUG,
        OOO_ENABLE_G               => OOO_ENABLE,
        ORD_ENABLE_G               => ORD_ENABLE,
        ATOMIC_ENABLE_G            => ATOMIC_ENABLE,
        HUB_CAP_ENABLE_G           => HUB_CAP_ENABLE,
        OOO_SLOT_COUNT_G           => OOO_SLOT_COUNT,
        OUTSTANDING_INT_RESERVED_G => OUTSTANDING_INT_RESERVED,
        IP_UID_G                   => IP_UID,
        VERSION_MAJOR_G            => VERSION_MAJOR,
        VERSION_MINOR_G            => VERSION_MINOR,
        VERSION_PATCH_G            => VERSION_PATCH,
        BUILD_G                    => BUILD,
        VERSION_DATE_G             => VERSION_DATE,
        VERSION_GIT_G              => VERSION_GIT,
        INSTANCE_ID_G              => INSTANCE_ID
    )
    port map(
        i_clk                    => i_clk,
        i_rst                    => hub_reset_int,
        i_pkt_valid              => pkt_valid,
        i_pkt_info               => pkt_info,
        o_rx_ready               => core_rx_ready,
        o_soft_reset_pulse       => core_soft_reset_pulse,
        o_wr_data_rdreq          => wr_data_rdreq,
        i_wr_data_q              => wr_data_q,
        i_wr_data_empty          => wr_data_empty,
        i_pkt_drop_count         => pkt_drop_count,
        i_pkt_drop_pulse         => pkt_drop_pulse,
        i_dl_fifo_usedw          => dl_fifo_usedw,
        i_dl_fifo_full           => dl_fifo_full,
        i_dl_fifo_overflow       => dl_fifo_overflow,
        i_dl_fifo_overflow_pulse => dl_fifo_overflow_pulse,
        i_bp_usedw               => bp_usedw,
        i_bp_full                => bp_full,
        i_bp_overflow            => bp_overflow,
        i_bp_overflow_pulse      => bp_overflow_pulse,
        i_bp_pkt_count           => bp_pkt_count,
        o_tx_reply_start         => tx_reply_start,
        o_tx_reply_info          => tx_reply_info,
        o_tx_reply_response      => tx_reply_response,
        o_tx_reply_has_data      => tx_reply_has_data,
        o_tx_reply_suppress      => tx_reply_suppress,
        i_tx_reply_ready         => tx_reply_ready,
        i_tx_reply_done          => tx_reply_done,
        o_tx_data_valid          => tx_data_valid,
        o_tx_data_word           => tx_data_word,
        i_tx_data_ready          => tx_data_ready,
        o_bus_ooo_enable         => bus_ooo_enable,
        o_bus_rd_cmd_valid       => bus_rd_cmd_valid,
        o_bus_rd_cmd_address     => bus_rd_cmd_address,
        o_bus_rd_cmd_length      => bus_rd_cmd_length,
        o_bus_rd_cmd_nonincrement => bus_rd_cmd_nonincrement,
        o_bus_rd_cmd_tag         => bus_rd_cmd_tag,
        o_bus_rd_cmd_lock        => bus_rd_cmd_lock,
        i_bus_rd_cmd_ready       => bus_rd_cmd_ready,
        i_bus_rd_data_valid      => bus_rd_data_valid,
        i_bus_rd_data            => bus_rd_data,
        i_bus_rd_data_tag        => bus_rd_data_tag,
        i_bus_rd_done            => bus_rd_done,
        i_bus_rd_done_tag        => bus_rd_done_tag,
        i_bus_rd_response        => bus_rd_response,
        i_bus_rd_timeout_pulse   => bus_rd_timeout_pulse,
        o_bus_wr_cmd_valid       => bus_wr_cmd_valid,
        o_bus_wr_cmd_address     => bus_wr_cmd_address,
        o_bus_wr_cmd_length      => bus_wr_cmd_length,
        o_bus_wr_cmd_nonincrement => bus_wr_cmd_nonincrement,
        o_bus_wr_cmd_lock        => bus_wr_cmd_lock,
        i_bus_wr_cmd_ready       => bus_wr_cmd_ready,
        o_bus_wr_data_valid      => bus_wr_data_valid,
        o_bus_wr_data            => bus_wr_data,
        i_bus_wr_data_ready      => bus_wr_data_ready,
        i_bus_wr_done            => bus_wr_done,
        i_bus_wr_response        => bus_wr_response,
        i_bus_wr_timeout_pulse   => bus_wr_timeout_pulse,
        i_bus_busy               => bus_busy
    );

    axi4_handler_inst : entity work.sc_hub_axi4_ooo_handler
    generic map(
        OOO_CFG_ENABLE_G    => OOO_ENABLE,
        RD_TIMEOUT_CYCLES_G    => RD_TIMEOUT_CYCLES,
        WR_TIMEOUT_CYCLES_G    => WR_TIMEOUT_CYCLES,
        MAX_READ_OUTSTANDING_G => OOO_SLOT_COUNT
    )
    port map(
        i_clk           => i_clk,
        i_rst           => hub_reset_int,
        i_ooo_enable       => bus_ooo_enable,
        i_rd_cmd_valid     => bus_rd_cmd_valid,
        o_rd_cmd_ready     => bus_rd_cmd_ready,
        i_rd_cmd_address   => bus_rd_cmd_address,
        i_rd_cmd_length    => bus_rd_cmd_length,
        i_rd_cmd_nonincrement => bus_rd_cmd_nonincrement,
        i_rd_cmd_tag       => bus_rd_cmd_tag,
        i_rd_cmd_lock      => bus_rd_cmd_lock,
        o_rd_data_valid    => bus_rd_data_valid,
        o_rd_data          => bus_rd_data,
        o_rd_data_tag      => bus_rd_data_tag,
        o_rd_done          => bus_rd_done,
        o_rd_done_tag      => bus_rd_done_tag,
        o_rd_response      => bus_rd_response,
        o_rd_timeout_pulse => bus_rd_timeout_pulse,
        i_wr_cmd_valid     => bus_wr_cmd_valid,
        o_wr_cmd_ready     => bus_wr_cmd_ready,
        i_wr_cmd_address   => bus_wr_cmd_address,
        i_wr_cmd_length    => bus_wr_cmd_length,
        i_wr_cmd_nonincrement => bus_wr_cmd_nonincrement,
        i_wr_cmd_lock      => bus_wr_cmd_lock,
        i_wr_data_valid    => bus_wr_data_valid,
        i_wr_data          => bus_wr_data,
        o_wr_data_ready    => bus_wr_data_ready,
        o_wr_done          => bus_wr_done,
        o_wr_response      => bus_wr_response,
        o_wr_timeout_pulse => bus_wr_timeout_pulse,
        o_busy             => bus_busy,
        m_axi_awid         => m_axi_awid,
        m_axi_awaddr       => m_axi_awaddr,
        m_axi_awlen        => m_axi_awlen,
        m_axi_awsize       => m_axi_awsize,
        m_axi_awburst      => m_axi_awburst,
        m_axi_awlock       => m_axi_awlock,
        m_axi_awvalid      => m_axi_awvalid,
        m_axi_awready      => m_axi_awready,
        m_axi_wdata        => m_axi_wdata,
        m_axi_wstrb        => m_axi_wstrb,
        m_axi_wlast        => m_axi_wlast,
        m_axi_wvalid       => m_axi_wvalid,
        m_axi_wready       => m_axi_wready,
        m_axi_bid          => m_axi_bid,
        m_axi_bresp        => m_axi_bresp,
        m_axi_bvalid       => m_axi_bvalid,
        m_axi_bready       => m_axi_bready,
        m_axi_arid         => m_axi_arid,
        m_axi_araddr       => m_axi_araddr,
        m_axi_arlen        => m_axi_arlen,
        m_axi_arsize       => m_axi_arsize,
        m_axi_arburst      => m_axi_arburst,
        m_axi_arlock       => m_axi_arlock,
        m_axi_arvalid      => m_axi_arvalid,
        m_axi_arready      => m_axi_arready,
        m_axi_rid          => m_axi_rid,
        m_axi_rdata        => m_axi_rdata,
        m_axi_rresp        => m_axi_rresp,
        m_axi_rlast        => m_axi_rlast,
        m_axi_rvalid       => m_axi_rvalid,
        m_axi_rready       => m_axi_rready
    );

    soft_reset_pulse <= core_soft_reset_pulse or rx_soft_reset_pulse;
    hub_reset_int    <= i_rst or soft_reset_pulse;

    accept_new_pkt_int <= '1'
        when ((not BACKPRESSURE) or bp_half_full = '0')
        else '0';

    o_download_ready <= download_ready_int
        when ((not BACKPRESSURE) or bp_half_full = '0' or pkt_in_progress = '1')
        else '0';
end architecture rtl;
