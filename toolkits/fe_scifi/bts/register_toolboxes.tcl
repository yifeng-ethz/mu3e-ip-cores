package require Tcl 8.5

namespace eval ::fe_scifi::toolkits {
        variable script_dir [file dirname [info script]]
        variable project_dir ""
}

proc ::fe_scifi::toolkits::resolve_project_dir {} {
        variable script_dir
        set candidates [list \
                [file normalize [pwd]] \
                [file normalize [file join $script_dir ..]] \
                [file normalize [file join $script_dir .. .. .. .. fe_board fe_scifi]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online fe_board fe_scifi]] \
        ]

        foreach candidate $candidates {
                if {[file exists [file join $candidate bts toolkit_debug_datapath debug_datapath.toolkit]] &&
                    [file exists [file join $candidate board_bring_up board_bring_up.toolkit]] &&
                    [llength [glob -nocomplain [file join $candidate *.sopcinfo]]] > 0} {
                        return $candidate
                }
        }

        error "unable to locate FE SciFi project dir from script_dir=$script_dir pwd=[pwd]"
}

set ::fe_scifi::toolkits::project_dir [::fe_scifi::toolkits::resolve_project_dir]
set ::env(FE_SCIFI_PROJECT_ROOT) $::fe_scifi::toolkits::project_dir

proc ::fe_scifi::toolkits::register_file {relative_path} {
        variable project_dir
        toolkit_register [file normalize [file join $project_dir $relative_path]]
}

::fe_scifi::toolkits::register_file "bts/toolkit_temp_sensor/temp_sensor.toolkit"
::fe_scifi::toolkits::register_file "bts/toolkit_debug_datapath/debug_datapath.toolkit"
::fe_scifi::toolkits::register_file "bts/toolkit_firefly/firefly.toolkit"
::fe_scifi::toolkits::register_file "bts/toolkit_debug_sc/debug_sc.toolkit"
::fe_scifi::toolkits::register_file "bts/toolkit_mutrig_controller/mutrig_controller_bts.toolkit"
::fe_scifi::toolkits::register_file "bts/toolkit_debug_datapath/data_path_bts.toolkit"
::fe_scifi::toolkits::register_file "bts/toolkit_upload_subsystem/upload_subsystem_bts.toolkit"
::fe_scifi::toolkits::register_file "board_bring_up/board_bring_up.toolkit"
