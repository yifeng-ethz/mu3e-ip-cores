# settings

# -> Assignments / Settings / Advanced Settings

# implement state machines that can recover gracefully from an illegal state
set_global_assignment -name SAFE_STATE_MACHINE ON
# don't replace shift registers with altshift_taps megafunction (see Quartus User Guide / Auto Shift Register Replacement)
# (<>)
set_global_assignment -name AUTO_SHIFT_REGISTER_RECOGNITION OFF

# -> Assignments / Settings / VHDL Input

set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008

set_global_assignment -name SAVE_DISK_SPACE OFF

# Timing-closure profile for HIP core clock domain.
set_global_assignment -name OPTIMIZATION_MODE "HIGH PERFORMANCE EFFORT"
set_global_assignment -name OPTIMIZATION_TECHNIQUE SPEED
set_global_assignment -name ROUTER_TIMING_OPTIMIZATION_LEVEL MAXIMUM
set_global_assignment -name PLACEMENT_EFFORT_MULTIPLIER 3.0
set_global_assignment -name ALLOW_REGISTER_DUPLICATION ON
set_global_assignment -name ALLOW_REGISTER_MERGING OFF
