#############################i_pcie0_rx[0] to i_pcie0_rx[7]############################
##   location, IO_STANDARD, XCVR_A10_RX_TERM_SEL, XCVR_A10_RX_ONE_STAGE_ENABLE,
##   XCVR_A10_RX_ADP_VGA_SEL, XCVR_VCCR_VCCT_VOLTAGE
set_location_assignment PIN_AT40 -to i_pcie0_rx[0]
set_location_assignment PIN_AP40 -to i_pcie0_rx[1]
set_location_assignment PIN_AN42 -to i_pcie0_rx[2]
set_location_assignment PIN_AM40 -to i_pcie0_rx[3]
set_location_assignment PIN_AL42 -to i_pcie0_rx[4]
set_location_assignment PIN_AK40 -to i_pcie0_rx[5]
set_location_assignment PIN_AJ42 -to i_pcie0_rx[6]
set_location_assignment PIN_AH40 -to i_pcie0_rx[7]

set_location_assignment PIN_BB44 -to o_pcie0_tx[0]
set_location_assignment PIN_BA42 -to o_pcie0_tx[1]
set_location_assignment PIN_AY44 -to o_pcie0_tx[2]
set_location_assignment PIN_AW42 -to o_pcie0_tx[3]
set_location_assignment PIN_AV44 -to o_pcie0_tx[4]
set_location_assignment PIN_AU42 -to o_pcie0_tx[5]
set_location_assignment PIN_AT44 -to o_pcie0_tx[6]
set_location_assignment PIN_AR42 -to o_pcie0_tx[7]

# IO_STANDARD assignment i_pcie0_rx[0] to i_pcie0_rx[7]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[0]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[1]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[2]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[3]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[4]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[5]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[6]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie0_rx[7]

# Logic Option assignment i_pcie0_rx[0] to i_pcie0_rx[7]
# Receiver On-Chip Termination R_R1
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[0]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[1]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[2]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[3]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[4]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[5]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[6]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie0_rx[7]

# Logic Option assignment i_pcie0_rx[0] to i_pcie0_rx[7]
# Receiver High Data Rate Mode Equalizer NON_S1_MODE
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[0]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[1]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[2]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[3]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[4]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[5]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[6]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie0_rx[7]

# Logic Option assignment i_pcie0_rx[0] to i_pcie0_rx[7]
# Receiver High Gain Mode Equalizer AC Gain Control RADP_CTLE_ACGAIN_4S_7
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[0]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[1]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[2]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[3]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[4]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[5]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[6]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to i_pcie0_rx[7]

# Logic Option assignment i_pcie0_rx[0] to i_pcie0_rx[7]
# Receiver High Gain Mode Equalizer DC Gain Control STG1_GAIN7
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[0]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[1]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[2]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[3]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[4]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[5]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[6]
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to i_pcie0_rx[7]

# Logic Option assignment i_pcie0_rx[0] to i_pcie0_rx[7]
# Receiver Variable Gain Amplifier Voltage Swing Select RADP_VGA_SEL_4
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[0]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[1]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[2]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[3]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[4]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[5]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[6]
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to i_pcie0_rx[7]

# Logic Option assignment i_pcie0_rx[0] to i_pcie0_rx[7]
# VCCR_GXB/VCCT_GXB Voltage 1_0V
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie0_rx[7]

# IO_STANDARD assignment o_pcie0_tx[0] to o_pcie0_tx[7]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[0]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[1]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[2]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[3]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[4]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[5]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[6]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to o_pcie0_tx[7]

# Logic Option assignment o_pcie0_tx[0] to o_pcie0_tx[7]
# XCVR_VCCR_VCCT_VOLTAGE 1_0V
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie0_tx[7]

# PCIe reset
# Location assignment
set_location_assignment PIN_BC30 -to i_pcie0_perst_n
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to i_pcie0_perst_n

# PCIe Refclk
# Location assignment
set_location_assignment PIN_AG37 -to i_pcie0_refclk -comment "Bank : 1D"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD HCSL -to i_pcie0_refclk

# Commit assignments
#export_assignments
