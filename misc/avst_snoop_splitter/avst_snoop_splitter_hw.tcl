package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         502
set VERSION_DATE_DEFAULT_CONST  20260502

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         avst_snoop_splitter
set_module_property DISPLAY_NAME                 "Avalon-ST Snoop Splitter"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Nonblocking Avalon-ST snoop splitter Mu3e IP Core"
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
    foreach param {DATA_WIDTH CHANNEL_WIDTH EMPTY_WIDTH ERROR_WIDTH} {
        if {[get_parameter_value $param] < 1} {
            send_message error "$param must be at least 1"
        }
    }
}

proc elaborate {} {
    set data_width [get_parameter_value DATA_WIDTH]
    set channel_width [get_parameter_value CHANNEL_WIDTH]
    set max_channel [expr {(1 << $channel_width) - 1}]

    foreach stream_if {in out0 out1} {
        set_interface_property $stream_if dataBitsPerSymbol $data_width
        set_interface_property $stream_if symbolsPerBeat 1
        set_interface_property $stream_if maxChannel $max_channel
    }
}

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL avst_snoop_splitter
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file avst_snoop_splitter.sv SYSTEM_VERILOG PATH rtl/avst_snoop_splitter.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL avst_snoop_splitter
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file avst_snoop_splitter.sv SYSTEM_VERILOG PATH rtl/avst_snoop_splitter.sv TOP_LEVEL_FILE

add_parameter DATA_WIDTH NATURAL 36
set_parameter_property DATA_WIDTH DISPLAY_NAME "Data Width"
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES 1:4096

add_parameter CHANNEL_WIDTH NATURAL 4
set_parameter_property CHANNEL_WIDTH DISPLAY_NAME "Channel Width"
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES 1:64

add_parameter EMPTY_WIDTH NATURAL 1
set_parameter_property EMPTY_WIDTH DISPLAY_NAME "Empty Width"
set_parameter_property EMPTY_WIDTH HDL_PARAMETER true
set_parameter_property EMPTY_WIDTH ALLOWED_RANGES 1:8

add_parameter ERROR_WIDTH NATURAL 1
set_parameter_property ERROR_WIDTH DISPLAY_NAME "Error Width"
set_parameter_property ERROR_WIDTH HDL_PARAMETER true
set_parameter_property ERROR_WIDTH ALLOWED_RANGES 1:32

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_display_item $TAB_CONFIGURATION "Sizing" GROUP
add_html_text "Overview" overview_html {<html><b>Nonblocking diagnostic split</b><br/>The input stream is forwarded through <b>out0</b> with the normal ready handshake. <b>out1</b> mirrors the same beat fields for SignalTap, histogram snoop, or other monitors, but its ready input is ignored.</html>}
add_display_item "Sizing" DATA_WIDTH parameter
add_display_item "Sizing" CHANNEL_WIDTH parameter
add_display_item "Sizing" EMPTY_WIDTH parameter
add_display_item "Sizing" ERROR_WIDTH parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>.<br/><br/>This IP has no software-visible CSR aperture; version identity is Platform Designer metadata only.</html>} $VERSION_STRING_DEFAULT_CONST]

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Streams" GROUP
add_html_text "Clock / Reset" clock_html {<html><b>clk/rst</b><br/>Included for Platform Designer clock-domain association. The splitter is combinational and owns no state.</html>}
add_html_text "Streams" streams_html {<html><b>in</b><br/>Observed Avalon-ST stream.<br/><br/><b>out0</b><br/>Primary stream. Its ready drives input ready.<br/><br/><b>out1</b><br/>Snoop stream. Data, valid, packet, empty, channel, and error mirror the input; ready is ignored.</html>}

add_display_item "" $TAB_REGMAP GROUP tab
add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_html {<html>No CSR window.</html>}

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

add_interface in avalon_streaming sink
set_interface_property in associatedClock clk
set_interface_property in associatedReset rst
set_interface_property in dataBitsPerSymbol 36
set_interface_property in symbolsPerBeat 1
set_interface_property in readyLatency 0
set_interface_property in maxChannel 15
set_interface_property in firstSymbolInHighOrderBits true
set_interface_property in errorDescriptor "stream_error"
set_interface_property in ENABLED true
add_interface_port in asi_data data Input DATA_WIDTH
add_interface_port in asi_valid valid Input 1
add_interface_port in asi_ready ready Output 1
add_interface_port in asi_startofpacket startofpacket Input 1
add_interface_port in asi_endofpacket endofpacket Input 1
add_interface_port in asi_empty empty Input EMPTY_WIDTH
add_interface_port in asi_channel channel Input CHANNEL_WIDTH
add_interface_port in asi_error error Input ERROR_WIDTH

add_interface out0 avalon_streaming source
set_interface_property out0 associatedClock clk
set_interface_property out0 associatedReset rst
set_interface_property out0 dataBitsPerSymbol 36
set_interface_property out0 symbolsPerBeat 1
set_interface_property out0 readyLatency 0
set_interface_property out0 maxChannel 15
set_interface_property out0 firstSymbolInHighOrderBits true
set_interface_property out0 errorDescriptor "stream_error"
set_interface_property out0 ENABLED true
add_interface_port out0 aso_out0_data data Output DATA_WIDTH
add_interface_port out0 aso_out0_valid valid Output 1
add_interface_port out0 aso_out0_ready ready Input 1
add_interface_port out0 aso_out0_startofpacket startofpacket Output 1
add_interface_port out0 aso_out0_endofpacket endofpacket Output 1
add_interface_port out0 aso_out0_empty empty Output EMPTY_WIDTH
add_interface_port out0 aso_out0_channel channel Output CHANNEL_WIDTH
add_interface_port out0 aso_out0_error error Output ERROR_WIDTH

add_interface out1 avalon_streaming source
set_interface_property out1 associatedClock clk
set_interface_property out1 associatedReset rst
set_interface_property out1 dataBitsPerSymbol 36
set_interface_property out1 symbolsPerBeat 1
set_interface_property out1 readyLatency 0
set_interface_property out1 maxChannel 15
set_interface_property out1 firstSymbolInHighOrderBits true
set_interface_property out1 errorDescriptor "stream_error"
set_interface_property out1 ENABLED true
add_interface_port out1 aso_out1_data data Output DATA_WIDTH
add_interface_port out1 aso_out1_valid valid Output 1
add_interface_port out1 aso_out1_ready ready Input 1
add_interface_port out1 aso_out1_startofpacket startofpacket Output 1
add_interface_port out1 aso_out1_endofpacket endofpacket Output 1
add_interface_port out1 aso_out1_empty empty Output EMPTY_WIDTH
add_interface_port out1 aso_out1_channel channel Output CHANNEL_WIDTH
add_interface_port out1 aso_out1_error error Output ERROR_WIDTH
