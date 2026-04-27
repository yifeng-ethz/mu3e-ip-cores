package require -exact qsys 18.1

set script_dir [file dirname [file normalize [info script]]]
set system_root [file normalize [file join $script_dir ..]]
set syn_dir [file join $system_root syn]
load_system [file join $syn_dir scifi_datapath_system_v3.qsys]

# The FEB top-level run-control fanout is a broadcast path. It must not
# depend on every downstream branch asserting ready, otherwise one blocked
# datapath consumer can stall the run-control command globally.
set_instance_parameter_value run_control_splitter USE_READY 0

# In the pipe topology histogram_statistics_0 is fed from the post-hit-stack
# copy. Keep the reset default aligned with that wiring so a run-control reset
# cannot silently return the histogram tap to the pre-hit-stack stream. The
# post stream is packetized hit_type3 traffic, so filter out frame protocol
# words before presenting it to histogram_statistics_0.
set_instance_parameter_value histogram_ingress_bridge_0 DEFAULT_SELECT_POST 1
set_instance_parameter_value histogram_ingress_bridge_0 FILTER_POST_HIT_WORDS 1
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_MAJOR 26
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_MINOR 0
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_PATCH 2
set_instance_parameter_value histogram_ingress_bridge_0 BUILD 425
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_DATE 20260425
set_instance_parameter_value histogram_ingress_bridge_0 VERSION_GIT 481097348
set_instance_parameter_value histogram_statistics_0 UPDATE_KEY_BIT_HI 21
set_instance_parameter_value histogram_statistics_0 UPDATE_KEY_BIT_LO 17

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

# Keep the clock-crossing bridge address width derived from the live map.
set_instance_parameter_value mm_clock_crossing_bridge USE_AUTO_ADDRESS_WIDTH 1

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc remove_connection_if_present {path} {
    catch {remove_connection $path}
}

proc replace_decoded_lane_mux_with_source_mux {lane} {
    set old_mux decoded_lane_mux_$lane
    set new_mux mutrig_lane_source_mux_$lane
    set fifo decoded_lane_fifo_$lane
    set emu emulator_mutrig_$lane
    set lane_dp mutrig_datapath_subsystem_${lane}

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
    if {[has_instance $new_mux]} {
        remove_instance $new_mux
    }

    add_instance $new_mux mutrig_lane_source_mux 1.0
    set_instance_parameter_value $new_mux SELECT_EMULATOR 1

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
}

for {set lane 0} {$lane < 8} {incr lane} {
    replace_decoded_lane_mux_with_source_mux $lane
}

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

set reroute_connections [list]
foreach connection [get_connections] {
    if {[string equal [get_connection_property $connection START] "mm_clock_crossing_bridge.m0"]} {
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
    set lvds_csr_group_used($group) 1
}

foreach group $lvds_csr_groups {
    if {![info exists lvds_csr_group_used($group)]} {
        continue
    }

    set bridge_name mm_pipeline_lvds_csr_$group
    set upstream_path mm_clock_crossing_bridge.m0/$bridge_name.s0

    add_connection $upstream_path
    set_connection_parameter_value $upstream_path baseAddress [format "0x%04x" $lvds_csr_group_base($group)]
    set_connection_parameter_value $upstream_path arbitrationPriority 1
    set_connection_parameter_value $upstream_path defaultConnection false
}

save_system [file join $syn_dir scifi_datapath_system_v3_pipe.qsys]
