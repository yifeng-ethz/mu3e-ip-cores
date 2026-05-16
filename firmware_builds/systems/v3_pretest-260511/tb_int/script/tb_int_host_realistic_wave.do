if {![info exists wave_vcd]} {
    set wave_vcd "sim/RC_EMUL_REALISTIC/feb_host_runctl_realistic.vcd"
}

vcd file $wave_vcd

proc tb_int_vcd_add {path} {
    if {[catch {vcd add -r $path} err]} {
        puts "WARN: vcd add skipped $path: $err"
    }
}

tb_int_vcd_add /tb_int_top/clk_125
tb_int_vcd_add /tb_int_top/rst
tb_int_vcd_add /tb_int_top/runctl_phy_vif/*
tb_int_vcd_add /tb_int_top/sc_phy_vif/*

tb_int_vcd_add /tb_int_top/runctl_host_synclink_data
tb_int_vcd_add /tb_int_top/runctl_host_synclink_error
tb_int_vcd_add /tb_int_top/runctl_host_out_valid
tb_int_vcd_add /tb_int_top/runctl_host_out_data
tb_int_vcd_add /tb_int_top/runctl_host_upload_valid
tb_int_vcd_add /tb_int_top/runctl_host_upload_data
tb_int_vcd_add /tb_int_top/runctl_host_csr_read
tb_int_vcd_add /tb_int_top/runctl_host_csr_address
tb_int_vcd_add /tb_int_top/runctl_host_csr_readdata
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/recv_state
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/host_state
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/recv_run_command
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/recv_payload_cnt
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/recv_run_number
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/synclink_idle_armed
tb_int_vcd_add /tb_int_top/u_runctl_mgmt_host/gts_counter

tb_int_vcd_add /tb_int_top/run_control_splitter_out0_valid
tb_int_vcd_add /tb_int_top/run_control_splitter_out0_data
tb_int_vcd_add /tb_int_top/run_control_splitter_out14_valid
tb_int_vcd_add /tb_int_top/run_control_splitter_out14_data
tb_int_vcd_add /tb_int_top/run_control_splitter_out15_valid
tb_int_vcd_add /tb_int_top/run_control_splitter_out15_data
tb_int_vcd_add /tb_int_top/emulator_ctrl_splitter_in_ready
tb_int_vcd_add /tb_int_top/emulator_ctrl_splitter_out0_valid
tb_int_vcd_add /tb_int_top/emulator_ctrl_splitter_out0_data
tb_int_vcd_add /tb_int_top/emulator_ctrl_state_from_splitter
tb_int_vcd_add /tb_int_top/emulator_running_from_splitter
tb_int_vcd_add /tb_int_top/hist_total_hits_shadow

tb_int_vcd_add /tb_int_top/stage_a_vif/*
tb_int_vcd_add /tb_int_top/debug_l2_vif/*
tb_int_vcd_add /tb_int_top/emulator_egress_vif/*
tb_int_vcd_add /tb_int_top/debug_emulator_egress_vif/*
tb_int_vcd_add /tb_int_top/pre_rbcam_vif/*
tb_int_vcd_add /tb_int_top/debug_pre_rbcam_vif/*
tb_int_vcd_add /tb_int_top/post_rbcam_vif/*
tb_int_vcd_add /tb_int_top/debug_post_rbcam_vif/*
tb_int_vcd_add /tb_int_top/feb_egress_vif/*
tb_int_vcd_add /tb_int_top/debug_feb_egress_vif/*
tb_int_vcd_add /tb_int_top/fill_vif/*

tb_int_vcd_add /tb_int_top/wave_model_emulator_commit_to_egress_cycles
tb_int_vcd_add /tb_int_top/wave_model_emulator_egress_to_rbcam_cycles
tb_int_vcd_add /tb_int_top/wave_model_pre_rbcam_delay_cycles
tb_int_vcd_add /tb_int_top/wave_model_post_rbcam_delay_cycles
tb_int_vcd_add /tb_int_top/wave_model_feb_egress_delay_cycles
tb_int_vcd_add /tb_int_top/wave_model_100khz_period_cycles
tb_int_vcd_add /tb_int_top/wave_model_periodic_channel
tb_int_vcd_add /tb_int_top/dec_stage_a_payload_*
tb_int_vcd_add /tb_int_top/dec_emulator_egress_payload_*
tb_int_vcd_add /tb_int_top/dec_pre_rbcam_payload_*
tb_int_vcd_add /tb_int_top/dec_post_rbcam_payload_*
tb_int_vcd_add /tb_int_top/dec_feb_egress_payload_*

tb_int_vcd_add /tb_int_top/hist_fill_valid
tb_int_vcd_add /tb_int_top/hist_fill_ready
tb_int_vcd_add /tb_int_top/hist_fill_data
tb_int_vcd_add /tb_int_top/hist_ext0_valid
tb_int_vcd_add /tb_int_top/hist_ext0_data
tb_int_vcd_add /tb_int_top/hist_ext1_valid
tb_int_vcd_add /tb_int_top/hist_ext1_data
tb_int_vcd_add /tb_int_top/hist_fill_valid_count
tb_int_vcd_add /tb_int_top/hist_fill_accept_count
tb_int_vcd_add /tb_int_top/hist_ext0_valid_count
tb_int_vcd_add /tb_int_top/hist_ext1_valid_count
tb_int_vcd_add /tb_int_top/hist_csr_read
tb_int_vcd_add /tb_int_top/hist_csr_address
tb_int_vcd_add /tb_int_top/hist_csr_readdata

run -all
vcd flush
quit -f
