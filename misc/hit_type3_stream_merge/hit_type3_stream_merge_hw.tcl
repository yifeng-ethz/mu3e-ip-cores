package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         429
set VERSION_DATE_DEFAULT_CONST  20260429

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         hit_type3_stream_merge
set_module_property DISPLAY_NAME                 "Hit Type3 Stream Merge"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Hit Type3 Stream Merge Mu3e IP Core"
set_module_property GROUP                        "Mu3e Utility/Modules"
set_module_property AUTHOR                       "OpenAI Codex"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     false
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL hit_type3_stream_merge
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type3_stream_merge.sv SYSTEM_VERILOG PATH rtl/hit_type3_stream_merge.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL hit_type3_stream_merge
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file hit_type3_stream_merge.sv SYSTEM_VERILOG PATH rtl/hit_type3_stream_merge.sv TOP_LEVEL_FILE

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_html_text "Overview" overview_html {<html><b>Packet-atomic hit_type3 merge</b><br/>Merges two 36-bit packetized post-hit-stack Avalon-ST streams into one histogram tap stream. Arbitration is round-robin at packet boundaries and never interleaves beats from different packets.</html>}

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>.<br/><br/>This utility has no software-visible CSR aperture.</html>} $VERSION_STRING_DEFAULT_CONST]

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Streams" GROUP
add_html_text "Clock / Reset" clock_html {<html><b>clk/reset</b><br/>Single synchronous domain. Reset is active high.</html>}
add_html_text "Streams" streams_html {<html><b>in0/in1</b><br/>36-bit packetized Avalon-ST sink streams with data, valid, ready, startofpacket, and endofpacket.<br/><br/><b>out</b><br/>Merged packetized source stream. No channel or error sidebands are present on this hit_type3 tap path.</html>}

add_display_item "" $TAB_REGMAP GROUP tab
add_display_item $TAB_REGMAP "Register Map" GROUP
add_html_text "Register Map" regmap_html {<html>No CSR registers. This IP is a pure streaming datapath helper.</html>}

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clk
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
add_interface_port reset reset reset Input 1

add_interface in0 avalon_streaming sink
set_interface_property in0 associatedClock clk
set_interface_property in0 associatedReset reset
set_interface_property in0 dataBitsPerSymbol 36
set_interface_property in0 symbolsPerBeat 1
set_interface_property in0 readyLatency 0
set_interface_property in0 ENABLED true
add_interface_port in0 asi_in0_data data Input 36
add_interface_port in0 asi_in0_valid valid Input 1
add_interface_port in0 asi_in0_ready ready Output 1
add_interface_port in0 asi_in0_startofpacket startofpacket Input 1
add_interface_port in0 asi_in0_endofpacket endofpacket Input 1

add_interface in1 avalon_streaming sink
set_interface_property in1 associatedClock clk
set_interface_property in1 associatedReset reset
set_interface_property in1 dataBitsPerSymbol 36
set_interface_property in1 symbolsPerBeat 1
set_interface_property in1 readyLatency 0
set_interface_property in1 ENABLED true
add_interface_port in1 asi_in1_data data Input 36
add_interface_port in1 asi_in1_valid valid Input 1
add_interface_port in1 asi_in1_ready ready Output 1
add_interface_port in1 asi_in1_startofpacket startofpacket Input 1
add_interface_port in1 asi_in1_endofpacket endofpacket Input 1

add_interface out avalon_streaming source
set_interface_property out associatedClock clk
set_interface_property out associatedReset reset
set_interface_property out dataBitsPerSymbol 36
set_interface_property out symbolsPerBeat 1
set_interface_property out readyLatency 0
set_interface_property out ENABLED true
add_interface_port out aso_out_data data Output 36
add_interface_port out aso_out_valid valid Output 1
add_interface_port out aso_out_ready ready Input 1
add_interface_port out aso_out_startofpacket startofpacket Output 1
add_interface_port out aso_out_endofpacket endofpacket Output 1
