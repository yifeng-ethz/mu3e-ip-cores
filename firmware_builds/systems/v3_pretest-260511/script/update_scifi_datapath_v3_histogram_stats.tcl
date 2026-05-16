# qsys-script recipe for scifi_datapath_system_v3.qsys.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

set hist_inst {histogram_statistics_0}
set inactive_hist_fill_source_inst {hist_inactive_fill_source}
set retired_histogram_path_insts {
    histogram_ingress_bridge_0
    hist_post_ts_sideband_0
    hist_pre_ts_trim_1
    hist_post_cdc_0
    hist_post_splitter_0
}
set run_control_mux_inst {run_control_mux}
set run_control_channel_dropper_inst {run_control_channel_dropper}
set run_control_splitter_inst {run_control_splitter}
set type0_ctrl_splitter_inst {run_control_type0_arb_splitter}
set mts_insts {mts_preprocessor_0 mts_preprocessor_1}
set type0_arb_base {0x3000}
set type0_arb_span {0x80}
set frame_deassembly_csr_base {0x2A80}
set frame_deassembly_csr_span {0x10}
set arb_hit_type0_version {26.6.3.0518}
set arb_hit_type0_version_major {26}
set arb_hit_type0_version_minor {6}
set arb_hit_type0_version_patch {3}
set arb_hit_type0_build {518}
set arb_hit_type0_version_date {20260516}
set arb_hit_type0_version_git {0x00000000}
set hit_type0_readyless_mux4_version {26.1.0.0516}
set hist_version_git {968989915}
set mts_version_git {933047952}
set emulator_version_git {1131313671}
array set mutrig_datapath_runctrl_out {
    0 2
    1 3
    2 4
    3 5
    4 8
    5 9
    6 10
    7 11
}

proc list_has {items needle} {
    return [expr {[lsearch -exact $items $needle] >= 0}]
}

proc add_instance_if_missing {name kind {version ""}} {
    if {![list_has [get_instances] $name]} {
        if {[string equal $version ""]} {
            add_instance $name $kind
        } else {
            add_instance $name $kind $version
        }
    }
}

proc remove_connection_if_present {path} {
    if {[list_has [get_connections] $path]} {
        if {[catch {remove_connection $path} err]} {
            puts "INFO: skipped stale connection ${path}: ${err}"
        }
    }
}

proc remove_instance_if_present {name} {
    if {[list_has [get_instances] $name]} {
        remove_instance $name
    }
}

proc remove_interface_if_present {name} {
    if {[catch {remove_interface $name} err]} {
        if {[list_has [get_interfaces] $name]} {
            error $err
        }
    }
}

proc remove_connections_containing {needle} {
    set matches {}
    foreach path [get_connections] {
        if {[string first $needle $path] >= 0} {
            lappend matches $path
        }
    }

    foreach path $matches {
        if {[catch {remove_connection $path} err]} {
            puts "INFO: skipped stale connection ${path}: ${err}"
        }
    }
}

proc add_connection_if_missing {start_if end_if} {
    set path "$start_if/$end_if"
    if {![list_has [get_connections] $path]} {
        add_connection $start_if $end_if
    }
}

proc set_connection_base_if_present {path base} {
    if {[list_has [get_connections] $path]} {
        set_connection_parameter_value $path baseAddress [format "0x%04x" $base]
        set_connection_parameter_value $path arbitrationPriority 1
        set_connection_parameter_value $path defaultConnection false
    }
}

proc set_instance_parameter_if_present {inst param value} {
    if {![list_has [get_instances] $inst]} {
        return
    }

    if {[list_has [get_instance_parameters $inst] $param]} {
        set_instance_parameter_value $inst $param $value
    }
}

proc tune_sc_hub_clock_crossing_bridge {} {
    # This bridge is the real SC-hub control-plane ingress into the datapath.
    # The SC hub issues one command stream and still needs 256-word bursts for
    # histogram-bin dumps, so keep burst capability but avoid oversized command
    # buffering and let the downstream bank bridges own the heavy address decode.
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {ADDRESS_UNITS} {WORDS}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {ADDRESS_WIDTH} {14}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {COMMAND_FIFO_DEPTH} {2}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {DATA_WIDTH} {32}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {MASTER_SYNC_DEPTH} {2}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {MAX_BURST_SIZE} {256}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {RESPONSE_FIFO_DEPTH} {512}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {SLAVE_SYNC_DEPTH} {2}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {SYMBOL_WIDTH} {8}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {SYSINFO_ADDR_WIDTH} {16}
    set_instance_parameter_if_present {mm_clock_crossing_bridge} {USE_AUTO_ADDRESS_WIDTH} {0}
}

proc configure_remote_csr_pipeline_bridge {inst addr_width sysinfo_width} {
    add_instance_if_missing $inst {altera_avalon_mm_bridge} {18.1}
    set_instance_parameter_if_present $inst {ADDRESS_UNITS} {WORDS}
    set_instance_parameter_if_present $inst {ADDRESS_WIDTH} $addr_width
    set_instance_parameter_if_present $inst {DATA_WIDTH} {32}
    set_instance_parameter_if_present $inst {LINEWRAPBURSTS} {0}
    set_instance_parameter_if_present $inst {MAX_BURST_SIZE} {1}
    set_instance_parameter_if_present $inst {MAX_PENDING_RESPONSES} {1}
    set_instance_parameter_if_present $inst {PIPELINE_COMMAND} {1}
    set_instance_parameter_if_present $inst {PIPELINE_RESPONSE} {0}
    set_instance_parameter_if_present $inst {SYMBOL_WIDTH} {8}
    set_instance_parameter_if_present $inst {SYSINFO_ADDR_WIDTH} $sysinfo_width
    set_instance_parameter_if_present $inst {USE_AUTO_ADDRESS_WIDTH} {1}
    set_instance_parameter_if_present $inst {USE_RESPONSE} {0}

    remove_connection_if_present "monitor_reset_sync.reset_out/${inst}.reset"
    add_connection_if_missing {lvds_rx_28nm_0.outclock} "${inst}.clk"
    add_connection_if_missing {master_datapath.master_reset} "${inst}.reset"
}

proc connect_remote_csr_endpoint {pipe endpoint local_base {remove_jtag 1}} {
    remove_connection_if_present "mm_clock_crossing_bridge.m0/${endpoint}"
    if {$remove_jtag} {
        remove_connection_if_present "master_datapath.master/${endpoint}"
    }
    add_connection_if_missing "${pipe}.m0" $endpoint
    set_connection_base_if_present "${pipe}.m0/${endpoint}" $local_base
}

proc connect_remote_csr_bank {pipe bank_base addr_width sysinfo_width endpoints} {
    configure_remote_csr_pipeline_bridge $pipe $addr_width $sysinfo_width
    add_connection_if_missing {mm_clock_crossing_bridge.m0} "${pipe}.s0"
    set_connection_base_if_present "mm_clock_crossing_bridge.m0/${pipe}.s0" $bank_base

    foreach endpoint $endpoints {
        set slave [lindex $endpoint 0]
        set local_base [lindex $endpoint 1]
        set remove_jtag 1
        if {[llength $endpoint] >= 3} {
            set remove_jtag [lindex $endpoint 2]
        }
        connect_remote_csr_endpoint $pipe $slave $local_base $remove_jtag
    }
}

proc insert_remote_sc_csr_pipeline_banks {} {
    tune_sc_hub_clock_crossing_bridge

    connect_remote_csr_bank {mm_pipeline_lvds_csr_low} 0x0000 13 13 [list \
        [list {lvds_rx_controller_pro_0.csr} 0x0000] \
        [list {mm_pipeline_jtagmaster2rstctrl.s0} 0x0200 0] \
        [list {mutrig_datapath_subsystem_0.backpressure_fifo_csr} 0x0860] \
        [list {mutrig_datapath_subsystem_1.backpressure_fifo_csr} 0x1860] \
    ]

    set emu_dbg_endpoints [list]
    for {set idx 0} {$idx < 8} {incr idx} {
        lappend emu_dbg_endpoints [list "emulator_mutrig_${idx}.csr" [expr {0x0100 * $idx}]]
    }
    lappend emu_dbg_endpoints [list {dbg_mm2runctrl_0.csr} 0x0800]
    lappend emu_dbg_endpoints [list {mutrig_datapath_subsystem_2.backpressure_fifo_csr} 0x0860]
    for {set idx 0} {$idx < 8} {incr idx} {
        lappend emu_dbg_endpoints [list "mutrig_datapath_subsystem_${idx}.csr" [expr {0x0A80 + (0x0010 * $idx)}]]
    }
    connect_remote_csr_bank {mm_pipeline_lvds_csr_emu_dbg} 0x2000 12 12 $emu_dbg_endpoints

    set type0_endpoints [list]
    for {set idx 0} {$idx < 8} {incr idx} {
        lappend type0_endpoints [list "arb_hit_type0_${idx}.csr" [expr {0x0080 * $idx}]]
    }
    lappend type0_endpoints [list {mutrig_datapath_subsystem_3.backpressure_fifo_csr} 0x0860]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_mutrig3} 0x3000 12 12 $type0_endpoints

    connect_remote_csr_bank {mm_pipeline_lvds_csr_mutrig4_mts0} 0x4000 12 12 [list \
        [list {mts_preprocessor_0.csr} 0x0000] \
        [list {mutrig_datapath_subsystem_4.backpressure_fifo_csr} 0x0860] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_mutrig5} 0x5000 12 12 [list \
        [list {mutrig_datapath_subsystem_5.backpressure_fifo_csr} 0x0860] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_mutrig6} 0x6000 12 12 [list \
        [list {mutrig_datapath_subsystem_6.backpressure_fifo_csr} 0x0860] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_mutrig7} 0x7000 12 12 [list \
        [list {mutrig_datapath_subsystem_7.backpressure_fifo_csr} 0x0860] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_mts1} 0x8000 12 5 [list \
        [list {mts_preprocessor_1.csr} 0x0000] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_hist} 0xA000 12 11 [list \
        [list {histogram_statistics_0.hist_bin} 0x0000] \
        [list {histogram_statistics_0.csr} 0x0400] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_hitstack_ring} 0xB000 12 11 [list \
        [list {hit_stack_subsystem_0.ring_buffer_cam_0_csr} 0x0000] \
        [list {hit_stack_subsystem_0.ring_buffer_cam_1_csr} 0x0080] \
        [list {hit_stack_subsystem_0.ring_buffer_cam_2_csr} 0x0100] \
        [list {hit_stack_subsystem_0.ring_buffer_cam_3_csr} 0x0180] \
        [list {mutrig_injector_0.csr} 0x0200] \
        [list {hit_stack_subsystem_1.ring_buffer_cam_0_csr} 0x0400] \
        [list {hit_stack_subsystem_1.ring_buffer_cam_1_csr} 0x0480] \
        [list {hit_stack_subsystem_1.ring_buffer_cam_2_csr} 0x0500] \
        [list {hit_stack_subsystem_1.ring_buffer_cam_3_csr} 0x0580] \
    ]
    connect_remote_csr_bank {mm_pipeline_lvds_csr_hitstack_frame} 0xD000 12 7 [list \
        [list {hit_stack_subsystem_0.feb_frame_assembly_csr} 0x0000] \
        [list {hit_stack_subsystem_1.feb_frame_assembly_csr} 0x0040] \
    ]
}

proc set_histogram_ip_identity {} {
    set_instance_parameter_value $::hist_inst {VERSION_MAJOR} {26}
    set_instance_parameter_value $::hist_inst {VERSION_MINOR} {3}
    set_instance_parameter_value $::hist_inst {VERSION_PATCH} {0}
    set_instance_parameter_value $::hist_inst {BUILD} {515}
    set_instance_parameter_value $::hist_inst {VERSION_DATE} {20260515}
    set_instance_parameter_if_present $::hist_inst {VERSION_GIT} $::hist_version_git
}

proc remove_retired_histogram_path {} {
    remove_interface_if_present {hit_type3_upper}

    foreach inst $::retired_histogram_path_insts {
        remove_connections_containing "${inst}."
    }

    remove_connection_if_present {hist_post_cdc_0.out/histogram_statistics_0.hist_fill_in}
    remove_connection_if_present {mts_preprocessor_0.hit_type1_out/histogram_statistics_0.hist_fill_in}
    remove_connection_if_present {mts_preprocessor_1.hit_type1_out/histogram_statistics_0.hist_fill_in}

    foreach inst $::retired_histogram_path_insts {
        remove_instance_if_present $inst
    }

    add_interface hit_type3_upper avalon_streaming source
    set_interface_property hit_type3_upper EXPORT_OF hit_stack_subsystem_0.hit_type3
}

proc tie_off_unused_hist_fill_in {} {
    add_instance_if_missing $::inactive_hist_fill_source_inst {avst_inactive_source} {26.0.0.0516}
    set_instance_parameter_value $::inactive_hist_fill_source_inst {DATA_WIDTH} {39}
    set_instance_parameter_value $::inactive_hist_fill_source_inst {CHANNEL_WIDTH} {4}

    add_connection_if_missing {lvds_rx_28nm_0.outclock} "$::inactive_hist_fill_source_inst.clk"
    add_connection_if_missing {master_datapath.master_reset} "$::inactive_hist_fill_source_inst.rst"
    add_connection_if_missing "$::inactive_hist_fill_source_inst.out" "$::hist_inst.hist_fill_in"
}

proc set_mts_ip_identity {} {
    foreach mts_inst $::mts_insts {
        if {[list_has [get_instances] $mts_inst]} {
            set_instance_parameter_value $mts_inst {VERSION_MAJOR} {26}
            set_instance_parameter_value $mts_inst {VERSION_MINOR} {3}
            set_instance_parameter_value $mts_inst {VERSION_PATCH} {4}
            set_instance_parameter_value $mts_inst {BUILD} {515}
            set_instance_parameter_value $mts_inst {VERSION_DATE} {20260515}
            set_instance_parameter_if_present $mts_inst {VERSION_GIT} $::mts_version_git
        }
    }
}

proc set_emulator_ip_identity {} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set inst "emulator_mutrig_${idx}"
        if {[list_has [get_instances] $inst]} {
            set_instance_parameter_value $inst {VERSION_MAJOR} {26}
            set_instance_parameter_value $inst {VERSION_MINOR} {3}
            set_instance_parameter_value $inst {VERSION_PATCH} {3}
            set_instance_parameter_value $inst {BUILD} {515}
            set_instance_parameter_value $inst {VERSION_DATE} {20260515}
            set_instance_parameter_if_present $inst {VERSION_GIT} $::emulator_version_git
            set_instance_parameter_if_present $inst {BYTE_STREAM_ENABLE} {false}
            set_instance_parameter_if_present $inst {DEBUG_LEVEL} {0}
        }
    }
}

proc set_type0_arb_ip_identity {inst idx} {
    set_instance_parameter_if_present $inst {VERSION_MAJOR} $::arb_hit_type0_version_major
    set_instance_parameter_if_present $inst {VERSION_MINOR} $::arb_hit_type0_version_minor
    set_instance_parameter_if_present $inst {VERSION_PATCH} $::arb_hit_type0_version_patch
    set_instance_parameter_if_present $inst {BUILD} $::arb_hit_type0_build
    set_instance_parameter_if_present $inst {VERSION_DATE} $::arb_hit_type0_version_date
    set_instance_parameter_if_present $inst {VERSION_GIT} $::arb_hit_type0_version_git
    set_instance_parameter_if_present $inst {IP_UID} {0x41485430}
    set_instance_parameter_if_present $inst {INSTANCE_ID} $idx
}

proc refresh_emulator_csr_address_map {} {
    foreach master {mm_clock_crossing_bridge.m0 master_datapath.master} {
        for {set idx 0} {$idx < 8} {incr idx} {
            set base [expr {0x2000 + (0x100 * $idx)}]
            set_connection_base_if_present "${master}/emulator_mutrig_${idx}.csr" $base
        }
        set_connection_base_if_present "${master}/dbg_mm2runctrl_0.csr" 0x2800
    }
}

proc widen_emulator_csr_apertures {} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set inst "emulator_mutrig_${idx}"
        if {[list_has [get_instances] $inst]} {
            set_instance_parameter_value $inst {CSR_ADDR_WIDTH} {6}
        }
    }
}

proc restore_lvds_decoded_lane_paths {} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set old_mux "decoded_lane_mux_${idx}"
        set retired_mux "mutrig_lane_source_mux_${idx}"

        remove_connection_if_present "lvds_rx_controller_pro_0.decoded${idx}/${old_mux}.in0"
        remove_connection_if_present "emulator_mutrig_${idx}.tx8b1k/${old_mux}.in1"
        remove_connection_if_present "${old_mux}.out/decoded_lane_fifo_${idx}.in"
        remove_connection_if_present "lvds_rx_28nm_0.outclock/${old_mux}.clk"
        remove_connection_if_present "master_datapath.master_reset/${old_mux}.reset"
        remove_instance_if_present $old_mux

        remove_connections_containing "${retired_mux}."
        remove_connection_if_present "emulator_mutrig_${idx}.tx8b1k/${retired_mux}.emu_in"
        remove_connection_if_present "lvds_rx_controller_pro_0.decoded${idx}/${retired_mux}.real_in"
        remove_connection_if_present "${retired_mux}.selected_out/decoded_lane_fifo_${idx}.in"
        remove_instance_if_present $retired_mux

        add_connection_if_missing "lvds_rx_controller_pro_0.decoded${idx}" "decoded_lane_fifo_${idx}.in"
    }
}

proc set_emulators_type0_only {} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set inst "emulator_mutrig_${idx}"
        if {![list_has [get_instances] $inst]} {
            continue
        }

        remove_connections_containing "${inst}.tx8b1k"
        set_instance_parameter_if_present $inst {BYTE_STREAM_ENABLE} {false}
        set_instance_parameter_if_present $inst {CLUSTER_LANE_COUNT_DEFAULT} {8}
        set_instance_parameter_if_present $inst {CLUSTER_LANE_INDEX_DEFAULT} $idx
        set_instance_parameter_if_present $inst {ASIC_ID_DEFAULT} $idx
        set_instance_parameter_if_present $inst {INSTANCE_ID} $idx
        set_instance_parameter_if_present $inst {DEBUG_LEVEL} {0}
    }
}

proc configure_run_control_splitter_for_type0_arb {} {
    if {![list_has [get_instances] $::run_control_splitter_inst]} {
        return
    }

    set_instance_parameter_value $::run_control_splitter_inst {NUMBER_OF_OUTPUTS} {16}
    set_instance_parameter_value $::run_control_splitter_inst {USE_READY} {0}
}

proc configure_type0_ctrl_splitter {} {
    if {![list_has [get_instances] $::run_control_splitter_inst]} {
        return
    }
    if {![list_has [get_instances] {emulator_ctrl_splitter}]} {
        return
    }

    add_instance_if_missing $::type0_ctrl_splitter_inst {altera_avalon_st_splitter} {18.1}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {BITS_PER_SYMBOL} {9}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {DATA_WIDTH} {9}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {ERROR_DESCRIPTOR} {}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {ERROR_WIDTH} {1}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {MAX_CHANNELS} {1}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {NUMBER_OF_OUTPUTS} {9}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {QUALIFY_VALID_OUT} {0}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {READY_LATENCY} {0}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {USE_CHANNEL} {0}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {USE_DATA} {1}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {USE_ERROR} {0}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {USE_PACKETS} {0}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {USE_READY} {0}
    set_instance_parameter_value $::type0_ctrl_splitter_inst {USE_VALID} {1}

    add_connection_if_missing {lvds_rx_28nm_0.outclock} "$::type0_ctrl_splitter_inst.clk"
    add_connection_if_missing {master_datapath.master_reset} "$::type0_ctrl_splitter_inst.reset"

    remove_connection_if_present {run_control_splitter.out15/emulator_ctrl_splitter.in}
    add_connection_if_missing {run_control_splitter.out15} "$::type0_ctrl_splitter_inst.in"
    add_connection_if_missing "$::type0_ctrl_splitter_inst.out0" {emulator_ctrl_splitter.in}
}

proc configure_type0_arbiter_lane {idx} {
    set inst "arb_hit_type0_${idx}"
    add_instance_if_missing $inst {arb_hit_type0} $::arb_hit_type0_version
    set_type0_arb_ip_identity $inst $idx
    set_instance_parameter_if_present $inst {MODE_DEFAULT} {1}
    set_instance_parameter_if_present $inst {WATCHDOG_DEFAULT} {500}
    set_instance_parameter_if_present $inst {FIFO_DEPTH} {16}
    # Temporarily expose debug conduits so stale DEBUG=2 connections from older
    # Qsys XML can be removed cleanly before the synthesis image is forced to 0.
    set_instance_parameter_if_present $inst {DEBUG_LEVEL} {2}
    set_instance_parameter_if_present "emulator_mutrig_${idx}" {DEBUG_LEVEL} {2}
    set_instance_parameter_if_present $inst {INSTANCE_ID} $idx

    add_connection_if_missing {lvds_rx_28nm_0.outclock} "${inst}.clk"
    add_connection_if_missing {master_datapath.master_reset} "${inst}.rst"
    add_connection_if_missing "$::type0_ctrl_splitter_inst.out[expr {1 + $idx}]" "${inst}.run_ctrl"

    remove_connection_if_present "mutrig_datapath_subsystem_${idx}.hit_type0_out/mux_mutrig2processor.in${idx}"
    remove_connection_if_present "mutrig_datapath_subsystem_${idx}.hit_type0_out/mux_mutrig2processor_0.in[expr {$idx - 4}]"
    remove_connection_if_present "mutrig_datapath_subsystem_${idx}.hit_type0_out/${inst}.real_in"
    remove_connection_if_present "emulator_mutrig_${idx}.hit_type0/${inst}.emu_in"
    remove_connection_if_present "mutrig_datapath_subsystem_${idx}.debug_hit_metadata/${inst}.real_hit_debug"
    remove_connection_if_present "emulator_mutrig_${idx}.hit_debug_metadata/${inst}.emu_hit_debug"
    add_connection_if_missing "mutrig_datapath_subsystem_${idx}.hit_type0_out" "${inst}.real_in"
    add_connection_if_missing "emulator_mutrig_${idx}.hit_type0" "${inst}.emu_in"

    foreach master {mm_clock_crossing_bridge.m0 master_datapath.master} {
        add_connection_if_missing $master "${inst}.csr"
        set_connection_base_if_present "${master}/${inst}.csr" [expr {$::type0_arb_base + ($::type0_arb_span * $idx)}]
    }
}

proc configure_type0_bank_mux {inst start_idx output_path} {
    set mts_inst [expr {$start_idx == 0 ? "mts_preprocessor_0" : "mts_preprocessor_1"}]
    set_instance_parameter_if_present $mts_inst {DEBUG} {2}
    for {set lane 0} {$lane < 4} {incr lane} {
        set_instance_parameter_if_present "arb_hit_type0_[expr {$start_idx + $lane}]" {DEBUG_LEVEL} {2}
    }

    remove_connection_if_present "${inst}.out/${output_path}"
    remove_connection_if_present "lvds_rx_28nm_0.outclock/${inst}.clk"
    remove_connection_if_present "lvds_rx_28nm_0.outclock/${inst}.clock"
    remove_connection_if_present "master_datapath.master_reset/${inst}.rst"
    remove_connection_if_present "master_datapath.master_reset/${inst}.reset"

    for {set lane 0} {$lane < 4} {incr lane} {
        remove_connection_if_present "mutrig_datapath_subsystem_[expr {$start_idx + $lane}].hit_type0_out/${inst}.in${lane}"
        remove_connection_if_present "arb_hit_type0_[expr {$start_idx + $lane}].selected_out/${inst}.in${lane}"
        remove_connection_if_present "arb_hit_type0_[expr {$start_idx + $lane}].selected_hit_debug/${inst}.in${lane}_metadata"
    }
    set output_sidecar_path [string map {.hit_type0_in .hit_type0_sidecar} $output_path]
    remove_connection_if_present "${inst}.selected_metadata/${output_sidecar_path}"

    remove_instance_if_present $inst
    add_instance $inst {hit_type0_readyless_mux4} $::hit_type0_readyless_mux4_version
    set_instance_parameter_if_present $inst {FIFO_DEPTH} {16}
    set_instance_parameter_if_present $inst {DEBUG_LEVEL} {0}

    add_connection_if_missing {lvds_rx_28nm_0.outclock} "${inst}.clk"
    add_connection_if_missing {master_datapath.master_reset} "${inst}.rst"
    for {set lane 0} {$lane < 4} {incr lane} {
        set idx [expr {$start_idx + $lane}]
        add_connection_if_missing "arb_hit_type0_${idx}.selected_out" "${inst}.in${lane}"
    }
    add_connection_if_missing "${inst}.out" $output_path
}

proc configure_type0_hit_arbitration {} {
    configure_run_control_splitter_for_type0_arb
    configure_type0_ctrl_splitter

    remove_connection_if_present {mux_mutrig2processor.out/mts_preprocessor_0.hit_type0_in}
    remove_connection_if_present {mux_mutrig2processor_0.out/mts_preprocessor_1.hit_type0_in}

    set_instance_parameter_if_present {mts_preprocessor_0} {DEBUG} {2}
    set_instance_parameter_if_present {mts_preprocessor_1} {DEBUG} {2}

    for {set idx 0} {$idx < 8} {incr idx} {
        configure_type0_arbiter_lane $idx
    }

    configure_type0_bank_mux {mux_mutrig2processor} 0 {mts_preprocessor_0.hit_type0_in}
    configure_type0_bank_mux {mux_mutrig2processor_0} 4 {mts_preprocessor_1.hit_type0_in}

    for {set idx 0} {$idx < 8} {incr idx} {
        set_instance_parameter_if_present "arb_hit_type0_${idx}" {DEBUG_LEVEL} {0}
        set_instance_parameter_if_present "emulator_mutrig_${idx}" {DEBUG_LEVEL} {0}
    }
    set_instance_parameter_if_present {mts_preprocessor_0} {DEBUG} {0}
    set_instance_parameter_if_present {mts_preprocessor_1} {DEBUG} {0}
}

proc restore_decoded_lane_to_frame_receiver_paths {} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set datapath "mutrig_datapath_subsystem_${idx}"
        if {![list_has [get_instances] $datapath]} {
            continue
        }

        add_connection_if_missing "decoded_lane_fifo_${idx}.out" "${datapath}.decoded_din"

        if {[info exists ::mutrig_datapath_runctrl_out($idx)]} {
            add_connection_if_missing "run_control_splitter.out$::mutrig_datapath_runctrl_out($idx)" "${datapath}.run_ctrl"
        }
    }
}

proc expose_frame_deassembly_csrs {} {
    foreach master {mm_clock_crossing_bridge.m0 master_datapath.master} {
        for {set idx 0} {$idx < 8} {incr idx} {
            set datapath "mutrig_datapath_subsystem_${idx}"
            if {![list_has [get_instances] $datapath]} {
                continue
            }

            set endpoint "${datapath}.csr"
            add_connection_if_missing $master $endpoint
            set_connection_base_if_present "${master}/${endpoint}" [expr {$::frame_deassembly_csr_base + ($::frame_deassembly_csr_span * $idx)}]
        }
    }
}

proc insert_run_control_channel_dropper {} {
    if {![list_has [get_instances] $::run_control_mux_inst]} {
        return
    }
    if {![list_has [get_instances] $::run_control_splitter_inst]} {
        return
    }

    add_instance_if_missing $::run_control_channel_dropper_inst {avst_channel_dropper} {26.0.0.0515}
    set_instance_parameter_value $::run_control_channel_dropper_inst {DATA_WIDTH} {9}
    set_instance_parameter_value $::run_control_channel_dropper_inst {CHANNEL_WIDTH} {1}

    add_connection_if_missing {lvds_rx_28nm_0.outclock} "$::run_control_channel_dropper_inst.clk"
    add_connection_if_missing {master_datapath.master_reset} "$::run_control_channel_dropper_inst.rst"

    remove_connection_if_present "$::run_control_mux_inst.out/$::run_control_splitter_inst.in"
    add_connection_if_missing "$::run_control_mux_inst.out" "$::run_control_channel_dropper_inst.in"
    add_connection_if_missing "$::run_control_channel_dropper_inst.out" "$::run_control_splitter_inst.in"
}

remove_retired_histogram_path
set_histogram_ip_identity

set_instance_parameter_value $hist_inst {ENABLE_PACKET} {false}
set_instance_parameter_value $hist_inst {ENABLE_PINGPONG} {true}
set_instance_parameter_value $hist_inst {SNOOP_EN} {false}
set_instance_parameter_if_present $hist_inst {N_DEBUG_INTERFACE} {0}

# The histogram now owns ingress source selection. The primary hit path stays
# at the legacy 39-bit Type-1 width, while readyless extended sources carry
# {ts[47:0], payload[38:0]} for delay-mode observability.
set_instance_parameter_value $hist_inst {AVST_DATA_WIDTH} {39}
set_instance_parameter_value $hist_inst {N_PORTS} {1}
set_instance_parameter_if_present {mutrig_reset_controller_0} {DEBUG} {0}
# Rate mode uses a locked ASIC:channel key so the 256-bin histogram maps
# directly onto the FEB 8 ASIC x 32 channel namespace. Delay mode still takes
# the true timestamp from hit_type1_extended_N[86:39] inside histogram_v2.
set_instance_parameter_value $hist_inst {UPDATE_KEY_BIT_LO} {30}
set_instance_parameter_value $hist_inst {UPDATE_KEY_BIT_HI} {38}
set_instance_parameter_value $hist_inst {FILTER_KEY_BIT_LO} {35}
set_instance_parameter_value $hist_inst {FILTER_KEY_BIT_HI} {38}
set_instance_parameter_value $hist_inst {UPDATE_KEY_REPRESENTATION} {UNSIGNED}
set_instance_parameter_value $hist_inst {LOCK_KEY_RANGES} {true}
set_instance_parameter_value $hist_inst {SAR_KEY_WIDTH} {32}
set_instance_parameter_value $hist_inst {SAR_TICK_WIDTH} {32}

add_connection_if_missing {mts_preprocessor_0.hit_type1_out} {hit_stack_subsystem_0.hit_type_1}
add_connection_if_missing {mts_preprocessor_1.hit_type1_out} {hit_stack_subsystem_1.hit_type_1}
add_connection_if_missing {mts_preprocessor_0.hit_type1_extended_0} "${hist_inst}.hit_type1_extended_0"
add_connection_if_missing {mts_preprocessor_1.hit_type1_extended_1} "${hist_inst}.hit_type1_extended_1"
for {set idx 0} {$idx < 8} {incr idx} {
    add_connection_if_missing "mutrig_datapath_subsystem_${idx}.headerinfo" "mutrig_injector_0.headerinfo${idx}"
}
tie_off_unused_hist_fill_in

set_mts_ip_identity

# The current emulator_mutrig CSR span is 0x100 bytes. Older V3 Qsys XML
# placed the eight emulator CSR windows every 0x40 bytes, which lets Qsys
# validate older catalogs but fails with the current component metadata.
set_emulator_ip_identity
widen_emulator_csr_apertures
refresh_emulator_csr_address_map
set_emulators_type0_only
restore_lvds_decoded_lane_paths
restore_decoded_lane_to_frame_receiver_paths
expose_frame_deassembly_csrs
configure_type0_hit_arbitration

if {[list_has [get_instances] $run_control_splitter_inst]} {
    set_instance_parameter_value $run_control_splitter_inst {USE_READY} {0}
}

if {[list_has [get_instances] $run_control_mux_inst]} {
    # The Intel streaming multiplexer normally tags the selected input in the
    # output channel. The downstream run-control splitter has no channel port;
    # insert a channel dropper after the mux so input 1 is not suppressed by
    # Platform Designer's generated channel adapter.
    set_instance_parameter_value $run_control_mux_inst {outChannelWidth} {1}
}
insert_run_control_channel_dropper
insert_remote_sc_csr_pipeline_banks

save_system
