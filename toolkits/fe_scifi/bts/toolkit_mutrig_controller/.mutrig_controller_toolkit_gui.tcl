###########################################################################################################
# @Name 		mutrig_controller_toolkit_gui.tcl
#
# @Brief		Setup the GUI, including base tab and config tab for displaying within the system console.
#
# @Functions	setup_all
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Sep 26, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################

package require mu3e::helpers 1.0
#package provide mutrig_controller::gui 1.0

namespace eval ::mutrig_controller::gui:: {
	namespace export \
	setup_all
}

proc ::mutrig_controller::gui::setup_all {} {
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
	
	
	
	#################################################################################################################
	#    __  __ _    _ _______ _____  _____ _____     _____ ____  _   _ ______ _____ _____    _______       ____    #
	#   |  \/  | |  | |__   __|  __ \|_   _/ ____|   / ____/ __ \| \ | |  ____|_   _/ ____|  |__   __|/\   |  _ \   #
	#   | \  / | |  | |  | |  | |__) | | || |  __   | |   | |  | |  \| | |__    | || |  __      | |  /  \  | |_) |  #
	#   | |\/| | |  | |  | |  |  _  /  | || | |_ |  | |   | |  | | . ` |  __|   | || | |_ |     | | / /\ \ |  _ <   #
	#   | |  | | |__| |  | |  | | \ \ _| || |__| |  | |___| |__| | |\  | |     _| || |__| |     | |/ ____ \| |_) |  #
	#   |_|  |_|\____/   |_|  |_|  \_\_____\_____|   \_____\____/|_| \_|_|    |_____\_____|     |_/_/    \_\____/   #
	#                                                                                                               #
	#################################################################################################################   
	toolkit_add 			"controllerGroup" 	group 			Tab0	
	toolkit_set_property	"controllerGroup"	title			"Config MuTRiG"
	
	::mutrig_controller::gui::setup_config_group "controllerGroup"
	
	
	
}

proc ::mutrig_controller::gui::setup_config_group {groupName} {
	# Generate Config Pattern Group
	toolkit_add 			"controlPanelGroup" group 			$groupName
	toolkit_set_property 	"controlPanelGroup" itemsPerRow		1
	toolkit_set_property	"controlPanelGroup"	title			"Control Panel"

	toolkit_add				"genbitsButton"		button 			$groupName
	toolkit_set_property	"genbitsButton"		text 			"Gen bit pattern"


}