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


package provide altera_lvds::core_14::main 0.1

package require altera_lvds::top::export
package require altera_lvds::util::hwtcl_utils  
package require altera_iopll_common::iopll

namespace eval ::altera_lvds::core_14::main:: {
   
   namespace import ::altera_emif::util::messaging::* 
   namespace import ::altera_lvds::top::export::*
   namespace import ::altera_lvds::util::hwtcl_utils::*
   namespace import ::altera_emif::util::hwtcl_utils::generate_top_level_sv_wrapper
   namespace import ::altera_emif::util::hwtcl_utils::get_file_type
   namespace import ::altera_emif::util::messaging::*
   namespace import ::altera_iopll_common::iopll::*
	
   
   variable top_level_mod_name "altera_lvds_core14"
}



proc ::altera_lvds::core_14::main::create_parameters {} {

   ::altera_iopll_common::iopll::init
     
    ::altera_lvds::top::export::inherit_top_level_parameter_defs
    
    set_parameter_property  SYS_INFO_DEVICE AFFECTS_ELABORATION true
    
    

    set_parameter_property J_FACTOR                         HDL_PARAMETER true
    set_parameter_property NUM_CHANNELS                     HDL_PARAMETER true
    set_parameter_property RX_BITSLIP_ROLLOVER              HDL_PARAMETER true
    set_parameter_property TX_REGISTER_CLOCK                HDL_PARAMETER true
    set_parameter_property TX_OUTCLOCK_NON_STD_PHASE_SHIFT  HDL_PARAMETER true
    
    set_parameter_property  TX_OUTCLOCK_NON_STD_PHASE_SHIFT     AFFECTS_ELABORATION true
    
    add_derived_hdl_param   SERDES_DPA_MODE                     string              "tx_mode" 
    add_derived_hdl_param   TX_OUTCLOCK_ENABLED                 string              "false"
    add_derived_hdl_param   TX_OUTCLOCK_DIV_WORD                integer             0               10 
    add_derived_hdl_param   TX_OUTCLOCK_BYPASS_SERIALIZER       string              "false"
    add_derived_hdl_param   TX_OUTCLOCK_USE_FALLING_CLOCK_EDGE  string              "false"
    
    add_derived_hdl_param   EXTERNAL_PLL                        string              "false"
    add_derived_hdl_param   ALIGN_TO_RISING_EDGE_ONLY           string              "false"
    add_derived_hdl_param   LOSE_LOCK_ON_ONE_CHANGE             string              "false"
    add_derived_hdl_param   USE_BITSLIP                         string              "false"
    add_derived_hdl_param   VCO_DIV_EXPONENT                    integer             0
    add_derived_hdl_param   VCO_FREQUENCY                       integer             0
    add_derived_hdl_param   LOOPBACK_MODE                       integer             0
    add_derived_hdl_param   SILICON_REV                         string              "14nm5"
   
    ::altera_iopll_common::iopll::declare_pll_physical_parameters
    
    return 1
}

proc ::altera_lvds::core_14::main::elaboration_callback {} {

	
   ::altera_iopll_common::iopll::init	

    set data_width [get_parameter_value J_FACTOR]
    set lvds_interface_width [get_parameter_value NUM_CHANNELS]
    set parallel_interface_width [expr $data_width*$lvds_interface_width]
    set mode [get_parameter_value MODE]


	::altera_iopll_common::iopll::set_physical_parameter_values "true"
    _set_derived_hdl_parameters


    _create_all_interfaces_disabled
    
    if {![param_string_compare USE_EXTERNAL_PLL "true"] || 
        [string_compare $mode "TX"] && [param_string_compare TX_REGISTER_CLOCK "inclock"]} {
        set_interface_property inclock_conduit_end ENABLED true
    } else {
        set_interface_property inclock_conduit_end ENABLED false
    }

    if {[param_string_compare PLL_USE_RESET "true"]} {
        set_interface_property pll_areset_conduit_end ENABLED true
    }    
        
    if {[string_compare $mode "TX"]} { 
    
        _elaborate_tx_interfaces
    
    } else {    
   
        _elaborate_common_rx_interfaces 
    
       if {[string_compare $mode "RX_DPA-FIFO"] || [string_compare $mode "RX_Soft-CDR"]} {   
        
            if {[param_string_compare RX_DPA_LOCKED_USED "true"] } {
                set_interface_property rx_dpa_locked_conduit_end ENABLED true 
            }
            
            if {[param_string_compare RX_DPA_USE_HOLD "true"] } {
                set_interface_property rx_dpa_hold_conduit_end ENABLED true
            }
            
            if {[param_string_compare RX_DPA_USE_RESET "true"] } {
                set_interface_property rx_dpa_reset_conduit_end ENABLED true
            }    

        } 
        
        if {[string_compare $mode "RX_DPA-FIFO"]} {
            
            if {[param_string_compare RX_FIFO_USE_RESET "true"] } {
                set_interface_property rx_fifo_reset_conduit_end ENABLED true
            }
             
        } elseif {[string_compare $mode "RX_Soft-CDR"]} {
            set_interface_property rx_divfwdclk_conduit_end ENABLED true
        }                                             
    } 

    if {[param_string_compare USE_EXTERNAL_PLL "true"]} {
        _elaborate_external_pll_interfaces
    }
    
    if {[::altera_emif::util::qini::get_ini_value "altera_lvds_loopback_mode"] != ""} {
        set_interface_property loopback_in_conduit_end ENABLED true
        set_interface_property loopback_out_conduit_end  ENABLED true
    }
	
    ::altera_iopll_common::iopll::declare_pll_interfaces
    if {[param_string_compare PLL_EXPORT_LOCK "true"] 
        && [param_string_compare USE_EXTERNAL_PLL "false"] 
        && [param_string_compare USE_CLOCK_PIN "false"] } {
        
        ::altera_iopll_common::iopll::enable_pll_locked_port
    }
		
    _update_qip

    return 1
}

proc ::altera_lvds::core_14::main::_update_qip {} {
    set qip_strings [list ]
    
    set set_inst_asgmnt "set_instance_assignment -entity \"%entityName%\" -library \"%libraryName%\""

    lappend qip_strings "${set_inst_asgmnt} -name MESSAGE_DISABLE 10034"
    lappend qip_strings "${set_inst_asgmnt} -name MESSAGE_DISABLE 10230"
    

    set mode [get_parameter_value MODE]
    set tx_register_clock [get_parameter_value TX_REGISTER_CLOCK]

    set coreclock_idx 2
    
    if {[string equal $mode "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
        set coreclock_idx 4
    }
    
    if {[param_string_compare USE_EXTERNAL_PLL "false"]} {
        if {![string equal $mode "RX_Soft-CDR"]} {
            if {[param_string_compare PLL_CORECLOCK_RESOURCE "Global"]} {
                if {[string equal $mode "RX_DPA-FIFO"] || [string equal $mode "RX_Non-DPA"]} {
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 15 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 15 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 15 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 15 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[1\]\""
                } elseif {[string equal $mode "TX"] && [string equal $tx_register_clock "tx_coreclock"]} {
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 23 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 10 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 10 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 10 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_C_COUNTER_DELAY_CHAIN 10 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[1\]\""
                }
            } elseif {[param_string_compare PLL_CORECLOCK_RESOURCE "Periphery"]}  {
                if {[string equal $mode "TX"] && [string equal $tx_register_clock "tx_coreclock"]} {
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 12 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 12 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[0\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 12 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|loaden\[1\]\""
                    lappend qip_strings "${set_inst_asgmnt} -name PLL_LVDS_DELAY_CHAIN 12 -to \"altera_lvds_core14:arch_inst|altera_iopll:internal_pll.pll_inst|lvds_clk\[1\]\""
                }
            }
        }
    }
    
    set_qip_strings $qip_strings
}

proc ::altera_lvds::core_14::main::sim_vhdl_fileset_callback {top_level} {
    variable top_level_mod_name
    ::altera_lvds::util::hwtcl_utils::generate_vhdl_sim $top_level $top_level_mod_name [list altera_lvds_core14.sv]
}

proc ::altera_lvds::core_14::main::sim_verilog_fileset_callback {top_level} {
    variable top_level_mod_name
    set rtl_only 0
    set encrypted 0
    
    ::altera_lvds::core_14::main::_add_common_files_to_fileset $top_level $top_level_mod_name $rtl_only $encrypted
}


proc ::altera_lvds::core_14::main::quartus_synth_fileset_callback {top_level} {
    variable top_level_mod_name
    set rtl_only 0
    set encrypted 0

    ::altera_lvds::core_14::main::_add_common_files_to_fileset $top_level $top_level_mod_name $rtl_only $encrypted

    source altera_lvds_sdc.tcl

    if {[param_string_compare GENERATE_SDC_FILE "true"]} {
        add_fileset_file ${top_level}.sdc SDC TEXT [generate_sdc_file $top_level]
        add_fileset_file sdc_util.tcl OTHER PATH sdc_util.tcl
    }
 
}

proc ::altera_lvds::core_14::main::get_wysiwyg_silicon_rev_string {} {
   set device [get_parameter_value SYS_INFO_DEVICE]
   emif_dbg 2 "Selected device at core: $device"
   
   return "14nm5"
   
   if {[regexp -lineanchor -nocase {^10A[XST]016} $device] || [regexp -lineanchor -nocase {^10A[XST]022} $device]} {
	   set retval "20nm1"
   } elseif {[regexp -lineanchor -nocase {^10A[XST]027} $device] || [regexp -lineanchor -nocase {^10A[XST]032} $device]} {
	   set retval "20nm2"
   } elseif {[regexp -lineanchor -nocase {^10A[XST]048} $device]} {
	   set retval "20nm3"
   } elseif {[regexp -lineanchor -nocase {^10A[XST]057} $device] || [regexp -lineanchor -nocase {^10A[XST]066} $device]} {
	   set retval "20nm4"
   } else {
      set retval "20nm5"
   }
   
   if {[regexp -lineanchor -nocase {ES$} $device]} {
      set retval "${retval}es"
   } elseif {[regexp -lineanchor -nocase {ES2$} $device]} {
      set retval "${retval}es2"
   }
   
   emif_dbg 2 "Selected SILICON_REV = $retval"
   return $retval
}


proc ::altera_lvds::core_14::main::_create_all_interfaces_disabled {} {
    set data_width [get_parameter_value J_FACTOR]
    set lvds_interface_width [get_parameter_value NUM_CHANNELS]
    set parallel_interface_width [expr $data_width*$lvds_interface_width]
    set mode [get_parameter_value MODE]
    set use_bitslip [param_string_compare RX_USE_BITSLIP "true"]
    
    add_if tx_in conduit end INPUT $parallel_interface_width
    add_if tx_out conduit end OUTPUT $lvds_interface_width    
    add_if tx_outclock conduit end OUTPUT
    add_if tx_coreclock conduit end OUTPUT
    add_if rx_in conduit end Input $lvds_interface_width 
    add_if rx_out conduit end OUTPUT $parallel_interface_width 
    add_if rx_bitslip_reset conduit end INPUT $lvds_interface_width
    add_if rx_bitslip_ctrl conduit end INPUT $lvds_interface_width
    add_if rx_bitslip_max conduit end OUTPUT $lvds_interface_width
    add_if rx_coreclock conduit end OUTPUT 
    add_if ext_fclk conduit end INPUT
    add_if ext_loaden conduit end INPUT
    add_if ext_coreclock conduit end INPUT
    add_if ext_tx_outclock_fclk conduit end INPUT
    add_if ext_tx_outclock_loaden conduit end INPUT
    add_if ext_vcoph conduit end INPUT 8 
    add_if ext_pll_locked conduit end INPUT
    add_if inclock conduit end Input
    add_if pll_areset conduit end INPUT
    add_if rx_dpa_locked conduit end OUTPUT $lvds_interface_width
    add_if rx_dpa_hold conduit end INPUT $lvds_interface_width
    add_if rx_dpa_reset conduit end INPUT $lvds_interface_width
    add_if rx_fifo_reset conduit end INPUT $lvds_interface_width
    add_if rx_divfwdclk conduit end OUTPUT $lvds_interface_width 
    add_if loopback_in conduit end INPUT $lvds_interface_width 
    add_if loopback_out conduit end OUTPUT $lvds_interface_width 
}

proc ::altera_lvds::core_14::main::_elaborate_tx_interfaces {} {

    set_interface_property tx_in_conduit_end ENABLED true
    
    set_interface_property tx_out_conduit_end ENABLED true
    
    if { [param_string_compare TX_USE_OUTCLOCK "true"] } {
        set_interface_property tx_outclock_conduit_end ENABLED true
    }

    if { [param_string_compare TX_EXPORT_CORECLOCK "true"] } {
        set_interface_property tx_coreclock_conduit_end ENABLED true
    }    
}

proc ::altera_lvds::core_14::main::_elaborate_common_rx_interfaces {} {

    set data_width [get_parameter_value J_FACTOR]
    set lvds_interface_width [get_parameter_value NUM_CHANNELS]
    set parallel_interface_width [expr $data_width*$lvds_interface_width]
    set mode [get_parameter_value MODE]
    set use_bitslip [param_string_compare RX_USE_BITSLIP "true"]

    set_interface_property rx_in_conduit_end ENABLED true
    
    set_interface_property rx_out_conduit_end ENABLED true
    
    if { [param_string_compare RX_BITSLIP_USE_RESET "true"] && $use_bitslip } {
        set_interface_property rx_bitslip_reset_conduit_end ENABLED true
    }

    if { $use_bitslip } {
        set_interface_property rx_bitslip_ctrl_conduit_end ENABLED true
    }

    if { $use_bitslip && [param_string_compare RX_BITSLIP_ASSERT_MAX "true"] } {
        set_interface_property rx_bitslip_max_conduit_end ENABLED true
    }
   
    if {[param_string_compare USE_EXTERNAL_PLL "false"]} {
        set_interface_property rx_coreclock_conduit_end ENABLED true
    } 

}

proc ::altera_lvds::core_14::main::_elaborate_external_pll_interfaces {} {

    set mode [get_parameter_value MODE]

    if {![string_compare $mode "RX_Soft-CDR"]} {
        set_interface_property ext_fclk_conduit_end ENABLED true
        set_interface_property ext_loaden_conduit_end ENABLED true
        set_interface_property ext_coreclock_conduit_end ENABLED true
    } else {
        set_interface_property ext_fclk_conduit_end ENABLED true
        set_interface_property ext_coreclock_conduit_end ENABLED true
    }
    
    if {[string_compare $mode "RX_Soft-CDR"] || [string_compare $mode "RX_DPA-FIFO"]} {
        set_interface_property ext_vcoph_conduit_end ENABLED true
        set_interface_property ext_pll_locked_conduit_end ENABLED true
    }
    
    if {[param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
        set_interface_property ext_tx_outclock_fclk_conduit_end ENABLED true
        set_interface_property ext_tx_outclock_loaden_conduit_end ENABLED true
    }
}


proc ::altera_lvds::core_14::main::_set_derived_hdl_parameters {} {
    
    set mode [get_parameter_value MODE]
    set data_width [get_parameter_value J_FACTOR]
    set rate [get_parameter_value DATA_RATE]

    if {[string_compare $mode "TX"] } {
        set_parameter_value SERDES_DPA_MODE "tx_mode"
        _set_derived_tx_hdl_parameters
    } elseif {[string_compare $mode "RX_DPA-FIFO"] } {
        set_parameter_value SERDES_DPA_MODE "dpa_mode_fifo"
    } elseif {[string_compare $mode "RX_Soft-CDR"] } {
        set_parameter_value SERDES_DPA_MODE "dpa_mode_cdr"
    } else {
        set_parameter_value SERDES_DPA_MODE "non_dpa_mode"
    }    
    
    
    if {[get_parameter_value USE_EXTERNAL_PLL]} {
        set_parameter_value EXTERNAL_PLL "true"
    } else {
        set_parameter_value EXTERNAL_PLL "false"
    }
    
    if {[get_parameter_value RX_DPA_ALIGN_TO_RISING_EDGE_ONLY]} {
        set_parameter_value ALIGN_TO_RISING_EDGE_ONLY "true"
    } else {
        set_parameter_value ALIGN_TO_RISING_EDGE_ONLY "false"
    }
    
    if {[get_parameter_value RX_DPA_LOSE_LOCK_ON_ONE_CHANGE]} {
        set_parameter_value LOSE_LOCK_ON_ONE_CHANGE "true"
    } else {
        set_parameter_value LOSE_LOCK_ON_ONE_CHANGE "false"
    }
    
    if {[::altera_emif::util::qini::get_ini_value "altera_lvds_loopback_mode"] != ""} {
        set_parameter_value LOOPBACK_MODE [::altera_emif::util::qini::get_ini_value "altera_lvds_loopback_mode"]
    } else {
        set_parameter_value LOOPBACK_MODE 0
    }

    set_parameter_value SILICON_REV [get_wysiwyg_silicon_rev_string]
    
    set vco_frequency [param_strip_units pll_vco_frequency]
    set_parameter_value VCO_FREQUENCY $vco_frequency
    
    set division_factor [expr {round($vco_frequency/$rate)}]
    if {$division_factor == 1} {
        set_parameter_value VCO_DIV_EXPONENT 0
    } elseif {$division_factor == 2} {
        set_parameter_value VCO_DIV_EXPONENT 1
    } elseif {$division_factor == 4} {
        set_parameter_value VCO_DIV_EXPONENT 2
    } elseif {$division_factor == 8} {
        set_parameter_value VCO_DIV_EXPONENT 3
    } else {
        send_message error "Unexpected VCO_DIV_EXPONENT"
    }
    
    if {[get_parameter_value RX_USE_BITSLIP]} {
        set_parameter_value USE_BITSLIP "true"
    } else {
        set_parameter_value USE_BITSLIP "false"
    }
}



proc ::altera_lvds::core_14::main::_set_derived_tx_hdl_parameters {} {
    
    set mode [get_parameter_value MODE]
    set data_width [get_parameter_value J_FACTOR]
    set outclock_div [get_parameter_value TX_OUTCLOCK_DIVISION]
    set outclock_div_word 0
    set outclock_shift_deg [get_parameter_value TX_OUTCLOCK_PHASE_SHIFT]
    set is_non_std_shift [get_parameter_value TX_OUTCLOCK_NON_STD_PHASE_SHIFT]

    
    if { $data_width == 10 } {
        if {$outclock_div == 10} {
             set outclock_div_word 31  
         } elseif { $outclock_div == 2 } {
             set outclock_div_word 341
         }
     } elseif { $data_width == 9 } {
         if {$outclock_div == 9} {
             set outclock_div_word 31
         }    
     } elseif { $data_width == 8 } {
         if {$outclock_div == 8} {
             set outclock_div_word 15
         } elseif {$outclock_div == 4} {
             set outclock_div_word 51
         } elseif {$outclock_div == 2} {
             set outclock_div_word 85
         }    
     } elseif { $data_width == 7 } {
         if {$outclock_div == 7} {
             set outclock_div_word 15
         }    
     } elseif { $data_width ==  6 } {
         if {$outclock_div == 6} {
             set outclock_div_word 7
         } elseif {$outclock_div == 2} {
             set outclock_div_word 21
         }
     } elseif { $data_width ==  5 } {
         if {$outclock_div == 5} {
             set outclock_div_word 7
         }
    } elseif { $data_width ==  4 } {
         if {$outclock_div == 4} {
             set outclock_div_word 3 
         } elseif {$outclock_div == 2} {
             set outclock_div_word 5
         }
    } elseif { $data_width ==  3 } {
         if {$outclock_div == 3} {
             set outclock_div_word 3
        }
    }
    
    if { [param_string_compare TX_USE_OUTCLOCK "true"] } {
        set_parameter_value TX_OUTCLOCK_ENABLED "true"
    } else {
        set_parameter_value TX_OUTCLOCK_ENABLED "false"
    }
    
    if { [string_compare $is_non_std_shift "false"] } {

        set rotated_outclock_div_word [bit_rotate $outclock_div_word $data_width [expr {$outclock_shift_deg/360}]]
                                            
        set_parameter_value TX_OUTCLOCK_DIV_WORD $rotated_outclock_div_word 

        if {$outclock_div == 1} {    
            set_parameter_value TX_OUTCLOCK_BYPASS_SERIALIZER "true"
        } else {
            set_parameter_value TX_OUTCLOCK_BYPASS_SERIALIZER "false"
            }
     
         if {[expr {$outclock_shift_deg/180 % 2}] == 1} {
             set_parameter_value TX_OUTCLOCK_USE_FALLING_CLOCK_EDGE "true" 
         } else {
             set_parameter_value TX_OUTCLOCK_USE_FALLING_CLOCK_EDGE "false"
         }    

     } else { 
        set_parameter_value TX_OUTCLOCK_BYPASS_SERIALIZER "false"
        set_parameter_value TX_OUTCLOCK_DIV_WORD $outclock_div_word 
        set_parameter_value TX_OUTCLOCK_USE_FALLING_CLOCK_EDGE "false" 
    }

}

proc ::altera_lvds::core_14::main::_add_common_files_to_fileset {top_level top_level_mod_name rtl_only encrypted} {

    set file_paths [concat [::altera_emif::util::hwtcl_utils::generate_top_level_sv_wrapper $top_level $top_level_mod_name] \
                           altera_lvds_core14.sv ]
    
    lappend file_paths ../../primitives/altera_std_synchronizer/altera_std_synchronizer_nocut.v 
    lappend file_paths ../../altera_iopll/wrappers/stratix10_altera_iopll.v

    foreach file_path $file_paths {
        set tmp [file split $file_path]
        set file_name [lindex $tmp end]
        add_fileset_file $file_name [::altera_emif::util::hwtcl_utils::get_file_type $file_name $rtl_only $encrypted] PATH $file_path
    }
}

proc ::altera_lvds::core_14::main::_init {} {
}

::altera_lvds::core_14::main::_init
