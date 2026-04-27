package require Tcl 8.5

namespace eval ::fe_scifi::runctl_log_probe {
    variable default_project_root "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi"
}

proc ::fe_scifi::runctl_log_probe::usage {} {
    puts "usage: system-console --script=runctl_log_fifo_probe.tcl ?--master-index N? ?--base-address HEX? ?--tuples N? ?--flush? ?--list?"
}

proc ::fe_scifi::runctl_log_probe::parse_args {} {
    array set opts [list \
        master_index -1 \
        base_address 0x20 \
        tuples 1 \
        flush 0 \
        list_only 0]

    set idx 0
    while {$idx < $::argc} {
        set arg [lindex $::argv $idx]
        switch -- $arg {
            --master-index {
                incr idx
                if {$idx >= $::argc} {
                    error "missing value for --master-index"
                }
                set opts(master_index) [lindex $::argv $idx]
            }
            --base-address {
                incr idx
                if {$idx >= $::argc} {
                    error "missing value for --base-address"
                }
                set opts(base_address) [lindex $::argv $idx]
            }
            --tuples {
                incr idx
                if {$idx >= $::argc} {
                    error "missing value for --tuples"
                }
                set opts(tuples) [lindex $::argv $idx]
            }
            --flush {
                set opts(flush) 1
            }
            --list {
                set opts(list_only) 1
            }
            --help {
                ::fe_scifi::runctl_log_probe::usage
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

proc ::fe_scifi::runctl_log_probe::fmt_u32 {value} {
    return [format "0x%08X" [expr {$value & 0xFFFFFFFF}]]
}

proc ::fe_scifi::runctl_log_probe::fmt_u48 {value} {
    return [format "0x%012llX" [expr {wide($value)}]]
}

proc ::fe_scifi::runctl_log_probe::decode_cmd {cmd_value} {
    switch -- $cmd_value {
        0x10 { return "RUN_PREPARE" }
        0x11 { return "RUN_SYNC" }
        0x12 { return "START_RUN" }
        0x13 { return "END_RUN" }
        0x14 { return "ABORT_RUN" }
        0x30 { return "RESET" }
        0x31 { return "STOP_RESET" }
        0x32 { return "ENABLE" }
        0x33 { return "DISABLE" }
        0x40 { return "ADDRESS" }
        default {
            return [format "UNKNOWN_%s" [::fe_scifi::runctl_log_probe::fmt_u32 $cmd_value]]
        }
    }
}

proc ::fe_scifi::runctl_log_probe::configure_runtime_paths {project_root} {
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

proc ::fe_scifi::runctl_log_probe::select_master_path {requested_index} {
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

proc ::fe_scifi::runctl_log_probe::emit_tuple {tuple_index tuple_words} {
    if {[llength $tuple_words] != 4} {
        error "expected 4 words per tuple, got [llength $tuple_words]"
    }

    set exec_ts [expr {[lindex $tuple_words 0] + 0}]
    set payload [expr {[lindex $tuple_words 1] + 0}]
    set info    [expr {[lindex $tuple_words 2] + 0}]
    set recv_hi [expr {[lindex $tuple_words 3] + 0}]
    set recv_ts [expr {((wide($recv_hi) & 0xFFFFFFFF) << 16) | (($info >> 16) & 0xFFFF)}]
    set cmd     [expr {$info & 0xFF}]
    set is_empty [expr {$exec_ts == 0 && $payload == 0 && $info == 0 && $recv_hi == 0}]

    puts "TUPLE_${tuple_index}_RAW=$tuple_words"
    puts "TUPLE_${tuple_index}_EMPTY=$is_empty"
    puts "TUPLE_${tuple_index}_CMD=[::fe_scifi::runctl_log_probe::decode_cmd $cmd]"
    puts "TUPLE_${tuple_index}_PAYLOAD=[::fe_scifi::runctl_log_probe::fmt_u32 $payload]"
    puts "TUPLE_${tuple_index}_EXEC_TS=[::fe_scifi::runctl_log_probe::fmt_u32 $exec_ts]"
    puts "TUPLE_${tuple_index}_RECV_TS=[::fe_scifi::runctl_log_probe::fmt_u48 $recv_ts]"
}

proc ::fe_scifi::runctl_log_probe::main {} {
    array set opts [::fe_scifi::runctl_log_probe::parse_args]

    set project_root $::fe_scifi::runctl_log_probe::default_project_root
    ::fe_scifi::runctl_log_probe::configure_runtime_paths $project_root

    set selected_path [::fe_scifi::runctl_log_probe::select_master_path $opts(master_index)]
    puts "SELECTED_MASTER=$selected_path"

    if {$opts(list_only)} {
        return
    }

    set master_fd [claim_service master $selected_path ""]
    set base_address [expr {$opts(base_address) + 0}]
    puts "BASE_ADDRESS=[::fe_scifi::runctl_log_probe::fmt_u32 $base_address]"

    if {$opts(flush)} {
        master_write_32 $master_fd $base_address 0x0
        puts "FLUSHED=1"
    }

    for {set idx 0} {$idx < $opts(tuples)} {incr idx} {
        set tuple [master_read_32 $master_fd $base_address 4]
        ::fe_scifi::runctl_log_probe::emit_tuple $idx $tuple
    }

    close_service master $master_fd
}

if {[catch {::fe_scifi::runctl_log_probe::main} err]} {
    puts "ERROR: $err"
    return -code error $err
}
