package require -exact qsys 18.1

proc abs_path {path} {
    if {[string equal [file pathtype $path] "absolute"]} {
        return $path
    }
    return [file join [pwd] $path]
}

if {[info exists ::phase5_system_dir] && [string match "/*" $::phase5_system_dir]} {
    set system_root $::phase5_system_dir
} elseif {[info exists ::env(PHASE5_SYSTEM_DIR)] && [string match "/*" $::env(PHASE5_SYSTEM_DIR)]} {
    set system_root $::env(PHASE5_SYSTEM_DIR)
} else {
    set script_dir [file dirname [abs_path [info script]]]
    set system_root [file dirname $script_dir]
}

set syn_dir [file join $system_root syn]
set pipe_qsys [file join $syn_dir scifi_datapath_system_v3_pipe.qsys]
if {![file exists $pipe_qsys]} {
    error "Pipe Qsys file not found: $pipe_qsys"
}

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc has_instance_parameter {name parameter} {
    return [expr {[lsearch -exact [get_instance_parameters $name] $parameter] >= 0}]
}

proc require_connection {path} {
    if {[lsearch -exact [get_connections] $path] < 0} {
        error "Required Qsys connection missing: $path"
    }
}

proc set_mts_runtime_lookback_version {name} {
    if {![has_instance $name]} {
        error "Required MTS instance missing: $name"
    }
    foreach parameter {
        MUTRIG_BUFFER_EXPECTED_LATENCY_8N
        MUTRIG_OVERFLOW_LOOKBACK_8N
        VERSION_MAJOR
        VERSION_MINOR
        VERSION_PATCH
        BUILD
        VERSION_DATE
        VERSION_GIT
    } {
        if {![has_instance_parameter $name $parameter]} {
            error "MTS instance $name missing parameter $parameter"
        }
    }

    set_instance_parameter_value $name MUTRIG_BUFFER_EXPECTED_LATENCY_8N 2000
    set_instance_parameter_value $name MUTRIG_OVERFLOW_LOOKBACK_8N 2000
    set_instance_parameter_value $name VERSION_MAJOR 26
    set_instance_parameter_value $name VERSION_MINOR 0
    set_instance_parameter_value $name VERSION_PATCH 9
    set_instance_parameter_value $name BUILD 501
    set_instance_parameter_value $name VERSION_DATE 20260501
    set_instance_parameter_value $name VERSION_GIT 76878657
}

load_system $pipe_qsys

foreach mts_instance {mts_preprocessor_0 mts_preprocessor_1} {
    set_mts_runtime_lookback_version $mts_instance
}

foreach path {
    mts_preprocessor_0.hit_type1_out/histogram_ingress_bridge_0.pre_in
    mts_preprocessor_1.hit_type1_out/hist_pre_lower_splitter_0.in
    hit_stack_subsystem_1.hit_type3/hist_post_lower_splitter_0.in
    hist_post_lower_splitter_0.out1/hist_post_merge_0.in1
} {
    require_connection $path
}

save_system $pipe_qsys
