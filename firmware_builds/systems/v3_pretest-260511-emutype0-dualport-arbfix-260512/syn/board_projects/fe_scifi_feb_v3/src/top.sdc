#

# false path for signaltap
set signaltap_cells [get_cells -hierarchical -nowarn *sld_signaltap*]
if { [get_collection_size $signaltap_cells] > 0 } {
    set_false_path -to $signaltap_cells
}

# false path for lvds controller, TODO: remove it by adding CDC
set_false_path -from {*lvds_rx_controller_pro*|assembler_symbol_errors*} -to {*lvds_rx_controller_pro*|csr.symbol_errors*}

# false path for reset
set top_reset_from [get_keepers -nowarn {feb_system:q_feb_system|altera_reset_controller:rst_controller_001|altera_reset_synchronizer:alt_rst_sync_uq1|altera_reset_synchronizer_int_chain_out}]
set top_reset_to   [get_keepers -nowarn {feb_system:q_feb_system|feb_system_data_path_subsystem:data_path_subsystem|feb_system_data_path_subsystem_rst_controller_003:rst_controller_003|altera_reset_controller:rst_controller_003|altera_reset_synchronizer:alt_rst_sync_uq1|altera_reset_synchronizer_int_chain[*]}]
if { [get_collection_size $top_reset_from] > 0 && [get_collection_size $top_reset_to] > 0 } {
    set_false_path -from $top_reset_from -to $top_reset_to
}

#set_false_path -from {*} -to {scifi_path:e_scifi_path|miso_156}

## false path for sorter
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|noverflow*} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|noverflow*};
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|noutoftime*} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|noutoftime*};
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|nout*} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|nout*};
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|credits*} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|credit*};
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|nintime*} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|nintime*};
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|o_sorter_delay*} -to {*}
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_debug[*]} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|hitsorter:\gen_sorter_path:*:scifi_sorter|sorter_reg_mapping:e_sorter_reg_mapping|o_reg_rdata[*]};
#
## false path for slow-control
#set_false_path -from {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|scifi_receiver_block:u_rxdeser|data_decoder:\gen_channels:*:e_data_decoder|ready_buf} -to {scifi_path:e_scifi_path|scifi_datapath:e_mutrig_datapath|scifi_receiver_block:u_rxdeser|o_SC_mutrig.receivers_ready[*]};
#set_false_path -from {reset_sync:e_reset_125_n|o_reset_n} -to {*clkdiv:*|clk2};

# false path: sc_hub AVMM handler → Qsys interconnect → sc_hub_core ext_write_diag
# The hub's AVMM master transaction launch creates a combinational path through the
# interconnect address-decode fabric back to the hub core's diagnostic registers.
# ext_write_diag capture depends only on core_state and i_bus_wr_data_ready (both
# registered internal signals), so this interconnect loopback path is not functional.
set hub_avmm_src [get_keepers -nowarn {*sc_hub*avmm_handler*avmm_state*}]
set hub_diag_dst [get_keepers -nowarn {*sc_hub*core_inst*ext_write_diag_data_hold*}]
if { [get_collection_size $hub_avmm_src] > 0 && [get_collection_size $hub_diag_dst] > 0 } {
    set_false_path -from $hub_avmm_src -to $hub_diag_dst
}
set hub_xlat_src [get_keepers -nowarn {*mm_interconnect_0*sc_hub_hub_translator*address_register*}]
if { [get_collection_size $hub_xlat_src] > 0 && [get_collection_size $hub_diag_dst] > 0 } {
    set_false_path -from $hub_xlat_src -to $hub_diag_dst
}

# false path: control_path_subsystem rst_controller_001 r_sync_rst fanout
#
# `r_sync_rst` is the final register in the Altera reset controller's
# synchronizer chain. Its Q output feeds only async-clear pins on downstream
# consumers — it is not wired to any data path. The synchronizer upstream of
# r_sync_rst guarantees metastability resolution on deassertion, so recovery
# timing on the long-route deassertion arc to each consumer's aclr pin is not
# functionally required.
#
# Without this constraint, Quartus flags ~3 ns of recovery violation on
# high-fanout destinations such as max10_prog_avmm, data_sc_merger.outpipe,
# mm_interconnect_0 agent pipeline stages, and firefly_xcvr_ctrl i2c state.
set rst_ctrl_src [get_keepers -nowarn {*control_path_subsystem*rst_controller_001*rst_controller_001*r_sync_rst}]
if { [get_collection_size $rst_ctrl_src] > 0 } {
    set_false_path -from $rst_ctrl_src
}

# multicycle path: merlin master limiter handshake inside sc_hub_cmd_pipe
# Platform Designer wraps every Avalon-MM master in a translator+limiter pair
# before the router. The limiter's `end_begintransfer` pulse travels through
# the router's address-decode combinational cone back to the translator's
# `address_register` D input. With the sc_hub_cmd_pipe bridge inserted, this
# intra-translator feedback path is 6 logic levels long and misses setup by
# -0.030 ns on the slow 85C corner at 156.25 MHz.
#
# The SC control plane issues commands at a tiny fraction of the clock rate
# (rate-limited by the SWB downlink), so the limiter sees at most one command
# accepted per dozens of cycles. A 2-cycle multicycle on this register-to-
# register path is trivially safe: the limiter simply accepts the next command
# one cycle later than the combinational lookahead would allow.
set cmdpipe_begintransfer [get_keepers -nowarn {*control_path_subsystem*sc_hub_cmd_pipe_m0_translator*end_begintransfer*}]
set cmdpipe_addr_register [get_keepers -nowarn {*control_path_subsystem*sc_hub_cmd_pipe_m0_translator*address_register*}]
if { [get_collection_size $cmdpipe_begintransfer] > 0 && [get_collection_size $cmdpipe_addr_register] > 0 } {
    set_multicycle_path -setup -end 2 -from $cmdpipe_begintransfer -to $cmdpipe_addr_register
    set_multicycle_path -hold  -end 1 -from $cmdpipe_begintransfer -to $cmdpipe_addr_register
}

# TODO: remove below
#set_false_path -from [get_keepers {feb_system:q_feb_system|feb_system_data_path_subsystem:data_path_subsystem|feb_system_data_path_subsystem_lvds_rx_controller_pro_0:lvds_rx_controller_pro_0|csr.soft_reset_req[0]}] -to [get_keepers {feb_system:q_feb_system|feb_system_data_path_subsystem:data_path_subsystem|feb_system_data_path_subsystem_lvds_rx_controller_pro_0:lvds_rx_controller_pro_0|bit_sliper_sync_cnt[8][2]}]
