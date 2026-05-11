# Headless JTAG snapshot for Phase-6 post-rbCAM histogram runs.
#
# Reads the counter/status apertures that the Python report needs in one
# System Console session, so the collection flow can run when the SWB PCIe
# endpoint is exposed only as UIO and /dev/mudaq0 is unavailable.

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
    puts "  system-console -cli --jdi <top.jdi> --script=phase6_post_rbcam_snapshot.tcl --"
    puts "      --active-lane <0..7> \[--skip-lvds\] \[--skip-source-mux\] \[--out <snapshot.json>\]"
    puts "      \[--master-pattern <glob>\] \[--fallback-pattern <glob>\] \[--service-tag <tag>\]"
}

proc parse_i {text} {
    if {[scan $text %i value] != 1} {
        error "invalid integer '$text'"
    }
    return $value
}

proc read_words {svc addr count} {
    set values [master_read_32 $svc $addr $count]
    set out [list]
    foreach value $values {
        lappend out [expr {[parse_i $value] & 0xffffffff}]
    }
    return $out
}

proc json_u32_array {values} {
    set parts [list]
    foreach value $values {
        lappend parts [format "%u" [expr {$value & 0xffffffff}]]
    }
    return "\[[join $parts ,]\]"
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {active-lane out master-pattern fallback-pattern service-tag} \
        {skip-lvds skip-source-mux}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }
    if {$opts(active-lane) eq ""} {
        usage
        error "--active-lane is required"
    }
    set active_lane [parse_i $opts(active-lane)]
    if {$active_lane < 0 || $active_lane > 7} {
        error "--active-lane must be 0..7"
    }

    if {$opts(master-pattern) eq ""} {
        set opts(master-pattern) "*#7-2*/phy_1/master"
    }
    if {$opts(fallback-pattern) eq ""} {
        set opts(fallback-pattern) "*#7-2*/phy_0/master,*phy_1/master,*phy_0/master"
    }
    set service_tag "phase6_snapshot"
    if {$opts(service-tag) ne ""} {
        set service_tag $opts(service-tag)
    }

    set claim [::board_test::jtag::claim_matching_master \
        $opts(master-pattern) \
        $opts(fallback-pattern) \
        0x00020400 \
        0x48495354 \
        $service_tag]
    set svc [dict get $claim service]

    set source_mux_base [expr {0x00002240 + $active_lane * 0x40}]
    if {$active_lane < 4} {
        set rbcam_base [expr {0x00021000 + $active_lane * 0x80}]
    } else {
        set rbcam_base [expr {0x00023000 + ($active_lane - 4) * 0x80}]
    }

    if {$opts(skip-source-mux)} {
        set source_mux [lrepeat 16 0]
    } else {
        set source_mux [read_words $svc $source_mux_base 16]
    }
    set rbcam [read_words $svc $rbcam_base 10]
    if {$opts(skip-lvds)} {
        set lvds [lrepeat 14 0]
    } else {
        set lvds [read_words $svc 0x00000000 14]
    }
    set frame_rcv [read_words $svc [expr {0x00010900 + $active_lane * 0x1000}] 3]
    set mts0 [read_words $svc 0x00004000 5]
    set mts1 [read_words $svc 0x00008000 5]
    set hist [read_words $svc [expr {0x00020400 + 8 * 4}] 11]
    set selector [read_words $svc 0x00020C00 8]

    ::board_test::jtag::close_claim $svc

    set json [format "{\"active_lane\":%d,\"source_mux\":%s,\"rbcam\":%s,\"lvds\":%s,\"frame_rcv\":%s,\"mts0\":%s,\"mts1\":%s,\"hist\":%s,\"selector\":%s}" \
        $active_lane \
        [json_u32_array $source_mux] \
        [json_u32_array $rbcam] \
        [json_u32_array $lvds] \
        [json_u32_array $frame_rcv] \
        [json_u32_array $mts0] \
        [json_u32_array $mts1] \
        [json_u32_array $hist] \
        [json_u32_array $selector]]

    if {$opts(out) ne ""} {
        set fd [open $opts(out) w]
        puts $fd $json
        close $fd
    }
    puts "PHASE6_POST_RBCAM_SNAPSHOT_JSON $json"
    ::board_test::jtag::puts_result "PHASE6_POST_RBCAM_SNAPSHOT_RESULT" [list status OK active_lane $active_lane]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
