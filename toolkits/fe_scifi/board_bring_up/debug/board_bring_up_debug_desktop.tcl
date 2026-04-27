package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up::debug::desktop {
        variable script_dir [file dirname [info script]]
}

set ::env(FE_SCIFI_BOARD_BRING_UP_POST_LAUNCH_HOOK) \
        [file normalize [file join $::fe_scifi::board_bring_up::debug::desktop::script_dir board_bring_up_runtime_probe.tcl]]

source [file normalize [file join $::fe_scifi::board_bring_up::debug::desktop::script_dir .. board_bring_up_desktop.tcl]]
