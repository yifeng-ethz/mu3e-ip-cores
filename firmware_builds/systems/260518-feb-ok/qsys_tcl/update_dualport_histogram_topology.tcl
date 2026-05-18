package require -exact qsys 18.1

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc has_connection {path} {
    return [expr {[lsearch -exact [get_connections] $path] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[has_connection $path]} {
        if {[catch {remove_connection $path} err]} {
            puts "INFO: stale connection ${path} could not be removed cleanly: $err"
        }
    }
}

proc remove_instance_if_present {name} {
    if {[has_instance $name]} {
        remove_instance $name
    }
}

proc add_connection_once {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

proc remove_connections_matching {pattern} {
    foreach path [get_connections] {
        if {[string match $pattern $path]} {
            if {[catch {remove_connection $path} err]} {
                puts "INFO: stale connection ${path} could not be removed cleanly: $err"
            }
        }
    }
}

proc set_optional_param {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        puts "INFO: optional parameter ${inst}.${name} not present: $err"
    }
}

proc add_mm_connection {start end base} {
    add_connection_once $start $end
    set_connection_parameter_value ${start}/${end} baseAddress [format "0x%08x" $base]
    set_connection_parameter_value ${start}/${end} arbitrationPriority 1
    set_connection_parameter_value ${start}/${end} defaultConnection false
}

proc add_instance_if_missing {name kind version} {
    if {![has_instance $name]} {
        add_instance $name $kind $version
    }
}

proc configure_histogram_v3_direct {inst} {
    set_optional_param $inst VERSION_MAJOR 26
    set_optional_param $inst VERSION_MINOR 3
    set_optional_param $inst VERSION_PATCH 4
    set_optional_param $inst BUILD 517
    set_optional_param $inst VERSION_DATE 20260517
    set_optional_param $inst VERSION_GIT 0

    set_optional_param $inst ENABLE_PACKET false
    set_optional_param $inst ENABLE_PINGPONG true
    set_optional_param $inst SNOOP_EN false
    set_optional_param $inst ENABLE_DEBUG_INPUTS false
    set_optional_param $inst N_DEBUG_INTERFACE 0

    set_optional_param $inst N_PORTS 8
    set_optional_param $inst AVST_DATA_WIDTH 45
    set_optional_param $inst TYPE0_DATA_WIDTH 45
    set_optional_param $inst TYPE1_DATA_WIDTH 39
    set_optional_param $inst AVST_CHANNEL_WIDTH 4
    set_optional_param $inst LOCK_KEY_RANGES true
    set_optional_param $inst POWER2_BIN_WIDTH_ONLY true
    set_optional_param $inst MAX_COUNT_BITS 20
    set_optional_param $inst FIFO_ADDR_WIDTH 2
    set_optional_param $inst COAL_QUEUE_DEPTH 4
    set_optional_param $inst KICK_COUNT_WIDTH 4
    set_optional_param $inst SAR_TICK_WIDTH 21
}

proc configure_readyless_mts {inst} {
    set_optional_param $inst VERSION_MAJOR 26
    set_optional_param $inst VERSION_MINOR 3
    set_optional_param $inst VERSION_PATCH 3
    set_optional_param $inst BUILD 517
    set_optional_param $inst VERSION_DATE 20260517
}

proc configure_running_gated_injector {inst} {
    set_optional_param $inst VERSION_MAJOR 26
    set_optional_param $inst VERSION_MINOR 1
    set_optional_param $inst VERSION_PATCH 1
    set_optional_param $inst BUILD 517
    set_optional_param $inst VERSION_DATE 20260517
    set_optional_param $inst VERSION_GIT 0
}

proc configure_emulator_header_sync_timestamps {inst} {
    set_optional_param $inst VERSION_MAJOR 26
    set_optional_param $inst VERSION_MINOR 3
    set_optional_param $inst VERSION_PATCH 3
    set_optional_param $inst BUILD 517
    set_optional_param $inst VERSION_DATE 20260517
}

proc configure_emulator_type0_fanout {} {
    remove_connection_if_present emulator_mutrig_qsys_inst.hit_type0/emulator_hit_type0_fanout.in
    remove_connection_if_present lvds_rx_28nm_0.outclock/emulator_hit_type0_fanout.clk
    remove_connection_if_present monitor_reset_sync.reset_out/emulator_hit_type0_fanout.rst
    for {set lane 0} {$lane < 8} {incr lane} {
        remove_connection_if_present emulator_hit_type0_fanout.out${lane}/arb_hit_type0_supercore_0.emu_in_${lane}
    }

    remove_instance_if_present emulator_hit_type0_fanout
    add_instance emulator_hit_type0_fanout hit_type0_fanout8 26.0.1.0517

    add_connection_once lvds_rx_28nm_0.outclock emulator_hit_type0_fanout.clk
    add_connection_once monitor_reset_sync.reset_out emulator_hit_type0_fanout.rst
    add_connection_once emulator_mutrig_qsys_inst.hit_type0 emulator_hit_type0_fanout.in
    for {set lane 0} {$lane < 8} {incr lane} {
        add_connection_once emulator_hit_type0_fanout.out${lane} arb_hit_type0_supercore_0.emu_in_${lane}
    }
}

proc configure_readyless_hit_mux {inst} {
    if {[string equal $inst "mux_mutrig2processor"]} {
        set input_paths {
            arb_hit_type0_supercore_0.selected_out_0
            arb_hit_type0_supercore_0.selected_out_1
            arb_hit_type0_supercore_0.selected_out_2
            arb_hit_type0_supercore_0.selected_out_3
        }
        set output_path "mts_preprocessor_0.hit_type0_in"
    } else {
        set input_paths {
            arb_hit_type0_supercore_0.selected_out_4
            arb_hit_type0_supercore_0.selected_out_5
            arb_hit_type0_supercore_0.selected_out_6
            arb_hit_type0_supercore_0.selected_out_7
        }
        set output_path "mts_preprocessor_1.hit_type0_in"
    }

    remove_connection_if_present ${inst}.out/${output_path}
    remove_connection_if_present lvds_rx_28nm_0.outclock/${inst}.clk
    remove_connection_if_present lvds_rx_28nm_0.outclock/${inst}.clock
    remove_connection_if_present master_datapath.master_reset/${inst}.reset
    remove_connection_if_present master_datapath.master_reset/${inst}.rst

    for {set lane 0} {$lane < 4} {incr lane} {
        remove_connection_if_present [lindex $input_paths $lane]/${inst}.in${lane}
    }

    remove_instance_if_present $inst
    add_instance $inst hit_type0_readyless_mux4 26.0.0.0512
    set_optional_param $inst FIFO_DEPTH 16

    add_connection_once lvds_rx_28nm_0.outclock ${inst}.clk
    add_connection_once master_datapath.master_reset ${inst}.rst
    for {set lane 0} {$lane < 4} {incr lane} {
        add_connection_once [lindex $input_paths $lane] ${inst}.in${lane}
    }
    add_connection_once ${inst}.out $output_path
}

proc configure_type0_hist_tap {lane} {
    set tap "hist_type0_lane${lane}_tap"
    set mux "mux_mutrig2processor"
    set mux_input $lane
    if {$lane >= 4} {
        set mux "mux_mutrig2processor_0"
        set mux_input [expr {$lane - 4}]
    }

    remove_connections_matching "*/${tap}.*"
    remove_connections_matching "${tap}.*/*"
    remove_instance_if_present $tap

    add_instance_if_missing $tap hit_type0_tap2 26.0.0.0517
    add_connection_once lvds_rx_28nm_0.outclock ${tap}.clk
    add_connection_once master_datapath.master_reset ${tap}.rst

    remove_connection_if_present arb_hit_type0_supercore_0.selected_out_${lane}/${mux}.in${mux_input}
    remove_connection_if_present arb_hit_type0_supercore_0.selected_out_${lane}/histogram_statistics_0.type0_lane${lane}

    add_connection_once arb_hit_type0_supercore_0.selected_out_${lane} ${tap}.in
    add_connection_once ${tap}.primary ${mux}.in${mux_input}
    add_connection_once ${tap}.hist histogram_statistics_0.type0_lane${lane}
}

proc configure_type1_hist_tap {tap src hss hist ts_src ts_hist} {
    remove_connections_matching "*/${tap}.*"
    remove_connections_matching "${tap}.*/*"
    remove_instance_if_present $tap

    add_instance_if_missing $tap avst_snoop_splitter 26.0.0.0502
    set_optional_param $tap DATA_WIDTH 39
    set_optional_param $tap CHANNEL_WIDTH 4
    set_optional_param $tap EMPTY_WIDTH 1
    set_optional_param $tap ERROR_WIDTH 1

    add_connection_once lvds_rx_28nm_0.outclock ${tap}.clk
    add_connection_once master_datapath.master_reset ${tap}.rst

    remove_connection_if_present ${src}/${hss}
    remove_connection_if_present ${src}/${hist}
    add_connection_once ${src} ${tap}.in
    add_connection_once ${tap}.out0 ${hss}
    add_connection_once ${tap}.out1 ${hist}

    add_connection_once ${ts_src} ${ts_hist}
}

proc configure_injector_headerinfo_links {} {
    for {set lane 0} {$lane < 8} {incr lane} {
        set start "mutrig_datapath_subsystem_${lane}.headerinfo"
        set end "mutrig_injector_0.headerinfo${lane}"
        add_connection_once $start $end
    }
}

proc require_connection_present {start end} {
    set path "${start}/${end}"
    if {![has_connection $path]} {
        error "required Qsys connection missing: ${path}"
    }
}

proc require_injector_headerinfo_links {} {
    for {set lane 0} {$lane < 8} {incr lane} {
        require_connection_present \
            "mutrig_datapath_subsystem_${lane}.headerinfo" \
            "mutrig_injector_0.headerinfo${lane}"
    }
}

proc require_instance_parameter_value {inst name expected} {
    set actual [get_instance_parameter_value $inst $name]
    set actual_l [string tolower $actual]
    set expected_l [string tolower $expected]
    set match 0
    if {[string compare $actual_l $expected_l] == 0} {
        set match 1
    }
    if {[string compare $expected_l "false"] == 0} {
        if {[string compare $actual_l "0"] == 0 || [string compare $actual_l "false"] == 0} {
            set match 1
        }
    }
    if {$match == 0} {
        error "required Qsys parameter drift: ${inst}.${name}=${actual}, expected ${expected}"
    }
}

proc require_emulator_byte_stream_disabled {} {
    require_instance_parameter_value emulator_mutrig_qsys_inst BYTE_STREAM_ENABLE false
}

configure_histogram_v3_direct histogram_statistics_0
configure_readyless_mts mts_preprocessor_0
configure_readyless_mts mts_preprocessor_1
configure_emulator_header_sync_timestamps emulator_mutrig_qsys_inst
configure_emulator_type0_fanout
configure_running_gated_injector mutrig_injector_0
configure_readyless_hit_mux mux_mutrig2processor
configure_readyless_hit_mux mux_mutrig2processor_0
configure_injector_headerinfo_links

remove_connections_matching */histogram_ingress_bridge_0.*
remove_connections_matching histogram_ingress_bridge_0.*/*
remove_connections_matching */histogram_ingress_bridge_1.*
remove_connections_matching histogram_ingress_bridge_1.*/*
remove_instance_if_present histogram_ingress_bridge_0
remove_instance_if_present histogram_ingress_bridge_1

remove_connections_matching */histogram_statistics_0.hist_fill_in
remove_connections_matching */histogram_statistics_0.fill_in_*
remove_connections_matching */histogram_statistics_0.debug_*

for {set lane 0} {$lane < 8} {incr lane} {
    configure_type0_hist_tap $lane
}

configure_type1_hist_tap \
    hist_type1_up_tap \
    mts_preprocessor_0.hit_type1_out \
    hit_stack_subsystem_0.hit_type_1 \
    histogram_statistics_0.type1_up \
    mts_preprocessor_0.hit_type1_ts \
    histogram_statistics_0.type1_up_ts

configure_type1_hist_tap \
    hist_type1_down_tap \
    mts_preprocessor_1.hit_type1_out \
    hit_stack_subsystem_1.hit_type_1 \
    histogram_statistics_0.type1_down \
    mts_preprocessor_1.hit_type1_ts \
    histogram_statistics_0.type1_down_ts

catch {remove_dangling_connections}
require_injector_headerinfo_links
require_emulator_byte_stream_disabled

save_system
