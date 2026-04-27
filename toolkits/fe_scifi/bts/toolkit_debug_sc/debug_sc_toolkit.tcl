package provide debug_sc 1.0
package require Tcl 8.5
package require math::fourier
#package require tdom 


namespace eval debug_sc_toolkit {
	
	set master_list	{} 
	set claimed_master_path {}
	# some address of the slaves 
	set mutrig_controller_csr_base_adr 0x2000
    # 0x3f010 (old)
    # 0x2000 (new)
	set schpad_ram_base_adr 0x1000
    # 0x0 (old)
    # 0x1000 (new)
	set result_ram_base_addr 0x40000
	set charge_injection_pulser_base_addr 0x04c4

	set address_to_read {0x0000}
	set address_to_write {0x0000}
	set data_to_write {0x0}
	set read_data {None}
	set write_status {"Not yet written"}
	set write_rdbk_en false
	
	set asic_number 4
	set asic_number_tsa 4
	set asic_mask {}
	for {set i 0} {$i<$asic_number} {incr i} {
		lappend asic_mask 0
	}
	set mask_page_show_en 0
	
	# parameter name, bit length, initial value
	# h(34) ch(71*32) t f = total 2662 bits
	set mutrig_header_param [list {"gen_idle" 1 1} {"sync_ch_rst" 1 1} {"ext_trig_mode" 1 0} {"ext_trig_endtime_sign" 1 0} {"ext_trig_offset" 4 0} {"ext_trig_endtime" 4 0} {"ms_limits" 5 0} {"ms_switch_sel" 1 0} {"ms_debug" 1 0} {"tx_mode" 3 4} {"pll_setcoarse" 1 0} {"pll_envomonitor" 1 0} {"disable_coarse" 1 0} {"pll_lol_dbg" 1 0} {"en_ch_evt_cnt" 1 0} {"dmon_sel" 5 31} {"dmon_sel_enable" 1 0} {"dmon_sw" 1 0}]
	set mutrig_ch_param [list {"energy_c_en" 1 1} {"energy_r_en" 1 1} {"sswitch" 1 1} {"cm_sensing_high_r" 1 0} {"amon_en_n" 1 1} {"edge" 1 1} {"edge_cml" 1 0} {"cml_sc" 1 0} {"tdctest_n" 1 1} {"amonctrl" 3 0} {"comp_spi" 2 0} {"tthresh_offset_1" 1 0} {"sipm" 6 15} {"tthresh_offset_2" 1 0} {"tthresh_sc" 2 0} {"tthresh" 6 62} {"ampcom_sc" 2 0} {"ampcom" 6 4} {"tthresh_offset_0" 1 0} {"inputbias" 6 4} {"ethresh" 8 0} {"ebias" 3 0} {"pole_sc" 1 0} {"pole" 6 63} {"cml" 4 8} {"delay" 1 0} {"pole_en_n" 1 0} {"mask" 1 0} {"recv_all" 1 1}] 
	set mutrig_tdc_param [list {"vnd2c_scale" 1 0} {"vnd2c_offset" 2 3} {"vnd2c" 6 31} {"vncntbuffer_scale" 1 0} {"vncntbuffer_offset" 2 3} {"vncntbuffer" 6 7} {"vncnt_scale" 1 0} {"vncnt_offset" 2 3} {"vncnt" 6 40} {"vnpcp_scale" 1 0} {"vnpcp_offset" 2 3} {"vnpcp" 6 15} {"vnvcodelay_scale" 1 0} {"vnvcodelay_offset" 2 3} {"vnvcodelay" 6 20} {"vnvcobuffer_scale" 1 0} {"vnvcobuffer_offset" 2 0} {"vnvcobuffer" 6 10} {"vnhitlogic_scale" 1 0} {"vnhitlogic_offset" 2 3} {"vnhitlogic" 6 20} {"vnpfc_scale" 1 0} {"vnpfc_offset" 2 3} {"vnpfc" 6 15} {"latchbias" 12 1800}]
	set mutrig_footer_param [list {"coin_xbar_lower_rx_ena" 1 0} {"coin_xbar_lower_tx_ena" 1 1} {"coin_xbar_lower_tx_vdac" 8 155} {"coin_xbar_lower_tx_idac" 6 0} {"coin_mat_xbl" 3 0} {"coin_mat_0" 6 0} {"coin_mat_1" 6 0} {"coin_mat_2" 6 0} {"coin_mat_3" 6 0} {"coin_mat_4" 6 0} {"coin_mat_5" 6 0} {"coin_mat_6" 6 0} {"coin_mat_7" 6 0} {"coin_mat_8" 6 0} {"coin_mat_9" 6 0} {"coin_mat_10" 6 0} {"coin_mat_11" 6 0} {"coin_mat_12" 6 0} {"coin_mat_13" 6 0} {"coin_mat_14" 6 0} {"coin_mat_15" 6 0} {"coin_mat_16" 6 0} {"coin_mat_17" 6 0} {"coin_mat_18" 6 0} {"coin_mat_19" 6 0} {"coin_mat_20" 6 63} {"coin_mat_21" 6 0} {"coin_mat_22" 6 0} {"coin_mat_23" 6 0} {"coin_mat_24" 6 63} {"coin_mat_25" 6 0} {"coin_mat_26" 6 0} {"coin_mat_27 " 6 0} {"coin_mat_28" 6 0} {"coin_mat_29" 6 0} {"coin_mat_30" 6 0} {"coin_mat_31" 6 0} {"coin_mat_xbu" 3 0} {"coin_xbar_upper_rx_ena" 1 0} {"coin_xbar_upper_tx_ena" 1 1} {"coin_xbar_upper_tx_vdac" 8 155} {"coin_xbar_upper_tx_idac" 6 0} {"coin_wnd" 1 0} {"amon_en" 1 0} {"amon_dac" 8 0} {"dmon_1_en" 1 0} {"dmon_1_dac" 8 0} {"dmon_2_en" 1 0} {"dmon_2_dac" 8 0} {"lvds_tx_vcm" 8 155} {"lvds_tx_bias" 6 0}] 

	set pulser_en 0	
	set asic_config_sel_to_load 0

	set tsa_all_plots {}
		
	proc dashBoard {} {
	
		variable claimed_master_path
		variable mutrigs_config_list
		set mutrigs_config_list {}
		variable mutrigs_config_words
		variable asic_mask
		variable asic_config_sel_to_load
		variable pulser_en
	
		toolkit_set_property self title "Debug Slow Control (SciFi) "
		toolkit_set_property self visible true
		
		# Create the central TAB
		toolkit_add 			Tab 			tabbedGroup 		self
		
		###########################################################
		#  ____           _____ _____ _____   _______       ____  #
		# |  _ \   /\    / ____|_   _/ ____| |__   __|/\   |  _ \ #
		# | |_) | /  \  | (___   | || |         | |  /  \  | |_) |#
		# |  _ < / /\ \  \___ \  | || |         | | / /\ \ |  _ < #
		# | |_) / ____ \ ____) |_| || |____     | |/ ____ \| |_) |#
		# |____/_/    \_\_____/|_____\_____|    |_/_/    \_\____/ #
        #                                                         # 
        ###########################################################   
		toolkit_add				basicGroup		group				Tab
		toolkit_set_property	basicGroup		title				Basic
		
		
		####################################################################
		#       _ _______       _____    _____ _____   ____  _    _ _____  #
		#      | |__   __|/\   / ____|  / ____|  __ \ / __ \| |  | |  __ \ #
		#      | |  | |  /  \ | |  __  | |  __| |__) | |  | | |  | | |__) |#
		#  _   | |  | | / /\ \| | |_ | | | |_ |  _  /| |  | | |  | |  ___/ #
		# | |__| |  | |/ ____ \ |__| | | |__| | | \ \| |__| | |__| | |     #
		#  \____/   |_/_/    \_\_____|  \_____|_|  \_\\____/ \____/|_|     #
		#                                								   #
		####################################################################
		## Link Jtag group
		toolkit_add 			linkjtagGroup 		group 		basicGroup
		toolkit_set_property	linkjtagGroup		expandableX	false
		toolkit_set_property	linkjtagGroup		expandableY	false
		toolkit_set_property	linkjtagGroup		itemsPerRow 1
		toolkit_set_property	linkjtagGroup 		title		"Link the Targeted JTAG to AVMM Master IP"
			
		# button to read master paths
		toolkit_add				getmp_show	button		linkjtagGroup
		toolkit_set_property	getmp_show	enabled 	true
		toolkit_set_property	getmp_show	expandableX false
		toolkit_set_property	getmp_show	expandableY false
		toolkit_set_property	getmp_show	text		"Read Alive Service Path"
		toolkit_set_property	getmp_show	onClick 	\
		{set ::debug_sc_toolkit::master_list [ ::debug_sc_toolkit::get_master_path ]}

		
		# combo-box to select 
		toolkit_add				getmi_cb	comboBox	linkjtagGroup
		toolkit_set_property	getmi_cb	enabled 	true
		toolkit_set_property	getmi_cb	expandableX 	false
		toolkit_set_property	getmi_cb	expandableY 	false
		toolkit_set_property	getmi_cb	preferredWidth 400
		#toolkit_set_property	getmi_cb	maxWidth 800
		toolkit_set_property	getmi_cb	foregroundColor blue
		
		toolkit_set_property	getmi_cb 	options		"?"
		# this returns the master index
		toolkit_set_property	getmi_cb 	onChange	\
		{set master_index_selected [ toolkit_get_property getmi_cb selected ]}
		
		# botton to record selected path
		toolkit_add				getmp_set	button		linkjtagGroup
		toolkit_set_property	getmp_set	enabled 	true
		toolkit_set_property	getmp_set	expandableX false
		toolkit_set_property	getmp_set	expandableY false
		toolkit_set_property	getmp_set	text		"Set Selected Master Path"
		toolkit_set_property	getmp_set	onClick 	\
		{set ::debug_sc_toolkit::master_path [ ::debug_sc_toolkit::get_open_master_path $master_index_selected ]}
		
		
		#################################################################################
		#    _____  ______  _____ ______ _______    _____ _____   ____  _    _ _____    #
		#   |  __ \|  ____|/ ____|  ____|__   __|  / ____|  __ \ / __ \| |  | |  __ \   #
		#   | |__) | |__  | (___ | |__     | |    | |  __| |__) | |  | | |  | | |__) |  #
		#   |  _  /|  __|  \___ \|  __|    | |    | | |_ |  _  /| |  | | |  | |  ___/   #
		#   | | \ \| |____ ____) | |____   | |    | |__| | | \ \| |__| | |__| | |       #
		#   |_|  \_\______|_____/|______|  |_|     \_____|_|  \_\\____/ \____/|_|       #
		#                                                                               #
		#################################################################################
		## Reset debug path group
		toolkit_add 			resetdebugGroup 		group 		basicGroup
		toolkit_set_property	resetdebugGroup			expandableX	false
		toolkit_set_property	resetdebugGroup			expandableY	false
		toolkit_set_property	resetdebugGroup			itemsPerRow 1
		toolkit_set_property	resetdebugGroup 		title		"Assert Reset from the Targeted JTAG to AVMM Master IP"
		
		# button to start read paths
		toolkit_add				getmp2_set	button		resetdebugGroup
		toolkit_set_property	getmp2_set	enabled 	true
		toolkit_set_property	getmp2_set	expandableX false
		toolkit_set_property	getmp2_set	expandableY false
		toolkit_set_property	getmp2_set	text		"Read Alive Service Path"
		toolkit_set_property	getmp2_set	onClick 	\
		{set jtag_debug_list [ ::debug_sc_toolkit::get_jtag_debug_path ]}
		
		# subgroup to display the paths
		toolkit_add 			resetdebugsubGroup 	group 		resetdebugGroup
		toolkit_set_property	resetdebugsubGroup	expandableX	false
		toolkit_set_property	resetdebugsubGroup	expandableY	false
		toolkit_set_property	resetdebugsubGroup	itemsPerRow 1
		toolkit_set_property	resetdebugsubGroup 	title		"Alived Service Paths"
		
		# text showing the path
		toolkit_add 			viewmp2_text 	text 			resetdebugsubGroup 
		toolkit_set_property 	viewmp2_text 	expandableX 	false
		toolkit_set_property 	viewmp2_text 	expandableY 	false
		toolkit_set_property 	viewmp2_text 	preferredWidth 	300
		toolkit_set_property 	viewmp2_text 	preferredHeight 300
		toolkit_set_property 	viewmp2_text 	editable 		false
		toolkit_set_property 	viewmp2_text 	htmlCapable 	true
		toolkit_set_property 	viewmp2_text 	text 			"No master path yet"
		
		# combo-box to select 
		toolkit_add				getmi2_cb	comboBox	resetdebugGroup
		toolkit_set_property	getmi2_cb	enabled 	true
		toolkit_set_property	getmi2_cb	expandableX false
		toolkit_set_property	getmi2_cb	expandableY false
		toolkit_set_property	getmi2_cb 	options		"?"
		# this returns the jtag debug index
		toolkit_set_property	getmi2_cb 	onChange	\
		{set jtag_debug_index_selected [ toolkit_get_property getmi2_cb selected ]}
		
		# button to reset the master
		toolkit_add 			rst_set		button		resetdebugGroup
		toolkit_set_property	rst_set		enabled		true
		toolkit_set_property	rst_set		expandableX false
		toolkit_set_property	rst_set		expandableY false
		toolkit_set_property	rst_set		text		"Reset JTAG Debug of Selected Master Path"
		toolkit_set_property	rst_set 	onClick		\
		{::debug_sc_toolkit::reset_jtag2avmm $jtag_debug_index_selected}
	
		
		
		###################################################################################################################
		#    _____  ______ _____ _____  _____ _______ ______ _____     _____       ____          __   _______       ____  #
		#   |  __ \|  ____/ ____|_   _|/ ____|__   __|  ____|  __ \   |  __ \     / /\ \        / /  |__   __|/\   |  _ \ #
		#   | |__) | |__ | |  __  | | | (___    | |  | |__  | |__) |  | |__) |   / /  \ \  /\  / /      | |  /  \  | |_) |#
		#   |  _  /|  __|| | |_ | | |  \___ \   | |  |  __| |  _  /   |  _  /   / /    \ \/  \/ /       | | / /\ \ |  _ < #
		#   | | \ \| |___| |__| |_| |_ ____) |  | |  | |____| | \ \   | | \ \  / /      \  /\  /        | |/ ____ \| |_) |#
		#   |_|  \_\______\_____|_____|_____/   |_|  |______|_|  \_\  |_|  \_\/_/        \/  \/         |_/_/    \_\____/ #
		#                                                                                                                 #
		###################################################################################################################                                                                                                                 
		## Register Read-Write TAB
		toolkit_add				regRWGroup		group				Tab
		toolkit_set_property	regRWGroup		title				"Read/Write Registers"
		
		#######################################################################
		#  _____  ______          _____     _____ _____   ____  _    _ _____  #
		# |  __ \|  ____|   /\   |  __ \   / ____|  __ \ / __ \| |  | |  __ \ #
		# | |__) | |__     /  \  | |  | | | |  __| |__) | |  | | |  | | |__) |#
		# |  _  /|  __|   / /\ \ | |  | | | | |_ |  _  /| |  | | |  | |  ___/ #
		# | | \ \| |____ / ____ \| |__| | | |__| | | \ \| |__| | |__| | |     #
		# |_|  \_\______/_/    \_\_____/   \_____|_|  \_\\____/ \____/|_|     #
		#                                                                     #
        #######################################################################      
		## Read Group
		toolkit_add 			readGroup 	group 		regRWGroup
		toolkit_set_property	readGroup	expandableX	false
		toolkit_set_property	readGroup	expandableY	false
		toolkit_set_property	readGroup	itemsPerRow 1
		toolkit_set_property	readGroup 	title		"Master Read 32 bit (Byte-Addressing)"
		
		# text box for input address
		toolkit_add				address_of_read		text			readGroup
		toolkit_set_property	address_of_read		expandableX		true
		toolkit_set_property	address_of_read		preferredWidth	100
		toolkit_set_property	address_of_read		preferredHeight	10
		toolkit_set_property	address_of_read		editable		true
		toolkit_set_property	address_of_read		text			$::debug_sc_toolkit::address_to_read
		
		# button to start read
		toolkit_add				startRead	button		readGroup
		toolkit_set_property	startRead	enabled 	true
		toolkit_set_property	startRead	expandableX false
		toolkit_set_property	startRead	expandableY false
		toolkit_set_property	startRead	text		"Set Address and Read"
		toolkit_set_property	startRead	onClick 	\
		{ ::debug_sc_toolkit::read_this_address }
		
		# text box for read data (display)
		toolkit_add				readData		text			readGroup
		toolkit_set_property	readData		expandableX		true
		toolkit_set_property	readData		preferredWidth	100
		toolkit_set_property	readData		preferredHeight	10
		toolkit_set_property	readData		editable		false
		toolkit_set_property	readData		text			$::debug_sc_toolkit::read_data
		
		
        ##################################################################################
		# __          _______  _____ _______ ______    _____ _____   ____  _    _ _____  #
		# \ \        / /  __ \|_   _|__   __|  ____|  / ____|  __ \ / __ \| |  | |  __ \ #
		#  \ \  /\  / /| |__) | | |    | |  | |__    | |  __| |__) | |  | | |  | | |__) |#
		#   \ \/  \/ / |  _  /  | |    | |  |  __|   | | |_ |  _  /| |  | | |  | |  ___/ #
		#	 \  /\  /  | | \ \ _| |_   | |  | |____  | |__| | | \ \| |__| | |__| | |     #
		#	  \/  \/   |_|  \_\_____|  |_|  |______|  \_____|_|  \_\\____/ \____/|_|     #
		#                                                                                #
		##################################################################################																																					
		## Write Group
		toolkit_add 			writeGroup 	group 		regRWGroup
		toolkit_set_property	writeGroup	expandableX	false
		toolkit_set_property	writeGroup	expandableY	false
		toolkit_set_property	writeGroup	itemsPerRow 1
		toolkit_set_property	writeGroup 	title		"Master Write 32 bit (Byte-Addressing)"

		# text-box for input address
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
		toolkit_set_property	address_of_write		text			$::debug_sc_toolkit::address_to_write
		toolkit_set_property	address_of_write		toolTip			"Write Address"
		
		# text-box for input write data
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
		toolkit_set_property	data_of_write		text			$::debug_sc_toolkit::data_to_write
		toolkit_set_property	data_of_write		toolTip			"Write Data"
		
		# button to start write
		toolkit_add				startRead	button		writeGroup
		toolkit_set_property	startRead	enabled 	true
		toolkit_set_property	startRead	expandableX false
		toolkit_set_property	startRead	expandableY false
		toolkit_set_property	startRead	text		"Set Address/Data to Write"
		toolkit_set_property	startRead	onClick 	\
		{ ::debug_sc_toolkit::write_this_address }
		
		# check-box for enabling readback validation
		toolkit_add				chkbox_rden		checkBox 	writeGroup
		toolkit_set_property	chkbox_rden		enabled		true
		toolkit_set_property	chkbox_rden		toolTip		"Disable it to prevent read side effect"
		toolkit_set_property	chkbox_rden		text		"Enable the readback validation"
		toolkit_set_property	chkbox_rden		onClick 	{::debug_sc_toolkit::en_rdbk_callback}
		
		# text-box for write data (readback validation)
		toolkit_add				writeValidation		text			writeGroup
		toolkit_set_property	writeValidation		expandableX		true
		toolkit_set_property	writeValidation		preferredWidth	100
		toolkit_set_property	writeValidation		preferredHeight	50
		toolkit_set_property	writeValidation		editable		false
		toolkit_set_property	writeValidation		text			$::debug_sc_toolkit::write_status
		
		
		########################################################################
		#    _____  _    _ _       _____ ______ _____     _______       ____   #
		#   |  __ \| |  | | |     / ____|  ____|  __ \   |__   __|/\   |  _ \  #
		#   | |__) | |  | | |    | (___ | |__  | |__) |     | |  /  \  | |_) | #
		#   |  ___/| |  | | |     \___ \|  __| |  _  /      | | / /\ \ |  _ <  #
		#   | |    | |__| | |____ ____) | |____| | \ \      | |/ ____ \| |_) | #
		#   |_|     \____/|______|_____/|______|_|  \_\     |_/_/    \_\____/  #
		#                                                                      #
		########################################################################                                                                     
		# pulser tab
		toolkit_add 			pulserGroup 	group 		Tab
		toolkit_set_property	pulserGroup		title		"Pulser"
		#
		toolkit_add				pulserCtrlGroup	group		pulserGroup
		toolkit_set_property	pulserCtrlGroup	title		"Pulser Control"
		toolkit_set_property	pulserCtrlGroup	itemsPerRow 1
		# enable
		toolkit_add				en_pulser_set	button		pulserCtrlGroup
		toolkit_set_property	en_pulser_set	text 		"Enable pulser"
		toolkit_set_property	en_pulser_set	visible		true
		toolkit_set_property	en_pulser_set	onClick		{::debug_sc_toolkit::toggle_pulser}
		# input of frequency
		toolkit_add				pulser_freqGroup 	group		pulserCtrlGroup
		toolkit_set_property	pulser_freqGroup	title		"pulser frequency in kHz"
		toolkit_set_property	pulser_freqGroup	preferredWidth	200
		toolkit_add				pulser_freq		text		pulser_freqGroup
		toolkit_set_property	pulser_freq		text		"100"
		toolkit_set_property	pulser_freq		toolTip		"pulser frequency in kHz"
		toolkit_set_property	pulser_freq		preferredWidth	200
		# input of width 
		toolkit_add				pulser_widthGroup 	group		pulserCtrlGroup
		toolkit_set_property	pulser_widthGroup	title		"width in 8ns"
		toolkit_set_property	pulser_widthGroup	preferredWidth	200
		toolkit_add				pulser_width	text		pulser_widthGroup
		toolkit_set_property	pulser_width	text		"40"
		toolkit_set_property	pulser_width	toolTip		"width in ns"
		toolkit_set_property	pulser_width	preferredWidth	200
		
		
		
		#################################################################################################################
		#    __  __ _    _ _______ _____  _____ _____     _____ ____  _   _ ______ _____ _____    _______       ____    #
		#   |  \/  | |  | |__   __|  __ \|_   _/ ____|   / ____/ __ \| \ | |  ____|_   _/ ____|  |__   __|/\   |  _ \   #
		#   | \  / | |  | |  | |  | |__) | | || |  __   | |   | |  | |  \| | |__    | || |  __      | |  /  \  | |_) |  #
		#   | |\/| | |  | |  | |  |  _  /  | || | |_ |  | |   | |  | | . ` |  __|   | || | |_ |     | | / /\ \ |  _ <   #
		#   | |  | | |__| |  | |  | | \ \ _| || |__| |  | |___| |__| | |\  | |     _| || |__| |     | |/ ____ \| |_) |  #
		#   |_|  |_|\____/   |_|  |_|  \_\_____\_____|   \_____\____/|_| \_|_|    |_____\_____|     |_/_/    \_\____/   #
		#                                                                                                               #
		#################################################################################################################                                                                                                            
		# Configure MuTRiG TAB
		toolkit_add				mutrigCfgGroup		group				Tab
		toolkit_set_property	mutrigCfgGroup		title				"MuTRiG Config"
		
		# Generate Config Pattern Group
		toolkit_add 			gencfgGroup 	group 		mutrigCfgGroup
		toolkit_set_property 	gencfgGroup 	itemsPerRow		1
		toolkit_set_property	gencfgGroup		title		"Control Panel"
		toolkit_add				gencfg_set		button 		gencfgGroup
		toolkit_set_property	gencfg_set		text 		"Gen bit pattern"
		## this generate words in hex from bit stream which gets updated param list from these combo-boxes
		toolkit_set_property 	gencfg_set		onClick		{::debug_sc_toolkit::create_bit_streams}
		
		## MuTRiG TABs (0-7 asic)
		toolkit_add				mutrigTab		tabbedGroup				mutrigCfgGroup
		for {set tab_index 0} {$tab_index < $::debug_sc_toolkit::asic_number} {incr tab_index} {
			### Init the config list of all mutrigs
			set mutrig_config_list {}
			lappend mutrig_config_list $::debug_sc_toolkit::mutrig_header_param 
			set ch_config_list {}
			for {set i 0} {$i<32} {incr i} {
				lappend ch_config_list $::debug_sc_toolkit::mutrig_ch_param
			}
			lappend mutrig_config_list $ch_config_list
			lappend mutrig_config_list $::debug_sc_toolkit::mutrig_tdc_param $::debug_sc_toolkit::mutrig_footer_param
			lappend mutrigs_config_list $mutrig_config_list
			
			### Setup GUIs
			toolkit_add				"mutrig${tab_index}Group"		group					mutrigTab
			toolkit_set_property	"mutrig${tab_index}Group"		expandableX				true
			toolkit_set_property	"mutrig${tab_index}Group"		expandableY				true
			toolkit_set_property	"mutrig${tab_index}Group"		title 					"MuTRiG${tab_index}"
			toolkit_add				"mutrig${tab_index}Tab"			tabbedGroup				"mutrig${tab_index}Group"
			
			### header group tab
			toolkit_add				"mutrig${tab_index}hGroup"		group 					"mutrig${tab_index}Tab"	
			toolkit_set_property	"mutrig${tab_index}hGroup"		title 					"Header"
			toolkit_set_property	"mutrig${tab_index}hGroup"		itemsPerRow				4
			toolkit_set_property	"mutrig${tab_index}hGroup"		preferredWidth			600
			toolkit_set_property	"mutrig${tab_index}hGroup"		preferredHeight			300
			#### bit fields (header)
			for {set i 0} {$i< [llength $::debug_sc_toolkit::mutrig_header_param ]} {incr i} {
				set item [lindex $::debug_sc_toolkit::mutrig_header_param $i]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				::debug_sc_toolkit::setup_combobox 		"mutrig${tab_index}hGroup" 	"${param_name}${tab_index}_cb"	$tab_index 	0	0	$i	
			}
			### channel group tab
			toolkit_add				"mutrig${tab_index}ChGroup"		group					"mutrig${tab_index}Tab"
			toolkit_set_property	"mutrig${tab_index}ChGroup"		title 					"Channel"
			toolkit_add				"mutrig${tab_index}ChTab"		tabbedGroup				"mutrig${tab_index}ChGroup"
			for {set i 0} {$i<32} {incr i} {
				#### each channel
				toolkit_add				"mutrig${tab_index}${i}cGroup"		group 					"mutrig${tab_index}ChTab"
				toolkit_set_property	"mutrig${tab_index}${i}cGroup"		title					"Ch${i}"
				toolkit_set_property	"mutrig${tab_index}${i}cGroup"		itemsPerRow				4
				##### bit fields (channel)
				for {set j 0} {$j< [llength $::debug_sc_toolkit::mutrig_ch_param ]} {incr j} {
					set item [lindex $::debug_sc_toolkit::mutrig_ch_param $j]
					set param_name [lindex $item 0]
					set param_bit_len [lindex $item 1]
					set param_value_dec [lindex $item 2]
					::debug_sc_toolkit::setup_combobox 		"mutrig${tab_index}${i}cGroup" 	"${param_name}${tab_index}_ch${i}_cb"	$tab_index 	1	$i	$j	
				}
			} 
			### TDC group tab
			toolkit_add				"mutrig${tab_index}tGroup"		group 					"mutrig${tab_index}Tab"
			toolkit_set_property	"mutrig${tab_index}tGroup"		title					"TDC"
			toolkit_set_property	"mutrig${tab_index}tGroup"		itemsPerRow				4
			#### bit field (tdc)
			for {set i 0} {$i< [llength $::debug_sc_toolkit::mutrig_tdc_param ]} {incr i} {
				set item [lindex $::debug_sc_toolkit::mutrig_tdc_param $i]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				::debug_sc_toolkit::setup_combobox 		"mutrig${tab_index}tGroup" 	"${param_name}${tab_index}_cb"	$tab_index 	2	0	$i	
			}
			### Footer group tab
			toolkit_add				"mutrig${tab_index}fGroup"		group 					"mutrig${tab_index}Tab"
			toolkit_set_property	"mutrig${tab_index}fGroup"		title					"Footer"
			toolkit_set_property	"mutrig${tab_index}fGroup"		itemsPerRow				4
			#### bit field (footer)
			for {set i 0} {$i< [llength $::debug_sc_toolkit::mutrig_footer_param ]} {incr i} {
				set item [lindex $::debug_sc_toolkit::mutrig_footer_param $i]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				::debug_sc_toolkit::setup_combobox 		"mutrig${tab_index}fGroup" 	"${param_name}${tab_index}_cb"	$tab_index 	3	0	$i	
			}
			
		}
		
		## Control Panel
		toolkit_add				load_ram_set		button 		gencfgGroup
		toolkit_set_property	load_ram_set 		text		"Load Scratch-pad RAM"
		toolkit_set_property	load_ram_set 		onClick		{::debug_sc_toolkit::load_ram_with_words $::debug_sc_toolkit::asic_config_sel_to_load}
		toolkit_add				load_ram_cb			comboBox	gencfgGroup
		toolkit_set_property	load_ram_cb			label		"asic"
		set cb_options {}
		for {set i 0} {$i < $debug_sc_toolkit::asic_number} {incr i} {
			lappend cb_options $i
		}
		toolkit_set_property	load_ram_cb 		options		$cb_options
		toolkit_set_property	load_ram_cb			selected 	$asic_config_sel_to_load
		toolkit_set_property	load_ram_cb			onChange	{set debug_sc_toolkit::asic_config_sel_to_load [toolkit_get_property 	load_ram_cb		selected]}
		
		toolkit_add				sel_ch_cb			comboBox	gencfgGroup
		toolkit_set_property	sel_ch_cb			label		"ch"
		set ch_cb_options {}
		for {set i 0} {$i < 32} {incr i} {
			lappend ch_cb_options $i
		}
		toolkit_set_property	sel_ch_cb 			options		$ch_cb_options
		
		toolkit_add				send_cmd_set		button 		gencfgGroup
		toolkit_set_property	send_cmd_set 		text		"Send Command to MuTRiG Controller"
		toolkit_set_property	send_cmd_set 		onClick		{debug_sc_toolkit::master_write_cmd_to_mctrl $::debug_sc_toolkit::asic_config_sel_to_load}
		
		toolkit_add				cfg_all_set			button 		gencfgGroup
		toolkit_set_property	cfg_all_set 		text		"Configure All MuTRiGs"
		toolkit_set_property	cfg_all_set 		onClick		{debug_sc_toolkit::cfg_all_asics}
		
		toolkit_add				show_mask_set		button 		gencfgGroup
		toolkit_set_property	show_mask_set 		text		"Show ASIC Mask Page"
		toolkit_set_property	show_mask_set 		onClick		{::debug_sc_toolkit::toggle_show_mask_page}
		
		toolkit_add				copy_from_set		button		gencfgGroup
		toolkit_set_property	copy_from_set		text		"Copy Settings from the set ASIC to others"
		toolkit_set_property	copy_from_set		onClick		{::debug_sc_toolkit::copy_settings}
		
		toolkit_add				copy_from_ch_set	button		gencfgGroup
		toolkit_set_property	copy_from_ch_set	text		"Copy Settings from the set Channel to other channels"
		toolkit_set_property	copy_from_ch_set	onClick		{::debug_sc_toolkit::copy_settings_ch}
		
		toolkit_add				save_to_set			fileChooserButton		gencfgGroup
		toolkit_set_property	save_to_set			chooserButtonText		"Save"
		toolkit_set_property	save_to_set			onChoose				{::debug_sc_toolkit::save_to_file}
		toolkit_set_property	save_to_set			text					"Save Settings to file"
		
		toolkit_add				save_as_xml_en_cnb	checkBox				gencfgGroup
		toolkit_set_property	save_as_xml_en_cnb	text					"Save as XML format"
		
		toolkit_add				load_from_set			fileChooserButton		gencfgGroup
		toolkit_set_property	load_from_set			chooserButtonText		"Load"
		toolkit_set_property	load_from_set			onChoose				{::debug_sc_toolkit::load_from_file}
		toolkit_set_property	load_from_set			text					"Load Settings from file"
		
		::debug_sc_toolkit::setup_mask_page
		
		###################################################
		#    _______ _____            _______       ____  #
		#   |__   __/ ____|  /\      |__   __|/\   |  _ \ #
		#      | | | (___   /  \        | |  /  \  | |_) |#
		#      | |  \___ \ / /\ \       | | / /\ \ |  _ < #
		#      | |  ____) / ____ \      | |/ ____ \| |_) |#
		#      |_| |_____/_/    \_\     |_/_/    \_\____/ #
		#                                                 #
		###################################################       
		toolkit_add				tsaGroup		group				Tab
		toolkit_set_property	tsaGroup		title				"Threshold Scan"
		toolkit_add				tsaTab			tabbedGroup				tsaGroup
		for {set tab_index 0} {$tab_index < $::debug_sc_toolkit::asic_number_tsa} {incr tab_index} {
			# the threshold scan result tab
			toolkit_add				"tsa${tab_index}Group"		group					tsaTab
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
		toolkit_add				tsaCtlrGroup			group				tsaGroup
		toolkit_set_property	tsaCtlrGroup			title				"Control Panel"
		toolkit_set_property	tsaCtlrGroup			itemsPerRow			1
		toolkit_add				run_tsa_set				button				tsaCtlrGroup
		toolkit_set_property	run_tsa_set				text				"RUN Threshold Scan for asic ${asic_config_sel_to_load}"
		toolkit_set_property	run_tsa_set				onClick				{::debug_sc_toolkit::start_tsa}
		
		toolkit_add				run_all_tsa_set				button				tsaCtlrGroup
		toolkit_set_property	run_all_tsa_set				text				"RUN Threshold Scan for all asics"
		toolkit_set_property	run_all_tsa_set				onClick				{::debug_sc_toolkit::start_all_tsa}

		toolkit_add				save_tsa_plots_to_file_set		fileChooserButton			tsaCtlrGroup
		toolkit_set_property	save_tsa_plots_to_file_set		chooserButtonText			"Save"
		toolkit_set_property	save_tsa_plots_to_file_set		text			"Save TSA plots to file" 
		toolkit_set_property	save_tsa_plots_to_file_set		onChoose			{::debug_sc_toolkit::save_tsa_to_file}


		
		
		return -code ok
	}
	
	
	
	## Functions
	proc get_open_master_path { master_index } {
		variable claimed_master_path
		set mpath [lindex [get_service_paths master] $master_index] 
		set master_path [claim_service master $mpath ""]
		set claimed_master_path $master_path
		return $master_path
	}
	
	proc get_master_path {} {
		# callback to link master (display)
		#refresh_connections
		variable master_list_private [get_service_paths master]
		variable master_index_option_list {}
		# display master path
		#toolkit_set_property	viewmp_text	text [ format "%s" $master_list_private ]
		# make list of options for master index
		for {set i 0} {$i < [ llength $master_list_private ]} {incr i} {
			variable master_index_option_list [ linsert $master_index_option_list $i $i ]
		}
		# set list of options for master index
		toolkit_set_property	getmi_cb 	options	$master_list_private
		return $master_list_private
	}
	

	
	proc get_jtag_debug_path {} {
	# callback to link jtag debug (display)
		#refresh_connections
		variable jtag_debug_list_private [get_service_paths jtag_debug]
		variable jtag_debug_index_option_list {}
		# display master path
		toolkit_set_property	viewmp2_text	text [ format "%s" $jtag_debug_list_private ]
		# make list of options for master index
		for {set i 0} {$i < [ llength $jtag_debug_list_private ]} {incr i} {
			variable jtag_debug_index_option_list [ linsert $jtag_debug_index_option_list $i $i ]
		}
		# set list of options for master index
		toolkit_set_property	getmi2_cb 	options	$jtag_debug_index_option_list
		return $jtag_debug_list_private
	}
	
	proc reset_jtag2avmm { jtag_debug_index } {
		set jtag_debug_path [lindex [get_service_paths jtag_debug] $jtag_debug_index ]
		set claim_jtag_path [claim_service jtag_debug $jtag_debug_path ""]
		jtag_debug_reset_system $claim_jtag_path
		return -code ok
	}
	
	proc read_this_address {} {
		variable claimed_master_path
		set master_path $claimed_master_path
		set address [toolkit_get_property address_of_read text]
		set ::debug_sc_toolkit::read_data	[master_read_32 $master_path $address 1]
		toolkit_set_property readData text $::debug_sc_toolkit::read_data
		return -code ok		
	}
	
	proc write_this_address {} {
		variable claimed_master_path
		set master_path $claimed_master_path
		set address [toolkit_get_property address_of_write text]
		set data [toolkit_get_property data_of_write text]
		set data_rb 0
		# write
		set ::debug_sc_toolkit::write	[master_write_32 $master_path $address $data]
		# read-back check 
		if {$::debug_sc_toolkit::write_rdbk_en == true} {
			set data_rb	[master_read_32 $master_path $address 1]
			if {[expr $data_rb == $data]} {
				toolkit_set_property writeValidation text "OK"
			} else {
				toolkit_set_property writeValidation text [format "Warning: Readback not match, is 0x%X" $data_rb ]
			}
		} 
		return -code ok
	}
	
	proc en_rdbk_callback {} {
		set ::debug_sc_toolkit::write_rdbk_en [toolkit_get_property chkbox_rden checked]
		if {$::debug_sc_toolkit::write_rdbk_en == false } {
			toolkit_set_property writeValidation text "Read-back Disabled"
		} else {
			toolkit_set_property writeValidation text "Click Write Botton to Start Write with Read-back"
		}	
		return -code ok
	}
	
	proc create_bit_stream {header_param ch_param tdc_param footer_param} {
		# use the parameters lengths and value to create/output a bit stream (MSB is bit 0, LSB is bit "last"), except for latchbias.
		set bit_stream ""
		set bit_stream_len 0
		# do not invert some parameters (in else)
		foreach item $header_param {
			if {[string equal [lindex $item 0] "ext_trig_offset"] || [string equal [lindex $item 0] "ext_trig_endtime"] || [string equal [lindex $item 0] "ms_limits"] || [string equal [lindex $item 0] "tx_mode"]} {
				set bits [format "%0*b" [lindex $item 1] [lindex $item 2]]
				set bits_rev [string_reverse $bits]
				set bit_stream_len [expr $bit_stream_len + [lindex $item 1]]
				append bit_stream $bits_rev
			} else {
				set bits [format "%0*b" [lindex $item 1] [lindex $item 2]]
				set bit_stream_len [expr $bit_stream_len + [lindex $item 1]]
				append bit_stream $bits
			}
		}
		
		for {set ch 0} {$ch<32} {incr ch} {
			foreach item [lindex $ch_param $ch] {
				set bits [format "%0*b" [lindex $item 1] [lindex $item 2]]
				set bit_stream_len [expr $bit_stream_len + [lindex $item 1]]
				append bit_stream $bits
			}
		}
		
		foreach item $tdc_param {
		# NOTE: the latchbias is big-endien, while other bit fields are little-endien
			if {[string equal [lindex $item 0] "latchbias"]} {
				set bits [format "%0*b" [lindex $item 1] [lindex $item 2]]
				set bits_rev [string_reverse $bits]
				set bit_stream_len [expr $bit_stream_len + [lindex $item 1]]
				append bit_stream $bits_rev
			} else {
				set bits [format "%0*b" [lindex $item 1] [lindex $item 2]]
				set bit_stream_len [expr $bit_stream_len + [lindex $item 1]]
				append bit_stream $bits
			}
		}
		
		foreach item $footer_param {
			set bits [format "%0*b" [lindex $item 1] [lindex $item 2]]
			set bit_stream_len [expr $bit_stream_len + [lindex $item 1]]
			append bit_stream $bits
		}
		
		set missing_digits [expr 32 - {$bit_stream_len % 32}]
		set padding_zeros [format "%0*b" $missing_digits 0]
		append bit_stream $padding_zeros
		return $bit_stream
 	}
	
	proc parse_reverse_bit_stream {bit_stream} {
	# takes the whole bit stream and parse into a list of word in hex format 
		#puts $bit_stream
		set bit_stream_parsed [split [regexp -all -inline {\d{1,32}} $bit_stream]]
		set i 0
		set words_in_hex {}
		foreach word $bit_stream_parsed {
			#puts stderr "word $i"
			#puts $word
			incr i
			set word_reversed [::debug_sc_toolkit::string_reverse $word]
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
	
	proc write_master_with_words {words_in_hex starting_addr} {
		variable claimed_master_path
		set addr $starting_addr
		#puts "master path: ${claimed_master_path}"
		foreach word $words_in_hex {
			master_write_32 $claimed_master_path $addr $word
			set addr [expr $addr + 4]
			#puts "written: ${word} (${addr})"
		}
 

	}
	
	proc string_reverse {str} {
		set res {}
		set i [string length $str]
		while {$i > 0} {append res [string index $str [incr i -1]]}
		return $res
	}
	
	
	proc setup_combobox {group_name cb_name mutrig_index field_index ch_index param_index} {
		if {[string equal $field_index "1"]} {  
			set param_list [lindex [lindex [lindex [lindex $::debug_sc_toolkit::mutrigs_config_list $mutrig_index] $field_index] $ch_index] $param_index]
			set param_name [lindex $param_list 0]
			set bit_len [lindex $param_list 1]
			set param_value  [lindex $param_list 2]
		} else {
			set param_list [lindex [lindex [lindex $::debug_sc_toolkit::mutrigs_config_list $mutrig_index] $field_index] $param_index]
			set param_name [lindex $param_list 0]
			set bit_len [lindex $param_list 1]
			set param_value  [lindex $param_list 2]
		}
		set range_up [expr 2**${bit_len}-1]
		set cb_options {}
		for {set i 0} {$i <= $range_up} {incr i} {
			lappend cb_options $i
		}
		toolkit_add				$cb_name	comboBox	$group_name
		toolkit_set_property	$cb_name	label		$param_name
		toolkit_set_property	$cb_name 	options		$cb_options
		toolkit_set_property	$cb_name	selected    $param_value
		# callback
		toolkit_set_property	$cb_name	onChange	\
		{::debug_sc_toolkit::update_config_list}
		return -code ok
	}
	
	proc update_config_list {} {
		variable mutrigs_config_list 
		set mutrigs_config_list {}
		# update the whole config nested list when one combo-box is changed 
		# asic
		for {set tab_index 0} {$tab_index < $::debug_sc_toolkit::asic_number} {incr tab_index} {
			set mutrig_config_list {}
			## header 
			set header_list {}
			for {set i 0} {$i< [llength $::debug_sc_toolkit::mutrig_header_param ]} {incr i} {
				set item [lindex $::debug_sc_toolkit::mutrig_header_param $i]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_new_value [toolkit_get_property "${param_name}${tab_index}_cb" selected]
				lappend  header_list [list $param_name $param_bit_len $param_new_value]
			}
			#puts $header_list
			## channel
			set channels_list {}
			for {set i 0} {$i<32} {incr i} {
				set channel_list {}
				for {set j 0} {$j< [llength $::debug_sc_toolkit::mutrig_ch_param ]} {incr j} {
					set item [lindex $::debug_sc_toolkit::mutrig_ch_param $j]
					set param_name [lindex $item 0]
					set param_bit_len [lindex $item 1]
					set param_new_value [toolkit_get_property "${param_name}${tab_index}_ch${i}_cb" selected]
					lappend channel_list [list $param_name $param_bit_len $param_new_value]
				}
				lappend	channels_list $channel_list
			}
			#puts $channels_list
			## tdc
			set tdc_list {}
			for {set i 0} {$i< [llength $::debug_sc_toolkit::mutrig_tdc_param ]} {incr i} {
				set item [lindex $::debug_sc_toolkit::mutrig_tdc_param $i]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_new_value [toolkit_get_property "${param_name}${tab_index}_cb" selected]
				lappend  tdc_list [list $param_name $param_bit_len $param_new_value]
			}
			#puts $tdc_list
			## footer
			set footer_list {}
			for {set i 0} {$i< [llength $::debug_sc_toolkit::mutrig_footer_param ]} {incr i} {
				set item [lindex $::debug_sc_toolkit::mutrig_footer_param $i]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_new_value [toolkit_get_property "${param_name}${tab_index}_cb" selected]
				lappend  footer_list [list $param_name $param_bit_len $param_new_value]
			}
			#puts $footer_list
			lappend mutrig_config_list $header_list $channels_list $tdc_list $footer_list
			lappend mutrigs_config_list $mutrig_config_list
		}
		#puts $mutrigs_config_list
	} 
	
	
	proc create_bit_streams {} {
		# input  : mutrigs_config_list (a list contains updated all mutrigs param info)
		# output : mutrigs_config_words (a list contains generated all mutrigs config word32 in hex, to be written to master)
		variable mutrigs_config_list 
		variable mutrigs_config_words
		set mutrigs_config_words {}
		for {set i 0} {$i<$::debug_sc_toolkit::asic_number} {incr i} {
			set mutrig_param [lindex $mutrigs_config_list $i]
			set header_param [lindex $mutrig_param 0]
			set ch_param [lindex $mutrig_param 1]
			set tdc_param [lindex $mutrig_param 2]
			set footer_param [lindex $mutrig_param 3]
			set bit_stream [::debug_sc_toolkit::create_bit_stream $header_param $ch_param $tdc_param $footer_param]
			set mutrig_config_words [::debug_sc_toolkit::parse_reverse_bit_stream $bit_stream]
			lappend mutrigs_config_words $mutrig_config_words
		}
		#puts $mutrigs_config_words
	}
	
	
	proc setup_mask_page {} {
		variable asic_mask
		for {set i 0} {$i<[llength $asic_mask]} {incr i} {
			toolkit_add				"gencfg_${i}_led"		led 		gencfgGroup
			toolkit_set_property	"gencfg_${i}_led"		visible 	false
			toolkit_set_property	"gencfg_${i}_led"		color		red_off
			toolkit_set_property	"gencfg_${i}_led"		text		"mask asic${i}"
		}
		toolkit_add				mask_text		text 	gencfgGroup
		toolkit_set_property	mask_text		visible 	false
		toolkit_set_property	mask_text		text 	$asic_mask
	}
	
	proc toggle_show_mask_page {} {
		variable asic_mask
		variable mask_page_show_en
		if {$mask_page_show_en == 0} {
			set mask_page_show_en 1
			set show true
		} else {
			set mask_page_show_en 0
			set show false
		}
		set asic_mask [toolkit_get_property	mask_text	text]
		toolkit_set_property	mask_text				visible 	$show
		for {set i 0} {$i<[llength $asic_mask]} {incr i} {
			toolkit_set_property	"gencfg_${i}_led"		visible 	$show
			if {[lindex $asic_mask $i] == 0} {
				toolkit_set_property	"gencfg_${i}_led"		color		red_off
			} else {
				toolkit_set_property	"gencfg_${i}_led"		color		red
			}
		}
		
	}
	
	proc load_ram_with_words {asic_index} {
		variable mutrigs_config_words
		variable schpad_ram_base_adr
		#puts "config asic ${asic_index}"
		#puts [lindex $mutrigs_config_words $asic_index]
		::debug_sc_toolkit::write_master_with_words [lindex $mutrigs_config_words $asic_index] $schpad_ram_base_adr
	}
	
	proc master_write_cmd_to_mctrl {asic_index} {
		variable mutrig_controller_csr_base_adr
		variable claimed_master_path 
		variable schpad_ram_base_adr
		set cfg_pattern_length_in_word_hex "0054"
		set cmd "0x011${asic_index}${cfg_pattern_length_in_word_hex}"
		# write offset to the pad
		master_write_32 $claimed_master_path [expr $mutrig_controller_csr_base_adr + 0x4]  $schpad_ram_base_adr
		# write command 
		master_write_32 $claimed_master_path $mutrig_controller_csr_base_adr $cmd
		
	}
	
	proc cfg_all_asics {} {
	# please create bit streams before calling this function
    # DEBUG
        #while {1} {
		for {set i 0} {$i<$::debug_sc_toolkit::asic_number} {incr i} {
			if {[lindex $::debug_sc_toolkit::asic_mask $i] == 0} {
				# write to scartch-pad ram
				::debug_sc_toolkit::load_ram_with_words $i
				# write csr 
				::debug_sc_toolkit::master_write_cmd_to_mctrl $i
				after 10
			} else {
				
			}
		}
        toolkit_send_message info "cfg_all_asics: done"
        #after 5000
        #}
	}
	
	proc toggle_pulser {} {
		variable pulser_en
		variable claimed_master_path
		set pulser_base_addr 0x04c4
		set cmd_on 01
		set cmd_off 0x00
		if {$pulser_en == 0} {
			set plr_f [toolkit_get_property	pulser_freq		text]
			set plr_w [toolkit_get_property	pulser_width	text]
			set plr_f_hex [format %04X $plr_f]
			set plr_w_hex [format %02X $plr_w]
			set cmd_on	"${plr_w_hex}${plr_f_hex}01"
			#puts "cmd:${cmd_on}"
			master_write_32	$claimed_master_path $pulser_base_addr "0x${cmd_on}"
			toolkit_set_property	en_pulser_set	text 		"Disable pulser"
			set pulser_en 1
		} else {
			master_write_32	$claimed_master_path $pulser_base_addr $cmd_off
			toolkit_set_property	en_pulser_set	text 		"Enable pulser"
			set pulser_en 0
		}
	}
	
	proc start_tsa {} {
		variable claimed_master_path
		variable asic_config_sel_to_load
		#variable mutrig_ctrl_base_addr
		variable mutrig_controller_csr_base_adr
		#set mutrig_controller_base_addr 0x3f010
		
		set asic_id_hex [format %01X $asic_config_sel_to_load]
		set tsa_start_cmd "012${asic_id_hex}0054"
		# write to controller to start tsa routine
		master_write_32	$claimed_master_path $mutrig_controller_csr_base_adr "0x${tsa_start_cmd}" 
		# monitor the progress
		while { 1 } {
			# toggle button
			toolkit_set_property	run_tsa_set				enabled		false
			set ctrl_csr [master_read_32 $claimed_master_path $mutrig_controller_csr_base_adr 0x1]
			set prog_info [format %d [expr $ctrl_csr%64]]
			# compl'
			if {[expr $ctrl_csr] == 0} {
				toolkit_set_property	run_tsa_set				enabled		true
				toolkit_set_property	run_tsa_set				text		"RUN Threshold Scan for asic ${asic_config_sel_to_load}"
				toolkit_send_message info "\n\[start_tsa\]: tth scan completed! (63 / 63) "
				break
			}
			# update scan progress
			toolkit_set_property	run_tsa_set				text		"${prog_info} / 63"
			toolkit_send_message info "\n\[start_tsa\]: tth scan progress: ${prog_info} / 63"
			after 1000
		}
		::debug_sc_toolkit::display_tsa_result
		return -code ok
	}
	
	proc start_all_tsa {} {
		variable claimed_master_path
		set mutrig_controller_base_addr 0x3f010
		variable mutrig_controller_csr_base_adr
		set tsa_start_all_cmd "01400054"
		# write to controller to start tsa routine
		master_write_32	$claimed_master_path $mutrig_controller_csr_base_adr "0x${tsa_start_all_cmd}"
		# monitor the progress
		while { 1 } {
			# toggle button
			toolkit_set_property	run_all_tsa_set				enabled		false
			set ctrl_csr [master_read_32 $claimed_master_path $mutrig_controller_csr_base_adr 0x1]
			set prog_info [format %d [expr $ctrl_csr%64]]
			# compl'
			if {[expr $ctrl_csr] == 0} {
				toolkit_set_property	run_all_tsa_set				enabled		true
				toolkit_set_property	run_all_tsa_set				text		"RUN Threshold Scan for all asics"
				toolkit_send_message info "\n\[start_tsa\]: tth scan completed! (63 / 63) "
				break
			}
			# update scan progress
			toolkit_set_property	run_all_tsa_set				text		"${prog_info} / 63"
			toolkit_send_message info "\n\[start_tsa\]: tth scan progress: ${prog_info} / 63"
			after 1000
		}
		::debug_sc_toolkit::display_all_tsa_result
		return -code ok
	}
	
	proc display_tsa_result {} {
		variable claimed_master_path
		variable asic_config_sel_to_load
		#set mutrig_controller_base_addr 0x10000
		::debug_sc_toolkit::read_tsa_result_ram $asic_config_sel_to_load
	}
	
	proc display_all_tsa_result {} {
		variable claimed_master_path
		#set mutrig_controller_base_addr 0x10000
		::debug_sc_toolkit::read_all_tsa_result_ram
	}
	
	proc read_tsa_result_ram {asic_index} {
		variable claimed_master_path
		#set result_ram_base_addr 0x10000
		variable result_ram_base_addr
		set asic_addr_ofst [expr 64*4*32]
		variable tsa_all_plots; # file to store the scan results append each list of 1 ch
		
		#puts "\n reading asic: ${asic_index} "
		#puts "offset is: ${asic_addr_ofst}"
		for {set ch 0} {$ch < 32} {incr ch} {
			set read_starting_addr [format %X [expr [expr $result_ram_base_addr + 64*4*[expr $ch]] + [expr $asic_addr_ofst*$asic_index]]]
			#puts "addr read: ${read_starting_addr}"
			set bar_category_str "ch: ${ch}"
			set result_of_one_channel [master_read_32 $claimed_master_path "0x${read_starting_addr}" 64]
			set step_tth 0
			foreach result_of_one_channel_one_step $result_of_one_channel {
				#puts "step:${step_tth}"
				#puts "result:${result_of_one_channel_one_step}"
				set result_of_one_channel_one_step [format %i [expr $result_of_one_channel_one_step]]
				#puts "result:${result_of_one_channel_one_step}"
				#puts "step:${step_tth}"
				#puts "rate:${result_of_one_channel_one_step}"
				toolkit_set_property	"tsa${asic_index}_${ch}LineC"		itemValue [list $step_tth [expr $result_of_one_channel_one_step]]
				incr step_tth
			}
			#puts $result_of_one_channel
			lappend tsa_all_plots $result_of_one_channel
		}
	}
	
	proc read_all_tsa_result_ram {} {
		variable tsa_all_plots
		set tsa_all_plots {}; # initialize it
		for {set asic_index 0} {$asic_index < $::debug_sc_toolkit::asic_number_tsa} {incr asic_index} {
			::debug_sc_toolkit::read_tsa_result_ram $asic_index
		}
	}

	proc save_tsa_to_file {} {
		variable tsa_all_plots
		set path_to_save [toolkit_get_property save_tsa_plots_to_file_set paths]
		set file [open "${path_to_save}\.txt" w+] ; # save as txt here
		puts $file $tsa_all_plots

		close $file
	}
	
	proc copy_settings {} {
	# get selection with the current tab
		set asic_id_from [toolkit_get_property 	load_ram_cb		selected]
		## header
			for {set param_index 0} {$param_index< [llength $::debug_sc_toolkit::mutrig_header_param ]} {incr param_index} {
				set item [lindex $::debug_sc_toolkit::mutrig_header_param $param_index]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				set selected_value [toolkit_get_property	"${param_name}${asic_id_from}_cb"	selected]
				#puts "${param_name}:${selected_value}"
				for {set asic_index 0} {$asic_index < $debug_sc_toolkit::asic_number} {incr asic_index} {
					if {$asic_index == $asic_id_from} {
						continue
					} else {
						toolkit_set_property	"${param_name}${asic_index}_cb"	selected $selected_value
					}
				}	
			}
		## channel 
			for {set ch_index 0} {$ch_index<32} {incr ch_index} {
				##### bit fields (channel)
				for {set param_index 0} {$param_index< [llength $::debug_sc_toolkit::mutrig_ch_param ]} {incr param_index} {
					set item [lindex $::debug_sc_toolkit::mutrig_ch_param $param_index]
					set param_name [lindex $item 0]
					set param_bit_len [lindex $item 1]
					set param_value_dec [lindex $item 2]
					set selected_value	[toolkit_get_property	"${param_name}${asic_id_from}_ch${ch_index}_cb"	selected]
					for {set asic_index 0} {$asic_index < $debug_sc_toolkit::asic_number} {incr asic_index} {
						if {$asic_index == $asic_id_from} {
							continue
						} else {
							toolkit_set_property	"${param_name}${asic_index}_ch${ch_index}_cb"	selected $selected_value
						}
					}
				}
			}
		## tdc
			for {set param_index 0} {$param_index< [llength $::debug_sc_toolkit::mutrig_tdc_param ]} {incr param_index} {
				set item [lindex $::debug_sc_toolkit::mutrig_tdc_param $param_index]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				set selected_value [toolkit_get_property	"${param_name}${asic_id_from}_cb"	selected]
				#puts "${param_name}:${selected_value}"
				for {set asic_index 0} {$asic_index < $debug_sc_toolkit::asic_number} {incr asic_index} {
					if {$asic_index == $asic_id_from} {
						continue
					} else {
						toolkit_set_property	"${param_name}${asic_index}_cb"	selected $selected_value
					}
				}	
			}
		## footer 
			for {set param_index 0} {$param_index< [llength $::debug_sc_toolkit::mutrig_footer_param ]} {incr param_index} {
				set item [lindex $::debug_sc_toolkit::mutrig_footer_param $param_index]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				set selected_value [toolkit_get_property	"${param_name}${asic_id_from}_cb"	selected]
				#puts "${param_name}:${selected_value}"
				for {set asic_index 0} {$asic_index < $debug_sc_toolkit::asic_number} {incr asic_index} {
					if {$asic_index == $asic_id_from} {
						continue
					} else {
						toolkit_set_property	"${param_name}${asic_index}_cb"	selected $selected_value
					}
				}	
			}
		# remember to update the config nested list which stores all the settings of all asics in tcl
		::debug_sc_toolkit::update_config_list
	}
	
	proc copy_settings_ch {} {
		# copy setting for one asic from the selected channel to other channels 
		set asic_id_from [toolkit_get_property 	load_ram_cb		selected]
		set ch_id_from [toolkit_get_property 	sel_ch_cb		selected]
		for {set param_index 0} {$param_index< [llength $::debug_sc_toolkit::mutrig_ch_param ]} {incr param_index} {
			set item [lindex $::debug_sc_toolkit::mutrig_ch_param $param_index]
			set param_name [lindex $item 0]
			set param_bit_len [lindex $item 1]
			set param_value_dec [lindex $item 2]
			set selected_value	[toolkit_get_property	"${param_name}${asic_id_from}_ch${ch_id_from}_cb"	selected]
			for {set ch_index 0} {$ch_index<32} {incr ch_index} {
				if {$ch_id_from == $ch_index} {
					continue
				} else {
					toolkit_set_property	"${param_name}${asic_id_from}_ch${ch_index}_cb" selected $selected_value
				}
			}
		}
		# remember to update the config nested list which stores all the settings of all asics in tcl
		::debug_sc_toolkit::update_config_list
	}
	
	proc save_to_file {} {
		set xml_en [toolkit_get_property save_as_xml_en_cnb checked]
		variable mutrigs_config_list
		set path_to_save [toolkit_get_property save_to_set paths]
		set file [open $path_to_save w+]
		
		if {$xml_en == false} {
			puts $file $mutrigs_config_list
		} else {
			# generate an xml format file

			set tlist_header $::debug_sc_toolkit::mutrig_header_param
			set tlist_tdc $::debug_sc_toolkit::mutrig_tdc_param
			
			set doc [dom createDocument mutrig_configuration]
			set mutrig_configuration [$doc documentElement]
			
			dom createNodeCmd elementNode header
			dom createNodeCmd elementNode param
			dom createNodeCmd elementNode name
			dom createNodeCmd elementNode bitlen
			dom createNodeCmd elementNode value
			dom createNodeCmd textNode t
			
			foreach line $tlist_header {
				lassign $line name bitlen value
				# or (if you don't have lassign) foreach {_root suite case} $line break
			
				$mutrig_configuration appendFromScript {
					param {
						name {t $name}
						bitlen {t $bitlen}
						value {t $value}
					}
				}
			}

			puts $file [$doc asXML]
#			for {set asic_index 0} {$asic_index < $debug_sc_toolkit::asic_number} {incr asic_index} {
#				
#			
#			}
		}
		close $file
		return -code ok 
	}
	
	proc load_from_file {} {
		variable mutrigs_config_list
		set path_to_load [toolkit_get_property load_from_set paths]
		set file [open $path_to_load r]
		set mutrigs_config_list [read $file]
		close $file
		# update the combo box from the tcl list read from this file
		::debug_sc_toolkit::update_combo_box
	}
	
	
	proc update_combo_box {} {
		variable mutrigs_config_list
		# update the combo box selected based on the read cfg file (list in tcl)
		for {set asic_index 0} {$asic_index < $::debug_sc_toolkit::asic_number} {incr asic_index} {
			set asic_cfg_list [lindex $mutrigs_config_list $asic_index]
			set header_cfg_list [lindex $asic_cfg_list 0]
			set channels_cfg_list [lindex $asic_cfg_list 1]
			set tdc_cfg_list [lindex $asic_cfg_list 2]
			set footer_cfg_list [lindex $asic_cfg_list 3]
			# header 
			for {set param_index 0} {$param_index< [llength $header_cfg_list ]} {incr param_index} {
				set item [lindex $header_cfg_list $param_index]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				toolkit_set_property 	"${param_name}${asic_index}_cb"	selected $param_value_dec
			}
			# channel
			for {set ch_index 0} {$ch_index<32} {incr ch_index} {
				set channel_cfg_list [lindex $channels_cfg_list $ch_index]
				for {set param_index 0} {$param_index< [llength $channel_cfg_list ]} {incr param_index} {
					set item [lindex $channel_cfg_list $param_index]
					set param_name [lindex $item 0]
					set param_bit_len [lindex $item 1]
					set param_value_dec [lindex $item 2]
					toolkit_set_property	"${param_name}${asic_index}_ch${ch_index}_cb"	selected $param_value_dec
				}
			}
			# tdc
			for {set param_index 0} {$param_index< [llength $tdc_cfg_list ]} {incr param_index} {
				set item [lindex $tdc_cfg_list $param_index]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				toolkit_set_property 	"${param_name}${asic_index}_cb"	selected $param_value_dec
			}
			# footer
			for {set param_index 0} {$param_index< [llength $footer_cfg_list ]} {incr param_index} {
				set item [lindex $footer_cfg_list $param_index]
				set param_name [lindex $item 0]
				set param_bit_len [lindex $item 1]
				set param_value_dec [lindex $item 2]
				toolkit_set_property 	"${param_name}${asic_index}_cb"	selected $param_value_dec
			}
		}
		return -code ok
	}

}



::debug_sc_toolkit::dashBoard

