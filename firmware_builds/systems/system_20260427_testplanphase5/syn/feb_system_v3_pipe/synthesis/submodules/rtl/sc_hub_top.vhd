-- File name: sc_hub_top.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.6.9
-- Date    : 20260414
-- Change  : Package the AVMM top as v26.6.9 after the write-accept staging
--           and follow-up core/pkt_rx reply-path borrow fixes. Keep the
--           exported identity generics aligned with the packaged 26.6.9.0414
--           release so internal CSR/meta readback matches the documented
--           version.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;

use work.sc_hub_pkg.all;

entity sc_hub_top is
    generic(
        BACKPRESSURE               : boolean := true;
        SCHEDULER_USE_PKT_TRANSFER : boolean := true;
        INVERT_RD_SIG              : boolean := true;
        DEBUG                      : natural := 1;
        OOO_ENABLE                 : boolean := false;
        ORD_ENABLE                 : boolean := true;
        ATOMIC_ENABLE              : boolean := true;
        HUB_CAP_ENABLE             : boolean := true;
        EXT_PLD_DEPTH              : positive := DEFAULT_DL_FIFO_DEPTH_CONST;
        PKT_QUEUE_DEPTH            : positive := 16;
        BP_FIFO_DEPTH              : positive := DEFAULT_BP_FIFO_DEPTH_CONST;
        RD_TIMEOUT_CYCLES          : positive := DEFAULT_RD_TIMEOUT_CONST;
        WR_TIMEOUT_CYCLES          : positive := DEFAULT_WR_TIMEOUT_CONST;
        OUTSTANDING_LIMIT          : positive := 8;
        OUTSTANDING_INT_RESERVED   : natural := 2;
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
        avm_hub_address             : out std_logic_vector(17 downto 0);
        avm_hub_read                : out std_logic;
        avm_hub_readdata            : in  std_logic_vector(31 downto 0);
        avm_hub_writeresponsevalid  : in  std_logic;
        avm_hub_response            : in  std_logic_vector(1 downto 0);
        avm_hub_write               : out std_logic;
        avm_hub_writedata           : out std_logic_vector(31 downto 0);
        avm_hub_waitrequest         : in  std_logic;
        avm_hub_readdatavalid       : in  std_logic;
        avm_hub_burstcount          : out std_logic_vector(8 downto 0);
        avs_csr_address             : in  std_logic_vector(ceil_log2_func(HUB_CSR_WINDOW_WORDS_CONST) - 1 downto 0);
        avs_csr_read                : in  std_logic;
        avs_csr_write               : in  std_logic;
        avs_csr_writedata           : in  std_logic_vector(31 downto 0);
        avs_csr_readdata            : out std_logic_vector(31 downto 0);
        avs_csr_readdatavalid       : out std_logic;
        avs_csr_waitrequest         : out std_logic;
        avs_csr_burstcount          : in  std_logic
    );
end entity sc_hub_top;

architecture rtl of sc_hub_top is
    signal uplink_ready_int        : std_logic;
    signal download_ready_int      : std_logic;
    signal accept_new_pkt_int      : std_logic;
    signal pkt_in_progress         : std_logic;
    signal pkt_valid               : std_logic := '0';
    signal pkt_info                : sc_pkt_info_t := SC_PKT_INFO_RESET_CONST;
    signal pkt_is_internal         : std_logic := '0';
    signal pkt_rx_valid            : std_logic;
    signal pkt_rx_info             : sc_pkt_info_t;
    signal pkt_rx_is_internal      : std_logic;
    signal wr_data_rdreq           : std_logic;
    signal wr_data_q               : std_logic_vector(31 downto 0);
    signal wr_data_empty           : std_logic;
    signal pkt_drop_count          : std_logic_vector(15 downto 0);
    signal pkt_drop_pulse          : std_logic;
    signal debug_drop_detail       : std_logic_vector(31 downto 0);
    signal dl_fifo_usedw           : std_logic_vector(9 downto 0);
    signal dl_fifo_full            : std_logic;
    signal dl_fifo_overflow        : std_logic;
    signal dl_fifo_overflow_pulse  : std_logic;
    signal bp_usedw                : std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH + 1) - 1 downto 0);
    signal bp_full                 : std_logic;
    signal bp_half_full            : std_logic;
    signal bp_overflow             : std_logic;
    signal bp_overflow_pulse       : std_logic;
    signal bp_pkt_count            : std_logic_vector(ceil_log2_func(BP_FIFO_DEPTH + 1) - 1 downto 0);
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
    signal bus_cmd_valid           : std_logic;
    signal bus_cmd_is_read         : std_logic;
    signal bus_cmd_nonincrement    : std_logic;
    signal bus_cmd_address         : std_logic_vector(17 downto 0);
    signal bus_cmd_length          : std_logic_vector(15 downto 0);
    signal bus_cmd_ready           : std_logic;
    signal bus_wr_data_valid       : std_logic;
    signal bus_wr_data             : std_logic_vector(31 downto 0);
    signal bus_wr_data_ready       : std_logic;
    signal bus_wr_accept_pulse     : std_logic;
    signal bus_wr_accept_address   : std_logic_vector(17 downto 0);
    signal bus_wr_accept_data      : std_logic_vector(31 downto 0);
    signal bus_rd_data_valid       : std_logic;
    signal bus_rd_data             : std_logic_vector(31 downto 0);
    signal bus_done                : std_logic;
    signal bus_response            : std_logic_vector(1 downto 0);
    signal bus_busy                : std_logic;
    signal bus_timeout_pulse       : std_logic;
    signal rx_ready                : std_logic;
    signal core_rx_ready           : std_logic;
    signal core_soft_reset_pulse   : std_logic;
    signal rx_soft_reset_pulse     : std_logic;
    signal soft_reset_comb         : std_logic;
    signal soft_reset_pulse        : std_logic := '0';
    signal hub_reset_int           : std_logic;
begin
    gen_invert_ready : if INVERT_RD_SIG generate
        uplink_ready_int <= not aso_upload_ready;
    end generate;

    gen_direct_ready : if not INVERT_RD_SIG generate
        uplink_ready_int <= aso_upload_ready;
    end generate;

    pkt_rx_inst : entity work.sc_hub_pkt_rx
    generic map(
        EXT_PLD_DEPTH_G   => EXT_PLD_DEPTH,
        PKT_QUEUE_DEPTH_G => PKT_QUEUE_DEPTH
    )
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
        o_pkt_is_internal     => pkt_rx_is_internal,
        o_soft_reset_pulse    => rx_soft_reset_pulse,
        i_wr_data_rdreq       => wr_data_rdreq,
        o_wr_data_q           => wr_data_q,
        o_wr_data_empty       => wr_data_empty,
        o_pkt_drop_count      => pkt_drop_count,
        o_pkt_drop_pulse      => pkt_drop_pulse,
        o_debug_drop_detail   => debug_drop_detail,
        o_fifo_usedw          => dl_fifo_usedw,
        o_fifo_full           => dl_fifo_full,
        o_fifo_overflow       => dl_fifo_overflow,
        o_fifo_overflow_pulse => dl_fifo_overflow_pulse
    );

    rx_ready <= '1' when (pkt_valid = '0' or core_rx_ready = '1') else '0';

    rx_pkt_stage : process(i_clk)
        variable pkt_valid_v       : std_logic;
        variable pkt_info_v        : sc_pkt_info_t;
        variable pkt_is_internal_v : std_logic;
    begin
        if rising_edge(i_clk) then
            if (hub_reset_int = '1') then
                pkt_valid       <= '0';
                pkt_info        <= SC_PKT_INFO_RESET_CONST;
                pkt_is_internal <= '0';
            else
                pkt_valid_v       := pkt_valid;
                pkt_info_v        := pkt_info;
                pkt_is_internal_v := pkt_is_internal;

                if (pkt_rx_valid = '1' and (pkt_valid = '0' or core_rx_ready = '1')) then
                    pkt_valid_v       := '1';
                    pkt_info_v        := pkt_rx_info;
                    pkt_is_internal_v := pkt_rx_is_internal;
                elsif (pkt_valid = '1' and core_rx_ready = '1') then
                    pkt_valid_v       := '0';
                    pkt_info_v        := SC_PKT_INFO_RESET_CONST;
                    pkt_is_internal_v := '0';
                end if;

                pkt_valid       <= pkt_valid_v;
                pkt_info        <= pkt_info_v;
                pkt_is_internal <= pkt_is_internal_v;
            end if;
        end if;
    end process rx_pkt_stage;

    pkt_tx_inst : entity work.sc_hub_pkt_tx
    generic map(
        BP_FIFO_DEPTH_G => BP_FIFO_DEPTH
    )
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

    core_inst : entity work.sc_hub_core
    generic map(
        DEBUG_G                    => DEBUG,
        OOO_ENABLE_G               => OOO_ENABLE,
        ORD_ENABLE_G               => ORD_ENABLE,
        ATOMIC_ENABLE_G            => ATOMIC_ENABLE,
        HUB_CAP_ENABLE_G           => HUB_CAP_ENABLE,
        BP_FIFO_DEPTH_G            => BP_FIFO_DEPTH,
        OUTSTANDING_LIMIT_G        => OUTSTANDING_LIMIT,
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
        i_pkt_is_internal        => pkt_is_internal,
        o_rx_ready               => core_rx_ready,
        o_soft_reset_pulse       => core_soft_reset_pulse,
        o_wr_data_rdreq          => wr_data_rdreq,
        i_wr_data_q              => wr_data_q,
        i_wr_data_empty          => wr_data_empty,
        i_pkt_drop_count         => pkt_drop_count,
        i_pkt_drop_pulse         => pkt_drop_pulse,
        i_debug_drop_detail      => debug_drop_detail,
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
        o_bus_cmd_valid          => bus_cmd_valid,
        o_bus_cmd_is_read        => bus_cmd_is_read,
        o_bus_cmd_nonincrement   => bus_cmd_nonincrement,
        o_bus_cmd_address        => bus_cmd_address,
        o_bus_cmd_length         => bus_cmd_length,
        i_bus_cmd_ready          => bus_cmd_ready,
        o_bus_wr_data_valid      => bus_wr_data_valid,
        o_bus_wr_data            => bus_wr_data,
        i_bus_wr_data_ready      => bus_wr_data_ready,
        i_bus_wr_accept_pulse    => bus_wr_accept_pulse,
        i_bus_wr_accept_address  => bus_wr_accept_address,
        i_bus_wr_accept_data     => bus_wr_accept_data,
        i_bus_rd_data_valid      => bus_rd_data_valid,
        i_bus_rd_data            => bus_rd_data,
        i_bus_done               => bus_done,
        i_bus_response           => bus_response,
        i_bus_busy               => bus_busy,
        i_bus_timeout_pulse      => bus_timeout_pulse,
        avs_csr_address          => avs_csr_address,
        avs_csr_read             => avs_csr_read,
        avs_csr_write            => avs_csr_write,
        avs_csr_writedata        => avs_csr_writedata,
        avs_csr_readdata         => avs_csr_readdata,
        avs_csr_readdatavalid    => avs_csr_readdatavalid,
        avs_csr_waitrequest      => avs_csr_waitrequest
    );

    avmm_handler_inst : entity work.sc_hub_avmm_handler
    generic map(
        RD_TIMEOUT_CYCLES_G => RD_TIMEOUT_CYCLES,
        WR_TIMEOUT_CYCLES_G => WR_TIMEOUT_CYCLES
    )
    port map(
        i_clk                   => i_clk,
        i_rst                   => hub_reset_int,
        i_cmd_valid             => bus_cmd_valid,
        o_cmd_ready             => bus_cmd_ready,
        i_cmd_is_read           => bus_cmd_is_read,
        i_cmd_nonincrement      => bus_cmd_nonincrement,
        i_cmd_address           => bus_cmd_address,
        i_cmd_length            => bus_cmd_length,
        i_wr_data_valid         => bus_wr_data_valid,
        i_wr_data               => bus_wr_data,
        o_wr_data_ready         => bus_wr_data_ready,
        o_wr_accept_pulse       => bus_wr_accept_pulse,
        o_wr_accept_address     => bus_wr_accept_address,
        o_wr_accept_data        => bus_wr_accept_data,
        o_rd_data_valid         => bus_rd_data_valid,
        o_rd_data               => bus_rd_data,
        o_rd_data_last          => open,
        o_done                  => bus_done,
        o_response              => bus_response,
        o_busy                  => bus_busy,
        o_timeout_pulse         => bus_timeout_pulse,
        avm_hub_address         => avm_hub_address,
        avm_hub_read            => avm_hub_read,
        avm_hub_readdata        => avm_hub_readdata,
        avm_hub_writeresponsevalid => avm_hub_writeresponsevalid,
        avm_hub_response        => avm_hub_response,
        avm_hub_write           => avm_hub_write,
        avm_hub_writedata       => avm_hub_writedata,
        avm_hub_waitrequest     => avm_hub_waitrequest,
        avm_hub_readdatavalid   => avm_hub_readdatavalid,
        avm_hub_burstcount      => avm_hub_burstcount
    );

    -- Rev 26.3.2: Register the soft-reset OR to break the combinational path
    -- from pkt_rx_inst|soft_reset_pulse through hub_reset_int into core_inst.
    -- One cycle of latency on the soft-reset path is acceptable (rare event).
    soft_reset_comb <= core_soft_reset_pulse or rx_soft_reset_pulse;

    soft_reset_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') then
                soft_reset_pulse <= '0';
            else
                soft_reset_pulse <= soft_reset_comb;
            end if;
        end if;
    end process soft_reset_reg;

    hub_reset_int <= i_rst or soft_reset_pulse;

    accept_new_pkt_int <= '1'
        when ((not BACKPRESSURE) or bp_half_full = '0')
        else '0';

    o_download_ready <= '0'
        when (download_ready_int = '0')
        else download_ready_int
            when ((not BACKPRESSURE) or bp_half_full = '0' or pkt_in_progress = '1')
            else '0';
end architecture rtl;
