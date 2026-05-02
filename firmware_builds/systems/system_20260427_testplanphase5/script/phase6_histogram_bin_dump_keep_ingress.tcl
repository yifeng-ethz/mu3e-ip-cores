# Headless System Console helper for Phase-6 histogram-bin CSV snapshots.
#
# The script configures histogram_statistics_0, clears the histogram SRAM, waits
# one measurement interval, then dumps 256 bins as CSV. It is intentionally kept
# in Tcl so final plot evidence can be generated without a Python plotting path.
#
# This Phase-6 variant intentionally does not force histogram_ingress_bridge_0
# back to the pre-rbCAM stream for normal hit profiles.  The Python runner owns
# the bridge selection through --hist-ingress-source; keeping that selection is
# required when validating the post-rbCAM egress tap.

set script_dir "."
if {[info exists ::env(BOARD_TEST_SCRIPT_DIR)] && $::env(BOARD_TEST_SCRIPT_DIR) ne ""} {
    set script_dir $::env(BOARD_TEST_SCRIPT_DIR)
} elseif {[info script] ne ""} {
    set script_dir [file dirname [file normalize [info script]]]
} elseif {[info exists ::argv0] && [string match *.tcl $::argv0]} {
    set script_dir [file dirname [file normalize $::argv0]]
}
source [file join $script_dir headless_jtag_common.tcl]

proc locate_project_spec {} {
    global script_dir
    set candidates [list \
        [file normalize [file join $script_dir .. .. .. .. toolkits fe_scifi board_bring_up fe_scifi_board_bring_up_project.tcl]] \
        [file normalize [file join $::env(HOME) packages mu3e_ip_dev mu3e-ip-cores toolkits fe_scifi board_bring_up fe_scifi_board_bring_up_project.tcl]]]
    foreach candidate $candidates {
        if {[file exists $candidate]} {
            return $candidate
        }
    }
    error "unable to locate FE SciFi board bring-up project preset spec"
}

source [locate_project_spec]

proc usage {} {
    puts "Usage:"
    puts "  system-console -cli --jdi <top.jdi> --script=phase5_histogram_bin_dump.tcl --"
    puts "      --profile <rate|delay|header|delay-hit-t|delay-debug1|delay-debug2> --out <bins.csv>"
    puts "      optional: --wait-ms <preset interval + guard> --lane-filter <0..7> --csr-base 0x00020400 --bin-base 0x00020000"
    puts "      optional: --read-chunk-words <1..256> --read-delay-ms <delay between chunks> --unsafe-bulk-read"
    puts "      optional: --rate-ingress-base-list 0x00020C00,0x00020C10"
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

proc split_u32_csv {text default_values} {
    if {$text eq ""} {
        return $default_values
    }
    set out [list]
    foreach item [split $text ","] {
        set trimmed [string trim $item]
        if {$trimmed eq ""} {
            continue
        }
        lappend out [parse_i $trimmed]
    }
    if {[llength $out] == 0} {
        error "empty integer CSV list '$text'"
    }
    return $out
}

proc decode_ingress_status {word} {
    return [list \
        raw [hex32 $word] \
        live_select_post [expr {$word & 0x1}] \
        requested_select_post [expr {($word >> 1) & 0x1}] \
        switch_pending [expr {($word >> 2) & 0x1}] \
        pre_packet_active [expr {($word >> 8) & 0x1}] \
        post_packet_active [expr {($word >> 9) & 0x1}] \
        post_hit_filter_enabled [expr {($word >> 10) & 0x1}] \
        post_hit_region [expr {($word >> 11) & 0x1}]]
}

proc builtin_preset_spec_by_id {preset_id} {
    set common_interval [dict create \
        "interval_cfg.interval_clocks" "0x07735940" \
        "csr.commit" "0x1"]

    switch -- $preset_id {
        "delay_hit_t" {
            return [dict create \
                id "delay_hit_t" \
                label "Hit T signed delay" \
                sample_interval_ms 1000 \
                sample_guard_ms 50 \
                field_values [dict merge $common_interval [dict create \
                    "csr.mode" "0x1" \
                    "csr.representation" "0x0" \
                    "csr.filter" "0x0" \
                    "left_bound.left_bound" "-1000" \
                    "bin_width.bin_width" "0x10" \
                    "keys_location.update_key_low" "0x1e" \
                    "keys_location.update_key_high" "0x26" \
                    "keys_location.filter_key_low" "0x23" \
                    "keys_location.filter_key_high" "0x26" \
                    "keys_value.filter_key_value" "0x0" \
                    "keys_value.update_key_value" "0x0"]]]
        }
        "delay_debug1" {
            return [dict create \
                id "delay_debug1" \
                label "MTS debug_1 signed delay" \
                sample_interval_ms 1000 \
                sample_guard_ms 50 \
                field_values [dict merge $common_interval [dict create \
                    "csr.mode" "0xf" \
                    "csr.representation" "0x0" \
                    "csr.filter" "0x0" \
                    "left_bound.left_bound" "-1000" \
                    "bin_width.bin_width" "0x10" \
                    "keys_location.update_key_low" "0x1e" \
                    "keys_location.update_key_high" "0x22" \
                    "keys_location.filter_key_low" "0x23" \
                    "keys_location.filter_key_high" "0x26" \
                    "keys_value.filter_key_value" "0x0" \
                    "keys_value.update_key_value" "0x0"]]]
        }
        "delay_debug2" {
            return [dict create \
                id "delay_debug2" \
                label "MTS debug_2 signed delay" \
                sample_interval_ms 1000 \
                sample_guard_ms 50 \
                field_values [dict merge $common_interval [dict create \
                    "csr.mode" "0xe" \
                    "csr.representation" "0x0" \
                    "csr.filter" "0x0" \
                    "left_bound.left_bound" "-1000" \
                    "bin_width.bin_width" "0x10" \
                    "keys_location.update_key_low" "0x1e" \
                    "keys_location.update_key_high" "0x22" \
                    "keys_location.filter_key_low" "0x23" \
                    "keys_location.filter_key_high" "0x26" \
                    "keys_value.filter_key_value" "0x0" \
                    "keys_value.update_key_value" "0x0"]]]
        }
        "delay_mts_both" -
        "delay_mts_upper" -
        "delay_mts_lower" {
            return [dict create \
                id $preset_id \
                label "MTS debug signed delay" \
                sample_interval_ms 1000 \
                sample_guard_ms 50 \
                field_values [dict merge $common_interval [dict create \
                    "csr.mode" "0x9" \
                    "csr.representation" "0x0" \
                    "csr.filter" "0x0" \
                    "left_bound.left_bound" "0x0" \
                    "bin_width.bin_width" "0x10" \
                    "keys_location.update_key_low" "0x11" \
                    "keys_location.update_key_high" "0x15" \
                    "keys_location.filter_key_low" "0x23" \
                    "keys_location.filter_key_high" "0x26" \
                    "keys_value.filter_key_value" "0x0" \
                    "keys_value.update_key_value" "0x0"]]]
        }
    }

    return ""
}

proc preset_spec_by_id {preset_id} {
    set project_spec [::fe_scifi::board_bring_up::project::get_spec]
    foreach ip_spec [dict get $project_spec ip_sequence] {
        if {![dict exists $ip_spec id] || [dict get $ip_spec id] ne "histogram_ingress"} {
            continue
        }
        foreach preset_spec [dict get $ip_spec presets] {
            if {[dict exists $preset_spec id] && [dict get $preset_spec id] eq $preset_id} {
                return $preset_spec
            }
        }
    }
    set builtin [builtin_preset_spec_by_id $preset_id]
    if {$builtin ne ""} {
        return $builtin
    }
    error "histogram_ingress preset '$preset_id' not found in FE SciFi toolkit project spec"
}

proc field_i {field_values key default_value} {
    if {[dict exists $field_values $key]} {
        return [parse_i [dict get $field_values $key]]
    }
    return $default_value
}

proc preset_id_for_profile {profile lane_filter} {
    if {$profile eq "rate"} {
        return "rate"
    }
    if {$profile eq "delay-hit" || $profile eq "delay_hit" || $profile eq "delay-hit-t" || $profile eq "delay_hit_t"} {
        return "delay_hit_t"
    }
    if {$profile eq "delay-debug1" || $profile eq "delay_debug1" || $profile eq "debug1"} {
        return "delay_debug1"
    }
    if {$profile eq "delay-debug2" || $profile eq "delay_debug2" || $profile eq "debug2"} {
        return "delay_debug2"
    }
    if {$profile eq "delay" || $profile eq "header"} {
        if {$lane_filter eq ""} {
            return "delay_mts_both"
        }
        if {$lane_filter < 0 || $lane_filter > 7} {
            error "--lane-filter must be 0..7"
        }
        set debug_source [expr {$lane_filter < 4 ? 0 : 1}]
        puts "PHASE5_HIST_DUMP_NOTE mode_minus7_filter_selects_debug_source_${debug_source};_individual_lane_isolation_still_requires_source_mask"
        if {$debug_source == 0} {
            return "delay_mts_upper"
        }
        return "delay_mts_lower"
    }
    error "unsupported profile '$profile'"
}

proc profile_uses_pre_hit_stream {profile} {
    return [expr {$profile eq "rate" || $profile eq "delay-hit" || $profile eq "delay_hit" || $profile eq "delay-hit-t" || $profile eq "delay_hit_t"}]
}

proc profile_supports_asic_filter {profile} {
    return [profile_uses_pre_hit_stream $profile]
}

proc config_from_preset {preset_id} {
    set preset_spec [preset_spec_by_id $preset_id]
    set field_values [dict get $preset_spec field_values]

    set left [field_i $field_values "left_bound.left_bound" 0]
    set bin_width [field_i $field_values "bin_width.bin_width" 1]
    set right [expr {$left + 256 * $bin_width}]
    set key_loc [expr { \
        ([field_i $field_values "keys_location.update_key_low" 0] & 0xff) | \
        (([field_i $field_values "keys_location.update_key_high" 0] & 0xff) << 8) | \
        (([field_i $field_values "keys_location.filter_key_low" 0] & 0xff) << 16) | \
        (([field_i $field_values "keys_location.filter_key_high" 0] & 0xff) << 24)}]
    set key_value [expr { \
        ([field_i $field_values "keys_value.update_key_value" 0] & 0xffff) | \
        (([field_i $field_values "keys_value.filter_key_value" 0] & 0xffff) << 16)}]
    set control [expr { \
        ([field_i $field_values "csr.commit" 1] & 0x1) | \
        (([field_i $field_values "csr.mode" 0] & 0xf) << 4) | \
        (([field_i $field_values "csr.representation" 1] & 0x1) << 8) | \
        (([field_i $field_values "csr.filter" 0] & 0x3) << 12)}]
    set interval_clocks [field_i $field_values "interval_cfg.interval_clocks" 125000000]
    set sample_interval_ms 1000
    if {[dict exists $preset_spec sample_interval_ms]} {
        set sample_interval_ms [parse_i [dict get $preset_spec sample_interval_ms]]
    }
    set sample_guard_ms 50
    if {[dict exists $preset_spec sample_guard_ms]} {
        set sample_guard_ms [parse_i [dict get $preset_spec sample_guard_ms]]
    }

    return [dict create \
        preset_id $preset_id \
        preset_label [dict get $preset_spec label] \
        left $left \
        right $right \
        bin_width $bin_width \
        key_loc [hex32 $key_loc] \
        key_value [hex32 $key_value] \
        control [hex32 $control] \
        interval_clocks $interval_clocks \
        sample_interval_ms $sample_interval_ms \
        sample_guard_ms $sample_guard_ms]
}

proc write_csr_word {svc csr_base word_index value} {
    master_write_32 $svc [expr {$csr_base + 4 * $word_index}] [expr {$value & 0xffffffff}]
}

proc read_csr_word {svc csr_base word_index} {
    set values [master_read_32 $svc [expr {$csr_base + 4 * $word_index}] 1]
    return [parse_i [lindex $values 0]]
}

proc read_histogram_stats {svc csr_base} {
    set underflow [read_csr_word $svc $csr_base 8]
    set overflow [read_csr_word $svc $csr_base 9]
    set total [read_csr_word $svc $csr_base 13]
    set dropped [read_csr_word $svc $csr_base 14]
    set coal_status [read_csr_word $svc $csr_base 15]
    set last_total [read_csr_word $svc $csr_base 17]
    set last_dropped [read_csr_word $svc $csr_base 18]
    return [list \
        underflow_count [expr {$underflow & 0xffffffff}] \
        overflow_count [expr {$overflow & 0xffffffff}] \
        total_hits [expr {$total & 0xffffffff}] \
        dropped_hits [expr {$dropped & 0xffffffff}] \
        coal_status [hex32 $coal_status] \
        coal_occupancy [expr {$coal_status & 0xff}] \
        coal_occupancy_max [expr {($coal_status >> 8) & 0xff}] \
        coal_queue_overflow_count [expr {($coal_status >> 16) & 0xffff}] \
        last_interval_total_hits [expr {$last_total & 0xffffffff}] \
        last_interval_dropped_hits [expr {$last_dropped & 0xffffffff}]]
}

proc read_histogram_bins {svc bin_base read_chunk_words read_delay_ms} {
    # Current board images expose a one-bit hist_bin burstcount port, and the
    # JTAG/System Console helper path is artifact-grade as repeated single-word
    # reads.  Native 256-bin burst snapshots need a later RTL/IP patch that
    # widens and validates hist_bin burstcount.
    if {$read_chunk_words <= 0 || $read_chunk_words > 256} {
        error "--read-chunk-words must be in range 1..256"
    }
    if {$read_delay_ms < 0} {
        error "--read-delay-ms must be non-negative"
    }

    set bins [list]
    for {set offset 0} {$offset < 256} {incr offset $read_chunk_words} {
        set remaining [expr {256 - $offset}]
        set words [expr {$read_chunk_words < $remaining ? $read_chunk_words : $remaining}]
        set values [master_read_32 $svc [expr {$bin_base + 4 * $offset}] $words]
        foreach value $values {
            lappend bins $value
        }
        if {($read_delay_ms > 0) && (($offset + $words) < 256)} {
            after $read_delay_ms
        }
    }

    return $bins
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

proc select_rate_ingress_pre {svc ingress_bases} {
    set rows [list]
    set present_count 0
    foreach base $ingress_bases {
        if {[catch {set uid [read_csr_word $svc $base 0]} err]} {
            puts "PHASE5_HIST_DUMP_WARN ingress_base=[hex32 $base] status=UID_READ_FAIL err={$err}"
            lappend rows [list base [hex32 $base] present 0 error "UID_READ_FAIL"]
            continue
        }
        if {$uid != 0x48495342} {
            puts "PHASE5_HIST_DUMP_WARN ingress_base=[hex32 $base] status=UID_MISMATCH uid=[hex32 $uid]"
            lappend rows [list base [hex32 $base] present 0 uid [hex32 $uid] error "UID_MISMATCH"]
            continue
        }

        write_csr_word $svc $base 2 0
        set decoded [list]
        for {set idx 0} {$idx < 100} {incr idx} {
            set status [read_csr_word $svc $base 3]
            set decoded [decode_ingress_status $status]
            array set st $decoded
            if {$st(live_select_post) == 0 && $st(requested_select_post) == 0 && $st(switch_pending) == 0} {
                incr present_count
                lappend rows [concat [list base [hex32 $base] present 1 uid [hex32 $uid]] $decoded]
                break
            }
            after 10
        }
        if {$idx >= 100} {
            error "histogram ingress bridge at [hex32 $base] did not switch to pre stream: $decoded"
        }
    }
    if {$present_count == 0} {
        error "no histogram ingress bridge responded at bases $ingress_bases"
    }
    return $rows
}

proc configure_histogram {svc csr_base profile lane_filter} {
    set preset_id [preset_id_for_profile $profile $lane_filter]
    set config [config_from_preset $preset_id]
    set left [dict get $config left]
    set right [dict get $config right]
    set bin_width [dict get $config bin_width]
    set key_loc [parse_i [dict get $config key_loc]]
    set key_value [parse_i [dict get $config key_value]]
    set interval_clocks [dict get $config interval_clocks]
    set control [parse_i [dict get $config control]]

    if {[profile_supports_asic_filter $profile] && $lane_filter ne ""} {
        if {$lane_filter < 0 || $lane_filter > 7} {
            error "--lane-filter must be 0..7"
        }
        set key_value [expr {($lane_filter & 0xf) << 16}]
        set control [expr {$control | 0x00001000}]
        set config [dict replace $config key_value [hex32 $key_value] control [hex32 $control]]
    }

    write_csr_word $svc $csr_base 3 $left
    write_csr_word $svc $csr_base 4 $right
    write_csr_word $svc $csr_base 5 $bin_width
    write_csr_word $svc $csr_base 6 $key_loc
    write_csr_word $svc $csr_base 7 $key_value
    write_csr_word $svc $csr_base 10 $interval_clocks
    write_csr_word $svc $csr_base 2 $control
    wait_apply_clear $svc $csr_base

    return $config
}

if {[catch {
    lassign [::board_test::jtag::parse_args \
        $argv \
        {profile out wait-ms lane-filter csr-base bin-base read-chunk-words read-delay-ms rate-ingress-base-list master-pattern fallback-pattern service-tag} \
        {unsafe-bulk-read}] opt_kvs positional
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
    set wait_ms ""
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
    set read_chunk_words 1
    if {$opts(read-chunk-words) ne ""} {
        set read_chunk_words [parse_i $opts(read-chunk-words)]
    }
    set read_delay_ms 0
    if {$opts(read-delay-ms) ne ""} {
        set read_delay_ms [parse_i $opts(read-delay-ms)]
    }
    if {$read_chunk_words > 1 && !$opts(unsafe-bulk-read)} {
        error "histogram bin bulk reads require --unsafe-bulk-read"
    }
    set ingress_bases [split_u32_csv $opts(rate-ingress-base-list) [list 0x00020C00 0x00020C10]]
    set service_tag $::board_test::jtag::default_service_tag
    if {$opts(service-tag) ne ""} {
        set service_tag $opts(service-tag)
    }
    if {$opts(master-pattern) eq ""} {
        if {[info exists ::env(BOARD_TEST_JTAG_MASTER_PATTERN)] && $::env(BOARD_TEST_JTAG_MASTER_PATTERN) ne ""} {
            set opts(master-pattern) $::env(BOARD_TEST_JTAG_MASTER_PATTERN)
        } else {
            set opts(master-pattern) "*#7-2*/phy_1/master"
        }
    }
    if {$opts(fallback-pattern) eq ""} {
        if {[info exists ::env(BOARD_TEST_JTAG_FALLBACK_PATTERN)] && $::env(BOARD_TEST_JTAG_FALLBACK_PATTERN) ne ""} {
            set opts(fallback-pattern) $::env(BOARD_TEST_JTAG_FALLBACK_PATTERN)
        } else {
            set opts(fallback-pattern) "*#7-2*/phy_0/master,*phy_1/master,*phy_0/master"
        }
    }

    set claim [::board_test::jtag::claim_matching_master \
        $opts(master-pattern) \
        $opts(fallback-pattern) \
        [hex32 $csr_base] \
        0x48495354 \
        $service_tag]
    set svc [dict get $claim service]
    set master_path [dict get $claim path]

    set ingress_status [list]
    foreach base $ingress_bases {
        if {[catch {set uid [read_csr_word $svc $base 0]} err]} {
            puts "PHASE6_HIST_DUMP_WARN ingress_base=[hex32 $base] status=UID_READ_FAIL err={$err}"
            lappend ingress_status [list base [hex32 $base] present 0 error "UID_READ_FAIL"]
            continue
        }
        if {$uid != 0x48495342} {
            puts "PHASE6_HIST_DUMP_WARN ingress_base=[hex32 $base] status=UID_MISMATCH uid=[hex32 $uid]"
            lappend ingress_status [list base [hex32 $base] present 0 uid [hex32 $uid] error "UID_MISMATCH"]
            continue
        }
        set status [read_csr_word $svc $base 3]
        lappend ingress_status [concat [list base [hex32 $base] present 1 uid [hex32 $uid]] [decode_ingress_status $status]]
    }
    set config [configure_histogram $svc $csr_base $profile $lane_filter]
    if {$wait_ms eq ""} {
        set wait_ms [expr {[dict get $config sample_interval_ms] + [dict get $config sample_guard_ms]}]
    }
    master_write_32 $svc $bin_base 0
    set stats_before_wait [read_histogram_stats $svc $csr_base]
    after $wait_ms
    set stats_after_wait [read_histogram_stats $svc $csr_base]
    set bins [read_histogram_bins $svc $bin_base $read_chunk_words $read_delay_ms]
    set stats_after_read [read_histogram_stats $svc $csr_base]
    array set st_wait $stats_after_wait
    array set st_read $stats_after_read
    set underflow_delta_read [expr {($st_read(underflow_count) - $st_wait(underflow_count)) & 0xffffffff}]
    set overflow_delta_read [expr {($st_read(overflow_count) - $st_wait(overflow_count)) & 0xffffffff}]

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
        read_chunk_words $read_chunk_words \
        read_delay_ms $read_delay_ms \
        ingress_status "{$ingress_status}" \
        wait_ms $wait_ms \
        stats_before_wait "{$stats_before_wait}" \
        stats_after_wait "{$stats_after_wait}" \
        stats_after_read "{$stats_after_read}" \
        underflow_delta_read $underflow_delta_read \
        overflow_delta_read $overflow_delta_read \
        config "{$config}"]
} err]} {
    catch {::board_test::jtag::close_claim $svc}
    ::board_test::jtag::fatal 2 ERROR $err
}
