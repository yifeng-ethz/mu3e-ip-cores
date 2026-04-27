# runctl_mgmt_host.sdc
#
# CDC timing intent for the dual-clock run-control management host between:
# - mm_clk      (Avalon-MM CSR domain)
# - lvdspll_clk (synclink / runctl / upload domain)
#
# Important:
# 1. Do not globally false-path mm_clk and lvdspll_clk for the whole system.
# 2. These constraints target only the explicit CDC structures inside
#    runctl_mgmt_host and silently skip when the expected node names are absent.

proc rcmh_get_registers_any {patterns} {
    set nodes [get_registers -nowarn __rcmh_no_match__]
    foreach pattern $patterns {
        set matches [get_registers -nowarn $pattern]
        if {[get_collection_size $matches] > 0} {
            set nodes [add_to_collection $nodes $matches]
        }
    }
    return $nodes
}

proc rcmh_node_patterns {leaf_name} {
    return [list \
        "runctl_mgmt_host:*|$leaf_name" \
        "*runctl_mgmt_host*|$leaf_name"]
}

proc rcmh_state_patterns {state_name} {
    return [list \
        "runctl_mgmt_host:*|$state_name" \
        "*runctl_mgmt_host*|$state_name"]
}

proc rcmh_apply_false_path_pair {from_nodes to_nodes} {
    if {[get_collection_size $from_nodes] > 0 && [get_collection_size $to_nodes] > 0} {
        set_false_path -from $from_nodes -to $to_nodes
    }
}

proc constrain_rcmh_mm_to_lvds_cdc {} {
    # CSR-driven toggle/data/mask controls are sampled in the lvds domain only
    # through explicit synchronizer chains or held-stable shadow buses.
    set local_cmd_word_src  [rcmh_get_registers_any [concat \
        [rcmh_node_patterns {local_cmd_word_mm[*]}] \
        [rcmh_node_patterns {local_cmd_hold_word_mm[*]}]]]
    set local_cmd_word_meta [rcmh_get_registers_any [rcmh_node_patterns {local_cmd_word_lvds_sync_q0[*]}]]
    set local_cmd_req_src   [rcmh_get_registers_any [rcmh_node_patterns {local_cmd_req_mm}]]
    set local_cmd_req_meta  [rcmh_get_registers_any [rcmh_node_patterns {local_cmd_req_lvds_sync[*]}]]
    set soft_reset_src      [rcmh_get_registers_any [rcmh_node_patterns {soft_reset_req_mm}]]
    set soft_reset_meta     [rcmh_get_registers_any [rcmh_node_patterns {soft_reset_req_lvds_sync[*]}]]
    set rst_mask_dp_src     [rcmh_get_registers_any [rcmh_node_patterns {rst_mask_dp_mm}]]
    set rst_mask_dp_meta    [rcmh_get_registers_any [rcmh_node_patterns {rst_mask_dp_lvds_sync[*]}]]
    set rst_mask_ct_src     [rcmh_get_registers_any [rcmh_node_patterns {rst_mask_ct_mm}]]
    set rst_mask_ct_meta    [rcmh_get_registers_any [rcmh_node_patterns {rst_mask_ct_lvds_sync[*]}]]

    rcmh_apply_false_path_pair $local_cmd_word_src $local_cmd_word_meta
    rcmh_apply_false_path_pair $local_cmd_req_src  $local_cmd_req_meta
    rcmh_apply_false_path_pair $soft_reset_src     $soft_reset_meta
    rcmh_apply_false_path_pair $rst_mask_dp_src    $rst_mask_dp_meta
    rcmh_apply_false_path_pair $rst_mask_ct_src    $rst_mask_ct_meta
}

proc constrain_rcmh_lvds_to_mm_cdc {} {
    # lvds-side toggles, snapshot banks, gray counters, and status mirrors are
    # sampled in mm_clk only after explicit toggle/2FF synchronization.
    set local_cmd_ack_src        [rcmh_get_registers_any [rcmh_node_patterns {local_cmd_ack_lvds}]]
    set local_cmd_ack_meta       [rcmh_get_registers_any [rcmh_node_patterns {local_cmd_ack_mm_sync[*]}]]
    set snap_update_src          [rcmh_get_registers_any [rcmh_node_patterns {snap_update_lvds}]]
    set snap_update_meta         [rcmh_get_registers_any [rcmh_node_patterns {snap_update_mm_sync[*]}]]

    set snap_last_cmd_src        [rcmh_get_registers_any [rcmh_node_patterns {snap_last_cmd_lvds[*]}]]
    set snap_last_cmd_dst        [rcmh_get_registers_any [rcmh_node_patterns {shadow_last_cmd[*]}]]
    set snap_run_number_src      [rcmh_get_registers_any [rcmh_node_patterns {snap_run_number_lvds[*]}]]
    set snap_run_number_dst      [rcmh_get_registers_any [rcmh_node_patterns {shadow_run_number[*]}]]
    set snap_reset_assert_src    [rcmh_get_registers_any [rcmh_node_patterns {snap_reset_assert_lvds[*]}]]
    set snap_reset_assert_dst    [rcmh_get_registers_any [rcmh_node_patterns {shadow_reset_assert[*]}]]
    set snap_reset_release_src   [rcmh_get_registers_any [rcmh_node_patterns {snap_reset_release_lvds[*]}]]
    set snap_reset_release_dst   [rcmh_get_registers_any [rcmh_node_patterns {shadow_reset_release[*]}]]
    set snap_fpga_addr_src       [rcmh_get_registers_any [rcmh_node_patterns {snap_fpga_addr_lvds[*]}]]
    set snap_fpga_addr_dst       [rcmh_get_registers_any [rcmh_node_patterns {shadow_fpga_addr[*]}]]
    set snap_fpga_addr_valid_src [rcmh_get_registers_any [rcmh_node_patterns {snap_fpga_addr_valid_lvds}]]
    set snap_fpga_addr_valid_dst [rcmh_get_registers_any [rcmh_node_patterns {shadow_fpga_addr_valid}]]
    set snap_recv_ts_src         [rcmh_get_registers_any [rcmh_node_patterns {snap_recv_ts_lvds[*]}]]
    set snap_recv_ts_dst         [rcmh_get_registers_any [rcmh_node_patterns {shadow_recv_ts[*]}]]
    set snap_exec_ts_src         [rcmh_get_registers_any [rcmh_node_patterns {snap_exec_ts_lvds[*]}]]
    set snap_exec_ts_dst         [rcmh_get_registers_any [rcmh_node_patterns {shadow_exec_ts[*]}]]

    set gts_gray_src             [rcmh_get_registers_any [rcmh_node_patterns {gts_gray_lvds[*]}]]
    set gts_gray_meta            [rcmh_get_registers_any [rcmh_node_patterns {gts_gray_mm_ff0[*]}]]
    set rx_cmd_gray_src          [rcmh_get_registers_any [rcmh_node_patterns {rx_cmd_gray_lvds[*]}]]
    set rx_cmd_gray_meta         [rcmh_get_registers_any [rcmh_node_patterns {rx_cmd_gray_ff0[*]}]]
    set rx_err_gray_src          [rcmh_get_registers_any [rcmh_node_patterns {rx_err_gray_lvds[*]}]]
    set rx_err_gray_meta         [rcmh_get_registers_any [rcmh_node_patterns {rx_err_gray_ff0[*]}]]
    set log_drop_gray_src        [rcmh_get_registers_any [rcmh_node_patterns {log_drop_gray_lvds[*]}]]
    set log_drop_gray_meta       [rcmh_get_registers_any [rcmh_node_patterns {log_drop_gray_ff0[*]}]]

    set recv_state_src           [rcmh_get_registers_any [rcmh_state_patterns {recv_state.*}]]
    set recv_state_meta          [rcmh_get_registers_any [rcmh_node_patterns {recv_state_sync_q0[*]}]]
    set host_state_src           [rcmh_get_registers_any [rcmh_state_patterns {host_state.*}]]
    set host_state_meta          [rcmh_get_registers_any [rcmh_node_patterns {host_state_sync_q0[*]}]]
    set recv_idle_meta           [rcmh_get_registers_any [rcmh_node_patterns {recv_idle_sync[*]}]]
    set host_idle_meta           [rcmh_get_registers_any [rcmh_node_patterns {host_idle_sync[*]}]]
    set dp_hreset_src            [rcmh_get_registers_any [rcmh_node_patterns {dp_hard_reset_q}]]
    set dp_hreset_meta           [rcmh_get_registers_any [rcmh_node_patterns {dp_hreset_sync[*]}]]
    set ct_hreset_src            [rcmh_get_registers_any [rcmh_node_patterns {ct_hard_reset_q}]]
    set ct_hreset_meta           [rcmh_get_registers_any [rcmh_node_patterns {ct_hreset_sync[*]}]]

    rcmh_apply_false_path_pair $local_cmd_ack_src        $local_cmd_ack_meta
    rcmh_apply_false_path_pair $snap_update_src          $snap_update_meta
    rcmh_apply_false_path_pair $snap_last_cmd_src        $snap_last_cmd_dst
    rcmh_apply_false_path_pair $snap_run_number_src      $snap_run_number_dst
    rcmh_apply_false_path_pair $snap_reset_assert_src    $snap_reset_assert_dst
    rcmh_apply_false_path_pair $snap_reset_release_src   $snap_reset_release_dst
    rcmh_apply_false_path_pair $snap_fpga_addr_src       $snap_fpga_addr_dst
    rcmh_apply_false_path_pair $snap_fpga_addr_valid_src $snap_fpga_addr_valid_dst
    rcmh_apply_false_path_pair $snap_recv_ts_src         $snap_recv_ts_dst
    rcmh_apply_false_path_pair $snap_exec_ts_src         $snap_exec_ts_dst
    rcmh_apply_false_path_pair $gts_gray_src             $gts_gray_meta
    rcmh_apply_false_path_pair $rx_cmd_gray_src          $rx_cmd_gray_meta
    rcmh_apply_false_path_pair $rx_err_gray_src          $rx_err_gray_meta
    rcmh_apply_false_path_pair $log_drop_gray_src        $log_drop_gray_meta
    rcmh_apply_false_path_pair $recv_state_src           $recv_state_meta
    rcmh_apply_false_path_pair $recv_state_src           $recv_idle_meta
    rcmh_apply_false_path_pair $host_state_src           $host_state_meta
    rcmh_apply_false_path_pair $host_state_src           $host_idle_meta
    rcmh_apply_false_path_pair $dp_hreset_src            $dp_hreset_meta
    rcmh_apply_false_path_pair $ct_hreset_src            $ct_hreset_meta
}

constrain_rcmh_mm_to_lvds_cdc
constrain_rcmh_lvds_to_mm_cdc
