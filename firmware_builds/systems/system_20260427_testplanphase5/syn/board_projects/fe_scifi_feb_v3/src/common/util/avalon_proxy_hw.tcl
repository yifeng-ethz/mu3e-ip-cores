#

package require qsys

set name "avalon_proxy"

set_module_property NAME $name
set_module_property GROUP {mu3e}

set_module_property VERSION 1.1
set_module_property DESCRIPTION ""
set_module_property AUTHOR "Alexandr Kozlinskiy"

#
add_parameter DATA_WIDTH INTEGER 32
set_parameter_property DATA_WIDTH DISPLAY_NAME "Data width"
set_parameter_property DATA_WIDTH ALLOWED_RANGES {8,16,32}
set_parameter_property DATA_WIDTH HDL_PARAMETER {true}

add_parameter ADDRESS_UNITS INTEGER 8
set_parameter_property ADDRESS_UNITS DISPLAY_NAME "Address units"
set_parameter_property ADDRESS_UNITS ALLOWED_RANGES {8,32}
set_parameter_property ADDRESS_UNITS UNITS BITS

add_parameter ADDRESS_WIDTH INTEGER 32
set_parameter_property ADDRESS_WIDTH DISPLAY_NAME "Address width"
set_parameter_property ADDRESS_WIDTH ALLOWED_RANGES {1:32}
set_parameter_property ADDRESS_WIDTH HDL_PARAMETER {true}

add_parameter USE_READ_DATA_VALID BOOLEAN false
set_parameter_property USE_READ_DATA_VALID DISPLAY_NAME "Use 'readdatavalid' signal"

add_parameter READ_LATENCY INTEGER 0
set_parameter_property READ_LATENCY DISPLAY_NAME "Read latency"
set_parameter_property READ_LATENCY UNITS CYCLES

#
add_fileset synth QUARTUS_SYNTH generate
proc generate { name } {
    set temp_file [ create_temp_file $name.vhd ]

    set in [ open avalon_proxy.vhd r ]
    set out [ open $temp_file w ]
    while { [ gets $in line ] != -1 } {
        # set entity name
        set line [ regsub -- avalon_proxy $line $name ]

        if { [ get_parameter_value USE_READ_DATA_VALID ] } {
            # enable readdatavalid signal
            set line [ regsub -- "--{RDV}" $line "" ]
        }

        puts $out $line
    }
    close $in
    close $out

    add_fileset_file $name.vhd VHDL PATH $temp_file
}

#
set_module_property VALIDATION_CALLBACK validate
proc validate {} {
    set_parameter_property ADDRESS_UNITS ALLOWED_RANGES {8,32}
    if { [ get_parameter_value DATA_WIDTH ] < 32 } {
        set_parameter_property ADDRESS_UNITS ALLOWED_RANGES {8}
    }

    set_parameter_property ADDRESS_WIDTH ALLOWED_RANGES {1:32}
    if { [ get_parameter_value ADDRESS_UNITS ] == 32 } {
        set_parameter_property ADDRESS_WIDTH ALLOWED_RANGES {1:30}
    }

    set_parameter_property READ_LATENCY ENABLED true
    if { [ get_parameter_value USE_READ_DATA_VALID ] } {
        set_parameter_property READ_LATENCY ENABLED false
    }
}

#
set_module_property ELABORATION_CALLBACK elaborate
proc elaborate {} {
    set dataWidth [ get_parameter_value DATA_WIDTH ]
    if { [ get_parameter_value ADDRESS_UNITS ] == 32 } {
        set addressUnits WORDS
    } else {
        set addressUnits SYMBOLS
    }
    set addressWidth [ get_parameter_value ADDRESS_WIDTH ]
    set readLatency [ get_parameter_value READ_LATENCY ]

    # clock
    add_interface clk clock end
    set_interface_property clk clockRate 0
    add_interface_port clk clk clk Input 1
    # reset
    add_interface reset reset end
    set_interface_property reset associatedClock clk
    add_interface_port reset reset reset Input 1

    # avalon slave
    set name {slave}
    add_interface $name avalon slave
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset reset
    set_interface_property $name addressUnits $addressUnits
    if { [ get_parameter_value USE_READ_DATA_VALID ] eq "false" } {
        set_interface_property $name readLatency $readLatency
    }

    set prefix {avs}
    add_interface_port $name ${prefix}_address address Input $addressWidth
    add_interface_port $name ${prefix}_read read Input 1
    add_interface_port $name ${prefix}_readdata readdata Output $dataWidth
    add_interface_port $name ${prefix}_write write Input 1
    add_interface_port $name ${prefix}_writedata writedata Input $dataWidth
    add_interface_port $name ${prefix}_waitrequest waitrequest Output 1

    # conduit master
    set name {master}
    add_interface $name avalon master
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset reset
    set_interface_property $name addressUnits $addressUnits
    if { [ get_parameter_value USE_READ_DATA_VALID ] eq "false" } {
        set_interface_property $name readLatency $readLatency
    }

    set prefix {avm}
    add_interface_port $name ${prefix}_address address Output $addressWidth
    add_interface_port $name ${prefix}_read read Output 1
    add_interface_port $name ${prefix}_readdata readdata Input $dataWidth
    add_interface_port $name ${prefix}_write write Output 1
    add_interface_port $name ${prefix}_writedata writedata Output $dataWidth
    add_interface_port $name ${prefix}_waitrequest waitrequest Input 1
}
