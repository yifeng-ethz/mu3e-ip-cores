set outdir "sta_debug_20260425_runctl265"
file mkdir $outdir

set lvds_rx_sclk {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk}
set lvds_firefly {lvds_firefly_clk}

report_timing -setup -npaths 20 -detail full_path -to_clock [get_clocks $lvds_rx_sclk] -file "$outdir/setup_lvds_rx_sclk_slow85.rpt"
report_timing -recovery -npaths 20 -detail full_path -to_clock [get_clocks $lvds_firefly] -file "$outdir/recovery_lvds_firefly_slow85.rpt"
