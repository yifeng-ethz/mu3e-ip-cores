#
# author : Alexandr Kozlinskiy
#

proc nios_base.add_clock_source { name clockFrequency args } {
    set clock_export ${name}
    set reset_export ${name}_reset
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -clock_export { incr i
                set clock_export [ lindex $args $i ]
            }
            -reset_export { incr i
                set reset_export [ lindex $args $i ]
            }
            default {
                send_message "Error" "\[nios_base.add_clock_source\] invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} clock_source

    set_instance_parameter_value ${name} {clockFrequency} ${clockFrequency}
    set_instance_parameter_value ${name} {resetSynchronousEdges} {DEASSERT}

    add_interface ${clock_export} clock sink
    set_interface_property ${clock_export} EXPORT_OF ${name}.clk_in
    add_interface ${reset_export} reset sink
    set_interface_property ${reset_export} EXPORT_OF ${name}.clk_in_reset
}

nios_base.add_clock_source clk [ expr int($nios_clk_mhz * 1e6) ] -reset_export rst

# cpu
add_instance cpu altera_nios2_gen2
set_instance_parameter_value cpu {impl} {Tiny}
set_instance_parameter_value cpu {resetSlave} {ram.s1}
set_instance_parameter_value cpu {resetOffset} {0x00000000}
set_instance_parameter_value cpu {exceptionSlave} {ram.s1}

set_instance_parameter_value cpu {io_regionbase} {0x70000000}
set_instance_parameter_value cpu {io_regionsize} {0x10000000}

# ram
add_instance ram altera_avalon_onchip_memory2
set_instance_parameter_value ram {memorySize} {0x00010000}
set_instance_parameter_value ram {initMemContent} {1}
set_instance_parameter_value ram {useNonDefaultInitFile} {1}
set_instance_parameter_value ram {initializationFileName} {output_files/nios_ram.hex}



add_connection clk.clk cpu.clk
add_connection clk.clk ram.clk1

add_connection clk.clk_reset cpu.reset
add_connection clk.clk_reset ram.reset1

add_connection                 cpu.data_master ram.s1
set_connection_parameter_value cpu.data_master/ram.s1                      baseAddress {0x10000000}
add_connection                 cpu.instruction_master ram.s1
set_connection_parameter_value cpu.instruction_master/ram.s1               baseAddress {0x10000000}
add_connection                 cpu.data_master cpu.debug_mem_slave
set_connection_parameter_value cpu.data_master/cpu.debug_mem_slave         baseAddress {0x70000000}
add_connection                 cpu.instruction_master cpu.debug_mem_slave
set_connection_parameter_value cpu.instruction_master/cpu.debug_mem_slave  baseAddress {0x70000000}



add_connection cpu.debug_reset_request cpu.reset
add_connection cpu.debug_reset_request ram.reset1



proc nios_base.connect { name clk reset avalon addr } {
    if { [ string length ${clk} ] > 0 } {
        add_connection clk.clk ${name}.${clk}
    }
    if { [ string length ${reset} ] > 0 } {
        add_connection clk.clk_reset ${name}.${reset}
        add_connection cpu.debug_reset_request ${name}.${reset}
    }
    if { [ string length ${avalon} ] > 0 } {
        add_connection                 cpu.data_master ${name}.${avalon}
        set_connection_parameter_value cpu.data_master/${name}.${avalon} baseAddress ${addr}
    }
}

proc nios_base.add_pio { name width direction addr } {
    add_instance ${name} altera_avalon_pio
    set_instance_parameter_value ${name} {width} ${width}
    set_instance_parameter_value ${name} {direction} ${direction}
    set_instance_parameter_value ${name} {bitModifyingOutReg} {1}

    nios_base.connect ${name} clk reset s1 ${addr}

    add_interface ${name} conduit end
    set_interface_property ${name} EXPORT_OF ${name}.external_connection
}

proc nios_base.add_vic { name width addr } {
    add_instance ${name} altera_vic
    set_instance_parameter_value ${name} {NUMBER_OF_INT_PORTS} ${width}

    set_instance_parameter_value cpu {setting_interruptControllerType} {External}
    set_instance_parameter_value cpu {setting_shadowRegisterSets} {4}
    add_connection ${name}.interrupt_controller_out cpu.interrupt_controller_in

    nios_base.connect ${name} clk reset csr_access ${addr}
}

proc nios_base.connect_irq { name irq } {
    set cpu cpu
    set irq_iface ${cpu}.irq
    set eic vic

    set ic_type [ get_instance_parameter_value ${cpu} setting_interruptControllerType ]
    if { [ string equal ${ic_type} External ] } {
#        set eic [ get_connections ${cpu}.interrupt_controller_in ]
        set irq_iface ${eic}.irq_input
    }

    add_connection ${irq_iface} ${name}
    set_connection_parameter_value ${irq_iface}/${name} irqNumber $irq
}

# uart, timers, i2c, spi
proc nios_base.init {} {
    add_instance sysid altera_avalon_sysid_qsys

    add_instance jtag_uart altera_avalon_jtag_uart

    add_instance timer altera_avalon_timer
    apply_preset timer "Simple periodic interrupt"
    set_instance_parameter_value timer {period} {1}
    set_instance_parameter_value timer {periodUnits} {MSEC}

    add_instance timer_ts altera_avalon_timer
    apply_preset timer_ts "Full-featured"

    add_instance i2c altera_avalon_i2c
    add_instance spi altera_avalon_spi

    nios_base.connect   sysid       clk     reset       control_slave       0x700F0000
    nios_base.connect   jtag_uart   clk     reset       avalon_jtag_slave   0x700F0010
    nios_base.connect   timer       clk     reset       s1                  0x700F0100
    nios_base.connect   timer_ts    clk     reset       s1                  0x700F0140
    nios_base.connect   i2c         clock   reset_sink  csr                 0x700F0200
    nios_base.connect   spi         clk     reset       spi_control_port    0x700F0240

    # IRQ assignments
    foreach { name irq } {
        jtag_uart.irq 2
        timer.irq 0
        i2c.interrupt_sender 4
        spi.irq 5
    } {
        nios_base.connect_irq $name $irq
    }

    add_interface i2c conduit end
    set_interface_property i2c EXPORTOF i2c.i2c_serial

    add_interface spi conduit end
    set_interface_property spi EXPORTOF spi.external

    nios_base.add_pio pio 32 Output 0x700F0280

    # i2c slave select port
    nios_base.add_pio i2c_mask 32 Output 0x700F02A0
}
nios_base.init

#package require cmdline

proc nios_base.export_avm { name addressWidth baseAddress args } {
    set cpu cpu
    set clk clk
    set dataWidth 32
    set addressUnits 32
    set readLatency 0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -cpu { incr i
                set cpu [ lindex $args $i ]
            }
            -clk { incr i
                set clk [ lindex $args $i ]
            }
            -dataWidth { incr i
                set dataWidth [ lindex $args $i ]
            }
            -addressUnits { incr i
                set addressUnits [ lindex $args $i ]
            }
            -readLatency { incr i
                set readLatency [ lindex $args $i ]
            }
            default {
                send_message "Error" "\[nios_base.export_avm\] invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} avalon_proxy
    set_instance_parameter_value ${name} {DATA_WIDTH} ${dataWidth}
    set_instance_parameter_value ${name} {ADDRESS_UNITS} ${addressUnits}
    set_instance_parameter_value ${name} {ADDRESS_WIDTH} ${addressWidth}
    if { ${readLatency} >= 0 } {
        set_instance_parameter_value ${name} {READ_LATENCY} ${readLatency}
    } else {
        set_instance_parameter_value ${name} {READ_LATENCY} 0
        set_instance_parameter_value ${name} {USE_READ_DATA_VALID} true
    }

    # clock
    add_connection ${clk}.clk ${name}.clk

    # resets
    if { [ string equal ${clk} clk ] == 0 } {
        add_connection ${clk}.clk_reset ${name}.reset
    }
    add_connection clk.clk_reset ${name}.reset
    add_connection cpu.debug_reset_request ${name}.reset

    add_connection                 ${cpu}.data_master ${name}.slave
    set_connection_parameter_value ${cpu}.data_master/${name}.slave baseAddress ${baseAddress}

    add_interface ${name} avalon master
    set_interface_property ${name} EXPORT_OF ${name}.master
}

proc nios_base.export_avm_v2 { name addressWidth baseAddress args } {
    set cpu cpu
    set clk clk
    set dataWidth 32
    set addressUnits 32
    set readLatency 0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -cpu { incr i
                set cpu [ lindex $args $i ]
            }
            -clk { incr i
                set clk [ lindex $args $i ]
            }
            -dataWidth { incr i
                set dataWidth [ lindex $args $i ]
            }
            -addressUnits { incr i
                set addressUnits [ lindex $args $i ]
            }
            -readLatency { incr i
                set readLatency [ lindex $args $i ]
            }
            default {
                send_message "Error" "\[nios_base.export_avm\] invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_merlin_slave_translator
    set_instance_parameter_value ${name} {USE_BEGINBURSTTRANSFER} {0}
    set_instance_parameter_value ${name} {USE_BEGINTRANSFER} {0}
    set_instance_parameter_value ${name} {USE_BYTEENABLE} {0}
    set_instance_parameter_value ${name} {USE_BURSTCOUNT} {0}
    set_instance_parameter_value ${name} {USE_READDATAVALID} {0}

    set_instance_parameter_value ${name} {AV_DATA_W} ${dataWidth}
    set_instance_parameter_value ${name} {UAV_DATA_W} ${dataWidth}
    set_instance_parameter_value ${name} {AV_ADDRESS_SYMBOLS} [ expr ${addressUnits} != 32 ]
    set_instance_parameter_value ${name} {AV_ADDRESS_W} ${addressWidth}
    set_instance_parameter_value ${name} {UAV_ADDRESS_W} ${addressWidth}
    set_instance_parameter_value ${name} {AV_READLATENCY} ${readLatency}

    # clock
    add_connection ${clk}.clk ${name}.clk

    # resets
    if { [ string equal ${clk} clk ] == 0 } {
        add_connection ${clk}.clk_reset ${name}.reset
    }
    add_connection clk.clk_reset ${name}.reset
    add_connection cpu.debug_reset_request ${name}.reset

    add_connection                 ${cpu}.data_master ${name}.avalon_universal_slave_0
    set_connection_parameter_value ${cpu}.data_master/${name}.avalon_universal_slave_0 baseAddress ${baseAddress}

    add_interface ${name} avalon master
    set_interface_property ${name} EXPORT_OF ${name}.avalon_anti_slave_0
}

proc nios_base.add_irq_bridge { name width args } {
    set cpu cpu
    set clk clk
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -cpu { incr i
                set cpu [ lindex $args $i ]
            }
            -clk { incr i
                set clk [ lindex $args $i ]
            }
            default {
                send_message "Error" "\[nios_base.add_irq_bridge\] invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_irq_bridge

    # signal width
    set_instance_parameter_value ${name} {IRQ_WIDTH} ${width}
    # signal polarity
    set_instance_parameter_value ${name} {IRQ_N} {0}

    for { set i 0 } { $i < $width } { incr i } {
        nios_base.connect_irq ${name}.sender${i}_irq [ expr 16 - $width + $i ]
    }

    add_connection ${clk}.clk ${name}.clk
    add_connection ${clk}.clk_reset ${name}.clk_reset

    add_interface ${name} interrupt receiver
    set_interface_property ${name} EXPORT_OF ${name}.receiver_irq
}
