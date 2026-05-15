# qsys-script recipe for scifi_datapath_system_v3.qsys.
#
# Keep this edit in Tcl so Platform Designer owns the system XML state.
package require -exact qsys 16.0

set inst {histogram_statistics_0}

set_instance_parameter_value $inst {ENABLE_PACKET} {false}
set_instance_parameter_value $inst {ENABLE_PINGPONG} {true}
set_instance_parameter_value $inst {SNOOP_EN} {false}

set_instance_parameter_value $inst {VERSION_MAJOR} {26}
set_instance_parameter_value $inst {VERSION_MINOR} {1}
set_instance_parameter_value $inst {VERSION_PATCH} {6}
set_instance_parameter_value $inst {BUILD} {429}
set_instance_parameter_value $inst {VERSION_DATE} {20260429}

save_system
