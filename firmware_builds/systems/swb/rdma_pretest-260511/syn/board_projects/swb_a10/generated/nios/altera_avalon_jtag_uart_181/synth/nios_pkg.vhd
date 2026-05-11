library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_altera_avalon_jtag_uart_181_xottjsy is
		port (
			clk            : in  std_logic                     := 'X';             -- clk
			rst_n          : in  std_logic                     := 'X';             -- reset_n
			av_chipselect  : in  std_logic                     := 'X';             -- chipselect
			av_address     : in  std_logic                     := 'X';             -- address
			av_read_n      : in  std_logic                     := 'X';             -- read_n
			av_readdata    : out std_logic_vector(31 downto 0);                    -- readdata
			av_write_n     : in  std_logic                     := 'X';             -- write_n
			av_writedata   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			av_waitrequest : out std_logic;                                        -- waitrequest
			av_irq         : out std_logic                                         -- irq
		);
	end component nios_altera_avalon_jtag_uart_181_xottjsy;

end nios_pkg;
