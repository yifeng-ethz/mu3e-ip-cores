-----------------------------------------------------------------------------
-- PCIe application block, handles all the pcie stuff not handled by the IP core
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-----------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;

entity pcie_application is
generic (
    g_DMA_WADDR_WIDTH : positive := 14;
    g_DMA_RADDR_WIDTH : positive := 12;
    g_DMA_DATA_WIDTH : positive := 32--;
);
port (
    o_writeregs_B           : out   reg32array_pcie;
    o_regwritten_B          : out   std_logic_vector(63 downto 0);
    i_clk_B                 : in    std_logic := '0';

    -- to IF
    o_tx_st                 : out   work.util.avst256_t;
    i_tx_st_ready0          : in    std_logic;

    -- from Config
    completer_id            : in    std_logic_vector(12 downto 0);

    -- from IF
    i_rx_st                 : in    work.util.avst256_t;
    rx_st_ready0            : out   std_logic;
    rx_bar0                 : in    std_logic_vector(7 downto 0);

    -- Interrupt stuff
    app_msi_req             : out   std_logic;
    app_msi_tc              : out   std_logic_vector(2 downto 0);
    app_msi_num             : out   std_logic_vector(4 downto 0);
    app_msi_ack             : in    std_logic;

    -- registers
    writeregs               : out   reg32array_pcie;
    regwritten              : out   std_logic_vector(63 downto 0);
    readregs                : in    reg32array_pcie;

    -- pcie writeable memory
    writememclk             : in    std_logic;
    writememreadaddr        : in    std_logic_vector(15 downto 0);
    writememreaddata        : out   std_logic_vector(31 downto 0);

    -- pcie readable memory
    readmem_data            : in    std_logic_vector(31 downto 0);
    readmem_addr            : in    std_logic_vector(15 downto 0);
    readmemclk              : in    std_logic;
    readmem_wren            : in    std_logic;
    readmem_endofevent      : in    std_logic;

    -- dma memory
    dma_data                : in    std_logic_vector(g_DMA_DATA_WIDTH-1 downto 0);
    dmamemclk               : in    std_logic;
    dmamem_wren             : in    std_logic;
    dmamem_endofevent       : in    std_logic;
    dmamemhalffull          : out   std_logic;

    -- second dma memory
    dma2_data               : in    std_logic_vector(g_DMA_DATA_WIDTH-1 downto 0);
    dma2memclk              : in    std_logic;
    dma2mem_wren            : in    std_logic;
    dma2mem_endofevent      : in    std_logic;
    dma2memhalffull         : out   std_logic;

    -- test ports
    testout                 : out   std_logic_vector(127 downto 0);
    testin                  : in    std_logic_vector(127 downto 0);
    inaddr32_r              : out   std_logic_vector(31 downto 0);
    inaddr32_w              : out   std_logic_vector(31 downto 0);

    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture RTL of pcie_application is

    signal wreg_reset_n, rreg_reset_n : std_logic;
    signal wmem_reset_n, rmem_reset_n : std_logic;
    signal dma1_reset_n, dma2_reset_n : std_logic;
    signal comp_reset_n : std_logic;

    -- from register read part
    signal rreg_readaddr            : std_logic_vector(5 downto 0);
    signal rreg_readlength          : std_logic_vector(9 downto 0);
    signal rreg_header2             : std_logic_vector(31 downto 0);
    signal rreg_readen              : std_logic;

    -- from register write part
    signal wreg_readaddr            : std_logic_vector(5 downto 0);
    signal wreg_readlength          : std_logic_vector(9 downto 0);
    signal wreg_header2             : std_logic_vector(31 downto 0);
    signal wreg_readen              : std_logic;

    -- from memory read part
    signal rmem_readaddr            : std_logic_vector(15 downto 0);
    signal rmem_readlength          : std_logic_vector(9 downto 0);
    signal rmem_header2             : std_logic_vector(31 downto 0);
    signal rmem_header2_reg         : std_logic_vector(31 downto 0);
    signal rmem_readen              : std_logic;

    -- from memory write part
    signal wmem_readaddr            : std_logic_vector(15 downto 0);
    signal wmem_readlength          : std_logic_vector(9 downto 0);
    signal wmem_header2             : std_logic_vector(31 downto 0);
    signal wmem_readen              : std_logic;

    signal rx_st_ready_rreg         : std_logic;
    signal rx_st_ready_wreg         : std_logic;

    signal rx_st_ready_rmem         : std_logic;
    signal rx_st_ready_wmem         : std_logic;

    -- registers
    signal writeregs_s              : reg32array_pcie;
    signal regwritten_s             : std_logic_vector(63 downto 0);
    signal readregs_s               : reg32array_pcie;
    signal readregs_int             : reg32array_pcie;

    signal writememaddr             : std_logic_vector(15 downto 0);
    signal writememaddr_r           : std_logic_vector(15 downto 0);
    signal writememaddr_w           : std_logic_vector(15 downto 0);
    signal writememdata             : std_logic_vector(31 downto 0);
    signal writememwren             : std_logic;
    signal writememq                : std_logic_vector(31 downto 0);


    signal readmem_readaddr         : std_logic_vector(13 downto 0);
    signal readmem_readdata         : std_logic_vector(127 downto 0);


    -- dma
    signal dma_request              : std_logic;
    signal dma_granted              : std_logic;
    signal dma_done                 : std_logic;
    signal dma2_request             : std_logic;
    signal dma2_granted             : std_logic;
    signal dma2_done                : std_logic;

    signal dma_tx_ready             : std_logic;
    signal dma_tx                   : work.util.avst256_t;

    signal dma2_tx_ready            : std_logic;
    signal dma2_tx                  : work.util.avst256_t;

    signal dma_control_address      : std_logic_vector(63 downto 0);
    signal dma2_control_address     : std_logic_vector(63 downto 0);
    signal dma_data_address         : std_logic_vector(63 downto 0);
    signal dma_data_address_out     : std_logic_vector(63 downto 0);
    signal dma2_data_address_out    : std_logic_vector(63 downto 0);
    signal dma_data_mem_addr        : std_logic_vector(11 downto 0);
    signal dma_data_pages           : std_logic_vector(19 downto 0);
    signal dma_data_pages_out       : std_logic_vector(19 downto 0);
    signal dma2_data_pages_out      : std_logic_vector(19 downto 0);
    signal dma_data_n_addrs         : std_logic_vector(11 downto 0);
    signal dma2_data_n_addrs        : std_logic_vector(11 downto 0);
    signal dma_write_config         : std_logic;
    signal dma2_write_config        : std_logic;

    signal app1_msi_req             : std_logic;
    signal app1_msi_tc              : std_logic_vector(2 downto 0);
    signal app1_msi_num             : std_logic_vector(4 downto 0);
    signal app1_msi_ack             : std_logic;

    signal app2_msi_req             : std_logic;
    signal app2_msi_tc              : std_logic_vector(2 downto 0);
    signal app2_msi_num             : std_logic_vector(4 downto 0);
    signal app2_msi_ack             : std_logic;

    signal testout_completer        : std_logic_vector(127 downto 0);
    signal testout_dma              : std_logic_vector(71 downto 0);

begin

    -- regenerate resets
    e_reset_n : entity work.ff_sync
    generic map ( W => 7 )
    port map (
        o_q(0) => wreg_reset_n,
        o_q(1) => rreg_reset_n,
        o_q(2) => wmem_reset_n,
        o_q(3) => rmem_reset_n,
        o_q(4) => dma1_reset_n,
        o_q(5) => dma2_reset_n,
        o_q(6) => comp_reset_n,
        i_d => (others => '1'),
        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    writeregs <= writeregs_s;
    regwritten <= regwritten_s;
    readregs_s(63 downto 56) <= readregs_int(63 downto 56);
    readregs_s(55 downto 0) <= readregs(55 downto 0);

    rx_st_ready0 <=
        '1' when rx_st_ready_wreg = '1' and rx_st_ready_rreg = '1' and rx_st_ready_wmem = '1' and rx_st_ready_rmem = '1' -- should we add the DMA here somehow?
        else '0';

    -- needs to changed once meory is added
    --rx_st_ready_rmem <= '1';
    --rx_st_ready_wmem <= '1';

    e_pcie_writeable_registers : entity work.pcie_writeable_registers
    port map (
        o_writeregs_B   => o_writeregs_B,
        o_regwritten_B  => o_regwritten_B,
        i_clk_B         => i_clk_B,

        -- from IF
        i_rx_st         => i_rx_st,
        o_rx_st_ready0  => rx_st_ready_wreg,
        i_rx_bar        => rx_bar0(0),

        -- registers
        writeregs       => writeregs_s,
        regwritten      => regwritten_s,

        -- to response engine
        readaddr        => wreg_readaddr,
        readlength      => wreg_readlength,
        header2         => wreg_header2,
        readen          => wreg_readen,
        -- debugging
        inaddr32_w      => inaddr32_w,

        i_reset_n       => wreg_reset_n,
        i_clk           => i_clk--,
    );

    e_pcie_readable_registers : entity work.pcie_readable_registers
    port map (
        -- from IF
        i_rx_st         => i_rx_st,
        o_rx_st_ready0  => rx_st_ready_rreg,
        i_rx_bar        => rx_bar0(1),

        -- to response engine
        readaddr        => rreg_readaddr,
        readlength      => rreg_readlength,
        header2         => rreg_header2,
        readen          => rreg_readen,
        -- debugging
        inaddr32_r      => inaddr32_r,

        i_reset_n       => rreg_reset_n,
        i_clk           => i_clk--,
    );

    e_pcie_writeable_memory : entity work.pcie_writeable_memory
    port map (
        -- from IF
        i_rx_st         => i_rx_st,
        o_rx_st_ready0  => rx_st_ready_wmem,
        i_rx_bar        => rx_bar0(2),

        -- to memory
        tomemaddr       => writememaddr_w,
        tomemdata       => writememdata,
        tomemwren       => writememwren,

        -- to response engine
        readaddr        => wmem_readaddr,
        readlength      => wmem_readlength,
        header2         => wmem_header2,
        readen          => wmem_readen,

        i_reset_n       => wmem_reset_n,
        i_clk           => i_clk--,
    );

    e_pcie_readable_memory : entity work.pcie_readable_memory
    port map (
        -- from IF
        i_rx_st         => i_rx_st,
        o_rx_st_ready0  => rx_st_ready_rmem,
        i_rx_bar        => rx_bar0(3),

        -- to response engine
        readaddr        => rmem_readaddr,
        readlength      => rmem_readlength,
        header2         => rmem_header2,
        readen          => rmem_readen,

        i_reset_n       => rmem_reset_n,
        i_clk           => i_clk--,
    );

    e_pcie_completer : entity work.pcie_completer
    port map (
        -- to IF
        o_tx_st             => o_tx_st,
        tx_st_ready0_next   => i_tx_st_ready0,

        -- from Config
        completer_id        => completer_id,

        -- registers
        writeregs           => writeregs_s,
        i_readregs          => readregs_s,

        -- from register read part
        rreg_readaddr       => rreg_readaddr,
        rreg_readlength     => rreg_readlength,
        rreg_header2        => rreg_header2,
        rreg_readen         => rreg_readen,

        -- from register write part
        wreg_readaddr       => wreg_readaddr,
        wreg_readlength     => wreg_readlength,
        wreg_header2        => wreg_header2,
        wreg_readen         => wreg_readen,

        -- from memory read part
        rmem_readaddr       => rmem_readaddr,
        rmem_readlength     => rmem_readlength,
        rmem_header2        => rmem_header2,
        rmem_readen         => rmem_readen,

        -- from memory write part
        wmem_readaddr       => wmem_readaddr,
        wmem_readlength     => wmem_readlength,
        wmem_header2        => wmem_header2,
        wmem_readen         => wmem_readen,

        -- to and from writeable memory
        writemem_addr       => writememaddr_r,
        writemem_data       => writememq,

        -- to and from readable memory
        readmem_addr        => readmem_readaddr,
        readmem_data        => readmem_readdata,

        -- to and from dma engine
        dma_request         => dma_request,
        dma_granted         => dma_granted,
        dma_done            => dma_done,
        dma_tx_ready        => dma_tx_ready,
        i_dma_tx            => dma_tx,

        -- to and from second dma engine
        dma2_request        => dma2_request,
        dma2_granted        => dma2_granted,
        dma2_done           => dma2_done,
        dma2_tx_ready       => dma2_tx_ready,
        i_dma2_tx           => dma2_tx,

        -- test port
        testout             => testout_completer,

        i_reset_n           => comp_reset_n,
        i_clk               => i_clk--,
    );

    writememaddr <=
        writememaddr_r when writememwren = '0' else
        writememaddr_w;

    e_pcie_wram_narrow : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => writememaddr'length,
        g_DATA0_WIDTH => writememdata'length,
        g_ADDR1_WIDTH => writememreadaddr'length,
        g_DATA1_WIDTH => writememreaddata'length,
        g_RDATA1_REG  => 1--,
    )
    port map (
        i_addr0     => writememaddr,
        i_wdata0    => writememdata,
        i_we0       => writememwren,
        o_rdata0    => writememq,
        i_clk0      => i_clk,

        i_addr1     => writememreadaddr,
        o_rdata1    => writememreaddata,
        i_clk1      => writememclk--,
    );

    e_pcie_ram_narrow : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => readmem_addr'length,
        g_DATA0_WIDTH => readmem_data'length,
        g_ADDR1_WIDTH => readmem_readaddr'length,
        g_DATA1_WIDTH => readmem_readdata'length,
        g_RDATA0_REG => 1,
        g_RDATA1_REG => 1--,
    )
    port map (
        i_addr0     => readmem_addr,
        i_wdata0    => readmem_data,
        i_we0       => readmem_wren,
        i_clk0      => readmemclk,

        i_addr1     => readmem_readaddr,
        o_rdata1    => readmem_readdata,
        i_clk1      => i_clk--,
    );

    e_dma1 : entity work.dma_engine
    generic map (
        g_WADDR_WIDTH => g_DMA_WADDR_WIDTH,
        g_RADDR_WIDTH => g_DMA_RADDR_WIDTH,
        g_DATA_WIDTH => g_DMA_DATA_WIDTH,
        IRQNUM                      => "00000",
        ENABLE_BIT                  => DMA_BIT_ENABLE,
        NOW_BIT                     => DMA_BIT_NOW,
        ENABLE_INTERRUPT_BIT        => DMA_BIT_ENABLE_INTERRUPTS
    )
    port map (
        -- Stuff for DMA writing
        dataclk                     => dmamemclk,
        datain                      => dma_data,
        datawren                    => dmamem_wren,
        endofevent                  => dmamem_endofevent,
        memhalffull                 => dmamemhalffull,

        -- Bus and device number
        cfg_busdev                  => completer_id,

        -- Comunication with completer
        dma_request                 => dma_request,
        dma_granted                 => dma_granted,
        dma_done                    => dma_done,
        tx_ready                    => i_tx_st_ready0,
        o_tx                        => dma_tx,

        -- Interrupt stuff
        app_msi_req                 => app1_msi_req,
        app_msi_tc                  => app1_msi_tc,
        app_msi_num                 => app1_msi_num,
        app_msi_ack                 => app1_msi_ack,

        -- Configuration register
        dma_control_address         => dma_control_address,
        dma_data_address            => dma_data_address,
        dma_data_address_out        => dma_data_address_out,
        dma_data_mem_addr           => dma_data_mem_addr,
        dma_addrmem_data_written    => regwritten_s(DMA_DATA_ADDR_LOW_REGISTER_W),
        dma_data_pages              => dma_data_pages,
        dma_data_pages_out          => dma_data_pages_out,
        dma_data_n_addrs            => dma_data_n_addrs,

        dma_register                => writeregs_s(DMA_REGISTER_W),
        dma_register_written        => regwritten_s(DMA_REGISTER_W),
        dma_status_register         => readregs_int(DMA_STATUS_REGISTER_R),
        test_out                    => testout_dma,

        i_reset_n                   => dma1_reset_n,
        i_clk                       => i_clk--,
    );

    e_dma2 : entity work.dma_engine
    generic map (
        g_WADDR_WIDTH => g_DMA_WADDR_WIDTH,
        g_RADDR_WIDTH => g_DMA_RADDR_WIDTH,
        g_DATA_WIDTH => g_DMA_DATA_WIDTH,
        IRQNUM                      => "00001",
        ENABLE_BIT                  => DMA2_BIT_ENABLE,
        NOW_BIT                     => DMA2_BIT_NOW,
        ENABLE_INTERRUPT_BIT        => DMA2_BIT_ENABLE_INTERRUPTS
    )
    port map (
        -- Stuff for DMA writing
        dataclk                     => dma2memclk,
        datain                      => dma2_data,
        datawren                    => dma2mem_wren,
        endofevent                  => dma2mem_endofevent,
        memhalffull                 => dma2memhalffull,

        -- Bus and device number
        cfg_busdev                  => completer_id,

        -- Comunication with completer
        dma_request                 => dma2_request,
        dma_granted                 => dma2_granted,
        dma_done                    => dma2_done,
        tx_ready                    => i_tx_st_ready0,
        o_tx                        => dma2_tx,

        -- Interrupt stuff
        app_msi_req                 => app2_msi_req,
        app_msi_tc                  => app2_msi_tc,
        app_msi_num                 => app2_msi_num,
        app_msi_ack                 => app2_msi_ack,

        -- Configuration register
        dma_control_address         => dma2_control_address,
        dma_data_address            => dma_data_address,
        dma_data_address_out        => dma2_data_address_out,
        dma_data_mem_addr           => dma_data_mem_addr,
        dma_addrmem_data_written    => regwritten_s(DMA_DATA_ADDR_LOW_REGISTER_W),
        dma_data_pages              => dma_data_pages,
        dma_data_pages_out          => dma2_data_pages_out,
        dma_data_n_addrs            => dma2_data_n_addrs,

        dma_register                => writeregs_s(DMA_REGISTER_W),
        dma_register_written        => regwritten_s(DMA_REGISTER_W),
        dma_status_register         => readregs_int(DMA2_STATUS_REGISTER_R),
        test_out                    => open,

        i_reset_n                   => dma2_reset_n,
        i_clk                       => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        testout <= (others => '0');
        dma_write_config <= '0';
        dma2_write_config <= '0';

        app_msi_req <= '0';
        app_msi_tc <= (others => '0');
        app_msi_num <= (others => '0');
        app1_msi_ack <= '0';
        app2_msi_ack <= '0';

    elsif rising_edge(i_clk) then

        -- IRQ arbitration
        if(app1_msi_req = '1' and app1_msi_ack = '0') then
            app_msi_req <= '1';
            app_msi_tc <= app1_msi_tc;
            app_msi_num <= app1_msi_num;
            app1_msi_ack <= app_msi_ack;
        elsif(app2_msi_req = '1' and app2_msi_ack = '0') then
            app_msi_req <= '1';
            app_msi_tc <= app2_msi_tc;
            app_msi_num <= app2_msi_num;
            app2_msi_ack <= app_msi_ack;
        else
            app_msi_req <= '0';
            app1_msi_ack <= '0';
            app2_msi_ack <= '0';
        end if;

        if ( rmem_header2 /= 0 ) then
            rmem_header2_reg <= rmem_header2;
        end if;

        dma_control_address <= writeregs_s(DMA_CTRL_ADDR_HI_REGISTER_W) & writeregs_s(DMA_CTRL_ADDR_LOW_REGISTER_W);
        dma2_control_address <= writeregs_s(DMA2_CTRL_ADDR_HI_REGISTER_W) & writeregs_s(DMA2_CTRL_ADDR_LOW_REGISTER_W);
        dma_data_address <= writeregs_s(DMA_DATA_ADDR_HI_REGISTER_W) & writeregs_s(DMA_DATA_ADDR_LOW_REGISTER_W);
        dma_data_n_addrs <= writeregs_s(DMA_NUM_ADDRESSES_REGISTER_W)(DMA_NUM_ADDRESSES_RANGE);
        dma2_data_n_addrs <= writeregs_s(DMA_NUM_ADDRESSES_REGISTER_W)(DMA2_NUM_ADDRESSES_RANGE);
        dma_data_mem_addr <= writeregs_s(DMA_RAM_LOCATION_NUM_PAGES_REGISTER_W)(DMA_RAM_LOCATION_RANGE);
        dma_data_pages <= writeregs_s(DMA_RAM_LOCATION_NUM_PAGES_REGISTER_W)(DMA_NUM_PAGES_RANGE);
        readregs_int(DMA_DATA_ADDR_HI_REGISTER_R) <= dma_data_address_out(63 downto 32);
        readregs_int(DMA_DATA_ADDR_LOW_REGISTER_R) <= dma_data_address_out(31 downto 0);
        readregs_int(DMA2_DATA_ADDR_HI_REGISTER_R) <= dma2_data_address_out(63 downto 32);
        readregs_int(DMA2_DATA_ADDR_LOW_REGISTER_R) <= dma2_data_address_out(31 downto 0);
        readregs_int(DMA_NUM_PAGES_REGISTER_R)(DMA_NUM_PAGES_RANGE) <= dma_data_pages_out;
        readregs_int(DMA2_NUM_PAGES_REGISTER_R)(DMA_NUM_PAGES_RANGE) <= dma2_data_pages_out;

        if(regwritten_s(DMA_DATA_ADDR_LOW_REGISTER_W)='1' and writeregs_s(DMA_REGISTER_W)(DMA_BIT_ADDR_WRITE_ENABLE) = '1') then
            dma_write_config <= '1';
        else
            dma_write_config <= '0';
        end if;

        if(regwritten_s(DMA_DATA_ADDR_LOW_REGISTER_W)='1' and writeregs_s(DMA_REGISTER_W)(DMA2_BIT_ADDR_WRITE_ENABLE) = '1') then
            dma2_write_config <= '1';
        else
            dma2_write_config <= '0';
        end if;

        testout(127 downto 124) <= testout_completer(127 downto 124);
        testout(123 downto 112) <= "00" & rmem_readlength; -- length of read request for readable memory
        testout(111 downto 108) <= testout_completer(123 downto 120); -- empty of FIFOs containing read & write requests
        --testout(107 downto 52) <= testout_dma(55 downto 0);
        testout(107 downto 92) <= rmem_readaddr;
        --testout(91 downto 88) <= "000" & rmem_readen;
        testout(91 downto 88) <= (others => '0'); -- bits currently not used
        testout(87 downto 56) <= rmem_header2_reg;
        testout(55 downto 52 ) <= (others => '0');
        testout(51 downto 20) <= readregs_int(56); -- DMA status register
        testout(19 downto 8) <= testin(11 downto 0);
        testout(7 downto 0) <= testout_completer(7 downto 0);

        --readregs_int(60) <= (others => '0');
        --readregs_int(61) <= (others => '0');
        --readregs_int(62) <= (others => '0');
        --readregs_int(63) <= (others => '0');
    end if;
    end process;

end architecture;
