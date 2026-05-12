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

set_module_property NAME                         hit_type0_readyless_mux4
set_module_property DISPLAY_NAME                 "Hit Type0 Readyless Mux4"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Readyless four-input hit_type0 Avalon-ST mux with per-input FIFOs"
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

proc validate {} {
    set depth [get_parameter_value FIFO_DEPTH]
    if {$depth < 2} {
        send_message error "FIFO_DEPTH must be at least 2"
    }
}

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL hit_type0_readyless_mux4
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type0_readyless_mux4.sv SYSTEM_VERILOG PATH rtl/hit_type0_readyless_mux4.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL hit_type0_readyless_mux4
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type0_readyless_mux4.sv SYSTEM_VERILOG PATH rtl/hit_type0_readyless_mux4.sv TOP_LEVEL_FILE

add_parameter FIFO_DEPTH NATURAL 16
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Input FIFO Depth"
set_parameter_property FIFO_DEPTH HDL_PARAMETER true
set_parameter_property FIFO_DEPTH ALLOWED_RANGES {2 4 8 16 32 64}

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_display_item $TAB_CONFIGURATION "Sizing" GROUP
add_html_text "Overview" overview_html {<html><b>Function</b><br/>Combines four readyless 45-bit hit_type0 streams into one readyless 45-bit hit_type0 stream. Each input has a small FIFO. The output channel preserves the input channel in bits [3:0] and places the selected local lane index in bits [5:4], matching the prior Platform Designer multiplexer contract.</html>}
add_display_item "Sizing" FIFO_DEPTH parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>Packaged as <b>%s</b>. This IP has no CSR aperture; version identity is Platform Designer metadata only.</html>} $VERSION_STRING_DEFAULT_CONST]

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Streams" GROUP
add_html_text "Streams" streams_html {<html><b>in0..in3</b><br/>Readyless Avalon-ST hit_type0 sinks: data, valid, error, channel, SOP/EOP, and endofrun sideband. No input ready is exported.<br/><br/><b>out</b><br/>Readyless Avalon-ST hit_type0 source. No output ready is consumed.</html>}

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

proc add_hit_sink {name index} {
    add_interface $name avalon_streaming end
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset rst
    set_interface_property $name dataBitsPerSymbol 45
    set_interface_property $name symbolsPerBeat 1
    set_interface_property $name readyLatency 0
    set_interface_property $name maxChannel 15
    set_interface_property $name firstSymbolInHighOrderBits true
    set_interface_property $name errorDescriptor "hiterr frameerr overflow"
    set_interface_property $name ENABLED true
    add_interface_port $name "asi_in${index}_data"          data          Input 45
    add_interface_port $name "asi_in${index}_valid"         valid         Input 1
    add_interface_port $name "asi_in${index}_error"         error         Input 3
    add_interface_port $name "asi_in${index}_channel"       channel       Input 4
    add_interface_port $name "asi_in${index}_startofpacket" startofpacket Input 1
    add_interface_port $name "asi_in${index}_endofpacket"   endofpacket   Input 1
    add_interface_port $name "asi_in${index}_endofrun"      endofrun      Input 1
}

for {set i 0} {$i < 4} {incr i} {
    add_hit_sink in${i} $i
}

add_interface out avalon_streaming start
set_interface_property out associatedClock clk
set_interface_property out associatedReset rst
set_interface_property out dataBitsPerSymbol 45
set_interface_property out symbolsPerBeat 1
set_interface_property out readyLatency 0
set_interface_property out maxChannel 63
set_interface_property out firstSymbolInHighOrderBits true
set_interface_property out errorDescriptor "hiterr frameerr overflow"
set_interface_property out ENABLED true
add_interface_port out aso_out_data          data          Output 45
add_interface_port out aso_out_valid         valid         Output 1
add_interface_port out aso_out_error         error         Output 3
add_interface_port out aso_out_channel       channel       Output 6
add_interface_port out aso_out_startofpacket startofpacket Output 1
add_interface_port out aso_out_endofpacket   endofpacket   Output 1
add_interface_port out aso_out_endofrun      endofrun      Output 1
