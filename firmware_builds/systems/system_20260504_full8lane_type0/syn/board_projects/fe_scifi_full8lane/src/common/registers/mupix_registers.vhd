-- Register Map
-- Note: 
-- write register, use naming scheme:       ***_REGISTER_W
-- read  register, use naming scheme:       ***_REGISTER_R
-- bit range     , use naming scheme:       ***_RANGE
-- single bit constant, use naming scheme:  ***_BIT

-- REGISTERS above 80: datapath

-- M.Mueller, November 2020

library ieee;
use ieee.std_logic_1164.all;

package mupix_registers is

--(x"60") --(start of the mp_datapath addr-space, 0x40-MUPIX_DATAPATH_ADDR_START is mp_ctrl )
constant MUPIX_DATAPATH_ADDR_START          : integer := 128;
constant MUPIX_LVDS_STATUS_BLOCK_LENGTH     : integer := 36;
--////////////////////////////////////////////--
--//////////////////REGISTER MAP//////////////--
--////////////////////////////////////////////--

-----------------------------------------------------------------
---- mupix ctrl (0x0400-0x0FFF)----------------------------------
-----------------------------------------------------------------

    constant BIAS_BIT                               :  integer := 0;        -- DOC: used wherever BIAS, CONF, VDAC and TDAC need order | MP_FEB
    constant CONF_BIT                               :  integer := 1;        -- DOC: used wherever BIAS, CONF, VDAC and TDAC need order | MP_FEB
    constant VDAC_BIT                               :  integer := 2;        -- DOC: used wherever BIAS, CONF, VDAC and TDAC need order | MP_FEB
    constant TDAC_BIT                               :  integer := 3;        -- DOC: used wherever BIAS, CONF, VDAC and TDAC need order | MP_FEB

    constant MP_CTRL_COMBINED_START_REGISTER_W      :  integer := 16#0400#; -- DOC: Used to send combined config data to the mupix, chip ID encoded in addr as regaddr + chipID | MP_FEB
    constant MP_CTRL_TDAC_START_REGISTER_W          :  integer := 16#0430#; -- DOC: Used to send TDAC to the mupix, chip ID encoded in addr as regaddr + chipID | MP_FEB
    constant MP_CTRL_CHIP_SELECT1_REGISTER_W        :  integer := 16#0460#; -- DOC: Used to specify the chip ID in case of direct SPI or direct register configuration | MP_FEB
    constant MP_CTRL_CHIP_SELECT2_REGISTER_W        :  integer := 16#0461#; -- DOC: Used to specify the chip ID in case of direct SPI or direct register configuration | MP_FEB

    constant MP_CTRL_BIAS_REGISTER_W                :  integer := 16#0462#; -- DOC: If you want to write the mupix BIAS reg only, send data here | MP_FEB
    constant MP_CTRL_CONF_REGISTER_W                :  integer := 16#0463#; -- DOC: If you want to write the mupix CONF reg only, send data here | MP_FEB
    constant MP_CTRL_VDAC_REGISTER_W                :  integer := 16#0464#; -- DOC: If you want to write the mupix VDAC reg only, send data here | MP_FEB

    constant MP_CTRL_SLOW_DOWN_REGISTER_W           :  integer := 16#0465#; -- DOC: Division factor for the mupix spi clk | MP_FEB

    constant MP_CTRL_SPI_BUSY_REGISTER_R            :  integer := 16#0466#; -- DOC: Indicates if the mupix spi is busy, do not send new data | MP_FEB
    constant MP_CTRL_DIRECT_SPI_ENABLE_REGISTER_W   :  integer := 16#0467#; -- DOC: Enable direct SPI configuration mode for mupix | MP_FEB
    constant MP_CTRL_SPI_ENABLE_REGISTER_W          :  integer := 16#0468#; -- DOC: Enable SPI configuration mode for mupix (direct spi needs to be disabled in this case) | MP_FEB
    constant MP_CTRL_DIRECT_SPI_BUSY_REGISTER_R     :  integer := 16#0469#; -- DOC: contains 1 bit for each spi bus, 1 if busy | MP_FEB
    constant MP_CTRL_DIRECT_SPI_START_REGISTER_W    :  integer := 16#046A#; -- DOC: Register for direct spi configuration mode, needs to be enabled first | MP_FEB
    constant MP_CTRL_DIRECT_SPI_CHIP_M_REGISTER_W   :  integer := 16#0480#; -- DOC: Register to set the chip mask when using direct spi mode | MP_FEB
    constant MP_CTRL_RESET_REGISTER_W               :  integer := 16#04A0#; -- DOC: write to this reg triggers a 1 cycle mp ctrl reset | MP_FEB
    constant MP_CTRL_RUN_TEST_REGISTER_W            :  integer := 16#04A1#; -- DOC: write to this reg triggers write of a TDAC test pattern | MP_FEB
    constant MP_CTRL_N_FREE_PAGES_REGISTER_R        :  integer := 16#04A2#; -- DOC: number of free TDAC pages | MP_FEB

    constant MP_CTRL_TESTRAM_RDATA_REGISTER_R        :  integer := 16#04A3#; -- DOC: number of free TDAC pages | MP_FEB
    constant MP_CTRL_TESTRAM_WADDR_REGISTER_W        :  integer := 16#04A4#; -- DOC: number of free TDAC pages | MP_FEB
    constant MP_CTRL_TESTRAM_RADDR_REGISTER_W        :  integer := 16#04A5#; -- DOC: number of free TDAC pages | MP_FEB
    constant MP_CTRL_TESTRAM_WDATA_REGISTER_W        :  integer := 16#04A6#; -- DOC: number of free TDAC pages | MP_FEB
    constant MP_CTRL_SLOW_CLK_SHIFT_REGISTER_W       :  integer := 16#04A7#; -- DOC: shift of the slow clock vs reset | MP_FEB
    constant MP_CTRL_SIN_INVERT_REGISTER_W           :  integer := 16#04A8#; -- DOC: invert sin | MP_FEB

    constant MP_CTRL_PIXEL_ADDR_REGISTER0_W          :  integer := 16#04A9#; -- DOC: set lower 8 chips each has 4 bits | MP_FEB
    constant MP_CTRL_PIXEL_ADDR_REGISTER1_W          :  integer := 16#04A9#; -- DOC: set upper 8 chips each has 4 bits | MP_FEB

-----------------------------------------------------------------
---- mupix datapath general (0x1300-0xFBFF)----------------------
-----------------------------------------------------------------
    constant MP_READOUT_MODE_REGISTER_W         :  integer := 16#1300#; -- DOC: to be removed | MP_FEB
        constant INVERT_TS_BIT                  :  integer := 0;        -- DOC: if set: TS is inverted | MP_FEB
        constant INVERT_TS2_BIT                 :  integer := 1;        -- DOC: if set: TS2 is inverted | MP_FEB
        constant GRAY_TS_BIT                    :  integer := 2;        -- DOC: if set: TS is grey-decoded | MP_FEB
        constant GRAY_TS2_BIT                   :  integer := 3;        -- DOC: if set: TS2 is grey-decoded | MP_FEB
        subtype  CHIP_ID_MODE_RANGE             is integer range 5 downto 4; -- DOC: bits to select different chip id numbering modes (not in use) | MP_FEB
        subtype  TOT_MODE_RANGE                 is integer range 8 downto 6; -- DOC: bits to select different TOT calculation modes (Default is to send TS2 as TOT, not in use) | MP_FEB
    constant MP_LVDS_LINK_MASK_REGISTER_W       :  integer := 16#1301#; -- DOC: masking of mupix lvds connections | MP_FEB
    constant MP_LVDS_LINK_MASK2_REGISTER_W      :  integer := 16#1302#; -- DOC: masking of mupix lvds connections | MP_FEB
    constant MP_DATA_GEN_CONTROL_REGISTER_W     :  integer := 16#1303#; -- DOC: controls the mupix data generator | MP_FEB
        subtype  MP_DATA_GEN_HIT_P_RANGE        is integer range 3 downto 0; -- DOC: generator hit output probability, 1/(2^(MP_DATA_GEN_HIT_P_RANGE+1)) for each cycle where a hit could be send | MP_FEB
        constant MP_DATA_GEN_FULL_STEAM_BIT     :  integer := 4;        -- DOC: if set: generator hit output probability is 1 | MP_FEB
        constant MP_DATA_GEN_SYNC_BIT           :  integer := 5;        -- DOC: if set: generator seed is the same on all boards else: generator seed depends on FPGA_ID | MP_FEB
        constant MP_DATA_GEN_ENGAGE_BIT         :  integer := 16;       -- DOC: if set: use hits from generator, datapath is not connected to link | MP_FEB
        constant MP_DATA_GEN_SORT_IN_BIT        :  integer := 17;       -- DOC: if set: generated hits are inserted after the data_unpacker (bevore sorter) | MP_FEB
        constant MP_DATA_GEN_ENABLE_BIT         :  integer := 31;       -- DOC: if set: data generator generates hits | MP_FEB
    constant MP_LVDS_INVERT_REGISTER_W          :  integer := 16#1304#;       -- DOC: inverting mupix lvds lines | MP_FEB 
    constant MP_DATA_BYPASS_SELECT_REGISTER_W   :  integer := 16#1305#;       -- DOC: bypass the mupix soter and put input to_integer(THISREG) directly on optical link (implemented but not connected in top) | MP_FEB
    constant MP_TS_HISTO_SELECT_REGISTER_W      :  integer := 16#1306#;       -- DOC: not in use | MP_FEB
        subtype  MP_TS_HISTO_LINK_SELECT_RANGE  is integer range 15 downto 0; -- DOC: not in use | MP_FEB
        subtype  MP_TS_HISTO_N_SAMPLE_RANGE     is integer range 31 downto 16;-- DOC: not in use | MP_FEB
    constant MP_LAST_SORTER_HIT_REGISTER_R      :  integer := 16#1307#;       -- DOC: register that contains the last mupix hit of the sorter output | MP_FEB
    constant MP_SORTER_INJECT_REGISTER_W        :  integer := 16#1308#;       -- DOC: used to inject single hits at the sorter inputs | MP_FEB
        -- select the input of the sorter to inject to
        subtype MP_SORTER_INJECT_SELECT_RANGE   is integer range 7 downto 4;  -- DOC: input of the sorter to inject to | MP_FEB
        -- rising edge on this bit will trigger a single inject of the word MP_SORTER_INJECT_REGISTER_W at sorter input MP_SORTER_INJECT_REGISTER_W(MP_SORTER_INJECT_SELECT_RANGE)
        constant MP_SORTER_INJECT_ENABLE_BIT    :  integer := 8;              -- DOC: rising_edge: single hit is injected | MP_FEB
    constant MP_HIT_ENA_CNT_REGISTER_R          :  integer := 16#1309#;       -- DOC: hit enable counter | MP_FEB
    constant MP_HIT_ENA_CNT_SELECT_REGISTER_W   :  integer := 16#130A#;       -- DOC: register to select the link for hit ena counter | MP_FEB
    constant MP_HIT_ENA_CNT_SORTER_IN_REGISTER_R :  integer := 16#130B#;      -- DOC: hit enable counter at the sorter input | MP_FEB
    constant MP_HIT_ENA_CNT_SORTER_SELECT_REGISTER_W :  integer := 16#130C#;  -- DOC: register to select the link for the sorter input hin ena counter | MP_FEB
    constant MP_HIT_ENA_CNT_SORTER_OUT_REGISTER_R : integer := 16#130D#;      -- DOC: hit counter at sorter output | MP_FEB
    constant MP_RESET_LVDS_N_REGISTER_W         :  integer := 16#130F#;       -- DOC: reset register for mupix lvds rx | MP_FEB
    constant MP_USE_ARRIVAL_TIME1_REGISTER_W    :  integer := 16#1310#;       -- DOC: use hit arrival time instead of timestamp from mupix (lower 32 chips) | MP_FEB
    constant MP_USE_ARRIVAL_TIME2_REGISTER_W    :  integer := 16#1311#;       -- DOC: use hit arrival time instead of timestamp from mupix (uppder 4 chips) | MP_FEB
    constant MP_TRIGGER0_REGISTER_R             :  integer := 16#1312#;       -- DOC: trigger0 | MP_FEB
    constant MP_TRIGGER1_REGISTER_R             :  integer := 16#1313#;       -- DOC: trigger1 | MP_FEB
    constant MP_TRIGGER0_REG_REGISTER_R         :  integer := 16#1314#;       -- DOC: Prev-trigger0 | MP_FEB
    constant MP_TRIGGER1_REG_REGISTER_R         :  integer := 16#1315#;       -- DOC: Prev-trigger1 | MP_FEB

-----------------------------------------------------------------
---- mupix PLL lock monitor (0x1200-0x12FF)----------------------
-----------------------------------------------------------------

    constant MP_HIT_ARRIVAL_START_REGISTER_R    :  integer := 16#1200#;       -- DOC: start of PLL lock monitor block, 4 Words for each chip, histogram lower bits of mupix arrival timestamp | MP_FEB

-----------------------------------------------------------------
---- mupix lvds rx (0x1100-0x11FF)-------------------------------
-----------------------------------------------------------------

    constant MP_LVDS_STATUS_START_REGISTER_W    :  integer := 16#1100#;       -- DOC: start of lvds status register block, 1 Word for each lvds link from here on | MP_FEB
        subtype  MP_LVDS_STATUS_DISP_ERR_RANGE  is integer range 23 downto 0; -- DOC: Disparity error counter in each lvds status register | MP_FEB 
        subtype  MP_LVDS_STATUS_ALIGNCNT_RANGE  is integer range 29 downto 24;-- DOC: realign counter | MP_FEB 
        constant MP_LVDS_STATUS_PLL_LOCKED_BIT  :  integer := 30;             -- DOC: PLL locked bit in each lvds status register | MP_FEB 
        constant MP_LVDS_STATUS_READY_BIT       :  integer := 31;             -- DOC: if set: this mupix lvds link is locked and ready | MP_FEB

-----------------------------------------------------------------
---- mupix sorter (0x1000-0x10FF)--------------------------------
-----------------------------------------------------------------

    constant MP_SORTER_COUNTER_REGISTER_R           :  integer := 16#1000#;       -- DOC: Hit counters in the sorter, 40 32 bit counters in total. For the inner pixel FEBs: 12 counters with in-time hits per chip, 12 counters with out-of-time hits per chip, 12 counters with overflows per chip, a counter with the number of output hits and the current credit value. The last two counters are currently reserved for future use | MP_FEB
    constant MP_SORTER_NINTIME_REGISTER_R           :  integer := 16#1000#;
    constant MP_SORTER_NOUTOFTIME_REGISTER_R        :  integer := 16#100C#;
    constant MP_SORTER_NOVERFLOW_REGISTER_R         :  integer := 16#1018#;
    constant MP_SORTER_NOUT_REGISTER_R              :  integer := 16#1024#;
    constant MP_SORTER_CREDIT_REGISTER_R            :  integer := 16#1025#;
    constant MP_SORTER_DELAY_REGISTER_W             :  integer := 16#1028#;       -- DOC: Minimum round-trip delay from sync reset going off to hit with TS > 0 appearing at sorter input in 8 ns steps | MP_FEB

end package;
