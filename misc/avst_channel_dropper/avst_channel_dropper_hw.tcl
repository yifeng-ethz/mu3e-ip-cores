package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         515
set VERSION_DATE_DEFAULT_CONST  20260515

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         avst_channel_dropper
set_module_property DISPLAY_NAME                 "Avalon-ST Channel Dropper"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Drops an Avalon-ST channel sideband without filtering beats"
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

    set_interface_property in dataBitsPerSymbol $data_width
    set_interface_property in symbolsPerBeat 1
    set_interface_property in maxChannel $max_channel

    set_interface_property out dataBitsPerSymbol $data_width
    set_interface_property out symbolsPerBeat 1
    set_interface_property out maxChannel 0
}

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL avst_channel_dropper
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file avst_channel_dropper.sv SYSTEM_VERILOG PATH rtl/avst_channel_dropper.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL avst_channel_dropper
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file avst_channel_dropper.sv SYSTEM_VERILOG PATH rtl/avst_channel_dropper.sv TOP_LEVEL_FILE

add_parameter DATA_WIDTH NATURAL 9
set_parameter_property DATA_WIDTH DISPLAY_NAME "Data Width"
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES 1:4096

add_parameter CHANNEL_WIDTH NATURAL 1
set_parameter_property CHANNEL_WIDTH DISPLAY_NAME "Input Channel Width"
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES 1:64

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_display_item $TAB_CONFIGURATION "Sizing" GROUP
add_html_text "Overview" overview_html {<html><b>Channel removal</b><br/>Forwards data and valid while discarding the Avalon-ST channel sideband. The input ready is held asserted, so this IP is intended only for readyless downstream consumers.</html>}
add_display_item "Sizing" DATA_WIDTH parameter
add_display_item "Sizing" CHANNEL_WIDTH parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>. This IP has no CSR aperture.</html>} $VERSION_STRING_DEFAULT_CONST]

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Streams" GROUP
add_html_text "Clock / Reset" clock_html {<html><b>clk/rst</b><br/>Included for Platform Designer clock-domain association. The datapath is combinational and owns no state.</html>}
add_html_text "Streams" streams_html {<html><b>in</b><br/>Channel-tagged Avalon-ST stream.<br/><br/><b>out</b><br/>The same data/valid beat without a channel sideband and without ready backpressure.</html>}

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
set_interface_property in dataBitsPerSymbol 9
set_interface_property in symbolsPerBeat 1
set_interface_property in readyLatency 0
set_interface_property in maxChannel 1
set_interface_property in firstSymbolInHighOrderBits true
set_interface_property in ENABLED true
add_interface_port in asi_data data Input DATA_WIDTH
add_interface_port in asi_valid valid Input 1
add_interface_port in asi_ready ready Output 1
add_interface_port in asi_channel channel Input CHANNEL_WIDTH

add_interface out avalon_streaming source
set_interface_property out associatedClock clk
set_interface_property out associatedReset rst
set_interface_property out dataBitsPerSymbol 9
set_interface_property out symbolsPerBeat 1
set_interface_property out readyLatency 0
set_interface_property out maxChannel 0
set_interface_property out firstSymbolInHighOrderBits true
set_interface_property out ENABLED true
add_interface_port out aso_data data Output DATA_WIDTH
add_interface_port out aso_valid valid Output 1
