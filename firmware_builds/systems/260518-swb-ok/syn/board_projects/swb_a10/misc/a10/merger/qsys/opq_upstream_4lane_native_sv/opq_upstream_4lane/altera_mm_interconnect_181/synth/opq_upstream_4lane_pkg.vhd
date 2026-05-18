library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package opq_upstream_4lane_pkg is
	component opq_upstream_4lane_altera_mm_interconnect_181_amqcmrq is
		port (
			clk_bridge_out_clk_clk                                              : in  std_logic                     := 'X';             -- clk
			csr_jtag_master_clk_reset_reset_bridge_in_reset_reset               : in  std_logic                     := 'X';             -- reset
			csr_jtag_master_master_translator_reset_reset_bridge_in_reset_reset : in  std_logic                     := 'X';             -- reset
			opq_0_rst_interface_reset_bridge_in_reset_reset                     : in  std_logic                     := 'X';             -- reset
			csr_jtag_master_master_address                                      : in  std_logic_vector(31 downto 0) := (others => 'X'); -- address
			csr_jtag_master_master_waitrequest                                  : out std_logic;                                        -- waitrequest
			csr_jtag_master_master_byteenable                                   : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- byteenable
			csr_jtag_master_master_read                                         : in  std_logic                     := 'X';             -- read
			csr_jtag_master_master_readdata                                     : out std_logic_vector(31 downto 0);                    -- readdata
			csr_jtag_master_master_readdatavalid                                : out std_logic;                                        -- readdatavalid
			csr_jtag_master_master_write                                        : in  std_logic                     := 'X';             -- write
			csr_jtag_master_master_writedata                                    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			opq_0_csr_address                                                   : out std_logic_vector(8 downto 0);                     -- address
			opq_0_csr_write                                                     : out std_logic;                                        -- write
			opq_0_csr_read                                                      : out std_logic;                                        -- read
			opq_0_csr_readdata                                                  : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			opq_0_csr_writedata                                                 : out std_logic_vector(31 downto 0);                    -- writedata
			opq_0_csr_burstcount                                                : out std_logic_vector(0 downto 0);                     -- burstcount
			opq_0_csr_readdatavalid                                             : in  std_logic                     := 'X';             -- readdatavalid
			opq_0_csr_waitrequest                                               : in  std_logic                     := 'X'              -- waitrequest
		);
	end component opq_upstream_4lane_altera_mm_interconnect_181_amqcmrq;

end opq_upstream_4lane_pkg;
