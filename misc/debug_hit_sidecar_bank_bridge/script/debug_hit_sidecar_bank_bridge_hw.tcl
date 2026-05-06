################################################################################
# debug_hit_sidecar_bank_bridge
# Metadata sidecar aligner for a 4-input hit_type0 mux bank.
################################################################################

package require -exact qsys 16.1

set_module_property NAME debug_hit_sidecar_bank_bridge
set_module_property VERSION 26.0.0.0506
set_module_property DISPLAY_NAME "DEBUG Hit Sidecar Bank Bridge"
set_module_property GROUP "Mu3e Data Plane/Utility"
set_module_property DESCRIPTION "Queues four lane-local 64-bit DEBUG metadata conduits and emits the metadata aligned with a 4-input hit_type0 mux output."
set_module_property AUTHOR "OpenAI Codex"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property INTERNAL false
set_module_property HIDE_FROM_SOPC false
set_module_property VALIDATION_CALLBACK validate

add_parameter DATA_WIDTH NATURAL 45
set_parameter_property DATA_WIDTH DISPLAY_NAME "Hit Data Width"
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES {45}

add_parameter CHANNEL_WIDTH NATURAL 6
set_parameter_property CHANNEL_WIDTH DISPLAY_NAME "Mux Channel Width"
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES {6}

add_parameter ERROR_WIDTH NATURAL 3
set_parameter_property ERROR_WIDTH DISPLAY_NAME "Error Width"
set_parameter_property ERROR_WIDTH HDL_PARAMETER true
set_parameter_property ERROR_WIDTH ALLOWED_RANGES {3}

add_parameter METADATA_WIDTH NATURAL 64
set_parameter_property METADATA_WIDTH DISPLAY_NAME "Metadata Width"
set_parameter_property METADATA_WIDTH HDL_PARAMETER true
set_parameter_property METADATA_WIDTH ALLOWED_RANGES {64}

add_parameter FIFO_DEPTH NATURAL 256
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Per-Lane Metadata FIFO Depth"
set_parameter_property FIFO_DEPTH HDL_PARAMETER true
set_parameter_property FIFO_DEPTH ALLOWED_RANGES {64 128 256 512}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL debug_hit_sidecar_bank_bridge
add_fileset_file debug_hit_sidecar_bank_bridge.sv SYSTEM_VERILOG PATH ../rtl/debug_hit_sidecar_bank_bridge.sv TOP_LEVEL_FILE

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
    if {[get_parameter_value DATA_WIDTH] != 45} {
        send_message error "DATA_WIDTH must be 45."
    }
    if {[get_parameter_value CHANNEL_WIDTH] != 6} {
        send_message error "CHANNEL_WIDTH must be 6."
    }
    if {[get_parameter_value ERROR_WIDTH] != 3} {
        send_message error "ERROR_WIDTH must be 3."
    }
    if {[get_parameter_value METADATA_WIDTH] != 64} {
        send_message error "METADATA_WIDTH must be 64."
    }
}

proc add_hit_type0_sink {name} {
    add_interface $name avalon_streaming end
    set_interface_property $name associatedClock clock
    set_interface_property $name associatedReset reset
    set_interface_property $name dataBitsPerSymbol 45
    set_interface_property $name firstSymbolInHighOrderBits true
    set_interface_property $name maxChannel 63
    set_interface_property $name readyLatency 0
    set_interface_property $name errorDescriptor ""
    set_interface_property $name ENABLED true
    add_interface_port $name asi_hit_type0_data          data          Input 45
    add_interface_port $name asi_hit_type0_valid         valid         Input 1
    add_interface_port $name asi_hit_type0_ready         ready         Output 1
    add_interface_port $name asi_hit_type0_error         error         Input 3
    add_interface_port $name asi_hit_type0_channel       channel       Input 6
    add_interface_port $name asi_hit_type0_startofpacket startofpacket Input 1
    add_interface_port $name asi_hit_type0_endofpacket   endofpacket   Input 1
    add_interface_port $name asi_hit_type0_endofrun      endofrun      Input 1
}

proc add_hit_type0_source {name} {
    add_interface $name avalon_streaming start
    set_interface_property $name associatedClock clock
    set_interface_property $name associatedReset reset
    set_interface_property $name dataBitsPerSymbol 45
    set_interface_property $name firstSymbolInHighOrderBits true
    set_interface_property $name maxChannel 63
    set_interface_property $name readyLatency 0
    set_interface_property $name errorDescriptor ""
    set_interface_property $name ENABLED true
    add_interface_port $name aso_hit_type0_data          data          Output 45
    add_interface_port $name aso_hit_type0_valid         valid         Output 1
    add_interface_port $name aso_hit_type0_ready         ready         Input 1
    add_interface_port $name aso_hit_type0_error         error         Output 3
    add_interface_port $name aso_hit_type0_channel       channel       Output 6
    add_interface_port $name aso_hit_type0_startofpacket startofpacket Output 1
    add_interface_port $name aso_hit_type0_endofpacket   endofpacket   Output 1
    add_interface_port $name aso_hit_type0_endofrun      endofrun      Output 1
}

proc add_sidecar_output {name} {
    add_interface $name conduit start
    set_interface_property $name associatedClock clock
    set_interface_property $name associatedReset reset
    set_interface_property $name ENABLED true
    add_interface_port $name coe_hit_type0_sidecar_metadata metadata Output 64
    add_interface_port $name coe_hit_type0_sidecar_valid    valid    Output 1
}

add_hit_type0_sink hit_type0_in
add_hit_type0_source hit_type0_out

add_interface lane0 conduit end
set_interface_property lane0 associatedClock clock
set_interface_property lane0 associatedReset reset
set_interface_property lane0 ENABLED true
add_interface_port lane0 coe_lane0_metadata metadata Input 64
add_interface_port lane0 coe_lane0_valid valid Input 1

add_interface lane1 conduit end
set_interface_property lane1 associatedClock clock
set_interface_property lane1 associatedReset reset
set_interface_property lane1 ENABLED true
add_interface_port lane1 coe_lane1_metadata metadata Input 64
add_interface_port lane1 coe_lane1_valid valid Input 1

add_interface lane2 conduit end
set_interface_property lane2 associatedClock clock
set_interface_property lane2 associatedReset reset
set_interface_property lane2 ENABLED true
add_interface_port lane2 coe_lane2_metadata metadata Input 64
add_interface_port lane2 coe_lane2_valid valid Input 1

add_interface lane3 conduit end
set_interface_property lane3 associatedClock clock
set_interface_property lane3 associatedReset reset
set_interface_property lane3 ENABLED true
add_interface_port lane3 coe_lane3_metadata metadata Input 64
add_interface_port lane3 coe_lane3_valid valid Input 1

add_sidecar_output hit_type0_sidecar
