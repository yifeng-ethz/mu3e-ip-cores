#!/usr/bin/env tclsh
# qsys-script driver: load <scifi.qsys>, map the per-lane frame-deassembly
# CSRs into the data-path debug/SC address windows, save.

package require -exact qsys 16.1

if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}

set qsys_path [lindex $argv 0]

if {![info exists ::env(SYSTEM_DIR)]} {
    puts "ERROR: SYSTEM_DIR is not set; pass --cmd=\"set ::env(SYSTEM_DIR) {/path/to/system}\""
    exit 1
}

set system_dir $::env(SYSTEM_DIR)
set patch [file join $system_dir qsys_tcl patch_scifi_datapath_v4_frame_deassembly_csr.tcl]

proc restore_component_version {path version} {
    set fd [open $path r]
    set text [read $fd]
    close $fd

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

    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
}

puts "APPLY load_system $qsys_path"
load_system $qsys_path
puts "APPLY source $patch"
source $patch
puts "APPLY restore component version $qsys_path"
restore_component_version $qsys_path 26.4.1.0521
puts "APPLY done $qsys_path"
