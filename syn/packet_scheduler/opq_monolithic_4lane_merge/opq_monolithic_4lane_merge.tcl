package require -exact qsys 16.0

create_system {opq_monolithic_4lane_merge}

set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

add_instance opq_0 ordered_priority_queue 25.0.722
set_instance_parameter_value opq_0 {N_LANE} {4}
set_instance_parameter_value opq_0 {MODE} {MERGING}
set_instance_parameter_value opq_0 {TRACK_HEADER} {true}
set_instance_parameter_value opq_0 {INGRESS_DATA_WIDTH} {32}
set_instance_parameter_value opq_0 {INGRESS_DATAK_WIDTH} {4}
set_instance_parameter_value opq_0 {CHANNEL_WIDTH} {2}
set_instance_parameter_value opq_0 {LANE_FIFO_DEPTH} {1024}
set_instance_parameter_value opq_0 {LANE_FIFO_WIDTH} {40}
set_instance_parameter_value opq_0 {TICKET_FIFO_DEPTH} {256}
set_instance_parameter_value opq_0 {HANDLE_FIFO_DEPTH} {64}
set_instance_parameter_value opq_0 {PAGE_RAM_DEPTH} {65536}
set_instance_parameter_value opq_0 {PAGE_RAM_RD_WIDTH} {36}
set_instance_parameter_value opq_0 {N_SHD} {256}
set_instance_parameter_value opq_0 {N_HIT} {255}
set_instance_parameter_value opq_0 {FRAME_SERIAL_SIZE} {16}
set_instance_parameter_value opq_0 {FRAME_SUBH_CNT_SIZE} {16}
set_instance_parameter_value opq_0 {FRAME_HIT_CNT_SIZE} {16}
set_instance_parameter_value opq_0 {DEBUG_LV} {1}

add_interface clk clock sink
set_interface_property clk EXPORT_OF opq_0.clk_interface

add_interface reset reset sink
set_interface_property reset EXPORT_OF opq_0.rst_interface

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

save_system {opq_monolithic_4lane_merge.qsys}
