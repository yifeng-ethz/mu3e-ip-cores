package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. toolkits infra cmsis_svd lib mu3e_cmsis_svd.tcl]]
source $helper_file

namespace eval ::mu3e::cmsis::spec {}

proc ::mu3e::cmsis::spec::build_device {} {
    set registers [list \
        [::mu3e::cmsis::svd::register UID 0x0 \
            -description "Software-visible IP identifier. Replace this template text with the author-owned CSR contract." \
            -access read-only \
            -fields [list \
                [::mu3e::cmsis::svd::field value 0 32 \
                    -description "Replace with the real UID field description." \
                    -access read-only]]] \
        [::mu3e::cmsis::svd::register META 0x4 \
            -description "Standard Mu3e metadata mux word. Replace page semantics and reset values with the real contract." \
            -access read-write \
            -fields [list \
                [::mu3e::cmsis::svd::field page_sel 0 2 \
                    -description "0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID by convention." \
                    -access read-write] \
                [::mu3e::cmsis::svd::field reserved 2 30 \
                    -description "Reserved, read as zero unless the IP defines otherwise." \
                    -access read-only]]]]

    return [::mu3e::cmsis::svd::device MU3E_IP_TEMPLATE \
        -version 0.0.0 \
        -description "Author-owned CMSIS-SVD template for a Mu3e FPGA IP CSR window. Keep this Tcl file as the editable source and regenerate the .svd XML after every register-map change." \
        -peripherals [list \
            [::mu3e::cmsis::svd::peripheral IP_TEMPLATE 0x0 \
                -description "Relative CSR window. The system integrator supplies the actual slave base address." \
                -groupName MU3E_IP_TEMPLATE \
                -addressBlockSize 0x8 \
                -registers $registers]]]
}

if {[info exists ::argv0] &&
    [file normalize $::argv0] eq [file normalize [info script]]} {
    set out_path [file join $script_dir ip_template.svd]
    if {[llength $::argv] >= 1} {
        set out_path [lindex $::argv 0]
    }
    ::mu3e::cmsis::svd::write_device_file \
        [::mu3e::cmsis::spec::build_device] $out_path
}
