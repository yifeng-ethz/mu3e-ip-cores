# qsys-script recipe for the v3 emulator byte-stream contract.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

set role {}
if {[info exists ::env(QSYS_BYTE_STREAM_ROLE)]} {
    set role $::env(QSYS_BYTE_STREAM_ROLE)
}

set instances [get_instances]

if {[string equal $role {}]} {
    if {[lsearch -exact $instances {emulator_mutrig_0}] >= 0} {
        set role {datapath}
    } elseif {[lsearch -exact $instances {data_path_subsystem}] >= 0} {
        set role {feb}
    } else {
        error {unable to infer Qsys role: no emulator_mutrig_0 or data_path_subsystem instance found}
    }
}

if {[string equal $role {datapath}]} {
    foreach idx {0 1 2 3 4 5 6 7} {
        set inst "emulator_mutrig_${idx}"
        if {[lsearch -exact $instances $inst] < 0} {
            error "required instance $inst is missing from datapath Qsys"
        }
        set_instance_parameter_value $inst {BYTE_STREAM_ENABLE} {true}
    }
} elseif {[string equal $role {feb}]} {
    if {[lsearch -exact $instances {data_path_subsystem}] < 0} {
        error {required instance data_path_subsystem is missing from FEB Qsys}
    }
} else {
    error "unknown QSYS_BYTE_STREAM_ROLE '$role' (expected datapath or feb)"
}

save_system
