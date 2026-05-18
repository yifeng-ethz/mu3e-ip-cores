-------------------------------------------------------
--! @swb_block.vhd
--! @brief the swb_block can be used
--! for the LCHb Board and the development board
--! mainly it includes the datapath which includes
--! merging hits from multiple FEBs. There will be
--! four types of SWB which differe accordingly to
--! the detector data they receive (inner pixel,
--! scifi, down and up stream pixel/tiles)
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;
use work.a10_counters.all;

entity swb_block is
generic (
    g_NLINKS_FEB_TOTL       : integer := 12;
    g_NLINKS_DATA_GENERIC   : integer := 8;
    g_NLINKS_FARM_TOTL      : integer := 3;
    g_NLINKS_DATA_PIXEL_US  : integer := 5;
    g_NLINKS_DATA_PIXEL_DS  : integer := 5;
    -- needed for simulation
    g_SC_SEC_SKIP_INIT      : std_logic := '0'--;
);
port (
    --! links to/from FEBs
    i_feb_rx            : in  work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    o_feb_tx            : out work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! PCIe registers / memory
    i_writeregs         : in  slv32_array_t(63 downto 0) := (others => (others => '0'));
    i_regwritten        : in  std_logic_vector(63 downto 0) := (others => '0');
    o_readregs          : out slv32_array_t(63 downto 0) := (others => (others => '0'));
    i_resets_n          : in  std_logic_vector(31 downto 0) := (others => '0');

    i_wmem_rdata        : in  std_logic_vector(31 downto 0) := (others => '0');
    o_wmem_addr         : out std_logic_vector(15 downto 0) := (others => '0');

    o_rmem_wdata        : out std_logic_vector(31 downto 0) := (others => '0');
    o_rmem_addr         : out std_logic_vector(15 downto 0) := (others => '0');
    o_rmem_we           : out std_logic := '0';

    i_dmamemhalffull    : in  std_logic := '0';
    o_dma_wren          : out std_logic := '0';
    o_endofevent        : out std_logic := '0';
    o_dma_data          : out std_logic_vector(255 downto 0) := (others => '0');
    o_opq_data          : out std_logic_vector(31 downto 0) := (others => '0');
    o_opq_datak         : out std_logic_vector(3 downto 0) := (others => '0');
    o_opq_valid         : out std_logic := '0';

    --! links to farm
    o_farm_tx           : out work.mu3e.link32_array_t(g_NLINKS_FARM_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! clock / reset_n
    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;

);
end entity;

--! @brief arch definition of the swb_block
--! @details The arch of the swb_block can be used
--! for the LCHb Board and the development board
--! mainly it includes the datapath which includes
--! merging hits from multiple FEBs. There will be
--! four types of SWB which differe accordingly to
--! the detector data they receive (inner pixel,
--! scifi, down and up stream pixel/tiles)
architecture arch of swb_block is

    --! data path control signals
    signal mask_n : std_logic_vector(63 downto 0) := (others => '0');
    signal debug_mask_generic_w : std_logic_vector(31 downto 0) := (others => '0');
    signal debug_mask_scifi_w : std_logic_vector(31 downto 0) := (others => '0');
    signal debug_selected_link_mask_w : std_logic_vector(31 downto 0) := (others => '0');
    signal debug_readout_state_w : std_logic_vector(31 downto 0) := (others => '0');
    signal debug_mask_select_generic : std_logic := '0';
    signal debug_mask_select_scifi : std_logic := '0';

    --! feb links
    signal feb_rx : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);

    --! demerged FEB links
    signal rx_data, rx_data_sim : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal rx_data_sim_opq : work.mu3e.link32_array_t(3 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal rx_data_sim_merged : work.mu3e.link32_array_t(3 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal rx_data_sim_merged_r : work.mu3e.link32_array_t(3 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal rx_sc : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0)   := (others => work.mu3e.LINK32_IDLE);
    signal rx_rc : work.mu3e.link32_array_t(g_NLINKS_FEB_TOTL-1 downto 0)   := (others => work.mu3e.LINK32_IDLE);
    signal gen_link : work.mu3e.link32_t;
    signal gen_link_decoded : work.mu3e.link32_t;
    signal data_gen_state : std_logic_vector(3 downto 0) := (others => '0');

    signal use_opq_merge : std_logic := '0';

    --! counters
    signal rate_mux : slv32_array_t(3*4 downto 0) := (others => (others => '0'));
    signal counter_mux : slv64_array_t(3*4+1 downto 0) := (others => (others => '0'));

    --! histograms
    signal histo_selected_link : integer range 0 to g_NLINKS_FEB_TOTL-1;
    signal histo_select_chip   : integer range 0 to 127;
    signal histo_rx_selected   : work.mu3e.link32_t;

    signal data_path_reset_n : std_logic;
    signal opq_reset_n : std_logic;
    signal dma_reset_n : std_logic;
    attribute keep : boolean;
    attribute preserve : boolean;
    attribute noprune : boolean;
    attribute altera_attribute : string;
    attribute keep of debug_mask_generic_w : signal is true;
    attribute keep of debug_mask_scifi_w : signal is true;
    attribute keep of debug_selected_link_mask_w : signal is true;
    attribute keep of debug_readout_state_w : signal is true;
    attribute keep of debug_mask_select_generic : signal is true;
    attribute keep of debug_mask_select_scifi : signal is true;
    attribute noprune of debug_mask_generic_w : signal is true;
    attribute noprune of debug_mask_scifi_w : signal is true;
    attribute noprune of debug_selected_link_mask_w : signal is true;
    attribute noprune of debug_readout_state_w : signal is true;
    attribute noprune of debug_mask_select_generic : signal is true;
    attribute noprune of debug_mask_select_scifi : signal is true;
    attribute altera_attribute of opq_reset_n : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of dma_reset_n : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name GLOBAL_SIGNAL OFF";

    constant OPQ_DMA_PACKER_UID_CONST : std_logic_vector(31 downto 0) := x"4F505144";

    signal opq_egress_data       : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_egress_datak      : std_logic_vector(3 downto 0) := (others => '0');
    signal opq_egress_valid      : std_logic := '0';
    signal opq_egress_sop        : std_logic := '0';
    signal opq_egress_eop        : std_logic := '0';
    signal opq_dma_ready         : std_logic := '0';
    signal opq_dma_input_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_dma_input_datak   : std_logic_vector(3 downto 0) := (others => '0');
    signal opq_dma_input_valid   : std_logic := '0';
    signal opq_dma_input_sop     : std_logic := '0';
    signal opq_dma_input_eop     : std_logic := '0';
    signal opq_dma_status        : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_dma_input_words   : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_dma_output_words  : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_dma_event_count   : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_dma_halt_count    : std_logic_vector(31 downto 0) := (others => '0');

    component swb_opq_dma_pipeline is
    port (
        i_clk                  : in  std_logic;
        i_reset_n              : in  std_logic;
        i_dma_enable           : in  std_logic;
        i_dma_halffull         : in  std_logic;
        i_opq_data             : in  std_logic_vector(31 downto 0);
        i_opq_datak            : in  std_logic_vector(3 downto 0);
        i_opq_valid            : in  std_logic;
        i_opq_sop              : in  std_logic;
        i_opq_eop              : in  std_logic;
        o_opq_ready            : out std_logic;
        o_opq_egress_data      : out std_logic_vector(35 downto 0);
        o_opq_egress_valid     : out std_logic;
        o_opq_egress_sop       : out std_logic;
        o_opq_egress_eop       : out std_logic;
        o_dma_data             : out std_logic_vector(255 downto 0);
        o_dma_datak            : out std_logic_vector(31 downto 0);
        o_dma_wen              : out std_logic;
        o_end_of_event         : out std_logic;
        o_input_word_cnt       : out std_logic_vector(31 downto 0);
        o_output_word_cnt      : out std_logic_vector(31 downto 0);
        o_event_cnt            : out std_logic_vector(31 downto 0);
        o_halt_cnt             : out std_logic_vector(31 downto 0)
    );
    end component;

    signal opq_dma_data       : std_logic_vector(255 downto 0) := (others => '0');
    signal opq_dma_datak      : std_logic_vector(31 downto 0) := (others => '0');
    signal opq_dma_wren       : std_logic := '0';
    signal opq_dma_endofevent : std_logic := '0';
    attribute keep of opq_dma_input_sop : signal is true;
    attribute keep of opq_dma_input_eop : signal is true;
    attribute keep of opq_dma_datak : signal is true;
    attribute preserve of opq_dma_input_sop : signal is true;
    attribute preserve of opq_dma_input_eop : signal is true;
    attribute preserve of opq_dma_datak : signal is true;

begin

    --! @brief data path of the SWB board
    --! @details the data path of the SWB board is first splitting the
    --! data from the FEBs into data, slow control and run control packages.
    --! The different paths are than assigned to the corresponding entities.
    --! The data is merged in time over all incoming FEBs. After this packages
    --! are build and the data is send of to the farm boars. The slow control
    --! data is saved in the PCIe memory and can be further used in the MIDAS
    --! system. The run control packages are used to control the run and give
    --! feedback to MIDAS if all FEBs started the run.

    --! counter readout
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    o_readregs(SWB_COUNTER_REGISTER_R) <= counter_mux(to_integer(unsigned(i_writeregs(SWB_COUNTER_REGISTER_W))))(31 downto 0);
    o_readregs(SWB_LINK_COUNTER_REGISTER_R) <= rate_mux(to_integer(unsigned(i_writeregs(SWB_COUNTER_REGISTER_W))));


    --! demerge data
    --! three types of data will be extracted from the links
    --! data => detector data
    --! sc => slow control packages
    --! rc => runcontrol packages
    g_demerge: FOR i in g_NLINKS_FEB_TOTL-1 downto 0 GENERATE
        feb_rx(i) <= work.mu3e.to_link(i_feb_rx(i).data, i_feb_rx(i).datak);
        e_data_demerge : entity work.swb_data_demerger
        port map (
            i_aligned           => '1',
            i_data              => feb_rx(i),

            o_data              => rx_data(i),
            o_sc                => rx_sc(i),
            o_rc                => rx_rc(i),
            o_fpga_id           => open,

            i_reset_n           => i_resets_n(RESET_BIT_EVENT_COUNTER),
            i_clk               => i_clk--,
        );
    end generate;


    --! run control used by MIDAS
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_run_control : entity work.run_control
    generic map (
        g_LINKS              => g_NLINKS_FEB_TOTL--,
    )
    port map (
        i_reset_ack_seen_n     => i_resets_n(RESET_BIT_RUN_START_ACK),
        i_reset_run_end_n      => i_resets_n(RESET_BIT_RUN_END_ACK),
        -- TODO: Write out padding 4kB at MIDAS Bank Builder if run end is done
        -- TODO: connect buffers emtpy from dma here
        -- o_all_run_end_seen => MIDAS Builder => i_buffer_empty
        i_buffers_empty        => (others => '1'),
        o_feb_merger_timeout   => o_readregs(CNT_FEB_MERGE_TIMEOUT_R),
        i_aligned              => (others => '1'),
        i_data                 => rx_rc,
        i_link_enable          => i_writeregs(FEB_ENABLE_REGISTER_W),
        i_addr                 => i_writeregs(RUN_NR_ADDR_REGISTER_W), -- ask for run number of FEB with this addr.
        i_run_number           => i_writeregs(RUN_NR_REGISTER_W)(23 downto 0),
        o_run_number           => o_readregs(RUN_NR_REGISTER_R), -- run number of i_addr
        o_runNr_ack            => o_readregs(RUN_NR_ACK_REGISTER_R), -- which FEBs have responded with run number in i_run_number
        o_run_stop_ack         => o_readregs(RUN_STOP_ACK_REGISTER_R),
        o_time_counter(31 downto 0)  => o_readregs(GLOBAL_TS_LOW_REGISTER_R),
        o_time_counter(63 downto 32) => o_readregs(GLOBAL_TS_HIGH_REGISTER_R),

        i_reset_n              => i_resets_n(RESET_BIT_GLOBAL_TS),
        i_clk                  => i_clk--,
    );


    --! SWB slow control
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_sc_main : entity work.swb_sc_main
    generic map (
        NLINKS => g_NLINKS_FEB_TOTL--,
    )
    port map (
        i_length_we     => i_writeregs(SC_MAIN_ENABLE_REGISTER_W)(0),
        i_length        => i_writeregs(SC_MAIN_LENGTH_REGISTER_W)(15 downto 0),
        i_mem_data      => i_wmem_rdata,
        o_mem_addr      => o_wmem_addr,
        o_mem_data      => o_feb_tx,
        o_done          => o_readregs(SC_MAIN_STATUS_REGISTER_R)(SC_MAIN_DONE),
        o_state         => o_readregs(SC_STATE_REGISTER_R)(27 downto 0),

        i_reset_n       => i_resets_n(RESET_BIT_SC_MAIN),
        i_clk           => i_clk--,
    );

    e_sc_secondary : entity work.swb_sc_secondary
    generic map (
        NLINKS      => g_NLINKS_FEB_TOTL,
        skip_init   => g_SC_SEC_SKIP_INIT--,
    )
    port map (
        i_link_enable           => i_writeregs(FEB_ENABLE_REGISTER_W)(g_NLINKS_FEB_TOTL-1 downto 0),
        i_link_data             => rx_sc,

        o_mem_addr              => o_rmem_addr,
        o_mem_addr_finished     => o_readregs(MEM_WRITEADDR_LOW_REGISTER_R)(15 downto 0),
        o_mem_data              => o_rmem_wdata,
        o_mem_we                => o_rmem_we,

        o_state                 => o_readregs(SC_STATE_REGISTER_R)(31 downto 28),

        i_reset_n               => i_resets_n(RESET_BIT_SC_SECONDARY),
        i_clk                   => i_clk--,
    );


    --------------------------------------------------
    -- histogramming for QC
    --------------------------------------------------
    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        histo_rx_selected <= work.mu3e.LINK32_IDLE;
    elsif rising_edge(i_clk) then
        histo_rx_selected <= rx_data(histo_selected_link);
    end if;
    end process;

    histo_selected_link <= to_integer(unsigned(i_writeregs(SWB_HISTO_LINK_SELECT_REGISTER_W)));
    histo_select_chip   <= to_integer(unsigned(i_writeregs(SWB_HISTO_CHIP_SELECT_REGISTER_W)));

    qc_histos_inst: entity work.qc_histos
    port map (
        i_data    => histo_rx_selected,
        i_chip_sel=> histo_select_chip,
        i_raddr   => i_writeregs(SWB_HISTO_ADDR_REGISTER_W),
        o_rdata   => o_readregs(SWB_HISTOS_DATA_REGISTER_R),
        i_zeromem => i_writeregs(SWB_ZERO_HISTOS_REGISTER_W)(1),
        i_ena     => i_writeregs(SWB_ZERO_HISTOS_REGISTER_W)(0),
        i_reset_n => i_reset_n,
        i_clk     => i_clk--,
    );


    --! Mapping Signals
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    process(i_clk, i_reset_n)
        variable selected_mask : std_logic_vector(31 downto 0);
    begin
    if ( i_reset_n /= '1' ) then
        data_path_reset_n <= '0';
        opq_reset_n <= '0';
        dma_reset_n <= '0';
        mask_n <= (others => '0');
        debug_mask_generic_w <= (others => '0');
        debug_mask_scifi_w <= (others => '0');
        debug_selected_link_mask_w <= (others => '0');
        debug_readout_state_w <= (others => '0');
        debug_mask_select_generic <= '0';
        debug_mask_select_scifi <= '0';
        use_opq_merge <= '0';
    elsif rising_edge(i_clk) then
        selected_mask := i_writeregs(SWB_GENERIC_MASK_REGISTER_W);
        if ( i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SCIFI) = '1' ) then
            selected_mask := i_writeregs(SWB_LINK_MASK_SCIFI_REGISTER_W);
        end if;
        data_path_reset_n <= i_resets_n(RESET_BIT_DATA_PATH);
        opq_reset_n <= data_path_reset_n;
        dma_reset_n <= data_path_reset_n;
        mask_n <= x"00000000" & selected_mask;
        debug_mask_generic_w <= i_writeregs(SWB_GENERIC_MASK_REGISTER_W);
        debug_mask_scifi_w <= i_writeregs(SWB_LINK_MASK_SCIFI_REGISTER_W);
        debug_selected_link_mask_w <= selected_mask;
        debug_readout_state_w <= i_writeregs(SWB_READOUT_STATE_REGISTER_W);
        debug_mask_select_generic <= i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GENERIC) or
                                     i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK);
        debug_mask_select_scifi <= i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SCIFI);
        use_opq_merge <= i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER);
    end if;
    end process;

    --! MuSiP data path
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_data_gen_link : entity work.data_generator_a10
    generic map (
        DATA_TYPE => MUPIX_HEADER_ID--,
    )
    port map (
        i_enable            => i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK),
        i_seed              => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W)(15 downto 0),
        o_data              => gen_link,
        i_slow_down         => i_writeregs(DATAGENERATOR_DIVIDER_REGISTER_W),
        o_state             => data_gen_state,

        i_reset_n           => i_resets_n(RESET_BIT_DATAGEN),
        i_clk               => i_clk--,
    );
    counter_mux(13)(31 downto 0) <= x"0000000" & data_gen_state;
    counter_mux(13)(63 downto 32) <= (others => '0');
    gen_link_decoded <= work.mu3e.to_link(gen_link.data, gen_link.datak);

    gen_link_data : FOR i in 0 to 3 GENERATE

        process(i_clk, i_reset_n)
        begin
        if ( i_reset_n /= '1' ) then
            rx_data_sim(i) <= work.mu3e.LINK32_IDLE;
        elsif rising_edge(i_clk) then
            if ( i_writeregs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GEN_LINK) = '1' ) then
                rx_data_sim(i) <= gen_link_decoded;
            else
                rx_data_sim(i) <= rx_data(i);
            end if;
        end if;
        end process;

    END GENERATE;

    g_opq_ingress_mask : for i in 0 to 3 generate
    begin
        rx_data_sim_opq(i) <= rx_data_sim(i) when mask_n(i) = '1' else work.mu3e.LINK32_IDLE;
    end generate;

    e_ingress_egress_adaptor : entity work.ingress_egress_adaptor
    port map (
        enable             => use_opq_merge,
        rx_ingress         => rx_data_sim_opq,
        rx_egress          => rx_data_sim_merged,
        opq_egress_ready   => opq_dma_ready,
        opq_egress_data    => opq_egress_data,
        opq_egress_datak   => opq_egress_datak,
        opq_egress_valid   => opq_egress_valid,
        opq_egress_sop     => opq_egress_sop,
        opq_egress_eop     => opq_egress_eop,
        reset_n            => opq_reset_n,
        clk                => i_clk--,
    );

    p_opq_dma_input_pipe : process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( dma_reset_n /= '1' ) then
            rx_data_sim_merged_r    <= (others => work.mu3e.LINK32_IDLE);
            opq_dma_input_data      <= (others => '0');
            opq_dma_input_datak     <= (others => '0');
            opq_dma_input_valid     <= '0';
            opq_dma_input_sop       <= '0';
            opq_dma_input_eop       <= '0';
        else
            rx_data_sim_merged_r    <= rx_data_sim_merged;
            opq_dma_input_data      <= opq_egress_data;
            opq_dma_input_datak     <= opq_egress_datak;
            opq_dma_input_valid     <= opq_egress_valid and opq_dma_ready;
            opq_dma_input_sop       <= opq_egress_sop and opq_dma_ready;
            opq_dma_input_eop       <= opq_egress_eop and opq_dma_ready;
        end if;
    end if;
    end process;

    o_opq_data  <= opq_dma_input_data;
    o_opq_datak <= opq_dma_input_datak;
    o_opq_valid <= opq_dma_input_valid;

    --! OPQ RDMA packer data path
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    -- LEGACY_DMA_DEAD: musip_mux_4_1, musip_event_builder, and the interim
    -- rdma_subsystem bridge are intentionally not instantiated in this path.
    e_opq_dma_pipeline : swb_opq_dma_pipeline
    port map (
        i_clk                  => i_clk,
        i_reset_n              => dma_reset_n,
        i_dma_enable           => use_opq_merge,
        i_dma_halffull         => i_dmamemhalffull,
        i_opq_data             => opq_egress_data,
        i_opq_datak            => opq_egress_datak,
        i_opq_valid            => opq_egress_valid,
        i_opq_sop              => opq_egress_sop,
        i_opq_eop              => opq_egress_eop,
        o_opq_ready            => opq_dma_ready,
        o_opq_egress_data      => open,
        o_opq_egress_valid     => open,
        o_opq_egress_sop       => open,
        o_opq_egress_eop       => open,
        o_dma_data             => opq_dma_data,
        o_dma_datak            => opq_dma_datak,
        o_dma_wen              => opq_dma_wren,
        o_end_of_event         => opq_dma_endofevent,
        o_input_word_cnt       => opq_dma_input_words,
        o_output_word_cnt      => opq_dma_output_words,
        o_event_cnt            => opq_dma_event_count,
        o_halt_cnt             => opq_dma_halt_count
    );

    -- Route the OPQ wire-frame packer output to the existing PCIe RDMA path.
    o_dma_data   <= opq_dma_data;
    o_dma_wren   <= opq_dma_wren;
    o_endofevent <= opq_dma_endofevent;

    opq_dma_status <= x"0000000" & use_opq_merge & i_dmamemhalffull & opq_dma_wren & opq_dma_endofevent;

    o_readregs(EVENT_BUILD_STATUS_REGISTER_R) <= opq_dma_status;
    o_readregs(EVENT_BUILD_IDLE_NOT_HEADER_R) <= opq_dma_input_words;
    o_readregs(EVENT_BUILD_SKIP_EVENT_DMA_R) <= opq_dma_output_words;
    o_readregs(EVENT_BUILD_CNT_EVENT_DMA_R) <= opq_dma_event_count;
    o_readregs(EVENT_BUILD_TAG_FIFO_FULL_R) <= opq_dma_halt_count;
    o_readregs(BUFFER_STATUS_REGISTER_R) <= opq_dma_status;
    o_readregs(DMA_CNT_WORDS_REGISTER_R) <= opq_dma_output_words;

    counter_mux(0)(31 downto 0) <= OPQ_DMA_PACKER_UID_CONST;
    counter_mux(0)(63 downto 32) <= (others => '0');
    counter_mux(1)(31 downto 0) <= opq_dma_status;
    counter_mux(1)(63 downto 32) <= (others => '0');
    counter_mux(2)(31 downto 0) <= opq_dma_input_words;
    counter_mux(2)(63 downto 32) <= (others => '0');
    counter_mux(3)(31 downto 0) <= opq_dma_output_words;
    counter_mux(3)(63 downto 32) <= (others => '0');
    counter_mux(4)(31 downto 0) <= opq_dma_event_count;
    counter_mux(4)(63 downto 32) <= (others => '0');
    counter_mux(5)(31 downto 0) <= opq_dma_halt_count;
    counter_mux(5)(63 downto 32) <= (others => '0');
    counter_mux(6) <= (others => '0');
    counter_mux(7) <= (others => '0');
    counter_mux(8) <= (others => '0');
    counter_mux(9) <= (others => '0');
    counter_mux(10) <= (others => '0');
    counter_mux(11) <= (others => '0');
    counter_mux(12) <= (others => '0');

    rate_mux(0) <= opq_dma_status;
    rate_mux(1) <= opq_dma_input_words;
    rate_mux(2) <= opq_dma_output_words;
    rate_mux(3) <= opq_dma_event_count;
    rate_mux(4) <= opq_dma_halt_count;
    rate_mux(5) <= (others => '0');
    rate_mux(6) <= (others => '0');
    rate_mux(7) <= (others => '0');
    rate_mux(8) <= (others => '0');
    rate_mux(9) <= (others => '0');
    rate_mux(10) <= (others => '0');
    rate_mux(11) <= (others => '0');
    rate_mux(12) <= (others => '0');

end architecture;
