package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         517
set VERSION_DATE_DEFAULT_CONST  20260517

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         hit_type0_tap2
set_module_property DISPLAY_NAME                 "hit_type0 Two-Way Tap"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Readyless two-way Avalon-ST hit_type0 tap for direct histogram input."
set_module_property GROUP                        "Mu3e Data Plane/Utility"
set_module_property AUTHOR                       "OpenAI Codex"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false
set_module_property VALIDATION_CALLBACK          validate

proc validate {} {
    foreach {name expected} {DATA_WIDTH 45 CHANNEL_WIDTH 4 ERROR_WIDTH 3} {
        if {[get_parameter_value $name] != $expected} {
            send_message error "$name must be $expected for FEB hit_type0."
        }
    }
}

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL hit_type0_tap2
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type0_tap2.sv SYSTEM_VERILOG PATH ../rtl/hit_type0_tap2.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL hit_type0_tap2
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type0_tap2.sv SYSTEM_VERILOG PATH ../rtl/hit_type0_tap2.sv TOP_LEVEL_FILE

add_parameter DATA_WIDTH NATURAL 45
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES {45}

add_parameter CHANNEL_WIDTH NATURAL 4
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES {4}

add_parameter ERROR_WIDTH NATURAL 3
set_parameter_property ERROR_WIDTH HDL_PARAMETER true
set_parameter_property ERROR_WIDTH ALLOWED_RANGES {3}

add_display_item "" "Configuration" GROUP tab
add_display_item "" "Identity" GROUP tab
add_display_item "" "Interfaces" GROUP tab
add_display_item "" "Register Map" GROUP tab
add_display_item "Configuration" "Datapath" GROUP
add_html_text "Datapath" overview_html {<html><b>Purpose</b><br/>Replicates one FEB hit_type0 selected lane to its primary MTS mux path and to one direct histogram Type0 lane. The stream is readyless so the histogram observation path cannot backpressure the selected lane.</html>}
add_display_item "Datapath" DATA_WIDTH parameter
add_display_item "Datapath" CHANNEL_WIDTH parameter
add_display_item "Datapath" ERROR_WIDTH parameter
add_display_item "Identity" "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This IP is packaged as <b>%s</b>. It has no CSR aperture.</html>} $VERSION_STRING_DEFAULT_CONST]
add_display_item "Interfaces" "Streams" GROUP
add_html_text "Streams" streams_html {<html><b>in</b><br/>45-bit FEB hit_type0 stream with valid, SOP, EOP, endofrun, channel[3:0], and error[2:0].<br/><br/><b>primary</b><br/>Replicated readyless output to the existing MTS mux path.<br/><br/><b>hist</b><br/>Replicated readyless output to the direct histogram Type0 lane sink.</html>}
add_display_item "Register Map" "CSR Window" GROUP
add_html_text "CSR Window" csr_html {<html>No software-visible registers.</html>}

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk csi_clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rsi_reset reset Input 1

add_interface in avalon_streaming sink
set_interface_property in associatedClock clk
set_interface_property in associatedReset rst
set_interface_property in dataBitsPerSymbol 45
set_interface_property in symbolsPerBeat 1
set_interface_property in readyLatency 0
set_interface_property in maxChannel 15
set_interface_property in firstSymbolInHighOrderBits true
set_interface_property in errorDescriptor "hiterr frameerr overflow"
set_interface_property in ENABLED true
add_interface_port in asi_in_data          data          Input 45
add_interface_port in asi_in_valid         valid         Input 1
add_interface_port in asi_in_error         error         Input 3
add_interface_port in asi_in_channel       channel       Input 4
add_interface_port in asi_in_startofpacket startofpacket Input 1
add_interface_port in asi_in_endofpacket   endofpacket   Input 1
add_interface_port in asi_in_endofrun      endofrun      Input 1

add_interface primary avalon_streaming source
set_interface_property primary associatedClock clk
set_interface_property primary associatedReset rst
set_interface_property primary dataBitsPerSymbol 45
set_interface_property primary symbolsPerBeat 1
set_interface_property primary readyLatency 0
set_interface_property primary maxChannel 15
set_interface_property primary firstSymbolInHighOrderBits true
set_interface_property primary errorDescriptor "hiterr frameerr overflow"
set_interface_property primary ENABLED true
add_interface_port primary aso_primary_data          data          Output 45
add_interface_port primary aso_primary_valid         valid         Output 1
add_interface_port primary aso_primary_error         error         Output 3
add_interface_port primary aso_primary_channel       channel       Output 4
add_interface_port primary aso_primary_startofpacket startofpacket Output 1
add_interface_port primary aso_primary_endofpacket   endofpacket   Output 1
add_interface_port primary aso_primary_endofrun      endofrun      Output 1

add_interface hist avalon_streaming source
set_interface_property hist associatedClock clk
set_interface_property hist associatedReset rst
set_interface_property hist dataBitsPerSymbol 45
set_interface_property hist symbolsPerBeat 1
set_interface_property hist readyLatency 0
set_interface_property hist maxChannel 15
set_interface_property hist firstSymbolInHighOrderBits true
set_interface_property hist errorDescriptor "hiterr frameerr overflow"
set_interface_property hist ENABLED true
add_interface_port hist aso_hist_data          data          Output 45
add_interface_port hist aso_hist_valid         valid         Output 1
add_interface_port hist aso_hist_error         error         Output 3
add_interface_port hist aso_hist_channel       channel       Output 4
add_interface_port hist aso_hist_startofpacket startofpacket Output 1
add_interface_port hist aso_hist_endofpacket   endofpacket   Output 1
add_interface_port hist aso_hist_endofrun      endofrun      Output 1
