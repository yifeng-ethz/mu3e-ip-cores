#============================================================
# Build by Terasic V2.0.0
#============================================================

set_global_assignment -name FAMILY "Arria 10"
set_global_assignment -name DEVICE 10AX115N2F45E1SG
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 100
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"



set_instance_assignment -name XCVR_REFCLK_PIN_TERMINATION DC_COUPLING_EXTERNAL_RESISTOR -to PCIE_REFCLK_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to PCIE_TX_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to PCIE_RX_p
set_instance_assignment -name XCVR_REFCLK_PIN_TERMINATION AC_COUPLING -to OB_PCIE_REFCLK_p
set_instance_assignment -name XCVR_REFCLK_PIN_TERMINATION AC_COUPLING -to QSFPA_REFCLK_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPA_RX_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPA_TX_p
set_instance_assignment -name XCVR_REFCLK_PIN_TERMINATION AC_COUPLING -to QSFPB_REFCLK_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPB_RX_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPB_TX_p
set_instance_assignment -name XCVR_REFCLK_PIN_TERMINATION AC_COUPLING -to QSFPC_REFCLK_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPC_RX_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPC_TX_p
set_instance_assignment -name XCVR_REFCLK_PIN_TERMINATION AC_COUPLING -to QSFPD_REFCLK_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPD_RX_p
set_instance_assignment -name XCVR_IO_PIN_TERMINATION 100_OHMS -to QSFPD_TX_p
#============================================================
# CLOCK
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLKUSR_100
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLK_100_B3D
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLK_50_B2J
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLK_50_B2L
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLK_50_B3D
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLK_50_B3F
set_instance_assignment -name IO_STANDARD "1.8 V" -to CLK_50_B3H
set_location_assignment PIN_AV26 -to CLKUSR_100
set_location_assignment PIN_AH11 -to CLK_100_B3D
set_location_assignment PIN_W36 -to CLK_50_B2J
set_location_assignment PIN_H32 -to CLK_50_B2L
set_location_assignment PIN_AN7 -to CLK_50_B3D
set_location_assignment PIN_G12 -to CLK_50_B3F
set_location_assignment PIN_D21 -to CLK_50_B3H

#============================================================
# KEY
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to CPU_RESET_n
set_instance_assignment -name IO_STANDARD "1.2 V" -to BUTTON[0]
set_instance_assignment -name IO_STANDARD "1.2 V" -to BUTTON[1]
set_instance_assignment -name IO_STANDARD "1.2 V" -to BUTTON[2]
set_instance_assignment -name IO_STANDARD "1.2 V" -to BUTTON[3]
set_location_assignment PIN_AP24 -to CPU_RESET_n
set_location_assignment PIN_AJ13 -to BUTTON[0]
set_location_assignment PIN_AE13 -to BUTTON[1]
set_location_assignment PIN_AV16 -to BUTTON[2]
set_location_assignment PIN_AR9 -to BUTTON[3]

#============================================================
# SW
#============================================================
set_instance_assignment -name IO_STANDARD "1.2 V" -to SW[0]
set_instance_assignment -name IO_STANDARD "1.2 V" -to SW[1]
set_location_assignment PIN_AY28 -to SW[0]
set_location_assignment PIN_AM27 -to SW[1]

#============================================================
# LED
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED_BRACKET[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED_BRACKET[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED_BRACKET[2]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED_BRACKET[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED[2]
set_instance_assignment -name IO_STANDARD "1.8 V" -to LED[3]
set_location_assignment PIN_AF10 -to LED_BRACKET[0]
set_location_assignment PIN_AF9 -to LED_BRACKET[1]
set_location_assignment PIN_Y13 -to LED_BRACKET[2]
set_location_assignment PIN_W11 -to LED_BRACKET[3]
set_location_assignment PIN_T11 -to LED[0]
set_location_assignment PIN_R11 -to LED[1]
set_location_assignment PIN_N15 -to LED[2]
set_location_assignment PIN_M15 -to LED[3]

#============================================================
# HEX0
#============================================================
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX0_D[0]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX0_D[1]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX0_D[2]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX0_D[3]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX0_D[4]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX0_D[5]
set_instance_assignment -name IO_STANDARD "1.8 V" -to HEX0_D[6]
set_instance_assignment -name IO_STANDARD "1.8 V" -to HEX0_DP
set_location_assignment PIN_AW8 -to HEX0_D[0]
set_location_assignment PIN_AY8 -to HEX0_D[1]
set_location_assignment PIN_AY9 -to HEX0_D[2]
set_location_assignment PIN_BA9 -to HEX0_D[3]
set_location_assignment PIN_BB9 -to HEX0_D[4]
set_location_assignment PIN_BD10 -to HEX0_D[5]
set_location_assignment PIN_V10 -to HEX0_D[6]
set_location_assignment PIN_AG9 -to HEX0_DP

#============================================================
# HEX1
#============================================================
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[0]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[1]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[2]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[3]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[4]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[5]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_D[6]
set_instance_assignment -name IO_STANDARD "1.2 V" -to HEX1_DP
set_location_assignment PIN_AM32 -to HEX1_D[0]
set_location_assignment PIN_AN32 -to HEX1_D[1]
set_location_assignment PIN_AN31 -to HEX1_D[2]
set_location_assignment PIN_AP31 -to HEX1_D[3]
set_location_assignment PIN_BA35 -to HEX1_D[4]
set_location_assignment PIN_BD34 -to HEX1_D[5]
set_location_assignment PIN_AR31 -to HEX1_D[6]
set_location_assignment PIN_BC28 -to HEX1_DP

#============================================================
# FAN
#============================================================
set_instance_assignment -name IO_STANDARD "1.2 V" -to FAN_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.2 V" -to FAN_I2C_SDA
set_instance_assignment -name IO_STANDARD "1.2 V" -to FAN_ALERT_n
set_location_assignment PIN_AJ33 -to FAN_I2C_SCL
set_location_assignment PIN_AL32 -to FAN_I2C_SDA
set_location_assignment PIN_AL31 -to FAN_ALERT_n

#============================================================
# FLASH
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_CLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[2]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[4]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[5]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[6]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[7]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[8]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[9]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[10]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[11]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[12]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[13]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[14]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[15]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[16]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[17]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[18]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[19]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[20]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[21]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[22]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[23]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[24]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[25]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_A[26]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[2]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[4]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[5]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[6]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[7]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[8]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[9]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[10]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[11]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[12]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[13]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[14]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[15]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[16]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[17]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[18]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[19]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[20]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[21]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[22]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[23]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[24]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[25]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[26]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[27]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[28]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[29]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[30]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_D[31]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_CE_n[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_CE_n[1]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_WE_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_OE_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_ADV_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_RESET_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_RDY_BSY_n[0]
set_instance_assignment -name IO_STANDARD "1.8 V" -to FLASH_RDY_BSY_n[1]
set_location_assignment PIN_T9 -to FLASH_CLK
set_location_assignment PIN_H26 -to FLASH_A[1]
set_location_assignment PIN_J18 -to FLASH_A[2]
set_location_assignment PIN_N17 -to FLASH_A[3]
set_location_assignment PIN_P15 -to FLASH_A[4]
set_location_assignment PIN_B18 -to FLASH_A[5]
set_location_assignment PIN_E18 -to FLASH_A[6]
set_location_assignment PIN_D18 -to FLASH_A[7]
set_location_assignment PIN_J10 -to FLASH_A[8]
set_location_assignment PIN_B17 -to FLASH_A[9]
set_location_assignment PIN_J11 -to FLASH_A[10]
set_location_assignment PIN_H8 -to FLASH_A[11]
set_location_assignment PIN_A17 -to FLASH_A[12]
set_location_assignment PIN_G8 -to FLASH_A[13]
set_location_assignment PIN_G9 -to FLASH_A[14]
set_location_assignment PIN_A16 -to FLASH_A[15]
set_location_assignment PIN_K11 -to FLASH_A[16]
set_location_assignment PIN_B15 -to FLASH_A[17]
set_location_assignment PIN_G7 -to FLASH_A[18]
set_location_assignment PIN_F6 -to FLASH_A[19]
set_location_assignment PIN_A15 -to FLASH_A[20]
set_location_assignment PIN_A14 -to FLASH_A[21]
set_location_assignment PIN_H6 -to FLASH_A[22]
set_location_assignment PIN_T12 -to FLASH_A[23]
set_location_assignment PIN_U12 -to FLASH_A[24]
set_location_assignment PIN_F7 -to FLASH_A[25]
set_location_assignment PIN_B14 -to FLASH_A[26]
set_location_assignment PIN_B35 -to FLASH_D[0]
set_location_assignment PIN_A35 -to FLASH_D[1]
set_location_assignment PIN_C35 -to FLASH_D[2]
set_location_assignment PIN_C33 -to FLASH_D[3]
set_location_assignment PIN_C32 -to FLASH_D[4]
set_location_assignment PIN_A32 -to FLASH_D[5]
set_location_assignment PIN_C26 -to FLASH_D[6]
set_location_assignment PIN_B24 -to FLASH_D[7]
set_location_assignment PIN_C36 -to FLASH_D[8]
set_location_assignment PIN_B34 -to FLASH_D[9]
set_location_assignment PIN_A34 -to FLASH_D[10]
set_location_assignment PIN_B33 -to FLASH_D[11]
set_location_assignment PIN_B32 -to FLASH_D[12]
set_location_assignment PIN_A31 -to FLASH_D[13]
set_location_assignment PIN_E24 -to FLASH_D[14]
set_location_assignment PIN_C25 -to FLASH_D[15]
set_location_assignment PIN_K33 -to FLASH_D[16]
set_location_assignment PIN_J39 -to FLASH_D[17]
set_location_assignment PIN_AA32 -to FLASH_D[18]
set_location_assignment PIN_J35 -to FLASH_D[19]
set_location_assignment PIN_H36 -to FLASH_D[20]
set_location_assignment PIN_AB32 -to FLASH_D[21]
set_location_assignment PIN_J34 -to FLASH_D[22]
set_location_assignment PIN_AA31 -to FLASH_D[23]
set_location_assignment PIN_J36 -to FLASH_D[24]
set_location_assignment PIN_J38 -to FLASH_D[25]
set_location_assignment PIN_K34 -to FLASH_D[26]
set_location_assignment PIN_H38 -to FLASH_D[27]
set_location_assignment PIN_H37 -to FLASH_D[28]
set_location_assignment PIN_Y31 -to FLASH_D[29]
set_location_assignment PIN_H35 -to FLASH_D[30]
set_location_assignment PIN_J33 -to FLASH_D[31]
set_location_assignment PIN_H10 -to FLASH_CE_n[0]
set_location_assignment PIN_N16 -to FLASH_CE_n[1]
set_location_assignment PIN_U10 -to FLASH_WE_n
set_location_assignment PIN_C16 -to FLASH_OE_n
set_location_assignment PIN_H7 -to FLASH_ADV_n
set_location_assignment PIN_C17 -to FLASH_RESET_n
set_location_assignment PIN_J8 -to FLASH_RDY_BSY_n[0]
set_location_assignment PIN_L36 -to FLASH_RDY_BSY_n[1]

#============================================================
# DDR4A
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to DDR4A_REFCLK_p
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[2]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[3]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[4]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[5]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[6]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[7]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[8]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[9]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[10]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[11]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[12]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[13]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[14]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[15]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_A[16]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_BA[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_BA[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_BG[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_BG[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4A_CK[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4A_CK[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4A_CK_n[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4A_CK_n[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_CKE[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_CKE[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[2]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[3]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[4]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[5]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[6]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS[7]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[2]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[3]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[4]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[5]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[6]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4A_DQS_n[7]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[0]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[1]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[2]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[3]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[4]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[5]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[6]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[7]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[8]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[9]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[10]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[11]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[12]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[13]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[14]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[15]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[16]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[17]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[18]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[19]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[20]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[21]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[22]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[23]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[24]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[25]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[26]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[27]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[28]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[29]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[30]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[31]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[32]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[33]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[34]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[35]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[36]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[37]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[38]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[39]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[40]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[41]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[42]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[43]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[44]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[45]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[46]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[47]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[48]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[49]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[50]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[51]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[52]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[53]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[54]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[55]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[56]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[57]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[58]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[59]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[60]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[61]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[62]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DQ[63]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[0]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[1]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[2]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[3]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[4]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[5]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[6]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4A_DBI_n[7]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_CS_n[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_CS_n[1]
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4A_RESET_n
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_ODT[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_ODT[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_PAR
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_ALERT_n
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4A_ACT_n
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4A_EVENT_n
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4A_SCL
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4A_SDA
set_location_assignment PIN_AV33 -to DDR4A_REFCLK_p
set_location_assignment PIN_AW34 -to DDR4A_A[0]
set_location_assignment PIN_AY34 -to DDR4A_A[1]
set_location_assignment PIN_AV31 -to DDR4A_A[2]
set_location_assignment PIN_AW31 -to DDR4A_A[3]
set_location_assignment PIN_BA37 -to DDR4A_A[4]
set_location_assignment PIN_BB37 -to DDR4A_A[5]
set_location_assignment PIN_AY36 -to DDR4A_A[6]
set_location_assignment PIN_AY37 -to DDR4A_A[7]
set_location_assignment PIN_AY32 -to DDR4A_A[8]
set_location_assignment PIN_AY33 -to DDR4A_A[9]
set_location_assignment PIN_AW35 -to DDR4A_A[10]
set_location_assignment PIN_AW36 -to DDR4A_A[11]
set_location_assignment PIN_AU34 -to DDR4A_A[12]
set_location_assignment PIN_AT31 -to DDR4A_A[13]
set_location_assignment PIN_AT32 -to DDR4A_A[14]
set_location_assignment PIN_AU32 -to DDR4A_A[15]
set_location_assignment PIN_AV32 -to DDR4A_A[16]
set_location_assignment PIN_AR32 -to DDR4A_BA[0]
set_location_assignment PIN_AP33 -to DDR4A_BA[1]
set_location_assignment PIN_AR33 -to DDR4A_BG[0]
set_location_assignment PIN_BC35 -to DDR4A_BG[1]
set_location_assignment PIN_BA34 -to DDR4A_CK[0]
set_location_assignment PIN_AM33 -to DDR4A_CK[1]
set_location_assignment PIN_BB35 -to DDR4A_CK_n[0]
set_location_assignment PIN_AN33 -to DDR4A_CK_n[1]
set_location_assignment PIN_BD33 -to DDR4A_CKE[0]
set_location_assignment PIN_AK31 -to DDR4A_CKE[1]
set_location_assignment PIN_AK37 -to DDR4A_DQS[0]
set_location_assignment PIN_AL34 -to DDR4A_DQS[1]
set_location_assignment PIN_AU38 -to DDR4A_DQS[2]
set_location_assignment PIN_AP38 -to DDR4A_DQS[3]
set_location_assignment PIN_AP29 -to DDR4A_DQS[4]
set_location_assignment PIN_BA29 -to DDR4A_DQS[5]
set_location_assignment PIN_BA26 -to DDR4A_DQS[6]
set_location_assignment PIN_AV30 -to DDR4A_DQS[7]
set_location_assignment PIN_AL37 -to DDR4A_DQS_n[0]
set_location_assignment PIN_AM34 -to DDR4A_DQS_n[1]
set_location_assignment PIN_AV38 -to DDR4A_DQS_n[2]
set_location_assignment PIN_AR38 -to DDR4A_DQS_n[3]
set_location_assignment PIN_AR29 -to DDR4A_DQS_n[4]
set_location_assignment PIN_BA30 -to DDR4A_DQS_n[5]
set_location_assignment PIN_BA27 -to DDR4A_DQS_n[6]
set_location_assignment PIN_AW30 -to DDR4A_DQS_n[7]
set_location_assignment PIN_AH35 -to DDR4A_DQ[0]
set_location_assignment PIN_AH32 -to DDR4A_DQ[1]
set_location_assignment PIN_AH36 -to DDR4A_DQ[2]
set_location_assignment PIN_AG35 -to DDR4A_DQ[3]
set_location_assignment PIN_AJ34 -to DDR4A_DQ[4]
set_location_assignment PIN_AH33 -to DDR4A_DQ[5]
set_location_assignment PIN_AJ36 -to DDR4A_DQ[6]
set_location_assignment PIN_AJ35 -to DDR4A_DQ[7]
set_location_assignment PIN_AK36 -to DDR4A_DQ[8]
set_location_assignment PIN_AN35 -to DDR4A_DQ[9]
set_location_assignment PIN_AM35 -to DDR4A_DQ[10]
set_location_assignment PIN_AM37 -to DDR4A_DQ[11]
set_location_assignment PIN_AP34 -to DDR4A_DQ[12]
set_location_assignment PIN_AT34 -to DDR4A_DQ[13]
set_location_assignment PIN_AL36 -to DDR4A_DQ[14]
set_location_assignment PIN_AL35 -to DDR4A_DQ[15]
set_location_assignment PIN_AT39 -to DDR4A_DQ[16]
set_location_assignment PIN_AV35 -to DDR4A_DQ[17]
set_location_assignment PIN_AV37 -to DDR4A_DQ[18]
set_location_assignment PIN_AT36 -to DDR4A_DQ[19]
set_location_assignment PIN_AU39 -to DDR4A_DQ[20]
set_location_assignment PIN_AU35 -to DDR4A_DQ[21]
set_location_assignment PIN_AU37 -to DDR4A_DQ[22]
set_location_assignment PIN_AV36 -to DDR4A_DQ[23]
set_location_assignment PIN_AR36 -to DDR4A_DQ[24]
set_location_assignment PIN_AN36 -to DDR4A_DQ[25]
set_location_assignment PIN_AM39 -to DDR4A_DQ[26]
set_location_assignment PIN_AR39 -to DDR4A_DQ[27]
set_location_assignment PIN_AN38 -to DDR4A_DQ[28]
set_location_assignment PIN_AN37 -to DDR4A_DQ[29]
set_location_assignment PIN_AM38 -to DDR4A_DQ[30]
set_location_assignment PIN_AR37 -to DDR4A_DQ[31]
set_location_assignment PIN_AM30 -to DDR4A_DQ[32]
set_location_assignment PIN_AN28 -to DDR4A_DQ[33]
set_location_assignment PIN_AN27 -to DDR4A_DQ[34]
set_location_assignment PIN_AM28 -to DDR4A_DQ[35]
set_location_assignment PIN_AN30 -to DDR4A_DQ[36]
set_location_assignment PIN_AM29 -to DDR4A_DQ[37]
set_location_assignment PIN_AP28 -to DDR4A_DQ[38]
set_location_assignment PIN_AL30 -to DDR4A_DQ[39]
set_location_assignment PIN_BB32 -to DDR4A_DQ[40]
set_location_assignment PIN_BC31 -to DDR4A_DQ[41]
set_location_assignment PIN_AW29 -to DDR4A_DQ[42]
set_location_assignment PIN_AW28 -to DDR4A_DQ[43]
set_location_assignment PIN_BA32 -to DDR4A_DQ[44]
set_location_assignment PIN_AY31 -to DDR4A_DQ[45]
set_location_assignment PIN_BB30 -to DDR4A_DQ[46]
set_location_assignment PIN_AY29 -to DDR4A_DQ[47]
set_location_assignment PIN_BB28 -to DDR4A_DQ[48]
set_location_assignment PIN_BD30 -to DDR4A_DQ[49]
set_location_assignment PIN_BB27 -to DDR4A_DQ[50]
set_location_assignment PIN_BD28 -to DDR4A_DQ[51]
set_location_assignment PIN_BC30 -to DDR4A_DQ[52]
set_location_assignment PIN_BD29 -to DDR4A_DQ[53]
set_location_assignment PIN_BC27 -to DDR4A_DQ[54]
set_location_assignment PIN_BB29 -to DDR4A_DQ[55]
set_location_assignment PIN_AT27 -to DDR4A_DQ[56]
set_location_assignment PIN_AV28 -to DDR4A_DQ[57]
set_location_assignment PIN_AR28 -to DDR4A_DQ[58]
set_location_assignment PIN_AT30 -to DDR4A_DQ[59]
set_location_assignment PIN_AU29 -to DDR4A_DQ[60]
set_location_assignment PIN_AU27 -to DDR4A_DQ[61]
set_location_assignment PIN_AT29 -to DDR4A_DQ[62]
set_location_assignment PIN_AR27 -to DDR4A_DQ[63]
set_location_assignment PIN_AK34 -to DDR4A_DBI_n[0]
set_location_assignment PIN_AP35 -to DDR4A_DBI_n[1]
set_location_assignment PIN_AT37 -to DDR4A_DBI_n[2]
set_location_assignment PIN_AP36 -to DDR4A_DBI_n[3]
set_location_assignment PIN_AP30 -to DDR4A_DBI_n[4]
set_location_assignment PIN_BA31 -to DDR4A_DBI_n[5]
set_location_assignment PIN_BD31 -to DDR4A_DBI_n[6]
set_location_assignment PIN_AU30 -to DDR4A_DBI_n[7]
set_location_assignment PIN_BB33 -to DDR4A_CS_n[0]
set_location_assignment PIN_AK33 -to DDR4A_CS_n[1]
set_location_assignment PIN_BD35 -to DDR4A_RESET_n
set_location_assignment PIN_BC32 -to DDR4A_ODT[0]
set_location_assignment PIN_AK32 -to DDR4A_ODT[1]
set_location_assignment PIN_BA36 -to DDR4A_PAR
set_location_assignment PIN_AG34 -to DDR4A_ALERT_n
set_location_assignment PIN_BB34 -to DDR4A_ACT_n
set_location_assignment PIN_AR34 -to DDR4A_EVENT_n
set_location_assignment PIN_AT35 -to DDR4A_SCL
set_location_assignment PIN_BC33 -to DDR4A_SDA

#============================================================
# DDR4B
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to DDR4B_REFCLK_p
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[2]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[3]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[4]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[5]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[6]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[7]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[8]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[9]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[10]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[11]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[12]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[13]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[14]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[15]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_A[16]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_BA[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_BA[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_BG[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_BG[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4B_CK[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4B_CK[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4B_CK_n[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V SSTL" -to DDR4B_CK_n[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_CKE[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_CKE[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[2]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[3]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[4]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[5]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[6]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS[7]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[0]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[1]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[2]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[3]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[4]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[5]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[6]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.2-V POD" -to DDR4B_DQS_n[7]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[0]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[1]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[2]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[3]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[4]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[5]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[6]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[7]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[8]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[9]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[10]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[11]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[12]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[13]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[14]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[15]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[16]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[17]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[18]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[19]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[20]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[21]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[22]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[23]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[24]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[25]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[26]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[27]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[28]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[29]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[30]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[31]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[32]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[33]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[34]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[35]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[36]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[37]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[38]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[39]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[40]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[41]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[42]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[43]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[44]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[45]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[46]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[47]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[48]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[49]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[50]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[51]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[52]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[53]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[54]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[55]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[56]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[57]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[58]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[59]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[60]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[61]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[62]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DQ[63]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[0]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[1]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[2]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[3]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[4]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[5]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[6]
set_instance_assignment -name IO_STANDARD "1.2-V POD" -to DDR4B_DBI_n[7]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_CS_n[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_CS_n[1]
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4B_RESET_n
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_ODT[0]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_ODT[1]
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_PAR
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_ALERT_n
set_instance_assignment -name IO_STANDARD "SSTL-12" -to DDR4B_ACT_n
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4B_EVENT_n
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4B_SCL
set_instance_assignment -name IO_STANDARD "1.2 V" -to DDR4B_SDA
set_location_assignment PIN_AP14 -to DDR4B_REFCLK_p
set_location_assignment PIN_AW15 -to DDR4B_A[0]
set_location_assignment PIN_AW14 -to DDR4B_A[1]
set_location_assignment PIN_AW13 -to DDR4B_A[2]
set_location_assignment PIN_AY13 -to DDR4B_A[3]
set_location_assignment PIN_AY14 -to DDR4B_A[4]
set_location_assignment PIN_BA14 -to DDR4B_A[5]
set_location_assignment PIN_BA12 -to DDR4B_A[6]
set_location_assignment PIN_BB12 -to DDR4B_A[7]
set_location_assignment PIN_AU13 -to DDR4B_A[8]
set_location_assignment PIN_AV13 -to DDR4B_A[9]
set_location_assignment PIN_AY11 -to DDR4B_A[10]
set_location_assignment PIN_BA11 -to DDR4B_A[11]
set_location_assignment PIN_AK14 -to DDR4B_A[12]
set_location_assignment PIN_AM13 -to DDR4B_A[13]
set_location_assignment PIN_AN13 -to DDR4B_A[14]
set_location_assignment PIN_AL14 -to DDR4B_A[15]
set_location_assignment PIN_AM14 -to DDR4B_A[16]
set_location_assignment PIN_AU14 -to DDR4B_BA[0]
set_location_assignment PIN_AP13 -to DDR4B_BA[1]
set_location_assignment PIN_AR13 -to DDR4B_BG[0]
set_location_assignment PIN_BB14 -to DDR4B_BG[1]
set_location_assignment PIN_BA10 -to DDR4B_CK[0]
set_location_assignment PIN_AV10 -to DDR4B_CK[1]
set_location_assignment PIN_BB10 -to DDR4B_CK_n[0]
set_location_assignment PIN_AV11 -to DDR4B_CK_n[1]
set_location_assignment PIN_BC10 -to DDR4B_CKE[0]
set_location_assignment PIN_AW9 -to DDR4B_CKE[1]
set_location_assignment PIN_AV18 -to DDR4B_DQS[0]
set_location_assignment PIN_BA15 -to DDR4B_DQS[1]
set_location_assignment PIN_BD13 -to DDR4B_DQS[2]
set_location_assignment PIN_AT10 -to DDR4B_DQS[3]
set_location_assignment PIN_AV7 -to DDR4B_DQS[4]
set_location_assignment PIN_AG12 -to DDR4B_DQS[5]
set_location_assignment PIN_AT15 -to DDR4B_DQS[6]
set_location_assignment PIN_AC13 -to DDR4B_DQS[7]
set_location_assignment PIN_AU18 -to DDR4B_DQS_n[0]
set_location_assignment PIN_BA16 -to DDR4B_DQS_n[1]
set_location_assignment PIN_BD14 -to DDR4B_DQS_n[2]
set_location_assignment PIN_AU10 -to DDR4B_DQS_n[3]
set_location_assignment PIN_AV6 -to DDR4B_DQS_n[4]
set_location_assignment PIN_AH12 -to DDR4B_DQS_n[5]
set_location_assignment PIN_AT16 -to DDR4B_DQS_n[6]
set_location_assignment PIN_AB12 -to DDR4B_DQS_n[7]
set_location_assignment PIN_AR19 -to DDR4B_DQ[0]
set_location_assignment PIN_AU19 -to DDR4B_DQ[1]
set_location_assignment PIN_AM17 -to DDR4B_DQ[2]
set_location_assignment PIN_AM18 -to DDR4B_DQ[3]
set_location_assignment PIN_AM20 -to DDR4B_DQ[4]
set_location_assignment PIN_AR18 -to DDR4B_DQ[5]
set_location_assignment PIN_AM19 -to DDR4B_DQ[6]
set_location_assignment PIN_AP19 -to DDR4B_DQ[7]
set_location_assignment PIN_BA17 -to DDR4B_DQ[8]
set_location_assignment PIN_AY17 -to DDR4B_DQ[9]
set_location_assignment PIN_AY16 -to DDR4B_DQ[10]
set_location_assignment PIN_AU15 -to DDR4B_DQ[11]
set_location_assignment PIN_AW18 -to DDR4B_DQ[12]
set_location_assignment PIN_AV17 -to DDR4B_DQ[13]
set_location_assignment PIN_AV15 -to DDR4B_DQ[14]
set_location_assignment PIN_AW16 -to DDR4B_DQ[15]
set_location_assignment PIN_BB17 -to DDR4B_DQ[16]
set_location_assignment PIN_BD16 -to DDR4B_DQ[17]
set_location_assignment PIN_BC16 -to DDR4B_DQ[18]
set_location_assignment PIN_BB18 -to DDR4B_DQ[19]
set_location_assignment PIN_BD18 -to DDR4B_DQ[20]
set_location_assignment PIN_BC18 -to DDR4B_DQ[21]
set_location_assignment PIN_BC15 -to DDR4B_DQ[22]
set_location_assignment PIN_BD15 -to DDR4B_DQ[23]
set_location_assignment PIN_AP8 -to DDR4B_DQ[24]
set_location_assignment PIN_AT12 -to DDR4B_DQ[25]
set_location_assignment PIN_AR8 -to DDR4B_DQ[26]
set_location_assignment PIN_AR12 -to DDR4B_DQ[27]
set_location_assignment PIN_AP11 -to DDR4B_DQ[28]
set_location_assignment PIN_AN11 -to DDR4B_DQ[29]
set_location_assignment PIN_AR11 -to DDR4B_DQ[30]
set_location_assignment PIN_AR7 -to DDR4B_DQ[31]
set_location_assignment PIN_AU8 -to DDR4B_DQ[32]
set_location_assignment PIN_AU9 -to DDR4B_DQ[33]
set_location_assignment PIN_AP10 -to DDR4B_DQ[34]
set_location_assignment PIN_AT9 -to DDR4B_DQ[35]
set_location_assignment PIN_AV8 -to DDR4B_DQ[36]
set_location_assignment PIN_AU7 -to DDR4B_DQ[37]
set_location_assignment PIN_AT7 -to DDR4B_DQ[38]
set_location_assignment PIN_AT6 -to DDR4B_DQ[39]
set_location_assignment PIN_AK13 -to DDR4B_DQ[40]
set_location_assignment PIN_AN12 -to DDR4B_DQ[41]
set_location_assignment PIN_AF12 -to DDR4B_DQ[42]
set_location_assignment PIN_AE12 -to DDR4B_DQ[43]
set_location_assignment PIN_AK12 -to DDR4B_DQ[44]
set_location_assignment PIN_AM12 -to DDR4B_DQ[45]
set_location_assignment PIN_AH13 -to DDR4B_DQ[46]
set_location_assignment PIN_AG13 -to DDR4B_DQ[47]
set_location_assignment PIN_AP15 -to DDR4B_DQ[48]
set_location_assignment PIN_AN16 -to DDR4B_DQ[49]
set_location_assignment PIN_AR17 -to DDR4B_DQ[50]
set_location_assignment PIN_AN17 -to DDR4B_DQ[51]
set_location_assignment PIN_AM15 -to DDR4B_DQ[52]
set_location_assignment PIN_AT17 -to DDR4B_DQ[53]
set_location_assignment PIN_AN15 -to DDR4B_DQ[54]
set_location_assignment PIN_AR16 -to DDR4B_DQ[55]
set_location_assignment PIN_AC12 -to DDR4B_DQ[56]
set_location_assignment PIN_AG14 -to DDR4B_DQ[57]
set_location_assignment PIN_AD14 -to DDR4B_DQ[58]
set_location_assignment PIN_AB14 -to DDR4B_DQ[59]
set_location_assignment PIN_AE14 -to DDR4B_DQ[60]
set_location_assignment PIN_AC11 -to DDR4B_DQ[61]
set_location_assignment PIN_AB13 -to DDR4B_DQ[62]
set_location_assignment PIN_AD13 -to DDR4B_DQ[63]
set_location_assignment PIN_AT19 -to DDR4B_DBI_n[0]
set_location_assignment PIN_AY18 -to DDR4B_DBI_n[1]
set_location_assignment PIN_BC17 -to DDR4B_DBI_n[2]
set_location_assignment PIN_AT11 -to DDR4B_DBI_n[3]
set_location_assignment PIN_AN10 -to DDR4B_DBI_n[4]
set_location_assignment PIN_AL12 -to DDR4B_DBI_n[5]
set_location_assignment PIN_AU17 -to DDR4B_DBI_n[6]
set_location_assignment PIN_AF14 -to DDR4B_DBI_n[7]
set_location_assignment PIN_BC13 -to DDR4B_CS_n[0]
set_location_assignment PIN_AV12 -to DDR4B_CS_n[1]
set_location_assignment PIN_BB13 -to DDR4B_RESET_n
set_location_assignment PIN_BC11 -to DDR4B_ODT[0]
set_location_assignment PIN_AW10 -to DDR4B_ODT[1]
set_location_assignment PIN_BB8 -to DDR4B_PAR
set_location_assignment PIN_AP18 -to DDR4B_ALERT_n
set_location_assignment PIN_BC12 -to DDR4B_ACT_n
set_location_assignment PIN_BD11 -to DDR4B_EVENT_n
set_location_assignment PIN_AP16 -to DDR4B_SCL
set_location_assignment PIN_AP9 -to DDR4B_SDA

#============================================================
# QDRIIA
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QDRIIA_REFCLK_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[18]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[19]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[20]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_A[21]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIIA_K_p
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIIA_K_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_D[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_BWS_n[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_BWS_n[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_CQ_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_CQ_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_Q[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_QVLD
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_WPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_RPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_DOFF_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIA_ODT
set_location_assignment PIN_L9 -to QDRIIA_REFCLK_p
set_location_assignment PIN_V12 -to QDRIIA_A[0]
set_location_assignment PIN_V13 -to QDRIIA_A[1]
set_location_assignment PIN_N10 -to QDRIIA_A[2]
set_location_assignment PIN_M10 -to QDRIIA_A[3]
set_location_assignment PIN_P11 -to QDRIIA_A[4]
set_location_assignment PIN_N11 -to QDRIIA_A[5]
set_location_assignment PIN_M9 -to QDRIIA_A[6]
set_location_assignment PIN_M8 -to QDRIIA_A[7]
set_location_assignment PIN_N7 -to QDRIIA_A[8]
set_location_assignment PIN_N8 -to QDRIIA_A[9]
set_location_assignment PIN_P10 -to QDRIIA_A[10]
set_location_assignment PIN_P9 -to QDRIIA_A[11]
set_location_assignment PIN_N6 -to QDRIIA_A[12]
set_location_assignment PIN_M7 -to QDRIIA_A[13]
set_location_assignment PIN_L10 -to QDRIIA_A[14]
set_location_assignment PIN_L7 -to QDRIIA_A[15]
set_location_assignment PIN_K7 -to QDRIIA_A[16]
set_location_assignment PIN_K8 -to QDRIIA_A[17]
set_location_assignment PIN_J9 -to QDRIIA_A[18]
set_location_assignment PIN_L6 -to QDRIIA_A[19]
set_location_assignment PIN_K6 -to QDRIIA_A[20]
set_location_assignment PIN_J6 -to QDRIIA_A[21]
set_location_assignment PIN_F12 -to QDRIIA_K_p
set_location_assignment PIN_E12 -to QDRIIA_K_n
set_location_assignment PIN_E8 -to QDRIIA_D[0]
set_location_assignment PIN_E9 -to QDRIIA_D[1]
set_location_assignment PIN_D8 -to QDRIIA_D[2]
set_location_assignment PIN_E11 -to QDRIIA_D[3]
set_location_assignment PIN_D9 -to QDRIIA_D[4]
set_location_assignment PIN_C8 -to QDRIIA_D[5]
set_location_assignment PIN_D10 -to QDRIIA_D[6]
set_location_assignment PIN_C10 -to QDRIIA_D[7]
set_location_assignment PIN_D11 -to QDRIIA_D[8]
set_location_assignment PIN_C13 -to QDRIIA_D[9]
set_location_assignment PIN_C12 -to QDRIIA_D[10]
set_location_assignment PIN_B12 -to QDRIIA_D[11]
set_location_assignment PIN_A12 -to QDRIIA_D[12]
set_location_assignment PIN_D13 -to QDRIIA_D[13]
set_location_assignment PIN_A11 -to QDRIIA_D[14]
set_location_assignment PIN_A10 -to QDRIIA_D[15]
set_location_assignment PIN_E13 -to QDRIIA_D[16]
set_location_assignment PIN_B10 -to QDRIIA_D[17]
set_location_assignment PIN_C11 -to QDRIIA_BWS_n[0]
set_location_assignment PIN_B13 -to QDRIIA_BWS_n[1]
set_location_assignment PIN_J13 -to QDRIIA_CQ_p
set_location_assignment PIN_H13 -to QDRIIA_CQ_n
set_location_assignment PIN_R12 -to QDRIIA_Q[0]
set_location_assignment PIN_R14 -to QDRIIA_Q[1]
set_location_assignment PIN_N12 -to QDRIIA_Q[2]
set_location_assignment PIN_M13 -to QDRIIA_Q[3]
set_location_assignment PIN_M12 -to QDRIIA_Q[4]
set_location_assignment PIN_M14 -to QDRIIA_Q[5]
set_location_assignment PIN_L12 -to QDRIIA_Q[6]
set_location_assignment PIN_K12 -to QDRIIA_Q[7]
set_location_assignment PIN_G10 -to QDRIIA_Q[8]
set_location_assignment PIN_H12 -to QDRIIA_Q[9]
set_location_assignment PIN_H11 -to QDRIIA_Q[10]
set_location_assignment PIN_J14 -to QDRIIA_Q[11]
set_location_assignment PIN_K14 -to QDRIIA_Q[12]
set_location_assignment PIN_K13 -to QDRIIA_Q[13]
set_location_assignment PIN_L14 -to QDRIIA_Q[14]
set_location_assignment PIN_N13 -to QDRIIA_Q[15]
set_location_assignment PIN_P13 -to QDRIIA_Q[16]
set_location_assignment PIN_R13 -to QDRIIA_Q[17]
set_location_assignment PIN_T14 -to QDRIIA_QVLD
set_location_assignment PIN_U8 -to QDRIIA_WPS_n
set_location_assignment PIN_U9 -to QDRIIA_RPS_n
set_location_assignment PIN_R9 -to QDRIIA_DOFF_n
set_location_assignment PIN_T10 -to QDRIIA_ODT

#============================================================
# QDRIIB
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QDRIIB_REFCLK_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[18]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[19]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[20]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_A[21]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIIB_K_p
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIIB_K_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_D[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_BWS_n[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_BWS_n[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_CQ_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_CQ_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_Q[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_QVLD
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_WPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_RPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_DOFF_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIB_ODT
set_location_assignment PIN_N18 -to QDRIIB_REFCLK_p
set_location_assignment PIN_L16 -to QDRIIB_A[0]
set_location_assignment PIN_L15 -to QDRIIB_A[1]
set_location_assignment PIN_E14 -to QDRIIB_A[2]
set_location_assignment PIN_D14 -to QDRIIB_A[3]
set_location_assignment PIN_G14 -to QDRIIB_A[4]
set_location_assignment PIN_F14 -to QDRIIB_A[5]
set_location_assignment PIN_D15 -to QDRIIB_A[6]
set_location_assignment PIN_C15 -to QDRIIB_A[7]
set_location_assignment PIN_F15 -to QDRIIB_A[8]
set_location_assignment PIN_F16 -to QDRIIB_A[9]
set_location_assignment PIN_H15 -to QDRIIB_A[10]
set_location_assignment PIN_G15 -to QDRIIB_A[11]
set_location_assignment PIN_E16 -to QDRIIB_A[12]
set_location_assignment PIN_D16 -to QDRIIB_A[13]
set_location_assignment PIN_E17 -to QDRIIB_A[14]
set_location_assignment PIN_G17 -to QDRIIB_A[15]
set_location_assignment PIN_G18 -to QDRIIB_A[16]
set_location_assignment PIN_L17 -to QDRIIB_A[17]
set_location_assignment PIN_K17 -to QDRIIB_A[18]
set_location_assignment PIN_H17 -to QDRIIB_A[19]
set_location_assignment PIN_H18 -to QDRIIB_A[20]
set_location_assignment PIN_K18 -to QDRIIB_A[21]
set_location_assignment PIN_K21 -to QDRIIB_K_p
set_location_assignment PIN_J21 -to QDRIIB_K_n
set_location_assignment PIN_G19 -to QDRIIB_D[0]
set_location_assignment PIN_F19 -to QDRIIB_D[1]
set_location_assignment PIN_E19 -to QDRIIB_D[2]
set_location_assignment PIN_D19 -to QDRIIB_D[3]
set_location_assignment PIN_C18 -to QDRIIB_D[4]
set_location_assignment PIN_B19 -to QDRIIB_D[5]
set_location_assignment PIN_B20 -to QDRIIB_D[6]
set_location_assignment PIN_C20 -to QDRIIB_D[7]
set_location_assignment PIN_F20 -to QDRIIB_D[8]
set_location_assignment PIN_L20 -to QDRIIB_D[9]
set_location_assignment PIN_J20 -to QDRIIB_D[10]
set_location_assignment PIN_N20 -to QDRIIB_D[11]
set_location_assignment PIN_L19 -to QDRIIB_D[12]
set_location_assignment PIN_L21 -to QDRIIB_D[13]
set_location_assignment PIN_K19 -to QDRIIB_D[14]
set_location_assignment PIN_J19 -to QDRIIB_D[15]
set_location_assignment PIN_M20 -to QDRIIB_D[16]
set_location_assignment PIN_M19 -to QDRIIB_D[17]
set_location_assignment PIN_G20 -to QDRIIB_BWS_n[0]
set_location_assignment PIN_H20 -to QDRIIB_BWS_n[1]
set_location_assignment PIN_D23 -to QDRIIB_CQ_p
set_location_assignment PIN_C23 -to QDRIIB_CQ_n
set_location_assignment PIN_L22 -to QDRIIB_Q[0]
set_location_assignment PIN_K23 -to QDRIIB_Q[1]
set_location_assignment PIN_J23 -to QDRIIB_Q[2]
set_location_assignment PIN_H23 -to QDRIIB_Q[3]
set_location_assignment PIN_H21 -to QDRIIB_Q[4]
set_location_assignment PIN_H22 -to QDRIIB_Q[5]
set_location_assignment PIN_G23 -to QDRIIB_Q[6]
set_location_assignment PIN_F21 -to QDRIIB_Q[7]
set_location_assignment PIN_E23 -to QDRIIB_Q[8]
set_location_assignment PIN_A22 -to QDRIIB_Q[9]
set_location_assignment PIN_B22 -to QDRIIB_Q[10]
set_location_assignment PIN_C22 -to QDRIIB_Q[11]
set_location_assignment PIN_B23 -to QDRIIB_Q[12]
set_location_assignment PIN_A21 -to QDRIIB_Q[13]
set_location_assignment PIN_C21 -to QDRIIB_Q[14]
set_location_assignment PIN_E22 -to QDRIIB_Q[15]
set_location_assignment PIN_F22 -to QDRIIB_Q[16]
set_location_assignment PIN_G22 -to QDRIIB_Q[17]
set_location_assignment PIN_K22 -to QDRIIB_QVLD
set_location_assignment PIN_K16 -to QDRIIB_WPS_n
set_location_assignment PIN_J16 -to QDRIIB_RPS_n
set_location_assignment PIN_H16 -to QDRIIB_DOFF_n
set_location_assignment PIN_M17 -to QDRIIB_ODT

#============================================================
# QDRIIC
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QDRIIC_REFCLK_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[18]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[19]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[20]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_A[21]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIIC_K_p
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIIC_K_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_D[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_BWS_n[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_BWS_n[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_CQ_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_CQ_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_Q[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_QVLD
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_WPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_RPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_DOFF_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIIC_ODT
set_location_assignment PIN_G24 -to QDRIIC_REFCLK_p
set_location_assignment PIN_D25 -to QDRIIC_A[0]
set_location_assignment PIN_D26 -to QDRIIC_A[1]
set_location_assignment PIN_A26 -to QDRIIC_A[2]
set_location_assignment PIN_A27 -to QDRIIC_A[3]
set_location_assignment PIN_A29 -to QDRIIC_A[4]
set_location_assignment PIN_A30 -to QDRIIC_A[5]
set_location_assignment PIN_B27 -to QDRIIC_A[6]
set_location_assignment PIN_B28 -to QDRIIC_A[7]
set_location_assignment PIN_C27 -to QDRIIC_A[8]
set_location_assignment PIN_C28 -to QDRIIC_A[9]
set_location_assignment PIN_B29 -to QDRIIC_A[10]
set_location_assignment PIN_B30 -to QDRIIC_A[11]
set_location_assignment PIN_C30 -to QDRIIC_A[12]
set_location_assignment PIN_C31 -to QDRIIC_A[13]
set_location_assignment PIN_L25 -to QDRIIC_A[14]
set_location_assignment PIN_K24 -to QDRIIC_A[15]
set_location_assignment PIN_J24 -to QDRIIC_A[16]
set_location_assignment PIN_G25 -to QDRIIC_A[17]
set_location_assignment PIN_F25 -to QDRIIC_A[18]
set_location_assignment PIN_J25 -to QDRIIC_A[19]
set_location_assignment PIN_H25 -to QDRIIC_A[20]
set_location_assignment PIN_J26 -to QDRIIC_A[21]
set_location_assignment PIN_AF34 -to QDRIIC_K_p
set_location_assignment PIN_AF35 -to QDRIIC_K_n
set_location_assignment PIN_AD33 -to QDRIIC_D[0]
set_location_assignment PIN_AC33 -to QDRIIC_D[1]
set_location_assignment PIN_AB33 -to QDRIIC_D[2]
set_location_assignment PIN_AB34 -to QDRIIC_D[3]
set_location_assignment PIN_AA34 -to QDRIIC_D[4]
set_location_assignment PIN_Y34 -to QDRIIC_D[5]
set_location_assignment PIN_W34 -to QDRIIC_D[6]
set_location_assignment PIN_AC35 -to QDRIIC_D[7]
set_location_assignment PIN_AA35 -to QDRIIC_D[8]
set_location_assignment PIN_AF36 -to QDRIIC_D[9]
set_location_assignment PIN_AE36 -to QDRIIC_D[10]
set_location_assignment PIN_AD34 -to QDRIIC_D[11]
set_location_assignment PIN_AE34 -to QDRIIC_D[12]
set_location_assignment PIN_AE33 -to QDRIIC_D[13]
set_location_assignment PIN_AE32 -to QDRIIC_D[14]
set_location_assignment PIN_AE31 -to QDRIIC_D[15]
set_location_assignment PIN_AF32 -to QDRIIC_D[16]
set_location_assignment PIN_AF31 -to QDRIIC_D[17]
set_location_assignment PIN_AB35 -to QDRIIC_BWS_n[0]
set_location_assignment PIN_AD35 -to QDRIIC_BWS_n[1]
set_location_assignment PIN_AD36 -to QDRIIC_CQ_p
set_location_assignment PIN_AC36 -to QDRIIC_CQ_n
set_location_assignment PIN_T36 -to QDRIIC_Q[0]
set_location_assignment PIN_R36 -to QDRIIC_Q[1]
set_location_assignment PIN_P35 -to QDRIIC_Q[2]
set_location_assignment PIN_N36 -to QDRIIC_Q[3]
set_location_assignment PIN_N37 -to QDRIIC_Q[4]
set_location_assignment PIN_M38 -to QDRIIC_Q[5]
set_location_assignment PIN_M39 -to QDRIIC_Q[6]
set_location_assignment PIN_N38 -to QDRIIC_Q[7]
set_location_assignment PIN_P36 -to QDRIIC_Q[8]
set_location_assignment PIN_Y36 -to QDRIIC_Q[9]
set_location_assignment PIN_M37 -to QDRIIC_Q[10]
set_location_assignment PIN_M35 -to QDRIIC_Q[11]
set_location_assignment PIN_T34 -to QDRIIC_Q[12]
set_location_assignment PIN_N35 -to QDRIIC_Q[13]
set_location_assignment PIN_T35 -to QDRIIC_Q[14]
set_location_assignment PIN_U35 -to QDRIIC_Q[15]
set_location_assignment PIN_V35 -to QDRIIC_Q[16]
set_location_assignment PIN_W35 -to QDRIIC_Q[17]
set_location_assignment PIN_U34 -to QDRIIC_QVLD
set_location_assignment PIN_F26 -to QDRIIC_WPS_n
set_location_assignment PIN_E26 -to QDRIIC_RPS_n
set_location_assignment PIN_D24 -to QDRIIC_DOFF_n
set_location_assignment PIN_B25 -to QDRIIC_ODT

#============================================================
# QDRIID
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QDRIID_REFCLK_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[18]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[19]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[20]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_A[21]
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIID_K_p
set_instance_assignment -name IO_STANDARD "DIFFERENTIAL 1.8-V HSTL CLASS I" -to QDRIID_K_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_D[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_BWS_n[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_BWS_n[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_CQ_p
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_CQ_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[0]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[1]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[2]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[3]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[4]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[5]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[6]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[7]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[8]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[9]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[10]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[11]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[12]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[13]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[14]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[15]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[16]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_Q[17]
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_QVLD
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_WPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_RPS_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_DOFF_n
set_instance_assignment -name IO_STANDARD "1.8-V HSTL CLASS I" -to QDRIID_ODT
set_location_assignment PIN_M34 -to QDRIID_REFCLK_p
set_location_assignment PIN_Y32 -to QDRIID_A[0]
set_location_assignment PIN_W33 -to QDRIID_A[1]
set_location_assignment PIN_P34 -to QDRIID_A[2]
set_location_assignment PIN_P33 -to QDRIID_A[3]
set_location_assignment PIN_L32 -to QDRIID_A[4]
set_location_assignment PIN_K32 -to QDRIID_A[5]
set_location_assignment PIN_R34 -to QDRIID_A[6]
set_location_assignment PIN_R33 -to QDRIID_A[7]
set_location_assignment PIN_T32 -to QDRIID_A[8]
set_location_assignment PIN_R32 -to QDRIID_A[9]
set_location_assignment PIN_N32 -to QDRIID_A[10]
set_location_assignment PIN_M32 -to QDRIID_A[11]
set_location_assignment PIN_T31 -to QDRIID_A[12]
set_location_assignment PIN_R31 -to QDRIID_A[13]
set_location_assignment PIN_K38 -to QDRIID_A[14]
set_location_assignment PIN_L37 -to QDRIID_A[15]
set_location_assignment PIN_K36 -to QDRIID_A[16]
set_location_assignment PIN_N33 -to QDRIID_A[17]
set_location_assignment PIN_M33 -to QDRIID_A[18]
set_location_assignment PIN_L39 -to QDRIID_A[19]
set_location_assignment PIN_K39 -to QDRIID_A[20]
set_location_assignment PIN_L35 -to QDRIID_A[21]
set_location_assignment PIN_F32 -to QDRIID_K_p
set_location_assignment PIN_E32 -to QDRIID_K_n
set_location_assignment PIN_E36 -to QDRIID_D[0]
set_location_assignment PIN_F34 -to QDRIID_D[1]
set_location_assignment PIN_F39 -to QDRIID_D[2]
set_location_assignment PIN_F36 -to QDRIID_D[3]
set_location_assignment PIN_D33 -to QDRIID_D[4]
set_location_assignment PIN_F31 -to QDRIID_D[5]
set_location_assignment PIN_G30 -to QDRIID_D[6]
set_location_assignment PIN_H30 -to QDRIID_D[7]
set_location_assignment PIN_G29 -to QDRIID_D[8]
set_location_assignment PIN_E33 -to QDRIID_D[9]
set_location_assignment PIN_G39 -to QDRIID_D[10]
set_location_assignment PIN_E37 -to QDRIID_D[11]
set_location_assignment PIN_F37 -to QDRIID_D[12]
set_location_assignment PIN_E34 -to QDRIID_D[13]
set_location_assignment PIN_D36 -to QDRIID_D[14]
set_location_assignment PIN_C37 -to QDRIID_D[15]
set_location_assignment PIN_D35 -to QDRIID_D[16]
set_location_assignment PIN_D34 -to QDRIID_D[17]
set_location_assignment PIN_F30 -to QDRIID_BWS_n[0]
set_location_assignment PIN_E31 -to QDRIID_BWS_n[1]
set_location_assignment PIN_G35 -to QDRIID_CQ_p
set_location_assignment PIN_F35 -to QDRIID_CQ_n
set_location_assignment PIN_L29 -to QDRIID_Q[0]
set_location_assignment PIN_N30 -to QDRIID_Q[1]
set_location_assignment PIN_K29 -to QDRIID_Q[2]
set_location_assignment PIN_J29 -to QDRIID_Q[3]
set_location_assignment PIN_M30 -to QDRIID_Q[4]
set_location_assignment PIN_J30 -to QDRIID_Q[5]
set_location_assignment PIN_N31 -to QDRIID_Q[6]
set_location_assignment PIN_P31 -to QDRIID_Q[7]
set_location_assignment PIN_H33 -to QDRIID_Q[8]
set_location_assignment PIN_G34 -to QDRIID_Q[9]
set_location_assignment PIN_G33 -to QDRIID_Q[10]
set_location_assignment PIN_L31 -to QDRIID_Q[11]
set_location_assignment PIN_J31 -to QDRIID_Q[12]
set_location_assignment PIN_K31 -to QDRIID_Q[13]
set_location_assignment PIN_L30 -to QDRIID_Q[14]
set_location_assignment PIN_M29 -to QDRIID_Q[15]
set_location_assignment PIN_M28 -to QDRIID_Q[16]
set_location_assignment PIN_N28 -to QDRIID_Q[17]
set_location_assignment PIN_P28 -to QDRIID_QVLD
set_location_assignment PIN_V32 -to QDRIID_WPS_n
set_location_assignment PIN_V33 -to QDRIID_RPS_n
set_location_assignment PIN_W31 -to QDRIID_DOFF_n
set_location_assignment PIN_Y33 -to QDRIID_ODT

#============================================================
# RZQ
#============================================================
set_instance_assignment -name IO_STANDARD "1.2 V" -to RZQ_DDR4_A
set_instance_assignment -name IO_STANDARD "1.2 V" -to RZQ_DDR4_B
set_instance_assignment -name IO_STANDARD "1.8 V" -to RZQ_QDRII_A
set_instance_assignment -name IO_STANDARD "1.8 V" -to RZQ_QDRII_B
set_instance_assignment -name IO_STANDARD "1.8 V" -to RZQ_QDRII_C
set_instance_assignment -name IO_STANDARD "1.8 V" -to RZQ_QDRII_D
set_location_assignment PIN_AU28 -to RZQ_DDR4_A
set_location_assignment PIN_BB15 -to RZQ_DDR4_B
set_location_assignment PIN_L11 -to RZQ_QDRII_A
set_location_assignment PIN_F17 -to RZQ_QDRII_B
set_location_assignment PIN_L24 -to RZQ_QDRII_C
set_location_assignment PIN_K37 -to RZQ_QDRII_D

#============================================================
# SI5340A
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340A_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340A_I2C_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340A_INTR
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340A_OE_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340A_RST_n
set_location_assignment PIN_AF11 -to SI5340A_I2C_SCL
set_location_assignment PIN_AE11 -to SI5340A_I2C_SDA
set_location_assignment PIN_AM6 -to SI5340A_INTR
set_location_assignment PIN_AJ10 -to SI5340A_OE_n
set_location_assignment PIN_AN6 -to SI5340A_RST_n

#============================================================
# SI5340B
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340B_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340B_I2C_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340B_INTR
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340B_OE_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to SI5340B_RST_n
set_location_assignment PIN_G37 -to SI5340B_I2C_SCL
set_location_assignment PIN_H31 -to SI5340B_I2C_SDA
set_location_assignment PIN_G32 -to SI5340B_INTR
set_location_assignment PIN_BD24 -to SI5340B_OE_n
set_location_assignment PIN_G38 -to SI5340B_RST_n

#============================================================
# TPS40428
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to TPS40428_CLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to TPS40428_DATA
set_instance_assignment -name IO_STANDARD "1.8 V" -to TPS40428_ALERT
set_location_assignment PIN_A24 -to TPS40428_CLK
set_location_assignment PIN_A25 -to TPS40428_DATA
set_location_assignment PIN_V36 -to TPS40428_ALERT

#============================================================
# RS422
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to RS422_DOUT
set_instance_assignment -name IO_STANDARD "1.8 V" -to RS422_DIN
set_instance_assignment -name IO_STANDARD "1.8 V" -to RS422_DE
set_instance_assignment -name IO_STANDARD "1.8 V" -to RS422_RE_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to RJ45_LED_L
set_instance_assignment -name IO_STANDARD "1.8 V" -to RJ45_LED_R
set_location_assignment PIN_W14 -to RS422_DOUT
set_location_assignment PIN_AM9 -to RS422_DIN
set_location_assignment PIN_AN8 -to RS422_DE
set_location_assignment PIN_AD9 -to RS422_RE_n
set_location_assignment PIN_AJ11 -to RJ45_LED_L
set_location_assignment PIN_Y14 -to RJ45_LED_R

#============================================================
# Temperature
#============================================================
set_instance_assignment -name IO_STANDARD "1.2 V" -to TEMP_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.2 V" -to TEMP_I2C_SDA
set_instance_assignment -name IO_STANDARD "1.2 V" -to TEMP_INT_n
set_instance_assignment -name IO_STANDARD "1.2 V" -to TEMP_OVERT_n
set_location_assignment PIN_AW11 -to TEMP_I2C_SCL
set_location_assignment PIN_AY12 -to TEMP_I2C_SDA
set_location_assignment PIN_AU12 -to TEMP_INT_n
set_location_assignment PIN_AT14 -to TEMP_OVERT_n

#============================================================
# POWER Monitor
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to POWER_MONITOR_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to POWER_MONITOR_I2C_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to POWER_MONITOR_ALERT
set_location_assignment PIN_AT26 -to POWER_MONITOR_I2C_SCL
set_location_assignment PIN_AP25 -to POWER_MONITOR_I2C_SDA
set_location_assignment PIN_BD23 -to POWER_MONITOR_ALERT

#============================================================
# SMA
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to SMA_CLKIN
set_instance_assignment -name IO_STANDARD "1.8 V" -to SMA_CLKOUT
set_location_assignment PIN_AC32 -to SMA_CLKIN
set_location_assignment PIN_AA36 -to SMA_CLKOUT

#============================================================
# PCIE
#============================================================
set_instance_assignment -name IO_STANDARD "1.8 V" -to PCIE_SMBCLK
set_instance_assignment -name IO_STANDARD "1.8 V" -to PCIE_SMBDAT
set_instance_assignment -name IO_STANDARD "LVDS" -to OB_PCIE_REFCLK_p
set_instance_assignment -name IO_STANDARD "HCSL" -to PCIE_REFCLK_p
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[3]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[4]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[5]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[6]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_TX_p[7]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[3]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[4]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[5]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[6]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to PCIE_RX_p[7]
set_instance_assignment -name IO_STANDARD "1.8 V" -to PCIE_PERST_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to PCIE_WAKE_n
set_location_assignment PIN_AM25 -to PCIE_SMBCLK
set_location_assignment PIN_AR24 -to PCIE_SMBDAT
set_location_assignment PIN_AK40 -to OB_PCIE_REFCLK_p
set_location_assignment PIN_AH40 -to PCIE_REFCLK_p
set_location_assignment PIN_AV44 -to PCIE_TX_p[0]
set_location_assignment PIN_AT44 -to PCIE_TX_p[1]
set_location_assignment PIN_AP44 -to PCIE_TX_p[2]
set_location_assignment PIN_AM44 -to PCIE_TX_p[3]
set_location_assignment PIN_AK44 -to PCIE_TX_p[4]
set_location_assignment PIN_AH44 -to PCIE_TX_p[5]
set_location_assignment PIN_AF44 -to PCIE_TX_p[6]
set_location_assignment PIN_AD44 -to PCIE_TX_p[7]
set_location_assignment PIN_AU42 -to PCIE_RX_p[0]
set_location_assignment PIN_AR42 -to PCIE_RX_p[1]
set_location_assignment PIN_AN42 -to PCIE_RX_p[2]
set_location_assignment PIN_AL42 -to PCIE_RX_p[3]
set_location_assignment PIN_AJ42 -to PCIE_RX_p[4]
set_location_assignment PIN_AG42 -to PCIE_RX_p[5]
set_location_assignment PIN_AE42 -to PCIE_RX_p[6]
set_location_assignment PIN_AC42 -to PCIE_RX_p[7]
set_location_assignment PIN_AT25 -to PCIE_PERST_n
set_location_assignment PIN_AN26 -to PCIE_WAKE_n

#============================================================
# QSFPA
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QSFPA_REFCLK_p
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_TX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_TX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_TX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_TX_p[3]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_RX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_RX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_RX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPA_RX_p[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_INTERRUPT_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_LP_MODE
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_MOD_PRS_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_MOD_SEL_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_RST_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPA_SDA
set_location_assignment PIN_AH5 -to QSFPA_REFCLK_p
set_location_assignment PIN_BD5 -to QSFPA_TX_p[0]
set_location_assignment PIN_BC3 -to QSFPA_TX_p[1]
set_location_assignment PIN_BB1 -to QSFPA_TX_p[2]
set_location_assignment PIN_AY1 -to QSFPA_TX_p[3]
set_location_assignment PIN_BB5 -to QSFPA_RX_p[0]
set_location_assignment PIN_AY5 -to QSFPA_RX_p[1]
set_location_assignment PIN_BA3 -to QSFPA_RX_p[2]
set_location_assignment PIN_AW3 -to QSFPA_RX_p[3]
set_location_assignment PIN_AB9 -to QSFPA_INTERRUPT_n
set_location_assignment PIN_AB10 -to QSFPA_LP_MODE
set_location_assignment PIN_AG10 -to QSFPA_MOD_PRS_n
set_location_assignment PIN_AC10 -to QSFPA_MOD_SEL_n
set_location_assignment PIN_AA9 -to QSFPA_RST_n
set_location_assignment PIN_AA10 -to QSFPA_SCL
set_location_assignment PIN_Y9 -to QSFPA_SDA

#============================================================
# QSFPB
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QSFPB_REFCLK_p
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_TX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_TX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_TX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_TX_p[3]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_RX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_RX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_RX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPB_RX_p[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_INTERRUPT_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_LP_MODE
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_MOD_PRS_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_MOD_SEL_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_RST_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPB_SDA
set_location_assignment PIN_AD5 -to QSFPB_REFCLK_p
set_location_assignment PIN_AP1 -to QSFPB_TX_p[0]
set_location_assignment PIN_AM1 -to QSFPB_TX_p[1]
set_location_assignment PIN_AK1 -to QSFPB_TX_p[2]
set_location_assignment PIN_AH1 -to QSFPB_TX_p[3]
set_location_assignment PIN_AN3 -to QSFPB_RX_p[0]
set_location_assignment PIN_AL3 -to QSFPB_RX_p[1]
set_location_assignment PIN_AJ3 -to QSFPB_RX_p[2]
set_location_assignment PIN_AG3 -to QSFPB_RX_p[3]
set_location_assignment PIN_AK9 -to QSFPB_INTERRUPT_n
set_location_assignment PIN_AM10 -to QSFPB_LP_MODE
set_location_assignment PIN_AL10 -to QSFPB_MOD_PRS_n
set_location_assignment PIN_AP6 -to QSFPB_MOD_SEL_n
set_location_assignment PIN_AR6 -to QSFPB_RST_n
set_location_assignment PIN_AM7 -to QSFPB_SCL
set_location_assignment PIN_AM8 -to QSFPB_SDA

#============================================================
# QSFPC
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QSFPC_REFCLK_p
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_TX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_TX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_TX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_TX_p[3]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_RX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_RX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_RX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPC_RX_p[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_INTERRUPT_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_LP_MODE
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_MOD_PRS_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_MOD_SEL_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_RST_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPC_SDA
set_location_assignment PIN_Y5 -to QSFPC_REFCLK_p
set_location_assignment PIN_AB1 -to QSFPC_TX_p[0]
set_location_assignment PIN_Y1 -to QSFPC_TX_p[1]
set_location_assignment PIN_V1 -to QSFPC_TX_p[2]
set_location_assignment PIN_T1 -to QSFPC_TX_p[3]
set_location_assignment PIN_AA3 -to QSFPC_RX_p[0]
set_location_assignment PIN_W3 -to QSFPC_RX_p[1]
set_location_assignment PIN_U3 -to QSFPC_RX_p[2]
set_location_assignment PIN_R3 -to QSFPC_RX_p[3]
set_location_assignment PIN_AD11 -to QSFPC_INTERRUPT_n
set_location_assignment PIN_AH10 -to QSFPC_LP_MODE
set_location_assignment PIN_AD10 -to QSFPC_MOD_PRS_n
set_location_assignment PIN_AL9 -to QSFPC_MOD_SEL_n
set_location_assignment PIN_AJ9 -to QSFPC_RST_n
set_location_assignment PIN_AL11 -to QSFPC_SCL
set_location_assignment PIN_AK11 -to QSFPC_SDA

#============================================================
# QSFPD
#============================================================
set_instance_assignment -name IO_STANDARD "LVDS" -to QSFPD_REFCLK_p
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_TX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_TX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_TX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_TX_p[3]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_RX_p[0]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_RX_p[1]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_RX_p[2]
set_instance_assignment -name IO_STANDARD "HSSI DIFFERENTIAL I/O" -to QSFPD_RX_p[3]
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_INTERRUPT_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_LP_MODE
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_MOD_PRS_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_MOD_SEL_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_RST_n
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to QSFPD_SDA
set_location_assignment PIN_T5 -to QSFPD_REFCLK_p
set_location_assignment PIN_K1 -to QSFPD_TX_p[0]
set_location_assignment PIN_H1 -to QSFPD_TX_p[1]
set_location_assignment PIN_F1 -to QSFPD_TX_p[2]
set_location_assignment PIN_D1 -to QSFPD_TX_p[3]
set_location_assignment PIN_J3 -to QSFPD_RX_p[0]
set_location_assignment PIN_G3 -to QSFPD_RX_p[1]
set_location_assignment PIN_E3 -to QSFPD_RX_p[2]
set_location_assignment PIN_D5 -to QSFPD_RX_p[3]
set_location_assignment PIN_W13 -to QSFPD_INTERRUPT_n
set_location_assignment PIN_AA12 -to QSFPD_LP_MODE
set_location_assignment PIN_Y12 -to QSFPD_MOD_PRS_n
set_location_assignment PIN_AA11 -to QSFPD_MOD_SEL_n
set_location_assignment PIN_Y11 -to QSFPD_RST_n
set_location_assignment PIN_W9 -to QSFPD_SCL
set_location_assignment PIN_W10 -to QSFPD_SDA
