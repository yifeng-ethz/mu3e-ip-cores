#

package require qsys

# module properties
set_module_property NAME {flash1616}
set_module_property DISPLAY_NAME {flash1616}
set_module_property GROUP {mu3e}

# default module properties
set_module_property VERSION {1.0}
set_module_property DESCRIPTION {}
set_module_property AUTHOR {akozlins}

add_parameter clockFrequency INTEGER 50000000
set_parameter_property clockFrequency UNITS HERTZ
add_parameter address_width INTEGER 28
set_parameter_property address_width UNITS BITS
add_parameter rw_wait INTEGER 144
set_parameter_property rw_wait UNITS NANOSECONDS
add_parameter setup_wait INTEGER 33
set_parameter_property setup_wait UNITS NANOSECONDS
add_parameter data_hold INTEGER 33
set_parameter_property data_hold UNITS NANOSECONDS

set_module_property COMPOSITION_CALLBACK compose
proc compose {} {
    add_instance clk clock_source
    set_instance_parameter_value clk {clockFrequency} [ get_parameter_value clockFrequency ]
    set_instance_parameter_value clk {resetSynchronousEdges} {DEASSERT}

    add_instance flash altera_generic_tristate_controller
#    apply_preset flash "Flash Memory Interface (CFI)"

    set_instance_parameter_value flash {TCM_ADDRESS_W} [ get_parameter_value address_width ]
    set_instance_parameter_value flash {TCM_DATA_W} {32}
    set_instance_parameter_value flash {TCM_BYTEENABLE_W} {4}
    set_instance_parameter_value flash {TCM_SYMBOLS_PER_WORD} {4}

    # timing units [ns] for read/write/setup_wait and data_hold
    set_instance_parameter_value flash {TCM_TIMING_UNITS} {0}
    set_instance_parameter_value flash {TCM_READ_WAIT} [ get_parameter_value rw_wait ]
    set_instance_parameter_value flash {TCM_WRITE_WAIT} [ get_parameter_value rw_wait ]
    set_instance_parameter_value flash {TCM_SETUP_WAIT} [ get_parameter_value setup_wait ]
    set_instance_parameter_value flash {TCM_DATA_HOLD} [ get_parameter_value data_hold ]

    set_instance_parameter_value flash {TCM_MAX_PENDING_READ_TRANSACTIONS} {3}
    set_instance_parameter_value flash {TCM_TURNAROUND_TIME} {4}
    set_instance_parameter_value flash {TCM_READLATENCY} {2}

    set_instance_parameter_value flash {USE_BEGINTRANSFER} {0}
    set_instance_parameter_value flash {USE_BYTEENABLE} {0}
    set_instance_parameter_value flash {USE_CHIPSELECT} {1}
    set_instance_parameter_value flash {ACTIVE_LOW_READ} {1}
    set_instance_parameter_value flash {ACTIVE_LOW_WRITE} {1}
    set_instance_parameter_value flash {ACTIVE_LOW_CHIPSELECT} {1}

    set_instance_parameter_value flash {IS_MEMORY_DEVICE} {1}

    add_instance flash_bridge altera_tristate_conduit_bridge

    add_connection clk.clk       flash.clk
    add_connection clk.clk       flash_bridge.clk
    add_connection clk.clk_reset flash.reset
    add_connection clk.clk_reset flash_bridge.reset

    add_connection flash.tcm flash_bridge.tcs

    # exported interfaces
    add_interface clk clock sink
    set_interface_property clk EXPORT_OF clk.clk_in
    add_interface reset reset sink
    set_interface_property reset EXPORT_OF clk.clk_in_reset
    add_interface uas avalon slave
    set_interface_property uas EXPORT_OF flash.uas
    add_interface out conduit end
    set_interface_property out EXPORT_OF flash_bridge.out

    foreach { name value } [ list \
        embeddedsw.configuration.hwClassnameDriverSupportList       altera_avalon_cfi_flash \
        embeddedsw.configuration.hwClassnameDriverSupportDefault    altera_avalon_cfi_flash \
        embeddedsw.CMacro.TIMING_UNITS  ns \
        embeddedsw.CMacro.WAIT_VALUE    [ get_parameter_value rw_wait ] \
        embeddedsw.CMacro.SETUP_VALUE   [ get_parameter_value setup_wait ] \
        embeddedsw.CMacro.HOLD_VALUE    [ get_parameter_value data_hold ] \
        embeddedsw.CMacro.SIZE          [ expr 1 << [ get_parameter_value address_width ] ] \
        embeddedsw.memoryInfo.MEM_INIT_DATA_WIDTH   32 \
        embeddedsw.memoryInfo.HAS_BYTE_LANE         0 \
        embeddedsw.memoryInfo.IS_FLASH              1 \
        embeddedsw.memoryInfo.GENERATE_DAT_SYM      1 \
        embeddedsw.memoryInfo.GENERATE_FLASH        1 \
        embeddedsw.memoryInfo.DAT_SYM_INSTALL_DIR   SIM_DIR \
        embeddedsw.memoryInfo.FLASH_INSTALL_DIR     APP_DIR \
    ] {
        set_module_assignment $name $value
    }

    foreach { name value } [ list \
        embeddedsw.configuration.isFlash 1 \
        embeddedsw.configuration.isMemoryDevice 1 \
        embeddedsw.configuration.isNonVolatileStorage 1 \
    ] {
        set_interface_assignment uas $name $value
    }
}
