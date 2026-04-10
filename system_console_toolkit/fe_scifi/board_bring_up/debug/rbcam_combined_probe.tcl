package require Tcl 8.5

# rbcam_combined_probe.tcl
# Runs inside the toolkit context via the post-launch hook.
# Chains: standard runtime probe first, then ring_buffer_cam META probe.

set _probe_dir [file dirname [info script]]

# 1) Source the standard runtime probe (fires after 1000 ms)
source [file normalize [file join $_probe_dir board_bring_up_runtime_probe.tcl]]

# 2) Source the META probe (fires after 8000 ms, well after runtime probe completes)
source [file normalize [file join $_probe_dir ring_buffer_cam_meta_probe.tcl]]

unset _probe_dir
