package require Tcl 8.5

namespace eval ::fe_scifi::board_bring_up::debug {
        variable output_path "/tmp/board_bring_up_runtime_probe.txt"
}

proc ::fe_scifi::board_bring_up::debug::write_lines {lines} {
        variable output_path
        set fd [open $output_path w]
        foreach line $lines {
                puts $fd $line
        }
        close $fd
}

proc ::fe_scifi::board_bring_up::debug::summarize_inventory {inventory type_name} {
        if {![dict exists $inventory $type_name]} {
                return ""
        }

        set rendered [list]
        foreach entry [dict get $inventory $type_name] {
                lappend rendered [format "%s|%s" [dict get $entry base] [dict get $entry hpath]]
        }
        return [join $rendered ";"]
}

proc ::fe_scifi::board_bring_up::debug::run {} {
        set lines [list]
        set display_name ""
        if {[info exists ::env(DISPLAY)]} {
                set display_name $::env(DISPLAY)
        }
        lappend lines "DISPLAY=$display_name"

        if {[catch {
                ::mu3e::helpers::show_servicePaths4comboBox "master" "jtagMasterGroup_showmp_comboBox"
                set master_path [::mu3e::helpers::get_selected_servicePath "jtagMasterGroup_showmp_comboBox"]
                lappend lines "MASTER_PATH=$master_path"

                set master_fd [::mu3e::helpers::open_master_service $master_path]
                toolkit_set_property "fd_master_path_text" text $master_fd
                lappend lines "MASTER_FD=$master_fd"

                set fd_global_variable "globalVariableTable"
                set link_id [::mu3e::helpers::get_global_variable $fd_global_variable "link_id"]
                lappend lines "LINK_ID=$link_id"
                lappend lines "CSR_META_DIR=[namespace eval ::data_path_bts::gui {set csr_meta_dir}]"
                lappend lines "PROJECT_ROOT=[namespace eval ::data_path_bts::gui {set project_root}]"
                lappend lines "SOPCINFO_CANDIDATES=[join [::data_path_bts::gui::sopcinfo_candidates] ,]"

                set compiled_inventory [::data_path_bts::gui::compiled_slave_inventory]
                if {$compiled_inventory eq ""} {
                        lappend lines "COMPILED_SOURCE="
                        lappend lines "EXPECTED_TYPES="
                        set live_inventory [dict create]
                } else {
                        set expected_types [lsort [dict keys [dict get $compiled_inventory by_type]]]
                        lappend lines "COMPILED_SOURCE=[dict get $compiled_inventory source]"
                        lappend lines "EXPECTED_TYPES=[join $expected_types ,]"
                        set live_inventory [::mu3e::helpers::collect_live_marker_inventory $link_id $expected_types]
                        foreach type_name $expected_types {
                                lappend lines "LIVE_${type_name}=[::fe_scifi::board_bring_up::debug::summarize_inventory $live_inventory $type_name]"
                        }
                }

                ::mu3e::helpers::link_slave
                lappend lines "AUTOLINK_STATUS=[toolkit_get_property autoLink_text text]"
        } probe_error probe_options]} {
                lappend lines "PROBE_ERROR=$probe_error"
                if {[dict exists $probe_options -errorinfo]} {
                        lappend lines "PROBE_ERRORINFO=[dict get $probe_options -errorinfo]"
                }
                if {[llength [info commands toolkit_send_message]] > 0} {
                        toolkit_send_message error "board_bring_up_runtime_probe: $probe_error"
                }
        }

        ::fe_scifi::board_bring_up::debug::write_lines $lines
        if {[llength [info commands toolkit_send_message]] > 0} {
                toolkit_send_message info "board_bring_up_runtime_probe: wrote [namespace eval ::fe_scifi::board_bring_up::debug {set output_path}]"
        }
}

after 1000 ::fe_scifi::board_bring_up::debug::run
