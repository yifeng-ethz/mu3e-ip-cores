# qsys-script recipe for deriving the pulserdrop local datapath Qsys from the
# canonical root datapath Qsys and restoring the cosim arb_hit_type0 route.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

if {![info exists ::src_qsys]} {
    error "src_qsys is not set"
}
if {![info exists ::dst_qsys]} {
    error "dst_qsys is not set"
}

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

proc has_interface {name} {
    return [expr {[lsearch -exact [get_interfaces] $name] >= 0}]
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

proc add_optional_mm_connection {start end base} {
    if {![regexp {^([^.]*)[.]} $start -> start_inst]} {
        error "invalid Avalon-MM start interface name: $start"
    }
    if {[has_instance $start_inst]} {
        add_mm_connection $start $end $base
    } else {
        puts "INFO: optional MM start instance ${start_inst} not present; skipped ${start}/${end}"
    }
}

proc set_optional_param {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        puts "INFO: optional parameter ${inst}.${name} not present: $err"
    }
}

proc configure_run_control_broadcasts {} {
    # Run-control is a broadcast fabric. The legacy Intel splitter backpressures
    # from every output when USE_READY=1, which blocks the single-emulator
    # topology after the old per-lane emulator sinks are removed.
    set_optional_param run_control_splitter USE_READY 0
    set_optional_param run_control_splitter READY_LATENCY 0
    set_optional_param run_control_splitter QUALIFY_VALID_OUT 0

    set_optional_param emulator_ctrl_splitter USE_READY 0
    set_optional_param emulator_ctrl_splitter READY_LATENCY 0
    set_optional_param emulator_ctrl_splitter QUALIFY_VALID_OUT 0
}

proc xml_attr_escape {value} {
    set value [string map {& &amp; < &lt; > &gt; \" &quot;} $value]
    return $value
}

proc update_component_metadata {path version description} {
    exec chmod u+w $path
    set fd [open $path r]
    set text [read $fd]
    close $fd

    set comp_idx [string first "<component" $text]
    if {$comp_idx < 0} {
        error "No component header found in $path"
    }

    if {![string equal $version {}]} {
        set ver_idx [string first {version="} $text $comp_idx]
        if {$ver_idx < 0} {
            error "No component version attribute found in $path"
        }
        set value_start [expr {$ver_idx + [string length {version="}]}]
        set value_end [string first {"} $text $value_start]
        if {$value_end < 0} {
            error "Unterminated component version attribute in $path"
        }
        set text [string replace $text $value_start [expr {$value_end - 1}] [xml_attr_escape $version]]
    }

    if {![string equal $description {}]} {
        set desc_idx [string first {description="} $text $comp_idx]
        if {$desc_idx < 0} {
            error "No component description attribute found in $path"
        }
        set value_start [expr {$desc_idx + [string length {description="}]}]
        set value_end [string first {"} $text $value_start]
        if {$value_end < 0} {
            error "Unterminated component description attribute in $path"
        }
        set text [string replace $text $value_start [expr {$value_end - 1}] [xml_attr_escape $description]]
    }

    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
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
    add_instance $::type0_emulator_inst emulator_mutrig 26.3.1.0513
    set_optional_param $::type0_emulator_inst BYTE_STREAM_ENABLE false
    set_optional_param $::type0_emulator_inst CSR_ADDR_WIDTH 6
    set_optional_param $::type0_emulator_inst CLUSTER_LANE_COUNT_DEFAULT 8
    set_optional_param $::type0_emulator_inst CLUSTER_LANE_INDEX_DEFAULT 0
    set_optional_param $::type0_emulator_inst ASIC_ID_DEFAULT 0
    set_optional_param $::type0_emulator_inst INSTANCE_ID 0
    set_optional_param $::type0_emulator_inst FIFO_DEPTH 64
    set_optional_param $::type0_emulator_inst DEBUG_LEVEL 0
    set_optional_param $::type0_emulator_inst VERSION_MAJOR 26
    set_optional_param $::type0_emulator_inst VERSION_MINOR 3
    set_optional_param $::type0_emulator_inst VERSION_PATCH 1
    set_optional_param $::type0_emulator_inst BUILD 513
    set_optional_param $::type0_emulator_inst VERSION_DATE 20260513
    set_optional_param $::type0_emulator_inst VERSION_GIT 0

    add_connection_once lvds_rx_28nm_0.outclock ${::type0_emulator_inst}.data_clock
    add_connection_once master_datapath.master_reset ${::type0_emulator_inst}.data_reset
    add_connection_once emulator_ctrl_splitter.out0 ${::type0_emulator_inst}.ctrl
    add_connection_once emulator_inject_fanout.out0 ${::type0_emulator_inst}.inject
    add_optional_mm_connection mm_pipeline_lvds_csr_emu_dbg.m0 ${::type0_emulator_inst}.csr 0x0000
    add_optional_mm_connection mm_clock_crossing_bridge.m0 ${::type0_emulator_inst}.csr 0x00002000
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
        add_optional_mm_connection mm_pipeline_lvds_csr_emu_dbg.m0 arb_hit_type0_supercore_0.csr_${lane} $arb_local_base
        add_optional_mm_connection mm_clock_crossing_bridge.m0 arb_hit_type0_supercore_0.csr_${lane} $arb_master_base
        add_mm_connection master_datapath.master arb_hit_type0_supercore_0.csr_${lane} $arb_master_base
    }
}

file mkdir [file dirname $::dst_qsys]
if {[file exists $::dst_qsys]} {
    exec chmod u+w $::dst_qsys
}

load_system $::src_qsys
remove_legacy_emulator_topology
configure_run_control_broadcasts
configure_single_emulator
configure_emulator_hit_fanout
configure_arb_supercore
rewire_type0_lanes
save_system $::dst_qsys
update_component_metadata \
    $::dst_qsys \
    "3.0.4.0512" \
    "Pulserdrop local datapath: restores cosim arb_hit_type0_supercore route at the 0x088A0 top-level CSR aperture and preserves the readyless run-control broadcast contract."
exec chmod a-w $::dst_qsys
puts "INFO: saved arb-enabled pulserdrop datapath $::dst_qsys from $::src_qsys"
