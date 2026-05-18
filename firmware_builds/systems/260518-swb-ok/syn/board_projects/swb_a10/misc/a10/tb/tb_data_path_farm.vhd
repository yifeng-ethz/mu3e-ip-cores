--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity tb_data_path_farm is
end entity;

architecture TB of tb_data_path_farm is

    signal reset_n  : std_logic;
    signal reset    : std_logic;

    -- Input from merging (first board) or links (subsequent boards)
    signal clk  :   std_logic := '0';
    signal data_en  :   std_logic;
    signal data_in  :   std_logic_vector(511 downto 0);
    signal ts_in    :   std_logic_vector(31 downto 0);

    -- Input from PCIe demanding events
    signal pcieclk      :   std_logic := '0';
    signal ts_req_A     :   std_logic_vector(31 downto 0);
    signal req_en_A     :   std_logic;
    signal ts_req_B     :   std_logic_vector(31 downto 0);
    signal req_en_B     :   std_logic;
    signal tsblock_done :   std_logic_vector(15 downto 0);

    -- Output to DMA
    signal dma_data_out     :   std_logic_vector(255 downto 0);
    signal dma_data_en      :   std_logic;
    signal dma_eoe          :   std_logic;

    -- Interface to memory bank A
    signal A_mem_clk        : std_logic := '0';
    signal A_mem_ready      : std_logic;
    signal A_mem_calibrated : std_logic;
    signal A_mem_addr       : std_logic_vector(25 downto 0);
    signal A_mem_data       : std_logic_vector(511 downto 0);
    signal A_mem_write      : std_logic;
    signal A_mem_read       : std_logic;
    signal A_mem_q          : std_logic_vector(511 downto 0);
    signal A_mem_q_valid    : std_logic;

    -- Interface to memory bank B
    signal B_mem_clk        : std_logic := '0';
    signal B_mem_ready      : std_logic;
    signal B_mem_calibrated : std_logic;
    signal B_mem_addr       : std_logic_vector(25 downto 0);
    signal B_mem_data       : std_logic_vector(511 downto 0);
    signal B_mem_write      : std_logic;
    signal B_mem_read       : std_logic;
    signal B_mem_q          : std_logic_vector(511 downto 0);
    signal B_mem_q_valid    : std_logic;

    -- links and datageneration
    constant NLINKS                 : positive := 8;
    constant NLINKS_TOTL            : positive := 16;
    constant LINK_FIFO_ADDR_WIDTH   : integer := 10;
    constant g_NLINKS_FARM_TOTL     : positive := 3;

    signal link_data        : std_logic_vector(NLINKS*32-1 downto 0);
    signal link_datak       : std_logic_vector(NLINKS*4-1 downto 0);
    signal counter_ddr3     : std_logic_vector(31 downto 0);

    signal w_pixel, r_pixel, w_scifi, r_scifi : std_logic_vector(NLINKS*38-1 downto 0);
    signal w_pixel_en, r_pixel_en, full_pixel, empty_pixel : std_logic;
    signal w_scifi_en, r_scifi_en, full_scifi, empty_scifi : std_logic;

    signal farm_data, farm_datak : slv32_array_t(g_NLINKS_FARM_TOTL-1 downto 0);

    signal rx : slv32_array_t(NLINKS_TOTL-1 downto 0);
    signal rx_k : slv4_array_t(NLINKS_TOTL-1 downto 0);

    signal link_data_pixel, link_data_scifi : std_logic_vector(NLINKS*32-1  downto 0);
    signal link_datak_pixel, link_datak_scifi : std_logic_vector(NLINKS*4-1  downto 0);

    signal pixel_data, scifi_data : std_logic_vector(257 downto 0);
    signal pixel_empty, pixel_ren, scifi_empty, scifi_ren : std_logic;
    signal data_wen, ddr_ready : std_logic;
    signal event_ts : std_logic_vector(47 downto 0);
    signal ts_req_num : std_logic_vector(31 downto 0);

    signal writeregs : slv32_array_t(63 downto 0) := (others => (others => '0'));

    signal resets_n : std_logic_vector(31 downto 0) := (others => '0');

    -- clk period
    constant pcieclk_period : time := 4 ns;
    constant CLK_MHZ : real := 250.0; -- MHz

    signal toggle : std_logic_vector(1 downto 0);
    signal startinput : std_logic;
    signal ts_in_next   :   std_logic_vector(31 downto 0);

    signal A_mem_read_del1: std_logic;
    signal A_mem_read_del2: std_logic;
    signal A_mem_read_del3: std_logic;
    signal A_mem_read_del4: std_logic;

    signal A_mem_addr_del1  : std_logic_vector(25 downto 0);
    signal A_mem_addr_del2  : std_logic_vector(25 downto 0);
    signal A_mem_addr_del3  : std_logic_vector(25 downto 0);
    signal A_mem_addr_del4  : std_logic_vector(25 downto 0);

    signal B_mem_read_del1: std_logic;
    signal B_mem_read_del2: std_logic;
    signal B_mem_read_del3: std_logic;
    signal B_mem_read_del4: std_logic;

    signal B_mem_addr_del1  : std_logic_vector(25 downto 0);
    signal B_mem_addr_del2  : std_logic_vector(25 downto 0);
    signal B_mem_addr_del3  : std_logic_vector(25 downto 0);
    signal B_mem_addr_del4  : std_logic_vector(25 downto 0);

    signal midas_data_511 : slv32_array_t(15 downto 0);

    signal test : std_logic := '0';
    signal dma_data_array : slv32_array_t(7 downto 0);
    signal dma_data : std_logic_vector(255 downto 0);

    signal writememdata : std_logic_vector(31 downto 0);
    signal writememdata_out : std_logic_vector(31 downto 0);
    signal writememdata_out_reg : std_logic_vector(31 downto 0);
    signal writememaddr : std_logic_vector(15 downto 0);
    signal memaddr : std_logic_vector(15 downto 0);
    signal memaddr_reg : std_logic_vector(15 downto 0);
    signal readmem_writedata : std_logic_vector(31 downto 0);
    signal readmem_writeaddr : std_logic_vector(15 downto 0);
    signal counter : std_logic_vector(31 downto 0);
    signal readmem_wren : std_logic;

    signal readregs : slv32_array_t(63 downto 0) := (others => (others => '0'));

    type state_type is (startup, idle, write_sc, wait_state, read_sc, finished);
    signal state : state_type;

    signal writememwren, toggle_read, done, fifo_we : std_logic;

    signal layer_idx : integer range 0 to 3;
    signal layer_marker : slv12_array_t(3 downto 0);

begin

-- synthesis read_comments_as_HDL on
    --test <= '1';
-- synthesis read_comments_as_HDL off

    clk         <= not clk after (0.5 us / CLK_MHZ);
    A_mem_clk   <= not A_mem_clk after (0.1 us / CLK_MHZ);
    B_mem_clk   <= not B_mem_clk after (0.1 us / CLK_MHZ);

    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    --! Setup
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! USE_GEN_LINK | USE_STREAM | USE_MERGER | USE_LINK | USE_GEN_MERGER | USE_FARM | SWB_READOUT_LINK_REGISTER_W | EFFECT                                                                         | WORKS
    --! ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    --! 1            | 0          | 0          | 1        | 0              | 0        | n                           | Generate data for all 64 links, readout link n via DAM                         | x
    --! 1            | 1          | 0          | 0        | 0              | 0        | -                           | Generate data for all 64 links, simple merging of links, readout via DAM       | x
    --! 1            | 0          | 1          | 0        | 0              | 0        | -                           | Generate data for all 64 links, time merging of links, readout via DAM         | x
    --! 0            | 0          | 0          | 0        | 1              | 1        | -                           | Generate time merged data, send to farm                                        | x

    resets_n(RESET_BIT_DATAGEN)                                 <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_FARM_STREAM_MERGER)                      <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_FARM_TIME_MERGER)                        <= '0', '1' after (1.0 us / CLK_MHZ);
    resets_n(RESET_BIT_SC_MAIN)                                 <= '0', '1' after (1.0 us / CLK_MHZ);
    writeregs(DATAGENERATOR_DIVIDER_REGISTER_W)                 <= x"00000002";
    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK)  <= '0';
    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM)    <= '0';
    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER)    <= '0';

    writeregs(FARM_LINK_MASK_REGISTER_W)                        <= x"00000000";--x"00000048";
    -- Data type: "00" = pixel, "01" = scifi, "10" = tiles
    writeregs(FARM_DATA_TYPE_REGISTER_W)(FARM_DATA_TYPE_ADDR_RANGE) <= "00";
    writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR)       <= '0';

    -- slow down register
    writeregs(INJECTION_WAIT_W) <= x"00000002";

    -- Request generation
    process begin
        req_en_A <= '0';
        wait for pcieclk_period;-- * 26500;
        req_en_A <= '1';
        ts_req_num <= x"00000008";
        ts_req_A <= x"04030201";--"00010000";
        wait for pcieclk_period;
        req_en_A <= '1';
        ts_req_A <= x"0B0A0906";--x"00030002";
        wait for pcieclk_period;
        req_en_A <= '0';
        wait for pcieclk_period;
        req_en_A <= '0';
        tsblock_done    <= (others => '0');
    end process;

    -- do dma requests
    process(clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        writeregs(GET_N_DMA_WORDS_REGISTER_W) <= x"0000000A";
        writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE) <= '0';
        --
    elsif rising_edge(clk) then
        writeregs(GET_N_DMA_WORDS_REGISTER_W) <= x"0000000A";
        if ( readregs(EVENT_BUILD_STATUS_REGISTER_R)(EVENT_BUILD_DONE) = '0' ) then
            writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE) <= '1';
        else
            writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE) <= '0';
        end if;
    end if;
    end process;

    --! Farm Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    farm_block : entity work.farm_block
    generic map (
        g_DDR4         => true,
        g_NLINKS_TOTL  => 8--,
    )
    port map (

        --! links to/from FEBs
        i_rx            => (others => work.mu3e.LINK32_IDLE),
        o_tx            => open,

        --! PCIe registers / memory
        i_writeregs     => writeregs,
        i_regwritten    => (others => '0'),
        o_readregs      => readregs,

        i_wmem_rdata    => writememdata_out,
        o_wmem_addr     => memaddr,

        i_resets_n      => resets_n,

        i_dmamemhalffull=> '0',
        o_dma_wren      => open,
        o_endofevent    => open,
        o_dma_data      => dma_data,

        --! 250 MHz clock pice / reset_n
        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    --! test to write injection data via SC entity
    wram : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 8,
        g_ADDR1_WIDTH => 8,
        g_DATA0_WIDTH => 32,
        g_DATA1_WIDTH => 32--,
    )
    port map (
        i_addr0     => writememaddr(7 downto 0),
        i_addr1     => memaddr(7 downto 0),
        i_clk0      => clk,
        i_clk1      => clk,
        i_wdata0    => writememdata,
        i_wdata1    => (others => '0'),
        i_we0       => writememwren,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => writememdata_out--,
    );

    done <= readregs(SC_MAIN_STATUS_REGISTER_R)(SC_MAIN_DONE);

    memory : process(clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        writememdata <= (others => '0');
        counter <= (others => '0');
        writememaddr <= x"FFFF";
        layer_idx <= 0;
        layer_marker(0) <= x"080";
        layer_marker(1) <= x"100";
        layer_marker(2) <= x"200";
        layer_marker(3) <= x"400";
        writememwren <= '0';
        writeregs(SC_MAIN_ENABLE_REGISTER_W)(0) <= '0';
        toggle_read  <= '0';
        state        <= startup;
    elsif rising_edge(clk) then
        writememwren    <= '0';
        writeregs(SC_MAIN_ENABLE_REGISTER_W)(0) <= '0';
        writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_WRITE_BUFFER_INJECTION) <= '0';

        case state is

        when startup =>
            writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_WRITE_BUFFER_INJECTION) <= '1';
            state <= idle;

        when idle =>
            if ( done = '1' ) then
                state <= write_sc;
            end if;

        when write_sc =>
            if(writememaddr(3 downto 0) = x"F")then
                -- we write to bit 8 in FEB address for injection
                -- 0000 1000 0000 L0 -> 0x080
                -- 0001 0000 0000 L1 -> 0x100
                -- 0010 0000 0000 L2 -> 0x200
                -- 0100 0000 0000 L3 -> 0x400
                writememdata <= x"1d0" & layer_marker(layer_idx) & x"bc";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"0")then
                writememdata <= x"0000000A";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            elsif(writememaddr(3 downto 0)  = x"1")then
                writememdata <= x"0000000A";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            -- x hit 0
            elsif(writememaddr(3 downto 0)  >= x"2" and counter(6 downto 0) < "1111000" )then
                counter <= counter + '1';
                writememdata <= counter;
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
            -- -- y hit 0
            -- elsif(writememaddr(3 downto 0)  = x"3")then
            --     counter <= counter + '1';
            --     writememdata <= counter;
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            -- -- z hit 0
            -- elsif(writememaddr(3 downto 0)  = x"4")then
            --     counter <= counter + '1';
            --     writememdata <= counter;
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            -- -- ID hit 0
            -- elsif(writememaddr(3 downto 0)  = x"5")then
            --     counter <= counter + '1';
            --     writememdata <= x"BEEFBEEF";
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            -- -- x hit 1
            -- elsif(writememaddr(3 downto 0)  = x"6")then
            --     counter <= counter + '1';
            --     writememdata <= counter;
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            -- -- y hit 1
            -- elsif(writememaddr(3 downto 0)  = x"7")then
            --     counter <= counter + '1';
            --     writememdata <= counter;
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            -- -- z hit 1
            -- elsif(writememaddr(3 downto 0)  = x"8")then
            --     counter <= counter + '1';
            --     writememdata <= counter;
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            -- -- ID hit 1
            -- elsif(writememaddr(3 downto 0)  = x"9")then
            --     counter <= counter + '1';
            --     writememdata <= x"BEEFBEEF";
            --     writememaddr <= writememaddr + 1;
            --     writememwren <= '1';
            elsif(counter(6 downto 0) = "1111000")then
                counter <= counter + '1';
                writememdata <= x"0000009c";
                writememaddr <= writememaddr + 1;
                writememwren <= '1';
                writeregs(SC_MAIN_LENGTH_REGISTER_W)(15 downto 0) <= x"000A";
            elsif(counter(6 downto 0) = "1111001")then
                writeregs(SC_MAIN_ENABLE_REGISTER_W)(0) <= '1';
                writememaddr <= (others => '1');
                counter <= (others => '0');
                if (layer_idx = 3) then
                    state <= finished;
                else
                    layer_idx <= layer_idx + 1;
                    state <= wait_state;
                end if;
            end if;

        when wait_state =>
            if ( done = '0' ) then
                state <= idle;
            end if;

        when finished =>
            writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) <= '1';

        when others =>
            writememaddr <= (others => '0');
            state <= startup;

        end case;
    end if;
    end process;

    dma_data_array(0) <= dma_data(0*32 + 31 downto 0*32);
    dma_data_array(1) <= dma_data(1*32 + 31 downto 1*32);
    dma_data_array(2) <= dma_data(2*32 + 31 downto 2*32);
    dma_data_array(3) <= dma_data(3*32 + 31 downto 3*32);
    dma_data_array(4) <= dma_data(4*32 + 31 downto 4*32);
    dma_data_array(5) <= dma_data(5*32 + 31 downto 5*32);
    dma_data_array(6) <= dma_data(6*32 + 31 downto 6*32);
    dma_data_array(7) <= dma_data(7*32 + 31 downto 7*32);

end architecture;
