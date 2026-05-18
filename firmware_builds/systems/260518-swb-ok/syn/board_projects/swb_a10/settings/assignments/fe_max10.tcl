#

set_global_assignment -name FAMILY "MAX 10 FPGA"
set_global_assignment -name DEVICE 10M25SAE144C8G
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"



set_location_assignment PIN_41 -to fpga_conf_done
set_location_assignment PIN_39 -to fpga_clk
set_location_assignment PIN_44 -to fpga_nstatus
set_location_assignment PIN_60 -to fpga_data[0]
set_location_assignment PIN_59 -to fpga_data[1]
set_location_assignment PIN_54 -to fpga_data[2]
set_location_assignment PIN_52 -to fpga_data[3]
set_location_assignment PIN_50 -to fpga_data[4]
set_location_assignment PIN_47 -to fpga_data[5]
set_location_assignment PIN_46 -to fpga_data[6]
set_location_assignment PIN_45 -to fpga_data[7]
set_location_assignment PIN_76 -to flash_csn
set_location_assignment PIN_85 -to flash_sck
set_location_assignment PIN_74 -to flash_io0
set_location_assignment PIN_78 -to flash_io1
set_location_assignment PIN_79 -to flash_io2
set_location_assignment PIN_84 -to flash_io3
set_location_assignment PIN_18 -to altera_reserved_tck
set_location_assignment PIN_19 -to altera_reserved_tdi
set_location_assignment PIN_20 -to altera_reserved_tdo
set_location_assignment PIN_16 -to altera_reserved_tms
set_location_assignment PIN_27 -to max10_osc_clk
set_location_assignment PIN_26 -to "max10_osc_clk(n)"
set_location_assignment PIN_29 -to max10_si_clk
set_location_assignment PIN_28 -to "max10_si_clk(n)"
set_location_assignment PIN_91 -to fpga_mscb_oe
set_location_assignment PIN_92 -to mscb_ena
set_location_assignment PIN_93 -to mscb_in
set_location_assignment PIN_96 -to mscb_out
set_location_assignment PIN_141 -to fpga_spi_clk
set_location_assignment PIN_140 -to fpga_spi_csn
set_location_assignment PIN_135 -to fpga_spi_D1
set_location_assignment PIN_132 -to fpga_spi_D2
set_location_assignment PIN_131 -to fpga_spi_D3
set_location_assignment PIN_130 -to fpga_spi_miso
set_location_assignment PIN_127 -to fpga_spi_mosi
set_location_assignment PIN_118 -to reset_fpga_bp_n
set_location_assignment PIN_43 -to fpga_nconfig
set_location_assignment PIN_119 -to reset_cpu_backplane_n
set_location_assignment PIN_38 -to board_select
set_location_assignment PIN_111 -to spare[0]
set_location_assignment PIN_100 -to spare[2]
set_location_assignment PIN_113 -to bp_mode_select[0]
set_location_assignment PIN_114 -to bp_mode_select[1]
set_location_assignment PIN_110 -to bp_spi_clk
set_location_assignment PIN_106 -to bp_spi_csn
set_location_assignment PIN_105 -to bp_spi_miso
set_location_assignment PIN_101 -to bp_spi_miso_en
set_location_assignment PIN_102 -to bp_spi_mosi
set_location_assignment PIN_62 -to spi_adr[0]
set_location_assignment PIN_64 -to spi_adr[1]
set_location_assignment PIN_65 -to spi_adr[2]
set_location_assignment PIN_66 -to attention_n[0]
set_location_assignment PIN_69 -to attention_n[1]
set_location_assignment PIN_70 -to spare[1]
set_location_assignment PIN_75 -to ref_addr[0]
set_location_assignment PIN_77 -to ref_addr[1]
set_location_assignment PIN_80 -to ref_addr[2]
set_location_assignment PIN_81 -to ref_addr[3]
set_location_assignment PIN_86 -to ref_addr[4]
set_location_assignment PIN_87 -to ref_addr[5]
set_location_assignment PIN_88 -to ref_addr[6]
set_location_assignment PIN_89 -to ref_addr[7]
set_location_assignment PIN_124 -to fpga_reset
set_location_assignment PIN_97 -to reset_max_bp_n
set_location_assignment PIN_99 -to temp_sens_dis

set_instance_assignment -name IO_STANDARD LVDS -to max10_osc_clk
set_instance_assignment -name IO_STANDARD LVDS -to max10_si_clk
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_clk
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_csn
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_D1
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_D2
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_D3
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_miso
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_spi_mosi
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_reset_n
set_instance_assignment -name IO_STANDARD "2.5 V" -to fpga_reset
