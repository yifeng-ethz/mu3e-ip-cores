# patch_scifi_datapath_v4_runctl_export_width.tcl
# Pin the exported runctl_mgmt_host sink interface width on
# scifi_datapath_system_v4 so that when feb_system_v4 re-elaborates the
# data_path_subsystem, the parent connection carries an explicit
# dataBitsPerSymbol/symbolsPerBeat into run_control_mux.in0. Without this the
# multiplexer output bitsPerSymbol collapses to 0 in the parent context and the
# inserted timing/channel adapter (avalon_st_adapter_008) fails with
# "divide by zero" on inDataWidth/inBitsPerSymbol. Closes BUG-024-I.
#
# Run-control profile (run-control_mgmt/runctl_mgmt_host_hw.tcl interface runctl):
#   dataBitsPerSymbol = 9, symbolsPerBeat = 1, valid-only, READYLESS, no channel.
# This patch only annotates the EXPORTED interface metadata; it does not add
# ready/backpressure and does not alter the mux/terminator/splitter fanout, so
# the readyless broadcast contract (BUG-018-R/BUG-019-R) is preserved.
#
# Invoke as:
#   qsys-script --search-path=... --script=<this file> <scifi_datapath_system_v4.qsys path>

package require -exact qsys 18.1

if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
puts "patch_runctl_export_width: load_system $qsys_path"
load_system $qsys_path

set iface "runctl_mgmt_host"
puts "patch_runctl_export_width: pin $iface dataBitsPerSymbol=9 symbolsPerBeat=1"
catch {set_interface_property $iface dataBitsPerSymbol 9}
catch {set_interface_property $iface symbolsPerBeat 1}

puts "patch_runctl_export_width: save_system $qsys_path"
save_system

puts "patch_runctl_export_width: done"
