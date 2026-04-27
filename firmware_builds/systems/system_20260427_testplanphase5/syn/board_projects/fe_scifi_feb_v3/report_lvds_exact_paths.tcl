package require ::quartus::project
package require ::quartus::sta

source [file join [file dirname [info script]] timing_clock_aliases.tcl]

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

set lvds_clk [mu3e_clock_alias_primary lvds_rx_clock]
set xcvr_clk [mu3e_clock_alias_primary xcvr_tx_clock]

if {[get_collection_size $lvds_clk] == 0} {
    post_message -type error "Failed to resolve LVDS setup clock for revision $revision_name"
    error "LVDS setup clock not found"
}

if {[get_collection_size $xcvr_clk] == 0} {
    post_message -type error "Failed to resolve XCVR setup clock for revision $revision_name"
    error "XCVR setup clock not found"
}

post_message -type info "Resolved [mu3e_clock_alias_label lvds_rx_clock] as [get_clock_info -name $lvds_clk]"
post_message -type info "Resolved [mu3e_clock_alias_label xcvr_tx_clock] as [get_clock_info -name $xcvr_clk]"

report_timing -setup -npaths 10 -detail full_path -show_routing \
    -from [all_registers] -to [all_registers] \
    -from_clock $lvds_clk -to_clock $lvds_clk \
    -file [file join $out_dir lvds_setup_full_path.rpt]

report_timing -setup -npaths 10 -detail full_path -show_routing \
    -from [all_registers] -to [all_registers] \
    -from_clock $xcvr_clk -to_clock $xcvr_clk \
    -file [file join $out_dir xcvr0_setup_full_path.rpt]

report_clock_transfers -setup \
    -file [file join $out_dir clock_transfers_setup.rpt]

report_ucp -panel_name "Unconstrained Paths" \
    -file [file join $out_dir unconstrained_paths.rpt]

reset_design
delete_timing_netlist
project_close
