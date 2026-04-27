package provide debug_datapath 1.0
package require Tcl 8.5
package require mu3e::helpers 1.0
	

namespace eval debug_datapath_toolkit {

	set master_list	{} 
	set address_to_read {0x0000}
	set address_to_write {0x0000}
	set data_to_write {0x0}
	set read_data {None}
	set write_status {Not yet written}
	
	# global monitor status
	set reading_on 0
	set assembly_reading_on 0
	set hist_reading_on 0
	
	# global settings
	set n_asic 4
	set histstat_n_bin 256
	set mutrig3_max_output_event_rate 32E6
	
	# all the memory mapped address
	set ch_rate_start_addr {0x10000}; 
	set ch_rate_span_addr {0x200};
	set lvdserr_start_addr {0x0840 0x1840 0x2840 0x3840}; # spans are all 0x4
	set lvdserr_span_addr {0x4};
	set histstat_start_addr {0x20000}
	set histstat_span_addr {0x400}
	
	# monitors settings and handlers
	set monitor_interval 1000
	set ch_rates {}
	set claimed_monitor_rate {}
	set claimed_monitor_assembly {}
	set claimed_monitor_hist {}

	proc dashBoard {} {
	
		set master_index_selected 0
		
		toolkit_set_property self title "Debug datapath (SciFi) "
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
		toolkit_set_property	basicGroup		title				"Setup"
		toolkit_set_property	basicGroup		itemsPerRow			1
		
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
		{set ::debug_datapath_toolkit::master_list [ ::debug_datapath_toolkit::get_master_path ]}
		
		
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
		{set ::debug_datapath_toolkit::master_path [ ::debug_datapath_toolkit::get_open_master_path $master_index_selected ]}
		
		
		
		toolkit_add 			io_rd_group 	group 		basicGroup
		toolkit_set_property	io_rd_group		title		"Master IO access"
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
		toolkit_add 			readGroup 	group 		io_rd_group
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
		toolkit_set_property	address_of_read		text			$::debug_datapath_toolkit::address_to_read
		
		# button to start read
		toolkit_add				startRead	button		readGroup
		toolkit_set_property	startRead	enabled 	true
		toolkit_set_property	startRead	expandableX false
		toolkit_set_property	startRead	expandableY false
		toolkit_set_property	startRead	text		"Set Address and Read"
		toolkit_set_property	startRead	onClick 	\
		{ ::debug_datapath_toolkit::read_this_address }
		
		# text box for read data (display)
		toolkit_add				readData		text			readGroup
		toolkit_set_property	readData		expandableX		true
		toolkit_set_property	readData		preferredWidth	100
		toolkit_set_property	readData		preferredHeight	10
		toolkit_set_property	readData		editable		false
		toolkit_set_property	readData		text			$::debug_datapath_toolkit::read_data
		
		
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
		toolkit_add 			writeGroup 	group 		io_rd_group
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
		toolkit_set_property	address_of_write		text			$::debug_datapath_toolkit::address_to_write
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
		toolkit_set_property	data_of_write		text			$::debug_datapath_toolkit::data_to_write
		toolkit_set_property	data_of_write		toolTip			"Write Data"
		
		# button to start write
		toolkit_add				startRead	button		writeGroup
		toolkit_set_property	startRead	enabled 	true
		toolkit_set_property	startRead	expandableX false
		toolkit_set_property	startRead	expandableY false
		toolkit_set_property	startRead	text		"Set Address/Data to Write"
		toolkit_set_property	startRead	onClick 	\
		{ ::debug_datapath_toolkit::write_this_address }
		
		# text box for write data (readback validation)
		toolkit_add				writeValidation		text			writeGroup
		toolkit_set_property	writeValidation		expandableX		true
		toolkit_set_property	writeValidation		preferredWidth	100
		toolkit_set_property	writeValidation		preferredHeight	10
		toolkit_set_property	writeValidation		editable		false
		toolkit_set_property	writeValidation		text			$::debug_datapath_toolkit::write_status
		
		
		# another group for debug temp sensor
		toolkit_add 			onewire_group 	group 		io_rd_group
		toolkit_set_property	onewire_group	title		"TCL to 1-Wire Master IP"
		
		toolkit_add 			convert_bt 	button 		onewire_group
		toolkit_set_property	convert_bt	text		"Convert Temperature"
		toolkit_set_property	convert_bt	onClick 	{::debug_datapath_toolkit::onewire_ip_convert}
		
		toolkit_add 			read_bt 	button 		onewire_group
		toolkit_set_property	read_bt		text		"Read Temperature"
		toolkit_set_property	read_bt		onClick 	{::debug_datapath_toolkit::onewire_ip_readT}
		
		
		
		###########################################################################
		#           _______      __     _   _  _____ ______   _______       ____  #
		#     /\   |  __ \ \    / /\   | \ | |/ ____|  ____| |__   __|/\   |  _ \ #
		#    /  \  | |  | \ \  / /  \  |  \| | |    | |__       | |  /  \  | |_) |#
		#   / /\ \ | |  | |\ \/ / /\ \ | . ` | |    |  __|      | | / /\ \ |  _ < #
		#  / ____ \| |__| | \  / ____ \| |\  | |____| |____     | |/ ____ \| |_) |#
		# /_/    \_\_____/   \/_/    \_\_| \_|\_____|______|    |_/_/    \_\____/ #
		#																		  #
        ###########################################################################																			 
		## Link Monitor Channel Rate Tab
		toolkit_add				rateGroup	group				Tab
		toolkit_set_property	rateGroup	title				"Rate"
		
		
		#########################################################################################
		#   _____ ____  _   _ _______ _____   ____  _         _____ _____   ____  _    _ _____  #
		#  / ____/ __ \| \ | |__   __|  __ \ / __ \| |       / ____|  __ \ / __ \| |  | |  __ \ #
		# | |   | |  | |  \| |  | |  | |__) | |  | | |      | |  __| |__) | |  | | |  | | |__) |#
		# | |   | |  | | . ` |  | |  |  _  /| |  | | |      | | |_ |  _  /| |  | | |  | |  ___/ #
		# | |___| |__| | |\  |  | |  | | \ \| |__| | |____  | |__| | | \ \| |__| | |__| | |     #
		#  \_____\____/|_| \_|  |_|  |_|  \_\\____/|______|  \_____|_|  \_\\____/ \____/|_|     #
		#                                                                                       #
		#########################################################################################                                                                                       
		## Control Panel Group
		toolkit_add 			controlGroup 	group 		rateGroup
		toolkit_set_property	controlGroup	expandableX	false
		toolkit_set_property	controlGroup	expandableY	false
		toolkit_set_property	controlGroup	itemsPerRow 1
		toolkit_set_property	controlGroup 	title		"Control Panel"
		# widgets
		toolkit_add				monitorLed		led			controlGroup
		toolkit_set_property	monitorLed		expandableX	false
		toolkit_set_property	monitorLed		expandableY	false
		toolkit_set_property	monitorLed		text		"Monitor Ongoing"
		toolkit_set_property	monitorLed		color		"green_off"
		
		toolkit_add				startButton	button		controlGroup
		toolkit_set_property	startButton	enabled 	true
		toolkit_set_property	startButton	expandableX false
		toolkit_set_property	startButton	expandableY false
		toolkit_set_property	startButton	text		"Start Monitor"
		toolkit_set_property	startButton	onClick 	{set ::debug_datapath_toolkit::reading_on [::debug_datapath_toolkit::toggle_monitor_status $::debug_datapath_toolkit::reading_on]}
		
		toolkit_add				stopButton	button		controlGroup
		toolkit_set_property	stopButton	enabled 	false
		toolkit_set_property	stopButton	expandableX false
		toolkit_set_property	stopButton	expandableY false
		toolkit_set_property	stopButton	text		"Stop Monitor"
		toolkit_set_property	stopButton	onClick 	{set ::debug_datapath_toolkit::reading_on [::debug_datapath_toolkit::toggle_monitor_status $::debug_datapath_toolkit::reading_on]}
		
		
		###########################################################################################################
		# __      _______ ________          __  _____         _______ ______    _____ _____   ____  _    _ _____  #
		# \ \    / /_   _|  ____\ \        / / |  __ \     /\|__   __|  ____|  / ____|  __ \ / __ \| |  | |  __ \ #
		#  \ \  / /  | | | |__   \ \  /\  / /  | |__) |   /  \  | |  | |__    | |  __| |__) | |  | | |  | | |__) |#
		#   \ \/ /   | | |  __|   \ \/  \/ /   |  _  /   / /\ \ | |  |  __|   | | |_ |  _  /| |  | | |  | |  ___/ #
		#    \  /   _| |_| |____   \  /\  /    | | \ \  / ____ \| |  | |____  | |__| | | \ \| |__| | |__| | |     #
		#     \/   |_____|______|   \/  \/     |_|  \_\/_/    \_\_|  |______|  \_____|_|  \_\\____/ \____/|_|     #
		#                                                                                                         #
		###########################################################################################################  
		
		## View Rate Group
		toolkit_add 			viewTab0 		tabbedGroup rateGroup
		
#		toolkit_add 			viewrateGroup 	group 		viewTab0
#		toolkit_set_property	viewrateGroup	expandableX	false
#		toolkit_set_property	viewrateGroup	expandableY	false
#		toolkit_set_property	viewrateGroup	itemsPerRow 1
#		toolkit_set_property	viewrateGroup 	title		"MuTRiG"
#		
#		toolkit_add 			viewrate1Group 	group 		viewTab0
#		toolkit_set_property	viewrate1Group	expandableX	false
#		toolkit_set_property	viewrate1Group	expandableY	false
#		toolkit_set_property	viewrate1Group	itemsPerRow 1
#		toolkit_set_property	viewrate1Group 	title		"MuTRiG1"
		
		
		set n_asic  $::debug_datapath_toolkit::n_asic
		for {set asic_i 0} {[expr $asic_i < $n_asic]} {incr asic_i} {
			set group_name [format "viewrateGroup_%i" $asic_i]
			toolkit_add 			$group_name 	group 		viewTab0
			toolkit_set_property	$group_name		expandableX	false
			toolkit_set_property	$group_name		expandableY	false
			toolkit_set_property	$group_name		itemsPerRow 1
			toolkit_set_property	$group_name 	title		[format "MuTRiG %i" $asic_i]
			
			# chart
			set chart_name	[format "rateBChart_%i" $asic_i]
			toolkit_add				$chart_name		barChart	$group_name	
			toolkit_set_property	$chart_name		title		"Channel Rate"
			toolkit_set_property	$chart_name		labelX		"channel ID"
			toolkit_set_property	$chart_name		labelY		[format "Hit Rate per %i ms" $::debug_datapath_toolkit::monitor_interval]
			toolkit_set_property	$chart_name		expandableX true
			toolkit_set_property	$chart_name		preferredWidth 800
			
			# statistics report text
			toolkit_add 			"${group_name}_stats_group" 	group 		$group_name
			toolkit_set_property	"${group_name}_stats_group"		itemsPerRow 1
			toolkit_set_property	"${group_name}_stats_group" 	title		"Statistics Report"
			toolkit_set_property	"${group_name}_stats_group" 	preferredWidth		400
			toolkit_set_property	"${group_name}_stats_group" 	preferredHeight		100
			
			toolkit_add				"${group_name}_stats_txt"		text		"${group_name}_stats_group"
			toolkit_set_property	"${group_name}_stats_txt"		editable 	false
			toolkit_set_property	"${group_name}_stats_txt"		expandableX true
			
		}
		
		
		############################################
		# frame assembly subsystem tab
		toolkit_add				assemblyGroup	group				Tab
		toolkit_set_property	assemblyGroup	title				"Assembly"
		
		
		## Control Panel Group
		toolkit_add 			assemblycontrolGroup 	group 		assemblyGroup
		toolkit_set_property	assemblycontrolGroup	expandableX	false
		toolkit_set_property	assemblycontrolGroup	expandableY	false
		toolkit_set_property	assemblycontrolGroup	itemsPerRow 1
		toolkit_set_property	assemblycontrolGroup 	title		"Control Panel"
		# widgets
		toolkit_add				assemblymonitorLed		led			assemblycontrolGroup
		toolkit_set_property	assemblymonitorLed		expandableX	false
		toolkit_set_property	assemblymonitorLed		expandableY	false
		toolkit_set_property	assemblymonitorLed		text		"Monitor Ongoing"
		toolkit_set_property	assemblymonitorLed		color		"green_off"
		
		toolkit_add				assemblystartButton	button		assemblycontrolGroup
		toolkit_set_property	assemblystartButton	enabled 	true
		toolkit_set_property	assemblystartButton	expandableX false
		toolkit_set_property	assemblystartButton	expandableY false
		toolkit_set_property	assemblystartButton	text		"Start Monitor"
		toolkit_set_property	assemblystartButton	onClick 	{set ::debug_datapath_toolkit::assembly_reading_on [::debug_datapath_toolkit::toggle_assembly_monitor_status $::debug_datapath_toolkit::assembly_reading_on]}
		
		toolkit_add				assemblystopButton	button		assemblycontrolGroup
		toolkit_set_property	assemblystopButton	enabled 	false
		toolkit_set_property	assemblystopButton	expandableX false
		toolkit_set_property	assemblystopButton	expandableY false
		toolkit_set_property	assemblystopButton	text		"Stop Monitor"
		toolkit_set_property	assemblystopButton	onClick 	{set ::debug_datapath_toolkit::assembly_reading_on [::debug_datapath_toolkit::toggle_assembly_monitor_status $::debug_datapath_toolkit::assembly_reading_on]}
		
		
		## txt field
		toolkit_add 			lvdsGroup 	group 			assemblyGroup
		toolkit_set_property	lvdsGroup	expandableX		true
		toolkit_set_property	lvdsGroup	expandableY		false
		toolkit_set_property	lvdsGroup	itemsPerRow 	1
		toolkit_set_property	lvdsGroup 	title			"LVDS Error"
		
		for {set i 0} {[expr $i < $n_asic]} {incr i} {
			toolkit_add				"lvdserr_${i}_txt"		text			lvdsGroup
			toolkit_set_property	"lvdserr_${i}_txt"		text			"Lane ${i} LVDS error: UNKNOWN "
			toolkit_set_property	"lvdserr_${i}_txt"		editable		false
		
		}
		
		############################################
		# histogram statistics tab
		toolkit_add				histogramGroup	group				Tab
		toolkit_set_property	histogramGroup	title				"Histogram Statistics"
		
		
		## Control Panel Group
		toolkit_add 			histogramcontrolGroup 	group 		histogramGroup
		toolkit_set_property	histogramcontrolGroup	expandableX	false
		toolkit_set_property	histogramcontrolGroup	expandableY	false
		toolkit_set_property	histogramcontrolGroup	itemsPerRow 1
		toolkit_set_property	histogramcontrolGroup 	title		"Control Panel"
		# widgets
		toolkit_add				histMonitorLed		led			histogramcontrolGroup
		toolkit_set_property	histMonitorLed		expandableX	false
		toolkit_set_property	histMonitorLed		expandableY	false
		toolkit_set_property	histMonitorLed		text		"Monitor Ongoing"
		toolkit_set_property	histMonitorLed		color		"green_off"
		
		toolkit_add				histStartButton	button		histogramcontrolGroup
		toolkit_set_property	histStartButton	enabled 	true
		toolkit_set_property	histStartButton	expandableX false
		toolkit_set_property	histStartButton	expandableY false
		toolkit_set_property	histStartButton	text		"Start Monitor"
		toolkit_set_property	histStartButton	onClick 	{set ::debug_datapath_toolkit::hist_reading_on [::debug_datapath_toolkit::toggle_hist_monitor_status $::debug_datapath_toolkit::hist_reading_on]}
		
		toolkit_add				histStopButton	button		histogramcontrolGroup
		toolkit_set_property	histStopButton	enabled 	false
		toolkit_set_property	histStopButton	expandableX false
		toolkit_set_property	histStopButton	expandableY false
		toolkit_set_property	histStopButton	text		"Stop Monitor"
		toolkit_set_property	histStopButton	onClick 	{set ::debug_datapath_toolkit::hist_reading_on [::debug_datapath_toolkit::toggle_hist_monitor_status $::debug_datapath_toolkit::hist_reading_on]}
		
		toolkit_add				histClearButton	button		histogramcontrolGroup
		toolkit_set_property	histClearButton	enabled 	true
		toolkit_set_property	histClearButton	expandableX false
		toolkit_set_property	histClearButton	expandableY false
		toolkit_set_property	histClearButton	text		"Clear Historam"
		toolkit_set_property	histClearButton	onClick 	{::debug_datapath_toolkit::clear_histogram}
		
		
		# plot histogram here
		toolkit_add 			histChartGroup 		group 		histogramGroup
		toolkit_set_property	histChartGroup		expandableX	true
		toolkit_set_property	histChartGroup		expandableY	true
		toolkit_set_property	histChartGroup		itemsPerRow 1
		toolkit_set_property	histChartGroup 		title		"histogram plot"
		
		toolkit_add				histChart		barChart	histChartGroup
		toolkit_set_property	histChart		title		"Histogram Statistics IP"
		toolkit_set_property	histChart		labelX		"Bin index"
		toolkit_set_property	histChart		labelY		"Bin count"
		toolkit_set_property	histChart		expandableX true
		toolkit_set_property	histChart		preferredHeight 600
		toolkit_set_property	histChart		preferredWidth 1400
		
	}
	
	
	
	
	# functions
	
	proc onewire_ip_convert {} {
		set mpath $::debug_datapath_toolkit::master_path
		set ip_status 1; # 1=busy 0=idle
		
		# config (with init)
		master_write_32 $mpath 0x4 	0x10b
		# tx data
		master_write_32 $mpath 0x10 0xcc
		# commit
		master_write_32 $mpath 0x0	0x1
		
		# poll 
		while {1} {
			set ip_status [master_read_32 $mpath 0x0 1]
			if {$ip_status == 0x0} {
				toolkit_send_message info "IP idle, writing another byte..."
				break
			} else {
				toolkit_send_message error "IP busy ($ip_status), keep polling..."
				after 100
			}
		}
		
		# config (without init)
		master_write_32 $mpath 0x4 	0x109
		# tx data
		master_write_32 $mpath 0x10 0x44
		# commit 
		master_write_32 $mpath 0x0	0x1
	}
	
	
	proc onewire_ip_readT {} {
		set mpath $::debug_datapath_toolkit::master_path
		set ip_status 1; # 1=busy 0=idle
		
		# config (with init)
		master_write_32 $mpath 0x4 	0x10b
		# tx data (ROM SKIP)
		master_write_32 $mpath 0x10 0xcc
		# commit
		master_write_32 $mpath 0x0	0x1
		
		# poll
		while {1} {
			set ip_status [master_read_32 $mpath 0x0 1]
			if {$ip_status == 0x0} {
				toolkit_send_message info "IP idle, keep writing another byte (read_pad)..."
				break
			} else {
				toolkit_send_message error "IP busy ($ip_status), keep polling..."
				after 100
			}
		}
		
		# config (without init)
		master_write_32 $mpath 0x4 	0x109
		# tx data (READ_PAD)
		master_write_32 $mpath 0x10 0xbe
		# commit 
		master_write_32 $mpath 0x0	0x1
		
		# poll
		while {1} {
			set ip_status [master_read_32 $mpath 0x0 1]
			if {$ip_status == 0x0} {
				toolkit_send_message info "IP idle, keep writing another byte (rx byte)..."
				break
			} else {
				toolkit_send_message error "IP busy ($ip_status), keep polling..."
				after 100
			}
		}
		
		# config (without init) (read 9 bytes)
		master_write_32 $mpath 0x4 	0x908
		# commit 
		master_write_32 $mpath 0x0	0x1
		# poll
		while {1} {
			set ip_status [master_read_32 $mpath 0x0 1]
			if {$ip_status == 0x0} {
				toolkit_send_message info "IP idle, read 9 bytes..."
				break
			} else {
				toolkit_send_message error "IP busy ($ip_status), keep polling..."
				after 100
			}
		}
		# rx data
		set pad {}; # pad consists of 9 byte
		toolkit_send_message error "=================="
		for {set i 0} {$i<9} {incr i}  {
			lappend pad [master_read_32 $mpath 0x0c 1]
			set da [lindex $pad $i]
			toolkit_send_message info "Byte ${i}: ${da}" 
			
		}
		# conv to temperature reading into f32
		set ls_byte [lindex $pad 0]
		set ms_byte [lindex $pad 1]
		set temp 0
		#set bytes [binary format H* $ls_byte]
		#toolkit_send_message info $bytes
		
	}
	
	proc clear_histogram {} {
		set mpath $::debug_datapath_toolkit::master_path
		variable histstat_start_addr
		# this should trigger its internal flush 
		master_write_32 $mpath $histstat_start_addr 0x0
		toolkit_send_message info "Histogram reset signal sent..."
	}
	
	
	proc toggle_hist_monitor_status {readon} {
		variable claimed_monitor_hist
		if [expr $readon == 0] {
			# TURN ON: toggle botton and led
			toolkit_set_property	histStartButton	enabled 	false
			toolkit_set_property	histStopButton	enabled 	true
			toolkit_set_property	histMonitorLed	color		"green"
			# Monitor on	
			monitor_set_enabled $claimed_monitor_hist 1	
			return 1
		} else {
			# TURN OFF: toggle botton and led
			toolkit_set_property	histStartButton	enabled 	true
			toolkit_set_property	histStopButton	enabled 	false
			toolkit_set_property	histMonitorLed	color		"green_off"
			monitor_set_enabled $claimed_monitor_hist 0
			return 0
		}
	}
	
	
	
	
	proc toggle_assembly_monitor_status {readon} {
		variable claimed_monitor_assembly
		variable n_asic
		if [expr $readon == 0] {
			# TURN ON: toggle botton and led
			toolkit_set_property	assemblystartButton	enabled 	false
			toolkit_set_property	assemblystopButton	enabled 	true
			toolkit_set_property	assemblymonitorLed	color		"green"
			# Monitor on
			for {set i 0} {$i < $n_asic} {incr i} {
				monitor_set_enabled [lindex $claimed_monitor_assembly $i] 1
			}
			return 1
		} else {
			# TURN OFF: toggle botton and led
			toolkit_set_property	assemblystartButton	enabled 	true
			toolkit_set_property	assemblystopButton	enabled 	false
			toolkit_set_property	assemblymonitorLed	color		"green_off"
			for {set i 0} {$i < $n_asic} {incr i} {
				monitor_set_enabled [lindex $claimed_monitor_assembly $i] 0
			}
			return 0
		}
	}
	
	proc toggle_monitor_status {readon} {
		variable claimed_monitor_rate
		if [expr $readon == 0] {
			# TURN ON: toggle botton and led
			toolkit_set_property	startButton	enabled 	false
			toolkit_set_property	stopButton	enabled 	true
			toolkit_set_property	monitorLed	color		"green"
			# Monitor on
			
			monitor_set_enabled $claimed_monitor_rate 1
			return 1
		} else {
			# TURN OFF: toggle botton and led
			toolkit_set_property	startButton	enabled 	true
			toolkit_set_property	stopButton	enabled 	false
			toolkit_set_property	monitorLed	color		"green_off"
			set read_list {}
			monitor_set_enabled $claimed_monitor_rate 0
			return 0
		}
	}
	
	
	
	proc monitor_read_hist_callback {} {
		set mpath $::debug_datapath_toolkit::master_path
		variable claimed_monitor_hist
		variable histstat_start_addr
		variable histstat_span_addr
		variable histstat_n_bin
		set hist_list [lindex [monitor_read_all_data $claimed_monitor_hist $mpath $histstat_start_addr $histstat_span_addr] 0]
		## cast bytes (lsb to msb) into word
		for {set i 0} {$i < [expr $histstat_n_bin*4]} {incr i 4} {
			set word [expr [format "%d" [lindex $hist_list $i]] + [format "%d" [lindex $hist_list [expr $i+1]]]*[expr {2**8}]+ [format "%d" [lindex $hist_list [expr $i+2]]]*[expr {2**16}] + [format "%d" [lindex $hist_list [expr $i+3]]]*[expr {2**24}]]
			#puts "word ${i}: ${word}"
			toolkit_set_property	histChart 		itemValue 	[list [expr $i/4] $word ]
		}
		
	}
	
	proc monitor_read_assembly_callback {monitor_index} {
		set mpath $::debug_datapath_toolkit::master_path
		variable claimed_monitor_assembly
		variable lvdserr_start_addr
		variable lvdserr_span_addr
		#puts "\n monitor_index: ${monitor_index}"
		set lvdserr_list [lindex [monitor_read_all_data [lindex $claimed_monitor_assembly $monitor_index] $mpath [lindex $lvdserr_start_addr $monitor_index] $lvdserr_span_addr] 0]
		#puts "lvdserr_list: ${lvdserr_list}"
		#set test [lindex $lvdserr_list 0]
		#puts "test: ${test}"
		set word [expr [format "%d" [lindex $lvdserr_list 0]] + [format "%d" [lindex $lvdserr_list 1]]*[expr {2**8}]+ [format "%d" [lindex $lvdserr_list 2]]*[expr {2**16}] + [format "%d" [lindex $lvdserr_list 3]]*[expr {2**24}]]
		#puts "word: ${word}"
		# trying to add a (+ 23543) after the text, so we can feel the incremental amount
		#set old_text_is [toolkit_get_property	"lvdserr_${monitor_index}_txt"		text]
		#regexp {\:\s(\d+)} "${old_text_is}" matched subg
		#puts "subg: ${subg}"
		#puts [toolkit_get_property	"lvdserr_${monitor_index}_txt"		text]
		
		toolkit_set_property	"lvdserr_${monitor_index}_txt"		text			"Lane ${monitor_index} LVDS error: ${word} "
		
	}
	
	
	proc monitor_read_rate_callback {} {
		set mpath $::debug_datapath_toolkit::master_path
		variable claimed_monitor_rate
		variable ch_rate_start_addr
		variable ch_rate_span_addr
		set rate_list [lindex [monitor_read_all_data $claimed_monitor_rate $mpath $ch_rate_start_addr $ch_rate_span_addr] 0]
		variable mutrig3_max_output_event_rate
		#puts $rate_list
		set n_asic $::debug_datapath_toolkit::n_asic
		#puts "total asic n:"
		#puts $n_asic
		for {set asic_i 0} {$asic_i < $n_asic} {incr asic_i} {
			
			set chart_name	[format "rateBChart_%i" $asic_i]
			set group_name_stats_txt [format "viewrateGroup_%i_stats_txt" $asic_i]
			set list_length 32
			set sum_asic_event_rate 0
			#puts "asic_i:"
			#puts $asic_i
			#puts "start at:"
			#puts [expr 32*4*$asic_i]
			#puts "end at:"
			#puts [expr 32*4*[expr $asic_i+1]]
			# display each channels on chart
			for {set i [expr 32*4*$asic_i]} {$i < [expr 32*4*[expr $asic_i+1]]} {incr i 4} {
				# sum four bytes into a word
				#puts "word ${i}: "
				set ch_rate_value_0 [format "%d" [lindex $rate_list $i]]
				#puts "byte 0:${ch_rate_value_0}"
				
				set ch_rate_value_1 [format "%d" [lindex $rate_list [expr $i+1]]]
				#puts "byte 1:${ch_rate_value_1}"
				
				set ch_rate_value_2 [format "%d" [lindex $rate_list [expr $i+2]]]
				#puts "byte 2:${ch_rate_value_2}"
				
				set ch_rate_value_3 [format "%d" [lindex $rate_list [expr $i+3]]]
				set ch_rate_value [expr $ch_rate_value_0 + $ch_rate_value_1*[expr {2**8}]+ $ch_rate_value_2*[expr {2**16}] + $ch_rate_value_3*[expr {2**24}]]
				#puts stderr "sum:${ch_rate_value}"
				set ch_name_global [format "%i" [expr $i/4]]
				set ch_name_local [expr $ch_name_global - [expr $asic_i*32]]
				toolkit_set_property	$chart_name 		itemValue 	[list $ch_name_local $ch_rate_value ]
				# sum the rate for all channel 
				set sum_asic_event_rate [expr $sum_asic_event_rate + $ch_rate_value]
			}
			# todo: make this for variable ch counter reset interval
			set saturation_ratio [expr $sum_asic_event_rate / $mutrig3_max_output_event_rate * 100]
			toolkit_set_property	$group_name_stats_txt		text "MuTRiG3 Output Link Event Satruation Ratio: ${saturation_ratio} \%"
		}
	
	}
	
#	proc monitor_ch_rate {asic_i} {
#		set master_path $::debug_datapath_toolkit::master_path
#		set addr [lindex $::debug_datapath_toolkit::ch_rate_start_addr $asic_i]
#		set words 32
#		set read_list [master_read_32 $master_path $addr $words]
#		return $read_list
#	}
	
	proc write_this_address {} {
		set master_path $::debug_datapath_toolkit::master_path
		set address [toolkit_get_property address_of_write text]
		set data [toolkit_get_property data_of_write text]
		set data_rb 0
		set ::debug_datapath_toolkit::write	[master_write_32 $master_path $address $data]
		set data_rb	[master_read_32 $master_path $address 1]
		if {[expr $data_rb == $data]} {
			toolkit_set_property writeValidation text "OK"
		
		} else {
			toolkit_set_property writeValidation text [format "Warning: Readback not match, is 0x%X" $data_rb ]
		
		}
	}
	
	proc read_this_address {} {
		set master_path $::debug_datapath_toolkit::master_path
		set address [toolkit_get_property address_of_read text]
		set ::debug_datapath_toolkit::read_data	[master_read_32 $master_path $address 1]
		toolkit_set_property readData text $::debug_datapath_toolkit::read_data
		
	}
	
	
	proc get_open_master_path { master_index } {
		
		set mpath [lindex [get_service_paths master] $master_index] 
		set master_path [claim_service master $mpath ""]
		# set up monitor if master path is decided
		::debug_datapath_toolkit::setup_monitor_rate $master_path
		::debug_datapath_toolkit::setup_monitor_assembly $master_path
		::debug_datapath_toolkit::setup_monitor_hist $master_path
		
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
	
	proc setup_monitor_rate {master_path} {
		variable claimed_monitor_rate
		variable monitor_interval
		variable ch_rate_start_addr
		variable ch_rate_span_addr
		set monitor [lindex [get_service_paths monitor] 0]
		#set is_service_open_return [is_service_open monitor $monitor]
		set claimed_monitor_rate [claim_service monitor $monitor rate_lib ""]
		#puts $claimed_monitor_rate
		monitor_set_interval $claimed_monitor_rate $monitor_interval
		monitor_set_callback $claimed_monitor_rate [list ::debug_datapath_toolkit::monitor_read_rate_callback]
		monitor_add_range 	$claimed_monitor_rate	$master_path $ch_rate_start_addr $ch_rate_span_addr
		#puts "monitor setup ok"
		#puts $is_service_open_return
	
	}
	
	proc setup_monitor_assembly {master_path} {
		variable claimed_monitor_assembly
		variable monitor_interval
		variable lvdserr_start_addr
		variable lvdserr_span_addr 
		variable n_asic
		set monitor [get_service_paths monitor]
		#puts $monitor
		for {set i 0} {$i < $n_asic} {incr i} {
			lappend claimed_monitor_assembly [claim_service monitor $monitor "assembly_lib" ""]
			# we get sth like this: /channels/toolkit_debug_datapath_toolkit_22/assembly_lib/monitor_1, where monitor_$i
			monitor_set_interval 	[lindex $claimed_monitor_assembly $i] 	$monitor_interval
			monitor_set_callback 	[lindex $claimed_monitor_assembly $i]	[list ::debug_datapath_toolkit::monitor_read_assembly_callback $i]
			monitor_add_range 		[lindex $claimed_monitor_assembly $i]	$master_path [lindex $lvdserr_start_addr $i] $lvdserr_span_addr
		}
	
		#puts $claimed_monitor_assembly
	}
	
	proc setup_monitor_hist {master_path} {
		variable claimed_monitor_hist
		variable monitor_interval
		variable histstat_start_addr
		variable histstat_span_addr 
		set monitor [get_service_paths monitor]
		#puts $monitor
		
		set claimed_monitor_hist [claim_service monitor $monitor "hist_lib" ""]
		monitor_set_interval 	$claimed_monitor_hist 	$monitor_interval
		monitor_set_callback 	$claimed_monitor_hist	[list ::debug_datapath_toolkit::monitor_read_hist_callback]
		monitor_add_range 		$claimed_monitor_hist	$master_path $histstat_start_addr $histstat_span_addr
		

	}



}
::debug_datapath_toolkit::dashBoard