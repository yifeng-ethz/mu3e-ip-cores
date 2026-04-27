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


package require altera_lvds::util::hwtcl_utils

proc generate_header { } {
	set sdc_content ""

   append sdc_content {

#####################################################################
#
# THIS IS AN AUTO-GENERATED FILE!
# -------------------------------
# If you modify this files, all your changes will be lost if you
# regenerate the core!
#
# FILE DESCRIPTION
# ----------------
# This file specifies the timing constraints for the Altera LVDS interface
} \n

   return $sdc_content
}

proc generate_sourcing {} {
   set sdc_content ""

   append sdc_content {
# Source helper script 
set script_dir [file dirname [info script]]
source "$script_dir/sdc_util.tcl"

set syn_flow 0
set sta_flow 0
set fit_flow 0
if { $::TimeQuestInfo(nameofexecutable) == "quartus_syn" } {
   set syn_flow 1
} elseif { $::TimeQuestInfo(nameofexecutable) == "quartus_sta" } {
   set sta_flow 1
} elseif { $::TimeQuestInfo(nameofexecutable) == "quartus_fit" } {
   set fit_flow 1
}

} \n
   return $sdc_content
}

proc generate_modifiable_variables { top_level } {
   set sdc_content ""

   append sdc_content {
##########################################################################################
# Modifiable user variables
# Change these values to match your design.
##########################################################################################

set ::RCCS 0.0

##########################################################################################
# The following functions are to find out all the instances and the corresponding PLL 
# refclk.  If you see an critical warning, modify to match your design.
##########################################################################################

}


   append sdc_content "set libname $top_level \n"
   append sdc_content "set corename altera_lvds_core14 \n"
   append sdc_content "\n"
   append sdc_content "set catch_exception \[catch { \n"
   append sdc_content "   set lvds_instance_name_list \[altera_iosubsystem_get_ip_instance_names \$libname \$corename\]\n "
   append sdc_content "} \]\n "
   append sdc_content "\n "
   append sdc_content "if {\$catch_exception != 0} {\n "
   append sdc_content "   post_message -type critical_warning \"Errors encountered when searching for LVDS instance name and ref clock pin names.  Please override variables lvds_instance_name_list and rerun read_sdc\"\n "
   append sdc_content "   return \n "
   append sdc_content "}\n "

   append sdc_content {
##########################################################################################
# Derived user variables
##########################################################################################

set half_RCCS [expr $::RCCS / 2]

}

   return $sdc_content
}

proc generate_forloop {} {

   set m_cnt [calculate_counter_value [get_parameter_value m_cnt_hi_div] [get_parameter_value m_cnt_lo_div] [get_parameter_value m_cnt_bypass_en]]
   set n_cnt [calculate_counter_value [get_parameter_value n_cnt_hi_div] [get_parameter_value n_cnt_lo_div] [get_parameter_value n_cnt_bypass_en]]
   for {set i 0} {$i < 9} {incr i} {
      set c${i}_cnt [calculate_counter_value [get_parameter_value c_cnt_hi_div${i}] [get_parameter_value c_cnt_lo_div${i}] [get_parameter_value c_cnt_bypass_en${i}]]
   }

   append sdc_content "###########################################################\n"
   append sdc_content "# IP parameters\n"
   append sdc_content "###########################################################\n"

   append sdc_content {
   
# Throw error only at TimeQuest but critical warning in Fitter\n"
if {$fit_flow} {
   set msg_error_type "critical_warning"
} else {
   set msg_error_type "error"
}

}
   if {[param_string_compare MODE "TX"]} {
      append sdc_content "set OC_C2P_SU  0.1\n"
      append sdc_content "set OC_C2P_H   0.1\n"
   } else {
      append sdc_content "set OC_C2P_SU 0.0\n"
      append sdc_content "set OC_C2P_H  0.0\n"
   }

   if {[param_string_compare MODE "RX_Soft-CDR"]} {
      append sdc_content "set OC_P2C_SU 0.0\n"
      append sdc_content "set OC_P2C_H  0.0\n"
   } else {
      append sdc_content "set OC_P2C_SU 0.0\n"
      append sdc_content "set OC_P2C_H  0.0\n"
   }

   append sdc_content "set use_external_pll [param_string_compare USE_EXTERNAL_PLL "true"]\n"

   set j_factor [get_parameter_value J_FACTOR]
   append sdc_content "set j_factor $j_factor \n"
   append sdc_content "set odd_jfactor [expr $j_factor % 2] \n"

   set ref_clock_mhz [::altera_lvds::util::hwtcl_utils::strip_units [get_parameter_value pll_inclock_frequency]]
   set ref_clock_ps [::altera_lvds::util::hwtcl_utils::freq_to_period $ref_clock_mhz]
   set ref_clock_ns [expr $ref_clock_ps / 1000.0]
   append sdc_content "set ref_clock_period_ns $ref_clock_ns \n"

   append sdc_content "set ncntr_setting $n_cnt \n"
   
   set fast_clock_mhz [get_parameter_value DATA_RATE]
   set fast_clock_ps [::altera_lvds::util::hwtcl_utils::freq_to_period $fast_clock_mhz]
   set fast_clock_ns [expr $fast_clock_ps / 1000.0]
   set slow_clock_ns [expr $fast_clock_ns * $j_factor]

   append sdc_content "set slow_clock_period_ns $slow_clock_ns \n"
   append sdc_content "set fast_clock_period_ns $fast_clock_ns \n"

   set loaden_clock_mhz [lindex [get_parameter_value pll_loaden_frequency] 0]
   set fclk_clock_mhz [lindex [get_parameter_value pll_fclk_frequency] 0]
   set sclk_clock_mhz [lindex [get_parameter_value pll_sclk_frequency] 0]

   append sdc_content "set sclk_multiply_by $m_cnt \n"
   append sdc_content "set sclk_divide_by [expr $n_cnt * $c1_cnt] \n"
   set sclk_phase_ns [expr [lindex [get_parameter_value pll_sclk_phase_shift] 0] / 1000.0]
   append sdc_content "set sclk_phase [expr round($sclk_phase_ns / $slow_clock_ns * 36000.0)/100.0 ] \n"

   append sdc_content "set fclk_multiply_by $m_cnt \n"
   append sdc_content "set fclk_divide_by [expr $n_cnt * $c0_cnt] \n"
   set fclk_phase_ns [expr [lindex [get_parameter_value pll_fclk_phase_shift] 0] / 1000.0]
   append sdc_content "set fclk_phase [expr round($fclk_phase_ns / $fast_clock_ns * 360.0) ] \n"

   append sdc_content "set loaden_multiply_by $m_cnt \n"
   append sdc_content "set loaden_divide_by [expr $n_cnt * $c1_cnt] \n"
   set loaden_phase_ns [expr [lindex [get_parameter_value pll_loaden_phase_shift] 0] / 1000.0]
   append sdc_content "set loaden_phase [expr round($loaden_phase_ns / $slow_clock_ns * 36000.0)/100.0 ] \n"
   append sdc_content "set loaden_duty [expr round(10000.0 / $j_factor)/100.0] \n"

   if {[param_string_compare TX_USE_OUTCLOCK "true"]} {
      set tx_outclock_loaden_clock_mhz [lindex [get_parameter_value pll_tx_outclock_loaden_frequency] 0]
      set tx_outclock_fclk_clock_mhz [lindex [get_parameter_value pll_tx_outclock_fclk_frequency] 0]

      append sdc_content "set tx_outclock_fclk_multiply_by $m_cnt \n"
      append sdc_content "set tx_outclock_fclk_divide_by [expr $n_cnt * $c2_cnt] \n"
      set tx_outclock_fclk_phase_ns [expr [lindex [get_parameter_value pll_tx_outclock_fclk_phase_shift] 0] / 1000.0]
      append sdc_content "set tx_outclock_fclk_phase [expr round($tx_outclock_fclk_phase_ns / $fast_clock_ns * 360.0) ] \n"

      append sdc_content "set tx_outclock_loaden_multiply_by $m_cnt \n"
      append sdc_content "set tx_outclock_loaden_divide_by [expr $n_cnt * $c3_cnt] \n"
      set tx_outclock_loaden_phase_ns [expr [lindex [get_parameter_value pll_tx_outclock_loaden_phase_shift] 0] / 1000.0]
      append sdc_content "set tx_outclock_loaden_phase [expr round($tx_outclock_loaden_phase_ns / $slow_clock_ns * 36000.0)/100.0 ] \n"
      append sdc_content "set tx_outclock_loaden_duty [expr round(10000.0 / $j_factor)/100.0] \n"
   }

   if {[get_parameter_value gui_enable_advanced_mode]} {
      set pll_maximum_number_of_reserved_clocks 5
      set num_extra_clocks [get_parameter_value gui_number_of_pll_output_clocks]
      set max_clocks [expr {$pll_maximum_number_of_reserved_clocks + $num_extra_clocks}]
      for { set i $pll_maximum_number_of_reserved_clocks } {$i < $max_clocks} {incr i} {
         set output_freq [get_parameter_value gui_actual_outclk_frequency_$i]
         set output_freq [format "%.6f" $output_freq]
         
         set phase_shift_ps [get_parameter_value gui_outclk_actual_phase_shift_ps_$i]
         set phase_shift_ps [expr {round($phase_shift_ps)}]
         
         set phase_shift_deg [lindex [::altera_iopll_common::iopll::ps_to_degrees $phase_shift_ps $output_freq] 0]
         regexp {([-0-9.]+)} $phase_shift_deg phase_shift_deg 
         set phase_shift_deg [expr {round($phase_shift_deg)}]
         
         set duty_cycle [get_parameter_value gui_actual_outclk_duty_cycle_$i]
         set duty_cycle [format "%.2f" $duty_cycle]
         
         append sdc_content "set c${i}_phase_degree $phase_shift_deg\n"
         append sdc_content "set c${i}_duty_cycle $duty_cycle\n"
         append sdc_content "set c${i}_multiply_by $m_cnt\n"
         append sdc_content "set c${i}_divide_by [eval "expr \$n_cnt * \$c${i}_cnt"]\n"
      }
   }
 


   append sdc_content "\n# Iterate through all instances of this IP \n"
   append sdc_content "foreach lvds_instance_name \$lvds_instance_name_list {  \n"
   append sdc_content {

   set core_clocks [list]
   set periphery_clocks [list]

   set lvds_core_instance_name "${lvds_instance_name}|arch_inst" 
   regexp {([0-9_A-Za-z]+)|} $lvds_instance_name -> lvds_top_level_name

   ###########################################################################################
   # Create Common Clocks, Periods, and Delays
   ###########################################################################################

   } \n

   append sdc_content [generate_clocks]
   append sdc_content [generate_multicycle_and_synchronzier]
   append sdc_content [generate_set_input_delay]
   append sdc_content [generate_set_false_path_for_tx]
   append sdc_content [generate_cut_path_for_internal_synchronizer]
   append sdc_content [generate_clock_uncertainty]


   append sdc_content "} \n"

   return $sdc_content
}

proc generate_rx_fwd_clock { } {
	set sdc_content ""

	append sdc_content "create_clock -name \$core_ck_name -period \$slow_clock_period_ns \${lvds_instance_name}|channels\[0\].soft_cdr.serdes_dpa_inst~O_PCLK \n"
	append sdc_content "lappend core_clocks \$core_ck_name\n"
	append sdc_content "\n"

	return $sdc_content
}

proc generate_rx_data_output_constraints { } {
	set sdc_content ""

	append sdc_content "set_output_delay -add_delay  -clock \$core_ck_name  \$board_delay dut_rx_out_export\[*\] \n"
	append sdc_content "\n"

	return $sdc_content
}

proc generate_tx_data_input_constraints { } {
	set sdc_content ""

	append sdc_content "set_input_delay -add_delay  -clock \$core_ck_name  \$board_delay dut_tx_in_export\[*\] \n"
	append sdc_content "\n"

	return $sdc_content
}

proc generate_tx_data_output_constraints { } {
	set sdc_content ""

	append sdc_content "set_output_delay -clock \$fast_ck_name 0 dut_tx_out_export*\n"
	append sdc_content "\n"

	return $sdc_content
}

proc generate_rx_bitslip_constraints { } {
	set sdc_content ""

	append sdc_content "set_input_delay -add_delay  -clock \$core_ck_name  \$board_delay \[get_ports {dut_rx_bitslip_ctrl_export\[*\]}\] \n"
	append sdc_content "\n"

	return $sdc_content
}

proc cut_paths {} {
	set sdc_content ""

    if {[param_string_compare MODE "RX_Non-DPA"]} {
        set lvds_if_name "rx_non_dpa"
    } elseif {[param_string_compare MODE "RX_DPA-FIFO"]} {
        set lvds_if_name "dpa_fifo"
    } elseif {[param_string_compare MODE "RX_Soft-CDR"]} {
        set lvds_if_name "soft_cdr"
    } elseif {[param_string_compare MODE "TX"]} {
        set lvds_if_name "tx"
    }
	    
    append sdc_content "   ##########################################################################################\n"
    append sdc_content "   # Core to Periphery timing is preliminary. Cutting C2P and P2C paths from reports\n"
    append sdc_content "   ##########################################################################################\n"
    #Cut all paths to and from serdes_dpa
    append sdc_content "   if {\$sta_flow} {\n"
    append sdc_content "      set_false_path -to \$lvds_core_instance_name|channels\[*\].$lvds_if_name.serdes_dpa_inst*\n"
    append sdc_content "      set_false_path -from \$lvds_core_instance_name|channels\[*\].$lvds_if_name.serdes_dpa_inst*\n"
    append sdc_content "   }\n"
    
	return $sdc_content
}

proc generate_clocks {} {
	set sdc_content ""


   if {[param_string_compare MODE "TX"] || [param_string_compare MODE "RX_Non-DPA"] || [param_string_compare MODE "RX_DPA-FIFO"]} {
      append sdc_content {
   set lvds_clock_tree_inst_name "${lvds_core_instance_name}|default_lvds_clock_tree.lvds_clock_tree_inst"

   set pll_fclk_tree_name "${lvds_clock_tree_inst_name}|lvdsfclk_in"
   if {[catch {get_node_info -name [get_edge_info -src [get_node_info -clock_edges $pll_fclk_tree_name]]} pll_fclk_name] != 0} {
      set pll_fclk_name $pll_fclk_tree_name
      if {$use_external_pll} {
      } else {
      }
   }
   set pll_lden_tree_name "${lvds_clock_tree_inst_name}|loaden_in"
   if {[catch { get_node_info -name [get_edge_info -src [get_node_info -clock_edges $pll_lden_tree_name]] } pll_lden_name ] != 0} {
      set pll_lden_name $pll_lden_tree_name
   }         

   if {[catch {
      set pll_instance_name [get_cell_info -name [get_node_info -cell $pll_fclk_name]]
      set pll_ref_ck_name "${pll_instance_name}|refclk[0]"
      set ref_ck_port_id [altera_iosubsystem_get_input_clk_id [get_nodes $pll_ref_ck_name]]
      set ref_ck_pin [get_port_info -name $ref_ck_port_id]
   }]} {
      set pll_fclk_name ""
      set pll_lden_name ""
      set pll_ref_ck_name ""
      set ref_ck_pin ""
   }
   if {$ncntr_setting == 1} {
      set ncntr_bypass 1
      set ccntr_src $pll_ref_ck_name
   } else {
      set ncntr_bypass 0
      set ccntr_src ${pll_instance_name}~ncntr_reg
   }
   
   if {$ref_ck_pin != ""} { 
      if {!$use_external_pll} {
         if {[altera_iosubsystem_get_clock_name_from_target $ref_ck_pin] == ""} {
            create_clock -name $ref_ck_pin -period $ref_clock_period_ns $ref_ck_pin
         }
         if {$pll_ref_ck_name != "" && $pll_fclk_name != ""} {
			if {$ncntr_bypass != 1} {
				altera_iosubsystem_create_generated_clock -source "$pll_ref_ck_name" -divide_by $ncntr_setting -duty_cycle 50.00 -name ${pll_instance_name}~ncntr_reg -target ${pll_instance_name}~ncntr_reg
			}
            altera_iosubsystem_create_generated_clock -source "${ccntr_src}" -divide_by $fclk_divide_by -multiply_by [expr $fclk_multiply_by*$ncntr_setting] -phase $fclk_phase -duty_cycle 50.00 -name "$pll_fclk_name" -target "$pll_fclk_name" 
         }
      }
      if {$pll_ref_ck_name != "" && $pll_lden_name != ""} {
         altera_iosubsystem_create_generated_clock -source "${ccntr_src}" -divide_by $loaden_divide_by -multiply_by [expr $loaden_multiply_by*$ncntr_setting] -phase $loaden_phase -duty_cycle $loaden_duty -name "$pll_lden_name" -target "$pll_lden_name" 
      }
   }

   if {$pll_fclk_name != ""} { 
      lappend periphery_clocks $pll_fclk_name
   }
   if {$pll_lden_name != "" } {
      lappend periphery_clocks $pll_lden_name
      if {$sta_flow} {
         set_false_path -from $pll_lden_name
      }
   }


      } \n

      if {[param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
         append sdc_content {
   set tx_outclock_lvds_clock_tree_inst_name "${lvds_core_instance_name}|phase_shifted_tx_outclock_serdes.outclock_tree"

   set pll_tx_outclock_fclk_tree_name "${tx_outclock_lvds_clock_tree_inst_name}|lvdsfclk_in"
   if {[catch {get_node_info -name [get_edge_info -src [get_node_info -clock_edges $pll_tx_outclock_fclk_tree_name]]} pll_tx_outclock_fclk_name] != 0} {
      set pll_tx_outclock_fclk_name $pll_tx_outclock_fclk_tree_name
   }
   set pll_tx_outclock_lden_tree_name "${tx_outclock_lvds_clock_tree_inst_name}|loaden_in"
   if {[catch { get_node_info -name [get_edge_info -src [get_node_info -clock_edges $pll_tx_outclock_lden_tree_name]] } pll_tx_outclock_lden_name ] != 0} {
      set pll_tx_outclock_lden_name $pll_tx_outclock_lden_tree_name
   }         

   if {!$use_external_pll} { altera_iosubsystem_create_generated_clock -source "${pll_ref_ck_name}" -divide_by $tx_outclock_fclk_divide_by -multiply_by $tx_outclock_fclk_multiply_by -phase $tx_outclock_fclk_phase -duty_cycle 50.00 -name "$pll_tx_outclock_fclk_name" -target "$pll_tx_outclock_fclk_name" }
   if {!$use_external_pll} { altera_iosubsystem_create_generated_clock -source "${pll_ref_ck_name}" -divide_by $tx_outclock_loaden_divide_by -multiply_by $tx_outclock_loaden_multiply_by -phase $tx_outclock_loaden_phase -duty_cycle $tx_outclock_loaden_duty -name "$pll_tx_outclock_lden_name" -target "$pll_tx_outclock_lden_name" }
   if {$pll_tx_outclock_fclk_name != ""} {
      lappend periphery_clocks $pll_tx_outclock_fclk_name
   }

   if {$pll_tx_outclock_lden_name != ""} {
      lappend periphery_clocks $pll_tx_outclock_lden_name
      
      if {$sta_flow} {
         set_false_path -from $pll_tx_outclock_lden_name
      }
   }
         } \n
      }

      if {![param_string_compare MODE "TX"] || [param_string_compare TX_REGISTER_CLOCK "tx_coreclock"]} {
         if {[param_string_compare MODE "TX"]} {
            append sdc_content {   if {[catch {set pll_out_pin [get_node_info -name [altera_iosubsystem_get_src_pll_out_pin ${lvds_core_instance_name}|channels[0].tx.tx_reg[0]]]}]} { set pll_out_pin "" } } \n
         } elseif { [param_string_compare MODE "RX_Non-DPA"] } {
            append sdc_content {   if {[catch {set pll_out_pin [get_node_info -name [altera_iosubsystem_get_src_pll_out_pin ${lvds_core_instance_name}|channels[0].rx_non_dpa.rx_reg[0]]]}]} { set pll_out_pin "" } } \n
         } elseif { [param_string_compare MODE "RX_DPA-FIFO"] } {
            append sdc_content {   if {[catch {set pll_out_pin [get_node_info -name [altera_iosubsystem_get_src_pll_out_pin ${lvds_core_instance_name}|channels[0].dpa_fifo.rx_reg[0]]]}]} { set pll_out_pin "" } } \n
         }

         append sdc_content {   if {!$use_external_pll && $pll_ref_ck_name != "" && $pll_out_pin != ""} { altera_iosubsystem_create_generated_clock -source "${ccntr_src}" -divide_by $sclk_divide_by -multiply_by [expr $sclk_multiply_by*$ncntr_setting] -phase $sclk_phase -duty_cycle 50.00 -name "${pll_out_pin}" -target "${pll_out_pin}" } } \n
         append sdc_content {   lappend core_clocks  "${pll_out_pin}" } \n
         if {[get_parameter_value gui_enable_advanced_mode]} {
            set pll_maximum_number_of_reserved_clocks 5
            set num_extra_clocks [get_parameter_value gui_number_of_pll_output_clocks]
            set max_clocks [expr {$pll_maximum_number_of_reserved_clocks + $num_extra_clocks}]
            append sdc_content {
   set pll_out_pin_base [string range $pll_out_pin 0 [expr [string last {[} $pll_out_pin]-1] ] 
         } \n
            for { set i $pll_maximum_number_of_reserved_clocks } {$i < $max_clocks} {incr i} {
               append sdc_content "   altera_iosubsystem_create_generated_clock -source \"\$\{pll_ref_ck_name\}\" -divide_by \$c${i}_divide_by -multiply_by \$c${i}_multiply_by -phase \$c${i}_phase_degree -duty_cycle \$c${i}_duty_cycle -name \"\$\{pll_out_pin_base\}\[$i\]\"  -target \"\$\{pll_out_pin_base\}\[$i\]\" \n"
               append sdc_content "   lappend core_clocks \"\$\{pll_out_pin_base\}\[$i\]\" \n"
            }
         }
      }
      if {[param_string_compare MODE "RX_DPA-FIFO"]} {
         append sdc_content {
         } \n
      }

   } elseif {[param_string_compare MODE "RX_Soft-CDR"]} {
      append sdc_content {
   set lvds_clock_tree_inst_name "${lvds_core_instance_name}|clock_pin_lvds_clock_tree.lvds_clock_tree_inst"
   set pll_fclk_tree_name "${lvds_clock_tree_inst_name}|lvdsfclk_in"
   if {[catch {get_node_info -name [get_edge_info -src [get_node_info -clock_edges $pll_fclk_tree_name]]} pll_fclk_name] != 0} {
      set pll_fclk_name $pll_fclk_tree_name
      if {$use_external_pll} {
      } else {
      }
   }

   if {[catch {
      set pll_instance_name [get_cell_info -name [get_node_info -cell $pll_fclk_name]]
      set pll_ref_ck_name "${pll_instance_name}|refclk[0]"
      set ref_ck_port_id [altera_iosubsystem_get_input_clk_id [get_nodes $pll_ref_ck_name]]
      set ref_ck_pin [get_port_info -name $ref_ck_port_id]
   }]} {
      set pll_fclk_name ""
      set pll_lden_name ""
      set pll_ref_ck_name ""
      set ref_ck_pin ""
   }
 
   if {[catch { get_node_info -name [altera_iosubsystem_get_src_pll_out_pin ${lvds_core_instance_name}|cdr_dummy_flop] } pll_out_pin ]} {
      set pll_out_pin ""
      post_message -type $msg_error_type "SDC cannot find clock source CDR coreclock dummy register."
   }
   if {!$use_external_pll} { 
      if {$ref_ck_pin != ""} {
         if {[altera_iosubsystem_get_clock_name_from_target $ref_ck_pin] == ""} {
            create_clock -name $ref_ck_pin -period $ref_clock_period_ns $ref_ck_pin
         }
         if {$pll_fclk_name != "" } {
            altera_iosubsystem_create_generated_clock -source "${ref_ck_pin}" -divide_by $fclk_divide_by -multiply_by $fclk_multiply_by -phase $fclk_phase -duty_cycle 50.00 -name "$pll_fclk_name" -target "$pll_fclk_name"
         }
         if {$pll_out_pin != ""} {
            altera_iosubsystem_create_generated_clock -source "${ref_ck_pin}" -divide_by $sclk_divide_by -multiply_by $sclk_multiply_by -phase $sclk_phase -duty_cycle 50.00 -name "${pll_out_pin}" -target "${pll_out_pin}"
         }
      }
   }

   lappend core_clocks ${pll_out_pin}
   lappend periphery_clocks $pll_fclk_name   
   
      } \n
      
      if {[get_parameter_value gui_enable_advanced_mode]} {
         set pll_maximum_number_of_reserved_clocks 5
         set num_extra_clocks [get_parameter_value gui_number_of_pll_output_clocks]
         set max_clocks [expr {$pll_maximum_number_of_reserved_clocks + $num_extra_clocks}]
         append sdc_content "if \{!\$use_external_pll && \$pll_out_pin != \"\" \} \{ \n"
         append sdc_content {
   set pll_out_pin_base [string range $pll_out_pin 0 [expr [string last {[} $pll_out_pin]-1] ]
         } \n
         for { set i $pll_maximum_number_of_reserved_clocks } {$i < $max_clocks} {incr i} {
            append sdc_content "   altera_iosubsystem_create_generated_clock -source \"\$\{ref_ck_pin\}\" -divide_by \$c${i}_divide_by -multiply_by \$c${i}_multiply_by -phase \$c${i}_phase_degree -duty_cycle \$c${i}_duty_cycle -name \"\$\{pll_out_pin_base\}\[$i\]\"  -target \"\$\{pll_out_pin_base\}\[$i\]\" \n"
            append sdc_content "   lappend core_clocks \"\$\{pll_out_pin_base\}\[$i\]\" \n"
         }
         append sdc_content "\} \n"
      }
      append sdc_content "   # generate clocks at LVDS data output to capture the proper periphery to core transfer \n"
      append sdc_content "   set num_chan [get_parameter_value NUM_CHANNELS] \n"

      append sdc_content {
   for {set ichan 0} {$ichan < $num_chan} {incr ichan} { 
      if {[catch {get_node_info -name [altera_iosubsystem_get_src_pll_in_pin ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~dpa_reg]} pll_in_pin]} {
         if {$use_external_pll} {
            post_message -type $msg_error_type "SDC cannot find the PLL that drives DPA.  Clock settings of channel $ichan are not created.  Please check your external PLL connectivity is in accordance with the Altera LVDS user guide."
         } else {
            post_message -type $msg_error_type "SDC cannot find the PLL that drives DPA.  Clock settings of channel $ichan are not created.  Please check the PLL to LVDS IP connectivity."
         }
         continue;
      }
      altera_iosubsystem_create_generated_clock -source ${pll_in_pin} -name ${lvds_instance_name}_dpa_ck_name_$ichan -divide_by $fclk_divide_by -multiply_by $fclk_multiply_by  -target ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~dpa_reg 
      lappend periphery_clocks ${lvds_instance_name}_dpa_ck_name_$ichan
      if {$odd_jfactor} {
         altera_iosubsystem_create_generated_clock -source ${pll_in_pin} -name ${lvds_instance_name}_dpa_ck_neg_name_$ichan -divide_by $fclk_divide_by -multiply_by $fclk_multiply_by  -target ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~dpa_reg__nff
         lappend periphery_clocks ${lvds_instance_name}_dpa_ck_neg_name_$ichan
         altera_iosubsystem_create_generated_clock -invert 1 -source ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~dpa_reg__nff -name ${lvds_instance_name}_core_ck_name_$ichan -divide_by $j_factor -target ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~O_PCLK 
      } else {
         altera_iosubsystem_create_generated_clock -invert 1 -source ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~dpa_reg -name ${lvds_instance_name}_core_ck_name_$ichan -divide_by $j_factor -target ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst~O_PCLK 
      }	 
      lappend core_clocks ${lvds_instance_name}_core_ck_name_$ichan
      for {set index 0} {$index < $j_factor} {incr index} { 
         altera_iosubsystem_create_generated_clock -source ${lvds_core_instance_name}|channels[${ichan}].soft_cdr.serdes_dpa_inst~dpa_reg -name ${lvds_instance_name}_dpa_data_out_${ichan}_$index -divide_by $j_factor -target ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst|rxdata[$index]	
         altera_iosubsystem_create_generated_clock -remove_clock 0 -add 1 -invert 1 -source ${lvds_core_instance_name}|channels[${ichan}].soft_cdr.serdes_dpa_inst~dpa_reg -name ${lvds_instance_name}_dpa_data_out_${ichan}_${index}_neg -divide_by $j_factor -target ${lvds_core_instance_name}|channels[$ichan].soft_cdr.serdes_dpa_inst|rxdata[$index]
         lappend periphery_clocks ${lvds_instance_name}_dpa_data_out_${ichan}_$index
         lappend periphery_clocks ${lvds_instance_name}_dpa_data_out_${ichan}_${index}_neg
         set_false_path -fall_from ${lvds_instance_name}_dpa_data_out_${ichan}_$index 
         set_false_path -rise_from ${lvds_instance_name}_dpa_data_out_${ichan}_${index}_neg 
      } 
   } 

      }
   }

   if {[param_string_compare TX_REGISTER_CLOCK "inclock"]} {
      append sdc_content {   lappend core_clocks  "$ref_ck_pin" } \n
   } else {
      append sdc_content {   lappend periphery_clocks  "$ref_ck_pin" } \n
   }
   
   return $sdc_content
}

proc generate_multicycle_and_synchronzier {} {
   set sdc_content ""

   if {[param_string_compare MODE "TX"]} {
      append sdc_content {
   set_multicycle_path -end -from ${lvds_core_instance_name}|channels[*].tx.tx_reg[*] -to ${lvds_core_instance_name}|channels[*].tx.serdes_dpa_inst~tx_internal_reg -setup [expr $j_factor -1]
   set_multicycle_path -end -from ${lvds_core_instance_name}|channels[*].tx.tx_reg[*] -to ${lvds_core_instance_name}|channels[*].tx.serdes_dpa_inst~tx_internal_reg -hold [expr $j_factor -1]

      } \n
   } elseif {[param_string_compare MODE "RX_Non-DPA"]} {
      append sdc_content {
   set_multicycle_path -start -to ${lvds_core_instance_name}|channels[*].rx_non_dpa.rx_reg[*] -from ${lvds_core_instance_name}|channels[*].rx_non_dpa.serdes_dpa_inst~rx_internal_reg -setup $j_factor
   set_multicycle_path -start -to ${lvds_core_instance_name}|channels[*].rx_non_dpa.rx_reg[*] -from ${lvds_core_instance_name}|channels[*].rx_non_dpa.serdes_dpa_inst~rx_internal_reg -hold [expr $j_factor -1]

      } \n

   } elseif {[param_string_compare MODE "RX_DPA-FIFO"]} {
      append sdc_content {
   set_multicycle_path -start -to ${lvds_core_instance_name}|channels[*].dpa_fifo.rx_reg[*] -from ${lvds_core_instance_name}|channels[*].dpa_fifo.serdes_dpa_inst~rx_internal_reg -setup $j_factor
   set_multicycle_path -start -to ${lvds_core_instance_name}|channels[*].dpa_fifo.rx_reg[*] -from ${lvds_core_instance_name}|channels[*].dpa_fifo.serdes_dpa_inst~rx_internal_reg -hold [expr $j_factor -1]         
      } \n

      append sdc_content [generate_for_dpa_locked dpa_fifo]

   } elseif {[param_string_compare MODE "RX_Soft-CDR"]} {

      append sdc_content [generate_for_dpa_locked soft_cdr]

   }

   return $sdc_content
}

proc generate_set_input_delay {} {
   set sdc_content ""

   if {[param_string_compare MODE "RX_Non-DPA"]} {
      append sdc_content {
   set lvdsin_name ${lvds_core_instance_name}|channels[*].rx_non_dpa.serdes_dpa_inst|lvdsin
   set lvdsin_nodes [get_nodes $lvdsin_name]
   foreach_in_collection i_lvdsin_node $lvdsin_nodes {
      array unset my_lvdsin_result
      altera_iosubsystem_traverse_fanin_up_to_depth $i_lvdsin_node altera_iosubsystem_is_node_type_pin synch my_lvdsin_result 10
      foreach i_lvdsin_port [array names my_lvdsin_result] {
         if {$::RSKM_USE_MICRO == 1} {
            set_input_delay -clock $ref_ck_pin $half_RCCS [get_node_info -name $i_lvdsin_port]
         } else {
            if {$sta_flow} {
               set_false_path -from [get_node_info -name $i_lvdsin_port]
            }
         }
      }
   }
      } \n
   }
   
   return $sdc_content
}

proc generate_set_false_path_for_tx {} {
   set sdc_content ""

   if {[param_string_compare MODE "TX"]} {
      append sdc_content {

   if {$::TCCS_USE_MICRO == 0 && $sta_flow} {
      set_false_path -from ${lvds_core_instance_name}|channels[*].tx.serdes_dpa_inst~tx_internal_reg 
   }   
      } \n
   }
}

proc generate_tccs_rskm {} {
   set sdc_content ""

   append sdc_content "\nadd_rskm_report_command altera_iosubsystem_report_rskm\n"
   append sdc_content "add_tccs_report_command altera_iosubsystem_report_tccs\n"

   return $sdc_content
}

proc generate_for_bslipmax { block internal_reg } {
   
   set sdc_content ""

   if {[param_string_compare RX_USE_BITSLIP "true"]} {
   
      set from  "\${lvds_core_instance_name}|channels\[*\].${block}.serdes_dpa_inst~${internal_reg}"
      set to "\[get_fanouts \${lvds_core_instance_name}|channels\[*\].${block}.serdes_dpa_inst|bitslipmax\]"

      append sdc_content "\n"
      append sdc_content "   # Set max delay constraint in FIT to avoid rediculous long bslipmax path but cut the timing path in STA since we have synchronizer \n"
      append sdc_content "   if {\$fit_flow == 1} { \n"
      append sdc_content "      set_max_delay -from $from -to $to \[expr 2*\$slow_clock_period_ns\] \n"
      append sdc_content "   } else { \n"
      append sdc_content "      set_false_path -from $from -to $to \n"
      append sdc_content "   } \n"
      append sdc_content "\n"
   }

   return $sdc_content
}

proc generate_for_dpa_locked { block } {
   
   set sdc_content ""

   if {[param_string_compare RX_DPA_LOCKED_USED "true"]} {
   
      set from  "\${lvds_core_instance_name}|channels\[*\].${block}.serdes_dpa_inst~dpa_reg"
      set to "\[get_fanouts \${lvds_core_instance_name}|channels\[*\].${block}.serdes_dpa_inst|dpalock\]"

      append sdc_content "\n"
      append sdc_content "   # Set max delay constraint in FIT to avoid rediculous long dpa_locked path but cut the timing path in STA since we have synchronizer \n"
      append sdc_content "   if {\$fit_flow == 1} { \n"
      append sdc_content "      set_max_delay -from $from -to $to \[expr 2*\$slow_clock_period_ns\] \n"
      append sdc_content "   } else { \n"
      append sdc_content "      set_false_path -from $from -to $to \n"
      append sdc_content "   } \n"
      append sdc_content "\n"
   }

   return $sdc_content
}


proc generate_cut_path_for_internal_synchronizer {} {

   if {[param_string_compare MODE "RX_Non-DPA"]} {
     set block "rx_non_dpa"
   } elseif {[param_string_compare MODE "RX_DPA-FIFO"]} {
     set block "dpa_fifo"
   } elseif {[param_string_compare MODE "RX_Soft-CDR"]} {
     set block "soft_cdr"
   } elseif {[param_string_compare MODE "TX"]} {
     set block "tx"
   }

   set list_of_pins [list fiforeset dpareset]
   
   set sdc_content ""

   foreach i_pin $list_of_pins {
      set i_through "\[get_pins -nowarn \${lvds_core_instance_name}|channels\[*\].${block}.serdes_dpa_inst|${i_pin}\]"

      append sdc_content "\n"
      append sdc_content "   # Set max delay constraint in FIT to avoid rediculous long $i_pin path but cut the timing path in STA since we have synchronizer \n"
      append sdc_content "   set through_pin_collection $i_through \n"
      append sdc_content "   if {\[get_collection_size \$through_pin_collection\] > 0} { \n"
      append sdc_content "      if {\$fit_flow == 1} { \n"
      append sdc_content "         set_max_delay -through $i_through \[expr 2*\$slow_clock_period_ns\] \n"
      append sdc_content "      } else { \n"
      append sdc_content "         set_false_path -through $i_through \n"
      append sdc_content "      } \n"
      append sdc_content "   } \n"
      append sdc_content "\n"
   }

   set reset_sync_reg {[get_pins -compatibility_mode -nowarn ${lvds_core_instance_name}|*pll_areset_sync*|sync_inst|*|clrn]}
   append sdc_content "\n"
   append sdc_content "   # Set max delay constraint in FIT to avoid rediculous long reset path but cut the timing path in STA since we have synchronizer \n"
   append sdc_content "   if {\$fit_flow == 1} { \n"
   append sdc_content "      set_max_delay -through $reset_sync_reg \[expr 2*\$slow_clock_period_ns\] \n"
   append sdc_content "   } else { \n"
   append sdc_content "      set_false_path -through $reset_sync_reg \n"
   append sdc_content "   } \n" 
   append sdc_content "\n"


   return $sdc_content
}


proc generate_clock_uncertainty {} {

      append sdc_content {

   # ------------------------- #
   # -                       - #
   # --- CLOCK UNCERTAINTY --- #
   # -                       - #
   # ------------------------- #
   

   if {($fit_flow == 1 || $sta_flow == 1)} {

      # Build target to clock names cache
      #Needed for external PLL mode because the clock name is not the same as the pin name
      array unset target_to_clock_name_map *
      foreach_in_collection iclk_name [get_clocks] {
         if { [catch { [get_node_info -name [get_clock_info -target $iclk_name]] } itarget ] } {
            continue
         }
         lappend target_to_clock_name_map($itarget) [get_clock_info -name $iclk_name]
      }

      # Get extra periphery clock uncertainty
      set periphery_clock_uncertainty [list]
      altera_iosubsystem_get_periphery_clock_uncertainty periphery_clock_uncertainty 

      if {$fit_flow == 1} {
         set overconstraints [list $OC_C2P_SU $OC_C2P_H $OC_P2C_SU $OC_P2C_H]
      } else {
         set overconstraints [list 0.0 0.0 0.0 0.0]
      }

      # Now loop over core/periphery clocks and set clock uncertainty
      set i_core_clock 0
      foreach core_clock $core_clocks {
         if {$core_clock != ""} {

            if {[info exists target_to_clock_name_map($core_clock)]} {
               set core_clock_target $target_to_clock_name_map($core_clock)               
            } else {
               set core_clock_target $core_clock
            }
				if {[get_collection_size [get_clocks -nowarn $core_clock_target]]==0} {
					continue
				}
            set i_periphery_clock 0
            foreach { periphery_clock } $periphery_clocks {

               if {[info exists target_to_clock_name_map($periphery_clock)]} {
                  set periphery_clock_target $target_to_clock_name_map($periphery_clock)
               } else {
                  set periphery_clock_target $periphery_clock
               }
					if {[get_collection_size [get_clocks -nowarn $periphery_clock_target]]==0} {
						continue
					}		
               # For these transfers it is safe to use the -add option since we rely on 
               # derive_clock_uncertainty for the base value.
               set add_to_derived "-add"
               set c2p_su         [expr [lindex $overconstraints 0] + [lindex $periphery_clock_uncertainty 0]]
               set c2p_h          [expr [lindex $overconstraints 1] + [lindex $periphery_clock_uncertainty 1]]
               set p2c_su         [expr [lindex $overconstraints 2] + [lindex $periphery_clock_uncertainty 2]]
               set p2c_h          [expr [lindex $overconstraints 3] + [lindex $periphery_clock_uncertainty 3]]


               set_clock_uncertainty -from [get_clocks $core_clock_target] -to   [get_clocks $periphery_clock_target] -setup $add_to_derived $c2p_su
               set_clock_uncertainty -from [get_clocks $core_clock_target] -to   [get_clocks $periphery_clock_target] -hold  $add_to_derived $c2p_h
               set_clock_uncertainty -to   [get_clocks $core_clock_target] -from [get_clocks $periphery_clock_target] -setup $add_to_derived $p2c_su
               set_clock_uncertainty -to   [get_clocks $core_clock_target] -from [get_clocks $periphery_clock_target] -hold  $add_to_derived $p2c_h

               incr i_periphery_clock
            }
         }
         incr i_core_clock
      }
   }

      } \n

}

proc generate_sdc_file { top_level } {
   set sdc_content ""

   append sdc_content [generate_header]
   append sdc_content [generate_sourcing]
   append sdc_content [generate_modifiable_variables $top_level]
   append sdc_content [generate_forloop]
   append sdc_content [generate_tccs_rskm]

   return $sdc_content
}

proc calculate_counter_value { cnt_hi cnt_lo cnt_bypass } {
   if {$cnt_bypass == "true"} {
      set result 1
   } else {
      set result [expr $cnt_hi + $cnt_lo]
   }
   return $result
}

