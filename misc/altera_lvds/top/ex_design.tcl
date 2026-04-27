# (C) 2001-2018 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


package provide altera_lvds::top::ex_design 0.1


namespace eval ::altera_lvds::top::ex_design:: {

    namespace import ::altera_emif::util::messaging::*

}



proc ::altera_lvds::top::ex_design::example_design_fileset_callback {name} {

    set generate_dps_example_design 1

	set default_device [get_parameter_value SYS_INFO_DEVICE]
	if {[string equal $default_device "Unknown"]} {
		set default_device "10AS066H2F34I1SGES"
	}

    set synth_qsys_name "ed_synth"
    set synth_qsys_file "${synth_qsys_name}.qsys"
    set synth_qsys_path [_create_and_get_temp_file_path $synth_qsys_file]
    
    set sim_qsys_name   "ed_sim"
    set sim_qsys_file   "${sim_qsys_name}.qsys"
    set sim_qsys_path   [_create_and_get_temp_file_path $sim_qsys_file]
    
    set dps_qsys_name   "ed_synth_dps"
    set dps_qsys_file   "${dps_qsys_name}.qsys"
    set dps_qsys_path   [_create_and_get_temp_file_path $dps_qsys_file]
    
    set tx_rx_qsys_name   "ed_synth_tx_rx"
    set tx_rx_qsys_file   "${tx_rx_qsys_name}.qsys"
    set tx_rx_qsys_path   [_create_and_get_temp_file_path $tx_rx_qsys_file]
    
        set file "qsys_interface_bridge/qsys_interface_bridge_hw.tcl"
        set path "ex_design/${file}"
        add_fileset_file $file OTHER PATH $path
    
    if {$generate_dps_example_design} {
        set file "dps_issp.tcl"
        set path "ex_design/${file}"
        add_fileset_file $file OTHER PATH $path
        
        set file "readme_dps.txt"
        set path "ex_design/${file}"
        add_fileset_file $file OTHER PATH $path
    }
    
    if {[get_parameter_value USE_EXTERNAL_PLL]} {
        set ext_pll_qsys_name   "lvds_external_pll"
        set ext_pll_qsys_file   "${ext_pll_qsys_name}.qsys"
        set ext_pll_qsys_path   [_create_and_get_temp_file_path $ext_pll_qsys_file]
        
        set ext_pll_sdc_file "ed_synth.sdc"
        set ext_pll_sdc_path [create_temp_file $ext_pll_sdc_file]
        set fh [open $ext_pll_sdc_path "w"]    
        puts $fh "derive_pll_clocks -create_base_clocks"
        close $fh
        add_fileset_file $ext_pll_sdc_file OTHER PATH $ext_pll_sdc_path
    }
    
    
    set params_file "params.tcl"
    set params_path [create_temp_file $params_file]
    set fh [open $params_path "w"]    
    
    puts $fh "# This file is auto-generated."
    puts $fh "# It is used by make_qii_design.tcl and make_sim_design.tcl, and"
    puts $fh "# is not intended to be executed directly."
    puts $fh ""
 
    foreach param_name [get_parameters] {
       set param_val [get_parameter_value $param_name]
       puts $fh "set ip_params(${param_name}) \"${param_val}\""
    }
    
    puts $fh "set device_family  \"[get_parameter_value SYS_INFO_DEVICE_FAMILY]\""
    puts $fh "set pro_edition  [_is_pro_edition]"
    puts $fh "set ed_params(ALTERA_LVDS_NAME)           \"$name\""
    puts $fh "set ed_params(DEFAULT_DEVICE)      \"$default_device\""
    puts $fh "set ed_params(SYNTH_QSYS_NAME)     \"$synth_qsys_name\""
    puts $fh "set ed_params(SYNTH_DPS_QSYS_NAME) \"$dps_qsys_name\""
    puts $fh "set ed_params(SYNTH_TX_RX_QSYS_NAME) \"$tx_rx_qsys_name\""
    puts $fh "set ed_params(SIM_QSYS_NAME)       \"$sim_qsys_name\""
    puts $fh "set ed_params(TMP_SYNTH_QSYS_PATH) \"$synth_qsys_path\""
    puts $fh "set ed_params(TMP_SIM_QSYS_PATH)   \"$sim_qsys_path\""
    puts $fh "set ed_params(TMP_DPS_QSYS_PATH)   \"$dps_qsys_path\""
    puts $fh "set ed_params(TMP_TX_RX_QSYS_PATH)   \"$tx_rx_qsys_path\""
        puts $fh "lappend ed_params(EXTRA_COPY_FILES)   \"qsys_interface_bridge\""
    
    if {[get_parameter_value USE_EXTERNAL_PLL]} {
        puts $fh "set ed_params(TMP_EXT_PLL_QSYS_PATH)   \"$ext_pll_qsys_path\""
        puts $fh "lappend ed_params(EXTRA_COPY_FILES)   \"$ext_pll_sdc_file\""
    }
    close $fh
    
    add_fileset_file $params_file OTHER PATH $params_path
 
    set qsys_script_exe_path "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-script"
    set platform [lindex $::tcl_platform(platform) 0]
    if { [_is_pro_edition] } {
        set pro_string "--pro"
    } else {
        set pro_string ""
    }

    if { $platform == "windows" } {
        set cmd [concat [list exec $qsys_script_exe_path $pro_string --quartus-project=none --cmd="source $params_path" --script=ex_design/make_qsys.tcl --search-path=ex_design/qsys_interface_bridge,\$]]
    } else {
        set cmd [concat [list exec $qsys_script_exe_path $pro_string --quartus-project=none --cmd='source $params_path' --script=ex_design/make_qsys.tcl --search-path=ex_design/qsys_interface_bridge,\$]]
    }
    set cmd_fail [catch { eval $cmd } tempresult]
    add_fileset_file $synth_qsys_file OTHER PATH $synth_qsys_path
    add_fileset_file $sim_qsys_file OTHER PATH $sim_qsys_path
    add_fileset_file $tx_rx_qsys_file OTHER PATH $tx_rx_qsys_path
    
    if {$generate_dps_example_design} {
        add_fileset_file $dps_qsys_file OTHER PATH $dps_qsys_path
    }
    if {[get_parameter_value USE_EXTERNAL_PLL]} {
        add_fileset_file $ext_pll_qsys_file OTHER PATH $ext_pll_qsys_path
    }
    
    if {[_is_pro_edition]} {
        set tmp_dir_path [create_temp_file ""]
        set ip_files [_ls_recursive "${tmp_dir_path}" "*.ip"]
        
        foreach path $ip_files {
            set file [_get_relative_path $tmp_dir_path $path]
            add_fileset_file $file OTHER PATH $path
        }
    }
    
    set file "make_qii_design.tcl"
    set path "ex_design/${file}"
    add_fileset_file $file OTHER PATH $path
 
    set file "make_sim_design.tcl"
    set path "ex_design/${file}"
    add_fileset_file $file OTHER PATH $path
    
    set file "readme.txt"
    set path "ex_design/${file}"
    add_fileset_file $file OTHER PATH $path
}
 

proc ::altera_lvds::top::ex_design::_is_pro_edition {} {
    
    if { [catch {is_qsys_edition QSYS_PRO} result] } {
        return 0
    } else {
        return $result
    }
}

proc ::altera_lvds::top::ex_design::_ls_recursive {base glob} {
    set files [list]

    foreach f [glob -nocomplain -types f -directory $base $glob] {
        set file_path [file join $base $f]
        lappend files $file_path
    }

    foreach d [glob -nocomplain -types d -directory $base *] {
        set files_recursive [_ls_recursive [file join $base $d] $glob]
        lappend files {*}$files_recursive
    }

    return $files
}

proc ::altera_lvds::top::ex_design::_get_relative_path {base path} {
    return [string trimleft [ string range $path [string length $base] [string length $path] ] "/"]
}

proc ::altera_lvds::top::ex_design::_create_and_get_temp_file_path { filename } {
    set qsys_path [create_temp_file $filename]
	set fh [open $qsys_path "w"] 
	close $fh
    return $qsys_path
}

proc ::altera_lvds::top::ex_design::_init {} {
}

::altera_lvds::top::ex_design::_init
