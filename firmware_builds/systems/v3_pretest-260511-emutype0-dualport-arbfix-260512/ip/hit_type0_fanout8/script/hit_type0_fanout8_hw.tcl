package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         512
set VERSION_DATE_DEFAULT_CONST  20260512

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         hit_type0_fanout8
set_module_property DISPLAY_NAME                 "hit_type0 Fanout 8"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Build-local eight-way Avalon-ST hit_type0 fanout that preserves endofrun."
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

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

proc validate {} {
    foreach {name expected} {DATA_WIDTH 45 CHANNEL_WIDTH 4 ERROR_WIDTH 3} {
        if {[get_parameter_value $name] != $expected} {
            send_message error "$name must be $expected for FEB hit_type0."
        }
    }
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL hit_type0_fanout8
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type0_fanout8.sv SYSTEM_VERILOG PATH ../rtl/hit_type0_fanout8.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL hit_type0_fanout8
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type0_fanout8.sv SYSTEM_VERILOG PATH ../rtl/hit_type0_fanout8.sv TOP_LEVEL_FILE

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
add_html_text "Datapath" overview_html {<html><b>Purpose</b><br/>Replicates one FEB hit_type0 Avalon-ST source to eight arbiter emulator inputs. The stream is readyless, matching both the emulator source and arbiter sinks, so Platform Designer should not insert ready/timing adapters on this path.</html>}
add_display_item "Datapath" DATA_WIDTH parameter
add_display_item "Datapath" CHANNEL_WIDTH parameter
add_display_item "Datapath" ERROR_WIDTH parameter
add_display_item "Identity" "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This build-local IP is packaged as <b>%s</b>. It has no CSR aperture.</html>} $VERSION_STRING_DEFAULT_CONST]
add_display_item "Interfaces" "Streams" GROUP
add_html_text "Streams" streams_html {<html><b>in</b><br/>45-bit FEB hit_type0 stream with valid, SOP, EOP, endofrun, channel[3:0], and error[2:0].<br/><br/><b>out0..out7</b><br/>Replicated readyless source streams with the same sideband contract.</html>}
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

proc add_hit_type0_sink {name} {
    add_interface $name avalon_streaming sink
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset rst
    set_interface_property $name dataBitsPerSymbol 45
    set_interface_property $name symbolsPerBeat 1
    set_interface_property $name readyLatency 0
    set_interface_property $name maxChannel 15
    set_interface_property $name firstSymbolInHighOrderBits true
    set_interface_property $name errorDescriptor "hiterr frameerr overflow"
    set_interface_property $name ENABLED true
    add_interface_port $name asi_in_data          data          Input 45
    add_interface_port $name asi_in_valid         valid         Input 1
    add_interface_port $name asi_in_error         error         Input 3
    add_interface_port $name asi_in_channel       channel       Input 4
    add_interface_port $name asi_in_startofpacket startofpacket Input 1
    add_interface_port $name asi_in_endofpacket   endofpacket   Input 1
    add_interface_port $name asi_in_endofrun      endofrun      Input 1
}

proc add_hit_type0_source {name index} {
    add_interface $name avalon_streaming source
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset rst
    set_interface_property $name dataBitsPerSymbol 45
    set_interface_property $name symbolsPerBeat 1
    set_interface_property $name readyLatency 0
    set_interface_property $name maxChannel 15
    set_interface_property $name firstSymbolInHighOrderBits true
    set_interface_property $name errorDescriptor "hiterr frameerr overflow"
    set_interface_property $name ENABLED true
    add_interface_port $name aso_out${index}_data          data          Output 45
    add_interface_port $name aso_out${index}_valid         valid         Output 1
    add_interface_port $name aso_out${index}_error         error         Output 3
    add_interface_port $name aso_out${index}_channel       channel       Output 4
    add_interface_port $name aso_out${index}_startofpacket startofpacket Output 1
    add_interface_port $name aso_out${index}_endofpacket   endofpacket   Output 1
    add_interface_port $name aso_out${index}_endofrun      endofrun      Output 1
}

add_hit_type0_sink in
for {set lane 0} {$lane < 8} {incr lane} {
    add_hit_type0_source out$lane $lane
}
