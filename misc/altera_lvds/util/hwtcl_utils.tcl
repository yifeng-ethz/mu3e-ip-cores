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


package provide altera_lvds::util::hwtcl_utils 0.1
package require altera_emif::util::hwtcl_utils
package require altera_emif::util::qini
package require altera_emif::util::messaging


namespace eval ::altera_lvds::util::hwtcl_utils:: {
   namespace export add_user_param
   namespace export add_derived_param
   namespace export add_derived_hdl_param
   namespace export add_text_to_gui
   namespace export add_param_to_gui
   namespace export string_compare
   namespace export param_string_compare
   namespace export bit_rotate
   namespace export map_allowed_range 
   namespace export add_if 
   namespace export add_multi_port_if
   namespace export get_lvds_clock_shift_in_degrees
   namespace export strip_units
   namespace export param_strip_units
   namespace export freq_to_period 
   namespace export parameter_within_legal_range 
   namespace export abs_val_diff
   namespace export get_closest_val_to_target
   namespace export pretty_reference_list
   namespace export compare_with_tolerance
   namespace export dump_parameter_values
   namespace import ::altera_emif::util::messaging::*
   
}



if {[::altera_emif::util::qini::ini_is_on "enable_lvds_trace_debug"]} {
    rename proc _proc
    _proc proc {name arglist body} {
        _proc $name $arglist [concat "proc_start;" $body ";proc_end"]
    }
    
    _proc proc_start {} {
        uplevel {
            set proc_name [lindex [info level 0] 0]
            set spacing [string repeat "   " [info level]]
            
            puts stderr "$spacing >>> ENTER PROC [info level 0]"
            
            set argslist [info args $proc_name]
            if {[llength $argslist]} {
                puts stderr "$spacing ARGSLIST $argslist"
            }
            
        }
    }
    _proc proc_end {} {
        uplevel {
            puts stderr "$spacing <<< LEAVE PROC [lindex [info level 0] 0]"
        }
    }
    
    set excluded_cmds(proc) 1
    set excluded_cmds(proc_start) 1
    set excluded_cmds(proc_end) 1
    
    foreach proc_name [concat [info procs] [info commands add_*] [info commands get_*] [info commands set_*] [info commands create_*]] {
        if {![info exists excluded_cmds($proc_name)]} {
            set included_cmds($proc_name) 1
        }
    }
    
    foreach proc_name [array names included_cmds] {
        puts stderr "PROC $proc_name"
        interp hide {} $proc_name $proc_name
        proc $proc_name args {
            tailcall interp invokehidden {} $proc_name {*}$args
        }
    }
}

proc ::altera_lvds::util::hwtcl_utils::add_user_param {\
   name \
   type \
   default_val \
   allowed_ranges \
   {unit ""} \
   {display_hint ""} \
   {affects_validation true} \
   {visible true} \
} {
   set derived false
   set affects_elab true
   _add_parameter $name $type $default_val $derived $visible $affects_elab false $allowed_ranges $unit $display_hint $affects_validation
}

proc ::altera_lvds::util::hwtcl_utils::add_derived_param {\
   name \
   type \
   default_val \
   visible \
   {unit ""} \
   {display_hint ""} \
} {
   set derived true
   set affects_elab true
   set allowed_ranges ""
   _add_parameter $name $type $default_val $derived $visible $affects_elab false $allowed_ranges $unit $display_hint
}

proc ::altera_lvds::util::hwtcl_utils::add_derived_hdl_param {\
   name \
   type \
   default_val \
   {width 1} \
} {
   add_parameter $name $type $default_val
   set_parameter_property $name HDL_PARAMETER true
   set_parameter_property $name DERIVED true   
   set_parameter_property $name AFFECTS_ELABORATION false
   set_parameter_property $name WIDTH $width
   
   return 1
}



proc ::altera_lvds::util::hwtcl_utils::_add_parameter {\
   name \
   type \
   default_val \
   {derived false} \
   {visible true} \
   {affects_elab true} \
   {hdl false} \
   {allowed_ranges ""} \
   {unit ""} \
   {display_hint ""} \
   {affects_validation true} \
} {
   add_parameter $name $type $default_val
   
   if {$derived} {
      set_parameter_property $name DERIVED true
   }
   
   if {[string_compare $visible false]} {
      set_parameter_property $name VISIBLE false
   }
   
   if {!$affects_elab} {
      set_parameter_property $name AFFECTS_ELABORATION false
   }
      set_parameter_property $name AFFECTS_VALIDATION $affects_validation   

   if {$hdl} {
      set_parameter_property $name HDL_PARAMETER true
   }
   
   if {$allowed_ranges != ""} {
      set_parameter_property $name ALLOWED_RANGES $allowed_ranges
   }
   
   if {$unit != ""} {
      set_parameter_property $name UNITS $unit
   }

  if {$display_hint != ""} {
      set_parameter_property $name DISPLAY_HINT $display_hint
   }
      
   set_parameter_property $name DISPLAY_NAME [get_string PARAM_${name}_NAME]
   set_parameter_property $name DESCRIPTION [get_string PARAM_${name}_DESC]

   return 1
}

proc ::altera_lvds::util::hwtcl_utils::add_text_to_gui {\
   parent \
   text_name \
} {
   add_display_item $parent $text_name text [get_string TEXT_${text_name}]
}

proc ::altera_lvds::util::hwtcl_utils::add_param_to_gui {\
   parent \
   param_name \
} {
   add_display_item $parent $param_name PARAMETER
   return 1
}



proc ::altera_lvds::util::hwtcl_utils::add_if {\
   name \
   type \
   qsys_dir \
   dir \
   {width 0} \
   {term "none"}
} {
   set if_name "${name}_${type}_${qsys_dir}"

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
   } else {
        add_interface_port $if_name $name export $dir $width
   }

   set_port_property $name VHDL_TYPE $port_vhdl_type

   if { [string_compare $term "none"] == 0 } {
        set_port_property $name TERMINATION true
        set_port_property $name TERMINATION_VALUE $term
   }     
}

proc ::altera_lvds::util::hwtcl_utils::add_multi_port_if {\
   name \
   type \
   qsys_dir \
   dir \
   port_to_width_map_name \
   {term "none"}
} {
   set if_name "${name}_${type}_${qsys_dir}"

   add_interface $if_name $type $qsys_dir
   set_interface_property $if_name ENABLED false 
   
   set_interface_assignment $if_name "ui.blockdiagram.direction" $dir
   
   upvar 1 $port_to_width_map_name port_to_width_map

	foreach port [array names port_to_width_map] { 
		set width $port_to_width_map($port)
		   
		if { $width == 0 || $width == 1} {
			 set width 1
			 set port_vhdl_type STD_LOGIC
		} else {
			 set port_vhdl_type STD_LOGIC_VECTOR
		}

		if { $type == "clock" } {
			add_interface_port $if_name $port clk $dir $width
		} else {
			add_interface_port $if_name $port export $dir $width
		}

		set_port_property $port VHDL_TYPE $port_vhdl_type

		if { [string_compare $term "none"] == 0 } {
			set_port_property $port TERMINATION true
			set_port_property $port TERMINATION_VALUE $term
		}     
	}
}

proc ::altera_lvds::util::hwtcl_utils::string_compare {string_1 string_2} {
    return [expr {[string compare -nocase $string_1 $string_2] == 0}] 
}

proc ::altera_lvds::util::hwtcl_utils::param_string_compare {param str} {
   return [::altera_lvds::util::hwtcl_utils::string_compare [get_parameter_value $param] $str]
}


proc ::altera_lvds::util::hwtcl_utils::strip_units {with_units} {
    if {[regexp {([0-9\.]+)} $with_units no_units]} {
        return $no_units
    } else {
		return "N/A"
    }    
 }



proc ::altera_lvds::util::hwtcl_utils::param_strip_units {param} {
    return [strip_units [get_parameter_value $param]]
}



proc ::altera_lvds::util::hwtcl_utils::parameter_within_legal_range {param} {

    set param_type [get_parameter_property $param TYPE]
    set param_val [get_parameter_value $param]
    set param_legal_range [get_parameter_property $param allowed_ranges]
    
    if { $param_legal_range == ""} {
        return 1
    }
    
    if { [regexp {.+:.+} $param_legal_range] } {
        set min_max_range [split $param_legal_range ':']
        set min [lindex $min_max_range 0]
        set max [lindex $min_max_range 1]

        if {$param_val <= $max && $param_val >= $min} {
            return 1
        } else {
            return 0
        }
    } else {
        foreach legal_val $param_legal_range {
            if {[string_compare $param_type "STRING"] && [string_compare $param_val $legal_val]} {
                return 1
            } elseif {$param_val == $legal_val} {
                return 1
            }
        }
    }
    
    return 0
}

proc ::altera_lvds::util::hwtcl_utils::bit_rotate {word width num_bits} {
    set num_bits [expr {$num_bits % $width}]
    set word [expr {$word << $num_bits}]
    return [expr {($word + $word/(1<<($width)))%(1<<($width))}]
}

proc ::altera_lvds::util::hwtcl_utils::ps_str_to_deg_str {shift_ps period {modulo 360}} {

   set shift [strip_units $shift_ps]
   set per   [strip_units $period]

   return   "[expr {round($shift*360.0/$per)%$modulo}] degrees" 
}


proc ::altera_lvds::util::hwtcl_utils::get_clock_shift_in_degrees {freq_param phase_shift_param} {

    set freq [param_strip_units $freq_param]
    set period [freq_to_period $freq]
    set shift [get_parameter_value $phase_shift_param] 
    if { [regexp -lineanchor {^[0-9.]+} $shift] } {
        return [ps_str_to_deg_str $shift $period]
    } else {
        return "Not Computable"
    }    
}


proc ::altera_lvds::util::hwtcl_utils::get_lvds_clock_shift_in_degrees {param {clk_param ""} } {

    if { [string_compare $clk_param ""] } {
        set freq [param_strip_units "pll_${param}_frequency"]
    } else {
        set freq [param_strip_units "pll_${clk_param}_frequency"]
    }
    set period [freq_to_period $freq]

    set shift [get_parameter_value "pll_${param}_phase_shift"] 
    if { [regexp -lineanchor {^[0-9.]+} $shift] } {
        return [ps_str_to_deg_str $shift $period]
    } else {
        return "Not Computable"
    }    
}

proc ::altera_lvds::util::hwtcl_utils::generate_vhdl_sim {top_level top_level_mod_name encrypted_files} {
	set rtl_only 0
	set encrypted 1   

	set non_encryp_simulators [::altera_emif::util::hwtcl_utils::get_simulator_attributes 1]

	set file_paths $encrypted_files

	foreach file_path $file_paths {
		set tmp [file split $file_path]
		set file_name [lindex $tmp end]

		add_fileset_file $file_name [::altera_emif::util::hwtcl_utils::get_file_type $file_name $rtl_only 0] PATH $file_path $non_encryp_simulators

		add_fileset_file [file join mentor $file_name] [::altera_emif::util::hwtcl_utils::get_file_type $file_name $rtl_only $encrypted] PATH [file join mentor $file_path] {MENTOR_SPECIFIC}
	} 
    
    set all_simulators [::altera_emif::util::hwtcl_utils::get_simulator_attributes 0]
    set file_paths [::altera_emif::util::hwtcl_utils::generate_top_level_vhd_wrapper $top_level $top_level_mod_name]

    foreach file_path $file_paths {
        set tmp [file split $file_path]
        set file_name [lindex $tmp end]
        add_fileset_file $file_name [::altera_emif::util::hwtcl_utils::get_file_type $file_name $rtl_only 0] PATH $file_path $all_simulators
    } 
}

proc ::altera_lvds::util::hwtcl_utils::map_allowed_range { gui_param_name legal_values } {

  set current_symbol [get_parameter_value $gui_param_name]
  regsub -all {[^-A-Za-z_0-9 ]+} $current_value {.} current_value
  set sanitized_legal [list]
  foreach val $legal_values {
    regsub -all {[^-A-Za-z_0-9 ]+} $val {.} val
    lappend sanitized_legal $val
  }

  set allowed_range [list]
  set legal_value [lindex $sanitized_legal 0]
  if {[lsearch -exact $sanitized_legal $current_value ] >= 0 } {
    lappend allowed_range "$current_value"
  }

  foreach val $sanitized_legal {
    if {$val != $current_value} {
      lappend allowed_range "$val"
    }
  }
}


proc ::altera_lvds::util::hwtcl_utils::freq_to_period {freq} {

    if { [regexp {[0-9.]+} $freq] } {
        set freq [strip_units $freq]
        return [expr {entier(1000000/$freq)}]
    } else {
        return "N/A" 
    }
}


proc ::altera_lvds::util::hwtcl_utils::abs_val_diff {num1 num2} {

    if {$num1 > $num2} {
        return [expr $num1 - $num2]
    } else {
        return [expr $num2 - $num1]
    }
}


proc ::altera_lvds::util::hwtcl_utils::get_closest_val_to_target {numlist target} {

    set min_diff ""
    foreach num $numlist {
        set diff [abs_val_diff $num $target]
        if {$min_diff == "" || [expr $diff < $min_diff]} {
            set min_diff $diff
            set closest_num $num
        }
    }
    
    return $closest_num
}


proc ::altera_lvds::util::hwtcl_utils::pretty_reference_list {reference_list num_counters} {
    
    set reference_list_keys { \
        "DEVICE" \
        "SPEEDGRADE" \
        "PART" \
        "PLL TYPE" \
        "NUMBER OF COUNTERS" \
        "PLL CHANNEL SPACING" \
        "PLL FRACTIONAL VCO MULTIPLIER" \
        "PLL AUTO RESET" \
        "PLL BANDWIDTH PRESET" \
        "PLL COMPENSATION MODE" \
        "PLL FEEDBACK MODE" \
        "REFERENCE CLOCK FREQUENCY" \
        "PLL DESIRED VCO FREQUENCY" \
        "ADVANCED PARAM USED" \
    }
    
    set reference_list_dump "\nREFERENCE LIST:\n"
    
    for {set i 0} {$i < 14} {incr i} {
        append reference_list_dump "\t" [lindex $reference_list_keys $i] " => " [lindex $reference_list $i] "\n"
    }   
    
    for {set i 0} {$i < $num_counters} {incr i} {
        set ref_list_idx [expr {14 + 3*$i}]
        set freq_idx $ref_list_idx
        set ps_idx [expr {$ref_list_idx + 1}]
        set dc_idx [expr {$ref_list_idx + 2}]
        
        append reference_list_dump "\t" "OUTPUT FREQ $i" " => " [lindex $reference_list $freq_idx] "\n"
        append reference_list_dump "\t" "OUTPUT PHASE SHIFT $i" " => " [lindex $reference_list $ps_idx] "\n"
        append reference_list_dump "\t" "OUTPUT DUTY CYCLE $i" " => " [lindex $reference_list $dc_idx] "\n"
    }
    
    return $reference_list_dump
}


proc ::altera_lvds::util::hwtcl_utils::dump_parameter_values {} {
    
    global parameter_value_changes
    set caller_level [info level]

    if {$caller_level == 1} {
        set caller "::"
    } else {
        set caller_query_level -1
        if {[
            catch {
                for {set i 1} {$i < $caller_level} {incr i} {
                    set caller_name [eval {lindex [info level $i] 0}]
                }
            }
        ] != 0} {
            set caller_query_level [expr {$i - 1}]
        }
        if {$caller_query_level == 0} {
            emif_ie "Internal Error: Found caller level as $caller_query_level!"
        }
        
        set caller [lindex [info level $caller_query_level] 0]
        set caller_namespace [uplevel 1 "namespace current"]
        if {[regexp "^\s*${caller_namespace}" $caller match] == 0} {
            set caller "${caller_namespace}::$caller"
        }
    }
     
    emif_dbg 2 "########## START $caller PARAMETER VALUE DUMP ##########"
    foreach param [get_parameters] {
        if {[get_parameter_property $param DERIVED]} {
            set param_string "(DERIVED) $param"
        } else {
            set param_string "(USER) $param"
        }
        set new_val [get_parameter_value $param]
        if {[info exists parameter_value_changes($param)]} {
            set prev_val_idx [expr {[llength $parameter_value_changes($param)] - 1}]
            set prev_val [lindex $parameter_value_changes($param) $prev_val_idx]
            
            while {$prev_val == "-"} {
                set prev_val_idx [expr {$prev_val_idx - 1}]
                set prev_val [lindex $parameter_value_changes($param) $prev_val_idx]
            }
            
            
            if {$prev_val == $new_val} {
                lappend parameter_value_changes($param) "-"
            } else {
                lappend parameter_value_changes($param) $new_val
                emif_dbg 2 "$param_string : $prev_val -> $new_val"
            }
        } else {
            set new_val [get_parameter_value $param]
            lappend parameter_value_changes($param) $new_val
            emif_dbg 2 "$param_string : $new_val"
        }
    }
    
    emif_dbg 2 "########### END $caller PARAMETER VALUE DUMP ###########"
}


proc ::altera_lvds::util::hwtcl_utils::compare_with_tolerance {num1 num2 tolerance_percentage} {

    emif_dbg 4 "compare_with_tolerance $num1 $num2 $tolerance_percentage"
    set tolerance_factor [expr {double($tolerance_percentage) / 100 }]
    emif_dbg 4 "tolerance_factor = $tolerance_factor"
    set tolerance [expr {$tolerance_factor * $num1}]
    emif_dbg 4 "tolerance = $tolerance"
    set upper_bound [expr {$num1 + $tolerance}]
    set lower_bound [expr {$num1 - $tolerance}]
    emif_dbg 4 "Bounds: ($lower_bound,$upper_bound)"
    
    if {$num2 <= $upper_bound && $num2 >= $lower_bound} {
        return 1
    } else {
        return 0
    }
}


proc ::altera_lvds::util::hwtcl_utils::_init {} {
}

::altera_lvds::util::hwtcl_utils::_init
