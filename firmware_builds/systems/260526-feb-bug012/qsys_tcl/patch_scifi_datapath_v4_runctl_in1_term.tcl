# patch_scifi_datapath_v4_runctl_in1_term.tcl
# Surgical qsys-script patch: add an avst_inactive_source to terminate
# run_control_mux.in1 in scifi_datapath_system_v4. Closes BUG-027-like
# floating-input hazard for the runctl AvST mux/adapter chain.
#
# Invoke as:
#   qsys-script --search-path=... --script=<this file> <scifi_datapath_system_v4.qsys path>

package require -exact qsys 18.1

if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
puts "patch_runctl_in1_term: load_system $qsys_path"
load_system $qsys_path

set inst_name "avst_runctl_in1_term"

# Add or update the instance.
set existing [get_instances]
if {[lsearch -exact $existing $inst_name] < 0} {
    puts "patch_runctl_in1_term: add_instance $inst_name avst_inactive_source 26.0.0.0516"
    add_instance $inst_name avst_inactive_source 26.0.0.0516
}
set_instance_parameter_value $inst_name DATA_WIDTH 9
set_instance_parameter_value $inst_name CHANNEL_WIDTH 1
# run_control_mux is altera_multiplexer with usePackets=false; tell the
# inactive source not to advertise SOP/EOP or qsys-generate fails with
# "source has startofpacket signal of 1 bits, but the sink does not".
set_instance_parameter_value $inst_name USE_PACKETS 0

# Connections (idempotent: add_connection is a no-op on duplicates).
catch {add_connection mu3e_lvds_controller_0.outclock $inst_name.clk clock}
catch {add_connection monitor_reset_sync.reset_out    $inst_name.rst reset}
catch {add_connection $inst_name.out run_control_mux.in1 avalon_streaming}

puts "patch_runctl_in1_term: save_system $qsys_path"
save_system

puts "patch_runctl_in1_term: done"
