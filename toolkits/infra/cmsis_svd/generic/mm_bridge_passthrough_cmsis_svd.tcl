package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::build_device {} {
    return [::mu3e::cmsis::svd::device MU3E_MM_BRIDGE_PASSTHROUGH \
        -version 1.0.0 \
        -description {CMSIS-SVD metadata wrapper for an Avalon MM bridge slave window. The bridge itself does not implement local CSRs; the downstream datapath map is described by separate SVD and runtime-map entries. BaseAddress is 0 because this file only describes the bridge aperture role.} \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral MM_BRIDGE_PASSTHROUGH 0x0 \
                -description {Metadata-only passthrough slave window. No local registers are implemented.} \
                -groupName MU3E_GENERIC \
                -addressBlockSize 0x10000 \
                -registers {}]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir mm_bridge_passthrough.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}
