#############################A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7############################
##   location, IO_STANDARD, XCVR_A10_RX_TERM_SEL, XCVR_A10_RX_ONE_STAGE_ENABLE,
##   XCVR_A10_RX_ADP_VGA_SEL, XCVR_VCCR_VCCT_VOLTAGE
set_location_assignment PIN_AT40 -to A10_PCIE_RX_P_0
set_location_assignment PIN_AP40 -to A10_PCIE_RX_P_1
set_location_assignment PIN_AN42 -to A10_PCIE_RX_P_2
set_location_assignment PIN_AM40 -to A10_PCIE_RX_P_3
set_location_assignment PIN_AL42 -to A10_PCIE_RX_P_4
set_location_assignment PIN_AK40 -to A10_PCIE_RX_P_5
set_location_assignment PIN_AJ42 -to A10_PCIE_RX_P_6
set_location_assignment PIN_AH40 -to A10_PCIE_RX_P_7

set_location_assignment PIN_BB44 -to A10_PCIE_TX_P_0
set_location_assignment PIN_BA42 -to A10_PCIE_TX_P_1
set_location_assignment PIN_AY44 -to A10_PCIE_TX_P_2
set_location_assignment PIN_AW42 -to A10_PCIE_TX_P_3
set_location_assignment PIN_AV44 -to A10_PCIE_TX_P_4
set_location_assignment PIN_AU42 -to A10_PCIE_TX_P_5
set_location_assignment PIN_AT44 -to A10_PCIE_TX_P_6
set_location_assignment PIN_AR42 -to A10_PCIE_TX_P_7

# IO_STANDARD assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_0
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_1
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_2
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_3
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_4
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_5
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_6
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_7

# Logic Option assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
# Receiver On-Chip Termination R_R1
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_0
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_1
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_2
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_3
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_4
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_5
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_6
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_7

# Logic Option assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
# Receiver High Data Rate Mode Equalizer NON_S1_MODE
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_0
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_1
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_2
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_3
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_4
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_5
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_6
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_7

# Logic Option assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
# Receiver High Gain Mode Equalizer AC Gain Control RADP_CTLE_ACGAIN_4S_7
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_0
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_1
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_2
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_3
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_4
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_5
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_6
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_7 -to A10_PCIE_RX_P_7

# Logic Option assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
# Receiver High Gain Mode Equalizer DC Gain Control STG1_GAIN7
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_0
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_1
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_2
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_3
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_4
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_5
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_6
set_instance_assignment -name XCVR_A10_RX_EQ_DC_GAIN_TRIM STG1_GAIN7 -to A10_PCIE_RX_P_7

# Logic Option assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
# Receiver Variable Gain Amplifier Voltage Swing Select RADP_VGA_SEL_4
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_0
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_1
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_2
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_3
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_4
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_5
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_6
set_instance_assignment -name XCVR_A10_RX_ADP_VGA_SEL RADP_VGA_SEL_4 -to A10_PCIE_RX_P_7

# Logic Option assignment A10_PCIE_RX_P_0 to A10_PCIE_RX_P_7
# VCCR_GXB/VCCT_GXB Voltage 1_0V
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_0
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_1
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_2
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_3
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_4
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_5
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_6
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_7

# IO_STANDARD assignment A10_PCIE_TX_P_0 to A10_PCIE_TX_P_7
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_0
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_1
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_2
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_3
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_4
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_5
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_6
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_PCIE_TX_P_7

# Logic Option assignment A10_PCIE_TX_P_0 to A10_PCIE_TX_P_7
# XCVR_VCCR_VCCT_VOLTAGE 1_0V
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_0
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_1
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_2
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_3
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_4
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_5
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_6
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_7

# PCIe reset
# Location assignment
set_location_assignment PIN_BC30 -to LVT_A10_PERST_N
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to LVT_A10_PERST_N

# PCIe Refclk
# Location assignment
set_location_assignment PIN_AG37 -to A10_CLK_PCIE_P_0 -comment "Bank : 1D"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD HCSL -to A10_CLK_PCIE_P_0

# Commit assignments
#export_assignments
