#------------------------------------------------------------------------------
# Robust headless run-control command injection for upload_subsystem_upload_system_jtag_master.master.
#
# Legacy positional mode is still accepted:
#   system-console ... --script=inject_runcmd.tcl 0x31 80
#
# Preferred mode:
#   system-console ... --script=inject_runcmd.tcl -- \
#       --cmd 0x31 --post-delay-ms 80
#------------------------------------------------------------------------------

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
    puts "  system-console -cli -disable_readline --jdi <top.jdi> --script=inject_runcmd.tcl -- \\"
    puts "      --cmd <hex> [--post-delay-ms <ms>] [--master-pattern <glob>] \\"
    puts "      [--fallback-pattern <glob>] [--uid-addr <byte_addr>] \\"
    puts "      [--uid-expected <hex>] [--status-addr <byte_addr>] \\"
    puts "      [--last-cmd-addr <byte_addr>] [--local-cmd-addr <byte_addr>] \\"
    puts "      [--service-tag <tag>]"
}

set cmd_hex ""
set post_delay_ms 50
set master_pattern "*#7-2*/upload_subsystem_upload_system_jtag_master.master"
set fallback_pattern "*upload_subsystem_upload_system_jtag_master.master"
set uid_addr 0x80
set uid_expected 0x52434D48
set status_addr 0x8C
set last_cmd_addr 0x90
set local_cmd_addr 0xCC
set service_tag "board_test_rc"

if {[llength $argv] >= 1 && ![string match --* [lindex $argv 0]]} {
    set cmd_hex [lindex $argv 0]
    if {[llength $argv] >= 2} {
        set post_delay_ms [lindex $argv 1]
    }
} else {
    if {[catch {
        lassign [::board_test::jtag::parse_args \
            $argv \
            {cmd post-delay-ms master-pattern fallback-pattern uid-addr uid-expected status-addr last-cmd-addr local-cmd-addr service-tag} \
            {}] opt_kvs positional
        array set opts $opt_kvs
        if {[llength $positional] != 0} {
            error "unexpected positional arguments"
        }
        if {$opts(cmd) eq ""} {
            usage
            error "--cmd is required"
        }
        set cmd_hex $opts(cmd)
        if {$opts(post-delay-ms) ne ""} { set post_delay_ms $opts(post-delay-ms) }
        if {$opts(master-pattern) ne ""} { set master_pattern $opts(master-pattern) }
        if {$opts(fallback-pattern) ne ""} { set fallback_pattern $opts(fallback-pattern) }
        if {$opts(uid-addr) ne ""} { set uid_addr $opts(uid-addr) }
        if {$opts(uid-expected) ne ""} { set uid_expected $opts(uid-expected) }
        if {$opts(status-addr) ne ""} { set status_addr $opts(status-addr) }
        if {$opts(last-cmd-addr) ne ""} { set last_cmd_addr $opts(last-cmd-addr) }
        if {$opts(local-cmd-addr) ne ""} { set local_cmd_addr $opts(local-cmd-addr) }
        if {$opts(service-tag) ne ""} { set service_tag $opts(service-tag) }
    } err]} {
        ::board_test::jtag::fatal 1 USAGE $err
    }
}

if {$cmd_hex eq ""} {
    usage
    ::board_test::jtag::fatal 1 USAGE "expected command byte"
}

if {[catch {
    set cmd_val [::board_test::jtag::parse_u32 $cmd_hex]
    set post_delay_ms [::board_test::jtag::parse_u32 $post_delay_ms]
    set uid_addr [::board_test::jtag::parse_u32 $uid_addr]
    set uid_expected [::board_test::jtag::parse_u32 $uid_expected]
    set status_addr [::board_test::jtag::parse_u32 $status_addr]
    set last_cmd_addr [::board_test::jtag::parse_u32 $last_cmd_addr]
    set local_cmd_addr [::board_test::jtag::parse_u32 $local_cmd_addr]

    set claim [::board_test::jtag::claim_matching_master \
        $master_pattern \
        $fallback_pattern \
        [::board_test::jtag::hex32 $uid_addr] \
        [::board_test::jtag::hex32 $uid_expected] \
        $service_tag]
    set svc [dict get $claim service]
    set master_path [dict get $claim path]
    set matched_uid [dict get $claim uid]

    set pre_status [lindex [master_read_32 $svc $status_addr 1] 0]
    set pre_last_cmd [lindex [master_read_32 $svc $last_cmd_addr 1] 0]
    puts "SELECTED master={$master_path} uid=$matched_uid"
    puts "PRE status=$pre_status last_cmd=$pre_last_cmd"

    master_write_32 $svc $local_cmd_addr $cmd_val
    after $post_delay_ms

    set post_status [lindex [master_read_32 $svc $status_addr 1] 0]
    set post_last_cmd [lindex [master_read_32 $svc $last_cmd_addr 1] 0]
    puts "POST status=$post_status last_cmd=$post_last_cmd"

    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::puts_result "INJECT_RESULT" [list \
        status OK \
        cmd [::board_test::jtag::hex32 $cmd_val] \
        master "{$master_path}" \
        uid $matched_uid \
        pre_last_cmd $pre_last_cmd \
        post_last_cmd $post_last_cmd]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 4 ERROR $err
}
