#!/usr/bin/env quartus_stp -t
# Usage:
#   quartus_stp -t capture_signaltap_vcd_hw.tcl \
#       <stpfile> <out_vcd> <instance_name> <signal_set_name> <trigger_name> \
#       [data_log_name] [timeout_s] [hardware_pattern]

if {$argc < 5} {
    puts "Usage: <stpfile> <out_vcd> <instance_name> <signal_set_name> <trigger_name> ?data_log_name? ?timeout_s? ?hardware_pattern?"
    exit 2
}

set stp_file         [file normalize [lindex $argv 0]]
set out_vcd          [file normalize [lindex $argv 1]]
set instance_name    [lindex $argv 2]
set signal_set_name  [lindex $argv 3]
set trigger_name     [lindex $argv 4]
set data_log_name    "capture_[clock clicks]"
set timeout_s        30
set hardware_pattern "*"

if {$argc >= 6} {
    set data_log_name [lindex $argv 5]
}
if {$argc >= 7} {
    set timeout_s [lindex $argv 6]
}
if {$argc >= 8} {
    set hardware_pattern [lindex $argv 7]
}

package require ::quartus::stp
package require ::quartus::jtag

set hw_name ""
foreach hw [get_hardware_names] {
    if {[string match $hardware_pattern $hw]} {
        set hw_name $hw
        break
    }
}
if {$hw_name eq ""} {
    puts "No hardware matched pattern: $hardware_pattern"
    puts "Available hardware:"
    foreach hw [get_hardware_names] {
        puts "  $hw"
    }
    exit 3
}
set dev_name [lindex [get_device_names -hardware_name $hw_name] 0]

puts "Using hardware : $hw_name"
puts "Using device   : $dev_name"
puts "Opening STP    : $stp_file"
puts "Signal set     : $signal_set_name"
puts "Trigger        : $trigger_name"
puts "Data log       : $data_log_name"
puts "Output VCD     : $out_vcd"
puts "Timeout (s)    : $timeout_s"

open_session -name $stp_file
run \
    -hardware_name $hw_name \
    -device_name $dev_name \
    -instance $instance_name \
    -signal_set $signal_set_name \
    -trigger $trigger_name \
    -data_log $data_log_name \
    -timeout $timeout_s

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
