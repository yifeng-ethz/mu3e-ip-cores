#!/usr/bin/env quartus_stp -t
# Usage:
#   quartus_stp -t capture_signaltap_vcd.tcl \
#       <stpfile> <out_vcd> <instance_name> <signal_set_name> <trigger_name> \
#       [data_log_name] [timeout_s]

if {$argc < 5} {
    puts "Usage: <stpfile> <out_vcd> <instance_name> <signal_set_name> <trigger_name> ?data_log_name? ?timeout_s?"
    exit 2
}

set stp_file         [file normalize [lindex $argv 0]]
set out_vcd          [file normalize [lindex $argv 1]]
set instance_name    [lindex $argv 2]
set signal_set_name  [lindex $argv 3]
set trigger_name     [lindex $argv 4]
set data_log_name    "capture_[clock clicks]"
set timeout_s        30

if {$argc >= 6} {
    set data_log_name [lindex $argv 5]
}
if {$argc >= 7} {
    set timeout_s [lindex $argv 6]
}

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
