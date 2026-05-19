package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 0
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         519
set VERSION_DATE_DEFAULT_CONST  20260519
set IP_UID_DEFAULT_CONST        0x4D484754 ;# ASCII "MHGT" Merger Hit Generic Type0

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         merger_hit_type0
set_module_property DISPLAY_NAME                 "Merger hit_type0 (Real + Emulator)"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Per-lane readyless 2:1 mux between the real MuTRiG hit_type0 stream (post mutrig_frame_deassembly) and the emulator hit_type0 stream. One CSR bit picks the source. Replaces the emulator_hit_type0_fanout broadcast pattern."
set_module_property GROUP                        "Mu3e Data Plane/Modules"
set_module_property AUTHOR                       "OpenAI Codex / Yifeng Wang"
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
    set sel [get_parameter_value SOURCE_SEL_DEFAULT]
    if {$sel != 0 && $sel != 1} {
        send_message error "SOURCE_SEL_DEFAULT must be 0 (REAL) or 1 (EMU)."
    }
}

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL merger_hit_type0
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file merger_hit_type0.sv SYSTEM_VERILOG PATH ../rtl/merger_hit_type0.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL merger_hit_type0
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file merger_hit_type0.sv SYSTEM_VERILOG PATH ../rtl/merger_hit_type0.sv TOP_LEVEL_FILE

# --- Parameters --------------------------------------------------------------

add_parameter DATA_WIDTH NATURAL 45
set_parameter_property DATA_WIDTH HDL_PARAMETER true
set_parameter_property DATA_WIDTH ALLOWED_RANGES {45}

add_parameter CHANNEL_WIDTH NATURAL 4
set_parameter_property CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property CHANNEL_WIDTH ALLOWED_RANGES {4}

add_parameter ERROR_WIDTH NATURAL 3
set_parameter_property ERROR_WIDTH HDL_PARAMETER true
set_parameter_property ERROR_WIDTH ALLOWED_RANGES {3}

add_parameter SOURCE_SEL_DEFAULT NATURAL 0
set_parameter_property SOURCE_SEL_DEFAULT DISPLAY_NAME "Reset source select (0=REAL, 1=EMU)"
set_parameter_property SOURCE_SEL_DEFAULT HDL_PARAMETER true
set_parameter_property SOURCE_SEL_DEFAULT ALLOWED_RANGES {0 1}
set_parameter_property SOURCE_SEL_DEFAULT DESCRIPTION "Reset value of CONTROL.source_sel. 0 = forward real MuTRiG (post mutrig_frame_deassembly). 1 = forward emulator hit_type0. Runtime-switchable via the CSR after reset."

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR HDL_PARAMETER true
add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR HDL_PARAMETER true
add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH HDL_PARAMETER true
add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD HDL_PARAMETER true
add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE HDL_PARAMETER true
add_parameter IP_UID STD_LOGIC_VECTOR $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID WIDTH 32

add_parameter INSTANCE_ID NATURAL 0
set_parameter_property INSTANCE_ID DISPLAY_NAME "Lane / ASIC instance id"
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID ALLOWED_RANGES 0:255

# --- GUI display -------------------------------------------------------------

add_display_item "" "Configuration" GROUP tab
add_display_item "" "Identity" GROUP tab
add_display_item "" "Interfaces" GROUP tab
add_display_item "" "Register Map" GROUP tab

add_display_item "Configuration" "Datapath" GROUP
add_html_text "Datapath" overview_html {<html><b>Purpose</b><br/>Per-lane readyless 2:1 mux between the real MuTRiG hit_type0 stream (post <b>mutrig_frame_deassembly</b>) and the emulator hit_type0 stream. One CSR bit selects which source forwards. The Avalon-ST <b>channel</b> field is forwarded verbatim and is the authoritative ASIC ID for downstream (histogram, hit_stack, etc.). FEB SciFi v3/v4 maps physical lane id 1:1 onto ASIC id - no remap.<br/><br/><b>Why readyless</b><br/>FEB hit_type0 plane convention. Removes the timing_adapter / channel_adapter wrappers that Platform Designer would otherwise insert and that BUG-027-I showed can silently drop hits.</html>}
add_display_item "Datapath" SOURCE_SEL_DEFAULT parameter
add_display_item "Datapath" INSTANCE_ID parameter

add_display_item "Identity" "Delivered Profile" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This IP is packaged as <b>%s</b>. UID = 0x%08X "MHGT".</html>} $VERSION_STRING_DEFAULT_CONST $IP_UID_DEFAULT_CONST]
add_display_item "Identity" VERSION_MAJOR parameter
add_display_item "Identity" VERSION_MINOR parameter
add_display_item "Identity" VERSION_PATCH parameter
add_display_item "Identity" BUILD parameter
add_display_item "Identity" VERSION_DATE parameter
add_display_item "Identity" IP_UID parameter

add_display_item "Interfaces" "Streams" GROUP
add_html_text "Streams" streams_html {<html><b>real_in</b><br/>45-bit FEB hit_type0 stream from <b>mutrig_frame_deassembly</b> for one ASIC lane. Channel carries the ASIC id verbatim. Readyless.<br/><br/><b>emu_in</b><br/>45-bit emulator hit_type0 stream for the same lane. Channel must carry the matching ASIC id. Readyless.<br/><br/><b>out</b><br/>45-bit hit_type0 source forwarding the CSR-selected ingress. Readyless.</html>}

add_display_item "Register Map" "CSR Window" GROUP
add_html_text "CSR Window" csr_html {<html><b>CSR map</b> (4 x 32-bit words, 3-bit address):<ul><li><b>0x0 UID</b> read-only, 0x4D484754 "MHGT"</li><li><b>0x1 VERSION</b> read-only, {MAJOR[8], MINOR[8], PATCH[4], BUILD[12]}</li><li><b>0x2 VERSION_DATE</b> read-only</li><li><b>0x3 CONTROL</b> read-write, bit 0 = source_sel (0=REAL, 1=EMU)</li></ul></html>}

# --- Interfaces --------------------------------------------------------------

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

# CSR Avalon-MM slave
add_interface csr avalon end
set_interface_property csr associatedClock clk
set_interface_property csr associatedReset rst
set_interface_property csr addressUnits WORDS
set_interface_property csr addressGroup 0
set_interface_property csr bridgedAddressOffset ""
set_interface_property csr bridgesToMaster ""
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr burstcountUnits WORDS
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 0
set_interface_property csr maximumPendingWriteTransactions 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address     address     Input  3
add_interface_port csr avs_csr_read        read        Input  1
add_interface_port csr avs_csr_write       write       Input  1
add_interface_port csr avs_csr_writedata   writedata   Input  32
add_interface_port csr avs_csr_readdata    readdata    Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1

# real_in: readyless Avalon-ST sink (post mutrig_frame_deassembly)
add_interface real_in avalon_streaming sink
set_interface_property real_in associatedClock clk
set_interface_property real_in associatedReset rst
set_interface_property real_in dataBitsPerSymbol 45
set_interface_property real_in symbolsPerBeat 1
set_interface_property real_in readyLatency 0
set_interface_property real_in maxChannel 15
set_interface_property real_in firstSymbolInHighOrderBits true
set_interface_property real_in errorDescriptor "hiterr frameerr overflow"
set_interface_property real_in ENABLED true
add_interface_port real_in asi_real_data          data          Input 45
add_interface_port real_in asi_real_valid         valid         Input 1
add_interface_port real_in asi_real_error         error         Input 3
add_interface_port real_in asi_real_channel       channel       Input 4
add_interface_port real_in asi_real_startofpacket startofpacket Input 1
add_interface_port real_in asi_real_endofpacket   endofpacket   Input 1
add_interface_port real_in asi_real_endofrun      endofrun      Input 1

# emu_in: readyless Avalon-ST sink (from emulator_mutrig hit_type0 per-lane stream)
add_interface emu_in avalon_streaming sink
set_interface_property emu_in associatedClock clk
set_interface_property emu_in associatedReset rst
set_interface_property emu_in dataBitsPerSymbol 45
set_interface_property emu_in symbolsPerBeat 1
set_interface_property emu_in readyLatency 0
set_interface_property emu_in maxChannel 15
set_interface_property emu_in firstSymbolInHighOrderBits true
set_interface_property emu_in errorDescriptor "hiterr frameerr overflow"
set_interface_property emu_in ENABLED true
add_interface_port emu_in asi_emu_data          data          Input 45
add_interface_port emu_in asi_emu_valid         valid         Input 1
add_interface_port emu_in asi_emu_error         error         Input 3
add_interface_port emu_in asi_emu_channel       channel       Input 4
add_interface_port emu_in asi_emu_startofpacket startofpacket Input 1
add_interface_port emu_in asi_emu_endofpacket   endofpacket   Input 1
add_interface_port emu_in asi_emu_endofrun      endofrun      Input 1

# out: readyless Avalon-ST source
add_interface out avalon_streaming source
set_interface_property out associatedClock clk
set_interface_property out associatedReset rst
set_interface_property out dataBitsPerSymbol 45
set_interface_property out symbolsPerBeat 1
set_interface_property out readyLatency 0
set_interface_property out maxChannel 15
set_interface_property out firstSymbolInHighOrderBits true
set_interface_property out errorDescriptor "hiterr frameerr overflow"
set_interface_property out ENABLED true
add_interface_port out aso_out_data          data          Output 45
add_interface_port out aso_out_valid         valid         Output 1
add_interface_port out aso_out_error         error         Output 3
add_interface_port out aso_out_channel       channel       Output 4
add_interface_port out aso_out_startofpacket startofpacket Output 1
add_interface_port out aso_out_endofpacket   endofpacket   Output 1
add_interface_port out aso_out_endofrun      endofrun      Output 1
