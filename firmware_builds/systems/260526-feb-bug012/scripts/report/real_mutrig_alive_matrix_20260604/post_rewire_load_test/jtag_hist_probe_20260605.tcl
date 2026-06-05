set out_path "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/260526-feb-bug012/scripts/report/real_mutrig_alive_matrix_20260604/post_rewire_load_test/jtag_hist_probe_20260605.log"

proc log_line {fd msg} {
    puts $fd $msg
    flush $fd
    puts $msg
}

proc read_one {fd master addr label} {
    if {[catch {master_read_32 $master $addr 1} value]} {
        log_line $fd [format "READ %-18s addr=0x%08x ERROR=%s" $label $addr $value]
        return
    }
    log_line $fd [format "READ %-18s addr=0x%08x value=%s" $label $addr $value]
}

set fd [open $out_path w]
log_line $fd "JTAG_HIST_PROBE_20260605"
log_line $fd "TIME=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"

set masters [get_service_paths master]
log_line $fd "MASTER_COUNT=[llength $masters]"
set idx 0
foreach path $masters {
    log_line $fd [format {MASTER[%d]=%s} $idx $path]
    set idx [expr {$idx + 1}]
}

foreach path $masters {
    if {[string first "master_datapath" $path] < 0 &&
        [string first "/phy_1/master" $path] < 0 &&
        [string first "phy_1/data_path" $path] < 0} {
        log_line $fd "SKIP_MASTER=$path"
        continue
    }

    log_line $fd "CLAIM_MASTER=$path"
    if {[catch {claim_service master $path ""} master_fd]} {
        log_line $fd "CLAIM_ERROR=$master_fd"
        continue
    }

    read_one $fd $master_fd 0x00007000 "hist_uid"
    read_one $fd $master_fd 0x00007004 "hist_meta"
    read_one $fd $master_fd 0x00007008 "hist_control"
    read_one $fd $master_fd 0x00007038 "hist_dropped"
    read_one $fd $master_fd 0x0000703c "hist_coal"
    read_one $fd $master_fd 0x0000a000 "injector_uid"
    read_one $fd $master_fd 0x00000000 "lvds_uid"

    catch {close_service master $master_fd} close_msg
    log_line $fd "CLOSE_MASTER=$path"
}

close $fd
puts "WROTE=$out_path"
