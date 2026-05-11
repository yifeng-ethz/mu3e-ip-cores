#
set_location_assignment PIN_AE11 -to clock_A
set_instance_assignment -name IO_STANDARD LVDS -to clock_A

set_location_assignment PIN_AA10 -to fast_reset_A
set_instance_assignment -name IO_STANDARD LVDS -to fast_reset_A


set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_B[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[3]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_D[4]
set_location_assignment PIN_J12 -to data_in_A[1]
set_location_assignment PIN_C14 -to data_in_A[2]
set_location_assignment PIN_A15 -to data_in_A[3]
set_location_assignment PIN_F15 -to data_in_A[4]
set_location_assignment PIN_J14 -to data_in_B[1]
set_location_assignment PIN_C13 -to data_in_B[2]
set_location_assignment PIN_J11 -to data_in_B[3]
set_location_assignment PIN_B13 -to data_in_B[4]
set_location_assignment PIN_AH7 -to data_in_C[1]
set_location_assignment PIN_AJ4 -to data_in_C[2]
set_location_assignment PIN_AK3 -to data_in_C[3]
set_location_assignment PIN_AH1 -to data_in_C[4]
set_location_assignment PIN_AK22 -to data_in_D[1]
set_location_assignment PIN_AK21 -to data_in_D[2]
set_location_assignment PIN_AH20 -to data_in_D[3]
set_location_assignment PIN_AH18 -to data_in_D[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_B[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[4]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[1]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[2]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[3]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_D[4]

# quick and dirty transceiver placement things (remove again .. maybe)
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_A[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_A[5]
set_location_assignment PIN_A14 -to data_in_A[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to data_in_C[5]
set_instance_assignment -name IO_STANDARD LVDS -to data_in_C[5]
set_location_assignment PIN_AB15 -to data_in_C[5]

set_location_assignment PIN_C8 -to csn_A[0]
set_location_assignment PIN_D15 -to csn_B[0]
set_location_assignment PIN_AF6 -to csn_C[0]
set_location_assignment PIN_AC21 -to csn_D[0]
set_instance_assignment -name IO_STANDARD LVDS_E_1R -to csn_A[0]
set_instance_assignment -name IO_STANDARD LVDS -to csn_B[0]
set_instance_assignment -name IO_STANDARD LVDS_E_1R -to csn_C[0]
set_instance_assignment -name IO_STANDARD LVDS -to csn_D[0]

set_location_assignment PIN_AG16 -to mosi_A
set_instance_assignment -name IO_STANDARD LVDS -to mosi_A

set_location_assignment PIN_AD15 -to enable_A
set_location_assignment PIN_AC15 -to enable_B
set_location_assignment PIN_A5 -to enable_C
set_location_assignment PIN_A4 -to enable_D
set_instance_assignment -name IO_STANDARD "2.5 V" -to enable_A
set_instance_assignment -name IO_STANDARD "2.5 V" -to enable_B
set_instance_assignment -name IO_STANDARD "2.5 V" -to enable_C
set_instance_assignment -name IO_STANDARD "2.5 V" -to enable_D

set_location_assignment PIN_AH12 -to Trig0_TTL
set_location_assignment PIN_AG12 -to Trig1_TTL
set_location_assignment PIN_AF13 -to Trig2_TTL
set_location_assignment PIN_AF12 -to Trig3_TTL

set_location_assignment PIN_AK19 -to gate_in
set_instance_assignment -name IO_STANDARD "2.5 V" -to gate_in

set_location_assignment PIN_AJ19 -to pulse_train_in
set_instance_assignment -name IO_STANDARD "2.5 V" -to pulse_train_in