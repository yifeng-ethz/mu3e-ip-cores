###########################################################################################################
# @Name 		mutrig_controller_toolkit_gui.tcl
#
# @Brief		Setup the GUI, including base tab and config tab for displaying within the system console.
#
# @Functions	setup_all
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Sep 27, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################

package require mu3e::helpers 1.0
package provide mutrig_controller::gui 1.0
package require mutrig_controller::bsp 24.0
package require dom::tcl 3.0
package require tdom

namespace eval ::mutrig_controller::gui:: {
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
	toolkit_set_property 	"controllerGroup" 	itemsPerRow 	2
	
	::mutrig_controller::gui::setup_config_group "controllerGroup" $n_asic
    
    
    # TSA TAB
    toolkit_add 			"tscanGroup" 	group 			Tab0	
	toolkit_set_property	"tscanGroup"	title			"Scan Threshold"
	toolkit_set_property 	"tscanGroup" 	itemsPerRow 	2
	
	::mutrig_controller::gui::setup_tsa_page "tscanGroup" 8
	
	
	#################################################################################################################
	#   _____ _       _           _   __      __        _       _     _         _______       ____  _      ______   #
	#  / ____| |     | |         | |  \ \    / /       (_)     | |   | |       |__   __|/\   |  _ \| |    |  ____|  #
	# | |  __| | ___ | |__   __ _| |   \ \  / /_ _ _ __ _  __ _| |__ | | ___      | |  /  \  | |_) | |    | |__     #
	# | | |_ | |/ _ \| '_ \ / _` | |    \ \/ / _` | '__| |/ _` | '_ \| |/ _ \     | | / /\ \ |  _ <| |    |  __|    #
	# | |__| | | (_) | |_) | (_| | |     \  / (_| | |  | | (_| | |_) | |  __/     | |/ ____ \| |_) | |____| |____   #
	#  \_____|_|\___/|_.__/ \__,_|_|      \/ \__,_|_|  |_|\__,_|_.__/|_|\___|     |_/_/    \_\____/|______|______|  #
	#                                                                                                               #
	#################################################################################################################
	variable fd_global_variable "globalVariableTable"
	::mutrig_controller::gui::init_global_variable  $fd_global_variable
	::mutrig_controller::gui::append_global_variable $fd_global_variable "n_asic" $n_asic
	::mutrig_controller::gui::append_global_variable $fd_global_variable "doc_xml" "empty..."
	::mutrig_controller::gui::append_global_variable $fd_global_variable "slaves" [list "mutrig_controller2.csr" "altera_avalon_onchip_memory2.s1" "mutrig_controller2.scan_result"]
	::mutrig_controller::gui::append_global_variable $fd_global_variable "mutrig_controller2.csr_base_address" 0x0
	::mutrig_controller::gui::append_global_variable $fd_global_variable "mutrig_controller2.csr_encountered" 0
	::mutrig_controller::gui::append_global_variable $fd_global_variable "altera_avalon_onchip_memory2.s1_base_address" 0x0
	::mutrig_controller::gui::append_global_variable $fd_global_variable "altera_avalon_onchip_memory2.s1_encountered" 0
    ::mutrig_controller::gui::append_global_variable $fd_global_variable "mutrig_controller2.scan_result_base_address" 0x0
	::mutrig_controller::gui::append_global_variable $fd_global_variable "mutrig_controller2.scan_result_encountered" 0
	toolkit_set_property	"globalVariableTable" visible 1

	# now its time to write to master
	
	
}
proc ::mutrig_controller::gui::configure_all_chips {} {
	variable fd_global_variable
	# retrieve the number of asic
	if {[catch {set n_asic [::mutrig_controller::gui::get_global_variable $fd_global_variable "n_asic"]} error_msg]} {
		toolkit_send_message error "$error_msg"
		return -code error
	} else {
		toolkit_send_message debug "found this variable! its value is $n_asic"
	}
    
    # get bank and calculate relative asic index
    set bank [toolkit_get_property "bank_comboBox" selectedItem]
    if {[string equal $bank "DOWN"]} {
        set asic_base 4
    } else {
        set asic_base 0
    }
    while {1} {
        toolkit_send_message warning "tx_engine_h2d_data: ////////////////////////////////////////////////"
        toolkit_send_message warning "tx_engine_h2d_data: starting configure..."
        for {set asic $asic_base} {[expr $asic < $n_asic+$asic_base]} {incr asic} { 
            set asic_relative [expr $asic%4]
            ::mutrig_controller::gui::tx_engine_h2d_data [::mutrig_controller::gui::generate_bit_stream $asic_relative] $asic
            # time between asic (no so needed)
            after 1
        }
        toolkit_send_message warning "tx_engine_h2d_data: configure done."
        toolkit_send_message warning "tx_engine_h2d_data: ////////////////////////////////////////////////"
        if {![toolkit_get_property "configCheckBox" checked]} {
            break
        }
        # time between continuous configurations
        after 2000
    }
    
        
	return -code ok
}



proc ::mutrig_controller::gui::tx_engine_h2d_data {data_list mutrig_index} {
	set fd_master_path [::mu3e::helpers::cget_opened_master_path]
	variable fd_global_variable
	set ram_name "altera_avalon_onchip_memory2.s1"
	set csr_name "mutrig_controller2.csr"
	set ram_base [::mutrig_controller::gui::get_global_variable $fd_global_variable "${ram_name}_base_address"]
	set csr_base [::mutrig_controller::gui::get_global_variable $fd_global_variable "${csr_name}_base_address"]
	# format is 
	# 		addr [0x0]: data [0x011m0054], where m is the mutrig index, 0x0054 is the cfg_len. 0x011 is the op code for cfg_mutrig
	# 		addr [0x4]: data [0x????????], which should be filled with the ram's offset as seen by the IP
	set cmd0 "0x011${mutrig_index}0054"
	set cmd1 $ram_base
	# write data
	master_write_32 $fd_master_path $ram_base $data_list
	# write command
	# step 1: write ram offset
	master_write_32 $fd_master_path [expr $csr_base+4] $cmd1
	# step 2: write descriptor to trigger irq
	master_write_32 $fd_master_path $csr_base $cmd0
	# step 3: polling for progress
	set running 1
	while {$running} {
		set progress [master_read_32 $fd_master_path $csr_base 1]
		# todo: support err return from device
		toolkit_send_message warning "tx_engine_h2d_data: progress is ${progress}"
		if {[expr $progress == 0x0]} {
			set running 0
			toolkit_send_message info "tx_engine_h2d_data: configure mutrig #${mutrig_index} done."
            break
		}
		after 10
	}
}

proc ::mutrig_controller::gui::generate_bit_stream {asic_id} {
	# from gui to config list
	set config_list {}
	foreach subField {"Header" "Channel" "TDC" "Footer"} {
		if {[catch {set param_info [::mutrig_controller::bsp::get_parameter_info "$subField"]} error_msg]} {
			toolkit_send_message error "$error_msg"
			return -code error
		}
		switch $subField {
			"Channel" {
				for {set ch 0} {[expr $ch < 32]} {incr ch} {
					foreach param $param_info {
						set name [lindex $param 0]
						set len [lindex $param 1]
						set order [lindex $param 2]
						set value [toolkit_get_property "subsettingGroup$subField${asic_id}_ch${ch}_comboBox_$name" selectedItem]
						lappend config_list [list $len $value $order]
					}
				}
			}
			default {
				foreach param $param_info {
					set name [lindex $param 0]
					set len [lindex $param 1]
					set order [lindex $param 2]
					set value [toolkit_get_property "subsettingGroup$subField${asic_id}_comboBox_$name" selectedItem]
					lappend config_list [list $len $value $order]
				}
			}
		}
	}
	#puts $config_list
	# generate bit stream 
	set bit_stream [::mutrig_controller::bsp::generate_bit_pattern $config_list]
	#puts $bit_stream
	set h2d_data_hex [::mu3e::helpers::parse_reverse_bit_stream $bit_stream]
	#puts $h2d_data_hex
	return $h2d_data_hex
}



		############################################################
		#   _____ _    _ _____        __       _____ _    _ _____  #
		#  / ____| |  | |_   _|       \ \     / ____| |  | |_   _| #
		# | |  __| |  | | | |     _____\ \   | |  __| |  | | | |   #
		# | | |_ | |  | | | |    |______> >  | | |_ | |  | | | |   #
		# | |__| | |__| |_| |_         / /   | |__| | |__| |_| |_  #
		#  \_____|\____/|_____|       /_/     \_____|\____/|_____| #
		#                                                          #
		############################################################
                                                        
######################################################################################################
##  Arguments:
##		none
##
##  Description:
##  	Get the setting from the gui and build tcl array. Then, copy it to other gui boxes. 
##
##	Returns:
##		-code ok	- if the operation has been successful
##		-code error - if error encounted and thus op aborted 
##
######################################################################################################
# @berief	
proc ::mutrig_controller::gui::copy_config_settings_comboBox {} {
	set asic_from [toolkit_get_property "asic_from_comboBox" selectedItem]
	set ch_from [toolkit_get_property "ch_from_comboBox" selectedItem]
	set asic_to [toolkit_get_property "asic_to_comboBox" selectedItem]
	set ch_to [toolkit_get_property "ch_to_comboBox" selectedItem]
	# optional finer granularity for Channel: which parameter to copy
	set ch_param_sel "all"
	if {[catch {set ch_param_sel [toolkit_get_property "ch_param_to_copy_comboBox" selectedItem]}]} {
		set ch_param_sel "all"
	}
	# format {array_Header} {array_Channel} {array_TDC} {array_Footer}
	foreach subField {"Header" "Channel" "TDC" "Footer"} {
		# get the parameter list for each sub-field
		if {[catch {set param_info [::mutrig_controller::bsp::get_parameter_info "$subField"]} error_msg]} {
			toolkit_send_message error "$error_msg"
			return -code error
		}
		# build the array with param_name as key, param_value as value
		switch $subField {
			"Channel" {
				foreach param $param_info {
					set name [lindex $param 0]
					#set len [lindex $param 1]
					#set order [lindex $param 2]
					set value [toolkit_get_property "subsettingGroup$subField${asic_from}_ch${ch_from}_comboBox_$name" selectedItem]
					set array_Channel($name) $value
				}
			}
			"Header" {
				foreach param $param_info {
					set name [lindex $param 0]
					#set len [lindex $param 1]
					#set order [lindex $param 2]
					set value [toolkit_get_property "subsettingGroup$subField${asic_from}_comboBox_$name" selectedItem]
					set array_Header($name) $value
				}
			}
			"TDC" {
				foreach param $param_info {
					set name [lindex $param 0]
					#set len [lindex $param 1]
					#set order [lindex $param 2]
					set value [toolkit_get_property "subsettingGroup$subField${asic_from}_comboBox_$name" selectedItem]
					set array_TDC($name) $value
				}
			}
			"Footer" {
				foreach param $param_info {
					set name [lindex $param 0]
					#set len [lindex $param 1]
					#set order [lindex $param 2]
					set value [toolkit_get_property "subsettingGroup$subField${asic_from}_comboBox_$name" selectedItem]
					set array_Footer($name) $value
				}
			}
		}
	}
	#parray array_Footer
	# copy from these arrays to the gui
	variable fd_global_variable
	# retrieve the number of asic
	if {[catch {set n_asic [::mutrig_controller::gui::get_global_variable $fd_global_variable "n_asic"]} error_msg]} {
		toolkit_send_message error "$error_msg"
		return -code error
	} else {
		toolkit_send_message debug "found this variable! its value is $n_asic"
	}
	# get the sub-field to copy
	foreach subField {"Header" "Channel" "TDC" "Footer"} {
		set subFieldCheckBox_array($subField) [toolkit_get_property "${subField}CheckBox" checked]
	}
	# copy to comboBoxes
	for {set asic 0} {[expr $asic < $n_asic]} {incr asic} {
		if {[string equal $asic_to "all"] || [expr $asic_to == $asic]} {
			for {set ch 0} {[expr $ch < 32]} {incr ch} {
				if {[string equal $ch_to "all"] || [expr $ch_to == $ch]} {
					# copy to this channel/asic
					# loop through all selected subfield 
					foreach {subField sel} [array get subFieldCheckBox_array] {
						if {$sel} {
							if {[catch {set param_info [::mutrig_controller::bsp::get_parameter_info "$subField"]} error_msg]} {
								toolkit_send_message error "$error_msg"
								return -code error
							}
							foreach param $param_info {
								set name [lindex $param 0]
								switch $subField {
									"Channel" {
										# if a specific Channel parameter is chosen, only copy that one
										if {[string equal $ch_param_sel "all"] || [string equal $ch_param_sel $name]} {
											set value $array_Channel($name)
											toolkit_set_property "subsettingGroup$subField${asic}_ch${ch}_comboBox_$name" selectedItem $value
										}
									}
									"Header" {
										set value $array_Header($name)
										toolkit_set_property "subsettingGroup$subField${asic}_comboBox_$name" selectedItem $value
									}
									"TDC" {
										set value $array_TDC($name)
										toolkit_set_property "subsettingGroup$subField${asic}_comboBox_$name" selectedItem $value
									}
									"Footer" {
										set value $array_Footer($name)
										toolkit_set_property "subsettingGroup$subField${asic}_comboBox_$name" selectedItem $value
									}
								}
							}
							# end of the param-loop
						}
					}
					# end of subfield-loop
				}
			} 
			# end of ch-loop
		}
	}
	# end of asic-loop
	return -code ok
}




		############################################################
		# __   ____  __ _             __       _____ _    _ _____  #
		# \ \ / /  \/  | |            \ \     / ____| |  | |_   _| #
		#  \ V /| \  / | |        _____\ \   | |  __| |  | | | |   #
		#   > < | |\/| | |       |______> >  | | |_ | |  | | | |   #
		#  / . \| |  | | |____         / /   | |__| | |__| |_| |_  #
		# /_/ \_\_|  |_|______|       /_/     \_____|\____/|_____| #
		#                                                          #
		############################################################

######################################################################################################
##  Arguments:
##		<fileChooserButtonName> - name of the file chooser button to get its path
##
##  Description:
##  	This function opens the xml configuration file and calls the 'set_config_settings` function 
##  to set gui and global variable table.
##
##	Returns:
##		-code ok	- if the operation has been successful
##		-code error - if file open cancelled 
##
######################################################################################################
proc ::mutrig_controller::gui::load_config_settings {fileChooserButtonName} {
	# error handling, NOTE: 0 if error, 1 if good (somehow this altera function has ret inverted)
	if {![catch [toolkit_get_property $fileChooserButtonName paths]]} {
		toolkit_send_message warning "load_config_settings: file selection cancelled, byte~"
		return -code error
	} else {
		set file_path [toolkit_get_property $fileChooserButtonName paths]
		set fd [open "$file_path" r]
		
		::mutrig_controller::gui::set_config_settings_to_comboBox $fd
		
		close $fd	
		toolkit_send_message info "load_config_settings: file loaded (${file_path}), have fun!"	
		return -code ok
	}

}

######################################################################################################
##  Arguments:
##		<fd> - file descriptor of the xml file just loaded
##
##  Description:
##  	This function sets the configuration plain text in global variable table and updates the gui 
##	comboBoxes. 
##
##	Returns:
##		-code ok	- if the operation has been successful
##		-code error - if error
##
######################################################################################################
proc ::mutrig_controller::gui::set_config_settings_to_comboBox {fd} {
	variable fd_global_variable
	# read from xml file
	set plain_text [read $fd]
	# build dom object
	dom parse $plain_text doc
	# set the global variable table with xml plain text
	# probe first, try append, then set
	if {[expr [::mutrig_controller::gui::probe_global_variable $fd_global_variable "doc_xml"] == 0]} {
			::mutrig_controller::gui::append_global_variable $fd_global_variable "doc_xml" $plain_text
			toolkit_send_message info "set_config_settings: created a new global variable"
		} else {
			toolkit_send_message info "set_config_settings: global variable existed, so I will modify it"
			::mutrig_controller::gui::set_global_variable $fd_global_variable "doc_xml" $plain_text
		}
    # partsDB xml -> gui 
    foreach node [[$doc selectNodes scifi_configurations/SMB/info/partsDB] childNodes] {
        set db_key [$node nodeName]
        set db_value [[$node childNodes] nodeValue]
        if {[catch [toolkit_set_property "${db_key}_textfield" text $db_value]]} {
            # this does not work as jvm through a higher level excemption from there, which is not capturable by tcl
            toolkit_send_message warning "set_config_settings_to_comboBox: unknown db key \"$db_key\", fall-through gui settings."
        } 
    }
	# set the gui comboBoxes
	foreach mutrig [$doc selectNodes scifi_configurations/SMB/mutrig] {
		set index_value [[[$mutrig selectNodes index] childNodes] nodeValue]
		set parameters [$mutrig selectNodes parameters]
		#puts "=================MUTRIG ${index_value}========================"
		foreach subField [$parameters childNodes] {
			set subFieldName [$subField nodeName]
			switch $subFieldName {
				"Channel" {
					foreach chan [$subField childNodes] {
						set ch_index [$chan nodeName]; # for example: "ch0", "ch1" ...
						foreach param [$chan childNodes] {
							set name [$param nodeName]
							set value [[$param childNodes] nodeValue]
							toolkit_set_property "subsettingGroup$subFieldName${index_value}_${ch_index}_comboBox_$name" selectedItem $value
							#puts "param_name: ${name}, param_value: ${value}"
						}
					}
				}
				default {
					#puts $subFieldName 
					foreach param [$subField childNodes] {
						set name [$param nodeName]
						set value [[$param childNodes] nodeValue]
						toolkit_set_property "subsettingGroup$subFieldName${index_value}_comboBox_$name" selectedItem $value
						#puts "param_name: ${name}, param_value: ${value}"
					}
					#puts "\n"
				}
			}
		}
	}
}



	############################################################
	#   _____ _    _ _____        __     __   ____  __ _       #
	#  / ____| |  | |_   _|       \ \    \ \ / /  \/  | |      #
	# | |  __| |  | | | |     _____\ \    \ V /| \  / | |      #
	# | | |_ | |  | | | |    |______> >    > < | |\/| | |      #
	# | |__| | |__| |_| |_         / /    / . \| |  | | |____  #
	#  \_____|\____/|_____|       /_/    /_/ \_\_|  |_|______| #
	#                                                          #
	############################################################                                                         


######################################################################################################
##  Arguments:
##		<fileChooserButtonName> - name of the file chooser button in the toolkit gui
##
##  Description:
##  	This function access the configuration from the global variable table and store it as plain text
##  to the file, which user chosed. 
##
##	Returns:
##		-code ok	- if the operation has been successful
##		-code error - if the file choosing has been aborted
##
######################################################################################################
proc ::mutrig_controller::gui::save_config_settings {fileChooserButtonName} {
	# must first call this function to update variables and store in the global variable table
	::mutrig_controller::gui::get_config_settings_from_comboBox
	variable fd_global_variable
	# error handling, NOTE: 0 if error, 1 if good (somehow this altera function has ret inverted)
	if {![catch [toolkit_get_property $fileChooserButtonName paths]]} {
		toolkit_send_message warning "save_config_settings: file selection cancelled, byte~"
		return -code error
	} else {
		set file_path [toolkit_get_property $fileChooserButtonName paths]
		set fd [open "$file_path" w]
		set plain_text [::mutrig_controller::gui::get_global_variable $fd_global_variable "doc_xml"]
		puts $fd $plain_text
		close $fd	
		toolkit_send_message info "save_config_settings: file saved (${file_path}), thank you!"	
		return -code ok
	}
}

######################################################################################################
##  Arguments:
##		none
##
##  Description:
##  	Gets user input from comboBoxes and stores in xml format into the global variable table.
##	It is called every time before you need to access the configurations. 
##
##	Returns:
##		-code ok	- if the operation has been successful
##		-code error - if the n_asic is not found in the table 
##
######################################################################################################
proc ::mutrig_controller::gui::get_config_settings_from_comboBox {} {
	variable fd_global_variable
	# retrieve the command ticket
	if {[catch {set n_asic [::mutrig_controller::gui::get_global_variable $fd_global_variable "n_asic"]} error_msg]} {
		toolkit_send_message error "$error_msg"
		return -code error
	} else {
		toolkit_send_message debug "found this variable! its value is $n_asic"
	}
	# store to xml
	# -----------------------------------------------------------------
	# 1) open dtd (document type definition)
	# 		NOTE: dtd has to be pre-created by Intellij. To open it type "snap run intellij-idea-community" in cmd.
	#		Next, follow the instruction "https://www.jetbrains.com/help/idea/generating-dtd.html" to generate dtd from xml. 
	#set mydtd_text [::mutrig_controller::gui::get_global_variable $fd_global_variable $dtdVarName]
	set mydtd_text ""
	set dtd [::dom::DOMImplementation createDocumentType "scifi_configurations" "" "" $mydtd_text]
	set doc [::dom::DOMImplementation createDocument "" "scifi_configurations" $dtd]
	set doc_ele [::dom::document cget $doc -documentElement]
	#set top [::dom::document createElement $doc "scifi_configurations"]
	set smb [::dom::document createElement $doc_ele "SMB" ]
	
	# <info>
	set smb_info [::dom::document createElement $smb "info"]
	set smb_info_version [::dom::document createElement $smb_info "version"]
	::mu3e::helpers::dom_set_node_value $smb_info_version 3
	# <parts db>
	set partsDB_token [::dom::document createElement $smb_info "partsDB"]
	::mu3e::helpers::dom_set_node_value [::dom::document createElement $partsDB_token "PN"] [toolkit_get_property "PN_textfield" text]
	::mu3e::helpers::dom_set_node_value [::dom::document createElement $partsDB_token "LOT"] [toolkit_get_property "LOT_textfield" text]
	::mu3e::helpers::dom_set_node_value [::dom::document createElement $partsDB_token "ITEM"] [toolkit_get_property "ITEM_textfield" text]
	::mu3e::helpers::dom_set_node_value [::dom::document createElement $partsDB_token "SN"] [toolkit_get_property "SN_textfield" text]
	# </parts db>
	::dom::document createElement $smb_info "n_mutrig" 
	::dom::document createElement $smb_info "good_mutrig_mask"
	::dom::document createElement $smb_info "bad_mutrig_mask"
	::dom::document createElement $smb_info "comment"
	# </info>
	
	# get the current settings from comboBoxes 
	set subgroupnames_array {"Header" "Channel" "TDC" "Footer"}
	for {set index 0} {$index < $n_asic} {incr index} {
		# setup the xml for each asic
		set smb_mutrig [::dom::document createElement $smb "mutrig"]
		set smb_mutrig_index [::dom::document createElement $smb_mutrig "index"]
		::mu3e::helpers::dom_set_node_value $smb_mutrig_index $index
		set smb_mutrig_param [::dom::document createElement $smb_mutrig "parameters"]
		foreach subgroupname $subgroupnames_array {
			# xml setup of each subfield 
			set smb_mutrig_param_sub [::dom::document createElement $smb_mutrig_param $subgroupname]
			# get the parameter list from bsp 
			if {[catch {set param_info [::mutrig_controller::bsp::get_parameter_info "$subgroupname"]} error_msg]} {
				toolkit_send_message error "$error_msg"
			} else {
				# loop through comboBoxes to get user input
				switch $subgroupname {
					"Channel" {
						for {set i 0} {$i < 32} {incr i} {
							set ch_token [::dom::document createElement $smb_mutrig_param_sub "ch${i}"]
							foreach param $param_info {
								set name [lindex $param 0]
								set len [lindex $param 1]
								set order [lindex $param 2]
								#set hi [expr {2**$len-1}]
								#set range [list 0 $hi]
								set title [toolkit_get_property "subsettingGroup$subgroupname${index}_ch${i}_comboBox_$name" label]
								set val [toolkit_get_property "subsettingGroup$subgroupname${index}_ch${i}_comboBox_$name" selectedItem]
								# xml stuff again for each parameter
								set token [::dom::document createElement $ch_token $name]
								::mu3e::helpers::dom_set_node_value $token $val
								#puts "title: ${title}. value: ${val}"
							}
						}
					}
					default {
						foreach param $param_info {
							set name [lindex $param 0]
							set len [lindex $param 1]
							set order [lindex $param 2]
							#set hi [expr {2**$len-1}]
							#set range [list 0 $hi]
							set title [toolkit_get_property "subsettingGroup$subgroupname${index}_comboBox_$name" label]
							set val [toolkit_get_property "subsettingGroup$subgroupname${index}_comboBox_$name" selectedItem]
							# xml stuff again for each parameter
							set token [::dom::document createElement $smb_mutrig_param_sub $name]
							::mu3e::helpers::dom_set_node_value $token $val
							#puts "title: ${title}. value: ${val}"
						}
					}
				}
			}
		}
	}
	# end of all loops, start to pack things up 
	#puts [::dom::document cget $doc -doctype]
	set plain_text [::dom::DOMImplementation serialize $doc -indent true -method xml]
	# TODO: try need to remove the DOCTYPE section, otherwise error will be reported from the parser
	regsub -all {<!(.|\n|\r)*]>} $plain_text "" plain_text; # does not work at this line
	#puts "xml (clean) file is: \n${plain_text}"
	::mutrig_controller::gui::set_global_variable $fd_global_variable "doc_xml" $plain_text
#	::dom::DOMImplementation destroy $doc
	return -code ok
}

proc ::mutrig_controller::gui::load_dtd {fileChooserButtonName dtdVarName} {
	variable fd_global_variable
	# error handling, NOTE: 0 if error, 1 if good (somehow this altera function has ret inverted)
	if {![catch [toolkit_get_property $fileChooserButtonName paths]]} {
		toolkit_send_message warning "load_dtd: file selection cancelled, byte~"
		return -code error
	} else {
		set file_path [toolkit_get_property $fileChooserButtonName paths]
		set fd [open "$file_path" r]
		set plain_text [read $fd]
		close $fd
		# try probe first
		if {[expr [::mutrig_controller::gui::probe_global_variable $fd_global_variable $dtdVarName] == 0]} {
			::mutrig_controller::gui::append_global_variable $fd_global_variable $dtdVarName $plain_text
			toolkit_send_message info "load_dtd: created a new global variable"
		} else {
			toolkit_send_message info "load_dtd: global variable existed, so I will modify it"
			::mutrig_controller::gui::set_global_variable $fd_global_variable $dtdVarName $plain_text
		}
		toolkit_send_message info "load_dtd: dtd loaded"	
		return -code ok
	}
	
}


		################################################################
		#   _____ ______ _______ _    _ _____      _____ _    _ _____  # 
		#  / ____|  ____|__   __| |  | |  __ \    / ____| |  | |_   _| #  
		# | (___ | |__     | |  | |  | | |__) |  | |  __| |  | | | |   # 
		#  \___ \|  __|    | |  | |  | |  ___/   | | |_ | |  | | | |   # 
		#  ____) | |____   | |  | |__| | |       | |__| | |__| |_| |_  # 
		# |_____/|______|  |_|   \____/|_|        \_____|\____/|_____| #  
		#                                                              # 
		################################################################ 
        
######################################################################################################
##  Arguments:
##		<groupName> - parent group name 
##		<n_asic> - number of mutrigs 
##
##  Description:
##  	This function sets up the configuration group supposed to be under main tab (Tab0)
##
##	Returns:
##		-code ok	- if the setup has been successful
##
######################################################################################################
proc ::mutrig_controller::gui::setup_config_group {groupName n_asic} {
	# setup control panel
	toolkit_add 			"controlPanelGroup" group 			$groupName
	toolkit_set_property 	"controlPanelGroup" itemsPerRow		1
	toolkit_set_property	"controlPanelGroup"	title			"Control Panel"
	# create the button to load dtd file
	toolkit_add				"loadDtdButton" 	fileChooserButton			"controlPanelGroup"
	toolkit_set_property	"loadDtdButton"		text						"Load DTD file" 
	toolkit_set_property	"loadDtdButton"		paths						"./trash_bin"; # some default path
	toolkit_set_property	"loadDtdButton"		chooserButtonText			"Load"
	toolkit_set_property	"loadDtdButton"		onChoose		{::mutrig_controller::gui::load_dtd "loadDtdButton" "scifi_configurations_dtd"}
	toolkit_set_property	"loadDtdButton"		visible 					false 
	# create the button to generate XML 
	toolkit_add				"genXmlButton"		button 			"controlPanelGroup"
	toolkit_set_property	"genXmlButton"		text 			"Gen XML pattern"
	toolkit_set_property	"genXmlButton"		onClick			{::mutrig_controller::gui::get_config_settings}
	toolkit_set_property	"genXmlButton"		visible 					false 
	# create a setting tabbed-group
	toolkit_add 			"settingTab" 		tabbedGroup 	$groupName
	for {set i 0} {$i < $n_asic} {incr i} {
		::mutrig_controller::gui::setup_config_setting_group "settingTab" $i
	}
	# create a button for save to xml
	toolkit_add				"saveXmlButton"		fileChooserButton 			"controlPanelGroup"
	toolkit_set_property	"saveXmlButton"		text 						"Save to XML"
	toolkit_set_property	"saveXmlButton"		paths						"./trash_bin/config.xml"; # some default path
	toolkit_set_property	"saveXmlButton"		chooserButtonText 			"Save"
	toolkit_set_property	"saveXmlButton"		onChoose 		{::mutrig_controller::gui::save_config_settings "saveXmlButton"} 
	# create a button for load from xml
	toolkit_add				"loadXmlButton"		fileChooserButton 			"controlPanelGroup"
	toolkit_set_property	"loadXmlButton"		text 						"Load from XML"
	toolkit_set_property	"loadXmlButton"		paths						"./trash_bin/config.xml"; # some default path
	toolkit_set_property	"loadXmlButton"		chooserButtonText 			"Load"
	toolkit_set_property	"loadXmlButton"		onChoose 		{::mutrig_controller::gui::load_config_settings "loadXmlButton"} 
	## setup copy panel
	toolkit_add				"copyGroup"			group			"controlPanelGroup"
	toolkit_set_property	"copyGroup"			itemsPerRow		2
	toolkit_set_property 	"copyGroup"			title			"Copy settings from"
	# create two from-comboBoxes
	::mu3e::helpers::toolkit_setup_combobox "copyGroup"	 "asic_from_comboBox" [list 0 [expr $n_asic-1]] 0 "asic"
	::mu3e::helpers::toolkit_setup_combobox "copyGroup"	 "ch_from_comboBox" [list 0 31] 0 "ch"
	# create the button
	toolkit_add				"copyButton"		button			"copyGroup"
	toolkit_set_property	"copyButton"		text			"to"
	toolkit_set_property	"copyButton"		onClick			{::mutrig_controller::gui::copy_config_settings_comboBox}
	# create a dummy text (for visual alignment)
	toolkit_add				"dummyText"			text			"copyGroup"
	toolkit_set_property	"dummyText"			text 			"including"
	#toolkit_set_property	"dummyText"			htmlCapable		1
	toolkit_set_property	"dummyText"			editable		0
	toolkit_set_property	"dummyText"			visible			1
	# create subfield checkBox
	foreach subField [list "Header" "Channel" "TDC" "Footer"] {
		toolkit_add				"${subField}CheckBox" checkBox		"copyGroup"
		toolkit_set_property	"${subField}CheckBox" toolTip 		"Include ${subField}"
		toolkit_set_property	"${subField}CheckBox" text			"$subField"
	}
	# create a dummy text (for visual alignment)
	toolkit_add				"dummyText1"			text			"copyGroup"
	toolkit_set_property	"dummyText1"			text 			"with channel param: "
	#toolkit_set_property	"dummyText1"			htmlCapable		1
	toolkit_set_property	"dummyText1"			editable		0
	toolkit_set_property	"dummyText1"			visible			1
	# create a combobox to choose Channel parameter granularity (including "all")
	toolkit_add                "ch_param_to_copy_comboBox" comboBox        "copyGroup"
	toolkit_set_property       "ch_param_to_copy_comboBox" label           ""
	# populate options from BSP + 'all'
	if {[catch {set _copy_param_info [::mutrig_controller::bsp::get_parameter_info "Channel"]} _err]} {
		toolkit_send_message warning "copy panel: cannot query Channel parameters; default to 'all' only. ($_err)"
		toolkit_set_property   "ch_param_to_copy_comboBox" options         {all}
	} else {
		set _ops {all}
		foreach _p $_copy_param_info { lappend _ops [lindex $_p 0] }
		toolkit_set_property   "ch_param_to_copy_comboBox" options         $_ops
	}
	toolkit_set_property       "ch_param_to_copy_comboBox" selectedItem    "all"
	# create two to-comboBoxes
	::mu3e::helpers::toolkit_setup_combobox "copyGroup"	 "asic_to_comboBox" [list 0 [expr $n_asic-1]] 0 "asic"
	::mu3e::helpers::toolkit_setup_combobox "copyGroup"	 "ch_to_comboBox" [list 0 31] 0 "ch"
	set op [toolkit_get_property "asic_to_comboBox" options]
	set op_new [list "all"]
	foreach i $op {
		lappend op_new $i
	}
	toolkit_set_property "asic_to_comboBox" options $op_new
	set op [toolkit_get_property "ch_to_comboBox" options]
	set op_new [list "all"]
	foreach i $op {
		lappend op_new $i
	}
	toolkit_set_property "ch_to_comboBox" options $op_new
	# create a group to send config
	toolkit_add				"configButton"		button			"controlPanelGroup"
	toolkit_set_property	"configButton"		text			"Configure"
	toolkit_set_property	"configButton"		onClick 		{::mutrig_controller::gui::configure_all_chips}
    
    toolkit_add				"configCheckBox"    checkBox		"controlPanelGroup"
	toolkit_set_property	"configCheckBox"    text			"Continuously"
	
	# create a partsDB group in the bottom
	toolkit_add				"partsDBGroup"		group 			$groupName
	toolkit_set_property	"partsDBGroup"		itemsPerRow		4
	toolkit_set_property	"partsDBGroup"		title			"partsDB"
	
	toolkit_add				"PN_textfield"		textField		"partsDBGroup"
	toolkit_set_property	"PN_textfield"		label			"PN"
	toolkit_set_property	"PN_textfield"		text			"0433"
	toolkit_set_property	"PN_textfield"		expandableX		1
	
	toolkit_add				"LOT_textfield"		textField		"partsDBGroup"
	toolkit_set_property	"LOT_textfield"		label			"LOT"
	toolkit_set_property	"LOT_textfield"		text			"0003"
	toolkit_set_property	"LOT_textfield"		expandableX		1
	
	toolkit_add				"ITEM_textfield"	textField		"partsDBGroup"
	toolkit_set_property	"ITEM_textfield"	label			"ITEM"
	toolkit_set_property	"ITEM_textfield"	text			"000001"
	toolkit_set_property	"ITEM_textfield"	expandableX		1
	
	toolkit_add				"SN_textfield"		textField		"partsDBGroup"
	toolkit_set_property	"SN_textfield"		label			"SN"
	toolkit_set_property	"SN_textfield"		text			"3.0-005"
	toolkit_set_property	"SN_textfield"		expandableX		1
    
    # create a connection group
	toolkit_add				"conGroup"		    group 			$groupName
	toolkit_set_property	"conGroup"		    itemsPerRow		1
	toolkit_set_property	"conGroup"		    title			"Connections"
    
    toolkit_add             "bank_comboBox"     comboBox      "conGroup"
    toolkit_set_property    "bank_comboBox"     label           "(DAB) Bank"
    toolkit_set_property    "bank_comboBox"     options         {"UP" "DOWN"}
	
	return -code ok
}		


######################################################################################################
##  Arguments:
##		<groupName> - parent group name 
##		<index> - index of mutrigs (up to 'n_asic`)
##
##  Description:
##  	This function setup the setting tab for one mutrig
##
##	Returns:
##		-code ok	- if the setup has been successful
##
######################################################################################################
proc ::mutrig_controller::gui::setup_config_setting_group {groupName index} {
	# setting MuTRiGx group under the settingTab tabbed-group
	toolkit_add				"settingGroup$index"		group			$groupName
	toolkit_set_property	"settingGroup$index"		title			"MuTRiG ${index}"
	toolkit_set_property	"settingGroup$index"		itemsPerRow		1
	# under each tab create header/channel/tdc/footer tabbed-group 
	toolkit_add 			"subsettingtab$index" 		tabbedGroup 	"settingGroup$index"
	set subgroupnames_array {"Header" "Channel" "TDC" "Footer"}
	# add Header/Channel/TDC/Footer group under this tabbed-group 
	foreach subgroupname $subgroupnames_array {
		::mutrig_controller::gui::setup_config_setting_subgroup "subsettingtab$index" $index "$subgroupname"
	}
	return -code ok
}


######################################################################################################
##  Arguments:
##		<groupName> - parent group name 
##		<index> - index of mutrigs (up to 'n_asic`)
##		<subgroupName> - subgroup name you wish to create
##
##  Description:
##  	This function setup the setting subtab for a subsetting (e.g. Header, Channel, TDC, Footer)
##
##	Returns:
##		-code ok	- if the setup has been successful
##
######################################################################################################
proc ::mutrig_controller::gui::setup_config_setting_subgroup {groupName index subgroupName} {
	toolkit_add				"subsettingGroup$subgroupName$index"	group		$groupName
	toolkit_set_property	"subsettingGroup$subgroupName$index"	title		"$subgroupName"
	toolkit_set_property	"subsettingGroup$subgroupName$index"	itemsPerRow	4
	toolkit_set_property	"subsettingGroup$subgroupName$index"	expandableY 1
	if {[catch {set param_info [::mutrig_controller::bsp::get_parameter_info "$subgroupName"]} error_msg]} {
		toolkit_send_message error "$error_msg"
	}
	# add subfield group under this tabbed-group 
	switch $subgroupName {
		"Channel" {
			toolkit_add 			"Chsubsettingtab$index" 		tabbedGroup 	"subsettingGroup$subgroupName$index"
			for {set i 0} {$i < 32} {incr i} {
				toolkit_add				"ChsubsettingGroup$subgroupName$index"	group	"Chsubsettingtab$index"
				toolkit_set_property	"ChsubsettingGroup$subgroupName$index"	title	"Ch${i}"
				toolkit_set_property	"ChsubsettingGroup$subgroupName$index"	itemsPerRow	4
				toolkit_set_property	"ChsubsettingGroup$subgroupName$index"	expandableY 1
				# create comboBoxes
				foreach param $param_info {
					set name [lindex $param 0]
					set len [lindex $param 1]
					set order [lindex $param 2]
					set hi [expr {2**$len-1}]
					set range [list 0 $hi]
					::mu3e::helpers::toolkit_setup_combobox "ChsubsettingGroup$subgroupName$index" "subsettingGroup$subgroupName${index}_ch${i}_comboBox_$name" $range 0 $name
				}
			}
			return -code ok
		} 
		default {
			# create comboBoxes
			foreach param $param_info {
				set name [lindex $param 0]
				set len [lindex $param 1]
				set order [lindex $param 2]
				set hi [expr {2**$len-1}]
				set range [list 0 $hi]
				::mu3e::helpers::toolkit_setup_combobox "subsettingGroup$subgroupName$index" "subsettingGroup$subgroupName${index}_comboBox_$name" $range 0 $name
			}
			return -code ok
		}
	}
}

proc ::mutrig_controller::gui::setup_tsa_page {baseGroupName n_asic_total} {
    # record total ASIC count for TSA operations
    variable tsa_n_asic_total
    set tsa_n_asic_total $n_asic_total
    # create a group under the base group
    toolkit_add				"tsaGroup"		group				$baseGroupName
    toolkit_set_property	tsaGroup		title				"Threshold Scan"
    toolkit_add				"tsaTab"		tabbedGroup		    tsaGroup
    
    # control panel
    toolkit_add				"tsaCtlrGroup"			group				tsaGroup
    toolkit_set_property	tsaCtlrGroup			title				"Control Panel"
    toolkit_set_property	tsaCtlrGroup			itemsPerRow			1
    
    # control panel - content
    toolkit_add				"run_all_tsa_set"			button				tsaCtlrGroup
    toolkit_set_property	run_all_tsa_set				text				"Run T Scan"
    toolkit_set_property	run_all_tsa_set				onClick				{::mutrig_controller::gui::run_tsa "mutrig_controller2.csr"}
    
    # E-Threshold scan button
    toolkit_add				"run_all_eth_set"			button				tsaCtlrGroup
    toolkit_set_property	run_all_eth_set				text				"Run E Scan"
    toolkit_set_property	run_all_eth_set				onClick				{::mutrig_controller::gui::run_eth "mutrig_controller2.csr"}
    
    
    toolkit_add				"save_tsa_plots_to_file_set"	fileChooserButton		tsaCtlrGroup
    # default filename: <what it is>_date-YYMMDD.csv
    set _today [clock format [clock seconds] -format {%y%m%d}]
    toolkit_set_property	save_tsa_plots_to_file_set		paths			        "./trash_bin/scan_result_date-${_today}.csv"
    toolkit_set_property	save_tsa_plots_to_file_set		chooserButtonText		"Save"
    toolkit_set_property	save_tsa_plots_to_file_set		text			        "Save results" 
    toolkit_set_property	save_tsa_plots_to_file_set		onChoose			    {::mutrig_controller::gui::save_tsa_results "save_tsa_plots_to_file_set"}  

    # plot area (group of tabs)
    # plot area (create a group in each tab)
    for {set tab_index 0} {$tab_index < $n_asic_total} {incr tab_index} {
        # the threshold scan result tab
        toolkit_add				"tsa${tab_index}Group"		group					"tsaTab"
        toolkit_set_property	"tsa${tab_index}Group"		expandableX				true
        toolkit_set_property	"tsa${tab_index}Group"		expandableY				true
        toolkit_set_property	"tsa${tab_index}Group"		title 					"MuTRiG${tab_index}"
        toolkit_add				"tsa${tab_index}_channelsTab" tabbedGroup			"tsa${tab_index}Group"
        for {set ch_index 0} {$ch_index < 32} {incr ch_index} {
            toolkit_add				"tsa${tab_index}_${ch_index}"	group				"tsa${tab_index}_channelsTab"	
            toolkit_set_property	"tsa${tab_index}_${ch_index}"	title				"Ch${ch_index}"
            toolkit_add				"tsa${tab_index}_${ch_index}LineC"		lineChart				"tsa${tab_index}_${ch_index}"
            toolkit_set_property	"tsa${tab_index}_${ch_index}LineC"		title					"T-Threshold Scan Plot (32 channels)"
            toolkit_set_property	"tsa${tab_index}_${ch_index}LineC"		labelX					"TTH Setting"
            toolkit_set_property	"tsa${tab_index}_${ch_index}LineC"		labelY					"Hit Rate"
        }
    }
    

    return -code ok
}

proc ::mutrig_controller::gui::run_tsa {typeName} {
    # init...
    set tsa_start_cmd "01400054"; # actually 0x0140_XXXX is ok, 0x54 is length (not needed here)
    variable fd_global_variable
    
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # gvtable -> base address
    set ipBase [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_base_address]
    
    # 1) h2d command
    # write to controller to start tsa routine
    master_write_32	$master_fd $ipBase "0x${tsa_start_cmd}" 
    toolkit_send_message info "run_tsa: threshold scan started, running..."
    # 2) poll for completion
    while {1} {
        # toggle button
        toolkit_set_property "run_all_tsa_set" enabled false
        set ctrl_csr [master_read_32 $master_fd $ipBase 0x1]
        set prog_info [format %d [expr $ctrl_csr%64]]
        # compl'
        if {[expr $ctrl_csr] == 0} {
            toolkit_set_property "run_all_tsa_set" enabled true
            toolkit_send_message debug "run_tsa: tth scan completed! (63 / 63) "
            break
        }
        # update scan progress
        toolkit_set_property "run_all_tsa_set" text "${prog_info} / 63"
        toolkit_send_message debug "run_tsa: tth scan progress: ${prog_info} / 63"
        after 1000
    }
    toolkit_set_property "run_all_tsa_set" text "Run T Scan"
    toolkit_send_message info "run_tsa: threshold scan completed!"
    # 3) plot results
    ::mutrig_controller::gui::plot_tsa "mutrig_controller2.scan_result" 
    
    # 4) persist results to global variable table
    ::mutrig_controller::gui::write_tsa_result_to_global_variable
    
    return -code ok

}

proc ::mutrig_controller::gui::run_eth {typeName} {
    # init...
    set tsa_start_cmd "01700000"
    variable fd_global_variable
    
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # gvtable -> base address
    set ipBase [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_base_address]
    
    # 1) h2d command
    master_write_32	$master_fd $ipBase "0x${tsa_start_cmd}"
    toolkit_send_message info "run_eth: E-threshold scan started, running..."
    # 2) poll for completion
    while {1} {
        # toggle button
        toolkit_set_property "run_all_eth_set" enabled false
        set ctrl_csr [master_read_32 $master_fd $ipBase 0x1]
        set prog_info [format %d [expr $ctrl_csr%64]]
        if {[expr $ctrl_csr] == 0} {
            toolkit_set_property "run_all_eth_set" enabled true
            toolkit_send_message debug "run_eth: scan completed! (63 / 63)"
            break
        }
        toolkit_set_property "run_all_eth_set" text "${prog_info} / 63"
        toolkit_send_message debug "run_eth: scan progress: ${prog_info} / 63"
        after 1000
    }
    toolkit_set_property "run_all_eth_set" text "Run E-Threshold"
    toolkit_send_message info "run_eth: E-threshold scan completed!"
    # 3) plot results same as TTH
    ::mutrig_controller::gui::plot_tsa "mutrig_controller2.scan_result"
    # 4) persist results to global variable table (same entry as last run)
    ::mutrig_controller::gui::write_tsa_result_to_global_variable
    return -code ok
}


proc ::mutrig_controller::gui::plot_tsa {typeName} {
    # init...
    variable tsa_n_asic_total
    variable fd_global_variable
    # reset results container for a fresh run
    variable tsa_all_plots
    set tsa_all_plots {}
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # gvtable -> base address
    set ipBase [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_base_address]

    # d2h and plot 
    # fallback to 8 if not set
    if {![info exists tsa_n_asic_total] || $tsa_n_asic_total <= 0} {
        set tsa_n_asic_total 8
    }
    for {set i 0} {$i < $tsa_n_asic_total} {incr i} {
		set asic_addr_ofst [expr 64*4*32]
		variable tsa_all_plots; # file to store the scan results append each list of 1 ch

		for {set ch 0} {$ch < 32} {incr ch} {
            # 1) calculate addr offset relative to this channel in <scan result>
			set read_starting_addr [format %X [expr [expr $ipBase + 64*4*[expr $ch]] + [expr $asic_addr_ofst*$i]]]
			set bar_category_str "ch: ${ch}"
            # 2) read result for this channel 
			set result_of_one_channel [master_read_32 $master_fd "0x${read_starting_addr}" 64]
            # 3) plot for this channel 
			set step_tth 0
			foreach result_of_one_channel_one_step $result_of_one_channel {
				set result_of_one_channel_one_step [format %i [expr $result_of_one_channel_one_step]]
				toolkit_set_property "tsa${i}_${ch}LineC" itemValue [list $step_tth [expr $result_of_one_channel_one_step]]
				incr step_tth
			}
            # 4) store the result 
			lappend tsa_all_plots $result_of_one_channel
		}
    }
    
	toolkit_send_message info "plot_tsa: scan results plot"
    return -code ok 
    
}


######################################################################################################
##  Arguments:
##     none
##
##  Description:
##      Writes the latest threshold scan results to the global variable table.
##      - Probes the table for an existing entry and appends a new one if missing.
##      - Uses mu3e_helpers.tcl global-variable helpers (init/append/set/probe/get).
##
##  Notes:
##      Expects ::mutrig_controller::gui::plot_tsa to have populated the namespace
##      variable 'tsa_all_plots' with the most recent scan results.
##
##  Returns:
##      -code ok on success
##      -code error if the results are not available
######################################################################################################
proc ::mutrig_controller::gui::write_tsa_result_to_global_variable {} {
    variable fd_global_variable
    # results collected by plot_tsa
    variable tsa_all_plots

    # Ensure results are available
    if {![info exists tsa_all_plots] || [llength $tsa_all_plots] == 0} {
        toolkit_send_message warning "write_tsa_result_to_global_variable: no TSA results available to store."
        return -code error
    }

    set varName "mutrig_controller2.scan_result_data"

    # Create or update entry using mu3e helper procs
    if {[::mu3e::helpers::probe_global_variable $fd_global_variable $varName] == 0} {
        ::mu3e::helpers::append_global_variable $fd_global_variable $varName $tsa_all_plots
        toolkit_send_message info "write_tsa_result_to_global_variable: created new entry '${varName}'."
    } else {
        ::mu3e::helpers::set_global_variable $fd_global_variable $varName $tsa_all_plots
        toolkit_send_message info "write_tsa_result_to_global_variable: updated existing entry '${varName}'."
    }

    return -code ok
}


######################################################################################################
##  Arguments:
##     <fileChooserButtonName> - name of the file chooser button to get its path
##
##  Description:
##      Saves the TSA results stored in the GlobalVariableTable to a CSV file.
##      - CSV columns: asic,ch,step,rate
##      - Iteration: asic in [0..n_asic-1], ch in [0..31], step in [0..63]
##
##  Returns:
##      -code ok on success
##      -code error if cancelled or data missing
######################################################################################################
proc ::mutrig_controller::gui::save_tsa_results {fileChooserButtonName} {
    variable fd_global_variable
    variable tsa_n_asic_total

    # Access results from global variable table
    set varName "mutrig_controller2.scan_result_data"
    if {[::mu3e::helpers::probe_global_variable $fd_global_variable $varName] == 0} {
        toolkit_send_message warning "save_tsa_results: TSA results not found in GlobalVariableTable."
        return -code error
    }
    set tsa_results [::mu3e::helpers::get_global_variable $fd_global_variable $varName]

    # Determine number of ASICs from TSA setup (not GVTable)
    if {![info exists tsa_n_asic_total] || $tsa_n_asic_total <= 0} {
        set total_asic 8
    } else {
        set total_asic $tsa_n_asic_total
    }

    # File selection handling (consistent with existing fileChooser pattern)
    if {![catch [toolkit_get_property $fileChooserButtonName paths]]} {
        toolkit_send_message warning "save_tsa_results: file selection cancelled."
        return -code error
    }
    set file_path [toolkit_get_property $fileChooserButtonName paths]

    # Open and write CSV
    if {[catch {set fd [open "$file_path" w]} err]} {
        toolkit_send_message error "save_tsa_results: cannot open file: $err"
        return -code error
    }

    # Header
    puts $fd "asic,ch,step,rate"

    # Iterate and write rows
    for {set asic 0} {$asic < $total_asic} {incr asic} {
        for {set ch 0} {$ch < 32} {incr ch} {
            set idx [expr {$asic*32 + $ch}]
            set ch_list [lindex $tsa_results $idx]
            for {set step 0} {$step < 64} {incr step} {
                set word [lindex $ch_list $step]
                # Convert to decimal integer for CSV
                set rate [format %i [expr {$word}]]
                puts $fd "$asic,$ch,$step,$rate"
            }
        }
    }

    close $fd
    toolkit_send_message info "save_tsa_results: saved to $file_path"
    return -code ok
}




		######################################################
		#  _    _ ______ _      _____  ______ _____   _____  #
		# | |  | |  ____| |    |  __ \|  ____|  __ \ / ____| #
		# | |__| | |__  | |    | |__) | |__  | |__) | (___   #
		# |  __  |  __| | |    |  ___/|  __| |  _  / \___ \  #
		# | |  | | |____| |____| |    | |____| | \ \ ____) | #
		# |_|  |_|______|______|_|    |______|_|  \_\_____/  #
		#                                                    #
		######################################################

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
proc ::mutrig_controller::gui::init_global_variable {tableName} {
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
proc ::mutrig_controller::gui::append_global_variable {tableName variableName variableValue} {
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

proc ::mutrig_controller::gui::remove_global_variable {tableName variableName variableValue} {
	
	
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
proc ::mutrig_controller::gui::set_global_variable {tableName variableName variableValue} {
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
proc ::mutrig_controller::gui::get_global_variable {tableName variableName} {
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
proc ::mutrig_controller::gui::probe_global_variable {tableName variableName} {
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
