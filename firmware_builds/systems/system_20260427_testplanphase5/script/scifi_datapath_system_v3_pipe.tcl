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
set base_qsys [file join $syn_dir scifi_datapath_system_v3.qsys]
if {![file exists $base_qsys]} {
    error "Base Qsys file not found: $base_qsys"
}
load_system $base_qsys

proc require_instance_interface {instance interface} {
    if {[lsearch -exact [get_instance_interfaces $instance] $interface] < 0} {
        error "Required Qsys interface missing: ${instance}.${interface}"
    }
}

foreach {instance interface} {
    mutrig_datapath_subsystem_0 decoded_din
    mutrig_datapath_subsystem_0 headerinfo
    hit_stack_subsystem_0 hit_type_1
    hit_stack_subsystem_0 hit_type3
    hit_stack_subsystem_0 ring_buffer_cam_0_filllevel
    hit_stack_subsystem_1 hit_type_1
    hit_stack_subsystem_1 hit_type3
} {
    require_instance_interface $instance $interface
}

# The FEB top-level run-control fanout is a broadcast path. It must not
# depend on every downstream branch asserting ready, otherwise one blocked
# datapath consumer can stall the run-control command globally.
set_instance_parameter_value run_control_splitter USE_READY 0

# In the pipe topology histogram_statistics_0 is the visible rate/delay
# measurement point. Default it to the pre-RBCAM MTS stream so the toolkit rate
# preset sees hit_type1 data[38:30] = {ASIC,channel}. Post-hit-stack traffic can
# still be selected explicitly through the ingress bridge CSR for local debug.
set_instance_parameter_value histogram_ingress_bridge_0 DEFAULT_SELECT_POST 0
set_instance_parameter_value histogram_ingress_bridge_0 ENABLE_POST_FORWARD 0
set_instance_parameter_value histogram_ingress_bridge_0 FILTER_POST_HIT_WORDS 1
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_MAJOR 26
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_MINOR 0
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_PATCH 2
set_instance_parameter_value histogram_ingress_bridge_0 BUILD 425
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_DATE 20260425
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_GIT 481097348
set_instance_parameter_value histogram_statistics_0 UPDATE_KEY_BIT_HI 21
set_instance_parameter_value histogram_statistics_0 UPDATE_KEY_BIT_LO 17
set_instance_parameter_value histogram_statistics_0 N_PORTS 2
set_instance_parameter_value histogram_statistics_0 CHANNELS_PER_PORT 0
set_instance_parameter_value histogram_statistics_0 COAL_QUEUE_DEPTH 256
set_instance_parameter_value histogram_statistics_0 VERSION_MAJOR 26
set_instance_parameter_value histogram_statistics_0 VERSION_MINOR 1
set_instance_parameter_value histogram_statistics_0 VERSION_PATCH 7
set_instance_parameter_value histogram_statistics_0 BUILD 501
set_instance_parameter_value histogram_statistics_0 VERSION_DATE 20260501
set_instance_parameter_value histogram_statistics_0 VERSION_GIT 375124078
# Keep the per-port FIFO at the signed-off Phase-5 depth. The histogram arbiter
# drains a single active FIFO at one hit per clock; extra depth should cover
# burst skew, not compensate for a throughput bubble.
set_instance_parameter_value histogram_statistics_0 FIFO_ADDR_WIDTH 8

# The emulator source was fixed to remove the obsolete pre-CRC delay byte.
# Keep the pipe integration metadata explicit so Qsys does not preserve stale
# 26.1.9 instance parameters from the base system.
proc set_emulator_mutrig_crcfix_version {name} {
    set_instance_parameter_value $name VERSION_MAJOR 26
    set_instance_parameter_value $name VERSION_MINOR 1
    set_instance_parameter_value $name VERSION_PATCH 10
    set_instance_parameter_value $name BUILD 425
    set_instance_parameter_value $name VERSION_DATE 20260425
    set_instance_parameter_value $name VERSION_GIT 179563176
}

proc set_mts_runtime_lookback_version {name} {
    set_instance_parameter_value $name MUTRIG_BUFFER_EXPECTED_LATENCY_8N 2000
    set_instance_parameter_value $name MUTRIG_OVERFLOW_LOOKBACK_8N 2000
    set_instance_parameter_value $name VERSION_MAJOR 26
    set_instance_parameter_value $name VERSION_MINOR 0
    set_instance_parameter_value $name VERSION_PATCH 9
    set_instance_parameter_value $name BUILD 501
    set_instance_parameter_value $name VERSION_DATE 20260501
    set_instance_parameter_value $name VERSION_GIT 76878657
}

foreach mts_instance {mts_preprocessor_0 mts_preprocessor_1} {
    set_mts_runtime_lookback_version $mts_instance
}

# Keep the clock-crossing bridge address width derived from the live map.
set_instance_parameter_value mm_clock_crossing_bridge USE_AUTO_ADDRESS_WIDTH 1

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc rebuild_mutrig_injector_multiheader {} {
    set old_injector mutrig_injector_0
    set new_injector mutrig_injector_0_replacement

    if {[has_instance $new_injector]} {
        remove_instance $new_injector
    }

    # Qsys hides mutrig_datapath_system_v3.headerinfo once the old injector is
    # removed. Build and connect the replacement first, then remove the old
    # instance and rename the replacement back to the stable instance name.
    add_instance $new_injector mutrig_injector_multiheader 26.0.3.429
    set_instance_parameter_value $new_injector HEADERINFO_CHANNEL_W 4
    set_instance_parameter_value $new_injector VERSION_MAJOR 26
    set_instance_parameter_value $new_injector VERSION_MINOR 0
    set_instance_parameter_value $new_injector VERSION_PATCH 3
    set_instance_parameter_value $new_injector BUILD 429
    set_instance_parameter_value $new_injector VERSION_DATE 20260429
    set_instance_parameter_value $new_injector VERSION_GIT 1385024213

    add_connection lvds_rx_28nm_0.outclock/${new_injector}.clock_interface
    add_connection master_datapath.master_reset/${new_injector}.reset_interface
    catch {remove_interface osc_clock_50_in}
    add_interface osc_clock_50_in clock sink
    set_interface_property osc_clock_50_in EXPORT_OF ${new_injector}.osc_clock_interface

    for {set idx 0} {$idx < 8} {incr idx} {
        add_connection mutrig_datapath_subsystem_${idx}.headerinfo/${new_injector}.headerinfo${idx}
    }
    add_connection run_control_splitter.out13/${new_injector}.runctl
    add_connection ${new_injector}.inject/emulator_inject_fanout.inject_in

    add_connection mm_clock_crossing_bridge.m0/${new_injector}.csr
    set_connection_parameter_value mm_clock_crossing_bridge.m0/${new_injector}.csr baseAddress 0xb200
    set_connection_parameter_value mm_clock_crossing_bridge.m0/${new_injector}.csr arbitrationPriority 1
    set_connection_parameter_value mm_clock_crossing_bridge.m0/${new_injector}.csr defaultConnection 0

    add_connection master_datapath.master/${new_injector}.csr
    set_connection_parameter_value master_datapath.master/${new_injector}.csr baseAddress 0x00022000
    set_connection_parameter_value master_datapath.master/${new_injector}.csr arbitrationPriority 1
    set_connection_parameter_value master_datapath.master/${new_injector}.csr defaultConnection 0

    if {[has_instance $old_injector]} {
        remove_instance $old_injector
    }
    set_instance_property $new_injector NAME $old_injector
    set_interface_property osc_clock_50_in EXPORT_OF ${old_injector}.osc_clock_interface
}

rebuild_mutrig_injector_multiheader

proc remove_connection_if_present {path} {
    if {[lsearch -exact [get_connections] $path] >= 0} {
        remove_connection $path
    }
}

proc require_connection {path} {
    if {[lsearch -exact [get_connections] $path] < 0} {
        error "Required Qsys connection missing: $path"
    }
}

if {[has_instance histogram_ingress_bridge_1]} {
    remove_instance histogram_ingress_bridge_1
}
add_instance histogram_ingress_bridge_1 histogram_ingress_bridge 26.0.2.425
set_instance_parameter_value histogram_ingress_bridge_1 DEFAULT_SELECT_POST 0
set_instance_parameter_value histogram_ingress_bridge_1 ENABLE_POST_FORWARD 0
set_instance_parameter_value histogram_ingress_bridge_1 FILTER_POST_HIT_WORDS 1
set_instance_parameter_value histogram_ingress_bridge_1 INSTANCE_ID 1
set_instance_parameter_value histogram_ingress_bridge_1 VERSION_MAJOR 26
set_instance_parameter_value histogram_ingress_bridge_1 VERSION_MINOR 0
set_instance_parameter_value histogram_ingress_bridge_1 VERSION_PATCH 2
set_instance_parameter_value histogram_ingress_bridge_1 BUILD 425
set_instance_parameter_value histogram_ingress_bridge_1 VERSION_DATE 20260425
set_instance_parameter_value histogram_ingress_bridge_1 VERSION_GIT 481097348

proc replace_decoded_lane_mux_with_source_mux {lane} {
    set old_mux decoded_lane_mux_$lane
    set new_mux mutrig_lane_source_mux_$lane
    set fifo decoded_lane_fifo_$lane
    set emu emulator_mutrig_$lane
    set lane_dp mutrig_datapath_subsystem_${lane}

    if {[has_instance $new_mux]} {
        remove_instance $new_mux
    }

    add_instance $new_mux mutrig_lane_source_mux 26.1.0.0427
    # Phase 5 is the real-MuTRiG board bring-up build. Keep the emulator
    # connected for simulation/debug, but reset to the live LVDS/deassembly
    # path. Software can select real/emulator per lane through this CSR.
    set_instance_parameter_value $new_mux SELECT_EMULATOR 0
    set_instance_parameter_value $new_mux INSTANCE_ID $lane

    if {[has_instance $emu]} {
        set_emulator_mutrig_crcfix_version $emu
        set_instance_parameter_value $emu ASIC_ID_DEFAULT $lane
        set_instance_parameter_value $emu CLUSTER_LANE_INDEX_DEFAULT $lane
        set_instance_parameter_value $emu CLUSTER_LANE_COUNT_DEFAULT 8
    }

    add_connection lvds_rx_28nm_0.outclock/$new_mux.clk
    add_connection master_datapath.master_reset/$new_mux.rst
    add_connection lvds_rx_controller_pro_0.decoded${lane}/$new_mux.real_in
    add_connection $emu.tx8b1k/$new_mux.emu_in
    add_connection $new_mux.selected_out/$lane_dp.decoded_din

    remove_connection_if_present lvds_rx_controller_pro_0.decoded${lane}/$old_mux.in0
    remove_connection_if_present $emu.tx8b1k/$old_mux.in1
    remove_connection_if_present $old_mux.out/$fifo.in
    remove_connection_if_present $fifo.out/$lane_dp.decoded_din
    remove_connection_if_present lvds_rx_28nm_0.outclock/$fifo.clk
    remove_connection_if_present master_datapath.master_reset/$fifo.clk_reset
    remove_connection_if_present lvds_rx_28nm_0.outclock/$old_mux.clk
    remove_connection_if_present master_datapath.master_reset/$old_mux.reset

    if {[has_instance $old_mux]} {
        remove_instance $old_mux
    }
    if {[has_instance $fifo]} {
        remove_instance $fifo
    }

    set mux_csr_base [expr {0x2240 + (0x40 * $lane)}]
    add_connection mm_clock_crossing_bridge.m0/$new_mux.csr
    set_connection_parameter_value mm_clock_crossing_bridge.m0/$new_mux.csr baseAddress [format "0x%04x" $mux_csr_base]
    set_connection_parameter_value mm_clock_crossing_bridge.m0/$new_mux.csr arbitrationPriority 1
    set_connection_parameter_value mm_clock_crossing_bridge.m0/$new_mux.csr defaultConnection false

    add_connection master_datapath.master/$new_mux.csr
    set_connection_parameter_value master_datapath.master/$new_mux.csr baseAddress [format "0x%04x" $mux_csr_base]
    set_connection_parameter_value master_datapath.master/$new_mux.csr arbitrationPriority 1
    set_connection_parameter_value master_datapath.master/$new_mux.csr defaultConnection false
}

for {set lane 0} {$lane < 8} {incr lane} {
    replace_decoded_lane_mux_with_source_mux $lane
}

# Phase-5 delay histograms must observe both hit-stack halves. Rewire the
# optional histogram debug inputs so mode -7 samples the signed timestamp-delta
# streams from both MTS preprocessors. Keep the ring-CAM fill-level streams on
# debug_3..6; the older MTS debug_burst stream is sacrificed in this build
# because the histogram IP exposes six debug sinks total.
foreach path {
    mts_preprocessor_0.debug_burst/histogram_statistics_0.debug_6
    mts_preprocessor_0.ts_delta/histogram_statistics_0.debug_1
    hit_stack_subsystem_0.ring_buffer_cam_0_filllevel/histogram_statistics_0.debug_2
    hit_stack_subsystem_0.ring_buffer_cam_1_filllevel/histogram_statistics_0.debug_3
    hit_stack_subsystem_0.ring_buffer_cam_2_filllevel/histogram_statistics_0.debug_4
    hit_stack_subsystem_0.ring_buffer_cam_3_filllevel/histogram_statistics_0.debug_5
} {
    remove_connection_if_present $path
}
add_connection mts_preprocessor_0.ts_delta/histogram_statistics_0.debug_1
add_connection mts_preprocessor_1.ts_delta/histogram_statistics_0.debug_2
add_connection hit_stack_subsystem_0.ring_buffer_cam_0_filllevel/histogram_statistics_0.debug_3
add_connection hit_stack_subsystem_0.ring_buffer_cam_1_filllevel/histogram_statistics_0.debug_4
add_connection hit_stack_subsystem_0.ring_buffer_cam_2_filllevel/histogram_statistics_0.debug_5
add_connection hit_stack_subsystem_0.ring_buffer_cam_3_filllevel/histogram_statistics_0.debug_6

# The Phase-5 histogram tap is a collective observation point. The base
# topology only forwarded the upper hit stack into histogram_statistics_0,
# which made lanes 4..7 visible at MTS/frame counters but invisible at the
# histogram. Preserve the two top-level upload exports, but merge the upper and
# lower post-hit-stack packet streams into the histogram post input.
proc configure_hit_type3_splitter {name} {
    add_instance $name altera_avalon_st_splitter 18.1
    set_instance_parameter_value $name BITS_PER_SYMBOL 36
    set_instance_parameter_value $name CHANNEL_WIDTH 1
    set_instance_parameter_value $name DATA_WIDTH 36
    set_instance_parameter_value $name ERROR_DESCRIPTOR ""
    set_instance_parameter_value $name ERROR_WIDTH 1
    set_instance_parameter_value $name MAX_CHANNELS 1
    set_instance_parameter_value $name NUMBER_OF_OUTPUTS 2
    set_instance_parameter_value $name QUALIFY_VALID_OUT 0
    set_instance_parameter_value $name READY_LATENCY 0
    set_instance_parameter_value $name USE_CHANNEL 0
    set_instance_parameter_value $name USE_DATA 1
    set_instance_parameter_value $name USE_ERROR 0
    set_instance_parameter_value $name USE_PACKETS 1
    set_instance_parameter_value $name USE_READY 1
    set_instance_parameter_value $name USE_VALID 1

    add_connection xcvr156_clock.clk/$name.clk
    add_connection xcvr156_clock.clk_reset/$name.reset
}

proc configure_hit_type1_splitter {name} {
    add_instance $name altera_avalon_st_splitter 18.1
    set_instance_parameter_value $name BITS_PER_SYMBOL 39
    set_instance_parameter_value $name CHANNEL_WIDTH 4
    set_instance_parameter_value $name DATA_WIDTH 39
    set_instance_parameter_value $name ERROR_DESCRIPTOR "tserr"
    set_instance_parameter_value $name ERROR_WIDTH 1
    # Qsys interprets MAX_CHANNELS as the largest encoded channel number.
    # The MTS hit_type1 sideband is 4 bits, so the legal range is 0..15.
    set_instance_parameter_value $name MAX_CHANNELS 15
    set_instance_parameter_value $name NUMBER_OF_OUTPUTS 2
    set_instance_parameter_value $name QUALIFY_VALID_OUT 0
    set_instance_parameter_value $name READY_LATENCY 0
    set_instance_parameter_value $name USE_CHANNEL 1
    set_instance_parameter_value $name USE_DATA 1
    set_instance_parameter_value $name USE_ERROR 1
    set_instance_parameter_value $name USE_PACKETS 1
    set_instance_parameter_value $name USE_READY 1
    set_instance_parameter_value $name USE_VALID 1

    add_connection lvds_rx_28nm_0.outclock/$name.clk
    add_connection master_datapath.master_reset/$name.reset
}

proc configure_hit_type1_null_sink {name} {
    add_instance $name altera_avalon_st_null_sink 18.1
    set_instance_parameter_value $name inBitsPerSymbol 39
    set_instance_parameter_value $name inSymbolsPerBeat 1
    set_instance_parameter_value $name inUsePackets true
    set_instance_parameter_value $name inReadyLatency 0

    add_connection lvds_rx_28nm_0.outclock/$name.clk
    add_connection master_datapath.master_reset/$name.reset
}

remove_connection_if_present hist_post_splitter_0.out1/hist_post_cdc_0.in

configure_hit_type3_splitter hist_post_lower_splitter_0
add_instance hist_post_merge_0 hit_type3_stream_merge 26.0.0.0429

add_connection xcvr156_clock.clk/hist_post_merge_0.clk
add_connection xcvr156_clock.clk_reset/hist_post_merge_0.reset
add_connection hit_stack_subsystem_1.hit_type3/hist_post_lower_splitter_0.in
add_connection hist_post_splitter_0.out1/hist_post_merge_0.in0
add_connection hist_post_lower_splitter_0.out1/hist_post_merge_0.in1
add_connection hist_post_merge_0.out/hist_post_cdc_0.in

catch {remove_interface hit_type3_lower}
add_interface hit_type3_lower avalon_streaming start
set_interface_property hit_type3_lower EXPORT_OF hist_post_lower_splitter_0.out0

# Make the lower MTS stream first-class histogram evidence. The base topology
# only routed mts_preprocessor_0 through histogram_ingress_bridge_0; the lower
# half went directly into hit_stack_subsystem_1 and was therefore invisible to
# the 256-bin rate plot. Insert the lower splitter while the original hit-stack
# endpoint is still visible; this legacy hit_stack_system composition drops its
# hit_type_1 boundary from the Qsys scripting API as soon as the original
# connection is removed. CHANNELS_PER_PORT=0 above is intentional because
# hit_type1 already carries a global ASIC ID.
if {[has_instance hist_pre_lower_splitter_0]} {
    remove_instance hist_pre_lower_splitter_0
}
if {[has_instance hist_pre_lower_drain_0]} {
    remove_instance hist_pre_lower_drain_0
}
configure_hit_type1_splitter hist_pre_lower_splitter_0
configure_hit_type1_null_sink hist_pre_lower_drain_0
add_connection lvds_rx_28nm_0.outclock/histogram_ingress_bridge_1.clock
add_connection master_datapath.master_reset/histogram_ingress_bridge_1.reset
add_connection hist_pre_lower_splitter_0.out0/hit_stack_subsystem_1.hit_type_1
add_connection mts_preprocessor_1.hit_type1_out/hist_pre_lower_splitter_0.in
add_connection hist_pre_lower_splitter_0.out1/histogram_ingress_bridge_1.pre_in
add_connection histogram_ingress_bridge_1.pre_out/hist_pre_lower_drain_0.in
add_connection histogram_ingress_bridge_1.hist_out/histogram_statistics_0.fill_in_1

add_connection mm_clock_crossing_bridge.m0/histogram_ingress_bridge_1.csr
set_connection_parameter_value mm_clock_crossing_bridge.m0/histogram_ingress_bridge_1.csr baseAddress 0xac10
set_connection_parameter_value mm_clock_crossing_bridge.m0/histogram_ingress_bridge_1.csr arbitrationPriority 1
set_connection_parameter_value mm_clock_crossing_bridge.m0/histogram_ingress_bridge_1.csr defaultConnection false

add_connection master_datapath.master/histogram_ingress_bridge_1.csr
set_connection_parameter_value master_datapath.master/histogram_ingress_bridge_1.csr baseAddress 0x00020c10
set_connection_parameter_value master_datapath.master/histogram_ingress_bridge_1.csr arbitrationPriority 1
set_connection_parameter_value master_datapath.master/histogram_ingress_bridge_1.csr defaultConnection false

# Split the LVDS-side CSR fanout into smaller Avalon-MM bridge islands.
# This keeps the external SC map unchanged while reducing the generated
# router/waitrequest feedback cone in the LVDS PLL serial-clock domain.
proc add_lvds_csr_bridge {name address_width} {
    add_instance $name altera_avalon_mm_bridge 18.1
    set_instance_parameter_value $name ADDRESS_UNITS WORDS
    set_instance_parameter_value $name ADDRESS_WIDTH $address_width
    set_instance_parameter_value $name DATA_WIDTH 32
    set_instance_parameter_value $name LINEWRAPBURSTS 0
    set_instance_parameter_value $name MAX_BURST_SIZE 1
    set_instance_parameter_value $name MAX_PENDING_RESPONSES 4
    set_instance_parameter_value $name PIPELINE_COMMAND 1
    set_instance_parameter_value $name PIPELINE_RESPONSE 0
    set_instance_parameter_value $name SYMBOL_WIDTH 8
    set_instance_parameter_value $name USE_AUTO_ADDRESS_WIDTH 1
    set_instance_parameter_value $name USE_RESPONSE 0

    add_connection lvds_rx_28nm_0.outclock/$name.clk
    add_connection monitor_clock_125.clk_reset/$name.reset
    add_connection master_datapath.master_reset/$name.reset
}

set lvds_csr_groups [list \
    low \
    emu_dbg \
    mutrig3 \
    mutrig4_mts0 \
    mutrig5 \
    mutrig6 \
    mutrig7 \
    mts1 \
    hist \
    hitstack_ring \
    hitstack_frame \
]

array set lvds_csr_group_base {
    low            0x0000
    emu_dbg        0x2000
    mutrig3        0x3000
    mutrig4_mts0   0x4000
    mutrig5        0x5000
    mutrig6        0x6000
    mutrig7        0x7000
    mts1           0x8000
    hist           0xa000
    hitstack_ring  0xb000
    hitstack_frame 0xd000
}

array set lvds_csr_group_width {
    low            13
    emu_dbg        12
    mutrig3        12
    mutrig4_mts0   12
    mutrig5        12
    mutrig6        12
    mutrig7        12
    mts1           12
    hist           12
    hitstack_ring  12
    hitstack_frame 12
}

proc lvds_csr_group_for_base {base_addr} {
    if {$base_addr < 0x2000} {
        return low
    } elseif {$base_addr < 0x3000} {
        return emu_dbg
    } elseif {$base_addr < 0x4000} {
        return mutrig3
    } elseif {$base_addr < 0x5000} {
        return mutrig4_mts0
    } elseif {$base_addr < 0x6000} {
        return mutrig5
    } elseif {$base_addr < 0x7000} {
        return mutrig6
    } elseif {$base_addr < 0x8000} {
        return mutrig7
    } elseif {$base_addr < 0x9000} {
        return mts1
    } elseif {$base_addr >= 0xa000 && $base_addr < 0xb000} {
        return hist
    } elseif {$base_addr >= 0xb000 && $base_addr < 0xc000} {
        return hitstack_ring
    } elseif {$base_addr >= 0xd000 && $base_addr < 0xe000} {
        return hitstack_frame
    }

    error [format "No LVDS CSR bridge group covers baseAddress 0x%04x" $base_addr]
}

foreach group $lvds_csr_groups {
    add_lvds_csr_bridge \
        mm_pipeline_lvds_csr_$group \
        $lvds_csr_group_width($group)
}

proc remember_lvds_csr_upstream_base {master_start group upstream_base} {
    global lvds_csr_master_upstream_base

    set key ${master_start}|${group}
    if {[info exists lvds_csr_master_upstream_base($key)] &&
        $lvds_csr_master_upstream_base($key) != $upstream_base} {
        error [format \
            "Inconsistent upstream base for %s/%s: 0x%04x vs 0x%04x" \
            $master_start \
            $group \
            $lvds_csr_master_upstream_base($key) \
            $upstream_base]
    }

    set lvds_csr_master_upstream_base($key) $upstream_base
}

proc reroute_clock_crossed_lvds_csr_master {} {
    global lvds_csr_endpoint_group
    global lvds_csr_endpoint_local_base
    global lvds_csr_group_base

    set master_start mm_clock_crossing_bridge.m0
    set reroute_connections [list]
    foreach connection [get_connections] {
        if {[string equal [get_connection_property $connection START] $master_start]} {
            lappend reroute_connections $connection
        }
    }

    foreach connection $reroute_connections {
        set end_point [get_connection_property $connection END]
        set base_addr [expr {[get_connection_parameter_value $connection baseAddress]}]
        set arb_prio [get_connection_parameter_value $connection arbitrationPriority]
        set default_conn [get_connection_parameter_value $connection defaultConnection]
        set group [lvds_csr_group_for_base $base_addr]
        set bridge_name mm_pipeline_lvds_csr_$group
        set local_base_addr [expr {$base_addr - $lvds_csr_group_base($group)}]

        remove_connection $connection
        add_connection $bridge_name.m0/$end_point
        set_connection_parameter_value $bridge_name.m0/$end_point baseAddress [format "0x%04x" $local_base_addr]
        set_connection_parameter_value $bridge_name.m0/$end_point arbitrationPriority $arb_prio
        set_connection_parameter_value $bridge_name.m0/$end_point defaultConnection $default_conn

        set lvds_csr_endpoint_group($end_point) $group
        set lvds_csr_endpoint_local_base($end_point) $local_base_addr
        remember_lvds_csr_upstream_base $master_start $group $lvds_csr_group_base($group)
    }
}

proc reroute_local_lvds_csr_master {} {
    global lvds_csr_endpoint_group
    global lvds_csr_endpoint_local_base

    set master_start master_datapath.master
    set candidate_connections [list]
    foreach connection [get_connections] {
        if {![string equal [get_connection_property $connection START] $master_start]} {
            continue
        }

        set end_point [get_connection_property $connection END]
        if {![info exists lvds_csr_endpoint_group($end_point)]} {
            continue
        }

        # These legacy CSR windows have a different local-master address map
        # than the System Console map. Leave them direct unless they are split
        # into finer bridge islands in a later timing-cleanup pass.
        if {[string match "mm_pipeline_*.s0" $end_point] ||
            [regexp {^mutrig_datapath_subsystem_[0-7]\.csr$} $end_point] ||
            [regexp {^hit_stack_subsystem_[01]\.ring_buffer_cam_[0-3]_csr$} $end_point] ||
            [string equal $end_point "mutrig_injector_0.csr"]} {
            continue
        }

        lappend candidate_connections $connection
    }

    foreach connection $candidate_connections {
        set end_point [get_connection_property $connection END]
        set base_addr [expr {[get_connection_parameter_value $connection baseAddress]}]
        set group $lvds_csr_endpoint_group($end_point)
        set local_base_addr $lvds_csr_endpoint_local_base($end_point)
        set upstream_base [expr {$base_addr - $local_base_addr}]

        set key ${master_start}|${group}
        if {[info exists local_master_upstream_base($key)] &&
            $local_master_upstream_base($key) != $upstream_base} {
            set local_master_conflict($group) 1
        } else {
            set local_master_upstream_base($key) $upstream_base
        }

        lappend local_master_group_connections($group) $connection
    }

    foreach group [array names local_master_group_connections] {
        if {[info exists local_master_conflict($group)]} {
            puts [format \
                "Skipping master_datapath bridge reroute for %s; local address windows are not contiguous" \
                $group]
            continue
        }

        foreach connection $local_master_group_connections($group) {
            remove_connection $connection
        }

        set key ${master_start}|${group}
        remember_lvds_csr_upstream_base \
            $master_start \
            $group \
            $local_master_upstream_base($key)
    }
}

reroute_clock_crossed_lvds_csr_master
reroute_local_lvds_csr_master

foreach master_start [list mm_clock_crossing_bridge.m0 master_datapath.master] {
    foreach group $lvds_csr_groups {
        set key ${master_start}|${group}
        if {![info exists lvds_csr_master_upstream_base($key)]} {
            continue
        }

        set bridge_name mm_pipeline_lvds_csr_$group
        set upstream_path $master_start/$bridge_name.s0

        add_connection $upstream_path
        set_connection_parameter_value $upstream_path baseAddress [format "0x%04x" $lvds_csr_master_upstream_base($key)]
        set_connection_parameter_value $upstream_path arbitrationPriority 1
        set_connection_parameter_value $upstream_path defaultConnection false
    }
}

foreach path {
    mts_preprocessor_0.hit_type1_out/histogram_ingress_bridge_0.pre_in
    histogram_ingress_bridge_0.pre_out/hit_stack_subsystem_0.hit_type_1
    mts_preprocessor_1.hit_type1_out/hist_pre_lower_splitter_0.in
    hist_pre_lower_splitter_0.out0/hit_stack_subsystem_1.hit_type_1
    hist_pre_lower_splitter_0.out1/histogram_ingress_bridge_1.pre_in
    histogram_ingress_bridge_1.pre_out/hist_pre_lower_drain_0.in
    histogram_ingress_bridge_0.hist_out/histogram_statistics_0.hist_fill_in
    histogram_ingress_bridge_1.hist_out/histogram_statistics_0.fill_in_1
} {
    require_connection $path
}

save_system [file join $syn_dir scifi_datapath_system_v3_pipe.qsys]
