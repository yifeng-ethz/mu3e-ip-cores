#!/usr/bin/env tclsh
# qsys-script driver: load <scifi.qsys>, remove the 8 avst_inactive_emu
# terminators (and their out/clk/rst connections), save. argv[0] = path to
# scifi_datapath_system_v4.qsys.
#
# Why: avst_inactive_emu_K.out -> arb.emu_in_K forces Qsys to auto-insert an
# avalon_st_adapter because the terminator does not drive arb.emu_in_K's
# error/endofrun ports; the adapter crashes with "can't read inPortErrorWidth".
# arb is MODE=REAL (MODE_DEFAULT=0) and ignores emu_in entirely, so leaving
# arb.emu_in_K unconnected (ties to 0 in synthesis, benign warning) is correct
# and inserts no adapter.
package require -exact qsys 16.1
if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
puts "APPLY load_system $qsys_path"
load_system $qsys_path

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

for {set k 0} {$k < 8} {incr k} {
    set ti avst_inactive_emu_${k}
    # Remove every connection touching this terminator (out/clk/rst).
    foreach c [get_connections] {
        if {[string match "*${ti}.*" $c]} {
            puts "APPLY remove_connection $c"
            remove_connection $c
        }
    }
    if {[has_instance $ti]} {
        puts "APPLY remove_instance $ti"
        remove_instance $ti
    }
}

puts "APPLY save_system"
save_system
puts "APPLY done $qsys_path"
