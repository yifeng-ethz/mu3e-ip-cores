# qsys-script recipe for scifi_datapath_system_v3.qsys.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

set hist_inst {histogram_statistics_0}
set bridge_inst {histogram_ingress_bridge_0}
set post_ts_inst {hist_post_ts_sideband_0}
set pre_trim_inst {hist_pre_ts_trim_1}
set run_control_splitter_inst {run_control_splitter}
set mts_insts {mts_preprocessor_0 mts_preprocessor_1}
set source_mux_base {0x2880}
set source_mux_span {0x40}
set frame_deassembly_csr_base {0x2A80}
set frame_deassembly_csr_span {0x10}
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

proc add_instance_if_missing {name kind} {
    if {![list_has [get_instances] $name]} {
        add_instance $name $kind
    }
}

proc remove_connection_if_present {path} {
    if {[list_has [get_connections] $path]} {
        remove_connection $path
    }
}

proc remove_instance_if_present {name} {
    if {[list_has [get_instances] $name]} {
        remove_instance $name
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

proc replace_decoded_lane_muxes_with_source_selectors {} {
    for {set idx 0} {$idx < 8} {incr idx} {
        set old_mux "decoded_lane_mux_${idx}"
        set new_mux "mutrig_lane_source_mux_${idx}"

        remove_connection_if_present "lvds_rx_controller_pro_0.decoded${idx}/${old_mux}.in0"
        remove_connection_if_present "emulator_mutrig_${idx}.tx8b1k/${old_mux}.in1"
        remove_connection_if_present "${old_mux}.out/decoded_lane_fifo_${idx}.in"
        remove_connection_if_present "lvds_rx_28nm_0.outclock/${old_mux}.clk"
        remove_connection_if_present "master_datapath.master_reset/${old_mux}.reset"
        remove_instance_if_present $old_mux

        add_instance_if_missing $new_mux {mutrig_lane_source_mux}
        set_instance_parameter_value $new_mux {SELECT_EMULATOR} {1}
        set_instance_parameter_value $new_mux {REAL_ALWAYS_VALID} {1}
        set_instance_parameter_value $new_mux {FIFO_DEPTH} {4}
        set_instance_parameter_value $new_mux {INSTANCE_ID} $idx

        add_connection_if_missing {lvds_rx_28nm_0.outclock} "${new_mux}.clk"
        add_connection_if_missing {master_datapath.master_reset} "${new_mux}.rst"
        add_connection_if_missing "lvds_rx_controller_pro_0.decoded${idx}" "${new_mux}.real_in"
        add_connection_if_missing "emulator_mutrig_${idx}.tx8b1k" "${new_mux}.emu_in"
        add_connection_if_missing "${new_mux}.selected_out" "decoded_lane_fifo_${idx}.in"

        foreach master {mm_clock_crossing_bridge.m0 master_datapath.master} {
            add_connection_if_missing $master "${new_mux}.csr"
            set_connection_base_if_present "${master}/${new_mux}.csr" [expr {$::source_mux_base + ($::source_mux_span * $idx)}]
        }
    }
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

add_instance_if_missing $post_ts_inst {histogram_post_ts_sideband}
add_instance_if_missing $pre_trim_inst {histogram_pre_ts_trim}

set_instance_parameter_value $post_ts_inst {VERSION_MAJOR} {26}
set_instance_parameter_value $post_ts_inst {VERSION_MINOR} {0}
set_instance_parameter_value $post_ts_inst {VERSION_PATCH} {0}
set_instance_parameter_value $post_ts_inst {BUILD} {514}
set_instance_parameter_value $post_ts_inst {VERSION_DATE} {20260514}

set_instance_parameter_value $pre_trim_inst {VERSION_MAJOR} {26}
set_instance_parameter_value $pre_trim_inst {VERSION_MINOR} {0}
set_instance_parameter_value $pre_trim_inst {VERSION_PATCH} {0}
set_instance_parameter_value $pre_trim_inst {BUILD} {514}
set_instance_parameter_value $pre_trim_inst {VERSION_DATE} {20260514}

remove_connection_if_present {hist_post_cdc_0.out/histogram_ingress_bridge_0.post_in}
add_connection_if_missing {lvds_rx_28nm_0.outclock} "${post_ts_inst}.clock"
add_connection_if_missing {master_datapath.master_reset} "${post_ts_inst}.reset"
add_connection_if_missing {hist_post_cdc_0.out} "${post_ts_inst}.in"
add_connection_if_missing "${post_ts_inst}.out" "${bridge_inst}.post_in"

remove_connection_if_present {mts_preprocessor_1.hit_type1_out/hit_stack_subsystem_1.hit_type_1}
add_connection_if_missing {lvds_rx_28nm_0.outclock} "${pre_trim_inst}.clock"
add_connection_if_missing {master_datapath.master_reset} "${pre_trim_inst}.reset"
add_connection_if_missing {mts_preprocessor_1.hit_type1_out} "${pre_trim_inst}.in"
add_connection_if_missing "${pre_trim_inst}.out" {hit_stack_subsystem_1.hit_type_1}

set_instance_parameter_value $hist_inst {ENABLE_PACKET} {false}
set_instance_parameter_value $hist_inst {ENABLE_PINGPONG} {true}
set_instance_parameter_value $hist_inst {SNOOP_EN} {false}

# The ingress bridge now drives {ts[47:0], payload[38:0]} into the
# histogram. Positive stream-delay mode (CONTROL.mode=1) subtracts the
# selected 48-bit timestamp slice from the histogram IP's run-control GTS,
# then trims the result to SAR_TICK_WIDTH for the normal fill/bin path.
set_instance_parameter_value $hist_inst {AVST_DATA_WIDTH} {87}
set_instance_parameter_value $hist_inst {UPDATE_KEY_BIT_LO} {39}
set_instance_parameter_value $hist_inst {UPDATE_KEY_BIT_HI} {86}
set_instance_parameter_value $hist_inst {UPDATE_KEY_REPRESENTATION} {UNSIGNED}
set_instance_parameter_value $hist_inst {LOCK_KEY_RANGES} {true}
set_instance_parameter_value $hist_inst {SAR_KEY_WIDTH} {32}
set_instance_parameter_value $hist_inst {SAR_TICK_WIDTH} {32}

set_instance_parameter_value $hist_inst {VERSION_MAJOR} {26}
set_instance_parameter_value $hist_inst {VERSION_MINOR} {2}
set_instance_parameter_value $hist_inst {VERSION_PATCH} {3}
set_instance_parameter_value $hist_inst {BUILD} {514}
set_instance_parameter_value $hist_inst {VERSION_DATE} {20260514}

set_instance_parameter_value $bridge_inst {VERSION_MAJOR} {26}
set_instance_parameter_value $bridge_inst {VERSION_MINOR} {0}
set_instance_parameter_value $bridge_inst {VERSION_PATCH} {9}
set_instance_parameter_value $bridge_inst {BUILD} {515}
set_instance_parameter_value $bridge_inst {VERSION_DATE} {20260515}
set_instance_parameter_value $bridge_inst {ENABLE_POST_FORWARD} {0}
set_instance_parameter_value $bridge_inst {FILTER_POST_HIT_WORDS} {1}

foreach mts_inst $mts_insts {
    if {[list_has [get_instances] $mts_inst]} {
        set_instance_parameter_value $mts_inst {VERSION_MAJOR} {26}
        set_instance_parameter_value $mts_inst {VERSION_MINOR} {3}
        set_instance_parameter_value $mts_inst {VERSION_PATCH} {2}
        set_instance_parameter_value $mts_inst {BUILD} {515}
        set_instance_parameter_value $mts_inst {VERSION_DATE} {20260515}
    }
}

# The current emulator_mutrig CSR span is 0x100 bytes. Older V3 Qsys XML
# placed the eight emulator CSR windows every 0x40 bytes, which lets Qsys
# validate older catalogs but fails with the current component metadata.
widen_emulator_csr_apertures
refresh_emulator_csr_address_map
replace_decoded_lane_muxes_with_source_selectors
restore_decoded_lane_to_frame_receiver_paths
expose_frame_deassembly_csrs

if {[list_has [get_instances] $run_control_splitter_inst]} {
    set_instance_parameter_value $run_control_splitter_inst {USE_READY} {0}
}

save_system
