# FEB_common false paths
# M. Mueller, September 2020

proc feb_common_set_false_path_if_present {from_pattern to_pattern} {
    set from_nodes [get_keepers -nowarn $from_pattern]
    set to_nodes   [get_keepers -nowarn $to_pattern]
    if { [get_collection_size $from_nodes] > 0 && [get_collection_size $to_nodes] > 0 } {
        set_false_path -from $from_nodes -to $to_nodes
    }
}

proc feb_common_set_false_path_from_if_present {from_pattern} {
    set from_nodes [get_keepers -nowarn $from_pattern]
    if { [get_collection_size $from_nodes] > 0 } {
        set_false_path -from $from_nodes -to *
    }
}

# idk why this is required, sync chain is not recognised
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|data_merger:e_merger|terminated[0]} {fe_block_v2:e_fe_block|resetsys:e_reset_system|ff_sync:i_ff_sync|ff[0][0]}

# buttons
feb_common_set_false_path_from_if_present {debouncer:db1|o_q[0]}
feb_common_set_false_path_from_if_present {debouncer:db2|o_q[0]}

# Max10 adc
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|adc_reg*} {fe_block_v2:e_fe_block|feb_reg_mapping:e_reg_mapping|adc_reg*}

# single bits only (program req and fifo aclr)
feb_common_set_false_path_from_if_present {fe_block_v2:e_fe_block|feb_reg_mapping:e_reg_mapping|o_programming_ctrl*}

# other stuff
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|max10_status*} {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|o_max10_status*}
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|max10_version*} {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|o_max10_version*}
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|programming_status*} {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|o_programming_status*}
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|feb_reg_mapping:e_reg_mapping|o_programming_addr_ena} {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|programming_addr_ena_reg}
feb_common_set_false_path_if_present {fe_block_v2:e_fe_block|feb_reg_mapping:e_reg_mapping|o_programming_addr*} {fe_block_v2:e_fe_block|max10_interface:e_max10_interface|max_spi_data_to_max*}

set programming_status_nodes [get_keepers -nowarn {*max10_interface|o_programming_status*}]
if { [get_collection_size $programming_status_nodes] > 0 } {
    set_false_path -from {*} -to $programming_status_nodes
}

# int run emergeny REMOVE THIS AGAIN
# no need for the nios to be able to read somehting ever (mupix feb only, do not merge !!!)
#set_false_path -from {fe_block_v2:e_fe_block|nios:e_nios*} -to {*_reg_mapping|o_reg_rdata*}

foreach e [ get_entity_instances -nowarn "firefly" ] {
    set to_regs [ get_registers -nocase "$e|*firefly_reg_mapping*|*" ]
    set from_regs [ get_registers -nocase "$e|*" ]
    set from_regs [ remove_from_collection $from_regs $to_regs ]
    set_false_path -from $from_regs -to $to_regs

}

# Firefly recovered-clock RX lanes now cross into i_clk_156 only through the
# explicit async FIFOs in generate_sync_xcvr1_rx. Cut only the FIFO pointer
# synchronizer paths; keep the in-lane timing fully constrained.
set firefly_fifo_rdptr [ get_registers -nowarn *firefly*sync_xcvr1_rx*rdptr_g* ]
set firefly_fifo_ws    [ get_registers -nowarn *firefly*sync_xcvr1_rx*ws_dgrp*dffpipe* ]
if { [ get_collection_size $firefly_fifo_rdptr ] > 0 && [ get_collection_size $firefly_fifo_ws ] > 0 } {
    set_false_path -from $firefly_fifo_rdptr -to $firefly_fifo_ws
}

set firefly_fifo_wrptr [ get_registers -nowarn *firefly*sync_xcvr1_rx*delayed_wrptr_g* ]
set firefly_fifo_rs    [ get_registers -nowarn *firefly*sync_xcvr1_rx*rs_dgwp*dffpipe* ]
if { [ get_collection_size $firefly_fifo_wrptr ] > 0 && [ get_collection_size $firefly_fifo_rs ] > 0 } {
    set_false_path -from $firefly_fifo_wrptr -to $firefly_fifo_rs
}
