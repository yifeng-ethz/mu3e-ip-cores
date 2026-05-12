set report_dir "round2_sta"
file mkdir $report_dir

set lvds_pll_sclk {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk}
set lvds_firefly_clk {lvds_firefly_clk}
set transceiver_pll_clock {transceiver_pll_clock[0]}
set clock_targets [list \
    [list transceiver_pll_clock $transceiver_pll_clock] \
    [list lvds_pll_sclk $lvds_pll_sclk] \
    [list lvds_firefly_clk $lvds_firefly_clk] \
]

report_clocks -file [file join $report_dir "round2_clocks.rpt"]
report_clock_transfers -file [file join $report_dir "round2_clock_transfers.rpt"]

foreach target $clock_targets {
    lassign $target label clock_name
    set clocks [get_clocks -nowarn $clock_name]
    if { [get_collection_size $clocks] == 0 } {
        post_message -type error "Round 2 timing script did not find clock: $clock_name"
        continue
    }
    report_timing \
        -setup \
        -to_clock $clocks \
        -npaths 50 \
        -detail full_path \
        -file [file join $report_dir "round2_${label}_setup_paths.rpt"]
    report_timing \
        -hold \
        -to_clock $clocks \
        -npaths 20 \
        -detail summary \
        -file [file join $report_dir "round2_${label}_hold_paths.rpt"]
}
