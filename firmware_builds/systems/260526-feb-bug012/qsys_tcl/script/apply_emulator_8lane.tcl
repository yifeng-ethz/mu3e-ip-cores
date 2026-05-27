#!/usr/bin/env tclsh
# qsys-script driver: load <scifi.qsys>, source the 8-lane emulator rewire
# patch, save. argv[0] = path to scifi_datapath_system_v4.qsys.
package require -exact qsys 16.1
if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
# SYSTEM_DIR is exported by the caller; the patch lives under qsys_tcl/.
set patch [file join $::env(SYSTEM_DIR) qsys_tcl patch_scifi_datapath_v4_emulator_8lane.tcl]
puts "APPLY load_system $qsys_path"
load_system $qsys_path
puts "APPLY source $patch"
source $patch
puts "APPLY done $qsys_path"
