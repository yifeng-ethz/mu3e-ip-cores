# Headless JTAG preset for Phase-5 injector-path SignalTap debug.
#
# This script is intentionally narrow. The current debug_sc_system_v3 Qsys
# image does not connect jtag_master.master to mm_bridge.s0, so FEB datapath
# CSRs such as mutrig_injector_0 and histogram_statistics_0 are not reachable
# through this JTAG master. Use sc_tool word addresses for datapath stimulus.
# Keep this guard in place unless the generated Qsys JTAG topology is changed
# and the JTAG byte bases are re-derived from the generated address inventory.

set script_dir "."
if {[info exists ::env(BOARD_TEST_SCRIPT_DIR)] && $::env(BOARD_TEST_SCRIPT_DIR) ne ""} {
    set script_dir $::env(BOARD_TEST_SCRIPT_DIR)
} elseif {[info script] ne ""} {
    set script_dir [file dirname [file normalize [info script]]]
} elseif {[info exists ::argv0] && [string match *.tcl $::argv0]} {
    set script_dir [file dirname [file normalize $::argv0]]
}
source [file join $script_dir headless_jtag_common.tcl]

proc usage {} {
    puts "Usage:"
    puts "  system-console ... --script=phase5_injector_jtag_preset.tcl -- \\"
    puts "      --action <setup|stop|snapshot> [--pulse-interval <cycles>] \\"
    puts "      [--pulse-high-cycles <cycles>] [--active-lanes-mask <mask>] \\"
    puts "      [--source-emulator-mask <mask>] [--skip-source-mux] \\"
    puts "      [--skip-histogram] [--skip-emulator] [--skip-runctl] \\"
    puts "      [--skip-injector-config] \\"
    puts "      [--skip-snapshot] [--master-pattern <glob>] \\"
    puts "      [--fallback-pattern <glob>] [--service-tag <tag>]"
    puts ""
    puts "Current status: disabled for datapath CSR access. The generated"
    puts "debug_sc_system_v3 JTAG master does not connect to mm_bridge.s0."
    puts "Use run_phase5_injector_datapath_sanity.py over sc_tool instead."
}

proc hex32 {value} {
    return [format "0x%08X" [expr {$value & 0xFFFFFFFF}]]
}

proc wr32 {svc addr value label} {
    master_write_32 $svc $addr $value
    puts [format "JTAG_PRESET_WRITE label=%s addr=%s value=%s" $label [hex32 $addr] [hex32 $value]]
    after 20
}

proc wrburst32 {svc addr values label} {
    master_write_32 $svc $addr $values
    set idx 0
    foreach value $values {
        puts [format "JTAG_PRESET_WRITE label=%s[%u] addr=%s value=%s" \
            $label $idx [hex32 [expr {$addr + (4 * $idx)}]] [hex32 $value]]
        incr idx
    }
    after 20
}

proc rd32 {svc addr label} {
    set words [master_read_32 $svc $addr 1]
    set value [lindex $words 0]
    puts [format "JTAG_PRESET_READ label=%s addr=%s value=%s" $label [hex32 $addr] [hex32 $value]]
    return $value
}

proc parse_mask {text name} {
    set value [::board_test::jtag::parse_u32 $text]
    if {$value < 0 || $value > 255} {
        error "$name must be in range 0x00..0xff"
    }
    return $value
}

proc emu_base {idx} {
    return [expr {0x00022000 + (0x40 * $idx)}]
}

proc source_mux_base {idx} {
    return [expr {0x00022240 + (0x40 * $idx)}]
}

proc configure_lvds {svc} {
    wr32 $svc 0x00020010 0x000001FF lvds_lane_go
}

proc configure_source_mux {svc source_mask active_mask clear_counters} {
    for {set idx 0} {$idx < 8} {incr idx} {
        if {(($active_mask >> $idx) & 1) == 0} {
            continue
        }
        set control 0
        if {(($source_mask >> $idx) & 1) != 0} {
            set control [expr {$control | 0x1}]
        }
        if {$clear_counters} {
            set control [expr {$control | 0x2}]
        }
        wr32 $svc [expr {[source_mux_base $idx] + 0x08}] $control "source_mux${idx}_control"
    }
}

proc configure_histogram {svc} {
    wr32 $svc 0x0002A40C 0x00000000 hist_left_bound
    wr32 $svc 0x0002A410 0x000000FF hist_right_bound
    wr32 $svc 0x0002A414 0x00000001 hist_bin_width
    wr32 $svc 0x0002A418 0x26231511 hist_update_key_channel_post
    wr32 $svc 0x0002A428 0x3FFFFFFF hist_interval_cfg
    wr32 $svc 0x0002A408 0x00000101 hist_control_apply_unsigned
    after 100
    rd32 $svc 0x0002A408 hist_control_after_apply
    wr32 $svc 0x0002A000 0x00000000 hist_clear_bin0
    after 50
    wr32 $svc 0x0002AC08 0x00000001 hist_ingress_select_post
    after 100
    rd32 $svc 0x0002AC0C hist_ingress_status
}

proc configure_emulators {svc active_mask} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set base [emu_base $idx]
        set enabled [expr {(($active_mask >> $idx) & 1) != 0}]
        wr32 $svc [expr {$base + 0x00}] 0x00000000 "emu${idx}_disable"
        wr32 $svc [expr {$base + 0x04}] 0x00000000 "emu${idx}_rate"
        set cluster [expr {0x00000001 | (16 << 8) | (16 << 14) | (($idx & 0xf) << 22) | (8 << 26)}]
        wr32 $svc [expr {$base + 0x08}] $cluster "emu${idx}_cluster"
        wr32 $svc [expr {$base + 0x0C}] [expr {0xDEADBEEF ^ $idx}] "emu${idx}_seed"
        wr32 $svc [expr {$base + 0x10}] [expr {0x00000008 | ($idx << 4)}] "emu${idx}_tx_mode"
        wr32 $svc [expr {$base + 0x18}] 0xFFFFFFFF "emu${idx}_inject_channel_mask"
        set control [expr {$enabled ? 0x00000001 : 0x00000000}]
        wr32 $svc [expr {$base + 0x00}] $control "emu${idx}_control"
    }
}

proc configure_injector {svc pulse_interval pulse_high} {
    set values [list \
        0x00000000 \
        0x00000064 \
        0x00000001 \
        0x00000001 \
        0x00000000 \
        $pulse_interval \
        $pulse_high \
        0x000003E7 \
        0x00000001 \
        0x0000ACE1 \
        0x00000004]
    set idx 0
    foreach value $values {
        wr32 $svc [expr {0x0002B200 + (4 * $idx)}] $value "injector_config${idx}"
        incr idx
    }
}

proc start_local_run {svc} {
    wr32 $svc 0x00022208 0x00000007 dbg_runctl_control_clear_enable
    wr32 $svc 0x00022218 0x00040000 dbg_runctl_gap_cycles
    wr32 $svc 0x00022214 0x00000001 dbg_runctl_self_run_script
    after 250
    rd32 $svc 0x00022204 dbg_runctl_status_after_self_run
    rd32 $svc 0x0002221C dbg_runctl_sent_count_after_self_run
    rd32 $svc 0x00022220 dbg_runctl_last_sent_after_self_run
}

proc stop_local_run {svc} {
    wr32 $svc 0x0002B200 0x00000000 injector_mode_off
    wr32 $svc 0x00022214 0x00000002 dbg_runctl_end_run_script
    after 100
    rd32 $svc 0x00022204 dbg_runctl_status_after_end_run
    rd32 $svc 0x0002221C dbg_runctl_sent_count_after_end_run
    rd32 $svc 0x00022220 dbg_runctl_last_sent_after_end_run
}

proc snapshot {svc} {
    rd32 $svc 0x0002B200 injector_mode
    rd32 $svc 0x0002B214 injector_pulse_interval
    rd32 $svc 0x0002A400 hist_uid
    rd32 $svc 0x0002AC00 hist_ingress_uid
    rd32 $svc 0x00022204 dbg_runctl_status
    rd32 $svc 0x0002221C dbg_runctl_sent_count
    rd32 $svc 0x0002A434 hist_total_hits
    rd32 $svc 0x0002A438 hist_dropped_hits
    for {set idx 0} {$idx < 8} {incr idx} {
        rd32 $svc [expr {[emu_base $idx] + 0x14}] "emu${idx}_status"
        rd32 $svc [expr {[source_mux_base $idx] + 0x18}] "source_mux${idx}_selected_beats"
    }
}

if {[catch {
    usage
    error "phase5_injector_jtag_preset is disabled: datapath CSRs are SC-only in the current Qsys topology"

    lassign [::board_test::jtag::parse_args \
        $argv \
        {action pulse-interval pulse-high-cycles active-lanes-mask source-emulator-mask master-pattern fallback-pattern service-tag} \
        {skip-source-mux skip-histogram skip-emulator skip-runctl skip-injector-config skip-snapshot}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }
    if {$opts(action) eq ""} {
        usage
        error "--action is required"
    }

    set action [string tolower $opts(action)]
    if {$action ni {setup stop snapshot}} {
        usage
        error "--action must be setup, stop, or snapshot"
    }

    set pulse_interval 12500
    if {$opts(pulse-interval) ne ""} {
        set pulse_interval [::board_test::jtag::parse_u32 $opts(pulse-interval)]
    }
    set pulse_high 5
    if {$opts(pulse-high-cycles) ne ""} {
        set pulse_high [::board_test::jtag::parse_u32 $opts(pulse-high-cycles)]
    }
    set active_mask 0xFF
    if {$opts(active-lanes-mask) ne ""} {
        set active_mask [parse_mask $opts(active-lanes-mask) "--active-lanes-mask"]
    }
    set source_mask 0xFF
    if {$opts(source-emulator-mask) ne ""} {
        set source_mask [parse_mask $opts(source-emulator-mask) "--source-emulator-mask"]
    }
    set service_tag "phase5_injector_jtag_preset"
    if {$opts(service-tag) ne ""} {
        set service_tag $opts(service-tag)
    }

    set claim [::board_test::jtag::claim_matching_master \
        $opts(master-pattern) \
        $opts(fallback-pattern) \
        0x00000400 \
        0x53434842 \
        $service_tag]
    set svc [dict get $claim service]
    set master_path [dict get $claim path]
    set matched_uid [dict get $claim uid]

    puts [format "JTAG_PRESET_BEGIN action=%s master={%s} uid=%s pulse_interval=%u pulse_high_cycles=%u active_lanes_mask=%s source_emulator_mask=%s" \
        $action \
        $master_path \
        $matched_uid \
        $pulse_interval \
        $pulse_high \
        [hex32 $active_mask] \
        [hex32 $source_mask]]

    if {$action eq "setup"} {
        configure_lvds $svc
        if {!$opts(skip-source-mux)} {
            configure_source_mux $svc $source_mask $active_mask 1
        } else {
            puts "JTAG_PRESET_SKIP block=source_mux"
        }
        if {!$opts(skip-histogram)} {
            configure_histogram $svc
        } else {
            puts "JTAG_PRESET_SKIP block=histogram"
        }
        if {!$opts(skip-emulator)} {
            configure_emulators $svc $active_mask
        } else {
            puts "JTAG_PRESET_SKIP block=emulator"
        }
        if {!$opts(skip-injector-config)} {
            configure_injector $svc $pulse_interval $pulse_high
        } else {
            puts "JTAG_PRESET_SKIP block=injector_config"
        }
        if {!$opts(skip-runctl)} {
            start_local_run $svc
        } else {
            puts "JTAG_PRESET_SKIP block=runctl"
        }
        wr32 $svc 0x0002B200 0x00000002 injector_mode_periodic
        after 50
        if {!$opts(skip-snapshot)} {
            snapshot $svc
        } else {
            puts "JTAG_PRESET_SKIP block=snapshot"
        }
    } elseif {$action eq "stop"} {
        stop_local_run $svc
        snapshot $svc
    } else {
        snapshot $svc
    }

    ::board_test::jtag::close_claim $svc
    puts [format "JTAG_PRESET_RESULT status=OK action=%s" $action]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
