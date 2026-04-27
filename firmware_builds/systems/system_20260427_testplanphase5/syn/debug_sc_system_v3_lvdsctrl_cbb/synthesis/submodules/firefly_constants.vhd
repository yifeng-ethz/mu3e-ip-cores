---------------------------------------
-- Firefly ECUO 14G x4 - constant library
-- Martin Mueller, August 2020
----------------------------------

library ieee;
use ieee.std_logic_1164.all;

package firefly_constants is

    -- device I2c address
    constant FFLY_DEV_ADDR_7        : std_logic_vector(6 downto 0) := "1010000";
    constant FFLY_DEV_ADDR_8_WRITE  : std_logic_vector(7 downto 0) := x"A0";
    constant FFLY_DEV_ADDR_8_READ   : std_logic_vector(7 downto 0) := x"A1";

    -- commands
    constant CMD_READ           : std_logic_vector(7 downto 0) := "10100001"; -- read current address
    constant CMD_WRITE          : std_logic_vector(7 downto 0) := "10100000";

    -- mem addr lower Page 00 (incomplete)
    constant ALARM_1        : std_logic_vector(7 downto 0) := "00000011"; -- 3
    constant ALARM_2        : std_logic_vector(7 downto 0) := "00000100"; -- 4
    constant ALARM_3        : std_logic_vector(7 downto 0) := "00000110"; -- 6
    constant ALARM_4        : std_logic_vector(7 downto 0) := "00000111"; -- 7

    constant ADDR_OP_TIME_1     : std_logic_vector(7 downto 0) := "00010011";
    constant ADDR_OP_TIME_2     : std_logic_vector(7 downto 0) := "00010100";
    constant ADDR_TEMPERATURE   : std_logic_vector(7 downto 0) := "00010110";
    constant ADDR_VCC_1         : std_logic_vector(7 downto 0) := "00011010";
    constant ADDR_VCC_2         : std_logic_vector(7 downto 0) := "00011011";

    constant RX1_PWR1  : std_logic_vector(7 downto 0) := "00100010";
    constant RX1_PWR2  : std_logic_vector(7 downto 0) := "00100011";
    constant RX2_PWR1  : std_logic_vector(7 downto 0) := "00100100";
    constant RX2_PWR2  : std_logic_vector(7 downto 0) := "00100101";
    constant RX3_PWR1  : std_logic_vector(7 downto 0) := "00100110";
    constant RX3_PWR2  : std_logic_vector(7 downto 0) := "00100111";
    constant RX4_PWR1  : std_logic_vector(7 downto 0) := "00101000";
    constant RX4_PWR2  : std_logic_vector(7 downto 0) := "00101001";

    type ALARM_TYPE is array (0 to 3) OF std_logic_vector(7 downto 0);
    constant ADDR_ALARM : ALARM_TYPE := (ALARM_1, ALARM_2, ALARM_3, ALARM_4);

    type RX_PWR_TYPE is array (0 to 7) OF std_logic_vector(7 downto 0);
    constant ADDR_RX_PWR        : RX_PWR_TYPE         := (RX1_PWR1, RX1_PWR2, RX2_PWR1, RX2_PWR2, RX3_PWR1, RX3_PWR2, RX4_PWR1, RX4_PWR2);

end package;
