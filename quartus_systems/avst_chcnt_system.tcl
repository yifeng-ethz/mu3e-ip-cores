# qsys scripting (.tcl) file for avst_chcnt_system
package require -exact qsys 16.0

create_system {avst_chcnt_system}
set_module_property VERSION 1.0.0.0511

set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance avsthit0ch2cntr_ctrl_0 avsthit0ch2cntr_ctrl 1.0.9
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {BYPASS_EXTERNAL_SCLR} {0}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {CHANNEL_BITFIELD_LSB} {36}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {CHANNEL_BITFIELD_MSB} {40}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {CHANNEL_ID_W} {5}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {CHANNEL_SEL_W} {32}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {CLK_FREQUENCY} {125000000}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {DEBUG} {1}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {RST_INTERVAL} {1000}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {RST_TIMER} {1}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {ST_CH_W} {4}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {ST_DATA_W} {45}
set_instance_parameter_value avsthit0ch2cntr_ctrl_0 {ST_ERR_W} {3}

add_instance clk_0 clock_source 18.1
set_instance_parameter_value clk_0 {clockFrequency} {125000000.0}
set_instance_parameter_value clk_0 {clockFrequencyKnown} {1}
set_instance_parameter_value clk_0 {resetSynchronousEdges} {DEASSERT}

add_instance counter_avmm_0 counter_avmm 1.2.2
set_instance_parameter_value counter_avmm_0 {ADDR_W} {5}
set_instance_parameter_value counter_avmm_0 {COUNTER_BITS} {31}
set_instance_parameter_value counter_avmm_0 {N_COUNTER} {32}
set_instance_parameter_value counter_avmm_0 {READ_ON_THE_FLY} {0}
set_instance_parameter_value counter_avmm_0 {USE_TOP_BIT_AS_OF_FLAG} {1}

add_instance st_splitter_0 altera_avalon_st_splitter 18.1
set_instance_parameter_value st_splitter_0 {BITS_PER_SYMBOL} {45}
set_instance_parameter_value st_splitter_0 {CHANNEL_WIDTH} {4}
set_instance_parameter_value st_splitter_0 {DATA_WIDTH} {45}
set_instance_parameter_value st_splitter_0 {ERROR_DESCRIPTOR} {}
set_instance_parameter_value st_splitter_0 {ERROR_WIDTH} {3}
set_instance_parameter_value st_splitter_0 {MAX_CHANNELS} {15}
set_instance_parameter_value st_splitter_0 {NUMBER_OF_OUTPUTS} {2}
set_instance_parameter_value st_splitter_0 {QUALIFY_VALID_OUT} {1}
set_instance_parameter_value st_splitter_0 {READY_LATENCY} {0}
set_instance_parameter_value st_splitter_0 {USE_CHANNEL} {1}
set_instance_parameter_value st_splitter_0 {USE_DATA} {1}
set_instance_parameter_value st_splitter_0 {USE_ERROR} {1}
set_instance_parameter_value st_splitter_0 {USE_PACKETS} {1}
set_instance_parameter_value st_splitter_0 {USE_READY} {0}
set_instance_parameter_value st_splitter_0 {USE_VALID} {1}

# exported interfaces
add_interface avmm_counter_value avalon slave
set_interface_property avmm_counter_value EXPORT_OF counter_avmm_0.avmm_counter_value
add_interface avmm_rst_interval avalon slave
set_interface_property avmm_rst_interval EXPORT_OF avsthit0ch2cntr_ctrl_0.avmm_rst_interval
add_interface clk clock sink
set_interface_property clk EXPORT_OF clk_0.clk_in
add_interface hit_type0_in avalon_streaming sink
set_interface_property hit_type0_in EXPORT_OF st_splitter_0.in
add_interface hit_type0_out avalon_streaming source
set_interface_property hit_type0_out EXPORT_OF st_splitter_0.out1
add_interface reset reset sink
set_interface_property reset EXPORT_OF clk_0.clk_in_reset
add_interface sclr_counter_req reset sink
set_interface_property sclr_counter_req EXPORT_OF avsthit0ch2cntr_ctrl_0.sclr_counter_req

# connections and connection parameters
add_connection avsthit0ch2cntr_ctrl_0.counter_control_port counter_avmm_0.counter_control_port
set_connection_parameter_value avsthit0ch2cntr_ctrl_0.counter_control_port/counter_avmm_0.counter_control_port endPort {}
set_connection_parameter_value avsthit0ch2cntr_ctrl_0.counter_control_port/counter_avmm_0.counter_control_port endPortLSB {0}
set_connection_parameter_value avsthit0ch2cntr_ctrl_0.counter_control_port/counter_avmm_0.counter_control_port startPort {}
set_connection_parameter_value avsthit0ch2cntr_ctrl_0.counter_control_port/counter_avmm_0.counter_control_port startPortLSB {0}
set_connection_parameter_value avsthit0ch2cntr_ctrl_0.counter_control_port/counter_avmm_0.counter_control_port width {0}

add_connection clk_0.clk avsthit0ch2cntr_ctrl_0.clock_sink

add_connection clk_0.clk counter_avmm_0.clock_sink

add_connection clk_0.clk st_splitter_0.clk

add_connection clk_0.clk_reset avsthit0ch2cntr_ctrl_0.reset_sink

add_connection clk_0.clk_reset counter_avmm_0.reset_sink

add_connection clk_0.clk_reset st_splitter_0.reset

add_connection st_splitter_0.out0 avsthit0ch2cntr_ctrl_0.hit_type0

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}

save_system {avst_chcnt_system.qsys}
