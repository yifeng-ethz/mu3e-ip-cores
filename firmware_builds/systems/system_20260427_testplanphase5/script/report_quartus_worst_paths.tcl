package require ::quartus::project
package require ::quartus::sta

if {[llength $argv] != 3} {
    puts stderr "usage: quartus_sta -t report_quartus_worst_paths.tcl <project> <revision> <output-dir>"
    qexit -error
}

set project_name [lindex $argv 0]
set revision_name [lindex $argv 1]
set output_dir [lindex $argv 2]

file mkdir $output_dir

project_open -revision $revision_name $project_name
create_timing_netlist
read_sdc
update_timing_netlist

set setup_report [file join $output_dir "${revision_name}.worst_setup_paths.rpt"]
set hold_report [file join $output_dir "${revision_name}.worst_hold_paths.rpt"]

report_timing -setup -npaths 25 -detail full_path -show_routing -file $setup_report
report_timing -hold -npaths 10 -detail full_path -show_routing -file $hold_report

delete_timing_netlist
project_close
