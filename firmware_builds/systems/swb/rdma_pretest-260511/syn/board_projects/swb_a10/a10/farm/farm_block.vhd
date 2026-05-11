-------------------------------------------------------
--! @farm_block.vhd
--! @brief the farm_block can be used
--! for the development board mainly it includes
--! the datapath which includes merging detector data
--! from multiple SWBs.
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity farm_block is
generic (
    g_DDR4 : boolean   := false;
    g_NLINKS_TOTL : positive  := 3--;
);
port (
    --! links to/from Farm
    i_rx                : in  work.mu3e.link32_array_t(g_NLINKS_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    o_tx                : out work.mu3e.link32_array_t(g_NLINKS_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! PCIe registers / memory
    i_writeregs         : in  slv32_array_t(63 downto 0);
    i_regwritten        : in  std_logic_vector(63 downto 0);
    o_readregs          : out slv32_array_t(63 downto 0);
    i_resets_n          : in  std_logic_vector(31 downto 0);

    i_wmem_rdata        : in  std_logic_vector(31 downto 0) := (others => '0');
    o_wmem_addr         : out std_logic_vector(15 downto 0) := (others => '0');

    i_dmamemhalffull    : in  std_logic;
    o_dma_wren          : out std_logic;
    o_endofevent        : out std_logic;
    o_dma_data          : out std_logic_vector(255 downto 0);

    -- Interface to memory bank A
    o_A_mem_ck          : out   std_logic_vector(0 downto 0);                      -- mem_ck
    o_A_mem_ck_n        : out   std_logic_vector(0 downto 0);                      -- mem_ck_n
    o_A_mem_a           : out   std_logic_vector(16 downto 0);                     -- mem_a
    o_A_mem_act_n       : out   std_logic_vector(0 downto 0);                      -- mem_act_n
    o_A_mem_ba          : out   std_logic_vector(2 downto 0);                      -- mem_ba
    o_A_mem_bg          : out   std_logic_vector(1 downto 0);                      -- mem_bg
    o_A_mem_cke         : out   std_logic_vector(0 downto 0);                      -- mem_cke
    o_A_mem_cs_n        : out   std_logic_vector(0 downto 0);                      -- mem_cs_n
    o_A_mem_odt         : out   std_logic_vector(0 downto 0);                      -- mem_odt
    o_A_mem_reset_n     : out   std_logic_vector(0 downto 0);                      -- mem_reset_n
    i_A_mem_alert_n     : in    std_logic_vector(0 downto 0)   := (others => 'X'); -- mem_alert_n
    o_A_mem_we_n        : out   std_logic_vector(0 downto 0);                      -- mem_we_n
    o_A_mem_ras_n       : out   std_logic_vector(0 downto 0);                      -- mem_ras_n
    o_A_mem_cas_n       : out   std_logic_vector(0 downto 0);                      -- mem_cas_n
    io_A_mem_dqs        : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs
    io_A_mem_dqs_n      : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs_n
    io_A_mem_dq         : inout std_logic_vector(63 downto 0)  := (others => 'X'); -- mem_dq
    o_A_mem_dm          : out   std_logic_vector(7 downto 0);                      -- mem_dm
    io_A_mem_dbi_n      : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dbi_n
    i_A_oct_rzqin       : in    std_logic                      := 'X';             -- oct_rzqin
    i_A_pll_ref_clk     : in    std_logic                      := 'X';             -- clk

    -- Interface to memory bank B
    o_B_mem_ck          : out   std_logic_vector(0 downto 0);                      -- mem_ck
    o_B_mem_ck_n        : out   std_logic_vector(0 downto 0);                      -- mem_ck_n
    o_B_mem_a           : out   std_logic_vector(16 downto 0);                     -- mem_a
    o_B_mem_act_n       : out   std_logic_vector(0 downto 0);                      -- mem_act_n
    o_B_mem_ba          : out   std_logic_vector(2 downto 0);                      -- mem_ba
    o_B_mem_bg          : out   std_logic_vector(1 downto 0);                      -- mem_bg
    o_B_mem_cke         : out   std_logic_vector(0 downto 0);                      -- mem_cke
    o_B_mem_cs_n        : out   std_logic_vector(0 downto 0);                      -- mem_cs_n
    o_B_mem_odt         : out   std_logic_vector(0 downto 0);                      -- mem_odt
    o_B_mem_reset_n     : out   std_logic_vector(0 downto 0);                      -- mem_reset_n
    i_B_mem_alert_n     : in    std_logic_vector(0 downto 0)   := (others => 'X'); -- mem_alert_n
    o_B_mem_we_n        : out   std_logic_vector(0 downto 0);                      -- mem_we_n
    o_B_mem_ras_n       : out   std_logic_vector(0 downto 0);                      -- mem_ras_n
    o_B_mem_cas_n       : out   std_logic_vector(0 downto 0);                      -- mem_cas_n
    io_B_mem_dqs        : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs
    io_B_mem_dqs_n      : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs_n
    io_B_mem_dq         : inout std_logic_vector(63 downto 0)  := (others => 'X'); -- mem_dq
    o_B_mem_dm          : out   std_logic_vector(7 downto 0);                      -- mem_dm
    io_B_mem_dbi_n      : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dbi_n
    i_B_oct_rzqin       : in    std_logic                      := 'X';             -- oct_rzqin
    i_B_pll_ref_clk     : in    std_logic                      := 'X';             -- clk

    --! 250 MHz clock pice / reset_n
    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

--! @brief arch definition of the farm_block
--! @details the farm_block can be used
--! for the development board mainly it includes
--! the datapath which includes merging detector data
--! from multiple SWBs.
--! scifi, down and up stream pixel/tiles)
architecture arch of farm_block is

    --! mapping signals
    signal rx : work.mu3e.link32_array_t(g_NLINKS_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! data gen links
    signal gen_link : work.mu3e.link32_t;

    --! aligned data
    signal aligned_data : work.mu3e.link64_array_t(g_NLINKS_TOTL-1 downto 0) := (others => work.mu3e.LINK64_IDLE);
    signal aligned_empty, aligned_ren, stream_ren : std_logic_vector(g_NLINKS_TOTL-1 downto 0);

    --! stream signal
    signal stream_counters : slv32_array_t(1 downto 0);

    --! ddr event builder
    signal ddr_rack, ddr_dma_wren, ddr_endofevent, ddr_dma_done : std_logic;
    signal ddr_dma_data : std_logic_vector(255 downto 0);
    signal ddr_data : std_logic_vector(511 downto 0);
    signal ddr_dma_cnt_words : std_logic_vector(31 downto 0);
    signal ddr_ts : std_logic_vector(47 downto 0);
    signal ddr_wen, ddr_ready, ddr_sop, ddr_eop, ddr_err : std_logic;

    --! debug event builder
    signal builder_data : work.mu3e.link64_t;
    signal builder_rempty, builder_dma_wren, builder_endofevent, builder_dma_done, builder_rack : std_logic;
    signal builder_dma_cnt_words : std_logic_vector(31 downto 0);
    signal builder_dma_data : std_logic_vector(255 downto 0);

    --! injection DMA to GPU
    signal injection_dma_wren, injection_endofevent, injection_dma_done : std_logic;
    signal injection_dma_data : std_logic_vector(255 downto 0);
    signal injection_dma_cnt_words : std_logic_vector(31 downto 0);
    signal injection, sc_injection : work.mu3e.link32_array_t(3 downto 0);

    --! coordination transformation
    signal float_hit : slv128_array_t(3 downto 0);
    signal float_hit_sop, float_hit_eop, float_hit_valid : std_logic_vector(3 downto 0);

    --! GPU event builder
    signal backpressure_gpu : std_logic;

    --! farm data path
    signal A_mem_ready      : std_logic;
    signal A_mem_calibrated : std_logic;
    signal A_mem_addr       : std_logic_vector(25 downto 0);
    signal A_mem_data       : std_logic_vector(511 downto 0);
    signal A_mem_write      : std_logic;
    signal A_mem_read       : std_logic;
    signal A_mem_q          : std_logic_vector(511 downto 0);
    signal A_mem_q_valid    : std_logic;
    signal B_mem_ready      : std_logic;
    signal B_mem_calibrated : std_logic;
    signal B_mem_addr       : std_logic_vector(25 downto 0);
    signal B_mem_data       : std_logic_vector(511 downto 0);
    signal B_mem_write      : std_logic;
    signal B_mem_read       : std_logic;
    signal B_mem_q          : std_logic_vector(511 downto 0);
    signal B_mem_q_valid    : std_logic;

    --! counters
    signal counter_link_to_fifo : slv32_array_t(8*13-1 downto 0);

begin

    --! @brief data path of the Farm board
    --! @details the data path of the farm board is first aligning the
    --! data from the SWB and is than grouping them into Pixel, Scifi and Tiles.
    --! The data is saved according to the sub-header time in the DDR memory.
    --! Via MIDAS one can select how much data one wants to readout from the DDR memory
    --! the stored data is marked and than forworded to the next farm pc


    --! status counter / outputs
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    o_readregs(SWB_LINK_COUNTER_REGISTER_R) <= counter_link_to_fifo(to_integer(unsigned(i_writeregs(SWB_COUNTER_REGISTER_W))));

    --! Farm slow control for data injection
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_sc_main : entity work.swb_sc_main
    generic map (
        -- NOTE: since we have a positive value here we need to put one link even
        -- if the farm boards are not connected to any FEBs
        NLINKS => 1--,
    )
    port map (
        i_length_we     => i_writeregs(SC_MAIN_ENABLE_REGISTER_W)(0),
        i_length        => i_writeregs(SC_MAIN_LENGTH_REGISTER_W)(15 downto 0),
        i_mem_data      => i_wmem_rdata,
        o_mem_addr      => o_wmem_addr,
        o_injection     => sc_injection,
        o_done          => o_readregs(SC_MAIN_STATUS_REGISTER_R)(SC_MAIN_DONE),
        o_state         => o_readregs(SC_STATE_REGISTER_R)(27 downto 0),
        i_reset_n       => i_resets_n(RESET_BIT_SC_MAIN),
        i_clk           => i_clk--,
    );

    e_data_injection : entity work.farm_data_injection
    port map (
        --! injection SC main
        i_injection     => sc_injection,

        --! PCIe registers
        i_writeregs     => i_writeregs,

        --! output hits per layer
        o_injection     => injection,

        --! 250 MHz clock pice / reset_n
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    --! Coordinate Converter
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- e_farm_coordinate_converter_dummy : entity work.farm_coordinate_converter_dummy
    -- port map (
    --     --! hits per layer input
    --     i_hits          => injection,

    --     --! hits output
    --     -- TODO: maybe we want a record here as well
    --     o_float_hit     => float_hit,
    --     o_sop           => float_hit_sop,
    --     o_eop           => float_hit_eop,
    --     o_valid         => float_hit_valid,

    --     --! 250 MHz clock pice / reset_n
    --     i_reset_n       => i_reset_n,
    --     i_clk           => i_clk--,
    -- );

    --! GPU event builder
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    gen_per_layer : for i in 0 to 3 generate
        float_hit(i)(127 downto 64) <= aligned_data(i).data;
        float_hit_sop(i) <= aligned_data(i).sop;
        float_hit_eop(i) <= aligned_data(i).eop;
        float_hit_valid(i) <= not aligned_data(i).idle;
        -- TODO: add buffer_almost_full to link_to_fifo
        aligned_ren(i) <= not aligned_empty(i) when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' else
                            stream_ren(i);
    end generate;
    e_farm_gpu_event_builder : entity work.farm_gpu_event_builder_onboard_RAM
    port map (
        --! hits per layer input
        i_float_hit         => float_hit,
        i_sop               => float_hit_sop,
        i_eop               => float_hit_eop,
        i_valid             => float_hit_valid,
        i_max_padding_size  => i_writeregs(FARM_GPU_EVENT_PADDING_W)(15 downto 0),
        o_almost_full       => backpressure_gpu,

        --! DMA
        i_dmamemhalffull    => i_dmamemhalffull,
        i_wen               => i_writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE),
        i_get_n_events      => i_writeregs(GET_N_GPU_EVENTS_REGISTER_W),
        o_dma_wen           => injection_dma_wren,
        o_dma_data          => injection_dma_data,
        o_endofevent        => injection_endofevent,
        o_dma_done          => injection_dma_done,

        --! 250 MHz clock pice / reset_n
        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    --! SWB Data Generation
    --! generate data in the format from the SWB
    --! PIXEL US, PIXEL DS, SCIFI --> Int Run 2021
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- gen pixel data
    e_data_gen_link : entity work.data_generator_a10
    generic map (
        go_to_sh => 3,
        test_error => false,
        is_farm => true,
        go_to_trailer => 4--,
    )
    port map (
        i_enable            => i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK),
        i_seed              => (others => '1'),
        o_data              => gen_link,
        i_slow_down         => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W),
        o_state             => open,

        i_reset_n           => i_resets_n(RESET_BIT_DATAGEN),
        i_clk               => i_clk--,
    );

    --! map links pixel / scifi
    generate_link_data :
    for i in 0 to g_NLINKS_TOTL-1 GENERATE
        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n /= '1' ) then
            rx(i) <= work.mu3e.LINK32_IDLE;
        elsif rising_edge(i_clk) then
            if ( i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK) = '1' ) then
                rx(i) <= work.mu3e.to_link(gen_link.data, gen_link.datak);
            else
                rx(i) <= work.mu3e.to_link(i_rx(i).data, i_rx(i).datak);
            end if;
        end if;
        end process;
    end generate;

    --! Link Alignment
    --! align data according to detector data
    --! two types of data will be extracted from the links
    --! PIXEL US, PIXEL DS, SCIFI --> Int Run 2021
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_farm_link_to_fifo : entity work.farm_link_to_fifo
    generic map (
        g_LINK_N   => g_NLINKS_TOTL--,
    )
    port map (
        --! link data
        i_rx        => rx,
        i_mask_n    => i_writeregs(FARM_LINK_MASK_REGISTER_W)(g_NLINKS_TOTL-1 downto 0),
        o_tx        => o_tx,

        --! data out
        o_q         => aligned_data,
        i_ren       => aligned_ren,
        o_rdempty   => aligned_empty,

        --! status counters
        o_counter   => counter_link_to_fifo(g_NLINKS_TOTL*13-1 downto 0),
        i_reset_n_cnt => i_resets_n(RESET_BIT_SWB_COUNTERS),

        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    -- -- get per 8ns data
    -- aligned_ren <=  '1' when aligned_empty = '0' and (aligned_data.sop = '1' or aligned_data.eop = '1' or aligned_data.t0 = '1' or aligned_data.t1 = '1' or aligned_data.d0 = '1' or aligned_data.d1 = '1') else
    --                 '1' when aligned_empty = '0' and (aligned_data.data(ts_range) = cur_8nts) else


    -- process(i_clk, i_reset_n) then
    -- begin
    -- if (i_reset_n /= '1') then
    --     cur_8nts <= (others => '1');
    --     cur_sbhdr <= (others => '1');
    -- elsif rising_edge(i_clk) then
    --     if (aligned_empty = '0') then
    --         aligned_data_reg_ts <= aligned_data(3 downto 0);
    --         if (aligned_data(i)(ts_range) /= cur_8nts) then
    --             cur_8nts <= cur_8nts + '1';
    --             float_hit_sop <= '1';
    --             float_hit_eop <= '1';
    --             float_hit_valid <= '0';
    --             float_hit(63 downto 0) <= aligned_data;
    --             float_hit_valid <= '1';
    --             aligned_ren <= '1';
    --         end if;
    --         aligned_data
    --     end if;
    -- end if;
    -- end process;


    --! stream merger
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_stream : entity work.swb_stream_merger
    generic map (
        g_ADDR_WIDTH => 11,
        N => g_NLINKS_TOTL--,
    )
    port map (
        i_rdata     => aligned_data,
        i_rempty    => aligned_empty,
        i_rmask_n   => i_writeregs(FARM_LINK_MASK_REGISTER_W)(g_NLINKS_TOTL-1 downto 0),
        o_rack      => stream_ren,

        -- farm data
        o_wdata     => builder_data,
        o_rempty    => builder_rempty,
        i_ren       => builder_rack,

        -- data for debug readout
        o_wdata_debug   => open,
        o_rempty_debug  => open,
        i_ren_debug     => '0',

        o_counters  => stream_counters,

        i_en        => i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_STREAM),
        i_reset_n   => i_resets_n(RESET_BIT_FARM_STREAM_MERGER),
        i_clk       => i_clk--,
    );

    --! readout switches
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    o_readregs(DMA_CNT_WORDS_REGISTER_R) <= injection_dma_cnt_words when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' else
                                            ddr_dma_cnt_words       when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '1' else
                                            builder_dma_cnt_words   when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '0' else
                                            (others => '0');
    o_dma_data      <=  injection_dma_data  when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' else
                        ddr_dma_data        when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '1' else
                        builder_dma_data    when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '0' else
                        (others => '0');
    o_dma_wren      <=  injection_dma_wren  when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' else
                        ddr_dma_wren        when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '1' else
                        builder_dma_wren    when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '0' else
                        '0';
    o_endofevent    <=  injection_endofevent    when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' else
                        ddr_endofevent          when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '1' else
                        builder_endofevent      when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '0' else
                        '0';
    o_readregs(EVENT_BUILD_STATUS_REGISTER_R)(EVENT_BUILD_DONE) <=  injection_dma_done  when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_INJECTION) = '1' else
                                                                    ddr_dma_done        when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '1' else
                                                                    builder_dma_done    when i_writeregs(FARM_READOUT_STATE_REGISTER_W)(USE_BIT_DDR) = '0' else
                                                                    '0';


    --! event builder used for the debug readout on the SWB
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_event_builder : entity work.swb_midas_event_builder
    port map (
        i_rx                => builder_data,
        i_rempty            => builder_rempty,

        i_get_n_words       => i_writeregs(GET_N_DMA_WORDS_REGISTER_W),
        i_dmamemhalffull    => i_dmamemhalffull,
        i_wen               => i_writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE),
        i_use_sop_type      => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_ALL),
        i_event_id          => i_writeregs(FARM_EVENT_ID_REGISTER_W),
        i_get_serial_number => i_writeregs(FARM_SERIAL_NUMBER_W),

        o_data              => builder_dma_data,
        o_wen               => builder_dma_wren,
        o_ren               => builder_rack,
        o_endofevent        => builder_endofevent,
        o_dma_cnt_words     => builder_dma_cnt_words,
        o_serial_num        => o_readregs(SERIAL_NUM_REGISTER_R),
        o_done              => builder_dma_done,

        o_counters(0)       => o_readregs(EVENT_BUILD_IDLE_NOT_HEADER_R),
        o_counters(1)       => o_readregs(EVENT_BUILD_SKIP_EVENT_DMA_R),
        o_counters(2)       => o_readregs(EVENT_BUILD_CNT_EVENT_DMA_R),
        o_counters(3)       => o_readregs(EVENT_BUILD_TAG_FIFO_FULL_R),

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );


    --! Farm MIDAS Event Builder
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- e_farm_midas_event_builder : entity work.farm_midas_event_builder_intrun22
    -- port map (
    --     --! data in
    --     i_rx            => builder_data,
    --     i_rempty        => builder_rempty,
    --     o_ren           => ddr_rack,

    --     -- Data type: "00" = pixel, "01" = scifi, "10" = tiles
    --     i_data_type     => i_writeregs(FARM_DATA_TYPE_REGISTER_W)(FARM_DATA_TYPE_ADDR_RANGE),
    --     i_event_id      => i_writeregs(FARM_DATA_TYPE_REGISTER_W)(FARM_EVENT_ID_ADDR_RANGE),

    --     --! DDR data
    --     o_data          => ddr_data,
    --     o_wen           => ddr_wen,
    --     o_event_ts      => ddr_ts,
    --     i_ddr_ready     => ddr_ready,
    --     o_sop           => ddr_sop,
    --     o_eop           => ddr_eop,
    --     o_err           => ddr_err,

    --     --! status counters
    --     --! 0: bank_builder_idle_not_header
    --     --! 1: bank_builder_skip_event
    --     --! 2: bank_builder_cnt_event
    --     --! 3: bank_builder_tag_fifo_full
    --     o_counters      => counter_midas_event_builder,

    --     i_reset_n       => i_reset_n,
    --     i_clk           => i_clk--,
    -- );


    -- --! Farm Data Path
    -- --! ------------------------------------------------------------------------
    -- --! ------------------------------------------------------------------------
    -- --! ------------------------------------------------------------------------
    -- e_farm_data_path : entity work.farm_data_path
    -- port map (
    --     --! input from merging (first board) or links (subsequent boards)
    --     i_data           => ddr_data,
    --     i_data_en        => ddr_wen,
    --     i_ts             => ddr_ts(35 downto 4), -- 3:0 -> hit, 9:0 -> sub header
    --     o_ddr_ready      => ddr_ready,
    --     i_err            => ddr_err,
    --     i_sop            => ddr_sop,
    --     i_eop            => ddr_eop,

    --     --! input from PCIe demanding events
    --     i_ts_req_A        => i_writeregs(DATA_REQ_A_W),
    --     i_req_en_A        => i_regwritten(DATA_REQ_A_W),
    --     i_ts_req_B        => i_writeregs(DATA_REQ_B_W),
    --     i_req_en_B        => i_regwritten(DATA_REQ_B_W),
    --     i_tsblock_done    => i_writeregs(DATA_TSBLOCK_DONE_W)(15 downto 0),
    --     o_tsblocks        => o_readregs(DATA_TSBLOCKS_R),

    --     --! output to DMA
    --     o_dma_data       => ddr_dma_data,
    --     o_dma_wren       => ddr_dma_wren,
    --     o_dma_eoe        => ddr_endofevent,
    --     i_dmamemhalffull => i_dmamemhalffull,
    --     i_num_req_events => i_writeregs(FARM_REQ_EVENTS_W),
    --     o_dma_done       => ddr_dma_done,
    --     i_dma_wen        => i_writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE),

    --     --! status counters
    --     --! 0: cnt_skip_event_dma
    --     --! 1: A_almost_full
    --     --! 2: B_almost_full
    --     --! 3: i_dmamemhalffull
    --     o_counters      => counter_ddr,

    --     --! interface to memory bank A
    --     A_mem_ready     => A_mem_ready,
    --     A_mem_calibrated=> A_mem_calibrated,
    --     A_mem_addr      => A_mem_addr,
    --     A_mem_data      => A_mem_data,
    --     A_mem_write     => A_mem_write,
    --     A_mem_read      => A_mem_read,
    --     A_mem_q         => A_mem_q,
    --     A_mem_q_valid   => A_mem_q_valid,

    --     --! interface to memory bank B
    --     B_mem_ready     => B_mem_ready,
    --     B_mem_calibrated=> B_mem_calibrated,
    --     B_mem_addr      => B_mem_addr,
    --     B_mem_data      => B_mem_data,
    --     B_mem_write     => B_mem_write,
    --     B_mem_read      => B_mem_read,
    --     B_mem_q         => B_mem_q,
    --     B_mem_q_valid   => B_mem_q_valid,

    --     i_reset_n        => i_resets_n(RESET_BIT_DDR),
    --     i_clk            => i_clk--,
    -- );


    --! Farm DDR Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_ddr_block : entity work.ddr_block
    generic map (
        g_DDR4                => g_DDR4--,
    )
    port map (
        --! control and status registers
        i_ddr_control         => i_writeregs(DDR_CONTROL_W),
        o_ddr_status          => o_readregs(DDR_STATUS_R),

        --! A interface
        o_A_ddr_calibrated    => A_mem_calibrated,
        o_A_ddr_ready         => A_mem_ready,
        i_A_ddr_addr          => A_mem_addr,
        i_A_ddr_datain        => A_mem_data,
        o_A_ddr_dataout       => A_mem_q,
        i_A_ddr_write         => A_mem_write,
        i_A_ddr_read          => A_mem_read,
        o_A_ddr_read_valid    => A_mem_q_valid,

        --! B interface
        o_B_ddr_calibrated    => B_mem_calibrated,
        o_B_ddr_ready         => B_mem_ready,
        i_B_ddr_addr          => B_mem_addr,
        i_B_ddr_datain        => B_mem_data,
        o_B_ddr_dataout       => B_mem_q,
        i_B_ddr_write         => B_mem_write,
        i_B_ddr_read          => B_mem_read,
        o_B_ddr_read_valid    => B_mem_q_valid,

        --! error counters
        o_error               => o_readregs(DDR_ERR_R),

        --! interface to memory bank A
        o_A_mem_ck            => o_A_mem_ck,
        o_A_mem_ck_n          => o_A_mem_ck_n,
        o_A_mem_a             => o_A_mem_a,
        o_A_mem_act_n         => o_A_mem_act_n,
        o_A_mem_ba            => o_A_mem_ba,
        o_A_mem_bg            => o_A_mem_bg,
        o_A_mem_cke           => o_A_mem_cke,
        o_A_mem_cs_n          => o_A_mem_cs_n,
        o_A_mem_odt           => o_A_mem_odt,
        o_A_mem_reset_n(0)    => o_A_mem_reset_n(0),
        i_A_mem_alert_n(0)    => i_A_mem_alert_n(0),
        o_A_mem_we_n(0)       => o_A_mem_we_n(0),
        o_A_mem_ras_n(0)      => o_A_mem_ras_n(0),
        o_A_mem_cas_n(0)      => o_A_mem_cas_n(0),
        io_A_mem_dqs          => io_A_mem_dqs,
        io_A_mem_dqs_n        => io_A_mem_dqs_n,
        io_A_mem_dq           => io_A_mem_dq,
        o_A_mem_dm            => o_A_mem_dm,
        io_A_mem_dbi_n        => io_A_mem_dbi_n,
        i_A_oct_rzqin         => i_A_oct_rzqin,
        i_A_pll_ref_clk       => i_A_pll_ref_clk,

        --! interface to memory bank B
        o_B_mem_ck            => o_B_mem_ck,
        o_B_mem_ck_n          => o_B_mem_ck_n,
        o_B_mem_a             => o_B_mem_a,
        o_B_mem_act_n         => o_B_mem_act_n,
        o_B_mem_ba            => o_B_mem_ba,
        o_B_mem_bg            => o_B_mem_bg,
        o_B_mem_cke           => o_B_mem_cke,
        o_B_mem_cs_n          => o_B_mem_cs_n,
        o_B_mem_odt           => o_B_mem_odt,
        o_B_mem_reset_n(0)    => o_B_mem_reset_n(0),
        i_B_mem_alert_n(0)    => i_B_mem_alert_n(0),
        o_B_mem_we_n(0)       => o_B_mem_we_n(0),
        o_B_mem_ras_n(0)      => o_B_mem_ras_n(0),
        o_B_mem_cas_n(0)      => o_B_mem_cas_n(0),
        io_B_mem_dqs          => io_B_mem_dqs,
        io_B_mem_dqs_n        => io_B_mem_dqs_n,
        io_B_mem_dq           => io_B_mem_dq,
        o_B_mem_dm            => o_B_mem_dm,
        io_B_mem_dbi_n        => io_B_mem_dbi_n,
        i_B_oct_rzqin         => i_B_oct_rzqin,
        i_B_pll_ref_clk       => i_B_pll_ref_clk,

        i_reset_n             => i_resets_n(RESET_BIT_DDR),
        i_clk                 => i_clk--,
     );

end architecture;
