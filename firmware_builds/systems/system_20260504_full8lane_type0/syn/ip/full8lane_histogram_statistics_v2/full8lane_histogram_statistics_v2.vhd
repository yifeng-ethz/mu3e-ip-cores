library ieee;
use ieee.std_logic_1164.all;

entity full8lane_histogram_statistics_v2 is
    generic (
        UPDATE_KEY_BIT_HI         : natural := 29;
        UPDATE_KEY_BIT_LO         : natural := 17;
        UPDATE_KEY_REPRESENTATION : string  := "UNSIGNED";
        FILTER_KEY_BIT_HI         : natural := 38;
        FILTER_KEY_BIT_LO         : natural := 35;
        SAR_TICK_WIDTH            : natural := 32;
        SAR_KEY_WIDTH             : natural := 16;
        N_BINS                    : natural := 256;
        MAX_COUNT_BITS            : natural := 32;
        DEF_LEFT_BOUND            : integer := -1000;
        DEF_BIN_WIDTH             : natural := 16;
        AVS_ADDR_WIDTH            : natural := 8;
        N_PORTS                   : natural := 8;
        FIFO_ADDR_WIDTH           : natural := 8;
        CHANNELS_PER_PORT         : natural := 32;
        COAL_QUEUE_DEPTH          : natural := 256;
        ENABLE_PINGPONG           : natural := 1;
        DEF_INTERVAL_CLOCKS       : natural := 125000000;
        AVST_DATA_WIDTH           : natural := 39;
        AVST_CHANNEL_WIDTH        : natural := 4;
        N_DEBUG_INTERFACE         : natural := 6;
        VERSION_MAJOR             : natural := 26;
        VERSION_MINOR             : natural := 1;
        VERSION_PATCH             : natural := 8;
        BUILD                     : natural := 502;
        IP_UID                    : natural := 1212765012;
        VERSION_DATE              : natural := 20260502;
        VERSION_GIT               : natural := 72231161;
        INSTANCE_ID               : natural := 0;
        SNOOP_EN                  : natural := 1;
        ENABLE_PACKET             : natural := 1;
        DEBUG                     : natural := 0
    );
    port (
        avs_hist_bin_readdata           : out std_logic_vector(31 downto 0);
        avs_hist_bin_read               : in  std_logic;
        avs_hist_bin_address            : in  std_logic_vector(AVS_ADDR_WIDTH - 1 downto 0);
        avs_hist_bin_waitrequest        : out std_logic;
        avs_hist_bin_write              : in  std_logic;
        avs_hist_bin_writedata          : in  std_logic_vector(31 downto 0);
        avs_hist_bin_burstcount         : in  std_logic_vector(AVS_ADDR_WIDTH downto 0);
        avs_hist_bin_readdatavalid      : out std_logic;
        avs_hist_bin_writeresponsevalid : out std_logic;
        avs_hist_bin_response           : out std_logic_vector(1 downto 0);

        avs_csr_readdata                : out std_logic_vector(31 downto 0);
        avs_csr_read                    : in  std_logic;
        avs_csr_address                 : in  std_logic_vector(4 downto 0);
        avs_csr_waitrequest             : out std_logic;
        avs_csr_write                   : in  std_logic;
        avs_csr_writedata               : in  std_logic_vector(31 downto 0);

        asi_hist_fill_in_ready          : out std_logic;
        asi_hist_fill_in_valid          : in  std_logic;
        asi_hist_fill_in_data           : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_hist_fill_in_startofpacket  : in  std_logic;
        asi_hist_fill_in_endofpacket    : in  std_logic;
        asi_hist_fill_in_channel        : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_1_ready             : out std_logic;
        asi_fill_in_1_valid             : in  std_logic;
        asi_fill_in_1_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_1_startofpacket     : in  std_logic;
        asi_fill_in_1_endofpacket       : in  std_logic;
        asi_fill_in_1_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_2_ready             : out std_logic;
        asi_fill_in_2_valid             : in  std_logic;
        asi_fill_in_2_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_2_startofpacket     : in  std_logic;
        asi_fill_in_2_endofpacket       : in  std_logic;
        asi_fill_in_2_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_3_ready             : out std_logic;
        asi_fill_in_3_valid             : in  std_logic;
        asi_fill_in_3_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_3_startofpacket     : in  std_logic;
        asi_fill_in_3_endofpacket       : in  std_logic;
        asi_fill_in_3_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_4_ready             : out std_logic;
        asi_fill_in_4_valid             : in  std_logic;
        asi_fill_in_4_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_4_startofpacket     : in  std_logic;
        asi_fill_in_4_endofpacket       : in  std_logic;
        asi_fill_in_4_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_5_ready             : out std_logic;
        asi_fill_in_5_valid             : in  std_logic;
        asi_fill_in_5_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_5_startofpacket     : in  std_logic;
        asi_fill_in_5_endofpacket       : in  std_logic;
        asi_fill_in_5_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_6_ready             : out std_logic;
        asi_fill_in_6_valid             : in  std_logic;
        asi_fill_in_6_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_6_startofpacket     : in  std_logic;
        asi_fill_in_6_endofpacket       : in  std_logic;
        asi_fill_in_6_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_7_ready             : out std_logic;
        asi_fill_in_7_valid             : in  std_logic;
        asi_fill_in_7_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_7_startofpacket     : in  std_logic;
        asi_fill_in_7_endofpacket       : in  std_logic;
        asi_fill_in_7_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        aso_hist_fill_out_ready         : in  std_logic := '1';
        aso_hist_fill_out_valid         : out std_logic;
        aso_hist_fill_out_data          : out std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        aso_hist_fill_out_startofpacket : out std_logic;
        aso_hist_fill_out_endofpacket   : out std_logic;
        aso_hist_fill_out_channel       : out std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_ctrl_data                   : in  std_logic_vector(8 downto 0);
        asi_ctrl_valid                  : in  std_logic;
        asi_ctrl_ready                  : out std_logic;

        asi_debug_1_valid               : in  std_logic;
        asi_debug_1_data                : in  std_logic_vector(15 downto 0);
        asi_debug_2_valid               : in  std_logic;
        asi_debug_2_data                : in  std_logic_vector(15 downto 0);
        asi_debug_3_valid               : in  std_logic;
        asi_debug_3_data                : in  std_logic_vector(15 downto 0);
        asi_debug_4_valid               : in  std_logic;
        asi_debug_4_data                : in  std_logic_vector(15 downto 0);
        asi_debug_5_valid               : in  std_logic;
        asi_debug_5_data                : in  std_logic_vector(15 downto 0);
        asi_debug_6_valid               : in  std_logic;
        asi_debug_6_data                : in  std_logic_vector(15 downto 0);

        i_interval_reset                : in  std_logic := '0';
        i_rst                           : in  std_logic;
        i_clk                           : in  std_logic
    );
end entity full8lane_histogram_statistics_v2;

architecture rtl of full8lane_histogram_statistics_v2 is
begin
    u_core : entity work.histogram_statistics_v2
        generic map (
            UPDATE_KEY_BIT_HI         => UPDATE_KEY_BIT_HI,
            UPDATE_KEY_BIT_LO         => UPDATE_KEY_BIT_LO,
            UPDATE_KEY_REPRESENTATION => UPDATE_KEY_REPRESENTATION,
            FILTER_KEY_BIT_HI         => FILTER_KEY_BIT_HI,
            FILTER_KEY_BIT_LO         => FILTER_KEY_BIT_LO,
            SAR_TICK_WIDTH            => SAR_TICK_WIDTH,
            SAR_KEY_WIDTH             => SAR_KEY_WIDTH,
            N_BINS                    => N_BINS,
            MAX_COUNT_BITS            => MAX_COUNT_BITS,
            DEF_LEFT_BOUND            => DEF_LEFT_BOUND,
            DEF_BIN_WIDTH             => DEF_BIN_WIDTH,
            AVS_ADDR_WIDTH            => AVS_ADDR_WIDTH,
            N_PORTS                   => N_PORTS,
            FIFO_ADDR_WIDTH           => FIFO_ADDR_WIDTH,
            CHANNELS_PER_PORT         => CHANNELS_PER_PORT,
            COAL_QUEUE_DEPTH          => COAL_QUEUE_DEPTH,
            ENABLE_PINGPONG           => ENABLE_PINGPONG /= 0,
            DEF_INTERVAL_CLOCKS       => DEF_INTERVAL_CLOCKS,
            AVST_DATA_WIDTH           => AVST_DATA_WIDTH,
            AVST_CHANNEL_WIDTH        => AVST_CHANNEL_WIDTH,
            N_DEBUG_INTERFACE         => N_DEBUG_INTERFACE,
            VERSION_MAJOR             => VERSION_MAJOR,
            VERSION_MINOR             => VERSION_MINOR,
            VERSION_PATCH             => VERSION_PATCH,
            BUILD                     => BUILD,
            IP_UID                    => IP_UID,
            VERSION_DATE              => VERSION_DATE,
            VERSION_GIT               => VERSION_GIT,
            INSTANCE_ID               => INSTANCE_ID,
            SNOOP_EN                  => SNOOP_EN /= 0,
            ENABLE_PACKET             => ENABLE_PACKET /= 0,
            DEBUG                     => DEBUG
        )
        port map (
            avs_hist_bin_readdata           => avs_hist_bin_readdata,
            avs_hist_bin_read               => avs_hist_bin_read,
            avs_hist_bin_address            => avs_hist_bin_address,
            avs_hist_bin_waitrequest        => avs_hist_bin_waitrequest,
            avs_hist_bin_write              => avs_hist_bin_write,
            avs_hist_bin_writedata          => avs_hist_bin_writedata,
            avs_hist_bin_burstcount         => avs_hist_bin_burstcount,
            avs_hist_bin_readdatavalid      => avs_hist_bin_readdatavalid,
            avs_hist_bin_writeresponsevalid => avs_hist_bin_writeresponsevalid,
            avs_hist_bin_response           => avs_hist_bin_response,
            avs_csr_readdata                => avs_csr_readdata,
            avs_csr_read                    => avs_csr_read,
            avs_csr_address                 => avs_csr_address,
            avs_csr_waitrequest             => avs_csr_waitrequest,
            avs_csr_write                   => avs_csr_write,
            avs_csr_writedata               => avs_csr_writedata,
            asi_hist_fill_in_ready          => asi_hist_fill_in_ready,
            asi_hist_fill_in_valid          => asi_hist_fill_in_valid,
            asi_hist_fill_in_data           => asi_hist_fill_in_data,
            asi_hist_fill_in_startofpacket  => asi_hist_fill_in_startofpacket,
            asi_hist_fill_in_endofpacket    => asi_hist_fill_in_endofpacket,
            asi_hist_fill_in_channel        => asi_hist_fill_in_channel,
            asi_fill_in_1_ready             => asi_fill_in_1_ready,
            asi_fill_in_1_valid             => asi_fill_in_1_valid,
            asi_fill_in_1_data              => asi_fill_in_1_data,
            asi_fill_in_1_startofpacket     => asi_fill_in_1_startofpacket,
            asi_fill_in_1_endofpacket       => asi_fill_in_1_endofpacket,
            asi_fill_in_1_channel           => asi_fill_in_1_channel,
            asi_fill_in_2_ready             => asi_fill_in_2_ready,
            asi_fill_in_2_valid             => asi_fill_in_2_valid,
            asi_fill_in_2_data              => asi_fill_in_2_data,
            asi_fill_in_2_startofpacket     => asi_fill_in_2_startofpacket,
            asi_fill_in_2_endofpacket       => asi_fill_in_2_endofpacket,
            asi_fill_in_2_channel           => asi_fill_in_2_channel,
            asi_fill_in_3_ready             => asi_fill_in_3_ready,
            asi_fill_in_3_valid             => asi_fill_in_3_valid,
            asi_fill_in_3_data              => asi_fill_in_3_data,
            asi_fill_in_3_startofpacket     => asi_fill_in_3_startofpacket,
            asi_fill_in_3_endofpacket       => asi_fill_in_3_endofpacket,
            asi_fill_in_3_channel           => asi_fill_in_3_channel,
            asi_fill_in_4_ready             => asi_fill_in_4_ready,
            asi_fill_in_4_valid             => asi_fill_in_4_valid,
            asi_fill_in_4_data              => asi_fill_in_4_data,
            asi_fill_in_4_startofpacket     => asi_fill_in_4_startofpacket,
            asi_fill_in_4_endofpacket       => asi_fill_in_4_endofpacket,
            asi_fill_in_4_channel           => asi_fill_in_4_channel,
            asi_fill_in_5_ready             => asi_fill_in_5_ready,
            asi_fill_in_5_valid             => asi_fill_in_5_valid,
            asi_fill_in_5_data              => asi_fill_in_5_data,
            asi_fill_in_5_startofpacket     => asi_fill_in_5_startofpacket,
            asi_fill_in_5_endofpacket       => asi_fill_in_5_endofpacket,
            asi_fill_in_5_channel           => asi_fill_in_5_channel,
            asi_fill_in_6_ready             => asi_fill_in_6_ready,
            asi_fill_in_6_valid             => asi_fill_in_6_valid,
            asi_fill_in_6_data              => asi_fill_in_6_data,
            asi_fill_in_6_startofpacket     => asi_fill_in_6_startofpacket,
            asi_fill_in_6_endofpacket       => asi_fill_in_6_endofpacket,
            asi_fill_in_6_channel           => asi_fill_in_6_channel,
            asi_fill_in_7_ready             => asi_fill_in_7_ready,
            asi_fill_in_7_valid             => asi_fill_in_7_valid,
            asi_fill_in_7_data              => asi_fill_in_7_data,
            asi_fill_in_7_startofpacket     => asi_fill_in_7_startofpacket,
            asi_fill_in_7_endofpacket       => asi_fill_in_7_endofpacket,
            asi_fill_in_7_channel           => asi_fill_in_7_channel,
            aso_hist_fill_out_ready         => aso_hist_fill_out_ready,
            aso_hist_fill_out_valid         => aso_hist_fill_out_valid,
            aso_hist_fill_out_data          => aso_hist_fill_out_data,
            aso_hist_fill_out_startofpacket => aso_hist_fill_out_startofpacket,
            aso_hist_fill_out_endofpacket   => aso_hist_fill_out_endofpacket,
            aso_hist_fill_out_channel       => aso_hist_fill_out_channel,
            asi_ctrl_data                   => asi_ctrl_data,
            asi_ctrl_valid                  => asi_ctrl_valid,
            asi_ctrl_ready                  => asi_ctrl_ready,
            asi_debug_1_valid               => asi_debug_1_valid,
            asi_debug_1_data                => asi_debug_1_data,
            asi_debug_2_valid               => asi_debug_2_valid,
            asi_debug_2_data                => asi_debug_2_data,
            asi_debug_3_valid               => asi_debug_3_valid,
            asi_debug_3_data                => asi_debug_3_data,
            asi_debug_4_valid               => asi_debug_4_valid,
            asi_debug_4_data                => asi_debug_4_data,
            asi_debug_5_valid               => asi_debug_5_valid,
            asi_debug_5_data                => asi_debug_5_data,
            asi_debug_6_valid               => asi_debug_6_valid,
            asi_debug_6_data                => asi_debug_6_data,
            i_interval_reset                => i_interval_reset,
            i_rst                           => i_rst,
            i_clk                           => i_clk
        );
end architecture rtl;
