# =============================================================================
# Per-wrapper SDC for firefly_xcvr_subsystem.vhd
#
# Owns: reset_sync chain into u_firefly_xcvr|u_reset_156_sync
# Latch clock: transceiver_pll_clock[0] (Firefly Tx PLL refclk pin)
#
# Failure: recovery WRS -3.11 ns at slow 1100 mV 85 C (and 3 sibling
#          corners). Source is the board reset pin coming through
#          rtl/adapters/board_reset_adapter.vhd:u_board_reset|board_reset_n_int
#          and resyncing into the Firefly Tx PLL-fed 156.25 MHz domain.
#
# Rationale: this is an async-reset deassertion path. board_reset is held
# for many ms after power-on by the on-board MAX10 and external reset
# tree, so the FFs in reset_sync see a clean release long after the
# destination clock is stable; STA cannot prove that statically because
# the reset launch clock (spare_clk_osc) is asynchronous to the latch
# (transceiver_pll_clock[0]). False-path the reset arc — functional data
# paths through firefly_xcvr_subsystem remain analyzed since data paths
# do not start at board_reset_n_int.
# =============================================================================

set xcvr_pll_dst [get_clocks -nowarn {transceiver_pll_clock[0]}]
set board_reset  [get_keepers -nowarn {*board_reset_adapter:*|board_reset_n_int}]
if {[get_collection_size $board_reset] > 0 && [get_collection_size $xcvr_pll_dst] > 0} {
    set_false_path -from $board_reset -to $xcvr_pll_dst
    post_message -type info "firefly_xcvr_subsystem.sdc: false_path board_reset -> transceiver_pll_clock\[0\]"
}

# =============================================================================
# Firefly RC-link region: async reset-synchronizer deassertion arcs that the
# fitter analyzes against the lvds_firefly_clk port (the 125 MHz Firefly RX
# refclk pin). These are the only setup violations reported on
# lvds_firefly_clk after the 260518 LVDS-swap build.
#
# Arc 1 (worst, slow 1100 mV 85 C setup WNS -0.925 ns):
#   From: data_path_subsystem|altera_reset_controller:rst_controller_001|
#         altera_reset_synchronizer:alt_rst_sync_uq1|
#         altera_reset_synchronizer_int_chain_out
#   To:   mu3e_lvds_controller_0|...|mu3e_lvds_controller:u_core|
#         data_reset_control_d1
#   Launch clock: mu3e_lvds_controller_0|phy|ALTLVDS_RX_component PLL divclk
#   Latch clock : lvds_firefly_clk (Firefly RX refclk port)
#
# Arc 2 (slow 1100 mV 85 C setup +0.050 ns, marginal pass on a false arc):
#   From: u_qsys|mclk125_reset_sync|altera_reset_controller:mclk125_reset_sync|
#         altera_reset_synchronizer:alt_rst_sync_uq1|
#         altera_reset_synchronizer_int_chain_out
#   To:   control_path_subsystem|...|rst_controller_005|
#         altera_reset_synchronizer_int_chain[*]
#   Launch clock: transceiver_pll_clock[0]
#   Latch clock : lvds_firefly_clk
#
# Root cause: both are async-reset deassertion arcs. data_reset_control_d1 is
# the first flop of a 3-FF reset-deassertion synchronizer
# (data_reset_control_d1/d2/d3, edge-detected by d3 && !d2 in
# mu3e_lvds_controller.sv) and rst_controller_005|...int_chain[*] is the input
# of an Altera reset-synchronizer chain. In both cases the launch register is
# a reset-synchronizer chain output; the launch and latch clocks are
# asynchronous, so STA cannot statically prove the reset-deassertion timing.
# The board reset is held for tens of ms after configuration by the on-board
# MAX10 / external reset tree, so deassertion is seen long after both clocks
# are stable. False-path ONLY these reset-synchronizer arcs.
#
# Functional lvds_firefly_clk intra-clock paths (e.g. master_datapath
# packets_to_master address[*] -> mu3e_lvds_controller avs_csr_readdata[*],
# slow corner setup +0.328 ns) are real and are NOT touched here.
# =============================================================================

set firefly_latch [get_clocks -nowarn {lvds_firefly_clk}]

# Arc 1: data_path rst_controller_001 sync output -> lvds_controller reset-sync FF
set dp_rst_sync_out [get_keepers -nowarn \
    {*data_path_subsystem*altera_reset_controller:rst_controller_001*altera_reset_synchronizer:alt_rst_sync_uq1*altera_reset_synchronizer_int_chain_out}]
set lvds_data_reset_d1 [get_keepers -nowarn \
    {*mu3e_lvds_controller:u_core|data_reset_control_d1}]
if {[get_collection_size $dp_rst_sync_out] > 0 && [get_collection_size $lvds_data_reset_d1] > 0} {
    set_false_path -from $dp_rst_sync_out -to $lvds_data_reset_d1
    post_message -type info "firefly_xcvr_subsystem.sdc: false_path data_path rst_controller_001 sync -> lvds data_reset_control_d1"
}

# Arc 2: mclk125 reset-sync output -> control_path rst_controller_005 sync chain
set mclk125_rst_sync_out [get_keepers -nowarn \
    {*mclk125_reset_sync*altera_reset_synchronizer:alt_rst_sync_uq1*altera_reset_synchronizer_int_chain_out}]
set ctrl_rst005_sync_in [get_keepers -nowarn \
    {*control_path_subsystem*rst_controller_005*altera_reset_synchronizer*altera_reset_synchronizer_int_chain[*]}]
if {[get_collection_size $mclk125_rst_sync_out] > 0 && [get_collection_size $ctrl_rst005_sync_in] > 0} {
    set_false_path -from $mclk125_rst_sync_out -to $ctrl_rst005_sync_in
    post_message -type info "firefly_xcvr_subsystem.sdc: false_path mclk125 rst sync -> control_path rst_controller_005 sync chain"
}
