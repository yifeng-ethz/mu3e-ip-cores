package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 6
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         512
set VERSION_DATE_DEFAULT_CONST  20260512
set VERSION_GIT_DEFAULT_CONST   0x00000000
set IP_UID_DEFAULT_CONST        0x41485430 ;# ASCII "AHT0"
set INSTANCE_ID_DEFAULT_CONST   0

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         arb_hit_type0
set_module_property DISPLAY_NAME                 "Arbiter hit_type0 (real / emu / mix RR)"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Per-lane arbiter on the post-deassembly hit_type0 boundary with 16-deep ingress FIFOs per source. Modes: REAL (real-only), EMU (emulator-only), MIX_RR (beat-level round-robin, multi-channel packetized egress). MIX_RR requires multi-channel packet support in every downstream consumer (hit processor / rbCAM); see Identity tab warning."
set_module_property GROUP                        "Mu3e Emulators/Modules"

# Elaboration callback emits a Platform Designer warning when MIX_RR is the
# default mode, because that selects the multi-channel packetized egress at
# reset and every downstream consumer must support per-channel packet state.
set_module_property ELABORATION_CALLBACK         elaborate
set_module_property VALIDATION_CALLBACK          validate

proc validate {} {
    set mode [get_parameter_value MODE_DEFAULT]
    set debug_level [get_parameter_value DEBUG_LEVEL]
    if {$mode == 2} {
        send_message warning "MODE_DEFAULT = MIX_RR. Merge-packet FSM collapses two source frames into one merged Avalon-ST packet (single-packet boundary, channel varies per beat). Per-beat channel demux at the downstream consumer is the audit gate before MIX_RR is promoted into a production datapath. See misc/arb_hit_type0/doc/RTL_PLAN.md sections 1 and 2.2."
    }
    if {$debug_level < 0 || $debug_level > 2} {
        send_message error "DEBUG_LEVEL must be 0 (off), 1 (FIFO levels), or 2 (FIFO levels plus per-hit metadata)."
    }
}

proc elaborate {} {
    set debug_level [get_parameter_value DEBUG_LEVEL]
    catch {set_interface_property debug_fifo ENABLED [expr {$debug_level >= 1}]}
    catch {set_interface_property real_hit_debug ENABLED [expr {$debug_level >= 2}]}
    catch {set_interface_property emu_hit_debug ENABLED [expr {$debug_level >= 2}]}
    catch {set_interface_property selected_hit_debug ENABLED [expr {$debug_level >= 2}]}

    catch {
        set_display_item_property mix_rr_warning_html TEXT "<html><b>MIX_RR mode warning</b><br/>In MIX_RR a merge-packet FSM combines the two source frames into <b>one merged Avalon-ST packet per merged_open window</b>. Single-packet boundary tracking is sufficient at the consumer (no per-channel SOP/EOP tracking required). However, per-beat <b>channel</b> still varies across the merged packet, so any consumer that separates the two sources' contributions (e.g. for per-source golden-reference plots) must read <b>channel</b> per beat. The Avalon-ST <b>channel</b> sideband and <b>maxChannel &gt; 0</b> declared at <b>mts_processor.hit_type0_in</b> and <b>ring_buffer_cam.hit_type1</b> is the contract; the per-beat channel use inside those IPs must be independently verified before MIX_RR is promoted to a production datapath. Treat MIX_RR as debug/test-only until the downstream chain is verified.</html>"
    }
}
set_module_property AUTHOR                       "Mu3e IP team"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL arb_hit_type0
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file arb_hit_type0_fifo.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_fifo.sv
add_fileset_file arb_hit_type0_arbiter.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_arbiter.sv
add_fileset_file arb_hit_type0_watchdog.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_watchdog.sv
add_fileset_file arb_hit_type0_runctl.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_runctl.sv
add_fileset_file arb_hit_type0_csr.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_csr.sv
add_fileset_file arb_hit_type0.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL arb_hit_type0
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file arb_hit_type0_fifo.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_fifo.sv
add_fileset_file arb_hit_type0_arbiter.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_arbiter.sv
add_fileset_file arb_hit_type0_watchdog.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_watchdog.sv
add_fileset_file arb_hit_type0_runctl.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_runctl.sv
add_fileset_file arb_hit_type0_csr.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0_csr.sv
add_fileset_file arb_hit_type0.sv SYSTEM_VERILOG PATH ../rtl/arb_hit_type0.sv TOP_LEVEL_FILE

# ---------- Parameters ----------

add_parameter MODE_DEFAULT NATURAL 0
set_parameter_property MODE_DEFAULT DISPLAY_NAME "Reset Mode (0=REAL, 1=EMU, 2=MIX_RR)"
set_parameter_property MODE_DEFAULT ALLOWED_RANGES 0:2
set_parameter_property MODE_DEFAULT HDL_PARAMETER true
set_parameter_property MODE_DEFAULT DESCRIPTION "Reset value for CONTROL.mode. 0 = REAL (real-only, single-channel egress), 1 = EMU (emulator-only, single-channel egress), 2 = MIX_RR (beat-level round-robin with merge-packet FSM, per-beat channel demuxes source 0..7=real, 8..15=emu)."

add_parameter WATCHDOG_DEFAULT NATURAL 500
set_parameter_property WATCHDOG_DEFAULT DISPLAY_NAME "Frame-alignment watchdog default (cycles)"
set_parameter_property WATCHDOG_DEFAULT ALLOWED_RANGES 0:65535
set_parameter_property WATCHDOG_DEFAULT HDL_PARAMETER true
set_parameter_property WATCHDOG_DEFAULT DESCRIPTION "Reset value for WATCHDOG_CYCLES CSR. After this many idle cycles on a stranded source while the peer has EORed or also gone silent, the watchdog synthesizes the missing EOP (and EOR if applicable) so the merged packet closes deterministically. 0 disables the watchdog (one-sided run-end then leaves the merged packet open until reset)."

add_parameter DEBUG_LEVEL NATURAL 0
set_parameter_property DEBUG_LEVEL DISPLAY_NAME "Debug Level"
set_parameter_property DEBUG_LEVEL ALLOWED_RANGES 0:2
set_parameter_property DEBUG_LEVEL HDL_PARAMETER true
set_parameter_property DEBUG_LEVEL AFFECTS_ELABORATION true
set_parameter_property DEBUG_LEVEL DESCRIPTION "0 disables optional debug conduits and keeps nominal synthesis behavior. 1 exposes FIFO fill-level observability. 2 also stores and propagates 64-bit per-hit debug metadata from real_hit_debug/emu_hit_debug to selected_hit_debug."

# Identity / Interfaces / Register Map tabs and the MIX_RR warning panel.
set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY    "Identity"
set TAB_INTERFACES  "Interfaces"
set TAB_REGMAP      "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Datapath" GROUP
add_display_item $TAB_CONFIGURATION "Debug" GROUP
add_display_item "Datapath" MODE_DEFAULT parameter
add_display_item "Datapath" WATCHDOG_DEFAULT parameter
add_display_item "Debug" DEBUG_LEVEL parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "MIX_RR Warning" GROUP
add_display_item "MIX_RR Warning" mix_rr_warning_html TEXT ""
set_display_item_property mix_rr_warning_html DISPLAY_HINT html
set_display_item_property mix_rr_warning_html TEXT "<html><b>MIX_RR mode warning</b><br/>In MIX_RR a merge-packet FSM combines the two source frames into <b>one merged Avalon-ST packet per merged_open window</b>. Single-packet boundary tracking is sufficient at the consumer (no per-channel SOP/EOP tracking required). However, per-beat <b>channel</b> still varies across the merged packet, so any consumer that separates the two sources' contributions (e.g. for per-source golden-reference plots) must read <b>channel</b> per beat. The Avalon-ST <b>channel</b> sideband and <b>maxChannel &gt; 0</b> declared at <b>mts_processor.hit_type0_in</b> and <b>ring_buffer_cam.hit_type1</b> is the contract; the per-beat channel use inside those IPs must be independently verified before MIX_RR is promoted to a production datapath. Treat MIX_RR as debug/test-only until the downstream chain is verified.</html>"
add_display_item $TAB_IDENTITY IP_UID parameter
add_display_item $TAB_IDENTITY INSTANCE_ID parameter

add_parameter FIFO_DEPTH NATURAL 16
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Per-source ingress FIFO depth"
set_parameter_property FIFO_DEPTH ALLOWED_RANGES {16}
set_parameter_property FIFO_DEPTH HDL_PARAMETER true
add_display_item "Datapath" FIFO_DEPTH parameter

add_parameter IP_UID STD_LOGIC_VECTOR $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID WIDTH 32
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID DESCRIPTION {Software-visible IP identifier at CSR word 0. Default ASCII "AHT0".}

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR HDL_PARAMETER true
set_parameter_property VERSION_MAJOR VISIBLE false

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR HDL_PARAMETER true
set_parameter_property VERSION_MINOR VISIBLE false

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH HDL_PARAMETER true
set_parameter_property VERSION_PATCH VISIBLE false

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD HDL_PARAMETER true
set_parameter_property BUILD VISIBLE false

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE HDL_PARAMETER true
set_parameter_property VERSION_DATE VISIBLE false

add_parameter VERSION_GIT STD_LOGIC_VECTOR $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT WIDTH 32
set_parameter_property VERSION_GIT HDL_PARAMETER true
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT VISIBLE false

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID DESCRIPTION "Per-integration instance identifier exposed through META page 3."

# ---------- Interfaces ----------

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
set_interface_property csr readLatency 1
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address     address     Input  5
add_interface_port csr avs_csr_write       write       Input  1
add_interface_port csr avs_csr_read        read        Input  1
add_interface_port csr avs_csr_writedata   writedata   Input  32
add_interface_port csr avs_csr_readdata    readdata    Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1

# Run-control sink: 9-bit Avalon-ST sink, one cycle per state command.
# IP sync-resets internal state on RUN_PREP and RESET states (decoded
# inside the IP per the runctl_mgmt_host shared encoding).
add_interface run_ctrl avalon_streaming end
set_interface_property run_ctrl associatedClock clk
set_interface_property run_ctrl associatedReset rst
set_interface_property run_ctrl dataBitsPerSymbol 9
set_interface_property run_ctrl errorDescriptor ""
set_interface_property run_ctrl firstSymbolInHighOrderBits true
set_interface_property run_ctrl maxChannel 0
set_interface_property run_ctrl readyLatency 0
set_interface_property run_ctrl ENABLED true
add_interface_port run_ctrl asi_ctrl_data  data  Input 9
add_interface_port run_ctrl asi_ctrl_valid valid Input 1

add_interface real_in avalon_streaming end
set_interface_property real_in associatedClock clk
set_interface_property real_in associatedReset rst
set_interface_property real_in dataBitsPerSymbol 45
set_interface_property real_in symbolsPerBeat 1
set_interface_property real_in readyLatency 0
set_interface_property real_in maxChannel 15
set_interface_property real_in errorDescriptor "hiterr frameerr overflow"
set_interface_property real_in firstSymbolInHighOrderBits true
set_interface_property real_in ENABLED true
add_interface_port real_in asi_real_data          data          Input 45
add_interface_port real_in asi_real_valid         valid         Input 1
add_interface_port real_in asi_real_error         error         Input 3
add_interface_port real_in asi_real_channel       channel       Input 4
add_interface_port real_in asi_real_startofpacket startofpacket Input 1
add_interface_port real_in asi_real_endofpacket   endofpacket   Input 1
add_interface_port real_in asi_real_endofrun      endofrun      Input 1

add_interface emu_in avalon_streaming end
set_interface_property emu_in associatedClock clk
set_interface_property emu_in associatedReset rst
set_interface_property emu_in dataBitsPerSymbol 45
set_interface_property emu_in symbolsPerBeat 1
set_interface_property emu_in readyLatency 0
set_interface_property emu_in maxChannel 15
set_interface_property emu_in errorDescriptor "hiterr frameerr overflow"
set_interface_property emu_in firstSymbolInHighOrderBits true
set_interface_property emu_in ENABLED true
add_interface_port emu_in asi_emu_data          data          Input 45
add_interface_port emu_in asi_emu_valid         valid         Input 1
add_interface_port emu_in asi_emu_error         error         Input 3
add_interface_port emu_in asi_emu_channel       channel       Input 4
add_interface_port emu_in asi_emu_startofpacket startofpacket Input 1
add_interface_port emu_in asi_emu_endofpacket   endofpacket   Input 1
add_interface_port emu_in asi_emu_endofrun      endofrun      Input 1

add_interface selected_out avalon_streaming start
set_interface_property selected_out associatedClock clk
set_interface_property selected_out associatedReset rst
set_interface_property selected_out dataBitsPerSymbol 45
set_interface_property selected_out symbolsPerBeat 1
set_interface_property selected_out readyLatency 0
set_interface_property selected_out maxChannel 15
set_interface_property selected_out errorDescriptor "hiterr frameerr overflow"
set_interface_property selected_out firstSymbolInHighOrderBits true
set_interface_property selected_out ENABLED true
add_interface_port selected_out aso_data          data          Output 45
add_interface_port selected_out aso_valid         valid         Output 1
add_interface_port selected_out aso_error         error         Output 3
add_interface_port selected_out aso_channel       channel       Output 4
add_interface_port selected_out aso_startofpacket startofpacket Output 1
add_interface_port selected_out aso_endofpacket   endofpacket   Output 1
add_interface_port selected_out aso_endofrun      endofrun      Output 1

add_interface debug_fifo conduit start
set_interface_property debug_fifo associatedClock clk
set_interface_property debug_fifo associatedReset rst
set_interface_property debug_fifo ENABLED false
add_interface_port debug_fifo coe_debug_real_fifo_level real_fifo_level Output 5
add_interface_port debug_fifo coe_debug_emu_fifo_level  emu_fifo_level  Output 5
add_interface_port debug_fifo coe_debug_fifo_flags      fifo_flags      Output 8

add_interface real_hit_debug conduit end
set_interface_property real_hit_debug associatedClock clk
set_interface_property real_hit_debug associatedReset rst
set_interface_property real_hit_debug ENABLED false
add_interface_port real_hit_debug coe_debug_real_hit_metadata       metadata Input 64
add_interface_port real_hit_debug coe_debug_real_hit_metadata_valid valid    Input 1

add_interface emu_hit_debug conduit end
set_interface_property emu_hit_debug associatedClock clk
set_interface_property emu_hit_debug associatedReset rst
set_interface_property emu_hit_debug ENABLED false
add_interface_port emu_hit_debug coe_debug_emu_hit_metadata       metadata Input 64
add_interface_port emu_hit_debug coe_debug_emu_hit_metadata_valid valid    Input 1

add_interface selected_hit_debug conduit start
set_interface_property selected_hit_debug associatedClock clk
set_interface_property selected_hit_debug associatedReset rst
set_interface_property selected_hit_debug ENABLED false
add_interface_port selected_hit_debug coe_debug_selected_hit_metadata       metadata Output 64
add_interface_port selected_hit_debug coe_debug_selected_hit_metadata_valid valid    Output 1
