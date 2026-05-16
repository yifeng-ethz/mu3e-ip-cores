package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         516
set VERSION_DATE_DEFAULT_CONST  20260516

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         avst_inactive_source
set_module_property DISPLAY_NAME                 "Avalon-ST Inactive Source"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Constant-valid-low Avalon-ST source for explicit Platform Designer stream tie-off."
set_module_property GROUP                        "Mu3e Data Plane/Modules"
set_module_property AUTHOR                       "OpenAI Codex"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false
set_module_property VALIDATION_CALLBACK          validate
set_module_property ELABORATION_CALLBACK         elaborate

proc validate {} {
    foreach param {DATA_WIDTH CHANNEL_WIDTH} {
        if {[get_parameter_value $param] < 1} {
            send_message error "$param must be at least 1"
        }
    }
}

proc elaborate {} {
    set data_width [get_parameter_value DATA_WIDTH]
    set channel_width [get_parameter_value CHANNEL_WIDTH]
    set max_channel [expr {(1 << $channel_width) - 1}]

    set_interface_property out dataBitsPerSymbol $data_width
    set_interface_property out symbolsPerBeat 1
    set_interface_property out maxChannel $max_channel
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL avst_inactive_source
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file avst_inactive_source.sv SYSTEM_VERILOG PATH rtl/avst_inactive_source.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL avst_inactive_source
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file avst_inactive_source.sv SYSTEM_VERILOG PATH rtl/avst_inactive_source.sv TOP_LEVEL_FILE

add_parameter DATA_WIDTH NATURAL 39
set_parameter_property DATA_WIDTH DISPLAY_NAME "Data Width"
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES 1:4096

add_parameter CHANNEL_WIDTH NATURAL 4
set_parameter_property CHANNEL_WIDTH DISPLAY_NAME "Channel Width"
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES 1:64

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

add_interface out avalon_streaming source
set_interface_property out associatedClock clk
set_interface_property out associatedReset rst
set_interface_property out dataBitsPerSymbol 39
set_interface_property out symbolsPerBeat 1
set_interface_property out readyLatency 0
set_interface_property out maxChannel 15
set_interface_property out firstSymbolInHighOrderBits true
set_interface_property out ENABLED true
add_interface_port out aso_data data Output DATA_WIDTH
add_interface_port out aso_valid valid Output 1
add_interface_port out aso_ready ready Input 1
add_interface_port out aso_startofpacket startofpacket Output 1
add_interface_port out aso_endofpacket endofpacket Output 1
add_interface_port out aso_channel channel Output CHANNEL_WIDTH
