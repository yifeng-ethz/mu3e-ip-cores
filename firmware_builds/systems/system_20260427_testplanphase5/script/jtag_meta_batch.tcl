# Headless system-console helper for batched metadata reads.

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
    puts "  system-console -cli -disable_readline --jdi <top.jdi> --script=jtag_meta_batch.tcl -- \\"
    puts "      --reads <label:mode:addr[:page],...> \\"
    puts "      [--master-pattern <glob>] [--fallback-pattern <glob>] \\"
    puts "      [--uid-addr <byte_addr>] [--uid-expected <hex>] [--service-tag <tag>]"
    puts "Modes:"
    puts "  direct: label:direct:<byte_addr>"
    puts "  meta:   label:meta:<meta_reg_byte_addr>:<page>"
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {reads master-pattern fallback-pattern uid-addr uid-expected service-tag} \
        {}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }
    if {$opts(reads) eq ""} {
        usage
        error "--reads is required"
    }

    set uid_addr ""
    if {$opts(uid-addr) ne ""} {
        set uid_addr [::board_test::jtag::hex32 [::board_test::jtag::parse_u32 $opts(uid-addr)]]
    }
    set uid_expected ""
    if {$opts(uid-expected) ne ""} {
        set uid_expected [::board_test::jtag::hex32 [::board_test::jtag::parse_u32 $opts(uid-expected)]]
    }
    set service_tag $::board_test::jtag::default_service_tag
    if {$opts(service-tag) ne ""} {
        set service_tag $opts(service-tag)
    }

    set claim [::board_test::jtag::claim_matching_master \
        $opts(master-pattern) \
        $opts(fallback-pattern) \
        $uid_addr \
        $uid_expected \
        $service_tag]
    set svc [dict get $claim service]
    set master_path [dict get $claim path]
    set matched_uid [dict get $claim uid]

    set count 0
    foreach spec [split $opts(reads) ,] {
        if {$spec eq ""} {
            continue
        }
        set parts [split $spec :]
        set label [lindex $parts 0]
        set mode [string tolower [lindex $parts 1]]
        if {$label eq "" || $mode eq ""} {
            error "bad read spec '$spec'"
        }

        if {$mode eq "direct"} {
            if {[llength $parts] != 3} {
                error "direct read spec must be label:direct:addr"
            }
            set addr [::board_test::jtag::parse_u32 [lindex $parts 2]]
            set value [lindex [master_read_32 $svc $addr 1] 0]
        } elseif {$mode eq "meta"} {
            if {[llength $parts] != 4} {
                error "meta read spec must be label:meta:addr:page"
            }
            set addr [::board_test::jtag::parse_u32 [lindex $parts 2]]
            set page [::board_test::jtag::parse_u32 [lindex $parts 3]]
            master_write_32 $svc $addr $page
            set value [lindex [master_read_32 $svc $addr 1] 0]
            if {$page != 0} {
                master_write_32 $svc $addr 0
            }
        } else {
            error "unsupported read mode '$mode'"
        }

        puts [format "JTAG_META_WORD label=%s mode=%s addr=%s value=%s" \
            $label \
            $mode \
            [::board_test::jtag::hex32 $addr] \
            [::board_test::jtag::hex32 $value]]
        incr count
    }

    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::puts_result "JTAG_META_RESULT" [list \
        status OK \
        master "{$master_path}" \
        uid $matched_uid \
        count $count]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
