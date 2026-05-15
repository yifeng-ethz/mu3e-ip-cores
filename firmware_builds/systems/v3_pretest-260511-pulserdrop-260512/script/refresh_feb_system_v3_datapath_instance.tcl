package require -exact qsys 18.1

if {![info exists env(SYSTEM_DIR)]} {
    error "SYSTEM_DIR is not set"
}

set system_dir $env(SYSTEM_DIR)
set qsys_path [file join $system_dir syn feb_system_v3.qsys]

if {![file exists $qsys_path]} {
    error "missing parent Qsys: $qsys_path"
}

exec chmod u+w $qsys_path

load_system $qsys_path

if {[lsearch -exact [get_instances] data_path_subsystem] < 0} {
    error "data_path_subsystem instance is absent from $qsys_path"
}
if {[lsearch -exact [get_instances] control_path_subsystem] < 0} {
    error "control_path_subsystem instance is absent from $qsys_path"
}

set avmm_slaves [list \
    {data_path_subsystem_lvds_rx_controller_pro_0.csr 0x0 0x40} \
    {data_path_subsystem_mutrig_reset_controller_0.reconfig_mgmt 0x200 0x300} \
    {data_path_subsystem_mutrig_datapath_subsystem_0_backpressure_fifo.csr 0x860 0x870} \
    {data_path_subsystem_mutrig_datapath_subsystem_1_backpressure_fifo.csr 0x1860 0x1870} \
    {data_path_subsystem_emulator_mutrig_qsys_inst.csr 0x2000 0x2040} \
    {data_path_subsystem_dbg_mm2runctrl_0.csr 0x2200 0x2240} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_0.csr 0x2280 0x2300} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_1.csr 0x2300 0x2380} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_2.csr 0x2380 0x2400} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_3.csr 0x2400 0x2480} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_4.csr 0x2480 0x2500} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_5.csr 0x2500 0x2580} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_6.csr 0x2580 0x2600} \
    {data_path_subsystem_arb_hit_type0_supercore_0_lane_7.csr 0x2600 0x2680} \
    {data_path_subsystem_mutrig_datapath_subsystem_2_backpressure_fifo.csr 0x2860 0x2870} \
    {data_path_subsystem_mutrig_datapath_subsystem_3_backpressure_fifo.csr 0x3860 0x3870} \
    {data_path_subsystem_mts_preprocessor_0.csr 0x4000 0x4020} \
    {data_path_subsystem_mutrig_datapath_subsystem_4_backpressure_fifo.csr 0x4860 0x4870} \
    {data_path_subsystem_mutrig_datapath_subsystem_5_backpressure_fifo.csr 0x5860 0x5870} \
    {data_path_subsystem_mutrig_datapath_subsystem_6_backpressure_fifo.csr 0x6860 0x6870} \
    {data_path_subsystem_mutrig_datapath_subsystem_7_backpressure_fifo.csr 0x7860 0x7870} \
    {data_path_subsystem_mts_preprocessor_1.csr 0x8000 0x8020} \
    {data_path_subsystem_histogram_statistics_0.hist_bin 0xA000 0xA400} \
    {data_path_subsystem_histogram_statistics_0.csr 0xA400 0xA480} \
    {data_path_subsystem_histogram_ingress_bridge_0.csr 0xAC00 0xAC10} \
    {data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_0.csr 0xB000 0xB080} \
    {data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_1.csr 0xB080 0xB100} \
    {data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_2.csr 0xB100 0xB180} \
    {data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_3.csr 0xB180 0xB200} \
    {data_path_subsystem_mutrig_injector_0.csr 0xB200 0xB240} \
    {data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_0.csr 0xB400 0xB480} \
    {data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_1.csr 0xB480 0xB500} \
    {data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_2.csr 0xB500 0xB580} \
    {data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_3.csr 0xB580 0xB600} \
    {data_path_subsystem_hit_stack_subsystem_0_feb_frame_assembly_0.csr 0xD000 0xD040} \
    {data_path_subsystem_hit_stack_subsystem_1_feb_frame_assembly_0.csr 0xD040 0xD080} \
]

set address_map "<address-map>"
foreach slave $avmm_slaves {
    foreach {name start end} $slave {
        break
    }
    append address_map "<slave name='$name' start='$start' end='$end' />"
}
append address_map "</address-map>"

validate_instance data_path_subsystem

set_instance_parameter_value control_path_subsystem AUTO_AVMM_PORT_ADDRESS_MAP $address_map
set_instance_parameter_value control_path_subsystem AUTO_AVMM_PORT_ADDRESS_WIDTH {AddressWidth = 16}

save_system $qsys_path

# Platform Designer 18.1 accepts the derived AUTO_AVMM_PORT_ADDRESS_MAP
# assignment above, but save_system recomputes this legacy field from the
# stale parent metadata. Keep the correction in the Tcl recipe so the parent
# XML consumed by qsys-generate exposes the arb CSR windows.
set fd [open $qsys_path r]
set text [read $fd]
close $fd

set map_param "<parameter name=\"AUTO_AVMM_PORT_ADDRESS_MAP\"><!\[CDATA\[$address_map\]\]></parameter>"
if {![regsub {<parameter name="AUTO_AVMM_PORT_ADDRESS_MAP"><!\[CDATA\[[^]]*\]\]></parameter>} $text $map_param updated]} {
    error "failed to replace AUTO_AVMM_PORT_ADDRESS_MAP in $qsys_path"
}

set fd [open $qsys_path w]
puts -nonewline $fd $updated
close $fd

exec chmod a-w $qsys_path
