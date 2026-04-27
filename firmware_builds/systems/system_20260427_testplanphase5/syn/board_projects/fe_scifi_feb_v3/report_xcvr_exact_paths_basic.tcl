package require ::quartus::project
package require ::quartus::sta

set project_name top
set revision_name top_nostp
if {[llength $argv] >= 1} {
    set revision_name [lindex $argv 0]
}

set out_dir [file join [pwd] timing_debug $revision_name]
file mkdir $out_dir

project_open $project_name -revision $revision_name
create_timing_netlist
read_sdc
update_timing_netlist

set xcvr_clk [get_clocks {transceiver_pll_clock[0]}]
if {[get_collection_size $xcvr_clk] == 0} {
    post_message -type error "Failed to resolve transceiver_pll_clock[0] for revision $revision_name"
    error "transceiver_pll_clock[0] not found"
}

report_timing -setup -npaths 10 -detail full_path \
    -from [all_registers] -to [all_registers] \
    -from_clock $xcvr_clk -to_clock $xcvr_clk \
    -file [file join $out_dir xcvr_setup_basic.rpt]

report_timing -recovery -npaths 10 -detail full_path \
    -from [all_registers] -to [all_registers] \
    -from_clock $xcvr_clk \
    -file [file join $out_dir xcvr_recovery_basic.rpt]

report_ucp -panel_name "Unconstrained Paths" \
    -file [file join $out_dir unconstrained_paths_basic.rpt]

reset_design
delete_timing_netlist
project_close
