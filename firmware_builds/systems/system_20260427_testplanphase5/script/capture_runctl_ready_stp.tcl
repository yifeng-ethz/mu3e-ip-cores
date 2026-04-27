#!/usr/bin/env quartus_stp -t
# Usage:
#   quartus_stp -t capture_runctl_ready_stp.tcl <stpfile> <out_vcd> [trigger_name]
#
# Example:
#   quartus_stp -t firmware_builds/systems/system_20260427_testplanphase5/script/capture_runctl_ready_stp.tcl \
#       firmware_builds/systems/system_20260427_testplanphase5/signaltap/phase4c_runctl_ready_fanout.stp \
#       /tmp/runctl_ready_fanout.vcd \
#       runctl_host_valid_rise
#
# Run the stimulus from another shell while this script is blocked in `run`, e.g.:
#   ./firmware_builds/systems/system_20260427_testplanphase5/bin/rc_tool 2 send reset

if {$argc < 2} {
    puts "Usage: <stpfile> <out_vcd> [trigger_name]"
    exit 2
}

set stp_file [file normalize [lindex $argv 0]]
set out_vcd  [file normalize [lindex $argv 1]]

set stp_xml [read [set stp_fh [open $stp_file r]]]
close $stp_fh

package require ::quartus::stp
package require ::quartus::jtag

set hw_name ""
set dev_name ""
foreach hw [get_hardware_names] {
    if {[string match "USB-Blaster*" $hw]} {
        set hw_name $hw
        break
    }
}
if {$hw_name eq ""} {
    set hw_name [lindex [get_hardware_names] 0]
}
set dev_name [lindex [get_device_names -hardware_name $hw_name] 0]

set instance_name auto_signaltap_0
set signal_set_name ""
set trigger_name ""

if {[regexp {<display_branch instance="([^"]+)" signal_set="([^"]+)" trigger="([^"]+)"} $stp_xml -> stp_instance stp_signal_set stp_trigger]} {
    set instance_name $stp_instance
    set signal_set_name $stp_signal_set
    set trigger_name $stp_trigger
} else {
    if {[regexp {<instance[^>]*name="([^"]+)"} $stp_xml -> stp_instance]} {
        set instance_name $stp_instance
    }
    if {[regexp {<signal_set[^>]*name="([^"]+)"} $stp_xml -> stp_signal_set]} {
        set signal_set_name $stp_signal_set
    }
    if {[regexp {<trigger[^>]*name="([^"]+)"} $stp_xml -> stp_trigger]} {
        set trigger_name $stp_trigger
    }
}

if {$argc >= 3 && [lindex $argv 2] ne ""} {
    set trigger_name [lindex $argv 2]
}

if {$signal_set_name eq "" || $trigger_name eq ""} {
    puts "Failed to extract SignalTap names from $stp_file"
    exit 3
}
set data_log_name "runctl_ready_[clock clicks]"

puts "Using hardware: $hw_name"
puts "Using device  : $dev_name"
puts "Opening STP   : $stp_file"
puts "Output VCD    : $out_vcd"

open_session -name $stp_file
run \
    -hardware_name $hw_name \
    -device_name $dev_name \
    -instance $instance_name \
    -signal_set $signal_set_name \
    -trigger $trigger_name \
    -data_log $data_log_name \
    -timeout 30

file mkdir [file dirname $out_vcd]
export_data_log \
    -instance $instance_name \
    -signal_set $signal_set_name \
    -trigger $trigger_name \
    -data_log $data_log_name \
    -filename $out_vcd \
    -format vcd

close_session
puts "Wrote $out_vcd"
