###########################################################################################################
# @Name 		data_path_toolkit_gui.tcl
#
# @Brief		Setup the GUI, including base tab and config tab for displaying within the system console.
#
# @Functions	setup_all
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Oct 22, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################

package require mu3e::helpers 1.0
package provide data_path_bts::gui 1.0

namespace eval ::data_path_bts::gui:: {
	namespace export \
	setup_all
}

proc ::mutrig_controller::gui::setup_all {n_asic} {
    toolkit_add 			Tab0 			tabbedGroup 		self
	###########################################################
	#  ____           _____ _____ _____   _______       ____  #
	# |  _ \   /\    / ____|_   _/ ____| |__   __|/\   |  _ \ #
	# | |_) | /  \  | (___   | || |         | |  /  \  | |_) |#
	# |  _ < / /\ \  \___ \  | || |         | | / /\ \ |  _ < #
	# | |_) / ____ \ ____) |_| || |____     | |/ ____ \| |_) |#
	# |____/_/    \_\_____/|_____\_____|    |_/_/    \_\____/ #
	#                                                         # 
	########################################################### 
	toolkit_add 			"baseGroup" 	group 				Tab0	
	toolkit_set_property 	"baseGroup" 	title 				"Setup Connections"
	toolkit_set_property 	"baseGroup" 	itemsPerRow 		1
	
	::mu3e::helpers::setup_base_group "baseGroup"

}











