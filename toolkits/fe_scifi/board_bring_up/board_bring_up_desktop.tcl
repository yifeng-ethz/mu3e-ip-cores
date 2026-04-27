package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up::desktop {
        variable script_dir [file dirname [info script]]
        variable project_dir ""
}

proc ::fe_scifi::board_bring_up::desktop::resolve_project_dir {} {
        variable script_dir
        set candidates [list \
                [file normalize [pwd]] \
                [file normalize [file join $script_dir ..]] \
                [file normalize [file join $script_dir .. .. .. .. fe_board fe_scifi]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online fe_board fe_scifi]] \
        ]

        foreach candidate $candidates {
                if {[file exists [file join $candidate bts register_toolboxes.tcl]] &&
                    [file exists [file join $candidate board_bring_up board_bring_up.toolkit]] &&
                    [llength [glob -nocomplain [file join $candidate *.sopcinfo]]] > 0} {
                        return $candidate
                }
        }

        error "unable to locate FE SciFi project dir from script_dir=$script_dir pwd=[pwd]"
}

set ::fe_scifi::board_bring_up::desktop::project_dir [::fe_scifi::board_bring_up::desktop::resolve_project_dir]
set ::env(FE_SCIFI_PROJECT_ROOT) $::fe_scifi::board_bring_up::desktop::project_dir

proc ::fe_scifi::board_bring_up::desktop::launch {} {
        variable script_dir
        variable project_dir

        set register_script [file join $project_dir bts register_toolboxes.tcl]

        if {[catch {
                cd $project_dir
                source $register_script
                toolkit_open board_bring_up
        } result options]} {
                puts stderr "board_bring_up_desktop: failed to open toolkit: $result"
                if {[dict exists $options -errorinfo]} {
                        puts stderr [dict get $options -errorinfo]
                }
        }
}

after 1500 ::fe_scifi::board_bring_up::desktop::launch
