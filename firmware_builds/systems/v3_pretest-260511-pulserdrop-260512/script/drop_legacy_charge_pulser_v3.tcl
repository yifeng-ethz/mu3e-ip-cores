# qsys-script recipe for dropping the dead FEB v3 legacy analog pulser path.
#
# Keep the topology edit in Tcl so Platform Designer owns the Qsys state.
package require -exact qsys 18.1

proc list_has {items needle} {
    return [expr {[lsearch -exact $items $needle] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[list_has [get_connections] $path]} {
        remove_connection $path
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

proc xml_attr_escape {text} {
    set text [string map {& &amp;} $text]
    set text [string map {\" &quot;} $text]
    set text [string map {< &lt;} $text]
    set text [string map {> &gt;} $text]
    return $text
}

proc update_component_metadata {path version description} {
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
        set text [string range $text 0 [expr {$value_start - 1}]][xml_attr_escape $version][string range $text $value_end end]
    }

    set desc_idx [string first {description="} $text $comp_idx]
    if {$desc_idx < 0} {
        error "No component description attribute found in $path"
    }
    set value_start [expr {$desc_idx + [string length {description="}]}]
    set value_end [string first {"} $text $value_start]
    if {$value_end < 0} {
        error "Unterminated component description attribute in $path"
    }
    set text [string range $text 0 [expr {$value_start - 1}]][xml_attr_escape $description][string range $text $value_end end]

    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
}

if {![info exists ::qsys_drop_role]} {
    error "qsys_drop_role is not set"
}
if {![info exists ::qsys_target]} {
    error "qsys_target is not set"
}

set role $::qsys_drop_role
set target $::qsys_target

if {[string equal $role {debug_sc}]} {
    foreach path {
        sc_hub_cmd_pipe.m0/charge_injection_pulser_0.csr_avmm
        jtag_master.master/charge_injection_pulser_0.csr_avmm
        clk125.out_clk/charge_injection_pulser_0.clock_interface
        jtag_master.master_reset/charge_injection_pulser_0.reset_interface
    } {
        remove_connection_if_present $path
    }

    remove_interface_if_present pulse_out_conduit
    remove_instance_if_present charge_injection_pulser_0
    remove_dangling_connections
    save_system

    update_component_metadata \
        $target \
        {3.1.0.0512} \
        {Drops dead legacy charge_injection_pulser_0 and pulse_out_conduit export; SC slot 4 is free.}
} elseif {[string equal $role {feb}]} {
    remove_interface_if_present pulse_out_conduit
    save_system

    update_component_metadata \
        $target \
        {} \
        {rc-readyless rollout with BYTE_STREAM_ENABLE=true emulator outputs. Drops dead control_path_subsystem.pulse_out_conduit export; scifi_inject remains driven by mutrig_injector_0.}
} else {
    error "unknown QSYS_DROP_ROLE '$role' (expected debug_sc or feb)"
}
