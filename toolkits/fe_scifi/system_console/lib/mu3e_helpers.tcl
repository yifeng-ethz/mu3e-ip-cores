###########################################################################################################
# @Name 		mu3e_helpers.tcl
#
# @Brief		Provides the helper functions used in the toolkit environment and _hw.tcl environment.
#
# @Functions	setup_base_group
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Sep 26, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
package provide mu3e::helpers 	1.0
package require dom::tcl 3.0

namespace eval ::mu3e::helpers:: {
	namespace export \
	setup_base_group \
	toolkit_setup_combobox \
	dom_set_node_value \
	configure_project_spec \
	clear_service_preferences

	variable service_preferences
	set service_preferences [dict create]
	 

}

proc ::mu3e::helpers::clear_service_preferences {} {
	variable service_preferences
	set service_preferences [dict create]
	return -code ok
}

proc ::mu3e::helpers::configure_project_spec {project_spec} {
	variable service_preferences

	set service_preferences [dict create]
	foreach key {preferred_link_ids preferred_device_patterns preferred_service_patterns} {
		if {[dict exists $project_spec $key]} {
			dict set service_preferences $key [dict get $project_spec $key]
		}
	}

	return -code ok
}

proc ::mu3e::helpers::service_path_match_rank {text patterns} {
	if {[llength $patterns] == 0} {
		return 0
	}

	set idx 0
	foreach pattern $patterns {
		if {[string first $pattern $text] >= 0} {
			return $idx
		}
		incr idx
	}

	return [expr {[llength $patterns] + 1}]
}

proc ::mu3e::helpers::extract_link_id {spath} {
	if {[regexp {@([^/]*)/} $spath -> link_id]} {
		return $link_id
	}

	return ""
}

proc ::mu3e::helpers::service_path_preference_key {service_type spath} {
	variable service_preferences

	set preferred_link_ids {}
	set preferred_device_patterns {}
	set preferred_service_patterns {}
	if {[dict exists $service_preferences preferred_link_ids]} {
		set preferred_link_ids [dict get $service_preferences preferred_link_ids]
	}
	if {[dict exists $service_preferences preferred_device_patterns]} {
		set preferred_device_patterns [dict get $service_preferences preferred_device_patterns]
	}
	if {[dict exists $service_preferences preferred_service_patterns $service_type]} {
		set preferred_service_patterns [dict get $service_preferences preferred_service_patterns $service_type]
	}

	set link_id [::mu3e::helpers::extract_link_id $spath]
	set link_rank [::mu3e::helpers::service_path_match_rank $link_id $preferred_link_ids]
	set device_rank [::mu3e::helpers::service_path_match_rank $spath $preferred_device_patterns]
	set service_rank [::mu3e::helpers::service_path_match_rank $spath $preferred_service_patterns]

	return [list $link_rank $device_rank $service_rank $spath]
}

proc ::mu3e::helpers::compare_service_paths {service_type lhs rhs} {
	set lhs_key [::mu3e::helpers::service_path_preference_key $service_type $lhs]
	set rhs_key [::mu3e::helpers::service_path_preference_key $service_type $rhs]

	foreach lhs_rank [lrange $lhs_key 0 2] rhs_rank [lrange $rhs_key 0 2] {
		if {$lhs_rank < $rhs_rank} {
			return -1
		}
		if {$lhs_rank > $rhs_rank} {
			return 1
		}
	}

	return [string compare [lindex $lhs_key 3] [lindex $rhs_key 3]]
}

proc ::mu3e::helpers::prioritize_service_paths {service_type spaths} {
	if {[llength $spaths] <= 1} {
		return $spaths
	}

	return [lsort -command [list ::mu3e::helpers::compare_service_paths $service_type] $spaths]
}

######################################################################################################
##  Arguments:
##		<baseGroupName> - name of the base group, in which a new group will be created.
##
##  Description:
##  This function sets up the JTAG group in the toolkit GUI and claim service from user selection.	
##
##	Returns:
##	-code ok	- if the setup has been successful
##
######################################################################################################		
proc ::mu3e::helpers::setup_base_group {baseGroupName} {
    # format the pass-in "setup connection" group
	toolkit_set_property $baseGroupName itemsPerRow 1
    
    # build sub groups
    # row 0
	::mu3e::helpers::toolkit_setup_jtagMaster  $baseGroupName
	# row 1 and 2
    toolkit_add             "row1_group"    group       $baseGroupName
    toolkit_set_property    "row1_group"    itemsPerRow 1
    toolkit_set_property    "row1_group"    title       "JTAG INFO"
	::mu3e::helpers::toolkit_setup_jtagReset  "row1_group" 
	::mu3e::helpers::toolkit_setup_slaveAddress "row1_group" 
    # row 3
    toolkit_add             "io_group"      group       $baseGroupName
    toolkit_set_property    "io_group"      itemsPerRow 2
    toolkit_set_property    "io_group"      title       "Master IO Access"
    ::mu3e::helpers::toolkit_setup_master_io_access "io_group"
	
	return -code ok
}

######################################################################################################
##  Arguments:
##		<baseGroupName> - name of the base group, in which a new group will be created.
##
##  Description:
##  This function sets up the "JTAG to Avalon Master Bridge IP group", which can display all master
##	paths. The user are prompted to select one. Upon selection, the master service is claimed and 
##	the global variable 'fd_master_path` is set as the descriptor ticket to gain access to this 
##  opened service.
##
##	Returns:
##	-code ok	- if the setup has been successful
##
######################################################################################################	
proc ::mu3e::helpers::toolkit_setup_jtagMaster {baseGroupName} { 
	
	set childGroupName "jtagMasterGroup"
	toolkit_add 			$childGroupName 	group 		$baseGroupName
	toolkit_set_property	$childGroupName		expandableX	false
	toolkit_set_property	$childGroupName		expandableY	false
	toolkit_set_property	$childGroupName		itemsPerRow 1
	toolkit_set_property	$childGroupName 	title		"JTAG to Avalon Master Bridge IP"
	set showmp_button "${childGroupName}_showmp_button"
	set comboBoxName "${childGroupName}_showmp_comboBox"; # NOTE: must not change, as the callback uses static value
	set openmp_button "${childGroupName}_openmp_button"
	# start to read all service path of master type
	toolkit_add				$showmp_button		button		$childGroupName
	toolkit_set_property	$showmp_button		enabled 	true
	toolkit_set_property	$showmp_button		expandableX false
	toolkit_set_property	$showmp_button		expandableY false
	toolkit_set_property	$showmp_button		text		"Show Alive (master) Service Path "
	toolkit_set_property	$showmp_button		onClick 	\
	{::mu3e::helpers::show_servicePaths4comboBox "master" "jtagMasterGroup_showmp_comboBox"} ; 
	# setup a comboBox 
	toolkit_add				$comboBoxName	comboBox	$childGroupName
	toolkit_set_property	$comboBoxName 	options		"?"
    toolkit_set_property	$comboBoxName 	foregroundColor blue
	toolkit_set_property	$comboBoxName	onChange	\
	{set servicePath2open [::mu3e::helpers::get_selected_servicePath "jtagMasterGroup_showmp_comboBox"]} ; 
	# claim the master service with return of fd
	toolkit_add				$openmp_button		button		$childGroupName
	toolkit_set_property	$openmp_button		text		"Claim Master Path"
	toolkit_set_property	$openmp_button		onClick 	\
	{toolkit_set_property "fd_master_path_text" text [::mu3e::helpers::open_master_service [::mu3e::helpers::get_selected_servicePath "jtagMasterGroup_showmp_comboBox"]]}
	toolkit_add				"fd_master_path_text" text		$childGroupName
	toolkit_set_property	"fd_master_path_text" visible	0
	toolkit_set_property	"fd_master_path_text" text		""
	#puts "debug here: "
	return -code ok
}

proc ::mu3e::helpers::cget_opened_master_path {} {
	return [toolkit_get_property "fd_master_path_text" text]
} 


######################################################################################################
##  Arguments:
##		<baseGroupName> - name of the base group, in which a new group will be created.
##
##  Description:
##  This function sets up the "JTAG DEBUG PHY" group in gui, which can display all jtag_debug
##	paths. The user are prompted to select one. Upon selection and click, without needing to claim,
##	this jtag_debug node will issue reset to the services connected. 
##
##	Returns:
##	-code ok	- if the setup has been successful
##
######################################################################################################
proc ::mu3e::helpers::toolkit_setup_jtagReset {baseGroupName} {
	set childGroupName "resetGroup"
	toolkit_add 			$childGroupName 	group 		$baseGroupName
	toolkit_set_property	$childGroupName		expandableX	false
	toolkit_set_property	$childGroupName		expandableY	false
	toolkit_set_property	$childGroupName		itemsPerRow 1
	toolkit_set_property	$childGroupName 	title		"JTAG DEBUG PHY"
	set showmp_button "${childGroupName}_showmp_button"
	set comboBoxName "${childGroupName}_showmp_comboBox"; # NOTE: must not change, as the callback uses static value
	set reset_button "${childGroupName}_reset_button"
	toolkit_add				$showmp_button		button		$childGroupName
	toolkit_set_property	$showmp_button		enabled 	true
	toolkit_set_property	$showmp_button		expandableX false
	toolkit_set_property	$showmp_button		expandableY false
	toolkit_set_property	$showmp_button		text		"Show Alive (jtag_debug) Service Path "
	toolkit_set_property	$showmp_button		onClick 	\
	{::mu3e::helpers::show_servicePaths4comboBox "jtag_debug" "resetGroup_showmp_comboBox"}
	# setup a comboBox 
	toolkit_add				$comboBoxName	comboBox	$childGroupName
	toolkit_set_property	$comboBoxName 	options		"?"
	toolkit_add				$reset_button	button		$childGroupName
	toolkit_set_property	$reset_button 	text		"Reset the Node"
	toolkit_set_property	$reset_button	onClick 	{jtag_debug_reset_system [::mu3e::helpers::get_selected_servicePath "resetGroup_showmp_comboBox"]}
	return -code ok
}


######################################################################################################
##  Arguments:
##		<baseGroupName> - name of the base group, in which a new group will be created.
##
##  Description:
##  This function sets up the ...
##
##	Returns:
##	-code ok	- if the setup has been successful
##
######################################################################################################
proc ::mu3e::helpers::toolkit_setup_slaveAddress {baseGroupName} {
	set childGroupName "slaveAddressGroup"
	# create a group under setup connection tab
	toolkit_add 			$childGroupName 	group 		$baseGroupName
	toolkit_set_property	$childGroupName		expandableX	false
	toolkit_set_property	$childGroupName		expandableY	false
	toolkit_set_property	$childGroupName		itemsPerRow 1
	toolkit_set_property	$childGroupName 	title		"Node Info"
	# create a button to refresh available service path of the service type (marker)
	toolkit_add				"ShowMarkerPath_button"		button		$childGroupName
	toolkit_set_property	"ShowMarkerPath_button"		text		"Show (marker) service paths"
	toolkit_set_property	"ShowMarkerPath_button"		onClick		{::mu3e::helpers::show_servicePaths4comboBox "marker" "ShowMarkerPath_comboBox"}
	# create a combo box for the user to select the path
	toolkit_add				"ShowMarkerPath_comboBox"	comboBox	$childGroupName
	toolkit_set_property	"ShowMarkerPath_comboBox"	options		"?"
	toolkit_set_property	"ShowMarkerPath_comboBox"	onChange	\
	{set servicePath2mark [::mu3e::helpers::get_selected_servicePath "ShowMarkerPath_comboBox"]} 
	# create a button to print the marker_info of the selected service path
	toolkit_add				"ShowMarkerInfo_button"		button		$childGroupName
	toolkit_set_property	"ShowMarkerInfo_button"		text		"Show marker info"
	toolkit_set_property	"ShowMarkerInfo_button"		onClick		{::mu3e::helpers::show_marker_info [::mu3e::helpers::get_selected_servicePath "ShowMarkerPath_comboBox"] "ShowMarkerInfo_textField" "ShowMarkerPath_comboBox"}
	# create a text field to show this array 
	toolkit_add				"ShowMarkerInfo_textField"	text		$childGroupName
	toolkit_set_property	"ShowMarkerInfo_textField"	visible		0
	toolkit_set_property	"ShowMarkerInfo_textField"	editable	0
	toolkit_set_property	"ShowMarkerInfo_textField"	htmlCapable	1
	
	# create a sub group for auto-link slaves
	toolkit_add 			"autoLinkGroup" 	group 		$childGroupName
	toolkit_set_property	"autoLinkGroup"		expandableX	false
	toolkit_set_property	"autoLinkGroup"		expandableY	false
	toolkit_set_property	"autoLinkGroup"		itemsPerRow 2
	toolkit_set_property	"autoLinkGroup" 	title		"Auto Link"
	# create a button to start auto link 
	toolkit_add				"autoLink_button"	button		"autoLinkGroup"
	toolkit_set_property	"autoLink_button"	text		"link slaves"
	toolkit_set_property	"autoLink_button"	onClick		{::mu3e::helpers::link_slave}
	# create a small report text
	toolkit_add				"autoLink_text"		textField		"autoLinkGroup"
	#toolkit_set_property	"autoLink_text"		htmlCapable	0
	toolkit_set_property	"autoLink_text"		text		"not set yet"
	toolkit_set_property	"autoLink_text"		editable	0
    # create a button to for revisit
	toolkit_add				"autoLinkRV_button"	button		"autoLinkGroup"
	toolkit_set_property	"autoLinkRV_button"	text		"revisit"
	toolkit_set_property	"autoLinkRV_button"	onClick		{::mu3e::helpers::link_slave_revisit_callback}
    
	
	return -code ok
}


proc ::mu3e::helpers::toolkit_setup_master_io_access {baseGroupName} {
    set address_to_read     0x0
    set read_data           "?"
    set address_to_write    0x0
    set data_to_write       0x0
    set write_status        "?"
    ##### Read Group ######
    toolkit_add 			readGroup 	group 		$baseGroupName
    toolkit_set_property	readGroup	expandableX	false
    toolkit_set_property	readGroup	expandableY	false
    toolkit_set_property	readGroup	itemsPerRow 1
    toolkit_set_property	readGroup 	title		"Read 32 bit (Byte-Addressing)"
    
    # text box for input address
    toolkit_add				address_of_read		text			readGroup
    toolkit_set_property	address_of_read		expandableX		true
    toolkit_set_property	address_of_read		preferredWidth	100
    toolkit_set_property	address_of_read		preferredHeight	10
    toolkit_set_property	address_of_read		editable		true
    toolkit_set_property	address_of_read		text			$address_to_read
    
    # button to start read
    toolkit_add				startRead	button		readGroup
    toolkit_set_property	startRead	enabled 	true
    toolkit_set_property	startRead	expandableX false
    toolkit_set_property	startRead	expandableY false
    toolkit_set_property	startRead	text		"Set Address and Read"
    toolkit_set_property	startRead	onClick 	\
    { ::mu3e::helpers::read_this_address [toolkit_get_property address_of_read text] "readData"}
    
    # text box for read data (display)
    toolkit_add				readData		textField		readGroup
    toolkit_set_property	readData		expandableX		true
    toolkit_set_property	readData		preferredWidth	100
    toolkit_set_property	readData		preferredHeight	10
    toolkit_set_property	readData		editable		false
    toolkit_set_property	readData        foregroundColor blue
    toolkit_set_property	readData		text			$read_data
                                                                                                                                            
    ###### Write Group ######
    toolkit_add 			writeGroup 	group 		$baseGroupName
    toolkit_set_property	writeGroup	expandableX	false
    toolkit_set_property	writeGroup	expandableY	false
    toolkit_set_property	writeGroup	itemsPerRow 1
    toolkit_set_property	writeGroup 	title		"Write 32 bit (Byte-Addressing)"

    
    # text box for input address
    toolkit_add 			writeaddrGroup 	group 		writeGroup
    toolkit_set_property	writeaddrGroup	expandableX	false
    toolkit_set_property	writeaddrGroup	expandableY	false
    toolkit_set_property	writeaddrGroup	itemsPerRow 1
    toolkit_set_property	writeaddrGroup 	title		"Write Address"
    
    toolkit_add				address_of_write		text			writeaddrGroup
    toolkit_set_property	address_of_write		expandableX		true
    toolkit_set_property	address_of_write		preferredWidth	100
    toolkit_set_property	address_of_write		preferredHeight	10
    toolkit_set_property	address_of_write		editable		true
    toolkit_set_property	address_of_write		text			$address_to_write
    toolkit_set_property	address_of_write		toolTip			"Write Address"
    
    # text box for input write data
    toolkit_add 			writedataGroup 	group 		writeGroup
    toolkit_set_property	writedataGroup	expandableX	false
    toolkit_set_property	writedataGroup	expandableY	false
    toolkit_set_property	writedataGroup	itemsPerRow 1
    toolkit_set_property	writedataGroup 	title		"Write Data"
    
    toolkit_add				data_of_write		text			writedataGroup
    toolkit_set_property	data_of_write		expandableX		true
    toolkit_set_property	data_of_write		preferredWidth	100
    toolkit_set_property	data_of_write		preferredHeight	10
    toolkit_set_property	data_of_write		editable		true
    toolkit_set_property	data_of_write		text			$data_to_write
    toolkit_set_property	data_of_write		toolTip			"Write Data"
    
    # button to start write
    toolkit_add				startRead	button		writeGroup
    toolkit_set_property	startRead	enabled 	true
    toolkit_set_property	startRead	expandableX false
    toolkit_set_property	startRead	expandableY false
    toolkit_set_property	startRead	text		"Set Address/Data to Write"
    toolkit_set_property	startRead	onClick 	\
    { ::mu3e::helpers::write_this_address [toolkit_get_property address_of_write text] [toolkit_get_property data_of_write text] "writeValidation"}
    
    # text box for write data (readback validation)
    toolkit_add				writeValidation		textField		writeGroup
    toolkit_set_property	writeValidation		expandableX		true
    toolkit_set_property	writeValidation		preferredWidth	100
    toolkit_set_property	writeValidation		preferredHeight	10
    toolkit_set_property	writeValidation		editable		false
    toolkit_set_property	writeValidation     foregroundColor blue
    toolkit_set_property	writeValidation		text			$write_status
    return -code ok
}

proc ::mu3e::helpers::read_this_address {addr displayTextBox} {
    set mpath [::mu3e::helpers::cget_opened_master_path]
    set rd_data [master_read_32 $mpath $addr 1]
    toolkit_set_property $displayTextBox text $rd_data
    return -code ok 
}

proc ::mu3e::helpers::write_this_address {addr data displayTextBox} {
    set mpath [::mu3e::helpers::cget_opened_master_path]
    # step 1: write
    master_write_32 $mpath $addr $data 
    # step 2: readback
    set rd_data [master_read_32 $mpath $addr 1]
    if {$rd_data == $data} {
        toolkit_set_property $displayTextBox text "ok"
        toolkit_set_property $displayTextBox backgroundColor green
    } else {
        toolkit_set_property $displayTextBox text "error"
        toolkit_set_property $displayTextBox backgroundColor red
        toolkit_send_message warning "write_this_address: readback (${rd_data}) mismatch with written data (${data}) to address (${addr})!"
    }
    return -code ok 
}





proc ::mu3e::helpers::normalize_base_address {base_value} {
    if {[scan $base_value %i parsed_value] != 1} {
        return ""
    }

    return [format "0x%08x" [expr {$parsed_value & 0xffffffff}]]
}

proc ::mu3e::helpers::compare_inventory_entry_bases {lhs rhs} {
    set lhs_base [dict get $lhs base]
    set rhs_base [dict get $rhs base]
    scan $lhs_base %i lhs_value
    scan $rhs_base %i rhs_value

    if {$lhs_value < $rhs_value} {
        return -1
    }
    if {$lhs_value > $rhs_value} {
        return 1
    }

    return [string compare [dict get $lhs hpath] [dict get $rhs hpath]]
}

proc ::mu3e::helpers::compiled_slave_inventory {} {
    if {[llength [info commands ::data_path_bts::gui::compiled_slave_inventory]] == 0} {
        return ""
    }

    if {[catch {::data_path_bts::gui::compiled_slave_inventory} compiled_inventory]} {
        toolkit_send_message warning "link_slave: unable to read compiled .sopcinfo inventory: $compiled_inventory"
        return ""
    }

    return $compiled_inventory
}

proc ::mu3e::helpers::collect_live_marker_inventory {link_id expected_types} {
    set live_inventory [dict create]
    set seen_entries [dict create]

    foreach path [get_service_paths marker] {
        if {![string match "*@$link_id/*" $path]} {
            continue
        }

        array set minfo [marker_get_info $path]
        if {![info exists minfo(TYPE_NAME)] || ![info exists minfo(BASE_ADDRESS)]} {
            continue
        }

        set type_name $minfo(TYPE_NAME)
        if {[lsearch -exact $expected_types $type_name] < 0} {
            continue
        }

        set base_address [::mu3e::helpers::normalize_base_address $minfo(BASE_ADDRESS)]
        if {$base_address eq ""} {
            continue
        }

        set hpath ""
        if {[info exists minfo(FULL_HPATH)]} {
            set hpath $minfo(FULL_HPATH)
        }

        set dedupe_key [format "%s|%s|%s" $type_name $base_address $hpath]
        if {[dict exists $seen_entries $dedupe_key]} {
            continue
        }
        dict set seen_entries $dedupe_key 1
        dict lappend live_inventory $type_name [dict create base $base_address hpath $hpath]
    }

    foreach type_name [dict keys $live_inventory] {
        dict set live_inventory $type_name [lsort -command ::mu3e::helpers::compare_inventory_entry_bases [dict get $live_inventory $type_name]]
    }

    return $live_inventory
}

proc ::mu3e::helpers::set_link_slave_status {status} {
    switch -- $status {
        FALLBACK {
            toolkit_set_property "autoLink_text" text "FALLBACK"
            toolkit_set_property "autoLink_text" backgroundColor "yellow"
            toolkit_set_property "autoLink_text" foregroundColor "black"
        }
        MISMATCH {
            toolkit_set_property "autoLink_text" text "MISMATCH"
            toolkit_set_property "autoLink_text" backgroundColor "yellow"
            toolkit_set_property "autoLink_text" foregroundColor "black"
        }
        ERROR {
            toolkit_set_property "autoLink_text" text "ERROR"
            toolkit_set_property "autoLink_text" backgroundColor "red"
            toolkit_set_property "autoLink_text" foregroundColor "black"
        }
        CONFLICT {
            toolkit_set_property "autoLink_text" text "CONFLICT"
            toolkit_set_property "autoLink_text" backgroundColor "yellow"
            toolkit_set_property "autoLink_text" foregroundColor "black"
        }
        default {
            toolkit_set_property "autoLink_text" text "OK"
            toolkit_set_property "autoLink_text" backgroundColor "green"
            toolkit_set_property "autoLink_text" foregroundColor "black"
        }
    }
}

proc ::mu3e::helpers::link_slave_from_compiled_inventory {compiled_inventory} {
    set fd_global_variable "globalVariableTable"
    set link_id [::mu3e::helpers::get_global_variable $fd_global_variable "link_id"]
    set expected_by_type [dict get $compiled_inventory by_type]
    set expected_types [lsort [dict keys $expected_by_type]]
    set live_inventory [::mu3e::helpers::collect_live_marker_inventory $link_id $expected_types]
    set source_path [dict get $compiled_inventory source]
    set mismatch_count 0
    set mismatch_types [list]
    set mismatch_details [list]

    if {[catch {::mu3e::helpers::append_global_variable $fd_global_variable "conflict_slaves" ""}]} {
        ::mu3e::helpers::set_global_variable $fd_global_variable "conflict_slaves" [list]
    } else {
        ::mu3e::helpers::set_global_variable $fd_global_variable "conflict_slaves" [list]
    }

    if {[::mu3e::helpers::probe_global_variable $fd_global_variable "slaves"]} {
        ::mu3e::helpers::set_global_variable $fd_global_variable "slaves" $expected_types
    }

    toolkit_send_message info "link_slave: validating live marker addresses against compiled project [file tail $source_path]"

    if {[dict size $live_inventory] == 0} {
        foreach type_name $expected_types {
            set expected_bases [list]
            foreach entry [dict get $expected_by_type $type_name] {
                lappend expected_bases [dict get $entry base]
            }

            if {[::mu3e::helpers::probe_global_variable $fd_global_variable "${type_name}_copies"]} {
                ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_copies" [llength $expected_bases]
            }

            if {[catch {::mu3e::helpers::append_global_variable $fd_global_variable "${type_name}_hpaths" ""}]} {
                ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_hpaths" [list]
            } else {
                ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_hpaths" [list]
            }
            if {[::mu3e::helpers::probe_global_variable $fd_global_variable "${type_name}_base_address"]} {
                ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_base_address" $expected_bases
            }
        }
        toolkit_send_message warning "link_slave: no typed datapath slave services were discovered on link ${link_id}. Falling back to the compiled address map from [file tail $source_path]; live marker validation is unavailable in this session. Check project auto-link or firmware if register access fails."
        ::mu3e::helpers::set_link_slave_status FALLBACK
        return -code ok
    }

    foreach type_name $expected_types {
        set expected_entries [dict get $expected_by_type $type_name]
        set actual_entries [list]
        if {[dict exists $live_inventory $type_name]} {
            set actual_entries [dict get $live_inventory $type_name]
        }

        set expected_bases [list]
        foreach entry $expected_entries {
            lappend expected_bases [dict get $entry base]
        }

        set actual_by_base [dict create]
        set actual_bases [list]
        foreach entry $actual_entries {
            set actual_base [dict get $entry base]
            lappend actual_bases $actual_base
            dict set actual_by_base $actual_base $entry
        }

        set missing_bases [list]
        set extra_bases [list]
        set matched_bases [list]
        set matched_hpaths [list]

        foreach expected_base $expected_bases {
            if {[dict exists $actual_by_base $expected_base]} {
                set match_entry [dict get $actual_by_base $expected_base]
                lappend matched_bases $expected_base
                lappend matched_hpaths [dict get $match_entry hpath]
            } else {
                lappend missing_bases $expected_base
            }
        }

        foreach actual_base $actual_bases {
            if {[lsearch -exact $expected_bases $actual_base] < 0} {
                lappend extra_bases $actual_base
            }
        }

        if {[::mu3e::helpers::probe_global_variable $fd_global_variable "${type_name}_copies"]} {
            ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_copies" [llength $expected_bases]
        }

        if {[catch {::mu3e::helpers::append_global_variable $fd_global_variable "${type_name}_hpaths" ""}]} {
            ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_hpaths" $matched_hpaths
        } else {
            ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_hpaths" $matched_hpaths
        }

        if {[::mu3e::helpers::probe_global_variable $fd_global_variable "${type_name}_base_address"]} {
            ::mu3e::helpers::set_global_variable $fd_global_variable "${type_name}_base_address" $matched_bases
        }

        if {[llength $missing_bases] > 0 || [llength $extra_bases] > 0} {
            incr mismatch_count
            lappend mismatch_types $type_name
            lappend mismatch_details "${type_name}: expected bases ${expected_bases}, live bases ${actual_bases}, missing ${missing_bases}, unexpected ${extra_bases}"
        }
    }

    if {$mismatch_count > 0} {
        ::mu3e::helpers::set_link_slave_status MISMATCH
        toolkit_send_message warning "link_slave: compiled project [file tail $source_path] does not match the live marker inventory on link ${link_id}. Mismatched slaves: [join $mismatch_types {, }]. This usually means an old firmware image or the wrong connection."
        foreach detail $mismatch_details {
            toolkit_send_message info "link_slave detail: $detail"
        }
    } else {
        ::mu3e::helpers::set_link_slave_status OK
        toolkit_send_message info "link_slave: live marker inventory matches compiled project [file tail $source_path] on link ${link_id}"
    }

    return -code ok
}

proc ::mu3e::helpers::link_slave_legacy {} {
	set fd_global_variable "globalVariableTable"; # must be the same name as the gui
    set link_id [::mu3e::helpers::get_global_variable $fd_global_variable "link_id"]; # get the link_id
    if {[catch {::mu3e::helpers::append_global_variable $fd_global_variable "conflict_slaves" ""}]} {
        ::mu3e::helpers::set_global_variable $fd_global_variable "conflict_slaves" [list]; # init the conflict slaves list
        toolkit_send_message warning "link_slave: error appending conflict slaves list, init it to empty list."
    }
	set slave_list [::mu3e::helpers::get_global_variable $fd_global_variable "slaves"]; # get the list of slaves
	set spaths [get_service_paths marker]
    set err 0
	# loop over all slave, for each slave loop over all paths
	foreach slave $slave_list {
        # 0) init...
        set base_addresses [list]
        set occurance_count 0
        set slave_hpaths [list]
        if {[catch {::mu3e::helpers::append_global_variable $fd_global_variable "${slave}_hpaths" ""}]} {
            ::mu3e::helpers::set_global_variable $fd_global_variable "${slave}_hpaths" [list]
            toolkit_send_message warning "link_slave: error appending ${slave}_hpaths, init to empty list."
        }
		# 1) set the required occurance 
        if {[::mu3e::helpers::probe_global_variable $fd_global_variable "${slave}_copies"]} {
            set occurance [::mu3e::helpers::get_global_variable $fd_global_variable "${slave}_copies"]
        } else {
            set occurance 1
        }
        # 2) iterate through the the whole "marker" service paths
		set set_count 0
        set occurance_actual 0
		foreach path $spaths {
            if {![string match "*@$link_id/*" $path]} {
                continue
            }
			array set minfo [marker_get_info $path]
            # 2.1) no TYPE_NAME (usually it is a device root)
			if {![info exists minfo(TYPE_NAME)]} {
				continue
            # 2.2) exist TYPE_NAME
			} else {
                # 2.2.1) found in the required "slaves" list? 
				if {[string equal $minfo(TYPE_NAME) $slave]} {
                    # yes! : 
                    # 1) increase occurance_actual 
                    incr occurance_actual
                    # 2) record the hpath for callback if needed in case of wrong occurance counts
                    lappend slave_hpaths $minfo(FULL_HPATH)
				}
			}
		}
        # store hpaths -> gv_table 
        ::mu3e::helpers::set_global_variable $fd_global_variable "${slave}_hpaths" $slave_hpaths
         
        
        # 3) report errors
        set conflict [expr $occurance_actual > $occurance]
        set less [expr $occurance_actual < $occurance]
        if {$conflict} {
            # 0) init...
            set comboBox_hpaths [::mu3e::helpers::get_global_variable $fd_global_variable "${slave}_hpaths"]
            # 1) report 
            toolkit_send_message warning "link_slave: found ($occurance_actual) of ($occurance) required \"${slave}\" under connected marker paths, you need to manually select ones you wish to connect in this console. "
            # 2) create gui group 
            # slave group
            toolkit_add	"autoLinkConflictGroup_${slave}" group "autoLinkGroup"
            toolkit_set_property "autoLinkConflictGroup_${slave}" itemsPerRow 2
            toolkit_set_property "autoLinkConflictGroup_${slave}" expandableX true
            toolkit_set_property "autoLinkConflictGroup_${slave}" title "${slave} options"
            toolkit_set_property "autoLinkConflictGroup_${slave}" visible 1
            # slave group - checkBoxes (pair of checkBox and hpath text field)
            for {set i 0} {$i < $occurance_actual} {incr i} {
                toolkit_add "autoLinkConflictCheckBox_${slave}_$i" checkBox "autoLinkConflictGroup_${slave}"
                toolkit_add "autoLinkConflictText_${slave}_$i" text "autoLinkConflictGroup_${slave}"
                toolkit_set_property "autoLinkConflictText_${slave}_$i" text [lindex $comboBox_hpaths $i]
                toolkit_set_property "autoLinkConflictText_${slave}_$i" editable false 
                toolkit_set_property "autoLinkConflictText_${slave}_$i" foregroundColor blue
            }
            # 3) append conf_slave -> gv_table
            set conf_slaves [::mu3e::helpers::get_global_variable $fd_global_variable "conflict_slaves"]
            lappend conf_slaves $slave 
            ::mu3e::helpers::set_global_variable $fd_global_variable "conflict_slaves" $conf_slaves
            set err -1
            continue 
            
        }
        if {$less} {
            toolkit_send_message error "link_slave: found ($occurance_actual) of ($occurance) required \"${slave}\" under connected marker paths, you need to check the jtag connections and confirm firmware is loaded. "
            set err -2
            continue 
        }
        
        # 4) if reach this point: no errors, we can write base address to gv_table
        set set_hpaths [::mu3e::helpers::get_global_variable $fd_global_variable "${slave}_hpaths"]
        # 4.1) find all base address(es)
        for {set i 0} {$i < $occurance_actual} {incr i} {
            # iterate the whole "marker" paths to set the base address 
            foreach path $spaths {
                if {![string match "*@$link_id/*" $path]} {
                    continue
                }
                array set minfo [marker_get_info $path]
                # no FULL_HPATH (usually it is a device root)
                if {![info exists minfo(FULL_HPATH)]} {
                    continue
                }
                if {![info exists minfo(TYPE_NAME)]} {
                    continue
                }
                if {[string equal $minfo(FULL_HPATH) [lindex $set_hpaths $i]] && [string equal $minfo(TYPE_NAME) $slave]} {
                    lappend base_addresses [format 0x%x $minfo(BASE_ADDRESS)]
                    break
                }
                
            }
        }
        # 4.2) store base_addr -> gv_table
        ::mu3e::helpers::set_global_variable $fd_global_variable "${slave}_base_address" $base_addresses

    # end of each slave
    }
    
    # 5) set the color box 
    if {[expr $err == -2]} {
        toolkit_set_property	"autoLink_text"		text		"ERROR"
        toolkit_set_property	"autoLink_text"		backgroundColor	"red"
        toolkit_set_property	"autoLink_text"		foregroundColor	"black"
    }
    if {[expr $err == -1]} {
        toolkit_set_property	"autoLink_text"		text		"CONFLICT"
        toolkit_set_property	"autoLink_text"		backgroundColor	"yellow"
        toolkit_set_property	"autoLink_text"		foregroundColor	"black"
    }
    if {[expr $err == 0]} {
        toolkit_set_property	"autoLink_text"		text		"OK"
        toolkit_set_property	"autoLink_text"		backgroundColor	"green"
        toolkit_set_property	"autoLink_text"		foregroundColor	"black"
    }
    
    return -code ok
}    

proc ::mu3e::helpers::link_slave {} {
    set compiled_inventory [::mu3e::helpers::compiled_slave_inventory]
    if {$compiled_inventory ne ""} {
        return [::mu3e::helpers::link_slave_from_compiled_inventory $compiled_inventory]
    }

    return [::mu3e::helpers::link_slave_legacy]
}

proc ::mu3e::helpers::link_slave_revisit_callback {} {
    if {[::mu3e::helpers::compiled_slave_inventory] ne ""} {
        return [::mu3e::helpers::link_slave]
    }

    set fd_global_variable "globalVariableTable"; # must be the same name as the gui
	set conf_slave_list [::mu3e::helpers::get_global_variable $fd_global_variable "conflict_slaves"]
	set spaths [get_service_paths marker]
    set link_id [::mu3e::helpers::get_global_variable $fd_global_variable "link_id"]; # get the link_id
    set err 0
    foreach conf_slave $conf_slave_list {
        set hpath2set [list]
        set base_addresses [list]
        # 1) calculate occurance count again here
        set occurance_actual 0
		foreach path $spaths {
            if {![string match "*@$link_id/*" $path]} {
                continue
            }
			array set minfo [marker_get_info $path]
            # no TYPE_NAME (usually it is a device root)
			if {![info exists minfo(TYPE_NAME)]} {
				continue
            # exist TYPE_NAME
			} else {
                # found in the required "conf_slave" list? 
				if {[string equal $minfo(TYPE_NAME) $conf_slave]} {
                    # yes! : 
                    # increase occurance_actual 
                    incr occurance_actual
				}
			}
		}
        
        # 2) see if this hpath associated check box has been checked  
        for {set i 0} {$i < $occurance_actual} {incr i} {
            if {[toolkit_get_property "autoLinkConflictCheckBox_${conf_slave}_$i" checked]} {
                lappend hpath2set [toolkit_get_property "autoLinkConflictText_${conf_slave}_$i" text]
            }
        }
        
        # 3) set the hpath 
        foreach hp $hpath2set {
            foreach path $spaths {
                if {![string match "*@$link_id/*" $path]} {
                    continue
                }
                array set minfo [marker_get_info $path]
                # no FULL_HPATH
                if {![info exists minfo(FULL_HPATH)]} {
                    continue
                }
                # no TYPE_NAME
                if {![info exists minfo(TYPE_NAME)]} {
                    continue
                }
                # found in the required "hpath2set" list? 
                if {[string equal $minfo(FULL_HPATH) $hp] && [string equal $minfo(TYPE_NAME) $conf_slave]} {
                    lappend base_addresses [format 0x%x $minfo(BASE_ADDRESS)]
                }  
            }
        }
        
        # 4) store address(es) -> gv_table 
        ::mu3e::helpers::set_global_variable $fd_global_variable "${conf_slave}_base_address" $base_addresses
        # 5) check if the correct amount of base address is set 
        # get the required occurance 
        if {[::mu3e::helpers::probe_global_variable $fd_global_variable "${conf_slave}_copies"]} {
            set occurance [::mu3e::helpers::get_global_variable $fd_global_variable "${conf_slave}_copies"]
        } else {
            set occurance 1
        }
        if {[expr [llength $base_addresses] == $occurance]} {
            toolkit_send_message info "link_slave_revisit_callback: slave base address(es) \"$conf_slave\" is set."
        } else {
            toolkit_send_message warning "link_slave_revisit_callback: slave ($conf_slave) requires ($occurance) but you set ([llength $base_addresses]). Please resolve it and click \"revisit\" buttun again."
            incr err 
        }
    }
    if {[expr $err == 0]} {
        toolkit_set_property	"autoLink_text"		text		"OK"
        toolkit_set_property	"autoLink_text"		backgroundColor	"green"
        toolkit_set_property	"autoLink_text"		foregroundColor	"black"
        return -code ok 
    }
    if {[expr $err > 0]} {
        toolkit_set_property	"autoLink_text"		text		"CONFLICT"
        toolkit_set_property	"autoLink_text"		backgroundColor	"yellow"
        toolkit_set_property	"autoLink_text"		foregroundColor	"black"
    }
}


proc ::mu3e::helpers::show_marker_info {service_path textFieldName comboBoxName} {
	array set comboBox_dimension [toolkit_get_widget_dimensions $comboBoxName]; # ex: width 853 height 24
	array set minfo [marker_get_info $service_path]
	set html_text ""
	foreach index [array names minfo] {
		append html_text "$index = $minfo(${index})<br>"
	}
	#puts $html_text
	toolkit_set_property $textFieldName	text $html_text
	toolkit_set_property $textFieldName visible 1
	toolkit_set_property $textFieldName maxWidth $comboBox_dimension(width)
	toolkit_set_property $textFieldName expandableX 1
	return -code ok 
}





######################################################################################################
##  Arguments:
##		<service_type> - type of services to probe (use 'get_service_types` to list all types)
##		<comboBoxName> - name of the comboBox to display the probe result
##
##  Description:
##	Probe the selected service and display the available service path associated with the connected
##	devices. 
##  
##	Returns:
##	-code ok	- if functions are successfully performed
##
######################################################################################################
proc ::mu3e::helpers::show_servicePaths4comboBox {service_type comboBoxName} {
	set spaths [get_service_paths $service_type]
	if {[llength $spaths] == 0} {
		toolkit_set_property $comboBoxName options "?"
		toolkit_send_message warning "show_servicePaths4comboBox: no live \"$service_type\" service paths found"
		return -code ok
	}
	set spaths [::mu3e::helpers::prioritize_service_paths $service_type $spaths]
	set selected_path ""
	if {![catch {toolkit_get_property $comboBoxName selectedItem} current_selection] && $current_selection ne "" && $current_selection ne "?" && [lsearch -exact $spaths $current_selection] >= 0} {
		set selected_path $current_selection
	} else {
		set selected_path [lindex $spaths 0]
	}
	toolkit_set_property $comboBoxName options $spaths
	toolkit_set_property $comboBoxName selectedItem $selected_path
	return -code ok
}


######################################################################################################
##  Arguments:
##		<comboBoxName> - name of the comboBox to retrieve the user selection
##
##  Description:
##	This function retrieves currently user selected item from a given comboBox. 
##  
##	Returns:
##	selected item in string 
##
######################################################################################################
proc ::mu3e::helpers::get_selected_servicePath {comboBoxName} {
	return [toolkit_get_property $comboBoxName selectedItem]
}


######################################################################################################
##  Arguments:
##		<spath> - service path to claim
##
##  Description:
##	This function claims the master service from the input service path. It returns the descriptor.
##  It also stores the link id to global variable `link_id`
##
##	**NOTE**: 
##  It ignores old opened service. Repetitively calling this function will result in multiple 
##  fd opened and returned. 
##  
##	Returns:
##  file descriptor of the claimed service 
##
######################################################################################################
proc ::mu3e::helpers::open_master_service {spath} {
	# ignore the old opened services, but you can see them by uncomment the line below
	# puts [get_claimed_services mylib]
    set fd_global_variable "globalVariableTable"; # must be the same name as the gui
    set fd_master_path [claim_service master $spath mylib ""]; # claim the master service
    if [regexp {@([^/]*)/\(link\)/JTAG} $spath -> link_id] {
        toolkit_send_message info "open_master_service: link_id is $link_id"
    } else {
        toolkit_send_message error "open_master_service: link_id not found in $spath"
        toolkit_send_message warning "open_master_service: please check the service path, it should be like /myservice/(link)/JTAG"
        return -code error "link_id not found in $spath"
    }
    # check if the link_id is already set
    if {[::mu3e::helpers::probe_global_variable $fd_global_variable "link_id"]} {
        # found : overwrite it
        ::mu3e::helpers::set_global_variable $fd_global_variable "link_id" $link_id
    } else {
        # no found : set it
        ::mu3e::helpers::append_global_variable $fd_global_variable "link_id" $link_id
    }
	return $fd_master_path
}

proc ::mu3e::helpers::open_monitor_service {} {
    return [claim_service monitor [get_service_paths monitor] mylib ""]
}

######################################################################################################
##  Arguments:
##		<parentGroupName> - name of parent group to plot in
##		<comboBoxName> - name of the comboBox will be created
##		<range> - inclusive range of the comboBox, format example: [list -2 10]
##		<default_value> - default value of the comboBox 
##		<labelName> - label of the comboBox, displayed in the gui
##
##  Description:
##	This function creates a comboBox with defined range and default value. 
##
##	Returns:
##  -code ok 	- if created successfully
##
######################################################################################################
proc ::mu3e::helpers::toolkit_setup_combobox {parentGroupName comboBoxName range default_value labelName} {
	toolkit_add				$comboBoxName	comboBox	$parentGroupName
	set lo [lindex $range 0]
	set hi [lindex $range 1]
	set range_list {}
	for {set i $lo} {$i <= $hi} {incr i} {
		lappend range_list $i
	}
	toolkit_set_property	$comboBoxName	options		$range_list
	toolkit_set_property	$comboBoxName	label		$labelName
    toolkit_set_property    $comboBoxName   selectedItem $default_value
	return -code ok
}

proc ::mu3e::helpers::dom_set_node_value {node_token value} {
	set node_token_n [::dom::document createTextNode $node_token "value"]
	::dom::node configure $node_token_n -nodeValue $value
	return -code ok 
}


#proc ::mu3e::helpers::dom_get_node {token nodeName} {
#	set ret {}
#	set token [::dom::node child $token]
#	foreach i $token {
#		set name [::dom::node cget $i -nodeName]
#		#puts "node name is: ${name}"
#		if {[string equal $name $nodeName]} {
#			#puts "found it ${nodeName}:"
#			#puts $i
#			lappend ret $i
#		}
#	}
#	return $ret
#}

proc ::mu3e::helpers::parse_reverse_bit_stream {bit_stream} {
	# takes the whole bit stream and parse into a list of word in hex format 
	#puts $bit_stream
	set bit_stream_parsed [split [regexp -all -inline {\d{1,32}} $bit_stream]]
	set i 0
	set words_in_hex {}
	foreach word $bit_stream_parsed {
		#puts stderr "word $i"
		#puts $word
		incr i
		set word_reversed [::mu3e::helpers::string_reverse $word]
		set bytes [split [regexp -all -inline {\d{1,8}} $word_reversed]]
		#puts $bytes
		set word_in_hex "0x"
		foreach byte $bytes {
			set ascii [binary format B8 $byte]
			scan $ascii %c ascii_dec
			set ascii_hex [format %-02x $ascii_dec]
			#puts stderr "byte"
			#puts $ascii_hex
			set word_in_hex $word_in_hex$ascii_hex
		}
		lappend words_in_hex $word_in_hex
		#puts $word_in_hex
	}
	#puts  $words_in_hex
	return $words_in_hex
}

proc ::mu3e::helpers::hex2bin {hex} {
    # example: set hex 0x61626364 (set dec 1633837924)
    # returns -> 01100001011000100110001101100100
    
    # 1) input conversion dec or 0xhex -> hex (without 0x in front) (both hex and dec are allowed)
    if {[regexp {0x} $hex match]} {
        # input is hex: do not touch
    } else {
        # input is dec: convert to hex
        set hex [format "0x%x" $hex]
    }
    # get rid of "0x" in front, regard it as hex anyways
    set hex [string map {"0x" ""} $hex]
    #puts "hex2bin: $hex"
    set length [string length $hex]
    
    # 2) pad to 4 digits 
    while {[expr [string length $hex]%4] != 0} {
        set hex "0$hex"
    }
    #puts $hex
    # 3) hex -> bit stream
    set true_hex [binary format H* $hex]
    binary scan $true_hex B* bits
    # trim for upper 4 bits in case of strange error (4 -> 0100 0000), so we remove the lower 4 bits
    if {[expr [string length $hex] == 1]} {
        #puts "before trim: $bits"
        set bits [::mu3e::helpers::binary_trim $bits 0 3]
        #puts "after trim: $bits"
    }
    #puts "bits: $bits"
    return $bits
}



proc ::mu3e::helpers::hex2dec {hex} {
    # example: 0x305 -> 773
    if {[regexp {0x} $hex match]} {
        return [format "%d" $hex]
    } else {
        error "hex2dec: you input ${hex} format is not hex"
    }
}

proc ::mu3e::helpers:hex2signed {hex} {
    set sign [expr {($hex & 0b10000000000000000000000000000000)}]
    set mag  [expr {($hex & 0b01111111111111111111111111111111)}]
    if {$sign == 0} {
        set exp 0
    } else {
        set exp [expr -2**31]
    }  
    set ret [expr {$exp + $mag}]
    return $ret
}

proc ::mu3e::helpers::binary_trim {bit_stream trimL trimH} {
    # big endien: 0 1 2 3 4 5 ... 31
    set parsed [split [regexp -all -inline {\d{1,1}} $bit_stream]]
    set bit_pos 0
    set ret ""
    foreach bit $parsed {
        if {$bit_pos >= $trimL && $bit_pos <= $trimH} {
            set ret ${ret}${bit}
        }
        incr bit_pos 
    }
    return $ret
}

proc ::mu3e::helpers::binary_trim_little_endien {bit_stream trimL trimH} {
    # little endien: 31 30 29 .... 2 1 0  
    set parsed [split [regexp -all -inline {\d{1,1}} $bit_stream]]
    set bit_pos [expr [llength $parsed]-1]
    set ret ""
    foreach bit $parsed { 
        if {$bit_pos >= $trimL && $bit_pos <= $trimH} { 
            set ret ${ret}${bit}
        }
        incr bit_pos -1
    }
    return $ret
}

proc ::mu3e::helpers::bin2hex {bin} {
    set bin [::mu3e::helpers::string_reverse $bin]
    set bytes [split [regexp -all -inline {\d{1,4}} $bin]]
    set hex ""
    foreach byte $bytes {
        set byte [::mu3e::helpers::string_reverse $byte]
        #puts "byte ->: ${byte}"
        set byte_parsed [split [regexp -all -inline {\d{1,1}} $byte]]
        set len [llength $byte_parsed]
        # pad leading zeros
        for {set i 0} {$i < [expr 4-$len]} {incr i} {
            set byte_parsed [linsert $byte_parsed 0 [expr 0]]
        }
        #puts "byte <-: ${byte_parsed}"
        set value 0
        set bit_pos 3
        foreach bit $byte_parsed {
            set value [expr $value + ${bit}*2**${bit_pos}]
            incr bit_pos -1
        }
        set value [format "%x" $value]
        #puts "byte value: $value"
        set hex $hex$value
    }
    set hex [::mu3e::helpers::string_reverse $hex]
    set hex "0x$hex"
    return $hex
}


######################################################################################################
##  Arguments:
##		<str> - string consists of '1' or '0' bits
##			
##  Description:
##  reverse the string in bit-ordering, for example 000101 -> 101000
##
##	Returns:
##		<res> - revered bit string
##
######################################################################################################
proc ::mu3e::helpers::string_reverse {str} {
	#puts "reversing..."
	#puts "input: $str"
	set res {}
	set i [string length $str]
	while {$i > 0} {append res [string index $str [incr i -1]]}
	#puts "output: $res"
	return $res
}


######################################################################################################
##  Arguments:
##		<tableName> - the name of the table which holds the global variables
##
##  Description:
##  	This function initialize the global variable table
##
##	Returns:
##  	-code ok		- if operation is successful 
##		
######################################################################################################
proc ::mu3e::helpers::init_global_variable {tableName} {
	set size 0
	toolkit_send_message debug "init_global_variable: create global variable table successful!"
	toolkit_add				$tableName	table			self
	toolkit_set_property	$tableName	rowCount		$size
	toolkit_set_property	$tableName	columnCount		2
	toolkit_set_property	$tableName	columnIndex		0
	toolkit_set_property	$tableName	columnHeader	"variable name"
	toolkit_set_property	$tableName	columnIndex		1
	toolkit_set_property	$tableName	columnHeader	"variable value"
	toolkit_set_property	$tableName	visible			false
	return -code ok
}


######################################################################################################
##  Arguments:
##		<tableName> - the name of the table which holds the global variables
##		<variableName> - the name of variable you wish to append
##		<variableValue> - the value of the variable to store 
##
##  Description:
##  	This function append a variable to the global variable table.
##  	The table must be created beforehand and the variable must not already be presented in the table. 
##
##	Returns:
##  	- if the variable is already existed
##			<error_msg> 
##  	- if operation is successful 
##			-code ok
##
######################################################################################################
proc ::mu3e::helpers::append_global_variable {tableName variableName variableValue} {
	set existed 0
	set size [toolkit_get_property $tableName rowCount]
	toolkit_set_property $tableName columnIndex 0
	# search for the variable
	for {set i 0} {$i < $size} {incr i} {
		toolkit_set_property $tableName rowIndex $i
		if {[string equal $variableName [toolkit_get_property $tableName cellText]]} {
			set existed 1
			break
		}
	}
	if {!$existed} { 
		toolkit_set_property $tableName rowCount [expr $size + 1]
		# set var name
		toolkit_set_property $tableName	columnIndex	0
		toolkit_set_property $tableName rowIndex $size
		toolkit_set_property $tableName cellText $variableName
		# set var value
		toolkit_set_property $tableName	columnIndex	1
		toolkit_set_property $tableName rowIndex $size
		toolkit_set_property $tableName cellText $variableValue
        toolkit_set_property $tableName cellEditable true
		return -code ok 
	} else {
		error "append_global_variable: variable \"${variableName}\" already existed, stop."
	}
}

proc ::mu3e::helpers::remove_global_variable {tableName variableName variableValue} {
	
	
}


######################################################################################################
##  Arguments:
##		<tableName> - the name of the table which holds the global variables
##		<variableName> - the name of variable you wish to change its value
##		<variableValue> - the new value of the variable to store 
##
##  Description:
##  	This function searches the global variable table for the specified variable and change its value. 
##
##	Returns:
## 		- if the variable is found in the table
##			-code ok 
##  	- if the variable is NOT found in the table
##			<error_msg> - report the not-found failure
##
######################################################################################################
proc ::mu3e::helpers::set_global_variable {tableName variableName variableValue} {
	set row_cnt [toolkit_get_property $tableName rowCount]
	# iterate through the table and modify the value 
	toolkit_set_property $tableName columnIndex 0
	for {set i 0} {$i < $row_cnt} {incr i} {
		toolkit_set_property $tableName rowIndex $i
		#puts "Row set to $i"
		if {[string equal $variableName [toolkit_get_property $tableName cellText]]} {
			toolkit_set_property $tableName columnIndex 1
			toolkit_set_property $tableName cellText "$variableValue"
			#puts "string found: ${variableName}"
			return -code ok
		}
		if {$i == [expr $row_cnt - 1]} {
			error "set_global_variable: reached the end of the table, \"${variableName}\" not found."
		}
	}
	error "set_global_variable: table \"${tableName}\" is empty."
}


######################################################################################################
##  Arguments:
##		<tableName> - the name of the table which holds the global variables
##		<variableName> - the name of variable you wish to get its value
##
##  Description:
##  	This function searches the global variable table for the specified variable and return its value. 
##
##	Returns:
##  	- if the variable is found in the table
##			value of the global variable 
##  	- if the variable is NOT found in the table
##			<error_msg> - report the not-found failure
##
######################################################################################################
proc ::mu3e::helpers::get_global_variable {tableName variableName} {
	set row_cnt [toolkit_get_property $tableName rowCount]
	# iterate through the table and get the value 
	toolkit_set_property $tableName columnIndex 0
	for {set i 0} {$i < $row_cnt} {incr i} {
		toolkit_set_property $tableName rowIndex $i
		#puts "Row set to $i"
		if {[string equal $variableName [toolkit_get_property $tableName cellText]]} {
			toolkit_set_property $tableName columnIndex 1
			#puts "string found: ${variableName}"
			return [toolkit_get_property $tableName cellText]
		}
		if {$i == [expr $row_cnt - 1]} {
			error "get_global_variable: reached the end of the table, \"${variableName}\" not found."
		}
	}
	error "get_global_variable: table \"${tableName}\" is empty."
}

######################################################################################################
##  Arguments:
##		<tableName> - the name of the table which holds the global variables
##		<variableName> - the name of variable you wish to get its value
##
##  Description:
##  	This function probes if the named variabe exists in the table. 
##
##	Returns:
##  	- if the variable is found in the table
##			count of the occurance, which must be larger than zero
##  	- if the variable is NOT found in the table
##			0
##
######################################################################################################
proc ::mu3e::helpers::probe_global_variable {tableName variableName} {
	set row_cnt [toolkit_get_property $tableName rowCount]
	set ret 0
	# iterate through the table
	toolkit_set_property $tableName columnIndex 0
	for {set i 0} {$i < $row_cnt} {incr i} {
		toolkit_set_property $tableName rowIndex $i
		#puts "Row set to $i"
		if {[string equal $variableName [toolkit_get_property $tableName cellText]]} {
			incr ret
		}
	}
	return $ret
}


proc ::mu3e::helpers::init_register32_value {} {
    set ret ""
    for {set i 0} {$i < 32} {incr i} {
        set ret ${ret}0
    }
    return $ret

}



 
