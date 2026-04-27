package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::build_device {} {
    return [::mu3e::cmsis::svd::device MU3E_HISTOGRAM_BIN_WINDOW \
        -version 1.0.0 \
        -description "CMSIS-SVD description of the histogram bin memory aperture. This file intentionally models the bin RAM as a read-only register window so the MF stack can expose it in a standard CMSIS-SVD tree while preserving clear separation from the control/status CSR window." \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral HISTOGRAM_BIN_WINDOW 0x0 \
                -description "Relative 256-word histogram bin aperture." \
                -groupName MU3E_DATA_PATH \
                -addressBlockSize 0x400 \
                -registers [::mu3e::cmsis::svd::word_window_registers 256 \
                    -descriptionPrefix "Histogram bin word" \
                    -fieldDescriptionPrefix "Histogram bin value" \
                    -access read-only]]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir histogram_bin_window.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}
