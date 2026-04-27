###########################################################################################################
# @Name 		data_path_toolkit_gui.tcl
#
# @Brief		Setup the GUI, including base tab and config tab for displaying within the system console.
#
# @Functions	setup_all
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Oct 22, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################

package require mu3e::helpers 1.0
package require lvds_rx::bsp 24.0
package require frame_deassembly::bsp 24.0
package require histogram_statistics::bsp 24.0
package require mutrig_injector::bsp 24.0
package require mts_processor::bsp 24.0
package require ring_buffer_cam::bsp 26.1
package require feb_frame_assembly::bsp 24.0
package require tdom

package provide data_path_bts::gui 1.0

namespace eval ::data_path_bts::gui:: {
	namespace export \
	setup_all \
    configure_csr_meta_dir

    variable csr_meta_dir ""
    variable project_root ""
    variable compiled_sopc_inventory ""
    variable csr_metadata_cache
    variable csr_runtime_version_check_done
    variable rate_histogram_version_warning_done
    variable rate_histogram_address_fallback_done
    array set csr_metadata_cache {}
    array set csr_runtime_version_check_done {}
    array set rate_histogram_version_warning_done {}
    array set rate_histogram_address_fallback_done {}
}

proc ::data_path_bts::gui::configure_csr_meta_dir {path} {
    variable csr_meta_dir
    variable project_root
    variable compiled_sopc_inventory
    variable csr_metadata_cache
    variable csr_runtime_version_check_done
    variable rate_histogram_version_warning_done
    variable rate_histogram_address_fallback_done

    if {[file pathtype $path] eq "relative"} {
        set csr_meta_dir [file join [pwd] $path]
    } else {
        set csr_meta_dir $path
    }
    set project_root [file dirname [file dirname $csr_meta_dir]]
    set compiled_sopc_inventory ""
    catch {array unset csr_metadata_cache *}
    catch {array unset csr_runtime_version_check_done *}
    catch {array unset rate_histogram_version_warning_done *}
    catch {array unset rate_histogram_address_fallback_done *}
    array set csr_metadata_cache {}
    array set csr_runtime_version_check_done {}
    array set rate_histogram_version_warning_done {}
    array set rate_histogram_address_fallback_done {}
    return -code ok
}

proc ::data_path_bts::gui::metadata_key_for_bsp_package {bspPkgName} {
    if {$bspPkgName eq "lvds_rx"} {
        return "lvds"
    }

    return $bspPkgName
}

proc ::data_path_bts::gui::doc_key_for_bsp_package {bspPkgName} {
    return [::data_path_bts::gui::metadata_key_for_bsp_package $bspPkgName]
}

proc ::data_path_bts::gui::kind_for_bsp_package {bspPkgName} {
    array set kind_map {
        lvds_rx lvds_rx_controller_pro
        frame_deassembly mutrig_frame_deassembly
        histogram_statistics histogram_statistics_v2
        mts_processor mts_preprocessor
        ring_buffer_cam ring_buffer_cam
        feb_frame_assembly feb_frame_assembly
        mutrig_injector mutrig_injector
    }

    if {[info exists kind_map($bspPkgName)]} {
        return $kind_map($bspPkgName)
    }

    return ""
}

proc ::data_path_bts::gui::version_namespace_token {version} {
    return [regsub -all {[^[:alnum:]]} $version _]
}

proc ::data_path_bts::gui::xml_escape {text} {
    return [string map [list & "&amp;" < "&lt;" > "&gt;"] $text]
}

proc ::data_path_bts::gui::field_description {field_node} {
    set description_node [$field_node selectNodes "description"]
    if {$description_node eq ""} {
        return "none"
    }

    set description_text [$description_node childNodes]
    if {$description_text eq ""} {
        return "none"
    }

    return [$description_text nodeValue]
}

proc ::data_path_bts::gui::metadata_for_bsp_package {bspPkgName} {
    variable csr_metadata_cache

    set meta_key [::data_path_bts::gui::metadata_key_for_bsp_package $bspPkgName]
    if {[info exists csr_metadata_cache($meta_key)]} {
        return $csr_metadata_cache($meta_key)
    }

    return ""
}

proc ::data_path_bts::gui::histogram_metadata {} {
    set metadata [::data_path_bts::gui::metadata_for_bsp_package "histogram_statistics"]
    if {$metadata ne ""} {
        return $metadata
    }

    catch {::data_path_bts::gui::load_local_metadata_xml "histogram_statistics"}
    return [::data_path_bts::gui::metadata_for_bsp_package "histogram_statistics"]
}

proc ::data_path_bts::gui::contract_register_spec {contract register_name} {
    if {[catch {dict get $contract registers} registers]} {
        return ""
    }

    foreach register $registers {
        if {![dict exists $register name]} {
            continue
        }
        if {[string equal -nocase [dict get $register name] $register_name]} {
            return $register
        }
    }

    return ""
}

proc ::data_path_bts::gui::contract_field_spec {contract register_name field_name} {
    set register_spec [::data_path_bts::gui::contract_register_spec $contract $register_name]
    if {$register_spec eq "" || ![dict exists $register_spec fields]} {
        return ""
    }

    foreach field [dict get $register_spec fields] {
        if {![dict exists $field name]} {
            continue
        }
        if {[string equal -nocase [dict get $field name] $field_name]} {
            return [list $register_spec $field]
        }
    }

    return ""
}

proc ::data_path_bts::gui::parse_contract_bit_range {bit_range} {
    if {![regexp {\[(\d+):(\d+)\]} $bit_range -> msb lsb]} {
        error "unsupported bit range \"$bit_range\""
    }

    return [list [expr {$msb + 0}] [expr {$lsb + 0}]]
}

proc ::data_path_bts::gui::histogram_register_offset {register_name {default_value ""}} {
    set metadata [::data_path_bts::gui::histogram_metadata]
    if {$metadata ne "" && [dict exists $metadata contract]} {
        set register_offset [::data_path_bts::gui::find_register_offset_in_contract [dict get $metadata contract] $register_name]
        if {$register_offset ne ""} {
            return [::data_path_bts::gui::parse_int_literal $register_offset]
        }
    }

    if {$default_value ne ""} {
        return $default_value
    }

    error "unable to resolve histogram register \"$register_name\""
}

proc ::data_path_bts::gui::register_writes_from_contract {contract field_values {commit_field_path ""}} {
    array set register_values {}
    set commit_register_offset ""

    foreach {field_path field_literal} $field_values {
        if {![regexp {^([^\.]+)\.(.+)$} $field_path -> register_name field_name]} {
            error "invalid contract field path \"$field_path\""
        }

        set field_spec [::data_path_bts::gui::contract_field_spec $contract $register_name $field_name]
        if {$field_spec eq ""} {
            error "unable to resolve contract field \"$field_path\""
        }

        lassign $field_spec register_spec resolved_field
        set register_offset [::data_path_bts::gui::parse_int_literal [dict get $register_spec address_offset]]
        lassign [::data_path_bts::gui::parse_contract_bit_range [dict get $resolved_field bit_range]] msb lsb
        set field_width [expr {$msb - $lsb + 1}]
        set field_mask [expr {$field_width >= 32 ? 0xffffffff : ((1 << $field_width) - 1)}]
        set field_value [expr {[::data_path_bts::gui::parse_int_literal $field_literal] & $field_mask}]

        if {![info exists register_values($register_offset)]} {
            set register_values($register_offset) 0
        }

        set register_mask [expr {($field_mask << $lsb) & 0xffffffff}]
        set register_word [expr {$register_values($register_offset) & (~$register_mask & 0xffffffff)}]
        set register_word [expr {$register_word | (($field_value << $lsb) & $register_mask)}]
        set register_values($register_offset) [expr {$register_word & 0xffffffff}]

        if {$commit_field_path ne "" && [string equal -nocase $field_path $commit_field_path]} {
            set commit_register_offset $register_offset
        }
    }

    set register_offsets [lsort -integer [array names register_values]]
    set register_writes [list]
    foreach register_offset $register_offsets {
        if {$commit_register_offset ne "" && $register_offset == $commit_register_offset} {
            continue
        }
        lappend register_writes [list $register_offset $register_values($register_offset)]
    }
    if {$commit_register_offset ne "" && [info exists register_values($commit_register_offset)]} {
        lappend register_writes [list $commit_register_offset $register_values($commit_register_offset)]
    }

    return $register_writes
}

proc ::data_path_bts::gui::find_register_offset_in_contract {contract register_name} {
    if {[catch {dict get $contract registers} registers]} {
        return ""
    }

    foreach register $registers {
        if {![dict exists $register name] || ![dict exists $register address_offset]} {
            continue
        }
        if {[string equal -nocase [dict get $register name] $register_name]} {
            return [dict get $register address_offset]
        }
    }

    return ""
}

proc ::data_path_bts::gui::find_register_write_before_read_in_contract {contract register_name} {
    if {[catch {dict get $contract registers} registers]} {
        return ""
    }

    foreach register $registers {
        if {![dict exists $register name]} {
            continue
        }
        if {[string equal -nocase [dict get $register name] $register_name] && [dict exists $register write_before_read]} {
            return [dict get $register write_before_read]
        }
    }

    return ""
}

proc ::data_path_bts::gui::format_common_csr_header_version {raw_value} {
    set major [expr {($raw_value >> 24) & 0xff}]
    set minor [expr {($raw_value >> 16) & 0xff}]
    set patch [expr {($raw_value >> 12) & 0xf}]
    set build [expr {$raw_value & 0xfff}]
    return [format "%d.%d.%1d%03d" $major $minor $patch $build]
}

proc ::data_path_bts::gui::parse_version_string {version_text} {
    set version_text [string trim $version_text]
    if {$version_text eq ""} {
        return ""
    }

    set parts [split $version_text "."]
    if {[llength $parts] == 3} {
        lassign $parts major minor tail
        if {![string is integer -strict $major] || ![string is integer -strict $minor] || ![string is integer -strict $tail]} {
            return ""
        }

        if {[string length $tail] > 3} {
            set patch [string index $tail 0]
            set build [string range $tail 1 end]
        } else {
            set patch 0
            set build $tail
        }
    } elseif {[llength $parts] == 4} {
        lassign $parts major minor patch build
        if {![string is integer -strict $major] || ![string is integer -strict $minor] || ![string is integer -strict $patch] || ![string is integer -strict $build]} {
            return ""
        }
    } else {
        return ""
    }

    return [dict create \
        major [expr {$major & 0xff}] \
        minor [expr {$minor & 0xff}] \
        patch [expr {$patch & 0xf}] \
        build [expr {$build & 0xfff}]]
}

proc ::data_path_bts::gui::version_dict_to_word {version_dict} {
    if {$version_dict eq ""} {
        return ""
    }

    return [expr { \
        (([dict get $version_dict major] & 0xff) << 24) | \
        (([dict get $version_dict minor] & 0xff) << 16) | \
        (([dict get $version_dict patch] & 0xf) << 12) | \
        ([dict get $version_dict build] & 0xfff)}]
}

proc ::data_path_bts::gui::format_common_csr_header_word {raw_value} {
    set raw_value [expr {$raw_value & 0xffffffff}]
    set major [expr {($raw_value >> 24) & 0xff}]
    set minor [expr {($raw_value >> 16) & 0xff}]
    set patch [expr {($raw_value >> 12) & 0xf}]
    set build [expr {$raw_value & 0xfff}]
    return [format "%d.%d.%d build %d" $major $minor $patch $build]
}

proc ::data_path_bts::gui::decode_runtime_version_readback {raw_read version_spec} {
    if {[scan $raw_read %i raw_value] != 1} {
        return ""
    }

    set raw_value [expr {$raw_value & 0xffffffff}]
    set encoding common_csr_header_v1
    if {[dict exists $version_spec encoding]} {
        set encoding [dict get $version_spec encoding]
    }

    switch -- $encoding {
        common_csr_header_v1 {
            return [::data_path_bts::gui::format_common_csr_header_version $raw_value]
        }
        default {
            toolkit_send_message warning "Unsupported runtime CSR version encoding \"$encoding\""
            return ""
        }
    }
}

proc ::data_path_bts::gui::maybe_alert_runtime_version {bspPkgName typeName master_fd ipBase} {
    variable csr_runtime_version_check_done

    set metadata [::data_path_bts::gui::metadata_for_bsp_package $bspPkgName]
    if {$metadata eq "" || ![dict exists $metadata runtime_version_check]} {
        return -code ok
    }

    set check_key [format "%s@%s" $typeName $ipBase]
    if {[info exists csr_runtime_version_check_done($check_key)]} {
        return -code ok
    }

    set version_spec [dict get $metadata runtime_version_check]
    set register_offset ""
    if {[dict exists $version_spec register_offset]} {
        set register_offset [dict get $version_spec register_offset]
    } elseif {[dict exists $version_spec register_name] && [dict exists $metadata contract]} {
        set register_offset [::data_path_bts::gui::find_register_offset_in_contract [dict get $metadata contract] [dict get $version_spec register_name]]
    }

    if {$register_offset eq ""} {
        toolkit_send_message warning "Runtime CSR version check for $typeName is configured but no register offset could be resolved"
        set csr_runtime_version_check_done($check_key) 1
        return -code ok
    }

    # writeBeforeRead: write the page selector before reading the version register
    if {[dict exists $version_spec register_name] && [dict exists $metadata contract]} {
        set wbr_value [::data_path_bts::gui::find_register_write_before_read_in_contract [dict get $metadata contract] [dict get $version_spec register_name]]
        if {$wbr_value ne ""} {
            catch {master_write_32 $master_fd [expr {$ipBase + $register_offset}] $wbr_value}
        }
    }

    if {[catch {master_read_32 $master_fd [expr {$ipBase + $register_offset}] 1} raw_read]} {
        toolkit_send_message warning "Runtime CSR version check for $typeName failed at [format 0x%X $ipBase]: $raw_read"
        set csr_runtime_version_check_done($check_key) 1
        return -code ok
    }

    if {[scan $raw_read %i runtime_version_word] != 1 || ![dict exists $metadata hw_tcl_version]} {
        set csr_runtime_version_check_done($check_key) 1
        return -code ok
    }
    set runtime_version_word [expr {$runtime_version_word & 0xffffffff}]

    set expected_version_dict [::data_path_bts::gui::parse_version_string [dict get $metadata hw_tcl_version]]
    if {$expected_version_dict eq ""} {
        set csr_runtime_version_check_done($check_key) 1
        return -code ok
    }

    set expected_version_word [::data_path_bts::gui::version_dict_to_word $expected_version_dict]
    if {$runtime_version_word != $expected_version_word} {
        set message "Runtime VERSION mismatch for $typeName at [format 0x%X $ipBase]: runtime=[::data_path_bts::gui::format_common_csr_header_word $runtime_version_word] toolkit=[::data_path_bts::gui::format_common_csr_header_word $expected_version_word] raw=$raw_read"
        if {[dict exists $metadata rtl_version]} {
            append message " rtl=" [dict get $metadata rtl_version]
        }
        toolkit_send_message warning $message
    }

    set csr_runtime_version_check_done($check_key) 1
    return -code ok
}

proc ::data_path_bts::gui::contract_to_xml {contract} {
    if {[catch {dict get $contract registers} registers]} {
        return ""
    }

    set xml_lines [list "<?xml version=\"1.0\" encoding=\"utf-8\"?>" "<registers>"]
    foreach register $registers {
        set reg_name [dict get $register name]
        set reg_description ""
        if {[dict exists $register description]} {
            set reg_description [dict get $register description]
        }
        set reg_address_offset [dict get $register address_offset]

        lappend xml_lines "    <register>"
        lappend xml_lines "        <name>[::data_path_bts::gui::xml_escape $reg_name]</name>"
        lappend xml_lines "        <description>[::data_path_bts::gui::xml_escape $reg_description]</description>"
        lappend xml_lines "        <addressOffset>[::data_path_bts::gui::xml_escape $reg_address_offset]</addressOffset>"
        if {[dict exists $register write_before_read]} {
            lappend xml_lines "        <writeBeforeRead>[::data_path_bts::gui::xml_escape [dict get $register write_before_read]]</writeBeforeRead>"
        }
        lappend xml_lines "        <size>32</size>"
        lappend xml_lines "        <fields>"

        foreach field [dict get $register fields] {
            set field_name [dict get $field name]
            set field_description ""
            if {[dict exists $field description]} {
                set field_description [dict get $field description]
            }
            set field_bit_range [dict get $field bit_range]
            set field_access [dict get $field access]

            lappend xml_lines "            <field>"
            lappend xml_lines "                <name>[::data_path_bts::gui::xml_escape $field_name]</name>"
            lappend xml_lines "                <description>[::data_path_bts::gui::xml_escape $field_description]</description>"
            lappend xml_lines "                <bitRange>[::data_path_bts::gui::xml_escape $field_bit_range]</bitRange>"
            lappend xml_lines "                <access>[::data_path_bts::gui::xml_escape $field_access]</access>"
            lappend xml_lines "            </field>"
        }

        lappend xml_lines "        </fields>"
        lappend xml_lines "    </register>"
    }
    lappend xml_lines "</registers>"

    return [join $xml_lines "\n"]
}

proc ::data_path_bts::gui::build_xml_from_bsp {bspPkgName} {
    array set csr_map [::${bspPkgName}::bsp::get_address_map ]

    set xml_lines [list "<?xml version=\"1.0\" encoding=\"utf-8\"?>" "<registers>"]
    foreach index [lsort -integer [array names csr_map]] {
        lappend xml_lines $csr_map($index)
    }
    lappend xml_lines "</registers>"

    return [join $xml_lines "\n"]
}

proc ::data_path_bts::gui::sopcinfo_candidates {} {
    variable project_root

    # Prefer the standalone datapath systems before the full FEB wrapper.
    # The FEB top-level .sopcinfo does not consistently expose every datapath
    # slave endpoint with names that this inventory parser recognizes.
    set candidates [list \
        [file join $project_root scifi_datapath_v2_system.sopcinfo] \
        [file join $project_root scifi_datapath_system_v2.sopcinfo] \
        [file join $project_root scifi_datapath_system.sopcinfo] \
        [file join $project_root mutrig_datapath_v2_system.sopcinfo] \
        [file join $project_root mutrig_datapath_system_v2.sopcinfo] \
        [file join $project_root mutrig_datapath_system.sopcinfo] \
        [file join $project_root feb_system_v2.sopcinfo] \
        [file join $project_root feb_system.sopcinfo] \
        [file join $project_root feb_system_v1.sopcinfo]]

    set unique_candidates [list]
    foreach candidate $candidates {
        if {[file exists $candidate] && [lsearch -exact $unique_candidates $candidate] < 0} {
            lappend unique_candidates $candidate
        }
    }

    return $unique_candidates
}

proc ::data_path_bts::gui::normalize_base_address {base_value} {
    if {[scan $base_value %i parsed_value] != 1} {
        return ""
    }

    return [format "0x%08x" [expr {$parsed_value & 0xffffffff}]]
}

proc ::data_path_bts::gui::compiled_inventory_start_names {} {
    return [list \
        "data_path_subsystem_master_datapath.master" \
        "master_datapath.master"]
}

proc ::data_path_bts::gui::compiled_inventory_type_for_end {end_name} {
    set short_name $end_name
    regsub {^data_path_subsystem_} $short_name "" short_name

    if {[regexp {^lvds_rx_controller_pro_[0-9]+\.csr$} $short_name]} {
        return "lvds_rx_controller_pro.csr"
    }
    if {[regexp {^mutrig_datapath_subsystem_[0-9]+_mutrig_frame_deassembly_[0-9]+\.csr$} $short_name]} {
        return "mutrig_frame_deassembly.csr"
    }
    if {[regexp {^histogram_statistics_[0-9]+\.csr$} $short_name]} {
        return "histogram_statistics.csr"
    }
    if {[regexp {^histogram_statistics_[0-9]+\.hist_bin$} $short_name]} {
        return "histogram_statistics.hist_bin"
    }
    if {[regexp {^mts_preprocessor_[0-9]+\.csr$} $short_name]} {
        return "mts_preprocessor.csr"
    }
    if {[regexp {^hit_stack_subsystem_[0-9]+_ring_buffer_cam_[0-9]+\.csr$} $short_name]} {
        return "ring_buffer_cam.csr"
    }
    if {[regexp {^hit_stack_subsystem_[0-9]+_feb_frame_assembly_[0-9]+\.csr$} $short_name]} {
        return "feb_frame_assembly.csr"
    }
    if {[regexp {^mutrig_injector_[0-9]+\.csr$} $short_name]} {
        return "mutrig_injector.csr"
    }

    return ""
}

proc ::data_path_bts::gui::compare_inventory_entries_by_base {lhs rhs} {
    set lhs_base [dict get $lhs base]
    set rhs_base [dict get $rhs base]
    scan $lhs_base %i lhs_value
    scan $rhs_base %i rhs_value

    if {$lhs_value < $rhs_value} {
        return -1
    }
    if {$lhs_value > $rhs_value} {
        return 1
    }

    return [string compare [dict get $lhs end] [dict get $rhs end]]
}

proc ::data_path_bts::gui::compiled_slave_inventory_from_sopcinfo {sopcinfo_path} {
    set fd [open $sopcinfo_path r]
    set start_names [::data_path_bts::gui::compiled_inventory_start_names]
    set by_type [dict create]
    set inside_connection 0
    set want_base 0
    array set connection {}

    while {[gets $fd line] >= 0} {
        set trimmed [string trim $line]

        if {[regexp {^<connection(?:\s|$)} $trimmed]} {
            catch {array unset connection *}
            array set connection {}
            set inside_connection 1
            set want_base 0
        }

        if {!$inside_connection} {
            continue
        }

        foreach key {kind start end} {
            if {[regexp [format {%s="([^"]+)"} $key] $trimmed -> parsed_value]} {
                set connection($key) $parsed_value
            }
        }

        if {[string first {<parameter name="baseAddress">} $trimmed] >= 0} {
            set want_base 1
        } elseif {$want_base && [regexp {<value>([^<]+)</value>} $trimmed -> parsed_base]} {
            set connection(base) [::data_path_bts::gui::normalize_base_address $parsed_base]
            set want_base 0
        }

        if {[regexp {^</connection>} $trimmed]} {
            if {[info exists connection(kind)] && [info exists connection(start)] && [info exists connection(end)] &&
                $connection(kind) eq "avalon" && [lsearch -exact $start_names $connection(start)] >= 0} {
                set type_name [::data_path_bts::gui::compiled_inventory_type_for_end $connection(end)]
                if {$type_name ne "" && [info exists connection(base)] && $connection(base) ne ""} {
                    dict lappend by_type $type_name [dict create end $connection(end) base $connection(base)]
                }
            }

            catch {array unset connection *}
            array set connection {}
            set inside_connection 0
            set want_base 0
        }
    }

    close $fd

    foreach type_name [dict keys $by_type] {
        dict set by_type $type_name [lsort -command ::data_path_bts::gui::compare_inventory_entries_by_base [dict get $by_type $type_name]]
    }

    if {[dict size $by_type] == 0} {
        return ""
    }

    return [dict create source $sopcinfo_path by_type $by_type]
}

proc ::data_path_bts::gui::compiled_slave_inventory {} {
    variable compiled_sopc_inventory

    if {$compiled_sopc_inventory ne ""} {
        return $compiled_sopc_inventory
    }

    foreach sopcinfo_path [::data_path_bts::gui::sopcinfo_candidates] {
        set parsed_inventory [::data_path_bts::gui::compiled_slave_inventory_from_sopcinfo $sopcinfo_path]
        if {$parsed_inventory ne ""} {
            set compiled_sopc_inventory $parsed_inventory
            return $compiled_sopc_inventory
        }
    }

    return ""
}

proc ::data_path_bts::gui::module_version_from_sopcinfo {sopcinfo_path kind_name} {
    set fd [open $sopcinfo_path r]
    set inside_module 0
    set module_kind ""
    set module_version ""

    while {[gets $fd line] >= 0} {
        if {[regexp {<module(?:\s|$)} $line]} {
            set inside_module 1
            set module_kind ""
            set module_version ""
        }

        if {!$inside_module} {
            continue
        }

        if {[regexp {kind="([^"]+)"} $line -> parsed_kind]} {
            set module_kind $parsed_kind
        }
        if {[regexp {version="([^"]+)"} $line -> parsed_version]} {
            set module_version $parsed_version
        }

        if {[string first ">" $line] >= 0} {
            if {$module_kind eq $kind_name && $module_version ne ""} {
                close $fd
                return $module_version
            }
            set inside_module 0
        }
    }

    close $fd
    return ""
}

proc ::data_path_bts::gui::hw_tcl_version_for_bsp_package {bspPkgName} {
    set kind_name [::data_path_bts::gui::kind_for_bsp_package $bspPkgName]
    if {$kind_name eq ""} {
        return ""
    }

    foreach sopcinfo_path [::data_path_bts::gui::sopcinfo_candidates] {
        set module_version [::data_path_bts::gui::module_version_from_sopcinfo $sopcinfo_path $kind_name]
        if {$module_version ne ""} {
            return $module_version
        }
    }

    return ""
}

proc ::data_path_bts::gui::load_local_metadata_xml {bspPkgName} {
    variable csr_meta_dir
    variable csr_metadata_cache

    if {$csr_meta_dir eq ""} {
        return ""
    }

    set meta_key [::data_path_bts::gui::metadata_key_for_bsp_package $bspPkgName]
    set helper_file [file join $csr_meta_dir board_bring_up_meta.tcl]
    set hw_tcl_version [::data_path_bts::gui::hw_tcl_version_for_bsp_package $bspPkgName]
    set metadata_proc ""
    set meta_file ""

    if {$hw_tcl_version ne ""} {
        set version_token [::data_path_bts::gui::version_namespace_token $hw_tcl_version]
        set meta_file [file join $csr_meta_dir $meta_key ${hw_tcl_version}.tcl]
        set metadata_proc ::fe_scifi::board_bring_up::csr_meta::${meta_key}::v${version_token}::get_metadata
    }

    if {$meta_file eq "" || ![file exists $meta_file]} {
        set meta_file [file join $csr_meta_dir ${meta_key}_csr_meta.tcl]
        set metadata_proc ::fe_scifi::board_bring_up::csr_meta::${meta_key}::get_metadata
    }

    if {![file exists $meta_file]} {
        return ""
    }

    if {![llength [info commands ::fe_scifi::board_bring_up::csr_meta::field]] && [file exists $helper_file]} {
        if {[catch {source $helper_file} helper_error]} {
            toolkit_send_message warning "Failed to source CSR metadata helper $helper_file: $helper_error"
            return ""
        }
    }

    if {![llength [info commands $metadata_proc]]} {
        if {[catch {source $meta_file} meta_error]} {
            toolkit_send_message warning "Failed to source local CSR metadata $meta_file: $meta_error"
            return ""
        }
    }

    if {![llength [info commands $metadata_proc]]} {
        return ""
    }

    if {[catch {$metadata_proc} metadata_error]} {
        toolkit_send_message warning "Failed to build local CSR metadata for $meta_key: $metadata_error"
        return ""
    }
    set metadata $metadata_error
    if {![dict exists $metadata contract]} {
        return ""
    }
    set csr_metadata_cache($meta_key) $metadata

    set message "Loaded local CSR metadata for $meta_key"
    if {[dict exists $metadata metadata_version]} {
        append message " metadata=" [dict get $metadata metadata_version]
    }
    if {[dict exists $metadata rtl_version]} {
        append message " rtl=" [dict get $metadata rtl_version]
    }
    if {[dict exists $metadata hw_tcl_version]} {
        append message " hw_tcl=" [dict get $metadata hw_tcl_version]
    }
    toolkit_send_message info $message

    return [::data_path_bts::gui::contract_to_xml [dict get $metadata contract]]
}

proc ::data_path_bts::gui::resolve_doc_xml {bspPkgName config_options} {
    if {[llength $config_options] > 0} {
        for {set i 0} {$i < [llength $config_options]} {incr i 2} {
            ::${bspPkgName}::bsp::configure [lindex $config_options $i] [lindex $config_options [expr $i + 1]]
        }
    }

    set xml_plain_text [::data_path_bts::gui::load_local_metadata_xml $bspPkgName]
    if {$xml_plain_text ne ""} {
        return $xml_plain_text
    }

    return [::data_path_bts::gui::build_xml_from_bsp $bspPkgName]
}

proc ::data_path_bts::gui::set_doc_xml {bspPkgName xml_plain_text} {
    variable fd_global_variable

    set doc_key [::data_path_bts::gui::doc_key_for_bsp_package $bspPkgName]
    set variable_name ${doc_key}_doc_xml

    if {![::mu3e::helpers::probe_global_variable $fd_global_variable $variable_name]} {
        ::mu3e::helpers::append_global_variable $fd_global_variable $variable_name "empty"
    }

    ::mu3e::helpers::set_global_variable $fd_global_variable $variable_name $xml_plain_text
    return [::mu3e::helpers::get_global_variable $fd_global_variable $variable_name]
}

proc ::data_path_bts::gui::setup_all {n_asic n_lane} {
    toolkit_add 			Tab0 			tabbedGroup 		self
	###########################################################
	#  ____           _____ _____ _____   _______       ____  #
	# |  _ \   /\    / ____|_   _/ ____| |__   __|/\   |  _ \ #
	# | |_) | /  \  | (___   | || |         | |  /  \  | |_) |#
	# |  _ < / /\ \  \___ \  | || |         | | / /\ \ |  _ < #
	# | |_) / ____ \ ____) |_| || |____     | |/ ____ \| |_) |#
	# |____/_/    \_\_____/|_____\_____|    |_/_/    \_\____/ #
	#                                                         # 
	########################################################### 
	toolkit_add 			"baseGroup" 	group 				Tab0	
	toolkit_set_property 	"baseGroup" 	title 				"Setup Connections"
	toolkit_set_property 	"baseGroup" 	itemsPerRow 		1
	
	::mu3e::helpers::setup_base_group "baseGroup"
    
    #################################################################################################################
	#   _____ _       _           _   __      __        _       _     _         _______       ____  _      ______   #
	#  / ____| |     | |         | |  \ \    / /       (_)     | |   | |       |__   __|/\   |  _ \| |    |  ____|  #
	# | |  __| | ___ | |__   __ _| |   \ \  / /_ _ _ __ _  __ _| |__ | | ___      | |  /  \  | |_) | |    | |__     #
	# | | |_ | |/ _ \| '_ \ / _` | |    \ \/ / _` | '__| |/ _` | '_ \| |/ _ \     | | / /\ \ |  _ <| |    |  __|    #
	# | |__| | | (_) | |_) | (_| | |     \  / (_| | |  | | (_| | |_) | |  __/     | |/ ____ \| |_) | |____| |____   #
	#  \_____|_|\___/|_.__/ \__,_|_|      \/ \__,_|_|  |_|\__,_|_.__/|_|\___|     |_/_/    \_\____/|______|______|  #
	#                                                                                                               #
	#################################################################################################################
	variable fd_global_variable "globalVariableTable"
	::mu3e::helpers::init_global_variable  $fd_global_variable
	::mu3e::helpers::append_global_variable $fd_global_variable "n_asic" $n_asic
	#::mu3e::helpers::append_global_variable $fd_global_variable "doc_xml" "empty..."
	::mu3e::helpers::append_global_variable $fd_global_variable "slaves" [list "lvds_rx_controller_pro.csr" \
    "mutrig_frame_deassembly.csr" "histogram_statistics.csr" "histogram_statistics.hist_bin" \
    "mutrig_injector.csr" "mts_preprocessor.csr" "ring_buffer_cam.csr" "feb_frame_assembly.csr"]
	::mu3e::helpers::append_global_variable $fd_global_variable "lvds_rx_controller_pro.csr_base_address" 0x0
	::mu3e::helpers::append_global_variable $fd_global_variable "lvds_rx_controller_pro.csr_encountered" 0
	::mu3e::helpers::append_global_variable $fd_global_variable "mutrig_frame_deassembly.csr_base_address" 0x0
	::mu3e::helpers::append_global_variable $fd_global_variable "mutrig_frame_deassembly.csr_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "mutrig_frame_deassembly.csr_copies" 8
    ::mu3e::helpers::append_global_variable $fd_global_variable "histogram_statistics.csr_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "histogram_statistics.csr_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "histogram_statistics.hist_bin_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "histogram_statistics.hist_bin_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "mutrig_injector.csr_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "mutrig_injector.csr_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "mts_preprocessor.csr_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "mts_preprocessor.csr_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "mts_preprocessor.csr_copies" 2
    ::mu3e::helpers::append_global_variable $fd_global_variable "ring_buffer_cam.csr_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "ring_buffer_cam.csr_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "ring_buffer_cam.csr_copies" 8
    ::mu3e::helpers::append_global_variable $fd_global_variable "feb_frame_assembly.csr_base_address" 0x0
    ::mu3e::helpers::append_global_variable $fd_global_variable "feb_frame_assembly.csr_encountered" 0
    ::mu3e::helpers::append_global_variable $fd_global_variable "feb_frame_assembly.csr_copies" 2
    
    ::mu3e::helpers::append_global_variable $fd_global_variable "lvds_doc_xml" "empty"
    ::mu3e::helpers::append_global_variable $fd_global_variable "frame_deassembly_doc_xml" "empty"
    ::mu3e::helpers::append_global_variable $fd_global_variable "mutrig_injector_doc_xml" "empty"
    ::mu3e::helpers::append_global_variable $fd_global_variable "hist_barChart_name" "hist_barChart"
    ::mu3e::helpers::append_global_variable $fd_global_variable "hist_regpack" 0
    
    #::mu3e::helpers::append_global_variable $fd_global_variable "histogram_statistics_doc_xml" "empty"
	toolkit_set_property	"globalVariableTable" visible 1
    
    
    # ////////////////////////////////// lvds tab ///////////////////////////////////////////
    # - lvds tab 
    toolkit_add 			"lvdsTab" 	group 				Tab0	
	toolkit_set_property 	"lvdsTab" 	title 				"LVDS"
	toolkit_set_property 	"lvdsTab" 	itemsPerRow 		2
    # -- lvds group
    toolkit_add 			"lvdsGroup" 	group 				"lvdsTab"	
	toolkit_set_property 	"lvdsGroup" 	title 				"IP Setting"
	toolkit_set_property 	"lvdsGroup" 	itemsPerRow 		2
    # --- lvds group content
    ::data_path_bts::gui::setup_lvds "lvdsGroup" $n_lane
    # -- control panel group
    toolkit_add 			"lvdsCtrlGroup" 	group 				"lvdsTab"
	toolkit_set_property 	"lvdsCtrlGroup" 	title 				"Control Panel"
	toolkit_set_property 	"lvdsCtrlGroup" 	itemsPerRow 		1
    # --- control panel content
    ::data_path_bts::gui::setup_lvds_controlPanel "lvdsCtrlGroup" $n_lane
    # /////////////////////////////////////////////////////////////////////////////
    
    
    
    # ////////////////////////////////// frame deassembly tab ///////////////////////////////////////////
    variable deassembly_monitor_fd ""
    set n_deassembly [::mu3e::helpers::get_global_variable $fd_global_variable "mutrig_frame_deassembly.csr_copies"]
    # - frame deassembly tab
    toolkit_add 			"deassemblyTab" 	group 				Tab0	
	toolkit_set_property 	"deassemblyTab" 	title 				"Frame Deassembly"
	toolkit_set_property 	"deassemblyTab" 	itemsPerRow 		2
    
    
    
    # -- control panel group
    toolkit_add 			"deassemblyCtrlGroup" 	group 				"deassemblyTab"
	toolkit_set_property 	"deassemblyCtrlGroup" 	title 				"Control Panel"
	toolkit_set_property 	"deassemblyCtrlGroup" 	itemsPerRow 		1
    

    # -- deassembly register values 
    toolkit_add 			"deassemblyGroup" 	group 				"deassemblyTab"
    toolkit_set_property 	"deassemblyGroup" 	itemsPerRow 		2
    set baseGroupNames [list]
    for {set i 0} {$i < $n_deassembly} {incr i} {
        # -- deassembly group
        lappend baseGroupNames "deassemblyGroup$i"
        toolkit_add 			"deassemblyGroup$i" 	group 				"deassemblyGroup"
        toolkit_set_property 	"deassemblyGroup$i" 	title 				"IP index $i"
        toolkit_set_property 	"deassemblyGroup$i" 	itemsPerRow 		1
        ::data_path_bts::gui::bsp2gui_setup  "frame_deassembly" deassemblyGroup${i} 1 [list]
        #::data_path_bts::gui::setup_deassembly "deassemblyGroup$i"
    }
    
    
    # -- control panel content
    toolkit_add             "deassemblyRead_button" button       "deassemblyCtrlGroup"
    toolkit_set_property    "deassemblyRead_button" text         "read"
    toolkit_set_property    "deassemblyRead_button" onClick      {::data_path_bts::gui::device2gui "frame_deassembly" "deassemblyGroup" "mutrig_frame_deassembly.csr" } 
    #::data_path_bts::gui::setup_deassembly_controlPanel "deassemblyCtrlGroup" 
    # /////////////////////////////////////////////////////////////////////////////
    
    
    # //////////////////////////////////// rate tab /////////////////////////////////////////
    # - rate tab
    toolkit_add 			"rateTab" 	group 				Tab0	
	toolkit_set_property 	"rateTab" 	title 				"Rate"
	toolkit_set_property 	"rateTab" 	itemsPerRow 		1
    # -- control panel 
    variable rate_monitor_fd ""
    toolkit_add 			"rateCtrlGroup" 	group 		"rateTab"
	toolkit_set_property	"rateCtrlGroup"	    expandableX	false
	toolkit_set_property	"rateCtrlGroup"	    expandableY	false
    toolkit_set_property    "rateCtrlGroup"     preferredWidth  240
    toolkit_set_property    "rateCtrlGroup"     maxWidth        240
	toolkit_set_property	"rateCtrlGroup"	    itemsPerRow 1
	toolkit_set_property	"rateCtrlGroup" 	title		"Control Panel"
    toolkit_add             "rateCtrl_checkBox"     checkBox      "rateCtrlGroup"
    toolkit_set_property    "rateCtrl_checkBox"     label         "monitor rate"   
    toolkit_set_property    "rateCtrl_checkBox"     onClick      {::data_path_bts::gui::rate_monitor_registers_functor}

    toolkit_add             "rateCtrl_loading_bitmap"  bitmap          "rateCtrlGroup"
    toolkit_set_property    "rateCtrl_loading_bitmap"  path            ../system_console/figures/loading.gif
    toolkit_set_property    "rateCtrl_loading_bitmap"  label           "stopped"
    toolkit_set_property    "rateCtrl_loading_bitmap"  visible         0
    
    toolkit_add             "tmp_button" button "rateCtrlGroup"
    toolkit_set_property    "tmp_button" text "Read Once"
    toolkit_set_property    "tmp_button" onClick {::data_path_bts::gui::rate_read_once}
    
    # -- rate histogram
    toolkit_add 			"rateHistGroup" 	group 		"rateTab"
    toolkit_set_property	"rateHistGroup"		expandableX	true
    toolkit_set_property	"rateHistGroup"		expandableY	true
    toolkit_set_property	"rateHistGroup"		itemsPerRow 1
    toolkit_set_property	"rateHistGroup" 	title		"channel rate plot"
    
    toolkit_add 			"rateAsicTab0" 		tabbedGroup     "rateHistGroup"
    for {set i 0} {[expr $i < $n_asic]} {incr i} {
        set group_name [format "rateHistGroupTab%i" $i]
        toolkit_add 			$group_name 	group 		"rateAsicTab0"
        toolkit_set_property	$group_name		expandableX	false
        toolkit_set_property	$group_name		expandableY	false
        toolkit_set_property	$group_name		itemsPerRow 1
        toolkit_set_property	$group_name 	title		[format "MuTRiG %i" $i]
			
        set chart_name	[format "rateBarChart%i" $i]
        toolkit_add				$chart_name		barChart	$group_name
        toolkit_set_property	$chart_name		title		"Channel Rate"
        toolkit_set_property	$chart_name		labelX		"channel ID"
        toolkit_set_property	$chart_name		labelY		[format "Hit Rate per %i ms" 1000]
        toolkit_set_property	$chart_name		expandableX true
        toolkit_set_property	$chart_name		preferredWidth 800
    }
    # /////////////////////////////////////////////////////////////////////////////
    
    
    # //////////////////////////////////// mutrig_ts processor tab /////////////////////////////////////////
    set n_processor [::mu3e::helpers::get_global_variable $fd_global_variable "mts_preprocessor.csr_copies"]
    # - processor tab 
    toolkit_add 			"mtsTab" 	group 				Tab0	
	toolkit_set_property 	"mtsTab" 	title 				"MTS Processor"
	toolkit_set_property 	"mtsTab" 	itemsPerRow 		2
    # -- control panel group
    toolkit_add 			"mtsCtrlGroup" 	group 				"mtsTab"
	toolkit_set_property 	"mtsCtrlGroup" 	title 				"Control Panel"
	toolkit_set_property 	"mtsCtrlGroup" 	itemsPerRow 		1
    
    # -- register values 
    toolkit_add 			"mtsGroup" 	group 				"mtsTab"
    toolkit_set_property 	"mtsGroup" 	itemsPerRow 		2
    set baseGroupNames [list]
    for {set i 0} {$i < $n_processor} {incr i} {
        # -- deassembly group
        lappend baseGroupNames "mtsGroup$i"
        toolkit_add 			"mtsGroup$i" 	group 				"mtsGroup"
        toolkit_set_property 	"mtsGroup$i" 	title 				"IP index $i"
        toolkit_set_property 	"mtsGroup$i" 	itemsPerRow 		1
        ::data_path_bts::gui::bsp2gui_setup  "mts_processor" mtsGroup${i} 0 [list]
    }
    
    # -- control panel content
    toolkit_add             "mtsRead_button" button       "mtsCtrlGroup"
    toolkit_set_property    "mtsRead_button" text         "read"
    toolkit_set_property    "mtsRead_button" onClick      {::data_path_bts::gui::device2gui "mts_processor" "mtsGroup" "mts_preprocessor.csr"; toolkit_set_property "mtsWrite_button" enabled 1 } 
    
    toolkit_add             "mtsWrite_button"   button      "mtsCtrlGroup"
    toolkit_set_property    "mtsWrite_button"   text        "write"
    toolkit_set_property    "mtsWrite_button"   enabled     0
    toolkit_set_property    "mtsWrite_button"   onClick     {::data_path_bts::gui::gui2device "mts_processor" "mtsGroup" "mts_preprocessor.csr"}
    
    # ///////////////////////////////////////////////////////////////////////////////////////
    
    
    # ////////////////////////////// cache stack tab ///////////////////////////////////////
    set n_stacks [::mu3e::helpers::get_global_variable $fd_global_variable "ring_buffer_cam.csr_copies"]
    # - stack tab
    toolkit_add 			"stackTab" 	group 				Tab0	
	toolkit_set_property 	"stackTab" 	title 				"Resequencing Buffer"
	toolkit_set_property 	"stackTab" 	itemsPerRow 		2
    
    # panel group
    toolkit_add 			"stackGroup" 	    group 		"stackTab"
	toolkit_set_property	"stackGroup"	    expandableX	false
	toolkit_set_property	"stackGroup"	    expandableY	false
    toolkit_set_property	"stackGroup"	    maxWidth	200
	toolkit_set_property	"stackGroup"	    itemsPerRow 1
	toolkit_set_property	"stackGroup" 	    title		"Control Panel"
    
    toolkit_add             "stackRead_button"  button      "stackGroup"
    toolkit_set_property    "stackRead_button"  text        "read"
    toolkit_set_property    "stackRead_button"  onClick     {::data_path_bts::gui::device2gui "ring_buffer_cam" "stackGroup" "ring_buffer_cam.csr"; toolkit_set_property "stackWrite_button" enabled 1 }
    
    toolkit_add             "stackWrite_button"  button      "stackGroup"
    toolkit_set_property    "stackWrite_button"  text        "write"
    toolkit_set_property    "stackWrite_button"  enabled     0
    toolkit_set_property    "stackWrite_button"  onClick     {::data_path_bts::gui::gui2device "ring_buffer_cam" "stackGroup" "ring_buffer_cam.csr"}
    
    # -- register values 
    toolkit_add 			"stackGroup" 	group 				"stackTab"
    toolkit_set_property 	"stackGroup" 	itemsPerRow 		4
    set baseGroupNames [list]
    for {set i 0} {$i < $n_stacks} {incr i} {
        # -- deassembly group
        lappend baseGroupNames "stackGroup$i"
        toolkit_add 			"stackGroup$i" 	group 				"stackGroup"
        toolkit_set_property 	"stackGroup$i" 	title 				"IP index $i"
        toolkit_set_property 	"stackGroup$i" 	itemsPerRow 		1
        ::data_path_bts::gui::bsp2gui_setup  "ring_buffer_cam" stackGroup${i} 0 [list]
    }
    
    # ///////////////////////////////////////////////////////////////////////////////////////////
    
    
    # //////////////////////////////// frame assembly tab ///////////////////////////////////////
    set n_assembly [::mu3e::helpers::get_global_variable $fd_global_variable "feb_frame_assembly.csr_copies"]
    # - assembly tab
    toolkit_add 			"assemblyTab" 	group 				Tab0	
	toolkit_set_property 	"assemblyTab" 	title 				"Frame Assembly"
	toolkit_set_property 	"assemblyTab" 	itemsPerRow 		2
    
    # panel group
    toolkit_add 			"assemblyGroup" 	group 		"assemblyTab"
	toolkit_set_property	"assemblyGroup"	    expandableX	false
	toolkit_set_property	"assemblyGroup"	    expandableY	false
    toolkit_set_property	"assemblyGroup"	    maxWidth	200
	toolkit_set_property	"assemblyGroup"	    itemsPerRow 1
	toolkit_set_property	"assemblyGroup" 	title		"Control Panel"
    
    toolkit_add             "assemblyRead_button"  button      "assemblyGroup"
    toolkit_set_property    "assemblyRead_button"  text        "read"
    toolkit_set_property    "assemblyRead_button"  onClick     {::data_path_bts::gui::device2gui "feb_frame_assembly" "assemblyGroup" "feb_frame_assembly.csr"; toolkit_set_property "assemblyWrite_button" enabled 1 }
    
    toolkit_add             "assemblyWrite_button"  button      "assemblyGroup"
    toolkit_set_property    "assemblyWrite_button"  text        "write"
    toolkit_set_property    "assemblyWrite_button"  enabled     0
    toolkit_set_property    "assemblyWrite_button"  onClick     {::data_path_bts::gui::gui2device "feb_frame_assembly" "assemblyGroup" "feb_frame_assembly.csr"}
    
    # -- register values 
    toolkit_add 			"assemblyGroup" 	group 				"assemblyTab"
    toolkit_set_property 	"assemblyGroup" 	itemsPerRow 		4
    set baseGroupNames [list]
    for {set i 0} {$i < $n_assembly} {incr i} {
        # -- assembly group
        lappend baseGroupNames "assemblyGroup$i"
        toolkit_add 			"assemblyGroup$i" 	group 				"assemblyGroup"
        toolkit_set_property 	"assemblyGroup$i" 	title 				"IP index $i"
        toolkit_set_property 	"assemblyGroup$i" 	itemsPerRow 		1
        ::data_path_bts::gui::bsp2gui_setup  "feb_frame_assembly" assemblyGroup${i} 0 [list]
    }
    
    
    # ///////////////////////////////////////////////////////////////////////////////////////////
    
    
    
    # ////////////////////////////////// histogram tab ///////////////////////////////////////////
    # histogram tab
    toolkit_add 			"histTab" 	group 				Tab0	
	toolkit_set_property 	"histTab" 	title 				"Histogram Statistics"
	toolkit_set_property 	"histTab" 	itemsPerRow 		2
    
    # panel group
    toolkit_add 			"histCtrlGroup" 	group 		"histTab"
	toolkit_set_property	"histCtrlGroup"	    expandableX	false
	toolkit_set_property	"histCtrlGroup"	    expandableY	false
    toolkit_set_property	"histCtrlGroup"	    maxWidth	200
	toolkit_set_property	"histCtrlGroup"	    itemsPerRow 1
	toolkit_set_property	"histCtrlGroup" 	title		"Control Panel"
    
    # panel group - content
    toolkit_add             "histRead_button"   button      "histCtrlGroup"
    toolkit_set_property    "histRead_button"   text        "read"
    toolkit_set_property    "histRead_button"   onClick     {::data_path_bts::gui::device2gui "histogram_statistics" "histRegGroup" "histogram_statistics.csr"; toolkit_set_property "histWrite_button" enabled 1}
    
    toolkit_add             "histWrite_button"   button      "histCtrlGroup"
    toolkit_set_property    "histWrite_button"   text        "write"
    toolkit_set_property    "histWrite_button"   enabled     0
    toolkit_set_property    "histWrite_button"   onClick     {::data_path_bts::gui::gui2device "histogram_statistics" "histRegGroup" "histogram_statistics.csr"}
    
    toolkit_add             "histPlot_button"   button      "histCtrlGroup"
    toolkit_set_property    "histPlot_button"   text         "plot"
    toolkit_set_property    "histPlot_button"   onClick     {::data_path_bts::gui::read_hist "histRegGroup"}
    
    ::mu3e::helpers::toolkit_setup_combobox "histCtrlGroup" "hist_lo_comboBox" [list 0 255] 0 "low"
    ::mu3e::helpers::toolkit_setup_combobox "histCtrlGroup" "hist_hi_comboBox" [list 0 255] 255 "high"
    
    
    # create a button for save to xml
	toolkit_add				"histSave_button"		fileChooserButton 			"histCtrlGroup"
	toolkit_set_property	"histSave_button"		text 						"save"
	toolkit_set_property	"histSave_button"		paths						"./trash_bin/dummy_hist"; # some default path
	toolkit_set_property	"histSave_button"		chooserButtonText 			"Save"
	toolkit_set_property	"histSave_button"		onChoose 		{::data_path_bts::gui::save_hist "histSave_button" "histRegGroup"} 
    
    # tab group
    toolkit_add 			"histTab0" 	    tabbedGroup "histTab"
    # tab group - registers tab
    toolkit_add 			"histRegGroup" 	group 		"histTab0"
    toolkit_set_property	"histRegGroup"	itemsPerRow 2
    toolkit_set_property	"histRegGroup" 	title		"Register Access"
    # tab group - registers tab - content
    ::data_path_bts::gui::bsp2gui_setup "histogram_statistics" "histRegGroup" 0 [list]
    

    # tab group - display tab
    toolkit_add 			"histDisplayGroup" 	    group 		"histTab0"
    toolkit_set_property	"histDisplayGroup"	    expandableX	false
	toolkit_set_property	"histDisplayGroup"	    expandableY	false
	toolkit_set_property	"histDisplayGroup"	    itemsPerRow 1
	toolkit_set_property	"histDisplayGroup" 	    title		"Display"
    # tab group - display tab - content
    toolkit_add             "hist_barChart"         barChart "histDisplayGroup"
    toolkit_set_property    "hist_barChart"         preferredWidth  1000
    
    # tab group - display tab
    toolkit_add 			"histHelpGroup" 	    group 		"histTab0"
    toolkit_set_property	"histHelpGroup"	        expandableX	false
	toolkit_set_property	"histHelpGroup"	        expandableY	false
	toolkit_set_property	"histHelpGroup"	        itemsPerRow 1
	toolkit_set_property	"histHelpGroup" 	    title		"Manual"
    # tab group - display tab - tabbedGroup
    toolkit_add 			"histHelpTab0" 	        tabbedGroup "histHelpGroup"
    array set histMan [::histogram_statistics::bsp::get_manual]
    #parray histMan
    foreach {histManKey histManContent} [array get histMan] {
        # tab group - display tab - tabbedGroup - group
        toolkit_add             "histHelp_${histManKey}_group" group "histHelpTab0"
        toolkit_set_property    "histHelp_${histManKey}_group" title $histManKey
        # tab group - display tab - tabbedGroup - group - content
        toolkit_add             "histManualText"        text        "histHelp_${histManKey}_group"
        toolkit_set_property    "histManualText"        preferredWidth  600
        toolkit_set_property    "histManualText"        preferredHeight 300
        toolkit_set_property    "histManualText"        editable      false
        toolkit_set_property    "histManualText"        htmlCapable   true
        toolkit_set_property    "histManualText"        text          $histManContent
    }
    
    # tab group - automation tab
    #################################################################
    ## scan of 0 - 65535. in a window of 256. takes 256 cycles.
    #################################################################
    toolkit_add 			"histAutoGroup" 	    group 		"histTab0"
    toolkit_set_property	"histAutoGroup"	        expandableX	false
	toolkit_set_property	"histAutoGroup"	        expandableY	false
	toolkit_set_property	"histAutoGroup"	        itemsPerRow 1
	toolkit_set_property	"histAutoGroup" 	    title		"Automation"
    
    # tab group - automation tab - setting group
    toolkit_add             "hitsAutoSetGroup"      group           "histAutoGroup"
    toolkit_set_property    "hitsAutoSetGroup"      preferredWidth  500
    toolkit_set_property    "hitsAutoSetGroup"      title           "Scan Settings"
    toolkit_set_property	"hitsAutoSetGroup"	    itemsPerRow 2
    # tab group - automation tab - setting group - content
    toolkit_add auto_step_textField textField hitsAutoSetGroup
    toolkit_set_property auto_step_textField label "step size"
    toolkit_set_property auto_step_textField text "256"
    toolkit_set_property auto_step_textField toolTip "enter the step size of the scan"
    toolkit_set_property auto_step_textField expandableX true
    
    toolkit_add auto_min_textField textField hitsAutoSetGroup
    toolkit_set_property auto_min_textField label "start value"
    toolkit_set_property auto_min_textField text "0"
    toolkit_set_property auto_min_textField toolTip "start value of left bin (default = 0)"
    toolkit_set_property auto_min_textField expandableX true
    
    toolkit_add auto_nstep_textField textField hitsAutoSetGroup
    toolkit_set_property auto_nstep_textField label "number of steps"
    toolkit_set_property auto_nstep_textField text "4"
    toolkit_set_property auto_nstep_textField toolTip "enter the number of steps of the scan. (default = 256)"
    toolkit_set_property auto_nstep_textField expandableX true
    
    # tab group - automation tab - control group
    toolkit_add             "hitsAutoCtrlGroup"      group           "histAutoGroup"
    toolkit_set_property    "hitsAutoCtrlGroup"      preferredWidth  200
    toolkit_set_property    "hitsAutoCtrlGroup"      title           "Scan Control"
    
    # tab group - automation tab - control group - content
    toolkit_add				"auto_start_button"		fileChooserButton 			"hitsAutoCtrlGroup"
	toolkit_set_property	"auto_start_button"		text 						"Start Scan"
	toolkit_set_property	"auto_start_button"		paths						"./scan_records/dummy_hist"; # some default path
	toolkit_set_property	"auto_start_button"		chooserButtonText 			"Create file sets"
	toolkit_set_property	"auto_start_button"		onChoose 		{::data_path_bts::gui::scan_hist "auto_start_button" "histRegGroup" "auto_step_textField" "auto_min_textField" "auto_nstep_textField"} 
    



    # ////////////////////////////////////////////////////////////////////////////////////////////
    
    
    
    
    
    # //////////////////////////////////// injector tab /////////////////////////////////////////
    # - injector tab
    toolkit_add 			"injTab" 	group 				Tab0	
	toolkit_set_property 	"injTab" 	title 				"MuTRiG Injector"
	toolkit_set_property 	"injTab" 	itemsPerRow 		2
    
    # panel group
    toolkit_add 			"injCtrlGroup" 	    group 		"injTab"
	toolkit_set_property	"injCtrlGroup"	    expandableX	false
	toolkit_set_property	"injCtrlGroup"	    expandableY	false
    toolkit_set_property	"injCtrlGroup"	    maxWidth	200
	toolkit_set_property	"injCtrlGroup"	    itemsPerRow 1
	toolkit_set_property	"injCtrlGroup" 	    title		"Control Panel"
    
    # panel group - content 
    toolkit_add             "injRead_button"   button      "injCtrlGroup"
    toolkit_set_property    "injRead_button"   text        "read"
    toolkit_set_property    "injRead_button"   onClick     {::data_path_bts::gui::device2gui "mutrig_injector" "injRegGroup" "mutrig_injector.csr"; toolkit_set_property "injWrite_button" enabled 1}
    
    toolkit_add             "injWrite_button"   button      "injCtrlGroup"
    toolkit_set_property    "injWrite_button"   text        "write"
    toolkit_set_property    "injWrite_button"   enabled     0
    toolkit_set_property    "injWrite_button"   onClick     {::data_path_bts::gui::gui2device "mutrig_injector" "injRegGroup" "mutrig_injector.csr"}
    
    # register group
    toolkit_add 			"injRegGroup" 	group 		"injTab"
    toolkit_set_property	"injRegGroup"	itemsPerRow 2
    toolkit_set_property	"injRegGroup" 	title		"Register Access"
    
    # register group - content 
    ::data_path_bts::gui::bsp2gui_setup "mutrig_injector" "injRegGroup" 0 [list -HEADERINFO_CHANNEL_W 4]
    # ///////////////////////////////////////////////////////////////////////////////////////////
    
    
    
    
    
    
    
    
    
    
    return -code ok 
}



    #########################################################################################################
    # @name             bsp2gui_setup 
    #
    # @berief           setup the gui from bsp
    # @param            <bspPkgName> - BSP package name of this IP core 
    #                   <baseGroupName> - base group name to reference the gui widgets 
    #                   <isMonitor> - whether to create an monitor service (TODO)
    #
    # @return           -code ok : success
    #########################################################################################################

proc ::data_path_bts::gui::bsp2gui_setup  {bspPkgName baseGroupName isMonitor config_options } {
    variable fd_global_variable
    # 1) PREPARATION
    set xml_plain_text [::data_path_bts::gui::resolve_doc_xml $bspPkgName $config_options]
    
    # xml -> gvtable 
    set xml_plain_text [::data_path_bts::gui::set_doc_xml $bspPkgName $xml_plain_text]
    
    # 2) BUILD GUI
    # parse xml tree of reg map and create gui 
    dom parse $xml_plain_text doc
    foreach i [$doc selectNodes "/registers/register"] {
        # dom -> register properties
        set regName [[[$i selectNodes "name"] childNodes] nodeValue]
        set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
        set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
        # register properties -> gui
        toolkit_add ${baseGroupName}_${regName}_group group $baseGroupName
        toolkit_set_property ${baseGroupName}_${regName}_group title "${regName}: ${regAddrOfst}"
        toolkit_set_property ${baseGroupName}_${regName}_group itemsPerRow 4
        toolkit_set_property ${baseGroupName}_${regName}_group toolTip $regDespt
        toolkit_set_property ${baseGroupName}_${regName}_group preferredWidth 180
        toolkit_set_property ${baseGroupName}_${regName}_group expandableX true
        # dom -> field properties -> gui
        foreach j [$i selectNodes "fields/field"] {
            # ---------- parse properties --------------
            # dom -> field properties
            set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
            set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
            set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
            set bitDescpt [::data_path_bts::gui::field_description $j]
            # [msb:lsb] -> $bitMsb and $bitLsb
            set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
            set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
            set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
            set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
            # ------------- build gui -----------------
            # field properties -> gui
            # single bit field: comboBox
            if {$bitLsb == $bitMsb} {
                toolkit_add ${baseGroupName}_${regName}${bitName}_checkBox checkBox ${baseGroupName}_${regName}_group
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_checkBox label $bitName
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_checkBox toolTip $bitDescpt
                if {[string equal $bitAccess "read-only"]} {
                    # make it gray if read-only, cannot make it not editable from gui, instead make the background color gray
                    toolkit_set_property ${baseGroupName}_${regName}${bitName}_checkBox backgroundColor gray
                    # done here
                }
            } else {
            # multiple bit field: textField 
                toolkit_add ${baseGroupName}_${regName}${bitName}_textField textField ${baseGroupName}_${regName}_group
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField label $bitName
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField text "0x0"
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField toolTip $bitDescpt
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField expandableX true
                # 10-20 unit for each letter 
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField minWidth [expr [string length $bitName]*2 + 10]
                toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField maxWidth [expr [string length $bitName]*2 + 55]
                if {[string equal $bitAccess "read-only"]} {
                    # make it gray if read-only 
                    toolkit_set_property ${baseGroupName}_${regName}${bitName}_textField editable false
                    # done here
                }
            } 
        }
    }
    return -code ok
}

    #########################################################################################################
    # @name             gui2device 
    #
    # @berief           (store) collect current gui values and write to device 
    # @param            <bspPkgName> - BSP package name of this IP core 
    #                   <baseGroupName> - base group name to reference the gui widgets 
    #                   <typeName> - the "typename" you get from the marker service points to the qsys ip
    #
    # @return           -code ok : success
    #########################################################################################################
proc ::data_path_bts::gui::gui2device {bspPkgName baseGroupName typeName} {
    # init...  
    variable fd_global_variable
    set n 0
    
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # check if multiple ip(s) are present 
    if {[::mu3e::helpers::probe_global_variable $fd_global_variable ${typeName}_copies]} {
        # exists: multiple instance
        set ipCopies [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_copies]
    } else {
        # does not exist: single
        set ipCopies 1
    }
    
    # gvtable -> base address
    set ipBases [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_base_address]
    
    # gvtable - > xml
    if {![::mu3e::helpers::probe_global_variable $fd_global_variable ${bspPkgName}_doc_xml]} {
        # fail: does not exist
        toolkit_send_message error "gui2device: no bsp reg map found"
        return -code error 
    } else {
        # success: exists
        set xml_plain_text [::mu3e::helpers::get_global_variable $fd_global_variable ${bspPkgName}_doc_xml]
    }
    
    # xml -> dom 
    dom parse $xml_plain_text doc
    
    
    # ---------------------- get multiple copies -------------------------
    foreach ipBase $ipBases {
        # set the basegroup name
        if {$ipCopies > 1} {
            # multiple instance: set for different groups (pad name)
            set baseGroupNameN "$baseGroupName$n"
            incr n
        } else {
            # single instance: set for default group
            set baseGroupNameN $baseGroupName
        }

        ::data_path_bts::gui::maybe_alert_runtime_version $bspPkgName $typeName $master_fd $ipBase
        
        # gui -> regValue
        foreach i [$doc selectNodes "/registers/register"] {
            # writeBeforeRead registers are read-only page views; skip on write-back
            if {[$i selectNodes "writeBeforeRead"] ne ""} {
                continue
            }
            set regValue ""
            # --------------- parse register ---------------
            set regName [[[$i selectNodes "name"] childNodes] nodeValue]
            set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
            set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
            # init as "00000......00000" (32 zeros)
            set regValue [::mu3e::helpers::init_register32_value]
            foreach j [$i selectNodes "fields/field"] {
                # --------------- parse field ---------------
                set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
                set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
                set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
                # [msb:lsb] -> $bitMsb and $bitLsb
                set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
                set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
                set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
                set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
                # gui -> bitValue
                # single bit: read checkBox 
                if {$bitLsb == $bitMsb} {
                    set bitValue [toolkit_get_property ${baseGroupNameN}_${regName}${bitName}_checkBox checked]
                    if {[string equal $bitValue false]} { 
                        set bitValue 0
                    } else {
                        set bitValue 1
                    }
                    #string replace $regValue 0 15 1111
                    set regValue [string replace $regValue $bitLsb $bitMsb $bitValue]
                    #puts "write_lvds: field ${bitName}, value ${bitValue}"
                } else {
                # multiple bit: read textField
                    if {[string equal $bitAccess "read-only"]} {
                        # read-only: do not write
                        continue
                    } else {
                        # writable: textField -> bitValue
                        set bitLen [expr $bitMsb - $bitLsb + 1]
                        set trimH [expr int(ceil($bitLen/4.0)*4)-1]
                        set trimL [expr ${bitLen}%4]
                        
                        # textField string -> binary string
                        set bitsValue [toolkit_get_property ${baseGroupNameN}_${regName}${bitName}_textField text]

                        # textField string -> binary string
                        set bitsValue [::mu3e::helpers::hex2bin $bitsValue]

                        
                        set bitsValue [::mu3e::helpers::binary_trim_little_endien $bitsValue 0 [expr $bitLen-1]]

                        # padding zeros to upper bits 
                        while {[expr [string length $bitsValue] < ${bitLen}]} {
                            set bitsValue "0$bitsValue"
                        }
                        set bitsValue [::mu3e::helpers::string_reverse $bitsValue]
                        set regValue [string replace $regValue $bitLsb $bitMsb $bitsValue]
                        #puts "write_lvds: field ${bitName}, value ${bitsValue}"
                    }
                }
            }
            # bitValue(s) -> regValue
            set regValue [::mu3e::helpers::parse_reverse_bit_stream ${regValue}]
            # h2d 
            master_write_32 $master_fd [expr ${ipBase}+${regAddrOfst}] $regValue
            #puts "write: ${regValue} -> ${regAddrOfst}"
        }
    }
    toolkit_send_message info "gui2device: write to \"${typeName}\" registers successful, byte~"
    return -code ok
}


    #########################################################################################################
    # @name             device2gui 
    #
    # @berief           (load) read the registers value in the device to host gui
    # @param            <bspPkgName> - BSP package name of this IP core 
    #                   <baseGroupName> - base group name to reference the gui widgets 
    #                   <typeName> - the "typename" you get from the marker service points to the qsys ip
    #
    # @return           -code ok : success
    #########################################################################################################
proc ::data_path_bts::gui::device2gui {bspPkgName baseGroupName typeName} {
    # init...  
    variable fd_global_variable
    set n 0
    
    # check if multiple ip(s) are present 
    if {[::mu3e::helpers::probe_global_variable $fd_global_variable ${typeName}_copies]} {
        # exists: multiple instance
        set ipCopies [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_copies]
    } else {
        # does not exist: single
        set ipCopies 1
    }
    
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # gvtable -> base address
    set ipBases [::mu3e::helpers::get_global_variable $fd_global_variable "${typeName}_base_address"]

    # gvtable - > xml (bsp structure)
    if {![::mu3e::helpers::probe_global_variable $fd_global_variable ${bspPkgName}_doc_xml]} {
        # fail: does not exist
        toolkit_send_message error "gui2device: no bsp reg map found"
        return -code error 
    } else {
        # success: exists
        set xml_plain_text [::mu3e::helpers::get_global_variable $fd_global_variable ${bspPkgName}_doc_xml]
    }
    
    # xml -> dom 
    dom parse $xml_plain_text doc
    
    # ---------------------- set multiple copies -------------------------
    foreach ipBase $ipBases {
        # set the 
        if {$ipCopies > 1} {
            # multiple instance: set for different groups (pad name)
            set baseGroupNameN "$baseGroupName$n"
            incr n
        } else {
            # single instance: set for default group
            set baseGroupNameN $baseGroupName
        
        }
        ::data_path_bts::gui::maybe_alert_runtime_version $bspPkgName $typeName $master_fd $ipBase
        # regValue -> gui
        foreach i [$doc selectNodes "/registers/register"] {
            set regValue ""
            # ------------------- parse register --------------------
            set regName [[[$i selectNodes "name"] childNodes] nodeValue]
            set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
            set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
            # writeBeforeRead: write the selector value before reading (read-multiplexed registers)
            set wbrNode [$i selectNodes "writeBeforeRead"]
            if {$wbrNode ne ""} {
                set selectorValue [[$wbrNode childNodes] nodeValue]
                master_write_32 $master_fd [expr ${ipBase}+${regAddrOfst}] $selectorValue
            }
            # master -> regValue (d2h read)
            set regValue [master_read_32 $master_fd [expr ${ipBase}+${regAddrOfst}] 1]
            #puts [format "read: %x from %x" $regValue [expr ${ipBase}+${regAddrOfst}]]
            set regValueBits [::mu3e::helpers::hex2bin $regValue]
            foreach j [$i selectNodes "fields/field"] {
                #  ------------------- parse field -------------------
                set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
                set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
                set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
                # [msb:lsb] -> $bitMsb and $bitLsb
                set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
                set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
                set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
                set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
                # bitValue -> bitBinary
                set bitBinary [::mu3e::helpers::binary_trim_little_endien $regValueBits $bitLsb $bitMsb]
                # bitBinary -> gui
                if {$bitLsb == $bitMsb} {
                    # single bit: write checkBox
                    toolkit_set_property ${baseGroupNameN}_${regName}${bitName}_checkBox checked $bitBinary
                } else {
                    # multiple bit: write comboBox
                    set bitHex [::mu3e::helpers::bin2hex $bitBinary]
                    toolkit_set_property ${baseGroupNameN}_${regName}${bitName}_textField text $bitHex
                }
            }
        }
    }
    toolkit_send_message info "device2gui: read from \"${typeName}\" registers successful, byte~"
    # enable the write button 
    
    return -code ok

}
    ############################################
    #                                          #
    #               misc functions             # 
    #                                          #
    ############################################
    
    ###############################
    # histograms 
    ###############################
proc ::data_path_bts::gui::read_hist {baseGroupName} {
    # init...
    set hist_bins 256
    set bin_index 0
    # get time for uid
    set seed_time [clock seconds]
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    variable fd_global_variable
    # gvtable -> base address
    set hist_csr_base [::mu3e::helpers::get_global_variable $fd_global_variable "histogram_statistics.csr_base_address"]
    set hist_bin_base [::mu3e::helpers::get_global_variable $fd_global_variable "histogram_statistics.hist_bin_base_address"]
    set hist_barChart_name [::mu3e::helpers::get_global_variable $fd_global_variable "hist_barChart_name"]
    # Append default wait time for histogram accumulation (ms)
    if {![::mu3e::helpers::probe_global_variable $fd_global_variable "hist_wait_time"]} {
        ::mu3e::helpers::append_global_variable $fd_global_variable "hist_wait_time" 1000
    }
    # get plot range 
    set low [toolkit_get_property "hist_lo_comboBox" selectedItem]
    set high [toolkit_get_property "hist_hi_comboBox" selectedItem]
    # get boundary and calc bin size
    set unsigned [toolkit_get_property ${baseGroupName}_csrrepresentation_checkBox checked]
    set left [toolkit_get_property ${baseGroupName}_left_boundleft_bound_textField text]
    set right [toolkit_get_property ${baseGroupName}_right_boundright_bound_textField text]
    #puts [format "left: %i right: %i" $left $right]
    if {!$unsigned} {
        set left [::mu3e::helpers:hex2signed $left]
        set right [::mu3e::helpers:hex2signed $right]
    } 
    #puts [format "left: %i right: %i" $left $right]
    set bin_sz [expr 1.0*($right - $left)/$hist_bins]
    
    # 1) flush (plot and IP)
    # -------------------- PLOT SETUP (no flush) --------------------
    # Use existing bar chart if present; otherwise create it once and remember the name
    set chart_var_name "hist_barChart_name"
    set chart_exists [::mu3e::helpers::probe_global_variable $fd_global_variable $chart_var_name]
    if {!$chart_exists} {
        # First time: create a stable chart name and remember it
        set chart_name "hist_barChart"
        ::mu3e::helpers::append_global_variable $fd_global_variable $chart_var_name $chart_name
    } else {
        set chart_name [::mu3e::helpers::get_global_variable $fd_global_variable $chart_var_name]
    }

    # Try to (re)configure the chart; if it's not created yet, create it now
    set need_create 0
    catch {toolkit_get_property $chart_name visible} errVis
    if {[string match "*invalid*" $errVis] || [string match "*not found*" $errVis]} {
        set need_create 1
    }

    if {$need_create} {
        toolkit_add $chart_name barChart "histDisplayGroup"
        toolkit_set_property $chart_name preferredWidth 1000
        toolkit_set_property $chart_name title "Histogram Bin Plot"
    }

    # Update axis labels (range or units may have changed)
    toolkit_set_property $chart_name labelX [format "\[%d : %d\]" $left $right]
    toolkit_set_property $chart_name labelY [format "bin count / %.2f" $bin_sz]
    toolkit_set_property $chart_name visible 1
    toolkit_set_property $chart_name enabled 1

    # -------------------- RESET ACCUMULATOR IN IP --------------------
    # (Keep this reset; but we don't flush the plot UI)
    master_write_32 $master_fd $hist_bin_base 0x0

    # -------------------- ACCUMULATION WITH REAL TIME --------------------
    set wait_ms [::mu3e::helpers::get_global_variable $fd_global_variable "hist_wait_time"]
    if {![string is integer -strict $wait_ms]} {
        toolkit_send_message warning "hist_wait_time invalid; using 1000 ms"
        set wait_ms 1000
    }
    set total_s [expr {int(ceil($wait_ms/1000.0))}]

    # record start time
    set start_ms [clock milliseconds]

    set next_report 1000
    set next_snapshot 5000

    while {1} {
        set now_ms [clock milliseconds]
        set elapsed_ms [expr {$now_ms - $start_ms}]
        set elapsed_s  [expr {int($elapsed_ms / 1000)}]

        # progress message every 1s
        if {$elapsed_ms >= $next_report && $elapsed_s <= $total_s} {
            toolkit_send_message info "Histogram accumulating... ${elapsed_s}s / ${total_s}s"
            incr next_report 1000
        }

        # snapshot every 5s
        if {$elapsed_ms >= $next_snapshot && $elapsed_s <= $total_s} {
            set csr_pack [master_read_32 $master_fd $hist_bin_base $hist_bins]
            # delete old chart by hiding it
            toolkit_set_property $chart_name visible 0
            toolkit_set_property $chart_name enabled 0

            # recreate fresh chart
            toolkit_add $chart_name barChart "histDisplayGroup"
            toolkit_set_property $chart_name preferredWidth 1000
            toolkit_set_property $chart_name title "Histogram Bin Plot"
            toolkit_set_property $chart_name labelX [format "\[%d : %d\]" $left $right]
            toolkit_set_property $chart_name labelY [format "bin count / %.2f" $bin_sz]
            set idx 0
            foreach regValue $csr_pack {
                if {($idx >= $low) && ($idx <= $high)} {
                    set y [format %i $regValue]
                    set x [expr {$idx*$bin_sz + 0.5*$bin_sz + $left}]
                    toolkit_set_property $chart_name itemValue [list $x $y]
                }
                incr idx
            }
            incr next_snapshot 5000
        }

        # check end condition
        if {$elapsed_ms >= $wait_ms} {
            break
        }

        # small sleep to avoid busy loop
        after 100
    }

    # final snapshot
    set csr_pack [master_read_32 $master_fd $hist_bin_base $hist_bins]
    # delete old chart by hiding it
    toolkit_set_property $chart_name visible 0
    toolkit_set_property $chart_name enabled 0

    # recreate fresh chart
    toolkit_add $chart_name barChart "histDisplayGroup"
    toolkit_set_property $chart_name preferredWidth 1000
    toolkit_set_property $chart_name title "Histogram Bin Plot"
    toolkit_set_property $chart_name labelX [format "\[%d : %d\]" $left $right]
    toolkit_set_property $chart_name labelY [format "bin count / %.2f" $bin_sz]
    set idx 0
    foreach regValue $csr_pack {
        if {($idx >= $low) && ($idx <= $high)} {
            set y [format %i $regValue]
            set x [expr {$idx*$bin_sz + 0.5*$bin_sz + $left}]
            toolkit_set_property $chart_name itemValue [list $x $y]
        }
        incr idx
    }

    toolkit_send_message info "Histogram accumulation complete."
    ::mu3e::helpers::set_global_variable $fd_global_variable "hist_regpack" $csr_pack
    return -code ok
    # -------------------- OLD CODE BELOW (flush plot) --------------------


    # # hide old plot
    # toolkit_set_property $hist_barChart_name visible 0
    # toolkit_set_property $hist_barChart_name enabled 0
    # # update gvtable
    # ::mu3e::helpers::set_global_variable $fd_global_variable "hist_barChart_name" "hist_barChart$seed_time"
    # # create new plot
    # toolkit_add "hist_barChart$seed_time" barChart "histDisplayGroup"
    # toolkit_set_property "hist_barChart$seed_time" preferredWidth 1000
    # toolkit_set_property "hist_barChart$seed_time" title "Histogram Bin Plot"
    # toolkit_set_property "hist_barChart$seed_time" labelX [format "\[%d : %d\]" $left $right]
    # toolkit_set_property "hist_barChart$seed_time" labelY [format "bin count / %.2f" $bin_sz]
    
    # # sclr the IP 
    # master_write_32 $master_fd $hist_bin_base 0x0
    # # 2) wait for user-defined accumulation time with progress output
    # set wait_ms [::mu3e::helpers::get_global_variable $fd_global_variable "hist_wait_time"]
    # if {![string is integer -strict $wait_ms]} {
    #     toolkit_send_message warning "hist_wait_time invalid, fallback to 1000 ms"
    #     set wait_ms 1000
    # }

    # # round up to seconds
    # set total_s [expr {int(ceil($wait_ms/1000.0))}]

    # for {set s 1} {$s <= $total_s} {incr s} {
    #     after 1000
    #     toolkit_send_message info "Histogram accumulating... ${s}s / ${total_s}s"
    # }

    # toolkit_send_message info "Histogram accumulation complete."
    # # 3) read <hist_bin>
    # set csr_pack [master_read_32 $master_fd $hist_bin_base $hist_bins]
    # #puts $csr_pack
    # # 4) plot 
    # foreach regValue $csr_pack {
    #     # 1) within range: plot
    #     if {[expr $bin_index <= $high && $bin_index >=$low]} {
    #         set regValue [format %i $regValue]
    #         set bin_mid [expr $bin_index*$bin_sz+0.5*$bin_sz+$left]
    #         toolkit_set_property "hist_barChart$seed_time" itemValue [list $bin_mid $regValue]
    #     # 2) out of range: do not plot
    #     } else {
    #         #toolkit_set_property "hist_barChart" itemValue [list $bin_index 0]
    #     }
    #     incr bin_index
    # }
    # toolkit_send_message info "read_hist: histogram `rate` plotted"
    # ::mu3e::helpers::set_global_variable $fd_global_variable "hist_regpack" $csr_pack
    # return -code ok
}

proc ::data_path_bts::gui::save_hist {fileChooserButtonName baseGroupName} {
    # init
    variable fd_global_variable
    set hist_bins 256
    set bin_index 0
    set bin_mids [list]
    set regValues [list]
    # get boundary and calc bin size
    set unsigned [toolkit_get_property ${baseGroupName}_csrrepresentation_checkBox checked]
    set left [toolkit_get_property ${baseGroupName}_left_boundleft_bound_textField text]
    set right [toolkit_get_property ${baseGroupName}_right_boundright_bound_textField text]
    if {!$unsigned} {
        set left [::mu3e::helpers:hex2signed $left]
        set right [::mu3e::helpers:hex2signed $right]
    } 
    set bin_sz [expr 1.0*($right - $left)/$hist_bins]
    
    # get hist content
    set csr_pack [::mu3e::helpers::get_global_variable $fd_global_variable "hist_regpack"]
    
    if {![catch [toolkit_get_property $fileChooserButtonName paths]]} {
		toolkit_send_message warning "save_hist: file selection cancelled, byte~"
		return -code error
	} else {
        # open path and file
		set file_path [toolkit_get_property $fileChooserButtonName paths]
		set fd [open "$file_path" w]
        
        # get reg value saved by last session -> two lists for x and y
        foreach regValue $csr_pack {
            set regValue [format %i $regValue]
            set bin_mid [expr $bin_index*$bin_sz+0.5*$bin_sz+$left]
            lappend bin_mids $bin_mid
            lappend regValues $regValue
            incr bin_index
        }
        # save to file 
        #puts $bin_mids
        #puts $regValues
		puts $fd $bin_mids 
        puts $fd $regValues 
		close $fd	
		toolkit_send_message info "save_hist: histogram data saved (${file_path}), thank you!"	
		return -code ok
	}
}

proc ::data_path_bts::gui::scan_hist {fileChooserButtonName baseGroupName stepSizeButtonName minButtonName nstepButtonName} {
    # init
    variable fd_global_variable
    set hist_bins 256
    set bin_mids [list]
    set regValues [list]
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    # gvtable -> base address
    set hist_csr_base [::mu3e::helpers::get_global_variable $fd_global_variable "histogram_statistics.csr_base_address"]
    set hist_bin_base [::mu3e::helpers::get_global_variable $fd_global_variable "histogram_statistics.hist_bin_base_address"]
    # scan related 
    set step_sz [toolkit_get_property $stepSizeButtonName text]
    set scan_min [toolkit_get_property $minButtonName text]
    set nstep [toolkit_get_property $nstepButtonName text]
    set unsigned [toolkit_get_property ${baseGroupName}_csrrepresentation_checkBox checked]
    
    # scan iterations
    for {set i 0} {$i < $nstep} {incr i} {
        # allow for abort
        # ...
    
        # 1) load new setting
        master_write_32 $master_fd [expr $hist_csr_base + 0x4] [expr $scan_min + $i*$step_sz]
        master_write_32 $master_fd [expr $hist_csr_base + 0x8] [expr $scan_min + [expr $i+1]*$step_sz]
        # 2) sclr the IP 
        master_write_32 $master_fd $hist_bin_base 0x0
        set bin_mids [list]
        set regValues [list]
        # 3) wait 1 s
        after 1000
        # 4) read <hist_bin>
        set csr_pack [master_read_32 $master_fd $hist_bin_base $hist_bins]
        # 5) get boundary and calc bin size
        set left [expr $scan_min + $i*$step_sz]
        set right [expr $scan_min + [expr $i+1]*$step_sz]
        if {!$unsigned} {
            set left [::mu3e::helpers:hex2signed $left]
            set right [::mu3e::helpers:hex2signed $right]
        } 
        set bin_index 0
        set bin_sz [expr 1.0*($right - $left)/$hist_bins]
            
        if {![catch [toolkit_get_property $fileChooserButtonName paths]]} {
            toolkit_send_message warning "save_hist: file selection cancelled, byte~"
            return -code error
        } else {
            # open path and file
            set file_path [toolkit_get_property $fileChooserButtonName paths]
            set file_path "${file_path}_step-${i}.txt"
            set fd [open "$file_path" w]
            
            # get reg value saved by last session -> two lists for x and y
            foreach regValue $csr_pack {
                set regValue [format %i $regValue]
                set bin_mid [expr $bin_index*$bin_sz+0.5*$bin_sz+$left]
                lappend bin_mids $bin_mid
                lappend regValues $regValue
                incr bin_index
            }
            # save to file 
            #puts $bin_mids
            #puts $regValues
            puts $fd $bin_mids 
            puts $fd $regValues 
            close $fd	
            toolkit_send_message info "scan_hist: process (${i}/${nstep}), histogram data saved as (${file_path})"	
        }
    }
    toolkit_send_message info "scan_hist: process (${nstep}/${nstep}), scan completed successful)"	
    return -code ok
}


    ###############################
    # deassembly 
    ###############################

proc ::data_path_bts::gui::setup_deassembly {baseGroupName} {
    variable fd_global_variable
    # 1) PREPARATION
    set xml_plain_text [::data_path_bts::gui::resolve_doc_xml "frame_deassembly" [list]]
    set xml_plain_text [::data_path_bts::gui::set_doc_xml "frame_deassembly" $xml_plain_text]
    dom parse $xml_plain_text doc
    # 2) SETUP 
    # parse xml tree of reg map and create gui 
    foreach i [$doc selectNodes "/registers/register"] {
        # parse register
        set regName [[[$i selectNodes "name"] childNodes] nodeValue]
        set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
        set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
        # gui for register
        toolkit_add ${regName}_group group $baseGroupName
        toolkit_set_property ${regName}_group title "${regName}: ${regAddrOfst}"
        toolkit_set_property ${regName}_group itemsPerRow 4
        toolkit_set_property ${regName}_group toolTip $regDespt
        foreach j [$i selectNodes "fields/field"] {
            # parse field 
            set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
            set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
            set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
            set bitDescpt [::data_path_bts::gui::field_description $j]
            # -- parse the [msb:lsb] format
            set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
            set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
            set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
            set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
            #puts "${bitMsb} : ${bitLsb}"
            # gui for field
            # 1) setup checkBox for single bit
            if {$bitLsb == $bitMsb} {
                toolkit_add ${regName}${bitName}_checkBox checkBox ${regName}_group
                toolkit_set_property ${regName}${bitName}_checkBox label $bitName
                toolkit_set_property ${regName}${bitName}_checkBox toolTip $bitDescpt
            
            } else {
            # 2) setup comboBox for multiple bit
                toolkit_add ${regName}${bitName}_textField textField ${regName}_group
                toolkit_set_property ${regName}${bitName}_textField label $bitName
                toolkit_set_property ${regName}${bitName}_textField text "?"
                toolkit_set_property ${regName}${bitName}_textField toolTip $bitDescpt
                if {[string equal $bitAccess "read-only"]} {
                    # make it gray if read-only 
                    toolkit_set_property ${regName}${bitName}_textField editable false
                } else {
                    # master write
                    
                }
            }
        }
    }
    
    
    
    
    return -code ok 
}

proc ::data_path_bts::gui::setup_deassembly_controlPanel {baseGroupName} {
    variable lvds_monitor_fd ""
    toolkit_add            "deassembly_controlPanel_write_button"     button      $baseGroupName
    toolkit_set_property   "deassembly_controlPanel_write_button"     text        "update registers"
    toolkit_set_property   "deassembly_controlPanel_write_button"     onClick      {::data_path_bts::gui::deassembly_update_registers_functor }
     
    toolkit_add            "deassembly_controlPanel_monitor_checkBox"     checkBox      $baseGroupName
    toolkit_set_property   "deassembly_controlPanel_monitor_checkBox"     label         "monitor registers"   
    toolkit_set_property   "deassembly_controlPanel_monitor_checkBox"     onClick      {::data_path_bts::gui::deassembly_monitor_registers_functor}

    toolkit_add             "deassembly_controlPanel_loading_bitmap"  bitmap          $baseGroupName
    toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  path            ../system_console/figures/loading.gif
    toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  label           "stopped"
    toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  visible         0
    
    return -code ok
}

proc ::data_path_bts::gui::deassembly_update_registers_functor {} {
    

    return -code ok
}

proc ::data_path_bts::gui::deassembly_monitor_registers_functor {} {
    variable deassembly_monitor_fd
    set checked [toolkit_get_property "deassembly_controlPanel_monitor_checkBox" checked]
    # hide button
    toolkit_set_property "deassembly_controlPanel_write_button" enabled [expr ![expr $checked]]
    # get selected master service path
    set master_path [::mu3e::helpers::get_selected_servicePath "jtagMasterGroup_showmp_comboBox"]
    if {$checked} {
        # open monitor serivce
        if {$deassembly_monitor_fd ne ""} {
            toolkit_send_message info "deassembly_monitor_registers_functor: monitor started..." 
        } else {
            #puts "monitor not created"
            # open monitor service -> fd
            set deassembly_monitor_fd [::mu3e::helpers::open_monitor_service]
            monitor_set_interval $deassembly_monitor_fd 1000
            monitor_set_callback $deassembly_monitor_fd [list ::data_path_bts::gui::read_deassembly]
            monitor_add_range $deassembly_monitor_fd $master_path 0x0 4
            toolkit_send_message info "deassembly_monitor_registers_functor: registered monitor service, monitor started..." 
        }
        monitor_set_enabled $deassembly_monitor_fd 1
        # update loading gif
        toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  label           "monitering..."
        toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  visible         1
        toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  toolTip         "press again to stop"
    } else {
        monitor_set_enabled $deassembly_monitor_fd 0
        # update loading gif
        toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  label           "stopped"
        toolkit_set_property    "deassembly_controlPanel_loading_bitmap"  visible         0
    }
    return -code ok

}

proc ::data_path_bts::gui::read_deassembly {} {
    # init ...
    variable fd_global_variable
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    # gvtable -> base address
    set deassembly_base_list [::mu3e::helpers::get_global_variable $fd_global_variable "mutrig_frame_deassembly.csr_base_address"]
    set span [expr 3*4]
    foreach base $deassembly_base_list {
        set registers [master_read_32 $master_fd $base 3]
        foreach register $registers {
            
        }
    }
    # read 
   
}   

    ###############################
    # lvds 
    ###############################

proc ::data_path_bts::gui::setup_lvds {baseGroupName n_lane} {
    variable fd_global_variable
    # 1) PREPARATION
    set xml_plain_text [::data_path_bts::gui::resolve_doc_xml "lvds_rx" [list -n_lane $n_lane]]
    set xml_plain_text [::data_path_bts::gui::set_doc_xml "lvds_rx" $xml_plain_text]
    dom parse $xml_plain_text doc
    
    # 2) SETUP 
    # parse xml tree of reg map and create gui 
    foreach i [$doc selectNodes "/registers/register"] {
        # parse register
        set regName [[[$i selectNodes "name"] childNodes] nodeValue]
        set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
        set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
        # gui for register
        toolkit_add ${regName}_group group $baseGroupName
        toolkit_set_property ${regName}_group title "${regName}: ${regAddrOfst}"
        toolkit_set_property ${regName}_group itemsPerRow 4
        toolkit_set_property ${regName}_group toolTip $regDespt
        foreach j [$i selectNodes "fields/field"] {
            # parse field 
            set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
            set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
            set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
            set bitDescpt [::data_path_bts::gui::field_description $j]
            # -- parse the [msb:lsb] format
            set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
            set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
            set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
            set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
            #puts "${bitMsb} : ${bitLsb}"
            # gui for field
            # 1) setup checkBox for single bit
            if {$bitLsb == $bitMsb} {
                toolkit_add ${regName}${bitName}_checkBox checkBox ${regName}_group
                toolkit_set_property ${regName}${bitName}_checkBox label $bitName
                toolkit_set_property ${regName}${bitName}_checkBox toolTip $bitDescpt
            
            } else {
            # 2) setup comboBox for multiple bit
                toolkit_add ${regName}${bitName}_textField textField ${regName}_group
                toolkit_set_property ${regName}${bitName}_textField label $bitName
                toolkit_set_property ${regName}${bitName}_textField text "?"
                toolkit_set_property ${regName}${bitName}_textField toolTip $bitDescpt
                if {[string equal $bitAccess "read-only"]} {
                    # make it gray if read-only 
                    toolkit_set_property ${regName}${bitName}_textField editable false
                } else {
                    # master write  
                }
            }
        }
    }
    return -code ok 
}



proc ::data_path_bts::gui::setup_lvds_controlPanel {baseGroupName n_lane} {
    variable lvds_monitor_fd ""
    toolkit_add            "lvds_controlPanel_read_button"     button      $baseGroupName
    toolkit_set_property   "lvds_controlPanel_read_button"     text        "update registers"
    toolkit_set_property   "lvds_controlPanel_read_button"     onClick      {::data_path_bts::gui::lvds_update_registers_functor }
     
    toolkit_add            "lvds_controlPanel_monitor_checkBox"     checkBox      $baseGroupName
    toolkit_set_property   "lvds_controlPanel_monitor_checkBox"     label         "monitor registers"   
    toolkit_set_property   "lvds_controlPanel_monitor_checkBox"     onClick      {::data_path_bts::gui::lvds_monitor_registers_functor}

    toolkit_add             "lvds_controlPanel_loading_bitmap"  bitmap          $baseGroupName
    toolkit_set_property    "lvds_controlPanel_loading_bitmap"  path            ../system_console/figures/loading.gif
    toolkit_set_property    "lvds_controlPanel_loading_bitmap"  label           "stopped"
    toolkit_set_property    "lvds_controlPanel_loading_bitmap"  visible         0
    
    return -code ok
}

proc ::data_path_bts::gui::lvds_update_registers_functor {} {
    ::data_path_bts::gui::write_lvds

    return -code ok
}

proc ::data_path_bts::gui::lvds_monitor_registers_functor {} {
    variable lvds_monitor_fd
    set checked [toolkit_get_property "lvds_controlPanel_monitor_checkBox" checked]
    # hide button
    toolkit_set_property "lvds_controlPanel_read_button" enabled [expr ![expr $checked]]
    # get selected master service path
    set master_path [::mu3e::helpers::get_selected_servicePath "jtagMasterGroup_showmp_comboBox"]
    if {$checked} {
        # open monitor serivce
        if {$lvds_monitor_fd ne ""} {
            toolkit_send_message info "lvds_monitor_registers_functor: monitor started..." 
        } else {
            #puts "monitor not created"
            # open monitor service -> fd
            set lvds_monitor_fd [::mu3e::helpers::open_monitor_service]
            monitor_set_interval $lvds_monitor_fd 1000
            monitor_set_callback $lvds_monitor_fd [list ::data_path_bts::gui::read_lvds]
            monitor_add_range $lvds_monitor_fd $master_path 0x0 4
            toolkit_send_message info "lvds_monitor_registers_functor: registered monitor service, monitor started..." 
        }
        monitor_set_enabled $lvds_monitor_fd 1
        # update loading gif
        toolkit_set_property    "lvds_controlPanel_loading_bitmap"  label           "monitering..."
        toolkit_set_property    "lvds_controlPanel_loading_bitmap"  visible         1
        toolkit_set_property    "lvds_controlPanel_loading_bitmap"  toolTip         "press again to stop"
    } else {
        monitor_set_enabled $lvds_monitor_fd 0
        # update loading gif
        toolkit_set_property    "lvds_controlPanel_loading_bitmap"  label           "stopped"
        toolkit_set_property    "lvds_controlPanel_loading_bitmap"  visible         0
    }
    return -code ok
}


proc ::data_path_bts::gui::read_lvds { } {
    
    # init...  
    variable fd_global_variable
    set n 0
    # init more...
    set typeName "lvds_rx_controller_pro.csr"
    set baseGroupName ""
    set bspPkgName "lvds"
    
    # check if multiple ip(s) are present 
    if {[::mu3e::helpers::probe_global_variable $fd_global_variable ${typeName}_copies]} {
        # exists: multiple instance
        set ipCopies [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_copies]
    } else {
        # does not exist: single
        set ipCopies 1
    }
    
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # gvtable -> base address
    set ipBases [::mu3e::helpers::get_global_variable $fd_global_variable "${typeName}_base_address"]

    # gvtable - > xml (bsp structure)
    if {![::mu3e::helpers::probe_global_variable $fd_global_variable ${bspPkgName}_doc_xml]} {
        # fail: does not exist
        toolkit_send_message error "read_lvds: no bsp reg map found"
        return -code error 
    } else {
        # success: exists
        set xml_plain_text [::mu3e::helpers::get_global_variable $fd_global_variable ${bspPkgName}_doc_xml]
    }
    
    # xml -> dom 
    dom parse $xml_plain_text doc
    
    # ---------------------- set multiple copies -------------------------
    foreach ipBase $ipBases {
       
        # regValue -> gui
        foreach i [$doc selectNodes "/registers/register"] {
            set regValue ""
            # ------------------- parse register --------------------
            set regName [[[$i selectNodes "name"] childNodes] nodeValue]
            set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
            set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
            # master -> regValue (d2h read)
            set regValue [master_read_32 $master_fd [expr ${ipBase}+${regAddrOfst}] 1]
            #puts [format "read: %x from %x" $regValue [expr ${ipBase}+${regAddrOfst}]]
            set regValueBits [::mu3e::helpers::hex2bin $regValue]
            foreach j [$i selectNodes "fields/field"] {
                #  ------------------- parse field -------------------
                set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
                set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
                set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
                # [msb:lsb] -> $bitMsb and $bitLsb
                set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
                set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
                set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
                set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
                # bitValue -> bitBinary
                set bitBinary [::mu3e::helpers::binary_trim_little_endien $regValueBits $bitLsb $bitMsb]
                # bitBinary -> gui
                if {$bitLsb == $bitMsb} {
                    # single bit: write checkBox
                    toolkit_set_property ${regName}${bitName}_checkBox checked $bitBinary
                } else {
                    # multiple bit: write comboBox
                    set bitHex [::mu3e::helpers::bin2hex $bitBinary]
                    toolkit_set_property ${regName}${bitName}_textField text $bitHex
                }
            }
        }
    }
    toolkit_send_message info "read_lvds: read from \"${typeName}\" registers successful, byte~"
    # enable the write button 
    
    return -code ok

}



proc ::data_path_bts::gui::write_lvds { } {
    # init...  
    variable fd_global_variable
    # init more...
    set typeName "lvds_rx_controller_pro.csr"
    set baseGroupName ""
    set bspPkgName "lvds"
    
    # request opened master service
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    
    # gvtable -> base address
    set ipBase [::mu3e::helpers::get_global_variable $fd_global_variable ${typeName}_base_address]
    
    # gvtable - > xml
    if {![::mu3e::helpers::probe_global_variable $fd_global_variable ${bspPkgName}_doc_xml]} {
        # fail: does not exist
        toolkit_send_message error "write_lvds: no bsp reg map found"
        return -code error 
    } else {
        # success: exists
        set xml_plain_text [::mu3e::helpers::get_global_variable $fd_global_variable ${bspPkgName}_doc_xml]
    }
    
    # xml -> dom 
    dom parse $xml_plain_text doc
    
    # gui -> regValue
    foreach i [$doc selectNodes "/registers/register"] {
        set regValue ""
        # --------------- parse register ---------------
        set regName [[[$i selectNodes "name"] childNodes] nodeValue]
        set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
        set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
        # init as "00000......00000" (32 zeros)
        set regValue [::mu3e::helpers::init_register32_value]
        foreach j [$i selectNodes "fields/field"] {
            # --------------- parse field ---------------
            set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
            set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
            set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
            # [msb:lsb] -> $bitMsb and $bitLsb
            set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
            set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
            set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
            set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
            # gui -> bitValue
            # single bit: read checkBox 
            if {$bitLsb == $bitMsb} {
                set bitValue [toolkit_get_property ${regName}${bitName}_checkBox checked]
                if {[string equal $bitValue false]} { 
                    set bitValue 0
                } else {
                    set bitValue 1
                }
                #string replace $regValue 0 15 1111
                set regValue [string replace $regValue $bitLsb $bitMsb $bitValue]
                #puts "write_lvds: field ${bitName}, value ${bitValue}"
            } else {
            # multiple bit: read textField
                # writable: textField -> bitValue
                set bitLen [expr $bitMsb - $bitLsb + 1]
                set trimH [expr int(ceil($bitLen/4.0)*4)-1]
                set trimL [expr ${bitLen}%4]
                
                #puts "trimH/L: $trimH $trimL"
                set bitsValue [toolkit_get_property ${regName}${bitName}_textField text]
#                    if {[string equal $bitName "filter"]} {
#                        puts "filter textfield.text: $bitsValue"
#                    }
                
                set bitsValue [::mu3e::helpers::hex2bin $bitsValue]
#                    if {[string equal $bitName "filter"]} {
#                        puts "filter textfield.text: $bitsValue"
#                    }
                
                set bitsValue [::mu3e::helpers::binary_trim_little_endien $bitsValue 0 [expr $bitLen-1]]
#                    if {[string equal $bitName "filter"]} {
#                        puts "filter textfield.text: $bitsValue"
#                    }
                # padding zeros to upper bits 
                while {[expr [string length $bitsValue] < ${bitLen}]} {
                    set bitsValue "0$bitsValue"
                }
                set bitsValue [::mu3e::helpers::string_reverse $bitsValue]
                set regValue [string replace $regValue $bitLsb $bitMsb $bitsValue]
                #puts "write_lvds: field ${bitName}, value ${bitsValue}"
                
            }
        }
        # bitValue(s) -> regValue
        set regValue [::mu3e::helpers::parse_reverse_bit_stream ${regValue}]
        # h2d 
        master_write_32 $master_fd [expr ${ipBase}+${regAddrOfst}] $regValue
        #puts "write: ${regValue} -> ${regAddrOfst}"
    }
    toolkit_send_message info "write_lvds: write to \"${typeName}\" registers successful, byte~"
    return -code ok
}

    ###############################
    # rate 
    ###############################

proc ::data_path_bts::gui::rate_monitor_registers_functor {} {
    variable rate_monitor_active
    variable rate_monitor_generation

    set checked [toolkit_get_property "rateCtrl_checkBox" checked]
    if {$checked} {
        set rate_monitor_active 1
        if {![info exists rate_monitor_generation]} {
            set rate_monitor_generation 0
        }
        incr rate_monitor_generation
        ::data_path_bts::gui::rate_monitor_arm_cycle $rate_monitor_generation 1
    } else {
        set rate_monitor_active 0
        if {![info exists rate_monitor_generation]} {
            set rate_monitor_generation 0
        }
        incr rate_monitor_generation
        ::data_path_bts::gui::rate_monitor_stop_ui
    }
    return -code ok
}

proc ::data_path_bts::gui::rate_monitor_stop_ui {} {
    toolkit_set_property    "rateCtrl_loading_bitmap"  label           "stopped"
    toolkit_set_property    "rateCtrl_loading_bitmap"  visible         0
    toolkit_set_property    "rateCtrl_loading_bitmap"  toolTip         ""
    return -code ok
}

proc ::data_path_bts::gui::rate_monitor_abort {message} {
    variable rate_monitor_active
    variable rate_monitor_generation

    set rate_monitor_active 0
    if {![info exists rate_monitor_generation]} {
        set rate_monitor_generation 0
    }
    incr rate_monitor_generation
    catch {toolkit_set_property "rateCtrl_checkBox" checked false}
    ::data_path_bts::gui::rate_monitor_stop_ui
    toolkit_send_message error $message
    return -code error
}

proc ::data_path_bts::gui::rate_monitor_arm_cycle {generation {announce_wait 0}} {
    variable rate_monitor_active
    variable rate_monitor_generation

    if {![info exists rate_monitor_generation] || $generation != $rate_monitor_generation} {
        return -code ok
    }

    if {![info exists rate_monitor_active] || !$rate_monitor_active} {
        return -code ok
    }

    if {[catch {::data_path_bts::gui::configure_rate_histogram_preset} rate_error]} {
        return [::data_path_bts::gui::rate_monitor_abort "rate_monitor: failed to arm histogram_statistics_0: $rate_error"]
    }

    set wait_ms [::data_path_bts::gui::rate_histogram_initial_wait_ms]
    if {$announce_wait} {
        toolkit_send_message info "rate_monitor: waiting ${wait_ms} ms for histogram_statistics_0 to accumulate one fixed interval"
    }
    toolkit_set_property    "rateCtrl_loading_bitmap"  label           "arming..."
    toolkit_set_property    "rateCtrl_loading_bitmap"  visible         1
    toolkit_set_property    "rateCtrl_loading_bitmap"  toolTip         "waiting for histogram interval; press again to stop"
    after $wait_ms [list ::data_path_bts::gui::rate_monitor_complete_cycle $generation]
    return -code ok
}

proc ::data_path_bts::gui::rate_monitor_complete_cycle {generation} {
    variable rate_monitor_active
    variable rate_monitor_generation

    if {![info exists rate_monitor_generation] || $generation != $rate_monitor_generation} {
        return -code ok
    }

    if {![info exists rate_monitor_active] || !$rate_monitor_active} {
        return -code ok
    }

    if {[catch {::data_path_bts::gui::read_rate 1} rate_error]} {
        return [::data_path_bts::gui::rate_monitor_abort "rate_monitor: failed to read histogram_statistics_0: $rate_error"]
    }

    toolkit_set_property    "rateCtrl_loading_bitmap"  label           "monitoring..."
    toolkit_set_property    "rateCtrl_loading_bitmap"  visible         1
    toolkit_set_property    "rateCtrl_loading_bitmap"  toolTip         "press again to stop"
    after 0 [list ::data_path_bts::gui::rate_monitor_arm_cycle $generation 0]
    return -code ok
}

proc ::data_path_bts::gui::board_bring_up_project_spec {} {
    if {[llength [info commands ::fe_scifi::board_bring_up::project::get_spec]] == 0} {
        return ""
    }

    if {[catch {::fe_scifi::board_bring_up::project::get_spec} project_spec]} {
        return ""
    }

    return $project_spec
}

proc ::data_path_bts::gui::rate_histogram_ip_spec {} {
    set project_spec [::data_path_bts::gui::board_bring_up_project_spec]
    if {$project_spec eq "" || ![dict exists $project_spec ip_sequence]} {
        return ""
    }

    foreach ip_spec [dict get $project_spec ip_sequence] {
        if {[dict exists $ip_spec id] && [dict get $ip_spec id] eq "histogram_ingress"} {
            return $ip_spec
        }
    }

    return ""
}

proc ::data_path_bts::gui::rate_histogram_preset_spec {} {
    set ip_spec [::data_path_bts::gui::rate_histogram_ip_spec]
    if {$ip_spec eq "" || ![dict exists $ip_spec presets]} {
        return ""
    }

    foreach preset_spec [dict get $ip_spec presets] {
        if {[dict exists $preset_spec id] && [dict get $preset_spec id] eq "rate"} {
            return $preset_spec
        }
    }

    return [lindex [dict get $ip_spec presets] 0]
}

proc ::data_path_bts::gui::rate_histogram_expected_version {} {
    set metadata [::data_path_bts::gui::histogram_metadata]
    if {$metadata ne "" && [dict exists $metadata hw_tcl_version]} {
        set parsed_version [::data_path_bts::gui::parse_version_string [dict get $metadata hw_tcl_version]]
        if {$parsed_version ne ""} {
            return $parsed_version
        }
    }

    set ip_spec [::data_path_bts::gui::rate_histogram_ip_spec]
    if {$ip_spec eq "" || ![dict exists $ip_spec expected_version]} {
        return ""
    }

    return [dict get $ip_spec expected_version]
}

proc ::data_path_bts::gui::rate_histogram_sample_interval_ms {} {
    set preset_spec [::data_path_bts::gui::rate_histogram_preset_spec]
    if {$preset_spec ne "" && [dict exists $preset_spec sample_interval_ms]} {
        return [dict get $preset_spec sample_interval_ms]
    }

    return 1000
}

proc ::data_path_bts::gui::rate_histogram_sample_guard_ms {} {
    set preset_spec [::data_path_bts::gui::rate_histogram_preset_spec]
    if {$preset_spec ne "" && [dict exists $preset_spec sample_guard_ms]} {
        return [dict get $preset_spec sample_guard_ms]
    }

    return 50
}

proc ::data_path_bts::gui::rate_histogram_initial_wait_ms {} {
    return [expr {[::data_path_bts::gui::rate_histogram_sample_interval_ms] + [::data_path_bts::gui::rate_histogram_sample_guard_ms]}]
}

proc ::data_path_bts::gui::inventory_expected_bases {type_name} {
    set compiled_inventory [::data_path_bts::gui::compiled_slave_inventory]
    if {$compiled_inventory ne "" && [dict exists $compiled_inventory by_type $type_name]} {
        set expected_bases [list]
        foreach inventory_entry [dict get $compiled_inventory by_type $type_name] {
            lappend expected_bases [dict get $inventory_entry base]
        }
        return $expected_bases
    }

    set project_spec [::data_path_bts::gui::board_bring_up_project_spec]
    if {$project_spec eq "" || ![dict exists $project_spec inventory]} {
        return [list]
    }

    foreach inventory_entry [dict get $project_spec inventory] {
        if {[dict exists $inventory_entry type_name] && [dict get $inventory_entry type_name] eq $type_name} {
            if {[dict exists $inventory_entry expected_bases]} {
                return [dict get $inventory_entry expected_bases]
            }
            return [list]
        }
    }

    return [list]
}

proc ::data_path_bts::gui::base_address_is_resolved {base_value} {
    if {$base_value eq ""} {
        return 0
    }

    if {[scan $base_value %i parsed_value] != 1} {
        return 0
    }

    return [expr {($parsed_value & 0xffffffff) != 0}]
}

proc ::data_path_bts::gui::rate_histogram_resolved_base {linked_bases type_name fallback_index label} {
    variable rate_histogram_address_fallback_done

    if {$fallback_index < [llength $linked_bases]} {
        set preferred_base [lindex $linked_bases $fallback_index]
        if {[::data_path_bts::gui::base_address_is_resolved $preferred_base]} {
            return $preferred_base
        }
    }

    foreach linked_base $linked_bases {
        if {[::data_path_bts::gui::base_address_is_resolved $linked_base]} {
            return $linked_base
        }
    }

    set inventory_bases [::data_path_bts::gui::inventory_expected_bases $type_name]
    if {$fallback_index < [llength $inventory_bases]} {
        set fallback_base [lindex $inventory_bases $fallback_index]
        if {[::data_path_bts::gui::base_address_is_resolved $fallback_base]} {
            set fallback_key [format "%s@%s" $label $fallback_base]
            if {![info exists rate_histogram_address_fallback_done($fallback_key)]} {
                toolkit_send_message warning "${label}: using project inventory fallback base $fallback_base because marker-based linking left the runtime base unresolved"
                set rate_histogram_address_fallback_done($fallback_key) 1
            }
            return $fallback_base
        }
    }

    error "${label}: base address is unresolved after marker linking and no project inventory fallback is available"
}

proc ::data_path_bts::gui::rate_histogram_instance_info {} {
    variable fd_global_variable

    set hist_csr_bases [::mu3e::helpers::get_global_variable $fd_global_variable "histogram_statistics.csr_base_address"]
    set hist_bin_bases [::mu3e::helpers::get_global_variable $fd_global_variable "histogram_statistics.hist_bin_base_address"]
    if {[llength $hist_csr_bases] < 1 || [llength $hist_bin_bases] < 1} {
        error "histogram_statistics base addresses are not linked"
    }

    set hist_csr_base [::data_path_bts::gui::rate_histogram_resolved_base $hist_csr_bases "histogram_statistics.csr" 0 "histogram_statistics_0.csr"]
    set hist_bin_base [::data_path_bts::gui::rate_histogram_resolved_base $hist_bin_bases "histogram_statistics.hist_bin" 0 "histogram_statistics_0.hist_bin"]
    return [list $hist_csr_base $hist_bin_base]
}

proc ::data_path_bts::gui::master_read_u32_scalar {master_fd address} {
    set raw_value [master_read_32 $master_fd $address 1]
    if {[llength $raw_value] > 0} {
        set raw_value [lindex $raw_value 0]
    }

    if {[scan $raw_value %i parsed_value] != 1} {
        error "unable to parse 32-bit readback \"$raw_value\" at [format 0x%X $address]"
    }

    return [expr {$parsed_value & 0xffffffff}]
}

proc ::data_path_bts::gui::parse_int_literal {value {default_value "__NO_DEFAULT__"}} {
    if {[scan $value %i parsed_value] == 1} {
        return [expr {$parsed_value & 0xffffffff}]
    }

    if {$default_value ne "__NO_DEFAULT__"} {
        return $default_value
    }

    error "unable to parse integer literal \"$value\""
}

proc ::data_path_bts::gui::format_histogram_version_word {version_word} {
    return [::data_path_bts::gui::format_common_csr_header_word $version_word]
}

proc ::data_path_bts::gui::rate_histogram_expected_version_word {} {
    set expected_version [::data_path_bts::gui::rate_histogram_expected_version]
    if {$expected_version eq ""} {
        return ""
    }

    set major [expr {[dict get $expected_version major] & 0xff}]
    set minor [expr {[dict get $expected_version minor] & 0xff}]
    set patch [expr {[dict get $expected_version patch] & 0xf}]
    set build [expr {[dict get $expected_version build] & 0xfff}]

    return [expr {($major << 24) | ($minor << 16) | ($patch << 12) | $build}]
}

proc ::data_path_bts::gui::histogram_warn_version_mismatch {master_fd hist_csr_base histogram_name} {
    variable rate_histogram_version_warning_done

    set expected_version_word [::data_path_bts::gui::rate_histogram_expected_version_word]
    if {$expected_version_word eq ""} {
        return -code ok
    }

    set check_key [format "%s@%s" $histogram_name $hist_csr_base]
    if {[info exists rate_histogram_version_warning_done($check_key)]} {
        return -code ok
    }

    set version_register_offset [::data_path_bts::gui::histogram_register_offset "VERSION" 0x34]
    if {[catch {set actual_version_word [::data_path_bts::gui::master_read_u32_scalar $master_fd [expr {$hist_csr_base + $version_register_offset}]]} version_error]} {
        toolkit_send_message warning "${histogram_name}: unable to read VERSION register: $version_error"
        set rate_histogram_version_warning_done($check_key) 1
        return -code ok
    }

    if {$actual_version_word != $expected_version_word} {
        toolkit_send_message warning "${histogram_name}: VERSION mismatch, toolkit expects [::data_path_bts::gui::format_histogram_version_word $expected_version_word] but hardware reports [::data_path_bts::gui::format_histogram_version_word $actual_version_word]"
    }

    set rate_histogram_version_warning_done($check_key) 1
    return -code ok
}

proc ::data_path_bts::gui::histogram_wait_for_cfg_apply {master_fd hist_csr_base {timeout_ms 1000}} {
    set control_register_offset [::data_path_bts::gui::histogram_register_offset "csr" 0x0]
    set deadline_ms [expr {[clock milliseconds] + $timeout_ms}]
    while {[clock milliseconds] < $deadline_ms} {
        set control_reg [::data_path_bts::gui::master_read_u32_scalar $master_fd [expr {$hist_csr_base + $control_register_offset}]]
        if {($control_reg & 0x2) == 0} {
            return -code ok
        }
        after 10
    }

    toolkit_send_message warning "histogram_wait_for_cfg_apply: timeout waiting for histogram_statistics_0 commit to settle"
    return -code ok
}

proc ::data_path_bts::gui::histogram_wait_for_flush_complete {master_fd hist_csr_base {timeout_ms 1000}} {
    set bank_status_offset [::data_path_bts::gui::histogram_register_offset "bank_status" 0x24]
    set deadline_ms [expr {[clock milliseconds] + $timeout_ms}]
    after 10
    while {[clock milliseconds] < $deadline_ms} {
        set bank_status [::data_path_bts::gui::master_read_u32_scalar $master_fd [expr {$hist_csr_base + $bank_status_offset}]]
        if {($bank_status & 0x2) == 0} {
            return -code ok
        }
        after 10
    }

    after 20
    return -code ok
}

proc ::data_path_bts::gui::rate_histogram_register_writes {} {
    set preset_spec [::data_path_bts::gui::rate_histogram_preset_spec]
    if {$preset_spec eq "" || ![dict exists $preset_spec field_values]} {
        return [list \
            [list 0x4 0x0] \
            [list 0xc 0x1] \
            [list 0x10 0x28282424] \
            [list 0x14 0x0] \
            [list 0x20 0x07735940] \
            [list 0x0 0x101]]
    }

    set field_values [dict get $preset_spec field_values]
    set metadata [::data_path_bts::gui::histogram_metadata]
    if {$metadata ne "" && [dict exists $metadata contract]} {
        if {![catch {::data_path_bts::gui::register_writes_from_contract [dict get $metadata contract] $field_values "csr.commit"} register_writes]} {
            return $register_writes
        }
        toolkit_send_message warning "rate_histogram_register_writes: falling back to built-in register map because local contract packing failed: $register_writes"
    }

    set control_word [expr { \
        ([::data_path_bts::gui::parse_int_literal [dict get $field_values "csr.commit"] 0x1] & 0x1) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "csr.mode"] 0x0] & 0xf) << 4) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "csr.representation"] 0x1] & 0x1) << 8) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "csr.filter"] 0x0] & 0x3) << 12)}]
    set keys_location_word [expr { \
        ([::data_path_bts::gui::parse_int_literal [dict get $field_values "keys_location.update_key_low"] 0x24] & 0xff) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "keys_location.update_key_high"] 0x28] & 0xff) << 8) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "keys_location.filter_key_low"] 0x24] & 0xff) << 16) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "keys_location.filter_key_high"] 0x28] & 0xff) << 24)}]
    set keys_value_word [expr { \
        ([::data_path_bts::gui::parse_int_literal [dict get $field_values "keys_value.update_key_value"] 0x0] & 0xffff) | \
        (([::data_path_bts::gui::parse_int_literal [dict get $field_values "keys_value.filter_key_value"] 0x0] & 0xffff) << 16)}]

    return [list \
        [list 0x4 [::data_path_bts::gui::parse_int_literal [dict get $field_values "left_bound.left_bound"] 0x0]] \
        [list 0xc [::data_path_bts::gui::parse_int_literal [dict get $field_values "bin_width.bin_width"] 0x1]] \
        [list 0x10 $keys_location_word] \
        [list 0x14 $keys_value_word] \
        [list 0x20 [::data_path_bts::gui::parse_int_literal [dict get $field_values "interval_cfg.interval_clocks"] 0x07735940]] \
        [list 0x0 $control_word]]
}

proc ::data_path_bts::gui::histogram_apply_preset {preset_name hist_csr_base} {
    set master_fd [::mu3e::helpers::cget_opened_master_path]

    switch -- $preset_name {
        rate {
            set register_writes [::data_path_bts::gui::rate_histogram_register_writes]
        }
        default {
            error "unknown histogram preset \"$preset_name\""
        }
    }

    foreach write_spec $register_writes {
        lassign $write_spec register_offset register_value
        master_write_32 $master_fd [expr {$hist_csr_base + $register_offset}] $register_value
    }

    return -code ok
}

proc ::data_path_bts::gui::configure_rate_histogram_preset {} {
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    lassign [::data_path_bts::gui::rate_histogram_instance_info] hist_csr_base hist_bin_base

    ::data_path_bts::gui::histogram_warn_version_mismatch $master_fd $hist_csr_base "histogram_statistics_0"
    ::data_path_bts::gui::histogram_apply_preset rate $hist_csr_base
    ::data_path_bts::gui::histogram_wait_for_cfg_apply $master_fd $hist_csr_base
    master_write_32 $master_fd $hist_bin_base 0x0
    toolkit_send_message info "configure_rate_histogram_preset: histogram_statistics_0 configured for 256-bin channel-rate readout with [::data_path_bts::gui::rate_histogram_sample_interval_ms] ms accumulation"
    return -code ok
}

proc ::data_path_bts::gui::reset_rate_chart {asic_index} {
    set group_name [format "rateHistGroupTab%i" $asic_index]
    set chart_name [format "rateBarChart%i" $asic_index]
    set sample_interval_ms [::data_path_bts::gui::rate_histogram_sample_interval_ms]

    catch {toolkit_set_property $chart_name visible 0}
    catch {toolkit_set_property $chart_name enabled 0}

    toolkit_add             $chart_name     barChart    $group_name
    toolkit_set_property    $chart_name     title       "Channel Rate"
    toolkit_set_property    $chart_name     labelX      "channel ID"
    toolkit_set_property    $chart_name     labelY      [format "counts / %d ms" $sample_interval_ms]
    toolkit_set_property    $chart_name     expandableX true
    toolkit_set_property    $chart_name     preferredWidth 800
}

proc ::data_path_bts::gui::rate_read_once {} {
    set wait_ms [::data_path_bts::gui::rate_histogram_initial_wait_ms]
    ::data_path_bts::gui::configure_rate_histogram_preset
    toolkit_send_message info "rate_read_once: histogram_statistics_0 preset armed, waiting ${wait_ms} ms before readout"
    after $wait_ms
    ::data_path_bts::gui::read_rate 1
    return -code ok
}

proc ::data_path_bts::gui::read_rate {{log_summary 0}} {
    variable fd_global_variable
    set master_fd [::mu3e::helpers::cget_opened_master_path]
    set n_asic [::mu3e::helpers::get_global_variable $fd_global_variable "n_asic"]

    if {[catch {lassign [::data_path_bts::gui::rate_histogram_instance_info] hist_csr_base hist_bin_base} rate_error]} {
        toolkit_send_message error "read_rate: $rate_error"
        return -code error
    }

    if {[catch {master_read_32 $master_fd $hist_bin_base 256} rate_bins]} {
        toolkit_send_message error "read_rate: failed to read histogram_statistics_0 bins: $rate_bins"
        return -code error
    }

    if {[llength $rate_bins] != 256} {
        toolkit_send_message warning "read_rate: expected 256 histogram bins from histogram_statistics_0, got [llength $rate_bins]"
    }

    set nonzero_bins 0
    for {set asic 0} {$asic < $n_asic} {incr asic} {
        set chart_name [format "rateBarChart%i" $asic]
        ::data_path_bts::gui::reset_rate_chart $asic
        for {set channel 0} {$channel < 32} {incr channel} {
            set bin_index [expr {$asic * 32 + $channel}]
            if {$bin_index < [llength $rate_bins]} {
                set rate [format %i [lindex $rate_bins $bin_index]]
            } else {
                set rate 0
            }
            if {$rate != 0} {
                incr nonzero_bins
            }
            toolkit_set_property $chart_name itemValue [list $channel $rate]
        }
    }

    if {$log_summary} {
        toolkit_send_message info "read_rate: loaded [llength $rate_bins] histogram bins from histogram_statistics_0, nonzero bins=$nonzero_bins"
    }

    return -code ok
}





    ################################################
    # garbage
    ################################################


## master -> hex -> gui
#proc ::data_path_bts::gui::read_lvds2 {} {
#    variable fd_global_variable
#    set master_fd [::mu3e::helpers::cget_opened_master_path]
#    #puts "read_lvds: reading..."
#    # gvtable -> base address
#    set lvds_base [::mu3e::helpers::get_global_variable $fd_global_variable "lvds_rx_controller_pro.csr_base_address"]
#    # gvtable -> doc_xml
#    set xml_plain_text [::mu3e::helpers::get_global_variable $fd_global_variable "lvds_doc_xml"]
#    # build dom object
#	dom parse $xml_plain_text doc
#    # parse xml tree of reg map and create gui 
#    foreach i [$doc selectNodes "/registers/register"] {
#        set regValue ""
#        # parse register
#        set regName [[[$i selectNodes "name"] childNodes] nodeValue]
#        set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
#        set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
#        # master -> reg 
#        set regValue [master_read_32 $master_fd [expr ${lvds_base}+${regAddrOfst}] 1]
#        #puts [format "regName: %s regValue: 0x%x" $regName $regValue]
#        set regValueBits [::mu3e::helpers::hex2bin $regValue]
#        #puts "write_lvds: get reg ${regName}, value *init is:${regValue}"
#        #puts [$i selectNodes "fields/field"]
#        foreach j [$i selectNodes "fields/field"] {
#            # parse field 
#            set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
#            set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
#            set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
#            # -- parse the [msb:lsb] format
#            set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
#            set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
#            set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
#            set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
#            #puts "${bitMsb} : ${bitLsb}"
#            #puts "field: raw is ${regValueBits}"
#            set bitBinary [::mu3e::helpers::binary_trim_little_endien $regValueBits $bitLsb $bitMsb]
#            # gui for field
#            # 1) load checkBox for single bit
#            if {$bitLsb == $bitMsb} {
#                toolkit_set_property ${regName}${bitName}_checkBox checked $bitBinary
#            } else {
#                # 2) load comboBox for multiple bit
#                #puts $bitBinary
#                set bitHex [::mu3e::helpers::bin2hex $bitBinary]
#                #puts "bitHex ${bitHex}"
#                toolkit_set_property ${regName}${bitName}_textField text $bitHex
#            }
#        }
#    }
#    return -code ok
#
#}
#
## master <- hex <- gui
#proc ::data_path_bts::gui::write_lvds2 {} {
#    variable fd_global_variable
#    set master_fd [::mu3e::helpers::cget_opened_master_path]
#    #puts "\n write_lvds: writing..."
#    
#    # gvtable -> base address
#    set lvds_base [::mu3e::helpers::get_global_variable $fd_global_variable "lvds_rx_controller_pro.csr_base_address"]
#    # gvtable -> doc_xml
#    set xml_plain_text [::mu3e::helpers::get_global_variable $fd_global_variable "lvds_doc_xml"]
#    # build dom object
#	dom parse $xml_plain_text doc
#    # parse xml tree of reg map and create gui 
#    foreach i [$doc selectNodes "/registers/register"] {
#        set regValue ""
#        # parse register
#        set regName [[[$i selectNodes "name"] childNodes] nodeValue]
#        set regDespt [[[$i selectNodes "description"] childNodes] nodeValue]
#        set regAddrOfst [[[$i selectNodes "addressOffset"] childNodes] nodeValue]
#        # init as "00000......00000" (32 zeros)
#        set regValue [::mu3e::helpers::init_register32_value]
#        #puts "write_lvds: get reg ${regName}, value *init is:${regValue}"
#        #puts [$i selectNodes "fields/field"]
#        foreach j [$i selectNodes "fields/field"] {
#            # parse field 
#            set bitName [[[$j selectNodes "name"] childNodes] nodeValue]
#            set bitRange [[[$j selectNodes "bitRange"] childNodes] nodeValue]
#            set bitAccess [[[$j selectNodes "access"] childNodes] nodeValue]
#            # -- parse the [msb:lsb] format
#            set bitMsb [lindex [regexp -all -inline {(\d)*:} $bitRange] 0]
#            set bitMsb [lindex [regexp -all -inline {(\d)*} $bitMsb] 0]
#            set bitLsb [lindex [regexp -all -inline {:(\d)*} $bitRange] 0]
#            set bitLsb [lindex [regexp -all -inline {(\w)*} $bitLsb] 2]
#            #puts "${bitMsb} : ${bitLsb}"
#            # gui for field
#            # 1) load checkBox for single bit
#            if {$bitLsb == $bitMsb} {
#                set bitValue [toolkit_get_property ${regName}${bitName}_checkBox checked]
#                if {[string equal $bitValue false]} { 
#                    set bitValue 0
#                } else {
#                    set bitValue 1
#                }
#                #string replace $regValue 0 15 1111
#                set regValue [string replace $regValue $bitLsb $bitMsb $bitValue]
#                #puts "write_lvds: field ${bitName}, value ${bitValue}"
#            } else {
##            # 2) load comboBox for multiple bit
#                if {[string equal $bitAccess "read-only"]} {
#                    # read-only: do not write
#                    #puts "write_lvds: field ${bitName} read-only! continue ->"
#                    continue
#                } else {
#                    # writable: value <- textField
#                    set bitLen [expr $bitMsb - $bitLsb + 1]
#                    set trimH [expr int(ceil(${bitLen}/4.0)*4)-1]
#                    set trimL [expr ${bitLen}%4]
#                    #puts "bitLen: ${bitLen} ${trimH} ${trimL}"
#                    set bitsValue [toolkit_get_property ${regName}${bitName}_textField text]
#                    #puts "bitsValue (raw): ${bitsValue}"
#                    set bitsValue [::mu3e::helpers::hex2bin $bitsValue]
#                    #puts "bitsValue (binary): ${bitsValue}"
#                    set bitsValue [::mu3e::helpers::binary_trim $bitsValue ${trimL} ${trimH}]
#                    #puts "bitsValue (trimmed): ${bitsValue}"
#                    set bitsValue [::mu3e::helpers::string_reverse $bitsValue]
#                    set regValue [string replace $regValue $bitLsb $bitMsb $bitsValue]
#                    #puts "write_lvds: field ${bitName}, value ${bitsValue}"   
#                }             
#            }
#        }
#        set regValue [::mu3e::helpers::parse_reverse_bit_stream ${regValue}]
#        #puts "write_lvds: get reg ${regName}, value *after is:${regValue}"
#        # master <- hex
#        #puts [expr ${lvds_base}+${regAddrOfst}]
#        #puts $regValue
#        master_write_32 $master_fd [expr ${lvds_base}+${regAddrOfst}] $regValue
#        
#        #puts "write_lvds: reg ${regName}, value ${}"
#    }
#    toolkit_send_message info "write_lvds: write registers done, byte~"
#    return -code ok
#
#}
