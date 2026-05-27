#!/usr/bin/env tclsh
# qsys-script driver: load <scifi.qsys>, source the merger->emu_in rewire
# patch, save. argv[0] = path to scifi_datapath_system_v4.qsys.
package require -exact qsys 16.1
if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
# Derive SYSTEM_DIR from the .qsys path (.../<SYSTEM_DIR>/generated/qsys/x.qsys)
# instead of $::env -- qsys-script sanitizes the environment.
if {[info exists ::env(SYSTEM_DIR)]} {
    set system_dir $::env(SYSTEM_DIR)
} else {
    set system_dir [file dirname [file dirname [file dirname $qsys_path]]]
}
set patch [file join $system_dir qsys_tcl patch_scifi_datapath_v4_merger_to_emu.tcl]
puts "APPLY load_system $qsys_path"
load_system $qsys_path
puts "APPLY source $patch"
source $patch
puts "APPLY done $qsys_path"
