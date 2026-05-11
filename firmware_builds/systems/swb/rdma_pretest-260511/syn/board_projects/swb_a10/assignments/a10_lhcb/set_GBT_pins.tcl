#  GBT pins and bank locations
#
#
#
#   _______  _______   _______  _______   _______  _______   _______  _______
#  |       ||       | |       ||       | |       ||       | |       ||       |
#  |  MP0  ||  MP0  | |  MP1  ||  MP1  | |  MP2  ||  MP2  | |  MP3  ||  MP3  |
#  |  RX   ||  TX   | |  RX   ||  TX   | |  RX   ||  TX   | |  RX   ||  TX   |
#  |_______||_______| |_______||_______| |_______||_______| |_______||_______|
#
#
#
#
#                       _________________________________________
#                      | MP0  | MP0  | MP1  | MP1  | MP2  | MP2  |
#                      | RX/TX| RX/TX| RX/TX| RX/TX| RX/TX| RX/TX|
#                      |______|______|______|______|______|______|
#                      | 4C     4D      4E     4F    4G      4H  |
#                      |                                         |
#                      |                                         |
#                      |                                         |
#                      |                                         |
#                      |                                         |
#                      |                                         |
#                      |                                         |
#                      |                             1G     1H   |
#                      |_________________________________________|
#                      |      |      |      |      | MP3  | MP3  |
#                      |      |      |      |      | RX/TX| RX/TX|
#                      |______|______|______|______|______|______|
#

puts "Set GBT Links \[47..0\]"

for { set i 0 } { $i < 48 } { incr i 6 } {
    if { $i >= 48 } {
        set_instance_assignment -name VIRTUAL_PIN ON -to rx_gbt[[expr $i + 0]]
        set_instance_assignment -name VIRTUAL_PIN ON -to rx_gbt[[expr $i + 1]]
        set_instance_assignment -name VIRTUAL_PIN ON -to rx_gbt[[expr $i + 2]]
        set_instance_assignment -name VIRTUAL_PIN ON -to rx_gbt[[expr $i + 3]]
        set_instance_assignment -name VIRTUAL_PIN ON -to rx_gbt[[expr $i + 4]]
        set_instance_assignment -name VIRTUAL_PIN ON -to rx_gbt[[expr $i + 5]]
        set_instance_assignment -name VIRTUAL_PIN ON -to tx_gbt[[expr $i + 0]]
        set_instance_assignment -name VIRTUAL_PIN ON -to tx_gbt[[expr $i + 1]]
        set_instance_assignment -name VIRTUAL_PIN ON -to tx_gbt[[expr $i + 2]]
        set_instance_assignment -name VIRTUAL_PIN ON -to tx_gbt[[expr $i + 3]]
        set_instance_assignment -name VIRTUAL_PIN ON -to tx_gbt[[expr $i + 4]]
        set_instance_assignment -name VIRTUAL_PIN ON -to tx_gbt[[expr $i + 5]]
        set gbt_activated_link_[expr $i + 0] "-disable"
        set gbt_activated_link_[expr $i + 1] "-disable"
        set gbt_activated_link_[expr $i + 2] "-disable"
        set gbt_activated_link_[expr $i + 3] "-disable"
        set gbt_activated_link_[expr $i + 4] "-disable"
        set gbt_activated_link_[expr $i + 5] "-disable"
    } else {
        set_instance_assignment -name VIRTUAL_PIN OFF -to rx_gbt[[expr $i + 0]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to rx_gbt[[expr $i + 1]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to rx_gbt[[expr $i + 2]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to rx_gbt[[expr $i + 3]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to rx_gbt[[expr $i + 4]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to rx_gbt[[expr $i + 5]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to tx_gbt[[expr $i + 0]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to tx_gbt[[expr $i + 1]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to tx_gbt[[expr $i + 2]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to tx_gbt[[expr $i + 3]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to tx_gbt[[expr $i + 4]]
        set_instance_assignment -name VIRTUAL_PIN OFF -to tx_gbt[[expr $i + 5]]
        set gbt_activated_link_[expr $i + 0] ""
        set gbt_activated_link_[expr $i + 1] ""
        set gbt_activated_link_[expr $i + 2] ""
        set gbt_activated_link_[expr $i + 3] ""
        set gbt_activated_link_[expr $i + 4] ""
        set gbt_activated_link_[expr $i + 5] ""
    }
}

set_location_assignment PIN_AW7 -to rx_gbt[0] $gbt_activated_link_0
set_location_assignment PIN_BA7 -to rx_gbt[1] $gbt_activated_link_1
set_location_assignment PIN_AY5 -to rx_gbt[2] $gbt_activated_link_2
set_location_assignment PIN_AV5 -to rx_gbt[3] $gbt_activated_link_3
set_location_assignment PIN_AT5 -to rx_gbt[4] $gbt_activated_link_4
set_location_assignment PIN_AP5 -to rx_gbt[5] $gbt_activated_link_5
set_location_assignment PIN_AN3 -to rx_gbt[6] $gbt_activated_link_6
set_location_assignment PIN_AM5 -to rx_gbt[7] $gbt_activated_link_7
set_location_assignment PIN_AL3 -to rx_gbt[8] $gbt_activated_link_8
set_location_assignment PIN_AK5 -to rx_gbt[9] $gbt_activated_link_9
set_location_assignment PIN_AJ3 -to rx_gbt[10] $gbt_activated_link_10
set_location_assignment PIN_AH5 -to rx_gbt[11] $gbt_activated_link_11
set_location_assignment PIN_AG3 -to rx_gbt[12] $gbt_activated_link_12
set_location_assignment PIN_AF5 -to rx_gbt[13] $gbt_activated_link_13
set_location_assignment PIN_AE3 -to rx_gbt[14] $gbt_activated_link_14
set_location_assignment PIN_AD5 -to rx_gbt[15] $gbt_activated_link_15
set_location_assignment PIN_AC3 -to rx_gbt[16] $gbt_activated_link_16
set_location_assignment PIN_AB5 -to rx_gbt[17] $gbt_activated_link_17
set_location_assignment PIN_AA3 -to rx_gbt[18] $gbt_activated_link_18
set_location_assignment PIN_W3 -to rx_gbt[19] $gbt_activated_link_19
set_location_assignment PIN_Y5 -to rx_gbt[20] $gbt_activated_link_20
set_location_assignment PIN_V5 -to rx_gbt[21] $gbt_activated_link_21
set_location_assignment PIN_U3 -to rx_gbt[22] $gbt_activated_link_22
set_location_assignment PIN_T5 -to rx_gbt[23] $gbt_activated_link_23
set_location_assignment PIN_R3 -to rx_gbt[24] $gbt_activated_link_24
set_location_assignment PIN_P5 -to rx_gbt[25] $gbt_activated_link_25
set_location_assignment PIN_N3 -to rx_gbt[26] $gbt_activated_link_26
set_location_assignment PIN_M5 -to rx_gbt[27] $gbt_activated_link_27
set_location_assignment PIN_L3 -to rx_gbt[28] $gbt_activated_link_28
set_location_assignment PIN_K5 -to rx_gbt[29] $gbt_activated_link_29
set_location_assignment PIN_H5 -to rx_gbt[30] $gbt_activated_link_30
set_location_assignment PIN_G7 -to rx_gbt[31] $gbt_activated_link_31
set_location_assignment PIN_F5 -to rx_gbt[32] $gbt_activated_link_32
set_location_assignment PIN_E7 -to rx_gbt[33] $gbt_activated_link_33
set_location_assignment PIN_D5 -to rx_gbt[34] $gbt_activated_link_34
set_location_assignment PIN_C7 -to rx_gbt[35] $gbt_activated_link_35
set_location_assignment PIN_R42 -to rx_gbt[36] $gbt_activated_link_36
set_location_assignment PIN_P40 -to rx_gbt[37] $gbt_activated_link_37
set_location_assignment PIN_N42 -to rx_gbt[38] $gbt_activated_link_38
set_location_assignment PIN_M40 -to rx_gbt[39] $gbt_activated_link_39
set_location_assignment PIN_L42 -to rx_gbt[40] $gbt_activated_link_40
set_location_assignment PIN_K40 -to rx_gbt[41] $gbt_activated_link_41
set_location_assignment PIN_H40 -to rx_gbt[42] $gbt_activated_link_42
set_location_assignment PIN_G38 -to rx_gbt[43] $gbt_activated_link_43
set_location_assignment PIN_F40 -to rx_gbt[44] $gbt_activated_link_44
set_location_assignment PIN_E38 -to rx_gbt[45] $gbt_activated_link_45
set_location_assignment PIN_D40 -to rx_gbt[46] $gbt_activated_link_46
set_location_assignment PIN_C38 -to rx_gbt[47] $gbt_activated_link_47

set_location_assignment PIN_BC7 -to tx_gbt[0] $gbt_activated_link_0
set_location_assignment PIN_BD5 -to tx_gbt[1] $gbt_activated_link_1
set_location_assignment PIN_BB5 -to tx_gbt[2] $gbt_activated_link_2
set_location_assignment PIN_BC3 -to tx_gbt[3] $gbt_activated_link_3
set_location_assignment PIN_BB1 -to tx_gbt[4] $gbt_activated_link_4
set_location_assignment PIN_BA3 -to tx_gbt[5] $gbt_activated_link_5
set_location_assignment PIN_AY1 -to tx_gbt[6] $gbt_activated_link_6
set_location_assignment PIN_AW3 -to tx_gbt[7] $gbt_activated_link_7
set_location_assignment PIN_AV1 -to tx_gbt[8] $gbt_activated_link_8
set_location_assignment PIN_AU3 -to tx_gbt[9] $gbt_activated_link_9
set_location_assignment PIN_AT1 -to tx_gbt[10] $gbt_activated_link_10
set_location_assignment PIN_AR3 -to tx_gbt[11] $gbt_activated_link_11
set_location_assignment PIN_AP1 -to tx_gbt[12] $gbt_activated_link_12
set_location_assignment PIN_AM1 -to tx_gbt[13] $gbt_activated_link_13
set_location_assignment PIN_AK1 -to tx_gbt[14] $gbt_activated_link_14
set_location_assignment PIN_AH1 -to tx_gbt[15] $gbt_activated_link_15
set_location_assignment PIN_AF1 -to tx_gbt[16] $gbt_activated_link_16
set_location_assignment PIN_AD1 -to tx_gbt[17] $gbt_activated_link_17
set_location_assignment PIN_AB1 -to tx_gbt[18] $gbt_activated_link_18
set_location_assignment PIN_Y1 -to tx_gbt[19] $gbt_activated_link_19
set_location_assignment PIN_V1 -to tx_gbt[20] $gbt_activated_link_20
set_location_assignment PIN_T1 -to tx_gbt[21] $gbt_activated_link_21
set_location_assignment PIN_P1 -to tx_gbt[22] $gbt_activated_link_22
set_location_assignment PIN_M1 -to tx_gbt[23] $gbt_activated_link_23
set_location_assignment PIN_K1 -to tx_gbt[24] $gbt_activated_link_24
set_location_assignment PIN_J3 -to tx_gbt[25] $gbt_activated_link_25
set_location_assignment PIN_H1 -to tx_gbt[26] $gbt_activated_link_26
set_location_assignment PIN_G3 -to tx_gbt[27] $gbt_activated_link_27
set_location_assignment PIN_F1 -to tx_gbt[28] $gbt_activated_link_28
set_location_assignment PIN_E3 -to tx_gbt[29] $gbt_activated_link_29
set_location_assignment PIN_D1 -to tx_gbt[30] $gbt_activated_link_30
set_location_assignment PIN_C3 -to tx_gbt[31] $gbt_activated_link_31
set_location_assignment PIN_B1 -to tx_gbt[32] $gbt_activated_link_32
set_location_assignment PIN_A3 -to tx_gbt[33] $gbt_activated_link_33
set_location_assignment PIN_B5 -to tx_gbt[34] $gbt_activated_link_34
set_location_assignment PIN_A7 -to tx_gbt[35] $gbt_activated_link_35
set_location_assignment PIN_K44 -to tx_gbt[36] $gbt_activated_link_36
set_location_assignment PIN_J42 -to tx_gbt[37] $gbt_activated_link_37
set_location_assignment PIN_H44 -to tx_gbt[38] $gbt_activated_link_38
set_location_assignment PIN_G42 -to tx_gbt[39] $gbt_activated_link_39
set_location_assignment PIN_F44 -to tx_gbt[40] $gbt_activated_link_40
set_location_assignment PIN_E42 -to tx_gbt[41] $gbt_activated_link_41
set_location_assignment PIN_D44 -to tx_gbt[42] $gbt_activated_link_42
set_location_assignment PIN_C42 -to tx_gbt[43] $gbt_activated_link_43
set_location_assignment PIN_B44 -to tx_gbt[44] $gbt_activated_link_44
set_location_assignment PIN_A42 -to tx_gbt[45] $gbt_activated_link_45
set_location_assignment PIN_B40 -to tx_gbt[46] $gbt_activated_link_46
set_location_assignment PIN_A38 -to tx_gbt[47] $gbt_activated_link_47

############## IOSTANDARD - NET ##################

set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[0]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[1]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[2]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[3]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[4]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[5]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[6]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[7]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[8]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[9]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[10]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[11]

set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[0]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[1]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[2]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[3]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[4]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[5]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[6]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[7]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[8]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[9]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[10]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[11]

#-----------------------------------------------------

set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[12]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[13]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[14]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[15]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[16]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[17]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[18]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[19]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[20]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[21]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[22]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[23]

set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[12]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[13]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[14]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[15]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[16]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[17]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[18]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[19]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[20]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[21]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[22]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[23]

#-----------------------------------------------------

set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[24]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[25]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[26]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[27]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[28]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[29]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[30]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[31]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[32]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[33]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[34]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[35]

set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[24]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[25]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[26]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[27]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[28]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[29]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[30]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[31]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[32]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[33]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[34]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[35]

#-----------------------------------------------------

set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[36]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[37]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[38]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[39]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[40]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[41]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[42]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[43]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[44]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[45]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[46]
set_instance_assignment -name IO_STANDARD "CURRENT MODE LOGIC (CML)"    -to rx_gbt[47]

set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[36]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[37]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[38]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[39]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[40]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[41]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[42]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[43]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[44]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[45]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[46]
set_instance_assignment -name IO_STANDARD "HIGH SPEED DIFFERENTIAL I/O" -to tx_gbt[47]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[7]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[8]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[9]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[10]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[11]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[7]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[8]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[9]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[10]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[11]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[12]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[13]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[14]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[15]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[16]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[17]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[18]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[19]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[20]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[21]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[22]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[23]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[12]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[13]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[14]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[15]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[16]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[17]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[18]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[19]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[20]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[21]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[22]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[23]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[24]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[25]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[26]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[27]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[28]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[29]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[30]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[31]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[32]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[33]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[34]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[35]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[24]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[25]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[26]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[27]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[28]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[29]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[30]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[31]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[32]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[33]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[34]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[35]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[36]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[37]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[38]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[39]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[40]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[41]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[42]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[43]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[44]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[45]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[46]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[47]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[36]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[37]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[38]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[39]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[40]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[41]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[42]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[43]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[44]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[45]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[46]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[47]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[7]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[8]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[9]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[10]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[11]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[0]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[1]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[2]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[3]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[4]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[5]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[6]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[7]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[8]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[9]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[10]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[11]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[12]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[13]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[14]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[15]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[16]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[17]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[18]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[19]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[20]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[21]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[22]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[23]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[12]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[13]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[14]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[15]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[16]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[17]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[18]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[19]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[20]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[21]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[22]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[23]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[24]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[25]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[26]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[27]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[28]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[29]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[30]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[31]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[32]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[33]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[34]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[35]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[24]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[25]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[26]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[27]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[28]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[29]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[30]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[31]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[32]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[33]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[34]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[35]

#-----------------------------------------------------

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[36]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[37]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[38]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[39]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[40]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[41]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[42]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[43]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[44]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[45]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[46]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to rx_gbt[47]

set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[36]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[37]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[38]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[39]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[40]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[41]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[42]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[43]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[44]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[45]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[46]
set_instance_assignment -name XCVR_VCCR_VCCT_VOLTAGE 1_0V   -to tx_gbt[47]

# Commit assignments
#export_assignments
