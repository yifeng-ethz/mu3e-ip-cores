library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ip_xcvr_reset_2_100_pkg is
	component altera_xcvr_reset_control is
		generic (
			CHANNELS              : integer := 1;
			PLLS                  : integer := 1;
			SYS_CLK_IN_MHZ        : integer := 250;
			SYNCHRONIZE_RESET     : integer := 1;
			REDUCED_SIM_TIME      : integer := 1;
			TX_PLL_ENABLE         : integer := 1;
			T_PLL_POWERDOWN       : integer := 1000;
			SYNCHRONIZE_PLL_RESET : integer := 0;
			TX_ENABLE             : integer := 1;
			TX_PER_CHANNEL        : integer := 0;
			T_TX_ANALOGRESET      : integer := 0;
			T_TX_DIGITALRESET     : integer := 20;
			T_PLL_LOCK_HYST       : integer := 0;
			EN_PLL_CAL_BUSY       : integer := 0;
			RX_ENABLE             : integer := 1;
			RX_PER_CHANNEL        : integer := 0;
			T_RX_ANALOGRESET      : integer := 40;
			T_RX_DIGITALRESET     : integer := 4000
		);
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			reset              : in  std_logic                    := 'X';             -- reset
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			tx_analogreset     : out std_logic_vector(1 downto 0);                    -- tx_analogreset
			tx_digitalreset    : out std_logic_vector(1 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(1 downto 0);                    -- tx_ready
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			tx_cal_busy        : in  std_logic_vector(1 downto 0) := (others => 'X'); -- tx_cal_busy
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			rx_analogreset     : out std_logic_vector(1 downto 0);                    -- rx_analogreset
			rx_digitalreset    : out std_logic_vector(1 downto 0);                    -- rx_digitalreset
			rx_ready           : out std_logic_vector(1 downto 0);                    -- rx_ready
			rx_is_lockedtodata : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_cal_busy        : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_cal_busy
			tx_manual          : in  std_logic_vector(1 downto 0) := (others => 'X'); -- tx_reset_mode
			rx_manual          : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_reset_mode
			tx_digitalreset_or : in  std_logic_vector(1 downto 0) := (others => 'X'); -- tx_digitalreset_or
			rx_digitalreset_or : in  std_logic_vector(1 downto 0) := (others => 'X')  -- rx_digitalreset_or
		);
	end component altera_xcvr_reset_control;

end ip_xcvr_reset_2_100_pkg;
