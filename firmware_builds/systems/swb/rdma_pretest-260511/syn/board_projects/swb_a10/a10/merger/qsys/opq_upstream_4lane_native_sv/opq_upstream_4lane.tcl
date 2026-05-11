package require -exact qsys 16.1

create_system {opq_upstream_4lane}

set_project_property DEVICE_FAMILY {Arria 10}
set_project_property HIDE_FROM_IP_CATALOG {false}

add_instance clk_bridge altera_clock_bridge 18.1
add_instance reset_bridge altera_reset_bridge 18.1
add_instance opq_0 ordered_priority_queue_native_sv_fixed4 26.5.0.0430
add_instance csr_jtag_master altera_jtag_avalon_master 18.1

set_instance_parameter_value csr_jtag_master {FAST_VER} {1}
set_instance_parameter_value csr_jtag_master {FIFO_DEPTHS} {2}
set_instance_parameter_value csr_jtag_master {PLI_PORT} {50000}
set_instance_parameter_value csr_jtag_master {USE_PLI} {0}

add_interface clk clock sink
set_interface_property clk EXPORT_OF clk_bridge.in_clk

add_interface reset reset sink
set_interface_property reset EXPORT_OF reset_bridge.in_reset

add_connection clk_bridge.out_clk reset_bridge.clk
add_connection clk_bridge.out_clk opq_0.clk_interface
add_connection reset_bridge.out_reset opq_0.rst_interface
add_connection clk_bridge.out_clk csr_jtag_master.clk
add_connection reset_bridge.out_reset csr_jtag_master.clk_reset
add_connection csr_jtag_master.master opq_0.csr
set_connection_parameter_value csr_jtag_master.master/opq_0.csr arbitrationPriority {1}
set_connection_parameter_value csr_jtag_master.master/opq_0.csr baseAddress {0x0000}
set_connection_parameter_value csr_jtag_master.master/opq_0.csr defaultConnection {0}
set_interconnect_requirement {csr_jtag_master.master} {qsys_mm.security} {NON_SECURE}

add_interface ingress_0 avalon_streaming sink
set_interface_property ingress_0 EXPORT_OF opq_0.ingress_0

add_interface ingress_1 avalon_streaming sink
set_interface_property ingress_1 EXPORT_OF opq_0.ingress_1

add_interface ingress_2 avalon_streaming sink
set_interface_property ingress_2 EXPORT_OF opq_0.ingress_2

add_interface ingress_3 avalon_streaming sink
set_interface_property ingress_3 EXPORT_OF opq_0.ingress_3

add_interface egress avalon_streaming source
set_interface_property egress EXPORT_OF opq_0.egress

save_system {opq_upstream_4lane.qsys}
