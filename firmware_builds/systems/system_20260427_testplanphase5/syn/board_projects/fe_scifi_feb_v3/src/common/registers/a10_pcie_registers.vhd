-- register map for a10

library ieee;
use ieee.std_logic_1164.all;

package a10_pcie_registers is

    constant LED_REGISTER_W                                 :  integer := 16#00#; -- DOC: Used to change LEDs on the boards | FARM
    constant RESET_REGISTER_W                               :  integer := 16#01#; -- DOC: Reset Register | ALL
        constant RESET_BIT_ALL                                  :  integer := 0;  -- DOC: Reset bit to reset all | ALL
        constant RESET_BIT_DATAGEN                              :  integer := 1;  -- DOC: Reset bit for the datagenerator which is generating the link data from FEBs | SWB
        constant RESET_BIT_SWB_STREAM_MERGER                    :  integer := 2;  -- DOC: Reset Round Robin Merger | SWB
        constant RESET_BIT_SWB_TIME_MERGER                      :  integer := 3;  -- DOC: Reset Time Merger | SWB
        constant RESET_BIT_RECEIVER                             :  integer := 4;  -- DOC: Not used at the moment | ALL
        constant RESET_BIT_DATAFIFO                             :  integer := 5;  -- DOC: Not used at the moment | ALL
        constant RESET_BIT_FIFOPLL                              :  integer := 6;  -- DOC: Not used at the moment | ALL
        constant RESET_BIT_SC_SECONDARY                         :  integer := 7;  -- DOC: Reset bit for the slowcontrol secondary | SWB
        constant RESET_BIT_SC_MAIN                              :  integer := 8;  -- DOC: Reset bit for the slowcontrol main | SWB
        constant RESET_BIT_PCIE_LOCAL                           :  integer := 9;  -- DOC: Not used at the moment | ALL
        constant RESET_BIT_TOP_PROC                             :  integer := 10; -- DOC: Not used at the moment | ALL
        constant RESET_BIT_PCIE_APPl                            :  integer := 12; -- DOC: Not used at the moment | ALL
        constant RESET_BIT_EVENT_COUNTER                        :  integer := 13; -- DOC: Reset bit for the swb_data_demerger | SWB
        constant RESET_BIT_DMA_EVAL                             :  integer := 14; -- DOC: Reset bit for DMA evaluationg / monitoring for PCIe 0 | ALL
        constant RESET_BIT_LINK_TEST                            :  integer := 15; -- DOC: Not used at the moment | ALL
        constant RESET_BIT_RUN_START_ACK                        :  integer := 16; -- DOC: Rest bit for seeing the run ack in run_control | SWB
        constant RESET_BIT_RUN_END_ACK                          :  integer := 17; -- DOC: Rest bit for seeing the run end in run_control | SWB
        constant RESET_BIT_NIOS                                 :  integer := 18; -- DOC: Not used at the moment | ALL
        constant RESET_BIT_DDR                                  :  integer := 19; -- DOC: Reset bit for DDR control entitie | FARM
        constant RESET_BIT_DATAFLOW                             :  integer := 20; -- DOC: Not used at the moment | ALL
        constant RESET_BIT_LINK_MERGER                          :  integer := 21; -- DOC: Not used at the moment | ALL
        constant RESET_BIT_DATA_PATH                            :  integer := 22; -- DOC: Reset bit for the data path | SWB
        constant RESET_BIT_FARM_DATA_PATH                       :  integer := 23; -- DOC: Reset bit for the data path | FARM
        constant RESET_BIT_FARM_STREAM_MERGER                   :  integer := 24; -- DOC: Reset bit for farm stream merger | FARM
        constant RESET_BIT_FARM_TIME_MERGER                     :  integer := 25; -- DOC: Reset bit for farm time merger | FARM
        constant RESET_BIT_LINK_LOCKED                          :  integer := 26; -- DOC: Reset bit for link locked bit | SWB/FARM
        constant RESET_BIT_GLOBAL_TS                            :  integer := 27; -- DOC: Reset bit for global time counter | SWB/FARM
        constant RESET_BIT_FARM_BLOCK                           :  integer := 28; -- DOC: Reset bit for the data path | FARM
        constant RESET_BIT_PCIE                                 :  integer := 31; -- DOC: Not used at the moment | ALL

    constant DATAGENERATOR_REGISTER_W                       : integer := 16#02#; -- DOC: Register to control the datagenerator which is generating the link data from FEBs | SWB
        constant DATAGENERATOR_BIT_ENABLE                       : integer := 0;  -- DOC: Not used at the moment | SWB
        constant DATAGENERATOR_BIT_ENABLE_PIXEL                 : integer := 1;  -- DOC: Bit to enable pixel data | SWB
        constant DATAGENERATOR_BIT_ENABLE_FIBRE                 : integer := 2;  -- DOC: Bit to enable fibre data | SWB
        constant DATAGENERATOR_BIT_ENABLE_TILE                  : integer := 3;  -- DOC: Bit to enable tile data | SWB
        constant DATAGENERATOR_BIT_ENABLE_TEST                  : integer := 4;  -- DOC: Not used at the moment | SWB
        constant DATAGENERATOR_BIT_DMA_HALFFUL_MODE             : integer := 5;  -- DOC: Not used at the moment | SWB
        subtype DATAGENERATOR_FRACCOUNT_RANGE                   is integer range 15 downto 8; -- DOC: Not used at the moment | SWB
        subtype DATAGENERATOR_NPIXEL_RANGE                      is integer range 15 downto 8; -- DOC: Not used at the moment | SWB
        subtype DATAGENERATOR_NFIBRE_RANGE                      is integer range 23 downto 16; -- DOC: Not used at the moment | SWB
        subtype DATAGENERATOR_NTILE_RANGE                       is integer range 31 downto 24; -- DOC: Not used at the moment | SWB

    constant DATAGENERATOR_DIVIDER_REGISTER_W               : integer := 16#03#; -- DOC: Register to slow down the datagenerator which is generating the link data from FEBs | SWB
    constant KWORD_W                                        : integer := 16#04#; -- DOC: Not used at the moment | ALL
    constant DMA_CONTROL_W                                  : integer := 16#05#; -- DOC: Not used at the moment | ALL
        subtype DMA_CONTROL_COUNTER_RANGE                       is integer range 15 downto 0; -- DOC: Not used at the moment | ALL
    constant DMA_SLOW_DOWN_REGISTER_W                       : integer := 16#06#; -- DOC: Not used at the moment | ALL

    constant LINK_TEST_REGISTER_W                           : integer := 16#07#; -- DOC: Not used at the moment | ALL
    constant LINK_TEST_BIT_ENABLE                               : integer := 0;  -- DOC: Not used at the moment | ALL

    constant RUN_NR_REGISTER_W                              : integer := 16#08#; -- DOC: Register to write the current run number | SWB
    constant RUN_NR_ADDR_REGISTER_W                         : integer := 16#09#; -- DOC: Ask for run number of FEB with this addr | SWB
    constant FEB_ENABLE_REGISTER_W                          : integer := 16#0A#; -- DOC: Enable register for FEBs for run control and slowcontrol | SWB
    constant DATA_LINK_MASK_REGISTER_W                      : integer := 16#0B#; -- DOC: Not used at the moment | SWB
    constant GET_N_DMA_WORDS_REGISTER_W                     : integer := 16#0C#; -- DOC: Number of requested words which will be send via DMA | SWB & FARM
    constant SC_MAIN_ENABLE_REGISTER_W                      : integer := 16#0D#; -- DOC: Reg that the slowcontrol main only starts on a 0->1 transition | SWB
    constant SC_MAIN_LENGTH_REGISTER_W                      : integer := 16#0E#; -- DOC: Lenght (15 downto 0) for slowcontrol package | SWB
    constant DATA_LINK_MASK_REGISTER_2_W                    : integer := 16#0F#; -- DOC: Not used at the moment | SWB
    constant SWB_LINK_MASK_PIXEL_REGISTER_W                 : integer := 16#10#; -- DOC: Mask Pixel links | SWB
    constant SWB_LINK_MASK_SCIFI_REGISTER_W                 : integer := 16#11#; -- DOC: Mask Scifi links | SWB
    constant SWB_LINK_MASK_TILES_REGISTER_W                 : integer := 16#12#; -- DOC: Mask Tile links | SWB
    constant SWB_READOUT_STATE_REGISTER_W                   : integer := 16#13#; -- DOC: Readout state | SWB
        constant USE_BIT_GEN_LINK                               : integer := 0;  -- DOC: Readout state where link data is generated (for debugging) | SWB & FARM
        constant USE_BIT_STREAM                                 : integer := 1;  -- DOC: Readout state where link data is read out in round-robin | SWB & FARM
        constant USE_BIT_MERGER                                 : integer := 2;  -- DOC: Readout state where link data is time aligned (tree) | SWB & FARM
        constant USE_BIT_GEN_MERGER                             : integer := 4;  -- DOC: Readout state where the time aligned data is generated (for debugging) | SWB & FARM
        constant USE_BIT_FARM                                   : integer := 5;  -- DOC: Readout state where the data is send to the farm (1) else (0) it is readout via DMA on the SWB | SWB & FARM
        constant USE_BIT_TEST                                   : integer := 6;  -- DOC: Not used at the moment | SWB & FARM
        constant USE_BIT_PIXEL_US                               : integer := 7;  -- DOC: Readout state to only readout US pixel data via DMA (for debugging) | SWB & FARM
        constant USE_BIT_PIXEL_DS                               : integer := 8;  -- DOC: Readout state to only readout DS pixel data via DMA (for debugging) | SWB & FARM
        constant USE_BIT_SCIFI                                  : integer := 9;  -- DOC: Readout state to only readout scifi data via DMA (for debugging) | SWB & FARM
        constant USE_BIT_TEST_ERROR                             : integer := 10; -- DOC: Readout state for testing an error handling in the time merger using generated data | SWB & FARM
        constant USE_BIT_DDR                                    : integer := 11; -- DOC: Readout state for using the ddr memory | FARM
        constant USE_BIT_ALL                                    : integer := 12; -- DOC: Readout state to only readout all data in round robin via DMA (for debugging) | SWB
        constant USE_BIT_TEST_DATA                              : integer := 13; -- DOC: Readout state where link data is real data from mem file (for simulation | SWB
        constant USE_BIT_SUBHDR_SUPPRESS                        : integer := 14; -- DOC: Readout state where subheaders are suppressed | SWB
        constant USE_BIT_HEAD_SUPPRESS                          : integer := 15; -- DOC: Readout state where headers are suppressed | SWB
        constant USE_BIT_INJECTION                              : integer := 16; -- DOC: Readout state to injected data | SWB & FARM
        constant USE_BIT_WRITE_BUFFER_INJECTION                 : integer := 17; -- DOC: Readout state to injected data | SWB & FARM
    constant SWB_READOUT_LINK_REGISTER_W                    : integer := 16#14#; -- DOC: Not used at the moment | SWB & FARM
    constant SWB_COUNTER_REGISTER_W                         : integer := 16#15#; -- DOC: Addr register to readout counter values from the SWB, to have more information about the counter look at a10_counter.md | SWB

    constant FARM_READOUT_STATE_REGISTER_W                  : integer := 16#16#; -- DOC: Readout state | FARM
    constant FARM_DATA_TYPE_REGISTER_W                      : integer := 16#17#; -- DOC: Data type for readout | FARM
        subtype FARM_DATA_TYPE_ADDR_RANGE                       is integer range 1 downto 0;    -- DOC: Data type: "00" = pixel, "01" = scifi, "10" = tiles | FARM
        subtype FARM_EVENT_ID_ADDR_RANGE                        is integer range 17 downto 2;    -- DOC: midas event id | FARM
    constant INJECTION_WAIT_W                               : integer := 16#18#; -- DOC: Wait counter for injection buffer readout | SWB & FARM

    constant SWB_SUBHEAD_SUPPRESS_REGISTER_W                : integer := 16#18#; -- DOC: subheader suppression per link | SWB
    constant SWB_HEAD_SUPPRESS_REGISTER_W                   : integer := 16#19#; -- DOC: header suppression per link | SWB
    constant SWB_ZERO_HISTOS_REGISTER_W                     : integer := 16#1A#; -- DOC: todo | SWB
    constant SWB_HISTO_ADDR_REGISTER_W                      : integer := 16#1B#; -- DOC: todo | SWB
    constant SWB_HISTO_CHIP_SELECT_REGISTER_W               : integer := 16#1C#; -- DOC: todo | SWB
    constant SWB_HISTO_LINK_SELECT_REGISTER_W               : integer := 16#1D#; -- DOC: todo | SWB

    constant DDR_CONTROL_W                                 : integer := 16#20#; -- DOC: Control register for the ddr_memory_controller | FARM
        constant DDR_BIT_ENABLE_A                              : integer := 0;  -- DOC: Enable statemachine of DDR-A | FARM
        constant DDR_BIT_COUNTERTEST_A                         : integer := 1;  -- DOC: Enable counter test (1) or dataflow (0) of DDR-A | FARM
        subtype  DDR_COUNTERSEL_RANGE_A                        is integer range 15 downto 14; -- DOC: "01" -> get poserr_reg, "10" -> get counterr_reg else cur time counter written to DDR | FARM
        subtype  DDR_RANGE_A                                   is integer range 15 downto 0; -- DOC: range for ddr a | FARM
        constant DDR_BIT_ENABLE_B                              : integer := 16;  -- DOC: Enable statemachine of DDR-B | FARM
        constant DDR_BIT_COUNTERTEST_B                         : integer := 17;  -- DOC: Enable counter test (1) or dataflow (0) of DDR-B | FARM
        subtype  DDR_COUNTERSEL_RANGE_B                        is integer range 31 downto 30; -- DOC: "01" -> get poserr_reg, "10" -> get counterr_reg else cur time counter written to DDR | FARM
        subtype  DDR_RANGE_B                                   is integer range 31 downto 16; -- DOC: range for ddr b | FARM
    constant FARM_LINK_MASK_REGISTER_W                      : integer := 16#21#; -- DOC: Mask Farm links | FARM

    constant DATA_REQ_A_W                                   : integer := 16#22#; -- DOC: Register for requesting subheaders from DDR, for SUBTS in GPU_SUBTS_SEL DO writereg(SUBTS) | FARM
    constant DATA_REQ_B_W                                   : integer := 16#23#; -- DOC: Register for requesting subheaders from DDR, for SUBTS in GPU_SUBTS_SEL DO writereg(SUBTS) | FARM
    constant DATA_TSBLOCK_DONE_W                            : integer := 16#24#; -- DOC: dynamic limit when we change from writing to reading (15 downto 8 from 35 downto 4 of the 48b TS) | FARM
    constant FARM_ID_REGISTER_W                             : integer := 16#25#; -- DOC: Farm ID written to the reserved filed of the MIDAS bank | FARM
    constant FARM_REQ_EVENTS_W                              : integer := 16#26#; -- DOC: total number of requested events (should match to len(DATA_REQ_A/B_W) from GPU selection | FARM
    constant FARM_CTL_REGISTER_W                            : integer := 16#27#;
        constant USE_BIT_PIXEL_ONLY                             : integer := 0;
        constant USE_BIT_SCIFI_ONLY                             : integer := 1;

    constant RESET_LINK_CTL_REGISTER_W                      : integer := 16#28#;
        subtype  RESET_LINK_COMMAND_RANGE                       is integer range 7 downto 0;
        subtype  RESET_LINK_FEB_RANGE                           is integer range 31 downto 29;
    constant RESET_LINK_RUN_NUMBER_REGISTER_W               : integer := 16#29#;
    constant FARM_EVENT_ID_REGISTER_W                       : integer := 16#2A#; -- DOC: set MIDAS event id (15 downto 0) and trigger mask (31 downto 16) | FARM
    constant FARM_GPU_EVENT_SIZE_W                          : integer := 16#2B#; -- DOC: set the size of the GPU event (default: 166666.67 x 96b = 2MB | 0x28B0A x 96b + 64b = 2MB) | FARM
    constant FARM_GPU_EVENT_PADDING_W                       : integer := 16#2C#; -- DOC: set the padding size in the GPU event (default: 1000=0x3E8) | FARM
    constant CLK_LINK_0_REGISTER_W                          : integer := 16#30#;
    constant CLK_LINK_1_REGISTER_W                          : integer := 16#31#;
    constant CLK_LINK_2_REGISTER_W                          : integer := 16#32#;
    constant CLK_LINK_3_REGISTER_W                          : integer := 16#33#;
    constant CLK_LINK_REST_REGISTER_W                       : integer := 16#34#;
        subtype  REST_0_RANGE                                   is integer range  7 downto  0;
        subtype  REST_1_RANGE                                   is integer range 15 downto  8;
        subtype  REST_2_RANGE                                   is integer range 23 downto 16;
        subtype  REST_3_RANGE                                   is integer range 31 downto 24;
    constant GET_N_GPU_EVENTS_REGISTER_W                    : integer := 16#35#; -- DOC: Number of requested GPU events which will be send via DMA | FARM

    -- Registers above 0x36 are in use for the PCIe controller/DMA
    constant DMA2_CTRL_ADDR_LOW_REGISTER_W                  : integer := 16#36#;
    constant DMA2_CTRL_ADDR_HI_REGISTER_W                   : integer := 16#37#;
    constant DMA_REGISTER_W                                 : integer := 16#38#;
        constant DMA_BIT_ENABLE                             : integer := 0;
        constant DMA_BIT_NOW                                : integer := 1;
        constant DMA_BIT_ADDR_WRITE_ENABLE                  : integer := 2;
        constant DMA_BIT_ENABLE_INTERRUPTS                  : integer := 3;
        constant DMA2_BIT_ENABLE                            : integer := 16;
        constant DMA2_BIT_NOW                               : integer := 17;
        constant DMA2_BIT_ADDR_WRITE_ENABLE                 : integer := 18;
        constant DMA2_BIT_ENABLE_INTERRUPTS                 : integer := 19;

    constant DMA_CTRL_ADDR_LOW_REGISTER_W                   : integer := 16#39#;
    constant DMA_CTRL_ADDR_HI_REGISTER_W                    : integer := 16#3A#;
    constant DMA_DATA_ADDR_LOW_REGISTER_W                   : integer := 16#3B#;
    constant DMA_DATA_ADDR_HI_REGISTER_W                    : integer := 16#3C#;
    constant DMA_RAM_LOCATION_NUM_PAGES_REGISTER_W          : integer := 16#3D#;
        subtype DMA_RAM_LOCATION_RANGE                          is integer range 31 downto 20;
        subtype DMA_NUM_PAGES_RANGE                             is integer range 19 downto 0;
    constant DMA_NUM_ADDRESSES_REGISTER_W                   : integer := 16#3E#;
        subtype DMA_NUM_ADDRESSES_RANGE                         is integer range 11 downto 0;
        subtype DMA2_NUM_ADDRESSES_RANGE                        is integer range 27 downto 16;

    --- Read register Map
    constant PLL_REGISTER_R                                 : integer := 16#00#;
        subtype  DIPSWITCH_RANGE                                is integer range 1 downto 0;
    constant VERSION_REGISTER_R                             : integer := 16#01#;
        subtype  VERSION_RANGE                                  is integer range 27 downto 0;
    constant EVENTCOUNTER_REGISTER_R                        : integer := 16#02#;
    constant EVENTCOUNTER64_REGISTER_R                      : integer := 16#03#;
    constant TIMECOUNTER_LOW_REGISTER_R                     : integer := 16#04#;
    constant TIMECOUNTER_HIGH_REGISTER_R                    : integer := 16#05#;
    constant MEM_WRITEADDR_LOW_REGISTER_R                   : integer := 16#06#;
    constant MEM_WRITEADDR_HIGH_REGISTER_R                  : integer := 16#07#;
    constant EVENT2COUNTER64_REGISTER_R                     : integer := 16#08#;
    constant inaddr32_r                                     : integer := 16#09#;
    constant inaddr32_w                                     : integer := 16#10#;
    constant CNT_PLL_156_REGISTER_R                         : integer := 16#0A#;
    constant CNT_PLL_250_REGISTER_R                         : integer := 16#0B#;
    constant SWB_HISTOS_DATA_REGISTER_R                     : integer := 16#0C#;
    constant DMA_STATUS_R                                   : integer := 16#11#;
        constant DMA_DATA_WEN                                   : integer:= 0;
        constant DMA_CONTROL_WEN                                : integer:= 1;
    constant PLL_LOCKED_REGISTER_R                          : integer := 16#12#;
    constant DEBUG_SC                                       : integer := 16#13#;
    constant DMA_HALFFUL_REGISTER_R                         : integer := 16#14#;
    constant DMA_NOTHALFFUL_REGISTER_R                      : integer := 16#15#;
    constant DMA_ENDEVENT_REGISTER_R                        : integer := 16#16#;
    constant DMA_NOTENDEVENT_REGISTER_R                     : integer := 16#17#;
    constant RUN_NR_ACK_REGISTER_R                          : integer := 16#18#;
    constant RUN_NR_REGISTER_R                              : integer := 16#19#;
    constant RUN_STOP_ACK_REGISTER_R                        : integer := 16#1A#;
    constant BUFFER_STATUS_REGISTER_R                       : integer := 16#1B#;
    constant EVENT_BUILD_STATUS_REGISTER_R                  : integer := 16#1C#;
        constant EVENT_BUILD_DONE                               : integer:= 0;
    constant CNT_FIFO_ALMOST_FULL_R                         : integer := 16#1D#;
    constant CNT_TAG_FIFO_FULL_R                            : integer := 16#1E#;
    constant CNT_RAM_FULL_R                                 : integer := 16#1F#;
    constant CNT_STREAM_FIFO_FULL_R                         : integer := 16#20#;
    constant CNT_DC_LINK_FIFO_FULL_R                        : integer := 16#21#;
    constant CNT_SKIP_EVENT_LINK_FIFO_R                     : integer := 16#22#;
    constant CNT_SKIP_EVENT_DMA_RAM_R                       : integer := 16#23#;
    constant CNT_IDLE_NOT_HEADER_R                          : integer := 16#24#;
    constant CNT_FEB_MERGE_TIMEOUT_R                        : integer := 16#25#;
    constant DDR_STATUS_R                                   : integer := 16#26#;
        constant DDR_BIT_CAL_SUCCESS                            : integer := 0;
        constant DDR_BIT_CAL_FAIL                               : integer := 1;
        constant DDR_BIT_RESET_N                                : integer := 2;
        constant DDR_BIT_READY                                  : integer := 3;
        constant DDR_BIT_TEST_WRITING                           : integer := 4;
        constant DDR_BIT_TEST_READING                           : integer := 5;
        constant DDR_BIT_TEST_DONE                              : integer := 6;
    constant DDR_ERR_R                                      : integer := 16#27#;
    constant DATA_TSBLOCKS_R                                : integer := 16#28#;
    constant SC_MAIN_STATUS_REGISTER_R                      : integer := 16#29#;
        constant SC_MAIN_DONE                                   : integer := 0;
    constant GLOBAL_TS_LOW_REGISTER_R                       : integer := 16#2A#;
    constant GLOBAL_TS_HIGH_REGISTER_R                      : integer := 16#2B#;
    constant SERIAL_NUM_REGISTER_R                          : integer := 16#2C#;
    constant DDR_CLK_CNT_R                                  : integer := 16#30#;
    constant SC_STATE_REGISTER_R                            : integer := 16#31#;
    constant DMA_CNT_WORDS_REGISTER_R                       : integer := 16#32#;
    constant SWB_COUNTER_REGISTER_R                         : integer := 16#33#;
    constant RESET_LINK_STATUS_REGISTER_R                   : integer := 16#34#;
    constant LINK_LOCKED_LOW_REGISTER_R                     : integer := 16#35#;
    constant LINK_LOCKED_HIGH_REGISTER_R                    : integer := 16#36#;

    -- Registers above 0x38 are in use for the PCIe controller/DMA
    constant DMA_STATUS_REGISTER_R                          : integer := 16#38#;
    constant DMA_DATA_ADDR_LOW_REGISTER_R                   : integer := 16#39#;
    constant DMA_DATA_ADDR_HI_REGISTER_R                    : integer := 16#3A#;
    constant DMA_NUM_PAGES_REGISTER_R                       : integer := 16#3B#;
    constant DMA2_STATUS_REGISTER_R                         : integer := 16#3C#;
    constant DMA2_DATA_ADDR_LOW_REGISTER_R                  : integer := 16#3D#;
    constant DMA2_DATA_ADDR_HI_REGISTER_R                   : integer := 16#3E#;
    constant DMA2_NUM_PAGES_REGISTER_R                      : integer := 16#3F#;

end package;
