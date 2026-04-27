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


package provide altera_lvds::top::main 0.1

package require altera_lvds::util::hwtcl_utils
package require altera_lvds::top::pll
package require ip_migrate
package require altera_iopll_common::iopll

namespace eval ::altera_lvds::top::main:: {
    
    namespace import ::altera_lvds::util::hwtcl_utils::*
    namespace import ::altera_emif::util::messaging::*
    namespace import ::altera_lvds::top::pll::*
    namespace import ::altera_iopll_common::iopll::*

}


proc ::altera_lvds::top::main::create_parameters {} {

   ::altera_iopll_common::iopll::init

    ::altera_lvds::util::hwtcl_utils::_add_parameter SYS_INFO_DEVICE_FAMILY string ""
    set_parameter_property SYS_INFO_DEVICE_FAMILY SYSTEM_INFO DEVICE_FAMILY
    set_parameter_property SYS_INFO_DEVICE_FAMILY VISIBLE false

    ::altera_lvds::util::hwtcl_utils::_add_parameter SYS_INFO_DEVICE string ""
    set_parameter_property SYS_INFO_DEVICE SYSTEM_INFO DEVICE
    set_parameter_property SYS_INFO_DEVICE VISIBLE false

    ::altera_lvds::util::hwtcl_utils::_add_parameter SYS_INFO_DEVICE_SPEEDGRADE string ""
    set_parameter_property SYS_INFO_DEVICE_SPEEDGRADE SYSTEM_INFO DEVICE_SPEEDGRADE
    set_parameter_property SYS_INFO_DEVICE_SPEEDGRADE VISIBLE false


    set allowed_modes {"TX" "RX_Non-DPA:RX Non-DPA" "RX_DPA-FIFO:RX DPA-FIFO" "RX_Soft-CDR:RX Soft-CDR"}
    add_user_param      MODE                                    string      "TX"            $allowed_modes          ""                              "radio"                                true
    add_user_param      USE_EXTERNAL_PLL                        boolean     false           ""                      ""                              ""                                     true
    add_user_param      USE_CLOCK_PIN                           boolean     false           ""                      ""                              ""                                     true
    add_user_param      NUM_CHANNELS                            integer     1               {1:24}                  ""                              ""                                     true
    add_user_param      J_FACTOR                                integer     10              {3 4 5 6 7 8 9 10}      ""                              ""                                     true
    add_user_param      DATA_RATE                               float       1000.0          {150.0:1600.0}            "MegabitsPerSecond"             ""                                     true
    add_user_param      INCLOCK_FREQUENCY                       float       100.0           {5:800}                 "Megahertz"                     ""                                     true
    add_user_param      ENABLE_MIGRATABLE_PORT_MAPPINGS         boolean     false           ""                      ""                              ""                                     true
    
    add_derived_param   ACTUAL_INCLOCK_FREQUENCY                float       100.000000      true               "Megahertz"                  
    add_derived_param   PORT_MAP_FILE_NAME                      string      "port_map_rx.csv" false            ""                           ""
    
    add_user_param      RX_USE_BITSLIP                          boolean     "false"         ""                      ""                           ""                                     true
    add_user_param      RX_INCLOCK_PHASE_SHIFT                  integer     0               ""                      ""                           ""                                     true
	add_user_param      RX_RCCS_VAL                             float       0.0             {0.0:1000000.0}                 ""                              ""                                     true
    
    add_user_param      RX_BITSLIP_USE_RESET                    boolean     "false"         ""
    add_user_param      RX_BITSLIP_ASSERT_MAX                   boolean     "false"         ""
    
    add_user_param      RX_DPA_USE_RESET                        boolean     "false"         ""    
    add_user_param      RX_DPA_LOSE_LOCK_ON_ONE_CHANGE          boolean     "false"         ""
    add_user_param      RX_DPA_ALIGN_TO_RISING_EDGE_ONLY        boolean     "false"         ""
    add_user_param      RX_DPA_USE_HOLD                         boolean     "false"         ""
    add_user_param      ENABLE_DIV_RECONFIG                     boolean     "false"         ""                      ""                           ""                                     true                       false

         
    add_user_param      RX_FIFO_USE_RESET                       boolean     "false"         ""
    add_user_param      RX_CDR_SIMULATION_PPM_DRIFT             integer    0               {-1000:1000}            "Picoseconds" 
    
    add_derived_param   RX_INCLOCK_PHASE_SHIFT_ACTUAL           integer     0               true               "" 
    add_derived_param   RX_DPA_LOCKED_USED                      boolean     "false"         false
    add_derived_param   RX_BITSLIP_ROLLOVER                     integer     10              true
    
    add_user_param      TX_USE_OUTCLOCK                         boolean     "true"          ""                      ""                           ""                                     true
    add_user_param      TX_OUTCLOCK_DIVISION                    integer     2               {2 10}                  ""                           ""                                     true
    add_user_param      TX_OUTCLOCK_PHASE_SHIFT                 integer     0               ""                      ""                           ""                                     true
    add_user_param      TX_EXPORT_CORECLOCK                     boolean     "true"         ""
    add_user_param      TX_REGISTER_CLOCK                       string      "tx_coreclock"  {"tx_coreclock" "inclock"} ""                     ""                                     true
    
    add_derived_param      TX_OUTCLOCK_PHASE_SHIFT_ACTUAL       integer     0               true               ""
    add_derived_param   TX_OUTCLOCK_NON_STD_PHASE_SHIFT         string      "false"         false              ""
    
    add_user_param      PLL_CORECLOCK_RESOURCE                  string      "Periphery"     {"Auto" "Periphery" "Global"}
    add_user_param      PLL_USE_RESET                           boolean     "true"          ""

    add_user_param      GENERATE_SDC_FILE                       BOOLEAN     "true"         ""                      ""                           ""                                     true                      false
    
    add_user_param      CPA_ENABLED                             BOOLEAN     "false"        ""                      ""                           ""                                     true                      false
   
    add_derived_param   PLL_EXPORT_LOCK                         boolean     "true"         false
    add_derived_param   pll_fclk_frequency                      string      "100.0 MHz"     false
    add_derived_param   pll_fclk_phase_shift                    string      "0 ps"          false

    add_derived_param   pll_sclk_frequency                      string      "10.0 MHz"      false
    add_derived_param   pll_sclk_phase_shift                    string      "0 ps"          false
    
    add_derived_param   pll_loaden_frequency                    string      "10.0 MHz"      false
    add_derived_param   pll_loaden_phase_shift                  string      "0 ps"          false
    add_derived_param   pll_loaden_duty_cycle                   integer     10              false
    
    add_derived_param   pll_tx_outclock_frequency               string      "0 ps"          false 
    add_derived_param   pll_tx_outclock_phase_shift             string      "0 ps"          false 
    add_derived_param   pll_tx_outclock_fclk_frequency          string      "0 ps"          false 
    add_derived_param   pll_tx_outclock_fclk_phase_shift        string      "0 ps"          false 
    add_derived_param   pll_tx_outclock_loaden_frequency        string      "0 ps"          false 
    add_derived_param   pll_tx_outclock_loaden_phase_shift      string      "0 ps"          false 
    
    add_derived_param   pll_dprio_clk_frequency                 string      "10.0 MHz"      false
    
    add_derived_param   pll_vco_frequency                       string      "0 ps"          false 
    add_derived_param   pll_inclock_frequency                   string      "10.0 MHz"      false
    add_derived_param   PLL_SPEED_GRADE                         integer     2               true               ""


    add_derived_param   GUI_CLOCK_PARAM_NAMES                   STRING_LIST ""              false
    add_derived_param   GUI_CLOCK_PARAM_VALUES                  STRING_LIST ""              false
    
    ::altera_iopll_common::iopll::set_sys_info_device_family SYS_INFO_DEVICE_FAMILY
    ::altera_iopll_common::iopll::set_sys_info_device SYS_INFO_DEVICE
    ::altera_iopll_common::iopll::set_sys_info_device_speedgrade PLL_SPEED_GRADE
    ::altera_iopll_common::iopll::set_reference_clock_frequency pll_inclock_frequency
    ::altera_iopll_common::iopll::set_vco_frequency pll_vco_frequency
    ::altera_iopll_common::iopll::set_external_pll_mode USE_EXTERNAL_PLL
    ::altera_iopll_common::iopll::declare_pll_parameters

    return 1
}


proc ::altera_lvds::top::main::add_display_items {} {

    set general_tab [get_string TAB_GENERAL_NAME]
    set rx_tab  [get_string TAB_RX_SETTINGS_NAME]
    set tx_tab  [get_string TAB_TX_SETTINGS_NAME]
    set clocking_tab [get_string TAB_CLOCKING_NAME]

    set top_tab [get_string TAB_TOP_LEVEL_SETTINGS_NAME]
    set pll_tab [get_string TAB_PLL_SETTINGS_NAME]
    set clock_resources [get_string TAB_CLOCK_RESOURCES_NAME]
    set dpa_tab [get_string TAB_DPA_SETTINGS_NAME]
    set bslip_tab [get_string TAB_BITSLIP_SETTINGS_NAME]
    set non_dpa_tab [get_string TAB_NON_DPA_SETTINGS_NAME]
 
 
    add_display_item "" $general_tab        GROUP tab
    add_display_item "" $pll_tab            GROUP tab
    add_display_item "" $rx_tab             GROUP tab
    add_display_item "" $tx_tab             GROUP tab
    add_display_item "" $clock_resources    GROUP tab
    add_display_item $general_tab   $top_tab                GROUP
   
    add_display_item $rx_tab        $bslip_tab              GROUP 
    add_display_item $rx_tab        $dpa_tab                GROUP 
    add_display_item $rx_tab        $non_dpa_tab            GROUP
    
 
    add_param_to_gui $general_tab       MODE 
    add_param_to_gui $general_tab       NUM_CHANNELS 
    add_param_to_gui $general_tab       DATA_RATE
    add_param_to_gui $general_tab       J_FACTOR  
    add_param_to_gui $general_tab       USE_CLOCK_PIN 
    add_param_to_gui $general_tab       ENABLE_MIGRATABLE_PORT_MAPPINGS 
    add_param_to_gui $general_tab       CPA_ENABLED 
    
    
    add_param_to_gui $pll_tab       USE_EXTERNAL_PLL
    add_param_to_gui $pll_tab       INCLOCK_FREQUENCY     
    add_param_to_gui $pll_tab       ACTUAL_INCLOCK_FREQUENCY
    add_param_to_gui $pll_tab       PLL_SPEED_GRADE
    add_param_to_gui $pll_tab       PLL_EXPORT_LOCK
    add_param_to_gui $pll_tab       PLL_USE_RESET 
    add_param_to_gui $pll_tab       PLL_CORECLOCK_RESOURCE

    add_param_to_gui $bslip_tab     RX_USE_BITSLIP
    add_param_to_gui $bslip_tab     RX_BITSLIP_USE_RESET
    add_param_to_gui $bslip_tab     RX_BITSLIP_ASSERT_MAX
    add_param_to_gui $bslip_tab     RX_BITSLIP_ROLLOVER
    
    add_param_to_gui $dpa_tab       RX_DPA_USE_RESET
    add_param_to_gui $dpa_tab       RX_DPA_LOCKED_USED
    add_param_to_gui $dpa_tab       RX_FIFO_USE_RESET
    add_param_to_gui $dpa_tab       RX_DPA_USE_HOLD
    add_param_to_gui $dpa_tab       ENABLE_DIV_RECONFIG
    
    add_param_to_gui $dpa_tab       RX_DPA_LOSE_LOCK_ON_ONE_CHANGE
    add_param_to_gui $dpa_tab       RX_DPA_ALIGN_TO_RISING_EDGE_ONLY
    add_param_to_gui $dpa_tab       RX_CDR_SIMULATION_PPM_DRIFT

    add_param_to_gui $non_dpa_tab   RX_INCLOCK_PHASE_SHIFT
    add_param_to_gui $non_dpa_tab   RX_INCLOCK_PHASE_SHIFT_ACTUAL
    add_param_to_gui $non_dpa_tab   RX_RCCS_VAL

    add_param_to_gui $tx_tab        TX_REGISTER_CLOCK
    add_param_to_gui $tx_tab        TX_EXPORT_CORECLOCK
    add_param_to_gui $tx_tab        TX_USE_OUTCLOCK
    add_param_to_gui $tx_tab        TX_OUTCLOCK_PHASE_SHIFT
    add_param_to_gui $tx_tab        TX_OUTCLOCK_PHASE_SHIFT_ACTUAL
    add_param_to_gui $tx_tab        TX_OUTCLOCK_DIVISION

    
    set clock_resource_group "Clock and PLL Configuration Summary (Can be used for external PLL)"
    add_display_item $clock_resources $clock_resource_group GROUP
    set CLOCKS_TABLE ""
    add_display_item $clock_resource_group clock_resource_table text $CLOCKS_TABLE

    ::altera_iopll_common::iopll::declare_pll_display_items $pll_tab
	
   return 1
}

proc ::altera_lvds::top::main::composition_callback {} {

    _compose
}

proc ::altera_lvds::top::main::validation_callback {} {

   ::altera_iopll_common::iopll::init

    _validate
}

proc ::altera_lvds::top::main::parameter_upgrade_callback {ip_core_type version old_parameters} {

    foreach param [get_parameters] {
        set params($param) 1
    }

    if { $version == 13.1 } {
        _upgrade_from_13_1 $old_parameters
    } else {
        foreach { name value } $old_parameters {
            emif_dbg 2 "Old Param: $name --> $value"
            if {[info exists params($name)]} {
                if {![get_parameter_property $name DERIVED]} {
                    set_parameter_value $name $value
                    emif_dbg 2 "Setting New Param: $name --> $value"
                } else {
                    emif_dbg 2 "Old Param: $name is now derived"
                }
            } else {
                emif_dbg 2 "Warning: Param: $name does not exist"
            }
        }
    }
}


proc ::altera_lvds::top::main::_validate {} {
    emif_dbg 1 "------------------ Running IP Validation for [get_module_property NAME] ------------------"
    _validate_parameters
    
    _generate_pll_parameters 

    retreive_pll_output_clocks_info
    ::altera_iopll_common::iopll::validate
    
    _set_derived_visible_parameters
}

proc ::altera_lvds::top::main::_compose {} {

    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]
    emif_dbg 2 "DEVICE FAMILY: $family"
    if {[string_compare $family "Arria 10"]} {
        set core_component altera_lvds_core20
    } else {
        set core_component altera_lvds_core14
    }
    
    set core_name core
    
    add_instance $core_name $core_component
     
    foreach param_name [get_instance_parameters $core_name] {
        set param_val [get_parameter_value $param_name]
        set_instance_parameter_value $core_name $param_name $param_val
    }

    altera_lvds::top::main::export_all_interfaces_of_sub_component $core_name
    
    if {[string equal -nocase [get_parameter_value ENABLE_MIGRATABLE_PORT_MAPPINGS] "true"]} {
            ::ip_migrate::do_port_mappings [get_parameter_value PORT_MAP_FILE_NAME]
        }
   
    return 1
}

proc ::altera_lvds::top::main::_upgrade_from_13_1 {old_parameters} {

    foreach { name value } $old_parameters {
        emif_dbg 2 "Old Param: $name --> $value"
        if {[string_compare $name device_family]} {
            set_parameter_value SYS_INFO_DEVICE_FAMILY $value
        } elseif {[string_compare $name _HIDDEN_ENABLE_SDC_GENERATION] || [string_compare $name GENERATE_SDC_FILE] || [string_compare $name AUTO_DEVICE]} {
        } else {
            if {![get_parameter_property $name DERIVED]} {
                set_parameter_value $name $value
                emif_dbg 2 "Setting New Param: $name --> $value"
            } else {
                emif_dbg 2 "Old Param: $name is now derived"
            }
        }
    }
}

proc ::altera_lvds::top::main::rename_exported_interface_ports {instance_name interface_name exported_interface_name} {

   
   set port_map [list]
   foreach port_name [get_instance_interface_ports $instance_name $interface_name] {
      lappend port_map $port_name
      lappend port_map $port_name
   }
   set_interface_property $exported_interface_name PORT_NAME_MAP $port_map
   return 1
}




proc ::altera_lvds::top::main::_export_single_port_interface {if_name if_type if_dir inst_name inst_if} {
         
   add_interface $if_name $if_type $if_dir
   set_interface_property $if_name EXPORT_OF "${inst_name}.${inst_if}"
     
   set port_map [list]
   set port_name [get_instance_interface_ports $inst_name $inst_if] 
      lappend port_map $if_name
      lappend port_map [lindex $port_name 0]

   set_interface_property $if_name PORT_NAME_MAP $port_map
   return 1
} 


proc ::altera_lvds::top::main::export_all_interfaces_of_sub_component {inst_name} {   

    set i 0
    foreach if_name [get_instance_interfaces $inst_name] {
        if {[regexp -lineanchor "\^(.*?)_(clock|reset|avalon|avalon_streaming|conduit)_(master|slave|source|sink|end)\$" $if_name matched if_short_name if_type if_dir ] } {
      
            add_interface $if_short_name $if_type $if_dir
            set_interface_property $if_short_name EXPORT_OF "${inst_name}.${if_name}"
         
            rename_exported_interface_ports $inst_name $if_name $if_short_name
            incr i
            }
        }
    return $i
}


proc ::altera_lvds::top::main::_generate_pll_parameters {} { 

    if {!([parameter_within_legal_range DATA_RATE] && [parameter_within_legal_range ACTUAL_INCLOCK_FREQUENCY]
        && [parameter_within_legal_range RX_INCLOCK_PHASE_SHIFT])} {
        return
    }

    set mode [get_parameter_value MODE]
    set rate [get_parameter_value DATA_RATE]
    set uses_clock_pin [get_parameter_value USE_CLOCK_PIN]
    set inclock_freq [get_parameter_value ACTUAL_INCLOCK_FREQUENCY]
    set j_factor [get_parameter_value J_FACTOR]
    set inclock_shift_deg 0
    set vco_freq [get_legal_vco $rate] 
    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]

    if {[string_compare $mode "RX_Non-DPA"]} {
        set inclock_shift_deg [get_parameter_value RX_INCLOCK_PHASE_SHIFT_ACTUAL]
    }    
    
    set fclk_period [freq_to_period $rate]
    set fclk_frequency_double  [format "%.6f" $rate]

    set_parameter_value pll_inclock_frequency "$inclock_freq MHz"
    
    set_parameter_value pll_fclk_frequency "$fclk_frequency_double MHz"
    set fclk_phase_shift [expr {round($fclk_period * (0.5 - double($inclock_shift_deg)/360))%($fclk_period)}]
    set_parameter_value pll_fclk_phase_shift "$fclk_phase_shift ps"

    
    
    if { ([string_compare $mode "RX_DPA-FIFO"]) || 
         ([string_compare $uses_clock_pin "false"]  && 
         ([string_compare $mode "RX_Non-DPA"]  || [string_compare $mode "TX"] || [string_compare $mode "RX_Soft-CDR"])) } { 

        set sclk_frequency_double  [format "%.6f" [expr {double($rate)/$j_factor}]]
        set loaden_shift_ps [expr {round($fclk_period*($j_factor - 1 - double($inclock_shift_deg)/360))%($fclk_period*$j_factor)}]
        if {[string_compare $family "Arria 10"]} {
           set sclk_shift_ps [expr {round($fclk_period * (0.0 - double($inclock_shift_deg)/360))%($fclk_period*$j_factor)}]
        } else {
           set sclk_shift_ps [expr {round($fclk_period * (0.5 - double($inclock_shift_deg)/360))%($fclk_period*$j_factor)}]
        }
        set_parameter_value pll_loaden_frequency "$sclk_frequency_double MHz"
        set_parameter_value pll_loaden_duty_cycle [expr {round(100.0/$j_factor)}]
        set_parameter_value pll_loaden_phase_shift "$loaden_shift_ps ps"

        set_parameter_value pll_sclk_frequency "$sclk_frequency_double MHz"
        set_parameter_value pll_sclk_phase_shift "$sclk_shift_ps ps"

    } else {
        set_parameter_value pll_sclk_frequency "0 MHz"
        set_parameter_value pll_sclk_phase_shift "0 ps"

        set_parameter_value pll_loaden_frequency "0 MHz"
        set_parameter_value pll_loaden_duty_cycle 50
        set_parameter_value pll_loaden_phase_shift "0 ps"
    }

    if  { [string_compare $mode "TX"] && [string_compare $uses_clock_pin "false"] && [param_string_compare TX_USE_OUTCLOCK "true"]} {

        set tx_outclock_div [get_parameter_value TX_OUTCLOCK_DIVISION]
        set tx_outclock_shift_deg [get_parameter_value TX_OUTCLOCK_PHASE_SHIFT_ACTUAL]
        
        set_parameter_value pll_tx_outclock_frequency "[format "%.6f" [expr {double ($rate)/$tx_outclock_div}]] MHz"
        set tx_outclock_phase_shift [expr {round($fclk_period * ((double($tx_outclock_shift_deg)/360 + 0.5)))%($fclk_period*$tx_outclock_div)}]
        emif_dbg 2 "Required tx_outclock_ps = $tx_outclock_phase_shift"
        set_parameter_value pll_tx_outclock_phase_shift "$tx_outclock_phase_shift ps"

        set_parameter_value pll_tx_outclock_fclk_frequency [get_parameter_value pll_fclk_frequency]
        set_parameter_value pll_tx_outclock_fclk_phase_shift [get_parameter_value pll_tx_outclock_phase_shift]
        
        set_parameter_value pll_tx_outclock_loaden_frequency [get_parameter_value pll_loaden_frequency]
        set tx_outclock_loaden_phase_shift [expr {$loaden_shift_ps + $tx_outclock_phase_shift - $fclk_phase_shift}]
        emif_dbg 2 "Required tx_outclock_loaden_phase_shift = $tx_outclock_loaden_phase_shift"
        set_parameter_value pll_tx_outclock_loaden_phase_shift "$tx_outclock_loaden_phase_shift ps"
            
    } else {
        set_parameter_value pll_tx_outclock_frequency "0 MHz"
        set_parameter_value pll_tx_outclock_phase_shift "0 ps"
        set_parameter_value pll_tx_outclock_loaden_phase_shift "0 ps"
    }

    
    set_parameter_value pll_vco_frequency "[format "%.6f" $vco_freq] MHz"
    emif_dbg 2 "Setting VCO Frequency to [get_parameter_value pll_vco_frequency]"

}


proc ::altera_lvds::top::main::_set_derived_visible_parameters { } {         
   
    set mode [get_parameter_value MODE]
    set param_list [list]
    set param_values [list] 
    set num_outclocks 0
    set j_factor [get_parameter_value J_FACTOR]
    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]
    if {[string_compare $mode "RX_Non-DPA"]} {
        set pll_compensation_mode "lvds"
    } else {
        set pll_compensation_mode "direct"
    }


    set desc_width 250

    set CLOCKS_TABLE "<html><table border=\"0\" width=\"100%\">"
    
    append CLOCKS_TABLE "<tr bgcolor=\"#C9DBF3\">
                            <td><font size=5>
                              Clock
                            </font></td>
                            <td><font size=5>
                              Frequency
                            </font></td>
                            <td><font size=5>
                              Phase Shift
                            </font></td>
                            <td><font size=5>
                              Duty Cycle
                            </font></td>
                            <td><font size=5>
                              PLL Port
                            </font></td>
                            <td><font size=5>
                              External PLL Usage
                            </font></td>
                          </tr>"
    
    if {[string_compare $mode "RX_DPA-FIFO"] ||[string_compare $mode "RX_Soft-CDR"]} {
        set vco_string "PLL VCO"
        set dpa_desc "Strictly required to be set to the given frequency using \"Specify VCO frequency\" on PLL IP. Use \"Enable access to PLL DPA output port\" on PLL IP to expose the VCO ports. Connect to ext_vcoph\[7:0\] on LVDS IP."
        set vco_ports "phout\[7:0\]"
    } else {
        set vco_string "PLL VCO"
        set dpa_desc "-"
        set vco_ports "-"
    }
    
    append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                        <td valign=\"top\"><b>
                          $vco_string
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_parameter_value pll_vco_frequency]
                        </b></td>
                        <td valign=\"top\"><b>
                          -
                        </b></td>
                        <td valign=\"top\"><b>
                          -
                        </b></td>
                        <td valign=\"top\"><b>
                          $vco_ports
                        </b></td>
                        <td valign=\"top\" width=\"$desc_width\"><b>
                          $dpa_desc
                        </b></td>
                        </tr>"

    append CLOCKS_TABLE "<tr bgcolor=\"#C9DBF3\">
                        <th colspan=\"6\"><b>
                          PLL-Generated Clocks
                        </b></th>
                        </tr>"                        
    
    if {[string_compare $family "Arria 10"]} {
        set lvds_clk_idx 0
        set outclk_idx 0
    } else {
        if {[string_compare $mode "TX"]} {
            set lvds_clk_idx 1
            set outclk_idx 2
        } else {
            set lvds_clk_idx 0
            set outclk_idx 0
        }
    }
    
    append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                        <td valign=\"top\"><b>
                          Fast clock
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_parameter_value pll_fclk_frequency]
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_lvds_clock_shift_in_degrees "fclk"]<br>
                          [get_parameter_value pll_fclk_phase_shift]<br>
                        </b></td>
                        <td valign=\"top\"><b>
                          50 %
                        </b></td>
                        <td valign=\"top\"><b>
                          lvds_clk\[$lvds_clk_idx\] <br>
                          Shares outclk$outclk_idx settings
                        </b></td>
                        <td valign=\"top\" width=\"$desc_width\"><b>
                          Use \"Access to PLL LVDS_CLK/LOADEN output port\" on PLL IP to expose lvds_clk ports. Connect to ext_fclk on LVDS IP.
                        </b></td>
                        </tr>"
    
    if {[string_compare $family "Arria 10"]} {
        set loaden_idx 0
        set outclk_idx 1
    } else {
        if {[string_compare $mode "TX"]} {
            set loaden_idx 1
            set outclk_idx 3
        } else {
            set loaden_idx 0
            set outclk_idx 1
        }
    }
    append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                        <td valign=\"top\"><b>
                          Load enable
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_parameter_value pll_loaden_frequency]
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_lvds_clock_shift_in_degrees "loaden"]<br>
                          [get_parameter_value pll_loaden_phase_shift]<br>
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_parameter_value pll_loaden_duty_cycle] %
                        </b></td>
                        <td valign=\"top\"><b>
                          loaden\[$loaden_idx\] <br>
                          Shares outclk$outclk_idx settings
                        </b></td>
                        <td valign=\"top\" width=\"$desc_width\"><b>
                          Use \"Access to PLL LVDS_CLK/LOADEN output port\" on PLL IP to expose loaden ports. Connect to ext_loaden on LVDS IP.
                        </b></td>
                      </tr>"
    
    if { [string_compare $mode "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] && [param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
        
        if {[string_compare $family "Arria 10"]} {
            set lvds_clk_idx 1
            set outclk_idx 2
        } else {
            set lvds_clk_idx 0
            set outclk_idx 0
        }
    
        append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                            <td valign=\"top\"><b>
                              Tx outclock fast clock
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_parameter_value pll_tx_outclock_fclk_frequency]
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_lvds_clock_shift_in_degrees "tx_outclock_fclk"]<br>
                              [get_parameter_value pll_tx_outclock_fclk_phase_shift]<br>
                            </b></td>
                            <td valign=\"top\"><b>
                              50 %
                            </b></td>
                            <td valign=\"top\"><b>
                              lvds_clk\[$lvds_clk_idx\] <br>
                              Shares outclk$outclk_idx settings
                            </b></td>
                            <td valign=\"top\" width=\"$desc_width\"><b>
                              Use \"Access to PLL LVDS_CLK/LOADEN output port\" on PLL IP to expose lvds_clk ports. Connect to ext_tx_outclock_fclk on LVDS IP.
                            </b></td>
                          </tr>"
                              
        if {[string_compare $family "Arria 10"]} {
            set loaden_idx 1
            set outclk_idx 3
        } else {
            set loaden_idx 0
            set outclk_idx 1
        }
        append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                            <td valign=\"top\"><b>
                              Tx outclock load enable
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_parameter_value pll_tx_outclock_loaden_frequency]
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_lvds_clock_shift_in_degrees "tx_outclock_loaden"]<br>
                              [get_parameter_value pll_tx_outclock_loaden_phase_shift]<br>
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_parameter_value pll_loaden_duty_cycle] %
                            </b></td>
                            <td valign=\"top\"><b>
                              loaden\[$loaden_idx\] <br>
                              Shares outclk$outclk_idx settings
                            </b></td>
                            <td valign=\"top\" width=\"$desc_width\"><b>
                              Use \"Access to PLL LVDS_CLK/LOADEN output port\" on PLL IP to expose loaden ports. Connect to ext_tx_outclock_loaden on LVDS IP.
                            </b></td>
                          </tr>"
             
    }
    append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                        <td valign=\"top\"><b>
                          Core clock
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_parameter_value pll_sclk_frequency]
                        </b></td>
                        <td valign=\"top\"><b>
                          [get_lvds_clock_shift_in_degrees "sclk"]<br>
                          [get_parameter_value pll_sclk_phase_shift]<br>
                        </b></td>
                        <td valign=\"top\"><b>
                          50 %
                        </b></td>
                        <td valign=\"top\"><b>
                          Any unused PLL outclock
                        </b></td>
                        <td valign=\"top\" width=\"$desc_width\"><b>
                          Connect to ext_coreclock on LVDS IP.
                        </b></td>
                      </tr>"
    
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
            set duty_cycle [expr {round($duty_cycle)}]
            set extra_clock_num [expr {$i - $pll_maximum_number_of_reserved_clocks}]
            
            append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                                <td valign=\"top\"><b>
                                  Extra clock $extra_clock_num
                                </b></td>
                                <td valign=\"top\"><b>
                                  $output_freq MHz
                                </b></td>
                                <td valign=\"top\"><b>
                                  $phase_shift_deg degrees<br>
                                  $phase_shift_ps ps<br>
                                </b></td>
                                <td valign=\"top\"><b>
                                  $duty_cycle %
                                </b></td>
                                <td valign=\"top\"><b>
                                  Any unused PLL outclock
                                </b></td>
                                <td valign=\"top\" width=\"$desc_width\"><b>
                                  Connect to core logic.
                                </b></td>
                              </tr>"
        }
    }
    
    if { [string_compare $mode "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"] } {
        if {[param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"]} {
            set tx_outclock_duty_cycle 50
        } else {
            if {$j_factor % 2 == 1} {
                set tx_outclock_duty_cycle [format "%.6f" [expr { 100 * ( double ( int( double($j_factor)/2 + 1 ) ) / $j_factor) }]]
            } else {
                set tx_outclock_duty_cycle 50
            }
        }
        append CLOCKS_TABLE "<tr bgcolor=\"#C9DBF3\">
                            <th colspan=\"6\"><b>
                              Non PLL-Generated Clocks
                            </b></th>
                            </tr>"
        append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                            <td valign=\"top\"><b>
                              Tx outclock
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_parameter_value pll_tx_outclock_frequency]
                            </b></td>
                            <td valign=\"top\"><b>
                              [get_parameter_value TX_OUTCLOCK_PHASE_SHIFT_ACTUAL] fclk degrees <br>
                              (w.r.t. TX data)
                            </b></td>
                            <td valign=\"top\"><b>
                              $tx_outclock_duty_cycle %
                            </b></td>
                            <td valign=\"top\"><b>
                              -
                            </b></td>
                            <td valign=\"top\" width=\"$desc_width\"><b>
                              -
                            </b></td>
                          </tr>"
    }
    
    append CLOCKS_TABLE "<tr bgcolor=\"#C9DBF3\">
                            <th colspan=\"6\"><b>
                              Other PLL Settings
                            </b></th>
                            </tr>"
    append CLOCKS_TABLE "<tr bgcolor=\"#FFFFFF\">
                            <td valign=\"top\"><b>
                              Compensation Mode
                            </b></td>
                            <td valign=\"top\"><b>
                              $pll_compensation_mode
                            </b></td>
                            <td valign=\"top\"><b>
                              
                            </b></td>
                            <td valign=\"top\"><b>
                              
                            </b></td>
                            <td valign=\"top\"><b>
                              
                            </b></td>
                            <td valign=\"top\" width=\"$desc_width\"><b>
                                
                            </b></td>
                          </tr>"
    
    append CLOCKS_TABLE "<tr bgcolor=\"#C0C0C0\">
                        <th colspan=\"6\" align=\"left\"><font size=2><b>
                          * The degrees of a clock's phase shift are with respect to itself unless otherwise stated
                        </font></b></th>
                        </tr>"
    

    append CLOCKS_TABLE "</table></html>"
    
    set_display_item_property clock_resource_table TEXT $CLOCKS_TABLE
}


proc ::altera_lvds::top::main::_validate_parameters { } {         
   
    foreach param [get_parameters] {
        if { [info procs _validate_$param] != "" } {
            emif_dbg 1 "Calling _validate_$param"
            _validate_$param 
        } else {
            emif_dbg 2 "Warning: _validate_$param does not exist"
        }
    }
}


proc ::altera_lvds::top::main::_validate_SYS_INFO_DEVICE_SPEEDGRADE { } {
   
    _validate_PLL_SPEED_GRADE
}

proc ::altera_lvds::top::main::_validate_NUM_CHANNELS { } {
   
    set mode [get_parameter_value MODE]

    if {[string_compare $mode "RX_DPA-FIFO"]} {
        set max_if_width 24 
    } elseif {[string_compare $mode "RX_Soft-CDR"]} {
        set max_if_width 12 
    } elseif {[string_compare $mode "RX_Non-DPA"]} {
        if {[::altera_emif::util::qini::ini_is_on "lvds_allow_wide_rx_non_dpa"]} { 
            set max_if_width 72 
        } else {
            set max_if_width 24 
        }
    } else {
        set max_if_width 72
    }    
   
   set_parameter_property NUM_CHANNELS allowed_ranges 1:${max_if_width} 
}

proc ::altera_lvds::top::main::_validate_USE_EXTERNAL_PLL { } {

    if {[get_parameter_value USE_CLOCK_PIN] == 1 || [get_parameter_value gui_enable_advanced_mode] || [get_parameter_value CPA_ENABLED] } {
        set_parameter_property USE_EXTERNAL_PLL ENABLED false
    } else {
        set_parameter_property USE_EXTERNAL_PLL ENABLED true
    }
}

proc ::altera_lvds::top::main::_validate_DATA_RATE { } {
    
    
    if {[get_parameter_value USE_CLOCK_PIN]} {
        set max_data_rate 800.0
    } elseif {[get_parameter_value USE_EXTERNAL_PLL]} {
        set max_data_rate 1600.0
    } else {
        set max_data_rate [get_pll_spec VCO_MAX]
    }

    set_parameter_property DATA_RATE allowed_ranges 150.0:$max_data_rate 
}

proc ::altera_lvds::top::main::_validate_INCLOCK_FREQUENCY { } {
   
    if {[get_parameter_value USE_CLOCK_PIN]} {
        set_parameter_property INCLOCK_FREQUENCY ENABLED false
    } else {
        set_parameter_property INCLOCK_FREQUENCY ENABLED true
        set refmin [get_pll_spec REF_MIN]
        set refmax [get_pll_spec REF_MAX]
        set allowed_range "{$refmin:$refmax}"
        set_parameter_property INCLOCK_FREQUENCY ALLOWED_RANGES $allowed_range
    } 
}

proc ::altera_lvds::top::main::_validate_USE_CLOCK_PIN { } {
    
    set mode [get_parameter_value MODE] 

        set_parameter_property USE_CLOCK_PIN ENABLED false
}

proc ::altera_lvds::top::main::_validate_CPA_ENABLED { } {
    
    set mode [get_parameter_value MODE] 
    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]

    if {![string_compare $family "Arria 10"]} {
        set_parameter_property CPA_ENABLED VISIBLE true
        if {![string_compare $mode "RX_Soft-CDR"]} {
            set_parameter_property CPA_ENABLED ENABLED true
        } else {
            set_parameter_property CPA_ENABLED ENABLED false
        }
    }

    emif_dbg 2 "CPA value set to [get_parameter_value CPA_ENABLED]"


}








proc ::altera_lvds::top::main::_validate_RX_INCLOCK_PHASE_SHIFT { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_Non-DPA"] && [param_string_compare USE_CLOCK_PIN "false"]} {
        if {!([parameter_within_legal_range DATA_RATE] && [parameter_within_legal_range ACTUAL_INCLOCK_FREQUENCY])} {
            return
        }
        set_parameter_property RX_INCLOCK_PHASE_SHIFT ENABLED true
        set rate [get_parameter_value DATA_RATE]
        set inclock_freq [get_parameter_value ACTUAL_INCLOCK_FREQUENCY]

        set fclk_inclk_div [expr {double($rate)/$inclock_freq}]
        set allowed_ranges "{0:[expr {round(ceil($fclk_inclk_div*360)-1)}]}"
        
        set_parameter_property RX_INCLOCK_PHASE_SHIFT ENABLED true
        set_parameter_property RX_INCLOCK_PHASE_SHIFT ALLOWED_RANGES  $allowed_ranges
    } else {
        set_parameter_property RX_INCLOCK_PHASE_SHIFT ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_RCCS_VAL { } {
 
    set mode [get_parameter_value MODE] 
    if {[string_compare $mode "RX_Non-DPA"]} {
        set_parameter_property RX_RCCS_VAL ENABLED true
    } else {
       set_parameter_property RX_RCCS_VAL ENABLED false
	}

}

proc ::altera_lvds::top::main::_validate_RX_USE_BITSLIP { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "TX"]} {
        set_parameter_property RX_USE_BITSLIP ENABLED false
    } else {
        set_parameter_property RX_USE_BITSLIP ENABLED true
    }
}

proc ::altera_lvds::top::main::_validate_RX_BITSLIP_ASSERT_MAX { } {
    
    set mode [get_parameter_value MODE] 
    set use_cda [get_parameter_value RX_USE_BITSLIP]

    if {[string_compare $mode "TX"] == 0 && $use_cda } {
        set_parameter_property RX_BITSLIP_ASSERT_MAX ENABLED true
    } else {
        set_parameter_property RX_BITSLIP_ASSERT_MAX ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_BITSLIP_USE_RESET { } {
    
    set mode [get_parameter_value MODE] 
    set use_cda [get_parameter_value RX_USE_BITSLIP]

    if {[string_compare $mode "TX"] == 0 && $use_cda } {
        set_parameter_property RX_BITSLIP_USE_RESET ENABLED true
    } else {
        set_parameter_property RX_BITSLIP_USE_RESET ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_BITSLIP_ROLLOVER { } {
    
    set_parameter_value RX_BITSLIP_ROLLOVER [get_parameter_value J_FACTOR]
}

proc ::altera_lvds::top::main::_validate_RX_DPA_USE_RESET { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"] || [string_compare $mode "RX_Soft-CDR"] } {
        set_parameter_property RX_DPA_USE_RESET ENABLED true
    } else {
        set_parameter_property RX_DPA_USE_RESET ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_DPA_LOSE_LOCK_ON_ONE_CHANGE { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"] || [string_compare $mode "RX_Soft-CDR"] } {
        set_parameter_property RX_DPA_LOSE_LOCK_ON_ONE_CHANGE ENABLED true
    } else {
        set_parameter_property RX_DPA_LOSE_LOCK_ON_ONE_CHANGE ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_DPA_LOCKED_USED { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"] || [string_compare $mode "RX_Soft-CDR"] } {
        set_parameter_value RX_DPA_LOCKED_USED "true"
    } else {
        set_parameter_value RX_DPA_LOCKED_USED "false"
    }
}

proc ::altera_lvds::top::main::_validate_RX_DPA_USE_HOLD { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"]} {
        set_parameter_property RX_DPA_USE_HOLD ENABLED true
    } else {
        set_parameter_property RX_DPA_USE_HOLD ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_DPA_ALIGN_TO_RISING_EDGE_ONLY { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"] || [string_compare $mode "RX_Soft-CDR"] } {
        set_parameter_property RX_DPA_ALIGN_TO_RISING_EDGE_ONLY ENABLED true
    } else {
        set_parameter_property RX_DPA_ALIGN_TO_RISING_EDGE_ONLY ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_RX_CDR_SIMULATION_PPM_DRIFT { } {
    
    set mode [get_parameter_value MODE] 

        set_parameter_property RX_CDR_SIMULATION_PPM_DRIFT ENABLED false
}

proc ::altera_lvds::top::main::_validate_RX_FIFO_USE_RESET { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"] } {
        set_parameter_property RX_FIFO_USE_RESET ENABLED true
    } else {
        set_parameter_property RX_FIFO_USE_RESET ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_ENABLE_DIV_RECONFIG { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_DPA-FIFO"] || [string_compare $mode "RX_Soft-CDR"]} {
        set_parameter_property ENABLE_DIV_RECONFIG ENABLED true
    } else {
        set_parameter_property ENABLE_DIV_RECONFIG ENABLED false
    }
    
    if {[::altera_emif::util::qini::ini_is_on "lvds_enable_div_reconfig"]} { 
        set_parameter_property ENABLE_DIV_RECONFIG VISIBLE true
    } else {
        set_parameter_property ENABLE_DIV_RECONFIG VISIBLE false
    }
}


proc ::altera_lvds::top::main::_validate_TX_REGISTER_CLOCK { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "TX"] } {
        set_parameter_property TX_REGISTER_CLOCK ENABLED true
        set tx_reg_clock [get_parameter_value TX_REGISTER_CLOCK]
        set inclock_freq [get_parameter_value ACTUAL_INCLOCK_FREQUENCY]
        set rate [get_parameter_value DATA_RATE]
        set j_factor [get_parameter_value J_FACTOR]
        
        if {[string_compare $tx_reg_clock "inclock"]} {
            set expected_inclock_freq  [format "%.6f" [expr {double($rate)/$j_factor}]]
            emif_dbg 2 "inclock_freq = $inclock_freq"
            emif_dbg 2 "expected_inclock_freq = $expected_inclock_freq"
            if { $expected_inclock_freq != $inclock_freq } {
                set readable_expected_inclock_freq [format "%.2f" $expected_inclock_freq]
                send_message error "Since the inclock is used to clock the TX core registers, it must match the slow clock frequency. Data rate ($rate)/ Serialization Factor ($j_factor) = $readable_expected_inclock_freq." 
            }
        }
    } else {
        set_parameter_property TX_REGISTER_CLOCK ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_TX_USE_OUTCLOCK { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "TX"] } {
        set_parameter_property TX_USE_OUTCLOCK ENABLED true
    } else {
        set_parameter_property TX_USE_OUTCLOCK ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_TX_OUTCLOCK_PHASE_SHIFT { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "TX" ] && [param_string_compare TX_USE_OUTCLOCK "true"] } {
        set outclock_div [get_parameter_value TX_OUTCLOCK_DIVISION]
        set allowed_ranges "{0:[expr {$outclock_div*360-1}]}"
        set_parameter_property TX_OUTCLOCK_PHASE_SHIFT ENABLED true
        set_parameter_property TX_OUTCLOCK_PHASE_SHIFT ALLOWED_RANGES  $allowed_ranges

    } else {
        set_parameter_property TX_OUTCLOCK_PHASE_SHIFT ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_TX_OUTCLOCK_DIVISION { } {
    
    set mode [get_parameter_value MODE] 
    set data_width [get_parameter_value J_FACTOR]
    
    if {[string_compare $mode "TX" ] && [param_string_compare TX_USE_OUTCLOCK "true"] } {
        set_parameter_property TX_OUTCLOCK_DIVISION ENABLED true    
        if { $data_width == 10 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {2 10}    
        } elseif { $data_width == 9 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {9}    
        } elseif { $data_width == 8 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {2 4 8}  
        } elseif { $data_width == 7 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {7}  
        } elseif { $data_width == 6 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {2 6}
        } elseif { $data_width == 5 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {5}  
        } elseif { $data_width == 4 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {2 4} 
        } elseif { $data_width == 3 } {
                set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES {3}  
        }
    } else {
        set_parameter_property TX_OUTCLOCK_DIVISION ALLOWED_RANGES 1:10
        set_parameter_property TX_OUTCLOCK_DIVISION ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_TX_EXPORT_CORECLOCK { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "TX"] && ![get_parameter_value USE_EXTERNAL_PLL] } {
        set_parameter_property TX_EXPORT_CORECLOCK ENABLED true
    } else {
        set_parameter_property TX_EXPORT_CORECLOCK ENABLED false
    }
}


proc ::altera_lvds::top::main::_validate_PLL_USE_RESET { } {
    
    set use_external_pll [get_parameter_value USE_EXTERNAL_PLL]

    if { $use_external_pll } {
        set_parameter_property PLL_USE_RESET ENABLED true
    } else {
        set use_reset [get_parameter PLL_USE_RESET]
        if {[string_compare $use_reset "false"]} {
            send_message error "The pll_areset mode must be enabled for internal PLL mode."
        } else {
            set_parameter_property PLL_USE_RESET ENABLED false
        }
    }
}

proc ::altera_lvds::top::main::_validate_PLL_EXPORT_LOCK { } {
    
    set use_clock_pin [get_parameter_value USE_CLOCK_PIN]
    set use_external_pll [get_parameter_value USE_EXTERNAL_PLL]

    if { $use_external_pll || $use_clock_pin } {
        set_parameter_value PLL_EXPORT_LOCK "false"
    } else {
        set_parameter_value PLL_EXPORT_LOCK "true"
    }
}

proc ::altera_lvds::top::main::_validate_PLL_CORECLOCK_RESOURCE { } {
    
    set use_clock_pin [get_parameter_value USE_CLOCK_PIN]
    set use_external_pll [get_parameter_value USE_EXTERNAL_PLL]
    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]

    if { $use_clock_pin || $use_external_pll || [param_string_compare MODE "RX_Soft-CDR"] || ![string_compare $family "Arria 10"]} {
        set_parameter_property PLL_CORECLOCK_RESOURCE ENABLED false
    } else {
        set_parameter_property PLL_CORECLOCK_RESOURCE ENABLED true
    }
}



proc ::altera_lvds::top::main::_validate_PLL_SPEED_GRADE { } {
    
    set speedgrade [get_parameter_value SYS_INFO_DEVICE_SPEEDGRADE]
    
    if {[string_compare $speedgrade "Unknown"] || $speedgrade == ""} {
        set_parameter_value PLL_SPEED_GRADE 1
    } else {
        set_parameter_value PLL_SPEED_GRADE $speedgrade
    }
}

proc ::altera_lvds::top::main::_validate_ACTUAL_INCLOCK_FREQUENCY { } {
    
    set use_clock_pin [get_parameter_value USE_CLOCK_PIN]
    set use_external_pll [get_parameter_value USE_EXTERNAL_PLL]

    if { $use_external_pll} {
        set_parameter_property PLL_CORECLOCK_RESOURCE ENABLED false
    } 
    
    if {!([parameter_within_legal_range DATA_RATE] && [parameter_within_legal_range INCLOCK_FREQUENCY])} {
        return
    }
    
    if {$use_clock_pin} {
        set_parameter_value ACTUAL_INCLOCK_FREQUENCY [format "%.6f" [get_parameter_value DATA_RATE]]
    } else {
        set inclk_freq [get_parameter_value INCLOCK_FREQUENCY]
        set actual_refclks [calculate_actual_inclock_frequency \
                            [get_parameter_value DATA_RATE] \
                            $inclk_freq]
        set_parameter_value ACTUAL_INCLOCK_FREQUENCY [get_closest_val_to_target $actual_refclks $inclk_freq]
    }
}

proc ::altera_lvds::top::main::_validate_RX_INCLOCK_PHASE_SHIFT_ACTUAL { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "RX_Non-DPA"]} {
        set_parameter_property RX_INCLOCK_PHASE_SHIFT_ACTUAL ENABLED true
        
        if {[param_string_compare USE_CLOCK_PIN "true"]} {
            set_parameter_property RX_INCLOCK_PHASE_SHIFT_ACTUAL ALLOWED_RANGES {0 180}
        } else {   
            
            if {!([parameter_within_legal_range DATA_RATE] && [parameter_within_legal_range ACTUAL_INCLOCK_FREQUENCY]
                && [parameter_within_legal_range RX_INCLOCK_PHASE_SHIFT])} {
                return
            }
            
            set rate [get_parameter_value DATA_RATE]
            set fclk_frequency_double  [format "%.6f" $rate]
            set vco_freq [get_legal_vco $rate] 
            set inclock_shift_deg [get_parameter_value RX_INCLOCK_PHASE_SHIFT]

            set vco_period [freq_to_period $vco_freq]
            set min_phase_shift_granularity_ps [expr {double($vco_period)/8}]
            set min_phase_shift_granularity_deg [lindex [::altera_iopll_common::iopll::ps_to_degrees $min_phase_shift_granularity_ps $fclk_frequency_double] 0]
            regexp {([-0-9.]+)} $min_phase_shift_granularity_deg min_phase_shift_granularity_deg 
            emif_dbg 2 "Min RX Inclock phase shift granularity: $min_phase_shift_granularity_ps ps ($min_phase_shift_granularity_deg deg)"
            
            set allowed_range [get_parameter_property RX_INCLOCK_PHASE_SHIFT ALLOWED_RANGES]
            emif_dbg 2 "RX Inclock Phase Shift allowed_range: $allowed_range"
            set max_inclock_phase_shift [lindex [split $allowed_range :] 1]
            set legal_shift 0
            set phases_deg [list]
            while {$legal_shift < $max_inclock_phase_shift} {
                lappend phases_deg $legal_shift
                set legal_shift [expr {$legal_shift + $min_phase_shift_granularity_deg}]
            }
            emif_dbg 2 "Legal Inclock Phase Shifts (deg): $phases_deg"
            set_parameter_value RX_INCLOCK_PHASE_SHIFT_ACTUAL [get_closest_val_to_target $phases_deg $inclock_shift_deg]
        }   
    } else {
        set_parameter_property RX_INCLOCK_PHASE_SHIFT_ACTUAL ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_TX_OUTCLOCK_PHASE_SHIFT_ACTUAL { } {
    
    set mode [get_parameter_value MODE] 

    if {[string_compare $mode "TX" ] && [param_string_compare TX_USE_OUTCLOCK "true"] } {
        if {!([parameter_within_legal_range ACTUAL_INCLOCK_FREQUENCY] && [parameter_within_legal_range DATA_RATE])} {
            return
        }
        set_parameter_property TX_OUTCLOCK_PHASE_SHIFT_ACTUAL ENABLED true

        set rate [get_parameter_value DATA_RATE]
        set fclk_frequency_double  [format "%.6f" $rate]
        set vco_freq [get_legal_vco $rate]
        set tx_outclock_shift_deg [get_parameter_value TX_OUTCLOCK_PHASE_SHIFT]

        set vco_period [freq_to_period $vco_freq]
        set min_phase_shift_granularity_ps [expr {double($vco_period)/8}]
        set min_phase_shift_granularity_deg [lindex [::altera_iopll_common::iopll::ps_to_degrees $min_phase_shift_granularity_ps $fclk_frequency_double] 0]
        regexp {([-0-9.]+)} $min_phase_shift_granularity_deg min_phase_shift_granularity_deg 
        emif_dbg 2 "Min TX Outclock phase shift granularity: $min_phase_shift_granularity_ps ps ($min_phase_shift_granularity_deg deg)"
        
        set allowed_range [get_parameter_property TX_OUTCLOCK_PHASE_SHIFT ALLOWED_RANGES]
        emif_dbg 2 "TX Outclock Phase Shift allowed_range: $allowed_range"
        set max_outclock_phase_shift [lindex [split $allowed_range :] 1]
        set legal_shift 0
        set phases_deg [list]
        while {$legal_shift < $max_outclock_phase_shift} {
            lappend phases_deg $legal_shift
            set legal_shift [expr {$legal_shift + $min_phase_shift_granularity_deg}]
        }
        set_parameter_value TX_OUTCLOCK_PHASE_SHIFT_ACTUAL [get_closest_val_to_target $phases_deg $tx_outclock_shift_deg]
        emif_dbg 2 "New Legal Outclock Phase Shifts (deg): $phases_deg"

    } else {
        set_parameter_property TX_OUTCLOCK_PHASE_SHIFT_ACTUAL ENABLED false
    }
}

proc ::altera_lvds::top::main::_validate_TX_OUTCLOCK_NON_STD_PHASE_SHIFT { } {
    
    set outclock_shift_deg [get_parameter_value TX_OUTCLOCK_PHASE_SHIFT]
    if { $outclock_shift_deg % 180 == 0 } {
        set_parameter_value TX_OUTCLOCK_NON_STD_PHASE_SHIFT "false"
    } else { 
        set_parameter_value TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"
        if {[get_parameter_value NUM_CHANNELS] > 23} {
            send_message error "Cannot choose phase shifts that are not multiples of 180 for the TX outclock for designs that span multiple banks (wider than 23 channels)." 
        }
    }
}

proc ::altera_lvds::top::main::_validate_PORT_MAP_FILE_NAME { } {
    if {[param_string_compare MODE "TX"]} {
        set_parameter_value PORT_MAP_FILE_NAME "port_map_tx.csv"
    } else {
        set_parameter_value PORT_MAP_FILE_NAME "port_map_rx.csv"
    }
}

proc ::altera_lvds::top::main::retreive_pll_output_clocks_info {} {
    set mode [get_parameter_value MODE]
    set reference_list [list]

    set pll_compensation_mode "direct"
    if {[string_compare $mode "RX_Non-DPA"]} {
        set pll_compensation_mode "lvds"
    } 
    
    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]
    
    if {[string_compare $family "Arria 10"]} {
        set reference_list [add_pll_clock $reference_list [get_parameter_value pll_fclk_frequency] [get_parameter_value pll_fclk_phase_shift] 50]
        
        set reference_list [add_pll_clock $reference_list [get_parameter_value pll_loaden_frequency] [get_parameter_value pll_loaden_phase_shift] [get_parameter_value pll_loaden_duty_cycle]]
                            
        if {[param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"] && [string_compare $mode "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"]} {
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_tx_outclock_fclk_frequency] [get_parameter_value pll_tx_outclock_fclk_phase_shift] 50]
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_tx_outclock_loaden_frequency] [get_parameter_value pll_tx_outclock_loaden_phase_shift] [get_parameter_value pll_loaden_duty_cycle]]
        }
        set reference_list [add_pll_clock $reference_list [get_parameter_value pll_sclk_frequency] [get_parameter_value pll_sclk_phase_shift] 50]
        
        if {[param_string_compare ENABLE_DIV_RECONFIG "true"]} {
            set pll_dprio_clk_frequency [param_strip_units pll_sclk_frequency]
            set pll_dprio_clk_frequency [format "%.6f" [expr {double($pll_dprio_clk_frequency)/4}]]
            set_parameter_value pll_dprio_clk_frequency "$pll_dprio_clk_frequency MHz"
            
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_dprio_clk_frequency] "0 ps" 50]
        }
    } else {
        if {[param_string_compare TX_OUTCLOCK_NON_STD_PHASE_SHIFT "true"] && [string_compare $mode "TX"] && [param_string_compare TX_USE_OUTCLOCK "true"]} {
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_tx_outclock_fclk_frequency] [get_parameter_value pll_tx_outclock_fclk_phase_shift] 50]
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_tx_outclock_loaden_frequency] [get_parameter_value pll_tx_outclock_loaden_phase_shift] [get_parameter_value pll_loaden_duty_cycle]]
        } else {
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_fclk_frequency] [get_parameter_value pll_fclk_phase_shift] 50]
            set reference_list [add_pll_clock $reference_list [get_parameter_value pll_loaden_frequency] [get_parameter_value pll_loaden_phase_shift] [get_parameter_value pll_loaden_duty_cycle]]
        } 
        
        set reference_list [add_pll_clock $reference_list [get_parameter_value pll_fclk_frequency] [get_parameter_value pll_fclk_phase_shift] 50]
        set reference_list [add_pll_clock $reference_list [get_parameter_value pll_loaden_frequency] [get_parameter_value pll_loaden_phase_shift] [get_parameter_value pll_loaden_duty_cycle]]
        
        set reference_list [add_pll_clock $reference_list [get_parameter_value pll_sclk_frequency] [get_parameter_value pll_sclk_phase_shift] 50]
    }
	
    ::altera_iopll_common::iopll::set_pll_output_clocks_info $pll_compensation_mode $reference_list
}

proc ::altera_lvds::top::main::_init {} {
}

::altera_lvds::top::main::_init 
