package provide firefly 1.0
package require Tcl 8.5
package require math::fourier


	
	


namespace eval firefly_toolkit {
	set ctrl_reading_enable 1
	set csr_enable 0
	
	#########begin GUI construction######
	proc dashBoard {} {
	
	
	toolkit_set_property self title "Monitor of FireFly Tranceiver on FEB"
	
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
	toolkit_add				basicGroup		group				my_tabs
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
	
	# button to start read
	toolkit_add				getmp_set	button		linkjtagGroup
	toolkit_set_property	getmp_set	enabled 	true
	toolkit_set_property	getmp_set	expandableX false
	toolkit_set_property	getmp_set	expandableY false
	toolkit_set_property	getmp_set	text		"Read Alive Service Path"
	toolkit_set_property	getmp_set	onClick 	\
	{set master_list [ ::firefly_toolkit::get_master_path ]}
	
	# subgroup to display the paths
	toolkit_add 			linkjtagsubGroup 	group 		linkjtagGroup
	toolkit_set_property	linkjtagsubGroup	expandableX	false
	toolkit_set_property	linkjtagsubGroup	expandableY	false
	toolkit_set_property	linkjtagsubGroup	itemsPerRow 1
	toolkit_set_property	linkjtagsubGroup 	title		"Alived Service Paths"
	
	# text showing the path
	toolkit_add 			viewmp_text 	text 			linkjtagsubGroup 
	toolkit_set_property 	viewmp_text 	expandableX 	false
	toolkit_set_property 	viewmp_text 	expandableY 	false
	toolkit_set_property 	viewmp_text 	preferredWidth 	300
	toolkit_set_property 	viewmp_text 	preferredHeight 300
	toolkit_set_property 	viewmp_text 	editable 		false
	toolkit_set_property 	viewmp_text 	htmlCapable 	true
	toolkit_set_property 	viewmp_text 	text 			"No master path yet"
	
	# botton to record selected path
	toolkit_add				getmp_set	button		linkjtagGroup
	toolkit_set_property	getmp_set	enabled 	true
	toolkit_set_property	getmp_set	expandableX false
	toolkit_set_property	getmp_set	expandableY false
	toolkit_set_property	getmp_set	text		"Set Selected Master Path"
	toolkit_set_property	getmp_set	onClick 	\
	{set master_path [ ::firefly_toolkit::get_open_master_path $master_index_selected ]; toolkit_set_property	monitorGroup		visible		true}
	
	# combo-box to select 
	toolkit_add				getmi_cb	comboBox	linkjtagGroup
	toolkit_set_property	getmi_cb	enabled 	true
	toolkit_set_property	getmi_cb	expandableX false
	toolkit_set_property	getmi_cb	expandableY false
	toolkit_set_property	getmi_cb 	options		"?"
	# this returns the master index
	toolkit_set_property	getmi_cb 	onChange	\
	{set master_index_selected [ toolkit_get_property getmi_cb selected ]}
	
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
	{set jtag_debug_list [ ::firefly_toolkit::get_jtag_debug_path ]}
	
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
	
	# botton to reset the master
	toolkit_add 			rst_set		button		resetdebugGroup
	toolkit_set_property	rst_set		enabled		true
	toolkit_set_property	rst_set		expandableX false
	toolkit_set_property	rst_set		expandableY false
	toolkit_set_property	rst_set		text		"Reset JTAG Debug of Selected Master Path"
	toolkit_set_property	rst_set 	onClick		\
	{::firefly_toolkit::reset_jtag2avmm $jtag_debug_index_selected}
	
	
	
	## Monitor Group
	toolkit_add				monitorGroup		group				my_tabs
	toolkit_set_property	monitorGroup		title				Monitoring
	toolkit_set_property	monitorGroup		visible				false
	### Monitor Control Group
	toolkit_add				monitorctrlGroup	group				monitorGroup
	toolkit_set_property	monitorctrlGroup	itemsPerRow 1
	toolkit_set_property	monitorctrlGroup	title 				"Monitor Control Panel"
	
	toolkit_add 			monior_set		button		monitorctrlGroup
	toolkit_set_property	monior_set		enabled		true
	toolkit_set_property	monior_set		expandableX false
	toolkit_set_property	monior_set		expandableY false
	toolkit_set_property	monior_set		text		"Set Monitoring"
	toolkit_set_property	monior_set 		onClick		\
	{ set claimed_list [ ::firefly_toolkit::open_monitor $master_index_selected ] }
	
	toolkit_add 			go_set		button		monitorctrlGroup
	toolkit_set_property	go_set		enabled		true
	toolkit_set_property	go_set		expandableX false
	toolkit_set_property	go_set		expandableY false
	toolkit_set_property	go_set		text		"Start Monitoring"
	toolkit_set_property	go_set 		onClick		\
	{monitor_set_enabled [lindex $claimed_list 0] 1}
	
	toolkit_add 			stop_set		button		monitorctrlGroup
	toolkit_set_property	stop_set		enabled		true
	toolkit_set_property	stop_set		expandableX false
	toolkit_set_property	stop_set		expandableY false
	toolkit_set_property	stop_set		text		"Stop Monitoring"
	toolkit_set_property	stop_set 		onClick		\
	{monitor_set_enabled [lindex $claimed_list 0] 0}
	
	toolkit_add 			rstff_set		button		monitorctrlGroup
	toolkit_set_property	rstff_set		enabled		false
	toolkit_set_property	rstff_set		expandableX false
	toolkit_set_property	rstff_set		expandableY false
	toolkit_set_property	rstff_set		text		"Reset FF Module"
	toolkit_set_property	rstff_set 		onClick		\
	{::firefly_toolkit::reset_ff [lindex $claimed_list 1]}

	toolkit_add 			ctrlenable_set		button		monitorctrlGroup
	toolkit_set_property	ctrlenable_set		enabled		false
	toolkit_set_property	ctrlenable_set		expandableX false
	toolkit_set_property	ctrlenable_set		expandableY false
	toolkit_set_property	ctrlenable_set		text		"Stop the Controller Read Action"
	toolkit_set_property	ctrlenable_set 		onClick		\
	{set ::firefly_toolkit::ctrl_reading_enable [::firefly_toolkit::ctrl_toggle  [lindex $claimed_list 1]  $::firefly_toolkit::ctrl_reading_enable ]   }
	
	toolkit_add 			hiddencsr_set		button		monitorctrlGroup
	toolkit_set_property	hiddencsr_set		enabled		false
	toolkit_set_property	hiddencsr_set		expandableX false
	toolkit_set_property	hiddencsr_set		expandableY false
	toolkit_set_property	hiddencsr_set		text		"Show CSR Page"
	toolkit_set_property	hiddencsr_set 		onClick		\
	{set ::firefly_toolkit::csr_enable [::firefly_toolkit::toggle_hidden_csr_page  [lindex $claimed_list 1]  $::firefly_toolkit::csr_enable ]   }
	
	### Monitor Display Group
	toolkit_add				monitordispGroup	group 	monitorGroup
	toolkit_set_property	monitordispGroup	title "Monitor Display Panel"
	toolkit_set_property	monitordispGroup	itemsPerRow 1
	
	#### Temp Display Group
	toolkit_add				tempdispGroup		group	monitordispGroup
	toolkit_set_property	tempdispGroup		title  "Temperature"
	##### Timechart ff1
	toolkit_add				temp_tchart			timeChart	tempdispGroup
	toolkit_set_property	temp_tchart			preferredHeight 200
	toolkit_set_property	temp_tchart			preferredWidth	600
	toolkit_set_property	temp_tchart			title		"FireFly 1 Temperature"
	toolkit_set_property	temp_tchart			labelX		"Time (Hour:Minute:Second)"  
	toolkit_set_property	temp_tchart			labelY		"Temperature (Celsius)"
	##### Timechart ff2
	toolkit_add				temp_tchart2		timeChart	tempdispGroup
	toolkit_set_property	temp_tchart2		preferredHeight 200
	toolkit_set_property	temp_tchart2		preferredWidth	600
	toolkit_set_property	temp_tchart2		title		"FireFly 2 Temperature"
	toolkit_set_property	temp_tchart2		labelX		"Time (Hour:Minute:Second)"  
	toolkit_set_property	temp_tchart2		labelY		"Temperature (Celsius)"
	
	#### Voltage Display Group
	toolkit_add				voltdispGroup		group 	monitordispGroup
	toolkit_set_property 	voltdispGroup		title	"Voltage"
	##### Timechart ff1
	toolkit_add				volt_tchart			timeChart	voltdispGroup
	toolkit_set_property	volt_tchart			preferredHeight 200
	toolkit_set_property	volt_tchart			preferredWidth	600
	toolkit_set_property	volt_tchart			title		"FireFly 1 VCC"
	toolkit_set_property	volt_tchart			labelX		"Time (Hour:Minute:Second)"  
	toolkit_set_property	volt_tchart			labelY		"VCC (V)" 
	##### Timechart ff2
	toolkit_add				volt_tchart2		timeChart	voltdispGroup
	toolkit_set_property	volt_tchart2		preferredHeight 200
	toolkit_set_property	volt_tchart2		preferredWidth	600
	toolkit_set_property	volt_tchart2		title		"FireFly 2 VCC"
	toolkit_set_property	volt_tchart2		labelX		"Time (Hour:Minute:Second)"  
	toolkit_set_property	volt_tchart2		labelY		"VCC (V)" 
			
	#### RX Power Display Group
	toolkit_add				rxpowdispGroup		group 	monitordispGroup
	toolkit_set_property	rxpowdispGroup		title	"RX Power"
	toolkit_set_property	rxpowdispGroup		itemsPerRow 2
	set rx_power_tchart_height 	200
	set rx_power_tchart_width 	600
	##### Timechart ff1 ch1
	toolkit_add				rxpow1_tchart		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow1_tchart		title		"FireFly 1 Received Optical Power - CH1"
	toolkit_set_property	rxpow1_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow1_tchart		labelY		"Power (mW)"
	toolkit_set_property	rxpow1_tchart		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow1_tchart		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow1_tchart		showLegend	true
	##### Timechart ff1 ch2
	toolkit_add				rxpow2_tchart		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow2_tchart		title		"FireFly 1 Received Optical Power - CH2"
	toolkit_set_property	rxpow2_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow2_tchart		labelY		"Power (mW)"
	toolkit_set_property	rxpow2_tchart		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow2_tchart		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow2_tchart		showLegend	true
	##### Timechart ff1 ch3
	toolkit_add				rxpow3_tchart		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow3_tchart		title		"FireFly 1 Received Optical Power - CH3"
	toolkit_set_property	rxpow3_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow3_tchart		labelY		"Power (mW)"
	toolkit_set_property	rxpow3_tchart		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow3_tchart		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow3_tchart		showLegend	true
	##### Timechart ff1 ch4
	toolkit_add				rxpow4_tchart		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow4_tchart		title		"FireFly 1 Received Optical Power -CH4"
	toolkit_set_property	rxpow4_tchart		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow4_tchart		labelY		"Power (mW)"
	toolkit_set_property	rxpow4_tchart		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow4_tchart		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow4_tchart		showLegend	true
	##### Timechart ff2 ch1
	toolkit_add				rxpow1_tchart2		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow1_tchart2		title		"FireFly 2 Received Optical Power - CH1"
	toolkit_set_property	rxpow1_tchart2		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow1_tchart2		labelY		"Power (mW)"
	toolkit_set_property	rxpow1_tchart2		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow1_tchart2		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow1_tchart2		showLegend	true
	##### Timechart ff2 ch2
	toolkit_add				rxpow2_tchart2		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow2_tchart2		title		"FireFly 2 Received Optical Power - CH2"
	toolkit_set_property	rxpow2_tchart2		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow2_tchart2		labelY		"Power (mW)"
	toolkit_set_property	rxpow2_tchart2		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow2_tchart2		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow2_tchart2		showLegend	true
	##### Timechart ff2 ch3
	toolkit_add				rxpow3_tchart2		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow3_tchart2		title		"FireFly 2 Received Optical Power - CH3"
	toolkit_set_property	rxpow3_tchart2		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow3_tchart2		labelY		"Power (mW)"
	toolkit_set_property	rxpow3_tchart2		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow3_tchart2		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow3_tchart2		showLegend	true
	##### Timechart ff2 ch4
	toolkit_add				rxpow4_tchart2		timeChart	rxpowdispGroup
	toolkit_set_property	rxpow4_tchart2		title		"FireFly 1 Received Optical Power -CH4"
	toolkit_set_property	rxpow4_tchart2		labelX		"Time (Hour:Minute:Second)"
	toolkit_set_property	rxpow4_tchart2		labelY		"Power (mW)"
	toolkit_set_property	rxpow4_tchart2		preferredHeight $rx_power_tchart_height
	toolkit_set_property	rxpow4_tchart2		preferredWidth	 $rx_power_tchart_width
	toolkit_set_property	rxpow4_tchart2		showLegend	true
	
##########################################################################################################	
#	-- Latched Loss Of Signal (LOS) fault indicator. Default = 0. Fault condition = 1. Value clears on read.
#	-- 3-0: L-Rx1 LOS 
#	-- 3-1: L-Rx2 LOS 
#	-- 3-2: L-Rx3 LOS
#	-- 3-3: L-Rx4 LOS
#	-- 3-4: L-Tx1 LOS
#	-- 3-5: L-Tx2 LOS
#	-- 3-6: L-Tx3 LOS
#	-- 3-7: L-Tx4 LOS
#	-- ----------------------------------------------
#	-- Latched Tx fault indicator. Default = 0. Fault condition = 1. Value clears on read.
#	-- 4-0: L_Tx1 Fault
#	-- 4-1: L_Tx2 Fault
#	-- 4-2: L_Tx3 Fault 
#	-- 4-3: L_Tx4 Fault
#	-- 4-4~7: Reserved
#	-- ----------------------------------------------
#	-- Value of 1 when module has experience a reset or at power up. Clear on read
#	-- 6-0: Int Complete Flag
#	-- 6-1~3: Reserved
#	-- Latched temperature alarm and warning, default value =0. High / Low alarm / warning value =1. Resets on read
#	-- 6-4: L-Temp Low Warning (0 °C)
#	-- 6-5: L-Temp High Warning (85 °C)
#	-- 6-6: L-Temp Low Alarm (0 °C)
#	-- 6-7: L-Temp High Alarm (85 °C)
#	-- ----------------------------------------------
#	-- Latched bias alarm and warning, default value = 0. High / Low alarm value =1. Resets on read
#	-- 7-0~3: Reserved
#	-- 7-4: L-Vcc3.3 Low Warning (3.135 V)
#	-- 7-5: L-Vcc3.3 High Warning (3.465 V)
#	-- 7-6: L-Vcc3.3 Low Alarm (3.135 V)
#	-- 7-7: L-Vcc3.3 High Alarm (3.465 V)
#	-- ==============================================
##############################################################################################################
	### Alarm and Warming Display Group
	toolkit_add				alarmdispGroup		group 	monitordispGroup
	toolkit_set_property	alarmdispGroup		title	"Alarms and Warmings"
	toolkit_set_property	alarmdispGroup		itemsPerRow 4
	#### leds
	toolkit_add				led_3_0				led		alarmdispGroup
	toolkit_set_property 	led_3_0				text	"FireFly 1 Rx1 LOS"
	toolkit_add				led_3_1				led		alarmdispGroup
	toolkit_set_property 	led_3_1				text	"FireFly 1 Rx2 LOS"
	toolkit_add				led_3_2				led		alarmdispGroup
	toolkit_set_property 	led_3_2				text	"FireFly 1 Rx3 LOS"
	toolkit_add				led_3_3				led		alarmdispGroup
	toolkit_set_property 	led_3_3				text	"FireFly 1 Rx4 LOS"
	toolkit_add				led_3_4				led		alarmdispGroup
	toolkit_set_property 	led_3_4				text	"FireFly 1 Tx1 LOS"
	toolkit_add				led_3_5				led		alarmdispGroup
	toolkit_set_property 	led_3_5				text	"FireFly 1 Tx2 LOS"
	toolkit_add				led_3_6				led		alarmdispGroup
	toolkit_set_property 	led_3_6				text	"FireFly 1 Tx3 LOS"
	toolkit_add				led_3_7				led		alarmdispGroup
	toolkit_set_property 	led_3_7				text	"FireFly 1 Tx4 LOS"
	toolkit_add				led_4_0				led		alarmdispGroup
	toolkit_set_property 	led_4_0				text	"FireFly 1 Tx1 Fault"
	toolkit_add				led_4_1				led		alarmdispGroup
	toolkit_set_property 	led_4_1				text	"FireFly 1 Tx2 Fault"
	toolkit_add				led_4_2				led		alarmdispGroup
	toolkit_set_property 	led_4_2				text	"FireFly 1 Tx3 Fault"
	toolkit_add				led_4_3				led		alarmdispGroup
	toolkit_set_property 	led_4_3				text	"FireFly 1 Tx4 Fault"
	toolkit_add				led_6_0				led		alarmdispGroup
	toolkit_set_property 	led_6_0				text	"FireFly 1 Int Complete Flag"
	toolkit_add				led_6_4				led		alarmdispGroup
	toolkit_set_property 	led_6_4				text	"FireFly 1 Temp Low Warning (0 C)"
	toolkit_add				led_6_5				led		alarmdispGroup
	toolkit_set_property 	led_6_5				text	"FireFly 1 Temp High Warning (85 C)"
	toolkit_add				led_6_6				led		alarmdispGroup
	toolkit_set_property 	led_6_6				text	"FireFly 1 Temp Low Alarm (0 C)"
	toolkit_add				led_6_7				led		alarmdispGroup
	toolkit_set_property 	led_6_7				text	"FireFly 1 Temp High Alarm (85 C)"
	toolkit_add				led_7_4				led		alarmdispGroup
	toolkit_set_property 	led_7_4				text	"FireFly 1 Vcc3.3 Low Warning (3.135 V)"
	toolkit_add				led_7_5				led		alarmdispGroup
	toolkit_set_property 	led_7_5				text	"FireFly 1 Vcc3.3 High Warning (3.465 V)"
	toolkit_add				led_7_6				led		alarmdispGroup
	toolkit_set_property 	led_7_6				text	"FireFly 1 Vcc3.3 Low Alarm (3.135 V)"
	toolkit_add				led_7_7				led		alarmdispGroup
	toolkit_set_property 	led_7_7				text	"FireFly 1 Vcc3.3 High Alarm (3.465 V)"
	
	### Physical Connection Group
	toolkit_add				phyconGroup		group 		monitordispGroup
	toolkit_set_property	phyconGroup		title		"Physical Connections (faulty)"
	toolkit_set_property	phyconGroup		itemsPerRow	4
	toolkit_set_property	phyconGroup		visible		false
	#### some text
	toolkit_add				wrongful_text	text	monitordispGroup
	toolkit_set_property	wrongful_text	editable	false
	toolkit_set_property	wrongful_text	text    "red = 1; green = 0 (except for `int_n'). Check the layout of FEB, something is wrong with the pull-ups. "
	#### LEDs
	toolkit_add				led_prs				led		phyconGroup
	toolkit_set_property 	led_prs				text	"FireFly 1 Module Present"
	toolkit_add				led_prs2			led		phyconGroup
	toolkit_set_property 	led_prs2			text	"FireFly 2 Module Present"
	toolkit_add				led_intn			led		phyconGroup
	toolkit_set_property 	led_intn			text	"FireFly 1 Init Fault"
	toolkit_add				led_intn2			led		phyconGroup
	toolkit_set_property 	led_intn2			text	"FireFly 2 Init Fault"
	
	return -code ok
	}
	
	proc toggle_hidden_csr_page { claimed_master csr_enable } {
		if { $csr_enable== 1 } {
			master_write_32 $claimed_master 0x0508 0
			set csr_enable 0
			toolkit_set_property	hiddencsr_set		text	"Show CSR Page"
			toolkit_set_property	phyconGroup		visible		false
		} else {
			master_write_32 $claimed_master 0x0508 1
			set csr_enable 1
			toolkit_set_property	hiddencsr_set		text	"Hide CSR Page"
			toolkit_set_property	phyconGroup		visible		true
		}
		return $csr_enable
	}
	
	proc reset_ff { claimed_master } {
		master_write_32 $claimed_master 0x0504 1
		#puts "resetting firefly..."
		after 10
		master_write_32 $claimed_master 0x0504 0
		#puts "firefly reset done"
	}
	
	proc ctrl_toggle { claimed_master ctrl_reading_enable } {
		if { $ctrl_reading_enable== 1 } {
			master_write_32 $claimed_master 0x0500 0
			set ctrl_reading_enable 0
			toolkit_set_property	ctrlenable_set		text	"Resume the Controller Read Action"
		} else {
			master_write_32 $claimed_master 0x0500 1
			set ctrl_reading_enable 1
			toolkit_set_property	ctrlenable_set		text	"Stop the Controller Read Action"
		}
		return $ctrl_reading_enable
	}
	
	
	proc open_monitor { master_index_selected } {
		set monitor [lindex [get_service_paths monitor] 0]
		set claimed_monitor [claim_service monitor $monitor my_lib ""]
		set mpath [lindex [get_service_paths master] $master_index_selected]
		set claimed_master [claim_service master $mpath my_lib ""]
		monitor_set_interval $claimed_monitor 1000
		monitor_set_callback $claimed_monitor [list ::firefly_toolkit::firefly_monitor_read $claimed_master $claimed_monitor $mpath]
		monitor_add_range $claimed_monitor	$mpath 0x0500 56
		toolkit_set_property	rstff_set		enabled		true
		toolkit_set_property	ctrlenable_set		enabled		true
		toolkit_set_property	hiddencsr_set		enabled		true
		return [list $claimed_monitor $claimed_master]
	}	
	
	proc firefly_monitor_read { claimed_master claimed_monitor mpath} {
		#set current_time [clock format [clock seconds] -format "%H.%M:%S"]
		# this is a 2D list of avmm FireFly XCVR Controller
		set ff_regs [monitor_read_all_data $claimed_monitor $mpath 0x0500 56]
		# temperature 
			# ff1
			set ff1_temp [lindex [lindex $ff_regs 0] 0] 
			# convert to string signed dec
			set ff1_temp_int [format "%d" $ff1_temp]
			toolkit_set_property 	temp_tchart		latest [expr $ff1_temp_int]
			# ff2
			set ff2_temp [lindex [lindex $ff_regs 0] 28] 
			# convert to string signed dec
			set ff2_temp_int [format "%d" $ff2_temp]
			toolkit_set_property 	temp_tchart2	latest [expr $ff2_temp_int]
		# vcc
			# ff1
			set ff1_vcc_l	[lindex [lindex $ff_regs 0] 4]
			set ff1_vcc_h	[lindex [lindex $ff_regs 0] 5]
			set ff1_vcc_l_int [format "%d" $ff1_vcc_l]
			set ff1_vcc_l_int_conv [expr $ff1_vcc_l_int*0.0001]
			set ff1_vcc_h_int [format "%d" $ff1_vcc_h]
			set ff1_vcc_h_int_conv [expr $ff1_vcc_h_int*0.0001*256]
			set ff1_vcc_total [expr $ff1_vcc_l_int_conv + $ff1_vcc_h_int_conv]
			toolkit_set_property 	volt_tchart		latest [expr $ff1_vcc_total]
			# ff2
			set ff2_vcc_l	[lindex [lindex $ff_regs 0] 4+28]
			set ff2_vcc_h	[lindex [lindex $ff_regs 0] 5+28]
			set ff2_vcc_l_int [format "%d" $ff2_vcc_l]
			set ff2_vcc_l_int_conv [expr $ff2_vcc_l_int*0.0001]
			set ff2_vcc_h_int [format "%d" $ff2_vcc_h]
			set ff2_vcc_h_int_conv [expr $ff2_vcc_h_int*0.0001*256]
			set ff2_vcc_total [expr $ff2_vcc_l_int_conv + $ff2_vcc_h_int_conv]
			toolkit_set_property 	volt_tchart2	latest [expr $ff2_vcc_total]
		# rx power
			## ff1
			## rx 1
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow1_tchart" 8 9
			## rx 2
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow2_tchart" 12 13
			## rx 3
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow3_tchart" 16 17
			## rx 4 
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow4_tchart" 20 21
			## ff2
			## rx 1
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow1_tchart2" 8+28 9+28
			## rx 2
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow2_tchart2" 12+28 13+28
			## rx 3
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow3_tchart2" 16+28 17+28
			## rx 4 
			::firefly_toolkit::update_rx_power_timechart $ff_regs "rxpow4_tchart2" 20+28 21+28
		# alarm
			## ff1
			::firefly_toolkit::update_alarm_and_warming_led "led_3_0" 24 0 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_1" 24 1 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_2" 24 2 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_3" 24 3 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_4" 24 4 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_5" 24 5 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_6" 24 6 $ff_regs
			::firefly_toolkit::update_alarm_and_warming_led "led_3_7" 24 7 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_4_0" 25 0 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_4_1" 25 1 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_4_2" 25 2 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_4_3" 25 3 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_6_0" 26 0 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_6_4" 26 4 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_6_5" 26 5 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_6_6" 26 6 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_6_7" 26 7 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_7_4" 27 4 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_7_5" 27 5 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_7_6" 27 6 $ff_regs 
			::firefly_toolkit::update_alarm_and_warming_led "led_7_7" 27 7 $ff_regs 
		# phy con
			## ff1
			::firefly_toolkit::update_phy_con_pin "led_prs" 0 $ff_regs 0
			::firefly_toolkit::update_phy_con_pin "led_prs2" 1 $ff_regs 0
			::firefly_toolkit::update_phy_con_pin "led_intn" 2 $ff_regs 1
			::firefly_toolkit::update_phy_con_pin "led_intn2" 3 $ff_regs 1
	}
	
	proc update_phy_con_pin { led_name bit_index ff_regs flip} {
		set led_byte [lindex [lindex $ff_regs 0] 3]
		set led_byte_int [format "%b" $led_byte]
		set bit 0 
		set is_red 0
		
		if { $flip == 1} {
			set color_red "green"
			set color_green "red"
		} else {
			set color_red "red"
			set color_green "green"
		}
		while { $bit < 8 } {
			set led_is_red [expr $led_byte_int % [expr 10]]
			set led_byte_int [expr $led_byte_int / [expr 10]]
			if { $bit == $bit_index && $led_is_red == 1 } {
				set is_red 1
			}
			incr bit
		}
		if { $is_red == 1 } {
			toolkit_set_property	$led_name	color	$color_red
		} else {
			toolkit_set_property	$led_name	color	$color_green
		}
	}
	
	proc update_alarm_and_warming_led { led_name byte_index bit_index ff_regs } {
		set led_byte [lindex [lindex $ff_regs 0] $byte_index]
		set led_byte_int [format "%b" $led_byte]
		set bit 0 
		set is_red 0
		while { $bit < 8 } {
			set led_is_red [expr $led_byte_int % [expr 10]]
			set led_byte_int [expr $led_byte_int / [expr 10]]
			if { $bit == $bit_index && $led_is_red == 1 } {
				set is_red 1
			}
			incr bit
		}
		if { $is_red == 1 } {
			toolkit_set_property	$led_name	color	red
		} else {
			toolkit_set_property	$led_name	color	green
		}
	}
	
	proc update_rx_power_timechart { ff_regs tchart_name regl_Bloc regh_Bloc} {
		set ff1_rx_l [lindex [lindex $ff_regs 0] $regl_Bloc] 
		set ff1_rx_h [lindex [lindex $ff_regs 0] $regh_Bloc] 
		set ff1_rx_l_int [format "%d" $ff1_rx_l]
		set ff1_rx_l_int_conv [expr $ff1_rx_l_int*0.0001]
		set ff1_rx_h_int [format "%d" $ff1_rx_h]
		set ff1_rx_h_int_conv [expr $ff1_rx_h_int*0.0001*256]
		set ff1_rx_total [expr $ff1_rx_l_int_conv + $ff1_rx_h_int_conv]
		toolkit_set_property	$tchart_name latest [expr $ff1_rx_total]
		
	}
		
	
	proc reset_jtag2avmm { jtag_debug_index } {
		set jtag_debug_path [lindex [get_service_paths jtag_debug] $jtag_debug_index ]
		set claim_jtag_path [claim_service jtag_debug $jtag_debug_path ""]
		jtag_debug_reset_system $claim_jtag_path
		return -code ok
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
	

	
	proc get_open_master_path { master_index } {
		
		set mpath [lindex [get_service_paths master] $master_index] 
		set master_path [claim_service master $mpath ""]
		return $master_path
	}
	

	
	proc close_master { path } {
		close_service master $path
	}	
	
	
	
	proc get_master_path {} {
	# callback to link master (display)
		#refresh_connections
		variable master_list_private [get_service_paths master]
		variable master_index_option_list {}
		# display master path
		toolkit_set_property	viewmp_text	text [ format "%s" $master_list_private ]
		# make list of options for master index
		for {set i 0} {$i < [ llength $master_list_private ]} {incr i} {
			variable master_index_option_list [ linsert $master_index_option_list $i $i ]
		}
		# set list of options for master index
		toolkit_set_property	getmi_cb 	options	$master_index_option_list
		return $master_list_private
	}
	
	
}



::firefly_toolkit::dashBoard



