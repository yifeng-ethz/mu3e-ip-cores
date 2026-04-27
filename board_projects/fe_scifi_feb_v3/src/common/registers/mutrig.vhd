
library ieee;
use ieee.std_logic_1164.all;

package mutrig is

    --! MuTrig
    CONSTANT C_HEAD_ID : std_logic_vector(7 downto 0) := "00011100";        --K28.0, 0x1C, 10 BIT: 1101000011
    CONSTANT C_TRAIL_ID : std_logic_vector(7 downto 0) := "10011100";       --K28.4, 0x9C, 10 BIT: 1011000011
    CONSTANT C_COMMA : std_logic_vector(7 downto 0) := "10111100";          --K28.5, 0xBC, 10 BIT: 1010000011, Sync character
    CONSTANT C_CLOCK_CORR_ID : std_logic_vector(7 downto 0) := "01111100";      --K28.3, 0x7C, 10 BIT: 0011000011, Clock Correction

    CONSTANT C_HEADER : std_logic_vector(7 downto 0) := C_HEAD_ID;
    CONSTANT C_TRAILER : std_logic_vector(7 downto 0) := C_TRAIL_ID;

    type mutrig_evtdata_array_t is array (natural range <>) of std_logic_vector(55 downto 0);   
    --spi pattern
    constant MUTRIG1_SPI_WORDS     : integer := 74;
    constant MUTRIG1_SPI_FIRST_MSB : integer := 21;
    constant STIC3_SPI_WORDS     : integer := 146;
    constant STIC3_SPI_FIRST_MSB : integer := 16;

end package;
