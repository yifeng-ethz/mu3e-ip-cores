#

package require qsys

set name "avalon_spi_master"

set_module_property NAME $name
set_module_property GROUP {vhdutil}

set_module_property VERSION 1.1
set_module_property DESCRIPTION ""
set_module_property AUTHOR "Alexandr Kozlinskiy"

#
add_parameter DATA_WIDTH INTEGER 8
set_parameter_property DATA_WIDTH DISPLAY_NAME "Data width"
set_parameter_property DATA_WIDTH ALLOWED_RANGES {8,16,32}
set_parameter_property DATA_WIDTH HDL_PARAMETER {true}

add_parameter FIFO_ADDR_WIDTH INTEGER 4
set_parameter_property FIFO_ADDR_WIDTH DISPLAY_NAME "FIFO address width"
set_parameter_property FIFO_ADDR_WIDTH ALLOWED_RANGES {1:32}
set_parameter_property FIFO_ADDR_WIDTH HDL_PARAMETER {true}

add_fileset synth QUARTUS_SYNTH generate
proc generate { name } {
    set temp_file [ create_temp_file $name.vhd ]

    set in [ open avalon_spi_master.vhd r ]
    set out [ open $temp_file w ]
    while { [ gets $in line ] != -1 } {
        # set entity name
        set line [ regsub -- avalon_spi_master $line $name ]

        puts $out $line
    }
    close $in
    close $out

    add_fileset_file $name.vhd VHDL PATH $temp_file
}

#
set_module_property ELABORATION_CALLBACK elaborate
proc elaborate {} {
    set dataWidth [ get_parameter_value DATA_WIDTH ]
    set fifoAddressWidth [ get_parameter_value FIFO_ADDR_WIDTH ]

    # clock
    add_interface clk clock end
    set_interface_property clk clockRate 0
    add_interface_port clk clk clk Input 1
    # reset
    add_interface reset reset end
    set_interface_property reset associatedClock clk
    add_interface_port reset reset reset Input 1

    # spi
    add_interface spi conduit end
    add_interface_port spi sclk sclk Output 1
    add_interface_port spi sdo sdo Output 1
    add_interface_port spi sdi sdi Input 1
    add_interface_port spi ss_n ss_n Output 32

    # avalon slave
    set name {slave}
    add_interface $name avalon slave
    set_interface_property $name associatedClock clk
    set_interface_property $name associatedReset reset
    set_interface_property $name addressUnits WORDS
    set_interface_property $name readLatency 1

    set prefix {avs}
    add_interface_port $name ${prefix}_address address Input 2
    add_interface_port $name ${prefix}_read read Input 1
    add_interface_port $name ${prefix}_readdata readdata Output 32
    add_interface_port $name ${prefix}_write write Input 1
    add_interface_port $name ${prefix}_writedata writedata Input 32
    add_interface_port $name ${prefix}_waitrequest waitrequest Output 1
}
