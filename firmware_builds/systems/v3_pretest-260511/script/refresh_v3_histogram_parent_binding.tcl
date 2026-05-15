set root [expr {[info exists env(MU3E_IP_CORES_ROOT)] ? $env(MU3E_IP_CORES_ROOT) : "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores"}]
set system_dir [file join $root firmware_builds systems v3_pretest-260511]

set datapath_version {3.0.6.515}
set top_description {FEB V3 top with streaming histogram debug plane: scifi_datapath_system_v3 keeps the main MTS-to-rbCAM Type-1 path at 39 bits, carries 48-bit hit timestamp sidebands on readyless MTS extended sources into histogram_statistics_v2, uses 0x100-wide emulator CSR windows, keeps run-control fanout readyless, selects emulator byte streams with static per-lane source muxes, and exports per-lane frame-deassembly parser CSRs.}
set datapath_description {scifi_datapath_system_v3 streaming histogram debug-plane contract: MTS Type-1 payloads remain on the legacy 39-bit main path while readyless hit_type1_extended_0/1 streams carry true hit_ts[47:0] above the payload directly into histogram_statistics_v2; histogram source selection is owned by the histogram CONTROL.in_port CSR; run-control fanout is readyless; decoded lane traffic uses explicit real/emulator source muxes rather than round-robin streaming multiplexers; parser CSRs are exported for live frame debug.}

set avmm_slaves [list \
    {data_path_subsystem_lvds_rx_controller_pro_0.csr 0x0 0x40} \
    {data_path_subsystem_mutrig_reset_controller_0.reconfig_mgmt 0x200 0x300} \
    {data_path_subsystem_mutrig_datapath_subsystem_0_backpressure_fifo.csr 0x860 0x870} \
    {data_path_subsystem_mutrig_datapath_subsystem_1_backpressure_fifo.csr 0x1860 0x1870} \
    {data_path_subsystem_emulator_mutrig_0.csr 0x2000 0x2100} \
    {data_path_subsystem_emulator_mutrig_1.csr 0x2100 0x2200} \
    {data_path_subsystem_emulator_mutrig_2.csr 0x2200 0x2300} \
    {data_path_subsystem_emulator_mutrig_3.csr 0x2300 0x2400} \
    {data_path_subsystem_emulator_mutrig_4.csr 0x2400 0x2500} \
    {data_path_subsystem_emulator_mutrig_5.csr 0x2500 0x2600} \
    {data_path_subsystem_emulator_mutrig_6.csr 0x2600 0x2700} \
    {data_path_subsystem_emulator_mutrig_7.csr 0x2700 0x2800} \
    {data_path_subsystem_dbg_mm2runctrl_0.csr 0x2800 0x2840} \
    {data_path_subsystem_mutrig_datapath_subsystem_2_backpressure_fifo.csr 0x2860 0x2870} \
    {data_path_subsystem_mutrig_lane_source_mux_0.csr 0x2880 0x28C0} \
    {data_path_subsystem_mutrig_lane_source_mux_1.csr 0x28C0 0x2900} \
    {data_path_subsystem_mutrig_lane_source_mux_2.csr 0x2900 0x2940} \
    {data_path_subsystem_mutrig_lane_source_mux_3.csr 0x2940 0x2980} \
    {data_path_subsystem_mutrig_lane_source_mux_4.csr 0x2980 0x29C0} \
    {data_path_subsystem_mutrig_lane_source_mux_5.csr 0x29C0 0x2A00} \
    {data_path_subsystem_mutrig_lane_source_mux_6.csr 0x2A00 0x2A40} \
    {data_path_subsystem_mutrig_lane_source_mux_7.csr 0x2A40 0x2A80} \
    {data_path_subsystem_mutrig_datapath_subsystem_0.csr 0x2A80 0x2A90} \
    {data_path_subsystem_mutrig_datapath_subsystem_1.csr 0x2A90 0x2AA0} \
    {data_path_subsystem_mutrig_datapath_subsystem_2.csr 0x2AA0 0x2AB0} \
    {data_path_subsystem_mutrig_datapath_subsystem_3.csr 0x2AB0 0x2AC0} \
    {data_path_subsystem_mutrig_datapath_subsystem_4.csr 0x2AC0 0x2AD0} \
    {data_path_subsystem_mutrig_datapath_subsystem_5.csr 0x2AD0 0x2AE0} \
    {data_path_subsystem_mutrig_datapath_subsystem_6.csr 0x2AE0 0x2AF0} \
    {data_path_subsystem_mutrig_datapath_subsystem_7.csr 0x2AF0 0x2B00} \
    {data_path_subsystem_mutrig_datapath_subsystem_3_backpressure_fifo.csr 0x3860 0x3870} \
    {data_path_subsystem_mts_preprocessor_0.csr 0x4000 0x4020} \
    {data_path_subsystem_mutrig_datapath_subsystem_4_backpressure_fifo.csr 0x4860 0x4870} \
    {data_path_subsystem_mutrig_datapath_subsystem_5_backpressure_fifo.csr 0x5860 0x5870} \
    {data_path_subsystem_mutrig_datapath_subsystem_6_backpressure_fifo.csr 0x6860 0x6870} \
    {data_path_subsystem_mutrig_datapath_subsystem_7_backpressure_fifo.csr 0x7860 0x7870} \
    {data_path_subsystem_mts_preprocessor_1.csr 0x8000 0x8020} \
    {data_path_subsystem_histogram_statistics_0.hist_bin 0xA000 0xA400} \
    {data_path_subsystem_histogram_statistics_0.csr 0xA400 0xA480} \
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

proc build_address_map {slaves} {
    set address_map "<address-map>"
    foreach slave $slaves {
        foreach {name start end} $slave {
            break
        }
        append address_map "<slave name='$name' start='$start' end='$end' />"
    }
    append address_map "</address-map>"
    return $address_map
}

proc read_text {path} {
    set fd [open $path r]
    set text [read $fd]
    close $fd
    return $text
}

proc write_text {path text} {
    exec chmod u+w $path
    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
}

proc replace_component_metadata {text version description path} {
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

    set desc_idx [string first {description="} $text $comp_idx]
    if {$desc_idx >= 0} {
        set desc_start [expr {$desc_idx + [string length {description="}]}]
        set desc_end [string first {"} $text $desc_start]
        if {$desc_end < 0} {
            error "Unterminated component description attribute in $path"
        }
        set text [string replace $text $desc_start [expr {$desc_end - 1}] $description]
    }

    return $text
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

proc update_datapath_component {path version description} {
    if {![file exists $path]} {
        puts "INFO: metadata target not present: $path"
        return
    }

    set text [replace_component_metadata [read_text $path] $version $description $path]
    write_text $path $text
    puts "INFO: updated datapath metadata: $path"
}

proc update_top_binding {path version description address_map} {
    if {![file exists $path]} {
        puts "INFO: top qsys target not present: $path"
        return
    }

    set text [read_text $path]
    set text [replace_component_metadata $text $version $description $path]
    set text [replace_module_version $text data_path_subsystem $version $path]
    set text [replace_xml_cdata_parameter $text AUTO_AVMM_PORT_ADDRESS_MAP $address_map $path]
    write_text $path $text
    puts "INFO: updated top datapath binding and CSR map: $path"
}

set address_map [build_address_map $avmm_slaves]

foreach path [list \
    [file join $root quartus_systems scifi_datapath_system_v3.qsys] \
    [file join $root quartus_systems scifi_datapath_system_v3_pipe.qsys] \
    [file join $root quartus_systems scifi_datapath_system_v3_lat4.qsys] \
] {
    update_datapath_component $path $datapath_version $datapath_description
}

update_top_binding \
    [file join $root quartus_systems feb_system_v3.qsys] \
    $datapath_version \
    $top_description \
    $address_map

update_top_binding \
    [file join $system_dir syn feb_system_v3.qsys] \
    $datapath_version \
    $top_description \
    $address_map
