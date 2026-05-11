--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity top is
port (
    BUTTON              : in    std_logic_vector(3 downto 0);
    SW                  : in    std_logic_vector(1 downto 0);

    HEX0_D              : out   std_logic_vector(6 downto 0) := (others => '1');
--    HEX0_DP             : out   std_logic := '1';
    HEX1_D              : out   std_logic_vector(6 downto 0) := (others => '1');
--    HEX1_DP             : out   std_logic := '1';

    LED                 : out   std_logic_vector(3 downto 0) := (others => '1');
    LED_BRACKET         : out   std_logic_vector(3 downto 0) := (others => '1');

    SMA_CLKOUT          : out   std_logic;
    SMA_CLKIN           : in    std_logic; -- 1.8V

    RS422_DE            : out   std_logic;
    RS422_DIN           : in    std_logic; -- 1.8V
    RS422_DOUT          : out   std_logic;
--    RS422_RE_n          : out   std_logic;
--    RJ45_LED_L          : out   std_logic;
    RJ45_LED_R          : out   std_logic;

    -- //////// FAN ////////
    FAN_I2C_SCL         : inout std_logic;
    FAN_I2C_SDA         : inout std_logic;

    -- //////// FLASH ////////
    FLASH_A             : out   std_logic_vector(26 downto 1);
    FLASH_D             : inout std_logic_vector(31 downto 0);
    FLASH_OE_n          : inout std_logic;
    FLASH_WE_n          : out   std_logic;
    FLASH_CE_n          : out   std_logic_vector(1 downto 0);
    FLASH_ADV_n         : out   std_logic;
    FLASH_CLK           : out   std_logic;
    FLASH_RESET_n       : out   std_logic;

    -- //////// POWER ////////
    POWER_MONITOR_I2C_SCL   : inout std_logic;
    POWER_MONITOR_I2C_SDA   : inout std_logic;

    -- //////// TEMP ////////
    TEMP_I2C_SCL        : inout std_logic;
    TEMP_I2C_SDA        : inout std_logic;

    -- //////// Transiver ////////
    QSFPA_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPB_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPC_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPD_TX_p          : out   std_logic_vector(3 downto 0);

    QSFPA_RX_p          : in    std_logic_vector(3 downto 0);
    QSFPB_RX_p          : in    std_logic_vector(3 downto 0);
    QSFPC_RX_p          : in    std_logic_vector(3 downto 0);
    QSFPD_RX_p          : in    std_logic_vector(3 downto 0);

    QSFPA_REFCLK_p      : in    std_logic;
    QSFPB_REFCLK_p      : in    std_logic;
    QSFPC_REFCLK_p      : in    std_logic;
    QSFPD_REFCLK_p      : in    std_logic;

    QSFPA_LP_MODE       : out   std_logic;
    QSFPB_LP_MODE       : out   std_logic;
    QSFPC_LP_MODE       : out   std_logic;
    QSFPD_LP_MODE       : out   std_logic;

    QSFPA_MOD_SEL_n     : out   std_logic;
    QSFPB_MOD_SEL_n     : out   std_logic;
    QSFPC_MOD_SEL_n     : out   std_logic;
    QSFPD_MOD_SEL_n     : out   std_logic;

    QSFPA_RST_n         : out   std_logic;
    QSFPB_RST_n         : out   std_logic;
    QSFPC_RST_n         : out   std_logic;
    QSFPD_RST_n         : out   std_logic;

    -- //////// PCIE ////////
    PCIE_RX_p           : in    std_logic_vector(7 downto 0);
    PCIE_TX_p           : out   std_logic_vector(7 downto 0);
    PCIE_PERST_n        : in    std_logic;
    PCIE_REFCLK_p       : in    std_logic;
    PCIE_SMBCLK         : in    std_logic;
    PCIE_SMBDAT         : inout std_logic;
    PCIE_WAKE_n         : out   std_logic;

    -- reserved calibraion clock
    CLKUSR_100          : in    std_logic;
    -- user reset and clock
    CPU_RESET_n         : in    std_logic;
    CLK_50_B2J          : in    std_logic--;
);
end entity;

architecture arch of top is

    -- constants
    constant g_NLINKS_DATAPATH_TOTL : positive := 8;
    constant g_NLINKS_FEB_TOTL   : integer := 16;
    constant g_NLINKS_DATA_GENERIC : integer := 8;
    constant g_NLINKS_FARM_TOTL  : integer := 1;
    constant g_NLINKS_DATA_PIXEL_US : integer := 0;
    constant g_NLINKS_DATA_PIXEL_DS : integer := 0;

    -- flash
    signal flash_address : std_logic_vector(31 downto 0);
    signal flash_cs_n : std_logic;

    --! external async reset
    signal areset_n : std_logic;

    --! local clock (oscillator)
    signal clk_50 : std_logic;
    --! local reset
    signal reset_50_n : std_logic;

    --! local 125 MHz clock
    signal pll_125 : std_logic;
    signal pll_125_locked : std_logic;

    -- global 125 MHz clock
    signal clk_125, reset_125_n : std_logic;

    -- pcie clock (250 MHz)
    signal pcie0_clk : std_logic;
    signal pcie0_reset_n : std_logic;

    -- pcie read / write registers
    signal pcie0_resets_n   : std_logic_vector(31 downto 0);
    signal pcie0_writeregs  : slv32_array_t(63 downto 0);
    signal pcie0_regwritten : std_logic_vector(63 downto 0);
    signal pcie0_readregs   : slv32_array_t(63 downto 0);

    -- pcie read / write memory
    signal readmem_writedata    : std_logic_vector(31 downto 0);
    signal readmem_writeaddr    : std_logic_vector(15 downto 0);
    signal readmem_wren         : std_logic;
    signal writememreadaddr     : std_logic_vector(15 downto 0);
    signal writememreaddata     : std_logic_vector(31 downto 0);

    -- pcie dma
    signal dma_data_wren, dmamem_endofevent, pcie0_dma0_hfull : std_logic;
    signal dma_data : std_logic_vector(255 downto 0);

    signal feb_rx_data, feb_tx_data : slv32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => x"000000BC");
    signal feb_rx_datak, feb_tx_datak : slv4_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => "0001");
    signal feb_rx, feb_tx : work.mu3e.link32_array_t(g_NLINKS_DATAPATH_TOTL-1 downto 0) := (others => work.mu3e.LINK32_ZERO);

begin

    areset_n <= CPU_RESET_n;

    -- local clock
    clk_50 <= CLK_50_B2J;

    -- generate local reset
    e_reset_50_n : entity work.reset_sync
    port map ( i_areset_n => areset_n, o_reset_n => reset_50_n, i_clk => clk_50 );

    --! generate and route 125 MHz clock to SMA output
    --! (can be connected to SMA input as global clock)
    e_pll_125 : component work.cmp.ip_pll_50to125
    port map (
        locked => pll_125_locked,
        outclk_0 => pll_125,
        refclk => clk_50,
        rst => not reset_50_n--,
    );
    SMA_CLKOUT <= pll_125;

    --! 125 MHz global clock (from SMA input)
    e_clk_125 : work.cmp.ip_clkctrl
    port map (
        inclk => SMA_CLKIN,
        outclk => clk_125--,
    );

    --! generate reset for 125 MHz
    e_reset_125_n : entity work.reset_sync
    port map ( i_areset_n => areset_n, o_reset_n => reset_125_n, i_clk => clk_125 );

    e_pcie_refclk_hz : entity work.clkdiv
    generic map ( g_N => 100000000 )
    port map ( o_clk => led(0), i_reset_n => areset_n, i_clk => PCIE_REFCLK_p );

    --! A10 block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_a10_block : entity work.a10_block
    generic map (
        g_XCVR0_DEV => 1,
        g_XCVR0_CHANNELS => 16,
        g_XCVR0_N => 4,
        g_XCVR1_CHANNELS => 0,
        g_XCVR1_N => 0,
        g_PCIE0_X => 8,
        g_FARM    => 0,
        g_CLK_MHZ => 50.0--,
    )
    port map (
        -- flash interface
        o_flash_address                 => flash_address,
        io_flash_data                   => FLASH_D,
        o_flash_read_n                  => FLASH_OE_n,
        o_flash_write_n                 => FLASH_WE_n,
        o_flash_cs_n                    => flash_cs_n,
        o_flash_reset_n                 => FLASH_RESET_n,

        -- I2C
        io_i2c_scl(0)                   => FAN_I2C_SCL,
        io_i2c_sda(0)                   => FAN_I2C_SDA,
        io_i2c_scl(1)                   => TEMP_I2C_SCL,
        io_i2c_sda(1)                   => TEMP_I2C_SDA,
        io_i2c_scl(2)                   => POWER_MONITOR_I2C_SCL,
        io_i2c_sda(2)                   => POWER_MONITOR_I2C_SDA,

        -- SPI
        i_spi_miso(0)                   => RS422_DIN,
        o_spi_mosi(0)                   => RS422_DOUT,
        o_spi_sclk(0)                   => RJ45_LED_R,
        o_spi_ss_n(0)                   => RS422_DE,

        -- XCVR0 (6250 Mbps @ 156.25 MHz)
        i_xcvr0_rx( 3 downto  0)        => QSFPA_RX_p,
        i_xcvr0_rx( 7 downto  4)        => QSFPB_RX_p,
        i_xcvr0_rx(11 downto  8)        => QSFPC_RX_p,
        i_xcvr0_rx(15 downto 12)        => QSFPD_RX_p,

        o_xcvr0_tx( 3 downto  0)        => QSFPA_TX_p,
        o_xcvr0_tx( 7 downto  4)        => QSFPB_TX_p,
        o_xcvr0_tx(11 downto  8)        => QSFPC_TX_p,
        o_xcvr0_tx(15 downto 12)        => QSFPD_TX_p,

        i_xcvr0_refclk                  => (others => clk_125),

        o_xcvr0_rx_data                 => feb_rx_data,
        o_xcvr0_rx_datak                => feb_rx_datak,
        i_xcvr0_tx_data                 => feb_tx_data,
        i_xcvr0_tx_datak                => feb_tx_datak,
        i_xcvr0_clk                     => pcie0_clk,

        -- XCVR1 (10000 Mbps @ 250 MHz)



        -- PCIe0
        i_pcie0_rx                      => PCIE_RX_p,
        o_pcie0_tx                      => PCIE_TX_p,
        i_pcie0_perst_n                 => PCIE_PERST_n,
        i_pcie0_refclk                  => PCIE_REFCLK_p,
        o_pcie0_reset_n                 => pcie0_reset_n,
        o_pcie0_clk                     => pcie0_clk,
        o_pcie0_clk_hz                  => led(1),

        -- PCIe0 DMA0
        i_pcie0_dma0_wdata              => dma_data,
        i_pcie0_dma0_we                 => dma_data_wren,
        i_pcie0_dma0_eoe                => dmamem_endofevent,
        o_pcie0_dma0_hfull              => pcie0_dma0_hfull,

        -- PCIe0 read interface to writable memory
        i_pcie0_wmem_addr               => writememreadaddr,
        o_pcie0_wmem_rdata              => writememreaddata,

        -- PCIe0 write interface to readable memory
        i_pcie0_rmem_addr               => readmem_writeaddr,
        i_pcie0_rmem_wdata              => readmem_writedata,
        i_pcie0_rmem_we                 => readmem_wren,

        -- PCIe0 update interface for readable registers
        i_pcie0_rregs                   => pcie0_readregs,

        -- PCIe0 read interface for writable registers
        o_pcie0_wregs                   => pcie0_writeregs,
        o_pcie0_resets_n                => pcie0_resets_n,

        o_clk_156_hz                    => led(3),

        i_reset_125_n                   => reset_125_n,
        i_clk_125                       => clk_125,
        o_clk_125_hz                    => led(2),

        i_reset_n                       => reset_50_n,
        i_clk                           => clk_50--,
    );

    --! blinky leds to check the wregs
    LED_BRACKET(3 downto 0) <= pcie0_writeregs(LED_REGISTER_W)(3 downto 0);

    --! map links
    -- for the dev setup we are generic for the input link

    -- data from the FEBs
    -- QSFPA RX(0) --> data --> feb_rx(0)
    feb_rx(0).data  <= feb_rx_data(0);
    feb_rx(0).datak <= feb_rx_datak(0);
    -- QSFPB RX(4) --> data --> feb_rx(1)
    feb_rx(1).data  <= feb_rx_data(4);
    feb_rx(1).datak <= feb_rx_datak(4);
    -- QSFPC RX(8) --> data --> feb_rx(2)
    feb_rx(2).data  <= feb_rx_data(8);
    feb_rx(2).datak <= feb_rx_datak(8);
    -- QSFPD RX(12) --> data --> feb_rx(3)
    feb_rx(3).data  <= feb_rx_data(12);
    feb_rx(3).datak <= feb_rx_datak(12);

    -- secondary links (data when scifi is connected)
    -- QSFPA RX(1) --> data --> feb_rx(4)
    feb_rx(4).data  <= feb_rx_data(1);
    feb_rx(4).datak <= feb_rx_datak(1);
    -- QSFPB RX(5) --> data --> feb_rx(5)
    feb_rx(5).data  <= feb_rx_data(5);
    feb_rx(5).datak <= feb_rx_datak(5);
    -- QSFPC RX(9) --> data --> feb_rx(6)
    feb_rx(6).data  <= feb_rx_data(9);
    feb_rx(6).datak <= feb_rx_datak(9);
    -- QSFPD RX(13) --> data --> feb_rx(7)
    feb_rx(7).data  <= feb_rx_data(13);
    feb_rx(7).datak <= feb_rx_datak(13);

    -- slow control to the FEBs
    -- QSFPA TX(0) <-- SC <-- feb_tx(0)
    feb_tx_data(0)   <= feb_tx(0).data;
    feb_tx_datak(0)  <= feb_tx(0).datak;
    -- QSFPB TX(4) <-- SC <-- feb_tx(1)
    feb_tx_data(4)   <= feb_tx(1).data;
    feb_tx_datak(4)  <= feb_tx(1).datak;
    -- QSFPC TX(8) <-- SC <-- feb_tx(2)
    feb_tx_data(8)   <= feb_tx(2).data;
    feb_tx_datak(8)  <= feb_tx(2).datak;
    -- QSFPD TX(12) <-- SC <-- feb_tx(3)
    feb_tx_data(12)  <= feb_tx(3).data;
    feb_tx_datak(12) <= feb_tx(3).datak;

    --! SWB Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_swb_block : entity work.swb_block
    generic map (
        g_NLINKS_FEB_TOTL       => g_NLINKS_DATAPATH_TOTL,
        g_NLINKS_DATA_GENERIC   => g_NLINKS_DATA_GENERIC,
        g_NLINKS_FARM_TOTL      => g_NLINKS_FARM_TOTL,
        g_NLINKS_DATA_PIXEL_US  => g_NLINKS_DATA_PIXEL_US,
        g_NLINKS_DATA_PIXEL_DS  => g_NLINKS_DATA_PIXEL_DS--,
    )
    port map (
        i_feb_rx        => feb_rx,
        o_feb_tx        => feb_tx,

        --! PCIe registers / memory
        i_writeregs     => pcie0_writeregs,
        i_regwritten    => pcie0_regwritten,
        o_readregs      => pcie0_readregs,
        i_resets_n      => pcie0_resets_n,

        i_wmem_rdata    => writememreaddata,
        o_wmem_addr     => writememreadaddr,

        o_rmem_wdata    => readmem_writedata,
        o_rmem_addr     => readmem_writeaddr,
        o_rmem_we       => readmem_wren,

        i_dmamemhalffull=> pcie0_dma0_hfull,
        o_dma_wren      => dma_data_wren,
        o_endofevent    => dmamem_endofevent,
        o_dma_data      => dma_data,

        o_farm_tx       => open,

        i_reset_n       => pcie0_reset_n,
        i_clk           => pcie0_clk--,
    );

    -- flash interface
    -- (address drives two chips, each with 16-bit data interface,
    -- such that the combined interface is 32-bit)
    FLASH_A(26 downto 1) <= flash_address(27 downto 2);
    FLASH_CE_n <= (flash_cs_n, flash_cs_n);
    -- ADV (address valid) and clock are not used in async-read mode
    FLASH_ADV_n <= '0';
    FLASH_CLK <= '0';

    -- enable QSFP links
    QSFPA_LP_MODE <= '0';
    QSFPB_LP_MODE <= '0';
    QSFPC_LP_MODE <= '0';
    QSFPD_LP_MODE <= '0';
    QSFPA_MOD_SEL_n <= '1';
    QSFPB_MOD_SEL_n <= '1';
    QSFPC_MOD_SEL_n <= '1';
    QSFPD_MOD_SEL_n <= '1';
    QSFPA_RST_n <= '1';
    QSFPB_RST_n <= '1';
    QSFPC_RST_n <= '1';
    QSFPD_RST_n <= '1';

end architecture;
