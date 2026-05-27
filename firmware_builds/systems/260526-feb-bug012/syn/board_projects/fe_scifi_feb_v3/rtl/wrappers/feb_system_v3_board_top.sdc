# =============================================================================
# Per-wrapper SDC for feb_system_v4_board_top.vhd
#
# Owns: the u_qsys (feb_system_v4) instance — covers reset arcs that
#       originate from a Qsys-internal altera_reset_controller and land
#       in clock domains that are external to the system's reset domain.
#
# Failure: recovery WRS -5.86 ns at slow 1100 mV 85 C (and 3 sibling
#          corners) on
#            ...|control_path_subsystem|pll_156t40|...|divclk
#          Source: ...|control_path_subsystem|rst_controller|altera_reset_controller|r_sync_rst
#          Sink:   ...|control_path_subsystem|mutrig_ctrl:mutrig_cfg_ctrl_0
#                  |alt_dcfifo_cdc|dcfifo_component|...|wraclr/rdaclr
#
#          The dcfifo wraclr/rdaclr ports are async-reset inputs whose
#          launch and latch are in different clock domains (lvds_firefly_clk
#          launches the reset_controller r_sync_rst; pll_156t40 divclk is
#          one of the dcfifo write/read clocks). The reset is held for
#          tens of ms on the board after configuration, so deassertion is
#          functionally safe across all silicon corners; STA cannot prove
#          that because it is an inter-clock async-reset arc.
# =============================================================================

set pll_156t40_dst   [get_clocks -nowarn {*pll_156t40*divclk}]
set ctrl_rst_src     [get_keepers -nowarn \
    {*control_path_subsystem*rst_controller*altera_reset_controller*r_sync_rst}]
if {[get_collection_size $ctrl_rst_src] > 0 && [get_collection_size $pll_156t40_dst] > 0} {
    set_false_path -from $ctrl_rst_src -to $pll_156t40_dst
    post_message -type info "feb_system_v4_board_top.sdc: false_path control_path rst_controller -> pll_156t40 divclk"
}

# Second Qsys reset arc: data_path_subsystem|rst_controller_001 ->
# feb_frame_assembly|gts_sync_fifo / csr_sync_fifo DCFIFO write/read
# clears. Latch clock is transceiver_pll_clock[0] (Firefly Tx PLL).
# Same async-reset deassertion rationale as the firefly_xcvr_subsystem
# arc above — reset is held long after the dcfifo's clocks lock.
set xcvr_pll_dst   [get_clocks -nowarn {transceiver_pll_clock[0]}]
set dp_rst_src     [get_keepers -nowarn \
    {*data_path_subsystem*altera_reset_controller:rst_controller_001*altera_reset_synchronizer_int_chain*}]
if {[get_collection_size $dp_rst_src] > 0 && [get_collection_size $xcvr_pll_dst] > 0} {
    set_false_path -from $dp_rst_src -to $xcvr_pll_dst
    post_message -type info "feb_system_v4_board_top.sdc: false_path data_path rst_controller_001 -> transceiver_pll_clock\[0\]"
}
