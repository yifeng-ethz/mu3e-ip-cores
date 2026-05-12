# qsys-script recipe for the FEB v3 mclk125 board-reset synchronizer.
#
# Keep the topology edit in Tcl so Platform Designer owns the Qsys state.
package require -exact qsys 18.1

proc list_has {items needle} {
    return [expr {[lsearch -exact $items $needle] >= 0}]
}

proc add_instance_if_missing {name kind version} {
    if {![list_has [get_instances] $name]} {
        add_instance $name $kind $version
    }
}

proc remove_instance_if_present {name} {
    if {[list_has [get_instances] $name]} {
        remove_instance $name
    }
}

proc add_connection_if_missing {start end} {
    set path "${start}/${end}"
    if {![list_has [get_connections] $path]} {
        add_connection $start $end
    }
}

proc remove_connection_if_present {start end} {
    set path "${start}/${end}"
    if {[list_has [get_connections] $path]} {
        remove_connection $path
    }
}

proc require_instance {name} {
    if {![list_has [get_instances] $name]} {
        error "required instance $name is missing"
    }
}

proc require_connection {start end} {
    set path "${start}/${end}"
    if {![list_has [get_connections] $path]} {
        error "required connection $path is missing after update"
    }
}

proc configure_reset_bridge {name} {
    add_instance_if_missing $name altera_reset_bridge 18.1
    set_instance_parameter_value $name {ACTIVE_LOW_RESET} {0}
    set_instance_parameter_value $name {NUM_RESET_OUTPUTS} {1}
    set_instance_parameter_value $name {SYNCHRONOUS_EDGES} {deassert}
    set_instance_parameter_value $name {USE_RESET_REQUEST} {0}
}

proc configure_reset_controller {name sync_depth} {
    add_instance_if_missing $name altera_reset_controller 18.1
    set_instance_parameter_value $name {NUM_RESET_INPUTS} {1}
    set_instance_parameter_value $name {OUTPUT_RESET_SYNC_EDGES} {deassert}
    set_instance_parameter_value $name {RESET_REQUEST_PRESENT} {0}
    set_instance_parameter_value $name {RESET_REQ_EARLY_DSRT_TIME} {1}
    set_instance_parameter_value $name {RESET_REQ_WAIT_TIME} {1}
    set_instance_parameter_value $name {MIN_RST_ASSERTION_TIME} {3}
    set_instance_parameter_value $name {SYNC_DEPTH} $sync_depth
    for {set idx 0} {$idx < 16} {incr idx} {
        set_instance_parameter_value $name "USE_RESET_REQUEST_IN${idx}" {0}
    }
}

if {![info exists ::qsys_target]} {
    error "qsys_target is not set"
}

set instances [get_instances]

if {[list_has $instances {data_path_subsystem}]} {
    foreach inst {
        data_path_subsystem
        mclk125_souce
        upload_subsystem
    } {
        require_instance $inst
    }

    configure_reset_bridge mclk125_reset_bridge
    configure_reset_controller mclk125_reset_sync 2

    add_connection_if_missing mclk125_souce.clk mclk125_reset_bridge.clk
    add_connection_if_missing mclk125_souce.clk_reset mclk125_reset_bridge.in_reset
    add_connection_if_missing mclk125_souce.clk mclk125_reset_sync.clk
    add_connection_if_missing mclk125_souce.clk_reset mclk125_reset_sync.reset_in0

    remove_connection_if_present mclk125_reset_bridge.out_reset data_path_subsystem.monitor_reset_in_reset
    add_connection_if_missing mclk125_souce.clk_reset data_path_subsystem.monitor_reset_in_reset

    remove_connection_if_present mclk125_souce.clk_reset upload_subsystem.upload_sc_clock_reset
    remove_connection_if_present mclk125_reset_bridge.out_reset upload_subsystem.upload_sc_clock_reset
    add_connection_if_missing mclk125_reset_sync.reset_out upload_subsystem.upload_sc_clock_reset

    require_connection mclk125_souce.clk mclk125_reset_bridge.clk
    require_connection mclk125_souce.clk_reset mclk125_reset_bridge.in_reset
    require_connection mclk125_souce.clk mclk125_reset_sync.clk
    require_connection mclk125_souce.clk_reset mclk125_reset_sync.reset_in0
    require_connection mclk125_souce.clk_reset data_path_subsystem.monitor_reset_in_reset
    require_connection mclk125_reset_sync.reset_out upload_subsystem.upload_sc_clock_reset

    remove_dangling_connections
    save_system
} elseif {[list_has $instances {monitor_clock_125}]} {
    foreach inst {
        monitor_clock_125
        master_datapath
        lvds_rx_controller_pro_0
        mutrig_reset_controller_0
        mm_clock_crossing_bridge
        mm_pipeline_jtagmaster2rstctrl
    } {
        require_instance $inst
    }

    configure_reset_controller monitor_reset_sync 2

    add_connection_if_missing monitor_clock_125.clk monitor_reset_sync.clk
    add_connection_if_missing monitor_clock_125.clk_reset monitor_reset_sync.reset_in0

    foreach endpoint {
        master_datapath.clk_reset
        lvds_rx_controller_pro_0.control_reset
        lvds_rx_controller_pro_0.data_reset
        mutrig_reset_controller_0.dpa_reset
        mm_clock_crossing_bridge.m0_reset
        mm_pipeline_jtagmaster2rstctrl.reset
    } {
        remove_connection_if_present monitor_clock_125.clk_reset $endpoint
        remove_connection_if_present monitor_reset_bridge.out_reset $endpoint
        add_connection_if_missing monitor_reset_sync.reset_out $endpoint
        require_connection monitor_reset_sync.reset_out $endpoint
    }

    remove_connection_if_present monitor_clock_125.clk monitor_reset_bridge.clk
    remove_connection_if_present monitor_clock_125.clk_reset monitor_reset_bridge.in_reset
    remove_instance_if_present monitor_reset_bridge

    require_connection monitor_clock_125.clk monitor_reset_sync.clk
    require_connection monitor_clock_125.clk_reset monitor_reset_sync.reset_in0

    remove_dangling_connections
    save_system
} else {
    error "unable to infer Qsys role for $::qsys_target"
}
