set_global_assignment -entity "debug_sc_system_v3_lvdsctrl" -library "lib_debug_sc_system_v3_lvdsctrl" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "debug_sc_system_v3_lvdsctrl" -library "lib_debug_sc_system_v3_lvdsctrl" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "debug_sc_system_v3_lvdsctrl" -library "lib_debug_sc_system_v3_lvdsctrl" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_debug_sc_system_v3_lvdsctrl" -name SPD_FILE [file join $::quartus(sip_path) "../debug_sc_system_v3_lvdsctrl.spd"]
set_global_assignment -library "lib_debug_sc_system_v3_lvdsctrl" -name MISC_FILE [file join $::quartus(sip_path) "../../debug_sc_system_v3_lvdsctrl.qsys"]

set_global_assignment -library "lib_debug_sc_system_v3_lvdsctrl" -name MISC_FILE [file join $::quartus(sip_path) "debug_sc_system_v3_lvdsctrl.v"]
