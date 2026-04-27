package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::word_registers {} {
    set regs {}

    for {set idx 0} {$idx < 256} {incr idx} {
        set name [format "WORD%03d" $idx]
        set offs [format "0x%03X" [expr {4 * $idx}]]
        lappend regs [::mu3e::cmsis::svd::register $name $offs \
            -description [format {Scratchpad RAM word %d.} $idx] \
            -access read-write \
            -fields [list \
                [::mu3e::cmsis::svd::field value 0 32 \
                    -description [format {Raw scratchpad word %d.} $idx] \
                    -access read-write]]]
    }

    return $regs
}

proc ::mu3e::cmsis::spec::build_device {} {
    return [::mu3e::cmsis::svd::device MU3E_SCRATCH_PAD_RAM \
        -version 1.0.0 \
        -description {CMSIS-SVD description of the generic 256-word scratchpad RAM slave window used by Mu3e FEB control paths. BaseAddress is 0 because this file describes the relative window; system integration supplies the live slave base address.} \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral SCRATCH_PAD_RAM 0x0 \
                -description {Relative 256-word read/write scratchpad aperture.} \
                -groupName MU3E_GENERIC \
                -addressBlockSize 0x400 \
                -registers [::mu3e::cmsis::spec::word_registers]]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir scratch_pad_ram.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}
