# qsys-script recipe for mutrig_datapath_system_v3.qsys.
#
# Keep the internal frame-deassembly output FIFO quiet in Platform Designer:
# the almost_empty status stream is unused by the FEB v3 integration.
package require -exact qsys 16.0

set_instance_parameter_value backpressure_fifo {USE_ALMOST_EMPTY_IF} {0}
save_system
