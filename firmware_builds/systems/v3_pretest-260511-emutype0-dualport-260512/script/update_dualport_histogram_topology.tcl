package require -exact qsys 18.1

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc has_connection {path} {
    return [expr {[lsearch -exact [get_connections] $path] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[has_connection $path]} {
        remove_connection $path
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

proc configure_histogram_bridge {inst instance_id} {
    if {![has_instance $inst]} {
        add_instance $inst histogram_ingress_bridge 26.0.6.0514
    }

    set_optional_param $inst DEFAULT_SELECT_POST 0
    set_optional_param $inst ENABLE_POST_FORWARD 0
    set_optional_param $inst FILTER_POST_HIT_WORDS 1
    set_optional_param $inst INSTANCE_ID $instance_id
    set_optional_param $inst VERSION_MAJOR 26
    set_optional_param $inst VERSION_MINOR 0
    set_optional_param $inst VERSION_PATCH 6
    set_optional_param $inst BUILD 514
    set_optional_param $inst VERSION_DATE 20260514
}

proc configure_readyless_mts {inst} {
    set_optional_param $inst VERSION_MAJOR 26
    set_optional_param $inst VERSION_MINOR 3
    set_optional_param $inst VERSION_PATCH 0
    set_optional_param $inst BUILD 512
    set_optional_param $inst VERSION_DATE 20260512
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

configure_histogram_bridge histogram_ingress_bridge_0 0
configure_histogram_bridge histogram_ingress_bridge_1 1
configure_readyless_mts mts_preprocessor_0
configure_readyless_mts mts_preprocessor_1
configure_readyless_hit_mux mux_mutrig2processor
configure_readyless_hit_mux mux_mutrig2processor_0

set_instance_parameter_value histogram_statistics_0 N_PORTS 2

add_connection_once lvds_rx_28nm_0.outclock histogram_ingress_bridge_1.clock
add_connection_once master_datapath.master_reset histogram_ingress_bridge_1.reset
add_mm_connection mm_pipeline_lvds_csr_hist.m0 histogram_ingress_bridge_1.csr 0x0c10
add_mm_connection master_datapath.master histogram_ingress_bridge_1.csr 0x00020c10

remove_connection_if_present mts_preprocessor_1.hit_type1_out/hit_stack_subsystem_1.hit_type_1
add_connection_once mts_preprocessor_1.hit_type1_out histogram_ingress_bridge_1.pre_in
add_connection_once histogram_ingress_bridge_1.pre_out hit_stack_subsystem_1.hit_type_1

remove_connection_if_present histogram_ingress_bridge_1.hist_out/histogram_statistics_0.fill_in_1
add_connection_once histogram_ingress_bridge_1.hist_out histogram_statistics_0.fill_in_1

save_system
