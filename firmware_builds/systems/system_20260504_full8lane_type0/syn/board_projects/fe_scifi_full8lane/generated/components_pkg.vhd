library ieee;
use ieee.std_logic_1164.all;

package cmp is

    constant GIT_HEAD : std_logic_vector(16*4-1 downto 0) := X"5e3eabdad6ffd310";

	component clk_ctrl_single is
		port (
			inclk  : in  std_logic := 'X'; -- inclk
			outclk : out std_logic         -- outclk
		);
	end component clk_ctrl_single;

	component trigPLL is
		port (
			refclk   : in  std_logic := 'X'; -- clk
			rst      : in  std_logic := 'X'; -- reset
			outclk_0 : out std_logic;        -- clk
			locked   : out std_logic         -- export
		);
	end component trigPLL;

	component native_reset_tx is
		port (
			clock           : in  std_logic                    := 'X';             -- clk
			reset           : in  std_logic                    := 'X';             -- reset
			pll_powerdown   : out std_logic_vector(3 downto 0);                    -- pll_powerdown
			tx_analogreset  : out std_logic_vector(3 downto 0);                    -- tx_analogreset
			tx_digitalreset : out std_logic_vector(3 downto 0);                    -- tx_digitalreset
			tx_ready        : out std_logic_vector(3 downto 0);                    -- tx_ready
			pll_locked      : in  std_logic_vector(3 downto 0) := (others => 'X'); -- pll_locked
			pll_select      : in  std_logic_vector(7 downto 0) := (others => 'X'); -- pll_select
			tx_cal_busy     : in  std_logic_vector(3 downto 0) := (others => 'X')  -- tx_cal_busy
		);
	end component native_reset_tx;

	component ip_altera_xcvr_reset_control is
		port (
			clock              : in  std_logic                    := 'X';             -- clk
			reset              : in  std_logic                    := 'X';             -- reset
			pll_powerdown      : out std_logic_vector(3 downto 0);                    -- pll_powerdown
			tx_analogreset     : out std_logic_vector(3 downto 0);                    -- tx_analogreset
			tx_digitalreset    : out std_logic_vector(3 downto 0);                    -- tx_digitalreset
			tx_ready           : out std_logic_vector(3 downto 0);                    -- tx_ready
			pll_locked         : in  std_logic_vector(3 downto 0) := (others => 'X'); -- pll_locked
			pll_select         : in  std_logic_vector(7 downto 0) := (others => 'X'); -- pll_select
			tx_cal_busy        : in  std_logic_vector(3 downto 0) := (others => 'X'); -- tx_cal_busy
			rx_analogreset     : out std_logic_vector(3 downto 0);                    -- rx_analogreset
			rx_digitalreset    : out std_logic_vector(3 downto 0);                    -- rx_digitalreset
			rx_ready           : out std_logic_vector(3 downto 0);                    -- rx_ready
			rx_is_lockedtodata : in  std_logic_vector(3 downto 0) := (others => 'X'); -- rx_is_lockedtodata
			rx_cal_busy        : in  std_logic_vector(3 downto 0) := (others => 'X')  -- rx_cal_busy
		);
	end component ip_altera_xcvr_reset_control;

	component ip_altera_xcvr_native_av is
		port (
			pll_powerdown           : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- pll_powerdown
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_pll_refclk           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_pll_refclk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			pll_locked              : out std_logic_vector(3 downto 0);                      -- pll_locked
			rx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_analogreset
			rx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_digitalreset
			rx_cdr_refclk           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- rx_cdr_refclk
			rx_serial_data          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_serial_data
			rx_is_lockedtoref       : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtoref
			rx_is_lockedtodata      : out std_logic_vector(3 downto 0);                      -- rx_is_lockedtodata
			rx_seriallpbken         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_seriallpbken
			tx_std_coreclkin        : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_std_coreclkin
			rx_std_coreclkin        : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_std_coreclkin
			tx_std_clkout           : out std_logic_vector(3 downto 0);                      -- tx_std_clkout
			rx_std_clkout           : out std_logic_vector(3 downto 0);                      -- rx_std_clkout
			rx_std_byteorder_ena    : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_std_byteorder_ena
			rx_std_byteorder_flag   : out std_logic_vector(3 downto 0);                      -- rx_std_byteorder_flag
			rx_std_wa_patternalign  : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- rx_std_wa_patternalign
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			rx_cal_busy             : out std_logic_vector(3 downto 0);                      -- rx_cal_busy
			reconfig_to_xcvr        : in  std_logic_vector(559 downto 0) := (others => 'X'); -- reconfig_to_xcvr
			reconfig_from_xcvr      : out std_logic_vector(367 downto 0);                    -- reconfig_from_xcvr
			tx_parallel_data        : in  std_logic_vector(127 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_datak                : in  std_logic_vector(15 downto 0)  := (others => 'X'); -- tx_datak
			unused_tx_parallel_data : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- unused_tx_parallel_data
			rx_parallel_data        : out std_logic_vector(127 downto 0);                    -- rx_parallel_data
			rx_datak                : out std_logic_vector(15 downto 0);                     -- rx_datak
			rx_errdetect            : out std_logic_vector(15 downto 0);                     -- rx_errdetect
			rx_disperr              : out std_logic_vector(15 downto 0);                     -- rx_disperr
			rx_runningdisp          : out std_logic_vector(15 downto 0);                     -- rx_runningdisp
			rx_patterndetect        : out std_logic_vector(15 downto 0);                     -- rx_patterndetect
			rx_syncstatus           : out std_logic_vector(15 downto 0);                     -- rx_syncstatus
			unused_rx_parallel_data : out std_logic_vector(31 downto 0)                      -- unused_rx_parallel_data
		);
	end component ip_altera_xcvr_native_av;

	component ip_alt_xcvr_reconfig is
		port (
			reconfig_busy             : out std_logic;                                         -- reconfig_busy
			mgmt_clk_clk              : in  std_logic                      := 'X';             -- clk
			mgmt_rst_reset            : in  std_logic                      := 'X';             -- reset
			reconfig_mgmt_address     : in  std_logic_vector(6 downto 0)   := (others => 'X'); -- address
			reconfig_mgmt_read        : in  std_logic                      := 'X';             -- read
			reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);                     -- readdata
			reconfig_mgmt_waitrequest : out std_logic;                                         -- waitrequest
			reconfig_mgmt_write       : in  std_logic                      := 'X';             -- write
			reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0)  := (others => 'X'); -- writedata
			ch0_7_to_xcvr             : out std_logic_vector(559 downto 0);                    -- reconfig_to_xcvr
			ch0_7_from_xcvr           : in  std_logic_vector(367 downto 0) := (others => 'X'); -- reconfig_from_xcvr
			ch8_15_to_xcvr            : out std_logic_vector(559 downto 0);                    -- reconfig_to_xcvr
			ch8_15_from_xcvr          : in  std_logic_vector(367 downto 0) := (others => 'X')  -- reconfig_from_xcvr
		);
	end component ip_alt_xcvr_reconfig;

	component fastlink_small is
		port (
			pll_powerdown           : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- pll_powerdown
			tx_analogreset          : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_analogreset
			tx_digitalreset         : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_digitalreset
			tx_pll_refclk           : in  std_logic_vector(0 downto 0)   := (others => 'X'); -- tx_pll_refclk
			tx_serial_data          : out std_logic_vector(3 downto 0);                      -- tx_serial_data
			pll_locked              : out std_logic_vector(3 downto 0);                      -- pll_locked
			tx_std_coreclkin        : in  std_logic_vector(3 downto 0)   := (others => 'X'); -- tx_std_coreclkin
			tx_std_clkout           : out std_logic_vector(3 downto 0);                      -- tx_std_clkout
			tx_cal_busy             : out std_logic_vector(3 downto 0);                      -- tx_cal_busy
			reconfig_to_xcvr        : in  std_logic_vector(559 downto 0) := (others => 'X'); -- reconfig_to_xcvr
			reconfig_from_xcvr      : out std_logic_vector(367 downto 0);                    -- reconfig_from_xcvr
			tx_parallel_data        : in  std_logic_vector(127 downto 0) := (others => 'X'); -- tx_parallel_data
			tx_datak                : in  std_logic_vector(15 downto 0)  := (others => 'X'); -- tx_datak
			unused_tx_parallel_data : in  std_logic_vector(31 downto 0)  := (others => 'X')  -- unused_tx_parallel_data
		);
	end component fastlink_small;

-- ./nios/nios.cmp
	component nios is
		port (
			avm_mscb_address      : out std_logic_vector(3 downto 0);                     -- address
			avm_mscb_read         : out std_logic;                                        -- read
			avm_mscb_readdata     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_mscb_write        : out std_logic;                                        -- write
			avm_mscb_writedata    : out std_logic_vector(31 downto 0);                    -- writedata
			avm_mscb_waitrequest  : in  std_logic                     := 'X';             -- waitrequest
			avm_pod_address       : out std_logic_vector(13 downto 0);                    -- address
			avm_pod_read          : out std_logic;                                        -- read
			avm_pod_readdata      : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_pod_write         : out std_logic;                                        -- write
			avm_pod_writedata     : out std_logic_vector(31 downto 0);                    -- writedata
			avm_pod_waitrequest   : in  std_logic                     := 'X';             -- waitrequest
			avm_qsfp_address      : out std_logic_vector(13 downto 0);                    -- address
			avm_qsfp_read         : out std_logic;                                        -- read
			avm_qsfp_readdata     : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_qsfp_write        : out std_logic;                                        -- write
			avm_qsfp_writedata    : out std_logic_vector(31 downto 0);                    -- writedata
			avm_qsfp_waitrequest  : in  std_logic                     := 'X';             -- waitrequest
			avm_sc_address        : out std_logic_vector(15 downto 0);                    -- address
			avm_sc_read           : out std_logic;                                        -- read
			avm_sc_readdata       : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_sc_write          : out std_logic;                                        -- write
			avm_sc_writedata      : out std_logic_vector(31 downto 0);                    -- writedata
			avm_sc_waitrequest    : in  std_logic                     := 'X';             -- waitrequest
			clk_clk               : in  std_logic                     := 'X';             -- clk
			clk_125_clock_clk     : in  std_logic                     := 'X';             -- clk
			clk_125_reset_reset_n : in  std_logic                     := 'X';             -- reset_n
			clk_156_clock_clk     : in  std_logic                     := 'X';             -- clk
			clk_156_reset_reset_n : in  std_logic                     := 'X';             -- reset_n
			i2c_sda_in            : in  std_logic                     := 'X';             -- sda_in
			i2c_scl_in            : in  std_logic                     := 'X';             -- scl_in
			i2c_sda_oe            : out std_logic;                                        -- sda_oe
			i2c_scl_oe            : out std_logic;                                        -- scl_oe
			i2c_mask_export       : out std_logic_vector(31 downto 0);                    -- export
			irq_bridge_irq        : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- irq
			pio_export            : out std_logic_vector(31 downto 0);                    -- export
			rst_reset_n           : in  std_logic                     := 'X';             -- reset_n
			spi_MISO              : in  std_logic                     := 'X';             -- MISO
			spi_MOSI              : out std_logic;                                        -- MOSI
			spi_SCLK              : out std_logic;                                        -- SCLK
			spi_SS_n              : out std_logic_vector(15 downto 0);                    -- SS_n
			spi_si_MISO           : in  std_logic                     := 'X';             -- MISO
			spi_si_MOSI           : out std_logic;                                        -- MOSI
			spi_si_SCLK           : out std_logic;                                        -- SCLK
			spi_si_SS_n           : out std_logic_vector(1 downto 0);                     -- SS_n
			temp_tsdcalo          : out std_logic_vector(7 downto 0);                     -- tsdcalo
			temp_ce_ce            : in  std_logic                     := 'X';             -- ce
			temp_clr_reset        : in  std_logic                     := 'X';             -- reset
			temp_done_tsdcaldone  : out std_logic                                         -- tsdcaldone
		);
	end component nios;

end package;
