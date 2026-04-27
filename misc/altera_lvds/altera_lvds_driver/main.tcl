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


package provide altera_lvds::driver::main 0.1

package require altera_lvds::top::export
package require altera_lvds::util::hwtcl_utils  

namespace eval ::altera_lvds::driver::main:: {
   
   namespace import ::altera_lvds::top::export::*
   namespace import ::altera_lvds::util::hwtcl_utils::*
   namespace import ::altera_emif::util::hwtcl_utils::generate_top_level_sv_wrapper
   namespace import ::altera_emif::util::hwtcl_utils::get_file_type

   
   variable top_level_mod_name "altera_lvds_driver"
}



proc ::altera_lvds::driver::main::create_parameters {} {
     
    ::altera_lvds::top::export::inherit_top_level_parameter_defs
    
    add_derived_param   VCO_DIV_EXPONENT                        integer     0               false
    add_derived_param   VCO_FREQUENCY                           integer     0               false
    add_derived_param   EXTERNAL_PLL                            string      "false"         false
    
    add_derived_hdl_param   TX_OUTCLOCK_ENABLED                 string      "false"
    add_derived_hdl_param   REFCLK_PERIOD                       integer     0
    
    set driver_param_list [list MODE \
                                J_FACTOR \
                                TX_OUTCLOCK_DIVISION \
                                TX_OUTCLOCK_PHASE_SHIFT \
                                TX_OUTCLOCK_NON_STD_PHASE_SHIFT \
                                NUM_CHANNELS \
                                pll_inclock_frequency \
                                pll_fclk_frequency \
                                pll_sclk_frequency \
                                pll_sclk_phase_shift \
                                pll_fclk_phase_shift\
                                ]
    
    foreach param $driver_param_list {
        set_parameter_property $param HDL_PARAMETER true
    }
    
    return 1
}

proc ::altera_lvds::driver::main::add_if_short {\
   name \
   type \
   qsys_dir \
   dir \
   {width 0} \
   {term "none"}
} {
   set if_name $name

   add_interface $if_name $type $qsys_dir
   set_interface_property $if_name ENABLED false 
   
   set_interface_assignment $if_name "ui.blockdiagram.direction" $dir

   if { $width == 0 } {
         set width 1
         set port_vhdl_type STD_LOGIC
   } else {
         set port_vhdl_type STD_LOGIC_VECTOR
   }
   
   if { $type == "clock" } {
        add_interface_port $if_name $name clk $dir $width
   } elseif { $type == "reset" } {
        set_interface_property $if_name synchronousEdges None
        add_interface_port $if_name $name reset $dir $width
   } else {
        add_interface_port $if_name $name export $dir $width
   }

   set_port_property $name VHDL_TYPE $port_vhdl_type

   if { [string_compare $term "none"] == 0 } {
        set_port_property $name TERMINATION true
        set_port_property $name TERMINATION_VALUE $term
   }     
}

proc ::altera_lvds::driver::main::elaboration_callback {} {

    set data_width [get_parameter_value J_FACTOR]
    set lvds_interface_width [get_parameter_value NUM_CHANNELS]
    set parallel_interface_width [expr $data_width*$lvds_interface_width]
    set mode [get_parameter_value MODE]
    
    if {[get_parameter_value USE_EXTERNAL_PLL]} {
        set_parameter_value EXTERNAL_PLL "true"
    } else {
        set_parameter_value EXTERNAL_PLL "false"
    }
    
    if { [param_string_compare TX_USE_OUTCLOCK "true"] } {
        set_parameter_value TX_OUTCLOCK_ENABLED "true"
    } else {
        set_parameter_value TX_OUTCLOCK_ENABLED "false"
    }
    
    set inclock_freq [get_parameter_value ACTUAL_INCLOCK_FREQUENCY]
    set_parameter_value REFCLK_PERIOD [freq_to_period $inclock_freq]
    
    add_if_short pll_areset conduit end Output
    add_if_short pll_locked conduit end Input
    add_if_short dpahold conduit end Output $lvds_interface_width
    add_if_short dparst conduit end Output $lvds_interface_width
    add_if_short fiforst conduit end Output $lvds_interface_width
    add_if_short par_in conduit end Output $parallel_interface_width
    add_if_short bslipcntl conduit end Output $lvds_interface_width
    add_if_short bsliprst conduit end Output $lvds_interface_width
    add_if_short lock conduit end Input $lvds_interface_width
    add_if_short bslipmax conduit end Input $lvds_interface_width
    add_if_short par_out conduit end Input $parallel_interface_width
    add_if_short lvdsin conduit end Output $lvds_interface_width
    add_if_short lvdsout conduit end Input $lvds_interface_width
    add_if_short pclk conduit end Input $lvds_interface_width
    add_if_short tx_outclock conduit end Input
    add_if_short coreclock conduit end Input
    add_if_short refclk conduit end Output
    add_if_short ext_refclk clock source Output
    add_if_short ext_reset reset source Output
    add_if_short ext_coreclock clock source Output
    add_if_short ext_fclk conduit end Output
    add_if_short ext_loaden conduit end Output
    add_if_short ext_tx_outclock_fclk conduit end Output
    add_if_short ext_tx_outclock_loaden conduit end Output
    add_if_short ext_vcoph conduit end Output 8
    add_if_short ext_pll_locked conduit end Output
    
    add_if_short user_mdio_dis           conduit end Output
    add_if_short user_dprio_rst_n        conduit end Output
    add_if_short user_dprio_read         conduit end Output
    add_if_short user_dprio_reg_addr     conduit end Output 9
    add_if_short user_dprio_write        conduit end Output
    add_if_short user_dprio_writedata    conduit end Output 8
    add_if_short user_dprio_clk          conduit end Input
    add_if_short user_dprio_block_select conduit end Input
    add_if_short user_dprio_readdata     conduit end Input 8
    add_if_short user_dprio_ready        conduit end Input
    
    if {[param_string_compare USE_EXTERNAL_PLL "false"]} {
        set_interface_property refclk ENABLED true
        set_interface_property coreclock ENABLED true
    } else {
        set_interface_property ext_refclk ENABLED true
        set_interface_property ext_reset ENABLED true
        set_interface_property coreclock ENABLED true
        set_interface_property pll_locked ENABLED true
        
        if {[string_compare $mode "TX"] && [param_string_compare TX_REGISTER_CLOCK "inclock"]} {
            set_interface_property refclk ENABLED true
        }
    }
        
    if {[param_string_compare PLL_USE_RESET "true"]} {
        set_interface_property pll_areset ENABLED true
    }

    if {[param_string_compare MODE "TX"]} {
        set_interface_property par_in ENABLED true
        set_interface_property lvdsout ENABLED true
        if { [param_string_compare TX_USE_OUTCLOCK "true"] } {
            set_interface_property tx_outclock ENABLED true
        }
    } else {
        set_interface_property lvdsin ENABLED true
        set_interface_property par_out ENABLED true
        
        set use_bitslip [param_string_compare RX_USE_BITSLIP "true"]
        
        if { $use_bitslip } {
            set_interface_property bslipcntl ENABLED true
        }
        
        if { $use_bitslip && [param_string_compare RX_BITSLIP_ASSERT_MAX "true"] } {
            set_interface_property bslipmax ENABLED true
        }
        
        if { [param_string_compare RX_BITSLIP_USE_RESET "true"] && $use_bitslip } {
            set_interface_property bsliprst ENABLED true
        }
        if {[param_string_compare MODE "RX_DPA-FIFO"] || [param_string_compare MODE "RX_Soft-CDR"]} {   
            set_interface_property dparst ENABLED true
            set_interface_property lock ENABLED true
            
            if {[param_string_compare ENABLE_DIV_RECONFIG "true"]} {
                set_interface_property user_mdio_dis           ENABLED true
                set_interface_property user_dprio_clk          ENABLED true
                set_interface_property user_dprio_rst_n        ENABLED true
                set_interface_property user_dprio_read         ENABLED true
                set_interface_property user_dprio_reg_addr     ENABLED true
                set_interface_property user_dprio_write        ENABLED true
                set_interface_property user_dprio_writedata    ENABLED true
                set_interface_property user_dprio_block_select ENABLED true
                set_interface_property user_dprio_readdata     ENABLED true
                set_interface_property user_dprio_ready        ENABLED true
            }
        }
        if {[param_string_compare MODE "RX_Soft-CDR"]} {  
            set_interface_property pclk ENABLED true
        }
    }

    if {[param_string_compare PLL_EXPORT_LOCK "true"] 
        && [param_string_compare USE_EXTERNAL_PLL "false"] 
        && [param_string_compare USE_CLOCK_PIN "false"] } {
        
        set_interface_property pll_locked ENABLED true
    }

    return 1
}

proc ::altera_lvds::driver::main::sim_vhdl_fileset_callback {top_level} {
    variable top_level_mod_name
    ::altera_lvds::util::hwtcl_utils::generate_vhdl_sim $top_level $top_level_mod_name [list altera_lvds_driver.sv]
}

proc ::altera_lvds::driver::main::sim_verilog_fileset_callback {top_level} {
    
    variable top_level_mod_name
    set rtl_only 0
    set encrypted 0
    
    set file_paths [concat [::altera_emif::util::hwtcl_utils::generate_top_level_sv_wrapper $top_level $top_level_mod_name] \
                           altera_lvds_driver.sv ]
    
    foreach file_path $file_paths {
        set tmp [file split $file_path]
        set file_name [lindex $tmp end]
        add_fileset_file $file_name [::altera_emif::util::hwtcl_utils::get_file_type $file_name $rtl_only $encrypted] PATH $file_path
    }
}


proc ::altera_lvds::driver::main::_init {} {
}

::altera_lvds::driver::main::_init
