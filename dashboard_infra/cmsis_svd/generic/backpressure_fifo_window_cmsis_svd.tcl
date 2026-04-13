package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::build_device {} {
    return [::mu3e::cmsis::svd::device MU3E_BACKPRESSURE_FIFO_WINDOW \
        -version 1.0.0 \
        -description "CMSIS-SVD description of the 4-word backpressure FIFO status window used in the SciFi datapath bridge. This is a conservative read-only word-window contract." \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral BACKPRESSURE_FIFO_CSR 0x0 \
                -description "Relative 4-word backpressure FIFO status aperture." \
                -groupName MU3E_DATA_PATH \
                -addressBlockSize 0x10 \
                -registers [::mu3e::cmsis::svd::word_window_registers 4 \
                    -descriptionPrefix "Backpressure FIFO CSR word" \
                    -fieldDescriptionPrefix "Raw backpressure FIFO CSR word" \
                    -access read-only]]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir backpressure_fifo_window.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}
