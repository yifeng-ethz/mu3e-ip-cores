-- Register Map for common parts of the sc memory on ArriaV
-- addr range: 0xFC00-0xFFFE

library ieee;
use ieee.std_logic_1164.all;

package feb_sc_registers is

    constant PACKET_TYPE_SC                        : std_logic_vector(2 downto 0) := "111";

    constant PACKET_TYPE_SC_READ                   : std_logic_vector(1 downto 0) := "00";
    constant PACKET_TYPE_SC_WRITE                  : std_logic_vector(1 downto 0) := "01";
    constant PACKET_TYPE_SC_READ_NONINCREMENTING   : std_logic_vector(1 downto 0) := "10";
    constant PACKET_TYPE_SC_WRITE_NONINCREMENTING  : std_logic_vector(1 downto 0) := "11";

    constant PACKET_R_BIT_POSITION                 :   integer := 24;
    constant PACKET_T_BIT_POSITION                 :   integer := 25;
    constant PACKET_S_BIT_POSITION                 :   integer := 26;
    constant PACKET_M_BIT_POSITION                 :   integer := 27;


    -- TODO: software checks
    --subtype FEB_SC_ADDR_RANGE       is integer range 255 downto 0;
    --subtype FEB_SC_DATA_SIZE_RANGE  is integer range 512 downto 1;
    --constant FEB_SC_RAM_SIZE : std_logic_vector(3 downto 0) := "1110";

    constant STATUS_REGISTER_R                  :   integer := 16#FC00#;        -- DOC: not in use | FEB_ALL
    constant GIT_HASH_REGISTER_R                :   integer := 16#FC01#;        -- DOC: contains the git hash of used firmware | FEB_ALL
    constant FPGA_TYPE_REGISTER_R               :   integer := 16#FC02#;        -- DOC: contains fpga type 111010: mupix, 111000 : mutrig | FEB_ALL
    constant FPGA_ID_REGISTER_RW                :   integer := 16#FC03#;        -- DOC: fgpa ID | FEB_ALL
    constant CMD_LEN_REGISTER_RW                :   integer := 16#FC04#;        -- DOC: length of data to read in a nios rpc call | FEB_ALL
    constant CMD_OFFSET_REGISTER_RW             :   integer := 16#FC05#;        -- DOC: positon of the data to read in a nios rpc call | FEB_ALL
    constant RUN_STATE_RESET_BYPASS_REGISTER_RW :   integer := 16#FC06#;        -- DOC: used to bypass the reset system and run without a clock box | FEB_ALL
    subtype  RUN_STATE_RANGE                    is  integer range 31 downto 16; -- DOC: not in use | FEB_ALL
    subtype  RESET_BYPASS_RANGE                 is  integer range 7 downto 0;   -- DOC: not in use | FEB_ALL
    constant RESET_BYPASS_BIT_REQUEST           :   integer := 8;               -- DOC: sends a bypass reset command | FEB_ALL
    constant RESET_BYPASS_BIT_ENABLE            :   integer := 9;               -- DOC: enables the use of the reset bypass | FEB_ALL

    constant RESET_PAYLOAD_REGISTER_RW          :   integer := 16#FC07#;        -- DOC: payload for the reset bypass commands | FEB_ALL
    constant RESET_OPTICAL_LINKS_REGISTER_RW    :   integer := 16#FC08#;        -- DOC: reset firefly | FEB_ALL
    constant RESET_PHASE_REGISTER_R             :   integer := 16#FC09#;        -- DOC: phase between reset rx clock and global clk | FEB_ALL
    constant MERGER_RATE_REGISTER_R             :   integer := 16#FC0A#;        -- DOC: output rate of the data merger | FEB_ALL

    constant ARRIA_TEMP_REGISTER_RW             :   integer := 16#FC10#;        -- DOC: ARRIAV internal temp sense | FEB_ALL
    constant MAX10_ADC_0_1_REGISTER_R           :   integer := 16#FC11#;        -- DOC: MAX10 adc data | FEB_ALL
    constant MAX10_ADC_2_3_REGISTER_R           :   integer := 16#FC12#;
    constant MAX10_ADC_4_5_REGISTER_R           :   integer := 16#FC13#;
    constant MAX10_ADC_6_7_REGISTER_R           :   integer := 16#FC14#;
    constant MAX10_ADC_8_9_REGISTER_R           :   integer := 16#FC15#;

    constant FIREFLY_STATUS_REGISTER_R          :   integer := 16#FC16#;
        constant FIREFLY1_INDEX_TEMP            :   integer := 0;               -- DOC: contains the temp of firefly1 | FEB_ALL
        constant FIREFLY1_INDEX_VOLT            :   integer := 1;               -- DOC: contains the voltage of firefly1 | FEB_ALL
        constant FIREFLY1_INDEX_RX1_POW         :   integer := 2;               -- DOC: received optical power on link 1 | FEB_ALL
        constant FIREFLY1_INDEX_RX2_POW         :   integer := 3;               -- DOC: received optical power on link 2 | FEB_ALL
        constant FIREFLY1_INDEX_RX3_POW         :   integer := 4;               -- DOC: received optical power on link 3 | FEB_ALL
        constant FIREFLY1_INDEX_RX4_POW         :   integer := 5;               -- DOC: received optical power on link 4 | FEB_ALL
        constant FIREFLY1_INDEX_ALARM           :   integer := 6;               -- DOC: firefly1 alarm | FEB_ALL

        constant FIREFLY2_INDEX_TEMP            :   integer := 7;               -- DOC: contains the temp of firefly2 | FEB_ALL
        constant FIREFLY2_INDEX_VOLT            :   integer := 8;               -- DOC: contains the voltage of firefly2 | FEB_ALL
        constant FIREFLY2_INDEX_RX1_POW         :   integer := 9;               -- DOC: received optical power on link 5 | FEB_ALL
        constant FIREFLY2_INDEX_RX2_POW         :   integer := 10;              -- DOC: received optical power on link 6 | FEB_ALL
        constant FIREFLY2_INDEX_RX3_POW         :   integer := 11;              -- DOC: received optical power on link 7 | FEB_ALL
        constant FIREFLY2_INDEX_RX4_POW         :   integer := 12;              -- DOC: received optical power on link 8 | FEB_ALL
        constant FIREFLY2_INDEX_ALARM           :   integer := 13;              -- DOC: firefly1 alarm | FEB_ALL

    constant NONINCREMENTING_TEST_REGISTER_RW   :   integer := 16#FC24#;        -- DOC: testing nonincrementing reads/writes to fifo (not in use) | FEB_ALL
    constant MAX10_VERSION_REGISTER_R           :   integer := 16#FC25#;        -- DOC: git hash of the max10 firmware | FEB_ALL
    constant MAX10_STATUS_REGISTER_R            :   integer := 16#FC26#;
    constant MAX10_STATUS_BIT_PLL_LOCKED        :   integer := 0;
    constant MAX10_STATUS_BIT_SPI_ARRIA_CLK     :   integer := 1;

    constant PROGRAMMING_CTRL_REGISTER_W        :   integer := 16#FC27#;
    constant PROGRAMMING_STATUS_REGISTER_R      :   integer := 16#FC28#;
    constant PROGRAMMING_STATUS_BIT_ARRIAWRITING:   integer := 0;
    constant PROGRAMMING_STATUS_BIT_SPI_BUSY    :   integer := 1;
    constant PROGRAMMING_STATUS_BIT_FIFO_EMPTY  :   integer := 14;
    constant PROGRAMMING_STATUS_BIT_FIFO_FULL   :   integer := 15;
    constant PROGRAMMING_STATUS_BIT_CONF_DONE   :   integer := 16;
    constant PROGRAMMING_STATUS_BIT_NSTATUS     :   integer := 17;
    constant PROGRAMMING_STATUS_BIT_TIMEOUT     :   integer := 18;
    constant PROGRAMMING_STATUS_BIT_CRCERROR    :   integer := 19;
    constant PROGRAMMING_ADDR_REGISTER_W        :   integer := 16#FC29#;
    constant PROGRAMMING_DATA_REGISTER_W        :   integer := 16#FC2A#;

    constant SI_STATUS_REGISTER                 :   integer := 16#FC2B#;
    constant TEST_OUT_REGISTER                  :   integer := 16#FC2C#;
    constant REBOOT_REGISTER_RW                 :   integer := 16#FC2D#;
    constant SHUTDOWN_REGISTER_RW               :   integer := 16#FC2E#;
    constant RUN_START_DENIAL_REGISTER_R        :   integer := 16#FC2F#;        -- DOC: Reason for denied run start ack | FEB_ALL
    constant RUN_NUMBER_REGISTER_R              :   integer := 16#FC2F#;        -- DOC: Run number on the FEB | FEB_ALL

    constant FIREFLY_XCVR_CH_SEL_REGISTER_RW    :   integer := 16#FF00#;
    constant FIREFLY_XCVR_N_CH_REGISTER_R       :   integer := 16#FF01#;
    constant FIREFLY_XCVR_CH_WIDTH_REGISTER_R   :   integer := 16#FF02#;
    constant FIREFLY_XCVR_TX_RESET_REGISTER_RW  :   integer := 16#FF10#;
    constant FIREFLY_XCVR_TX_STATUS_REGISTER_R  :   integer := 16#FF11#;
    constant FIREFLY_XCVR_TX_ERROR_REGISTER_R   :   integer := 16#FF12#;
    constant FIREFLY_XCVR_RX_RESET_REGISTER_RW  :   integer := 16#FF20#;
    constant FIREFLY_XCVR_RX_STATUS_REGISTER_R  :   integer := 16#FF21#;
    constant FIREFLY_XCVR_RX_ERROR_REGISTER_R   :   integer := 16#FF22#;

    constant FIREFLY_XCVR_LOL_REGISTER_R        :   integer := 16#FF23#;
    constant FIREFLY_XCVR_ERR_CNT_REGISTER_R    :   integer := 16#FF24#;
    constant FIREFLY_XCVR_DATA_REGISTER_R       :   integer := 16#FF2A#;
    constant FIREFLY_XCVR_DATAK_REGISTER_R      :   integer := 16#FF2B#;
    constant FIREFLY_XCVR_GBIT_REGISTER_R       :   integer := 16#FF2C#;
    constant FIREFLY_XCVR_LOOPBACK_REGISTER_RW  :   integer := 16#FF2F#;

    constant RESET_LINK_RESTART_REGISTER_RW     :   integer := 16#FF30#;
    constant LVDS_CONTROLLER_STATE_REGISTER_R   :   integer := 16#FF31#;

end package;
