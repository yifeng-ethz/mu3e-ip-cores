#puts "Set PCIe Links[7..0]"
#############################A10_PCIE_RX/TX_P_0 to A10_PCIE_RX/TX_P_7############################
#source $LHCb_git/readout40-firmware/lli-pcie40v2/scripts/set_PCIe_Assignments_bus1.tcl
#puts "Set PCIe Links[15..8]"
#############################A10_PCIE_RX/TX_P_8 to A10_PCIE_RX/TX_P_15############################
#source $LHCb_git/readout40-firmware/lli-pcie40v2/scripts/set_PCIe_Assignments_bus2.tcl

puts "Set I2C busses"
############################# I2C BUS #############################################################
#          assignment i2c for minipod (A10_MP)
#                     i2c for PLL PCie PLLSI53154
#                     i2c for PLL TFC (A10_5344_SMB)
#                     i2c for PLL Jitter cleaner (A10_5345_1 adnd A10_5345_2)
#                     i2c for TSENSE (MMC_A10_TSENSE_SMB)
#                     i2c for SFP1 and 2 (A10_SFP1_SMB and A10_SFP2_SMB)
#                     i2c for CPCIE/IPMI (A10_CPCIE_SMB)
#                     i2c for Power Mezzanine (A10_MEZZ_I2C)
#                     i2c for Serial eeprom (SERIAL_EEPROM)
# location assignment
set_location_assignment PIN_A17  -to A10_MP_SCL
set_location_assignment PIN_B16  -to A10_MP_SDA
set_location_assignment PIN_B15  -to A10_MP_INT
set_location_assignment PIN_AY34 -to A10_SI53154_SMB_SCL
set_location_assignment PIN_BD24 -to A10_SI53154_SMB_SDA
set_location_assignment PIN_BA17 -to A10_SI5344_SMB_SCL
set_location_assignment PIN_BB21 -to A10_SI5344_SMB_SDA
set_location_assignment PIN_BB25 -to A10_SI5345_1_SMB_SCL
set_location_assignment PIN_BB23 -to A10_SI5345_1_SMB_SDA
set_location_assignment PIN_D34  -to A10_SI5345_2_SMB_SCL
set_location_assignment PIN_C35  -to A10_SI5345_2_SMB_SDA
set_location_assignment PIN_BA35 -to MMC_A10_TSENSE_SMB_SCL
set_location_assignment PIN_BD29 -to MMC_A10_TSENSE_SMB_SDA
set_location_assignment PIN_AR36 -to A10_SFP1_SMB_SCL
set_location_assignment PIN_AT34 -to A10_SFP1_SMB_SDA
set_location_assignment PIN_AR37 -to A10_SFP2_SMB_SCL
set_location_assignment PIN_AU30 -to A10_SFP2_SMB_SDA
set_location_assignment PIN_AV18 -to A10_CPCIE_SMB_SCL
set_location_assignment PIN_AV19 -to A10_CPCIE_SMB_SDA
set_location_assignment PIN_K24  -to A10_MEZZ_I2C_SCL
set_location_assignment PIN_L24  -to A10_MEZZ_I2C_SDA
set_location_assignment PIN_G33  -to SERIAL_EEPROM_SCL
set_location_assignment PIN_F32  -to SERIAL_EEPROM_SDA
set_location_assignment PIN_F33  -to SERIAL_EEPROM_WRITE_PROTECT
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_MP_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_MP_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_MP_INT
set_instance_assignment -name IO_STANDARD "1.8 V" -to LT1_EN
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI53154_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI53154_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5344_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5344_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_1_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_1_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_2_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_2_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to MMC_A10_TSENSE_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to MMC_A10_TSENSE_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP1_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP1_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP2_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP2_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_CPCIE_SMB_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_CPCIE_SMB_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_MEZZ_I2C_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_MEZZ_I2C_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to SERIAL_EEPROM_SCL
set_instance_assignment -name IO_STANDARD "1.8 V" -to SERIAL_EEPROM_SDA
set_instance_assignment -name IO_STANDARD "1.8 V" -to SERIAL_EEPROM_WRITE_PROTECT
# Logical assignment
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_MP_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_MP_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI53154_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI53154_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI5344_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI5344_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI5345_1_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI5345_1_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI5345_2_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SI5345_2_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to MMC_A10_TSENSE_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to MMC_A10_TSENSE_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SFP1_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SFP1_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SFP2_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_SFP2_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_CPCIE_SMB_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_CPCIE_SMB_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_MEZZ_I2C_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to A10_MEZZ_I2C_SDA
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SERIAL_EEPROM_SCL
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SERIAL_EEPROM_SDA


puts "Set Level translators control"
#############################Level translators #########################################################
# assignment
set_location_assignment PIN_B17 -to LT1_EN -comment "level translator enable for Minipods I2C"
set_location_assignment PIN_A14 -to LT2_EN -comment "level translator enable for Minipods resets"
set_location_assignment PIN_A20 -to LT3_EN -comment "level translator enable for Minipods resets"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to LT1_EN
set_instance_assignment -name IO_STANDARD "1.8 V" -to LT2_EN
set_instance_assignment -name IO_STANDARD "1.8 V" -to LT3_EN


puts "Set LTC2418"
############################# SPI LTC2418 #########################################################
# assignment SPI bus LTC2418
# location assignment
set_location_assignment PIN_BC24 -to A10_M5FL_L2418_SPI_SDI
set_location_assignment PIN_BD22 -to A10_M5FL_L2418_SPI_SDO
set_location_assignment PIN_BD26 -to A10_M5FL_L2418_SPI_SCK
set_location_assignment PIN_AY35 -to A10_M5FL_L2418_SPI_CS0_N
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2418_SPI_SDI
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2418_SPI_SDO
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2418_SPI_SCK
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2418_SPI_CS0_N


puts "Set LTC2498"
############################# SPI LTC2498 #########################################################
# assignment SPI bus LTC2498
# location assignment
set_location_assignment PIN_B33 -to A10_M5FL_L2498_SPI_CS0_N
set_location_assignment PIN_A33 -to A10_M5FL_L2498_SPI_SCK
set_location_assignment PIN_B32 -to A10_M5FL_L2498_SPI_SDI
set_location_assignment PIN_A32 -to A10_M5FL_L2498_SPI_SDO

# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2498_SPI_CS0_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2498_SPI_SCK
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2498_SPI_SDI
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_L2498_SPI_SDO

puts "Set M1619"
############################# M1619 temperature sensor #########################################################
# location assignment
set_location_assignment PIN_AV34 -to A10_M5FL_M1619_ALERT_N
set_location_assignment PIN_AV35 -to A10_M5FL_M1619_OVTEMP_N
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_M1619_ALERT_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_M5FL_M1619_OVTEMP_N


puts "Set SI5344 and 5345 PLLs"
############################# SI5344 and 5345 PLLs #########################################################
# location 5344 PLL
set_location_assignment PIN_AP12 -to A10_SI53344_FANOUT_CLK_P -comment "External clock through fanou"
set_location_assignment PIN_C11  -to A10_SI5344_240_P -comment "240 MHz from TFC PLL"
set_location_assignment PIN_BC20 -to A10_SI5344_INTR_N -comment "TFC PLL interrupt"
set_location_assignment PIN_BB20 -to A10_SI5344_LOL_N -comment "TFC PLL Loss of lock"
set_location_assignment PIN_BC21 -to A10_SI5344_LOS_XAXB_N -comment "TFC PLL input loss"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD LVDS -to A10_SI53344_FANOUT_CLK_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SI53344_FANOUT_CLK_P
set_instance_assignment -name IO_STANDARD LVDS -to A10_SI5344_240_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SI5344_240_P
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5344_INTR_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5344_LOL_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5344_LOS_XAXB_N
# location 5345 PLLs 1 and 2
set_location_assignment PIN_AY24 -to A10_SI5345_1_JITTER_CLOCK_P -comment "Clock sent to jitter fitering PLL # 1"
set_location_assignment PIN_BA25 -to A10_SI5345_1_JITTER_INTR_N -comment "Jitter filtering PLL # 1 interrupt"
set_location_assignment PIN_AU23 -to A10_SI5345_1_JITTER_LOL_N -comment "Jitter filtering PLL # 1 loss of lock"
set_location_assignment PIN_AV24 -to A10_SI5345_2_CLK_240_P -comment "240 MHz from jitter filtering PLL # 2"
set_location_assignment PIN_G35  -to A10_SI5345_2_JITTER_CLOCK_P -comment "Clock sent to jitter fitering PLL # 2"
set_location_assignment PIN_E35  -to A10_SI5345_2_JITTER_INTR_N -comment "Jitter filtering PLL # 2 interrupt"
set_location_assignment PIN_E34  -to A10_SI5345_2_JITTER_LOL_N -comment "Jitter filtering PLL # 2 loss of lock"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD LVDS -to A10_SI5345_1_JITTER_CLOCK_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SI5345_1_JITTER_CLOCK_P
set_instance_assignment -name IO_STANDARD LVDS -to A10_SI5345_2_CLK_240_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SI5345_2_CLK_240_P
set_instance_assignment -name IO_STANDARD LVDS -to A10_SI5345_2_JITTER_CLOCK_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SI5345_2_JITTER_CLOCK_P
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_1_JITTER_INTR_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_1_JITTER_LOL_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_2_JITTER_INTR_N
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SI5345_2_JITTER_LOL_N


puts "Set SI53340 fanout"
############################# SI53340 #########################################################
# location 53340 2 clock fanout
set_location_assignment PIN_AY20 -to A10_SI53340_2_CLK_40_P -comment "40 MHz oscillator clock through fanout"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD LVDS -to A10_SI53340_2_CLK_40_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SI53340_2_CLK_40_P


puts "Set SMA Clk"
############################# SMA Clk #########################################################
# location SMA clk
set_location_assignment PIN_AT10 -to A10_CUSTOM_CLK_P -comment "External clock coming from SMA through SI5344 fanout"
set_location_assignment PIN_AV15 -to A10_SMA_CLK_IN_P -comment "SMA clock input through TTL \u2192 LVDS driver"
set_location_assignment PIN_AN33 -to A10_SMA_CLK_OUT_P -comment "SMA Clock output through LVDS \u2192 TTL driver"
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD LVDS -to A10_CUSTOM_CLK_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_CUSTOM_CLK_P
set_instance_assignment -name IO_STANDARD LVDS -to A10_SMA_CLK_IN_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SMA_CLK_IN_P
set_instance_assignment -name IO_STANDARD LVDS -to A10_SMA_CLK_OUT_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to A10_SMA_CLK_OUT_P


puts "Set Oscillator clocks"
############################# OSCILLATORS CLOCKS #####################################################
set_location_assignment PIN_AU33 -to CLK_A10_100MHZ_P
set_location_assignment PIN_BD32 -to TRANSCEIVER_CALIBRATION_CLK
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD LVDS -to CLK_A10_100MHZ_P
set_instance_assignment -name INPUT_TERMINATION "Differential" -to CLK_A10_100MHZ_P


puts "Set XCVR RefClocks"
############################# REF CLOCKS ##########################################################
# location assignment
set_location_assignment PIN_AN37 -to A10_REFCLK_TFC_P -comment "Bank : 1C"
set_location_assignment PIN_AL37 -to A10_REFCLK_2_TFC_P -comment "Bank : 1C"
set_location_assignment PIN_AY40 -to A10_REFCLK_TFC_CMU_P -comment "Bank : 1C"
set_location_assignment PIN_AL8  -to A10_REFCLK_10G_P_0 -comment "Bank : 4C"
set_location_assignment PIN_AG8  -to A10_REFCLK_10G_P_1 -comment "Bank : 4D"
set_location_assignment PIN_AC8  -to A10_REFCLK_10G_P_2 -comment "Bank : 4E"
set_location_assignment PIN_W8   -to A10_REFCLK_10G_P_3 -comment "Bank : 4F"
set_location_assignment PIN_R8   -to A10_REFCLK_10G_P_4 -comment "Bank : 4G"
set_location_assignment PIN_L8   -to A10_REFCLK_10G_P_5 -comment "Bank : 4H"
set_location_assignment PIN_R37  -to A10_REFCLK_10G_P_6 -comment "Bank : 1G"
set_location_assignment PIN_L37  -to A10_REFCLK_10G_P_7 -comment "Bank : 1H"
set_location_assignment PIN_AN8  -to A10_REFCLK_GBT_P_0 -comment "Bank : 4C"
set_location_assignment PIN_AJ8  -to A10_REFCLK_GBT_P_1 -comment "Bank : 4D"
set_location_assignment PIN_AE8  -to A10_REFCLK_GBT_P_2 -comment "Bank : 4E"
set_location_assignment PIN_AA8  -to A10_REFCLK_GBT_P_3 -comment "Bank : 4F"
set_location_assignment PIN_U8   -to A10_REFCLK_GBT_P_4 -comment "Bank : 4G"
set_location_assignment PIN_N8   -to A10_REFCLK_GBT_P_5 -comment "Bank : 4H"
set_location_assignment PIN_U37  -to A10_REFCLK_GBT_P_6 -comment "Bank : 1G"
set_location_assignment PIN_N37  -to A10_REFCLK_GBT_P_7 -comment "Bank : 1H"
# IO_STANDARD assignment
#FH add constraints
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_TFC_P
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_2_TFC_P
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_TFC_CMU_P
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_0
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_1
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_2
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_3
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_4
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_5
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_6
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_10G_P_7
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_0
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_1
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_2
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_3
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_4
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_5
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_6
set_instance_assignment -name XCVR_A10_REFCLK_TERM_TRISTATE "TRISTATE_OFF" -to A10_REFCLK_GBT_P_7


puts "Set front plate LEDs"
############################# COLOR LEDS ####################################################
set_location_assignment PIN_AW13 -to A10_LED_3C_1[0]
set_location_assignment PIN_BA13 -to A10_LED_3C_1[1]
set_location_assignment PIN_BC13 -to A10_LED_3C_1[2]
set_location_assignment PIN_AV14 -to A10_LED_3C_2[0]
set_location_assignment PIN_AN14 -to A10_LED_3C_2[1]
set_location_assignment PIN_AN15 -to A10_LED_3C_2[2]
set_location_assignment PIN_BB11 -to A10_LED_3C_3[0]
set_location_assignment PIN_BB12 -to A10_LED_3C_3[1]
set_location_assignment PIN_AY12 -to A10_LED_3C_3[2]
set_location_assignment PIN_BA14 -to A10_LED_3C_4[0]
set_location_assignment PIN_BB13 -to A10_LED_3C_4[1]
set_location_assignment PIN_AP13 -to A10_LED_3C_4[2]


puts "Set User LEDs"
############################# USER LEDS ####################################################
set_location_assignment PIN_AV11 -to A10_LED[0]
set_location_assignment PIN_AV13 -to A10_LED[1]
set_location_assignment PIN_AW11 -to A10_LED[2]
set_location_assignment PIN_AY10 -to A10_LED[3]
set_location_assignment PIN_BA10 -to A10_LED[4]
set_location_assignment PIN_BB10 -to A10_LED[5]
set_location_assignment PIN_AY11 -to A10_LED[6]
set_location_assignment PIN_AW12 -to A10_LED[7]


puts "Set input switch"
############################# USER SWITCHES ######################################################
set_location_assignment PIN_AV10 -to A10_SW[0]
set_location_assignment PIN_AU12 -to A10_SW[1]
set_location_assignment PIN_AU11 -to A10_SW[2]
set_location_assignment PIN_AU10 -to A10_SW[3]
set_location_assignment PIN_AT9  -to A10_SW[4]
set_location_assignment PIN_AR10 -to A10_SW[5]
set_location_assignment PIN_AR9  -to A10_SW[6]
set_location_assignment PIN_AP11 -to A10_SW[7]


puts "Set USB debug interface"
############################# USB debug interface ######################################################
set_location_assignment PIN_R31 -to A10_M10_USB_ADDR[0]
set_location_assignment PIN_R30 -to A10_M10_USB_ADDR[1]
set_location_assignment PIN_H31 -to A10_M10_USB_CLK
set_location_assignment PIN_T33 -to A10_M10_USB_DATA[0]
set_location_assignment PIN_U33 -to A10_M10_USB_DATA[1]
set_location_assignment PIN_P33 -to A10_M10_USB_DATA[2]
set_location_assignment PIN_N33 -to A10_M10_USB_DATA[3]
set_location_assignment PIN_P34 -to A10_M10_USB_DATA[4]
set_location_assignment PIN_R34 -to A10_M10_USB_DATA[5]
set_location_assignment PIN_T35 -to A10_M10_USB_DATA[6]
set_location_assignment PIN_T34 -to A10_M10_USB_DATA[7]
set_location_assignment PIN_L34 -to A10_M10_USB_EMPTY
set_location_assignment PIN_K34 -to A10_M10_USB_FULL
set_location_assignment PIN_L32 -to A10_M10_USB_OE_N
set_location_assignment PIN_N34 -to A10_M10_USB_RD_N
set_location_assignment PIN_U32 -to A10_M10_USB_RESET_N
set_location_assignment PIN_M32 -to A10_M10_USB_SCL
set_location_assignment PIN_T32 -to A10_M10_USB_SDA
set_location_assignment PIN_M35 -to A10_M10_USB_WR_N
set_location_assignment PIN_J32 -to A10_PROC_RST_N


puts "Set Minipods resets"
############################# Minipods reset ######################################################
set_location_assignment PIN_B13 -to A10_U2_RESETL
set_location_assignment PIN_A13 -to A10_U3_RESETL
set_location_assignment PIN_B12 -to A10_U4_RESETL
set_location_assignment PIN_A12 -to A10_U5_RESETL
set_location_assignment PIN_B20 -to A10_U6_RESETL
set_location_assignment PIN_A19 -to A10_U7_RESETL
set_location_assignment PIN_B18 -to A10_U8_RESETL
set_location_assignment PIN_A18 -to A10_U9_RESETL


puts "Set Front plate connector TFC interface"
############################# Front plate connector TFC interface ######################################################
# location assignment
set_location_assignment PIN_BC14 -to TFC_CHANNEL_A_IN_P
set_location_assignment PIN_BD17 -to TFC_CHANNEL_A_OUT_P
set_location_assignment PIN_BB15 -to TFC_CHANNEL_B_IN_P
set_location_assignment PIN_BC16 -to TFC_CHANNEL_B_OUT_P
set_location_assignment PIN_BC19 -to TFC_CLK_OUT_P
set_location_assignment PIN_BD13 -to TFC_ORBIT_IN_P
set_location_assignment PIN_BC18 -to TFC_ORBIT_OUT_P
# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD LVDS -to TFC_CHANNEL_A_IN_P
set_instance_assignment -name IO_STANDARD LVDS -to TFC_CHANNEL_A_OUT_P
set_instance_assignment -name IO_STANDARD LVDS -to TFC_CHANNEL_B_IN_P
set_instance_assignment -name IO_STANDARD LVDS -to TFC_CHANNEL_B_OUT_P
set_instance_assignment -name IO_STANDARD LVDS -to TFC_CLK_OUT_P
set_instance_assignment -name IO_STANDARD LVDS -to TFC_ORBIT_IN_P
set_instance_assignment -name IO_STANDARD LVDS -to TFC_ORBIT_OUT_P


puts "Set Power mezzanine GPIOs"
############################# Power Mezzanine GPIO ######################################################
# location assignment
#FH modif 08/04/19
puts "Set Power Mezz interfaces"
set_location_assignment PIN_L27 -to A10_MMC_POWER_OFF_RQST_N
set_location_assignment PIN_L28 -to A10_MMC_SPARE
set_location_assignment PIN_L23 -to A10_SI53340_2_CLK_SEL
set_location_assignment PIN_M23 -to A10_GP_SPARE

puts "Set SFP+ interfaces"
############################# SFP+ interface ######################################################
# location assignment
set_location_assignment PIN_AM35 -to A10_SFP1_RS0
set_location_assignment PIN_AU36 -to A10_SFP1_RS1
set_location_assignment PIN_AR35 -to A10_SFP1_RX_LOSS
set_location_assignment PIN_AW38 -to A10_SFP1_TFC_RX_P
set_location_assignment PIN_BC38 -to A10_SFP1_TFC_TX_P
set_location_assignment PIN_AU37 -to A10_SFP1_TX_DISABLE
set_location_assignment PIN_AT35 -to A10_SFP1_TX_FAULT
set_location_assignment PIN_AV33 -to A10_SFP1_TX_MOD_ABS
set_location_assignment PIN_AL32 -to A10_SFP2_RS0
set_location_assignment PIN_AU35 -to A10_SFP2_RS1
set_location_assignment PIN_AL34 -to A10_SFP2_RX_LOSS
set_location_assignment PIN_BA38 -to A10_SFP2_TFC_RX_P
set_location_assignment PIN_BD40 -to A10_SFP2_TFC_TX_P
set_location_assignment PIN_AT37 -to A10_SFP2_TX_DISABLE
set_location_assignment PIN_AT32 -to A10_SFP2_TX_FAULT
set_location_assignment PIN_AW33 -to A10_SFP2_TX_MOD_ABS
########################### PATCH to compensate SFP+ wire inversion ########################
#does not exist anymore as it is fixed on the PCB
#set_location_assignment PIN_AY40 -to A10_SFP3_TFC_RX_P
#set_location_assignment PIN_AV40 -to A10_SFP4_TFC_RX_P
#set_location_assignment PIN_BB40 -to A10_SFP3_TFC_TX_P
#set_location_assignment PIN_BC42 -to A10_SFP4_TFC_TX_P

# IO_STANDARD assignment
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_SFP1_TFC_RX_P
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP1_TFC_RX_P
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_SFP1_TFC_TX_P
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP1_TFC_TX_P
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_SFP2_TFC_RX_P
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP2_TFC_RX_P
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_SFP2_TFC_TX_P
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP2_TFC_TX_P
########################### PATCH to compensate SFP+ wire inversion ########################
#set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_SFP3_TFC_RX_P
#set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP3_TFC_RX_P
#set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_SFP3_TFC_TX_P
#set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP3_TFC_TX_P
#set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_SFP4_TFC_RX_P
#set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP4_TFC_RX_P
#set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_SFP4_TFC_TX_P
#set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V -to A10_SFP4_TFC_TX_P

puts "Set filtered Refclk monitoring interface"
############################# SFP+ interface reference clock in external clock ######################################################
# location assignment
#set_location_assignment PIN_AY40 -to A10_REFCLK_TFC_CMU_P -comment "Bank : 1C"

# IO_STANDARD assignment
#set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to A10_REFCLK_TFC_CMU_P
#set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to A10_REFCLK_TFC_CMU_P


puts "Set A10 spares"
############################ A10 spares ######################################################
# location assignment
set_location_assignment PIN_C25 -to SPARE[0]
set_location_assignment PIN_C23 -to SPARE[1]
set_location_assignment PIN_B25 -to SPARE[2]
set_location_assignment PIN_C24 -to SPARE[3]
set_location_assignment PIN_A25 -to SPARE[4]
set_location_assignment PIN_B22 -to SPARE[5]
set_location_assignment PIN_A24 -to SPARE[6]
set_location_assignment PIN_B23 -to SPARE[7]


puts "Set Partial reconfiguration signals"
############################ Partial Reconfiguration signals ######################################################
# location assignment
set_location_assignment PIN_BB28 -to A10_M5FL_PR_DONE
set_location_assignment PIN_BA28 -to A10_M5FL_PR_ERROR
set_location_assignment PIN_BB30 -to A10_M5FL_PR_READY
set_location_assignment PIN_BD31 -to A10_M5FL_PR_REQUEST


puts "Set M5FL Spare connections"
############################ MAX5FL Spare connections ######################################################
# location assignment
set_location_assignment PIN_BD21 -to A10_M5FL_SPARE[0]
set_location_assignment PIN_AU17 -to A10_M5FL_SPARE[1]
set_location_assignment PIN_BC25 -to A10_M5FL_SPARE[2]
set_location_assignment PIN_BC26 -to A10_M5FL_SPARE[3]
set_location_assignment PIN_BD23 -to A10_M5FL_SPARE[4]
set_location_assignment PIN_AY32 -to A10_M5FL_SPARE[5]
set_location_assignment PIN_AT19 -to A10_M5FL_SPARE[6]
set_location_assignment PIN_AT20 -to A10_M5FL_SPARE[7]
set_location_assignment PIN_AW32 -to A10_M5FL_SPARE[8]


puts "Set Miscellaneous"
############################ Miscellaneous ######################################################
# location assignment
set_location_assignment PIN_BD27 -to A10_M5FL_CPU_RESET_N -comment "Reset from MAX5 of push button"
set_location_assignment PIN_BD28 -to A10_M5FL_CRC_ERROR -comment "CRC error to Max5"



#8B10B
puts "Set SFP for TFC Pins"
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)" -to rx_tfc
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_tfc
set_location_assignment PIN_AV40 -to rx_tfc
set_location_assignment PIN_BC42 -to tx_tfc
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP_TX_FAULT
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP_TX_DISABLE
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP_MOD_ABS
set_instance_assignment -name IO_STANDARD "1.8 V" -to A10_SFP_RX_LOS
set_location_assignment PIN_AT35 -to A10_SFP_TX_FAULT
set_location_assignment PIN_AU37 -to A10_SFP_TX_DISABLE
set_location_assignment PIN_AV33 -to A10_SFP_MOD_ABS
set_location_assignment PIN_AR35 -to A10_SFP_RX_LOS


# Commit assignments
#export_assignments
