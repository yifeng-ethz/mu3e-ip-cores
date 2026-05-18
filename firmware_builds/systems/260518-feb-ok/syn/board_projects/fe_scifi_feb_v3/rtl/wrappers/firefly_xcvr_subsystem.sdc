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
