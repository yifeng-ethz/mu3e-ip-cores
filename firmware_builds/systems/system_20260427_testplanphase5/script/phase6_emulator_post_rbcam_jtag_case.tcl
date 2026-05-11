# Headless System Console helper for Phase-6 emulator post-rbCAM cases.
#
# This configures the FEB directly through its JTAG Avalon masters. It is used
# when the SWB slow-control path is unavailable or too noisy, but the FEB JTAG
# master remains live.

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
    puts "  system-console -cli --jdi <top.jdi> --script=phase6_emulator_post_rbcam_jtag_case.tcl --"
    puts "      --op <idle|setup|teardown|status> --run-number <n> --case-mode <1|2>"
    puts "      optional setup args: --pulse-interval <n> --multiplicity <n> --header-delay <n>"
    puts "      optional emulator args: --emu-hit-rate <phase-inc> --emu-control <0|1>"
    puts "      optional emulator args: --emu-signal <csr-word> --emu-cluster-width <n>"
    puts "      optional setup args: --pulse-high <n> --header-channel <n> --active-lane <0..7>"
    puts "      optional source args: --source-mode <real|emulator|rr> --hist-snoop-source <pre|post> --lvds-lane-go-mask <mask> \[--skip-lvds-config\] \[--skip-source-mux\] \[--skip-emulator-config\] \[--skip-runctl-reset\] \[--skip-runctl-start\]"
    puts "      optional run-control args: --address-payload <n> (default 2 for link-2 FEB address)"
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

proc write_word {svc addr value} {
    master_write_32 $svc $addr [expr {$value & 0xffffffff}]
}

proc read_word {svc addr} {
    set values [master_read_32 $svc $addr 1]
    return [parse_i [lindex $values 0]]
}

proc read_words {svc addr count} {
    set values [master_read_32 $svc $addr $count]
    set out [list]
    foreach value $values {
        lappend out [expr {[parse_i $value] & 0xffffffff}]
    }
    return $out
}

proc hex_word_list {words} {
    set out [list]
    foreach word $words {
        lappend out [hex32 $word]
    }
    return [join $out ","]
}

proc jtag_runctl {svc local_cmd_addr cmd payload24 post_delay_ms} {
    set word [expr {(($payload24 & 0xffffff) << 8) | ($cmd & 0xff)}]
    write_word $svc $local_cmd_addr $word
    if {$post_delay_ms > 0} {
        after $post_delay_ms
    }
    return $word
}

proc source_mode_word {source_mode} {
    switch -- $source_mode {
        real { return 0 }
        emulator { return 1 }
        rr { return 2 }
        default { error "--source-mode must be real, emulator, or rr" }
    }
}

proc configure_sources {svc source_mux_base source_mux_stride source_mode} {
    set mode_word [source_mode_word $source_mode]
    set rows [list]
    for {set lane 0} {$lane < 8} {incr lane} {
        set base [expr {$source_mux_base + $lane * $source_mux_stride}]
        write_word $svc [expr {$base + 8}] [expr {0x00000100 | $mode_word}]
        after 1
        write_word $svc [expr {$base + 8}] $mode_word
        set words [read_words $svc $base 4]
        lappend rows [list lane $lane base [hex32 $base] control [hex32 [lindex $words 2]] status [hex32 [lindex $words 3]]]
    }
    return $rows
}

proc emulator_cluster_fix_word {header_channel multiplicity} {
    set low $header_channel
    if {$low < 0} { set low 0 }
    if {$low > 127} { set low 127 }
    set width $multiplicity
    if {$width < 1} { set width 1 }
    set high [expr {$low + $width - 1}]
    if {$high > 127} { set high 127 }
    if {$high < $low} { set high $low }
    return [expr {($low & 0x7f) | (($high & 0x7f) << 7) | (1 << 14)}]
}

proc configure_emulators {svc emu_base emu_stride active_lane emu_hit_rate emu_control emu_signal emu_cluster_width header_channel} {
    set cluster_fix [emulator_cluster_fix_word $header_channel $emu_cluster_width]
    set rows [list]
    for {set lane 0} {$lane < 8} {incr lane} {
        set base [expr {$emu_base + $lane * $emu_stride}]
        set enabled [expr {($lane == $active_lane) && ($emu_control != 0)}]
        write_word $svc [expr {$base + 0x1c}] 0x00000000
        if {$enabled} {
            write_word $svc [expr {$base + 0x20}] $emu_signal
            write_word $svc [expr {$base + 0x24}] 0x00000000
            write_word $svc [expr {$base + 0x28}] 0x00000020
            write_word $svc [expr {$base + 0x2c}] [expr {$emu_hit_rate & 0x0000ffff}]
            write_word $svc [expr {$base + 0x30}] $cluster_fix
            write_word $svc [expr {$base + 0x34}] 0x00000000
            write_word $svc [expr {$base + 0x38}] [expr {0xDEADBEEF ^ $lane}]
            write_word $svc [expr {$base + 0x3c}] 0x00010001
        }
        write_word $svc [expr {$base + 0x1c}] $enabled
        set words [read_words $svc $base 16]
        lappend rows [list \
            lane $lane \
            base [hex32 $base] \
            central [hex32 [lindex $words 7]] \
            signal [hex32 [lindex $words 8]] \
            format [hex32 [lindex $words 10]] \
            cluster_fix [hex32 [lindex $words 12]]]
    }
    return $rows
}

proc selector_control_word {hist_snoop_source} {
    switch -- $hist_snoop_source {
        pre { return 0x00000000 }
        post { return 0x00000003 }
        default { error "--hist-snoop-source must be pre or post" }
    }
}

proc configure_selector {svc selector_base hist_snoop_source} {
    set control_word [selector_control_word $hist_snoop_source]
    write_word $svc [expr {$selector_base + 8}] [expr {0x00000100 | $control_word}]
    after 5
    write_word $svc [expr {$selector_base + 8}] $control_word
    set words [read_words $svc $selector_base 8]
    set status_word [lindex $words 3]
    if {$hist_snoop_source eq "pre"} {
        if {($status_word & 0x1) != 0} {
            error "histogram snoop selector did not enter pre mode: status=[hex32 $status_word]"
        }
    } else {
        if {($status_word & 0x3) != 0x3} {
            error "histogram snoop selector did not enter filtered post mode: status=[hex32 $status_word]"
        }
    }
    return [list \
        source $hist_snoop_source \
        uid [hex32 [lindex $words 0]] \
        meta [hex32 [lindex $words 1]] \
        control [hex32 [lindex $words 2]] \
        status [hex32 [lindex $words 3]] \
        hp_seen [hex32 [lindex $words 4]] \
        rb_seen [hex32 [lindex $words 5]] \
        hist_emit [hex32 [lindex $words 6]] \
        hist_drop [hex32 [lindex $words 7]]]
}

proc configure_lvds_lanes {svc lvds_base lane_go_mask} {
    write_word $svc [expr {$lvds_base + 8}] $lane_go_mask
    after 10
    write_word $svc [expr {$lvds_base + 16}] 0x00000000
    after 2
    write_word $svc [expr {$lvds_base + 16}] $lane_go_mask
    set lane_go [read_word $svc [expr {$lvds_base + 16}]]
    set soft_reset [read_word $svc [expr {$lvds_base + 8}]]
    return [list base [hex32 $lvds_base] soft_reset [hex32 $soft_reset] lane_go [hex32 $lane_go]]
}

proc injector_layout {svc injector_base} {
    set word0 [read_word $svc $injector_base]
    if {($word0 & 0xffffffff) == 0x4D494E4A} {
        return [list \
            name headered \
            mode 8 \
            header_delay 12 \
            header_interval 16 \
            multiplicity 20 \
            header_channel 24 \
            pulse_interval 28 \
            pulse_high 32 \
            read_count 13]
    }
    return [list \
        name legacy \
        mode 0 \
        header_delay 4 \
        header_interval 8 \
        multiplicity 12 \
        header_channel 16 \
        pulse_interval 20 \
        pulse_high 24 \
        read_count 11]
}

proc configure_injector {svc injector_base case_mode pulse_interval multiplicity header_delay pulse_high header_channel} {
    set layout [injector_layout $svc $injector_base]
    set mode_offset [dict get $layout mode]
    write_word $svc [expr {$injector_base + $mode_offset}] 0
    write_word $svc [expr {$injector_base + [dict get $layout header_delay]}] $header_delay
    write_word $svc [expr {$injector_base + [dict get $layout header_interval]}] 1
    write_word $svc [expr {$injector_base + [dict get $layout multiplicity]}] $multiplicity
    write_word $svc [expr {$injector_base + [dict get $layout header_channel]}] $header_channel
    write_word $svc [expr {$injector_base + [dict get $layout pulse_interval]}] $pulse_interval
    write_word $svc [expr {$injector_base + [dict get $layout pulse_high]}] $pulse_high
    write_word $svc [expr {$injector_base + $mode_offset}] $case_mode
    set words [read_words $svc $injector_base [dict get $layout read_count]]
    return [list \
        layout [dict get $layout name] \
        mode_offset [hex32 $mode_offset] \
        mode [hex32 $case_mode] \
        header_delay [hex32 $header_delay] \
        multiplicity [hex32 $multiplicity] \
        pulse_interval [hex32 $pulse_interval] \
        pulse_high [hex32 $pulse_high] \
        readback [hex_word_list $words]]
}

proc read_injector {svc injector_base} {
    set layout [injector_layout $svc $injector_base]
    set words [read_words $svc $injector_base [dict get $layout read_count]]
    return [list \
        layout [dict get $layout name] \
        mode_offset [hex32 [dict get $layout mode]] \
        readback [hex_word_list $words]]
}

proc send_reset_address_stop {svc local_cmd_addr address_payload runctl_delay_ms post_stop_reset_ms} {
    set words [list]
    lappend words [hex32 [jtag_runctl $svc $local_cmd_addr 0x30 0xFFFF $runctl_delay_ms]]
    lappend words [hex32 [jtag_runctl $svc $local_cmd_addr 0x40 $address_payload $runctl_delay_ms]]
    lappend words [hex32 [jtag_runctl $svc $local_cmd_addr 0x31 0xFFFF $runctl_delay_ms]]
    if {$post_stop_reset_ms > 0} { after $post_stop_reset_ms }
    return $words
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {op run-number case-mode pulse-interval multiplicity header-delay pulse-high header-channel active-lane source-mode hist-snoop-source emu-hit-rate emu-control emu-signal emu-cluster-width post-stop-reset-ms runctl-delay-ms lvds-lane-go-mask address-payload data-master-pattern data-fallback-pattern upload-master-pattern upload-fallback-pattern service-tag data-service-tag upload-service-tag} \
        {skip-lvds-config skip-source-mux skip-emulator-config skip-runctl-reset skip-runctl-start}] opt_kvs positional
    array set opts $opt_kvs

    if {[llength $positional] != 0} {
        error "unexpected positional arguments"
    }
    if {$opts(op) eq ""} {
        usage
        error "--op is required"
    }

    set op [string tolower $opts(op)]
    if {$op ne "idle" && $op ne "setup" && $op ne "teardown" && $op ne "status"} {
        usage
        error "--op must be idle, setup, teardown, or status"
    }

    set run_number 66000
    if {$opts(run-number) ne ""} { set run_number [parse_i $opts(run-number)] }
    set case_mode 1
    if {$opts(case-mode) ne ""} { set case_mode [parse_i $opts(case-mode)] }
    set pulse_interval 12500
    if {$opts(pulse-interval) ne ""} { set pulse_interval [parse_i $opts(pulse-interval)] }
    set multiplicity 1
    if {$opts(multiplicity) ne ""} { set multiplicity [parse_i $opts(multiplicity)] }
    set header_delay 500
    if {$opts(header-delay) ne ""} { set header_delay [parse_i $opts(header-delay)] }
    set pulse_high 5
    if {$opts(pulse-high) ne ""} { set pulse_high [parse_i $opts(pulse-high)] }
    set header_channel 0
    if {$opts(header-channel) ne ""} { set header_channel [parse_i $opts(header-channel)] }
    set active_lane 0
    if {$opts(active-lane) ne ""} { set active_lane [parse_i $opts(active-lane)] }
    set source_mode "emulator"
    if {$opts(source-mode) ne ""} { set source_mode [string tolower $opts(source-mode)] }
    if {$source_mode ne "real" && $source_mode ne "emulator" && $source_mode ne "rr"} {
        usage
        error "--source-mode must be real, emulator, or rr"
    }
    set hist_snoop_source "post"
    if {$opts(hist-snoop-source) ne ""} { set hist_snoop_source [string tolower $opts(hist-snoop-source)] }
    if {$hist_snoop_source ne "pre" && $hist_snoop_source ne "post"} {
        usage
        error "--hist-snoop-source must be pre or post"
    }
    set emu_hit_rate 0x0800
    if {$opts(emu-hit-rate) ne ""} { set emu_hit_rate [parse_i $opts(emu-hit-rate)] }
    set emu_control 0x00000001
    if {$opts(emu-control) ne ""} { set emu_control [parse_i $opts(emu-control)] }
    set emu_signal 0x00000001
    if {$opts(emu-signal) ne ""} { set emu_signal [parse_i $opts(emu-signal)] }
    set emu_cluster_width 1
    if {$opts(emu-cluster-width) ne ""} { set emu_cluster_width [parse_i $opts(emu-cluster-width)] }
    set post_stop_reset_ms 50
    if {$opts(post-stop-reset-ms) ne ""} { set post_stop_reset_ms [parse_i $opts(post-stop-reset-ms)] }
    set runctl_delay_ms 50
    if {$opts(runctl-delay-ms) ne ""} { set runctl_delay_ms [parse_i $opts(runctl-delay-ms)] }
    set address_payload 2
    if {$opts(address-payload) ne ""} { set address_payload [parse_i $opts(address-payload)] }

    if {$active_lane < 0 || $active_lane > 7} {
        error "--active-lane must be 0..7"
    }

    set data_master_pattern "*#7-2*/phy_1/master"
    if {$opts(data-master-pattern) ne ""} { set data_master_pattern $opts(data-master-pattern) }
    set data_fallback_pattern "*#7-2*/phy_0/master,*phy_1/master,*phy_0/master"
    if {$opts(data-fallback-pattern) ne ""} { set data_fallback_pattern $opts(data-fallback-pattern) }
    set upload_master_pattern "*#7-2*/phy_2/master"
    if {$opts(upload-master-pattern) ne ""} { set upload_master_pattern $opts(upload-master-pattern) }
    set upload_fallback_pattern "*#7-2*/upload_subsystem_upload_system_jtag_master.master,*upload_subsystem_upload_system_jtag_master.master,*phy_2/master"
    if {$opts(upload-fallback-pattern) ne ""} { set upload_fallback_pattern $opts(upload-fallback-pattern) }
    set data_service_tag "phase6_data"
    if {$opts(service-tag) ne ""} { set data_service_tag $opts(service-tag) }
    if {$opts(data-service-tag) ne ""} { set data_service_tag $opts(data-service-tag) }
    set upload_service_tag "phase6_runctl"
    if {$opts(upload-service-tag) ne ""} { set upload_service_tag $opts(upload-service-tag) }

    set data_claim [::board_test::jtag::claim_matching_master \
        $data_master_pattern \
        $data_fallback_pattern \
        0x00020400 \
        0x48495354 \
        $data_service_tag]
    set data_svc [dict get $data_claim service]
    set data_path [dict get $data_claim path]

    set upload_claim [::board_test::jtag::claim_matching_master \
        $upload_master_pattern \
        $upload_fallback_pattern \
        0x00000080 \
        0x52434D48 \
        $upload_service_tag]
    set upload_svc [dict get $upload_claim service]
    set upload_path [dict get $upload_claim path]

    # The compiled datapath exposes the lower emulator/source-mux/injector
    # CSRs at their local data-path addresses, while the histogram CSR/bin and
    # snoop selector sit behind the shifted histogram JTAG window.
    set emu_base 0x00002000
    set emu_stride 0x40
    set source_mux_base 0x00002240
    set source_mux_stride 0x40
    set selector_base 0x00020C00
    # master_datapath.master sees mutrig_injector_0.csr at the direct Qsys
    # byte base. The SC word aperture is separately exposed at 0x0AC80.
    set injector_base 0x00022000
    set lvds_base 0x00000000
    set lvds_lane_go_mask 0x000001FF
    if {$opts(lvds-lane-go-mask) ne ""} { set lvds_lane_go_mask [parse_i $opts(lvds-lane-go-mask)] }
    set local_cmd_addr 0x000000CC
    set runctl_status_addr 0x0000008C
    set runctl_last_cmd_addr 0x00000090

    set runctl_words [list]
    set lvds_status [list skipped 1]
    if {$op eq "idle"} {
        set runctl_words [send_reset_address_stop $upload_svc $local_cmd_addr $address_payload $runctl_delay_ms $post_stop_reset_ms]
        if {$opts(skip-lvds-config)} {
            set lvds_status [list skipped 1 reason skip-lvds-config]
        } else {
            set lvds_status [configure_lvds_lanes $data_svc $lvds_base $lvds_lane_go_mask]
        }
        set source_rows [list]
        set emu_rows [list]
        set selector_status [configure_selector $data_svc $selector_base $hist_snoop_source]
        set injector_status [concat [list mode idle_not_configured] [read_injector $data_svc $injector_base]]
    } elseif {$op eq "setup"} {
        if {!$opts(skip-runctl-reset)} {
            set runctl_words [send_reset_address_stop $upload_svc $local_cmd_addr $address_payload $runctl_delay_ms $post_stop_reset_ms]
        } else {
            lappend runctl_words "skip_reset_stop"
        }
        if {$opts(skip-lvds-config)} {
            set lvds_status [list skipped 1 reason skip-lvds-config]
        } else {
            set lvds_status [configure_lvds_lanes $data_svc $lvds_base $lvds_lane_go_mask]
        }
        if {$opts(skip-source-mux)} {
            set source_rows [list skipped 1 reason skip-source-mux]
        } else {
            set source_rows [configure_sources $data_svc $source_mux_base $source_mux_stride $source_mode]
        }
        if {$opts(skip-emulator-config)} {
            set emu_rows [list skipped 1 reason skip-emulator-config]
        } else {
            set emu_rows [configure_emulators $data_svc $emu_base $emu_stride $active_lane $emu_hit_rate $emu_control $emu_signal $emu_cluster_width $header_channel]
        }
        set selector_status [configure_selector $data_svc $selector_base $hist_snoop_source]
        set injector_status [configure_injector $data_svc $injector_base $case_mode $pulse_interval $multiplicity $header_delay $pulse_high $header_channel]
        if {$opts(skip-runctl-start)} {
            lappend runctl_words "skip_start"
        } else {
            lappend runctl_words [hex32 [jtag_runctl $upload_svc $local_cmd_addr 0x10 $run_number $runctl_delay_ms]]
            lappend runctl_words [hex32 [jtag_runctl $upload_svc $local_cmd_addr 0x11 0 $runctl_delay_ms]]
            lappend runctl_words [hex32 [jtag_runctl $upload_svc $local_cmd_addr 0x12 0 $runctl_delay_ms]]
        }
    } elseif {$op eq "teardown"} {
        set injector_status [configure_injector $data_svc $injector_base 0 $pulse_interval $multiplicity $header_delay $pulse_high $header_channel]
        set selector_status [configure_selector $data_svc $selector_base $hist_snoop_source]
        set source_rows [list]
        set emu_rows [list]
        lappend runctl_words [hex32 [jtag_runctl $upload_svc $local_cmd_addr 0x13 0 $runctl_delay_ms]]
    } else {
        set source_rows [list]
        set emu_rows [list]
        set selector_status [configure_selector $data_svc $selector_base $hist_snoop_source]
        set injector_status [concat [list mode not_read] [read_injector $data_svc $injector_base]]
    }

    set runctl_status [read_word $upload_svc $runctl_status_addr]
    set runctl_last_cmd [read_word $upload_svc $runctl_last_cmd_addr]

    ::board_test::jtag::close_claim $data_svc
    ::board_test::jtag::close_claim $upload_svc
    ::board_test::jtag::puts_result "PHASE6_JTAG_CASE_RESULT" [list \
        status OK \
        op $op \
        run_number $run_number \
        active_lane $active_lane \
        source_mode $source_mode \
        hist_snoop_source $hist_snoop_source \
        lvds_lane_go_mask [hex32 $lvds_lane_go_mask] \
        skip_lvds_config $opts(skip-lvds-config) \
        skip_runctl_reset $opts(skip-runctl-reset) \
        skip_runctl_start $opts(skip-runctl-start) \
        skip_source_mux $opts(skip-source-mux) \
        address_payload [hex32 $address_payload] \
        case_mode $case_mode \
        multiplicity $multiplicity \
        pulse_interval $pulse_interval \
        emu_hit_rate [hex32 $emu_hit_rate] \
        emu_control [hex32 $emu_control] \
        emu_signal [hex32 $emu_signal] \
        emu_cluster_width $emu_cluster_width \
        data_master "{$data_path}" \
        upload_master "{$upload_path}" \
        runctl_words "{$runctl_words}" \
        runctl_status [hex32 $runctl_status] \
        runctl_last_cmd [hex32 $runctl_last_cmd] \
        lvds "{$lvds_status}" \
        selector "{$selector_status}" \
        injector "{$injector_status}" \
        source_mux "{$source_rows}" \
        emulators "{$emu_rows}"]
} err]} {
    catch {::board_test::jtag::close_claim $data_svc}
    catch {::board_test::jtag::close_claim $upload_svc}
    ::board_test::jtag::fatal 2 ERROR $err
    exit 2
}
