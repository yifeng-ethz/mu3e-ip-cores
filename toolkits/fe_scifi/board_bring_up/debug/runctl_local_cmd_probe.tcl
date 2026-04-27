package require Tcl 8.5

namespace eval ::fe_scifi::runctl_local_cmd_probe {
    variable default_project_root "/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi"
    variable csr_uid          0x00
    variable csr_control      0x02
    variable csr_status       0x03
    variable csr_last_cmd     0x04
    variable csr_run_number   0x06
    variable csr_rx_cmd_count 0x0F
    variable csr_rx_err_count 0x10
    variable csr_log_status   0x11
    variable csr_log_pop      0x12
    variable csr_local_cmd    0x13
    variable csr_ack_symbols  0x14
}

proc ::fe_scifi::runctl_local_cmd_probe::usage {} {
    puts "usage: system-console --script=runctl_local_cmd_probe.tcl ?--master-index N? ?--master-match GLOB? ?--base-address HEX? ?--tuples N? ?--flush? ?--inject HEX? ?--sleep-ms N? ?--emu-base HEX? ?--emu-count N? ?--emu-stride HEX? ?--status?"
}

proc ::fe_scifi::runctl_local_cmd_probe::parse_args {} {
    array set opts [list \
        master_index -1 \
        master_match "" \
        base_address 0x16000 \
        tuples 1 \
        flush 0 \
        list_only 0 \
        inject_list {} \
        sleep_ms 100 \
        emu_base 0x2000 \
        emu_count 8 \
        emu_stride 0x40 \
        read_status 0]

    set idx 0
    while {$idx < $::argc} {
        set arg [lindex $::argv $idx]
        switch -- $arg {
            --master-index -
            --master-match -
            --base-address -
            --tuples -
            --inject -
            --sleep-ms -
            --emu-base -
            --emu-count -
            --emu-stride {
                incr idx
                if {$idx >= $::argc} {
                    error "missing value for $arg"
                }
                set value [lindex $::argv $idx]
                switch -- $arg {
                    --master-index { set opts(master_index) $value }
                    --master-match { set opts(master_match) $value }
                    --base-address { set opts(base_address) $value }
                    --tuples { set opts(tuples) $value }
                    --inject { lappend opts(inject_list) $value }
                    --sleep-ms { set opts(sleep_ms) $value }
                    --emu-base { set opts(emu_base) $value }
                    --emu-count { set opts(emu_count) $value }
                    --emu-stride { set opts(emu_stride) $value }
                }
            }
            --flush {
                set opts(flush) 1
            }
            --status {
                set opts(read_status) 1
            }
            --list {
                set opts(list_only) 1
            }
            --help {
                ::fe_scifi::runctl_local_cmd_probe::usage
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

proc ::fe_scifi::runctl_local_cmd_probe::fmt_u32 {value} {
    return [format "0x%08X" [expr {$value & 0xFFFFFFFF}]]
}

proc ::fe_scifi::runctl_local_cmd_probe::fmt_u48 {value} {
    return [format "0x%012llX" [expr {wide($value)}]]
}

proc ::fe_scifi::runctl_local_cmd_probe::decode_cmd {cmd_value} {
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
        64 { return "ADDRESS" }
        default {
            return [format "UNKNOWN_%s" [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $cmd_int]]
        }
    }
}

proc ::fe_scifi::runctl_local_cmd_probe::decode_recv_state {state_word} {
    switch -- [expr {$state_word + 0}] {
        0 { return "IDLE" }
        1 { return "RX_PAYLOAD" }
        2 { return "LOGGING" }
        3 { return "LOG_ERROR" }
        4 { return "CLEANUP" }
        default { return [format "RECV_%s" [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $state_word]] }
    }
}

proc ::fe_scifi::runctl_local_cmd_probe::decode_host_state {state_word} {
    switch -- [expr {$state_word + 0}] {
        0 { return "IDLE" }
        1 { return "POSTING" }
        2 { return "CLEANUP" }
        default { return [format "HOST_%s" [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $state_word]] }
    }
}

proc ::fe_scifi::runctl_local_cmd_probe::configure_runtime_paths {project_root} {
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

proc ::fe_scifi::runctl_local_cmd_probe::select_master_path {requested_index requested_match} {
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

proc ::fe_scifi::runctl_local_cmd_probe::csr_addr {base_address reg_word} {
    return [expr {$base_address + (($reg_word + 0) << 2)}]
}

proc ::fe_scifi::runctl_local_cmd_probe::read_reg {master_fd base_address reg_word} {
    return [expr {[master_read_32 $master_fd [::fe_scifi::runctl_local_cmd_probe::csr_addr $base_address $reg_word] 1] + 0}]
}

proc ::fe_scifi::runctl_local_cmd_probe::write_reg {master_fd base_address reg_word value} {
    master_write_32 $master_fd [::fe_scifi::runctl_local_cmd_probe::csr_addr $base_address $reg_word] $value
}

proc ::fe_scifi::runctl_local_cmd_probe::emit_tuple {tuple_index tuple_words} {
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
    puts "TUPLE_${tuple_index}_CMD=[::fe_scifi::runctl_local_cmd_probe::decode_cmd $cmd]"
    puts "TUPLE_${tuple_index}_PAYLOAD=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $payload]"
    puts "TUPLE_${tuple_index}_EXEC_TS=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $exec_ts]"
    puts "TUPLE_${tuple_index}_RECV_TS=[::fe_scifi::runctl_local_cmd_probe::fmt_u48 $recv_ts]"
}

proc ::fe_scifi::runctl_local_cmd_probe::read_log_tuple {master_fd base_address} {
    variable csr_log_pop
    set tuple_words {}
    for {set word_idx 0} {$word_idx < 4} {incr word_idx} {
        lappend tuple_words [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_log_pop]
    }
    return $tuple_words
}

proc ::fe_scifi::runctl_local_cmd_probe::flush_log_fifo {master_fd base_address} {
    variable csr_control
    set control_word [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_control]
    ::fe_scifi::runctl_local_cmd_probe::write_reg $master_fd $base_address $csr_control [expr {$control_word | 0x2}]
}

proc ::fe_scifi::runctl_local_cmd_probe::emit_host_status {master_fd base_address} {
    variable csr_uid
    variable csr_status
    variable csr_last_cmd
    variable csr_run_number
    variable csr_rx_cmd_count
    variable csr_rx_err_count
    variable csr_log_status
    variable csr_ack_symbols
    variable csr_local_cmd

    set uid_word      [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_uid]
    set status_word   [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_status]
    set last_cmd_word [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_last_cmd]
    set run_word      [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_run_number]
    set rx_cmd_word   [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_rx_cmd_count]
    set rx_err_word   [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_rx_err_count]
    set log_word      [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_log_status]
    set ack_word      [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_ack_symbols]
    set local_word    [::fe_scifi::runctl_local_cmd_probe::read_reg $master_fd $base_address $csr_local_cmd]

    set recv_idle     [expr {$status_word & 0x1}]
    set host_idle     [expr {($status_word >> 1) & 0x1}]
    set dp_reset      [expr {($status_word >> 4) & 0x1}]
    set ct_reset      [expr {($status_word >> 5) & 0x1}]
    set recv_state    [expr {($status_word >> 8) & 0xFF}]
    set host_state    [expr {($status_word >> 16) & 0xFF}]
    set local_busy    [expr {($status_word >> 30) & 0x1}]
    set log_empty     [expr {($status_word >> 31) & 0x1}]
    set fpga_addr     [expr {($last_cmd_word >> 16) & 0xFFFF}]
    set last_cmd      [expr {$last_cmd_word & 0xFF}]
    set log_usedw     [expr {$log_word & 0x3FF}]
    set log_empty_ro  [expr {($log_word >> 16) & 0x1}]
    set log_full      [expr {($log_word >> 17) & 0x1}]
    set ack_start     [expr {$ack_word & 0xFF}]
    set ack_end       [expr {($ack_word >> 8) & 0xFF}]

    puts "HOST_UID=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $uid_word]"
    puts "HOST_STATUS=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $status_word]"
    puts "HOST_RECV_IDLE=$recv_idle"
    puts "HOST_HOST_IDLE=$host_idle"
    puts "HOST_DP_HARD_RESET=$dp_reset"
    puts "HOST_CT_HARD_RESET=$ct_reset"
    puts "HOST_RECV_STATE=[::fe_scifi::runctl_local_cmd_probe::decode_recv_state $recv_state]"
    puts "HOST_HOST_STATE=[::fe_scifi::runctl_local_cmd_probe::decode_host_state $host_state]"
    puts "HOST_LOCAL_CMD_BUSY=$local_busy"
    puts "HOST_STATUS_LOG_EMPTY=$log_empty"
    puts "HOST_LAST_CMD_WORD=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $last_cmd_word]"
    puts "HOST_LAST_CMD=[::fe_scifi::runctl_local_cmd_probe::decode_cmd $last_cmd]"
    puts "HOST_LAST_FPGA_ADDR=[format \"0x%04X\" $fpga_addr]"
    puts "HOST_RUN_NUMBER=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $run_word]"
    puts "HOST_RX_CMD_COUNT=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $rx_cmd_word]"
    puts "HOST_RX_ERR_COUNT=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $rx_err_word]"
    puts "HOST_LOG_STATUS=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $log_word]"
    puts "HOST_LOG_USEDW=$log_usedw"
    puts "HOST_LOG_EMPTY=$log_empty_ro"
    puts "HOST_LOG_FULL=$log_full"
    puts "HOST_LOCAL_CMD_WORD=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $local_word]"
    puts "HOST_ACK_START=[format \"0x%02X\" $ack_start]"
    puts "HOST_ACK_END=[format \"0x%02X\" $ack_end]"
}

proc ::fe_scifi::runctl_local_cmd_probe::emit_emulator_status {master_fd emu_base emu_count emu_stride} {
    set emu_base   [expr {$emu_base + 0}]
    set emu_count  [expr {$emu_count + 0}]
    set emu_stride [expr {$emu_stride + 0}]
    for {set idx 0} {$idx < $emu_count} {incr idx} {
        set base_addr   [expr {$emu_base + $idx * $emu_stride}]
        set ctrl_addr   [expr {$base_addr + 0x00}]
        set rate_addr   [expr {$base_addr + 0x04}]
        set txmode_addr [expr {$base_addr + 0x10}]
        set stat_addr   [expr {$base_addr + 0x14}]
        set ctrl_word   [master_read_32 $master_fd $ctrl_addr 1]
        set rate_word   [master_read_32 $master_fd $rate_addr 1]
        set txmode_word [master_read_32 $master_fd $txmode_addr 1]
        set stat_word   [master_read_32 $master_fd $stat_addr 1]
        set frame_count [expr {$stat_word & 0xFFFF}]
        set event_count [expr {($stat_word >> 16) & 0x3FF}]
        puts [format "EMU_%d_BASE=%s" $idx [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $base_addr]]
        puts [format "EMU_%d_CTRL=%s" $idx [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $ctrl_word]]
        puts [format "EMU_%d_RATE=%s" $idx [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $rate_word]]
        puts [format "EMU_%d_TXMODE=%s" $idx [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $txmode_word]]
        puts [format "EMU_%d_STATUS=%s" $idx [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $stat_word]]
        puts [format "EMU_%d_FRAME_COUNT=%d" $idx $frame_count]
        puts [format "EMU_%d_EVENT_COUNT=%d" $idx $event_count]
    }
}

proc ::fe_scifi::runctl_local_cmd_probe::main {} {
    variable csr_local_cmd
    array set opts [::fe_scifi::runctl_local_cmd_probe::parse_args]

    set project_root $::fe_scifi::runctl_local_cmd_probe::default_project_root
    ::fe_scifi::runctl_local_cmd_probe::configure_runtime_paths $project_root

    set selected_path [::fe_scifi::runctl_local_cmd_probe::select_master_path $opts(master_index) $opts(master_match)]
    puts "SELECTED_MASTER=$selected_path"

    if {$opts(list_only)} {
        return
    }

    set master_fd [claim_service master $selected_path ""]
    set base_address [expr {$opts(base_address) + 0}]
    puts "BASE_ADDRESS=[::fe_scifi::runctl_local_cmd_probe::fmt_u32 $base_address]"

    if {$opts(flush)} {
        ::fe_scifi::runctl_local_cmd_probe::flush_log_fifo $master_fd $base_address
        puts "FLUSHED=1"
    }

    set inject_idx 0
    foreach inject_word $opts(inject_list) {
        set inject_value [expr {$inject_word + 0}]
        puts [format "INJECT_%d_WORD=%s" $inject_idx [::fe_scifi::runctl_local_cmd_probe::fmt_u32 $inject_value]]
        puts [format "INJECT_%d_CMD=%s" $inject_idx [::fe_scifi::runctl_local_cmd_probe::decode_cmd [expr {$inject_value & 0xFF}]]]
        ::fe_scifi::runctl_local_cmd_probe::write_reg $master_fd $base_address $csr_local_cmd $inject_value
        if {$opts(sleep_ms) > 0} {
            after $opts(sleep_ms)
        }
        incr inject_idx
    }

    for {set idx 0} {$idx < $opts(tuples)} {incr idx} {
        set tuple [::fe_scifi::runctl_local_cmd_probe::read_log_tuple $master_fd $base_address]
        ::fe_scifi::runctl_local_cmd_probe::emit_tuple $idx $tuple
    }

    if {$opts(read_status)} {
        ::fe_scifi::runctl_local_cmd_probe::emit_host_status $master_fd $base_address
        ::fe_scifi::runctl_local_cmd_probe::emit_emulator_status \
            $master_fd $opts(emu_base) $opts(emu_count) $opts(emu_stride)
    }

    close_service master $master_fd
}

if {[catch {::fe_scifi::runctl_local_cmd_probe::main} err]} {
    puts "ERROR: $err"
    return -code error $err
}
