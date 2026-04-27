package require -exact qsys 16.1

set_module_property NAME inactive_reset_source
set_module_property DISPLAY_NAME "Inactive Reset Source"
set_module_property VERSION 26.0.0.0425
set_module_property DESCRIPTION "Constant inactive reset source for Platform Designer reset sink tie-off."
set_module_property GROUP "Mu3e Utility/Modules"
set_module_property AUTHOR "OpenAI Codex"
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL inactive_reset_source
add_fileset_file inactive_reset_source.sv SYSTEM_VERILOG PATH inactive_reset_source.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL inactive_reset_source
add_fileset_file inactive_reset_source.sv SYSTEM_VERILOG PATH inactive_reset_source.sv TOP_LEVEL_FILE

add_interface clk clock end
set_interface_property clk clockRate 0
add_interface_port clk csi_clk clk Input 1

add_interface reset reset start
set_interface_property reset associatedClock ""
set_interface_property reset synchronousEdges NONE
add_interface_port reset rso_reset reset Output 1
