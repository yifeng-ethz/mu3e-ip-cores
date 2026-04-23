# qsys scripting (.tcl) file for feb_bringup_system
package require -exact qsys 18.1

create_system {feb_bringup_system}

set repo_dir [pwd]
set mem_init_file [file join $repo_dir board_projects fe_scifi_feb_v3 generated software app mem_init nios_ram.hex]

set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

# Instances and instance parameters
add_instance clk clock_source 18.1
set_instance_parameter_value clk {clockFrequency} {50000000.0}
set_instance_parameter_value clk {clockFrequencyKnown} {1}
set_instance_parameter_value clk {resetSynchronousEdges} {DEASSERT}

add_instance cpu altera_nios2_gen2 18.1
set_instance_parameter_value cpu {impl} {Tiny}
set_instance_parameter_value cpu {resetSlave} {ram.s1}
set_instance_parameter_value cpu {resetOffset} {0x00000000}
set_instance_parameter_value cpu {exceptionSlave} {ram.s1}
set_instance_parameter_value cpu {io_regionbase} {0x70000000}
set_instance_parameter_value cpu {io_regionsize} {0x10000000}

add_instance ram altera_avalon_onchip_memory2 18.1
set_instance_parameter_value ram {memorySize} {0x00010000}
set_instance_parameter_value ram {initMemContent} {1}
set_instance_parameter_value ram {useNonDefaultInitFile} {1}
set_instance_parameter_value ram {initializationFileName} $mem_init_file

add_instance sysid altera_avalon_sysid_qsys 18.1
set_instance_parameter_value sysid {id} {0x46454233}

add_instance jtag_uart altera_avalon_jtag_uart 18.1
set_instance_parameter_value jtag_uart {readBufferDepth} {64}
set_instance_parameter_value jtag_uart {readIRQThreshold} {8}
set_instance_parameter_value jtag_uart {writeBufferDepth} {64}
set_instance_parameter_value jtag_uart {writeIRQThreshold} {8}

add_instance timer altera_avalon_timer 18.1
apply_preset timer "Simple periodic interrupt"
set_instance_parameter_value timer {period} {1}
set_instance_parameter_value timer {periodUnits} {MSEC}

add_instance timer_ts altera_avalon_timer 18.1
apply_preset timer_ts "Full-featured"

add_instance pio altera_avalon_pio 18.1
set_instance_parameter_value pio {bitModifyingOutReg} {1}
set_instance_parameter_value pio {direction} {Output}
set_instance_parameter_value pio {width} {32}
set_instance_parameter_value pio {resetValue} {0}

add_instance si_out altera_avalon_pio 18.1
set_instance_parameter_value si_out {bitModifyingOutReg} {1}
set_instance_parameter_value si_out {direction} {Output}
set_instance_parameter_value si_out {width} {16}
set_instance_parameter_value si_out {resetValue} {60}

add_instance si_in altera_avalon_pio 18.1
set_instance_parameter_value si_in {bitClearingEdgeCapReg} {0}
set_instance_parameter_value si_in {captureEdge} {0}
set_instance_parameter_value si_in {direction} {Input}
set_instance_parameter_value si_in {width} {8}

add_instance dbg0 altera_avalon_pio 18.1
set_instance_parameter_value dbg0 {bitModifyingOutReg} {1}
set_instance_parameter_value dbg0 {direction} {Output}
set_instance_parameter_value dbg0 {width} {32}
set_instance_parameter_value dbg0 {resetValue} {0}

add_instance dbg1 altera_avalon_pio 18.1
set_instance_parameter_value dbg1 {bitModifyingOutReg} {1}
set_instance_parameter_value dbg1 {direction} {Output}
set_instance_parameter_value dbg1 {width} {32}
set_instance_parameter_value dbg1 {resetValue} {0}

# Exported interfaces
add_interface clk_in clock sink
set_interface_property clk_in EXPORT_OF clk.clk_in

add_interface reset_in reset sink
set_interface_property reset_in EXPORT_OF clk.clk_in_reset

add_interface si_gpio_out conduit end
set_interface_property si_gpio_out EXPORT_OF si_out.external_connection

add_interface si_status_in conduit end
set_interface_property si_status_in EXPORT_OF si_in.external_connection

# Connections
foreach sink {
    cpu.clk
    ram.clk1
    sysid.clk
    jtag_uart.clk
    timer.clk
    timer_ts.clk
    pio.clk
    si_out.clk
    si_in.clk
    dbg0.clk
    dbg1.clk
} {
    add_connection clk.clk $sink
}

foreach sink {
    cpu.reset
    ram.reset1
    sysid.reset
    jtag_uart.reset
    timer.reset
    timer_ts.reset
    pio.reset
    si_out.reset
    si_in.reset
    dbg0.reset
    dbg1.reset
} {
    add_connection clk.clk_reset $sink
    add_connection cpu.debug_reset_request $sink
}

add_connection cpu.data_master ram.s1
set_connection_parameter_value cpu.data_master/ram.s1 baseAddress {0x10000000}
add_connection cpu.instruction_master ram.s1
set_connection_parameter_value cpu.instruction_master/ram.s1 baseAddress {0x10000000}

add_connection cpu.data_master cpu.debug_mem_slave
set_connection_parameter_value cpu.data_master/cpu.debug_mem_slave baseAddress {0x70000000}
add_connection cpu.instruction_master cpu.debug_mem_slave
set_connection_parameter_value cpu.instruction_master/cpu.debug_mem_slave baseAddress {0x70000000}

add_connection cpu.data_master sysid.control_slave
set_connection_parameter_value cpu.data_master/sysid.control_slave baseAddress {0x700F0000}
add_connection cpu.data_master jtag_uart.avalon_jtag_slave
set_connection_parameter_value cpu.data_master/jtag_uart.avalon_jtag_slave baseAddress {0x700F0010}
add_connection cpu.data_master timer.s1
set_connection_parameter_value cpu.data_master/timer.s1 baseAddress {0x700F0100}
add_connection cpu.data_master timer_ts.s1
set_connection_parameter_value cpu.data_master/timer_ts.s1 baseAddress {0x700F0140}
add_connection cpu.data_master pio.s1
set_connection_parameter_value cpu.data_master/pio.s1 baseAddress {0x700F0200}
add_connection cpu.data_master si_out.s1
set_connection_parameter_value cpu.data_master/si_out.s1 baseAddress {0x700F0220}
add_connection cpu.data_master si_in.s1
set_connection_parameter_value cpu.data_master/si_in.s1 baseAddress {0x700F0240}
add_connection cpu.data_master dbg0.s1
set_connection_parameter_value cpu.data_master/dbg0.s1 baseAddress {0x700F0260}
add_connection cpu.data_master dbg1.s1
set_connection_parameter_value cpu.data_master/dbg1.s1 baseAddress {0x700F0280}

add_connection cpu.irq jtag_uart.irq
set_connection_parameter_value cpu.irq/jtag_uart.irq irqNumber {2}
add_connection cpu.irq timer.irq
set_connection_parameter_value cpu.irq/timer.irq irqNumber {0}

set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}

save_system [file join $repo_dir quartus_system feb_bringup_system.qsys]
