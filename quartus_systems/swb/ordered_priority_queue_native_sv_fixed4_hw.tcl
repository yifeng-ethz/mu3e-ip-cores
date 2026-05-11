package require -exact qsys 16.1

set_module_property NAME                         ordered_priority_queue_native_sv_fixed4
set_module_property DISPLAY_NAME                 "Ordered Priority Queue Native SV Fixed4"
set_module_property VERSION                      26.5.0.0430
set_module_property GROUP                        "Mu3e Data Plane/Modules"
set_module_property DESCRIPTION                  "Fixed-profile 4-lane native-SV OPQ wrapper for MuSiP integration"
set_module_property AUTHOR                       "Yifeng Wang / Codex local packaging"
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

# Identity constants - packaged 2026-04-30
# UID = ASCII "OPQM" (Ordered Priority Queue, Monolithic) = 0x4F50514D
set IP_UID_DEFAULT_CONST        1330663757
set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 5
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         430
set VERSION_DATE_DEFAULT_CONST  20260430
set VERSION_GIT_DEFAULT_CONST   1332117425
set INSTANCE_ID_DEFAULT_CONST   0
set OPQ_VERSION_STRING          [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]
set OPQ_GIT_HEX_STRING          [format "0x%08X" $VERSION_GIT_DEFAULT_CONST]

set OPQ_VERSIONING_HTML {<html><b>Common identity header</b><br/>CSR word <b>0x001</b> selects the META page on write and returns the selected payload on read.<br/><br/><b>Page 0</b>: VERSION word, encoded as YEAR[31:24], MINOR[23:16], PATCH[15:12], BUILD[11:0].<br/><b>Page 1</b>: VERSION_DATE (YYYYMMDD).<br/><b>Page 2</b>: VERSION_GIT (32-bit truncated git stamp).<br/><b>Page 3</b>: INSTANCE_ID.</html>}
set OPQ_CSR_WINDOW_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Name</th><th>Access</th><th>Description</th></tr>
<tr><td>0x000</td><td>UID</td><td>RO</td><td>Immutable Mu3e IP identifier. Default ASCII "OPQM".</td></tr>
<tr><td>0x001</td><td>META</td><td>RW/RO</td><td>Write page selector[1:0]. Read selected page: VERSION / DATE / GIT / INSTANCE_ID.</td></tr>
<tr><td>0x002</td><td>LANE_MASK</td><td>RW</td><td>Bit i = 1 masks lane i at packet boundaries. In-flight packets drain; new packets on masked lanes are dropped and counted.</td></tr>
<tr><td>0x003</td><td>CTRL</td><td>WO</td><td>Bit 0 = write-1 pulse to clear all software-visible counters.</td></tr>
<tr><td>0x004</td><td>STATUS</td><td>RO</td><td>Lane-mask summary, busy flags, and effective-mask state.</td></tr>
<tr><td>0x005</td><td>CAP</td><td>RO</td><td>Capability summary and per-lane counter-window geometry.</td></tr>
<tr><td>0x008..0x010</td><td>FT_* Counters</td><td>RO</td><td>Frame-table write/read/drop counters for headers, subheaders, and hits.</td></tr>
<tr><td>0x040 + lane*0x10 + 0..A</td><td>Lane Counters</td><td>RO</td><td>Per-lane write/read/drop counters plus live lane/ticket free-credit counters.</td></tr>
<tr><td>0x040 + lane*0x10 + B</td><td>DRR_ALLOWANCE</td><td>RW</td><td>Per-lane deficit-round-robin refill allowance in page words per participating subheader.</td></tr>
<tr><td>0x040 + lane*0x10 + C..F</td><td>DRR Live / Stats</td><td>RO</td><td>Live DRR deficit budget plus per-lane block-grant / served-beat / defer-round counters.</td></tr>
</table></html>}
set OPQ_META_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[1:0]</b> write-only selector</td><td>PAGE_SEL</td><td>Selects which identity payload is returned on the next read: 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</td></tr>
<tr><td><b>[31:0]</b> read data</td><td>META_PAYLOAD</td><td>Selected identity payload returned by the read-side mux.</td></tr>
</table></html>}
set OPQ_CTRL_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[0]</b></td><td>CLEAR_COUNTERS</td><td>Write-1 pulse. Clears all per-lane and frame-table software-visible counters.</td></tr>
<tr><td><b>[31:1]</b></td><td>RESERVED</td><td>Ignored; write zero for forward compatibility.</td></tr>
</table></html>}
set OPQ_STATUS_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[3:0]</b></td><td>LANE_MASK_SHADOW</td><td>Software-programmed lane mask value for the fixed 4-lane instance.</td></tr>
<tr><td><b>[16]</b></td><td>ALLOC_BUSY</td><td>High when the page allocator is active.</td></tr>
<tr><td><b>[17]</b></td><td>ARBITER_BUSY</td><td>High when the page-RAM write-port arbiter is active.</td></tr>
<tr><td><b>[18]</b></td><td>PRESENTER_BUSY</td><td>High when the egress presenter is driving a packet.</td></tr>
<tr><td><b>[19]</b></td><td>MASK_EFFECTIVE</td><td>High when any lane is currently blocked at the packet-boundary gate.</td></tr>
<tr><td><b>[31:20]</b></td><td>RESERVED</td><td>Reads zero.</td></tr>
</table></html>}
set OPQ_CAP_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Name</th><th>Description</th></tr>
<tr><td><b>[0]</b></td><td>UID_META_HEADER</td><td>Common Mu3e UID + META header is implemented.</td></tr>
<tr><td><b>[1]</b></td><td>LANE_MASK_CTRL</td><td>Software lane masking at packet boundaries is implemented.</td></tr>
<tr><td><b>[2]</b></td><td>PER_LANE_CNTRS</td><td>Per-lane write/read/drop and credit counters are implemented.</td></tr>
<tr><td><b>[3]</b></td><td>FT_CNTRS</td><td>Frame-table write/read/drop counters are implemented.</td></tr>
<tr><td><b>[4]</b></td><td>DRR_CTRL</td><td>Per-lane DRR allowance programming and live observability are implemented.</td></tr>
<tr><td><b>[15:8]</b></td><td>LANE_REGION_STRIDE</td><td>Per-lane CSR region stride in words, fixed at 0x10.</td></tr>
<tr><td><b>[23:16]</b></td><td>LANE_REGION_BASE</td><td>Base word address of the per-lane counter window, fixed at 0x40.</td></tr>
<tr><td><b>[31:24]</b></td><td>N_LANE</td><td>Number of instantiated ingress lanes, fixed at 4.</td></tr>
</table></html>}
set OPQ_LANE_REGION_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Offset</th><th>Name</th><th>Description</th></tr>
<tr><td>+0</td><td>WR_HDR_CNT</td><td>Per-lane header tickets accepted from ingress parsing.</td></tr>
<tr><td>+1</td><td>WR_SHD_CNT</td><td>Per-lane subheader tickets accepted from ingress parsing.</td></tr>
<tr><td>+2</td><td>WR_HIT_CNT</td><td>Per-lane hit words written into the lane FIFO.</td></tr>
<tr><td>+3</td><td>RD_HDR_CNT</td><td>Per-lane header tickets consumed by the page allocator.</td></tr>
<tr><td>+4</td><td>RD_SHD_CNT</td><td>Per-lane subheaders accepted into the merged page stream.</td></tr>
<tr><td>+5</td><td>RD_HIT_CNT</td><td>Per-lane hits accepted into the merged page stream.</td></tr>
<tr><td>+6..+8</td><td>DROP_*_CNT</td><td>Per-lane packet words dropped before frame-table ownership.</td></tr>
<tr><td>+9..+A</td><td>CREDIT</td><td>Live lane-FIFO and ticket-FIFO free-credit counters.</td></tr>
<tr><td>+B</td><td>DRR_ALLOWANCE</td><td>Software-programmed DRR refill allowance for that lane.</td></tr>
<tr><td>+C..+F</td><td>DRR Live / Stats</td><td>Live DRR quantum, grant count, beat count, and defer count.</td></tr>
</table></html>}

if {[info exists ::env(OPQ_SOURCE_ROOT)] && $::env(OPQ_SOURCE_ROOT) ne ""} {
    set OPQ_SOURCE_ROOT [file normalize $::env(OPQ_SOURCE_ROOT)]
} else {
    set OPQ_SOURCE_ROOT [file normalize [file join [file dirname [info script]] "../../../../../../../../musip_2604/external/mu3e-ip-cores/packet_scheduler"]]
}

proc opq_source_file {relative_path} {
    global OPQ_SOURCE_ROOT
    return [file normalize [file join $OPQ_SOURCE_ROOT $relative_path]]
}

add_fileset synth QUARTUS_SYNTH
set_fileset_property synth TOP_LEVEL ordered_priority_queue_dut_sv
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_dut_sv.sv"] SYSTEM_VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_dut_sv.sv"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv"] SYSTEM_VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_block_path.sv"] SYSTEM_VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_block_path.sv"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_frame_table_presenter.sv"] SYSTEM_VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_frame_table_presenter.sv"]
add_fileset_file [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv"] SYSTEM_VERILOG PATH [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv"]
add_fileset_file [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv"] SYSTEM_VERILOG PATH [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv"]
add_fileset_file [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv"] SYSTEM_VERILOG PATH [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv"]
add_fileset_file [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv"] SYSTEM_VERILOG PATH [opq_source_file "rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/handle_fifo.v"] VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/handle_fifo.v"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/lane_fifo.v"] VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/lane_fifo.v"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/page_ram.v"] VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/page_ram.v"]
add_fileset_file [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ticket_fifo.v"] VERILOG PATH [opq_source_file "syn/quartus/opq_native_sv_4lane_signoff/src_compat/ticket_fifo.v"]
add_fileset_file [opq_source_file "rtl/sv_ver/vendor/alt_ram/frame_table.v"] VERILOG PATH [opq_source_file "rtl/sv_ver/vendor/alt_ram/frame_table.v"]
add_fileset_file [opq_source_file "rtl/sv_ver/vendor/alt_ram/tile_fifo.v"] VERILOG PATH [opq_source_file "rtl/sv_ver/vendor/alt_ram/tile_fifo.v"]

add_parameter IP_UID NATURAL $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID ALLOWED_RANGES 0:2147483647
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID ENABLED false
set_parameter_property IP_UID DESCRIPTION {ASCII four-character Mu3e IP identifier. Exposed at CSR word 0x00.}

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR DISPLAY_NAME "Version Major"
set_parameter_property VERSION_MAJOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MAJOR HDL_PARAMETER true
set_parameter_property VERSION_MAJOR ENABLED false

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR DISPLAY_NAME "Version Minor"
set_parameter_property VERSION_MINOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MINOR HDL_PARAMETER true
set_parameter_property VERSION_MINOR ENABLED false

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH DISPLAY_NAME "Version Patch"
set_parameter_property VERSION_PATCH ALLOWED_RANGES 0:15
set_parameter_property VERSION_PATCH HDL_PARAMETER true
set_parameter_property VERSION_PATCH ENABLED false

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD DISPLAY_NAME "Build Stamp"
set_parameter_property BUILD ALLOWED_RANGES 0:4095
set_parameter_property BUILD HDL_PARAMETER true
set_parameter_property BUILD ENABLED false
set_parameter_property BUILD DESCRIPTION {12-bit MMDD packaging stamp packed into META page 0 VERSION[11:0].}

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE DISPLAY_NAME "Version Date"
set_parameter_property VERSION_DATE ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_DATE HDL_PARAMETER true
set_parameter_property VERSION_DATE ENABLED false
set_parameter_property VERSION_DATE DESCRIPTION {YYYYMMDD packaging date exposed through META page 1.}

add_parameter VERSION_GIT NATURAL $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT DISPLAY_NAME "Git Stamp"
set_parameter_property VERSION_GIT ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT HDL_PARAMETER true
set_parameter_property VERSION_GIT ENABLED false
set_parameter_property VERSION_GIT DESCRIPTION {Truncated source git stamp exposed through META page 2.}

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID ALLOWED_RANGES 0:2147483647
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID ENABLED true
set_parameter_property INSTANCE_ID DESCRIPTION {Per-instance integration identifier exposed through META page 3.}

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item "" $TAB_IDENTITY      GROUP tab
add_display_item "" $TAB_INTERFACES    GROUP tab
add_display_item "" $TAB_REGMAP        GROUP tab

add_display_item $TAB_CONFIGURATION "Profile" GROUP
add_html_text "Profile" profile_html "<html><b>Fixed4 profile</b><br/>MuSiP-local fixed 4-lane native-SystemVerilog wrapper for the Mu3e Demo OPQ profile. The RTL fallback profile is N_SHD=128 and N_HIT=255, with one expected hit loss for a 256-hit cluster. Packaged as <b>${OPQ_VERSION_STRING}</b> (git <b>${OPQ_GIT_HEX_STRING}</b>).</html>"

add_display_item $TAB_IDENTITY "Versioning" GROUP
add_html_text "Versioning" versioning_html $OPQ_VERSIONING_HTML
add_display_item "Versioning" IP_UID        parameter
add_display_item "Versioning" VERSION_MAJOR parameter
add_display_item "Versioning" VERSION_MINOR parameter
add_display_item "Versioning" VERSION_PATCH parameter
add_display_item "Versioning" BUILD         parameter
add_display_item "Versioning" VERSION_DATE  parameter
add_display_item "Versioning" VERSION_GIT   parameter
add_display_item "Versioning" INSTANCE_ID   parameter

add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Ingress"       GROUP
add_display_item $TAB_INTERFACES "Egress"        GROUP
add_display_item $TAB_INTERFACES "CSR"           GROUP
add_html_text "Clock / Reset" clock_html {<html><b>clk_interface</b> / <b>rst_interface</b><br/>Single synchronous data-path domain for ingress, egress, and CSR access.</html>}
add_html_text "Ingress" ingress_html {<html><b>ingress_0..ingress_3</b> are fixed 36-bit Avalon-ST sinks with channel, start/end-of-packet, valid, and error sidebands.</html>}
add_html_text "Egress" egress_html {<html><b>egress</b> is a fixed 36-bit Avalon-ST source with ready backpressure.</html>}
add_html_text "CSR" csr_html {<html><b>csr</b> is a 32-bit Avalon-MM slave with 9-bit word address. It implements the common Mu3e UID + META identity header plus OPQ runtime control, status, and counters.</html>}

add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_window_html $OPQ_CSR_WINDOW_HTML
add_display_item $TAB_REGMAP "META Fields (0x001)" GROUP
add_html_text "META Fields (0x001)" meta_fields_html $OPQ_META_FIELDS_HTML
add_display_item $TAB_REGMAP "CTRL Fields (0x003)" GROUP
add_html_text "CTRL Fields (0x003)" ctrl_fields_html $OPQ_CTRL_FIELDS_HTML
add_display_item $TAB_REGMAP "STATUS Fields (0x004)" GROUP
add_html_text "STATUS Fields (0x004)" status_fields_html $OPQ_STATUS_FIELDS_HTML
add_display_item $TAB_REGMAP "CAP Fields (0x005)" GROUP
add_html_text "CAP Fields (0x005)" cap_fields_html $OPQ_CAP_FIELDS_HTML
add_display_item $TAB_REGMAP "Lane Region (0x040 + lane*0x10)" GROUP
add_html_text "Lane Region (0x040 + lane*0x10)" lane_region_html $OPQ_LANE_REGION_HTML

add_interface egress avalon_streaming start
set_interface_property egress associatedClock clk_interface
set_interface_property egress associatedReset rst_interface
set_interface_property egress dataBitsPerSymbol 36
set_interface_property egress errorDescriptor {hit_err shd_err hdr_err}
set_interface_property egress firstSymbolInHighOrderBits true
set_interface_property egress readyLatency 0
set_interface_property egress ENABLED true
add_interface_port egress aso_egress_startofpacket startofpacket Output 1
add_interface_port egress aso_egress_endofpacket endofpacket Output 1
add_interface_port egress aso_egress_valid valid Output 1
add_interface_port egress aso_egress_ready ready Input 1
add_interface_port egress aso_egress_error error Output 3
add_interface_port egress aso_egress_data data Output 36

add_interface clk_interface clock end
set_interface_property clk_interface clockRate 0
set_interface_property clk_interface ENABLED true
add_interface_port clk_interface d_clk clk Input 1

add_interface rst_interface reset end
set_interface_property rst_interface associatedClock clk_interface
set_interface_property rst_interface synchronousEdges BOTH
set_interface_property rst_interface ENABLED true
add_interface_port rst_interface d_reset reset Input 1

add_interface csr avalon end
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock clk_interface
set_interface_property csr associatedReset rst_interface
set_interface_property csr bitsPerSymbol 8
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr burstcountUnits WORDS
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 1
set_interface_property csr maximumPendingWriteTransactions 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address address Input 9
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_writedata writedata Input 32
add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_readdatavalid readdatavalid Output 1
add_interface_port csr avs_csr_waitrequest waitrequest Output 1
add_interface_port csr avs_csr_burstcount burstcount Input 1

foreach lane {0 1 2 3} {
    add_interface ingress_${lane} avalon_streaming end
    set_interface_property ingress_${lane} associatedClock clk_interface
    set_interface_property ingress_${lane} associatedReset rst_interface
    set_interface_property ingress_${lane} dataBitsPerSymbol 36
    set_interface_property ingress_${lane} errorDescriptor {hit_err shd_err hdr_err}
    set_interface_property ingress_${lane} firstSymbolInHighOrderBits true
    set_interface_property ingress_${lane} maxChannel 3
    set_interface_property ingress_${lane} readyLatency 0
    set_interface_property ingress_${lane} ENABLED true
    add_interface_port ingress_${lane} asi_ingress_${lane}_channel channel Input 2
    add_interface_port ingress_${lane} asi_ingress_${lane}_startofpacket startofpacket Input 1
    add_interface_port ingress_${lane} asi_ingress_${lane}_endofpacket endofpacket Input 1
    add_interface_port ingress_${lane} asi_ingress_${lane}_data data Input 36
    add_interface_port ingress_${lane} asi_ingress_${lane}_valid valid Input 1
    add_interface_port ingress_${lane} asi_ingress_${lane}_error error Input 3
}
