set report_dir "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/260526-feb-bug012/scripts/report/real_mutrig_alive_matrix_20260604/post_rewire_load_test"
set out_path [file join $report_dir "jtag_real_mutrig_smoke_lvdsreset_20260605.log"]
set csv_path [file join $report_dir "jtag_real_mutrig_smoke_lvdsreset_20260605_counts.csv"]

set LVDS     0x00000000
set HIST_CSR 0x00007000
set HIST_BIN 0x00008000
set INJ      0x0000a000
set EMU      0x00001000
set RUNCTL   0x00016000

set HIST_UID 0x48495354
set INJ_UID  0x4d494e4a
set RCMH_UID 0x52434d48

set N_BINS 256
set INTERVAL 12500
set PULSE_HIGH 5
set DWELL_MS 2200

set CTRL_TYPE0      [expr {(0 << 16) | (0 << 2) | (1 << 8) | 1}]
set CTRL_TYPE1_UP   [expr {(1 << 16) | (1 << 2) | (1 << 8) | 1}]
set CTRL_TYPE1_DOWN [expr {(2 << 16) | (2 << 2) | (1 << 8) | 1}]

set MERGER_BASES [list 0x2400 0x2480 0x2500 0x2580 0x2600 0x2680 0x2700 0x2780]
set FRAME_BASES  [list 0x88a0 0x18a0 0x28a0 0x38a0 0x48a0 0x58a0 0x68a0 0x78a0]

proc log_line {fd msg} {
    puts $fd $msg
    flush $fd
    puts $msg
}

proc u32 {value} {
    return [expr {$value + 0}]
}

proc fmt {value} {
    return [format "0x%08X" [expr {($value + 0) & 0xffffffff}]]
}

proc addr_word {base word} {
    return [expr {($base + 0) + (($word + 0) << 2)}]
}

proc read_u32 {master addr} {
    set raw [master_read_32 $master $addr 1]
    return [expr {$raw + 0}]
}

proc write_u32 {master addr value} {
    master_write_32 $master $addr $value
}

proc write_word {master base word value} {
    write_u32 $master [addr_word $base $word] $value
}

proc read_word {master base word} {
    return [read_u32 $master [addr_word $base $word]]
}

proc write_verify {fd master base word value mask label} {
    set addr [addr_word $base $word]
    set want [expr {($value + 0) & ($mask + 0)}]
    set last 0
    for {set tries 0} {$tries < 6} {incr tries} {
        write_u32 $master $addr $value
        after 30
        set last [read_u32 $master $addr]
        if {[expr {$last & ($mask + 0)}] == $want} {
            log_line $fd [format "VERIFY %-24s addr=%s write=%s read=%s PASS" $label [fmt $addr] [fmt $value] [fmt $last]]
            return 1
        }
    }
    log_line $fd [format "VERIFY %-24s addr=%s write=%s read=%s FAIL" $label [fmt $addr] [fmt $value] [fmt $last]]
    return 0
}

proc find_master {masters must_have_a must_have_b} {
    foreach path $masters {
        if {[string first $must_have_a $path] >= 0 && [string first $must_have_b $path] >= 0} {
            return $path
        }
    }
    return ""
}

proc runctl_cmd {fd runctl_master word delay_ms} {
    global RUNCTL
    write_word $runctl_master $RUNCTL 0x13 $word
    after $delay_ms
    set status [read_word $runctl_master $RUNCTL 0x03]
    set last_cmd [read_word $runctl_master $RUNCTL 0x04]
    log_line $fd [format "RUNCTL cmd=%s status=%s last_cmd=%s" [fmt $word] [fmt $status] [fmt $last_cmd]]
    return $status
}

proc terminate_quiet {fd runctl_master dp_master} {
    global INJ
    write_word $dp_master $INJ 2 0
    after 80
    runctl_cmd $fd $runctl_master 0x13 250
}

proc set_real_path {fd dp_master} {
    global EMU INJ MERGER_BASES FRAME_BASES
    write_verify $fd $dp_master $EMU 7 0 0xffffffff "emu.central"
    write_verify $fd $dp_master $EMU 9 0 0xffffffff "emu.background"
    write_verify $fd $dp_master $EMU 8 0 0xffffffff "emu.signal"
    write_verify $fd $dp_master $INJ 2 0 0x0000000f "inj.mode.off"
    set lane 0
    foreach base $MERGER_BASES {
        write_verify $fd $dp_master $base 3 0 0x00000001 [format "merger%d.real" $lane]
        incr lane
    }
    set lane 0
    foreach base $FRAME_BASES {
        write_verify $fd $dp_master $base 0 1 0x00000001 [format "frame%d.enable" $lane]
        incr lane
    }
}

proc configure_injector {fd dp_master interval pulse_high} {
    global INJ
    write_verify $fd $dp_master $INJ 2 0 0x0000000f "inj.mode.off"
    write_verify $fd $dp_master $INJ 6 0 0x000000ff "inj.header_ch"
    write_verify $fd $dp_master $INJ 3 300 0xffffffff "inj.header_delay"
    write_verify $fd $dp_master $INJ 4 1 0xffffffff "inj.header_interval"
    write_verify $fd $dp_master $INJ 5 1 0xffffffff "inj.multiplicity"
    write_verify $fd $dp_master $INJ 7 $interval 0xffffffff "inj.pulse_interval"
    write_verify $fd $dp_master $INJ 8 $pulse_high 0x000000ff "inj.pulse_high"
}

proc arm_histogram {fd dp_master ctrl} {
    global HIST_CSR N_BINS
    write_verify $fd $dp_master $HIST_CSR 3 0 0xffffffff "hist.left"
    write_verify $fd $dp_master $HIST_CSR 4 $N_BINS 0xffffffff "hist.right"
    write_verify $fd $dp_master $HIST_CSR 5 1 0xffffffff "hist.bin_width"
    write_word $dp_master $HIST_CSR 2 $ctrl
    after 150
    set control [read_word $dp_master $HIST_CSR 2]
    log_line $fd [format "HIST_ARM ctrl=%s control_after=%s" [fmt $ctrl] [fmt $control]]
}

proc log_lvds_status {fd dp_master prefix} {
    global LVDS
    set uid [read_word $dp_master $LVDS 0]
    set lane_go [read_word $dp_master $LVDS 4]
    set soft_reset [read_word $dp_master $LVDS 6]
    set phy_losn [read_word $dp_master $LVDS 12]
    set phy_dpalock [read_word $dp_master $LVDS 14]
    log_line $fd [format "%s_LVDS uid=%s lane_go=%s soft_reset=%s phy_losn=%s phy_dpalock=%s" \
        $prefix [fmt $uid] [fmt $lane_go] [fmt $soft_reset] [fmt $phy_losn] [fmt $phy_dpalock]]
}

proc lvds_soft_reset {fd dp_master} {
    global LVDS
    log_lvds_status $fd $dp_master "BEFORE"
    write_verify $fd $dp_master $LVDS 4 0x000001ff 0x000001ff "lvds.lane_go"
    write_word $dp_master $LVDS 6 0x000001ff
    log_line $fd "LVDS_SOFT_RESET_WRITE mask=0x000001ff"
    after 1200
    log_lvds_status $fd $dp_master "AFTER"
}

proc read_bins {dp_master} {
    global HIST_BIN N_BINS
    set raw [master_read_32 $dp_master $HIST_BIN $N_BINS]
    set out [list]
    foreach value $raw {
        lappend out [expr {$value + 0}]
    }
    return $out
}

proc summarize_bins {bins} {
    set sum 0
    set occupied 0
    set max_value 0
    set max_bin 0
    set idx 0
    foreach value $bins {
        set value [expr {$value + 0}]
        set sum [expr {$sum + $value}]
        if {$value > 0} {
            incr occupied
        }
        if {$value > $max_value} {
            set max_value $value
            set max_bin $idx
        }
        incr idx
    }
    return [list $sum $occupied $max_bin $max_value]
}

proc run_window {fd csv_fd runctl_master dp_master label ctrl interval pulse_high dwell_ms} {
    global HIST_CSR INJ
    log_line $fd "WINDOW_START label=$label interval=$interval ctrl=[fmt $ctrl]"
    set_real_path $fd $dp_master
    configure_injector $fd $dp_master $interval $pulse_high
    runctl_cmd $fd $runctl_master 0x13 180
    runctl_cmd $fd $runctl_master 0x110 300
    runctl_cmd $fd $runctl_master 0x11 240
    set status [runctl_cmd $fd $runctl_master 0x12 350]
    arm_histogram $fd $dp_master $ctrl
    write_verify $fd $dp_master $INJ 2 2 0x0000000f "inj.mode.periodic"
    after $dwell_ms
    set total [read_word $dp_master $HIST_CSR 13]
    set dropped [read_word $dp_master $HIST_CSR 14]
    set coal [read_word $dp_master $HIST_CSR 15]
    set last_total [read_word $dp_master $HIST_CSR 17]
    set last_drop [read_word $dp_master $HIST_CSR 18]
    set bins [read_bins $dp_master]
    lassign [summarize_bins $bins] bin_sum occupied max_bin max_value
    log_line $fd [format "WINDOW_RESULT label=%s status=%s total=%u last_total=%u dropped=%u last_drop=%u coal=%s occupied=%u bin_sum=%u max_bin=%u max_value=%u" \
        $label [fmt $status] $total $last_total $dropped $last_drop [fmt $coal] $occupied $bin_sum $max_bin $max_value]
    set idx 0
    foreach value $bins {
        puts $csv_fd [format "%s,%d,%d" $label $idx [expr {$value + 0}]]
        incr idx
    }
    terminate_quiet $fd $runctl_master $dp_master
}

set fd [open $out_path w]
set csv_fd [open $csv_path w]
puts $csv_fd "label,bin,count"

log_line $fd "JTAG_REAL_MUTRIG_SMOKE_20260605"
log_line $fd "TIME=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"

set masters [get_service_paths master]
set dp_path [find_master $masters "#7-2" "phy_1/master"]
set runctl_path [find_master $masters "#7-2" "phy_2/master"]
log_line $fd "DATAPATH_MASTER=$dp_path"
log_line $fd "RUNCTL_MASTER=$runctl_path"
if {$dp_path eq "" || $runctl_path eq ""} {
    error "missing FEB datapath or runctl JTAG master"
}

set dp_master [claim_service master $dp_path ""]
set runctl_master [claim_service master $runctl_path ""]

set hist_uid [read_word $dp_master $HIST_CSR 0]
set inj_uid [read_word $dp_master $INJ 0]
set runctl_uid [read_word $runctl_master $RUNCTL 0]
log_line $fd [format "UIDS hist=%s inj=%s runctl=%s" [fmt $hist_uid] [fmt $inj_uid] [fmt $runctl_uid]]
if {$hist_uid != $HIST_UID || $inj_uid != $INJ_UID || $runctl_uid != $RCMH_UID} {
    error "unexpected UID set"
}

lvds_soft_reset $fd $dp_master

run_window $fd $csv_fd $runctl_master $dp_master "type0" $CTRL_TYPE0 $INTERVAL $PULSE_HIGH $DWELL_MS
run_window $fd $csv_fd $runctl_master $dp_master "type1_up" $CTRL_TYPE1_UP $INTERVAL $PULSE_HIGH $DWELL_MS
run_window $fd $csv_fd $runctl_master $dp_master "type1_down" $CTRL_TYPE1_DOWN $INTERVAL $PULSE_HIGH $DWELL_MS

terminate_quiet $fd $runctl_master $dp_master
close_service master $runctl_master
close_service master $dp_master
close $csv_fd
close $fd
puts "WROTE=$out_path"
puts "CSV=$csv_path"
