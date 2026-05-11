package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 1
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         502
set VERSION_DATE_DEFAULT_CONST  20260502
set VERSION_GIT_DEFAULT_CONST   0x0528DBAD
set IP_UID_DEFAULT_CONST        0x48534E50
set INSTANCE_ID_DEFAULT_CONST   0

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         histogram_snoop_selector
set_module_property DISPLAY_NAME                 "Histogram Snoop Selector"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Histogram Snoop Selector Mu3e IP Core"
set_module_property GROUP                        "Mu3e Data Plane/Modules"
set_module_property AUTHOR                       "OpenAI Codex"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL histogram_snoop_selector
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file histogram_snoop_selector.sv SYSTEM_VERILOG PATH rtl/histogram_snoop_selector.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL histogram_snoop_selector
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file histogram_snoop_selector.sv SYSTEM_VERILOG PATH rtl/histogram_snoop_selector.sv TOP_LEVEL_FILE

add_parameter DEFAULT_SELECT_RBCAM NATURAL 0
set_parameter_property DEFAULT_SELECT_RBCAM DISPLAY_NAME "Default Select rbCAM"
set_parameter_property DEFAULT_SELECT_RBCAM ALLOWED_RANGES 0:1
set_parameter_property DEFAULT_SELECT_RBCAM HDL_PARAMETER true
set_parameter_property DEFAULT_SELECT_RBCAM DESCRIPTION "0 selects hit-processor ingress snoop after reset. 1 selects rbCAM egress snoop."

add_parameter DEFAULT_FILTER_RBCAM NATURAL 1
set_parameter_property DEFAULT_FILTER_RBCAM DISPLAY_NAME "Default Filter rbCAM Hits"
set_parameter_property DEFAULT_FILTER_RBCAM ALLOWED_RANGES 0:1
set_parameter_property DEFAULT_FILTER_RBCAM HDL_PARAMETER true
set_parameter_property DEFAULT_FILTER_RBCAM DESCRIPTION "1 filters rbCAM frame words and only forwards hit words after K23.7 subheaders."

add_parameter IP_UID STD_LOGIC_VECTOR $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID WIDTH 32
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID DESCRIPTION {Software-visible IP identifier at CSR word 0. Default ASCII "HSNP".}

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
add_display_item $TAB_CONFIGURATION "Defaults" GROUP
add_html_text "Overview" overview_html {<html><b>Nonblocking histogram snoop</b><br/>This IP chooses between a 39-bit hit-processor type1 snoop and a 36-bit rbCAM type2 egress snoop. Both input ready signals are tied high, so histogram backpressure cannot block either observed datapath. If the histogram sink is not ready, selected samples are dropped and counted.</html>}
add_display_item "Defaults" DEFAULT_SELECT_RBCAM parameter
add_display_item "Defaults" DEFAULT_FILTER_RBCAM parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_display_item $TAB_IDENTITY "Versioning" GROUP
add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>.<br/><br/><b>Common identity header</b><br/>Word <b>0</b> is <b>UID</b> (default ASCII "HSNP"). A write to word 0 clears counters.<br/>Word <b>1</b> is <b>META</b>: write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</html>} $VERSION_STRING_DEFAULT_CONST]
add_html_text "Versioning" versioning_html {<html><b>VERSION encoding</b><br/>VERSION[31:24] = MAJOR, VERSION[23:16] = MINOR, VERSION[15:12] = PATCH, VERSION[11:0] = BUILD.</html>}
add_display_item "Versioning" IP_UID parameter
add_display_item "Versioning" INSTANCE_ID parameter

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Streams" GROUP
add_display_item $TAB_INTERFACES "CSR" GROUP
add_html_text "Clock / Reset" clock_html {<html><b>clk/rst</b><br/>Single synchronous histogram observation clock domain.</html>}
add_html_text "Streams" streams_html {<html><b>hp_in</b><br/>39-bit type1 hit-processor snoop stream. Ready is always high.<br/><br/><b>rb_in</b><br/>36-bit raw rbCAM type2 egress snoop stream, including channel/error/empty sidebands accepted for Platform Designer compatibility. Ready is always high. With filtering enabled, only data words following K23.7 subheaders are repacked into the 39-bit histogram layout.<br/><br/><b>hist_out</b><br/>39-bit histogram input stream. It is intentionally lossy on downstream backpressure to protect the observed datapaths.</html>}
add_html_text "CSR" csr_iface_html {<html><b>csr</b><br/>Eight-word Avalon-MM slave aperture for source select, status, and low 32-bit live counters.</html>}

add_display_item "" $TAB_REGMAP GROUP tab
add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_html {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Name</th><th>Access</th><th>Description</th></tr>
<tr><td>0x00</td><td>UID</td><td>RO/W</td><td>Read default ASCII <b>HSNP</b>. Any write clears counters.</td></tr>
<tr><td>0x01</td><td>META</td><td>RW/RO</td><td>Write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</td></tr>
<tr><td>0x02</td><td>CONTROL</td><td>RW</td><td>Bit 0 selects rbCAM egress when set; bit 1 enables rbCAM hit-word filtering; bit 8 clears counters.</td></tr>
<tr><td>0x03</td><td>STATUS</td><td>RO</td><td>Live source, filter, input valids, rbCAM filter state, histogram ready/valid, and rbCAM subheader timestamp.</td></tr>
<tr><td>0x04</td><td>HP_SEEN_LO</td><td>RO</td><td>Low 32 bits of hit-processor snoop valid samples.</td></tr>
<tr><td>0x05</td><td>RB_SEEN_LO</td><td>RO</td><td>Low 32 bits of accepted rbCAM hit-word snoop samples.</td></tr>
<tr><td>0x06</td><td>HIST_EMIT_LO</td><td>RO</td><td>Low 32 bits of selected samples emitted to histogram.</td></tr>
<tr><td>0x07</td><td>HIST_DROP_LO</td><td>RO</td><td>Low 32 bits of selected samples dropped because histogram was not ready.</td></tr>
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
set_interface_property csr explicitAddressSpan 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address address Input 3
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_writedata writedata Input 32
add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1

add_interface hp_in avalon_streaming sink
set_interface_property hp_in associatedClock clk
set_interface_property hp_in associatedReset rst
set_interface_property hp_in dataBitsPerSymbol 39
set_interface_property hp_in symbolsPerBeat 1
set_interface_property hp_in readyLatency 0
set_interface_property hp_in maxChannel 15
set_interface_property hp_in firstSymbolInHighOrderBits true
set_interface_property hp_in errorDescriptor "tserr"
set_interface_property hp_in ENABLED true
add_interface_port hp_in asi_hp_data data Input 39
add_interface_port hp_in asi_hp_valid valid Input 1
add_interface_port hp_in asi_hp_ready ready Output 1
add_interface_port hp_in asi_hp_startofpacket startofpacket Input 1
add_interface_port hp_in asi_hp_endofpacket endofpacket Input 1
add_interface_port hp_in asi_hp_channel channel Input 4
add_interface_port hp_in asi_hp_empty empty Input 1
add_interface_port hp_in asi_hp_error error Input 1

add_interface rb_in avalon_streaming sink
set_interface_property rb_in associatedClock clk
set_interface_property rb_in associatedReset rst
set_interface_property rb_in dataBitsPerSymbol 36
set_interface_property rb_in errorDescriptor {"tsglitcherr"}
set_interface_property rb_in maxChannel 15
set_interface_property rb_in symbolsPerBeat 1
set_interface_property rb_in readyLatency 0
set_interface_property rb_in firstSymbolInHighOrderBits true
set_interface_property rb_in ENABLED true
add_interface_port rb_in asi_rb_data data Input 36
add_interface_port rb_in asi_rb_valid valid Input 1
add_interface_port rb_in asi_rb_ready ready Output 1
add_interface_port rb_in asi_rb_startofpacket startofpacket Input 1
add_interface_port rb_in asi_rb_endofpacket endofpacket Input 1
add_interface_port rb_in asi_rb_channel channel Input 4
add_interface_port rb_in asi_rb_empty empty Input 1
add_interface_port rb_in asi_rb_error error Input 1

add_interface hist_out avalon_streaming source
set_interface_property hist_out associatedClock clk
set_interface_property hist_out associatedReset rst
set_interface_property hist_out dataBitsPerSymbol 39
set_interface_property hist_out symbolsPerBeat 1
set_interface_property hist_out readyLatency 0
set_interface_property hist_out maxChannel 15
set_interface_property hist_out firstSymbolInHighOrderBits true
set_interface_property hist_out ENABLED true
add_interface_port hist_out aso_hist_data data Output 39
add_interface_port hist_out aso_hist_valid valid Output 1
add_interface_port hist_out aso_hist_ready ready Input 1
add_interface_port hist_out aso_hist_startofpacket startofpacket Output 1
add_interface_port hist_out aso_hist_endofpacket endofpacket Output 1
add_interface_port hist_out aso_hist_channel channel Output 4
