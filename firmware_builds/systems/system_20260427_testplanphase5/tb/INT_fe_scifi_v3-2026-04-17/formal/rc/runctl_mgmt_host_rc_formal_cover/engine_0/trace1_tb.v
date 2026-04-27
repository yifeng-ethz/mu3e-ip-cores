`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  runctl_mgmt_host_rc_formal_tb UUT (

  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    UUT.dut.aso_runctl_data = 9'b000000000;
    UUT.dut.aso_runctl_valid = 1'b0;
    UUT.dut.aso_upload_data = 36'b000000000000000000000000000000000000;
    UUT.dut.aso_upload_endofpacket = 1'b1;
    UUT.dut.aso_upload_startofpacket = 1'b0;
    UUT.dut.aso_upload_valid = 1'b0;
    UUT.dut.avs_csr_readdata = 32'b00000000000000000000000000000000;
    UUT.dut.avs_csr_waitrequest = 1'b1;
    UUT.dut.csr_scratch = 32'b00000000000000000000000000000000;
    UUT.dut.csr_state = 2'b00;
    UUT.dut.ct_hard_reset_q = 1'b1;
    UUT.dut.ct_hreset_sync = 2'b00;
    UUT.dut.dp_hard_reset_q = 1'b1;
    UUT.dut.dp_hreset_sync = 2'b00;
    UUT.dut.ev_cmd_accepted = 1'b0;
    UUT.dut.ev_rx_error = 1'b0;
    UUT.dut.ext_hard_reset_q = 1'b0;
    UUT.dut.gts_counter = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.gts_gray_lvds = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.gts_gray_mm_ff0 = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.gts_gray_mm_ff1 = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.gts_h_shadow = 32'b00000000000000000000000000000000;
    UUT.dut.host_exec_ts = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.host_idle_sync = 2'b00;
    UUT.dut.host_state = 8'b00000000;
    UUT.dut.host_state_sync_q0 = 8'b00000000;
    UUT.dut.host_state_sync_q1 = 8'b00000000;
    UUT.dut.local_cmd_ack_lvds = 1'b0;
    UUT.dut.local_cmd_ack_mm_sync = 2'b00;
    UUT.dut.local_cmd_consume_lvds = 1'b0;
    UUT.dut.local_cmd_pending_lvds = 1'b0;
    UUT.dut.local_cmd_req_lvds_seen = 1'b0;
    UUT.dut.local_cmd_req_lvds_sync = 2'b00;
    UUT.dut.local_cmd_req_mm = 1'b0;
    UUT.dut.local_cmd_word_lvds = 32'b00000000000000000000000000000000;
    UUT.dut.local_cmd_word_lvds_sync_q0 = 32'b00000000000000000000000000000000;
    UUT.dut.local_cmd_word_lvds_sync_q1 = 32'b00000000000000000000000000000000;
    UUT.dut.local_cmd_word_mm = 32'b00000000000000000000000000000000;
    UUT.dut.log_fifo_data = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    UUT.dut.log_fifo_rdreq = 1'b1;
    UUT.dut.log_fifo_wrreq = 1'b1;
    UUT.dut.meta_page = 2'b00;
    UUT.dut.pipe_r2h_done = 1'b0;
    UUT.dut.pipe_r2h_start = 1'b0;
    UUT.dut.recv_fpga_address = 16'b0000000000000000;
    UUT.dut.recv_idle_sync = 2'b00;
    UUT.dut.recv_payload32 = 32'b00000000000000000000000000000000;
    UUT.dut.recv_payload_cnt = 4'b0000;
    UUT.dut.recv_payload_len = 4'b0000;
    UUT.dut.recv_reset_assert_mask = 16'b0000000000000000;
    UUT.dut.recv_reset_release_mask = 16'b0000000000000000;
    UUT.dut.recv_run_command = 8'b00000000;
    UUT.dut.recv_run_number = 32'b00000000000000000000000000000000;
    UUT.dut.recv_state = 8'b00000000;
    UUT.dut.recv_state_sync_q0 = 8'b00000000;
    UUT.dut.recv_state_sync_q1 = 8'b00000000;
    UUT.dut.recv_timestamp = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.rst_mask_ct_lvds_sync = 2'b00;
    UUT.dut.rst_mask_ct_mm = 1'b0;
    UUT.dut.rst_mask_dp_lvds_sync = 2'b00;
    UUT.dut.rst_mask_dp_mm = 1'b0;
    UUT.dut.rx_cmd_count_lvds = 32'b00000000000000000000000000000000;
    UUT.dut.rx_cmd_gray_ff0 = 32'b00000000000000000000000000000000;
    UUT.dut.rx_cmd_gray_ff1 = 32'b00000000000000000000000000000000;
    UUT.dut.rx_cmd_gray_lvds = 32'b00000000000000000000000000000000;
    UUT.dut.rx_err_count_lvds = 32'b00000000000000000000000000000000;
    UUT.dut.rx_err_gray_ff0 = 32'b00000000000000000000000000000000;
    UUT.dut.rx_err_gray_ff1 = 32'b00000000000000000000000000000000;
    UUT.dut.rx_err_gray_lvds = 32'b00000000000000000000000000000000;
    UUT.dut.shadow_exec_ts = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.shadow_fpga_addr = 16'b0000000000000000;
    UUT.dut.shadow_fpga_addr_valid = 1'b0;
    UUT.dut.shadow_last_cmd = 8'b00000000;
    UUT.dut.shadow_recv_ts = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.shadow_reset_assert = 16'b0000000000000000;
    UUT.dut.shadow_reset_release = 16'b0000000000000000;
    UUT.dut.shadow_run_number = 32'b00000000000000000000000000000000;
    UUT.dut.snap_exec_ts_lvds = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.snap_fpga_addr_lvds = 16'b0000000000000000;
    UUT.dut.snap_fpga_addr_valid_lvds = 1'b0;
    UUT.dut.snap_last_cmd_lvds = 8'b00000000;
    UUT.dut.snap_recv_ts_lvds = 48'b000000000000000000000000000000000000000000000000;
    UUT.dut.snap_reset_assert_lvds = 16'b0000000000000000;
    UUT.dut.snap_reset_release_lvds = 16'b0000000000000000;
    UUT.dut.snap_run_number_lvds = 32'b00000000000000000000000000000000;
    UUT.dut.snap_update_lvds = 1'b0;
    UUT.dut.snap_update_mm_seen = 1'b0;
    UUT.dut.snap_update_mm_sync = 2'b00;
    UUT.dut.soft_reset_pulse_lvds = 1'b0;
    UUT.dut.soft_reset_req_lvds_seen = 1'b0;
    UUT.dut.soft_reset_req_lvds_sync = 2'b00;
    UUT.dut.soft_reset_req_mm = 1'b0;
    UUT.dut.upload_state = 8'b00000000;
    UUT.f_cycle = 6'b000000;
    UUT.f_past_valid = 1'b0;
    UUT.f_reset_sr = 2'b11;
    UUT.runctl_stall_ctr = 4'b0000;
    UUT.upload_stall_ctr = 4'b0000;
    UUT.noack_cmd = 8'b00110000;
    UUT.stim_kind = 3'b011;
    UUT.error_code = 3'b100;
    UUT.kchar_byte = 8'b00111100;
    UUT.prepare_run_number = 32'b00000000000000000000000000000000;

    // state 0
    UUT.aso_runctl_ready = 1'b1;
    UUT.aso_upload_ready = 1'b1;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.aso_runctl_ready <= 1'b1;
      UUT.aso_upload_ready <= 1'b1;
    end

    // state 2
    if (cycle == 1) begin
      UUT.aso_runctl_ready <= 1'b1;
      UUT.aso_upload_ready <= 1'b1;
    end

    // state 3
    if (cycle == 2) begin
      UUT.aso_runctl_ready <= 1'b1;
      UUT.aso_upload_ready <= 1'b1;
    end

    genclock <= cycle < 3;
    cycle <= cycle + 1;
  end
endmodule
