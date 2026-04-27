package require Tcl 8.5

namespace eval ::fe_scifi::runctl_dp_selfrun_probe {
    variable default_project_root "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi"
}

proc ::fe_scifi::runctl_dp_selfrun_probe::usage {} {
    puts "usage: system-console --script=runctl_dp_selfrun_probe.tcl ?--master-index N? ?--master-match GLOB? ?--base-address HEX? ?--emu-base HEX? ?--emu-count N? ?--emu-stride HEX? ?--gap-cycles N? ?--polls N? ?--poll-ms N? ?--launch-self-run? ?--no-status? ?--list?"
}

proc ::fe_scifi::runctl_dp_selfrun_probe::parse_args {} {
    array set opts [list \
        master_index -1 \
        master_match "" \
        base_address 0x2200 \
        emu_base 0x2000 \
        emu_count 8 \
        emu_stride 0x40 \
        gap_cycles -1 \
        polls 10 \
        poll_ms 100 \
        launch_self_run 0 \
        read_status 1 \
        list_only 0]

    set idx 0
    while {$idx < $::argc} {
        set arg [lindex $::argv $idx]
        switch -- $arg {
            --master-index -
            --master-match -
            --base-address -
            --emu-base -
            --emu-count -
            --emu-stride -
            --gap-cycles -
            --polls -
            --poll-ms {
                incr idx
                if {$idx >= $::argc} {
                    error "missing value for $arg"
                }
                set value [lindex $::argv $idx]
                switch -- $arg {
                    --master-index { set opts(master_index) $value }
                    --master-match { set opts(master_match) $value }
                    --base-address { set opts(base_address) $value }
                    --emu-base { set opts(emu_base) $value }
                    --emu-count { set opts(emu_count) $value }
                    --emu-stride { set opts(emu_stride) $value }
                    --gap-cycles { set opts(gap_cycles) $value }
                    --polls { set opts(polls) $value }
                    --poll-ms { set opts(poll_ms) $value }
                }
            }
            --launch-self-run {
                set opts(launch_self_run) 1
            }
            --no-status {
                set opts(read_status) 0
            }
            --list {
                set opts(list_only) 1
            }
            --help {
                ::fe_scifi::runctl_dp_selfrun_probe::usage
                return -code return
            }
            default {
                error "unknown option: $arg"
            }
        }
        incr idx
    }

    return [array get opts]
}

proc ::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 {value} {
    return [format "0x%08X" [expr {$value & 0xFFFFFFFF}]]
}

proc ::fe_scifi::runctl_dp_selfrun_probe::configure_runtime_paths {project_root} {
    set tcllib_dir "/data1/intelFPGA/18.1/quartus/common/tcl/packages/tcllib-1.11"
    foreach rel [list \
        system_console/lib \
        system_console/lib/tclxml-3.2 \
        system_console/lib/tcldom-3.0 \
        system_console/lib/tdom-0.9.4-src] {
        set path [file join $project_root $rel]
        if {[lsearch -exact $::auto_path $path] < 0} {
            lappend ::auto_path $path
        }
    }
    if {[lsearch -exact $::auto_path $tcllib_dir] < 0} {
        lappend ::auto_path $tcllib_dir
    }
}

proc ::fe_scifi::runctl_dp_selfrun_probe::select_master_path {requested_index requested_match} {
    package require mu3e::helpers 1.0
    source "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl"
    ::mu3e::helpers::clear_service_preferences
    ::mu3e::helpers::configure_project_spec [::fe_scifi::board_bring_up::project::get_spec]
    set paths [::mu3e::helpers::prioritize_service_paths master [get_service_paths master]]

    puts "MASTER_COUNT=[llength $paths]"
    set idx 0
    foreach path $paths {
        puts [format "MASTER_%d=%s" $idx $path]
        incr idx
    }

    if {$requested_match ne ""} {
        foreach path $paths {
            if {[string match $requested_match $path]} {
                return $path
            }
        }
        error "requested --master-match ${requested_match} did not match any master path"
    }

    if {$requested_index >= 0} {
        if {$requested_index >= [llength $paths]} {
            error "requested --master-index ${requested_index} is out of range"
        }
        return [lindex $paths $requested_index]
    }

    if {[llength $paths] == 0} {
        error "no master services found"
    }

    return [lindex $paths 0]
}

proc ::fe_scifi::runctl_dp_selfrun_probe::read_u32 {master_fd addr} {
    return [expr {[master_read_32 $master_fd $addr 1] + 0}]
}

proc ::fe_scifi::runctl_dp_selfrun_probe::decode_state {state_word} {
    switch -- [expr {$state_word & 0x1FF}] {
        1 { return "IDLE" }
        2 { return "RUN_PREPARE" }
        4 { return "SYNC" }
        8 { return "RUNNING" }
        16 { return "TERMINATING" }
        64 { return "RESET" }
        256 { return "OUT_OF_DAQ" }
        default { return "UNKNOWN" }
    }
}

proc ::fe_scifi::runctl_dp_selfrun_probe::decode_host_cmd {cmd_value} {
    set cmd_int [expr {$cmd_value + 0}]
    switch -- $cmd_int {
        16 { return "RUN_PREPARE" }
        17 { return "RUN_SYNC" }
        18 { return "START_RUN" }
        19 { return "END_RUN" }
        20 { return "ABORT_RUN" }
        48 { return "RESET" }
        49 { return "STOP_RESET" }
        50 { return "ENABLE" }
        51 { return "DISABLE" }
        0  { return "DIRECT_STATE" }
        default { return [format "UNKNOWN_%s" [::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $cmd_int]] }
    }
}

proc ::fe_scifi::runctl_dp_selfrun_probe::emit_dbg_status {master_fd base_address prefix} {
    set id_word      [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_address + 0x00}]]
    set status_word  [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_address + 0x04}]]
    set control_word [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_address + 0x08}]]
    set gap_word     [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_address + 0x18}]]
    set sent_word    [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_address + 0x1C}]]
    set last_word    [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_address + 0x20}]]

    set gap_cycles   [expr {($status_word >> 16) & 0xFFFF}]
    set local_enable [expr {$status_word & 0x1}]
    set pending      [expr {($status_word >> 1) & 0x1}]
    set script_busy  [expr {($status_word >> 2) & 0x1}]
    set overrun      [expr {($status_word >> 3) & 0x1}]
    set bad_cmd      [expr {($status_word >> 4) & 0x1}]
    set last_host    [expr {($status_word >> 5) & 0x1}]

    set last_state   [expr {$last_word & 0x1FF}]
    set last_from_host [expr {($last_word >> 9) & 0x1}]
    set last_cmd     [expr {($last_word >> 10) & 0xFF}]

    puts "${prefix}_ID=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $id_word]"
    puts "${prefix}_STATUS=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $status_word]"
    puts "${prefix}_CONTROL=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $control_word]"
    puts "${prefix}_GAP_CFG=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $gap_word]"
    puts "${prefix}_SENT_COUNT=$sent_word"
    puts "${prefix}_LOCAL_ENABLE=$local_enable"
    puts "${prefix}_PENDING=$pending"
    puts "${prefix}_SCRIPT_BUSY=$script_busy"
    puts "${prefix}_STICKY_OVERRUN=$overrun"
    puts "${prefix}_STICKY_BAD_CMD=$bad_cmd"
    puts "${prefix}_LAST_FROM_HOST=$last_host"
    puts "${prefix}_GAP_CYCLES=$gap_cycles"
    puts "${prefix}_LAST_SENT=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $last_word]"
    puts "${prefix}_LAST_SENT_CMD=[::fe_scifi::runctl_dp_selfrun_probe::decode_host_cmd $last_cmd]"
    puts "${prefix}_LAST_SENT_STATE=[::fe_scifi::runctl_dp_selfrun_probe::decode_state $last_state]"
    puts "${prefix}_LAST_SENT_FROM_HOST=$last_from_host"
}

proc ::fe_scifi::runctl_dp_selfrun_probe::capture_emulator_status {master_fd emu_base emu_count emu_stride} {
    set rows {}
    for {set idx 0} {$idx < $emu_count} {incr idx} {
        set base_addr   [expr {$emu_base + $idx * $emu_stride}]
        set ctrl_word   [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_addr + 0x00}]]
        set rate_word   [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_addr + 0x04}]]
        set txmode_word [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_addr + 0x10}]]
        set stat_word   [::fe_scifi::runctl_dp_selfrun_probe::read_u32 $master_fd [expr {$base_addr + 0x14}]]
        set frame_count [expr {$stat_word & 0xFFFF}]
        set event_count [expr {($stat_word >> 16) & 0x3FF}]
        lappend rows [list $idx $base_addr $ctrl_word $rate_word $txmode_word $stat_word $frame_count $event_count]
    }
    return $rows
}

proc ::fe_scifi::runctl_dp_selfrun_probe::emit_emulator_status {prefix rows {baseline {}}} {
    array set base_frame {}
    array set base_event {}
    if {[llength $baseline] > 0} {
        foreach row $baseline {
            lassign $row idx _ _ _ _ _ frame_count event_count
            set base_frame($idx) $frame_count
            set base_event($idx) $event_count
        }
    }

    foreach row $rows {
        lassign $row idx base_addr ctrl_word rate_word txmode_word stat_word frame_count event_count
        set frame_delta 0
        set event_delta 0
        if {[info exists base_frame($idx)]} {
            set frame_delta [expr {$frame_count - $base_frame($idx)}]
            set event_delta [expr {$event_count - $base_event($idx)}]
        }
        puts [format "%s_EMU_%d_BASE=%s" $prefix $idx [::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $base_addr]]
        puts [format "%s_EMU_%d_CTRL=%s" $prefix $idx [::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $ctrl_word]]
        puts [format "%s_EMU_%d_RATE=%s" $prefix $idx [::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $rate_word]]
        puts [format "%s_EMU_%d_TXMODE=%s" $prefix $idx [::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $txmode_word]]
        puts [format "%s_EMU_%d_STATUS=%s" $prefix $idx [::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $stat_word]]
        puts [format "%s_EMU_%d_FRAME_COUNT=%d" $prefix $idx $frame_count]
        puts [format "%s_EMU_%d_EVENT_COUNT=%d" $prefix $idx $event_count]
        puts [format "%s_EMU_%d_FRAME_DELTA=%d" $prefix $idx $frame_delta]
        puts [format "%s_EMU_%d_EVENT_DELTA=%d" $prefix $idx $event_delta]
    }
}

proc ::fe_scifi::runctl_dp_selfrun_probe::main {} {
    array set opts [::fe_scifi::runctl_dp_selfrun_probe::parse_args]

    set project_root $::fe_scifi::runctl_dp_selfrun_probe::default_project_root
    ::fe_scifi::runctl_dp_selfrun_probe::configure_runtime_paths $project_root

    set selected_path [::fe_scifi::runctl_dp_selfrun_probe::select_master_path $opts(master_index) $opts(master_match)]
    puts "SELECTED_MASTER=$selected_path"
    if {$opts(list_only)} {
        return
    }

    set master_fd [claim_service master $selected_path ""]
    set base_address [expr {$opts(base_address) + 0}]
    set emu_base [expr {$opts(emu_base) + 0}]
    set emu_stride [expr {$opts(emu_stride) + 0}]
    puts "DBG_BASE=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $base_address]"

    ::fe_scifi::runctl_dp_selfrun_probe::emit_dbg_status $master_fd $base_address "BEFORE"
    set baseline_rows {}
    if {$opts(read_status)} {
        set baseline_rows [::fe_scifi::runctl_dp_selfrun_probe::capture_emulator_status $master_fd $emu_base $opts(emu_count) $emu_stride]
        ::fe_scifi::runctl_dp_selfrun_probe::emit_emulator_status "BEFORE" $baseline_rows
    }

    if {$opts(gap_cycles) >= 0} {
        set gap_cfg [expr {($opts(gap_cycles) & 0xFFFF) << 16}]
        master_write_32 $master_fd [expr {$base_address + 0x18}] $gap_cfg
        puts "WRITE_GAP=[::fe_scifi::runctl_dp_selfrun_probe::fmt_u32 $gap_cfg]"
    }

    if {$opts(launch_self_run)} {
        master_write_32 $master_fd [expr {$base_address + 0x08}] 0x00000007
        puts "WRITE_CONTROL=0x00000007"
        master_write_32 $master_fd [expr {$base_address + 0x14}] 0x00000001
        puts "WRITE_SCRIPT=0x00000001"
    }

    for {set idx 0} {$idx < $opts(polls)} {incr idx} {
        if {$opts(poll_ms) > 0} {
            after $opts(poll_ms)
        }
        ::fe_scifi::runctl_dp_selfrun_probe::emit_dbg_status $master_fd $base_address [format "POLL_%02d" $idx]
    }

    if {$opts(read_status)} {
        set final_rows [::fe_scifi::runctl_dp_selfrun_probe::capture_emulator_status $master_fd $emu_base $opts(emu_count) $emu_stride]
        ::fe_scifi::runctl_dp_selfrun_probe::emit_emulator_status "AFTER" $final_rows $baseline_rows
    }

    close_service master $master_fd
}

if {[catch {::fe_scifi::runctl_dp_selfrun_probe::main} err]} {
    puts "ERROR: $err"
    return -code error $err
}
