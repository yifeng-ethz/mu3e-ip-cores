# qsys-script recipe for the synthesis hit_stack_system.qsys component.
#
# The debug/snoop variant remains in hit_stack_system_rbcam_snoop.qsys.  The
# component named hit_stack_system must stay lean for firmware synthesis.
package require -exact qsys 16.0

proc list_has {items needle} {
    return [expr {[lsearch -exact $items $needle] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[list_has [get_connections] $path]} {
        if {[catch {remove_connection $path} err]} {
            puts "INFO: skipped stale connection ${path}: ${err}"
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

proc remove_interface_if_present {name} {
    if {[catch {remove_interface $name} err]} {
        if {[list_has [get_interfaces] $name]} {
            error $err
        }
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

foreach inst {feb_frame_assembly_0 ring_buffer_cam_0 ring_buffer_cam_1 ring_buffer_cam_2 ring_buffer_cam_3} {
    if {[list_has [get_instances] $inst]} {
        set_instance_parameter_value $inst {DEBUG} {0}
    }
}

foreach ifname {
    frame_debug_burst
    frame_debug_delay8loss
    frame_debug_filllevel
    frame_debug_loss8fill
    frame_debug_ts
    frame_ts_delta
    ring_buffer_cam_0_filllevel
    ring_buffer_cam_0_hit_type2_snoop
    ring_buffer_cam_1_filllevel
    ring_buffer_cam_1_hit_type2_snoop
    ring_buffer_cam_2_filllevel
    ring_buffer_cam_2_hit_type2_snoop
    ring_buffer_cam_3_filllevel
    ring_buffer_cam_3_hit_type2_snoop
} {
    remove_interface_if_present $ifname
}

for {set idx 0} {$idx < 4} {incr idx} {
    set splitter "rbcam${idx}_hit_type2_splitter"
    remove_connections_containing "${splitter}."
    remove_instance_if_present $splitter
    add_connection_if_missing "ring_buffer_cam_${idx}.hit_type2" "feb_frame_assembly_0.hit_type2_${idx}"
}

remove_dangling_connections
save_system
