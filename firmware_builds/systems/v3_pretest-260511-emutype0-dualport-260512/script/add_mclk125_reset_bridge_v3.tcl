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

proc remove_connections_matching {pattern} {
    foreach path [get_connections] {
        if {[string match $pattern $path]} {
            remove_connection $path
        }
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

proc require_no_connection_start {start} {
    foreach path [get_connections] {
        if {[string match "${start}/*" $path]} {
            error "unexpected stale reset connection remains: $path"
        }
    }
}

proc connection_count_start {start} {
    set count 0
    foreach path [get_connections] {
        if {[string match "${start}/*" $path]} {
            incr count
        }
    }
    return $count
}

proc remove_stale_unconnected_bridge {name} {
    if {![list_has [get_instances] $name]} {
        return
    }
    if {[connection_count_start "${name}.m0"] != 0} {
        return
    }

    puts "INFO: removing stale unconnected Avalon-MM bridge $name"
    remove_connections_matching "*/${name}.*"
    remove_connections_matching "${name}.*/*"
    remove_instance $name
}

proc require_bridge_master_connected {bridges} {
    foreach bridge $bridges {
        require_instance $bridge
        if {[connection_count_start "${bridge}.m0"] == 0} {
            error "$bridge has no m0 target; an open Avalon-MM bridge injects X readdatavalid into generated simulation"
        }
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

proc configure_pipeline_response_registers {bridges} {
    foreach bridge $bridges {
        require_instance $bridge
        set_instance_parameter_value $bridge {PIPELINE_RESPONSE} {1}
        set actual [get_instance_parameter_value $bridge {PIPELINE_RESPONSE}]
        if {[string compare $actual {1}] != 0} {
            error "$bridge PIPELINE_RESPONSE must be 1 to keep idle readdatavalid reset-clean"
        }
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
    remove_stale_unconnected_bridge mm_pipeline_lvds_csr_hitstack_frame
    set external_control_bridges {
        mm_pipeline_jtagmaster2rstctrl
        mm_pipeline_lvds_csr_low
        mm_pipeline_lvds_csr_emu_dbg
        mm_pipeline_lvds_csr_mutrig3
        mm_pipeline_lvds_csr_mutrig4_mts0
        mm_pipeline_lvds_csr_mutrig5
        mm_pipeline_lvds_csr_mutrig6
        mm_pipeline_lvds_csr_mutrig7
        mm_pipeline_lvds_csr_mts1
        mm_pipeline_lvds_csr_hist
        mm_pipeline_lvds_csr_hitstack_ring
    }
    require_bridge_master_connected $external_control_bridges
    configure_pipeline_response_registers {
        mm_pipeline_jtagmaster2rstctrl
        mm_pipeline_lvds_csr_low
        mm_pipeline_lvds_csr_emu_dbg
        mm_pipeline_lvds_csr_mutrig3
        mm_pipeline_lvds_csr_mutrig4_mts0
        mm_pipeline_lvds_csr_mutrig5
        mm_pipeline_lvds_csr_mutrig6
        mm_pipeline_lvds_csr_mutrig7
        mm_pipeline_lvds_csr_mts1
        mm_pipeline_lvds_csr_hist
        mm_pipeline_lvds_csr_hitstack_ring
    }

    add_connection_if_missing monitor_clock_125.clk monitor_reset_sync.clk
    add_connection_if_missing monitor_clock_125.clk_reset monitor_reset_sync.reset_in0

    foreach endpoint {
        master_datapath.clk_reset
        lvds_rx_controller_pro_0.control_reset
        lvds_rx_controller_pro_0.data_reset
        mutrig_reset_controller_0.dpa_reset
        mm_clock_crossing_bridge.m0_reset
        mm_pipeline_jtagmaster2rstctrl.reset
        decoded_lane_fifo_0.clk_reset
        decoded_lane_fifo_1.clk_reset
        decoded_lane_fifo_2.clk_reset
        decoded_lane_fifo_3.clk_reset
        decoded_lane_fifo_4.clk_reset
        decoded_lane_fifo_5.clk_reset
        decoded_lane_fifo_6.clk_reset
        decoded_lane_fifo_7.clk_reset
        decoded_lane_mux_0.reset
        decoded_lane_mux_1.reset
        decoded_lane_mux_2.reset
        decoded_lane_mux_3.reset
        decoded_lane_mux_4.reset
        decoded_lane_mux_5.reset
        decoded_lane_mux_6.reset
        decoded_lane_mux_7.reset
        emulator_mutrig_qsys_inst.data_reset
        emulator_ctrl_splitter.reset
        emulator_inject_fanout.reset
        emulator_hit_type0_fanout.rst
        hit_stack_subsystem_0.datapath_reset
        hit_stack_subsystem_1.datapath_reset
        hist_post_cdc_0.out_clk_reset
        histogram_statistics_0.reset
        arb_hit_type0_supercore_0.rst
        run_control_splitter.reset
        run_control_mux.reset
        mutrig_datapath_subsystem_0.reset
        mutrig_datapath_subsystem_1.reset
        mutrig_datapath_subsystem_2.reset
        mutrig_datapath_subsystem_3.reset
        mutrig_datapath_subsystem_4.reset
        mutrig_datapath_subsystem_5.reset
        mutrig_datapath_subsystem_6.reset
        mutrig_datapath_subsystem_7.reset
        mm_pipeline_lvds_csr_low.reset
        mm_pipeline_lvds_csr_emu_dbg.reset
        mm_pipeline_lvds_csr_mutrig3.reset
        mm_pipeline_lvds_csr_mutrig4_mts0.reset
        mm_pipeline_lvds_csr_mutrig5.reset
        mm_pipeline_lvds_csr_mutrig6.reset
        mm_pipeline_lvds_csr_mutrig7.reset
        mm_pipeline_lvds_csr_mts1.reset
        mm_pipeline_lvds_csr_hist.reset
        mm_pipeline_lvds_csr_hitstack_ring.reset
        dbg_mm2runctrl_0.reset_interface
        mutrig_injector_0.reset_interface
        mts_preprocessor_0.reset_interface
        mts_preprocessor_1.reset_interface
        mux_mutrig2processor.rst
        mux_mutrig2processor_0.rst
        hist_type0_lane0_tap.rst
        hist_type0_lane1_tap.rst
        hist_type0_lane2_tap.rst
        hist_type0_lane3_tap.rst
        hist_type0_lane4_tap.rst
        hist_type0_lane5_tap.rst
        hist_type0_lane6_tap.rst
        hist_type0_lane7_tap.rst
        hist_type1_up_tap.rst
        hist_type1_down_tap.rst
    } {
        remove_connection_if_present master_datapath.master_reset $endpoint
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
    require_no_connection_start master_datapath.master_reset

    remove_dangling_connections
    save_system
} else {
    error "unable to infer Qsys role for $::qsys_target"
}
