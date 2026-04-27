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


package require -exact qsys 15.0


proc string_compare {string_1 string_2} {
    return [expr {[string compare -nocase $string_1 $string_2] == 0}] 
}

proc param_string_compare {param str {param_map "ip_params"}} {
    upvar $param_map ip_params
    return [string_compare $ip_params($param) $str]
}

proc interface_exists_on_instance {interface_name instance} {
    set interface_list [get_instance_interfaces $instance]
    return [expr [lsearch $interface_list $interface_name] != -1]
}

proc strip_units {with_units} {
    if {[regexp {([0-9\.]+)} $with_units no_units]} {
        return $no_units
    } else {
        return "N/A"
    }    
}

proc add_external_pll {ext_pll_name} {
    upvar ip_params ip_params
    upvar device_family device_family
    add_instance $ext_pll_name altera_iopll
    
    set_instance_parameter_value $ext_pll_name gui_en_lvds_ports "Enable LVDS_CLK/LOADEN 0"
    set_instance_parameter_value $ext_pll_name gui_fix_vco_frequency 1
    
    if {[param_string_compare MODE "RX_Soft-CDR"] || [param_string_compare MODE "RX_DPA-FIFO"]} {
        set_instance_parameter_value $ext_pll_name gui_en_phout_ports 1
    }
    
    set_instance_parameter_value $ext_pll_name gui_reference_clock_frequency [strip_units $ip_params(pll_inclock_frequency)]
    set_instance_parameter_value $ext_pll_name gui_fixed_vco_frequency [strip_units $ip_params(pll_vco_frequency)]
    if {[param_string_compare MODE "RX_Non-DPA"]} {
        set_instance_parameter_value $ext_pll_name gui_operation_mode lvds
    } else {
        set_instance_parameter_value $ext_pll_name gui_operation_mode direct
    }
    
    if {[string_compare $device_family "Arria 10"]} {
        add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_fclk_frequency)] [strip_units $ip_params(pll_fclk_phase_shift)] 50 1
        add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_loaden_frequency)] [strip_units $ip_params(pll_loaden_phase_shift)] [strip_units $ip_params(pll_loaden_duty_cycle)]
        
        if {[param_string_compare MODE "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
            set_instance_parameter_value $ext_pll_name gui_en_lvds_ports "Enable LVDS_CLK/LOADEN 0 & 1"
            add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_tx_outclock_fclk_frequency)] [strip_units $ip_params(pll_tx_outclock_fclk_phase_shift)] 50       
            add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_tx_outclock_loaden_frequency)] [strip_units $ip_params(pll_tx_outclock_loaden_phase_shift)] [strip_units $ip_params(pll_loaden_duty_cycle)]
        }
        
        add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_sclk_frequency)] [strip_units $ip_params(pll_sclk_phase_shift)] 50
    } else {
        if {[param_string_compare MODE "TX"]} {
            set_instance_parameter_value $ext_pll_name gui_en_lvds_ports "Enable LVDS_CLK/LOADEN 0 & 1"
        }
        
        if {[param_string_compare MODE "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
            add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_tx_outclock_fclk_frequency)] [strip_units $ip_params(pll_tx_outclock_fclk_phase_shift)] 50 1      
            add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_tx_outclock_loaden_frequency)] [strip_units $ip_params(pll_tx_outclock_loaden_phase_shift)] [strip_units $ip_params(pll_loaden_duty_cycle)]
        } else {
            add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_fclk_frequency)] [strip_units $ip_params(pll_fclk_phase_shift)] 50 1
            add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_loaden_frequency)] [strip_units $ip_params(pll_loaden_phase_shift)] [strip_units $ip_params(pll_loaden_duty_cycle)]
        }
    
        add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_fclk_frequency)] [strip_units $ip_params(pll_fclk_phase_shift)] 50
        add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_loaden_frequency)] [strip_units $ip_params(pll_loaden_phase_shift)] [strip_units $ip_params(pll_loaden_duty_cycle)]

        add_extra_pll_clock $ext_pll_name [strip_units $ip_params(pll_sclk_frequency)] [strip_units $ip_params(pll_sclk_phase_shift)] 50
    }
}

proc add_extra_pll_clock {ext_pll_name frequency {phase_shift 0} {duty_cycle 50} {first 0}} {
    if {$first} {
        set num_clocks 0
    } else {
        set num_clocks [get_instance_parameter_value $ext_pll_name gui_number_of_clocks]
    }
    set extra_clk_idx $num_clocks
    incr num_clocks
    set_instance_parameter_value $ext_pll_name gui_number_of_clocks $num_clocks
    
    set_instance_parameter_value $ext_pll_name gui_output_clock_frequency$extra_clk_idx $frequency
    set_instance_parameter_value $ext_pll_name gui_phase_shift$extra_clk_idx $phase_shift
    set_instance_parameter_value $ext_pll_name gui_duty_cycle$extra_clk_idx $duty_cycle
    
    return $extra_clk_idx
}

proc enable_dynamic_phase_shift_pll {ext_pll_name} {
    set_instance_parameter_value $ext_pll_name gui_en_dps_ports 1    
    set scanclk_idx [add_extra_pll_clock $ext_pll_name 50.0]
    
    return $scanclk_idx
}

proc add_lvds_core {core_name} {
    upvar ip_params ip_params
    add_instance $core_name altera_lvds

    foreach param_name [array names ip_params] { 
        set_instance_parameter_value $core_name $param_name $ip_params($param_name)
    }
    set_instance_parameter_value $core_name GENERATE_SDC_FILE "true"
}

proc add_complement_lvds_core {core_name} {
    upvar ip_params ip_params
    upvar complement_ip_params complement_ip_params
    
    add_instance $core_name altera_lvds
    
    foreach param_name [array names ip_params] { 
        set complement_ip_params($param_name) $ip_params($param_name)
    }

    if {[param_string_compare MODE "TX"]} {
        set complement_ip_params(MODE) "RX_DPA-FIFO"
    } elseif {[param_string_compare MODE "RX_Soft-CDR"] || [param_string_compare MODE "RX_DPA-FIFO"] || [param_string_compare MODE "RX_Non-DPA"]} {
        set complement_ip_params(MODE) "TX"
    }

    foreach param_name [array names complement_ip_params] { 
        set_instance_parameter_value $core_name $param_name $complement_ip_params($param_name)
    }
    
    set_instance_parameter_value $core_name GENERATE_SDC_FILE "true"
}

proc add_driver {driver_name} {
    upvar ip_params ip_params
    
    add_instance $driver_name altera_lvds_driver

    foreach param_name [get_instance_parameters $driver_name] { 
        if {![get_instance_parameter_property $driver_name $param_name DERIVED]} {
            set_instance_parameter_value $driver_name $param_name $ip_params($param_name)
        }
    }
}

proc add_source_probe_component {name instance_id {source_width 1} {probe_width 0}} {
    add_instance $name altera_in_system_sources_probes
    
    set_instance_parameter_value $name gui_use_auto_index 1
    set_instance_parameter_value $name sld_instance_index 0
    set_instance_parameter_value $name instance_id $instance_id
    set_instance_parameter_value $name probe_width $probe_width
    set_instance_parameter_value $name source_width $source_width
    set_instance_parameter_value $name source_initial_value 0
    set_instance_parameter_value $name create_source_clock 0
    set_instance_parameter_value $name create_source_clock_enable 0
}

proc configure_lvds_pll_bridge {bridge_name} {
    
    upvar ip_params ip_params
    upvar device_family device_family
    
    set INTERFACES [list]
    set PORTS [list]
    
    lappend INTERFACES {ext_fclk conduit end}
    lappend PORTS {ext_fclk ext_fclk export Output 1}
    
    lappend INTERFACES {ext_tx_outclock_fclk conduit end}
    lappend PORTS {ext_tx_outclock_fclk ext_tx_outclock_fclk export Output 1}
    
    lappend INTERFACES {ext_loaden conduit end}
    lappend PORTS {ext_loaden ext_loaden export Output 1}
    
    lappend INTERFACES {ext_tx_outclock_loaden conduit end}
    lappend PORTS {ext_tx_outclock_loaden ext_tx_outclock_loaden export Output 1}
    
    lappend INTERFACES {ext_vcoph conduit end}
    lappend PORTS {ext_vcoph ext_vcoph export Output 8}
    
    lappend INTERFACES {ext_pll_locked conduit end}
    lappend PORTS {ext_pll_locked ext_pll_locked export Output 1}
    
    lappend INTERFACES {ext_coreclock conduit end}
    lappend PORTS {ext_coreclock ext_coreclock export Output 1}
    
    lappend INTERFACES {ext_fclk2 conduit end}
    lappend PORTS {ext_fclk2 ext_fclk2 export Output 1}
    
    lappend INTERFACES {ext_tx_outclock_fclk2 conduit end}
    lappend PORTS {ext_tx_outclock_fclk2 ext_tx_outclock_fclk2 export Output 1}
    
    lappend INTERFACES {ext_loaden2 conduit end}
    lappend PORTS {ext_loaden2 ext_loaden2 export Output 1}
    
    lappend INTERFACES {ext_tx_outclock_loaden2 conduit end}
    lappend PORTS {ext_tx_outclock_loaden2 ext_tx_outclock_loaden2 export Output 1}
    
    lappend INTERFACES {ext_vcoph2 conduit end}
    lappend PORTS {ext_vcoph2 ext_vcoph2 export Output 8}
    
    lappend INTERFACES {ext_pll_locked2 conduit end}
    lappend PORTS {ext_pll_locked2 ext_pll_locked2 export Output 1}
    
    lappend INTERFACES {ext_coreclock2 conduit end}
    lappend PORTS {ext_coreclock2 ext_coreclock2 export Output 1}
    
    lappend INTERFACES {lvds_clk conduit end}
    lappend PORTS {lvds_clk lvds_clk lvds_clk Input 2}
    
    lappend INTERFACES {loaden conduit end}
    lappend PORTS {loaden loaden loaden Input 2}
    
    lappend INTERFACES {locked conduit end}
    lappend PORTS {locked locked export Input 1}
    
    lappend INTERFACES {phout conduit end}
    lappend PORTS {phout phout phout Input 8}
    
    lappend INTERFACES {coreclock_in clock end}
    lappend PORTS {coreclock_in coreclock_in clk Input 1}
    
    lappend INTERFACES {pll_locked conduit end}
    lappend PORTS {pll_locked pll_locked export Output 1}
    
    lappend INTERFACES {num_phase_shifts_in conduit end}
    lappend PORTS {num_phase_shifts_in num_phase_shifts_in source Input 3}
    
    lappend INTERFACES {phase_en_in conduit end}
    lappend PORTS {phase_en_in phase_en_in source Input 1}
    
    lappend INTERFACES {updn_in conduit end}
    lappend PORTS {updn_in updn_in source Input 1}
    
    lappend INTERFACES {cntsel_in conduit end}
    lappend PORTS {cntsel_in cntsel_in source Input 5}
    
    lappend INTERFACES {scanclk_in clock end}
    lappend PORTS {scanclk_in scanclk_in clk Input 1}
    
    lappend INTERFACES {reset_in conduit end}
    lappend PORTS {reset_in reset_in source Input 1}
    
    lappend INTERFACES {pll_locked_prb conduit end}
    lappend PORTS {pll_locked_prb pll_locked_prb probe Output 1}
    
    lappend INTERFACES {coreclock conduit end}
    lappend PORTS {coreclock coreclock export Output 1}
    
    lappend INTERFACES {reset reset start}
    lappend PORTS {reset reset reset Output 1}
    
    lappend INTERFACES {pll_areset conduit end}
    lappend PORTS {pll_areset pll_areset export Output 1}
    
    lappend INTERFACES {phase_en conduit end}
    lappend PORTS {phase_en phase_en phase_en Output 1}
    
    lappend INTERFACES {updn conduit end}
    lappend PORTS {updn updn updn Output 1}
    
    lappend INTERFACES {cntsel conduit end}
    lappend PORTS {cntsel cntsel cntsel Output 5}
    
    lappend INTERFACES {num_phase_shifts conduit end}
    lappend PORTS {num_phase_shifts num_phase_shifts num_phase_shifts Output 3}
    
    lappend INTERFACES {scanclk conduit end}
    lappend PORTS {scanclk scanclk scanclk Output 1}
    
    set CONNECTIONS [list]
    if {[string_compare $device_family "Arria 10"]} {
        lappend CONNECTIONS {lvds_clk[0] ext_fclk}
        lappend CONNECTIONS {lvds_clk[0] ext_fclk2}
        lappend CONNECTIONS {lvds_clk[1] ext_tx_outclock_fclk}
        lappend CONNECTIONS {lvds_clk[1] ext_tx_outclock_fclk2}
        lappend CONNECTIONS {loaden[0] ext_loaden}
        lappend CONNECTIONS {loaden[0] ext_loaden2}
        lappend CONNECTIONS {loaden[1] ext_tx_outclock_loaden}
        lappend CONNECTIONS {loaden[1] ext_tx_outclock_loaden2}
    } else {
        if {[param_string_compare MODE "TX"]} {
            lappend CONNECTIONS {lvds_clk[1] ext_fclk}
            lappend CONNECTIONS {lvds_clk[0] ext_tx_outclock_fclk}
            lappend CONNECTIONS {loaden[1] ext_loaden}
            lappend CONNECTIONS {loaden[0] ext_tx_outclock_loaden}
            
            lappend CONNECTIONS {lvds_clk[0] ext_fclk2}
            lappend CONNECTIONS {loaden[0] ext_loaden2}
        } else {
            lappend CONNECTIONS {lvds_clk[0] ext_fclk}
            lappend CONNECTIONS {loaden[0] ext_loaden}
            
            lappend CONNECTIONS {lvds_clk[1] ext_fclk2}
            lappend CONNECTIONS {lvds_clk[0] ext_tx_outclock_fclk2}
            lappend CONNECTIONS {loaden[1] ext_loaden2}
            lappend CONNECTIONS {loaden[0] ext_tx_outclock_loaden2}
        }
    }
        
    lappend CONNECTIONS {phout ext_vcoph}
    lappend CONNECTIONS {phout ext_vcoph2}
    lappend CONNECTIONS {locked ext_pll_locked}
    lappend CONNECTIONS {locked ext_pll_locked2}
    lappend CONNECTIONS {locked pll_locked}
    lappend CONNECTIONS {locked pll_locked_prb}
    lappend CONNECTIONS {coreclock_in ext_coreclock}
    lappend CONNECTIONS {coreclock_in ext_coreclock2}
    lappend CONNECTIONS {coreclock_in coreclock}
    lappend CONNECTIONS {phase_en_in phase_en}
    lappend CONNECTIONS {updn_in updn}
    lappend CONNECTIONS {cntsel_in cntsel}
    lappend CONNECTIONS {num_phase_shifts_in num_phase_shifts}
    lappend CONNECTIONS {scanclk_in scanclk}
    lappend CONNECTIONS {reset_in reset}
    lappend CONNECTIONS {reset_in pll_areset}
    
    set CUSTOM_ELABORATION_COMMANDS [list]
    lappend CUSTOM_ELABORATION_COMMANDS {set_interface_property reset synchronousEdges NONE}
    
    set_instance_parameter_value $bridge_name INTERFACES $INTERFACES
    set_instance_parameter_value $bridge_name PORTS $PORTS
    set_instance_parameter_value $bridge_name CONNECTIONS $CONNECTIONS
    set_instance_parameter_value $bridge_name CUSTOM_ELABORATION_COMMANDS $CUSTOM_ELABORATION_COMMANDS
}

proc disable_disconnected_bridge_interfaces {bridge_name} {
    
    set CUSTOM_ELABORATION_COMMANDS [get_instance_parameter_value $bridge_name CUSTOM_ELABORATION_COMMANDS]
    
    foreach connection [get_connections $bridge_name] {
        set start_connection [split [get_connection_property $connection START] .]
        set start_instance [lindex $start_connection 0]
        set start_interface [lindex $start_connection 1]
        set end_connection [split [get_connection_property $connection END] .]
        set end_instance [lindex $end_connection 0]
        set end_interface [lindex $end_connection 1]
        
        if {[string_compare $start_instance $bridge_name]} {
            set enabled_interfaces($start_interface) 1
        } 
        if {[string_compare $end_instance $bridge_name]} {
            set enabled_interfaces($end_interface) 1
        }    
    }
    
    foreach interface [get_interfaces] {
        set export [split [get_interface_property $interface EXPORT_OF] .]
        set exported_instance [lindex $export 0]
        set exported_interface [lindex $export 1]
        if {[string_compare $exported_instance $bridge_name]} {
            set enabled_interfaces($exported_interface) 1
        }
    }
    
    foreach interface [get_instance_interfaces $bridge_name] {
        if {![info exists enabled_interfaces($interface)]} {
            lappend CUSTOM_ELABORATION_COMMANDS "set_interface_property $interface ENABLED false"
        }
    }

    set_instance_parameter_value $bridge_name CUSTOM_ELABORATION_COMMANDS $CUSTOM_ELABORATION_COMMANDS
}

proc add_connections_bridge_lvds {core_name bridge_name {param_map "ip_params"} {second_set 0}} {
    upvar $param_map ip_params
    
    if {$second_set} {
        set suffix "2"
    } else {
        set suffix ""
    }
    
    add_connection $core_name.ext_fclk/$bridge_name.ext_fclk$suffix
    if {[param_string_compare MODE "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
        add_connection $core_name.ext_tx_outclock_fclk/$bridge_name.ext_tx_outclock_fclk$suffix
        add_connection $core_name.ext_tx_outclock_loaden/$bridge_name.ext_tx_outclock_loaden$suffix
    }
    add_connection $bridge_name.ext_coreclock$suffix/$core_name.ext_coreclock
    
    if {![param_string_compare MODE "RX_Soft-CDR"]} {
        add_connection $core_name.ext_loaden/$bridge_name.ext_loaden$suffix
    }
    
    if {[param_string_compare MODE "RX_Soft-CDR"] || [param_string_compare MODE "RX_DPA-FIFO"]} {
        add_connection $core_name.ext_vcoph/$bridge_name.ext_vcoph$suffix
        add_connection $core_name.ext_pll_locked/$bridge_name.ext_pll_locked$suffix
    }
}

proc add_connections_pll_bridge {ext_pll_name bridge_name {param_map "ip_params"}} {
    upvar $param_map ip_params
    upvar device_family device_family
    
    add_connection $ext_pll_name.lvds_clk/$bridge_name.lvds_clk
    add_connection $ext_pll_name.loaden/$bridge_name.loaden
    add_connection $bridge_name.locked/$ext_pll_name.locked
    
    if {[param_string_compare MODE "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
        add_connection $ext_pll_name.outclk4/$bridge_name.coreclock_in
    } else {
        if {[string_compare $device_family "Arria 10"]} {
            add_connection $ext_pll_name.outclk2/$bridge_name.coreclock_in
        } else {
            add_connection $ext_pll_name.outclk4/$bridge_name.coreclock_in
        }
        
    }
    
    if {[param_string_compare MODE "RX_Soft-CDR"] || [param_string_compare MODE "RX_DPA-FIFO"]} {
        set_instance_parameter_value $ext_pll_name gui_en_phout_ports 1
        add_connection $bridge_name.phout/$ext_pll_name.phout
    }
}

proc add_connections_lvds_pll_bridge {core_name ext_pll_name bridge_name} {
    upvar ip_params ip_params
    upvar device_family device_family
    
    configure_lvds_pll_bridge $bridge_name
    add_connections_pll_bridge $ext_pll_name $bridge_name
    add_connections_bridge_lvds $core_name $bridge_name
}

proc add_connections_driver_lvds {core_name driver_name bridge_name ext_pll_name} {
    upvar ip_params ip_params
    
    if {[param_string_compare USE_EXTERNAL_PLL "false"]} {
        add_connection $driver_name.refclk/$core_name.inclock
        if {![param_string_compare MODE "TX"]} {
            add_connection $core_name.rx_coreclock/$driver_name.coreclock
        } elseif {[param_string_compare TX_EXPORT_CORECLOCK "true"]} {
            add_connection $core_name.tx_coreclock/$driver_name.coreclock
        }
    } else {
        add_connection $driver_name.ext_refclk/$ext_pll_name.refclk
        add_connection $driver_name.ext_reset/$ext_pll_name.reset
        add_connection $driver_name.pll_locked/$bridge_name.pll_locked
        add_connection $driver_name.coreclock/$bridge_name.coreclock
        
        if {[param_string_compare MODE "TX"] && [param_string_compare TX_REGISTER_CLOCK "inclock"]} {
            add_connection $driver_name.refclk/$core_name.inclock
        }
    }
    
    if {[param_string_compare PLL_USE_RESET "true"]} {
        add_connection $core_name.pll_areset/$driver_name.pll_areset
    }

    if {[param_string_compare MODE "TX"]} {
        add_connection $core_name.tx_in/$driver_name.par_in
        add_connection $core_name.tx_out/$driver_name.lvdsout
        if { [param_string_compare TX_USE_OUTCLOCK "true"] } {
            add_connection $driver_name.tx_outclock/$core_name.tx_outclock
        }
    } else {
        add_connection $core_name.rx_in/$driver_name.lvdsin
        add_connection $core_name.rx_out/$driver_name.par_out
        
        set use_bitslip [param_string_compare RX_USE_BITSLIP "true"]
        
        if { $use_bitslip } {
            add_connection $core_name.rx_bitslip_ctrl/$driver_name.bslipcntl
        }
        
        if { $use_bitslip && [param_string_compare RX_BITSLIP_ASSERT_MAX "true"] } {
            add_connection $core_name.rx_bitslip_max/$driver_name.bslipmax
        }
        
        if { [param_string_compare RX_BITSLIP_USE_RESET "true"] && $use_bitslip } {
            add_connection $core_name.rx_bitslip_reset/$driver_name.bsliprst
        }
        if {[param_string_compare MODE "RX_DPA-FIFO"] || [param_string_compare MODE "RX_Soft-CDR"]} {   
            if {[param_string_compare RX_DPA_USE_RESET "true"] } {
                add_connection $core_name.rx_dpa_reset/$driver_name.dparst
            }
            add_connection $core_name.rx_dpa_locked/$driver_name.lock
            
            if {[param_string_compare ENABLE_DIV_RECONFIG "true"]} {
                add_connection $core_name.user_mdio_dis/$driver_name.user_mdio_dis         
                add_connection $core_name.user_dprio_clk/$driver_name.user_dprio_clk         
                add_connection $core_name.user_dprio_rst_n/$driver_name.user_dprio_rst_n       
                add_connection $core_name.user_dprio_read/$driver_name.user_dprio_read        
                add_connection $core_name.user_dprio_reg_addr/$driver_name.user_dprio_reg_addr    
                add_connection $core_name.user_dprio_write/$driver_name.user_dprio_write       
                add_connection $core_name.user_dprio_writedata/$driver_name.user_dprio_writedata   
                add_connection $core_name.user_dprio_block_select/$driver_name.user_dprio_block_select
                add_connection $core_name.user_dprio_readdata/$driver_name.user_dprio_readdata    
                add_connection $core_name.user_dprio_ready/$driver_name.user_dprio_ready       
            }
        }
        if {[param_string_compare MODE "RX_Soft-CDR"]} {  
            add_connection $core_name.rx_divfwdclk/$driver_name.pclk
        }
    }

    if {[param_string_compare PLL_EXPORT_LOCK "true"] 
        && [param_string_compare USE_EXTERNAL_PLL "false"] 
        && [param_string_compare USE_CLOCK_PIN "false"] } {
        
        add_connection $core_name.pll_locked/$driver_name.pll_locked
    }
}

proc export_interfaces {component_name {export_prefix ""} {interface_list ""}} {
    if {$interface_list == ""} {
        set interface_list [get_instance_interfaces $component_name]
    } 
    
    if {$export_prefix == ""} {
        set export_prefix $component_name
    }
    
    foreach interface_name $interface_list {
        set exported_interface_name ${export_prefix}_$interface_name
        add_interface $exported_interface_name conduit end
        set_interface_property $exported_interface_name EXPORT_OF "${component_name}.${interface_name}"
    }
}

if {! [info exists ip_params] || ! [info exists ed_params]} {
   source "params.tcl"
}

set lvds_if    [list $ed_params(ALTERA_LVDS_NAME)]

create_system
set_project_property DEVICE_FAMILY $device_family
set_project_property DEVICE $ip_params(SYS_INFO_DEVICE)


set core_name $lvds_if
set driver_name driver
set ext_pll_name external_pll
set bridge_name bridge

if {[param_string_compare USE_EXTERNAL_PLL "true"]} {
    add_external_pll $ext_pll_name
    set_instance_property $ext_pll_name AUTO_EXPORT true
    save_system $ed_params(TMP_EXT_PLL_QSYS_PATH)
    
    create_system
    set_project_property DEVICE_FAMILY $device_family
    set_project_property DEVICE $ip_params(SYS_INFO_DEVICE)
    add_external_pll $ext_pll_name
}

add_lvds_core $core_name

if {[param_string_compare USE_EXTERNAL_PLL "true"]} {
 
    set_instance_property $core_name AUTO_EXPORT true
    add_instance $bridge_name qsys_interface_bridge 
    add_connections_lvds_pll_bridge $core_name $ext_pll_name $bridge_name
    export_interfaces $bridge_name $core_name [list coreclock pll_locked]
    disable_disconnected_bridge_interfaces $bridge_name
    export_interfaces $ext_pll_name $ext_pll_name [list refclk reset]
} else {
    export_interfaces $core_name
}

save_system $ed_params(TMP_SYNTH_QSYS_PATH)


create_system
set_project_property DEVICE_FAMILY $device_family
set_project_property DEVICE $ip_params(SYS_INFO_DEVICE)
add_lvds_core $core_name

if {[param_string_compare USE_EXTERNAL_PLL "true"]} {
    add_external_pll $ext_pll_name
    add_instance $bridge_name qsys_interface_bridge 
    add_connections_lvds_pll_bridge $core_name $ext_pll_name $bridge_name
}

add_driver $driver_name
add_connections_driver_lvds $core_name $driver_name $bridge_name $ext_pll_name

if {[param_string_compare USE_EXTERNAL_PLL "true"]} {
    disable_disconnected_bridge_interfaces $bridge_name
}

save_system $ed_params(TMP_SIM_QSYS_PATH)

create_system
set_project_property DEVICE_FAMILY $device_family
set_project_property DEVICE $ip_params(SYS_INFO_DEVICE)
set ip_params(USE_EXTERNAL_PLL) "true"
add_external_pll $ext_pll_name
set scanclk_idx [enable_dynamic_phase_shift_pll $ext_pll_name]
add_lvds_core $core_name
set_instance_property $core_name AUTO_EXPORT true
add_instance $bridge_name qsys_interface_bridge 
add_connections_lvds_pll_bridge $core_name $ext_pll_name $bridge_name

set coreclock_idx [expr {[get_instance_parameter_value $ext_pll_name gui_number_of_clocks] - 1}]
add_connection $ext_pll_name.outclk$coreclock_idx $bridge_name.scanclk_in

add_connection $bridge_name.scanclk $ext_pll_name.scanclk
add_connection $bridge_name.reset $ext_pll_name.reset
add_connection $bridge_name.pll_areset $core_name.pll_areset

set dps_ports(cntsel) [list 5 CSEL]
set dps_ports(num_phase_shifts) [list 3 NPS]
set dps_ports(updn) [list 1 UPDN]
set dps_ports(phase_en) [list 1 PEN]

foreach dps_port [array names dps_ports] {
    set width [lindex $dps_ports($dps_port) 0]
    set instance_id [lindex $dps_ports($dps_port) 1]
    add_source_probe_component $dps_port $instance_id $width 
    add_connection $ext_pll_name.$dps_port $bridge_name.$dps_port
    add_connection $dps_port.sources $bridge_name.${dps_port}_in
}

add_source_probe_component reset RST
add_connection reset.sources $bridge_name.reset_in

add_source_probe_component pll_locked LCK 0 1
add_connection pll_locked.probes $bridge_name.pll_locked_prb

set extra_clock_idx [add_extra_pll_clock $ext_pll_name 50.0]

export_interfaces $bridge_name $core_name [list coreclock pll_locked]
disable_disconnected_bridge_interfaces $bridge_name
export_interfaces $ext_pll_name $ext_pll_name [list refclk outclk$extra_clock_idx]

save_system $ed_params(TMP_DPS_QSYS_PATH)

create_system
set_project_property DEVICE_FAMILY $device_family
set_project_property DEVICE $ip_params(SYS_INFO_DEVICE)
add_external_pll $ext_pll_name
add_lvds_core $core_name
set_instance_property $core_name AUTO_EXPORT true
set complement_core_name "${core_name}_complement"
array set complement_ip_params {}
add_complement_lvds_core $complement_core_name
set_instance_property $complement_core_name AUTO_EXPORT true
add_instance $bridge_name qsys_interface_bridge 
add_connections_lvds_pll_bridge $core_name $ext_pll_name $bridge_name
add_connections_pll_bridge $ext_pll_name $bridge_name complement_ip_params
add_connections_bridge_lvds $complement_core_name $bridge_name complement_ip_params 1
export_interfaces $bridge_name $core_name [list coreclock pll_locked]
disable_disconnected_bridge_interfaces $bridge_name
export_interfaces $ext_pll_name $ext_pll_name [list refclk reset]

save_system $ed_params(TMP_TX_RX_QSYS_PATH)

