-----------------------------------------------------------------------------
-- Wrapper for the PCIe interface
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity pcie_block is
generic (
    g_DMA_WADDR_WIDTH : positive := 14;
    g_DMA_RADDR_WIDTH : positive := 12;
    g_DMA_DATA_WIDTH : positive := 32;
    g_PCIE_X : positive := 8--;
);
port (
    o_writeregs_B       : out   reg32array_pcie;
    o_regwritten_B      : out   std_logic_vector(63 downto 0);
    i_clk_B             : in    std_logic := '0';

    -- PCIe
    pcie_rx_p           : in    std_logic_vector(g_PCIE_X-1 downto 0);
    pcie_tx_p           : out   std_logic_vector(g_PCIE_X-1 downto 0);
    i_pcie_smbclk       : in    std_logic := '1';
    io_pcie_smbdat      : inout std_logic;
    pcie_waken          : out   std_logic; --//PCIe Wake-Up (TR=0)
    -- perst indicates when the power supply
    -- is within specified voltage tolerance and is stable
    i_pcie_perst_n      : in    std_logic;
    -- 100 MHz reference clock defined by the PCIe specification
    -- (provided via PCIe connector on MB)
    i_pcie_refclk       : in    std_logic;

    pcie_led_x1         : out   std_logic;
    pcie_led_x4         : out   std_logic;
    pcie_led_x8         : out   std_logic;

    -- pcie registers
    writeregs           : out   reg32array_pcie;
    regwritten          : out   std_logic_vector(63 downto 0);
    readregs            : in    reg32array_pcie;

    -- pcie writeable memory
    writememclk         : in    std_logic;
    writememreadaddr    : in    std_logic_vector(15 downto 0) := (others => '0');
    writememreaddata    : out   std_logic_vector(31 downto 0);

    -- pcie readable memory
    readmem_data        : in    std_logic_vector(31 downto 0) := (others => '0');
    readmem_addr        : in    std_logic_vector(15 downto 0) := (others => '0');
    readmemclk          : in    std_logic;
    readmem_wren        : in    std_logic := '0';
    readmem_endofevent  : in    std_logic := '0';

    -- dma memory
    dma_data            : in    std_logic_vector(g_DMA_DATA_WIDTH-1 downto 0) := (others => '0');
    dmamemclk           : in    std_logic;
    dmamem_wren         : in    std_logic := '0';
    dmamem_endofevent   : in    std_logic := '0';
    dmamemhalffull      : out   std_logic;

    -- second dma memory
    dma2_data           : in    std_logic_vector(g_DMA_DATA_WIDTH-1 downto 0) := (others => '0');
    dma2memclk          : in    std_logic;
    dma2mem_wren        : in    std_logic := '0';
    dma2mem_endofevent  : in    std_logic := '0';
    dma2memhalffull     : out   std_logic;

    -- test ports
    testout             : out   std_logic_vector(127 downto 0);
    inaddr32_r          : out   std_logic_vector(31 downto 0);
    inaddr32_w          : out   std_logic_vector(31 downto 0);

    -- data async reset
    i_areset_n          : in    std_logic;
    -- data clock (250 MHz)
    o_clk               : out   std_logic--;
);
end entity;

architecture RTL of pcie_block is

    -- reset and clock stuff
    signal pld_clk              : std_logic;
    signal pld_reset_n          : std_logic;
    signal reset_n              : std_logic;

    signal coreclkout_hip       : std_logic;

    -- Receiver IF
    signal rx_mask0             : std_logic;
    signal rx_st_bardec0        : std_logic_vector(7 downto 0);
    signal rx_st                : work.util.avst256_t;
    signal rx_st_ready0         : std_logic;

    -- Transmitter IF

    signal tx_st                : work.util.avst256_t;
    signal tx_st_ready0         : std_logic;

    -- Interrupt stuff
    signal app_int_ack          : std_logic;
    signal app_int_sts          : std_logic;
    signal app_msi_ack          : std_logic;
    signal app_msi_num          : std_logic_vector(4 downto 0);
    signal app_msi_req          : std_logic;
    signal app_msi_tc           : std_logic_vector(2 downto 0);

    -- Completion stuff
    signal cpl_err_icm          : std_logic_vector(6 downto 0);
    signal cpl_pending          : std_logic;

    -- Power mamangement
    signal pme_to_sr            : std_logic;

    -- Configuration space
    signal tl_cfg_add           : std_logic_vector(3 downto 0);
    signal tl_cfg_ctl           : std_logic_vector(31 downto 0);
    signal tl_cfg_ctl_wr        : std_logic;
    signal tl_cfg_sts           : std_logic_vector(52 downto 0);
    signal tl_cfg_sts_wr        : std_logic;


    -- Config registers decoded
    signal cfg_busdev_icm       : std_logic_vector(12 downto 0);
    signal cfg_msicsr           : std_logic_vector(15 downto 0);

    -- Reset and link status
    signal dlup                 : std_logic;
    signal dlup_exit            : std_logic;
    signal hotrst_exit          : std_logic;
    signal l2_exit              : std_logic;
    signal currentspeed         : std_logic_vector(1 downto 0);
    signal lane_act             : std_logic_vector(3 downto 0);
    signal serdes_pll_locked    : std_logic;

    -- DMA
    signal dma_data_reg, dma2_data_reg : std_logic_vector(g_DMA_DATA_WIDTH-1 downto 0) := (others => '0');
    signal dmamem_wren_reg, dma2mem_wren_reg : std_logic := '0';
    signal dmamem_endofevent_reg, dma2mem_endofevent_reg : std_logic := '0';

    signal testbus              : std_logic_vector(127 downto 0);

begin

    -- "Avalon-MM Interface for PCIe User Guide / 7.2.1.2. pld_clk"
    -- | coreclkout_hip can drive the Application Layer clock along with the pld_clk input to the IP core.
    -- | The pld_clk can optionally be sourced by a different clock than coreclkout_hip.
    -- | The pld_clk minimum frequency cannot be lower than the coreclkout_hip frequency.
    --
    -- [AK] NOTE:
    -- assign pld_clock and o_clk at the same simulation step
    -- to avoid timing difference in registers driven by these clocks
    pld_clk <= coreclkout_hip;
    o_clk <= coreclkout_hip;

    -- SIMULATION: generate PCIe Application clock
    generate_simulation : if work.util.SIMULATION generate
        coreclkout_hip <= not pld_clk after (0.5 us / 10000);
    end generate;

    -- [AK] TODO: use reset_sync
    pld_reset_n <= i_pcie_perst_n;

    -- [AK] TODO: use reset_sync
    reset_n <= i_areset_n;

    cpl_pending <= '0';

    pcie_led_x1 <= lane_act(0);
    pcie_led_x4 <= lane_act(2);
    pcie_led_x8 <= lane_act(3);

    io_pcie_smbdat <= 'Z';

    generate_ip_pcie_x8_256 : if ( g_PCIE_X = 8 ) generate
        -- synthesis read_comments_as_HDL on
        --e_pcie_x8_256 : component work.cmp.ip_pcie_x8_256
        --port map (
        --    clr_st              => open,
        --    hpg_ctrler          => (others => '0'),
        --    tl_cfg_add          => tl_cfg_add,
        --    tl_cfg_ctl          => tl_cfg_ctl,
        --    tl_cfg_sts          => tl_cfg_sts,
        --    cpl_err             => cpl_err_icm,
        --    cpl_pending         => cpl_pending,
        --    coreclkout_hip      => coreclkout_hip,
        --    currentspeed        => currentspeed,
        --    pld_core_ready      => serdes_pll_locked,
        --    pld_clk_inuse       => open,
        --    serdes_pll_locked   => serdes_pll_locked,
        --    reset_status        => open,
        --    testin_zero         => open,
        --    rx_in0              => pcie_rx_p(0),
        --    rx_in1              => pcie_rx_p(1),
        --    rx_in2              => pcie_rx_p(2),
        --    rx_in3              => pcie_rx_p(3),
        --    rx_in4              => pcie_rx_p(4),
        --    rx_in5              => pcie_rx_p(5),
        --    rx_in6              => pcie_rx_p(6),
        --    rx_in7              => pcie_rx_p(7),
        --    tx_out0             => pcie_tx_p(0),
        --    tx_out1             => pcie_tx_p(1),
        --    tx_out2             => pcie_tx_p(2),
        --    tx_out3             => pcie_tx_p(3),
        --    tx_out4             => pcie_tx_p(4),
        --    tx_out5             => pcie_tx_p(5),
        --    tx_out6             => pcie_tx_p(6),
        --    tx_out7             => pcie_tx_p(7),
        --    derr_cor_ext_rcv    => open,
        --    derr_cor_ext_rpl    => open,
        --    derr_rpl            => open,
        --    dlup                => dlup,
        --    dlup_exit           => dlup_exit,
        --    ev128ns             => open,
        --    ev1us               => open,
        --    hotrst_exit         => hotrst_exit,
        --    int_status          => open,
        --    l2_exit             => l2_exit,
        --    lane_act            => lane_act,
        --    ltssmstate          => open,
        --    rx_par_err          => open,
        --    tx_par_err          => open,
        --    cfg_par_err         => open,
        --    ko_cpl_spc_header   => open,
        --    ko_cpl_spc_data     => open,
        --    app_int_sts         => app_int_sts,
        --    app_int_ack         => app_int_ack,
        --    app_msi_num         => app_msi_num,
        --    app_msi_req         => app_msi_req,
        --    app_msi_tc          => app_msi_tc,
        --    app_msi_ack         => app_msi_ack,
        --    npor                => i_pcie_perst_n,
        --    pin_perst           => i_pcie_perst_n,
        --    pld_clk             => pld_clk,
        --    pm_auxpwr           => '0',
        --    pm_data             => (others => '0'),
        --    pme_to_cr           => pme_to_sr,
        --    pm_event            => '0',
        --    pme_to_sr           => pme_to_sr,
        --    refclk              => i_pcie_refclk,
        --    rx_st_bar           => rx_st_bardec0,
        --    rx_st_mask          => rx_mask0,
        --    rx_st_sop(0)        => rx_st.sop,
        --    rx_st_eop(0)        => rx_st.eop,
        --    rx_st_err(0)        => rx_st.err,
        --    rx_st_valid(0)      => rx_st.valid,
        --    rx_st_ready         => rx_st_ready0,
        --    rx_st_data          => rx_st.data,
        --    rx_st_empty         => rx_st.empty,
        --    tx_cred_data_fc     => open,
        --    tx_cred_fc_hip_cons => open,
        --    tx_cred_fc_infinite => open,
        --    tx_cred_hdr_fc      => open,
        --    tx_cred_fc_sel      => (others => '0'),
        --    tx_st_sop(0)        => tx_st.sop,
        --    tx_st_eop(0)        => tx_st.eop,
        --    tx_st_err(0)        => tx_st.err,
        --    tx_st_valid(0)      => tx_st.valid,
        --    tx_st_ready         => tx_st_ready0,
        --    tx_st_data          => tx_st.data,
        --    tx_st_empty         => tx_st.empty,
        --    test_in             => X"00000188",
        --    simu_mode_pipe      => '0'
        --);
        -- synthesis read_comments_as_HDL off
    end generate;

    generate_ip_pcie_x4_256 : if ( g_PCIE_X = 4 ) generate
        -- synthesis read_comments_as_HDL on
        --e_pcie_x4_256 : component work.cmp.ip_pcie_x4_256
        --port map (
        --    clr_st              => open,
        --    hpg_ctrler          => (others => '0'),
        --    tl_cfg_add          => tl_cfg_add,
        --    tl_cfg_ctl          => tl_cfg_ctl,
        --    tl_cfg_sts          => tl_cfg_sts,
        --    cpl_err             => cpl_err_icm,
        --    cpl_pending         => cpl_pending,
        --    coreclkout_hip      => coreclkout_hip,
        --    currentspeed        => currentspeed,
        --    pld_core_ready      => serdes_pll_locked,
        --    pld_clk_inuse       => open,
        --    serdes_pll_locked   => serdes_pll_locked,
        --    reset_status        => open,
        --    testin_zero         => open,
        --    rx_in0              => pcie_rx_p(0),
        --    rx_in1              => pcie_rx_p(1),
        --    rx_in2              => pcie_rx_p(2),
        --    rx_in3              => pcie_rx_p(3),
        --    tx_out0             => pcie_tx_p(0),
        --    tx_out1             => pcie_tx_p(1),
        --    tx_out2             => pcie_tx_p(2),
        --    tx_out3             => pcie_tx_p(3),
        --    derr_cor_ext_rcv    => open,
        --    derr_cor_ext_rpl    => open,
        --    derr_rpl            => open,
        --    dlup                => dlup,
        --    dlup_exit           => dlup_exit,
        --    ev128ns             => open,
        --    ev1us               => open,
        --    hotrst_exit         => hotrst_exit,
        --    int_status          => open,
        --    l2_exit             => l2_exit,
        --    lane_act            => lane_act,
        --    ltssmstate          => open,
        --    rx_par_err          => open,
        --    tx_par_err          => open,
        --    cfg_par_err         => open,
        --    ko_cpl_spc_header   => open,
        --    ko_cpl_spc_data     => open,
        --    app_int_sts         => app_int_sts,
        --    app_int_ack         => app_int_ack,
        --    app_msi_num         => app_msi_num,
        --    app_msi_req         => app_msi_req,
        --    app_msi_tc          => app_msi_tc,
        --    app_msi_ack         => app_msi_ack,
        --    npor                => i_pcie_perst_n,
        --    pin_perst           => i_pcie_perst_n,
        --    pld_clk             => pld_clk,
        --    pm_auxpwr           => '0',
        --    pm_data             => (others => '0'),
        --    pme_to_cr           => pme_to_sr,
        --    pm_event            => '0',
        --    pme_to_sr           => pme_to_sr,
        --    refclk              => i_pcie_refclk,
        --    rx_st_bar           => rx_st_bardec0,
        --    rx_st_mask          => rx_mask0,
        --    rx_st_sop(0)        => rx_st.sop,
        --    rx_st_eop(0)        => rx_st.eop,
        --    rx_st_err(0)        => rx_st.err,
        --    rx_st_valid(0)      => rx_st.valid,
        --    rx_st_ready         => rx_st_ready0,
        --    rx_st_data          => rx_st.data,
        --    rx_st_empty         => rx_st.empty,
        --    tx_cred_data_fc     => open,
        --    tx_cred_fc_hip_cons => open,
        --    tx_cred_fc_infinite => open,
        --    tx_cred_hdr_fc      => open,
        --    tx_cred_fc_sel      => (others => '0'),
        --    tx_st_sop(0)        => tx_st.sop,
        --    tx_st_eop(0)        => tx_st.eop,
        --    tx_st_err(0)        => tx_st.err,
        --    tx_st_valid(0)      => tx_st.valid,
        --    tx_st_ready         => tx_st_ready0,
        --    tx_st_data          => tx_st.data,
        --    tx_st_empty         => tx_st.empty,
        --    test_in             => X"00000188",
        --    simu_mode_pipe      => '0'
        --);
        -- synthesis read_comments_as_HDL off
    end generate;

    -- Configuration bus decode
    e_cfgbus : entity work.pcie_cfgbus
    port map (
        tl_cfg_add      => tl_cfg_add,
        tl_cfg_ctl      => tl_cfg_ctl,

        cfg_busdev      => cfg_busdev_icm,
        cfg_dev_ctrl    => open,
        cfg_slot_ctrl   => open,
        cfg_link_ctrl   => open,
        cfg_prm_cmd     => open,
        cfg_msi_addr    => open,
        cfg_pmcsr       => open,
        cfg_msixcsr     => open,
        cfg_msicsr      => open,
        tx_ercgen       => open,
        rx_errcheck     => open,
        cfg_tcvcmap     => open,
        cfg_msi_data    => open,

        i_reset_n       => pld_reset_n,
        i_clk           => pld_clk--,
    );

    process(dmamemclk, i_areset_n)
    begin
    if ( i_areset_n /= '1' ) then
        dma_data_reg            <= (others => '0');
        dmamem_wren_reg         <= '0';
        dmamem_endofevent_reg   <= '0';

        dma2_data_reg           <= (others => '0');
        dma2mem_wren_reg        <= '0';
        dma2mem_endofevent_reg  <= '0';
    elsif rising_edge(dmamemclk) then
        dma_data_reg            <= dma_data;
        dmamem_wren_reg         <= dmamem_wren;
        dmamem_endofevent_reg   <= dmamem_endofevent;

        dma2_data_reg           <= dma2_data;
        dma2mem_wren_reg        <= dma2mem_wren;
        dma2mem_endofevent_reg  <= dma2mem_endofevent;
    end if;
    end process;

    e_pcie_application : entity work.pcie_application
    generic map (
        g_DMA_WADDR_WIDTH => g_DMA_WADDR_WIDTH,
        g_DMA_RADDR_WIDTH => g_DMA_RADDR_WIDTH,
        g_DMA_DATA_WIDTH => g_DMA_DATA_WIDTH--,
    )
    port map (
        o_writeregs_B       => o_writeregs_B,
        o_regwritten_B      => o_regwritten_B,
        i_clk_B             => i_clk_B,

        -- to IF
        o_tx_st             => tx_st,
        i_tx_st_ready0      => tx_st_ready0,

        -- from Config
        completer_id        => cfg_busdev_icm,

        -- from IF
        i_rx_st             => rx_st,
        rx_st_ready0        => rx_st_ready0,
        rx_bar0             => rx_st_bardec0,

        -- Interrupt stuff
        app_msi_req         => app_msi_req,
        app_msi_tc          => app_msi_tc,
        app_msi_num         => app_msi_num,
        app_msi_ack         => app_msi_ack,

        -- registers
        writeregs           => writeregs,
        regwritten          => regwritten,
        readregs            => readregs,

        -- pcie writeable memory
        writememclk         => writememclk,
        writememreadaddr    => writememreadaddr,
        writememreaddata    => writememreaddata,

        -- pcie readable memory
        readmem_data        => readmem_data,
        readmem_addr        => readmem_addr,
        readmemclk          => readmemclk,
        readmem_wren        => readmem_wren,
        readmem_endofevent  => readmem_endofevent,

        -- dma memory
        dma_data            => dma_data_reg,
        dmamemclk           => dmamemclk,
        dmamem_wren         => dmamem_wren_reg,
        dmamem_endofevent   => dmamem_endofevent_reg,
        dmamemhalffull      => dmamemhalffull,

        -- 2nd dma memory
        dma2_data           => dma2_data_reg,
        dma2memclk          => dma2memclk,
        dma2mem_wren        => dma2mem_wren_reg,
        dma2mem_endofevent  => dma2mem_endofevent_reg,
        dma2memhalffull     => dma2memhalffull,

        -- test ports
        testout             => testout,
        testin              => testbus,
        inaddr32_r          => inaddr32_r,
        inaddr32_w          => inaddr32_w,

        i_reset_n           => reset_n,
        i_clk               => pld_clk--,
    );

end architecture;
