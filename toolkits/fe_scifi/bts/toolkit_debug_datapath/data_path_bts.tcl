###########################################################################################################
# @Name 		data_path_bts.tcl
#
# @Brief		Board-Test-System (BTS) of the data path.
#				
#
# @Functions	main: calls gui to setup 
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Oct 22, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 8.5
# some gui packages 
package require data_path_bts::gui 1.0
# some bsp(s)
#package require lvds_controller_pro::bsp 24.0
#package require mutrig_frame_deassembly::bsp 24.0
#package require histogram_statistics::bsp 24.0
# has to match the IP core year and tag version, format: <year>.<tag>.<month|date>.<build_index>

namespace eval data_path_bts {} {
    # global constants
	variable n_asic 8
    variable n_lane 9
	
	proc main {} {
		variable n_asic
        variable n_lane
		
		# setup guis
		::data_path_bts::gui::setup_all $n_asic $n_lane
		# source board support package
        
		return -code ok
	}
}

::data_path_bts::main