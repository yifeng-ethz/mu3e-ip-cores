package require Tcl 8.5

# ring_buffer_cam_meta_probe.tcl
# Post-launch probe: reads ring_buffer_cam registers to validate the BSP layout.
# Tries the already-claimed master first. If that fails (wrong master for data path),
# scans available masters using claim_service and finds one that can reach 0x21000.

namespace eval ::fe_scifi::board_bring_up::debug::rbcam_probe {
    variable output_path "/tmp/ring_buffer_cam_meta_probe.txt"
}

proc ::fe_scifi::board_bring_up::debug::rbcam_probe::write_lines {lines} {
    variable output_path
    set fd [open $output_path w]
    foreach line $lines {
        puts $fd $line
    }
    close $fd
}

proc ::fe_scifi::board_bring_up::debug::rbcam_probe::run {} {
    set lines [list]
    lappend lines "PROBE=ring_buffer_cam_meta_probe"
    lappend lines "TIMESTAMP=[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"

    if {[catch {
        set fd_gv "globalVariableTable"
        set rbcam_bases [::mu3e::helpers::get_global_variable $fd_gv "ring_buffer_cam.csr_base_address"]
        lappend lines "RBCAM_BASES=$rbcam_bases"
        set base [lindex $rbcam_bases 0]
        lappend lines "TARGET_BASE=$base"

        # Try the already-claimed master first
        set master_fd [::mu3e::helpers::cget_opened_master_path]
        lappend lines "CLAIMED_MASTER=$master_fd"

        set use_master $master_fd
        set quick_ok 0
        if {![catch {master_read_32 $master_fd [expr {$base + 0x0C}] 1} qr]} {
            set quick_ok 1
            lappend lines "QUICK_READ_OK=[format 0x%08X [expr {$qr & 0xFFFFFFFF}]]"
        } else {
            lappend lines "QUICK_READ_FAIL=$qr"
            lappend lines "NOTE=Claimed master cannot reach data path. Trying other masters..."

            # Scan available masters on the target device (Arria V)
            set all_masters [get_service_paths master]
            set arria_masters [list]
            foreach mp $all_masters {
                if {[string match "*5AGXBA7D4*" $mp]} {
                    lappend arria_masters $mp
                }
            }
            lappend lines "ARRIA_V_MASTERS=[llength $arria_masters]"

            foreach mp $arria_masters {
                lappend lines "  TRYING=$mp"
                if {[catch {claim_service master $mp rbcam_probe ""} claimed]} {
                    lappend lines "    CLAIM_ERROR=$claimed"
                    continue
                }
                if {![catch {master_read_32 $claimed [expr {$base + 0x0C}] 1} tr]} {
                    lappend lines "    READ_OK=[format 0x%08X [expr {$tr & 0xFFFFFFFF}]]"
                    set use_master $claimed
                    set quick_ok 1
                    break
                } else {
                    lappend lines "    READ_FAIL=$tr"
                }
            }
        }

        if {!$quick_ok} {
            lappend lines "NO_REACHABLE_MASTER"
            lappend lines "STATUS=FAIL"
            ::fe_scifi::board_bring_up::debug::rbcam_probe::write_lines $lines
            return
        }

        lappend lines "USING_MASTER=$use_master"

        # Dump first 10 words raw
        lappend lines "--- INSTANCE 0 BASE=$base RAW_DUMP ---"
        for {set w 0} {$w <= 9} {incr w} {
            set addr [expr {$base + $w * 4}]
            if {[catch {master_read_32 $use_master $addr 1} val]} {
                lappend lines [format "  WORD_%d (0x%02X) = ERROR" $w [expr {$w*4}]]
            } else {
                lappend lines [format "  WORD_%d (0x%02X) = 0x%08X" $w [expr {$w*4}] [expr {$val & 0xFFFFFFFF}]]
            }
        }

        # Detect layout
        if {[catch {master_read_32 $use_master [expr {$base + 0x00}] 1} word0]} {
            lappend lines "WORD0_READ_ERROR=$word0"
        } else {
            set w0 [expr {$word0 & 0xFFFFFFFF}]
            if {$w0 == 0x5242434D} {
                lappend lines "DETECTED_LAYOUT=NEW_26_1 (UID=RBCM)"
                foreach {sel name} {0 VERSION 1 DATE 2 GIT 3 INSTANCE_ID} {
                    catch {master_write_32 $use_master [expr {$base + 0x04}] $sel}
                    if {[catch {master_read_32 $use_master [expr {$base + 0x04}] 1} mr]} {
                        lappend lines "META_${name}=ERROR"
                    } else {
                        set mhex [format "0x%08X" [expr {$mr & 0xFFFFFFFF}]]
                        if {$name eq "VERSION"} {
                            set major [expr {($mr >> 24) & 0xFF}]
                            set minor [expr {($mr >> 16) & 0xFF}]
                            set patch [expr {($mr >> 12) & 0xF}]
                            set build [expr {$mr & 0xFFF}]
                            lappend lines "META_${name}=$mhex (${major}.${minor}.${patch}.${build})"
                        } elseif {$name eq "DATE"} {
                            lappend lines "META_${name}=$mhex (decimal=[expr {$mr & 0xFFFFFFFF}])"
                        } else {
                            lappend lines "META_${name}=$mhex"
                        }
                    }
                }
                if {![catch {master_read_32 $use_master [expr {$base + 0x08}] 1} cv]} {
                    set go [expr {$cv & 0x1}]
                    set sr [expr {($cv >> 1) & 0x1}]
                    set fe [expr {($cv >> 4) & 0x1}]
                    lappend lines "CTRL=[format 0x%08X [expr {$cv & 0xFFFFFFFF}]] (go=$go soft_reset=$sr filter_inerr=$fe)"
                }
                if {![catch {master_read_32 $use_master [expr {$base + 0x0C}] 1} lv]} {
                    lappend lines "EXPECTED_LATENCY=[format 0x%04X [expr {$lv & 0xFFFF}]] (decimal=[expr {$lv & 0xFFFF}])"
                }
            } else {
                lappend lines "DETECTED_LAYOUT=OLD_PRE_26_1 (word0=[format 0x%08X $w0])"
                lappend lines "NOTE=Firmware predates _hw.tcl 26.1. UID/META registers not present."
                set go [expr {$w0 & 0x1}]
                set sr [expr {($w0 >> 1) & 0x1}]
                set fe [expr {($w0 >> 4) & 0x1}]
                lappend lines "OLD_CTRL=[format 0x%08X $w0] (go=$go soft_reset=$sr filter_inerr=$fe)"
                if {![catch {master_read_32 $use_master [expr {$base + 0x04}] 1} lat]} {
                    lappend lines "OLD_EXPECTED_LATENCY=[format 0x%04X [expr {$lat & 0xFFFF}]] (decimal=[expr {$lat & 0xFFFF}])"
                }
                lappend lines ""
                lappend lines "CONCLUSION=The BSP update is correct for _hw.tcl 26.1 but the FPGA"
                lappend lines "  bitstream still runs the old RTL without UID/META header."
                lappend lines "  Recompile the FPGA to match the new register layout."
            }
        }

        lappend lines "STATUS=OK"
    } probe_error probe_options]} {
        lappend lines "PROBE_ERROR=$probe_error"
        if {[dict exists $probe_options -errorinfo]} {
            lappend lines "PROBE_ERRORINFO=[dict get $probe_options -errorinfo]"
        }
        lappend lines "STATUS=FAIL"
    }

    ::fe_scifi::board_bring_up::debug::rbcam_probe::write_lines $lines
    if {[llength [info commands toolkit_send_message]] > 0} {
        toolkit_send_message info "ring_buffer_cam_meta_probe: wrote [namespace eval ::fe_scifi::board_bring_up::debug::rbcam_probe {set output_path}]"
    }
}

after 8000 ::fe_scifi::board_bring_up::debug::rbcam_probe::run
