# settings

# -> Assignments / Settings / Advanced Settings

# implement state machines that can recover gracefully from an illegal state
set_global_assignment -name SAFE_STATE_MACHINE ON
#
# Keep the non-aggressive optimization mode, but restore the surrounding timing
# features so we can spend some of the recovered headroom on timing closure.
set_global_assignment -name OPTIMIZATION_MODE Balanced
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"
set_global_assignment -name OPTIMIZE_MULTI_CORNER_TIMING ON
set_global_assignment -name ADVANCED_PHYSICAL_OPTIMIZATION ON
set_global_assignment -name ALLOW_REGISTER_DUPLICATION ON
set_global_assignment -name ROUTER_LCELL_INSERTION_AND_LOGIC_DUPLICATION Auto
set_global_assignment -name ROUTER_REGISTER_DUPLICATION Auto

# -> Assignments / Settings / VHDL Input

set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008

set_global_assignment -name SAVE_DISK_SPACE OFF
