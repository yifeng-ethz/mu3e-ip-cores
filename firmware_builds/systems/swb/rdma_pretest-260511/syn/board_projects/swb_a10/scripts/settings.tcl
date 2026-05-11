#
# a10_board-local Quartus settings override.
# Source the shared baseline first, then bias the compile toward timing closure
# for the SC/flash bring-up image even if area/runtime increase.
#

set a10_board_script_dir [file dirname [info script]]
source [file normalize [file join $a10_board_script_dir .. util quartus settings.tcl]]

set_global_assignment -name OPTIMIZATION_MODE "AGGRESSIVE PERFORMANCE"
set_global_assignment -name PLACEMENT_EFFORT_MULTIPLIER 4.0
set_global_assignment -name ROUTER_EFFORT_MULTIPLIER 4.0
set_global_assignment -name ROUTER_CLOCKING_TOPOLOGY_ANALYSIS ON
set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT EXTRA
set_global_assignment -name NUM_PARALLEL_PROCESSORS 16
