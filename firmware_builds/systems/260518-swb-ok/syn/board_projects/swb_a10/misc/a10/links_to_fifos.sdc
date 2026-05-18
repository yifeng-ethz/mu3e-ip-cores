#

#set_min_delay -from {a10_block:e_a10_block|reset_logic:e_reset_logic_pcie|o_resets_n[22]} -to {swb_block:e_swb_block|swb_data_path:*} -100
#set_max_delay -from {a10_block:e_a10_block|reset_logic:e_reset_logic_pcie|o_resets_n[22]} -to {swb_block:e_swb_block|swb_data_path:*} 100
#set_false_path -from {a10_block:e_a10_block|pcie_block:\generate_pcie0:e_pcie0_block|pcie_application:e_pcie_application|pcie_writeable_registers:e_pcie_writeable_registers|writeregs_r[*][*]} -to {swb_block:e_swb_block|swb_data_path:\generate_generic_path:e_swb_data_path_generic|links_to_fifos:e_links_to_fifos|*};
