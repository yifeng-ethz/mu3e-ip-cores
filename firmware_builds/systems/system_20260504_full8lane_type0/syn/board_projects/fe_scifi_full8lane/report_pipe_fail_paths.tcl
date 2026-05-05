package require ::quartus::project
package require ::quartus::sta

set project_name top
set revision_name top_nostp_pipe
if {[llength $argv] >= 1} {
    set revision_name [lindex $argv 0]
}

set out_dir [file join [pwd] timing_debug $revision_name]
file mkdir $out_dir

project_open $project_name -revision $revision_name
create_timing_netlist
read_sdc
update_timing_netlist

set lvds_firefly_clk [get_clocks -nowarn {lvds_firefly_clk}]
set xcvr_clk [get_clocks -nowarn {transceiver_pll_clock[0]}]

if {[get_collection_size $lvds_firefly_clk] == 0} {
    post_message -type error "Failed to resolve lvds_firefly_clk for revision $revision_name"
    error "lvds_firefly_clk not found"
}

if {[get_collection_size $xcvr_clk] == 0} {
    post_message -type error "Failed to resolve transceiver_pll_clock[0] for revision $revision_name"
    error "transceiver_pll_clock[0] not found"
}

report_timing -setup -npaths 20 -detail full_path -show_routing \
    -to_clock $lvds_firefly_clk \
    -file [file join $out_dir lvds_firefly_setup_all_sources.rpt]

report_timing -recovery -npaths 20 -detail full_path -show_routing \
    -to_clock $xcvr_clk \
    -file [file join $out_dir xcvr_recovery_all_sources.rpt]

report_timing -recovery -npaths 20 -detail full_path -show_routing \
    -from [all_inputs] -to_clock $xcvr_clk \
    -file [file join $out_dir xcvr_recovery_inputs.rpt]

reset_design
delete_timing_netlist
project_close
