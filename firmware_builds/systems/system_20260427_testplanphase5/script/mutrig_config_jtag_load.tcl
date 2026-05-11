# Headless MuTRiG configuration loader for the FEB control-path JTAG master.

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
    puts "  system-console -cli -disable_readline --script=mutrig_config_jtag_load.tcl -- \\"
    puts "      --words-file <path> --asic-id <0..7> [--scratchpad-base <byte_addr>] \\"
    puts "      [--controller-offset <byte_addr>] [--csr-base <byte_addr>] \\"
    puts "      [--command-len <words>] [--poll-ms <ms>] [--timeout-ms <ms>] \\"
    puts "      [--readback] [--master-pattern <glob>] [--fallback-pattern <glob>]"
}

proc read_words_file {path} {
    set fd [open $path r]
    set text [read $fd]
    close $fd
    set words [list]
    foreach token [regexp -all -inline {0x[0-9a-fA-F]+|[0-9]+} $text] {
        lappend words [::board_test::jtag::parse_u32 $token]
    }
    return $words
}

proc write_words {svc base words} {
    set idx 0
    foreach word $words {
        master_write_32 $svc [expr {$base + (4 * $idx)}] [expr {$word & 0xffffffff}]
        incr idx
    }
}

proc verify_words {svc base words} {
    set got [master_read_32 $svc $base [llength $words]]
    set idx 0
    foreach exp $words obs $got {
        set exp32 [expr {$exp & 0xffffffff}]
        set obs32 [expr {$obs & 0xffffffff}]
        if {$exp32 != $obs32} {
            error [format "scratchpad readback mismatch word %u: expected %s got %s" \
                $idx \
                [::board_test::jtag::hex32 $exp32] \
                [::board_test::jtag::hex32 $obs32]]
        }
        incr idx
    }
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {words-file asic-id scratchpad-base controller-offset csr-base command-len poll-ms timeout-ms master-pattern fallback-pattern service-tag} \
        {readback}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }
    if {$opts(words-file) eq "" || $opts(asic-id) eq ""} {
        usage
        error "--words-file and --asic-id are required"
    }

    set words_file [file normalize $opts(words-file)]
    set asic_id [::board_test::jtag::parse_u32 $opts(asic-id)]
    if {$asic_id < 0 || $asic_id > 7} {
        error "--asic-id must be in 0..7"
    }

    set scratchpad_base 0x00000000
    if {$opts(scratchpad-base) ne ""} {
        set scratchpad_base [::board_test::jtag::parse_u32 $opts(scratchpad-base)]
    }
    set controller_offset $scratchpad_base
    if {$opts(controller-offset) ne ""} {
        set controller_offset [::board_test::jtag::parse_u32 $opts(controller-offset)]
    }
    set csr_base 0x0003F010
    if {$opts(csr-base) ne ""} {
        set csr_base [::board_test::jtag::parse_u32 $opts(csr-base)]
    }
    set poll_ms 10
    if {$opts(poll-ms) ne ""} {
        set poll_ms [::board_test::jtag::parse_u32 $opts(poll-ms)]
    }
    set timeout_ms 15000
    if {$opts(timeout-ms) ne ""} {
        set timeout_ms [::board_test::jtag::parse_u32 $opts(timeout-ms)]
    }

    set words [read_words_file $words_file]
    if {[llength $words] == 0} {
        error "words file did not contain any data words"
    }
    set command_len [llength $words]
    if {$opts(command-len) ne ""} {
        set command_len [::board_test::jtag::parse_u32 $opts(command-len)]
    }
    if {$command_len <= 0 || $command_len > 256} {
        error "--command-len must be in 1..256"
    }

    set master_pattern $opts(master-pattern)
    if {$master_pattern eq ""} {
        set master_pattern "*5AG*#7-2*/phy_0/master"
    }
    set fallback_pattern $opts(fallback-pattern)
    if {$fallback_pattern eq ""} {
        set fallback_pattern "*#7-2*/phy_0/master,*phy_0/master"
    }
    set service_tag $::board_test::jtag::default_service_tag
    if {$opts(service-tag) ne ""} {
        set service_tag $opts(service-tag)
    }

    set claim [::board_test::jtag::claim_matching_master \
        $master_pattern \
        $fallback_pattern \
        "" \
        "" \
        $service_tag]
    set svc [dict get $claim service]
    set master_path [dict get $claim path]

    set pre_status [lindex [master_read_32 $svc $csr_base 1] 0]
    if {[expr {$pre_status & 0xffffffff}] != 0} {
        error [format "MuTRiG controller is not idle before config: %s" [::board_test::jtag::hex32 $pre_status]]
    }

    write_words $svc $scratchpad_base $words
    if {$opts(readback)} {
        verify_words $svc $scratchpad_base $words
    }

    master_write_32 $svc [expr {$csr_base + 4}] [expr {$controller_offset & 0xffffffff}]
    set command [expr {(0x011 << 20) | (($asic_id & 0xf) << 16) | ($command_len & 0xffff)}]
    master_write_32 $svc $csr_base $command

    set elapsed 0
    set polls 0
    set status 0xffffffff
    while {$elapsed <= $timeout_ms} {
        after $poll_ms
        incr elapsed $poll_ms
        incr polls
        set status [lindex [master_read_32 $svc $csr_base 1] 0]
        if {[expr {$status & 0xffffffff}] == 0} {
            break
        }
    }
    if {[expr {$status & 0xffffffff}] != 0} {
        error [format "MuTRiG config timed out after %u ms, last status %s" \
            $elapsed \
            [::board_test::jtag::hex32 $status]]
    }

    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::puts_result "MUTRIG_CFG_JTAG_RESULT" [list \
        status OK \
        master "{$master_path}" \
        asic $asic_id \
        words [llength $words] \
        command_len $command_len \
        command [::board_test::jtag::hex32 $command] \
        scratchpad_base [::board_test::jtag::hex32 $scratchpad_base] \
        controller_offset [::board_test::jtag::hex32 $controller_offset] \
        csr_base [::board_test::jtag::hex32 $csr_base] \
        polls $polls]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
