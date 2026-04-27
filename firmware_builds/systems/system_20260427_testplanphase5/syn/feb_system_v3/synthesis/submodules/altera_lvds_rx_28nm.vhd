LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY altera_lvds_rx_28nm IS
	generic (
		N_LANE						: natural
	
	);
	PORT
	(
		pll_areset					: IN STD_LOGIC ; --
		rx_channel_data_align		: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_dpa_lock_reset			: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_dpll_hold				: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_fifo_reset				: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_in						: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_inclock					: IN STD_LOGIC ; --
		rx_reset					: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_cda_max					: OUT STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_dpa_locked				: OUT STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0); --
		rx_locked					: OUT STD_LOGIC ; --
		rx_out						: OUT STD_LOGIC_VECTOR (N_LANE*10-1 DOWNTO 0); --
		rx_outclock					: OUT STD_LOGIC --
	);
END altera_lvds_rx_28nm;


ARCHITECTURE SYN OF altera_lvds_rx_28nm IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
	SIGNAL sub_wire2	: STD_LOGIC ;
	SIGNAL sub_wire3	: STD_LOGIC_VECTOR (N_LANE*10-1 DOWNTO 0);
	SIGNAL sub_wire4	: STD_LOGIC ;



	COMPONENT altlvds_rx
	GENERIC (
		buffer_implementation		: STRING;
		cds_mode		: STRING;
		common_rx_tx_pll		: STRING;
		data_align_rollover		: NATURAL;
		data_rate		: STRING;
		deserialization_factor		: NATURAL;
		dpa_initial_phase_value		: NATURAL;
		dpll_lock_count		: NATURAL;
		dpll_lock_window		: NATURAL;
		enable_clock_pin_mode		: STRING;
		enable_dpa_align_to_rising_edge_only		: STRING;
		enable_dpa_calibration		: STRING;
		enable_dpa_fifo		: STRING;
		enable_dpa_initial_phase_selection		: STRING;
		enable_dpa_mode		: STRING;
		enable_dpa_pll_calibration		: STRING;
		enable_soft_cdr_mode		: STRING;
		implement_in_les		: STRING;
		inclock_boost		: NATURAL;
		inclock_data_alignment		: STRING;
		inclock_period		: NATURAL;
		inclock_phase_shift		: NATURAL;
		input_data_rate		: NATURAL;
		intended_device_family		: STRING;
		lose_lock_on_one_change		: STRING;
		lpm_hint		: STRING;
		lpm_type		: STRING;
		number_of_channels		: NATURAL;
		outclock_resource		: STRING;
		pll_operation_mode		: STRING;
		pll_self_reset_on_loss_lock		: STRING;
		port_rx_channel_data_align		: STRING;
		port_rx_data_align		: STRING;
		refclk_frequency		: STRING;
		registered_data_align_input		: STRING;
		registered_output		: STRING;
		reset_fifo_at_first_lock		: STRING;
		rx_align_data_reg		: STRING;
		sim_dpa_is_negative_ppm_drift		: STRING;
		sim_dpa_net_ppm_variation		: NATURAL;
		sim_dpa_output_clock_phase_shift		: NATURAL;
		use_coreclock_input		: STRING;
		use_dpll_rawperror		: STRING;
		use_external_pll		: STRING;
		use_no_phase_shift		: STRING;
		x_on_bitslip		: STRING;
		clk_src_is_pll		: STRING
	);
	PORT (
			pll_areset	: IN STD_LOGIC ;
			rx_channel_data_align	: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_dpa_lock_reset	: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_dpll_hold	: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_fifo_reset	: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_in	: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_inclock	: IN STD_LOGIC ;
			rx_reset	: IN STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_cda_max	: OUT STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_dpa_locked	: OUT STD_LOGIC_VECTOR (N_LANE-1 DOWNTO 0);
			rx_locked	: OUT STD_LOGIC ;
			rx_out	: OUT STD_LOGIC_VECTOR (N_LANE*10-1 DOWNTO 0);
			rx_outclock	: OUT STD_LOGIC 
	);
	END COMPONENT;

BEGIN
	rx_cda_max    <= sub_wire0(N_LANE-1 DOWNTO 0);
	rx_dpa_locked    <= sub_wire1(N_LANE-1 DOWNTO 0);
	rx_locked    <= sub_wire2;
	rx_out    <= sub_wire3(N_LANE*10-1 DOWNTO 0);
	rx_outclock    <= sub_wire4;

	ALTLVDS_RX_component : ALTLVDS_RX
	GENERIC MAP (
		buffer_implementation 		=> "RAM",
		cds_mode 					=> "UNUSED",
		common_rx_tx_pll 			=> "OFF",
		data_align_rollover 		=> 10,
		data_rate 					=> "1250.0 Mbps",
		deserialization_factor 		=> 10,
		dpa_initial_phase_value 	=> 0,
		dpll_lock_count 			=> 0,
		dpll_lock_window 			=> 0,
		enable_clock_pin_mode 		=> "UNUSED",
		enable_dpa_align_to_rising_edge_only 	=> "OFF",
		enable_dpa_calibration 		=> "ON",
		enable_dpa_fifo 			=> "UNUSED",
		enable_dpa_initial_phase_selection 		=> "OFF",
		enable_dpa_mode 			=> "ON",
		enable_dpa_pll_calibration 	=> "OFF",
		enable_soft_cdr_mode 		=> "OFF",
		implement_in_les 			=> "OFF",
		inclock_boost 				=> 0,
		inclock_data_alignment 		=> "EDGE_ALIGNED",
		inclock_period 				=> 8000,
		inclock_phase_shift 		=> 0,
		input_data_rate 			=> 1250,
		intended_device_family 		=> "Arria V",
		lose_lock_on_one_change 	=> "UNUSED",
		lpm_hint 					=> "CBX_MODULE_PREFIX=altera_lvds_rx_28nm",
		lpm_type 					=> "altlvds_rx",
		number_of_channels 			=> N_LANE,
		outclock_resource 			=> "Global clock",
		pll_operation_mode 			=> "UNUSED",
		pll_self_reset_on_loss_lock => "UNUSED",
		port_rx_channel_data_align 	=> "PORT_USED",
		port_rx_data_align 			=> "PORT_UNUSED",
		refclk_frequency 			=> "125.000000 MHz",
		registered_data_align_input => "UNUSED",
		registered_output 			=> "ON",
		reset_fifo_at_first_lock 	=> "UNUSED",
		rx_align_data_reg 			=> "UNUSED",
		sim_dpa_is_negative_ppm_drift 			=> "OFF",
		sim_dpa_net_ppm_variation 	=> 0,
		sim_dpa_output_clock_phase_shift		=> 0,
		use_coreclock_input 		=> "OFF",
		use_dpll_rawperror 			=> "OFF",
		use_external_pll 			=> "OFF",
		use_no_phase_shift 			=> "ON",
		x_on_bitslip 				=> "ON",
		clk_src_is_pll 				=> "off"
	)
	PORT MAP (
		pll_areset 				=> pll_areset,
		rx_channel_data_align 	=> rx_channel_data_align,
		rx_dpa_lock_reset 		=> rx_dpa_lock_reset,
		rx_dpll_hold 			=> rx_dpll_hold,
		rx_fifo_reset			=> rx_fifo_reset,
		rx_in 					=> rx_in,
		rx_inclock 				=> rx_inclock,
		rx_reset 				=> rx_reset,
		rx_cda_max 				=> sub_wire0,
		rx_dpa_locked 			=> sub_wire1,
		rx_locked 				=> sub_wire2,
		rx_out 					=> sub_wire3,
		rx_outclock 			=> sub_wire4
	);



END SYN;



