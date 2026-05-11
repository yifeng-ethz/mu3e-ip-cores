library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component altera_avalon_i2c is
		generic (
			USE_AV_ST       : integer := 0;
			FIFO_DEPTH      : integer := 4;
			FIFO_DEPTH_LOG2 : integer := 2
		);
		port (
			clk       : in  std_logic                     := 'X';             -- clk
			rst_n     : in  std_logic                     := 'X';             -- reset_n
			intr      : out std_logic;                                        -- irq
			addr      : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- address
			read      : in  std_logic                     := 'X';             -- read
			write     : in  std_logic                     := 'X';             -- write
			writedata : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			readdata  : out std_logic_vector(31 downto 0);                    -- readdata
			sda_in    : in  std_logic                     := 'X';             -- sda_in
			scl_in    : in  std_logic                     := 'X';             -- scl_in
			sda_oe    : out std_logic;                                        -- sda_oe
			scl_oe    : out std_logic;                                        -- scl_oe
			src_data  : out std_logic_vector(7 downto 0);                     -- data
			src_valid : out std_logic;                                        -- valid
			src_ready : in  std_logic                     := 'X';             -- ready
			snk_data  : in  std_logic_vector(15 downto 0) := (others => 'X'); -- data
			snk_valid : in  std_logic                     := 'X';             -- valid
			snk_ready : out std_logic                                         -- ready
		);
	end component altera_avalon_i2c;

end nios_pkg;
