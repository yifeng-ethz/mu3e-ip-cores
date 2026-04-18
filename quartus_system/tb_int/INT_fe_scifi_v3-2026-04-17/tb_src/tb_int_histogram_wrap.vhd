library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_int_histogram_wrap is
    generic (
        G_UPDATE_KEY_BIT_HI         : natural := 15;
        G_UPDATE_KEY_BIT_LO         : natural := 0;
        G_UPDATE_KEY_REPRESENTATION : string  := "UNSIGNED";
        G_FILTER_KEY_BIT_HI         : natural := 15;
        G_FILTER_KEY_BIT_LO         : natural := 0;
        G_SAR_TICK_WIDTH            : natural := 16;
        G_SAR_KEY_WIDTH             : natural := 16;
        G_N_BINS                    : natural := 256;
        G_MAX_COUNT_BITS            : natural := 32;
        G_DEF_LEFT_BOUND            : integer := 0;
        G_DEF_BIN_WIDTH             : natural := 1;
        G_AVS_ADDR_WIDTH            : natural := 11;
        G_N_PORTS                   : natural := 1;
        G_CHANNELS_PER_PORT         : natural := 32;
        G_COAL_QUEUE_DEPTH          : natural := 256;
        G_ENABLE_PINGPONG           : boolean := true;
        G_DEF_INTERVAL_CLOCKS       : natural := 125000000;
        G_AVST_DATA_WIDTH           : natural := 39;
        G_AVST_CHANNEL_WIDTH        : natural := 4;
        G_VERSION_MAJOR             : natural := 26;
        G_VERSION_MINOR             : natural := 0;
        G_VERSION_PATCH             : natural := 0;
        G_BUILD                     : natural := 0;
        G_INSTANCE_ID               : natural := 0;
        G_SNOOP_EN                  : boolean := false;
        G_ENABLE_PACKET             : boolean := false
    );
    port (
        i_clk                       : in  std_logic;
        i_rst                       : in  std_logic;
        i_interval_reset            : in  std_logic;

        i_stream_valid              : in  std_logic_vector(7 downto 0);
        i_stream_sop                : in  std_logic_vector(7 downto 0);
        i_stream_eop                : in  std_logic_vector(7 downto 0);
        i_stream_data               : in  std_logic_vector((8 * G_AVST_DATA_WIDTH) - 1 downto 0);
        i_stream_channel            : in  std_logic_vector((8 * G_AVST_CHANNEL_WIDTH) - 1 downto 0);

        avs_hist_bin_readdata       : out std_logic_vector(31 downto 0);
        avs_hist_bin_read           : in  std_logic;
        avs_hist_bin_address        : in  std_logic_vector(G_AVS_ADDR_WIDTH - 1 downto 0);
        avs_hist_bin_waitrequest    : out std_logic;
        avs_hist_bin_write          : in  std_logic;
        avs_hist_bin_writedata      : in  std_logic_vector(31 downto 0);
        avs_hist_bin_burstcount     : in  std_logic_vector(G_AVS_ADDR_WIDTH downto 0);
        avs_hist_bin_readdatavalid  : out std_logic;
        avs_hist_bin_writerespvalid : out std_logic;
        avs_hist_bin_response       : out std_logic_vector(1 downto 0);

        avs_csr_readdata            : out std_logic_vector(31 downto 0);
        avs_csr_read                : in  std_logic;
        avs_csr_address             : in  std_logic_vector(4 downto 0);
        avs_csr_waitrequest         : out std_logic;
        avs_csr_write               : in  std_logic;
        avs_csr_writedata           : in  std_logic_vector(31 downto 0)
    );
end entity tb_int_histogram_wrap;

architecture rtl of tb_int_histogram_wrap is
    function slice_data(
        vec : std_logic_vector;
        idx : natural
    ) return std_logic_vector is
        variable result_v : std_logic_vector(G_AVST_DATA_WIDTH - 1 downto 0);
        constant lo_c     : natural := idx * G_AVST_DATA_WIDTH;
        constant hi_c     : natural := lo_c + G_AVST_DATA_WIDTH - 1;
    begin
        result_v := vec(hi_c downto lo_c);
        return result_v;
    end function;

    function slice_channel(
        vec : std_logic_vector;
        idx : natural
    ) return std_logic_vector is
        variable result_v : std_logic_vector(G_AVST_CHANNEL_WIDTH - 1 downto 0);
        constant lo_c     : natural := idx * G_AVST_CHANNEL_WIDTH;
        constant hi_c     : natural := lo_c + G_AVST_CHANNEL_WIDTH - 1;
    begin
        result_v := vec(hi_c downto lo_c);
        return result_v;
    end function;

    signal unused_fill_ready_0 : std_logic;
    signal unused_fill_ready_1 : std_logic;
    signal unused_fill_ready_2 : std_logic;
    signal unused_fill_ready_3 : std_logic;
    signal unused_fill_ready_4 : std_logic;
    signal unused_fill_ready_5 : std_logic;
    signal unused_fill_ready_6 : std_logic;
    signal unused_fill_ready_7 : std_logic;
    signal unused_ctrl_ready   : std_logic;
    signal unused_fill_out_valid : std_logic;
    signal unused_fill_out_data  : std_logic_vector(G_AVST_DATA_WIDTH - 1 downto 0);
    signal unused_fill_out_sop   : std_logic;
    signal unused_fill_out_eop   : std_logic;
    signal unused_fill_out_ch    : std_logic_vector(G_AVST_CHANNEL_WIDTH - 1 downto 0);
begin
    u_hist : entity work.histogram_statistics_v2
        generic map (
            UPDATE_KEY_BIT_HI         => G_UPDATE_KEY_BIT_HI,
            UPDATE_KEY_BIT_LO         => G_UPDATE_KEY_BIT_LO,
            UPDATE_KEY_REPRESENTATION => G_UPDATE_KEY_REPRESENTATION,
            FILTER_KEY_BIT_HI         => G_FILTER_KEY_BIT_HI,
            FILTER_KEY_BIT_LO         => G_FILTER_KEY_BIT_LO,
            SAR_TICK_WIDTH            => G_SAR_TICK_WIDTH,
            SAR_KEY_WIDTH             => G_SAR_KEY_WIDTH,
            N_BINS                    => G_N_BINS,
            MAX_COUNT_BITS            => G_MAX_COUNT_BITS,
            DEF_LEFT_BOUND            => G_DEF_LEFT_BOUND,
            DEF_BIN_WIDTH             => G_DEF_BIN_WIDTH,
            AVS_ADDR_WIDTH            => G_AVS_ADDR_WIDTH,
            N_PORTS                   => G_N_PORTS,
            CHANNELS_PER_PORT         => G_CHANNELS_PER_PORT,
            COAL_QUEUE_DEPTH          => G_COAL_QUEUE_DEPTH,
            ENABLE_PINGPONG           => G_ENABLE_PINGPONG,
            DEF_INTERVAL_CLOCKS       => G_DEF_INTERVAL_CLOCKS,
            AVST_DATA_WIDTH           => G_AVST_DATA_WIDTH,
            AVST_CHANNEL_WIDTH        => G_AVST_CHANNEL_WIDTH,
            N_DEBUG_INTERFACE         => 0,
            VERSION_MAJOR             => G_VERSION_MAJOR,
            VERSION_MINOR             => G_VERSION_MINOR,
            VERSION_PATCH             => G_VERSION_PATCH,
            BUILD                     => G_BUILD,
            INSTANCE_ID               => G_INSTANCE_ID,
            SNOOP_EN                  => G_SNOOP_EN,
            ENABLE_PACKET             => G_ENABLE_PACKET,
            DEBUG                     => 0
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
            avs_hist_bin_writeresponsevalid => avs_hist_bin_writerespvalid,
            avs_hist_bin_response           => avs_hist_bin_response,

            avs_csr_readdata                => avs_csr_readdata,
            avs_csr_read                    => avs_csr_read,
            avs_csr_address                 => avs_csr_address,
            avs_csr_waitrequest             => avs_csr_waitrequest,
            avs_csr_write                   => avs_csr_write,
            avs_csr_writedata               => avs_csr_writedata,

            asi_hist_fill_in_ready          => unused_fill_ready_0,
            asi_hist_fill_in_valid          => i_stream_valid(0),
            asi_hist_fill_in_data           => slice_data(i_stream_data, 0),
            asi_hist_fill_in_startofpacket  => i_stream_sop(0),
            asi_hist_fill_in_endofpacket    => i_stream_eop(0),
            asi_hist_fill_in_channel        => slice_channel(i_stream_channel, 0),

            asi_fill_in_1_ready             => unused_fill_ready_1,
            asi_fill_in_1_valid             => i_stream_valid(1),
            asi_fill_in_1_data              => slice_data(i_stream_data, 1),
            asi_fill_in_1_startofpacket     => i_stream_sop(1),
            asi_fill_in_1_endofpacket       => i_stream_eop(1),
            asi_fill_in_1_channel           => slice_channel(i_stream_channel, 1),

            asi_fill_in_2_ready             => unused_fill_ready_2,
            asi_fill_in_2_valid             => i_stream_valid(2),
            asi_fill_in_2_data              => slice_data(i_stream_data, 2),
            asi_fill_in_2_startofpacket     => i_stream_sop(2),
            asi_fill_in_2_endofpacket       => i_stream_eop(2),
            asi_fill_in_2_channel           => slice_channel(i_stream_channel, 2),

            asi_fill_in_3_ready             => unused_fill_ready_3,
            asi_fill_in_3_valid             => i_stream_valid(3),
            asi_fill_in_3_data              => slice_data(i_stream_data, 3),
            asi_fill_in_3_startofpacket     => i_stream_sop(3),
            asi_fill_in_3_endofpacket       => i_stream_eop(3),
            asi_fill_in_3_channel           => slice_channel(i_stream_channel, 3),

            asi_fill_in_4_ready             => unused_fill_ready_4,
            asi_fill_in_4_valid             => i_stream_valid(4),
            asi_fill_in_4_data              => slice_data(i_stream_data, 4),
            asi_fill_in_4_startofpacket     => i_stream_sop(4),
            asi_fill_in_4_endofpacket       => i_stream_eop(4),
            asi_fill_in_4_channel           => slice_channel(i_stream_channel, 4),

            asi_fill_in_5_ready             => unused_fill_ready_5,
            asi_fill_in_5_valid             => i_stream_valid(5),
            asi_fill_in_5_data              => slice_data(i_stream_data, 5),
            asi_fill_in_5_startofpacket     => i_stream_sop(5),
            asi_fill_in_5_endofpacket       => i_stream_eop(5),
            asi_fill_in_5_channel           => slice_channel(i_stream_channel, 5),

            asi_fill_in_6_ready             => unused_fill_ready_6,
            asi_fill_in_6_valid             => i_stream_valid(6),
            asi_fill_in_6_data              => slice_data(i_stream_data, 6),
            asi_fill_in_6_startofpacket     => i_stream_sop(6),
            asi_fill_in_6_endofpacket       => i_stream_eop(6),
            asi_fill_in_6_channel           => slice_channel(i_stream_channel, 6),

            asi_fill_in_7_ready             => unused_fill_ready_7,
            asi_fill_in_7_valid             => i_stream_valid(7),
            asi_fill_in_7_data              => slice_data(i_stream_data, 7),
            asi_fill_in_7_startofpacket     => i_stream_sop(7),
            asi_fill_in_7_endofpacket       => i_stream_eop(7),
            asi_fill_in_7_channel           => slice_channel(i_stream_channel, 7),

            aso_hist_fill_out_ready         => '1',
            aso_hist_fill_out_valid         => unused_fill_out_valid,
            aso_hist_fill_out_data          => unused_fill_out_data,
            aso_hist_fill_out_startofpacket => unused_fill_out_sop,
            aso_hist_fill_out_endofpacket   => unused_fill_out_eop,
            aso_hist_fill_out_channel       => unused_fill_out_ch,

            asi_ctrl_data                   => (others => '0'),
            asi_ctrl_valid                  => '0',
            asi_ctrl_ready                  => unused_ctrl_ready,

            asi_debug_1_valid               => '0',
            asi_debug_1_data                => (others => '0'),
            asi_debug_2_valid               => '0',
            asi_debug_2_data                => (others => '0'),
            asi_debug_3_valid               => '0',
            asi_debug_3_data                => (others => '0'),
            asi_debug_4_valid               => '0',
            asi_debug_4_data                => (others => '0'),
            asi_debug_5_valid               => '0',
            asi_debug_5_data                => (others => '0'),
            asi_debug_6_valid               => '0',
            asi_debug_6_data                => (others => '0'),

            i_interval_reset                => i_interval_reset,
            i_rst                           => i_rst,
            i_clk                           => i_clk
        );
end architecture rtl;
