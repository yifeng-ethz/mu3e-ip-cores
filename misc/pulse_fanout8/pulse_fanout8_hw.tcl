package require -exact qsys 16.1

set_module_property NAME pulse_fanout8
set_module_property DISPLAY_NAME "Pulse Fanout x8"
set_module_property VERSION 1.0
set_module_property DESCRIPTION "Simple 1-to-8 conduit pulse fanout helper."
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
set_fileset_property QUARTUS_SYNTH TOP_LEVEL pulse_fanout8
add_fileset_file pulse_fanout8.sv SYSTEM_VERILOG PATH pulse_fanout8.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL pulse_fanout8
add_fileset_file pulse_fanout8.sv SYSTEM_VERILOG PATH pulse_fanout8.sv TOP_LEVEL_FILE

add_interface clk clock end
set_interface_property clk clockRate 0
add_interface_port clk csi_clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clk
set_interface_property reset synchronousEdges BOTH
add_interface_port reset rsi_reset reset Input 1

add_interface inject_in conduit end
set_interface_property inject_in associatedClock clk
set_interface_property inject_in associatedReset reset
add_interface_port inject_in coe_inject_pulse pulse Input 1

add_interface inject_aux_in conduit end
set_interface_property inject_aux_in associatedClock ""
set_interface_property inject_aux_in associatedReset ""
add_interface_port inject_aux_in coe_aux_inject_pulse pulse Input 1

add_interface out0 conduit start
set_interface_property out0 associatedClock clk
set_interface_property out0 associatedReset reset
add_interface_port out0 coe_out0_pulse pulse Output 1
add_interface_port out0 coe_out0_masked_pulse masked_pulse Output 1

add_interface out1 conduit start
set_interface_property out1 associatedClock clk
set_interface_property out1 associatedReset reset
add_interface_port out1 coe_out1_pulse pulse Output 1
add_interface_port out1 coe_out1_masked_pulse masked_pulse Output 1

add_interface out2 conduit start
set_interface_property out2 associatedClock clk
set_interface_property out2 associatedReset reset
add_interface_port out2 coe_out2_pulse pulse Output 1
add_interface_port out2 coe_out2_masked_pulse masked_pulse Output 1

add_interface out3 conduit start
set_interface_property out3 associatedClock clk
set_interface_property out3 associatedReset reset
add_interface_port out3 coe_out3_pulse pulse Output 1
add_interface_port out3 coe_out3_masked_pulse masked_pulse Output 1

add_interface out4 conduit start
set_interface_property out4 associatedClock clk
set_interface_property out4 associatedReset reset
add_interface_port out4 coe_out4_pulse pulse Output 1
add_interface_port out4 coe_out4_masked_pulse masked_pulse Output 1

add_interface out5 conduit start
set_interface_property out5 associatedClock clk
set_interface_property out5 associatedReset reset
add_interface_port out5 coe_out5_pulse pulse Output 1
add_interface_port out5 coe_out5_masked_pulse masked_pulse Output 1

add_interface out6 conduit start
set_interface_property out6 associatedClock clk
set_interface_property out6 associatedReset reset
add_interface_port out6 coe_out6_pulse pulse Output 1
add_interface_port out6 coe_out6_masked_pulse masked_pulse Output 1

add_interface out7 conduit start
set_interface_property out7 associatedClock clk
set_interface_property out7 associatedReset reset
add_interface_port out7 coe_out7_pulse pulse Output 1
add_interface_port out7 coe_out7_masked_pulse masked_pulse Output 1

add_interface out8 conduit start
set_interface_property out8 associatedClock clk
set_interface_property out8 associatedReset reset
add_interface_port out8 coe_out8_pulse pulse Output 1
add_interface_port out8 coe_out8_masked_pulse masked_pulse Output 1
