#

package require qsys;

set ::SGR_RED "\033\[0;31m"
set ::SGR_RESET "\033\[0m"

proc ::error { msg } {
    puts "${::SGR_RED}E \[[ lindex [ info level 1 ] 0 ]\] $msg${::SGR_RESET}"
    exit 1
}

# ::add_fifo --
#
#   Add FIFO Intel FPGA IP (fifo) instance and auto export.
#
# Arguments:
#   width       - fifo width [bits]
#   depth       - fifo depth [words]
#   -dc         - dual clock
#   -usedw      - add usedw port (number of words in the fifo)
#   -aclr       - add aclr port (asynchronous clear)
#   -name $     - instance name
#
proc ::add_fifo { width depth args } {
    set name fifo_0
    set dc 0
    set usedw 0
    set aclr 0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            -dc {
                set dc 1
            }
            -usedw {
                set usedw 1
            }
            -aclr {
                set aclr 1
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} fifo

    if { ${dc} == 1 } {
        set_instance_parameter_value ${name} {GUI_Clock} {4}
    }

    set_instance_parameter_value ${name} {GUI_Width} ${width}
    set_instance_parameter_value ${name} {GUI_Depth} ${depth}

    # showahead mode
    set_instance_parameter_value ${name} {GUI_LegacyRREQ} {0}

    # usedw port
    set_instance_parameter_value ${name} {GUI_UsedW} ${usedw}

    # async clear port
    if { ${aclr} && ${dc} == 0 } {
        set_instance_parameter_value ${name} {GUI_sc_aclr} {1}
    }
    if { ${aclr} && ${dc} == 1 } {
        set_instance_parameter_value ${name} {GUI_dc_aclr} {1}
    }

    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_ram_2port --
#
#   Add 2-port Intel FPGA IP (ram_2port) instance and auto export.
#   Default is 1rw (one read port and one write port) RAM.
#
# Arguments:
#   width       - word width [bits]
#   words       - RAM size [words]
#   -2rw        - two read/write ports
#   -dc         - dual clock
#   -rdw $      - Read-During-Write (old - old data, new - new data)
#   -widthA $   - width of port A [bits]
#   -widthB $   - width of port B [bits]
#   -regA       - register outputs of port A
#   -regB       - register outputs of port B
#   -name $     - instance name
#
proc ::add_ram_2port { width words args } {
    set name ram_2port_0
    set 2rw 0
    set dc 0
    set rdw 0
    set widthA ${width}
    set widthB ${width}
    set regA 0
    set regB 0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            -2rw {
                set 2rw 1
            }
            -dc {
                set dc 1
            }
            -rdw { incr i
                set rdw [ lindex $args $i ]
            }
            -widthA { incr i
                set widthA [ lindex $args $i ]
            }
            -widthB { incr i
                set widthB [ lindex $args $i ]
            }
            -regA {
                set regA 1
            }
            -regB {
                set regB 1
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} ram_2port

    set_instance_parameter_value ${name} {GUI_DATAA_WIDTH} ${width}
    set_instance_parameter_value ${name} {GUI_QA_WIDTH} ${widthA}
    set_instance_parameter_value ${name} {GUI_QB_WIDTH} ${widthB}

    set_instance_parameter_value ${name} {GUI_MEMSIZE_WORDS} ${words}

    # different data widths on different ports
    if { ${width} != ${widthA} || ${width} != ${widthB} } {
        set_instance_parameter_value ${name} {GUI_VAR_WIDTH} {1}
    }

    # two read/write ports
    if { ${2rw} == 1 } {
        set_instance_parameter_value ${name} {GUI_MODE} {1}
    }

    # dual clock
    if { ${2rw} == 0 && ${dc} == 1 } {
        # separate read and write clocks
        set_instance_parameter_value ${name} {GUI_CLOCK_TYPE} {1}
    }
    if { ${2rw} == 1 && ${dc} == 1 } {
        # custom clocks for A and B ports
        set_instance_parameter_value ${name} {GUI_CLOCK_TYPE} {4}
    }

    switch -- ${rdw} {
        0 {}
        old { set_instance_parameter_value ${name} {GUI_Q_PORT_MODE} {1} }
        new { set_instance_parameter_value ${name} {GUI_Q_PORT_MODE} {3} }
        default { ::error "invalid RDW '[ lindex $args $i ]'" }
    }

    # output registers
    set_instance_parameter_value ${name} {GUI_READ_OUTPUT_QA} ${regA}
    set_instance_parameter_value ${name} {GUI_READ_OUTPUT_QB} ${regB}

    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_altclkctrl --
#
#   Add Clock Control Block IP (altclkctrl) instance and auto export.
#
# Arguments:
#   n           - number of inputs
#   -name $     - instance name
#
proc ::add_altclkctrl { n args } {
    set name altclkctrl_0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altclkctrl

    set_instance_parameter_value ${name} {CLOCK_TYPE} {0}

    set_instance_parameter_value ${name} {NUMBER_OF_CLOCKS} ${n}

    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_altclkctrl --
#
#   Add IOPLL Intel FPGA IP (altera_iopll) instance and auto export.
#
# Arguments:
#   refclk      - reference clock frequency [MHz]
#   outclk      -
#   -locked     - add locked port
#   -name $     - instance name
#
proc ::add_altera_iopll { refclk outclk args } {
    set name iopll_0
    set locked 0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            -locked {
                set locked 1
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_iopll

    set_instance_parameter_value ${name} {gui_reference_clock_frequency} ${refclk}

    set_instance_parameter_value ${name} {gui_output_clock_frequency0} ${outclk}

    set_instance_parameter_value ${name} {gui_use_locked} ${locked}

    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_altera_modular_adc --
#
#   Add Modular ADC Core instance and auto export.
#
# Arguments:
#   channels    - list of active channels
#   -seq_order  - channel acquisition sequence
#   -name $     - instance name
#
proc ::add_altera_modular_adc { channels args } {
    set name modular_adc_0
    set seq_order ""
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            -seq_order { incr i
                set seq_order [ lindex $args $i ]
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_modular_adc

    set_instance_parameter_value ${name} {CORE_VAR} {3}

    foreach channel $channels {
        if { [ string equal $channel tsd ] } {
            # temperature sensing diode
            set_instance_parameter_value ${name} {use_tsd} {1}
        } \
        else {
            set_instance_parameter_value ${name} use_ch$channel {1}
        }
    }

    set n 0
    foreach slot $seq_order {
        incr n
    }
    if { $n > 0 } {
        set_instance_parameter_value ${name} {seq_order_length} $n
        set i 0
        foreach slot $seq_order {
            incr i
            set_instance_parameter_value ${name} seq_order_slot_$i $slot
        }
    }

    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_altera_xcvr_fpll_a10 --
proc ::add_altera_xcvr_fpll_a10 { refclk_frequency output_clock_frequency args } {
    set name xcvr_fpll_a10_0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_xcvr_fpll_a10

    # fpll mode Transceiver
    set_instance_parameter_value ${name} {gui_fpll_mode} {2}
    # protocol mode Basic
    set_instance_parameter_value ${name} {gui_hssi_prot_mode} {0}

    set_instance_parameter_value ${name} {gui_desired_refclk_frequency} ${refclk_frequency}
    set_instance_parameter_value ${name} {gui_actual_refclk_frequency} ${refclk_frequency}

    # bandwidth High
    set_instance_parameter_value ${name} {gui_bw_sel} {high}
    # operation mode Direct
    set_instance_parameter_value ${name} {gui_operation_mode} {0}

    set_instance_parameter_value ${name} {gui_hssi_output_clock_frequency} ${output_clock_frequency}

    set_instance_parameter_value ${name} {enable_pll_reconfig} {1}
    set_instance_parameter_value ${name} {rcfg_separate_avmm_busy} {1}
    set_instance_parameter_value ${name} {set_capability_reg_enable} {1}
    set_instance_parameter_value ${name} {set_csr_soft_logic_enable} {1}

    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_altera_xcvr_native_a10 --
proc ::add_altera_xcvr_native_a10 { channels channel_width cdr_refclk_freq data_rate args } {
    set name xcvr_native_a10_0
    set mode basic_std
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            -mode { incr i
                set mode [ lindex $args $i ]
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    #set_project_property FABRIC_MODE value {NATIVE}

    # Instances and instance parameters
    add_instance ${name} altera_xcvr_native_a10
    set_instance_parameter_value ${name} {design_environment} {NATIVE}

    set_instance_parameter_value ${name} {support_mode} {user_mode}

    if { [ string equal $mode basic_std ] } {
        if { ${channel_width} == 8 || ${channel_width} == 10 } {
            set_instance_parameter_value ${name} {std_pcs_pma_width} {10}
        }
        if { ${channel_width} == 16 || ${channel_width} == 20 } {
            set_instance_parameter_value ${name} {std_pcs_pma_width} {20}
        }
        if { ${channel_width} == 32 || ${channel_width} == 40 } {
            set_instance_parameter_value ${name} {std_pcs_pma_width} {20}
            set_instance_parameter_value ${name} {std_tx_byte_ser_mode} {Serialize x2}
            set_instance_parameter_value ${name} {std_rx_byte_deser_mode} {Deserialize x2}
        }
        if { ${channel_width} == 8 || ${channel_width} == 16 || ${channel_width} == 32 } {
            # enable 8b10b decoder/encoder
            set_instance_parameter_value ${name} {std_tx_8b10b_enable} {1}
            set_instance_parameter_value ${name} {std_rx_8b10b_enable} {1}

            set_instance_parameter_value ${name} {std_rx_word_aligner_mode} {synchronous state machine}
            set_instance_parameter_value ${name} {std_rx_word_aligner_pattern_len} {10}
            # word aligner pattern K28.5
            set_instance_parameter_value ${name} {std_rx_word_aligner_pattern} {0x283}
        } else {
            set_instance_parameter_value ${name} {std_tx_8b10b_enable} {0}
            set_instance_parameter_value ${name} {std_rx_8b10b_enable} {0}
        }
        if { ${channel_width} == 10 || ${channel_width} == 20 || ${channel_width} == 40 } {
            set_instance_parameter_value ${name} {enable_port_rx_std_bitslip} {1}
        }
    }
    if { [ string equal $mode basic_enh ] } {
        set_instance_parameter_value ${name} {enh_pcs_pma_width} ${channel_width}
        set_instance_parameter_value ${name} {enh_pld_pcs_width} ${channel_width}

        # gearbox
        set_instance_parameter_value ${name} {enable_port_rx_enh_bitslip} {1}
        set_instance_parameter_value ${name} {enh_rx_bitslip_enable} {1}
    }

    # datapath options
    set_instance_parameter_value ${name} {protocol_mode} ${mode}
    set_instance_parameter_value ${name} {pma_mode} {basic}
    set_instance_parameter_value ${name} {duplex_mode} {duplex}
    set_instance_parameter_value ${name} {channels} ${channels}

    set_instance_parameter_value ${name} {set_data_rate} ${data_rate}

    set_instance_parameter_value ${name} {enable_simple_interface} {1}
    set_instance_parameter_value ${name} {enable_split_interface} {0}

    # CDR options
    set_instance_parameter_value ${name} {set_cdr_refclk_freq} ${cdr_refclk_freq}
    set_instance_parameter_value ${name} {rx_ppm_detect_threshold} {1000}

    # PMA ports
    set_instance_parameter_value ${name} {enable_port_rx_is_lockedtodata} {1}
    set_instance_parameter_value ${name} {enable_port_rx_is_lockedtoref} {1}
    set_instance_parameter_value ${name} {enable_port_rx_seriallpbken_tx} {1}
    set_instance_parameter_value ${name} {enable_port_rx_seriallpbken} {1}

    # dynamic reconfiguration
    set_instance_parameter_value ${name} {rcfg_enable} {1}
    set_instance_parameter_value ${name} {rcfg_shared} {1}
    set_instance_parameter_value ${name} {rcfg_separate_avmm_busy} {1}
    set_instance_parameter_value ${name} {set_capability_reg_enable} {1}
    set_instance_parameter_value ${name} {set_csr_soft_logic_enable} {1}

    # exported interfaces
    set_instance_property ${name} AUTO_EXPORT {true}
}

# ::add_altera_xcvr_reset_control --
proc ::add_altera_xcvr_reset_control { CHANNELS SYS_CLK_IN_MHZ args } {
    set name xcvr_reset_control_0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_xcvr_reset_control
    apply_preset ${name} "Arria 10 Default Settings"

    foreach { parameter value } [ list      \
        CHANNELS            $CHANNELS       \
        PLLS                1               \
        SYS_CLK_IN_MHZ      $SYS_CLK_IN_MHZ \
        gui_pll_cal_busy    1               \
        RX_PER_CHANNEL      1               \
    ] {
        set_instance_parameter_value $name $parameter $value
    }

    set_instance_property $name AUTO_EXPORT {true}
}

# ::add_pcie_a10_hip --
#
#   Add ...
#
# Arguments:
#   -mode $     - Hard IP mode (...)
#   -name $     - instance name
#
proc add_pcie_a10_hip { args } {
    set name pcie_a10_hip_0
    set mode 0
    set mm 0
    set auto_export 1
    set vendor_id 0x1172
    set device_id 0xE001
    set revision_id 1
    set class_code 0xFF0000
    set bar0_width 12
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -name { incr i
                set name [ lindex $args $i ]
            }
            -mode { incr i
                set mode [ lindex $args $i ]
            }
            -mm { incr i
                set mm [ lindex $args $i ]
                set auto_export 0
            }
            default {
                ::error "invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} altera_pcie_a10_hip

    set_instance_parameter_value ${name} {wrala_hwtcl} ${mode}
    if { $mm > 0 } {
        set_instance_parameter_value ${name} {interface_type_hwtcl} {Avalon-MM}
        set_instance_parameter_value ${name} {avmm_addr_width_hwtcl} ${mm}
    }

    if { $bar0_width > 0 } {
        set_instance_parameter_value ${name} {bar0_type_hwtcl} {32-bit non-prefetchable memory}
        set_instance_parameter_value ${name} {bar0_address_width_hwtcl} ${bar0_width}
        set_instance_parameter_value ${name} {bar1_type_hwtcl} {Disabled}
        set_instance_parameter_value ${name} {bar1_address_width_hwtcl} 0
        set_instance_parameter_value ${name} {bar2_type_hwtcl} {Disabled}
        set_instance_parameter_value ${name} {bar2_address_width_hwtcl} 0
        set_instance_parameter_value ${name} {bar3_type_hwtcl} {Disabled}
        set_instance_parameter_value ${name} {bar3_address_width_hwtcl} 0
        set_instance_parameter_value ${name} {bar4_type_hwtcl} {Disabled}
        set_instance_parameter_value ${name} {bar4_address_width_hwtcl} 0
        set_instance_parameter_value ${name} {bar5_type_hwtcl} {Disabled}
        set_instance_parameter_value ${name} {bar5_address_width_hwtcl} 0
    }

    set_instance_parameter_value ${name} {vendor_id_hwtcl} ${vendor_id}
    set_instance_parameter_value ${name} {device_id_hwtcl} ${device_id}
    set_instance_parameter_value ${name} {revision_id_hwtcl} ${revision_id}

    set_instance_parameter_value ${name} {class_code_hwtcl} ${class_code}
    set_instance_parameter_value ${name} {subsystem_vendor_id_hwtcl} ${vendor_id}
    set_instance_parameter_value ${name} {subsystem_device_id_hwtcl} ${device_id}

    set_instance_parameter_value ${name} {maximum_payload_size_hwtcl} {128}
    set_instance_parameter_value ${name} {completion_timeout_hwtcl} {ABCD}
    set_instance_parameter_value ${name} {advance_error_reporting_hwtcl} {1}

    if { $auto_export } {
        set_instance_property ${name} AUTO_EXPORT {true}
    }
}
