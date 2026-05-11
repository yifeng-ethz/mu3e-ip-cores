#!/bin/sh
# \
exec quartus_sh -t "$0" "$@"

set QSF [ lindex $argv 0 ]
cd [ file dirname $QSF ]
set QSF [ file tail $QSF ]

namespace eval ::quartus::qsf {

    set family ""
    set device ""

    proc set_global_assignment { args } {
        if { [ string equal [ lindex $args 0 ] "-name" ] != 1 } return
        set name [ lindex $args 1 ]
        set value [ lindex $args 2 ]
        switch $name {
            QIP_FILE {
                if { [ file exists $value ] == 0 } {
                    puts stderr "W \[set_global_assignment\] QIP '$value' not found"
                } else {
                    lappend ::quartus::qsf::deps([ info script ]) "$value"
                    set ::quartus::qsf::deps($value) [ list ]
                    source $value
                }
            }
            SOURCE_TCL_SCRIPT_FILE {
                if { [ file exists $value ] == 0 } {
                    puts stderr "W \[set_global_assignment\] TCL '$value' not found"
                } else {
                    lappend ::quartus::qsf::deps([ info script ]) "$value"
                    set ::quartus::qsf::deps($value) [ list ]
                    source $value
                }
            }
            VHDL_FILE {
                lappend ::quartus::qsf::deps([ info script ]) "$value"
                puts $value
            }

            # check FAMILY/DEVICE assignments
            FAMILY {
                set family $::quartus::qsf::family
                if { $family != "" && $family != $value } {
                    puts stderr "E \[set_global_assignment\] FAMILY '$value', was '$family'"
                }
                set ::quartus::qsf::family $value
            }
            DEVICE {
                set device $::quartus::qsf::device
                if { $device != "" && $device != $value } {
                    puts stderr "E \[set_global_assignment\] DEVICE '$value', was '$device'"
                }
                set ::quartus::qsf::device $value
            }
        }
    }

    proc set_instance_assignment { args } {
    }

    proc set_location_assignment { args } {
    }

#    proc set_parameter { args } {
#    }

    # intercept access to ::quartus(qip_path)
    proc trace_quartus_qip_path { args } {
        set ::quartus(qip_path) [ file dirname [ info script ] ]
    }

    trace add variable ::quartus(qip_path) read trace_quartus_qip_path

    set deps(top.qsf) [ list ]
    source "$QSF"

    trace remove variable ::quartus(qip_path) read trace_quartus_qip_path

    set f [ open "top.d" w ]
    foreach i [ array names ::quartus::qsf::deps ] {
        puts $f "$i : $::quartus::qsf::deps($i)"
    }
    close $f
}
