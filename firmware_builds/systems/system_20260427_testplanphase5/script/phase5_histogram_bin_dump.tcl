# Headless System Console helper for Phase-5 histogram-bin CSV snapshots.
#
# The script configures histogram_statistics_0, clears the histogram SRAM, waits
# one measurement interval, then dumps 256 bins as CSV. It is intentionally kept
# in Tcl so final plot evidence can be generated without a Python plotting path.

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
    puts "  system-console -cli --jdi <top.jdi> --script=phase5_histogram_bin_dump.tcl --"
    puts "      --profile <rate|delay|header> --out <bins.csv>"
    puts "      optional: --wait-ms 1050 --lane-filter <0..7> --csr-base 0x00020400 --bin-base 0x00020000"
}

proc parse_i {text} {
    if {[scan $text %i value] != 1} {
        error "invalid integer '$text'"
    }
    return $value
}

proc hex32 {value} {
    return [format "0x%08X" [expr {$value & 0xffffffff}]]
}

proc write_csr_word {svc csr_base word_index value} {
    master_write_32 $svc [expr {$csr_base + 4 * $word_index}] [expr {$value & 0xffffffff}]
}

proc read_csr_word {svc csr_base word_index} {
    set values [master_read_32 $svc [expr {$csr_base + 4 * $word_index}] 1]
    return [parse_i [lindex $values 0]]
}

proc wait_apply_clear {svc csr_base} {
    for {set idx 0} {$idx < 100} {incr idx} {
        set control [read_csr_word $svc $csr_base 2]
        if {($control & 0x2) == 0} {
            return
        }
        after 10
    }
    error "histogram apply_pending did not clear"
}

proc configure_histogram {svc csr_base profile lane_filter} {
    set interval_1s 125000000
    set keyloc_global_channel 0x2623261e
    set keyloc_delay_debug 0x26231511
    set keyloc_debug_source 0x17101511

    if {$profile eq "rate"} {
        set left 0
        set right 255
        set bin_width 1
        set key_loc $keyloc_global_channel
        set key_value 0
        set control 0x00000101
    } elseif {$profile eq "delay" || $profile eq "header"} {
        set left 0
        set right 4095
        set bin_width 16
        set key_loc $keyloc_delay_debug
        set key_value 0
        set control 0x00000091
    } else {
        error "unsupported profile '$profile'"
    }

    if {$lane_filter ne ""} {
        if {$lane_filter < 0 || $lane_filter > 7} {
            error "--lane-filter must be 0..7"
        }
        if {$profile eq "delay" || $profile eq "header"} {
            set debug_source [expr {$lane_filter < 4 ? 0 : 1}]
            puts "PHASE5_HIST_DUMP_NOTE mode_minus7_filter_selects_debug_source_${debug_source};_individual_lane_isolation_still_requires_source_mask"
            set key_loc $keyloc_debug_source
            set key_value [expr {($debug_source & 0xf) << 16}]
        } else {
            set key_value [expr {($lane_filter & 0xf) << 16}]
        }
        set control [expr {$control | 0x00001000}]
    }

    write_csr_word $svc $csr_base 3 $left
    write_csr_word $svc $csr_base 4 $right
    write_csr_word $svc $csr_base 5 $bin_width
    write_csr_word $svc $csr_base 6 $key_loc
    write_csr_word $svc $csr_base 7 $key_value
    write_csr_word $svc $csr_base 10 $interval_1s
    write_csr_word $svc $csr_base 2 $control
    wait_apply_clear $svc $csr_base

    return [dict create \
        left $left \
        right $right \
        bin_width $bin_width \
        key_loc [hex32 $key_loc] \
        key_value [hex32 $key_value] \
        control [hex32 $control] \
        interval_clocks $interval_1s]
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {profile out wait-ms lane-filter csr-base bin-base master-pattern fallback-pattern service-tag} \
        {}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }
    if {$opts(profile) eq "" || $opts(out) eq ""} {
        usage
        error "--profile and --out are required"
    }

    set profile [string tolower $opts(profile)]
    set out_path $opts(out)
    set wait_ms 1050
    if {$opts(wait-ms) ne ""} {
        set wait_ms [parse_i $opts(wait-ms)]
    }
    set lane_filter ""
    if {$opts(lane-filter) ne ""} {
        set lane_filter [parse_i $opts(lane-filter)]
    }
    set csr_base 0x00020400
    if {$opts(csr-base) ne ""} {
        set csr_base [parse_i $opts(csr-base)]
    }
    set bin_base 0x00020000
    if {$opts(bin-base) ne ""} {
        set bin_base [parse_i $opts(bin-base)]
    }
    set service_tag $::board_test::jtag::default_service_tag
    if {$opts(service-tag) ne ""} {
        set service_tag $opts(service-tag)
    }

    set claim [::board_test::jtag::claim_matching_master \
        $opts(master-pattern) \
        $opts(fallback-pattern) \
        [hex32 $csr_base] \
        0x48495354 \
        $service_tag]
    set svc [dict get $claim service]
    set master_path [dict get $claim path]

    set config [configure_histogram $svc $csr_base $profile $lane_filter]
    master_write_32 $svc $bin_base 0
    after $wait_ms
    set bins [master_read_32 $svc $bin_base 256]

    set fd [open $out_path w]
    puts $fd "bin_index,bin_center,count"
    set bin_width [dict get $config bin_width]
    set left [dict get $config left]
    for {set idx 0} {$idx < [llength $bins]} {incr idx} {
        set raw [parse_i [lindex $bins $idx]]
        set center [expr {$left + $idx * $bin_width + $bin_width / 2.0}]
        puts $fd [format "%d,%.3f,%u" $idx $center [expr {$raw & 0xffffffff}]]
    }
    close $fd

    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::puts_result "PHASE5_HIST_DUMP_RESULT" [list \
        status OK \
        profile $profile \
        lane_filter "{$lane_filter}" \
        out "{$out_path}" \
        master "{$master_path}" \
        csr_base [hex32 $csr_base] \
        bin_base [hex32 $bin_base] \
        wait_ms $wait_ms \
        config "{$config}"]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
