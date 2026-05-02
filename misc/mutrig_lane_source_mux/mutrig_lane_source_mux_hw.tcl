package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 2
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         502
set VERSION_DATE_DEFAULT_CONST  20260502
set VERSION_GIT_DEFAULT_CONST   0x0528DBAD
set IP_UID_DEFAULT_CONST        0x4D4C534D
set INSTANCE_ID_DEFAULT_CONST   0

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         mutrig_lane_source_mux
set_module_property DISPLAY_NAME                 "MuTRiG Lane Source Mux"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "MuTRiG Lane Source Mux Mu3e IP Core"
set_module_property GROUP                        "Mu3e Emulators/Modules"
set_module_property AUTHOR                       "OpenAI Codex"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false
set_module_property ELABORATION_CALLBACK         elaborate
set_module_property VALIDATION_CALLBACK          validate

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

proc validate {} {
    set select_emulator [get_parameter_value SELECT_EMULATOR]
    if {$select_emulator < 0 || $select_emulator > 1} {
        send_message error "SELECT_EMULATOR must stay in the range 0..1."
    }

    set fifo_depth [get_parameter_value FIFO_DEPTH]
    if {$fifo_depth < 2 || $fifo_depth > 16} {
        send_message error "FIFO_DEPTH must stay in the range 2..16."
    }
}

proc elaborate {} {
    catch {
        set select_emulator [get_parameter_value SELECT_EMULATOR]
        set fifo_depth [get_parameter_value FIFO_DEPTH]
        set default_label [expr {$select_emulator ? "emulator" : "real MuTRiG"}]
        set_display_item_property source_overview_html TEXT [format {<html><b>Runtime lane source select</b><br/>This IP forwards real LVDS/deassembly traffic, local emulator traffic, or a mixed stream into one MuTRiG datapath lane. Mixed mode keeps shallow FIFOs on both inputs and uses one-beat round-robin arbitration when both are non-empty.<br/><br/><b>Reset default</b><br/>This instance resets to the <b>%s</b> source. Software may switch each lane independently by writing CONTROL.<br/><br/><b>Mixed FIFO depth</b><br/>Each input FIFO has <b>%d</b> beats.</html>} $default_label $fifo_depth]
    }
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL mutrig_lane_source_mux
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file mutrig_lane_source_mux.sv SYSTEM_VERILOG PATH rtl/mutrig_lane_source_mux.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL mutrig_lane_source_mux
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file mutrig_lane_source_mux.sv SYSTEM_VERILOG PATH rtl/mutrig_lane_source_mux.sv TOP_LEVEL_FILE

add_parameter SELECT_EMULATOR NATURAL 0
set_parameter_property SELECT_EMULATOR DISPLAY_NAME "Reset Select Emulator"
set_parameter_property SELECT_EMULATOR ALLOWED_RANGES 0:1
set_parameter_property SELECT_EMULATOR HDL_PARAMETER true
set_parameter_property SELECT_EMULATOR DESCRIPTION "Reset value for CONTROL.select_emulator. 0 selects real decoded MuTRiG traffic, 1 selects the emulator stream."

add_parameter FIFO_DEPTH NATURAL 4
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Mixed FIFO Depth"
set_parameter_property FIFO_DEPTH ALLOWED_RANGES 2:16
set_parameter_property FIFO_DEPTH HDL_PARAMETER true
set_parameter_property FIFO_DEPTH DESCRIPTION "Per-input FIFO depth used only when CONTROL.mixed_rr is set."

add_parameter IP_UID STD_LOGIC_VECTOR $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID WIDTH 32
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID DESCRIPTION {Software-visible IP identifier at CSR word 0. Default ASCII "MLSM".}

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR DISPLAY_NAME "Version Major"
set_parameter_property VERSION_MAJOR HDL_PARAMETER true
set_parameter_property VERSION_MAJOR ENABLED false
set_parameter_property VERSION_MAJOR VISIBLE false

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR DISPLAY_NAME "Version Minor"
set_parameter_property VERSION_MINOR HDL_PARAMETER true
set_parameter_property VERSION_MINOR ENABLED false
set_parameter_property VERSION_MINOR VISIBLE false

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH DISPLAY_NAME "Version Patch"
set_parameter_property VERSION_PATCH HDL_PARAMETER true
set_parameter_property VERSION_PATCH ENABLED false
set_parameter_property VERSION_PATCH VISIBLE false

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD DISPLAY_NAME "Build"
set_parameter_property BUILD HDL_PARAMETER true
set_parameter_property BUILD ENABLED false
set_parameter_property BUILD VISIBLE false

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE DISPLAY_NAME "Version Date"
set_parameter_property VERSION_DATE HDL_PARAMETER true
set_parameter_property VERSION_DATE ENABLED false
set_parameter_property VERSION_DATE VISIBLE false

add_parameter VERSION_GIT STD_LOGIC_VECTOR $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT DISPLAY_NAME "Version Git"
set_parameter_property VERSION_GIT WIDTH 32
set_parameter_property VERSION_GIT HDL_PARAMETER true
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT ENABLED false
set_parameter_property VERSION_GIT VISIBLE false

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID DESCRIPTION "Per-integration instance identifier exposed through META page 3."

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_display_item $TAB_CONFIGURATION "Reset Policy" GROUP
add_html_text "Overview" source_overview_html {<html><b>Runtime lane source select</b><br/>This IP forwards real LVDS/deassembly traffic, local emulator traffic, or an RR-arbitrated mixed stream into one MuTRiG datapath lane.</html>}
add_html_text "Reset Policy" reset_policy_html {<html><b>Safe switching</b><br/>Software should switch modes while the run is stopped or the lane is otherwise quiescent. The selector is synchronous, but it does not frame-align or drain either 8b/1k stream before changing source. Entering or leaving mixed mode flushes the mixed-mode FIFOs.</html>}
add_display_item "Reset Policy" SELECT_EMULATOR parameter
add_display_item "Reset Policy" FIFO_DEPTH parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_display_item $TAB_IDENTITY "Versioning" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>.<br/><br/><b>Common identity header</b><br/>Word <b>0</b> is <b>UID</b> (default ASCII "MLSM").<br/>Word <b>1</b> is <b>META</b>: write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</html>} $VERSION_STRING_DEFAULT_CONST]
add_html_text "Versioning" versioning_html {<html><b>VERSION encoding</b><br/>VERSION[31:24] = MAJOR, VERSION[23:16] = MINOR, VERSION[15:12] = PATCH, VERSION[11:0] = BUILD.</html>}
add_display_item "Versioning" IP_UID parameter
add_display_item "Versioning" INSTANCE_ID parameter

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Streams" GROUP
add_display_item $TAB_INTERFACES "Control" GROUP
add_html_text "Clock / Reset" clock_html {<html><b>clk/rst</b><br/>Single synchronous lane clock domain shared by the two input streams, selected output stream, and CSR registers.</html>}
add_html_text "Streams" streams_html {<html><b>real_in</b><br/>9-bit decoded MuTRiG stream from the LVDS controller.<br/><br/><b>emu_in</b><br/>9-bit 8b/1k stream from emulator_mutrig.<br/><br/><b>selected_out</b><br/>The selected or mixed stream. Error and channel sidebands are forwarded without modification.</html>}
add_html_text "Control" control_html {<html><b>csr</b><br/>16-word Avalon-MM slave aperture. Each lane has a separate instance so software configures real, emulator, or mixed operation per lane.</html>}

add_display_item "" $TAB_REGMAP GROUP tab
add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_html {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Name</th><th>Access</th><th>Description</th></tr>
<tr><td>0x00</td><td>UID</td><td>RO</td><td>Default ASCII <b>MLSM</b>.</td></tr>
<tr><td>0x01</td><td>META</td><td>RW/RO</td><td>Write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</td></tr>
<tr><td>0x02</td><td>CONTROL</td><td>RW</td><td>Bit 0 select_emulator: 0=real, 1=emulator. Bit 1 clears counters/FIFOs when written as one. Bit 2 mixed_rr enables real+emulator RR arbitration.</td></tr>
<tr><td>0x03</td><td>STATUS</td><td>RO</td><td>Live select plus current valid/error/channel sidebands for real, emulator, and selected output. Bit 26 reports mixed_rr.</td></tr>
<tr><td>0x04</td><td>REAL_BEATS</td><td>RO</td><td>Saturating real input valid-beat counter.</td></tr>
<tr><td>0x05</td><td>EMU_BEATS</td><td>RO</td><td>Saturating emulator input valid-beat counter.</td></tr>
<tr><td>0x06</td><td>SELECTED_BEATS</td><td>RO</td><td>Saturating selected output valid-beat counter.</td></tr>
<tr><td>0x07</td><td>SWITCH_COUNT</td><td>RO</td><td>Saturating count of source-mode changes through CONTROL.</td></tr>
<tr><td>0x08</td><td>LAST_SELECTED</td><td>RO</td><td>Last selected source, error, channel, and 9-bit data.</td></tr>
<tr><td>0x09</td><td>FIFO_STATUS</td><td>RO</td><td>Mixed-mode FIFO levels and grant state.</td></tr>
<tr><td>0x0a</td><td>REAL_DROPS</td><td>RO</td><td>Real-input FIFO overflow drops in mixed mode.</td></tr>
<tr><td>0x0b</td><td>EMU_DROPS</td><td>RO</td><td>Emulator-input FIFO overflow drops in mixed mode.</td></tr>
<tr><td>0x0c</td><td>REAL_SELECTED</td><td>RO</td><td>Output beats sourced from real input.</td></tr>
<tr><td>0x0d</td><td>EMU_SELECTED</td><td>RO</td><td>Output beats sourced from emulator input.</td></tr>
</table></html>}

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

add_interface csr avalon end
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock clk
set_interface_property csr associatedReset rst
set_interface_property csr bitsPerSymbol 8
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address address Input 4
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_writedata writedata Input 32
add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1

add_interface real_in avalon_streaming sink
set_interface_property real_in associatedClock clk
set_interface_property real_in associatedReset rst
set_interface_property real_in dataBitsPerSymbol 9
set_interface_property real_in symbolsPerBeat 1
set_interface_property real_in readyLatency 0
set_interface_property real_in maxChannel 15
set_interface_property real_in errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property real_in ENABLED true
add_interface_port real_in asi_real_data data Input 9
add_interface_port real_in asi_real_valid valid Input 1
add_interface_port real_in asi_real_error error Input 3
add_interface_port real_in asi_real_channel channel Input 4

add_interface emu_in avalon_streaming sink
set_interface_property emu_in associatedClock clk
set_interface_property emu_in associatedReset rst
set_interface_property emu_in dataBitsPerSymbol 9
set_interface_property emu_in symbolsPerBeat 1
set_interface_property emu_in readyLatency 0
set_interface_property emu_in maxChannel 15
set_interface_property emu_in errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property emu_in ENABLED true
add_interface_port emu_in asi_emu_data data Input 9
add_interface_port emu_in asi_emu_valid valid Input 1
add_interface_port emu_in asi_emu_error error Input 3
add_interface_port emu_in asi_emu_channel channel Input 4

add_interface selected_out avalon_streaming source
set_interface_property selected_out associatedClock clk
set_interface_property selected_out associatedReset rst
set_interface_property selected_out dataBitsPerSymbol 9
set_interface_property selected_out symbolsPerBeat 1
set_interface_property selected_out readyLatency 0
set_interface_property selected_out maxChannel 15
set_interface_property selected_out errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property selected_out ENABLED true
add_interface_port selected_out aso_data data Output 9
add_interface_port selected_out aso_valid valid Output 1
add_interface_port selected_out aso_error error Output 3
add_interface_port selected_out aso_channel channel Output 4
