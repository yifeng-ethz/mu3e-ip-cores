# Headless system-console helper for direct 32-bit AVMM access.

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
    puts "  system-console -cli -disable_readline --jdi <top.jdi> --script=jtag_rw.tcl -- \\"
    puts "      --op <read|write> --addr <byte_addr> [--count <n>] [--data <w0,w1,...>] \\"
    puts "      [--master-pattern <glob>] [--fallback-pattern <glob>] \\"
    puts "      [--uid-addr <byte_addr>] [--uid-expected <hex>] [--service-tag <tag>]"
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {op addr count data master-pattern fallback-pattern uid-addr uid-expected service-tag} \
        {}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }

    if {$opts(op) eq "" || $opts(addr) eq ""} {
        usage
        error "--op and --addr are required"
    }

    set op [string tolower $opts(op)]
    if {$op ne "read" && $op ne "write"} {
        error "--op must be 'read' or 'write'"
    }

    set addr [::board_test::jtag::parse_u32 $opts(addr)]
    set count 1
    if {$opts(count) ne ""} {
        set count [::board_test::jtag::parse_u32 $opts(count)]
    }
    if {$count < 1} {
        error "--count must be >= 1"
    }

    set data_words [list]
    if {$op eq "write"} {
        if {$opts(data) eq ""} {
            error "--data is required for write operations"
        }
        foreach word [split $opts(data) ,] {
            if {$word eq ""} {
                continue
            }
            lappend data_words [::board_test::jtag::parse_u32 $word]
        }
        if {[llength $data_words] == 0} {
            error "--data did not contain any words"
        }
        set count [llength $data_words]
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

    if {$op eq "read"} {
        set words [master_read_32 $svc $addr $count]
        set idx 0
        foreach word $words {
            set word_addr [expr {$addr + (4 * $idx)}]
            puts [format "JTAG_RW_WORD index=%u addr=%s value=%s" \
                $idx \
                [::board_test::jtag::hex32 $word_addr] \
                [::board_test::jtag::hex32 $word]]
            incr idx
        }
    } else {
        set idx 0
        foreach word $data_words {
            master_write_32 $svc [expr {$addr + (4 * $idx)}] $word
            puts [format "JTAG_RW_WRITE index=%u addr=%s value=%s" \
                $idx \
                [::board_test::jtag::hex32 [expr {$addr + (4 * $idx)}]] \
                [::board_test::jtag::hex32 $word]]
            incr idx
        }
    }

    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::puts_result "JTAG_RW_RESULT" [list \
        status OK \
        op $op \
        master "{$master_path}" \
        uid $matched_uid \
        count $count]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
