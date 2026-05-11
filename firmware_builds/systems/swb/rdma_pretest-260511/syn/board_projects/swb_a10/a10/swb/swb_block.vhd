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
    signal rdma_reset_n : std_logic;
    attribute altera_attribute : string;
    attribute altera_attribute of opq_reset_n : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name GLOBAL_SIGNAL OFF";
    attribute altera_attribute of rdma_reset_n : signal is "-name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name GLOBAL_SIGNAL OFF";

    signal rdma_csr_rdata : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_csr_uid : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_csr_status : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_cnt_rqe_consumed : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_cnt_cqe_posted : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_cnt_bytes_written : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_cnt_opq_input_w : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_cnt_halt : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_cnt_eoe_observed : std_logic_vector(31 downto 0) := (others => '0');
    signal rdma_host_stub_status : std_logic_vector(31 downto 0) := (others => '0');

    component swb_rdma_subsystem_bridge is
    port (
        clk                    : in  std_logic;
        reset_n                : in  std_logic;
        enable                 : in  std_logic;
        opq_data               : in  std_logic_vector(31 downto 0);
        opq_datak              : in  std_logic_vector(3 downto 0);
        opq_valid              : in  std_logic;
        opq_sop                : in  std_logic;
        opq_eop                : in  std_logic;
        csr_addr               : in  std_logic_vector(7 downto 0);
        csr_wdata              : in  std_logic_vector(31 downto 0);
        csr_write              : in  std_logic;
        csr_rdata              : out std_logic_vector(31 downto 0);
        csr_uid                : out std_logic_vector(31 downto 0);
        csr_status             : out std_logic_vector(31 downto 0);
        cnt_rqe_consumed       : out std_logic_vector(31 downto 0);
        cnt_cqe_posted         : out std_logic_vector(31 downto 0);
        cnt_bytes_written      : out std_logic_vector(31 downto 0);
        cnt_opq_input_w        : out std_logic_vector(31 downto 0);
        cnt_halt               : out std_logic_vector(31 downto 0);
        cnt_eoe_observed       : out std_logic_vector(31 downto 0);
        host_stub_status       : out std_logic_vector(31 downto 0);
        o_dma_data             : out std_logic_vector(255 downto 0);
        o_dma_wren             : out std_logic;
        o_endofevent           : out std_logic
    );
    end component;

    signal rdma_dma_data     : std_logic_vector(255 downto 0) := (others => '0');
    signal rdma_dma_wren     : std_logic := '0';
    signal rdma_endofevent   : std_logic := '0';

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
    begin
    if ( i_reset_n /= '1' ) then
        data_path_reset_n <= '0';
        opq_reset_n <= '0';
        rdma_reset_n <= '0';
        mask_n <= (others => '0');
        use_opq_merge <= '0';
    elsif rising_edge(i_clk) then
        data_path_reset_n <= i_resets_n(RESET_BIT_DATA_PATH);
        opq_reset_n <= data_path_reset_n;
        rdma_reset_n <= data_path_reset_n;
        mask_n <= x"00000000" & i_writeregs(SWB_GENERIC_MASK_REGISTER_W);
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
        enable      => use_opq_merge,
        rx_ingress  => rx_data_sim_opq,
        rx_egress   => rx_data_sim_merged,
        reset_n     => opq_reset_n,
        clk         => i_clk--,
    );

    p_rdma_opq_input_pipe : process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( rdma_reset_n /= '1' ) then
            rx_data_sim_merged_r <= (others => work.mu3e.LINK32_IDLE);
        else
            rx_data_sim_merged_r <= rx_data_sim_merged;
        end if;
    end if;
    end process;

    o_opq_data  <= rx_data_sim_merged_r(0).data;
    o_opq_datak <= rx_data_sim_merged_r(0).datak;
    o_opq_valid <= not rx_data_sim_merged_r(0).idle;

    --! RDMA post-OPQ data path
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_rdma_subsystem_bridge : swb_rdma_subsystem_bridge
    port map (
        clk                    => i_clk,
        reset_n                => rdma_reset_n,
        enable                 => use_opq_merge,
        opq_data               => rx_data_sim_merged_r(0).data,
        opq_datak              => rx_data_sim_merged_r(0).datak,
        opq_valid              => not rx_data_sim_merged_r(0).idle,
        opq_sop                => rx_data_sim_merged_r(0).sop,
        opq_eop                => rx_data_sim_merged_r(0).eop,
        csr_addr               => i_writeregs(SWB_LOOKUP_CTRL_REGISTER_W)(7 downto 0),
        csr_wdata              => i_writeregs(SWB_LOOKUP_DS_CTRL_REGISTER_W),
        csr_write              => i_regwritten(SWB_LOOKUP_DS_CTRL_REGISTER_W),
        csr_rdata              => rdma_csr_rdata,
        csr_uid                => rdma_csr_uid,
        csr_status             => rdma_csr_status,
        cnt_rqe_consumed       => rdma_cnt_rqe_consumed,
        cnt_cqe_posted         => rdma_cnt_cqe_posted,
        cnt_bytes_written      => rdma_cnt_bytes_written,
        cnt_opq_input_w        => rdma_cnt_opq_input_w,
        cnt_halt               => rdma_cnt_halt,
        cnt_eoe_observed       => rdma_cnt_eoe_observed,
        host_stub_status       => rdma_host_stub_status,
        o_dma_data             => rdma_dma_data,
        o_dma_wren             => rdma_dma_wren,
        o_endofevent           => rdma_endofevent
    );

    -- Route the rdma_subsystem AXI4-W -> DMA-FIFO bridge output to the legacy
    -- PCIe DMA0 path (i_pcie0_dma0_wdata/we/eoe on a10_block).
    o_dma_data   <= rdma_dma_data;
    o_dma_wren   <= rdma_dma_wren;
    o_endofevent <= rdma_endofevent;

    o_readregs(EVENT_BUILD_STATUS_REGISTER_R) <= rdma_csr_status;
    o_readregs(EVENT_BUILD_IDLE_NOT_HEADER_R) <= rdma_cnt_opq_input_w;
    o_readregs(EVENT_BUILD_SKIP_EVENT_DMA_R) <= rdma_cnt_bytes_written;
    o_readregs(EVENT_BUILD_CNT_EVENT_DMA_R) <= rdma_cnt_rqe_consumed;
    o_readregs(EVENT_BUILD_TAG_FIFO_FULL_R) <= rdma_cnt_cqe_posted;
    o_readregs(BUFFER_STATUS_REGISTER_R) <= rdma_cnt_halt;
    o_readregs(DMA_CNT_WORDS_REGISTER_R) <= rdma_cnt_eoe_observed;

    counter_mux(0)(31 downto 0) <= rdma_csr_uid;
    counter_mux(0)(63 downto 32) <= (others => '0');
    counter_mux(1)(31 downto 0) <= rdma_csr_status;
    counter_mux(1)(63 downto 32) <= (others => '0');
    counter_mux(2)(31 downto 0) <= rdma_cnt_rqe_consumed;
    counter_mux(2)(63 downto 32) <= (others => '0');
    counter_mux(3)(31 downto 0) <= rdma_cnt_cqe_posted;
    counter_mux(3)(63 downto 32) <= (others => '0');
    counter_mux(4)(31 downto 0) <= rdma_cnt_bytes_written;
    counter_mux(4)(63 downto 32) <= (others => '0');
    counter_mux(5)(31 downto 0) <= rdma_cnt_opq_input_w;
    counter_mux(5)(63 downto 32) <= (others => '0');
    counter_mux(6)(31 downto 0) <= rdma_cnt_halt;
    counter_mux(6)(63 downto 32) <= (others => '0');
    counter_mux(7)(31 downto 0) <= rdma_cnt_eoe_observed;
    counter_mux(7)(63 downto 32) <= (others => '0');
    counter_mux(8)(31 downto 0) <= rdma_csr_rdata;
    counter_mux(8)(63 downto 32) <= (others => '0');
    counter_mux(9)(31 downto 0) <= rdma_host_stub_status;
    counter_mux(9)(63 downto 32) <= (others => '0');
    counter_mux(10) <= (others => '0');
    counter_mux(11) <= (others => '0');
    counter_mux(12) <= (others => '0');

    rate_mux(0) <= rdma_csr_status;
    rate_mux(1) <= rdma_cnt_rqe_consumed;
    rate_mux(2) <= rdma_cnt_cqe_posted;
    rate_mux(3) <= rdma_cnt_bytes_written;
    rate_mux(4) <= rdma_cnt_opq_input_w;
    rate_mux(5) <= rdma_cnt_halt;
    rate_mux(6) <= rdma_cnt_eoe_observed;
    rate_mux(7) <= rdma_host_stub_status;
    rate_mux(8) <= (others => '0');
    rate_mux(9) <= (others => '0');
    rate_mux(10) <= (others => '0');
    rate_mux(11) <= (others => '0');
    rate_mux(12) <= (others => '0');

end architecture;
