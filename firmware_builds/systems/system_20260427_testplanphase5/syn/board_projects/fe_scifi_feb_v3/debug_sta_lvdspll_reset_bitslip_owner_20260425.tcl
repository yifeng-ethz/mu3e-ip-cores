set outdir "sta_debug_20260425_lvdspll_reset_bitslip_owner"
file mkdir $outdir

project_open -revision top_nostp_pipe top_nostp_pipe
create_timing_netlist -model slow
read_sdc
update_timing_netlist

set lvds_rx_sclk {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk}
set lvds_firefly {lvds_firefly_clk}
set cclk156 {u_feb_system|u_qsys|control_path_subsystem|pll_156t40|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}

report_timing -setup -npaths 50 -detail full_path \
    -to_clock [get_clocks $lvds_rx_sclk] \
    -file "$outdir/setup_to_lvds_rx_sclk_slow85.rpt"

report_timing -setup -npaths 50 -detail full_path \
    -from_clock [get_clocks $lvds_rx_sclk] \
    -to_clock [get_clocks $lvds_rx_sclk] \
    -file "$outdir/setup_lvds_rx_sclk_to_lvds_rx_sclk_slow85.rpt"

report_timing -setup -npaths 30 -detail summary \
    -from_clock [get_clocks $lvds_firefly] \
    -to_clock [get_clocks $lvds_rx_sclk] \
    -file "$outdir/setup_lvds_firefly_to_lvds_rx_sclk_slow85.rpt"

report_timing -setup -npaths 30 -detail summary \
    -from_clock [get_clocks $cclk156] \
    -to_clock [get_clocks $lvds_rx_sclk] \
    -file "$outdir/setup_cclk156_to_lvds_rx_sclk_slow85.rpt"

delete_timing_netlist
project_close
