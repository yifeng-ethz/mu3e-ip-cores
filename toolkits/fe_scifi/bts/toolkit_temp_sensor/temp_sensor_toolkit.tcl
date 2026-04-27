package provide temp_sensor 1.0
package require Tcl 8.5
package require mu3e::helpers 1.0


	
	


namespace eval temp_sensor_toolkit {

    variable monitor_ongoing 0
    
	variable sensor_loc_list [list {MuTRiG0} {MuTRiG1} {SiPM0} {SiPM1} {DAB0} {DAB1} ]
	variable sensor_adr_list [list {[expr 2*4]} {[expr 3*4]} {[expr 4*4]} {[expr 5*4]} {[expr 6*4]} {[expr 7*4]}]
    
	variable sensor_reading_list [list {0x0} {0x0} {0x0} {0x0} {0x0} {0x0} {0x0}]
	variable sensor_reading_float32_list [list {0} {0} {0} {0} {0} {0} {0}]
	variable sensor_selected_index 0
	variable sense_tickbox_list [list  {enable_sense_MuTRiG0_tb} {enable_sense_MuTRiG1_tb} {enable_sense_SiPM0_tb} {enable_sense_SiPM1_tb} {enable_sense_DAB0_tb} {enable_sense_DAB1_tb} {enable_sense_ondie_tb}]
	

	#########begin GUI construction######
	proc dashBoard {} {
    variable sensor_loc_list
	
	toolkit_set_property self title "Monitor of Temperature Sensors on FEB"
	#toolkit_set_property self author "Yifeng Wang"
	toolkit_set_property self visible true
	
	# Create the central TAB
	toolkit_add 			my_tabs 		tabbedGroup 		self
	
	###########################################################
	#  ____           _____ _____ _____   _______       ____  #
	# |  _ \   /\    / ____|_   _/ ____| |__   __|/\   |  _ \ #
	# | |_) | /  \  | (___   | || |         | |  /  \  | |_) |#
	# |  _ < / /\ \  \___ \  | || |         | | / /\ \ |  _ < #
	# | |_) / ____ \ ____) |_| || |____     | |/ ____ \| |_) |#
	# |____/_/    \_\_____/|_____\_____|    |_/_/    \_\____/ #
    #                                                         # 
    ###########################################################   
    toolkit_add 			"baseGroup" 	group 				my_tabs	
	toolkit_set_property 	"baseGroup" 	title 				"Setup Connections"
	toolkit_set_property 	"baseGroup" 	itemsPerRow 		1
	
	::mu3e::helpers::setup_base_group "baseGroup"
    
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
	::mu3e::helpers::init_global_variable  $fd_global_variable
	::mu3e::helpers::append_global_variable $fd_global_variable "slaves" [list "onewire_master_controller.csr"]
	::mu3e::helpers::append_global_variable $fd_global_variable "onewire_master_controller.csr_base_address" 0x0
	::mu3e::helpers::append_global_variable $fd_global_variable "onewire_master_controller.csr_encountered" 0
	toolkit_set_property	"globalVariableTable" visible 1
    
    
    
	toolkit_add				basicGroup		group				my_tabs
	toolkit_set_property	basicGroup		title				"Control"
	
	toolkit_add 			topGroup 	group 		basicGroup
	toolkit_set_property	topGroup	expandableX	false
	toolkit_set_property	topGroup	expandableY	false
	toolkit_set_property	topGroup	itemsPerRow 1
	toolkit_set_property	topGroup 	title		"Control Panel"
	
	toolkit_add				led0Button	button		topGroup
	toolkit_set_property	led0Button	enabled 	true
	toolkit_set_property	led0Button	expandableX false
	toolkit_set_property	led0Button	expandableY false
	toolkit_set_property	led0Button	text		"Read On/Off"
	toolkit_set_property	led0Button	onClick \
	{::temp_sensor_toolkit::monitor_registers_functor}
	
	
	toolkit_add				led0LED		led			topGroup
	toolkit_set_property	led0LED		expandableX	false
	toolkit_set_property	led0LED		expandableY	false
	toolkit_set_property	led0LED		text		"Reading Ongoing"
	toolkit_set_property	led0LED		color		"green_off"
	
	
    
    
    ## /////////////////////////// READING TAB //////////////////////////////////////
    variable monitor_fd ""
	## Reading group
	toolkit_add 			readingGroup 		group 		basicGroup
	toolkit_set_property	readingGroup		expandableX	false
	toolkit_set_property	readingGroup		expandableY	false
	toolkit_set_property	readingGroup		itemsPerRow 1
	toolkit_set_property	readingGroup 		title		"Reading from temperature sensors (celcius)"
    
    foreach i $sensor_loc_list {
        # create group for each sensor 
        toolkit_add 		    read${i}_group 		group 		readingGroup
        toolkit_set_property	read${i}_group		expandableX	false
        toolkit_set_property	read${i}_group		expandableY	false
        toolkit_set_property	read${i}_group		itemsPerRow 2
        toolkit_set_property	read${i}_group 		title		"read ${i}"
        # create text box for displaying temp value
        toolkit_add 			read${i}_text 	    text 			read${i}_group
        toolkit_set_property 	read${i}_text 	    expandableX 	false
        toolkit_set_property 	read${i}_text 	    expandableY 	false
        toolkit_set_property 	read${i}_text 	    preferredWidth 	100
        toolkit_set_property 	read${i}_text 	    preferredHeight 20
        toolkit_set_property 	read${i}_text 	    editable 		false
        toolkit_set_property 	read${i}_text 	    htmlCapable 	false
        toolkit_set_property 	read${i}_text 	    text 			"?"
        # create a tick box for status of reading
        toolkit_add				read${i}_checkBox	checkBox 	    read${i}_group
    
    }
	

	

	
	########################################
	#    _____  _      ____ _______ _____  #
	#   |  __ \| |    / __ \__   __/ ____| #
	#   | |__) | |   | |  | | | | | (___   #
	#   |  ___/| |   | |  | | | |  \___ \  #
	#   | |    | |___| |__| | | |  ____) | #
	#   |_|    |______\____/  |_| |_____/  #
	#                                      #
	########################################
	toolkit_add				plotsGroup		group				my_tabs
	toolkit_set_property	plotsGroup		title				Plots
	toolkit_set_property	plotsGroup		itemsPerRow			2
		
	set tchart_height 	200
	set tchart_width 	600
	# Timechart
	toolkit_add				dab0_tchart		timeChart	plotsGroup
	toolkit_set_property	dab0_tchart		title		"DAB up Temperature"
	toolkit_set_property	dab0_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	dab0_tchart		labelY		"Celsius"
	toolkit_set_property	dab0_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	dab0_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	dab0_tchart		showLegend		true
	
	toolkit_add				dab1_tchart		timeChart	plotsGroup
	toolkit_set_property	dab1_tchart		title		"DAB down Temperature"
	toolkit_set_property	dab1_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	dab1_tchart		labelY		"Celsius"
	toolkit_set_property	dab1_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	dab1_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	dab1_tchart		showLegend		true
	
	toolkit_add				mutrig0_tchart		timeChart	plotsGroup
	toolkit_set_property	mutrig0_tchart		title		"MuTRiG up Temperature"
	toolkit_set_property	mutrig0_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	mutrig0_tchart		labelY		"Celsius"
	toolkit_set_property	mutrig0_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	mutrig0_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	mutrig0_tchart		showLegend		true
	
	toolkit_add				mutrig1_tchart		timeChart	plotsGroup
	toolkit_set_property	mutrig1_tchart		title		"MuTRiG down Temperature"
	toolkit_set_property	mutrig1_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	mutrig1_tchart		labelY		"Celsius"
	toolkit_set_property	mutrig1_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	mutrig1_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	mutrig1_tchart		showLegend		true
	
	toolkit_add				sipm0_tchart		timeChart	plotsGroup
	toolkit_set_property	sipm0_tchart		title		"SiPM up Temperature"
	toolkit_set_property	sipm0_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	sipm0_tchart		labelY		"Celsius"
	toolkit_set_property	sipm0_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	sipm0_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	sipm0_tchart		showLegend		true
	
	toolkit_add				sipm1_tchart		timeChart	plotsGroup
	toolkit_set_property	sipm1_tchart		title		"SiPM down Temperature"
	toolkit_set_property	sipm1_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	sipm1_tchart		labelY		"Celsius"
	toolkit_set_property	sipm1_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	sipm1_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	sipm1_tchart		showLegend		true
	
	toolkit_add				ondie_tchart		timeChart	plotsGroup
	toolkit_set_property	ondie_tchart		title		"FPGA Internal (on-die) Temperature"
	toolkit_set_property	ondie_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	ondie_tchart		labelY		"Celsius"
	toolkit_set_property	ondie_tchart		preferredHeight 	$tchart_height
	toolkit_set_property	ondie_tchart		preferredWidth	 	$tchart_width
	toolkit_set_property	ondie_tchart		showLegend		true
	
	
	
	return -code ok
	}
	
	
    proc ::temp_sensor_toolkit::access_master_controller {} {
        # globals
        set sensor_plot_list [list "mutrig0" "mutrig1" "sipm0" "sipm1" "dab0" "dab1"]
        variable fd_global_variable
        variable sensor_adr_list
        variable sensor_loc_list
        # get some variables
        set fd_master_path [::mu3e::helpers::cget_opened_master_path]
        set base_address [::mu3e::helpers::get_global_variable $fd_global_variable "onewire_master_controller.csr_base_address"]
        # init...
		set iter_index 0
		variable sense_tickbox_list
        set readingf32_float 0
        # reading is ongoing here!	
		for {set i 0} {$i < [llength $sensor_adr_list]} {incr i} {
			# 1) get raw readings and update list
            set addr [expr [lindex $sensor_adr_list $i] + $base_address]
            set readingf32	[master_read_32 $fd_master_path $addr 1]
            # 2) convert to float-32 and update list
            binary scan [binary format i $readingf32] f readingf32_float
            # 3) update text
            set name [lindex $sensor_loc_list $i]
            toolkit_set_property read${name}_text text "${readingf32_float} C"
            # 4) toggle master controller
            set checkBoxName read${name}_checkBox
            ::temp_sensor_toolkit::enable_sense $checkBoxName $i
            # 5) plot 
            set plotName [lindex $sensor_plot_list $i]
            set plotName "${plotName}_tchart"
            toolkit_set_property $plotName latest [expr $readingf32_float]
       }
        
    }


	proc monitor_temp {} {
        # globals
		variable readingf32_float
        variable fd_global_variable
        
        # get some variables
        set fd_master_path [::mu3e::helpers::cget_opened_master_path]
        set base_address [::mu3e::helpers::get_global_variable $fd_global_variable "onewire_master_controller.csr_base_address"]
        # init...
		set iter_index 0
		variable sense_tickbox_list
		
		# reading is ongoing here!	
		foreach iter_addr $::temp_sensor_toolkit::sensor_adr_list {
			# get raw readings and update list
            # /////////////////// new ///////////////////
            set addr [expr $iter_addr+$base_address]
            set readingf32	[master_read_32 $fd_master_path $addr 1]
            lset ::temp_sensor_toolkit::sensor_reading_list $iter_index $readingf32
            # convert to float-32 and update list
            binary scan [binary format i $readingf32] f readingf32_float
            lset ::temp_sensor_toolkit::sensor_reading_float32_list $iter_index $readingf32_float
            
            # /////////////////// old ///////////////////
#			## for 2's complement
#			if {$iter_index == 6} { 
#				set readingint8	[master_read_8 $fd_master_path $iter_addr 1]
#				if {[expr $readingint8] <= 127} {
#					set on_die_reading_int8 [expr $readingint8]
#				} else {
#					set on_die_reading_int8 [expr [expr $readingint8] - 256]
#				}
#			## for float 32 
#			} else {
#                set addr [expr $iter_addr+$base_address]
#				set readingf32	[master_read_32 $fd_master_path $addr 1]
#				lset ::temp_sensor_toolkit::sensor_reading_list $iter_index $readingf32
#				# convert to float-32 and update list
#				binary scan [binary format i $readingf32] f readingf32_float
#				lset ::temp_sensor_toolkit::sensor_reading_float32_list $iter_index $readingf32_float
#			}
			incr iter_index
		}
		
		# update the text box to display readings
        toolkit_send_message warning "monitor_temp: reading..."
#		toolkit_set_property view_reading0_text text [format "%f C" [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 4]]
#		toolkit_set_property 	dab0_tchart		latest [expr [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 4]]
#		toolkit_set_property view_reading1_text text [format "%f C" [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 5]]
#		toolkit_set_property 	dab1_tchart		latest [expr [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 5]]
#		toolkit_set_property view_reading2_text text [format "%f C" [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 0]]
#		toolkit_set_property 	mutrig0_tchart		latest [expr [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 0]]
#		toolkit_set_property view_reading3_text text [format "%f C" [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 1]]
#		toolkit_set_property 	mutrig1_tchart		latest [expr [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 1]]
#		toolkit_set_property view_reading4_text text [format "%f C" [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 2]]
#		toolkit_set_property 	sipm0_tchart		latest [expr [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 2]]
#		toolkit_set_property view_reading5_text text [format "%f C" [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 3]]
#		toolkit_set_property 	sipm1_tchart		latest [expr [lindex $::temp_sensor_toolkit::sensor_reading_float32_list 3]]
#		toolkit_set_property view_reading6_text text [format "%d C" $on_die_reading_int8]
#		toolkit_set_property 	ondie_tchart		latest [expr $on_die_reading_int8]
		
		set tickbox_index 0
		# check if sensor needs to be enable or disabled
		foreach sensor_tickbox $sense_tickbox_list {
			# continuously write to keep enabled or disabled (TODO: refactor this)
			::temp_sensor_toolkit::enable_sense $sensor_tickbox $tickbox_index
			incr tickbox_index
		}
	
	}


		

	proc ::temp_sensor_toolkit::enable_sense {tickbox_name sensor_index} {
        # globals
        variable fd_global_variable
        # get some variables
        set fd_master_path [::mu3e::helpers::cget_opened_master_path]
        set base_address [::mu3e::helpers::get_global_variable $fd_global_variable "onewire_master_controller.csr_base_address"]
        
        set sel_line [format "%04x" $sensor_index]
		if { [toolkit_get_property $tickbox_name checked] == "false" } {
			master_write_32 $fd_master_path  [expr $base_address + 4] 0x0000$sel_line
		} else {
			master_write_32 $fd_master_path  [expr $base_address + 4] 0x0001$sel_line
		}
		return -code ok
	}
	
	proc ::temp_sensor_toolkit::monitor_registers_functor {} {
        variable monitor_fd
        variable monitor_ongoing
        if {$monitor_ongoing} {
            set monitor_ongoing 0
            toolkit_set_property	led0LED color green_off
        } else {
            set monitor_ongoing 1
            toolkit_set_property	led0LED color green
        }
        
        # get selected master service path
        set master_path [::mu3e::helpers::get_selected_servicePath "jtagMasterGroup_showmp_comboBox"]
        if {$monitor_ongoing} {
            # open monitor serivce
            if {$monitor_fd ne ""} {
                toolkit_send_message info "monitor_registers_functor: monitor started..." 
            } else {
                #puts "monitor not created"
                # open monitor service -> fd
                set monitor_fd [::mu3e::helpers::open_monitor_service]
                monitor_set_interval $monitor_fd 1000
                monitor_set_callback $monitor_fd [list ::temp_sensor_toolkit::access_master_controller]
                monitor_add_range $monitor_fd $master_path 0x0 4
            }
            monitor_set_enabled $monitor_fd 1
#            # update loading gif
#            toolkit_set_property    "lvds_controlPanel_loading_bitmap"  label           "monitering..."
#            toolkit_set_property    "lvds_controlPanel_loading_bitmap"  visible         1
#            toolkit_set_property    "lvds_controlPanel_loading_bitmap"  toolTip         "press again to stop"
        } else {
            monitor_set_enabled $monitor_fd 0
#            # update loading gif
#            toolkit_set_property    "lvds_controlPanel_loading_bitmap"  label           "stopped"
#            toolkit_set_property    "lvds_controlPanel_loading_bitmap"  visible         0
        }
        return -code ok
    }
	
	

	

}

::temp_sensor_toolkit::dashBoard



