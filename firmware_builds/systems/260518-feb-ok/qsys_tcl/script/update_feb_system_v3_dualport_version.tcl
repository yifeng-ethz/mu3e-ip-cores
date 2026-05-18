package require -exact qsys 18.1

if {![info exists env(SYSTEM_DIR)]} {
    error "SYSTEM_DIR is not set"
}

set datapath_description {Direct V3 histogram topology: histogram_statistics_0.N_PORTS=8, type0_lane0..7 connect from hist_type0_lane*_tap.hist while tap.primary preserves the MTS mux path; type1_up/down connect from hist_type1_*_tap.out1 while tap.out0 preserves the hit-stack path; type1_up/down_ts connect directly from the matching MTS timestamp sideband. No histogram_ingress_bridge instance is part of the data path.}
set datapath_version {3.0.6.0517}
set datapath_address_map [join [list \
    {<address-map>} \
    {<slave name='data_path_subsystem_lvds_rx_controller_pro_0.csr' start='0x0' end='0x40' />} \
    {<slave name='data_path_subsystem_mutrig_reset_controller_0.reconfig_mgmt' start='0x200' end='0x300' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_0_backpressure_fifo.csr' start='0x860' end='0x870' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_1_backpressure_fifo.csr' start='0x1860' end='0x1870' />} \
    {<slave name='data_path_subsystem_emulator_mutrig_qsys_inst.csr' start='0x2000' end='0x2100' />} \
    {<slave name='data_path_subsystem_dbg_mm2runctrl_0.csr' start='0x2200' end='0x2240' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_0' start='0x2280' end='0x2300' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_1' start='0x2300' end='0x2380' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_2' start='0x2380' end='0x2400' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_3' start='0x2400' end='0x2480' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_4' start='0x2480' end='0x2500' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_5' start='0x2500' end='0x2580' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_6' start='0x2580' end='0x2600' />} \
    {<slave name='data_path_subsystem_arb_hit_type0_supercore_0.csr_7' start='0x2600' end='0x2680' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_2_backpressure_fifo.csr' start='0x2860' end='0x2870' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_3_backpressure_fifo.csr' start='0x3860' end='0x3870' />} \
    {<slave name='data_path_subsystem_mts_preprocessor_0.csr' start='0x4000' end='0x4020' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_4_backpressure_fifo.csr' start='0x4860' end='0x4870' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_5_backpressure_fifo.csr' start='0x5860' end='0x5870' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_6_backpressure_fifo.csr' start='0x6860' end='0x6870' />} \
    {<slave name='data_path_subsystem_mutrig_datapath_subsystem_7_backpressure_fifo.csr' start='0x7860' end='0x7870' />} \
    {<slave name='data_path_subsystem_mts_preprocessor_1.csr' start='0x8000' end='0x8020' />} \
    {<slave name='data_path_subsystem_histogram_statistics_0.hist_bin' start='0xA000' end='0xA400' />} \
    {<slave name='data_path_subsystem_histogram_statistics_0.csr' start='0xA400' end='0xA480' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_0.csr' start='0xB000' end='0xB080' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_1.csr' start='0xB080' end='0xB100' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_2.csr' start='0xB100' end='0xB180' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_0_ring_buffer_cam_3.csr' start='0xB180' end='0xB200' />} \
    {<slave name='data_path_subsystem_mutrig_injector_0.csr' start='0xB200' end='0xB240' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_0.csr' start='0xB400' end='0xB480' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_1.csr' start='0xB480' end='0xB500' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_2.csr' start='0xB500' end='0xB580' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_1_ring_buffer_cam_3.csr' start='0xB580' end='0xB600' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_0_feb_frame_assembly_0.csr' start='0xD000' end='0xD040' />} \
    {<slave name='data_path_subsystem_hit_stack_subsystem_1_feb_frame_assembly_0.csr' start='0xD040' end='0xD080' />} \
    {</address-map>} \
] ""]

proc update_component_metadata {path version description} {
    if {![file exists $path]} {
        puts "INFO: metadata target not present: $path"
        return
    }

    exec chmod u+w $path
    set fd [open $path r]
    set text [read $fd]
    close $fd

    regsub {^<\?xml version="[^"]*"} $text {<?xml version="1.0"} text

    set comp_idx [string first "<component" $text]
    if {$comp_idx < 0} {
        error "No component header found in $path"
    }
    set ver_idx [string first {version="} $text $comp_idx]
    if {$ver_idx < 0} {
        error "No component version attribute found in $path"
    }
    set value_start [expr {$ver_idx + [string length {version="}]}]
    set value_end [string first {"} $text $value_start]
    if {$value_end < 0} {
        error "Unterminated component version attribute in $path"
    }
    set text [string replace $text $value_start [expr {$value_end - 1}] $version]

    regsub {description="[^"]*"} $text [format {description="%s"} $description] text

    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
    exec chmod a-w $path
    puts "INFO: updated qsys metadata: $path"
}

proc replace_xml_cdata_parameter {text name value path} {
    set marker [format {<parameter name="%s"><![CDATA[} $name]
    set marker_idx [string first $marker $text]
    if {$marker_idx < 0} {
        error "No $name CDATA parameter found in $path"
    }
    set value_start [expr {$marker_idx + [string length $marker]}]
    set value_end [string first {]]></parameter>} $text $value_start]
    if {$value_end < 0} {
        error "Unterminated $name CDATA parameter in $path"
    }
    return [string replace $text $value_start [expr {$value_end - 1}] $value]
}

proc replace_module_version {text module_name version path} {
    set marker [format {<module
   name="%s"} $module_name]
    set module_idx [string first $marker $text]
    if {$module_idx < 0} {
        error "No module $module_name found in $path"
    }
    set ver_idx [string first {version="} $text $module_idx]
    if {$ver_idx < 0} {
        error "No version attribute found for module $module_name in $path"
    }
    set value_start [expr {$ver_idx + [string length {version="}]}]
    set value_end [string first {"} $text $value_start]
    if {$value_end < 0} {
        error "Unterminated version attribute for module $module_name in $path"
    }
    return [string replace $text $value_start [expr {$value_end - 1}] $version]
}

proc remove_exported_interface {text interface_name path} {
    set marker [format {<interface
   name="%s"} $interface_name]
    set interface_idx [string first $marker $text]
    if {$interface_idx < 0} {
        return $text
    }

    set value_end [string first {/>} $text $interface_idx]
    if {$value_end < 0} {
        error "Unterminated interface $interface_name in $path"
    }
    set remove_start $interface_idx
    if {$remove_start > 0 && [string index $text [expr {$remove_start - 1}]] eq " "} {
        set remove_start [expr {$remove_start - 1}]
    }
    set remove_end [expr {$value_end + [string length {/>}] - 1}]
    puts "INFO: removed stale exported interface $interface_name from $path"
    return [string replace $text $remove_start $remove_end {}]
}

proc update_top_datapath_binding {path datapath_version address_map} {
    if {![file exists $path]} {
        puts "INFO: top qsys target not present: $path"
        return
    }

    exec chmod u+w $path
    set fd [open $path r]
    set text [read $fd]
    close $fd

    set text [replace_xml_cdata_parameter \
        $text AUTO_AVMM_PORT_ADDRESS_MAP $address_map $path]
    set text [replace_module_version \
        $text data_path_subsystem $datapath_version $path]
    set text [remove_exported_interface \
        $text pulse_out_conduit $path]

    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
    exec chmod a-w $path
    puts "INFO: updated top datapath binding and CSR map: $path"
}

update_component_metadata \
    [file join $env(SYSTEM_DIR) syn feb_system_v3.qsys] \
    $datapath_version \
    $top_description

update_top_datapath_binding \
    [file join $env(SYSTEM_DIR) syn feb_system_v3.qsys] \
    $datapath_version \
    $datapath_address_map

foreach path [list \
    [file join $env(SYSTEM_DIR) quartus_systems scifi_datapath_system_v3.qsys] \
] {
    update_component_metadata $path $datapath_version $datapath_description
}
