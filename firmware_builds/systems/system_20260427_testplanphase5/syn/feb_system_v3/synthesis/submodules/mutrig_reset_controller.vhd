-- File name: mutrig_reset_controller.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Jul 16, 2024
-- =========
-- Description:	[MuTRiG Reset Controller] 
-- 		Reset the MuTRiGs by asserting the reset for during run state "SYNC".
--		Reset is treated as asynchronize which allow phase adjustment.
--		Features a built-in phase detector to measure the phase between firefly reset link lvds_rx_out_clock 
--		and the datapath clock. 
--
--		Phase relationship: 
--				pll_dps_clk is derived from si_direct_clk(ref) (deterministic phase)
--				lvds_dpa_clk is different after each reset (its phase can be measured compare to si_direct_clk)
--		Usage:
--				Tune pll_dps_clk phase, so the mutrig reset is aligned with lvds_dpa_clk, where run control command is issued. 
--				After link establishment, tune each lane on this FEB so that the MuTRiGs are in sync (seen by double peak)
--				Repeat the tuning for all FEBs. 
--				
--
--			
-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;

entity mutrig_reset_controller is 
	generic (
		RESET_LANE		: natural := 2;
		DEBUG			: natural := 1
	);
	port (
		-- streaming run control interface (lvds_dpa_clk)
		asi_runcontrol_data				: in  std_logic_vector(8 downto 0);
		asi_runcontrol_valid			: in  std_logic;
		asi_runcontrol_ready			: out std_logic;
		
		-- mutrig reset conduit (pll_dps_clk)
		o_mutrig_reset					: out std_logic_vector(RESET_LANE-1 downto 0);
		
		-- mgmt interface for the pll (si_direct_clk)
		avs_reconfig_mgmt_address		: in  std_logic_vector(5 downto 0);
		avs_reconfig_mgmt_read			: in  std_logic;
		avs_reconfig_mgmt_readdata		: out std_logic_vector(31 downto 0);
		avs_reconfig_mgmt_write			: in  std_logic;
		avs_reconfig_mgmt_writedata		: in  std_logic_vector(31 downto 0);
		avs_reconfig_mgmt_waitrequest	: out std_logic := '0'; -- just for debug, as empty inside
		
		
		-- reset and clock interface 
		-- rst
		i_lvds_dpa_rst					: in  std_logic;
		-- clk
		o_pll_dps_clk					: out std_logic; -- p*
		i_si_direct_clk					: in  std_logic; -- s*
		i_lvds_dpa_clk					: in  std_logic  -- d*
	);
end entity mutrig_reset_controller;


architecture rtl of mutrig_reset_controller is 

	signal pclk				: std_logic;
	signal sclk				: std_logic;
	signal dclk				: std_logic;
	
	signal drst				: std_logic;
	
	signal dmutrig_reset	: std_logic;
	
	-- run mgmt agent
	type run_state_t is (IDLE, RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST, SYNC_TEST, RESET, OUT_OF_DAQ, ERROR);
	signal run_state_cmd	: run_state_t;
	
	-- altera pll ip
	signal reconfig_to_pll			: std_logic_vector(63 downto 0);
	signal reconfig_to_pll_reg		: std_logic_vector(63 downto 0);
	signal reconfig_from_pll		: std_logic_vector(63 downto 0);
	component alt_pll is
	port (
		refclk            : in  std_logic                     := 'X';             -- clk
		rst               : in  std_logic                     := 'X';             -- reset
		outclk_0          : out std_logic;                                        -- clk
		locked            : out std_logic;                                        -- export
		reconfig_to_pll   : in  std_logic_vector(63 downto 0) := (others => 'X'); -- reconfig_to_pll
		reconfig_from_pll : out std_logic_vector(63 downto 0)                     -- reconfig_from_pll
	);
	end component alt_pll;
	
	-- altera pll reconfig ip
	component alt_pll_reconfig is
	generic (
		ENABLE_BYTEENABLE   : boolean := false;
		BYTEENABLE_WIDTH    : integer := 4;
		RECONFIG_ADDR_WIDTH : integer := 6;
		RECONFIG_DATA_WIDTH : integer := 32;
		reconf_width        : integer := 64;
		WAIT_FOR_LOCK       : boolean := true
	);
	port (
		mgmt_clk          : in  std_logic                     := 'X';             -- clk
		mgmt_reset        : in  std_logic                     := 'X';             -- reset
		mgmt_waitrequest  : out std_logic;                                        -- waitrequest
		mgmt_read         : in  std_logic                     := 'X';             -- read
		mgmt_write        : in  std_logic                     := 'X';             -- write
		mgmt_readdata     : out std_logic_vector(31 downto 0);                    -- readdata
		mgmt_address      : in  std_logic_vector(5 downto 0)  := (others => 'X'); -- address
		mgmt_writedata    : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
		reconfig_to_pll   : out std_logic_vector(63 downto 0);                    -- reconfig_to_pll
		reconfig_from_pll : in  std_logic_vector(63 downto 0) := (others => 'X')  -- reconfig_from_pll
	);
	end component alt_pll_reconfig;

begin
	
	proc_wire_clk_and_rst : process (all)
	begin
		-- clock
		o_pll_dps_clk		<= pclk;
		sclk				<= i_si_direct_clk;
		dclk				<= i_lvds_dpa_clk;
		-- reset
		drst				<= i_lvds_dpa_rst;
		gen_reset_o : for i in 0 to RESET_LANE-1 loop
			o_mutrig_reset(i)		<= dmutrig_reset;
		end loop gen_reset_o;
	end process;
	-- ------------------------------
	-- run management agent
	-- ------------------------------
	proc_run_mgmt_agent : process (drst, dclk)
	begin
		if (drst = '1') then 
			run_state_cmd		<= IDLE;
		elsif (rising_edge(dclk)) then
			-- valid
			if (asi_runcontrol_valid = '1') then 
				-- payload of run control to run cmd
				case asi_runcontrol_data is 
					when "000000001" =>
						run_state_cmd		<= IDLE;
					when "000000010" => 
						run_state_cmd		<= RUN_PREPARE;
					when "000000100" =>
						run_state_cmd		<= SYNC;
					when "000001000" =>
						run_state_cmd		<= RUNNING;
					when "000010000" =>
						run_state_cmd		<= TERMINATING;
					when "000100000" => 
						run_state_cmd		<= LINK_TEST;
					when "001000000" =>
						run_state_cmd		<= SYNC_TEST;
					when "010000000" =>
						run_state_cmd		<= RESET;
					when "100000000" =>
						run_state_cmd		<= OUT_OF_DAQ;
					when others =>
						run_state_cmd		<= ERROR;
				end case;
			else 
				run_state_cmd		<= run_state_cmd;
			end if;
			-- ready
			-- TODO: hook up with main state machine
			asi_runcontrol_ready		<= '1';
		end if;
	end process;
	
	-- -------------------------------
	-- mutrig reset issuer
	-- -------------------------------
	proc_reset_issuer : process (drst, dclk)
		-- generates the reset based on the run command in dclk domain
	begin
		if (drst = '1') then 
			
		elsif (rising_edge(dclk)) then
			if (run_state_cmd = SYNC) then 
				dmutrig_reset			<= '1';
			else 
				dmutrig_reset			<= '0';
			end if;
		end if;
	end process;
	
	-- --------------------------------------
	-- sub-ip instantiation 
	-- --------------------------------------
--	ip_alt_pll : component alt_pll
--	-- In clock:  free-running si clock 
--	-- Out clock: phase shifted clock
--	port map (
--		refclk            => sclk,            
--		rst               => drst,             
--		outclk_0          => pclk,         
--		locked            => open,           
--		reconfig_to_pll   => reconfig_to_pll_reg,   -- <=
--		reconfig_from_pll => reconfig_from_pll  
--	);
--	
--	proc_useless_pipeline : process (sclk) -- can we do this? maybe slow down the clock? 
--	begin
--		if (rising_edge(sclk)) then
--			reconfig_to_pll_reg		<= reconfig_to_pll;
--		end if;
--	end process;
--	
--	ip_alt_pll_reconfig : component alt_pll_reconfig
--	-- clock: datapath clock 
--	port map (
--		mgmt_clk          => sclk,     
--		mgmt_reset        => drst,    
--		mgmt_waitrequest  => avs_reconfig_mgmt_waitrequest,  
--		mgmt_read         => avs_reconfig_mgmt_read,      
--		mgmt_write        => avs_reconfig_mgmt_write,       
--		mgmt_readdata     => avs_reconfig_mgmt_readdata,  
--		mgmt_address      => avs_reconfig_mgmt_address,    
--		mgmt_writedata    => avs_reconfig_mgmt_writedata,    
--		reconfig_to_pll   => reconfig_to_pll, -- => 
--		reconfig_from_pll => reconfig_from_pll 
--	);
	
	




end architecture; 