# qsys-script recipe for mutrig_datapath_system_v3.qsys.
#
# Keep the internal frame-deassembly output FIFO quiet in Platform Designer:
# the almost_empty status stream is unused by the FEB v3 integration.
package require -exact qsys 16.0

proc list_has {items needle} {
    return [expr {[lsearch -exact $items $needle] >= 0}]
}

proc remove_interface_if_present {name} {
    if {[catch {remove_interface $name} err]} {
        if {[list_has [get_interfaces] $name]} {
            error $err
        }
    }
}

proc remove_connection_if_present {path} {
    if {[list_has [get_connections] $path]} {
        if {[catch {remove_connection $path} err]} {
            # Disabled legacy instances can leave stale connection entries whose
            # endpoint interfaces no longer elaborate; remove_dangling_connections
            # below cleans those without needing the endpoint to exist.
            if {[list_has [get_connections] $path]} {
                puts "INFO: deferring stale connection cleanup for $path: $err"
            }
        }
    }
}

proc remove_instance_if_present {name} {
    if {[list_has [get_instances] $name]} {
        remove_instance $name
    }
}

set_instance_parameter_value backpressure_fifo {USE_ALMOST_EMPTY_IF} {0}
set_instance_parameter_value mutrig_frame_deassembly_0 {DEBUG_LV} {0}
remove_interface_if_present debug_hit_metadata

foreach path {
    system_clock_reset_interface.clk/lvdserr_count_subsystem.counter_clk
    system_clock_reset_interface.clk_reset/lvdserr_count_subsystem.counter_rst
    dbg_counter_fab_sclr.to_counter_control_port_b/lvdserr_count_subsystem.counter_sclr
    lvdserr_count_subsystem.avst_out/mutrig_frame_deassembly_0.rx8b1k
} {
    remove_connection_if_present $path
}

remove_interface_if_present avmm_errcnt
remove_interface_if_present avst_in
remove_instance_if_present lvdserr_count_subsystem
remove_dangling_connections
save_system
