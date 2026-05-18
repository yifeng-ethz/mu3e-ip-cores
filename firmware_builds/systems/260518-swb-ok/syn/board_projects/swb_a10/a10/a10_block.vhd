--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity a10_block is
generic (
    g_XCVR0_DEV         : integer := 0;
    g_XCVR0_CHANNELS    : integer := 16;
    g_XCVR0_N           : integer := 4;
    -- [AK] TODO: rename to g_XCVR0_RX_MAP
    g_XCVR0_RX_P        : integer_vector := ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 );
    g_XCVR0_TX_P        : integer_vector := ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 );
    g_XCVR1_CHANNELS    : integer := 0;
    g_XCVR1_N           : integer := 0;
    g_XCVR1_RX_P        : integer_vector := ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 );
    g_XCVR1_TX_P        : integer_vector := ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 );
    g_SFP_CHANNELS      : integer := 0;
    g_PCIE0_X           : integer := 8;
    g_FARM              : integer := 0;
    g_CLK_MHZ           : real := 50.0--;
);
port (
    -- flash interface
    o_flash_address     : out   std_logic_vector(31 downto 0);
    io_flash_data       : inout std_logic_vector(31 downto 0);
    o_flash_read_n      : out   std_logic;
    o_flash_write_n     : out   std_logic;
    o_flash_cs_n        : out   std_logic;
    o_flash_reset_n     : out   std_logic;

    -- I2C
    io_i2c_scl          : inout std_logic_vector(31 downto 0);
    io_i2c_sda          : inout std_logic_vector(31 downto 0);

    -- SPI
    i_spi_miso          : in    std_logic_vector(31 downto 0) := (others => '0');
    o_spi_mosi          : out   std_logic_vector(31 downto 0);
    o_spi_sclk          : out   std_logic_vector(31 downto 0);
    o_spi_ss_n          : out   std_logic_vector(31 downto 0);

    -- XCVR0 (6250 Mbps @ 156.25 MHz)
    i_xcvr0_rx          : in    std_logic_vector(g_XCVR0_CHANNELS-1 downto 0) := (others => '0');
    o_xcvr0_tx          : out   std_logic_vector(g_XCVR0_CHANNELS-1 downto 0);
    i_xcvr0_refclk      : in    std_logic_vector(g_XCVR0_N-1 downto 0) := (others => '0');

    o_xcvr0_rx_data     : out   slv32_array_t(g_XCVR0_CHANNELS-1 downto 0);
    o_xcvr0_rx_datak    : out   slv4_array_t(g_XCVR0_CHANNELS-1 downto 0);
    i_xcvr0_tx_data     : in    slv32_array_t(g_XCVR0_CHANNELS-1 downto 0) := (others => (others => '0'));
    i_xcvr0_tx_datak    : in    slv4_array_t(g_XCVR0_CHANNELS-1 downto 0) := (others => (others => '0'));
    i_xcvr0_clk         : in    std_logic := '0';

    -- XCVR1 (10000 Mbps @ 250 MHz)
    i_xcvr1_rx          : in    std_logic_vector(g_XCVR1_CHANNELS-1 downto 0) := (others => '0');
    o_xcvr1_tx          : out   std_logic_vector(g_XCVR1_CHANNELS-1 downto 0);
    i_xcvr1_refclk      : in    std_logic_vector(g_XCVR1_N-1 downto 0) := (others => '0');

    o_xcvr1_rx_data     : out   slv32_array_t(g_XCVR1_CHANNELS-1 downto 0);
    o_xcvr1_rx_datak    : out   slv4_array_t(g_XCVR1_CHANNELS-1 downto 0);
    i_xcvr1_tx_data     : in    slv32_array_t(g_XCVR1_CHANNELS-1 downto 0) := (others => (others => '0'));
    i_xcvr1_tx_datak    : in    slv4_array_t(g_XCVR1_CHANNELS-1 downto 0) := (others => (others => '0'));
    i_xcvr1_clk         : in    std_logic := '0';

    -- SFP
    i_sfp_rx            : in    std_logic_vector(g_SFP_CHANNELS-1 downto 0) := (others => '0');
    o_sfp_tx            : out   std_logic_vector(g_SFP_CHANNELS-1 downto 0);
    i_sfp_refclk        : in    std_logic := '0';



    -- PCIe0
    i_pcie0_rx          : in    std_logic_vector(g_PCIE0_X-1 downto 0) := (others => '0');
    o_pcie0_tx          : out   std_logic_vector(g_PCIE0_X-1 downto 0);
    i_pcie0_perst_n     : in    std_logic := '0';
    i_pcie0_refclk      : in    std_logic := '0'; -- ref 100 MHz clock
    o_pcie0_reset_n     : out   std_logic;
    o_pcie0_clk         : out   std_logic;
    o_pcie0_clk_hz      : out   std_logic;

    -- PCIe0 DMA0
    i_pcie0_dma0_wdata  : in    std_logic_vector(255 downto 0) := (others => '0');
    i_pcie0_dma0_we     : in    std_logic := '0'; -- write enable
    i_pcie0_dma0_eoe    : in    std_logic := '0'; -- end of event
    o_pcie0_dma0_hfull  : out   std_logic; -- half full

    -- PCIe0 read interface to writable memory
    i_pcie0_wmem_addr   : in    std_logic_vector(15 downto 0) := (others => '0');
    o_pcie0_wmem_rdata  : out   std_logic_vector(31 downto 0);

    -- PCIe0 write interface to readable memory
    i_pcie0_rmem_addr   : in    std_logic_vector(15 downto 0) := (others => '0');
    i_pcie0_rmem_wdata  : in    std_logic_vector(31 downto 0) := (others => '0');
    i_pcie0_rmem_we     : in    std_logic := '0';

    -- PCIe0 update interface for readable registers
    i_pcie0_rregs       : in    slv32_array_t(63 downto 0) := (others => (others => '0'));

    -- PCIe0 read interface for writable registers
    o_pcie0_wregs       : out   slv32_array_t(63 downto 0);
    o_pcie0_regwritten  : out   std_logic_vector(63 downto 0);
    o_pcie0_resets_n    : out   std_logic_vector(31 downto 0);

    -- reference clock (derived from clk_125)
    -- for 6.25 Gbit xcvr
    o_reset_156_n       : out   std_logic;
    o_clk_156           : out   std_logic;
    o_clk_156_hz        : out   std_logic;

    -- reference clock (derived from clk_125)
    -- for 10 Gbit xcvr
    o_reset_250_n       : out   std_logic;
    o_clk_250           : out   std_logic;
    o_clk_250_hz        : out   std_logic;

    -- global 125 MHz clock
    -- (should only be used as reference clock)
    i_reset_125_n       : in    std_logic;
    i_clk_125           : in    std_logic;
    o_clk_125_hz        : out   std_logic;



    -- local clock
    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of a10_block is

    signal flash_address    : std_logic_vector(31 downto 0) := (others => '0');
    signal flash_reset_n    : std_logic;

    signal reset_156_n      : std_logic;
    signal clk_156          : std_logic;
    signal reset_250_n      : std_logic;
    signal clk_250          : std_logic;

    signal pcie0_clk        : std_logic;
    signal pcie0_reset_n    : std_logic;

    signal nios_reset_n     : std_logic;

    signal nios_i2c_scl     : std_logic;
    signal nios_i2c_scl_oe  : std_logic;
    signal nios_i2c_sda     : std_logic;
    signal nios_i2c_sda_oe  : std_logic;
    signal nios_i2c_mask    : std_logic_vector(31 downto 0);

    signal nios_spi_miso    : std_logic;
    signal nios_spi_mosi    : std_logic;
    signal nios_spi_sclk    : std_logic;
    signal nios_spi_ss_n    : std_logic_vector(31 downto 0);

    signal nios_pio         : std_logic_vector(31 downto 0);

    signal av_xcvr0         : work.util.avalon_t := work.util.c_AVALON_ZERO;
    signal av_xcvr1         : work.util.avalon_t := work.util.c_AVALON_ZERO;
    signal av_sfp           : work.util.avalon_t := work.util.c_AVALON_ZERO;

    signal xcvr0_rx_data    : slv32_array_t(o_xcvr0_rx_data'range);
    signal xcvr0_rx_datak   : slv4_array_t(o_xcvr0_rx_datak'range);
    signal xcvr0_tx_data    : slv32_array_t(i_xcvr0_tx_data'range);
    signal xcvr0_tx_datak   : slv4_array_t(i_xcvr0_tx_datak'range);
    signal xcvr1_rx_data    : slv32_array_t(o_xcvr1_rx_data'range);
    signal xcvr1_rx_datak   : slv4_array_t(o_xcvr1_rx_datak'range);
    signal xcvr1_tx_data    : slv32_array_t(i_xcvr1_tx_data'range);
    signal xcvr1_tx_datak   : slv4_array_t(i_xcvr1_tx_datak'range);

    signal xcvr0_rx_locked  : std_logic_vector(o_xcvr0_rx_data'range);
    signal xcvr1_rx_locked  : std_logic_vector(o_xcvr1_rx_data'range);
    signal xcvr0_rx_LoL_cnt : slv8_array_t(o_xcvr0_rx_data'range);
    signal xcvr1_rx_LoL_cnt : slv8_array_t(o_xcvr1_rx_data'range);
    signal xcvr0_rx_err_cnt : slv16_array_t(o_xcvr0_rx_data'range);
    signal xcvr1_rx_err_cnt : slv16_array_t(o_xcvr1_rx_data'range);
    signal xcvr_ctrl_r, xcvr_ctrl_w : std_logic_vector(31 downto 0);

    signal pcie0_rregs      : reg32array_pcie;
    signal pcie0_wregs      : reg32array_pcie;
    signal pcie0_wregs_B    : reg32array_pcie;
    signal local_pcie0_rregs_A : slv32_array_t(63 downto 0) := (others => (others => '0')); -- PCIe clk
    signal local_pcie0_rregs_B : slv32_array_t(63 downto 0) := (others => (others => '0')); -- data link clk

    signal pcie0_resets_n   : std_logic_vector(31 downto 0);
    signal pcie0_dma0_hfull : std_logic;

    --! pll lock counters
    signal cnt_lock_125to156 : std_logic_vector(30 downto 0);
    signal cnt_lock_125to250 : std_logic_vector(30 downto 0);
    signal clk_156_locked, clk_250_locked : std_logic;

begin

    assert ( true
        and ( g_XCVR0_N = 0 or g_XCVR0_CHANNELS mod g_XCVR0_N = 0 )
        and ( g_XCVR1_N = 0 or g_XCVR1_CHANNELS mod g_XCVR1_N = 0 )
    ) severity failure;

    o_flash_reset_n <= flash_reset_n;
    o_flash_address <= flash_address;

    o_pcie0_clk <= pcie0_clk;

    --! output signals
    gen_pcie0_wregs_mapping : for i in 0 to 63 generate
        o_pcie0_wregs(i) <= pcie0_wregs(i);
    end generate;
    o_pcie0_resets_n    <= pcie0_resets_n;
    o_pcie0_dma0_hfull  <= pcie0_dma0_hfull;

    e_cnt_125to156 : entity work.counter
    generic map (
        WRAP => true,
        W => cnt_lock_125to156'length--,
    )
    port map (
        o_cnt => cnt_lock_125to156,
        i_ena => not clk_156_locked,
        i_reset_n => pcie0_reset_n,
        i_clk => pcie0_clk--,
    );
    local_pcie0_rregs_A(CNT_PLL_156_REGISTER_R) <= clk_156_locked & cnt_lock_125to156;

    e_cnt_125to250 : entity work.counter
    generic map (
        WRAP => true,
        W => cnt_lock_125to250'length--,
    )
    port map (
        o_cnt => cnt_lock_125to250,
        i_ena => not clk_250_locked,
        i_reset_n => pcie0_reset_n,
        i_clk => pcie0_clk
    );
    local_pcie0_rregs_A(CNT_PLL_250_REGISTER_R) <= clk_250_locked & cnt_lock_125to250;

    -- 156.25 MHz data clock (reference is 125 MHz global clock)
    e_clk_156 : component work.cmp.ip_pll_125to156
    port map (
        locked => clk_156_locked,
        outclk_0 => clk_156,
        refclk => i_clk_125,
        rst => not i_reset_125_n--,
    );
    o_clk_156 <= clk_156;

    -- 250 MHz data clock (reference is 125 MHz global clock)
    e_clk_250 : component work.cmp.ip_pll_125to250
    port map (
        locked => clk_250_locked,
        outclk_0 => clk_250,
        refclk => i_clk_125,
        rst => not i_reset_125_n--,
    );
    o_clk_250 <= clk_250;

    e_reset_156_n : entity work.reset_sync
    port map ( i_areset_n => i_reset_n, o_reset_n => reset_156_n,  i_clk => clk_156 );
    o_reset_156_n <= reset_156_n;

    e_reset_250_n : entity work.reset_sync
    port map ( i_areset_n => i_reset_n, o_reset_n => reset_250_n, i_clk => clk_250 );
    o_reset_250_n <= reset_250_n;

    e_pcie0_reset_n : entity work.reset_sync
    port map ( i_areset_n => i_reset_n, o_reset_n => pcie0_reset_n, i_clk => pcie0_clk );
    o_pcie0_reset_n <= pcie0_reset_n;

    e_clk_125_hz : entity work.clkdiv
    generic map ( g_N => 125000000 )
    port map ( o_clk => o_clk_125_hz, i_reset_n => i_reset_125_n, i_clk => i_clk_125 );

    e_clk_156_hz : entity work.clkdiv
    generic map ( g_N => 156250000 )
    port map ( o_clk => o_clk_156_hz, i_reset_n => reset_156_n, i_clk => clk_156 );

    e_clk_250_hz : entity work.clkdiv
    generic map ( g_N => 250000000 )
    port map ( o_clk => o_clk_250_hz, i_reset_n => reset_250_n, i_clk => clk_250 );

    e_pcie0_clk_hz : entity work.clkdiv
    generic map ( g_N => 250000000 )
    port map ( o_clk => o_pcie0_clk_hz, i_reset_n => pcie0_reset_n, i_clk => pcie0_clk );

    --! save git version to version register
    local_pcie0_rregs_A(VERSION_REGISTER_R) <= GIT_HEAD_INT32(work.cmp.GIT_HEAD);

    --! generate reset regs for 250 MHz clk for pcie0
    e_reset_logic_pcie : entity work.reset_logic
    port map (
        i_reset_register    => pcie0_wregs(RESET_REGISTER_W),
        o_resets_n          => pcie0_resets_n,

        i_reset_n           => pcie0_reset_n,
        i_clk               => pcie0_clk--,
    );

    -- nios reset sequence
    e_nios_reset_n : entity work.debouncer
    generic map (
        W => 2,
        N => integer(g_CLK_MHZ * 1000000.0 * 0.250) -- 250ms
    )
    port map (
        i_d(0) => '1',           i_d(1) => flash_reset_n,
        o_q(0) => flash_reset_n, o_q(1) => nios_reset_n,

        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    -- nios
    e_nios : work.cmp.nios
    port map (
        flash_tcm_address_out           => flash_address(27 downto 0),
        flash_tcm_data_out              => io_flash_data,
        flash_tcm_read_n_out(0)         => o_flash_read_n,
        flash_tcm_write_n_out(0)        => o_flash_write_n,
        flash_tcm_chipselect_n_out(0)   => o_flash_cs_n,

        i2c_scl_in                      => nios_i2c_scl,
        i2c_scl_oe                      => nios_i2c_scl_oe,
        i2c_sda_in                      => nios_i2c_sda,
        i2c_sda_oe                      => nios_i2c_sda_oe,
        i2c_mask_export                 => nios_i2c_mask,

        spi_MISO                        => nios_spi_miso,
        spi_MOSI                        => nios_spi_mosi,
        spi_SCLK                        => nios_spi_sclk,
        spi_SS_n                        => nios_spi_ss_n,

        pio_export                      => nios_pio,

        avm_xcvr0_address               => av_xcvr0.address(17 downto 0),
        avm_xcvr0_read                  => av_xcvr0.read,
        avm_xcvr0_readdata              => av_xcvr0.readdata,
        avm_xcvr0_write                 => av_xcvr0.write,
        avm_xcvr0_writedata             => av_xcvr0.writedata,
        avm_xcvr0_waitrequest           => av_xcvr0.waitrequest,

        avm_xcvr1_address               => av_xcvr1.address(17 downto 0),
        avm_xcvr1_read                  => av_xcvr1.read,
        avm_xcvr1_readdata              => av_xcvr1.readdata,
        avm_xcvr1_write                 => av_xcvr1.write,
        avm_xcvr1_writedata             => av_xcvr1.writedata,
        avm_xcvr1_waitrequest           => av_xcvr1.waitrequest,

        avm_sfp_address                 => av_sfp.address(13 downto 0),
        avm_sfp_read                    => av_sfp.read,
        avm_sfp_readdata                => av_sfp.readdata,
        avm_sfp_write                   => av_sfp.write,
        avm_sfp_writedata               => av_sfp.writedata,
        avm_sfp_waitrequest             => av_sfp.waitrequest,

        rst_reset_n                     => nios_reset_n,
        clk_clk                         => i_clk--,
    );

    -- i2c mux
    e_i2c_mux : entity work.i2c_mux
    port map (
        io_scl      => io_i2c_scl,
        io_sda      => io_i2c_sda,

        o_scl       => nios_i2c_scl,
        i_scl_oe    => nios_i2c_scl_oe,
        o_sda       => nios_i2c_sda,
        i_sda_oe    => nios_i2c_sda_oe,

        i_mask      => nios_i2c_mask--,
    );

    -- spi mux
    o_spi_mosi <= (others => nios_spi_mosi);
    o_spi_sclk <= (others => nios_spi_sclk);
    o_spi_ss_n <= nios_spi_ss_n;
    -- TODO: implement mux

    -- xcvr_block 6250 Mbps @ 156.25 MHz
    generate_xcvr0_block : if ( g_XCVR0_CHANNELS > 0 ) generate
        signal xcvr0_tx_mux10 : std_logic_vector(i_xcvr0_tx_datak'range) := (others => '0');
        signal xcvr0_tx_data10 : slv40_array_t(i_xcvr0_tx_datak'range) := (others => (others => '0'));
        signal clock40 : std_logic_vector(39 downto 0);
        signal reset40 : std_logic_vector(39 downto 0);
        signal reset9 : std_logic_vector(8 downto 0);
        signal l_xcvr0_rx_locked : std_logic_vector(xcvr0_rx_locked'range);
    begin
        e_xcvr0_block : entity work.xcvr_block
        generic map (
            g_XCVR_N        => g_XCVR0_N,
            g_CHANNELS      => g_XCVR0_CHANNELS / g_XCVR0_N,
            g_REFCLK_MHZ    => 125.0,
            g_RATE_MBPS     => 6250,
            g_CLK_MHZ       => g_CLK_MHZ--,
        )
        port map (
            i_rx_serial         => i_xcvr0_rx,
            o_tx_serial         => o_xcvr0_tx,

            i_refclk            => i_xcvr0_refclk,

            o_rx_data           => xcvr0_rx_data,
            o_rx_datak          => xcvr0_rx_datak,

            i_tx_data           => xcvr0_tx_data,
            i_tx_datak          => xcvr0_tx_datak,

            i_tx_mux10          => xcvr0_tx_mux10,
            i_tx_data10         => xcvr0_tx_data10,

            i_tx_clk            => (others => clk_156),
            i_rx_clk            => (others => clk_156),

            o_rx_locked         => l_xcvr0_rx_locked,
            o_rx_LoL_cnt        => xcvr0_rx_LoL_cnt,
            o_rx_err_cnt        => xcvr0_rx_err_cnt,

            i_avs_address       => av_xcvr0.address(17 downto 0),
            i_avs_read          => av_xcvr0.read,
            o_avs_readdata      => av_xcvr0.readdata,
            i_avs_write         => av_xcvr0.write,
            i_avs_writedata     => av_xcvr0.writedata,
            o_avs_waitrequest   => av_xcvr0.waitrequest,

            i_reset_n           => i_reset_n,
            i_clk               => i_clk--,
        );

        e_xcvr0_rx_locked : entity work.ff_sync
        generic map ( W => xcvr0_rx_locked'length )
        port map (
            i_d => l_xcvr0_rx_locked, o_q => xcvr0_rx_locked,
            i_reset_n => pcie0_reset_n, i_clk => pcie0_clk--,
        );

        generate_mux10 : for i in g_XCVR0_N-1 downto 0 generate
            -- last channel of each xcvr is reset
            xcvr0_tx_mux10((i+1)*g_XCVR0_CHANNELS/g_XCVR0_N-1) <= work.util.to_std_logic(g_XCVR0_DEV = 1);
            xcvr0_tx_data10((i+1)*g_XCVR0_CHANNELS/g_XCVR0_N-1) <= reset40;
            -- one to last channel is clock
            xcvr0_tx_mux10((i+1)*g_XCVR0_CHANNELS/g_XCVR0_N-2) <= work.util.to_std_logic(g_XCVR0_DEV = 1);
            xcvr0_tx_data10((i+1)*g_XCVR0_CHANNELS/g_XCVR0_N-2) <= clock40;
        end generate;

        e_a10_reset_link : entity work.a10_reset_link
        port map (
            o_datak             => reset9(8),
            o_data(7 downto 0)  => reset9(7 downto 0),

            i_reset_run_number  => pcie0_wregs_B(RESET_LINK_RUN_NUMBER_REGISTER_W),
            i_reset_ctl         => pcie0_wregs_B(RESET_LINK_CTL_REGISTER_W),

            o_state_out         => local_pcie0_rregs_B(RESET_LINK_STATUS_REGISTER_R),

            i_reset_n           => reset_156_n,
            i_clk               => clk_156--,
        );

        e_reset_clock_gen : entity work.reset_clock_gen
        port map (
            i_reset9        => reset9,
            o_reset40       => reset40,

            o_clock40       => clock40,

            i_reset_156_n   => reset_156_n,
            i_clk_156       => clk_156--,
        );

    end generate;

    generate_xcvr0_fifo : for i in g_XCVR0_CHANNELS-1 downto 0 generate
        e_xcvr0_fifo : entity work.xcvr_fifo
        port map (
            -- map logical channel rx(i) to physical channel g_XCVR0_RX_P(i)
            i_xcvr_rx_data      => xcvr0_rx_data(work.util.map_index(i, g_XCVR0_RX_P)),
            i_xcvr_rx_datak     => xcvr0_rx_datak(work.util.map_index(i, g_XCVR0_RX_P)),
            o_xcvr_tx_data      => xcvr0_tx_data(work.util.map_index(i, g_XCVR0_TX_P)),
            o_xcvr_tx_datak     => xcvr0_tx_datak(work.util.map_index(i, g_XCVR0_TX_P)),
            i_xcvr_clk          => clk_156,

            o_rx_data           => o_xcvr0_rx_data(i),
            o_rx_datak          => o_xcvr0_rx_datak(i),
            i_tx_data           => i_xcvr0_tx_data(i),
            i_tx_datak          => i_xcvr0_tx_datak(i),
            i_clk               => i_xcvr0_clk,

            i_reset_n           => reset_156_n--,
        );
    end generate;

    --! check locks for links
    process(pcie0_clk, pcie0_resets_n(RESET_BIT_LINK_LOCKED))
        variable locked_in : std_logic_vector(63 downto 0);
        variable xcvr_ctrl_ch : integer;
    begin
    if rising_edge(pcie0_clk) then
        locked_in := (others => '0');
        for i in g_XCVR0_CHANNELS-1 downto 0 loop
            locked_in(i) := xcvr0_rx_locked(work.util.map_index(i, g_XCVR0_RX_P));
        end loop;
        for i in g_XCVR1_CHANNELS-1 downto 0 loop
            locked_in(g_XCVR0_CHANNELS+i) := xcvr1_rx_locked(work.util.map_index(i, g_XCVR1_RX_P));
        end loop;
        local_pcie0_rregs_A(LINK_LOCKED_LOW_REGISTER_R) <= locked_in(31 downto 0);
        local_pcie0_rregs_A(LINK_LOCKED_HIGH_REGISTER_R) <= locked_in(63 downto 32);

        local_pcie0_rregs_A(XCVR_CTRL_REGISTER_R) <= xcvr_ctrl_r;
        xcvr_ctrl_w <= pcie0_wregs(XCVR_CTRL_REGISTER_W);
        xcvr_ctrl_r <= (others => '0');
        xcvr_ctrl_ch := to_integer(unsigned(xcvr_ctrl_w(XCVR_CTRL_CH_RANGE)));
        if ( xcvr_ctrl_ch < g_XCVR0_CHANNELS ) then
            if ( xcvr_ctrl_w(XCVR_CTRL_REG_RANGE) = 0 ) then
                xcvr_ctrl_r(7 downto 0) <= xcvr0_rx_LoL_cnt(xcvr_ctrl_ch);
            end if;
            if ( xcvr_ctrl_w(XCVR_CTRL_REG_RANGE) = 1 ) then
                xcvr_ctrl_r(15 downto 0) <= xcvr0_rx_err_cnt(xcvr_ctrl_ch);
            end if;
        elsif ( xcvr_ctrl_ch < g_XCVR0_CHANNELS + g_XCVR1_CHANNELS ) then
            xcvr_ctrl_ch := xcvr_ctrl_ch - g_XCVR0_CHANNELS;
            if ( xcvr_ctrl_w(XCVR_CTRL_REG_RANGE) = 0 ) then
                xcvr_ctrl_r(7 downto 0) <= xcvr1_rx_LoL_cnt(xcvr_ctrl_ch);
            end if;
            if ( xcvr_ctrl_w(XCVR_CTRL_REG_RANGE) = 1 ) then
                xcvr_ctrl_r(15 downto 0) <= xcvr1_rx_err_cnt(xcvr_ctrl_ch);
            end if;
        end if;

    end if;
    end process;

    -- xcvr_block 10000 Mbps @ 250 MHz
    generate_xcvr1_block : if ( g_XCVR1_CHANNELS > 0 ) generate
        signal l_xcvr1_rx_locked : std_logic_vector(xcvr1_rx_locked'range);
    begin
        e_xcvr1_block : entity work.xcvr_block
        generic map (
            g_MODE          => "enh",
            g_XCVR_N        => g_XCVR1_N,
            g_CHANNELS      => g_XCVR1_CHANNELS / g_XCVR1_N,
            g_REFCLK_MHZ    => 125.0,
            g_RATE_MBPS     => 10000,
            g_CLK_MHZ       => g_CLK_MHZ--,
        )
        port map (
            o_rx_data           => xcvr1_rx_data,
            o_rx_datak          => xcvr1_rx_datak,

            i_tx_data           => xcvr1_tx_data,
            i_tx_datak          => xcvr1_tx_datak,

            i_rx_clk            => (others => clk_250),
            i_tx_clk            => (others => clk_250),

            i_rx_serial         => i_xcvr1_rx,
            o_tx_serial         => o_xcvr1_tx,

            i_refclk            => i_xcvr1_refclk,

            o_rx_locked         => l_xcvr1_rx_locked,
            o_rx_LoL_cnt        => xcvr1_rx_LoL_cnt,
            o_rx_err_cnt        => xcvr1_rx_err_cnt,

            i_avs_address       => av_xcvr1.address(17 downto 0),
            i_avs_read          => av_xcvr1.read,
            o_avs_readdata      => av_xcvr1.readdata,
            i_avs_write         => av_xcvr1.write,
            i_avs_writedata     => av_xcvr1.writedata,
            o_avs_waitrequest   => av_xcvr1.waitrequest,

            i_reset_n           => i_reset_n,
            i_clk               => i_clk--,
        );

        e_xcvr1_rx_locked : entity work.ff_sync
        generic map ( W => xcvr1_rx_locked'length )
        port map (
            i_d => l_xcvr1_rx_locked, o_q => xcvr1_rx_locked,
            i_reset_n => pcie0_reset_n, i_clk => pcie0_clk--,
        );
    end generate;

    generate_xcvr1_fifo : for i in g_XCVR1_CHANNELS-1 downto 0 generate
        e_xcvr1_fifo : entity work.xcvr_fifo
        port map (
            i_xcvr_rx_data      => xcvr1_rx_data(work.util.map_index(i, g_XCVR1_RX_P)),
            i_xcvr_rx_datak     => xcvr1_rx_datak(work.util.map_index(i, g_XCVR1_RX_P)),
            o_xcvr_tx_data      => xcvr1_tx_data(work.util.map_index(i, g_XCVR1_TX_P)),
            o_xcvr_tx_datak     => xcvr1_tx_datak(work.util.map_index(i, g_XCVR1_TX_P)),
            i_xcvr_clk          => clk_250,

            o_rx_data           => o_xcvr1_rx_data(i),
            o_rx_datak          => o_xcvr1_rx_datak(i),
            i_tx_data           => i_xcvr1_tx_data(i),
            i_tx_datak          => i_xcvr1_tx_datak(i),
            i_clk               => i_xcvr1_clk,

            i_reset_n           => reset_250_n--,
        );
    end generate;

    generate_sfp_block : if ( g_SFP_CHANNELS > 0 ) generate
        e_xcvr_sfp : entity work.xcvr_enh
        generic map (
            g_CHANNELS      => g_SFP_CHANNELS,
            g_BYTES         => 1,
            g_REFCLK_MHZ    => 125.0,
            g_RATE_MBPS     => 1250,
            g_CLK_MHZ       => g_CLK_MHZ--,
        )
        port map (
            i_rx_serial => i_sfp_rx,
            o_tx_serial => o_sfp_tx,

            i_refclk => i_sfp_refclk,

            i_tx_data => X"BC" & X"BC",
            i_tx_datak => "1" & "1",

            i_rx_clkin => (others => i_clk_125),
            i_tx_clkin => (others => i_clk_125),

            i_avs_address       => av_sfp.address(13 downto 0),
            i_avs_read          => av_sfp.read,
            o_avs_readdata      => av_sfp.readdata,
            i_avs_write         => av_sfp.write,
            i_avs_writedata     => av_sfp.writedata,
            o_avs_waitrequest   => av_sfp.waitrequest,

            i_reset_n => i_reset_n,
            i_clk => i_clk--,
        );
    end generate;

    --! PCIe register mapping
    e_register_mapping : entity work.pcie_register_mapping
    generic map (
        g_FARM => g_FARM--,
    )
    port map (
        i_pcie0_rregs_A         => i_pcie0_rregs,

        i_local_pcie0_rregs_A   => local_pcie0_rregs_A,
        i_local_pcie0_rregs_B   => local_pcie0_rregs_B,

        o_pcie0_rregs           => pcie0_rregs,

        i_reset_n               => pcie0_reset_n,

        i_clk_A                 => pcie0_clk,
        i_clk_B                 => clk_156--,
    );

    -- PCIe0
    generate_pcie0 : if ( g_PCIE0_X > 0 ) generate
        e_pcie0_block : entity work.pcie_block
        generic map (
            g_DMA_WADDR_WIDTH => 11,
            g_DMA_RADDR_WIDTH => 11,
            g_DMA_DATA_WIDTH => 256,
            g_PCIE_X => g_PCIE0_X--,
        )
        port map (
            pcie_rx_p               => i_pcie0_rx,
            pcie_tx_p               => o_pcie0_tx,
            i_pcie_perst_n          => i_pcie0_perst_n,
            i_pcie_refclk           => i_pcie0_refclk,

            readregs                => pcie0_rregs,
            writeregs               => pcie0_wregs,
            regwritten              => o_pcie0_regwritten,

            i_clk_B                 => clk_156,
            o_writeregs_B           => pcie0_wregs_B,
            o_regwritten_B          => open,

            writememreadaddr        => i_pcie0_wmem_addr,
            writememreaddata        => o_pcie0_wmem_rdata,
            writememclk             => pcie0_clk,

            readmem_addr            => i_pcie0_rmem_addr,
            readmem_data            => i_pcie0_rmem_wdata,
            readmem_wren            => i_pcie0_rmem_we,
            readmemclk              => pcie0_clk,
            readmem_endofevent      => '0',

            dma_data                => i_pcie0_dma0_wdata,
            dmamem_wren             => i_pcie0_dma0_we,
            dmamem_endofevent       => i_pcie0_dma0_eoe,
            dmamemhalffull          => pcie0_dma0_hfull,
            dmamemclk               => pcie0_clk,

            dma2memclk              => pcie0_clk,

            i_areset_n              => '1',
            o_clk                   => pcie0_clk--,
        );
    end generate;

    --! DMA evaluationg / monitoring for PCIe 0
    e_dma_evaluation_pcie0 : entity work.dma_evaluation
    port map (
        i_dmamemhalffull            => pcie0_dma0_hfull,
        i_dmamem_endofevent         => i_pcie0_dma0_eoe,

        o_halffull_counter          => local_pcie0_rregs_A(DMA_HALFFUL_REGISTER_R),
        o_nothalffull_counter       => local_pcie0_rregs_A(DMA_NOTHALFFUL_REGISTER_R),
        o_endofevent_counter        => local_pcie0_rregs_A(DMA_ENDEVENT_REGISTER_R),
        o_notendofevent_counter     => local_pcie0_rregs_A(DMA_NOTENDEVENT_REGISTER_R),

        i_reset_n                   => pcie0_resets_n(RESET_BIT_DMA_EVAL),
        i_clk                       => pcie0_clk--,
    );
    local_pcie0_rregs_A(DMA_STATUS_R)(DMA_DATA_WEN) <= i_pcie0_dma0_we;

end architecture;
