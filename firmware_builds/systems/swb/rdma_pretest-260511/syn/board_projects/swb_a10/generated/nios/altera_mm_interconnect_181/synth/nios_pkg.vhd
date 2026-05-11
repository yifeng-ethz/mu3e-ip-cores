library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_mm_interconnect_181_7d7plwy is
		port (
			clk_clk_clk                                                     : in  std_logic                     := 'X';             -- clk
			cpu_reset_reset_bridge_in_reset_reset                           : in  std_logic                     := 'X';             -- reset
			jtag_master_clk_reset_reset_bridge_in_reset_reset               : in  std_logic                     := 'X';             -- reset
			jtag_master_master_translator_reset_reset_bridge_in_reset_reset : in  std_logic                     := 'X';             -- reset
			cpu_data_master_address                                         : in  std_logic_vector(30 downto 0) := (others => 'X'); -- address
			cpu_data_master_waitrequest                                     : out std_logic;                                        -- waitrequest
			cpu_data_master_byteenable                                      : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- byteenable
			cpu_data_master_read                                            : in  std_logic                     := 'X';             -- read
			cpu_data_master_readdata                                        : out std_logic_vector(31 downto 0);                    -- readdata
			cpu_data_master_write                                           : in  std_logic                     := 'X';             -- write
			cpu_data_master_writedata                                       : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			cpu_data_master_debugaccess                                     : in  std_logic                     := 'X';             -- debugaccess
			cpu_instruction_master_address                                  : in  std_logic_vector(30 downto 0) := (others => 'X'); -- address
			cpu_instruction_master_waitrequest                              : out std_logic;                                        -- waitrequest
			cpu_instruction_master_read                                     : in  std_logic                     := 'X';             -- read
			cpu_instruction_master_readdata                                 : out std_logic_vector(31 downto 0);                    -- readdata
			jtag_master_master_address                                      : in  std_logic_vector(31 downto 0) := (others => 'X'); -- address
			jtag_master_master_waitrequest                                  : out std_logic;                                        -- waitrequest
			jtag_master_master_byteenable                                   : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- byteenable
			jtag_master_master_read                                         : in  std_logic                     := 'X';             -- read
			jtag_master_master_readdata                                     : out std_logic_vector(31 downto 0);                    -- readdata
			jtag_master_master_readdatavalid                                : out std_logic;                                        -- readdatavalid
			jtag_master_master_write                                        : in  std_logic                     := 'X';             -- write
			jtag_master_master_writedata                                    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			avm_sfp_slave_address                                           : out std_logic_vector(13 downto 0);                    -- address
			avm_sfp_slave_write                                             : out std_logic;                                        -- write
			avm_sfp_slave_read                                              : out std_logic;                                        -- read
			avm_sfp_slave_readdata                                          : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_sfp_slave_writedata                                         : out std_logic_vector(31 downto 0);                    -- writedata
			avm_sfp_slave_waitrequest                                       : in  std_logic                     := 'X';             -- waitrequest
			avm_xcvr0_slave_address                                         : out std_logic_vector(17 downto 0);                    -- address
			avm_xcvr0_slave_write                                           : out std_logic;                                        -- write
			avm_xcvr0_slave_read                                            : out std_logic;                                        -- read
			avm_xcvr0_slave_readdata                                        : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_xcvr0_slave_writedata                                       : out std_logic_vector(31 downto 0);                    -- writedata
			avm_xcvr0_slave_waitrequest                                     : in  std_logic                     := 'X';             -- waitrequest
			avm_xcvr1_slave_address                                         : out std_logic_vector(17 downto 0);                    -- address
			avm_xcvr1_slave_write                                           : out std_logic;                                        -- write
			avm_xcvr1_slave_read                                            : out std_logic;                                        -- read
			avm_xcvr1_slave_readdata                                        : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			avm_xcvr1_slave_writedata                                       : out std_logic_vector(31 downto 0);                    -- writedata
			avm_xcvr1_slave_waitrequest                                     : in  std_logic                     := 'X';             -- waitrequest
			cpu_debug_mem_slave_address                                     : out std_logic_vector(8 downto 0);                     -- address
			cpu_debug_mem_slave_write                                       : out std_logic;                                        -- write
			cpu_debug_mem_slave_read                                        : out std_logic;                                        -- read
			cpu_debug_mem_slave_readdata                                    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			cpu_debug_mem_slave_writedata                                   : out std_logic_vector(31 downto 0);                    -- writedata
			cpu_debug_mem_slave_byteenable                                  : out std_logic_vector(3 downto 0);                     -- byteenable
			cpu_debug_mem_slave_waitrequest                                 : in  std_logic                     := 'X';             -- waitrequest
			cpu_debug_mem_slave_debugaccess                                 : out std_logic;                                        -- debugaccess
			flash_uas_address                                               : out std_logic_vector(27 downto 0);                    -- address
			flash_uas_write                                                 : out std_logic;                                        -- write
			flash_uas_read                                                  : out std_logic;                                        -- read
			flash_uas_readdata                                              : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			flash_uas_writedata                                             : out std_logic_vector(31 downto 0);                    -- writedata
			flash_uas_burstcount                                            : out std_logic_vector(2 downto 0);                     -- burstcount
			flash_uas_byteenable                                            : out std_logic_vector(3 downto 0);                     -- byteenable
			flash_uas_readdatavalid                                         : in  std_logic                     := 'X';             -- readdatavalid
			flash_uas_waitrequest                                           : in  std_logic                     := 'X';             -- waitrequest
			flash_uas_lock                                                  : out std_logic;                                        -- lock
			flash_uas_debugaccess                                           : out std_logic;                                        -- debugaccess
			i2c_csr_address                                                 : out std_logic_vector(3 downto 0);                     -- address
			i2c_csr_write                                                   : out std_logic;                                        -- write
			i2c_csr_read                                                    : out std_logic;                                        -- read
			i2c_csr_readdata                                                : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			i2c_csr_writedata                                               : out std_logic_vector(31 downto 0);                    -- writedata
			i2c_mask_s1_address                                             : out std_logic_vector(2 downto 0);                     -- address
			i2c_mask_s1_write                                               : out std_logic;                                        -- write
			i2c_mask_s1_readdata                                            : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			i2c_mask_s1_writedata                                           : out std_logic_vector(31 downto 0);                    -- writedata
			i2c_mask_s1_chipselect                                          : out std_logic;                                        -- chipselect
			jtag_uart_avalon_jtag_slave_address                             : out std_logic_vector(0 downto 0);                     -- address
			jtag_uart_avalon_jtag_slave_write                               : out std_logic;                                        -- write
			jtag_uart_avalon_jtag_slave_read                                : out std_logic;                                        -- read
			jtag_uart_avalon_jtag_slave_readdata                            : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			jtag_uart_avalon_jtag_slave_writedata                           : out std_logic_vector(31 downto 0);                    -- writedata
			jtag_uart_avalon_jtag_slave_waitrequest                         : in  std_logic                     := 'X';             -- waitrequest
			jtag_uart_avalon_jtag_slave_chipselect                          : out std_logic;                                        -- chipselect
			pio_s1_address                                                  : out std_logic_vector(2 downto 0);                     -- address
			pio_s1_write                                                    : out std_logic;                                        -- write
			pio_s1_readdata                                                 : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			pio_s1_writedata                                                : out std_logic_vector(31 downto 0);                    -- writedata
			pio_s1_chipselect                                               : out std_logic;                                        -- chipselect
			ram_s1_address                                                  : out std_logic_vector(16 downto 0);                    -- address
			ram_s1_write                                                    : out std_logic;                                        -- write
			ram_s1_readdata                                                 : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			ram_s1_writedata                                                : out std_logic_vector(31 downto 0);                    -- writedata
			ram_s1_byteenable                                               : out std_logic_vector(3 downto 0);                     -- byteenable
			ram_s1_chipselect                                               : out std_logic;                                        -- chipselect
			ram_s1_clken                                                    : out std_logic;                                        -- clken
			spi_spi_control_port_address                                    : out std_logic_vector(2 downto 0);                     -- address
			spi_spi_control_port_write                                      : out std_logic;                                        -- write
			spi_spi_control_port_read                                       : out std_logic;                                        -- read
			spi_spi_control_port_readdata                                   : in  std_logic_vector(15 downto 0) := (others => 'X'); -- readdata
			spi_spi_control_port_writedata                                  : out std_logic_vector(15 downto 0);                    -- writedata
			spi_spi_control_port_chipselect                                 : out std_logic;                                        -- chipselect
			sysid_control_slave_address                                     : out std_logic_vector(0 downto 0);                     -- address
			sysid_control_slave_readdata                                    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			timer_s1_address                                                : out std_logic_vector(2 downto 0);                     -- address
			timer_s1_write                                                  : out std_logic;                                        -- write
			timer_s1_readdata                                               : in  std_logic_vector(15 downto 0) := (others => 'X'); -- readdata
			timer_s1_writedata                                              : out std_logic_vector(15 downto 0);                    -- writedata
			timer_s1_chipselect                                             : out std_logic;                                        -- chipselect
			timer_ts_s1_address                                             : out std_logic_vector(2 downto 0);                     -- address
			timer_ts_s1_write                                               : out std_logic;                                        -- write
			timer_ts_s1_readdata                                            : in  std_logic_vector(15 downto 0) := (others => 'X'); -- readdata
			timer_ts_s1_writedata                                           : out std_logic_vector(15 downto 0);                    -- writedata
			timer_ts_s1_chipselect                                          : out std_logic                                         -- chipselect
		);
	end component nios_altera_mm_interconnect_181_7d7plwy;

end nios_pkg;
