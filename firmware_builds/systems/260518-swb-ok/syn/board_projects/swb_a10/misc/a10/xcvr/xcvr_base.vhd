--
-- author : Alexandr Kozlinskiy
-- date : 2019-03-20
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity xcvr_base is
generic (
    g_MODE : string := "std";
    g_CHANNELS : positive := 4;
    g_BITS : positive := 40;
    g_REFCLK_MHZ : real;
    g_RATE_MBPS : positive;
    g_CLK_MHZ : real--;
);
port (
    -- serial data
    i_rx_serial         : in    std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_serial         : out   std_logic_vector(g_CHANNELS-1 downto 0);

    -- reference clock to cdr and pll
    i_refclk            : in    std_logic;

    -- parallel data
    o_rx_data           : out   std_logic_vector(g_CHANNELS*g_BITS-1 downto 0);
    i_tx_data           : in    std_logic_vector(g_CHANNELS*g_BITS-1 downto 0);

    -- parallel clocks
    o_rx_clkout         : out   std_logic_vector(g_CHANNELS-1 downto 0);
    i_rx_clkin          : in    std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_clkout         : out   std_logic_vector(g_CHANNELS-1 downto 0);
    i_tx_clkin          : in    std_logic_vector(g_CHANNELS-1 downto 0);

    --
    o_rx_analogreset    : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_rx_digitalreset   : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_analogreset    : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_digitalreset   : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_rx_lockedtoref    : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_rx_lockedtodata   : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_rx_ready          : out   std_logic_vector(g_CHANNELS-1 downto 0);
    o_tx_ready          : out   std_logic_vector(g_CHANNELS-1 downto 0);

    i_rx_bitslip        : in    std_logic_vector(g_CHANNELS-1 downto 0) := (others => '0');
    i_rx_seriallpbken   : in    std_logic_vector(g_CHANNELS-1 downto 0) := (others => '0');

    -- avalon slave interfaces
    -- # address units words
    -- # read latency 0
    i_phy_channel       : in    integer := 0;
    i_phy_address       : in    std_logic_vector(9 downto 0) := (others => '0');
    i_phy_read          : in    std_logic := '0';
    o_phy_readdata      : out   std_logic_vector(31 downto 0) := X"CCCCCCCC";
    i_phy_write         : in    std_logic := '0';
    i_phy_writedata     : in    std_logic_vector(31 downto 0) := (others => '0');
    o_phy_waitrequest   : out   std_logic := '0';

    i_pll_address       : in    std_logic_vector(9 downto 0) := (others => '0');
    i_pll_read          : in    std_logic := '0';
    o_pll_readdata      : out   std_logic_vector(31 downto 0) := X"CCCCCCCC";
    i_pll_write         : in    std_logic := '0';
    i_pll_writedata     : in    std_logic_vector(31 downto 0) := (others => '0');
    o_pll_waitrequest   : out   std_logic := '0';

    i_reset_n           : in    std_logic;
    -- clock to phy/pll avalon slaves and reset controller
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of xcvr_base is

    constant c_BYTES : positive := work.util.value_if(g_BITS = 10 or g_BITS = 20 or g_BITS = 40, g_BITS / 10, 0);

    signal ch : integer range 0 to g_CHANNELS-1 := 0;

    signal rx_parallel_data     :   std_logic_vector(g_CHANNELS*g_BITS-1 downto 0);
    signal tx_parallel_data     :   std_logic_vector(g_CHANNELS*g_BITS-1 downto 0);

    signal pll_powerdown        :   std_logic_vector(0 downto 0);
    signal pll_cal_busy         :   std_logic_vector(0 downto 0);
    signal pll_locked           :   std_logic_vector(0 downto 0);

    signal tx_serial_clk        :   std_logic;

    -- analog reset => reset PMA/CDR (phys medium attachment, clock data recovery)
    -- digital reset => reset PCS (phys coding sublayer)
    signal tx_analogreset       :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal tx_digitalreset      :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_analogreset       :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_digitalreset      :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal tx_cal_busy          :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_cal_busy          :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal tx_ready             :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_ready             :   std_logic_vector(g_CHANNELS-1 downto 0);
    signal rx_is_lockedtoref    :   std_logic_vector(g_CHANNELS-1 downto 0);
    -- locked to data - indicates that the RX CDR is locked to incoming data
    signal rx_is_lockedtodata   :   std_logic_vector(g_CHANNELS-1 downto 0);

    signal tx_fifo_error        :   std_logic_vector(g_CHANNELS-1 downto 0) := (others => '0');
    signal rx_fifo_error        :   std_logic_vector(g_CHANNELS-1 downto 0) := (others => '0');

    signal rx_syncstatus        :   std_logic_vector(g_CHANNELS*c_BYTES-1 downto 0) := (others => '0');
    signal rx_patterndetect     :   std_logic_vector(g_CHANNELS*c_BYTES-1 downto 0) := (others => '0');
    signal rx_enapatternalign   :   std_logic_vector(g_CHANNELS-1 downto 0);

begin

    ch <= i_phy_channel;

    o_rx_data <= rx_parallel_data;
    tx_parallel_data <= i_tx_data;

    o_rx_analogreset <= rx_analogreset;
    o_rx_digitalreset <= rx_digitalreset;
    o_tx_analogreset <= tx_analogreset;
    o_tx_digitalreset <= tx_digitalreset;

    o_rx_ready <= rx_ready;
    o_tx_ready <= tx_ready;
    o_rx_lockedtoref <= rx_is_lockedtoref;
    o_rx_lockedtodata <= rx_is_lockedtodata;

    generate_xcvr_phy_2_10_125_1250 : if (
        g_MODE = "std" and g_CHANNELS = 2 and g_BITS = 10 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 1250
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_2_10_125_1250
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
--        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_4_10_125_1250 : if (
        g_MODE = "std" and g_CHANNELS = 4 and g_BITS = 10 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 1250
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_4_10_125_1250
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
--        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_4_40_125_5000 : if (
        g_MODE = "std" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_4_40_125_5000
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
--        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_4_40_125_6250 : if (
        g_MODE = "std" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_4_40_125_6250
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
--        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_6_40_125_5000 : if (
        g_MODE = "std" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_6_40_125_5000
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
--        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_6_40_125_6250 : if (
        g_MODE = "std" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_6_40_125_6250
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
--        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_4_40_125_5000_enh : if (
        g_MODE = "enh" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_4_40_125_5000_enh
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_4_40_125_6250_enh : if (
        g_MODE = "enh" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_4_40_125_6250_enh
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_4_40_125_10000_enh : if (
        g_MODE = "enh" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 10000
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_4_40_125_10000_enh
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_6_40_125_5000_enh : if (
        g_MODE = "enh" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_6_40_125_5000_enh
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_6_40_125_6250_enh : if (
        g_MODE = "enh" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_6_40_125_6250_enh
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    generate_xcvr_phy_6_40_125_10000_enh : if (
        g_MODE = "enh" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 10000
    ) generate
    e_phy : component work.cmp.ip_xcvr_phy_6_40_125_10000_enh
    port map (
        tx_serial_data  => o_tx_serial,
        rx_serial_data  => i_rx_serial,

        rx_cdr_refclk0  => i_refclk,
        tx_serial_clk0  => (others => tx_serial_clk),

        tx_analogreset  => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset  => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy     => tx_cal_busy,
        rx_cal_busy     => rx_cal_busy,

        rx_is_lockedtoref   => rx_is_lockedtoref,
        rx_is_lockedtodata  => rx_is_lockedtodata,

        rx_bitslip          => i_rx_bitslip,

        rx_parallel_data    => rx_parallel_data,
        tx_parallel_data    => tx_parallel_data,
        tx_enh_data_valid   => (others => '1'),

        tx_clkout       => o_tx_clkout,
        tx_coreclkin    => i_tx_clkin,
        rx_clkout       => o_rx_clkout,
        rx_coreclkin    => i_rx_clkin,

        rx_seriallpbken => i_rx_seriallpbken,

        unused_tx_parallel_data => (others => '0'),
        unused_rx_parallel_data => open,

        reconfig_address        => std_logic_vector(to_unsigned(ch, work.util.vector_width(g_CHANNELS))) & i_phy_address,
        reconfig_read(0)        => i_phy_read,
        reconfig_readdata       => o_phy_readdata,
        reconfig_write(0)       => i_phy_write,
        reconfig_writedata      => i_phy_writedata,
        reconfig_waitrequest(0) => o_phy_waitrequest,
        reconfig_reset(0)       => not i_reset_n,
        reconfig_clk(0)         => i_clk--,
    );
    end generate;

    assert ( false
        -- mode std
        or ( g_MODE = "std" and g_CHANNELS = 2 and g_BITS = 10 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 1250 )
        or ( g_MODE = "std" and g_CHANNELS = 4 and g_BITS = 10 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 1250 )
        or ( g_MODE = "std" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000 )
        or ( g_MODE = "std" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250 )
        or ( g_MODE = "std" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000 )
        or ( g_MODE = "std" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250 )
        -- mode enh
        or ( g_MODE = "enh" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000 )
        or ( g_MODE = "enh" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250 )
        or ( g_MODE = "enh" and g_CHANNELS = 4 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 10000 )
        or ( g_MODE = "enh" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000 )
        or ( g_MODE = "enh" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250 )
        or ( g_MODE = "enh" and g_CHANNELS = 6 and g_BITS = 40 and g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 10000 )
    ) report "ERROR: undefined 'ip_xcvr_phy_'"
        & ", g_MODE = '" & g_MODE & "'"
        & ", g_CHANNELS = " & integer'image(g_CHANNELS)
        & ", g_BITS = " & integer'image(g_BITS)
        & ", g_REFCLK_MHZ = " & real'image(g_REFCLK_MHZ)
        & ", g_RATE_MBPS = " & integer'image(g_RATE_MBPS)
    severity failure;



    generate_xcvr_fpll_125_1250 : if ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 1250 ) generate
    e_fpll : component work.cmp.ip_xcvr_fpll_125_1250
    port map (
        pll_refclk0     => i_refclk,
        pll_powerdown   => pll_powerdown(0),
        pll_cal_busy    => pll_cal_busy(0),
        pll_locked      => pll_locked(0),
        tx_serial_clk   => tx_serial_clk,

        reconfig_address0       => i_pll_address,
        reconfig_read0          => i_pll_read,
        reconfig_readdata0      => o_pll_readdata,
        reconfig_write0         => i_pll_write,
        reconfig_writedata0     => i_pll_writedata,
        reconfig_waitrequest0   => o_pll_waitrequest,
        reconfig_reset0         => not i_reset_n,
        reconfig_clk0           => i_clk--,
    );
    end generate;

    generate_xcvr_fpll_125_5000 : if ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000 ) generate
    e_fpll : component work.cmp.ip_xcvr_fpll_125_5000
    port map (
        pll_refclk0     => i_refclk,
        pll_powerdown   => pll_powerdown(0),
        pll_cal_busy    => pll_cal_busy(0),
        pll_locked      => pll_locked(0),
        tx_serial_clk   => tx_serial_clk,

        reconfig_address0       => i_pll_address,
        reconfig_read0          => i_pll_read,
        reconfig_readdata0      => o_pll_readdata,
        reconfig_write0         => i_pll_write,
        reconfig_writedata0     => i_pll_writedata,
        reconfig_waitrequest0   => o_pll_waitrequest,
        reconfig_reset0         => not i_reset_n,
        reconfig_clk0           => i_clk--,
    );
    end generate;

    generate_xcvr_fpll_125_6250 : if ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250 ) generate
    e_fpll : component work.cmp.ip_xcvr_fpll_125_6250
    port map (
        pll_refclk0     => i_refclk,
        pll_powerdown   => pll_powerdown(0),
        pll_cal_busy    => pll_cal_busy(0),
        pll_locked      => pll_locked(0),
        tx_serial_clk   => tx_serial_clk,

        reconfig_address0       => i_pll_address,
        reconfig_read0          => i_pll_read,
        reconfig_readdata0      => o_pll_readdata,
        reconfig_write0         => i_pll_write,
        reconfig_writedata0     => i_pll_writedata,
        reconfig_waitrequest0   => o_pll_waitrequest,
        reconfig_reset0         => not i_reset_n,
        reconfig_clk0           => i_clk--,
    );
    end generate;

    generate_xcvr_fpll_125_10000 : if ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 10000 ) generate
    e_fpll : component work.cmp.ip_xcvr_fpll_125_10000
    port map (
        pll_refclk0     => i_refclk,
        pll_powerdown   => pll_powerdown(0),
        pll_cal_busy    => pll_cal_busy(0),
        pll_locked      => pll_locked(0),
        tx_serial_clk   => tx_serial_clk,

        reconfig_address0       => i_pll_address,
        reconfig_read0          => i_pll_read,
        reconfig_readdata0      => o_pll_readdata,
        reconfig_write0         => i_pll_write,
        reconfig_writedata0     => i_pll_writedata,
        reconfig_waitrequest0   => o_pll_waitrequest,
        reconfig_reset0         => not i_reset_n,
        reconfig_clk0           => i_clk--,
    );
    end generate;

    assert ( false
        or ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 1250 )
        or ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 5000 )
        or ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 6250 )
        or ( g_REFCLK_MHZ = 125.0 and g_RATE_MBPS = 10000 )
    ) report "ERROR: undefined 'ip_xcvr_fpll_'"
        & ", g_REFCLK_MHZ = " & real'image(g_REFCLK_MHZ)
        & ", g_RATE_MBPS = " & integer'image(g_RATE_MBPS)
    severity failure;



    generate_xcvr_reset_2_50 : if ( g_CHANNELS = 2 and g_CLK_MHZ = 50.0 ) generate
    e_reset : component work.cmp.ip_xcvr_reset_2_50
    port map (
        tx_analogreset => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy => tx_cal_busy,
        rx_cal_busy => rx_cal_busy,

        tx_ready => tx_ready,
        rx_ready => rx_ready,

        rx_is_lockedtodata => rx_is_lockedtodata,

        pll_powerdown => pll_powerdown,
        pll_cal_busy => pll_cal_busy,
        pll_locked => pll_locked,

        pll_select => (others => '0'),

        reset => not i_reset_n,
        clock => i_clk--,
    );
    end generate;

    generate_xcvr_reset_2_100 : if ( g_CHANNELS = 2 and g_CLK_MHZ = 100.0 ) generate
    e_reset : component work.cmp.ip_xcvr_reset_2_100
    port map (
        tx_analogreset => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy => tx_cal_busy,
        rx_cal_busy => rx_cal_busy,

        tx_ready => tx_ready,
        rx_ready => rx_ready,

        rx_is_lockedtodata => rx_is_lockedtodata,

        pll_powerdown => pll_powerdown,
        pll_cal_busy => pll_cal_busy,
        pll_locked => pll_locked,

        pll_select => (others => '0'),

        reset => not i_reset_n,
        clock => i_clk--,
    );
    end generate;

    generate_xcvr_reset_4_50 : if ( g_CHANNELS = 4 and g_CLK_MHZ = 50.0 ) generate
    e_reset : component work.cmp.ip_xcvr_reset_4_50
    port map (
        tx_analogreset => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy => tx_cal_busy,
        rx_cal_busy => rx_cal_busy,

        tx_ready => tx_ready,
        rx_ready => rx_ready,

        rx_is_lockedtodata => rx_is_lockedtodata,

        pll_powerdown => pll_powerdown,
        pll_cal_busy => pll_cal_busy,
        pll_locked => pll_locked,

        pll_select => (others => '0'),

        reset => not i_reset_n,
        clock => i_clk--,
    );
    end generate;

    generate_xcvr_reset_4_100 : if ( g_CHANNELS = 4 and g_CLK_MHZ = 100.0 ) generate
    e_reset : component work.cmp.ip_xcvr_reset_4_100
    port map (
        tx_analogreset => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy => tx_cal_busy,
        rx_cal_busy => rx_cal_busy,

        tx_ready => tx_ready,
        rx_ready => rx_ready,

        rx_is_lockedtodata => rx_is_lockedtodata,

        pll_powerdown => pll_powerdown,
        pll_cal_busy => pll_cal_busy,
        pll_locked => pll_locked,

        pll_select => (others => '0'),

        reset => not i_reset_n,
        clock => i_clk--,
    );
    end generate;

    generate_xcvr_reset_6_50 : if ( g_CHANNELS = 6 and g_CLK_MHZ = 50.0 ) generate
    e_reset : component work.cmp.ip_xcvr_reset_6_50
    port map (
        tx_analogreset => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy => tx_cal_busy,
        rx_cal_busy => rx_cal_busy,

        tx_ready => tx_ready,
        rx_ready => rx_ready,

        rx_is_lockedtodata => rx_is_lockedtodata,

        pll_powerdown => pll_powerdown,
        pll_cal_busy => pll_cal_busy,
        pll_locked => pll_locked,

        pll_select => (others => '0'),

        reset => not i_reset_n,
        clock => i_clk--,
    );
    end generate;

    generate_xcvr_reset_6_100 : if ( g_CHANNELS = 6 and g_CLK_MHZ = 100.0 ) generate
    e_reset : component work.cmp.ip_xcvr_reset_6_100
    port map (
        tx_analogreset => tx_analogreset,
        tx_digitalreset => tx_digitalreset,
        rx_analogreset => rx_analogreset,
        rx_digitalreset => rx_digitalreset,

        tx_cal_busy => tx_cal_busy,
        rx_cal_busy => rx_cal_busy,

        tx_ready => tx_ready,
        rx_ready => rx_ready,

        rx_is_lockedtodata => rx_is_lockedtodata,

        pll_powerdown => pll_powerdown,
        pll_cal_busy => pll_cal_busy,
        pll_locked => pll_locked,

        pll_select => (others => '0'),

        reset => not i_reset_n,
        clock => i_clk--,
    );
    end generate;

    assert ( false
        or ( g_CHANNELS = 2 and g_CLK_MHZ = 50.0 )
        or ( g_CHANNELS = 2 and g_CLK_MHZ = 100.0 )
        or ( g_CHANNELS = 4 and g_CLK_MHZ = 50.0 )
        or ( g_CHANNELS = 4 and g_CLK_MHZ = 100.0 )
        or ( g_CHANNELS = 6 and g_CLK_MHZ = 50.0 )
        or ( g_CHANNELS = 6 and g_CLK_MHZ = 100.0 )
    ) report "ERROR: undefined 'ip_xcvr_reset_'"
        & ", g_CHANNELS = " & integer'image(g_CHANNELS)
        & ", g_CLK_MHZ = " & real'image(g_CLK_MHZ)
    severity failure;

end architecture;
