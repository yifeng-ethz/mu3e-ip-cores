###########################################################################################################
# @Name 		upload_subsystem_toolkit_gui.tcl
#
# @Brief		Setup the GUI, including base tab and config tab for displaying within the system console.
#
# @Functions	setup_all
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			May 28, 2025
# @Version		1.0 (file created)
#				
#
###########################################################################################################

package require mu3e::helpers 1.0
package require tdom

package provide upload_subsystem_bts::gui 1.0

namespace eval ::upload_subsystem_bts::gui:: {
	namespace export \
	setup_all
}

proc ::upload_subsystem_bts::gui::setup_all {} {
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
    # slaves header
    ::mu3e::helpers::append_global_variable $fd_global_variable "slaves" [list "runctl_mgmt_host.csr"]
    # slave list
    ::mu3e::helpers::append_global_variable $fd_global_variable "runctl_mgmt_host.csr_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "runctl_mgmt_host.csr_encountered" 0
    # counters
    ::mu3e::helpers::append_global_variable $fd_global_variable "logTable_current_row" 0
    
    toolkit_set_property	"globalVariableTable" visible 1
    
    # ////////////////////////////////// run control tab ///////////////////////////////////////////
    # - run control tab 
    toolkit_add 			"rcTab" 	group 				Tab0	
	toolkit_set_property 	"rcTab" 	title 				"Run Control Management Host"
	toolkit_set_property 	"rcTab" 	itemsPerRow 		2
    # -- run control group
    toolkit_add 			"rcGroup" 	group 				"rcTab"	
	toolkit_set_property 	"rcGroup" 	title 				"Log FIFO"
	toolkit_set_property 	"rcGroup" 	itemsPerRow 		2
    # --- run control content 
    ::upload_subsystem_bts::gui::setup_rc "rcGroup" 
    # --- run control panel
    toolkit_add 			"rcCtrlGroup" 	    group 		"rcTab"
	toolkit_set_property	"rcCtrlGroup"	    expandableX	false
	toolkit_set_property	"rcCtrlGroup"	    expandableY	false
    toolkit_set_property	"rcCtrlGroup"	    maxWidth	300
    toolkit_set_property	"rcCtrlGroup"	    preferredWidth	100
	toolkit_set_property	"rcCtrlGroup"	    itemsPerRow 1
	toolkit_set_property	"rcCtrlGroup" 	    title		"Control Panel"
    # --- run control panel content
    toolkit_add             "rcRead_button"   button      "rcCtrlGroup"
    toolkit_set_property    "rcRead_button"   text        "read"
    toolkit_set_property    "rcRead_button"   onClick     {::upload_subsystem_bts::gui::readbackLogFifo "rc_table"}
    
    toolkit_add             "rcClr_button"   button       "rcCtrlGroup"
    toolkit_set_property    "rcClr_button"   text         "flush"
    toolkit_set_property    "rcClr_button"   onClick      {::upload_subsystem_bts::gui::clearLogFifo "rc_table"}
    
    
    
    
    # /////////////////////////////////////////////////////////////////////////////////////////
    
    return -code ok
}




proc ::upload_subsystem_bts::gui::setup_rc {groupName} {
    variable fd_global_variable
    # 1) PREPARATION  
    

    # 2) SETUP GUI
    toolkit_add				rc_table 	table			"rcGroup"
    toolkit_set_property	rc_table    preferredWidth   600
	toolkit_set_property	rc_table	rowCount		4
	toolkit_set_property	rc_table	columnCount		4
	toolkit_set_property	rc_table	columnIndex		0
	toolkit_set_property	rc_table	columnHeader	"Timestamp"
	toolkit_set_property	rc_table	columnIndex		1
	toolkit_set_property	rc_table	columnHeader	"Command"
    toolkit_set_property	rc_table	columnIndex		2
	toolkit_set_property	rc_table	columnHeader	"Payload"
    toolkit_set_property	rc_table	columnIndex		3
	toolkit_set_property	rc_table	columnHeader	"Timestamp Execution"
	toolkit_set_property	rc_table	visible			1
    
    return -code ok
}

proc ::upload_subsystem_bts::gui::readbackLogFifo {tableName} {
    variable fd_global_variable
    # what row is now ?
    set currentRow [::mu3e::helpers::get_global_variable $fd_global_variable "logTable_current_row"]
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    # get the base address of runctl host csr in qsys
    set baseCsr [::mu3e::helpers::get_global_variable $fd_global_variable "runctl_mgmt_host.csr_base_address"]
    set logPopAddr [expr {$baseCsr + (0x12 << 2)}]
    # d2h via CSR_LOG_POP
    set logTuple {}
    for {set wordIdx 0} {$wordIdx < 4} {incr wordIdx} {
        lappend logTuple [master_read_32 $master_fd $logPopAddr 1]
    }
    #puts $logTuple
     
    # tuple -> info, the tcl list 0 1 2 3 corresponding to word 3 2 1 0. tcl-2 = word-1 (info)
    set infoTimestamp [::mu3e::helpers::hex2bin [lindex $logTuple 3]]
    set infoTimestamp ${infoTimestamp}[::mu3e::helpers::hex2bin [lindex $logTuple 2]]
    set infoTimestamp [::mu3e::helpers::binary_trim_little_endien $infoTimestamp 16 63]
    set infoTimestamp [::mu3e::helpers::bin2hex $infoTimestamp]
    set infoCommand [::mu3e::helpers::hex2bin [lindex $logTuple 2]]
    set infoCommand [::mu3e::helpers::binary_trim_little_endien $infoCommand 0 7]
    set infoCommand [::upload_subsystem_bts::gui::decRunCommand $infoCommand]
    set infoPayload [lindex $logTuple 1]
    set infoTimestampExe [lindex $logTuple 0]
    # surpress empty tuple
    if {$infoTimestamp == 0x0} {
        toolkit_send_message info "readbackLogFifo: FIFO might be empty now (ts = 0)"
        return -code ok 
    }
    
    # info -> table
    toolkit_set_property $tableName rowIndex $currentRow
    toolkit_set_property $tableName columnIndex 0
    toolkit_set_property $tableName cellText $infoTimestamp
    toolkit_set_property $tableName columnIndex 1
    toolkit_set_property $tableName cellText $infoCommand
    toolkit_set_property $tableName columnIndex 2
    toolkit_set_property $tableName cellText $infoPayload
    toolkit_set_property $tableName columnIndex 3
    toolkit_set_property $tableName cellText $infoTimestampExe
    
    # enlongate table
    if {[toolkit_get_property $tableName rowCount] <= [expr $currentRow + 1]} {
        toolkit_set_property $tableName rowCount [expr [toolkit_get_property $tableName rowCount] + 1]
    }
    # incr row count 
    ::mu3e::helpers::set_global_variable $fd_global_variable "logTable_current_row" [expr $currentRow + 1]
    
    
    
    return -code ok
    
}

proc ::upload_subsystem_bts::gui::clearLogFifo {tableName} {
    variable fd_global_variable
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    # get the base address of runctl host csr in qsys
    set baseCsr [::mu3e::helpers::get_global_variable $fd_global_variable "runctl_mgmt_host.csr_base_address"]
    set controlAddr [expr {$baseCsr + (0x02 << 2)}]
    set controlWord [master_read_32 $master_fd $controlAddr 1]
    # h2d: CSR_CONTROL bit1 is log_flush (W1P)
    master_write_32 $master_fd $controlAddr [expr {($controlWord + 0) | 0x2}]
    # also clear the logTable 
    # ... todo 
    toolkit_send_message info "readbackLogFifo: LOG FIFO flushed"
    return -code ok
}

proc ::upload_subsystem_bts::gui::decRunCommand {binaryCommand} {
    switch [::mu3e::helpers::bin2hex $binaryCommand] {
        0x30 {
            set command "RESET"
        } 
        0x31 {
            set command "STOP_RESET"
        }
        0x32 {
            set command "ENABLE"
        }
        0x33 {
            set command "DISABLE"
        }
        0x10 {
            set command "RUN_PREPARE"
        }
        0x11 {
            set command "RUN_SYNC"
        }
        0x12 {
            set command "START_RUN"
        }
        0x13 {
            set command "END_RUN" 
        }
        0x14 {
            set command "ABORT_RUN"
        }
        default {
            set command "WRONG COMMAND!"
        }
    
    }
    
    return $command

} 

