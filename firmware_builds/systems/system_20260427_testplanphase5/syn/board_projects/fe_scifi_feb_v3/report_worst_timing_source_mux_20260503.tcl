project_open top -revision top_nostp_pipe
create_timing_netlist
read_sdc
update_timing_netlist

set report_dir output_files_pipe
file mkdir $report_dir

report_timing \
    -setup \
    -npaths 80 \
    -detail full_path \
    -file "$report_dir/top_nostp_pipe_source_mux_2631_worst_setup_20260503.rpt"

report_timing \
    -hold \
    -npaths 80 \
    -detail full_path \
    -file "$report_dir/top_nostp_pipe_source_mux_2631_worst_hold_20260503.rpt"

report_timing \
    -setup \
    -from_clock {transceiver_pll_clock[0]} \
    -to_clock {transceiver_pll_clock[0]} \
    -npaths 40 \
    -detail full_path \
    -file "$report_dir/top_nostp_pipe_source_mux_2631_xcvr_setup_20260503.rpt"

report_timing \
    -setup \
    -from_clock {lvds_firefly_clk} \
    -to_clock {lvds_firefly_clk} \
    -npaths 40 \
    -detail full_path \
    -file "$report_dir/top_nostp_pipe_source_mux_2631_lvds_firefly_setup_20260503.rpt"

report_timing \
    -hold \
    -from_clock {lvds_firefly_clk} \
    -to_clock {lvds_firefly_clk} \
    -npaths 40 \
    -detail full_path \
    -file "$report_dir/top_nostp_pipe_source_mux_2631_lvds_firefly_hold_20260503.rpt"

report_timing \
    -hold \
    -from_clock {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk} \
    -to_clock {u_feb_system|u_qsys|data_path_subsystem|lvds_rx_28nm_0|ALTLVDS_RX_component|auto_generated|pll_sclk~PLL_OUTPUT_COUNTER|divclk} \
    -npaths 40 \
    -detail full_path \
    -file "$report_dir/top_nostp_pipe_source_mux_2631_pll_sclk_hold_20260503.rpt"

project_close
