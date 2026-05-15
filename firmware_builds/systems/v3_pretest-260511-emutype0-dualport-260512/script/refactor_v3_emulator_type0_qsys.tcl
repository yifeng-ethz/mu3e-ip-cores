# qsys-script recipe for the FEB v3 emulator-type0 datapath topology.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

set ::type0_emulator_inst emulator_mutrig_qsys_inst

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc remove_instance_if_present {name} {
    if {[has_instance $name]} {
        remove_instance $name
    }
}

proc has_connection {path} {
    return [expr {[lsearch -exact [get_connections] $path] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[has_connection $path]} {
        remove_connection $path
    }
}

proc add_connection_once {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

proc add_mm_connection {start end base} {
    add_connection_once $start $end
    set_connection_parameter_value ${start}/${end} baseAddress [format "0x%04x" $base]
    set_connection_parameter_value ${start}/${end} arbitrationPriority 1
    set_connection_parameter_value ${start}/${end} defaultConnection false
}

proc set_optional_param {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        puts "INFO: optional parameter ${inst}.${name} not present: $err"
    }
}

proc configure_run_control_broadcasts {} {
    # Run-control is a broadcast fabric. Keep both splitters readyless so a
    # missing or backpressured debug/emulator leaf cannot stall every sink.
    set_optional_param run_control_splitter USE_READY 0
    set_optional_param run_control_splitter READY_LATENCY 0
    set_optional_param run_control_splitter QUALIFY_VALID_OUT 0

    set_optional_param emulator_ctrl_splitter USE_READY 0
    set_optional_param emulator_ctrl_splitter READY_LATENCY 0
    set_optional_param emulator_ctrl_splitter QUALIFY_VALID_OUT 0
}

proc remove_legacy_emulator_topology {} {
    remove_instance_if_present arb_hit_type0_supercore_0
    remove_instance_if_present emulator_hit_type0_fanout

    foreach lane {0 1 2 3 4 5 6 7} {
        remove_connection_if_present emulator_mutrig_${lane}.tx8b1k/decoded_lane_mux_${lane}.in1
        remove_connection_if_present emulator_ctrl_splitter.out${lane}/emulator_mutrig_${lane}.ctrl
        remove_connection_if_present emulator_inject_fanout.out${lane}/emulator_mutrig_${lane}.inject
        remove_connection_if_present lvds_rx_28nm_0.outclock/emulator_mutrig_${lane}.data_clock
        remove_connection_if_present master_datapath.master_reset/emulator_mutrig_${lane}.data_reset
        remove_connection_if_present mm_pipeline_lvds_csr_emu_dbg.m0/emulator_mutrig_${lane}.csr
        remove_connection_if_present master_datapath.master/emulator_mutrig_${lane}.csr
        remove_instance_if_present emulator_mutrig_${lane}
    }

    remove_instance_if_present emulator_mutrig_qsys_lane
    remove_instance_if_present emulator_mutrig_qsys_inst
    remove_dangling_connections
}

proc configure_single_emulator {} {
    add_instance $::type0_emulator_inst emulator_mutrig 26.3.0.0506
    set_optional_param $::type0_emulator_inst BYTE_STREAM_ENABLE false
    set_optional_param $::type0_emulator_inst CLUSTER_LANE_COUNT_DEFAULT 8
    set_optional_param $::type0_emulator_inst CLUSTER_LANE_INDEX_DEFAULT 0
    set_optional_param $::type0_emulator_inst ASIC_ID_DEFAULT 0
    set_optional_param $::type0_emulator_inst INSTANCE_ID 0
    set_optional_param $::type0_emulator_inst FIFO_DEPTH 64
    set_optional_param $::type0_emulator_inst DEBUG_LEVEL 0
    set_optional_param $::type0_emulator_inst VERSION_MAJOR 26
    set_optional_param $::type0_emulator_inst VERSION_MINOR 3
    set_optional_param $::type0_emulator_inst VERSION_PATCH 0
    set_optional_param $::type0_emulator_inst BUILD 506
    set_optional_param $::type0_emulator_inst VERSION_DATE 20260506
    set_optional_param $::type0_emulator_inst VERSION_GIT 0

    add_connection_once lvds_rx_28nm_0.outclock ${::type0_emulator_inst}.data_clock
    add_connection_once master_datapath.master_reset ${::type0_emulator_inst}.data_reset
    add_connection_once emulator_ctrl_splitter.out0 ${::type0_emulator_inst}.ctrl
    add_connection_once emulator_inject_fanout.out0 ${::type0_emulator_inst}.inject
    add_mm_connection mm_pipeline_lvds_csr_emu_dbg.m0 ${::type0_emulator_inst}.csr 0x0000
    add_mm_connection master_datapath.master ${::type0_emulator_inst}.csr 0x00002000
}

proc configure_emulator_hit_fanout {} {
    add_instance emulator_hit_type0_fanout hit_type0_fanout8 26.0.0.0512
    add_connection_once lvds_rx_28nm_0.outclock emulator_hit_type0_fanout.clk
    add_connection_once master_datapath.master_reset emulator_hit_type0_fanout.rst
    add_connection_once ${::type0_emulator_inst}.hit_type0 emulator_hit_type0_fanout.in
}

proc configure_arb_supercore {} {
    add_instance arb_hit_type0_supercore_0 arb_hit_type0_supercore 1.0

    add_connection_once lvds_rx_28nm_0.outclock arb_hit_type0_supercore_0.clk
    add_connection_once master_datapath.master_reset arb_hit_type0_supercore_0.rst
    add_connection_once emulator_ctrl_splitter.out1 arb_hit_type0_supercore_0.run_ctrl
}

array set lane_mts_mux {
    0 mux_mutrig2processor.in0
    1 mux_mutrig2processor.in1
    2 mux_mutrig2processor.in2
    3 mux_mutrig2processor.in3
    4 mux_mutrig2processor_0.in0
    5 mux_mutrig2processor_0.in1
    6 mux_mutrig2processor_0.in2
    7 mux_mutrig2processor_0.in3
}

proc rewire_type0_lanes {} {
    for {set lane 0} {$lane < 8} {incr lane} {
        remove_connection_if_present mutrig_datapath_subsystem_${lane}.hit_type0_out/$::lane_mts_mux($lane)

        add_connection_once mutrig_datapath_subsystem_${lane}.hit_type0_out arb_hit_type0_supercore_0.real_in_${lane}
        add_connection_once emulator_hit_type0_fanout.out${lane} arb_hit_type0_supercore_0.emu_in_${lane}
        add_connection_once arb_hit_type0_supercore_0.selected_out_${lane} $::lane_mts_mux($lane)

        set arb_local_base [expr {0x0280 + (0x80 * $lane)}]
        set arb_master_base [expr {0x00002280 + (0x80 * $lane)}]
        add_mm_connection mm_pipeline_lvds_csr_emu_dbg.m0 arb_hit_type0_supercore_0.csr_${lane} $arb_local_base
        add_mm_connection master_datapath.master arb_hit_type0_supercore_0.csr_${lane} $arb_master_base
    }
}

remove_legacy_emulator_topology
configure_run_control_broadcasts
configure_single_emulator
configure_emulator_hit_fanout
configure_arb_supercore
rewire_type0_lanes

save_system
