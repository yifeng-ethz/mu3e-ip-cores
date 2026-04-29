set clocks [list \
    {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk} \
    {lvds_firefly_clk} \
]

foreach clock_name $clocks {
    puts "PHASE5_TIMING_REPORT_BEGIN $clock_name"
    report_timing -setup -npaths 10 -detail full_path -to_clock $clock_name
    puts "PHASE5_TIMING_REPORT_END $clock_name"
}
