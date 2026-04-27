package require Tcl 8.5
package require mutrig_controller::gui 1.0
package require mutrig_controller::bsp 24.0; # has to match the IP core year and tag version, format: <year>.<tag>.<month|date>.<build_index>

namespace eval mutrig_controller_bts {} {
	variable n_asic 4
	
	proc main {} {
		variable n_asic
		
		# setup guis
		::mutrig_controller::gui::setup_all $n_asic 
		# source board support package
		
	}
	
#	proc toolkit_setup_onewirePanel { baseGroupName nSensor } {
#		set childGroupName "onewirePanelGroup"
#		toolkit_add 			$childGroupName 	group 		$baseGroupName
#		toolkit_set_property	$childGroupName		expandableX	false
#		toolkit_set_property	$childGroupName		expandableY	false
#		toolkit_set_property	$childGroupName		itemsPerRow 1
#		toolkit_set_property	$childGroupName 	title		"1-Wire Controller Panel"
#		
#		for {set i 0} {$i < $nSensor} {incr i} {
#			set groupName "sensorControlGroup_$i"
#			set textName "sensorReading_$i"
#			toolkit_add				$groupName		group		$childGroupName
#			toolkit_set_property	$groupName		itemsPerRow 1
#			toolkit_set_property	$groupName		title		"sensor #$i"
#			
#			toolkit_add				$textName		text		$groupName
#			toolkit_set_property	$textName		editable	0
#			toolkit_set_property	$textName		preferredHeight	20
#			toolkit_set_property	$textName		preferredWidth	80
#			toolkit_set_property	$textName		text			"? C"
#		}
#		
#	}


}
::mutrig_controller_bts::main
