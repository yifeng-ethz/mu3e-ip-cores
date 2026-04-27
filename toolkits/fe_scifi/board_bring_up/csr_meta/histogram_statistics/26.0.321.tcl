package require Tcl 8.5

set script_dir [file dirname [info script]]
set helper_file [file normalize [file join $script_dir .. board_bring_up_meta.tcl]]
if {![llength [info commands ::fe_scifi::board_bring_up::csr_meta::field]]} {
    source $helper_file
}

namespace eval ::fe_scifi::board_bring_up::csr_meta::histogram_statistics::v26_0_321 {}

proc ::fe_scifi::board_bring_up::csr_meta::histogram_statistics::v26_0_321::get_metadata {} {
    set registers [list \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "csr" \
            "Histogram Statistics v2 control and status register." \
            "0x0" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "commit" "Write 1 to commit the pending histogram settings. Read 0 when the configuration has settled into the live datapath." {[0:0]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "cfg_apply_pending" "1 while a committed configuration is waiting for the ingress path to drain before it becomes active." {[1:1]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "mode" "Histogram operating mode selector." {[7:4]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "representation" "Update-key representation: 0 selects signed extraction, 1 selects unsigned extraction." {[8:8]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "filter" "Filter mode encoded as bits {reject, enable}. 0 disables filtering, 1 keeps matching events, 3 rejects matching events." {[13:12]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "error" "Set when the most recent commit request was rejected by CSR validation." {[24:24]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "error_info" "Validation error code for the last rejected commit. 0x1 indicates invalid bounds while auto-deriving the right bound." {[31:28]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "left_bound" \
            "Lower edge of the histogram range. Signed when representation=0, unsigned when representation=1." \
            "0x4" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "left_bound" "Lower bound applied to the extracted update key before binning." {[31:0]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "right_bound" \
            "Upper edge of the histogram range. When bin_width is non-zero it is derived at commit time from left_bound + N_BINS * bin_width." \
            "0x8" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "right_bound" "Upper bound used for the binning range." {[31:0]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "bin_width" \
            "Width of one histogram bin in update-key units. A zero value enables explicit left/right-bound mode." \
            "0xc" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "bin_width" "Bin width in update-key units." {[15:0]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "keys_location" \
            "Bit positions of the update and filter keys within the snooped data word." \
            "0x10" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "update_key_low" "Least-significant bit of the update key." {[7:0]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "update_key_high" "Most-significant bit of the update key." {[15:8]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "filter_key_low" "Least-significant bit of the filter key." {[23:16]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "filter_key_high" "Most-significant bit of the filter key." {[31:24]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "keys_value" \
            "Literal values compared against the extracted update and filter keys." \
            "0x14" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "update_key_value" "Update-key comparison value used by mode-dependent histogram logic." {[15:0]} "read-write"] \
                [::fe_scifi::board_bring_up::csr_meta::field "filter_key_value" "Filter-key comparison value." {[31:16]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "underflow_counter" \
            "Counts divider underflow events where the extracted key fell below the configured histogram range." \
            "0x18" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "underflow_cnt" "Number of update-key underflow events since the last clear or interval rollover." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "overflow_counter" \
            "Counts divider overflow events where the extracted key exceeded the configured histogram range." \
            "0x1c" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "overflow_cnt" "Number of update-key overflow events since the last clear or interval rollover." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "interval_cfg" \
            "Histogram accumulation interval in clock cycles for ping-pong bank switching." \
            "0x20" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "interval_clocks" "Number of clock cycles per accumulation interval." {[31:0]} "read-write"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "bank_status" \
            "Live ping-pong bank state captured into the CSR clock domain." \
            "0x24" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "active_bank" "Currently active write bank. The host reads the opposite frozen bank while ping-pong mode is enabled." {[0:0]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "flushing" "1 while a histogram bank is being cleared." {[1:1]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "flush_addr" "Bin index currently being cleared." {[15:8]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "port_status" \
            "Ingress FIFO summary per port pair." \
            "0x28" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "fifo_empty_mask" "Bit mask of FIFO-empty status for the eight ingress ports." {[7:0]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "fifo_pair_level_max" "Maximum FIFO fill level observed across the four ingress-port pairs." {[23:16]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "total_hits" \
            "Total accepted histogram-update events accumulated in the current interval." \
            "0x2c" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "total_hits" "Total accepted events." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "dropped_hits" \
            "Total dropped events accumulated in the current interval." \
            "0x30" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "dropped_hits" "Total dropped events." {[31:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "VERSION" \
            {Common CSR identity header packed as MAJOR[31:24], MINOR[23:16], PATCH[15:12], BUILD[11:0].} \
            "0x34" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "major" "Major version." {[31:24]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "minor" "Minor version." {[23:16]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "patch" "Patch version." {[15:12]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "build" "Build number." {[11:0]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "coalescing_status" \
            "Internal coalescing-queue occupancy summary." \
            "0x38" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "queue_occupancy" "Current queue occupancy." {[7:0]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "queue_occupancy_max" "Maximum queue occupancy observed in the current interval." {[15:8]} "read-only"] \
                [::fe_scifi::board_bring_up::csr_meta::field "queue_overflow_count" "Total queue overflow events." {[31:16]} "read-only"]]] \
        [::fe_scifi::board_bring_up::csr_meta::register \
            "scratch" \
            "Free-form scratch register reserved for integration debug." \
            "0x3c" \
            [list \
                [::fe_scifi::board_bring_up::csr_meta::field "scratch" "Scratchpad value." {[31:0]} "read-write"]]]]

    return [::fe_scifi::board_bring_up::csr_meta::metadata \
        "1.0.0" \
        "1.0" \
        "26.0.321" \
        [::fe_scifi::board_bring_up::csr_meta::contract $registers] \
        [::fe_scifi::board_bring_up::csr_meta::runtime_version_check register_name "VERSION"]]
}
