###########################################################################################################
# @Name 		mutrig_controller_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the MuTRiG Controller IP core. 
#				Contains the tcl-list to bit pattern generator.
#
# @Functions	generate_bit_pattern
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Sep 27, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide mutrig_controller::bsp 	24.0

namespace eval ::mutrig_controller::bsp:: {
	namespace export \
	generate_bit_pattern 
}

######################################################################################################
##  Arguments:
##		<config> - tcl list of configuration bit length, value and bit-ordering for each parameter
##			format: 
##			{parameter0} {parameter1} {parameter2} ...
##			     └── <length> <value in dec> <ordering>
##			<ordering> - 0: do not reverse, 1: need reverse
##
##  Description:
##  convert the pre-defined tcl list into bit string 
##
##	Returns:
##		<bits> - the configure bit string for MuTRiG
##
######################################################################################################
proc ::mutrig_controller::bsp::generate_bit_pattern {config} {
	set bits {}
	foreach parameter $config {
		set length [lindex $parameter 0]
		set value_in_dec [lindex $parameter 1]
		#puts "value in dec: $value_in_dec"
		set ordering [lindex $parameter 2]
		#puts "ordering: $ordering"
		# value_in_dec -> parameter_bits
		set parameter_bits [format "%0*b" $length $value_in_dec]
		if {$ordering == 0} {
			append bits $parameter_bits
		} else {
			append bits [::mutrig_controller::bsp::string_reverse $parameter_bits]
		}
	}
	return $bits
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
proc ::mutrig_controller::bsp::string_reverse {str} {
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
##		<fieldName> - name of the bit field (e.g. Header, Channel, TDC, Footer)
##			
##  Description:
##  This function returns the info of the selected bit field.
##
##	Returns:
##		<info> - format [list {parameter_name parameter_bit_length parameter_ordering}
##					<ordering> - 0: normal, 1: need reversal
##
######################################################################################################
proc ::mutrig_controller::bsp::get_parameter_info {fieldName} {
	set mutrig_header_param \
	[list {"gen_idle" 1 0} {"sync_ch_rst" 1 0} {"ext_trig_mode" 1 0} {"ext_trig_endtime_sign" 1 0} \
	{"ext_trig_offset" 4 1} {"ext_trig_endtime" 4 1} {"ms_limits" 5 1} {"ms_switch_sel" 1 0} \
	{"ms_debug" 1 0} {"tx_mode" 3 1} {"pll_setcoarse" 1 0} {"pll_envomonitor" 1 0} \
	{"disable_coarse" 1 0} {"pll_lol_dbg" 1 0} {"en_ch_evt_cnt" 1 0} {"dmon_sel" 5 0} \
	{"dmon_sel_enable" 1 0} {"dmon_sw" 1 0}]
	set mutrig_ch_param \
	[list {"energy_c_en" 1 0} {"energy_r_en" 1 0} {"sswitch" 1 0} \
	{"cm_sensing_high_r" 1 0} {"amon_en_n" 1 0} {"edge" 1 0} {"edge_cml" 1 0} {"cml_sc" 1 0} \
	{"tdctest_n" 1 0} {"amonctrl" 3 0} {"comp_spi" 2 0} {"tthresh_offset_1" 1 0} {"sipm" 6 0} \
	{"tthresh_offset_2" 1 0} {"tthresh_sc" 2 0} {"tthresh" 6 0} {"ampcom_sc" 2 0} {"ampcom" 6 0} \
	{"tthresh_offset_0" 1 0} {"inputbias" 6 0} {"ethresh" 8 0} {"ebias" 3 0} {"pole_sc" 1 0} \
	{"pole" 6 0} {"cml" 4 0} {"delay" 1 0} {"pole_en_n" 1 0} {"mask" 1 0} {"recv_all" 1 0}] 
	set mutrig_tdc_param \
	[list {"vnd2c_scale" 1 0} {"vnd2c_offset" 2 0} {"vnd2c" 6 0} \
	{"vncntbuffer_scale" 1 0} {"vncntbuffer_offset" 2 0} {"vncntbuffer" 6 0} {"vncnt_scale" 1 0} \
	{"vncnt_offset" 2 0} {"vncnt" 6 0} {"vnpcp_scale" 1 0} {"vnpcp_offset" 2 0} {"vnpcp" 6 0} \
	{"vnvcodelay_scale" 1 0} {"vnvcodelay_offset" 2 0} {"vnvcodelay" 6 0} {"vnvcobuffer_scale" 1 0} \
	{"vnvcobuffer_offset" 2 0} {"vnvcobuffer" 6 0} {"vnhitlogic_scale" 1 0} {"vnhitlogic_offset" 2 0} \
	{"vnhitlogic" 6 0} {"vnpfc_scale" 1 0} {"vnpfc_offset" 2 0} {"vnpfc" 6 0} {"latchbias" 12 1}]
	set mutrig_footer_param \
	[list {"coin_xbar_lower_rx_ena" 1 0} {"coin_xbar_lower_tx_ena" 1 0} \
	{"coin_xbar_lower_tx_vdac" 8 0} {"coin_xbar_lower_tx_idac" 6 0} {"coin_mat_xbl" 3 0} \
	{"coin_mat_0" 6 0} {"coin_mat_1" 6 0} {"coin_mat_2" 6 0} {"coin_mat_3" 6 0} {"coin_mat_4" 6 0} \
	{"coin_mat_5" 6 0} {"coin_mat_6" 6 0} {"coin_mat_7" 6 0} {"coin_mat_8" 6 0} {"coin_mat_9" 6 0} \
	{"coin_mat_10" 6 0} {"coin_mat_11" 6 0} {"coin_mat_12" 6 0} {"coin_mat_13" 6 0} {"coin_mat_14" 6 0} \
	{"coin_mat_15" 6 0} {"coin_mat_16" 6 0} {"coin_mat_17" 6 0} {"coin_mat_18" 6 0} {"coin_mat_19" 6 0} \
	{"coin_mat_20" 6 0} {"coin_mat_21" 6 0} {"coin_mat_22" 6 0} {"coin_mat_23" 6 0} {"coin_mat_24" 6 0} \
	{"coin_mat_25" 6 0} {"coin_mat_26" 6 0} {"coin_mat_27" 6 0} {"coin_mat_28" 6 0} {"coin_mat_29" 6 0} \
	{"coin_mat_30" 6 0} {"coin_mat_31" 6 0} {"coin_mat_xbu" 3 0} {"coin_xbar_upper_rx_ena" 1 0} \
	{"coin_xbar_upper_tx_ena" 1 0} {"coin_xbar_upper_tx_vdac" 8 0} {"coin_xbar_upper_tx_idac" 6 0} \
	{"coin_wnd" 1 0} {"amon_en" 1 0} {"amon_dac" 8 0} {"dmon_1_en" 1 0} {"dmon_1_dac" 8 0} \
	{"dmon_2_en" 1 0} {"dmon_2_dac" 8 0} {"lvds_tx_vcm" 8 0} {"lvds_tx_bias" 6 0}] 
	switch $fieldName {
		"Header" {
			return $mutrig_header_param
		}
		"Channel" {
			return $mutrig_ch_param
		}
		"TDC" {
			return $mutrig_tdc_param
		}
		"Footer" {
			return $mutrig_footer_param
		}
		default {
			error "Input (\"${fieldName}\") does not match with any defined field name of MuTRiG. \
			(e.g. Header, Channel, TDC, Footer)"
		}
	}
	
	
}






