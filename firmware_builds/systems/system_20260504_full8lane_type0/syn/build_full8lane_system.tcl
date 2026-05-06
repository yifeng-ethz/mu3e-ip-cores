package require -exact qsys 18.1

proc abs_dir {path} {
    set save_dir [pwd]
    cd $path
    set result [pwd]
    cd $save_dir
    return $result
}

if {[info exists full8lane_syn_dir] && [info exists full8lane_system_dir]} {
    set syn_dir [abs_dir $full8lane_syn_dir]
    set system_dir [abs_dir $full8lane_system_dir]
} elseif {[info exists env(FULL8LANE_SYN_DIR)] && [info exists env(FULL8LANE_SYSTEM_DIR)]} {
    set syn_dir [abs_dir $env(FULL8LANE_SYN_DIR)]
    set system_dir [abs_dir $env(FULL8LANE_SYSTEM_DIR)]
} else {
    set script_path [info script]
    if {[string length $script_path] == 0} {
        set script_path [file join [pwd] build_full8lane_system.tcl]
    }
    if {![string equal [file pathtype $script_path] absolute]} {
        set script_path [file join [pwd] $script_path]
    }
    set syn_dir [abs_dir [file dirname $script_path]]
    set system_dir [abs_dir [file join $syn_dir ..]]
}

set repo_dir [abs_dir [file join $system_dir .. .. ..]]
set ref_system_dir [file join $repo_dir firmware_builds systems system_20260427_testplanphase5]
set ref_syn_dir [file join $ref_system_dir syn]

set ref_inner_system_name scifi_datapath_system_v3_pipe
set control_system_name full8lane_control_path_subsystem
set inner_system_name full8lane_type0_datapath
set supercore_system_name arb_hit_type0_supercore
set outer_system_name full8lane_type0_system
set inner_system_version 2.0
set outer_system_version 2.0
set control_ref_qsys_path [file join $ref_syn_dir debug_sc_system_v3.qsys]
set inner_ref_qsys_path [file join $ref_syn_dir ${ref_inner_system_name}.qsys]
set outer_ref_qsys_path [file join $ref_syn_dir feb_system_v3_pipe.qsys]
set ref_upload_qsys_path [file join $ref_syn_dir upload_system_v3.qsys]
set control_qsys_path [file join $syn_dir ${control_system_name}.qsys]
set supercore_qsys_path [file join $syn_dir ${supercore_system_name}.qsys]
set inner_qsys_path [file join $syn_dir ${inner_system_name}.qsys]
set outer_qsys_path [file join $syn_dir ${outer_system_name}.qsys]
set ipx_path [file join $syn_dir mu3e_ip_cores.ipx]
set components_ipx_path [file join $syn_dir components.ipx]
set arb_script_dir [file join $repo_dir misc arb_hit_type0 script]
set debug_sidecar_fanout_script_dir [file join $repo_dir misc debug_sidecar_fanout script]
set debug_hit_sidecar_bank_bridge_script_dir [file join $repo_dir misc debug_hit_sidecar_bank_bridge script]
set emulator_ip_dir [file join $repo_dir emulator_mutrig]
set frame_deassembly_script_dir [file join $repo_dir mutrig_frame_deassembly script]
set mts_processor_ip_dir [file join $repo_dir mutrig_timestamp_processor]
set ring_buffer_cam_script_dir [file join $repo_dir ring-buffer_cam script]
set feb_frame_assembly_ip_dir [file join $repo_dir feb_frame_assembly]
set ref_hit_stack_qsys_path [file join $repo_dir run-control_mgmt reference feb_system_v2_snapshot_20260415 hit_stack_system.qsys]
set upload_readyless_ip_dir [file join $syn_dir ip upload_system_v3_readyless]
set upload_readyless_qsys_path [file join $upload_readyless_ip_dir upload_system_v3.qsys]
set hit_stack_readyless_ip_dir [file join $syn_dir ip hit_stack_system_readyless]
set hit_stack_readyless_qsys_path [file join $hit_stack_readyless_ip_dir hit_stack_system.qsys]
set full8lane_onewire_ip_dir [file join $syn_dir ip full8lane_onewire_master]
set full8lane_sc_hub_ip_dir [file join $syn_dir ip full8lane_sc_hub_v2]
set full8lane_histogram_ip_dir [file join $syn_dir ip full8lane_histogram_statistics_v2]
set histogram_compat_ip_dir [file join $syn_dir ip histogram_statistics_v2]
set search_path [join [list $syn_dir $arb_script_dir $debug_sidecar_fanout_script_dir $debug_hit_sidecar_bank_bridge_script_dir $emulator_ip_dir $frame_deassembly_script_dir $mts_processor_ip_dir $ring_buffer_cam_script_dir $feb_frame_assembly_ip_dir $upload_readyless_ip_dir $hit_stack_readyless_ip_dir $full8lane_onewire_ip_dir $full8lane_sc_hub_ip_dir $full8lane_histogram_ip_dir $histogram_compat_ip_dir $ipx_path $components_ipx_path "\$"] ","]
set lvds_controller_version 26.2.1.0506
set debug_sidecar_fanout_version 26.0.0.0506
set debug_hit_sidecar_bank_bridge_version 26.0.0.0506
set emulator_mutrig_version 26.3.0.0506
set frame_deassembly_version 26.1.0.0506
set mts_preprocessor_version 26.1.0.0506
set ring_buffer_cam_version 26.2.7.0506
set feb_frame_assembly_version 26.1.0.0506
set histogram_ingress_bridge_version 26.0.5.0506
set runctl_mgmt_host_readyless_version 26.3.0.505
set lvds_controller_local_csr_base 0x9000
set lvds_controller_master_csr_base 0x00030000
# qsys-script in some Quartus 18.1 launch environments does not preserve
# arbitrary shell environment variables. Support both shell env and an explicit
# Tcl override: qsys-script --cmd {set full8lane_debug_level 2} --script ...
if {![info exists full8lane_debug_level]} {
    set full8lane_debug_level 0
}
if {[info exists env(FULL8LANE_DEBUG_LEVEL)]} {
    set full8lane_debug_level $env(FULL8LANE_DEBUG_LEVEL)
} elseif {[info exists env(DEBUG_LEVEL)]} {
    set full8lane_debug_level $env(DEBUG_LEVEL)
}
if {![string is integer -strict $full8lane_debug_level] || $full8lane_debug_level < 0 || $full8lane_debug_level > 2} {
    error "FULL8LANE_DEBUG_LEVEL/DEBUG_LEVEL must be an integer in the range 0..2."
}
# Histogram mode -7 stages debug_1 and debug_2 through ingress FIFOs 0 and 1.
# Keep the nominal datapath at one fill stream, but enable the second staging
# FIFO in DEBUG_LEVEL=2 builds so both MTS timestamp debug streams can advance.
set histogram_data_port_count [expr {$full8lane_debug_level >= 2 ? 2 : 1}]
puts "INFO: full8lane debug level $full8lane_debug_level, histogram data ports $histogram_data_port_count"

proc chmod_generated_artifacts_writable {syn_dir system_names} {
    foreach name $system_names {
        foreach path [list \
            [file join $syn_dir ${name}.qsys] \
            [file join $syn_dir ${name}.sopcinfo] \
            [file join $syn_dir $name] \
        ] {
            if {[file exists $path]} {
                exec chmod -R u+w $path
            }
        }
    }
}

chmod_generated_artifacts_writable \
    $syn_dir \
    [list $control_system_name $supercore_system_name $inner_system_name $outer_system_name]

proc set_required_param {inst name value} {
    set_instance_parameter_value $inst $name $value
}

proc set_optional_param {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        puts "INFO: optional parameter ${inst}.${name} not present in this catalog: $err"
    }
}

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

proc add_mm_connection {start end base} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
    set_connection_parameter_value ${start}/${end} baseAddress [format "0x%04x" $base]
    set_connection_parameter_value ${start}/${end} arbitrationPriority 1
    set_connection_parameter_value ${start}/${end} defaultConnection false
}

proc add_stream_connection {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

proc add_interrupt_connection {start end irq} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
    set_connection_parameter_value ${start}/${end} irqNumber $irq
}

proc add_clock_connection {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

proc add_reset_connection {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

proc add_conduit_connection {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

proc add_lvds_outclock_if_present {end} {
    set inst [lindex [split $end .] 0]
    if {[has_instance $inst]} {
        add_clock_connection lvds_rx_controller_pro_0.outclock $end
    }
}

proc connect_lvds_outclock_domains {} {
    foreach end {
        arb_hit_type0_supercore_0.clk
        dbg_mm2runctrl_0.clock_interface
        emulator_ctrl_splitter.clk
        emulator_inject_fanout.clk
        hist_post_cdc_0.out_clk
        histogram_ingress_bridge_0.clock
        histogram_statistics_0.clock
        hit_stack_subsystem_0.datapath_clock
        hit_stack_subsystem_1.datapath_clock
        mm_clock_crossing_bridge.m0_clk
        mm_pipeline_lvds_csr_emu_dbg.clk
        mm_pipeline_lvds_csr_hist.clk
        mm_pipeline_lvds_csr_hitstack_frame.clk
        mm_pipeline_lvds_csr_hitstack_ring.clk
        mm_pipeline_lvds_csr_low.clk
        mm_pipeline_lvds_csr_mts1.clk
        mm_pipeline_lvds_csr_mutrig3.clk
        mm_pipeline_lvds_csr_mutrig4_mts0.clk
        mm_pipeline_lvds_csr_mutrig5.clk
        mm_pipeline_lvds_csr_mutrig6.clk
        mm_pipeline_lvds_csr_mutrig7.clk
        mts_preprocessor_0.clock_interface
        mts_preprocessor_1.clock_interface
        mutrig_injector_0.clock_interface
        mutrig_reset_controller_0.dpa_clock
        mux_mutrig2processor.clk
        mux_mutrig2processor_0.clk
        run_control_splitter.clk
    } {
        add_lvds_outclock_if_present $end
    }
    for {set lane 0} {$lane < 8} {incr lane} {
        add_lvds_outclock_if_present emulator_mutrig_${lane}.data_clock
        add_lvds_outclock_if_present mutrig_frame_deassembly_${lane}.clock_sink
        add_lvds_outclock_if_present backpressure_fifo_${lane}.clk
    }
}

proc ensure_export {name type dir internal} {
    if {[lsearch -exact [get_interfaces] $name] < 0} {
        add_interface $name $type $dir
    }
    set_interface_property $name EXPORT_OF $internal
}

proc force_export {name type dir internal} {
    if {[lsearch -exact [get_interfaces] $name] >= 0} {
        remove_interface $name
    }
    add_interface $name $type $dir
    set_interface_property $name EXPORT_OF $internal
}

proc patch_qsys_component_version {qsys_path version} {
    set fd [open $qsys_path r]
    set content [read $fd]
    close $fd

    set pattern {(<component[^>]*version=")[^"]+(")}
    set replacement "\\1${version}\\2"
    set count [regsub $pattern $content $replacement patched]
    if {$count == 0} {
        error "failed to patch root component version in $qsys_path"
    }

    exec chmod u+w $qsys_path
    set fd [open $qsys_path w]
    puts -nonewline $fd $patched
    close $fd
}

proc patch_qsys_module_parameter {content module_name param_name param_value} {
    set marker " <module\n   name=\"$module_name\""
    set start [string first $marker $content]
    if {$start < 0} {
        error "failed to find module $module_name"
    }

    set module_end [string first "\n <module" $content [expr {$start + 1}]]
    set connection_start [string first "\n <connection" $content [expr {$start + 1}]]
    if {$module_end < 0 || ($connection_start >= 0 && $connection_start < $module_end)} {
        set module_end $connection_start
    }
    if {$module_end < 0} {
        error "failed to find end of module $module_name"
    }

    set block [string range $content $start [expr {$module_end - 1}]]
    set pattern "(<parameter name=\"$param_name\" value=\")\[^\"]+(\" />)"
    set replacement "\\1${param_value}\\2"
    set count [regsub $pattern $block $replacement patched_block]
    if {$count != 1} {
        error "failed to patch $module_name.$param_name"
    }

    set patched [string range $content 0 [expr {$start - 1}]]
    append patched $patched_block
    append patched [string range $content $module_end end]
    return $patched
}

proc patch_qsys_module_version {content module_name module_version} {
    set marker " <module\n   name=\"$module_name\""
    set start [string first $marker $content]
    if {$start < 0} {
        error "failed to find module $module_name"
    }

    set module_end [string first "\n <module" $content [expr {$start + 1}]]
    set connection_start [string first "\n <connection" $content [expr {$start + 1}]]
    if {$module_end < 0 || ($connection_start >= 0 && $connection_start < $module_end)} {
        set module_end $connection_start
    }
    if {$module_end < 0} {
        error "failed to find end of module $module_name"
    }

    set block [string range $content $start [expr {$module_end - 1}]]
    set pattern {(<module[^>]*version=")[^"]+(")}
    set replacement "\\1${module_version}\\2"
    set count [regsub $pattern $block $replacement patched_block]
    if {$count != 1} {
        error "failed to patch $module_name.version"
    }

    set patched [string range $content 0 [expr {$start - 1}]]
    append patched $patched_block
    append patched [string range $content $module_end end]
    return $patched
}

proc ensure_qsys_interface_export_content {content name internal type dir} {
    set existing "   name=\"$name\"\n   internal=\"$internal\""
    if {[string first $existing $content] >= 0} {
        return $content
    }

    set block " <interface\n   name=\"$name\"\n   internal=\"$internal\"\n   type=\"$type\"\n   dir=\"$dir\" />\n"
    set marker "\n <module"
    set idx [string first $marker $content]
    if {$idx < 0} {
        error "failed to find first module insertion point while adding interface $name"
    }

    set patched [string range $content 0 $idx]
    append patched $block
    append patched [string range $content [expr {$idx + 1}] end]
    return $patched
}

proc ensure_qsys_connection_content {content kind start end} {
    set existing "   start=\"$start\"\n   end=\"$end\""
    if {[string first $existing $content] >= 0} {
        return $content
    }

    set block " <connection\n   kind=\"$kind\"\n   version=\"18.1\"\n   start=\"$start\"\n   end=\"$end\""
    if {[string equal $kind "conduit"]} {
        append block ">\n"
        append block "  <parameter name=\"endPort\" value=\"\" />\n"
        append block "  <parameter name=\"endPortLSB\" value=\"0\" />\n"
        append block "  <parameter name=\"startPort\" value=\"\" />\n"
        append block "  <parameter name=\"startPortLSB\" value=\"0\" />\n"
        append block "  <parameter name=\"width\" value=\"0\" />\n"
        append block " </connection>\n"
    } else {
        append block " />\n"
    }

    set marker "\n</system>"
    set idx [string last $marker $content]
    if {$idx < 0} {
        error "failed to find end-of-system insertion point while adding connection $start/$end"
    }

    set patched [string range $content 0 $idx]
    append patched $block
    append patched [string range $content [expr {$idx + 1}] end]
    return $patched
}

proc patch_qsys_instance_version {qsys_path module_name module_version} {
    set fd [open $qsys_path r]
    set content [read $fd]
    close $fd

    set content [patch_qsys_module_version $content $module_name $module_version]

    exec chmod u+w $qsys_path
    set fd [open $qsys_path w]
    puts -nonewline $fd $content
    close $fd
}

proc patch_qsys_instance_parameter {qsys_path module_name param_name param_value} {
    set fd [open $qsys_path r]
    set content [read $fd]
    close $fd

    set content [patch_qsys_module_parameter $content $module_name $param_name $param_value]

    exec chmod u+w $qsys_path
    set fd [open $qsys_path w]
    puts -nonewline $fd $content
    close $fd
}

proc ensure_qsys_connection {qsys_path kind start end} {
    set fd [open $qsys_path r]
    set content [read $fd]
    close $fd

    set content [ensure_qsys_connection_content $content $kind $start $end]

    exec chmod u+w $qsys_path
    set fd [open $qsys_path w]
    puts -nonewline $fd $content
    close $fd
}

proc materialize_readyless_upload_qsys {ref_qsys_path dst_qsys_path runctl_version} {
    set fd [open $ref_qsys_path r]
    set content [read $fd]
    close $fd

    # The reference upload subsystem pins runctl_mgmt_host to an older readyful
    # package.  Keep the subsystem topology, but force the readyless host
    # component so the exported runctl interface has no backpressure pin.
    set content [patch_qsys_module_version \
        $content \
        runctl_mgmt_host_0 \
        $runctl_version]

    file mkdir [file dirname $dst_qsys_path]
    if {[file exists $dst_qsys_path]} {
        exec chmod u+w $dst_qsys_path
    }
    set fd [open $dst_qsys_path w]
    puts -nonewline $fd $content
    close $fd
    puts "INFO: materialized readyless upload_system_v3 override at $dst_qsys_path"
}

proc materialize_readyless_hit_stack_qsys {ref_qsys_path dst_qsys_path debug_level ring_version feb_version} {
    set fd [open $ref_qsys_path r]
    set content [read $fd]
    close $fd

    # Keep the legacy hit-stack component local to the parent system, but make
    # its run-control fanout a one-way broadcast so rbCAM/FEB ready cannot
    # backpressure the run-control command source.
    set content [patch_qsys_module_parameter \
        $content \
        run_control_splitter_0 \
        USE_READY \
        0]

    set content [patch_qsys_module_version \
        $content \
        feb_frame_assembly_0 \
        $feb_version]
    set content [patch_qsys_module_parameter \
        $content \
        feb_frame_assembly_0 \
        DEBUG \
        $debug_level]

    for {set idx 0} {$idx < 4} {incr idx} {
        set inst ring_buffer_cam_$idx
        set content [patch_qsys_module_version \
            $content \
            $inst \
            $ring_version]
        set content [patch_qsys_module_parameter \
            $content \
            $inst \
            DEBUG \
            $debug_level]
    }

    if {$debug_level >= 1} {
        set content [ensure_qsys_interface_export_content \
            $content \
            frame_debug_queue_status \
            feb_frame_assembly_0.debug_queue_status \
            avalon_streaming \
            start]

        for {set idx 0} {$idx < 4} {incr idx} {
            set content [ensure_qsys_interface_export_content \
                $content \
                ring_buffer_cam_${idx}_debug_observability \
                ring_buffer_cam_${idx}.debug_observability \
                conduit \
                start]
        }
    }

    if {$debug_level >= 2} {
        set content [ensure_qsys_interface_export_content \
            $content \
            frame_debug_hit_sidecar \
            feb_frame_assembly_0.debug_hit_sidecar \
            avalon_streaming \
            start]

        for {set idx 0} {$idx < 4} {incr idx} {
            set content [ensure_qsys_interface_export_content \
                $content \
                hit_type1_${idx}_metadata \
                ring_buffer_cam_${idx}.hit_type1_metadata \
                conduit \
                end]
            set content [ensure_qsys_connection_content \
                $content \
                conduit \
                ring_buffer_cam_${idx}.hit_type2_metadata \
                feb_frame_assembly_0.hit_type2_${idx}_sidecar]
        }
    }

    file mkdir [file dirname $dst_qsys_path]
    if {[file exists $dst_qsys_path]} {
        exec chmod u+w $dst_qsys_path
    }
    set fd [open $dst_qsys_path w]
    puts -nonewline $fd $content
    close $fd
    puts "INFO: materialized readyless hit_stack_system override at $dst_qsys_path"
}

proc ensure_qsys_interface_export {qsys_path name internal type dir before_name} {
    set fd [open $qsys_path r]
    set content [read $fd]
    close $fd

    set existing "   name=\"$name\"\n   internal=\"$internal\""
    if {[string first $existing $content] >= 0} {
        return
    }

    set block " <interface\n   name=\"$name\"\n   internal=\"$internal\"\n   type=\"$type\"\n   dir=\"$dir\" />\n"
    set marker " <interface\n   name=\"$before_name\""
    set idx [string first $marker $content]
    if {$idx < 0} {
        error "failed to find insertion point $before_name in $qsys_path"
    }
    set patched [string range $content 0 [expr {$idx - 1}]]
    append patched $block
    append patched [string range $content $idx end]

    exec chmod u+w $qsys_path
    set fd [open $qsys_path w]
    puts -nonewline $fd $patched
    close $fd
}

proc configure_backpressure_fifo {name depth} {
    add_instance $name altera_avalon_sc_fifo 18.1
    set_required_param $name BITS_PER_SYMBOL 45
    set_required_param $name CHANNEL_WIDTH 4
    set_required_param $name EMPTY_LATENCY 3
    set_required_param $name ENABLE_EXPLICIT_MAXCHANNEL true
    set_required_param $name ERROR_WIDTH 3
    set_required_param $name EXPLICIT_MAXCHANNEL 15
    set_required_param $name FIFO_DEPTH $depth
    set_required_param $name SYMBOLS_PER_BEAT 1
    set_required_param $name USE_ALMOST_EMPTY_IF 1
    set_required_param $name USE_ALMOST_FULL_IF 0
    set_required_param $name USE_FILL_LEVEL 1
    set_required_param $name USE_MEMORY_BLOCKS 1
    set_required_param $name USE_PACKETS 1
    set_required_param $name USE_STORE_FORWARD 0
}

proc configure_run_ctrl_splitter {name outputs} {
    add_instance $name altera_avalon_st_splitter 18.1
    set_required_param $name BITS_PER_SYMBOL 9
    set_required_param $name CHANNEL_WIDTH 1
    set_required_param $name DATA_WIDTH 9
    set_required_param $name ERROR_DESCRIPTOR ""
    set_required_param $name ERROR_WIDTH 1
    set_required_param $name MAX_CHANNELS 1
    set_required_param $name NUMBER_OF_OUTPUTS $outputs
    set_required_param $name QUALIFY_VALID_OUT 0
    set_required_param $name READY_LATENCY 0
    set_required_param $name USE_CHANNEL 0
    set_required_param $name USE_DATA 1
    set_required_param $name USE_ERROR 0
    set_required_param $name USE_PACKETS 0
    set_required_param $name USE_READY 0
    set_required_param $name USE_VALID 1
}

proc configure_arb_child {name lane mode watchdog} {
    add_instance $name arb_hit_type0 26.4.0.0506
    set_required_param $name MODE_DEFAULT $mode
    set_required_param $name WATCHDOG_DEFAULT $watchdog
    set_required_param $name FIFO_DEPTH 16
    set_required_param $name DEBUG_LEVEL $::full8lane_debug_level
    set_required_param $name IP_UID 1095263280
    set_required_param $name INSTANCE_ID $lane
    set_required_param $name VERSION_MAJOR 26
    set_required_param $name VERSION_MINOR 4
    set_required_param $name VERSION_PATCH 0
    set_required_param $name BUILD 506
    set_required_param $name VERSION_DATE 20260506
}

proc configure_frame_deassembly {name} {
    add_instance $name mutrig_frame_deassembly $::frame_deassembly_version
    set_required_param $name CHANNEL_WIDTH 4
    set_required_param $name CSR_ADDR_WIDTH 2
    set_required_param $name DEBUG_LV $::full8lane_debug_level
    set_required_param $name MODE_HALT 0
    # Keep a defensive build-level VERSION_GIT override for the generated
    # datapath instances. The mutrig_frame_deassembly submodule now clamps
    # its git-derived default into the signed-31-bit validator range, but
    # this explicit value keeps the bring-up image deterministic.
    set_required_param $name VERSION_GIT 0
}

proc adopt_sv_lvds_controller {} {
    # MV2/B016/B017: the SV LVDS package now absorbs the Arria V PHY. Replace
    # both stale pieces and keep only the external FEB-facing pins/streams.
    foreach stale_inst {lvds_rx_controller_pro_0 lvds_rx_28nm_0 receiver_clock_125} {
        remove_instance_if_present $stale_inst
    }
    remove_dangling_connections

    add_instance lvds_rx_controller_pro_0 mu3e_lvds_controller $::lvds_controller_version
    set_required_param lvds_rx_controller_pro_0 N_LANE 9
    set_required_param lvds_rx_controller_pro_0 N_ENGINE 1
    set_required_param lvds_rx_controller_pro_0 ROUTING_TOPOLOGY 1
    set_required_param lvds_rx_controller_pro_0 SCORE_WINDOW_W 10
    set_required_param lvds_rx_controller_pro_0 SCORE_ACCEPT 8
    set_required_param lvds_rx_controller_pro_0 SCORE_REJECT 2
    set_required_param lvds_rx_controller_pro_0 STEER_QUEUE_DEPTH 4
    set_required_param lvds_rx_controller_pro_0 SYNC_PATTERN 0x0FA
    set_required_param lvds_rx_controller_pro_0 DEBUG_LEVEL $::full8lane_debug_level
    set_required_param lvds_rx_controller_pro_0 IP_UID 0x4C564453
    set_required_param lvds_rx_controller_pro_0 INSTANCE_ID 0
    set_required_param lvds_rx_controller_pro_0 VERSION_MAJOR 26
    set_required_param lvds_rx_controller_pro_0 VERSION_MINOR 2
    set_required_param lvds_rx_controller_pro_0 VERSION_PATCH 1
    set_required_param lvds_rx_controller_pro_0 BUILD 0x506
    set_required_param lvds_rx_controller_pro_0 VERSION_DATE 0x20260506
    set_required_param lvds_rx_controller_pro_0 VERSION_GIT 0x00000000

    add_clock_connection monitor_clock_125.clk lvds_rx_controller_pro_0.control_clock
    add_reset_connection monitor_clock_125.clk_reset lvds_rx_controller_pro_0.control_reset
    add_reset_connection monitor_clock_125.clk_reset lvds_rx_controller_pro_0.data_reset
    # The SV adapter exposes a 4 KiB CSR aperture. Keep it in a free upstream
    # slot rather than expanding mm_pipeline_lvds_csr_low over lane 2/3 slots.
    add_mm_connection mm_clock_crossing_bridge.m0 lvds_rx_controller_pro_0.csr $::lvds_controller_local_csr_base
    add_mm_connection master_datapath.master lvds_rx_controller_pro_0.csr $::lvds_controller_master_csr_base

    force_export lvds_pll_inclock clock end lvds_rx_controller_pro_0.inclock
    force_export lvds_outclock clock start lvds_rx_controller_pro_0.outclock
    force_export serial conduit end lvds_rx_controller_pro_0.serial
    force_export redriver conduit end lvds_rx_controller_pro_0.redriver
    force_export rstlink avalon_streaming start lvds_rx_controller_pro_0.decoded8
}

proc configure_emulator_for_type0_bank {name lane} {
    set_optional_param $name ASIC_ID_DEFAULT [expr {8 + $lane}]
    set_optional_param $name CLUSTER_LANE_INDEX_DEFAULT $lane
    set_optional_param $name CLUSTER_LANE_COUNT_DEFAULT 8
    set_optional_param $name FIFO_DEPTH 64
    set_optional_param $name GIT_STAMP_OVERRIDE true
    set_optional_param $name VERSION_MAJOR 26
    set_optional_param $name VERSION_MINOR 3
    set_optional_param $name VERSION_PATCH 0
    set_optional_param $name BUILD 506
    set_optional_param $name VERSION_DATE 20260506
    set_optional_param $name DEBUG_LEVEL $::full8lane_debug_level
}

proc instantiate_emulator_for_type0_bank {name lane} {
    remove_instance_if_present $name
    add_instance $name emulator_mutrig $::emulator_mutrig_version
    configure_emulator_for_type0_bank $name $lane
}

proc configure_full8lane_onewire_master {name} {
    add_instance $name full8lane_onewire_master 26.2.1.428
    set_required_param $name MASTER_INIT_RESET_US 500
    set_required_param $name MASTER_WAIT_PRESENCE_US 45
    set_required_param $name MASTER_SAMPLE_PRESENCE_TIMEOUT_US 1000
    set_required_param $name SLOTS_SEPERATION_US 5
    set_required_param $name RX_SLOT_US 90
    set_required_param $name RX_PULL_LOW_US 5
    set_required_param $name RX_MASTER_SAMPLE_US 10
    set_required_param $name TX_SLOT_US 90
    set_required_param $name TX_PULL_LOW_US 5
    set_required_param $name PARACITIC_POWERING 0
    set_required_param $name REF_CLOCK_RATE 125000000
    set_required_param $name AVST_DATA_WIDTH 8
    set_required_param $name AVMM_DATA_WIDTH 32
    set_required_param $name N_DQ_LINES 6
    set_required_param $name AVST_CHANNEL_WIDTH 3
    set_required_param $name RX_BUFFER_DEPTH 16
    set_required_param $name TX_BUFFER_DEPTH 8
    set_required_param $name MAX_BUFFER_DEPTH 16
    set_required_param $name VARIANT lite
    set_required_param $name DEBUG_LV 0
    set_required_param $name RX_FIFO_TYPE MLAB
    set_required_param $name TX_FIFO_TYPE MLAB
    set_required_param $name EN_STREAMING true
    set_required_param $name USE_IRQ true
    set_optional_param $name DEVICE_FAMILY {Arria V}
}

proc configure_full8lane_sc_hub {name} {
    add_instance $name full8lane_sc_hub_v2 26.6.10.423
    set_required_param $name PRESET FEB_SCIFI_DEFAULT
    set_required_param $name BUS_TYPE AVALON
    set_required_param $name ADDR_WIDTH 18
    set_required_param $name DATA_WIDTH 32
    set_required_param $name DEBUG 1
    set_required_param $name INSTANCE_ID 0
    set_required_param $name VERSION_MAJOR 26
    set_required_param $name VERSION_MINOR 6
    set_required_param $name VERSION_PATCH 9
    set_required_param $name BUILD 414
    set_required_param $name VERSION_DATE 20260414
    set_required_param $name VERSION_GIT 98822845
    set_required_param $name IP_UID 1396918338
    set_required_param $name BACKPRESSURE true
    set_required_param $name SCHEDULER_USE_PKT_TRANSFER true
    set_required_param $name INVERT_RD_SIG false
    set_required_param $name OOO_ENABLE false
    set_required_param $name ORD_ENABLE true
    set_required_param $name ATOMIC_ENABLE true
    set_required_param $name HUB_CAP_ENABLE true
    set_required_param $name BP_FIFO_DEPTH 512
    set_required_param $name OUTSTANDING_LIMIT 8
    set_required_param $name OUTSTANDING_INT_RESERVED 2
    set_required_param $name RD_TIMEOUT_CYCLES 1024
    set_required_param $name WR_TIMEOUT_CYCLES 1024
}

proc configure_full8lane_histogram_statistics {name} {
    add_instance $name full8lane_histogram_statistics_v2 26.1.8.502
    set_required_param $name AVST_CHANNEL_WIDTH 4
    set_required_param $name AVST_DATA_WIDTH 39
    set_required_param $name AVS_ADDR_WIDTH 8
    set_required_param $name BUILD 502
    set_required_param $name CHANNELS_PER_PORT 32
    set_required_param $name COAL_QUEUE_DEPTH 256
    set_required_param $name DEBUG $::full8lane_debug_level
    set_required_param $name DEF_BIN_WIDTH 1
    set_required_param $name DEF_INTERVAL_CLOCKS 125000000
    set_required_param $name DEF_LEFT_BOUND 0
    set_required_param $name ENABLE_PACKET false
    set_required_param $name ENABLE_PINGPONG true
    set_required_param $name FIFO_ADDR_WIDTH 8
    set_required_param $name FILTER_KEY_BIT_HI 38
    set_required_param $name FILTER_KEY_BIT_LO 35
    set_required_param $name INSTANCE_ID 0
    set_required_param $name IP_UID 1212765012
    set_required_param $name MAX_COUNT_BITS 32
    set_required_param $name N_BINS 256
    set_required_param $name N_DEBUG_INTERFACE 6
    set_required_param $name N_PORTS $::histogram_data_port_count
    set_required_param $name SAR_KEY_WIDTH 8
    set_required_param $name SAR_TICK_WIDTH 16
    set_required_param $name SNOOP_EN false
    set_required_param $name UPDATE_KEY_BIT_HI 34
    set_required_param $name UPDATE_KEY_BIT_LO 30
    set_required_param $name UPDATE_KEY_REPRESENTATION SIGNED
    set_required_param $name VERSION_DATE 20260502
    set_required_param $name VERSION_GIT 72231161
    set_required_param $name VERSION_MAJOR 26
    set_required_param $name VERSION_MINOR 1
    set_required_param $name VERSION_PATCH 8
}

proc chmod_generated_artifacts {syn_dir system_names} {
    foreach name $system_names {
        foreach path [list \
            [file join $syn_dir ${name}.qsys] \
            [file join $syn_dir ${name}.sopcinfo] \
            [file join $syn_dir $name synthesis] \
        ] {
            if {[file exists $path]} {
                exec chmod -R a-w $path
            }
        }
    }
}

proc generate_system {qsys_path search_path} {
    set generate_cmd "qsys-generate \"$qsys_path\" --clear-output-directory --synthesis=VERILOG --search-path=\"$search_path\" 2>&1"
    puts "INFO: running $generate_cmd"
    set generate_output [exec sh -c $generate_cmd]
    puts $generate_output
}

proc insert_qip_line_before {qip_path marker line} {
    set fd [open $qip_path r]
    set content [read $fd]
    close $fd

    set output_lines [list]
    set inserted 0
    foreach existing [split $content "\n"] {
        if {[string equal $existing $line]} {
            continue
        }
        if {!$inserted && [string first $marker $existing] >= 0} {
            lappend output_lines $line
            set inserted 1
        }
        lappend output_lines $existing
    }
    if {!$inserted} {
        lappend output_lines $line
    }

    exec chmod u+w $qip_path
    set fd [open $qip_path w]
    puts -nonewline $fd [join $output_lines "\n"]
    close $fd
}

proc patch_histogram_compatibility {syn_dir system_name histogram_compat_ip_dir} {
    set submodule_dir [file join $syn_dir $system_name synthesis submodules]
    set qip_path [file join $syn_dir $system_name synthesis ${system_name}.qip]
    set compat_wrapper_src [file join $histogram_compat_ip_dir histogram_statistics_v2.vhd]
    set bool_core_src [file join $histogram_compat_ip_dir histogram_statistics_v2_bool_core.vhd]
    set compat_wrapper_dst [file join $submodule_dir histogram_statistics_v2.vhd]
    set bool_core_dst [file join $submodule_dir histogram_statistics_v2_bool_core.vhd]

    foreach required [list $qip_path $compat_wrapper_src $bool_core_src $submodule_dir] {
        if {![file exists $required]} {
            error "required histogram compatibility path is missing: $required"
        }
    }

    foreach dst [list $compat_wrapper_dst $bool_core_dst] {
        if {[file exists $dst]} {
            exec chmod u+w $dst
        }
    }
    file copy -force $compat_wrapper_src $compat_wrapper_dst
    file copy -force $bool_core_src $bool_core_dst

    set marker {submodules/histogram_statistics_v2.vhd}
    set bool_core_line [format {set_global_assignment -library "%s" -name VHDL_FILE [file join $::quartus(qip_path) "submodules/histogram_statistics_v2_bool_core.vhd"]} $system_name]
    insert_qip_line_before $qip_path $marker $bool_core_line
    puts "INFO: patched $system_name histogram_statistics_v2 compatibility shim into generated synthesis tree"
}

proc build_control_path_qsys {ref_qsys_path qsys_path} {
    puts "INFO: loading control-path reference $ref_qsys_path"
    load_system $ref_qsys_path
    set_project_property DEVICE_FAMILY {Arria V}
    set_project_property DEVICE {5AGXBA7D4F31C5}
    set_project_property HIDE_FROM_IP_CATALOG {false}

    remove_instance_if_present onewire_master_0
    remove_instance_if_present sc_hub
    remove_dangling_connections
    configure_full8lane_onewire_master onewire_master_0
    configure_full8lane_sc_hub sc_hub

    force_export sense_dq conduit end onewire_master_0.sense_dq
    force_export data_sc_merger_out avalon_streaming start sc_hub.upload
    force_export sc_hub_hub_sc_packet_downlink conduit end sc_hub.download
    add_mm_connection sc_hub.hub sc_hub_cmd_pipe.s0 0x0000
    add_mm_connection jtag_master.master sc_hub.csr 0x0400
    add_mm_connection onewire_master_controller_0.ctrl onewire_master_0.ctrl 0x0000
    add_stream_connection onewire_master_0.rx onewire_master_controller_0.rx
    add_stream_connection onewire_master_controller_0.tx onewire_master_0.tx
    add_clock_connection clk125.out_clk sc_hub.hub_clock
    add_clock_connection clk125.out_clk onewire_master_0.clock
    add_reset_connection clk156.clk_reset sc_hub.hub_reset
    add_interrupt_connection onewire_master_controller_0.complete onewire_master_0.complete 0
    add_reset_connection clk156.clk_reset onewire_master_0.reset
    add_reset_connection jtag_master.master_reset sc_hub.hub_reset
    add_reset_connection jtag_master.master_reset onewire_master_0.reset
    set_interconnect_requirement {sc_hub.hub} {qsys_mm.insertPerformanceMonitor} {FALSE}

    save_system $qsys_path
    puts "INFO: saved full8lane control-path subsystem $qsys_path"
}

proc build_supercore_qsys {qsys_path} {
    create_system arb_hit_type0_supercore
    set_project_property DEVICE_FAMILY {Arria V}
    set_project_property DEVICE {5AGXBA7D4F31C5}
    set_project_property HIDE_FROM_IP_CATALOG {false}

    add_instance clk_bridge altera_clock_bridge 18.1
    set_required_param clk_bridge EXPLICIT_CLOCK_RATE 0.0
    set_required_param clk_bridge NUM_CLOCK_OUTPUTS 1

    add_instance reset_bridge altera_reset_bridge 18.1
    set_required_param reset_bridge ACTIVE_LOW_RESET 0
    set_required_param reset_bridge SYNCHRONOUS_EDGES deassert
    set_required_param reset_bridge NUM_RESET_OUTPUTS 1
    set_required_param reset_bridge USE_RESET_REQUEST 0

    configure_run_ctrl_splitter run_ctrl_splitter 8
    add_connection clk_bridge.out_clk reset_bridge.clk
    add_connection clk_bridge.out_clk run_ctrl_splitter.clk
    add_connection reset_bridge.out_reset run_ctrl_splitter.reset

    add_interface clk clock sink
    set_interface_property clk EXPORT_OF clk_bridge.in_clk
    add_interface rst reset sink
    set_interface_property rst EXPORT_OF reset_bridge.in_reset
    add_interface run_ctrl avalon_streaming sink
    set_interface_property run_ctrl EXPORT_OF run_ctrl_splitter.in

    for {set lane 0} {$lane < 8} {incr lane} {
        set inst lane_$lane
        configure_arb_child $inst $lane 0 500
        add_connection clk_bridge.out_clk $inst.clk
        add_connection reset_bridge.out_reset $inst.rst
        add_connection run_ctrl_splitter.out$lane $inst.run_ctrl

        add_interface csr_$lane avalon end
        set_interface_property csr_$lane EXPORT_OF $inst.csr
        add_interface real_in_$lane avalon_streaming sink
        set_interface_property real_in_$lane EXPORT_OF $inst.real_in
        add_interface emu_in_$lane avalon_streaming sink
        set_interface_property emu_in_$lane EXPORT_OF $inst.emu_in
        add_interface selected_out_$lane avalon_streaming source
        set_interface_property selected_out_$lane EXPORT_OF $inst.selected_out
        if {$::full8lane_debug_level >= 1} {
            add_interface debug_fifo_$lane conduit start
            set_interface_property debug_fifo_$lane EXPORT_OF $inst.debug_fifo
        }
        if {$::full8lane_debug_level >= 2} {
            add_interface real_hit_debug_$lane conduit end
            set_interface_property real_hit_debug_$lane EXPORT_OF $inst.real_hit_debug
            add_interface emu_hit_debug_$lane conduit end
            set_interface_property emu_hit_debug_$lane EXPORT_OF $inst.emu_hit_debug
            add_interface selected_hit_debug_$lane conduit start
            set_interface_property selected_hit_debug_$lane EXPORT_OF $inst.selected_hit_debug
        }
    }

    set_interconnect_requirement {$system} qsys_mm.clockCrossingAdapter AUTO
    set_interconnect_requirement {$system} qsys_mm.enableEccProtection FALSE
    set_interconnect_requirement {$system} qsys_mm.enableInstrumentation FALSE
    set_interconnect_requirement {$system} qsys_mm.insertDefaultSlave FALSE
    set_interconnect_requirement {$system} qsys_mm.maxAdditionalLatency 4

    save_system $qsys_path
    puts "INFO: saved generated arb_hit_type0_supercore subsystem $qsys_path"
}

proc rebind_outer_control_path {kind} {
    remove_instance_if_present control_path_subsystem
    remove_dangling_connections
    add_instance control_path_subsystem $kind 1.0

    ensure_export download_sc conduit end control_path_subsystem.sc_hub_hub_sc_packet_downlink
    ensure_export legacy_firefly_mon avalon start control_path_subsystem.legacy_firefly_mon
    ensure_export max10_link conduit end control_path_subsystem.max10_link
    ensure_export max10_link_clock clock end control_path_subsystem.max10_link_clock
    ensure_export mutrig_cfg_ctrl_0_spi_export2top conduit end control_path_subsystem.mutrig_cfg_ctrl_0_spi_export2top
    ensure_export pulse_out_conduit conduit end control_path_subsystem.pulse_out_conduit
    ensure_export sense_dq conduit end control_path_subsystem.sense_dq
    ensure_export to_firefly_ucc8 conduit end control_path_subsystem.to_firefly_ucc8

    add_mm_connection control_path_subsystem.upload_avmm_port upload_subsystem.csr 0x0000
    add_stream_connection control_path_subsystem.data_sc_merger_out upload_subsystem.upload_sc
    add_clock_connection mclk125_souce.clk control_path_subsystem.clk125_in_clk
    add_clock_connection cclk156_source.clk control_path_subsystem.clk156_in_clk
    add_reset_connection control_reset_sync_125.reset_out control_path_subsystem.clk156_in_rst
}

proc rebind_outer_data_path {kind version} {
    remove_instance_if_present data_path_subsystem
    remove_dangling_connections
    add_instance data_path_subsystem $kind $version

    force_export control_path_clk125 clock start mclk125_souce.clk
    ensure_export inject conduit end data_path_subsystem.inject
    ensure_export lvds_pll_inclock clock end data_path_subsystem.lvds_pll_inclock
    ensure_export mutrig_reset conduit end data_path_subsystem.mutrig_reset
    ensure_export redriver conduit end data_path_subsystem.redriver
    ensure_export serial conduit end data_path_subsystem.serial
    ensure_export upload_data1 avalon_streaming start data_path_subsystem.hit_type3_lower

    add_mm_connection control_path_subsystem.avmm_port data_path_subsystem.avmm_port 0x0000
    add_stream_connection data_path_subsystem.hit_type3_upper upload_subsystem.upload_data
    add_stream_connection data_path_subsystem.rstlink upload_subsystem.synclink
    add_stream_connection upload_subsystem.runctl_mgmt_host data_path_subsystem.runctl_mgmt_host

    add_clock_connection mclk125_souce.clk data_path_subsystem.avmm_clk
    add_clock_connection mclk125_souce.clk data_path_subsystem.monitor_clock_125_in
    add_clock_connection cclk156_source.clk data_path_subsystem.xcvr_clock
    add_clock_connection data_path_subsystem.lvds_outclock upload_lvds_reset_bridge.clk
    add_clock_connection data_path_subsystem.lvds_outclock upload_subsystem.lvds_outclock
    add_clock_connection osc50_source.out_clk data_path_subsystem.osc_clock_50_in

    add_reset_connection ext_reset_pipe2_cclk156.out_reset data_path_subsystem.xcvr_reset
    add_reset_connection control_reset_sync_125.reset_out data_path_subsystem.avmm_rst
    add_reset_connection control_reset_sync_125.reset_out data_path_subsystem.monitor_reset_in_reset
    add_reset_connection control_path_subsystem.sclr_counter_req data_path_subsystem.counter_sclr
}

array set lane_csr_bridge {
    0 mm_pipeline_lvds_csr_low
    1 mm_pipeline_lvds_csr_low
    2 mm_pipeline_lvds_csr_emu_dbg
    3 mm_pipeline_lvds_csr_mutrig3
    4 mm_pipeline_lvds_csr_mutrig4_mts0
    5 mm_pipeline_lvds_csr_mutrig5
    6 mm_pipeline_lvds_csr_mutrig6
    7 mm_pipeline_lvds_csr_mutrig7
}

array set lane_runctrl_out {
    0 2
    1 3
    2 4
    3 5
    4 8
    5 9
    6 10
    7 11
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

if {![file exists $inner_ref_qsys_path]} {
    error "Reference inner qsys not found: $inner_ref_qsys_path"
}
if {![file exists $control_ref_qsys_path]} {
    error "Reference control qsys not found: $control_ref_qsys_path"
}
if {![file exists $outer_ref_qsys_path]} {
    error "Reference outer qsys not found: $outer_ref_qsys_path"
}
if {![file exists $ref_upload_qsys_path]} {
    error "Reference upload qsys not found: $ref_upload_qsys_path"
}
if {![file exists $ref_hit_stack_qsys_path]} {
    error "Reference hit-stack qsys not found: $ref_hit_stack_qsys_path"
}

materialize_readyless_upload_qsys $ref_upload_qsys_path $upload_readyless_qsys_path $runctl_mgmt_host_readyless_version
materialize_readyless_hit_stack_qsys \
    $ref_hit_stack_qsys_path \
    $hit_stack_readyless_qsys_path \
    $full8lane_debug_level \
    $ring_buffer_cam_version \
    $feb_frame_assembly_version
build_control_path_qsys $control_ref_qsys_path $control_qsys_path
build_supercore_qsys $supercore_qsys_path
reload_ip_catalog

puts "INFO: loading 8-lane topology reference $inner_ref_qsys_path"
load_system $inner_ref_qsys_path
set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

# Keep the pipe reference's current histogram defaults explicit in the new
# recipe so regenerating against a stale base cannot move the observation tap.
set_required_param histogram_ingress_bridge_0 DEFAULT_SELECT_POST 1
set_required_param histogram_ingress_bridge_0 FILTER_POST_HIT_WORDS 1
set_required_param histogram_ingress_bridge_0 VERSION_MAJOR 26
set_required_param histogram_ingress_bridge_0 VERSION_MINOR 0
set_required_param histogram_ingress_bridge_0 VERSION_PATCH 5
set_required_param histogram_ingress_bridge_0 BUILD 506
set_required_param histogram_ingress_bridge_0 VERSION_DATE 20260506
set_optional_param histogram_ingress_bridge_0 VERSION_GIT 481097348
set_required_param mts_preprocessor_0 DEBUG $full8lane_debug_level
set_required_param mts_preprocessor_1 DEBUG $full8lane_debug_level

set_required_param mm_clock_crossing_bridge USE_AUTO_ADDRESS_WIDTH 1
# Run-control commands are broadcast pulses/words.  Keep every parent fanout
# source readyless so generated ready plumbing cannot turn a slow consumer into
# command-source backpressure.
set_required_param run_control_splitter USE_READY 0
set_required_param run_control_splitter NUMBER_OF_OUTPUTS 16
set_required_param emulator_ctrl_splitter USE_READY 0
adopt_sv_lvds_controller

# Mu3e SciFi frames are 128 sub-headers x 16 cycles = 2048 datapath cycles.
# N_SHD=128 is set inside hit_stack_subsystem composition; the dotted-path
# override here is rejected by qsys-script ("No interface named ...") and
# isn't needed because the resolved sopcinfo already shows N_SHD=128 at
# both feb_frame_assembly_0 instances. See BUG_HISTORY.md B008.

# Remove the byte-stream source-mux path and the nested per-lane datapath
# subsystem. The replacement is flattened in this Qsys recipe so the Type0
# arbiter sits on the post-deassembly hit_type0 boundary.
remove_instance_if_present arb_hit_type0_supercore_0
remove_instance_if_present type0_run_ctrl_splitter
remove_instance_if_present run_control_mts1_fda0_splitter
remove_instance_if_present histogram_statistics_0
for {set lane 0} {$lane < 8} {incr lane} {
    remove_instance_if_present mutrig_lane_source_mux_$lane
    remove_instance_if_present mutrig_datapath_subsystem_$lane
    remove_instance_if_present mutrig_frame_deassembly_$lane
    remove_instance_if_present backpressure_fifo_$lane
    remove_instance_if_present emulator_mutrig_$lane
}
remove_dangling_connections

add_instance arb_hit_type0_supercore_0 arb_hit_type0_supercore 1.0
configure_full8lane_histogram_statistics histogram_statistics_0

# B002 defensive fix (2026-05-05): eliminate type0_run_ctrl_splitter intermediate
# hop.  run_control_splitter.out2 feeds arb_hit_type0_supercore_0.run_ctrl
# directly.  The Intel 18.1 splitter tops out at 16 outputs, so preserve the
# reference out12 slot by cascading a two-output readyless splitter for MTS1 and
# mutrig_frame_deassembly_0.ctrl.
# NOTE: dbg_mm2runctrl_0.aso_ctrl merge into run_control_splitter.in is
# deferred — no standard altera_avalon_st_merger exists in Qsys 18.1 and a
# non-packet multiplexer would mis-schedule the USE_PACKETS=0 run-ctrl stream.

add_clock_connection lvds_rx_controller_pro_0.outclock arb_hit_type0_supercore_0.clk
add_reset_connection master_datapath.master_reset arb_hit_type0_supercore_0.rst
add_stream_connection run_control_splitter.out2 arb_hit_type0_supercore_0.run_ctrl

configure_run_ctrl_splitter run_control_mts1_fda0_splitter 2
add_clock_connection lvds_rx_controller_pro_0.outclock run_control_mts1_fda0_splitter.clk
add_reset_connection master_datapath.master_reset run_control_mts1_fda0_splitter.reset
remove_connection_if_present run_control_splitter.out12/mts_preprocessor_1.run_ctrl
add_stream_connection run_control_splitter.out12 run_control_mts1_fda0_splitter.in
add_stream_connection run_control_mts1_fda0_splitter.out0 mts_preprocessor_1.run_ctrl

add_mm_connection mm_pipeline_lvds_csr_hist.m0 histogram_statistics_0.hist_bin 0x0000
add_mm_connection mm_pipeline_lvds_csr_hist.m0 histogram_statistics_0.csr 0x0400
add_mm_connection master_datapath.master histogram_statistics_0.hist_bin 0x00020000
add_mm_connection master_datapath.master histogram_statistics_0.csr 0x00020400
add_stream_connection mts_preprocessor_0.debug_ts histogram_statistics_0.debug_1
add_stream_connection mts_preprocessor_1.debug_ts histogram_statistics_0.debug_2
add_stream_connection histogram_ingress_bridge_0.hist_out histogram_statistics_0.hist_fill_in
add_stream_connection run_control_splitter.out0 histogram_statistics_0.ctrl
# DEBUG_LEVEL=1 fill-level map. The histogram core has six debug sinks:
# debug_1/2 stay reserved for dual-MTS timing metadata, so debug_3..6 carry
# the four no-ready rbCAM fill-level streams exported by hit_stack_subsystem_0.
# The matching hit_stack_subsystem_1 and backpressure FIFO levels need an
# upstream aggregation stream before they can be added losslessly here.
add_stream_connection hit_stack_subsystem_0.ring_buffer_cam_0_filllevel histogram_statistics_0.debug_3
add_stream_connection hit_stack_subsystem_0.ring_buffer_cam_1_filllevel histogram_statistics_0.debug_4
add_stream_connection hit_stack_subsystem_0.ring_buffer_cam_2_filllevel histogram_statistics_0.debug_5
add_stream_connection hit_stack_subsystem_0.ring_buffer_cam_3_filllevel histogram_statistics_0.debug_6
add_clock_connection lvds_rx_controller_pro_0.outclock histogram_statistics_0.clock
add_reset_connection master_datapath.master_reset histogram_statistics_0.reset
add_reset_connection reset_bridge_export.out_reset histogram_statistics_0.interval_reset

if {$full8lane_debug_level >= 2} {
    foreach bank {0 1} {
        set bridge mts${bank}_hit_type0_sidecar_bridge
        add_instance $bridge debug_hit_sidecar_bank_bridge $debug_hit_sidecar_bank_bridge_version
        set_required_param $bridge DATA_WIDTH 45
        set_required_param $bridge CHANNEL_WIDTH 6
        set_required_param $bridge ERROR_WIDTH 3
        set_required_param $bridge METADATA_WIDTH 64
        set_required_param $bridge FIFO_DEPTH 256
        add_clock_connection lvds_rx_controller_pro_0.outclock $bridge.clock
        add_reset_connection master_datapath.master_reset $bridge.reset

        set fanout mts${bank}_hit_type1_sidecar_fanout
        add_instance $fanout debug_sidecar_fanout $debug_sidecar_fanout_version
        set_required_param $fanout DATA_WIDTH 64
        add_clock_connection lvds_rx_controller_pro_0.outclock $fanout.clock
        add_reset_connection master_datapath.master_reset $fanout.reset
        # Existing reference-system MTS instances expose DEBUG-elaborated
        # interfaces only after the saved system is reloaded by qsys-generate.
        # The MTS-to-fanout input binding is patched into the saved Qsys below.
        for {set idx 0} {$idx < 4} {incr idx} {
            add_conduit_connection $fanout.out$idx hit_stack_subsystem_${bank}.hit_type1_${idx}_metadata
        }
    }

    remove_connection_if_present mux_mutrig2processor.out/mts_preprocessor_0.hit_type0_in
    remove_connection_if_present mux_mutrig2processor_0.out/mts_preprocessor_1.hit_type0_in
    add_stream_connection mux_mutrig2processor.out mts0_hit_type0_sidecar_bridge.hit_type0_in
    add_stream_connection mts0_hit_type0_sidecar_bridge.hit_type0_out mts_preprocessor_0.hit_type0_in
    add_stream_connection mux_mutrig2processor_0.out mts1_hit_type0_sidecar_bridge.hit_type0_in
    add_stream_connection mts1_hit_type0_sidecar_bridge.hit_type0_out mts_preprocessor_1.hit_type0_in
}

for {set lane 0} {$lane < 8} {incr lane} {
    set fda mutrig_frame_deassembly_$lane
    set fifo backpressure_fifo_$lane
    set emu emulator_mutrig_$lane

    configure_frame_deassembly $fda
    configure_backpressure_fifo $fifo 128
    instantiate_emulator_for_type0_bank $emu $lane

    add_clock_connection lvds_rx_controller_pro_0.outclock $fda.clock_sink
    add_clock_connection lvds_rx_controller_pro_0.outclock $fifo.clk
    add_clock_connection lvds_rx_controller_pro_0.outclock $emu.data_clock
    add_reset_connection master_datapath.master_reset $fda.reset_sink
    add_reset_connection master_datapath.master_reset $fifo.clk_reset
    add_reset_connection master_datapath.master_reset $emu.data_reset
    add_stream_connection emulator_ctrl_splitter.out$lane $emu.ctrl
    add_conduit_connection emulator_inject_fanout.out$lane $emu.inject

    add_stream_connection lvds_rx_controller_pro_0.decoded${lane} $fda.rx8b1k
    add_stream_connection $fda.hit_type0 arb_hit_type0_supercore_0.real_in_$lane
    add_stream_connection $emu.hit_type0 arb_hit_type0_supercore_0.emu_in_$lane
    if {$full8lane_debug_level >= 2} {
        add_conduit_connection $fda.debug_hit_metadata arb_hit_type0_supercore_0.real_hit_debug_$lane
        add_conduit_connection $emu.hit_debug_metadata arb_hit_type0_supercore_0.emu_hit_debug_$lane
        set sidecar_bank [expr {$lane < 4 ? 0 : 1}]
        set sidecar_lane [expr {$lane % 4}]
        add_conduit_connection \
            arb_hit_type0_supercore_0.selected_hit_debug_$lane \
            mts${sidecar_bank}_hit_type0_sidecar_bridge.lane${sidecar_lane}
    }
    add_stream_connection arb_hit_type0_supercore_0.selected_out_$lane $fifo.in
    add_stream_connection $fifo.out $lane_mts_mux($lane)
    add_stream_connection $fda.headerinfo mutrig_injector_0.headerinfo$lane
    if {$lane == 0} {
        # B002/B1 follow-up: fda_0.ctrl was type0_run_ctrl_splitter.out1.
        # run_control_mts1_fda0_splitter.out0 preserves MTS1; out1 drives FDA0.
        add_stream_connection run_control_mts1_fda0_splitter.out1 $fda.ctrl
    } else {
        add_stream_connection run_control_splitter.out$lane_runctrl_out($lane) $fda.ctrl
    }

    set bridge $lane_csr_bridge($lane)
    if {$lane < 2} {
        set local_frame_base [expr {0x0900 + (0x1000 * $lane)}]
        set local_fifo_base [expr {0x0860 + (0x1000 * $lane)}]
    } else {
        set local_frame_base 0x0900
        set local_fifo_base 0x0860
    }
    set master_frame_base [expr {0x00010900 + (0x1000 * $lane)}]
    set master_fifo_base [expr {0x00000860 + (0x1000 * $lane)}]
    set arb_local_base [expr {0x0280 + (0x80 * $lane)}]
    set arb_master_base [expr {0x2280 + (0x80 * $lane)}]
    set emu_local_base [expr {0x0040 * $lane}]
    set emu_master_base [expr {0x00002000 + (0x40 * $lane)}]

    add_mm_connection $bridge.m0 $fda.csr $local_frame_base
    add_mm_connection $bridge.m0 $fifo.csr $local_fifo_base
    add_mm_connection master_datapath.master $fda.csr $master_frame_base
    add_mm_connection master_datapath.master $fifo.csr $master_fifo_base
    add_mm_connection mm_pipeline_lvds_csr_emu_dbg.m0 $emu.csr $emu_local_base
    add_mm_connection master_datapath.master $emu.csr $emu_master_base
    add_mm_connection mm_pipeline_lvds_csr_emu_dbg.m0 arb_hit_type0_supercore_0.csr_$lane $arb_local_base
    add_mm_connection master_datapath.master arb_hit_type0_supercore_0.csr_$lane $arb_master_base
}

connect_lvds_outclock_domains

set_interconnect_requirement {$system} qsys_mm.clockCrossingAdapter AUTO
set_interconnect_requirement {$system} qsys_mm.enableEccProtection FALSE
set_interconnect_requirement {$system} qsys_mm.enableInstrumentation FALSE
set_interconnect_requirement {$system} qsys_mm.insertDefaultSlave FALSE
set_interconnect_requirement {$system} qsys_mm.maxAdditionalLatency 4

save_system $inner_qsys_path
patch_qsys_component_version $inner_qsys_path $inner_system_version
patch_qsys_instance_version $inner_qsys_path histogram_ingress_bridge_0 $histogram_ingress_bridge_version
patch_qsys_instance_version $inner_qsys_path mts_preprocessor_0 $mts_preprocessor_version
patch_qsys_instance_version $inner_qsys_path mts_preprocessor_1 $mts_preprocessor_version
patch_qsys_instance_parameter $inner_qsys_path mts_preprocessor_0 DEBUG $full8lane_debug_level
patch_qsys_instance_parameter $inner_qsys_path mts_preprocessor_1 DEBUG $full8lane_debug_level
if {$full8lane_debug_level >= 2} {
    foreach bank {0 1} {
        ensure_qsys_connection \
            $inner_qsys_path \
            conduit \
            mts${bank}_hit_type0_sidecar_bridge.hit_type0_sidecar \
            mts_preprocessor_${bank}.hit_type0_sidecar
        ensure_qsys_connection \
            $inner_qsys_path \
            conduit \
            mts_preprocessor_${bank}.hit_type1_sidecar \
            mts${bank}_hit_type1_sidecar_fanout.in
    }
}
ensure_qsys_interface_export \
    $inner_qsys_path \
    lvds_outclock \
    lvds_rx_controller_pro_0.outclock \
    clock \
    start \
    lvds_pll_inclock
puts "INFO: saved full8lane inner datapath $inner_qsys_path"
reload_ip_catalog

puts "INFO: loading FEB wrapper reference $outer_ref_qsys_path"
load_system $outer_ref_qsys_path
set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}
rebind_outer_control_path $control_system_name
rebind_outer_data_path $inner_system_name $inner_system_version
save_system $outer_qsys_path
patch_qsys_component_version $outer_qsys_path $outer_system_version
puts "INFO: saved full8lane outer system $outer_qsys_path"

generate_system $control_qsys_path $search_path
generate_system $supercore_qsys_path $search_path
generate_system $inner_qsys_path $search_path
generate_system $outer_qsys_path $search_path
patch_histogram_compatibility $syn_dir $inner_system_name $histogram_compat_ip_dir
patch_histogram_compatibility $syn_dir $outer_system_name $histogram_compat_ip_dir

chmod_generated_artifacts $syn_dir [list $control_system_name $supercore_system_name $inner_system_name $outer_system_name]
puts "INFO: ${outer_system_name} generation complete; qsys/sopcinfo/synthesis artifacts are read-only."
exit 0
