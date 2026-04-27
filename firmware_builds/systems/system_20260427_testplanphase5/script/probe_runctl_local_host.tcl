# Headless probe for the FEB-local run-control host behind upload_subsystem_upload_system_jtag_master.master.

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
    puts "  system-console -cli -disable_readline --script=probe_runctl_local_host.tcl -- \\"
    puts "      [--soft-reset] [--local-cmd <hex>] [--post-delay-ms <ms>] \\"
    puts "      [--master-pattern <glob>] [--fallback-pattern <glob>] \\"
    puts "      [--uid-addr <byte_addr>] [--uid-expected <hex>] \\"
    puts "      [--control-addr <byte_addr>] [--status-addr <byte_addr>] \\"
    puts "      [--last-cmd-addr <byte_addr>] [--rx-cmd-count-addr <byte_addr>] \\"
    puts "      [--local-cmd-addr <byte_addr>] [--service-tag <tag>]"
}

set master_pattern "*#7-2*/upload_subsystem_upload_system_jtag_master.master"
set fallback_pattern "*upload_subsystem_upload_system_jtag_master.master"
set uid_addr 0x80
set uid_expected 0x52434D48
set control_addr 0x88
set status_addr 0x8C
set last_cmd_addr 0x90
set rx_cmd_count_addr 0xBC
set local_cmd_addr 0xCC
set post_delay_ms 50
set service_tag "board_test_local_probe"
set do_soft_reset 0
set local_cmd_hex ""

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {local-cmd post-delay-ms master-pattern fallback-pattern uid-addr uid-expected control-addr status-addr last-cmd-addr rx-cmd-count-addr local-cmd-addr service-tag} \
        {soft-reset}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }

    if {$opts(soft-reset)} { set do_soft_reset 1 }
    if {$opts(local-cmd) ne ""} { set local_cmd_hex $opts(local-cmd) }
    if {$opts(post-delay-ms) ne ""} { set post_delay_ms $opts(post-delay-ms) }
    if {$opts(master-pattern) ne ""} { set master_pattern $opts(master-pattern) }
    if {$opts(fallback-pattern) ne ""} { set fallback_pattern $opts(fallback-pattern) }
    if {$opts(uid-addr) ne ""} { set uid_addr $opts(uid-addr) }
    if {$opts(uid-expected) ne ""} { set uid_expected $opts(uid-expected) }
    if {$opts(control-addr) ne ""} { set control_addr $opts(control-addr) }
    if {$opts(status-addr) ne ""} { set status_addr $opts(status-addr) }
    if {$opts(last-cmd-addr) ne ""} { set last_cmd_addr $opts(last-cmd-addr) }
    if {$opts(rx-cmd-count-addr) ne ""} { set rx_cmd_count_addr $opts(rx-cmd-count-addr) }
    if {$opts(local-cmd-addr) ne ""} { set local_cmd_addr $opts(local-cmd-addr) }
    if {$opts(service-tag) ne ""} { set service_tag $opts(service-tag) }
} err]} {
    usage
    ::board_test::jtag::fatal 1 USAGE $err
}

if {[catch {
    set uid_addr [::board_test::jtag::parse_u32 $uid_addr]
    set uid_expected [::board_test::jtag::parse_u32 $uid_expected]
    set control_addr [::board_test::jtag::parse_u32 $control_addr]
    set status_addr [::board_test::jtag::parse_u32 $status_addr]
    set last_cmd_addr [::board_test::jtag::parse_u32 $last_cmd_addr]
    set rx_cmd_count_addr [::board_test::jtag::parse_u32 $rx_cmd_count_addr]
    set local_cmd_addr [::board_test::jtag::parse_u32 $local_cmd_addr]
    set post_delay_ms [::board_test::jtag::parse_u32 $post_delay_ms]

    set local_cmd_val ""
    if {$local_cmd_hex ne ""} {
        set local_cmd_val [::board_test::jtag::parse_u32 $local_cmd_hex]
    }

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
    set pre_rx_cmd_count [lindex [master_read_32 $svc $rx_cmd_count_addr 1] 0]
    puts "SELECTED master={$master_path} uid=$matched_uid"
    puts "PRE status=$pre_status last_cmd=$pre_last_cmd rx_cmd_count=$pre_rx_cmd_count"

    if {$do_soft_reset} {
        master_write_32 $svc $control_addr 0x1
        puts "ACTION soft_reset control_addr=[::board_test::jtag::hex32 $control_addr]"
    }
    if {$local_cmd_val ne ""} {
        master_write_32 $svc $local_cmd_addr $local_cmd_val
        puts "ACTION local_cmd addr=[::board_test::jtag::hex32 $local_cmd_addr] value=[::board_test::jtag::hex32 $local_cmd_val]"
    }
    after $post_delay_ms

    set post_status [lindex [master_read_32 $svc $status_addr 1] 0]
    set post_last_cmd [lindex [master_read_32 $svc $last_cmd_addr 1] 0]
    set post_rx_cmd_count [lindex [master_read_32 $svc $rx_cmd_count_addr 1] 0]
    puts "POST status=$post_status last_cmd=$post_last_cmd rx_cmd_count=$post_rx_cmd_count"

    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::puts_result "PROBE_RESULT" [list \
        status OK \
        master "{$master_path}" \
        uid $matched_uid \
        pre_status $pre_status \
        post_status $post_status \
        pre_last_cmd $pre_last_cmd \
        post_last_cmd $post_last_cmd \
        pre_rx_cmd_count $pre_rx_cmd_count \
        post_rx_cmd_count $post_rx_cmd_count]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
