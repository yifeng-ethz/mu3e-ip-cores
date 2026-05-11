#############################A10_PCIE_RX_P_8 to A10_PCIE_RX_P_15############################
##   location, IO_STANDARD, XCVR_A10_RX_TERM_SEL, XCVR_A10_RX_ONE_STAGE_ENABLE,
##   XCVR_A10_RX_ADP_VGA_SEL, XCVR_VCCR_VCCT_VOLTAGE
# for ES2 : pcie_rx_0 to pcie_rx_7
set_location_assignment PIN_AC42 -to A10_PCIE_RX_P_8
set_location_assignment PIN_AB40 -to A10_PCIE_RX_P_9
set_location_assignment PIN_AA42 -to A10_PCIE_RX_P_10
set_location_assignment PIN_W42  -to A10_PCIE_RX_P_11
set_location_assignment PIN_Y40  -to A10_PCIE_RX_P_12
set_location_assignment PIN_V40  -to A10_PCIE_RX_P_13
set_location_assignment PIN_U42  -to A10_PCIE_RX_P_14
set_location_assignment PIN_T40  -to A10_PCIE_RX_P_15

set_location_assignment PIN_AF44 -to A10_PCIE_TX_P_8
set_location_assignment PIN_AD44 -to A10_PCIE_TX_P_9
set_location_assignment PIN_AB44 -to A10_PCIE_TX_P_10
set_location_assignment PIN_Y44  -to A10_PCIE_TX_P_11
set_location_assignment PIN_V44  -to A10_PCIE_TX_P_12
set_location_assignment PIN_T44  -to A10_PCIE_TX_P_13
set_location_assignment PIN_P44  -to A10_PCIE_TX_P_14
set_location_assignment PIN_M44  -to A10_PCIE_TX_P_15

# IO_STANDARD assignment A10_PCIE_RX_P_8 to A10_PCIE_RX_P_15
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_8
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_9
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_10
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_11
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_12
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_13
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_14
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_PCIE_RX_P_15

# Logic Option assignment A10_PCIE_RX_P_8 to A10_PCIE_RX_P_15
# Receiver On-Chip Termination R_R1
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_8
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_9
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_10
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_11
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_12
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_13
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_14
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to A10_PCIE_RX_P_15

# Logic Option assignment A10_PCIE_RX_P_8 to A10_PCIE_RX_P_15
# Receiver High Data Rate Mode Equalizer NON_S1_MODE
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_8
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_9
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_10
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_11
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_12
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_13
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_14
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to A10_PCIE_RX_P_15

# Logic Option assignment A10_PCIE_RX_P_8 to A10_PCIE_RX_P_15
# Receiver High Gain Mode Equalizer AC Gain Control RADP_CTLE_ACGAIN_4S_7
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_8
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_9
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_10
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_11
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_12
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_13
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_14
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to A10_PCIE_RX_P_15


# Logic Option assignment A10_PCIE_RX_P_8 to A10_PCIE_RX_P_15
# VCCR_GXB/VCCT_GXB Voltage 1_0V
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_8
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_9
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_10
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_11
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_12
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_13
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_14
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_RX_P_15

# Logic Option assignment A10_PCIE_TX_P_8 to A10_PCIE_TX_P_15
# XCVR_VCCR_VCCT_VOLTAGE 1_0V
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_8
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_9
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_10
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_11
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_12
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_13
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_14
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_PCIE_TX_P_15

# PCIe reset
# Location assignment
set_location_assignment PIN_BC28 -to LVT_A10_PERST_2_N
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to LVT_A10_PERST_2_N

# PCIe Refclk
# Location assignment
set_location_assignment PIN_W37 -to A10_CLK_PCIE_P_1 -comment "Bank : 1F"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD HCSL -to A10_CLK_PCIE_P_1

# Commit assignments
#export_assignments
