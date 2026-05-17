package require -exact qsys 18.1

if {![info exists ::debug_level]} {
    error "set ::debug_level before sourcing set_qsys_debug_level.tcl"
}

set debug_level $::debug_level
if {($debug_level < 0) || ($debug_level > 2)} {
    error "DEBUG_LEVEL must be in the range 0..2"
}

set changed_count 0
foreach inst [get_instances] {
    if {[lsearch -exact [get_instance_parameters $inst] DEBUG_LEVEL] >= 0} {
        set_instance_parameter_value $inst DEBUG_LEVEL $debug_level
        incr changed_count
    }
}

validate_system
save_system
puts "INFO: set DEBUG_LEVEL=${debug_level} on ${changed_count} instance(s)"
