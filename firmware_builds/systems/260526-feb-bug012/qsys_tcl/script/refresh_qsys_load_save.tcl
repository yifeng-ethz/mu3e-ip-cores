#!/usr/bin/env tclsh
# qsys-script helper. Loads the .qsys passed as argv[0] and saves it again.
# Forces re-elaboration of nested subsystem references against the current
# IP catalog (used by the qsys-refresh make target to propagate fresh IP
# VERSION_PATCH/BUILD/VERSION_DATE values through the hierarchy).
package require -exact qsys 18.1
if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
set ts [clock format [clock seconds] -format {%H:%M:%S}]
puts "$ts QSYS-REFRESH load_system $qsys_path"
load_system $qsys_path
set ts [clock format [clock seconds] -format {%H:%M:%S}]
puts "$ts QSYS-REFRESH save_system $qsys_path"
save_system
set ts [clock format [clock seconds] -format {%H:%M:%S}]
puts "$ts QSYS-REFRESH done $qsys_path"
