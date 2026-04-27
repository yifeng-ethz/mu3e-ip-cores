package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up {}

set raw_script_dir [file normalize [file dirname [info script]]]
set script_dir ""
set script_dir_candidates [list]
if {[info exists ::env(FE_SCIFI_PROJECT_ROOT)] && $::env(FE_SCIFI_PROJECT_ROOT) ne ""} {
        lappend script_dir_candidates [file normalize [file join $::env(FE_SCIFI_PROJECT_ROOT) board_bring_up]]
}
lappend script_dir_candidates \
        [file normalize [file join [pwd] board_bring_up]] \
        [file normalize [file join $::env(HOME) packages online_dpv2 online fe_board fe_scifi board_bring_up]] \
        $raw_script_dir

foreach candidate $script_dir_candidates {
        if {[file exists [file join $candidate board_bring_up.tcl]] &&
            [file exists [file join $candidate board_bring_up.toolkit]]} {
                set script_dir $candidate
                break
        }
}

if {$script_dir eq ""} {
        set script_dir $raw_script_dir
}

proc ::fe_scifi::board_bring_up::resolve_project_root {script_dir} {
        set candidates [list]
        if {[info exists ::env(FE_SCIFI_PROJECT_ROOT)] && $::env(FE_SCIFI_PROJECT_ROOT) ne ""} {
                lappend candidates [file normalize $::env(FE_SCIFI_PROJECT_ROOT)]
        }
        lappend candidates \
                [file normalize [file join $script_dir ..]] \
                [file normalize [pwd]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online fe_board fe_scifi]]

        foreach candidate $candidates {
                if {[file exists [file join $candidate bts register_toolboxes.tcl]]} {
                        return $candidate
                }
        }

        error "unable to locate FE SciFi project root from script_dir=$script_dir pwd=[pwd]"
}

proc ::fe_scifi::board_bring_up::resolve_repo_root {script_dir} {
        set candidates [list \
                [file normalize [file join $script_dir .. .. ..]] \
                [file normalize [file join $::env(HOME) packages mu3e_ip_dev mu3e-ip-cores]] \
                [file normalize [file join [pwd] .. .. .. .. mu3e_ip_dev mu3e-ip-cores]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online mu3e-ip-cores]] \
        ]

        foreach candidate $candidates {
                if {[file exists [file join $candidate toolkits infra board_bring_up lib board_bring_up_contract.tcl]]} {
                        return $candidate
                }
        }

        error "unable to locate mu3e-ip-cores toolkits infra from script_dir=$script_dir pwd=[pwd]"
}

proc ::fe_scifi::board_bring_up::resolve_project_script {script_dir} {
        set candidates [list]
        if {[info exists ::env(FE_SCIFI_PROJECT_ROOT)] && $::env(FE_SCIFI_PROJECT_ROOT) ne ""} {
                lappend candidates [file normalize [file join $::env(FE_SCIFI_PROJECT_ROOT) board_bring_up fe_scifi_board_bring_up_project.tcl]]
        }
        lappend candidates \
                [file normalize [file join $script_dir fe_scifi_board_bring_up_project.tcl]] \
                [file normalize [file join [pwd] board_bring_up fe_scifi_board_bring_up_project.tcl]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online fe_board fe_scifi board_bring_up fe_scifi_board_bring_up_project.tcl]]

        foreach candidate $candidates {
                if {[file exists $candidate]} {
                        return $candidate
                }
        }

        error "unable to locate fe_scifi_board_bring_up_project.tcl from script_dir=$script_dir pwd=[pwd]"
}

proc ::fe_scifi::board_bring_up::maybe_run_post_launch_hook {} {
        if {![info exists ::env(FE_SCIFI_BOARD_BRING_UP_POST_LAUNCH_HOOK)]} {
                return -code ok
        }

        set hook_script $::env(FE_SCIFI_BOARD_BRING_UP_POST_LAUNCH_HOOK)
        if {$hook_script eq ""} {
                return -code ok
        }

        if {![file exists $hook_script]} {
                toolkit_send_message warning "Board Bring Up post-launch hook not found: $hook_script"
                return -code ok
        }

        after 1000 [list source $hook_script]
        return -code ok
}

proc ::fe_scifi::board_bring_up::launch_shared_dashboard {script_dir} {
        set repo_root [::fe_scifi::board_bring_up::resolve_repo_root $script_dir]
        set project_script [::fe_scifi::board_bring_up::resolve_project_script $script_dir]

        source [file join $repo_root toolkits infra board_bring_up lib board_bring_up_contract.tcl]
        source [file join $repo_root toolkits infra board_bring_up lib board_bring_up_gui.tcl]
        source $project_script

        ::board_bring_up::gui::launch [::fe_scifi::board_bring_up::project::get_spec]
        ::fe_scifi::board_bring_up::maybe_run_post_launch_hook
}

proc ::fe_scifi::board_bring_up::launch_legacy_dashboard {script_dir reason} {
        set project_root [::fe_scifi::board_bring_up::resolve_project_root $script_dir]
        set lib_dir [file join $project_root system_console lib]
        set csr_meta_dir [file join $script_dir csr_meta]
        set project_script [::fe_scifi::board_bring_up::resolve_project_script $script_dir]
        set tcllib_dir /data1/intelFPGA/18.1/quartus/common/tcl/packages/tcllib-1.11

        if {![file exists [file join $lib_dir data_path_toolkit_gui.tcl]]} {
                error "shared board_bring_up dashboard unavailable ($reason), and legacy FE SciFi dashboard sources are missing at $lib_dir"
        }

        foreach path [list \
                $tcllib_dir \
                $lib_dir \
                [file join $lib_dir tclxml-3.2] \
                [file join $lib_dir tcldom-3.0] \
                [file join $lib_dir tdom-0.9.4-src] \
        ] {
                if {[lsearch -exact $::auto_path $path] < 0} {
                        lappend ::auto_path $path
                }
        }

        toolkit_send_message warning "Shared board_bring_up dashboard unavailable; loading legacy FE SciFi datapath dashboard instead. Root cause: $reason"
        foreach source_file [list \
                mu3e_helpers.tcl \
                lvds_rx_bsp.tcl \
                frame_deassembly_bsp.tcl \
                histogram_statistics_bsp.tcl \
                mutrig_injector_bsp.tcl \
                mts_processor_bsp.tcl \
                ring_buffer_cam_bsp.tcl \
                feb_frame_assembly_bsp.tcl \
                data_path_toolkit_gui.tcl \
        ] {
                source [file join $lib_dir $source_file]
        }

        if {[catch {
                source $project_script
                ::mu3e::helpers::configure_project_spec [::fe_scifi::board_bring_up::project::get_spec]
        } project_error]} {
                toolkit_send_message warning "Failed to apply board-specific service preferences in legacy dashboard: $project_error"
                ::mu3e::helpers::clear_service_preferences
        }

        ::data_path_bts::gui::configure_csr_meta_dir $csr_meta_dir
        ::data_path_bts::gui::setup_all 8 9
        toolkit_set_property self title "Board Bring Up (Datapath)"
        ::fe_scifi::board_bring_up::maybe_run_post_launch_hook
}

if {[catch {
        ::fe_scifi::board_bring_up::launch_shared_dashboard $script_dir
} result]} {
        ::fe_scifi::board_bring_up::launch_legacy_dashboard $script_dir $result
}
