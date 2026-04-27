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


set altera_lvds_tcl_libs_dir "$env(QUARTUS_ROOTDIR)/../ip/altera/altera_lvds/util"
if {[lsearch -exact $auto_path $altera_lvds_tcl_libs_dir] == -1} {
	lappend auto_path $altera_lvds_tcl_libs_dir
}

set altera_emif_tcl_libs_dir "$env(QUARTUS_ROOTDIR)/../ip/altera/emif/util"
if {[lsearch -exact $auto_path $altera_emif_tcl_libs_dir] == -1} {
	lappend auto_path $altera_emif_tcl_libs_dir
}

lappend auto_path $env(QUARTUS_ROOTDIR)/../ip/altera/alt_xcvr/alt_xcvr_tcl_packages
lappend auto_path $env(QUARTUS_ROOTDIR)/../ip/altera/altera_iopll_common
lappend auto_path $env(QUARTUS_ROOTDIR)/../ip/altera/alt_xcvr/alt_xcvr_core/nf

package require -exact qsys 15.0


package require altera_lvds::top::main
package require altera_lvds::top::ex_design

load_strings gui.properties

set_module_property DESCRIPTION [get_string HWTCL_MODULE_DESCRIPTION]
set_module_property NAME altera_lvds_mu3e
set_module_property VERSION 18.1
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property DISPLAY_NAME [get_string HWTCL_MODULE_DISPLAY_NAME]
set_module_property GROUP "Basic Functions/I\/O"
set_module_property AUTHOR "Intel Corporation"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property SUPPORTED_DEVICE_FAMILIES {{Arria 10} {Stratix 10}}
set_module_property HIDE_FROM_SOPC false
set_module_property HIDE_FROM_QSYS false
set_module_property EDITABLE true

add_documentation_link "Intel LVDS user guide" http://www.altera.com/literature/ug/ug_altera_lvds.pdf

set_module_property SUPPRESS_WARNINGS NO_PORTS_AFTER_ELABORATION

set_module_property COMPOSITION_CALLBACK ::altera_lvds::top::main::composition_callback
set_module_property VALIDATION_CALLBACK ::altera_lvds::top::main::validation_callback 
add_fileset example_design EXAMPLE_DESIGN ::altera_lvds::top::ex_design::example_design_fileset_callback 
set_module_property PARAMETER_UPGRADE_CALLBACK ::altera_lvds::top::main::parameter_upgrade_callback


::altera_lvds::top::main::create_parameters 
::altera_lvds::top::main::add_display_items


add_documentation_link "User Guide" "https://documentation.altera.com/#/link/sam1412665235337/sam1412665036681"
add_documentation_link "Release Notes" "https://documentation.altera.com/#/link/hco1421698042087/hco1421698013408"
