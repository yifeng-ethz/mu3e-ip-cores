# (C) 2001-2018 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


set altera_lvds_libs_dir "$env(QUARTUS_ROOTDIR)/../ip/altera/altera_lvds/util"
if {[lsearch -exact $auto_path $altera_lvds_libs_dir] == -1} {
	lappend auto_path $altera_lvds_libs_dir
}

set altera_emif_libs_dir "$env(QUARTUS_ROOTDIR)/../ip/altera/emif/util"
if {[lsearch -exact $auto_path $altera_emif_libs_dir] == -1} {
	lappend auto_path $altera_emif_libs_dir
}

lappend auto_path $env(QUARTUS_ROOTDIR)/../ip/altera/alt_xcvr/alt_xcvr_tcl_packages
lappend auto_path $env(QUARTUS_ROOTDIR)/../ip/altera/altera_iopll_common
lappend auto_path $env(QUARTUS_ROOTDIR)/../ip/altera/alt_xcvr/alt_xcvr_core/nf


package require -exact qsys 15.0
package require altera_lvds::core_14::main 


set_module_property DESCRIPTION "Altlvds 14NM Core"
set_module_property NAME altera_lvds_core14
set_module_property VERSION 18.1
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "I/O"
set_module_property AUTHOR "Altera Corporation"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true

set_module_property HIDE_FROM_QSYS true
set_module_property HIDE_FROM_SOPC true
set_module_property INTERNAL true


::altera_lvds::core_14::main::create_parameters 

set_module_property ELABORATION_CALLBACK ::altera_lvds::core_14::main::elaboration_callback

add_fileset sim_verilog SIM_VERILOG ::altera_lvds::core_14::main::sim_verilog_fileset_callback

add_fileset quartus_synth QUARTUS_SYNTH ::altera_lvds::core_14::main::quartus_synth_fileset_callback

add_fileset sim_vhdl SIM_VHDL ::altera_lvds::core_14::main::sim_vhdl_fileset_callback



