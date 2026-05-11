#!/bin/sh
# \
exec quartus_sta -t "$0" "$@"

# execute from command in firmware project directory with  quartus_sta -t /path/to/print_critical_path.tcl 
project_open -force "top.qpf" -revision top
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_timing -npaths 1
