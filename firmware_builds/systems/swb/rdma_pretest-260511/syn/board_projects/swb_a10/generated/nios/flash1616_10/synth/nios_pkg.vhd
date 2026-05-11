library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package nios_pkg is
	component nios_flash1616_10_skpx6xq is
		port (
			clk_clk                  : in    std_logic                     := 'X';             -- clk
			reset_reset_n            : in    std_logic                     := 'X';             -- reset_n
			uas_address              : in    std_logic_vector(27 downto 0) := (others => 'X'); -- address
			uas_burstcount           : in    std_logic_vector(2 downto 0)  := (others => 'X'); -- burstcount
			uas_read                 : in    std_logic                     := 'X';             -- read
			uas_write                : in    std_logic                     := 'X';             -- write
			uas_waitrequest          : out   std_logic;                                        -- waitrequest
			uas_readdatavalid        : out   std_logic;                                        -- readdatavalid
			uas_byteenable           : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- byteenable
			uas_readdata             : out   std_logic_vector(31 downto 0);                    -- readdata
			uas_writedata            : in    std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			uas_lock                 : in    std_logic                     := 'X';             -- lock
			uas_debugaccess          : in    std_logic                     := 'X';             -- debugaccess
			out_tcm_address_out      : out   std_logic_vector(27 downto 0);                    -- tcm_address_out
			out_tcm_read_n_out       : out   std_logic_vector(0 downto 0);                     -- tcm_read_n_out
			out_tcm_write_n_out      : out   std_logic_vector(0 downto 0);                     -- tcm_write_n_out
			out_tcm_data_out         : inout std_logic_vector(31 downto 0) := (others => 'X'); -- tcm_data_out
			out_tcm_chipselect_n_out : out   std_logic_vector(0 downto 0)                      -- tcm_chipselect_n_out
		);
	end component nios_flash1616_10_skpx6xq;

end nios_pkg;
