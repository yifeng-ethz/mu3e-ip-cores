# Tcl package index file, version 1.0

# some helper packages 
package ifneeded mu3e::helpers 1.0 [list source [file join $dir mu3e_helpers.tcl]]
# some gui packages
package ifneeded mutrig_controller::gui 1.0 [list source [file join $dir mutrig_controller_toolkit_gui.tcl]]
package ifneeded data_path_bts::gui 1.0 [list source [file join $dir data_path_toolkit_gui.tcl]]
package ifneeded upload_subsystem_bts::gui 1.0 [list source [file join $dir upload_subsystem_toolkit_gui.tcl]]
# some bsp(packages)
package ifneeded mutrig_controller::bsp 24.0 [list source [file join $dir mutrig_controller_bsp.tcl]]
package ifneeded lvds_rx::bsp 24.0 [list source [file join $dir lvds_rx_bsp.tcl]]
package ifneeded frame_deassembly::bsp 24.0 [list source [file join $dir frame_deassembly_bsp.tcl]]
package ifneeded histogram_statistics::bsp 24.0 [list source [file join $dir histogram_statistics_bsp.tcl]]
package ifneeded mutrig_injector::bsp 24.0 [list source [file join $dir mutrig_injector_bsp.tcl]]
package ifneeded mts_processor::bsp 24.0 [list source [file join $dir mts_processor_bsp.tcl]]
package ifneeded ring_buffer_cam::bsp 26.1 [list source [file join $dir ring_buffer_cam_bsp.tcl]]
package ifneeded feb_frame_assembly::bsp 24.0 [list source [file join $dir feb_frame_assembly_bsp.tcl]]
