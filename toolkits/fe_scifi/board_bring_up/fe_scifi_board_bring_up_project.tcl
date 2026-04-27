package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up::project {
        variable script_dir [file dirname [info script]]
}

proc ::fe_scifi::board_bring_up::project::repo_root {} {
        variable script_dir
        set candidates [list \
                [file normalize [file join $script_dir .. .. ..]] \
                [file normalize [file join $::env(HOME) packages mu3e_ip_dev mu3e-ip-cores]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online mu3e-ip-cores]] \
        ]

        foreach candidate $candidates {
                if {[file exists [file join $candidate mu3e_lvds_controller lvds_rx_controller_pro_hw.tcl]] &&
                    [file exists [file join $candidate histogram_statistics histogram_statistics_hw.tcl]]} {
                        return $candidate
                }
        }

        error "unable to locate mu3e-ip-cores from script_dir=$script_dir pwd=[pwd]"
}

proc ::fe_scifi::board_bring_up::project::project_root {} {
        variable script_dir
        return [file normalize [file join $script_dir ..]]
}

proc ::fe_scifi::board_bring_up::project::shared_file {args} {
        return [file join [::fe_scifi::board_bring_up::project::repo_root] {*}$args]
}

proc ::fe_scifi::board_bring_up::project::get_spec {} {
        set repo_root [::fe_scifi::board_bring_up::project::repo_root]

        set histogram_rate_preset [dict create \
                id "rate" \
                label "8 MuTRiG Channel Rate" \
                sample_interval_ms 1000 \
                sample_guard_ms 50 \
                field_values [dict create \
                        "csr.mode" "0x0" \
                        "csr.representation" "0x1" \
                        "csr.filter" "0x0" \
                        "left_bound.left_bound" "0x0" \
                        "bin_width.bin_width" "0x1" \
                        "keys_location.update_key_low" "0x24" \
                        "keys_location.update_key_high" "0x28" \
                        "keys_location.filter_key_low" "0x24" \
                        "keys_location.filter_key_high" "0x28" \
                        "keys_value.filter_key_value" "0x0" \
                        "keys_value.update_key_value" "0x0" \
                        "interval_cfg.interval_clocks" "0x07735940" \
                        "csr.commit" "0x1"]]

        set inventory [list \
                [dict create type_name "lvds_rx_controller_pro.csr" copies 1 expected_bases [list "0x00000000"]] \
                [dict create type_name "mutrig_frame_deassembly.csr" copies 8 expected_bases [list "0x00010900" "0x00011900" "0x00012900" "0x00013900" "0x00014900" "0x00015900" "0x00016900" "0x00017900"]] \
                [dict create type_name "histogram_statistics.csr" copies 2 expected_bases [list "0x00020400" "0x00020C00"]] \
                [dict create type_name "histogram_statistics.hist_bin" copies 2 expected_bases [list "0x00020000" "0x00020800"]] \
                [dict create type_name "mts_preprocessor.csr" copies 2 expected_bases [list "0x00004000" "0x00008000"]] \
                [dict create type_name "ring_buffer_cam.csr" copies 8 expected_bases [list "0x00021000" "0x00021080" "0x00021100" "0x00021180" "0x00023000" "0x00023080" "0x00023100" "0x00023180"]] \
                [dict create type_name "feb_frame_assembly.csr" copies 2 expected_bases [list "0x00025000" "0x00025040"]] \
                [dict create type_name "mutrig_injector.csr" copies 1 expected_bases [list "0x00022000"]]]

        set ip_sequence [list \
                [dict create \
                        id "lvds_rx" \
                        title "LVDS RX Controller" \
                        type_name "lvds_rx_controller_pro.csr" \
                        meta_file [file join $repo_root mu3e_lvds_controller lvds_rx_controller_pro_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::lvds_rx_controller_pro" \
                        hw_file [file join $repo_root mu3e_lvds_controller lvds_rx_controller_pro_hw.tcl] \
                        config_options [list -n_lane 9]] \
                [dict create \
                        id "frame_deassembly" \
                        title "MuTRiG Frame Deassembly" \
                        type_name "mutrig_frame_deassembly.csr" \
                        meta_file [file join $repo_root mutrig_frame_deassembly mutrig_frame_deassembly_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::mutrig_frame_deassembly" \
                        hw_file [file join $repo_root mutrig_frame_deassembly mutrig_frame_deassembly_hw.tcl] \
                        instance_titles [list "MuTRiG 0" "MuTRiG 1" "MuTRiG 2" "MuTRiG 3" "MuTRiG 4" "MuTRiG 5" "MuTRiG 6" "MuTRiG 7"]] \
                [dict create \
                        id "histogram_ingress" \
                        title "Histogram Statistics 0" \
                        type_name "histogram_statistics.csr" \
                        hist_type_name "histogram_statistics.hist_bin" \
                        instance_indices [list 0] \
                        expected_version [dict create major 26 minor 0 patch 0 build 321] \
                        meta_file [file join $repo_root histogram_statistics histogram_statistics_v2_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::histogram_statistics_v2" \
                        hw_file [file join $repo_root histogram_statistics histogram_statistics_v2_hw.tcl] \
                        histogram_bins 256 \
                        histogram_clear_before_read 0 \
                        presets [list $histogram_rate_preset]] \
                [dict create \
                        id "mts_preprocessor" \
                        title "MuTRiG Timestamp Processor" \
                        type_name "mts_preprocessor.csr" \
                        meta_file [file join $repo_root mutrig_timestamp_processor mts_processor_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::mts_processor" \
                        hw_file [file join $repo_root mutrig_timestamp_processor mts_processor_hw.tcl] \
                        instance_titles [list "Processor UP" "Processor DW"]] \
                [dict create \
                        id "ring_buffer_cam" \
                        title "Ring Buffer CAM" \
                        type_name "ring_buffer_cam.csr" \
                        meta_file [file join $repo_root ring-buffer_cam script ring_buffer_cam_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::ring_buffer_cam" \
                        hw_file [file join $repo_root ring-buffer_cam script ring_buffer_cam_hw.tcl] \
                        instance_titles [list "Stack 0 / Ring 0" "Stack 0 / Ring 1" "Stack 0 / Ring 2" "Stack 0 / Ring 3" "Stack 1 / Ring 0" "Stack 1 / Ring 1" "Stack 1 / Ring 2" "Stack 1 / Ring 3"]] \
                [dict create \
                        id "histogram_egress" \
                        title "Histogram Statistics 1" \
                        type_name "histogram_statistics.csr" \
                        hist_type_name "histogram_statistics.hist_bin" \
                        instance_indices [list 1] \
                        expected_version [dict create major 26 minor 0 patch 0 build 321] \
                        meta_file [file join $repo_root histogram_statistics histogram_statistics_v2_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::histogram_statistics_v2" \
                        hw_file [file join $repo_root histogram_statistics histogram_statistics_v2_hw.tcl] \
                        histogram_bins 256 \
                        histogram_clear_before_read 0] \
                [dict create \
                        id "feb_frame_assembly" \
                        title "FEB Frame Assembly" \
                        type_name "feb_frame_assembly.csr" \
                        meta_file [file join $repo_root feb_frame_assembly feb_frame_assembly_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::feb_frame_assembly" \
                        hw_file [file join $repo_root feb_frame_assembly feb_frame_assembly_hw.tcl] \
                        instance_titles [list "Assembly 0" "Assembly 1"]] \
                [dict create \
                        id "mutrig_injector" \
                        title "MuTRiG Injector" \
                        type_name "mutrig_injector.csr" \
                        meta_file [file join $repo_root charge_injection mutrig_injector_csr_meta.tcl] \
                        meta_namespace "::board_bring_up::meta::mutrig_injector" \
                        hw_file [file join $repo_root charge_injection mutrig_injector_hw.tcl] \
                        config_options [list -HEADERINFO_CHANNEL_W 4]]]

        return [dict create \
                title "Board Bring Up (Datapath)" \
                preferred_link_ids [list "1#7-2"] \
                preferred_device_patterns [list "5AGXBA7D4" "5AGT("] \
                preferred_service_patterns [dict create \
                        master [list \
                                "/phy_1/master" \
                                "alt_sld_fab_sldfabric.node_4/phy_1/data_path_subsystem_master_datapath.master" \
                                "data_path_subsystem_master_datapath.master"] \
                        jtag_debug [list \
                                "/phy_1" \
                                "alt_sld_fab_sldfabric.node_4/phy_1" \
                                "alt_sld_fab_sldfabric.node_2/phy_0" \
                                "alt_sld_fab_sldfabric.node_5/phy_2"] \
                        marker [list \
                                "/phy_1/master" \
                                "/phy_1" \
                                "alt_sld_fab_sldfabric.node_4/phy_1/data_path_subsystem_master_datapath.master" \
                                "data_path_subsystem_master_datapath.master" \
                                "control_path_subsystem_jtag_master.master" \
                                "upload_subsystem_upload_system_jtag_master.master"]] \
                notes [list \
                        "Project wrapper for scifi_datapath_v2_system master_datapath address map." \
                        "Write-back stays disabled until a successful read populates the dashboard state." \
                        "Histogram Statistics 0 includes the preset for 8 MuTRiG channel-rate monitoring."] \
                inventory $inventory \
                ip_sequence $ip_sequence]
}
