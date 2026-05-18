#############################i_pcie1_rx[0] to i_pcie1_rx[7]############################
##   location, IO_STANDARD, XCVR_A10_RX_TERM_SEL, XCVR_A10_RX_ONE_STAGE_ENABLE,
##   XCVR_A10_RX_ADP_VGA_SEL, XCVR_VCCR_VCCT_VOLTAGE
# for ES2 : pcie_rx_0 to pcie_rx_7
set_location_assignment PIN_AC42 -to i_pcie1_rx[0]
set_location_assignment PIN_AB40 -to i_pcie1_rx[1]
set_location_assignment PIN_AA42 -to i_pcie1_rx[2]
set_location_assignment PIN_W42  -to i_pcie1_rx[3]
set_location_assignment PIN_Y40  -to i_pcie1_rx[4]
set_location_assignment PIN_V40  -to i_pcie1_rx[5]
set_location_assignment PIN_U42  -to i_pcie1_rx[6]
set_location_assignment PIN_T40  -to i_pcie1_rx[7]

set_location_assignment PIN_AF44 -to o_pcie1_tx[0]
set_location_assignment PIN_AD44 -to o_pcie1_tx[1]
set_location_assignment PIN_AB44 -to o_pcie1_tx[2]
set_location_assignment PIN_Y44  -to o_pcie1_tx[3]
set_location_assignment PIN_V44  -to o_pcie1_tx[4]
set_location_assignment PIN_T44  -to o_pcie1_tx[5]
set_location_assignment PIN_P44  -to o_pcie1_tx[6]
set_location_assignment PIN_M44  -to o_pcie1_tx[7]

# IO_STANDARD assignment i_pcie1_rx[0] to i_pcie1_rx[7]
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[0]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[1]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[2]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[3]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[4]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[5]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[6]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to i_pcie1_rx[7]

# Logic Option assignment i_pcie1_rx[0] to i_pcie1_rx[7]
# Receiver On-Chip Termination R_R1
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[0]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[1]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[2]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[3]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[4]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[5]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[6]
set_instance_assignment -name XCVR_A10_RX_TERM_SEL R_R1 -to i_pcie1_rx[7]

# Logic Option assignment i_pcie1_rx[0] to i_pcie1_rx[7]
# Receiver High Data Rate Mode Equalizer NON_S1_MODE
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[0]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[1]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[2]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[3]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[4]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[5]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[6]
set_instance_assignment -name XCVR_A10_RX_ONE_STAGE_ENABLE NON_S1_MODE -to i_pcie1_rx[7]

# Logic Option assignment i_pcie1_rx[0] to i_pcie1_rx[7]
# Receiver High Gain Mode Equalizer AC Gain Control RADP_CTLE_ACGAIN_4S_7
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[0]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[1]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[2]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[3]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[4]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[5]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[6]
set_instance_assignment -name XCVR_A10_RX_ADP_CTLE_ACGAIN_4S RADP_CTLE_ACGAIN_4S_0 -to i_pcie1_rx[7]


# Logic Option assignment i_pcie1_rx[0] to i_pcie1_rx[7]
# VCCR_GXB/VCCT_GXB Voltage 1_0V
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to i_pcie1_rx[7]

# Logic Option assignment o_pcie1_tx[0] to o_pcie1_tx[7]
# XCVR_VCCR_VCCT_VOLTAGE 1_0V
# for ES2 : pcie_rx_0 to pcie_rx_7
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to o_pcie1_tx[7]

# PCIe reset
# Location assignment
set_location_assignment PIN_BC28 -to i_pcie1_perst_n
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to i_pcie1_perst_n

# PCIe Refclk
# Location assignment
set_location_assignment PIN_W37 -to i_pcie1_refclk -comment "Bank : 1F"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD HCSL -to i_pcie1_refclk

# Commit assignments
#export_assignments
