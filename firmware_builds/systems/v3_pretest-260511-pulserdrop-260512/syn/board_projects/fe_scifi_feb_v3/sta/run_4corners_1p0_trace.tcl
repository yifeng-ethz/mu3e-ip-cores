package require ::quartus::project
package require ::quartus::sta

set project_name top
set revision_name top

set report_dir [file join [pwd] sta fail_trace_1p0]
file mkdir $report_dir

project_open $project_name -revision $revision_name
create_timing_netlist
read_sdc

report_clocks -file [file join $report_dir clocks_1p0.rpt]
report_sdc -file [file join $report_dir sdc_1p0.rpt]

set corners {
    slow85 5_H4_slow_1100mv_85c
    slow0  5_H4_slow_1100mv_0c
    fast85 MIN_fast_1100mv_85c
    fast0  MIN_fast_1100mv_0c
}

set summary_path [file join $report_dir summary_1p0.txt]
set summary_fh [open $summary_path w]
puts $summary_fh "FEB SciFi v3 integration STA trace at 1.0x nominal clocks"
puts $summary_fh "Project: $project_name"
puts $summary_fh "Revision: $revision_name"
puts $summary_fh "Generated: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $summary_fh "Clock source: board-local top.qip SDC_FILE entries, no 1.1x override"
puts $summary_fh ""

foreach {label op} $corners {
    set_operating_conditions $op
    update_timing_netlist

    puts $summary_fh "## $label ($op)"

    set setup_path [file join $report_dir "${label}_setup_full_path.rpt"]
    set hold_path [file join $report_dir "${label}_hold_full_path.rpt"]
    set recovery_path [file join $report_dir "${label}_recovery_full_path.rpt"]
    set removal_path [file join $report_dir "${label}_removal_full_path.rpt"]

    report_timing -setup -npaths 20 -detail full_path -show_routing \
        -file $setup_path
    report_timing -hold -npaths 20 -detail full_path -show_routing \
        -file $hold_path
    report_timing -recovery -npaths 20 -detail full_path -show_routing \
        -file $recovery_path
    report_timing -removal -npaths 20 -detail full_path -show_routing \
        -file $removal_path

    puts $summary_fh "setup_report: $setup_path"
    puts $summary_fh "hold_report: $hold_path"
    puts $summary_fh "recovery_report: $recovery_path"
    puts $summary_fh "removal_report: $removal_path"
    puts $summary_fh ""
}

close $summary_fh

delete_timing_netlist
project_close
