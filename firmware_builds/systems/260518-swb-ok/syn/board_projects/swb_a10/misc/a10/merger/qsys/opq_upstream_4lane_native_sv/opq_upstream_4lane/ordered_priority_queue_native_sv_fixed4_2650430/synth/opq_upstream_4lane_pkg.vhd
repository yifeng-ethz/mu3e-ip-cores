library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package opq_upstream_4lane_pkg is
	component ordered_priority_queue_dut_sv is
		generic (
			IP_UID        : natural := 1330663757;
			VERSION_MAJOR : natural := 26;
			VERSION_MINOR : natural := 5;
			VERSION_PATCH : natural := 0;
			BUILD         : natural := 430;
			VERSION_DATE  : natural := 20260430;
			VERSION_GIT   : natural := 1332117425;
			INSTANCE_ID   : natural := 0;
			DEBUG_LV      : natural := 0
		);
		port (
			aso_egress_startofpacket    : out std_logic;                                        -- startofpacket
			aso_egress_endofpacket      : out std_logic;                                        -- endofpacket
			aso_egress_valid            : out std_logic;                                        -- valid
			aso_egress_ready            : in  std_logic                     := 'X';             -- ready
			aso_egress_error            : out std_logic_vector(2 downto 0);                     -- error
			aso_egress_data             : out std_logic_vector(35 downto 0);                    -- data
			d_clk                       : in  std_logic                     := 'X';             -- clk
			d_reset                     : in  std_logic                     := 'X';             -- reset
			avs_csr_address             : in  std_logic_vector(8 downto 0)  := (others => 'X'); -- address
			avs_csr_read                : in  std_logic                     := 'X';             -- read
			avs_csr_write               : in  std_logic                     := 'X';             -- write
			avs_csr_writedata           : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			avs_csr_readdata            : out std_logic_vector(31 downto 0);                    -- readdata
			avs_csr_readdatavalid       : out std_logic;                                        -- readdatavalid
			avs_csr_waitrequest         : out std_logic;                                        -- waitrequest
			avs_csr_burstcount          : in  std_logic                     := 'X';             -- burstcount
			asi_ingress_0_channel       : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- channel
			asi_ingress_0_startofpacket : in  std_logic                     := 'X';             -- startofpacket
			asi_ingress_0_endofpacket   : in  std_logic                     := 'X';             -- endofpacket
			asi_ingress_0_data          : in  std_logic_vector(35 downto 0) := (others => 'X'); -- data
			asi_ingress_0_valid         : in  std_logic                     := 'X';             -- valid
			asi_ingress_0_error         : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- error
			asi_ingress_1_channel       : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- channel
			asi_ingress_1_startofpacket : in  std_logic                     := 'X';             -- startofpacket
			asi_ingress_1_endofpacket   : in  std_logic                     := 'X';             -- endofpacket
			asi_ingress_1_data          : in  std_logic_vector(35 downto 0) := (others => 'X'); -- data
			asi_ingress_1_valid         : in  std_logic                     := 'X';             -- valid
			asi_ingress_1_error         : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- error
			asi_ingress_2_channel       : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- channel
			asi_ingress_2_startofpacket : in  std_logic                     := 'X';             -- startofpacket
			asi_ingress_2_endofpacket   : in  std_logic                     := 'X';             -- endofpacket
			asi_ingress_2_data          : in  std_logic_vector(35 downto 0) := (others => 'X'); -- data
			asi_ingress_2_valid         : in  std_logic                     := 'X';             -- valid
			asi_ingress_2_error         : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- error
			asi_ingress_3_channel       : in  std_logic_vector(1 downto 0)  := (others => 'X'); -- channel
			asi_ingress_3_startofpacket : in  std_logic                     := 'X';             -- startofpacket
			asi_ingress_3_endofpacket   : in  std_logic                     := 'X';             -- endofpacket
			asi_ingress_3_data          : in  std_logic_vector(35 downto 0) := (others => 'X'); -- data
			asi_ingress_3_valid         : in  std_logic                     := 'X';             -- valid
			asi_ingress_3_error         : in  std_logic_vector(2 downto 0)  := (others => 'X')  -- error
		);
	end component ordered_priority_queue_dut_sv;

end opq_upstream_4lane_pkg;
