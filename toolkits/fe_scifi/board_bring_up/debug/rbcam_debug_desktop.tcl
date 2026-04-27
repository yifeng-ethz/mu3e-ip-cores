package require Tcl 8.5

# rbcam_debug_desktop.tcl
# Debug desktop script: uses a combined post-launch hook that runs
# both the standard runtime probe and the ring_buffer_cam META probe
# inside the toolkit context.

namespace eval ::fe_scifi::board_bring_up::debug::rbcam_desktop {
    variable script_dir [file dirname [info script]]
}

# Point the post-launch hook to our combined probe wrapper
set ::env(FE_SCIFI_BOARD_BRING_UP_POST_LAUNCH_HOOK) \
    [file normalize [file join $::fe_scifi::board_bring_up::debug::rbcam_desktop::script_dir rbcam_combined_probe.tcl]]

# Source the main desktop bootstrap (registers toolkits, opens board_bring_up)
source [file normalize [file join $::fe_scifi::board_bring_up::debug::rbcam_desktop::script_dir .. board_bring_up_desktop.tcl]]
