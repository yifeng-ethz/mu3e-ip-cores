# qsys scripting (.tcl) file for avst_errcnt_system
package require -exact qsys 16.0

create_system {avst_errcnt_system}
set_module_property VERSION 1.0.0.0511

set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance avst2cntr_fab_0 avst2cntr_fab 1.0.3
set_instance_parameter_value avst2cntr_fab_0 {DEBUG} {1}
set_instance_parameter_value avst2cntr_fab_0 {EN_LOGIC} {OR}
set_instance_parameter_value avst2cntr_fab_0 {ERR_MASK} {1}
set_instance_parameter_value avst2cntr_fab_0 {ST_CH_W} {3}
set_instance_parameter_value avst2cntr_fab_0 {ST_DATA_W} {9}
set_instance_parameter_value avst2cntr_fab_0 {ST_ERR_W} {3}

add_instance clk_0 clock_source 18.1
set_instance_parameter_value clk_0 {clockFrequency} {125000000.0}
set_instance_parameter_value clk_0 {clockFrequencyKnown} {0}
set_instance_parameter_value clk_0 {resetSynchronousEdges} {DEASSERT}

add_instance counter_avmm_0 counter_avmm 1.2.2
set_instance_parameter_value counter_avmm_0 {ADDR_W} {1}
set_instance_parameter_value counter_avmm_0 {COUNTER_BITS} {31}
set_instance_parameter_value counter_avmm_0 {N_COUNTER} {1}
set_instance_parameter_value counter_avmm_0 {READ_ON_THE_FLY} {1}
set_instance_parameter_value counter_avmm_0 {USE_TOP_BIT_AS_OF_FLAG} {1}

add_instance st_splitter_0 altera_avalon_st_splitter 18.1
set_instance_parameter_value st_splitter_0 {BITS_PER_SYMBOL} {9}
set_instance_parameter_value st_splitter_0 {CHANNEL_WIDTH} {3}
set_instance_parameter_value st_splitter_0 {DATA_WIDTH} {9}
set_instance_parameter_value st_splitter_0 {ERROR_DESCRIPTOR} {}
set_instance_parameter_value st_splitter_0 {ERROR_WIDTH} {3}
set_instance_parameter_value st_splitter_0 {MAX_CHANNELS} {7}
set_instance_parameter_value st_splitter_0 {NUMBER_OF_OUTPUTS} {2}
set_instance_parameter_value st_splitter_0 {QUALIFY_VALID_OUT} {1}
set_instance_parameter_value st_splitter_0 {READY_LATENCY} {0}
set_instance_parameter_value st_splitter_0 {USE_CHANNEL} {1}
set_instance_parameter_value st_splitter_0 {USE_DATA} {1}
set_instance_parameter_value st_splitter_0 {USE_ERROR} {1}
set_instance_parameter_value st_splitter_0 {USE_PACKETS} {0}
set_instance_parameter_value st_splitter_0 {USE_READY} {0}
set_instance_parameter_value st_splitter_0 {USE_VALID} {1}

# exported interfaces
add_interface avmm_errcnt avalon slave
set_interface_property avmm_errcnt EXPORT_OF counter_avmm_0.avmm_counter_value
add_interface avst_in avalon_streaming sink
set_interface_property avst_in EXPORT_OF st_splitter_0.in
add_interface avst_out avalon_streaming source
set_interface_property avst_out EXPORT_OF st_splitter_0.out1
add_interface counter_clk clock sink
set_interface_property counter_clk EXPORT_OF clk_0.clk_in
add_interface counter_rst reset sink
set_interface_property counter_rst EXPORT_OF clk_0.clk_in_reset
add_interface counter_sclr conduit end
set_interface_property counter_sclr EXPORT_OF avst2cntr_fab_0.counter_sclr_port

# connections and connection parameters
add_connection clk_0.clk avst2cntr_fab_0.clock_sink

add_connection clk_0.clk counter_avmm_0.clock_sink

add_connection clk_0.clk st_splitter_0.clk

add_connection clk_0.clk_reset avst2cntr_fab_0.reset_sink

add_connection clk_0.clk_reset counter_avmm_0.reset_sink

add_connection clk_0.clk_reset st_splitter_0.reset

add_connection counter_avmm_0.counter_control_port avst2cntr_fab_0.counter_control_port
set_connection_parameter_value counter_avmm_0.counter_control_port/avst2cntr_fab_0.counter_control_port endPort {}
set_connection_parameter_value counter_avmm_0.counter_control_port/avst2cntr_fab_0.counter_control_port endPortLSB {0}
set_connection_parameter_value counter_avmm_0.counter_control_port/avst2cntr_fab_0.counter_control_port startPort {}
set_connection_parameter_value counter_avmm_0.counter_control_port/avst2cntr_fab_0.counter_control_port startPortLSB {0}
set_connection_parameter_value counter_avmm_0.counter_control_port/avst2cntr_fab_0.counter_control_port width {0}

add_connection st_splitter_0.out0 avst2cntr_fab_0.avst_monitor4link

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}

save_system {avst_errcnt_system.qsys}
