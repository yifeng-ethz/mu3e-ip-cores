library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package opq_upstream_4lane_pkg is
	component opq_upstream_4lane_altera_jtag_avalon_master_181_dzttzdy is
		generic (
			USE_PLI     : integer := 0;
			PLI_PORT    : integer := 50000;
			FIFO_DEPTHS : integer := 2
		);
		port (
			clk_clk              : in  std_logic                     := 'X';             -- clk
			clk_reset_reset      : in  std_logic                     := 'X';             -- reset
			master_address       : out std_logic_vector(31 downto 0);                    -- address
			master_readdata      : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			master_read          : out std_logic;                                        -- read
			master_write         : out std_logic;                                        -- write
			master_writedata     : out std_logic_vector(31 downto 0);                    -- writedata
			master_waitrequest   : in  std_logic                     := 'X';             -- waitrequest
			master_readdatavalid : in  std_logic                     := 'X';             -- readdatavalid
			master_byteenable    : out std_logic_vector(3 downto 0);                     -- byteenable
			master_reset_reset   : out std_logic                                         -- reset
		);
	end component opq_upstream_4lane_altera_jtag_avalon_master_181_dzttzdy;

end opq_upstream_4lane_pkg;
