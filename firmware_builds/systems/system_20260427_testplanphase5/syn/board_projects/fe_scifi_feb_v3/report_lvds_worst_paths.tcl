source [file join [file dirname [info script]] timing_clock_aliases.tcl]

set lvds_clk [mu3e_clock_alias_primary lvds_rx_clock]
set xcvr_clk [mu3e_clock_alias_primary xcvr_tx_clock]

report_timing -npaths 5 -detail full_path \
    -from_clock $lvds_clk \
    -to_clock $lvds_clk

report_timing -npaths 5 -detail full_path \
    -from_clock $xcvr_clk \
    -to_clock $xcvr_clk
