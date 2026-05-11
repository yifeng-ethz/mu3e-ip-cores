library ieee;
use ieee.std_logic_1164.all;

package cmp is

    constant GIT_HEAD : std_logic_vector(16*4-1 downto 0) := X"ead2ba747caae359";

-- ./a10/ip/ip_clkctrl/ip_clkctrl.cmp
	component ip_clkctrl is
		port (
			inclk  : in  std_logic := 'X'; -- inclk
			outclk : out std_logic         -- outclk
		);
	end component ip_clkctrl;

-- ./a10/ip/ip_madd/ip_madd.cmp
	component ip_madd is
		port (
			aclr   : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- aclr
			ax     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- ax
			ay     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- ay
			az     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- az
			clk    : in  std_logic                     := 'X';             -- clk
			ena    : in  std_logic                     := 'X';             -- ena
			result : out std_logic_vector(31 downto 0)                     -- result
		);
	end component ip_madd;

-- ./a10/ip/ip_pll_100to125/ip_pll_100to125.cmp
	component ip_pll_100to125 is
		port (
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic;        -- clk
			refclk   : in  std_logic := 'X'; -- clk
			rst      : in  std_logic := 'X'  -- reset
		);
	end component ip_pll_100to125;

-- ./a10/ip/ip_pll_125to156/ip_pll_125to156.cmp
	component ip_pll_125to156 is
		port (
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic;        -- clk
			refclk   : in  std_logic := 'X'; -- clk
			rst      : in  std_logic := 'X'  -- reset
		);
	end component ip_pll_125to156;

-- ./a10/ip/ip_pll_125to250/ip_pll_125to250.cmp
	component ip_pll_125to250 is
		port (
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic;        -- clk
			refclk   : in  std_logic := 'X'; -- clk
			rst      : in  std_logic := 'X'  -- reset
		);
	end component ip_pll_125to250;

-- ./a10/ip/ip_pll_50to125/ip_pll_50to125.cmp
	component ip_pll_50to125 is
		port (
			locked   : out std_logic;        -- export
			outclk_0 : out std_logic;        -- clk
			refclk   : in  std_logic := 'X'; -- clk
			rst      : in  std_logic := 'X'  -- reset
		);
	end component ip_pll_50to125;

-- ./a10/ip/ip_xcvr_fpll_125_10000/ip_xcvr_fpll_125_10000.cmp
	component ip_xcvr_fpll_125_10000 is
		port (
			pll_cal_busy          : out std_logic;                                        -- pll_cal_busy
			pll_locked            : out std_logic;                                        -- pll_locked
			pll_powerdown         : in  std_logic                     := 'X';             -- pll_powerdown
			pll_refclk0           : in  std_logic                     := 'X';             -- clk
			reconfig_write0       : in  std_logic                     := 'X';             -- write
			reconfig_read0        : in  std_logic                     := 'X';             -- read
			reconfig_address0     : in  std_logic_vector(9 downto 0)  := (others => 'X'); -- address
			reconfig_writedata0   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			reconfig_readdata0    : out std_logic_vector(31 downto 0);                    -- readdata
			reconfig_waitrequest0 : out std_logic;                                        -- waitrequest
			reconfig_clk0         : in  std_logic                     := 'X';             -- clk
			reconfig_reset0       : in  std_logic                     := 'X';             -- reset
			tx_serial_clk         : out std_logic                                         -- clk
		);
	end component ip_xcvr_fpll_125_10000;

-- ./a10/ip/ip_xcvr_fpll_125_1250/ip_xcvr_fpll_125_1250.cmp
	component ip_xcvr_fpll_125_1250 is
		port (
			pll_cal_busy          : out std_logic;                                        -- pll_cal_busy
			pll_locked            : out std_logic;                                        -- pll_locked
			pll_powerdown         : in  std_logic                     := 'X';             -- pll_powerdown
			pll_refclk0           : in  std_logic                     := 'X';             -- clk
			reconfig_write0       : in  std_logic                     := 'X';             -- write
			reconfig_read0        : in  std_logic                     := 'X';             -- read
			reconfig_address0     : in  std_logic_vector(9 downto 0)  := (others => 'X'); -- address
			reconfig_writedata0   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			reconfig_readdata0    : out std_logic_vector(31 downto 0);                    -- readdata
			reconfig_waitrequest0 : out std_logic;                                        -- waitrequest
			reconfig_clk0         : in  std_logic                     := 'X';             -- clk
			reconfig_reset0       : in  std_logic                     := 'X';             -- reset
			tx_serial_clk         : out std_logic                                         -- clk
		);
	end component ip_xcvr_fpll_125_1250;

-- ./a10/ip/ip_xcvr_fpll_125_5000/ip_xcvr_fpll_125_5000.cmp
	component ip_xcvr_fpll_125_5000 is
		port (
			pll_cal_busy          : out std_logic;                                        -- pll_cal_busy
			pll_locked            : out std_logic;                                        -- pll_locked
			pll_powerdown         : in  std_logic                     := 'X';             -- pll_powerdown
			pll_refclk0           : in  std_logic                     := 'X';             -- clk
			reconfig_write0       : in  std_logic                     := 'X';             -- write
			reconfig_read0        : in  std_logic                     := 'X';             -- read
			reconfig_address0     : in  std_logic_vector(9 downto 0)  := (others => 'X'); -- address
			reconfig_writedata0   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			reconfig_readdata0    : out std_logic_vector(31 downto 0);                    -- readdata
			reconfig_waitrequest0 : out std_logic;                                        -- waitrequest
			reconfig_clk0         : in  std_logic                     := 'X';             -- clk
			reconfig_reset0       : in  std_logic                     := 'X';             -- reset
			tx_serial_clk         : out std_logic                                         -- clk
		);
	end component ip_xcvr_fpll_125_5000;

-- ./a10/ip/ip_xcvr_fpll_125_6250/ip_xcvr_fpll_125_6250.cmp
	component ip_xcvr_fpll_125_6250 is
		port (
			pll_cal_busy          : out std_logic;                                        -- pll_cal_busy
			pll_locked            : out std_logic;                                        -- pll_locked
			pll_powerdown         : in  std_logic                     := 'X';             -- pll_powerdown
			pll_refclk0           : in  std_logic                     := 'X';             -- clk
			reconfig_write0       : in  std_logic                     := 'X';             -- write
			reconfig_read0        : in  std_logic                     := 'X';             -- read
			reconfig_address0     : in  std_logic_vector(9 downto 0)  := (others => 'X'); -- address
			reconfig_writedata0   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			reconfig_readdata0    : out std_logic_vector(31 downto 0);                    -- readdata
			reconfig_waitrequest0 : out std_logic;                                        -- waitrequest
			reconfig_clk0         : in  std_logic                     := 'X';             -- clk
			reconfig_reset0       : in  std_logic                     := 'X';             -- reset
			tx_serial_clk         : out std_logic                                         -- clk
		);
	end component ip_xcvr_fpll_125_6250;

-- ./a10/ip/ip_xcvr_phy_2_10_125_1250/ip_xcvr_phy_2_10_125_1250.cmp
	component ip_xcvr_phy_2_10_125_1250 is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(10 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(1 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(1 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(1 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(1 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(19 downto 0);                     -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(1 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(1 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_parallel_data        : in  std_logic_vector(19 downto 0)  := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(1 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(235 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(235 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_2_10_125_1250;

-- ./a10/ip/ip_xcvr_phy_4_10_125_1250/ip_xcvr_phy_4_10_125_1250.cmp
	component ip_xcvr_phy_4_10_125_1250 is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(11 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(39 downto 0);                     -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_parallel_data        : in  std_logic_vector(39 downto 0)  := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(471 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(471 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_4_10_125_1250;

-- ./a10/ip/ip_xcvr_phy_4_40_125_10000_enh/ip_xcvr_phy_4_40_125_10000_enh.cmp
	component ip_xcvr_phy_4_40_125_10000_enh is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(11 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(159 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_enh_data_valid       : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_enh_data_valid
			tx_parallel_data        : in  std_logic_vector(159 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(351 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(351 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_4_40_125_10000_enh;

-- ./a10/ip/ip_xcvr_phy_4_40_125_5000_enh/ip_xcvr_phy_4_40_125_5000_enh.cmp
	component ip_xcvr_phy_4_40_125_5000_enh is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(11 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(159 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_enh_data_valid       : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_enh_data_valid
			tx_parallel_data        : in  std_logic_vector(159 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(351 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(351 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_4_40_125_5000_enh;

-- ./a10/ip/ip_xcvr_phy_4_40_125_5000/ip_xcvr_phy_4_40_125_5000.cmp
	component ip_xcvr_phy_4_40_125_5000 is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(11 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(159 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_parallel_data        : in  std_logic_vector(159 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(351 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(351 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_4_40_125_5000;

-- ./a10/ip/ip_xcvr_phy_4_40_125_6250_enh/ip_xcvr_phy_4_40_125_6250_enh.cmp
	component ip_xcvr_phy_4_40_125_6250_enh is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(11 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(159 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_enh_data_valid       : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_enh_data_valid
			tx_parallel_data        : in  std_logic_vector(159 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(351 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(351 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_4_40_125_6250_enh;

-- ./a10/ip/ip_xcvr_phy_4_40_125_6250/ip_xcvr_phy_4_40_125_6250.cmp
	component ip_xcvr_phy_4_40_125_6250 is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(11 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(159 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(3 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_parallel_data        : in  std_logic_vector(159 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(351 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(351 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_4_40_125_6250;

-- ./a10/ip/ip_xcvr_phy_6_40_125_10000_enh/ip_xcvr_phy_6_40_125_10000_enh.cmp
	component ip_xcvr_phy_6_40_125_10000_enh is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(12 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(5 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(239 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(5 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_enh_data_valid       : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_enh_data_valid
			tx_parallel_data        : in  std_logic_vector(239 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(5 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(527 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(527 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_6_40_125_10000_enh;

-- ./a10/ip/ip_xcvr_phy_6_40_125_5000_enh/ip_xcvr_phy_6_40_125_5000_enh.cmp
	component ip_xcvr_phy_6_40_125_5000_enh is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(12 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(5 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(239 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(5 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_enh_data_valid       : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_enh_data_valid
			tx_parallel_data        : in  std_logic_vector(239 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(5 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(527 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(527 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_6_40_125_5000_enh;

-- ./a10/ip/ip_xcvr_phy_6_40_125_5000/ip_xcvr_phy_6_40_125_5000.cmp
	component ip_xcvr_phy_6_40_125_5000 is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(12 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(5 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(239 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(5 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_parallel_data        : in  std_logic_vector(239 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(5 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(527 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(527 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_6_40_125_5000;

-- ./a10/ip/ip_xcvr_phy_6_40_125_6250_enh/ip_xcvr_phy_6_40_125_6250_enh.cmp
	component ip_xcvr_phy_6_40_125_6250_enh is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(12 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(5 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(239 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(5 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_enh_data_valid       : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_enh_data_valid
			tx_parallel_data        : in  std_logic_vector(239 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(5 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(527 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(527 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_6_40_125_6250_enh;

-- ./a10/ip/ip_xcvr_phy_6_40_125_6250/ip_xcvr_phy_6_40_125_6250.cmp
	component ip_xcvr_phy_6_40_125_6250 is
		port (
			reconfig_write          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- write
			reconfig_read           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- read
			reconfig_address        : in  std_logic_vector(12 downto 0)  := (others => 'X'); -- address
			reconfig_writedata      : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			reconfig_readdata       : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_waitrequest    : out std_logic_vector(0 downto 0);                      -- waitrequest
			reconfig_clk            : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- clk
			reconfig_reset          : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- reset
			rx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_bitslip              : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_bitslip
			rx_cal_busy             : out std_logic_vector(5 downto 0);                      -- rx_cal_busy
			rx_cdr_refclk0          : in  std_logic                      := 'X';             -- clk
			rx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			rx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			rx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_is_lockedtodata      : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtodata
			rx_is_lockedtoref       : out std_logic_vector(5 downto 0);                      -- rx_is_lockedtoref
			rx_parallel_data        : out std_logic_vector(239 downto 0);                    -- rx_parallel_data
			rx_serial_data          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_seriallpbken         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_analogreset          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_cal_busy             : out std_logic_vector(5 downto 0);                      -- tx_cal_busy
			tx_clkout               : out std_logic_vector(5 downto 0);                      -- clk
			tx_coreclkin            : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_digitalreset         : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_parallel_data        : in  std_logic_vector(239 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_serial_clk0          : in  std_logic_vector(5 downto 0)   := (others => 'X'); -- clk
			tx_serial_data          : out std_logic_vector(5 downto 0);                      -- tx_serial_data
			unused_rx_parallel_data : out std_logic_vector(527 downto 0);                    -- unused_rx_parallel_data
			unused_tx_parallel_data : in  std_logic_vector(527 downto 0) := (others => 'X')  -- unused_tx_parallel_data
		);
	end component ip_xcvr_phy_6_40_125_6250;

-- ./a10/ip/ip_xcvr_reset_2_100/ip_xcvr_reset_2_100.cmp
	component ip_xcvr_reset_2_100 is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			reset              : in  std_logic                    := 'X';             -- reset
			rx_analogreset     : out std_logic_vector(1 downto 0);                    -- rx_analogreset
			rx_cal_busy        : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_cal_busy
			rx_digitalreset    : out std_logic_vector(1 downto 0);                    -- rx_digitalreset
			rx_is_lockedtodata : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_ready           : out std_logic_vector(1 downto 0);                    -- rx_ready
			tx_analogreset     : out std_logic_vector(1 downto 0);                    -- tx_analogreset
			tx_cal_busy        : in  std_logic_vector(1 downto 0) := (others => 'X'); -- tx_cal_busy
			tx_digitalreset    : out std_logic_vector(1 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(1 downto 0)                     -- tx_ready
		);
	end component ip_xcvr_reset_2_100;

-- ./a10/ip/ip_xcvr_reset_2_50/ip_xcvr_reset_2_50.cmp
	component ip_xcvr_reset_2_50 is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			reset              : in  std_logic                    := 'X';             -- reset
			rx_analogreset     : out std_logic_vector(1 downto 0);                    -- rx_analogreset
			rx_cal_busy        : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_cal_busy
			rx_digitalreset    : out std_logic_vector(1 downto 0);                    -- rx_digitalreset
			rx_is_lockedtodata : in  std_logic_vector(1 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_ready           : out std_logic_vector(1 downto 0);                    -- rx_ready
			tx_analogreset     : out std_logic_vector(1 downto 0);                    -- tx_analogreset
			tx_cal_busy        : in  std_logic_vector(1 downto 0) := (others => 'X'); -- tx_cal_busy
			tx_digitalreset    : out std_logic_vector(1 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(1 downto 0)                     -- tx_ready
		);
	end component ip_xcvr_reset_2_50;

-- ./a10/ip/ip_xcvr_reset_4_100/ip_xcvr_reset_4_100.cmp
	component ip_xcvr_reset_4_100 is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			reset              : in  std_logic                    := 'X';             -- reset
			rx_analogreset     : out std_logic_vector(3 downto 0);                    -- rx_analogreset
			rx_cal_busy        : in  std_logic_vector(3 downto 0) := (others => 'X'); -- rx_cal_busy
			rx_digitalreset    : out std_logic_vector(3 downto 0);                    -- rx_digitalreset
			rx_is_lockedtodata : in  std_logic_vector(3 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_ready           : out std_logic_vector(3 downto 0);                    -- rx_ready
			tx_analogreset     : out std_logic_vector(3 downto 0);                    -- tx_analogreset
			tx_cal_busy        : in  std_logic_vector(3 downto 0) := (others => 'X'); -- tx_cal_busy
			tx_digitalreset    : out std_logic_vector(3 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(3 downto 0)                     -- tx_ready
		);
	end component ip_xcvr_reset_4_100;

-- ./a10/ip/ip_xcvr_reset_4_50/ip_xcvr_reset_4_50.cmp
	component ip_xcvr_reset_4_50 is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			reset              : in  std_logic                    := 'X';             -- reset
			rx_analogreset     : out std_logic_vector(3 downto 0);                    -- rx_analogreset
			rx_cal_busy        : in  std_logic_vector(3 downto 0) := (others => 'X'); -- rx_cal_busy
			rx_digitalreset    : out std_logic_vector(3 downto 0);                    -- rx_digitalreset
			rx_is_lockedtodata : in  std_logic_vector(3 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_ready           : out std_logic_vector(3 downto 0);                    -- rx_ready
			tx_analogreset     : out std_logic_vector(3 downto 0);                    -- tx_analogreset
			tx_cal_busy        : in  std_logic_vector(3 downto 0) := (others => 'X'); -- tx_cal_busy
			tx_digitalreset    : out std_logic_vector(3 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(3 downto 0)                     -- tx_ready
		);
	end component ip_xcvr_reset_4_50;

-- ./a10/ip/ip_xcvr_reset_6_100/ip_xcvr_reset_6_100.cmp
	component ip_xcvr_reset_6_100 is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			reset              : in  std_logic                    := 'X';             -- reset
			rx_analogreset     : out std_logic_vector(5 downto 0);                    -- rx_analogreset
			rx_cal_busy        : in  std_logic_vector(5 downto 0) := (others => 'X'); -- rx_cal_busy
			rx_digitalreset    : out std_logic_vector(5 downto 0);                    -- rx_digitalreset
			rx_is_lockedtodata : in  std_logic_vector(5 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_ready           : out std_logic_vector(5 downto 0);                    -- rx_ready
			tx_analogreset     : out std_logic_vector(5 downto 0);                    -- tx_analogreset
			tx_cal_busy        : in  std_logic_vector(5 downto 0) := (others => 'X'); -- tx_cal_busy
			tx_digitalreset    : out std_logic_vector(5 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(5 downto 0)                     -- tx_ready
		);
	end component ip_xcvr_reset_6_100;

-- ./a10/ip/ip_xcvr_reset_6_50/ip_xcvr_reset_6_50.cmp
	component ip_xcvr_reset_6_50 is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			pll_cal_busy       : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_cal_busy
			pll_locked         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_locked
			pll_powerdown      : out std_logic_vector(0 downto 0);                    -- pll_powerdown
			pll_select         : in  std_logic_vector(0 downto 0) := (others => 'X'); -- pll_select
			reset              : in  std_logic                    := 'X';             -- reset
			rx_analogreset     : out std_logic_vector(5 downto 0);                    -- rx_analogreset
			rx_cal_busy        : in  std_logic_vector(5 downto 0) := (others => 'X'); -- rx_cal_busy
			rx_digitalreset    : out std_logic_vector(5 downto 0);                    -- rx_digitalreset
			rx_is_lockedtodata : in  std_logic_vector(5 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_ready           : out std_logic_vector(5 downto 0);                    -- rx_ready
			tx_analogreset     : out std_logic_vector(5 downto 0);                    -- tx_analogreset
			tx_cal_busy        : in  std_logic_vector(5 downto 0) := (others => 'X'); -- tx_cal_busy
			tx_digitalreset    : out std_logic_vector(5 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(5 downto 0)                     -- tx_ready
		);
	end component ip_xcvr_reset_6_50;

-- ./a10/pcieapp/ip_pcie_x4_256/ip_pcie_x4_256.cmp
	component ip_pcie_x4_256 is
		port (
			clr_st              : out std_logic;                                         -- reset
			hpg_ctrler          : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- hpg_ctrler
			tl_cfg_add          : out std_logic_vector(3 downto 0);                      -- tl_cfg_add
			tl_cfg_ctl          : out std_logic_vector(31 downto 0);                     -- tl_cfg_ctl
			tl_cfg_sts          : out std_logic_vector(52 downto 0);                     -- tl_cfg_sts
			cpl_err             : in  std_logic_vector(6 downto 0)   := (others => 'X'); -- cpl_err
			cpl_pending         : in  std_logic                      := 'X';             -- cpl_pending
			coreclkout_hip      : out std_logic;                                         -- clk
			currentspeed        : out std_logic_vector(1 downto 0);                      -- currentspeed
			test_in             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- test_in
			simu_mode_pipe      : in  std_logic                      := 'X';             -- simu_mode_pipe
			sim_pipe_pclk_in    : in  std_logic                      := 'X';             -- sim_pipe_pclk_in
			sim_pipe_rate       : out std_logic_vector(1 downto 0);                      -- sim_pipe_rate
			sim_ltssmstate      : out std_logic_vector(4 downto 0);                      -- sim_ltssmstate
			eidleinfersel0      : out std_logic_vector(2 downto 0);                      -- eidleinfersel0
			eidleinfersel1      : out std_logic_vector(2 downto 0);                      -- eidleinfersel1
			eidleinfersel2      : out std_logic_vector(2 downto 0);                      -- eidleinfersel2
			eidleinfersel3      : out std_logic_vector(2 downto 0);                      -- eidleinfersel3
			powerdown0          : out std_logic_vector(1 downto 0);                      -- powerdown0
			powerdown1          : out std_logic_vector(1 downto 0);                      -- powerdown1
			powerdown2          : out std_logic_vector(1 downto 0);                      -- powerdown2
			powerdown3          : out std_logic_vector(1 downto 0);                      -- powerdown3
			rxpolarity0         : out std_logic;                                         -- rxpolarity0
			rxpolarity1         : out std_logic;                                         -- rxpolarity1
			rxpolarity2         : out std_logic;                                         -- rxpolarity2
			rxpolarity3         : out std_logic;                                         -- rxpolarity3
			txcompl0            : out std_logic;                                         -- txcompl0
			txcompl1            : out std_logic;                                         -- txcompl1
			txcompl2            : out std_logic;                                         -- txcompl2
			txcompl3            : out std_logic;                                         -- txcompl3
			txdata0             : out std_logic_vector(31 downto 0);                     -- txdata0
			txdata1             : out std_logic_vector(31 downto 0);                     -- txdata1
			txdata2             : out std_logic_vector(31 downto 0);                     -- txdata2
			txdata3             : out std_logic_vector(31 downto 0);                     -- txdata3
			txdatak0            : out std_logic_vector(3 downto 0);                      -- txdatak0
			txdatak1            : out std_logic_vector(3 downto 0);                      -- txdatak1
			txdatak2            : out std_logic_vector(3 downto 0);                      -- txdatak2
			txdatak3            : out std_logic_vector(3 downto 0);                      -- txdatak3
			txdetectrx0         : out std_logic;                                         -- txdetectrx0
			txdetectrx1         : out std_logic;                                         -- txdetectrx1
			txdetectrx2         : out std_logic;                                         -- txdetectrx2
			txdetectrx3         : out std_logic;                                         -- txdetectrx3
			txelecidle0         : out std_logic;                                         -- txelecidle0
			txelecidle1         : out std_logic;                                         -- txelecidle1
			txelecidle2         : out std_logic;                                         -- txelecidle2
			txelecidle3         : out std_logic;                                         -- txelecidle3
			txdeemph0           : out std_logic;                                         -- txdeemph0
			txdeemph1           : out std_logic;                                         -- txdeemph1
			txdeemph2           : out std_logic;                                         -- txdeemph2
			txdeemph3           : out std_logic;                                         -- txdeemph3
			txmargin0           : out std_logic_vector(2 downto 0);                      -- txmargin0
			txmargin1           : out std_logic_vector(2 downto 0);                      -- txmargin1
			txmargin2           : out std_logic_vector(2 downto 0);                      -- txmargin2
			txmargin3           : out std_logic_vector(2 downto 0);                      -- txmargin3
			txswing0            : out std_logic;                                         -- txswing0
			txswing1            : out std_logic;                                         -- txswing1
			txswing2            : out std_logic;                                         -- txswing2
			txswing3            : out std_logic;                                         -- txswing3
			phystatus0          : in  std_logic                      := 'X';             -- phystatus0
			phystatus1          : in  std_logic                      := 'X';             -- phystatus1
			phystatus2          : in  std_logic                      := 'X';             -- phystatus2
			phystatus3          : in  std_logic                      := 'X';             -- phystatus3
			rxdata0             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata0
			rxdata1             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata1
			rxdata2             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata2
			rxdata3             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata3
			rxdatak0            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak0
			rxdatak1            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak1
			rxdatak2            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak2
			rxdatak3            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak3
			rxelecidle0         : in  std_logic                      := 'X';             -- rxelecidle0
			rxelecidle1         : in  std_logic                      := 'X';             -- rxelecidle1
			rxelecidle2         : in  std_logic                      := 'X';             -- rxelecidle2
			rxelecidle3         : in  std_logic                      := 'X';             -- rxelecidle3
			rxstatus0           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus0
			rxstatus1           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus1
			rxstatus2           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus2
			rxstatus3           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus3
			rxvalid0            : in  std_logic                      := 'X';             -- rxvalid0
			rxvalid1            : in  std_logic                      := 'X';             -- rxvalid1
			rxvalid2            : in  std_logic                      := 'X';             -- rxvalid2
			rxvalid3            : in  std_logic                      := 'X';             -- rxvalid3
			rxdataskip0         : in  std_logic                      := 'X';             -- rxdataskip0
			rxdataskip1         : in  std_logic                      := 'X';             -- rxdataskip1
			rxdataskip2         : in  std_logic                      := 'X';             -- rxdataskip2
			rxdataskip3         : in  std_logic                      := 'X';             -- rxdataskip3
			rxblkst0            : in  std_logic                      := 'X';             -- rxblkst0
			rxblkst1            : in  std_logic                      := 'X';             -- rxblkst1
			rxblkst2            : in  std_logic                      := 'X';             -- rxblkst2
			rxblkst3            : in  std_logic                      := 'X';             -- rxblkst3
			rxsynchd0           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd0
			rxsynchd1           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd1
			rxsynchd2           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd2
			rxsynchd3           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd3
			currentcoeff0       : out std_logic_vector(17 downto 0);                     -- currentcoeff0
			currentcoeff1       : out std_logic_vector(17 downto 0);                     -- currentcoeff1
			currentcoeff2       : out std_logic_vector(17 downto 0);                     -- currentcoeff2
			currentcoeff3       : out std_logic_vector(17 downto 0);                     -- currentcoeff3
			currentrxpreset0    : out std_logic_vector(2 downto 0);                      -- currentrxpreset0
			currentrxpreset1    : out std_logic_vector(2 downto 0);                      -- currentrxpreset1
			currentrxpreset2    : out std_logic_vector(2 downto 0);                      -- currentrxpreset2
			currentrxpreset3    : out std_logic_vector(2 downto 0);                      -- currentrxpreset3
			txsynchd0           : out std_logic_vector(1 downto 0);                      -- txsynchd0
			txsynchd1           : out std_logic_vector(1 downto 0);                      -- txsynchd1
			txsynchd2           : out std_logic_vector(1 downto 0);                      -- txsynchd2
			txsynchd3           : out std_logic_vector(1 downto 0);                      -- txsynchd3
			txblkst0            : out std_logic;                                         -- txblkst0
			txblkst1            : out std_logic;                                         -- txblkst1
			txblkst2            : out std_logic;                                         -- txblkst2
			txblkst3            : out std_logic;                                         -- txblkst3
			txdataskip0         : out std_logic;                                         -- txdataskip0
			txdataskip1         : out std_logic;                                         -- txdataskip1
			txdataskip2         : out std_logic;                                         -- txdataskip2
			txdataskip3         : out std_logic;                                         -- txdataskip3
			rate0               : out std_logic_vector(1 downto 0);                      -- rate0
			rate1               : out std_logic_vector(1 downto 0);                      -- rate1
			rate2               : out std_logic_vector(1 downto 0);                      -- rate2
			rate3               : out std_logic_vector(1 downto 0);                      -- rate3
			pld_core_ready      : in  std_logic                      := 'X';             -- pld_core_ready
			pld_clk_inuse       : out std_logic;                                         -- pld_clk_inuse
			serdes_pll_locked   : out std_logic;                                         -- serdes_pll_locked
			reset_status        : out std_logic;                                         -- reset_status
			testin_zero         : out std_logic;                                         -- testin_zero
			rx_in0              : in  std_logic                      := 'X';             -- rx_in0
			rx_in1              : in  std_logic                      := 'X';             -- rx_in1
			rx_in2              : in  std_logic                      := 'X';             -- rx_in2
			rx_in3              : in  std_logic                      := 'X';             -- rx_in3
			tx_out0             : out std_logic;                                         -- tx_out0
			tx_out1             : out std_logic;                                         -- tx_out1
			tx_out2             : out std_logic;                                         -- tx_out2
			tx_out3             : out std_logic;                                         -- tx_out3
			derr_cor_ext_rcv    : out std_logic;                                         -- derr_cor_ext_rcv
			derr_cor_ext_rpl    : out std_logic;                                         -- derr_cor_ext_rpl
			derr_rpl            : out std_logic;                                         -- derr_rpl
			dlup                : out std_logic;                                         -- dlup
			dlup_exit           : out std_logic;                                         -- dlup_exit
			ev128ns             : out std_logic;                                         -- ev128ns
			ev1us               : out std_logic;                                         -- ev1us
			hotrst_exit         : out std_logic;                                         -- hotrst_exit
			int_status          : out std_logic_vector(3 downto 0);                      -- int_status
			l2_exit             : out std_logic;                                         -- l2_exit
			lane_act            : out std_logic_vector(3 downto 0);                      -- lane_act
			ltssmstate          : out std_logic_vector(4 downto 0);                      -- ltssmstate
			rx_par_err          : out std_logic;                                         -- rx_par_err
			tx_par_err          : out std_logic_vector(1 downto 0);                      -- tx_par_err
			cfg_par_err         : out std_logic;                                         -- cfg_par_err
			ko_cpl_spc_header   : out std_logic_vector(7 downto 0);                      -- ko_cpl_spc_header
			ko_cpl_spc_data     : out std_logic_vector(11 downto 0);                     -- ko_cpl_spc_data
			app_int_sts         : in  std_logic                      := 'X';             -- app_int_sts
			app_int_ack         : out std_logic;                                         -- app_int_ack
			app_msi_num         : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- app_msi_num
			app_msi_req         : in  std_logic                      := 'X';             -- app_msi_req
			app_msi_tc          : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- app_msi_tc
			app_msi_ack         : out std_logic;                                         -- app_msi_ack
			npor                : in  std_logic                      := 'X';             -- npor
			pin_perst           : in  std_logic                      := 'X';             -- pin_perst
			pld_clk             : in  std_logic                      := 'X';             -- clk
			pm_auxpwr           : in  std_logic                      := 'X';             -- pm_auxpwr
			pm_data             : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- pm_data
			pme_to_cr           : in  std_logic                      := 'X';             -- pme_to_cr
			pm_event            : in  std_logic                      := 'X';             -- pm_event
			pme_to_sr           : out std_logic;                                         -- pme_to_sr
			refclk              : in  std_logic                      := 'X';             -- clk
			rx_st_bar           : out std_logic_vector(7 downto 0);                      -- rx_st_bar
			rx_st_mask          : in  std_logic                      := 'X';             -- rx_st_mask
			rx_st_sop           : out std_logic_vector(0 downto 0);                      -- startofpacket
			rx_st_eop           : out std_logic_vector(0 downto 0);                      -- endofpacket
			rx_st_err           : out std_logic_vector(0 downto 0);                      -- error
			rx_st_valid         : out std_logic_vector(0 downto 0);                      -- valid
			rx_st_ready         : in  std_logic                      := 'X';             -- ready
			rx_st_data          : out std_logic_vector(255 downto 0);                    -- data
			rx_st_empty         : out std_logic_vector(1 downto 0);                      -- empty
			tx_cred_data_fc     : out std_logic_vector(11 downto 0);                     -- tx_cred_data_fc
			tx_cred_fc_hip_cons : out std_logic_vector(5 downto 0);                      -- tx_cred_fc_hip_cons
			tx_cred_fc_infinite : out std_logic_vector(5 downto 0);                      -- tx_cred_fc_infinite
			tx_cred_hdr_fc      : out std_logic_vector(7 downto 0);                      -- tx_cred_hdr_fc
			tx_cred_fc_sel      : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- tx_cred_fc_sel
			tx_st_sop           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- startofpacket
			tx_st_eop           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- endofpacket
			tx_st_err           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- error
			tx_st_valid         : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- valid
			tx_st_ready         : out std_logic;                                         -- ready
			tx_st_data          : in  std_logic_vector(255 downto 0) := (others => 'X'); -- data
			tx_st_empty         : in  std_logic_vector(1 downto 0)   := (others => 'X')  -- empty
		);
	end component ip_pcie_x4_256;

-- ./a10/pcieapp/ip_pcie_x8_256/ip_pcie_x8_256.cmp
	component ip_pcie_x8_256 is
		port (
			clr_st              : out std_logic;                                         -- reset
			hpg_ctrler          : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- hpg_ctrler
			tl_cfg_add          : out std_logic_vector(3 downto 0);                      -- tl_cfg_add
			tl_cfg_ctl          : out std_logic_vector(31 downto 0);                     -- tl_cfg_ctl
			tl_cfg_sts          : out std_logic_vector(52 downto 0);                     -- tl_cfg_sts
			cpl_err             : in  std_logic_vector(6 downto 0)   := (others => 'X'); -- cpl_err
			cpl_pending         : in  std_logic                      := 'X';             -- cpl_pending
			coreclkout_hip      : out std_logic;                                         -- clk
			currentspeed        : out std_logic_vector(1 downto 0);                      -- currentspeed
			test_in             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- test_in
			simu_mode_pipe      : in  std_logic                      := 'X';             -- simu_mode_pipe
			sim_pipe_pclk_in    : in  std_logic                      := 'X';             -- sim_pipe_pclk_in
			sim_pipe_rate       : out std_logic_vector(1 downto 0);                      -- sim_pipe_rate
			sim_ltssmstate      : out std_logic_vector(4 downto 0);                      -- sim_ltssmstate
			eidleinfersel0      : out std_logic_vector(2 downto 0);                      -- eidleinfersel0
			eidleinfersel1      : out std_logic_vector(2 downto 0);                      -- eidleinfersel1
			eidleinfersel2      : out std_logic_vector(2 downto 0);                      -- eidleinfersel2
			eidleinfersel3      : out std_logic_vector(2 downto 0);                      -- eidleinfersel3
			eidleinfersel4      : out std_logic_vector(2 downto 0);                      -- eidleinfersel4
			eidleinfersel5      : out std_logic_vector(2 downto 0);                      -- eidleinfersel5
			eidleinfersel6      : out std_logic_vector(2 downto 0);                      -- eidleinfersel6
			eidleinfersel7      : out std_logic_vector(2 downto 0);                      -- eidleinfersel7
			powerdown0          : out std_logic_vector(1 downto 0);                      -- powerdown0
			powerdown1          : out std_logic_vector(1 downto 0);                      -- powerdown1
			powerdown2          : out std_logic_vector(1 downto 0);                      -- powerdown2
			powerdown3          : out std_logic_vector(1 downto 0);                      -- powerdown3
			powerdown4          : out std_logic_vector(1 downto 0);                      -- powerdown4
			powerdown5          : out std_logic_vector(1 downto 0);                      -- powerdown5
			powerdown6          : out std_logic_vector(1 downto 0);                      -- powerdown6
			powerdown7          : out std_logic_vector(1 downto 0);                      -- powerdown7
			rxpolarity0         : out std_logic;                                         -- rxpolarity0
			rxpolarity1         : out std_logic;                                         -- rxpolarity1
			rxpolarity2         : out std_logic;                                         -- rxpolarity2
			rxpolarity3         : out std_logic;                                         -- rxpolarity3
			rxpolarity4         : out std_logic;                                         -- rxpolarity4
			rxpolarity5         : out std_logic;                                         -- rxpolarity5
			rxpolarity6         : out std_logic;                                         -- rxpolarity6
			rxpolarity7         : out std_logic;                                         -- rxpolarity7
			txcompl0            : out std_logic;                                         -- txcompl0
			txcompl1            : out std_logic;                                         -- txcompl1
			txcompl2            : out std_logic;                                         -- txcompl2
			txcompl3            : out std_logic;                                         -- txcompl3
			txcompl4            : out std_logic;                                         -- txcompl4
			txcompl5            : out std_logic;                                         -- txcompl5
			txcompl6            : out std_logic;                                         -- txcompl6
			txcompl7            : out std_logic;                                         -- txcompl7
			txdata0             : out std_logic_vector(31 downto 0);                     -- txdata0
			txdata1             : out std_logic_vector(31 downto 0);                     -- txdata1
			txdata2             : out std_logic_vector(31 downto 0);                     -- txdata2
			txdata3             : out std_logic_vector(31 downto 0);                     -- txdata3
			txdata4             : out std_logic_vector(31 downto 0);                     -- txdata4
			txdata5             : out std_logic_vector(31 downto 0);                     -- txdata5
			txdata6             : out std_logic_vector(31 downto 0);                     -- txdata6
			txdata7             : out std_logic_vector(31 downto 0);                     -- txdata7
			txdatak0            : out std_logic_vector(3 downto 0);                      -- txdatak0
			txdatak1            : out std_logic_vector(3 downto 0);                      -- txdatak1
			txdatak2            : out std_logic_vector(3 downto 0);                      -- txdatak2
			txdatak3            : out std_logic_vector(3 downto 0);                      -- txdatak3
			txdatak4            : out std_logic_vector(3 downto 0);                      -- txdatak4
			txdatak5            : out std_logic_vector(3 downto 0);                      -- txdatak5
			txdatak6            : out std_logic_vector(3 downto 0);                      -- txdatak6
			txdatak7            : out std_logic_vector(3 downto 0);                      -- txdatak7
			txdetectrx0         : out std_logic;                                         -- txdetectrx0
			txdetectrx1         : out std_logic;                                         -- txdetectrx1
			txdetectrx2         : out std_logic;                                         -- txdetectrx2
			txdetectrx3         : out std_logic;                                         -- txdetectrx3
			txdetectrx4         : out std_logic;                                         -- txdetectrx4
			txdetectrx5         : out std_logic;                                         -- txdetectrx5
			txdetectrx6         : out std_logic;                                         -- txdetectrx6
			txdetectrx7         : out std_logic;                                         -- txdetectrx7
			txelecidle0         : out std_logic;                                         -- txelecidle0
			txelecidle1         : out std_logic;                                         -- txelecidle1
			txelecidle2         : out std_logic;                                         -- txelecidle2
			txelecidle3         : out std_logic;                                         -- txelecidle3
			txelecidle4         : out std_logic;                                         -- txelecidle4
			txelecidle5         : out std_logic;                                         -- txelecidle5
			txelecidle6         : out std_logic;                                         -- txelecidle6
			txelecidle7         : out std_logic;                                         -- txelecidle7
			txdeemph0           : out std_logic;                                         -- txdeemph0
			txdeemph1           : out std_logic;                                         -- txdeemph1
			txdeemph2           : out std_logic;                                         -- txdeemph2
			txdeemph3           : out std_logic;                                         -- txdeemph3
			txdeemph4           : out std_logic;                                         -- txdeemph4
			txdeemph5           : out std_logic;                                         -- txdeemph5
			txdeemph6           : out std_logic;                                         -- txdeemph6
			txdeemph7           : out std_logic;                                         -- txdeemph7
			txmargin0           : out std_logic_vector(2 downto 0);                      -- txmargin0
			txmargin1           : out std_logic_vector(2 downto 0);                      -- txmargin1
			txmargin2           : out std_logic_vector(2 downto 0);                      -- txmargin2
			txmargin3           : out std_logic_vector(2 downto 0);                      -- txmargin3
			txmargin4           : out std_logic_vector(2 downto 0);                      -- txmargin4
			txmargin5           : out std_logic_vector(2 downto 0);                      -- txmargin5
			txmargin6           : out std_logic_vector(2 downto 0);                      -- txmargin6
			txmargin7           : out std_logic_vector(2 downto 0);                      -- txmargin7
			txswing0            : out std_logic;                                         -- txswing0
			txswing1            : out std_logic;                                         -- txswing1
			txswing2            : out std_logic;                                         -- txswing2
			txswing3            : out std_logic;                                         -- txswing3
			txswing4            : out std_logic;                                         -- txswing4
			txswing5            : out std_logic;                                         -- txswing5
			txswing6            : out std_logic;                                         -- txswing6
			txswing7            : out std_logic;                                         -- txswing7
			phystatus0          : in  std_logic                      := 'X';             -- phystatus0
			phystatus1          : in  std_logic                      := 'X';             -- phystatus1
			phystatus2          : in  std_logic                      := 'X';             -- phystatus2
			phystatus3          : in  std_logic                      := 'X';             -- phystatus3
			phystatus4          : in  std_logic                      := 'X';             -- phystatus4
			phystatus5          : in  std_logic                      := 'X';             -- phystatus5
			phystatus6          : in  std_logic                      := 'X';             -- phystatus6
			phystatus7          : in  std_logic                      := 'X';             -- phystatus7
			rxdata0             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata0
			rxdata1             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata1
			rxdata2             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata2
			rxdata3             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata3
			rxdata4             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata4
			rxdata5             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata5
			rxdata6             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata6
			rxdata7             : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- rxdata7
			rxdatak0            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak0
			rxdatak1            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak1
			rxdatak2            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak2
			rxdatak3            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak3
			rxdatak4            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak4
			rxdatak5            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak5
			rxdatak6            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak6
			rxdatak7            : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rxdatak7
			rxelecidle0         : in  std_logic                      := 'X';             -- rxelecidle0
			rxelecidle1         : in  std_logic                      := 'X';             -- rxelecidle1
			rxelecidle2         : in  std_logic                      := 'X';             -- rxelecidle2
			rxelecidle3         : in  std_logic                      := 'X';             -- rxelecidle3
			rxelecidle4         : in  std_logic                      := 'X';             -- rxelecidle4
			rxelecidle5         : in  std_logic                      := 'X';             -- rxelecidle5
			rxelecidle6         : in  std_logic                      := 'X';             -- rxelecidle6
			rxelecidle7         : in  std_logic                      := 'X';             -- rxelecidle7
			rxstatus0           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus0
			rxstatus1           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus1
			rxstatus2           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus2
			rxstatus3           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus3
			rxstatus4           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus4
			rxstatus5           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus5
			rxstatus6           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus6
			rxstatus7           : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- rxstatus7
			rxvalid0            : in  std_logic                      := 'X';             -- rxvalid0
			rxvalid1            : in  std_logic                      := 'X';             -- rxvalid1
			rxvalid2            : in  std_logic                      := 'X';             -- rxvalid2
			rxvalid3            : in  std_logic                      := 'X';             -- rxvalid3
			rxvalid4            : in  std_logic                      := 'X';             -- rxvalid4
			rxvalid5            : in  std_logic                      := 'X';             -- rxvalid5
			rxvalid6            : in  std_logic                      := 'X';             -- rxvalid6
			rxvalid7            : in  std_logic                      := 'X';             -- rxvalid7
			rxdataskip0         : in  std_logic                      := 'X';             -- rxdataskip0
			rxdataskip1         : in  std_logic                      := 'X';             -- rxdataskip1
			rxdataskip2         : in  std_logic                      := 'X';             -- rxdataskip2
			rxdataskip3         : in  std_logic                      := 'X';             -- rxdataskip3
			rxdataskip4         : in  std_logic                      := 'X';             -- rxdataskip4
			rxdataskip5         : in  std_logic                      := 'X';             -- rxdataskip5
			rxdataskip6         : in  std_logic                      := 'X';             -- rxdataskip6
			rxdataskip7         : in  std_logic                      := 'X';             -- rxdataskip7
			rxblkst0            : in  std_logic                      := 'X';             -- rxblkst0
			rxblkst1            : in  std_logic                      := 'X';             -- rxblkst1
			rxblkst2            : in  std_logic                      := 'X';             -- rxblkst2
			rxblkst3            : in  std_logic                      := 'X';             -- rxblkst3
			rxblkst4            : in  std_logic                      := 'X';             -- rxblkst4
			rxblkst5            : in  std_logic                      := 'X';             -- rxblkst5
			rxblkst6            : in  std_logic                      := 'X';             -- rxblkst6
			rxblkst7            : in  std_logic                      := 'X';             -- rxblkst7
			rxsynchd0           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd0
			rxsynchd1           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd1
			rxsynchd2           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd2
			rxsynchd3           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd3
			rxsynchd4           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd4
			rxsynchd5           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd5
			rxsynchd6           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd6
			rxsynchd7           : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- rxsynchd7
			currentcoeff0       : out std_logic_vector(17 downto 0);                     -- currentcoeff0
			currentcoeff1       : out std_logic_vector(17 downto 0);                     -- currentcoeff1
			currentcoeff2       : out std_logic_vector(17 downto 0);                     -- currentcoeff2
			currentcoeff3       : out std_logic_vector(17 downto 0);                     -- currentcoeff3
			currentcoeff4       : out std_logic_vector(17 downto 0);                     -- currentcoeff4
			currentcoeff5       : out std_logic_vector(17 downto 0);                     -- currentcoeff5
			currentcoeff6       : out std_logic_vector(17 downto 0);                     -- currentcoeff6
			currentcoeff7       : out std_logic_vector(17 downto 0);                     -- currentcoeff7
			currentrxpreset0    : out std_logic_vector(2 downto 0);                      -- currentrxpreset0
			currentrxpreset1    : out std_logic_vector(2 downto 0);                      -- currentrxpreset1
			currentrxpreset2    : out std_logic_vector(2 downto 0);                      -- currentrxpreset2
			currentrxpreset3    : out std_logic_vector(2 downto 0);                      -- currentrxpreset3
			currentrxpreset4    : out std_logic_vector(2 downto 0);                      -- currentrxpreset4
			currentrxpreset5    : out std_logic_vector(2 downto 0);                      -- currentrxpreset5
			currentrxpreset6    : out std_logic_vector(2 downto 0);                      -- currentrxpreset6
			currentrxpreset7    : out std_logic_vector(2 downto 0);                      -- currentrxpreset7
			txsynchd0           : out std_logic_vector(1 downto 0);                      -- txsynchd0
			txsynchd1           : out std_logic_vector(1 downto 0);                      -- txsynchd1
			txsynchd2           : out std_logic_vector(1 downto 0);                      -- txsynchd2
			txsynchd3           : out std_logic_vector(1 downto 0);                      -- txsynchd3
			txsynchd4           : out std_logic_vector(1 downto 0);                      -- txsynchd4
			txsynchd5           : out std_logic_vector(1 downto 0);                      -- txsynchd5
			txsynchd6           : out std_logic_vector(1 downto 0);                      -- txsynchd6
			txsynchd7           : out std_logic_vector(1 downto 0);                      -- txsynchd7
			txblkst0            : out std_logic;                                         -- txblkst0
			txblkst1            : out std_logic;                                         -- txblkst1
			txblkst2            : out std_logic;                                         -- txblkst2
			txblkst3            : out std_logic;                                         -- txblkst3
			txblkst4            : out std_logic;                                         -- txblkst4
			txblkst5            : out std_logic;                                         -- txblkst5
			txblkst6            : out std_logic;                                         -- txblkst6
			txblkst7            : out std_logic;                                         -- txblkst7
			txdataskip0         : out std_logic;                                         -- txdataskip0
			txdataskip1         : out std_logic;                                         -- txdataskip1
			txdataskip2         : out std_logic;                                         -- txdataskip2
			txdataskip3         : out std_logic;                                         -- txdataskip3
			txdataskip4         : out std_logic;                                         -- txdataskip4
			txdataskip5         : out std_logic;                                         -- txdataskip5
			txdataskip6         : out std_logic;                                         -- txdataskip6
			txdataskip7         : out std_logic;                                         -- txdataskip7
			rate0               : out std_logic_vector(1 downto 0);                      -- rate0
			rate1               : out std_logic_vector(1 downto 0);                      -- rate1
			rate2               : out std_logic_vector(1 downto 0);                      -- rate2
			rate3               : out std_logic_vector(1 downto 0);                      -- rate3
			rate4               : out std_logic_vector(1 downto 0);                      -- rate4
			rate5               : out std_logic_vector(1 downto 0);                      -- rate5
			rate6               : out std_logic_vector(1 downto 0);                      -- rate6
			rate7               : out std_logic_vector(1 downto 0);                      -- rate7
			pld_core_ready      : in  std_logic                      := 'X';             -- pld_core_ready
			pld_clk_inuse       : out std_logic;                                         -- pld_clk_inuse
			serdes_pll_locked   : out std_logic;                                         -- serdes_pll_locked
			reset_status        : out std_logic;                                         -- reset_status
			testin_zero         : out std_logic;                                         -- testin_zero
			rx_in0              : in  std_logic                      := 'X';             -- rx_in0
			rx_in1              : in  std_logic                      := 'X';             -- rx_in1
			rx_in2              : in  std_logic                      := 'X';             -- rx_in2
			rx_in3              : in  std_logic                      := 'X';             -- rx_in3
			rx_in4              : in  std_logic                      := 'X';             -- rx_in4
			rx_in5              : in  std_logic                      := 'X';             -- rx_in5
			rx_in6              : in  std_logic                      := 'X';             -- rx_in6
			rx_in7              : in  std_logic                      := 'X';             -- rx_in7
			tx_out0             : out std_logic;                                         -- tx_out0
			tx_out1             : out std_logic;                                         -- tx_out1
			tx_out2             : out std_logic;                                         -- tx_out2
			tx_out3             : out std_logic;                                         -- tx_out3
			tx_out4             : out std_logic;                                         -- tx_out4
			tx_out5             : out std_logic;                                         -- tx_out5
			tx_out6             : out std_logic;                                         -- tx_out6
			tx_out7             : out std_logic;                                         -- tx_out7
			derr_cor_ext_rcv    : out std_logic;                                         -- derr_cor_ext_rcv
			derr_cor_ext_rpl    : out std_logic;                                         -- derr_cor_ext_rpl
			derr_rpl            : out std_logic;                                         -- derr_rpl
			dlup                : out std_logic;                                         -- dlup
			dlup_exit           : out std_logic;                                         -- dlup_exit
			ev128ns             : out std_logic;                                         -- ev128ns
			ev1us               : out std_logic;                                         -- ev1us
			hotrst_exit         : out std_logic;                                         -- hotrst_exit
			int_status          : out std_logic_vector(3 downto 0);                      -- int_status
			l2_exit             : out std_logic;                                         -- l2_exit
			lane_act            : out std_logic_vector(3 downto 0);                      -- lane_act
			ltssmstate          : out std_logic_vector(4 downto 0);                      -- ltssmstate
			rx_par_err          : out std_logic;                                         -- rx_par_err
			tx_par_err          : out std_logic_vector(1 downto 0);                      -- tx_par_err
			cfg_par_err         : out std_logic;                                         -- cfg_par_err
			ko_cpl_spc_header   : out std_logic_vector(7 downto 0);                      -- ko_cpl_spc_header
			ko_cpl_spc_data     : out std_logic_vector(11 downto 0);                     -- ko_cpl_spc_data
			app_int_sts         : in  std_logic                      := 'X';             -- app_int_sts
			app_int_ack         : out std_logic;                                         -- app_int_ack
			app_msi_num         : in  std_logic_vector(4 downto 0)   := (others => 'X'); -- app_msi_num
			app_msi_req         : in  std_logic                      := 'X';             -- app_msi_req
			app_msi_tc          : in  std_logic_vector(2 downto 0)   := (others => 'X'); -- app_msi_tc
			app_msi_ack         : out std_logic;                                         -- app_msi_ack
			npor                : in  std_logic                      := 'X';             -- npor
			pin_perst           : in  std_logic                      := 'X';             -- pin_perst
			pld_clk             : in  std_logic                      := 'X';             -- clk
			pm_auxpwr           : in  std_logic                      := 'X';             -- pm_auxpwr
			pm_data             : in  std_logic_vector(9 downto 0)   := (others => 'X'); -- pm_data
			pme_to_cr           : in  std_logic                      := 'X';             -- pme_to_cr
			pm_event            : in  std_logic                      := 'X';             -- pm_event
			pme_to_sr           : out std_logic;                                         -- pme_to_sr
			refclk              : in  std_logic                      := 'X';             -- clk
			rx_st_bar           : out std_logic_vector(7 downto 0);                      -- rx_st_bar
			rx_st_mask          : in  std_logic                      := 'X';             -- rx_st_mask
			rx_st_sop           : out std_logic_vector(0 downto 0);                      -- startofpacket
			rx_st_eop           : out std_logic_vector(0 downto 0);                      -- endofpacket
			rx_st_err           : out std_logic_vector(0 downto 0);                      -- error
			rx_st_valid         : out std_logic_vector(0 downto 0);                      -- valid
			rx_st_ready         : in  std_logic                      := 'X';             -- ready
			rx_st_data          : out std_logic_vector(255 downto 0);                    -- data
			rx_st_empty         : out std_logic_vector(1 downto 0);                      -- empty
			tx_cred_data_fc     : out std_logic_vector(11 downto 0);                     -- tx_cred_data_fc
			tx_cred_fc_hip_cons : out std_logic_vector(5 downto 0);                      -- tx_cred_fc_hip_cons
			tx_cred_fc_infinite : out std_logic_vector(5 downto 0);                      -- tx_cred_fc_infinite
			tx_cred_hdr_fc      : out std_logic_vector(7 downto 0);                      -- tx_cred_hdr_fc
			tx_cred_fc_sel      : in  std_logic_vector(1 downto 0)   := (others => 'X'); -- tx_cred_fc_sel
			tx_st_sop           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- startofpacket
			tx_st_eop           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- endofpacket
			tx_st_err           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- error
			tx_st_valid         : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- valid
			tx_st_ready         : out std_logic;                                         -- ready
			tx_st_data          : in  std_logic_vector(255 downto 0) := (others => 'X'); -- data
			tx_st_empty         : in  std_logic_vector(1 downto 0)   := (others => 'X')  -- empty
		);
	end component ip_pcie_x8_256;

-- ./nios/nios.cmp
	component nios is
		port (
			avm_sfp_address            : out   std_logic_vector(13 downto 0);                    -- address
			avm_sfp_read               : out   std_logic;                                        -- read
			avm_sfp_readdata           : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_sfp_write              : out   std_logic;                                        -- write
			avm_sfp_writedata          : out   std_logic_vector(31 downto 0);                    -- writedata
			avm_sfp_waitrequest        : in    std_logic                     := 'X';             -- waitrequest
			avm_xcvr0_address          : out   std_logic_vector(17 downto 0);                    -- address
			avm_xcvr0_read             : out   std_logic;                                        -- read
			avm_xcvr0_readdata         : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_xcvr0_write            : out   std_logic;                                        -- write
			avm_xcvr0_writedata        : out   std_logic_vector(31 downto 0);                    -- writedata
			avm_xcvr0_waitrequest      : in    std_logic                     := 'X';             -- waitrequest
			avm_xcvr1_address          : out   std_logic_vector(17 downto 0);                    -- address
			avm_xcvr1_read             : out   std_logic;                                        -- read
			avm_xcvr1_readdata         : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_xcvr1_write            : out   std_logic;                                        -- write
			avm_xcvr1_writedata        : out   std_logic_vector(31 downto 0);                    -- writedata
			avm_xcvr1_waitrequest      : in    std_logic                     := 'X';             -- waitrequest
			clk_clk                    : in    std_logic                     := 'X';             -- clk
			flash_tcm_address_out      : out   std_logic_vector(27 downto 0);                    -- tcm_address_out
			flash_tcm_read_n_out       : out   std_logic_vector(0 downto 0);                     -- tcm_read_n_out
			flash_tcm_write_n_out      : out   std_logic_vector(0 downto 0);                     -- tcm_write_n_out
			flash_tcm_data_out         : inout std_logic_vector(31 downto 0) := (others => 'X'); -- tcm_data_out
			flash_tcm_chipselect_n_out : out   std_logic_vector(0 downto 0);                     -- tcm_chipselect_n_out
			i2c_sda_in                 : in    std_logic                     := 'X';             -- sda_in
			i2c_scl_in                 : in    std_logic                     := 'X';             -- scl_in
			i2c_sda_oe                 : out   std_logic;                                        -- sda_oe
			i2c_scl_oe                 : out   std_logic;                                        -- scl_oe
			i2c_mask_export            : out   std_logic_vector(31 downto 0);                    -- export
			pio_export                 : out   std_logic_vector(31 downto 0);                    -- export
			rst_reset_n                : in    std_logic                     := 'X';             -- reset_n
			spi_MISO                   : in    std_logic                     := 'X';             -- MISO
			spi_MOSI                   : out   std_logic;                                        -- MOSI
			spi_SCLK                   : out   std_logic;                                        -- SCLK
			spi_SS_n                   : out   std_logic_vector(31 downto 0)                     -- SS_n
		);
	end component nios;

end package;
