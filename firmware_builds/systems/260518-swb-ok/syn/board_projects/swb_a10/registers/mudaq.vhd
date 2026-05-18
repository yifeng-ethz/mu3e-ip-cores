--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

package mudaq is

    --! 8b/10b words
    constant K28_0 : std_logic_vector(7 downto 0) := X"1C"; -- still used in MuPix ??
    constant K28_4 : std_logic_vector(7 downto 0) := X"9C"; -- used as end of packet marker between FEB <--> SW board

    --! data path farm types
    subtype dataplusts_type is std_logic_vector(519 downto 0);
    subtype tsrange_type is std_logic_vector(7 downto 0);
    subtype tsupper is natural range 15 downto 8;
    subtype tslower is natural range 7 downto 0;
    constant tsone : tsrange_type := (others => '1');
    constant tszero : tsrange_type := (others => '0');


    --! time merger tree constants
    constant N_LINKS_TREE : integer_vector(3 downto 0) := (1, 2, 4, 8);


    --! FEB - SWB protocol
    --constant HEADER_K               : std_logic_vector(31 downto 0) := x"bcbcbcbc";
    constant MUPIX_HEADER_ID        : std_logic_vector(5 downto 0) := "111010";
    constant TILE_HEADER_ID         : std_logic_vector(5 downto 0) := "110100";
    constant SCIFI_HEADER_ID        : std_logic_vector(5 downto 0) := "111000";
    constant OUTER_HEADER_ID        : std_logic_vector(5 downto 0) := "111001";
    constant DATA_SUB_HEADER_ID     : std_logic_vector(5 downto 0) := "111111";
    constant GENERIC_HEADER_ID      : std_logic_vector(5 downto 0) := "111110";
    constant DUMMY_HEADER_ID        : std_logic_vector(5 downto 0) := "101000";
    constant SC_HEADER_ID           : std_logic_vector(5 downto 0) := "111011";

    -- out of band
    constant SC_OOB_c       : std_logic_vector(1 downto 0) := "00";
    constant SC_READ_c      : std_logic_vector(1 downto 0) := "10";
    constant SC_WRITE_c     : std_logic_vector(1 downto 0) := "11";

    -- start of packet
    constant FIFO_SOP_c     : std_logic_vector(3 downto 0) := "0010";
    -- payload
    constant FIFO_PAYLOAD_c : std_logic_vector(3 downto 0) := "0000";
    -- end of packet
    constant FIFO_EOP_c     : std_logic_vector(3 downto 0) := "0011";
    -- end of run
    constant FIFO_EOR_c     : std_logic_vector(3 downto 0) := "0111";


    subtype reg32 is std_logic_vector(31 downto 0);
    subtype reg64 is std_logic_vector(63 downto 0);   

    -- TODO: REMOVE THIS NUMBER HERE
    constant NREGISTERS :  integer := 64;
    type reg32array_pcie is array (NREGISTERS-1 downto 0) of reg32;

    -- [AK] TODO: use slv32_array_t
    type reg32array is array (natural range <>) of reg32;
    type reg64array is array (natural range <>) of reg64;

    --! type for run state
    subtype run_state_t is std_logic_vector(9 downto 0);

    constant RUN_STATE_BITPOS_IDLE        : integer := 0;
    constant RUN_STATE_BITPOS_PREP        : integer := 1;
    constant RUN_STATE_BITPOS_SYNC        : integer := 2;
    constant RUN_STATE_BITPOS_RUNNING     : integer := 3;
    constant RUN_STATE_BITPOS_TERMINATING : integer := 4;
    constant RUN_STATE_BITPOS_LINK_TEST   : integer := 5;
    constant RUN_STATE_BITPOS_SYNC_TEST   : integer := 6;
    constant RUN_STATE_BITPOS_RESET       : integer := 7;
    constant RUN_STATE_BITPOS_OUT_OF_DAQ  : integer := 8;

    constant RUN_STATE_IDLE        : run_state_t := (RUN_STATE_BITPOS_IDLE         => '1', others =>'0');
    constant RUN_STATE_PREP        : run_state_t := (RUN_STATE_BITPOS_PREP         => '1', others =>'0');
    constant RUN_STATE_SYNC        : run_state_t := (RUN_STATE_BITPOS_SYNC         => '1', others =>'0');
    constant RUN_STATE_RUNNING     : run_state_t := (RUN_STATE_BITPOS_RUNNING      => '1', others =>'0');
    constant RUN_STATE_TERMINATING : run_state_t := (RUN_STATE_BITPOS_TERMINATING  => '1', others =>'0');
    constant RUN_STATE_LINK_TEST   : run_state_t := (RUN_STATE_BITPOS_LINK_TEST    => '1', others =>'0');
    constant RUN_STATE_SYNC_TEST   : run_state_t := (RUN_STATE_BITPOS_SYNC_TEST    => '1', others =>'0');
    constant RUN_STATE_RESET       : run_state_t := (RUN_STATE_BITPOS_RESET        => '1', others =>'0');
    constant RUN_STATE_OUT_OF_DAQ  : run_state_t := (RUN_STATE_BITPOS_OUT_OF_DAQ   => '1', others =>'0');
    constant RUN_STATE_UNDEFINED   : run_state_t := (others =>'0');

    -- reset link words
    constant RESET_LINK_RUN_PREPARE : std_logic_vector(7 DOWNTO 0) := x"10";
    constant RESET_LINK_SYNC : std_logic_vector(7 DOWNTO 0) := x"11";
    constant RESET_LINK_START_RUN : std_logic_vector(7 DOWNTO 0) := x"12";
    constant RESET_LINK_END_RUN : std_logic_vector(7 DOWNTO 0) := x"13";
    constant RESET_LINK_ABORT_RUN : std_logic_vector(7 DOWNTO 0) := x"14";
    constant RESET_LINK_START_LINK_TEST : std_logic_vector(7 DOWNTO 0) := x"20";
    constant RESET_LINK_STOP_LINK_TEST : std_logic_vector(7 DOWNTO 0) := x"21";
    constant RESET_LINK_START_SYNC_TEST : std_logic_vector(7 DOWNTO 0) := x"24";
    constant RESET_LINK_STOP_SYNC_TEST : std_logic_vector(7 DOWNTO 0) := x"25";
    constant RESET_LINK_TEST_SYNC : std_logic_vector(7 DOWNTO 0) := x"26";
    constant RESET_LINK_RESET : std_logic_vector(7 DOWNTO 0) := x"30";
    constant RESET_LINK_STOP_RESET : std_logic_vector(7 DOWNTO 0) := x"31";
    constant RESET_LINK_ENABLE : std_logic_vector(7 DOWNTO 0) := x"32";
    constant RESET_LINK_DISABLE : std_logic_vector(7 DOWNTO 0) := x"33";
    constant RESET_LINK_ADDRESS : std_logic_vector(7 DOWNTO 0) := x"34";

    -- mscb addressing (for networks with 8bit and 16bit addresses, we will use 16 ?)
    constant MSCB_CMD_ADDR_NODE16           : std_logic_vector(7 downto 0)      := X"0A";
    constant MSCB_CMD_ADDR_NODE8            : std_logic_vector(7 downto 0)      := X"09";
    constant MSCB_CMD_ADDR_GRP8             : std_logic_vector(7 downto 0)      := X"11"; -- group addressing
    constant MSCB_CMD_ADDR_GRP16            : std_logic_vector(7 downto 0)      := X"12";
    constant MSCB_CMD_ADDR_BC               : std_logic_vector(7 downto 0)      := X"10"; --broadcast
    constant MSCB_CMD_PING8                 : std_logic_vector(7 downto 0)      := X"19";
    constant MSCB_CMD_PING16                : std_logic_vector(7 downto 0)      := X"1A";

    constant run_prep_acknowledge           : std_logic_vector(31 downto 0)     := x"000000FE";
    constant run_prep_acknowledge_datak     : std_logic_vector(3 downto 0)      := "0001";
    constant RUN_END                        : std_logic_vector(31 downto 0)     := x"000000FD";
    constant RUN_END_DATAK                  : std_logic_vector(3 downto 0)      := "0001";
    constant MERGER_TIMEOUT                 : std_logic_vector(31 downto 0)     := x"000000FB";
    constant MERGER_TIMEOUT_DATAK           : std_logic_vector(3 downto 0)      := "0001";

    constant MERGER_FIFO_RUN_END_MARKER     : std_logic_vector(3 downto 0)      := "0111";
    constant MERGER_FIFO_SUB_MARKER         : std_logic_vector(3 downto 0)      := "0100";
    constant MERGER_FIFO_PAKET_END_MARKER   : std_logic_vector(3 downto 0)      := "0011";
    constant MERGER_FIFO_PAKET_START_MARKER : std_logic_vector(3 downto 0)      := "0010";
    constant MERGER_FIFO_PAKET_T1_MARKER    : std_logic_vector(3 downto 0)      := "0001";

    -- FEB Arria-MAX SPI addresses
    constant FEBSPI_ADDR_GITHASH            : std_logic_vector(6 downto 0)      := "0000000";
    constant FEBSPI_ADDR_STATUS             : std_logic_vector(6 downto 0)      := "0000010";
    constant FEBSPI_ADDR_CONTROL            : std_logic_vector(6 downto 0)      := "0000011";
    constant FEBSPI_ADDR_RESET              : std_logic_vector(6 downto 0)      := "0000100";
    constant FEBSPI_ADDR_PROGRAMMING_STATUS : std_logic_vector(6 downto 0)      := "0010000";
    constant FEBSPI_ADDR_PROGRAMMING_COUNT  : std_logic_vector(6 downto 0)      := "0010001";
    constant FEBSPI_ADDR_PROGRAMMING_CTRL   : std_logic_vector(6 downto 0)      := "0010010";
    constant FEBSPI_ADDR_PROGRAMMING_ADDR   : std_logic_vector(6 downto 0)      := "0010011";
    constant FEBSPI_ADDR_PROGRAMMING_WFIFO  : std_logic_vector(6 downto 0)      := "0010100";

    constant FEBSPI_ADDR_ADCCTRL            : std_logic_vector(6 downto 0)      := "0100000";
    constant FEBSPI_ADDR_ADCDATA            : std_logic_vector(6 downto 0)      := "0100001";

    -- FEB-MAX SPI Flash
    constant COMMAND_WRITE_ENABLE               : std_logic_vector(7 downto 0) := X"06";
    constant COMMAND_WRITE_DISABLE              : std_logic_vector(7 downto 0) := X"04";
    constant COMMAND_READ_STATUS_REGISTER1      : std_logic_vector(7 downto 0) := X"05";
    constant COMMAND_READ_STATUS_REGISTER2      : std_logic_vector(7 downto 0) := X"35";
    constant COMMAND_READ_STATUS_REGISTER3      : std_logic_vector(7 downto 0) := X"15";
    constant COMMAND_WRITE_ENABLE_VSR           : std_logic_vector(7 downto 0) := X"50";
    constant COMMAND_WRITE_STATUS_REGISTER1     : std_logic_vector(7 downto 0) := X"01";
    constant COMMAND_WRITE_STATUS_REGISTER2     : std_logic_vector(7 downto 0) := X"31";
    constant COMMAND_WRITE_STATUS_REGISTER3     : std_logic_vector(7 downto 0) := X"11";
    constant COMMAND_READ_DATA                  : std_logic_vector(7 downto 0) := X"03";
    constant COMMAND_FAST_READ                  : std_logic_vector(7 downto 0) := X"0B";
    constant COMMAND_DUAL_OUTPUT_FAST_READ      : std_logic_vector(7 downto 0) := X"3B";
    constant COMMAND_DUAL_IO_FAST_READ          : std_logic_vector(7 downto 0) := X"BB";
    constant COMMAND_QUAD_OUTPUT_FAST_READ      : std_logic_vector(7 downto 0) := X"6B";
    constant COMMAND_QUAD_IO_FAST_READ          : std_logic_vector(7 downto 0) := X"EB";
    constant COMMAND_QUAD_IO_WORD_FAST_READ     : std_logic_vector(7 downto 0) := X"E7";
    constant COMMAND_PAGE_PROGRAM               : std_logic_vector(7 downto 0) := X"02";
    constant COMMAND_QUAD_PAGE_PROGRAM          : std_logic_vector(7 downto 0) := X"32";
    constant COMMAND_FAST_PAGE_PROGRAM          : std_logic_vector(7 downto 0) := X"F2";
    constant COMMAND_SECTOR_ERASE               : std_logic_vector(7 downto 0) := X"20";
    constant COMMAND_BLOCK_ERASE_32             : std_logic_vector(7 downto 0) := X"52";
    constant COMMAND_BLOCK_ERASE_64             : std_logic_vector(7 downto 0) := X"D8";
    constant COMMAND_CHIP_ERASE                 : std_logic_vector(7 downto 0) := X"C7";
    constant COMMAND_ENABLE_RESET               : std_logic_vector(7 downto 0) := X"66";
    constant COMMAND_RESET                      : std_logic_vector(7 downto 0) := X"99";
    constant COMMAND_JEDEC_ID                   : std_logic_vector(7 downto 0) := X"9F";
    constant COMMAND_ERASE_SECURITY_REGISTERS   : std_logic_vector(7 downto 0) := X"44";
    constant COMMAND_PROG_SECURITY_REGISTERS    : std_logic_vector(7 downto 0) := X"42";
    constant COMMAND_READ_SECURITY_REGISTERS    : std_logic_vector(7 downto 0) := X"42";

    -- MIDAS Bank Names
    constant DebugPixelHitSWB : std_logic_vector(31 downto 0) := x"53504844"; -- DHPS
    constant DebugFibreHitSWB : std_logic_vector(31 downto 0) := x"53464844"; -- DHFS
    constant DebugTileHitUpstream : std_logic_vector(31 downto 0) := x"55544844"; -- DHTU
    constant DebugTileHitDownstream : std_logic_vector(31 downto 0) := x"44544844"; -- DHTD
    constant DebugGenHitSWB : std_logic_vector(31 downto 0) := x"55474844"; -- DHGU
    constant NONEBankName : std_logic_vector(31 downto 0) := x"454E4F4E"; -- NONE

    function link_36_to_std (
        i : in  integer--;
    ) return std_logic_vector;

    function GIT_HEAD_INT32 (
        hash : in std_logic_vector(63 downto 0)--;
    ) return std_logic_vector;

end package;

package body mudaq is

    function link_36_to_std (
        i : in  integer--;
    ) return std_logic_vector is
    begin
        if ( i >= 36 ) then
            return (5 downto 0 => '1');
        else
            return std_logic_vector(to_unsigned(i, 6));
        end if;
    end function;

    function GIT_HEAD_INT32 (
        hash : in std_logic_vector(63 downto 0)--;
    ) return std_logic_vector is
    begin
        return hash( 3 downto  0) & hash (7 downto  4)
             & hash(11 downto  8) & hash(15 downto 12)
             & hash(19 downto 16) & hash(23 downto 20)
             & hash(27 downto 24) & hash(31 downto 28);
    end function;

end package body;
