-- register map for a10 counters

library ieee;
use ieee.std_logic_1164.all;

package a10_counters is

    -- SWB Counters
    -- debug readout counters
    constant SWB_BANK_BUILDER_IDLE_NOT_HEADER_CNT   :  integer := 16#00#;
    constant SWB_BANK_BUILDER_SKIP_EVENT_CNT        :  integer := 16#01#;
    constant SWB_BANK_BUILDER_EVENT_CNT             :  integer := 16#02#;
    constant SWB_BANK_BUILDER_TAG_FIFO_FULL_CNT     :  integer := 16#03#;
    constant SWB_DEBUG_RO_CNT                       :  integer := 16#04#;

    -- datapath counters
    constant SWB_STREAM_FIFO_FULL_CNT               :  integer := 16#00#;
    constant SWB_STREAM_DEBUG_FIFO_ALFULL_CNT       :  integer := 16#01#;
    constant DUMMY_0_CNT                            :  integer := 16#02#;
    constant DUMMY_1_CNT                            :  integer := 16#03#;
    constant DUMMY_2_CNT                            :  integer := 16#04#;
    constant DUMMY_3_CNT                            :  integer := 16#05#;
    constant SWB_EVENTS_TO_FARM_CNT                 :  integer := 16#06#;
    constant SWB_MERGER_DEBUG_FIFO_ALFULL_CNT       :  integer := 16#07#;
    constant SWB_DATAPATH_CNT                       :  integer := 16#08#;
    
    -- each layer (0, 1, 2) has for each merge counts
    -- layer0 (4 merge), layer1 (2 merge) layer0 (1 merge)
    constant SWB_MERGER_HEADER_CNT                  :  integer := 16#00#;
    constant SWB_MERGER_SHEADER_CNT                 :  integer := 16#01#;
    constant SWB_MERGER_HIT_CNT                     :  integer := 16#02#;
    constant SWB_TREE_CNT                           :  integer := 16#03#;
    -- at the moment this information is also in mudaq.vhd at N_LINKS_TREE
    constant SWB_LAYER0_OUT_CNT                     :  integer := 16#04#;
    constant SWB_LAYER1_OUT_CNT                     :  integer := 16#02#;
    constant SWB_LAYER2_OUT_CNT                     :  integer := 16#01#;

    -- link counters
    constant SWB_LINK_FIFO_ALMOST_FULL_CNT    :  integer := 16#00#;
    constant SWB_LINK_FIFO_FULL_CNT           :  integer := 16#01#;
    constant SWB_SKIP_EVENT_CNT               :  integer := 16#02#;
    constant SWB_EVENT_CNT                    :  integer := 16#03#;
    constant SWB_SUB_HEADER_CNT               :  integer := 16#04#;
    constant SWB_LINK_CNT                     :  integer := 16#05#;



    -- Farm counters
    -- link counters (0-14)
    constant FARM_LINK_FIFO_ALMOST_FULL_CNT    :  integer := 16#00#;
    constant FARM_LINK_FIFO_FULL_CNT           :  integer := 16#01#;
    constant FARM_SKIP_EVENT_CNT               :  integer := 16#02#;
    constant FARM_EVENT_CNT                    :  integer := 16#03#;
    constant FARM_SUB_HEADER_CNT               :  integer := 16#04#;
    constant FARM_LINK_CNT                     :  integer := 16#03#;
    
    -- event builder counters ddr memory (15-18)
    constant FARM_DDR_BUILDER_IDLE_NOT_HEADER_CNT   :  integer := 16#00#;
    constant FARM_DDR_BUILDER_SKIP_EVENT_CNT        :  integer := 16#01#;
    constant FARM_DDR_BUILDER_EVENT_CNT             :  integer := 16#02#;
    constant FARM_DDR_BUILDER_TAG_FIFO_FULL_CNT     :  integer := 16#03#;

    -- counter ddr (19-22)
    constant FARM_DDR_CNT_SKIP_EVENT_DMA    :  integer := 16#00#;
    constant FARM_DDR_A_ALMOST_FULL         :  integer := 16#01#;
    constant FARM_DDR_B_ALMOST_FULL         :  integer := 16#02#;
    constant FARM_DDR_DMA_HALFFULL          :  integer := 16#03#;

    -- bank builder without ddr (23-26)
    constant FARM_BANK_BUILDER_IDLE_NOT_HEADER_CNT   :  integer := 16#00#;
    constant FARM_BANK_BUILDER_SKIP_EVENT_CNT        :  integer := 16#01#;
    constant FARM_BANK_BUILDER_EVENT_CNT             :  integer := 16#02#;
    constant FARM_BANK_BUILDER_TAG_FIFO_FULL_CNT     :  integer := 16#03#;

end package;
