# patch_scifi_datapath_v4_runctl_drop_mux.tcl
# BUG-024-I fix: collapse the vestigial run_control_mux on
# scifi_datapath_system_v4 so feb_system_v4 can re-elaborate the
# data_path_subsystem without the avalon_st_adapter "divide by zero".
#
# Root cause: run_control_mux (altera multiplexer, 2 inputs) had in0 = the
# exported runctl source (9-bit, valid-only, READYLESS, no channel) and
# in1 = avst_runctl_in1_term (a dead terminator that advertises a channel +
# ready). When feb_system_v4 re-elaborates the subsystem, the mux cannot
# reconcile the channel-less/readyless in0 against the channel/ready in1 and
# its output bitsPerSymbol collapses to 0, so the inserted channel/timing
# adapter divides inDataWidth/0. The multiplexer cannot be reduced to a single
# input (numInputInterfaces range is 2-16) and the export width cannot be
# pinned (set_interface_property rejects dataBitsPerSymbol on an export), so the
# mux is removed entirely.
#
# Why this is safe for the READYLESS broadcast contract (BUG-018-R/BUG-019-R):
# the readyless property is owned by run_control_splitter (USE_READY=0,
# READY_LATENCY=0, QUALIFY_VALID_OUT=0; see set_readyless_ctrl_splitters.tcl),
# NOT by the mux. The mux was a degenerate 2-input fan-in whose in1 terminator
# never asserts valid. The runctl source profile (9-bit, valid-only, no channel,
# no ready, no packets) matches the splitter "in" profile exactly, so the
# export connects directly to run_control_splitter.in with no adapter. All 16
# splitter outputs to the run-control consumers are untouched.
#
# Invoke as:
#   qsys-script --search-path=... --script=<this file> <scifi_datapath_system_v4.qsys path>

package require -exact qsys 18.1

if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
puts "patch_runctl_drop_mux: load_system $qsys_path"
load_system $qsys_path

# 1. Re-point the exported runctl sink from the mux input to the splitter input.
set iface "runctl_mgmt_host"
if {[lsearch -exact [get_interfaces] $iface] >= 0} {
    puts "patch_runctl_drop_mux: remove_interface $iface (was run_control_mux.in0)"
    remove_interface $iface
}

# 2. Remove the vestigial mux and the dead terminator. Removing an instance
#    also removes every connection that touches it.
foreach inst {run_control_mux avst_runctl_in1_term} {
    if {[lsearch -exact [get_instances] $inst] >= 0} {
        puts "patch_runctl_drop_mux: remove_instance $inst"
        remove_instance $inst
    }
}

# 3. Export the runctl source directly onto the readyless splitter input.
puts "patch_runctl_drop_mux: add_interface $iface -> run_control_splitter.in"
add_interface $iface avalon_streaming sink
set_interface_property $iface EXPORT_OF run_control_splitter.in

puts "patch_runctl_drop_mux: save_system $qsys_path"
save_system

puts "patch_runctl_drop_mux: done"
