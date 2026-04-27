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


package provide altera_lvds::top::pll 0.1

package require altera_lvds::util::hwtcl_utils
package require quartus::advanced_pll_legality
package require ::quartus::pll::legality

namespace eval ::altera_lvds::top::pll:: {
    
    namespace import ::altera_lvds::util::hwtcl_utils::*
    namespace import ::altera_emif::util::messaging::*

    namespace export get_pll_spec
    namespace export calculate_actual_inclock_frequency
    namespace export get_legal_vco
    namespace export add_pll_clock
}



proc ::altera_lvds::top::pll::calculate_actual_inclock_frequency {rate refclk} {

    set F_PFD_MAX [get_pll_spec PFD_MAX]  
    set F_PFD_MIN [get_pll_spec PFD_MIN]
    set F_VCO_MAX [get_pll_spec VCO_MAX]
    set F_VCO_MIN [get_pll_spec VCO_MIN]

   
    set target_vco [get_legal_vco $rate]


    set MAX_N [expr {int(floor($refclk/$F_PFD_MIN))}]
    set MIN_N [expr {int(ceil($refclk/$F_PFD_MAX))}]
    set MAX_M 1024
    set MIN_M 4
    set index 0 
    
    set best_rational [_get_best_rational_for_pll [expr {double($target_vco)/$refclk}] \
                                                  $MAX_M $MAX_N $MIN_N $MIN_M]  

    for {set index 0} { $index < [llength $best_rational] } {incr index} {
        set m_n_pair [lindex $best_rational [expr {([llength $best_rational]) - $index - 1 }]] 
        set m_counter [lindex $m_n_pair 0]
        set n_counter [lindex $m_n_pair 1]
        lappend actual_refclks [format "%.6f" [expr {double($target_vco)*$n_counter/$m_counter}]]
     } 
     
     return $actual_refclks
}


proc ::altera_lvds::top::pll::get_legal_vco { data_rate } {

    set F_VCO_MIN [get_pll_spec VCO_MIN]
    set F_VCO_MAX [get_pll_spec VCO_MAX]


    if {$F_VCO_MIN > $data_rate} {
        set found 0
        for {set factor 2} { !$found && $factor <= 128 } { set factor [expr {$factor * 2}] } {
            if {[expr {$factor * $data_rate}] >= $F_VCO_MIN} {
                set found 1
                break
            }
        }
        
        set target_vco [format "%.6f" [expr {$factor*$data_rate}]]
        if {!$found || $target_vco > $F_VCO_MAX} {
            send_message error "Cannot find a legal VCO frequency for this data rate."
        }
    } elseif {$F_VCO_MAX < $data_rate} {
        set speedgrade [get_parameter_value PLL_SPEED_GRADE]
        send_message error "Data rate \"$data_rate\"MHz is higher than max VCO frequency of the PLL. Try using a faster speed grade."
        set target_vco $data_rate
    } else {
        set target_vco $data_rate
    } 
    return $target_vco
}




proc ::altera_lvds::top::pll::get_pll_spec { spec } {
    set speedgrade [get_parameter_value PLL_SPEED_GRADE]
    set family [get_parameter_value SYS_INFO_DEVICE_FAMILY]
    
    set pll_compensation_mode "direct"
    if {[string_compare [get_parameter_value MODE] "RX_Non-DPA"]} {
        set pll_compensation_mode "lvds"
    }
    
    set ref_list [list  -family $family \
                        -type "IOPLL" \
                        -speedgrade $speedgrade \
                        -is_fractional false \
                        -compensation_mode $pll_compensation_mode]

    if {[string_compare $spec PFD_MAX]} {
        return 325.000000
    } elseif {[string_compare $spec PFD_MIN]} {
        return 10.000000
    } elseif {[string_compare $spec VCO_MAX] || [string_compare $spec VCO_MIN]} {
        array set result_array [::quartus::pll::legality::get_legal_vco_range $ref_list]
        set vco_min $result_array(vco_min)
        set vco_max $result_array(vco_max)
        
        if {[string_compare $spec VCO_MAX]} {
            return $vco_max
        } else {
            return $vco_min
        }
    } elseif {[string_compare $spec REF_MAX] || [string_compare $spec REF_MIN]} {
        array set result_array [::quartus::pll::legality::get_legal_refclk_range $ref_list]
        set refclk_min $result_array(refclk_min)
        set refclk_max $result_array(refclk_max)
        
        if {[string_compare $spec REF_MAX]} {
            return $refclk_max
        } else {
            return $refclk_min
        }
    }
   
   return -1
}




proc ::altera_lvds::top::pll::_get_reference_item {item} {


    if {[string_compare $item "speed"]} {
        return get_parameter_value PLL_SPEED_GRADE
    } elseif {[string_compare $item "device_part"]} {
        set device [get_parameter_value SYS_INFO_DEVICE]
        if {[string_compare $device "Unknown"]} {
			set device "10AS066H2F34I1SGES"
		}
        return $device
    } elseif {[string_compare $item "pll_type"]} {
        return "fPLL"
    } elseif {[string_compare $item "channel_spacing"]} {
        return "0.0 MHz"
    } elseif {[string_compare $item "fractional_vco_multiplier"]} {
        return "false"
    }    

    return ""
} 


proc ::altera_lvds::top::pll::_get_best_rational_for_pll {   dbl        \
                                                    {max_m 1024}    \
                                                    {max_n 1024}    \
                                                    {min_n 1   }    \
                                                    {min_m 4   }    \
                                                    {precision 0.0000005}} {
    set min_err dbl
    set result "" 
    
    for {set n $min_n} {$n <= $max_n} {incr n} {
        set m [expr {round($dbl*$n)}]
        if {$m < $min_m} {
            continue
        }
        if {[expr {abs(double($m)/$n - $dbl)}] < $precision && $m <= $max_m } {
        return [list [list $m $n]]
        } elseif {[expr {abs(double($m)/$n - $dbl)}] < $min_err && $m <= $max_m  } {
            set min_err [expr abs(double($m)/$n - $dbl)]
            lappend result [list $m $n]
        } elseif { $m > $max_m } {
            break
        }    
    }     
    return $result
}    


proc ::altera_lvds::top::pll::add_pll_clock {reference_list frequency phase_shift duty_cycle} {
    
    lappend reference_list $frequency
    lappend reference_list $phase_shift
    lappend reference_list $duty_cycle
    
    emif_dbg 2 "Adding clock with frequency:$frequency phase_shift:$phase_shift duty_cycle:$duty_cycle"
    
    return $reference_list
}

    


proc ::altera_lvds::top::pll::_init {} {
}

::altera_lvds::top::pll::_init

