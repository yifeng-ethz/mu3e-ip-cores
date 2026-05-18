# base frontend Arria-V assignments

set_global_assignment -name FAMILY "Arria V"
set_global_assignment -name DEVICE 5AGXBA7D4F31C5
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "15 MM HEAT SINK WITH STILL AIR"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"

set_global_assignment -name ON_CHIP_BITSTREAM_DECOMPRESSION ON
set_global_assignment -name GENERATE_RBF_FILE ON

# power rails supply voltages
set_global_assignment -name VCCT_L_USER_VOLTAGE 1.1V
set_global_assignment -name VCCT_R_USER_VOLTAGE 1.1V
set_global_assignment -name VCCL_GXBL_USER_VOLTAGE 1.1V
set_global_assignment -name VCCL_GXBR_USER_VOLTAGE 1.1V
set_global_assignment -name VCCR_L_USER_VOLTAGE 1.1V
set_global_assignment -name VCCR_R_USER_VOLTAGE 1.1V
set_global_assignment -name VCCA_L_USER_VOLTAGE 2.5V
set_global_assignment -name VCCA_R_USER_VOLTAGE 2.5V

# measurement voltages
set_global_assignment -name OUTPUT_IO_TIMING_NEAR_END_VMEAS "HALF VCCIO" -rise
set_global_assignment -name OUTPUT_IO_TIMING_NEAR_END_VMEAS "HALF VCCIO" -fall
set_global_assignment -name OUTPUT_IO_TIMING_FAR_END_VMEAS "HALF SIGNAL SWING" -rise
set_global_assignment -name OUTPUT_IO_TIMING_FAR_END_VMEAS "HALF SIGNAL SWING" -fall

# consider the PCI Express hard IP blocks on the left/right side of the device powered down
# consider the transceivers on the left/right side of the device powered down
set_global_assignment -name POWER_HSSI_VCCHIP_LEFT "Opportunistically power off"
set_global_assignment -name POWER_HSSI_VCCHIP_RIGHT "Opportunistically power off"
set_global_assignment -name POWER_HSSI_LEFT "Opportunistically power off"
set_global_assignment -name POWER_HSSI_RIGHT "Opportunistically power off"

# toggle rates
set_global_assignment -name POWER_USE_INPUT_FILES OFF
set_global_assignment -name POWER_DEFAULT_INPUT_IO_TOGGLE_RATE 100%
set_global_assignment -name POWER_USE_PVA ON
set_global_assignment -name POWER_DEFAULT_TOGGLE_RATE 100%

# conf scheme
set_global_assignment -name STRATIXV_CONFIGURATION_SCHEME "PASSIVE PARALLEL X8"
set_global_assignment -name USE_CONFIGURATION_DEVICE OFF
set_global_assignment -name STRATIXII_CONFIGURATION_DEVICE AUTO

# conf pins
set_global_assignment -name ENABLE_OCT_DONE OFF
set_global_assignment -name ENABLE_CONFIGURATION_PINS OFF
set_global_assignment -name ENABLE_BOOT_SEL_PIN OFF

set_global_assignment -name ENABLE_INIT_DONE_OUTPUT OFF
set_global_assignment -name FORCE_CONFIGURATION_VCCIO OFF
set_global_assignment -name CONFIGURATION_VCCIO_LEVEL AUTO

set_global_assignment -name CRC_ERROR_OPEN_DRAIN ON
set_global_assignment -name RESERVE_DATA7_THROUGH_DATA5_AFTER_CONFIGURATION "AS INPUT TRI-STATED"

set_instance_assignment -name IO_STANDARD LVDS -to testout
set_location_assignment PIN_AK4 -to testout
set_location_assignment PIN_AK5 -to "testout(n)"

set_location_assignment PIN_F19 -to FPGA_Test[0]
set_location_assignment PIN_G20 -to FPGA_Test[1]
set_location_assignment PIN_J19 -to FPGA_Test[2]
set_location_assignment PIN_K19 -to FPGA_Test[3]
set_location_assignment PIN_J20 -to FPGA_Test[4]
set_location_assignment PIN_K20 -to FPGA_Test[5]
set_location_assignment PIN_F20 -to FPGA_Test[6]
set_location_assignment PIN_F21 -to FPGA_Test[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_Test[7]
set_location_assignment PIN_AG27 -to LVDS_clk_si1_fpga_A
set_instance_assignment -name IO_STANDARD LVDS -to LVDS_clk_si1_fpga_A
set_location_assignment PIN_AG25 -to clk_125_bottom
set_instance_assignment -name IO_STANDARD LVDS -to clk_125_bottom
set_location_assignment PIN_AJ22 -to systemclock_bottom
set_instance_assignment -name IO_STANDARD LVDS -to systemclock_bottom
set_location_assignment PIN_C5 -to LVDS_clk_si1_fpga_B
set_instance_assignment -name IO_STANDARD LVDS -to LVDS_clk_si1_fpga_B
set_location_assignment PIN_A2 -to systemclock
set_instance_assignment -name IO_STANDARD LVDS -to systemclock
set_location_assignment PIN_D2 -to clk_125_top
set_instance_assignment -name IO_STANDARD LVDS -to clk_125_top
set_location_assignment PIN_E1 -to spare_clk_osc
set_instance_assignment -name IO_STANDARD LVDS -to spare_clk_osc
set_location_assignment PIN_AC28 -to firefly1_tx_data[0]
set_location_assignment PIN_AA28 -to firefly1_tx_data[1]
set_location_assignment PIN_W28 -to firefly1_tx_data[2]
set_location_assignment PIN_U28 -to firefly1_tx_data[3]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly1_tx_data[3]
set_location_assignment PIN_U27 -to "firefly1_tx_data[3](n)"
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly1_tx_data[2]
set_location_assignment PIN_W27 -to "firefly1_tx_data[2](n)"
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly1_tx_data[1]
set_location_assignment PIN_AA27 -to "firefly1_tx_data[1](n)"
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly1_tx_data[0]
set_location_assignment PIN_AC27 -to "firefly1_tx_data[0](n)"
set_instance_assignment -name IO_STANDARD LVDS -to transceiver_pll_clock[0]
set_location_assignment PIN_W23 -to "transceiver_pll_clock(n)"
set_location_assignment PIN_N28 -to firefly2_tx_data[0]
set_location_assignment PIN_L28 -to firefly2_tx_data[1]
set_location_assignment PIN_J28 -to firefly2_tx_data[2]
set_location_assignment PIN_G28 -to firefly2_tx_data[3]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_tx_data[0]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_tx_data[1]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_tx_data[2]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_tx_data[3]
set_location_assignment PIN_W22 -to transceiver_pll_clock[0]
set_instance_assignment -name MEMORY_INTERFACE_DATA_PIN_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:0:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:0:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa"
set_instance_assignment -name MEMORY_INTERFACE_DATA_PIN_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:1:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:1:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa"
set_instance_assignment -name MEMORY_INTERFACE_DATA_PIN_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:2:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:2:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa"
set_instance_assignment -name MEMORY_INTERFACE_DATA_PIN_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:3:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:3:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa"
set_instance_assignment -name MEMORY_INTERFACE_DATA_PIN_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:4:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:4:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa"
set_location_assignment PIN_A23 -to Firefly_ModSel_n[0]
set_location_assignment PIN_L22 -to Firefly_Int_n[0]
set_location_assignment PIN_B24 -to Firefly_ModSel_n[1]
set_location_assignment PIN_K23 -to Firefly_ModPrs_n[0]
set_location_assignment PIN_A24 -to Firefly_Rst_n[0]
set_location_assignment PIN_B25 -to Firefly_Rst_n[1]
set_location_assignment PIN_A26 -to Firefly_ModPrs_n[1]
set_location_assignment PIN_A27 -to Firefly_Int_n[1]
set_location_assignment PIN_D24 -to Firefly_Scl
set_location_assignment PIN_E24 -to Firefly_Sda
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_Int_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_Int_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_ModPrs_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_ModPrs_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_ModSel_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_ModSel_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_Rst_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_Rst_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_Scl
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to Firefly_Sda
set_instance_assignment -name DQ_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:0:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:0:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -disable
set_instance_assignment -name DQ_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:1:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:1:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -disable
set_instance_assignment -name DQ_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:2:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:2:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -disable
set_instance_assignment -name DQ_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:3:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:3:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -disable
set_instance_assignment -name DQ_GROUP 4 -from "chipclocks:cc|clockshift:\\genshifts:4:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -to "chipclocks:cc|clockshift:\\genshifts:4:cs|clockoutbuf:cob|clockoutbuf_iobuf_out_e961:clockoutbuf_iobuf_out_e961_component|obufa" -disable
set_location_assignment PIN_D25 -to si45_oe_n[0]
set_location_assignment PIN_K24 -to si45_intr_n[0]
set_location_assignment PIN_J23 -to si45_lol_n[0]
set_location_assignment PIN_C25 -to si45_rst_n[0]
set_location_assignment PIN_J25 -to si45_spi_cs_n[0]
set_location_assignment PIN_C27 -to si45_spi_in[0]
set_location_assignment PIN_K25 -to si45_spi_out[0]
set_location_assignment PIN_D26 -to si45_spi_sclk[0]
set_location_assignment PIN_A28 -to si45_fdec[0]
set_location_assignment PIN_B27 -to si45_finc[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_fdec[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_finc[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_intr_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_lol_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_oe_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_rst_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_cs_n[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_in[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_out[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_sclk[0]
set_location_assignment PIN_J24 -to si45_oe_n[1]
set_location_assignment PIN_A29 -to si45_intr_n[1]
set_location_assignment PIN_B28 -to si45_lol_n[1]
set_location_assignment PIN_H24 -to si45_rst_n[1]
set_location_assignment PIN_C28 -to si45_spi_cs_n[1]
set_location_assignment PIN_C26 -to si45_spi_in[1]
set_location_assignment PIN_D27 -to si45_spi_out[1]
set_location_assignment PIN_E25 -to si45_spi_sclk[1]
set_location_assignment PIN_F25 -to si45_fdec[1]
set_location_assignment PIN_G25 -to si45_finc[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_fdec[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_finc[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_intr_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_lol_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_oe_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_rst_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_cs_n[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_in[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_out[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to si45_spi_sclk[1]
set_location_assignment PIN_AD30 -to firefly1_rx_data
set_location_assignment PIN_AB30 -to firefly2_rx_data[0]
set_location_assignment PIN_Y30 -to firefly2_rx_data[1]
set_location_assignment PIN_V30 -to firefly2_rx_data[2]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_rx_data[2]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_rx_data[1]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly2_rx_data[0]
set_instance_assignment -name IO_STANDARD "1.5-V PCML" -to firefly1_rx_data
set_location_assignment PIN_AC25 -to firefly1_lvds_rx_in
set_instance_assignment -name IO_STANDARD LVDS -to firefly1_lvds_rx_in
set_location_assignment PIN_AF18 -to firefly2_lvds_rx_in
set_instance_assignment -name IO_STANDARD LVDS -to firefly2_lvds_rx_in
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to firefly1_lvds_rx_in
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to firefly2_lvds_rx_in
set_global_assignment -name DEVICE_MIGRATION_LIST "5AGXBA7D4F31C5,5AGXBB1D4F31C5,5AGXBA5D4F31C5"
set_instance_assignment -name IO_STANDARD LVDS -to transceiver_pll_clock[1]
set_location_assignment PIN_U22 -to transceiver_pll_clock[1]
set_location_assignment PIN_U23 -to "transceiver_pll_clock[1](n)"
set_instance_assignment -name IO_STANDARD LVDS -to transceiver_pll_clock[2]
set_location_assignment PIN_R22 -to transceiver_pll_clock[2]
set_location_assignment PIN_R23 -to "transceiver_pll_clock[2](n)"
set_location_assignment PIN_E4 -to PushButton[1]
set_location_assignment PIN_E3 -to PushButton[0]
set_location_assignment PIN_AG29 -to altera_reserved_tck
set_location_assignment PIN_AF29 -to altera_reserved_tdi
set_location_assignment PIN_AF30 -to altera_reserved_tdo
set_location_assignment PIN_AG30 -to altera_reserved_tms
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr_0[0]
set_instance_assignment -name IO_STANDARD "2.5 V" -to altera_reserved_tck
set_instance_assignment -name IO_STANDARD "2.5 V" -to altera_reserved_tdi
set_instance_assignment -name IO_STANDARD "2.5 V" -to altera_reserved_tdo
set_instance_assignment -name IO_STANDARD "2.5 V" -to altera_reserved_tms
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[7]
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[6]
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[5]
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[4]
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[3]
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[2]
set_instance_assignment -name IO_STANDARD "2.5 V" -to ref_adr[1]
set_location_assignment PIN_AD23 -to ref_adr[7]
set_location_assignment PIN_AE23 -to ref_adr[6]
set_location_assignment PIN_AK24 -to ref_adr[4]
set_location_assignment PIN_AJ24 -to ref_adr[5]
set_location_assignment PIN_AF24 -to ref_adr[3]
set_location_assignment PIN_AG24 -to ref_adr[2]
set_location_assignment PIN_AH25 -to ref_adr[1]
set_location_assignment PIN_AJ25 -to ref_adr[0]
set_location_assignment PIN_D23 -to board_select_n
set_instance_assignment -name IO_STANDARD LVDS -to lvds_firefly_clk
set_location_assignment PIN_AB25 -to "firefly1_lvds_rx_in(n)"
set_location_assignment PIN_AE18 -to "firefly2_lvds_rx_in(n)"
set_location_assignment PIN_AH26 -to lvds_firefly_clk
set_location_assignment PIN_AG26 -to "lvds_firefly_clk(n)"
set_location_assignment PIN_D20 -to lcd_csn
set_location_assignment PIN_B22 -to lcd_wen
set_location_assignment PIN_J21 -to lcd_d_cn
set_location_assignment PIN_B21 -to lcd_data[0]
set_location_assignment PIN_D21 -to lcd_data[1]
set_location_assignment PIN_H19 -to lcd_data[2]
set_location_assignment PIN_E22 -to lcd_data[3]
set_location_assignment PIN_E21 -to lcd_data[4]
set_location_assignment PIN_G19 -to lcd_data[5]
set_location_assignment PIN_A21 -to lcd_data[6]
set_location_assignment PIN_C20 -to lcd_data[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to board_select_n
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_csn
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_wen
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_d_cn
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[0]
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_sclk
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_mosi
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_miso
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_D1
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_D2
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_D3
set_instance_assignment -name IO_STANDARD "2.5 V" -to max10_spi_csn
set_location_assignment PIN_AK26 -to max10_spi_miso
set_location_assignment PIN_AK25 -to max10_spi_mosi
set_location_assignment PIN_AG28 -to max10_spi_csn
set_location_assignment PIN_AK27 -to max10_spi_sclk
set_location_assignment PIN_AJ28 -to max10_spi_D1
set_location_assignment PIN_AH28 -to max10_spi_D2
set_location_assignment PIN_AJ27 -to max10_spi_D3
set_location_assignment PIN_AK17 -to mscb_fpga_in
set_location_assignment PIN_AJ18 -to mscb_fpga_oe_n
set_location_assignment PIN_AH17 -to mscb_fpga_out
set_location_assignment PIN_F1 -to "spare_clk_osc(n)"
set_location_assignment PIN_AF28 -to fpga_reset
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_reset
