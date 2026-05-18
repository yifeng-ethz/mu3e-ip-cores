#

set_global_assignment -name FAMILY "MAX 10 FPGA"
set_global_assignment -name DEVICE 10M08SAE144C8GES
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"



set_location_assignment PIN_6 -to Arduino_A0
set_location_assignment PIN_7 -to Arduino_A1
set_location_assignment PIN_8 -to Arduino_A2
set_location_assignment PIN_10 -to Arduino_A3
set_location_assignment PIN_11 -to Arduino_A4
set_location_assignment PIN_12 -to Arduino_A5
set_location_assignment PIN_13 -to Arduino_A6
set_location_assignment PIN_14 -to Arduino_A7
set_location_assignment PIN_27 -to CLOCK
set_location_assignment PIN_28 -to DIFFIO_L20N_CLK1N
set_location_assignment PIN_29 -to DIFFIO_L20P_CLK1P
set_location_assignment PIN_32 -to DIFFIO_L27N_PLL_CLKOUTN
set_location_assignment PIN_33 -to DIFFIO_L27P_PLL_CLKOUTP
set_location_assignment PIN_38 -to DIFFIO_B1N
set_location_assignment PIN_39 -to DIFFIO_B1P
set_location_assignment PIN_41 -to DIFFIO_B3N
set_location_assignment PIN_43 -to DIFFIO_B3P
set_location_assignment PIN_44 -to DIFFIO_B5N
set_location_assignment PIN_45 -to DIFFIO_B5P
set_location_assignment PIN_46 -to DIFFIO_B7N
set_location_assignment PIN_47 -to DIFFIO_B7P
set_location_assignment PIN_50 -to DIFFIO_B9N
set_location_assignment PIN_52 -to DIFFIO_B9P
set_location_assignment PIN_55 -to DIFFIO_B12N
set_location_assignment PIN_56 -to DIFFIO_B12P
set_location_assignment PIN_57 -to DIFFIO_B14N
set_location_assignment PIN_58 -to DIFFIO_B14P
set_location_assignment PIN_59 -to DIFFIO_B16N
set_location_assignment PIN_60 -to DIFFIO_B16P
set_location_assignment PIN_62 -to Arduino_IO8
set_location_assignment PIN_64 -to Arduino_IO9
set_location_assignment PIN_65 -to Arduino_IO10
set_location_assignment PIN_66 -to Arduino_IO11
set_location_assignment PIN_69 -to Arduino_IO12
set_location_assignment PIN_70 -to Arduino_IO13
set_location_assignment PIN_75 -to Arduino_IO1
set_location_assignment PIN_74 -to Arduino_IO0
set_location_assignment PIN_77 -to Arduino_IO3
set_location_assignment PIN_76 -to Arduino_IO2
set_location_assignment PIN_79 -to Arduino_IO4
set_location_assignment PIN_81 -to Arduino_IO5
set_location_assignment PIN_84 -to Arduino_IO6
set_location_assignment PIN_86 -to Arduino_IO7
set_location_assignment PIN_88 -to DIFFIO_R14P_CLK2P
set_location_assignment PIN_89 -to DIFFIO_R14N_CLK2N
set_location_assignment PIN_90 -to DIFFIO_R16P_CLK3P
set_location_assignment PIN_91 -to DIFFIO_R16N_CLK3N
set_location_assignment PIN_92 -to DIFFIO_R18P
set_location_assignment PIN_93 -to DIFFIO_R18N
set_location_assignment PIN_96 -to DIFFIO_R26P_DPCLK3
set_location_assignment PIN_98 -to DIFFIO_R26N_DPCLK2
set_location_assignment PIN_99 -to DIFFIO_R27P
set_location_assignment PIN_100 -to DIFFIO_R28P
set_location_assignment PIN_101 -to DIFFIO_R27N
set_location_assignment PIN_102 -to DIFFIO_R28N
set_location_assignment PIN_105 -to DIFFIO_R33P
set_location_assignment PIN_106 -to DIFFIO_R33N
set_location_assignment PIN_110 -to DIFFIO_T1P
set_location_assignment PIN_111 -to DIFFIO_T1N
set_location_assignment PIN_113 -to DIFFIO_T4N
set_location_assignment PIN_114 -to DIFFIO_T6P
set_location_assignment PIN_118 -to DIFFIO_T10P
set_location_assignment PIN_119 -to DIFFIO_T10N
set_location_assignment PIN_120 -to SWITCH1
set_location_assignment PIN_121 -to RESET_N
set_location_assignment PIN_124 -to SWITCH2
set_location_assignment PIN_127 -to SWITCH3
set_location_assignment PIN_130 -to SWITCH4
set_location_assignment PIN_131 -to SWITCH5
set_location_assignment PIN_132 -to LED1
set_location_assignment PIN_134 -to LED2
set_location_assignment PIN_135 -to LED3
set_location_assignment PIN_140 -to LED4
set_location_assignment PIN_141 -to LED5

set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A0
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A1
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A2
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A3
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A4
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A5
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A6
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_A7
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_L20N_CLK1N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_L20P_CLK1P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_L27N_PLL_CLKOUTN
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_L27P_PLL_CLKOUTP
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B1N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B1P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B3N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B3P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B5N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B5P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B7N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B7P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B9N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B9P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B12N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B12P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B14N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B14P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B16N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_B16P
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO8
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO9
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO10
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO11
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO12
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO13
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO1
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO0
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO3
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO2
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO4
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO5
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO6
set_instance_assignment -name IO_STANDARD "2.5 V" -to Arduino_IO7
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R14P_CLK2P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R14N_CLK2N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R16P_CLK3P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R16N_CLK3N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R18P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R18N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R26P_DPCLK3
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R26N_DPCLK2
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R27P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R28P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R27N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R28N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R33P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_R33N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_T1P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_T1N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_T4N
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_T6P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_T10P
set_instance_assignment -name IO_STANDARD "2.5 V" -to DIFFIO_T10N
set_instance_assignment -name IO_STANDARD "2.5 V" -to SWITCH1
set_instance_assignment -name IO_STANDARD "2.5 V" -to RESET_N
set_instance_assignment -name IO_STANDARD "2.5 V" -to SWITCH2
set_instance_assignment -name IO_STANDARD "2.5 V" -to SWITCH3
set_instance_assignment -name IO_STANDARD "2.5 V" -to SWITCH4
set_instance_assignment -name IO_STANDARD "2.5 V" -to SWITCH5
set_instance_assignment -name IO_STANDARD "2.5 V" -to LED1
set_instance_assignment -name IO_STANDARD "2.5 V" -to LED2
set_instance_assignment -name IO_STANDARD "2.5 V" -to LED3
set_instance_assignment -name IO_STANDARD "2.5 V" -to LED4
set_instance_assignment -name IO_STANDARD "2.5 V" -to LED5
