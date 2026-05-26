package require ::quartus::stp

set hw_substr  [lindex $argv 0]
set dev_substr [lindex $argv 1]
set stp_file   [lindex $argv 2]
set inst       [lindex $argv 3]
set sigset     [lindex $argv 4]
set trig       [lindex $argv 5]
set out_csv    [lindex $argv 6]
set data_log   [lindex $argv 7]
set timeout_s  [lindex $argv 8]
if {$timeout_s eq ""} {
    set timeout_s 30
}

set hw_name ""
foreach h [get_hardware_names] {
    if {[string first $hw_substr $h] >= 0} {
        set hw_name $h
    }
}
if {$hw_name eq ""} {
    puts "ERROR: no hardware matching '$hw_substr'."
    foreach h [get_hardware_names] {
        puts "  HW: $h"
    }
    exit 2
}
puts "HARDWARE: $hw_name"

set dev_name ""
foreach d [get_device_names -hardware_name $hw_name] {
    if {[string first $dev_substr $d] >= 0} {
        set dev_name $d
    }
}
if {$dev_name eq ""} {
    puts "ERROR: no device matching '$dev_substr' on $hw_name."
    foreach d [get_device_names -hardware_name $hw_name] {
        puts "  DEV: $d"
    }
    exit 3
}
puts "DEVICE: $dev_name"

open_session -name $stp_file
puts "SESSION OPEN: $stp_file"
puts "RUN instance=$inst sigset=$sigset trig=$trig log=$data_log timeout=${timeout_s}s ..."
set rc [catch {
    run -instance $inst -signal_set $sigset -trigger $trig \
        -data_log $data_log -timeout $timeout_s \
        -hardware_name $hw_name -device_name $dev_name
} msg]
puts "RUN rc=$rc msg=$msg"

set rc2 [catch {
    export_data_log -data_log $data_log -filename $out_csv -format csv \
        -instance $inst -signal_set $sigset -trigger $trig
} msg2]
puts "EXPORT rc=$rc2 msg=$msg2 -> $out_csv"

close_session
puts "DONE"
if {$rc != 0 || $rc2 != 0} {
    exit 4
}
