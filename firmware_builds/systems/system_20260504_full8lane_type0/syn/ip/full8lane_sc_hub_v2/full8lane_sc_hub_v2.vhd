library ieee;
use ieee.std_logic_1164.all;

use work.sc_hub_pkg.all;

entity full8lane_sc_hub_v2 is
    generic(
        BACKPRESSURE               : natural := 1;
        SCHEDULER_USE_PKT_TRANSFER : natural := 1;
        INVERT_RD_SIG              : natural := 1;
        DEBUG                      : natural := 1;
        OOO_ENABLE                 : natural := 0;
        ORD_ENABLE                 : natural := 1;
        ATOMIC_ENABLE              : natural := 1;
        HUB_CAP_ENABLE             : natural := 1;
        EXT_PLD_DEPTH              : positive := DEFAULT_DL_FIFO_DEPTH_CONST;
        PKT_QUEUE_DEPTH            : positive := 16;
        BP_FIFO_DEPTH              : positive := DEFAULT_BP_FIFO_DEPTH_CONST;
        RD_TIMEOUT_CYCLES          : positive := DEFAULT_RD_TIMEOUT_CONST;
        WR_TIMEOUT_CYCLES          : positive := DEFAULT_WR_TIMEOUT_CONST;
        OUTSTANDING_LIMIT          : positive := 8;
        OUTSTANDING_INT_RESERVED   : natural := 2;
        IP_UID                     : natural := 16#53434842#;
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
end entity full8lane_sc_hub_v2;

architecture rtl of full8lane_sc_hub_v2 is
begin
    u_core : entity work.sc_hub_top
    generic map(
        BACKPRESSURE               => BACKPRESSURE /= 0,
        SCHEDULER_USE_PKT_TRANSFER => SCHEDULER_USE_PKT_TRANSFER /= 0,
        INVERT_RD_SIG              => INVERT_RD_SIG /= 0,
        DEBUG                      => DEBUG,
        OOO_ENABLE                 => OOO_ENABLE /= 0,
        ORD_ENABLE                 => ORD_ENABLE /= 0,
        ATOMIC_ENABLE              => ATOMIC_ENABLE /= 0,
        HUB_CAP_ENABLE             => HUB_CAP_ENABLE /= 0,
        EXT_PLD_DEPTH              => EXT_PLD_DEPTH,
        PKT_QUEUE_DEPTH            => PKT_QUEUE_DEPTH,
        BP_FIFO_DEPTH              => BP_FIFO_DEPTH,
        RD_TIMEOUT_CYCLES          => RD_TIMEOUT_CYCLES,
        WR_TIMEOUT_CYCLES          => WR_TIMEOUT_CYCLES,
        OUTSTANDING_LIMIT          => OUTSTANDING_LIMIT,
        OUTSTANDING_INT_RESERVED   => OUTSTANDING_INT_RESERVED,
        IP_UID                     => IP_UID,
        VERSION_MAJOR              => VERSION_MAJOR,
        VERSION_MINOR              => VERSION_MINOR,
        VERSION_PATCH              => VERSION_PATCH,
        BUILD                      => BUILD,
        VERSION_DATE               => VERSION_DATE,
        VERSION_GIT                => VERSION_GIT,
        INSTANCE_ID                => INSTANCE_ID
    )
    port map(
        i_clk                      => i_clk,
        i_rst                      => i_rst,
        i_download_data            => i_download_data,
        i_download_datak           => i_download_datak,
        o_download_ready           => o_download_ready,
        aso_upload_data            => aso_upload_data,
        aso_upload_valid           => aso_upload_valid,
        aso_upload_ready           => aso_upload_ready,
        aso_upload_startofpacket   => aso_upload_startofpacket,
        aso_upload_endofpacket     => aso_upload_endofpacket,
        avm_hub_address            => avm_hub_address,
        avm_hub_read               => avm_hub_read,
        avm_hub_readdata           => avm_hub_readdata,
        avm_hub_writeresponsevalid => avm_hub_writeresponsevalid,
        avm_hub_response           => avm_hub_response,
        avm_hub_write              => avm_hub_write,
        avm_hub_writedata          => avm_hub_writedata,
        avm_hub_waitrequest        => avm_hub_waitrequest,
        avm_hub_readdatavalid      => avm_hub_readdatavalid,
        avm_hub_burstcount         => avm_hub_burstcount,
        avs_csr_address            => avs_csr_address,
        avs_csr_read               => avs_csr_read,
        avs_csr_write              => avs_csr_write,
        avs_csr_writedata          => avs_csr_writedata,
        avs_csr_readdata           => avs_csr_readdata,
        avs_csr_readdatavalid      => avs_csr_readdatavalid,
        avs_csr_waitrequest        => avs_csr_waitrequest,
        avs_csr_burstcount         => avs_csr_burstcount
    );
end architecture rtl;
