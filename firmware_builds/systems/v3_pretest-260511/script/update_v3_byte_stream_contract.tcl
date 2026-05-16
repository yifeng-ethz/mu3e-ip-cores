# qsys-script recipe for the v3 emulator Type-0 contract.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

set instances [get_instances]

if {[lsearch -exact $instances {emulator_mutrig_0}] >= 0} {
    foreach idx {0 1 2 3 4 5 6 7} {
        set inst "emulator_mutrig_${idx}"
        if {[lsearch -exact $instances $inst] < 0} {
            error "required instance $inst is missing from datapath Qsys"
        }
        set_instance_parameter_value $inst {BYTE_STREAM_ENABLE} {false}
    }
} elseif {[lsearch -exact $instances {data_path_subsystem}] < 0} {
    error {unable to infer Qsys role: no emulator_mutrig_0 or data_path_subsystem instance found}
}

save_system
