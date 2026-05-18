#
set_location_assignment PIN_AC21 -to clock_A
set_location_assignment PIN_AA10 -to clock_B
set_location_assignment PIN_AD9 -to clock_C
set_location_assignment PIN_D15 -to clock_D
set_instance_assignment -name IO_STANDARD "2.5 V" -to clock_A
set_instance_assignment -name IO_STANDARD "2.5 V" -to clock_B
set_instance_assignment -name IO_STANDARD "2.5 V" -to clock_C
set_instance_assignment -name IO_STANDARD "2.5 V" -to clock_D

set_location_assignment PIN_AE11 -to fast_reset_B
set_location_assignment PIN_D12 -to fast_reset_D
set_location_assignment PIN_AD22 -to fast_reset_A
set_location_assignment PIN_AH8 -to fast_reset_C
set_instance_assignment -name IO_STANDARD LVDS -to fast_reset_A
set_instance_assignment -name IO_STANDARD LVDS -to fast_reset_B
set_instance_assignment -name IO_STANDARD LVDS -to fast_reset_C
set_instance_assignment -name IO_STANDARD LVDS -to fast_reset_D

set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[6]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[7]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[8]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[9]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[6]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[7]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[8]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[9]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[6]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[7]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[8]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[9]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[6]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[7]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[8]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_E[9]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[6]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[7]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[8]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[9]
set_location_assignment PIN_AB22 -to data_in_A[1]
set_location_assignment PIN_AH23 -to data_in_A[2]
set_location_assignment PIN_AG22 -to data_in_A[3]
set_location_assignment PIN_AG21 -to data_in_A[4]
set_location_assignment PIN_AH20 -to data_in_A[5]
set_location_assignment PIN_AK22 -to data_in_A[6]
set_location_assignment PIN_AK21 -to data_in_A[7]
set_location_assignment PIN_AH18 -to data_in_A[8]
set_location_assignment PIN_AB17 -to data_in_A[9]
set_location_assignment PIN_AJ13 -to data_in_B[1]
set_location_assignment PIN_AF13 -to data_in_B[2]
set_location_assignment PIN_AH12 -to data_in_B[3]
set_location_assignment PIN_AC12 -to data_in_B[4]
set_location_assignment PIN_AH11 -to data_in_B[5]
set_location_assignment PIN_AB11 -to data_in_B[6]
set_location_assignment PIN_AK10 -to data_in_B[7]
set_location_assignment PIN_AB9 -to data_in_B[8]
set_location_assignment PIN_AJ10 -to data_in_B[9]
set_location_assignment PIN_AH7 -to data_in_C[1]
set_location_assignment PIN_AB15 -to data_in_C[2]
set_location_assignment PIN_AK16 -to data_in_C[3]
set_location_assignment PIN_AB6 -to data_in_C[4]
set_location_assignment PIN_AF6 -to data_in_C[5]
set_location_assignment PIN_AJ4 -to data_in_C[6]
set_location_assignment PIN_AK3 -to data_in_C[7]
set_location_assignment PIN_AK2 -to data_in_C[8]
set_location_assignment PIN_AH1 -to data_in_C[9]
set_location_assignment PIN_F15 -to data_in_D[1]
set_location_assignment PIN_A15 -to data_in_D[2]
set_location_assignment PIN_C14 -to data_in_D[3]
set_location_assignment PIN_A14 -to data_in_D[4]
set_location_assignment PIN_J14 -to data_in_D[5]
set_location_assignment PIN_C13 -to data_in_D[6]
set_location_assignment PIN_J12 -to data_in_D[7]
set_location_assignment PIN_B13 -to data_in_D[8]
set_location_assignment PIN_J11 -to data_in_D[9]
set_location_assignment PIN_D9 -to data_in_E[1]
set_location_assignment PIN_C8 -to data_in_E[2]
set_location_assignment PIN_A7 -to data_in_E[3]
set_location_assignment PIN_E7 -to data_in_E[4]
set_location_assignment PIN_F8 -to data_in_E[5]
set_location_assignment PIN_A6 -to data_in_E[6]
set_location_assignment PIN_D6 -to data_in_E[7]
set_location_assignment PIN_A5 -to data_in_E[8]
set_location_assignment PIN_A3 -to data_in_E[9]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[6]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[7]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[8]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[9]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[6]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[7]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[8]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[9]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[6]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[7]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[8]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[9]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[6]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[7]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[8]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[9]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[6]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[7]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[8]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_E[9]
set_location_assignment PIN_AJ16 -to "data_in_C[3](n)"
set_location_assignment PIN_AA15 -to "data_in_C[2](n)"
set_location_assignment PIN_B6 -to "data_in_E[6](n)"

set_location_assignment PIN_AK19 -to SIN_A
set_location_assignment PIN_AB18 -to SIN_B
set_location_assignment PIN_AD16 -to SIN_C
set_location_assignment PIN_D19 -to SIN_D
set_instance_assignment -name IO_STANDARD LVDS -to SIN_A
set_instance_assignment -name IO_STANDARD LVDS -to SIN_B
set_instance_assignment -name IO_STANDARD LVDS -to SIN_C
set_instance_assignment -name IO_STANDARD LVDS -to SIN_D

set_location_assignment PIN_AC15 -to csn_A[0]
set_location_assignment PIN_AD15 -to csn_A[1]
set_location_assignment PIN_AG6 -to csn_A[2]
set_location_assignment PIN_AF7 -to csn_B[0]
set_location_assignment PIN_AG16 -to csn_B[1]
set_location_assignment PIN_AF16 -to csn_B[2]
set_location_assignment PIN_G17 -to csn_C[0]
set_location_assignment PIN_F17 -to csn_C[1]
set_location_assignment PIN_B7 -to csn_C[2]
set_location_assignment PIN_C7 -to csn_D[0]
set_location_assignment PIN_B9 -to csn_D[1]
set_location_assignment PIN_B10 -to csn_D[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_A[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_A[1]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_A[0]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_B[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_B[1]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_B[0]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_C[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_C[1]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_C[0]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_D[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_D[1]
set_instance_assignment -name IO_STANDARD "2.5 V" -to csn_D[0]

set_location_assignment PIN_AB21 -to mosi_A
set_location_assignment PIN_AA11 -to mosi_B
set_location_assignment PIN_AC9 -to mosi_C
set_location_assignment PIN_E15 -to mosi_D
set_instance_assignment -name IO_STANDARD "2.5 V" -to mosi_A
set_instance_assignment -name IO_STANDARD "2.5 V" -to mosi_B
set_instance_assignment -name IO_STANDARD "2.5 V" -to mosi_C
set_instance_assignment -name IO_STANDARD "2.5 V" -to mosi_D
