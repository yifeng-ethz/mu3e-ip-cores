#

add_instance flash flash1616
set_instance_parameter_value flash {clockFrequency} [ expr int($nios_clk_mhz * 1e6) ]

nios_base.connect flash clk reset "" ""

add_connection                 cpu.data_master flash.uas
set_connection_parameter_value cpu.data_master/flash.uas        baseAddress {0x00000000}
add_connection                 cpu.instruction_master flash.uas
set_connection_parameter_value cpu.instruction_master/flash.uas baseAddress {0x00000000}

# reset vector
if 1 {
    set_instance_parameter_value cpu {resetSlave} {flash.uas}
    set_instance_parameter_value cpu {resetOffset} {0x05E40000}
}

add_interface flash conduit end
set_interface_property flash EXPORT_OF flash.out



# jtag master
if 1 {
    add_instance jtag_master altera_jtag_avalon_master

    add_connection clk.clk jtag_master.clk
    add_connection clk.clk_reset jtag_master.clk_reset

    add_connection jtag_master.master ram.s1
    add_connection jtag_master.master flash.uas
}
