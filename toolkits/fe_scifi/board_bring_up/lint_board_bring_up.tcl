package require Tcl 8.5

set script_dir [file dirname [info script]]
set repo_root [file normalize [file join $script_dir .. .. ..]]

namespace eval ::lint_gui {
        variable widgets
        variable table_cells
        variable messages

        array set widgets {}
        array set table_cells {}
        set messages [list]
}

proc ::lint_gui::init_widget {name type parent} {
        variable widgets
        set widgets($name,type) $type
        set widgets($name,parent) $parent
        set widgets($name,visible) 1
        set widgets($name,enabled) 1
        set widgets($name,text) ""
        if {$type eq "comboBox"} {
                set widgets($name,options) [list]
                set widgets($name,selectedItem) ""
        }
        if {$type eq "checkBox"} {
                set widgets($name,checked) 0
        }
        if {$type eq "table"} {
                set widgets($name,rowCount) 0
                set widgets($name,columnCount) 0
                set widgets($name,rowIndex) 0
                set widgets($name,columnIndex) 0
        }
        if {$type eq "barChart"} {
                set widgets($name,itemValue) [list]
        }
}

proc ::lint_gui::widget_exists {name} {
        variable widgets
        return [info exists widgets($name,type)]
}

proc toolkit_add {name type parent} {
        if {$parent ne "self" && ![::lint_gui::widget_exists $parent]} {
                error "lint_gui: missing parent widget \"$parent\" for \"$name\""
        }
        ::lint_gui::init_widget $name $type $parent
}

proc toolkit_set_property {widget property value} {
        variable ::lint_gui::widgets
        variable ::lint_gui::table_cells

        if {![info exists widgets($widget,type)] && $widget ne "self"} {
                error "lint_gui: widget \"$widget\" does not exist"
        }

        if {$widget eq "self"} {
                set widgets(self,type) root
        }

        if {[info exists widgets($widget,type)] && $widgets($widget,type) eq "table" && $property eq "cellText"} {
                set row $widgets($widget,rowIndex)
                set col $widgets($widget,columnIndex)
                set table_cells($widget,$row,$col) $value
                return
        }

        if {[info exists widgets($widget,type)] && $widgets($widget,type) eq "barChart" && $property eq "itemValue"} {
                lappend widgets($widget,itemValue) $value
                return
        }

        set widgets($widget,$property) $value
}

proc toolkit_get_property {widget property} {
        variable ::lint_gui::widgets
        variable ::lint_gui::table_cells

        if {![info exists widgets($widget,type)] && $widget ne "self"} {
                        error "lint_gui: widget \"$widget\" does not exist"
        }

        if {$widget eq "self"} {
                set widgets(self,type) root
        }

        if {[info exists widgets($widget,type)] && $widgets($widget,type) eq "table" && $property eq "cellText"} {
                set row $widgets($widget,rowIndex)
                set col $widgets($widget,columnIndex)
                if {[info exists table_cells($widget,$row,$col)]} {
                        return $table_cells($widget,$row,$col)
                }
                return ""
        }

        if {[info exists widgets($widget,$property)]} {
                return $widgets($widget,$property)
        }

        return ""
}

proc toolkit_send_message {level message} {
        variable ::lint_gui::messages
        lappend messages [list $level $message]
}

proc get_service_paths {service_type} {
        return [list]
}

proc claim_service {service_type service_path client_name extra} {
        return "dummy-${service_type}"
}

proc marker_get_info {service_path} {
        return [list]
}

proc master_read_32 {master_ticket address count} {
        if {$count <= 1} {
                return 0
        }
        set values [list]
        for {set index 0} {$index < $count} {incr index} {
                lappend values 0
        }
        return $values
}

proc master_write_32 {master_ticket address data} {
        return -code ok
}

proc jtag_debug_reset_system {service_path} {
        return -code ok
}

rename ::after ::lint_builtin_after
proc after {args} {
        return ""
}

proc assert_true {condition message} {
        if {!$condition} {
                error $message
        }
}

proc assert_equals {actual expected message} {
        if {![string equal $actual $expected]} {
                error "$message: expected \"$expected\", got \"$actual\""
        }
}

proc check_no_tabs {path} {
        if {![file exists $path]} {
                puts "lint_board_bring_up: skipping missing optional file $path"
                return
        }
        set fd [open $path r]
        set text [read $fd]
        close $fd
        if {[string first "\t" $text] >= 0} {
                error "tab character found in $path"
        }
}

::lint_gui::init_widget self root ""

set files_to_scan [list \
        [file join $repo_root toolkits infra board_bring_up lib board_bring_up_meta.tcl] \
        [file join $repo_root mu3e_lvds_controller lvds_rx_controller_pro_csr_meta.tcl] \
        [file join $repo_root mutrig_frame_deassembly mutrig_frame_deassembly_csr_meta.tcl] \
        [file join $repo_root mutrig_timestamp_processor mts_processor_csr_meta.tcl] \
        [file join $repo_root feb_frame_assembly feb_frame_assembly_csr_meta.tcl] \
        [file join $repo_root charge_injection mutrig_injector_csr_meta.tcl] \
        [file join $repo_root ring-buffer_cam script ring_buffer_cam_csr_meta.tcl] \
        [file join $repo_root histogram_statistics histogram_statistics_v2_csr_meta.tcl] \
        [file join $script_dir fe_scifi_board_bring_up_project.tcl] \
        [file join $script_dir board_bring_up.tcl] \
        [file join $script_dir lint_board_bring_up.tcl]]

foreach file_path $files_to_scan {
        check_no_tabs $file_path
}

source [file join $script_dir board_bring_up.tcl]

assert_true [::lint_gui::widget_exists board_bring_up_tabs] "missing top-level tab widget"
assert_true [::lint_gui::widget_exists histogram_ingress_write_button] "missing histogram ingress write button"
assert_true [::lint_gui::widget_exists ring_buffer_cam_subtabs] "missing ring-buffer tab group"
assert_equals [toolkit_get_property histogram_ingress_write_button enabled] false "histogram ingress write button must stay disabled before read"
assert_equals [toolkit_get_property self title] "Board Bring Up (Datapath)" "unexpected toolkit title"

puts "PASS: board_bring_up smoke lint"
