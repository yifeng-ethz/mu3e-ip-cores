package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. board_bring_up_meta.tcl]]
if {![llength [info commands ::fe_scifi::board_bring_up::csr_meta::field]]} {
    source $helper_file
}

namespace eval ::fe_scifi::board_bring_up::csr_meta::ring_buffer_cam::v26_1_4_0402 {}

proc ::fe_scifi::board_bring_up::csr_meta::ring_buffer_cam::v26_1_4_0402::get_metadata {} {
    set registers [list \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "uid" \
            "Software-visible IP identifier. Default payload is ASCII RBCM (0x5242434D) but is integration-time overridable." \
            "0x0" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "uid" "Compile-time / integration-time overridable IP identifier." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "meta_version" \
            "Read-multiplexed metadata word (page 0). MAJOR\[31:24\], MINOR\[23:16\], PATCH\[15:12\], BUILD\[11:0\]." \
            "0x4" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "version" "Packed version word: MAJOR\[31:24\], MINOR\[23:16\], PATCH\[15:12\], BUILD\[11:0\]. Write 0 to select this page before reading." {[31:0]} "read-only"]] \
            write_before_read "0x0"] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "meta_date" \
            "Read-multiplexed metadata word (page 1). YYYYMMDD provenance date." \
            "0x4" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "date" "YYYYMMDD build-provenance date word. Write 1 to select this page before reading." {[31:0]} "read-only"]] \
            write_before_read "0x1"] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "meta_git" \
            "Read-multiplexed metadata word (page 2). Truncated build git hash." \
            "0x4" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "git" "Truncated build git hash. Write 2 to select this page before reading." {[31:0]} "read-only"]] \
            write_before_read "0x2"] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "meta_instance_id" \
            "Read-multiplexed metadata word (page 3). Integrator-defined instance identifier." \
            "0x4" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "instance_id" "Integrator-defined instance identifier. Write 3 to select this page before reading." {[31:0]} "read-only"]] \
            write_before_read "0x3"] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "control_and_status" \
            "Control and status registers of Ring-Buffer CAM IP." \
            "0x8" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "go" "Allow to accept hits." {[0:0]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "soft_reset" "Running reset request for the ring-buffer CAM." {[1:1]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "filter_inerr" "Filter the ingress error hits with tserr." {[4:4]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "Latency" \
            "Read-pointer delay target in cycles. Reset default is 2000." \
            "0xc" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "expected_latency" "Expected latency value to set in unit of cycles (8 ns)." {[15:0]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "Fill_level_meter" \
            "Live fill-level estimate derived from push, pop, and overwrite counters." \
            "0x10" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "fill_level" "Fill-level counter of current hits inside." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "In-error count" \
            "Count of filtered ingress timestamp-error hits." \
            "0x14" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "inerr_count" "Counter of error=tserr hits." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "push count" \
            "Total accepted push operations." \
            "0x18" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "push_count" "Counter of push-in hits." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "pop count" \
            "Total drained hits." \
            "0x1c" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "pop_count" "Counter of pop-out hits." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "overwrite count" \
            "Total overwrite events." \
            "0x20" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "overwrite_count" "Counter of overwritten hits." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "cache-miss count" \
            "Total cache-miss / empty-search events." \
            "0x24" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "cache_miss_count" "Counter of cache-missed hits." {[31:0]} "read-only"]]]]

    return [::fe_scifi::board_bring_up::csr_meta::metadata \
        "1.0.0" \
        "5.4" \
        "26.1.4.0402" \
        [::fe_scifi::board_bring_up::csr_meta::contract $registers] \
        [::fe_scifi::board_bring_up::csr_meta::runtime_version_check \
            register_name "meta_version" \
            encoding "common_csr_header_v1"]]
}
