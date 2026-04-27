package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. board_bring_up_meta.tcl]]
if {![llength [info commands ::fe_scifi::board_bring_up::csr_meta::field]]} {
    source $helper_file
}

namespace eval ::fe_scifi::board_bring_up::csr_meta::mts_processor::v26_0_0402 {}

proc ::fe_scifi::board_bring_up::csr_meta::mts_processor::v26_0_0402::get_metadata {} {
    set registers [list \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "control_and_status" \
            "Control and status registers of MuTRiG Timestamp Processor IP" \
            "0x0" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "go" "Allow hit processing while the run state is RUNNING." {[0:0]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "force_stop" "Force the datapath output to stop in any run state." {[1:1]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "soft_reset" "Soft reset this IP, including counters and in-flight hits." {[2:2]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "bypass_lapse" "Disable lapse correction between MuTRiG and global timestamps for raw coarse-counter debugging." {[3:3]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "discard_hiterr" "Disable the input check on the upstream hiterr signal." {[4:4]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "op_mode" {3-bit operating mode control: bit 2 selects long or short output decode, bit 1 selects whether delay uses T or E timestamp, bit 0 is reserved.} {[30:28]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "discard_hit_counter" \
            "Counter of discarded hits at the input due to hiterr." \
            "0x4" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "discard_hit_count" "Number of discarded hits." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "expected_latency_8ns" \
            "Expected MuTRiG buffering latency in 8 ns units." \
            "0x8" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "expected_latency" "Expected hit latency. Default is 2000 and may need tuning for long-hit mode or sustained link saturation." {[31:0]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "total_hit_cnt_hi" \
            "Upper 16 bits of the total ingress hit counter." \
            "0xc" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "total_hit_cnt_hi" "Upper 16 bits of the total ingress hit counter, including error hits." {[15:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "total_hit_cnt_lo" \
            "Lower 32 bits of the total ingress hit counter." \
            "0x10" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "total_hit_cnt_lo" "Lower 32 bits of the total ingress hit counter, including error hits." {[31:0]} "read-only"]]]]

    return [::fe_scifi::board_bring_up::csr_meta::metadata \
        "1.0.0" \
        "5.4" \
        "26.0.0402" \
        [::fe_scifi::board_bring_up::csr_meta::contract $registers]]
}
