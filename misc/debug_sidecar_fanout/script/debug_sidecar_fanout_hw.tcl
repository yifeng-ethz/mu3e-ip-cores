################################################################################
# debug_sidecar_fanout
# Four-way DEBUG hit metadata conduit fanout for Platform Designer systems.
################################################################################

package require -exact qsys 16.1

set_module_property NAME debug_sidecar_fanout
set_module_property VERSION 26.0.0.0506
set_module_property DISPLAY_NAME "DEBUG Sidecar Fanout"
set_module_property GROUP "Mu3e Data Plane/Utility"
set_module_property DESCRIPTION "Four-way combinational fanout for 64-bit DEBUG hit metadata conduits."
set_module_property AUTHOR "OpenAI Codex"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property INTERNAL false
set_module_property HIDE_FROM_SOPC false
set_module_property VALIDATION_CALLBACK validate

add_parameter DATA_WIDTH NATURAL 64
set_parameter_property DATA_WIDTH DISPLAY_NAME "Metadata Width"
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES {64}
set_parameter_property DATA_WIDTH DESCRIPTION "Width of the metadata sidecar bus."

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL debug_sidecar_fanout
add_fileset_file debug_sidecar_fanout.sv SYSTEM_VERILOG PATH ../rtl/debug_sidecar_fanout.sv TOP_LEVEL_FILE

add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
add_interface_port clock i_clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
add_interface_port reset i_rst reset Input 1

proc validate {} {
    set data_width [get_parameter_value DATA_WIDTH]
    if {$data_width != 64} {
        send_message error "DATA_WIDTH must be 64."
    }
}

add_interface in conduit end
set_interface_property in associatedClock clock
set_interface_property in associatedReset reset
set_interface_property in ENABLED true
add_interface_port in coe_in_metadata metadata Input 64
add_interface_port in coe_in_valid valid Input 1

add_interface out0 conduit start
set_interface_property out0 associatedClock clock
set_interface_property out0 associatedReset reset
set_interface_property out0 ENABLED true
add_interface_port out0 coe_out0_metadata metadata Output 64
add_interface_port out0 coe_out0_valid valid Output 1

add_interface out1 conduit start
set_interface_property out1 associatedClock clock
set_interface_property out1 associatedReset reset
set_interface_property out1 ENABLED true
add_interface_port out1 coe_out1_metadata metadata Output 64
add_interface_port out1 coe_out1_valid valid Output 1

add_interface out2 conduit start
set_interface_property out2 associatedClock clock
set_interface_property out2 associatedReset reset
set_interface_property out2 ENABLED true
add_interface_port out2 coe_out2_metadata metadata Output 64
add_interface_port out2 coe_out2_valid valid Output 1

add_interface out3 conduit start
set_interface_property out3 associatedClock clock
set_interface_property out3 associatedReset reset
set_interface_property out3 ENABLED true
add_interface_port out3 coe_out3_metadata metadata Output 64
add_interface_port out3 coe_out3_valid valid Output 1
