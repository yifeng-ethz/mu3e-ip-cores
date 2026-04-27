package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up::debug::cli {
        variable output_path "/tmp/board_bring_up_cli_probe.txt"
}

if {[llength [info commands toolkit_send_message]] == 0} {
        proc toolkit_send_message {level msg} {
                puts stderr "[string toupper $level]: $msg"
        }
}

proc ::fe_scifi::board_bring_up::debug::cli::resolve_project_root {} {
        set candidates [list]
        if {[info exists ::env(FE_SCIFI_PROJECT_ROOT)] && $::env(FE_SCIFI_PROJECT_ROOT) ne ""} {
                lappend candidates [file normalize $::env(FE_SCIFI_PROJECT_ROOT)]
        }
        lappend candidates \
                [file normalize [pwd]] \
                [file normalize [file join [file dirname [info script]] .. .. .. .. .. fe_board fe_scifi]] \
                [file normalize [file join $::env(HOME) packages online_dpv2 online fe_board fe_scifi]]

        foreach candidate $candidates {
                if {[file exists [file join $candidate bts register_toolboxes.tcl]] &&
                    [llength [glob -nocomplain [file join $candidate *.sopcinfo]]] > 0} {
                        return $candidate
                }
        }

        error "unable to locate FE SciFi project root from pwd=[pwd] script=[info script]"
}

proc ::fe_scifi::board_bring_up::debug::cli::configure_runtime_paths {project_root} {
        set tcllib_dir /data1/intelFPGA/18.1/quartus/common/tcl/packages/tcllib-1.11
        set lib_dir [file join $project_root system_console lib]

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
}

proc ::fe_scifi::board_bring_up::debug::cli::compare_inventory {compiled_inventory live_inventory} {
        set mismatch_types [list]
        set detail_lines [list]
        set expected_types [lsort [dict keys [dict get $compiled_inventory by_type]]]

        foreach type_name $expected_types {
                set expected_entries [dict get $compiled_inventory by_type $type_name]
                set actual_entries [list]
                if {[dict exists $live_inventory $type_name]} {
                        set actual_entries [dict get $live_inventory $type_name]
                }

                set expected_bases [list]
                foreach entry $expected_entries {
                        lappend expected_bases [dict get $entry base]
                }

                set actual_bases [list]
                foreach entry $actual_entries {
                        lappend actual_bases [dict get $entry base]
                }

                set missing_bases [list]
                foreach expected_base $expected_bases {
                        if {[lsearch -exact $actual_bases $expected_base] < 0} {
                                lappend missing_bases $expected_base
                        }
                }

                set extra_bases [list]
                foreach actual_base $actual_bases {
                        if {[lsearch -exact $expected_bases $actual_base] < 0} {
                                lappend extra_bases $actual_base
                        }
                }

                if {[llength $missing_bases] > 0 || [llength $extra_bases] > 0} {
                        lappend mismatch_types $type_name
                        lappend detail_lines "${type_name}: expected bases ${expected_bases}, live bases ${actual_bases}, missing ${missing_bases}, unexpected ${extra_bases}"
                }
        }

        if {[dict size $live_inventory] == 0} {
                return [dict create status NO_TYPED_MARKERS mismatch_types $expected_types details [list "plain CLI did not expose typed datapath marker services on the selected link; use the toolkit runtime probe for authoritative GUI-side validation"]]
        }

        if {[llength $mismatch_types] > 0} {
                return [dict create status MISMATCH mismatch_types $mismatch_types details $detail_lines]
        }

        return [dict create status OK mismatch_types [list] details [list]]
}

proc ::fe_scifi::board_bring_up::debug::cli::summarize_inventory {inventory type_name} {
        if {![dict exists $inventory $type_name]} {
                return ""
        }

        set rendered [list]
        foreach entry [dict get $inventory $type_name] {
                lappend rendered [format "%s|%s" [dict get $entry base] [dict get $entry hpath]]
        }
        return [join $rendered ";"]
}

proc ::fe_scifi::board_bring_up::debug::cli::write_lines {lines} {
        variable output_path
        set fd [open $output_path w]
        foreach line $lines {
                puts $fd $line
        }
        close $fd
}

proc ::fe_scifi::board_bring_up::debug::cli::main {} {
        variable output_path

        set project_root [::fe_scifi::board_bring_up::debug::cli::resolve_project_root]
        set ::env(FE_SCIFI_PROJECT_ROOT) $project_root
        ::fe_scifi::board_bring_up::debug::cli::configure_runtime_paths $project_root

        package require mu3e::helpers 1.0
        package require data_path_bts::gui 1.0

        set project_script [file join $project_root board_bring_up fe_scifi_board_bring_up_project.tcl]
        source $project_script
        ::mu3e::helpers::clear_service_preferences
        ::mu3e::helpers::configure_project_spec [::fe_scifi::board_bring_up::project::get_spec]
        ::data_path_bts::gui::configure_csr_meta_dir [file join $project_root board_bring_up csr_meta]

        set master_paths [::mu3e::helpers::prioritize_service_paths master [get_service_paths master]]
        if {[llength $master_paths] == 0} {
                error "no live master services found"
        }

        set master_path [lindex $master_paths 0]
        set link_id [::mu3e::helpers::extract_link_id $master_path]
        set master_fd [claim_service master $master_path mylib ""]

        set compiled_inventory [::data_path_bts::gui::compiled_slave_inventory]
        if {$compiled_inventory eq ""} {
                error "unable to parse compiled .sopcinfo inventory under $project_root"
        }

        set expected_types [lsort [dict keys [dict get $compiled_inventory by_type]]]
        set live_inventory [::mu3e::helpers::collect_live_marker_inventory $link_id $expected_types]
        set comparison [::fe_scifi::board_bring_up::debug::cli::compare_inventory $compiled_inventory $live_inventory]

        set lines [list \
                "PROJECT_ROOT=$project_root" \
                "MASTER_PATH=$master_path" \
                "MASTER_FD=$master_fd" \
                "LINK_ID=$link_id" \
                "COMPILED_SOURCE=[dict get $compiled_inventory source]" \
                "NOTE=CLI inventory is debug-only and may expose fewer marker services than the toolkit runtime" \
                "STATUS=[dict get $comparison status]" \
                "MISMATCH_TYPES=[join [dict get $comparison mismatch_types] ,]"]

        foreach type_name $expected_types {
                lappend lines "LIVE_${type_name}=[::fe_scifi::board_bring_up::debug::cli::summarize_inventory $live_inventory $type_name]"
        }
        foreach detail [dict get $comparison details] {
                lappend lines "DETAIL=$detail"
        }

        close_service master $master_fd
        ::fe_scifi::board_bring_up::debug::cli::write_lines $lines

        puts [join $lines "\n"]
        puts "WROTE=$output_path"
}

::fe_scifi::board_bring_up::debug::cli::main
