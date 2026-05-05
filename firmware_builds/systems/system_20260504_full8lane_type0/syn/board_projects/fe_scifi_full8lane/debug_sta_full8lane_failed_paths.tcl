set outdir "sta_debug_full8lane_failed_paths"
file mkdir $outdir

set xcvr_clk {transceiver_pll_clock[0]}
set lvds_rx_sclk {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk}

report_timing -setup -npaths 20 -detail full_path -show_routing \
    -from_clock [get_clocks $xcvr_clk] \
    -to_clock [get_clocks $xcvr_clk] \
    -file "$outdir/setup_xcvr0_same_clock.rpt"

report_timing -setup -npaths 20 -detail full_path -show_routing \
    -from_clock [get_clocks $lvds_rx_sclk] \
    -to_clock [get_clocks $lvds_rx_sclk] \
    -file "$outdir/setup_lvds_rx_sclk_same_clock.rpt"
