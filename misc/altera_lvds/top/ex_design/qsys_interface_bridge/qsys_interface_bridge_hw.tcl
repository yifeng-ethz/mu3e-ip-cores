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

proc add_user_param {\
    name \
    type \
    default_val \
    {allowed_ranges ""}\
    {unit ""} \
    {display_hint ""} \
    {affects_validation true} \
    {visible true} \
} {
    set derived false
    set affects_elab true
    _add_parameter $name $type $default_val $derived $visible $affects_elab false $allowed_ranges $unit $display_hint $affects_validation
}

proc add_derived_param {\
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

proc _add_parameter {\
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

    set_parameter_property $name DISPLAY_NAME $name
    set_parameter_property $name DESCRIPTION ""

    return 1
}

proc add_param_to_gui {\
   parent \
   param_name \
} {
   add_display_item $parent $param_name PARAMETER
   return 1
}

proc create_parameters {} {
    add_user_param      INTERFACES                              STRING_LIST ""              ""                      ""                              "WIDTH:500"                            true
    add_user_param      PORTS                                   STRING_LIST ""              ""                      ""                              "WIDTH:500"                            true
    add_user_param      CONNECTIONS                             STRING_LIST ""              ""                      ""                              "WIDTH:500"                            true
    add_user_param      CUSTOM_ELABORATION_COMMANDS             STRING_LIST ""              ""                      ""                              "WIDTH:500"                            true
}

proc add_display_items {} {
    add_display_item "" INTERFACES_TEXT text {INTERFACE SYNTAX: <name> <type> <direction> [<associated_clock>]}
    add_param_to_gui "" INTERFACES
    
    add_display_item "" PORTS_TEXT text {PORT SYNTAX: <interface> <port> [<signal_type> <direction> <width_expression>]}
    add_param_to_gui "" PORTS
    
    add_display_item "" CONNECTIONS_TEXT text {CONNECTIONS SYNTAX: <source_port> <destination_port>}
    add_param_to_gui "" CONNECTIONS
    
    set custom_elab_text {Custom elaboration commands allow you to set specific interface properties. Example: set_interface_property reset associatedClock "clock1"}
    add_display_item "" CUSTOM_ELABORATION_COMMANDS_TEXT text $custom_elab_text
    add_param_to_gui "" CUSTOM_ELABORATION_COMMANDS
}

proc elaborate {} {
    foreach interface [get_parameter_value INTERFACES] {
        add_interface {*}$interface
    }
    
    foreach interface_port [get_parameter_value PORTS] {
        add_interface_port {*}$interface_port
    }
    
    foreach command [get_parameter_value CUSTOM_ELABORATION_COMMANDS] {
        {*}$command
    }
}

proc generate { output_name } {
    set port_list ""
    set ports [get_module_ports]
    foreach port $ports {
        set direction [string tolower [get_port_property $port DIRECTION]]
        set width_val [get_port_property $port WIDTH_VALUE]
        
        if {$width_val > 1} {
            set end   [expr {$width_val - 1}]
            set range "\[$end:0\]"
        } else {
            set range ""
        }
        
        append port_list "    $direction wire $range $port"
        
        if {![string_compare $port [lindex $ports end]]} {
            append port_list ", \n"
        } else {
            append port_list "\n"
        }
    }
    
    set assignment_list ""
    foreach connection [get_parameter_value CONNECTIONS] {
        set source [lindex $connection 0]
        set dest   [lindex $connection 1]
        append assignment_list "    assign $dest = $source; \n"
    }
    
    set verilog_body ""
    append verilog_body "module ${output_name} (\n"
    append verilog_body "$port_list"
    append verilog_body ");\n"
    append verilog_body "$assignment_list"
    append verilog_body "endmodule"
    
    add_fileset_file "${output_name}.v" VERILOG TEXT $verilog_body
}

set_module_property DESCRIPTION ""
set_module_property NAME qsys_interface_bridge
set_module_property VERSION 1.0
set_module_property INTERNAL true
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME qsys_interface_bridge
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false

set_module_property ELABORATION_CALLBACK elaborate
set_module_property AUTHOR "Altera Corporation"

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH generate
add_fileset SIM_VERILOG SIM_VERILOG generate

create_parameters
add_display_items