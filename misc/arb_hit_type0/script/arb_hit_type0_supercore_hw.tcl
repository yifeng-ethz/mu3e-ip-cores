package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 4
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         0505
set VERSION_DATE_DEFAULT_CONST  20260505
set VERSION_GIT_DEFAULT_CONST   0x00000000
set IP_UID_DEFAULT_CONST        0x41485430 ;# ASCII "AHT0"

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         arb_hit_type0_supercore
set_module_property DISPLAY_NAME                 "Arbiter hit_type0 supercore"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Qsys-composed multi-lane wrapper around arb_hit_type0. One run-control sink is split to all lanes; each lane keeps an independent CSR aperture and independent real/emu/selected hit_type0 streams."
set_module_property GROUP                        "Mu3e Emulators/Modules"
set_module_property AUTHOR                       "Mu3e IP team"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false
set_module_property VALIDATION_CALLBACK          validate
set_module_property ELABORATION_CALLBACK         elaborate
set_module_property COMPOSITION_CALLBACK         compose

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

add_parameter LANE_COUNT NATURAL 8
set_parameter_property LANE_COUNT DISPLAY_NAME "Lane count"
set_parameter_property LANE_COUNT ALLOWED_RANGES 1:32
set_parameter_property LANE_COUNT HDL_PARAMETER false
set_parameter_property LANE_COUNT AFFECTS_ELABORATION true
set_parameter_property LANE_COUNT DESCRIPTION "Number of arb_hit_type0 lane instances composed into this supercore."

add_parameter MODE_DEFAULT NATURAL 0
set_parameter_property MODE_DEFAULT DISPLAY_NAME "Reset Mode (0=REAL, 1=EMU, 2=MIX_RR)"
set_parameter_property MODE_DEFAULT ALLOWED_RANGES 0:2
set_parameter_property MODE_DEFAULT HDL_PARAMETER false
set_parameter_property MODE_DEFAULT DESCRIPTION "Reset value propagated to each lane's CONTROL.mode."

add_parameter WATCHDOG_DEFAULT NATURAL 500
set_parameter_property WATCHDOG_DEFAULT DISPLAY_NAME "Frame-alignment watchdog default (cycles)"
set_parameter_property WATCHDOG_DEFAULT ALLOWED_RANGES 0:65535
set_parameter_property WATCHDOG_DEFAULT HDL_PARAMETER false
set_parameter_property WATCHDOG_DEFAULT DESCRIPTION "Reset value propagated to each lane's WATCHDOG_CYCLES CSR."

add_parameter FIFO_DEPTH NATURAL 16
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Per-source ingress FIFO depth"
set_parameter_property FIFO_DEPTH ALLOWED_RANGES {16}
set_parameter_property FIFO_DEPTH HDL_PARAMETER false
set_parameter_property FIFO_DEPTH DESCRIPTION "Per-source ingress FIFO depth propagated to each lane."

add_display_item "" "Configuration" GROUP tab
add_display_item "Configuration" LANE_COUNT parameter
add_display_item "Configuration" MODE_DEFAULT parameter
add_display_item "Configuration" WATCHDOG_DEFAULT parameter
add_display_item "Configuration" FIFO_DEPTH parameter

add_display_item "" "Interfaces" GROUP tab
add_html_text "Interfaces" interfaces_html {<html>
<b>Composition contract</b><br/>
The supercore exports one <b>clk</b>, one active-high synchronous <b>rst</b>, and one 9-bit
Avalon-ST <b>run_ctrl</b> sink. Internally, run-control is broadcast through an
altera_avalon_st_splitter with ready disabled.<br/><br/>
For every lane <b>i</b>, the component exports:
<ul>
<li><b>csr_i</b>: 32-word Avalon-MM lane CSR aperture</li>
<li><b>real_in_i</b>: real post-deassembly hit_type0 stream</li>
<li><b>emu_in_i</b>: emulator hit_type0 stream</li>
<li><b>selected_out_i</b>: selected hit_type0 stream to downstream FIFO/MTS</li>
</ul>
</html>}

add_display_item "" "Register Map" GROUP tab
add_html_text "Register Map" regmap_html {<html>
Each lane is one unmodified <b>arb_hit_type0</b> instance. The integrating Qsys
system assigns one 32-word CSR aperture per exported <b>csr_i</b>. Lane-local
register contents match <b>misc/arb_hit_type0/script/arb_hit_type0_hw.tcl</b>.
</html>}

set SUPERCORE_MAX_STATIC_LANES 32

proc add_static_clock_reset_runctrl_interfaces {} {
    add_interface clk clock end
    set_interface_property clk ENABLED true

    add_interface rst reset end
    set_interface_property rst associatedClock clk
    set_interface_property rst synchronousEdges DEASSERT
    set_interface_property rst ENABLED true

    add_interface run_ctrl avalon_streaming end
    set_interface_property run_ctrl associatedClock clk
    set_interface_property run_ctrl associatedReset rst
    set_interface_property run_ctrl dataBitsPerSymbol 9
    set_interface_property run_ctrl errorDescriptor ""
    set_interface_property run_ctrl firstSymbolInHighOrderBits true
    set_interface_property run_ctrl maxChannel 0
    set_interface_property run_ctrl readyLatency 0
    set_interface_property run_ctrl ENABLED true
}

proc add_static_csr_interface {name enabled} {
    add_interface $name avalon end
    set_interface_property $name addressUnits WORDS
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset rst
    set_interface_property $name bitsPerSymbol 8
    set_interface_property $name burstOnBurstBoundariesOnly false
    set_interface_property $name explicitAddressSpan 0
    set_interface_property $name holdTime 0
    set_interface_property $name linewrapBursts false
    set_interface_property $name maximumPendingReadTransactions 0
    set_interface_property $name readLatency 0
    set_interface_property $name readWaitTime 1
    set_interface_property $name setupTime 0
    set_interface_property $name timingUnits Cycles
    set_interface_property $name writeWaitTime 0
    set_interface_property $name ENABLED $enabled
}

proc add_static_hit_stream_interface {name dir enabled} {
    add_interface $name avalon_streaming $dir
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset rst
    set_interface_property $name dataBitsPerSymbol 45
    set_interface_property $name symbolsPerBeat 1
    set_interface_property $name readyLatency 0
    set_interface_property $name maxChannel 15
    set_interface_property $name errorDescriptor "hiterr frameerr overflow"
    set_interface_property $name firstSymbolInHighOrderBits true
    set_interface_property $name ENABLED $enabled
}

add_static_clock_reset_runctrl_interfaces
for {set lane 0} {$lane < $SUPERCORE_MAX_STATIC_LANES} {incr lane} {
    set enabled [expr {$lane < 8}]
    add_static_csr_interface csr_$lane $enabled
    add_static_hit_stream_interface real_in_$lane end $enabled
    add_static_hit_stream_interface emu_in_$lane end $enabled
    add_static_hit_stream_interface selected_out_$lane start $enabled
}

proc set_lane_interfaces_enabled {lane enabled} {
    foreach prefix {csr real_in emu_in selected_out} {
        catch {set_interface_property ${prefix}_$lane ENABLED $enabled}
    }
}

proc elaborate {} {
    set lane_count [get_parameter_value LANE_COUNT]
    for {set lane 0} {$lane < $::SUPERCORE_MAX_STATIC_LANES} {incr lane} {
        set_lane_interfaces_enabled $lane [expr {$lane < $lane_count}]
    }
}

proc validate {} {
    set lane_count [get_parameter_value LANE_COUNT]
    set mode_default [get_parameter_value MODE_DEFAULT]
    set watchdog_default [get_parameter_value WATCHDOG_DEFAULT]
    set fifo_depth [get_parameter_value FIFO_DEPTH]

    if {$lane_count < 1 || $lane_count > 32} {
        send_message error "LANE_COUNT must be in the range 1..32."
    }
    if {$mode_default < 0 || $mode_default > 2} {
        send_message error "MODE_DEFAULT must be 0 (REAL), 1 (EMU), or 2 (MIX_RR)."
    }
    if {$watchdog_default < 0 || $watchdog_default > 65535} {
        send_message error "WATCHDOG_DEFAULT must be in the range 0..65535."
    }
    if {$fifo_depth != 16} {
        send_message error "FIFO_DEPTH is fixed at 16 for arb_hit_type0."
    }
    if {$mode_default == 2} {
        send_message warning "MODE_DEFAULT = MIX_RR. Downstream per-beat channel handling must be verified before production use."
    }
}

proc set_child_param_if_present {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        send_message info "Optional child parameter ${inst}.${name} not present: $err"
    }
}

proc export_existing_interface {name type dir target} {
    catch {add_interface $name $type $dir}
    set_interface_property $name ENABLED true
    set_interface_property $name EXPORT_OF $target
}

proc compose {} {
    set lane_count [get_parameter_value LANE_COUNT]
    set mode_default [get_parameter_value MODE_DEFAULT]
    set watchdog_default [get_parameter_value WATCHDOG_DEFAULT]
    set fifo_depth [get_parameter_value FIFO_DEPTH]

    add_instance clk_bridge altera_clock_bridge 18.1
    set_instance_parameter_value clk_bridge EXPLICIT_CLOCK_RATE 0.0
    set_instance_parameter_value clk_bridge NUM_CLOCK_OUTPUTS 1

    add_instance reset_bridge altera_reset_bridge 18.1
    set_instance_parameter_value reset_bridge ACTIVE_LOW_RESET 0
    set_instance_parameter_value reset_bridge SYNCHRONOUS_EDGES deassert
    set_instance_parameter_value reset_bridge NUM_RESET_OUTPUTS 1
    set_instance_parameter_value reset_bridge USE_RESET_REQUEST 0

    add_instance run_ctrl_splitter altera_avalon_st_splitter 18.1
    set_instance_parameter_value run_ctrl_splitter BITS_PER_SYMBOL 9
    set_instance_parameter_value run_ctrl_splitter CHANNEL_WIDTH 1
    set_instance_parameter_value run_ctrl_splitter DATA_WIDTH 9
    set_instance_parameter_value run_ctrl_splitter ERROR_DESCRIPTOR ""
    set_instance_parameter_value run_ctrl_splitter ERROR_WIDTH 1
    set_instance_parameter_value run_ctrl_splitter MAX_CHANNELS 1
    set_instance_parameter_value run_ctrl_splitter NUMBER_OF_OUTPUTS $lane_count
    set_instance_parameter_value run_ctrl_splitter QUALIFY_VALID_OUT 0
    set_instance_parameter_value run_ctrl_splitter READY_LATENCY 0
    set_instance_parameter_value run_ctrl_splitter USE_CHANNEL 0
    set_instance_parameter_value run_ctrl_splitter USE_DATA 1
    set_instance_parameter_value run_ctrl_splitter USE_ERROR 0
    set_instance_parameter_value run_ctrl_splitter USE_PACKETS 0
    set_instance_parameter_value run_ctrl_splitter USE_READY 0
    set_instance_parameter_value run_ctrl_splitter USE_VALID 1

    add_connection clk_bridge.out_clk reset_bridge.clk clock
    add_connection clk_bridge.out_clk run_ctrl_splitter.clk clock
    add_connection reset_bridge.out_reset run_ctrl_splitter.reset reset

    for {set lane 0} {$lane < $lane_count} {incr lane} {
        set inst lane_$lane
        add_instance $inst arb_hit_type0 26.4.0.0505
        set_instance_parameter_value $inst MODE_DEFAULT $mode_default
        set_instance_parameter_value $inst WATCHDOG_DEFAULT $watchdog_default
        set_instance_parameter_value $inst FIFO_DEPTH $fifo_depth
        set_instance_parameter_value $inst IP_UID $IP_UID_DEFAULT_CONST
        set_instance_parameter_value $inst INSTANCE_ID $lane
        set_child_param_if_present $inst VERSION_MAJOR $VERSION_MAJOR_DEFAULT_CONST
        set_child_param_if_present $inst VERSION_MINOR $VERSION_MINOR_DEFAULT_CONST
        set_child_param_if_present $inst VERSION_PATCH $VERSION_PATCH_DEFAULT_CONST
        set_child_param_if_present $inst BUILD $BUILD_DEFAULT_CONST
        set_child_param_if_present $inst VERSION_DATE $VERSION_DATE_DEFAULT_CONST
        set_child_param_if_present $inst VERSION_GIT $VERSION_GIT_DEFAULT_CONST

        add_connection clk_bridge.out_clk $inst.clk clock
        add_connection reset_bridge.out_reset $inst.rst reset
        add_connection run_ctrl_splitter.out$lane $inst.run_ctrl avalon_streaming

        export_existing_interface csr_$lane avalon end $inst.csr
        export_existing_interface real_in_$lane avalon_streaming end $inst.real_in
        export_existing_interface emu_in_$lane avalon_streaming end $inst.emu_in
        export_existing_interface selected_out_$lane avalon_streaming start $inst.selected_out
    }

    export_existing_interface clk clock end clk_bridge.in_clk
    export_existing_interface rst reset end reset_bridge.in_reset
    export_existing_interface run_ctrl avalon_streaming end run_ctrl_splitter.in
}
