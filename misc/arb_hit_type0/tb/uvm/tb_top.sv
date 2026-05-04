`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import lcg_prng_pkg::*;
  import arb_hit_type0_reg_pkg::*;
  import arb_hit_type0_pkg::*;

  localparam int CLK_PERIOD_NS = 8;

  logic clk;
  logic rst;

  arb_hit_type0_clk_rst_if reset_if(clk, rst);
  arb_hit_type0_hit_if     real_if(clk, rst);
  arb_hit_type0_hit_if     emu_if(clk, rst);
  arb_hit_type0_hit_mon_if egress_if(clk, rst);
  arb_hit_type0_csr_if     csr_if(clk, rst);
  arb_hit_type0_runctl_if  runctl_if(clk, rst);

  arb_hit_type0_env_cfg env_cfg;

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_NS / 2) clk = ~clk;
  end

  initial begin
    real_if.init_source();
    emu_if.init_source();
    csr_if.init_master();
    runctl_if.init_source();
    rst = 1'b1;
    repeat (16) @(posedge clk);
    rst = 1'b0;
  end

  arb_hit_type0 dut (
    .clk                        (clk),
    .rst                        (rst),

    .avs_csr_address            (csr_if.address),
    .avs_csr_write              (csr_if.write),
    .avs_csr_read               (csr_if.read),
    .avs_csr_writedata          (csr_if.writedata),
    .avs_csr_readdata           (csr_if.readdata),
    .avs_csr_waitrequest        (csr_if.waitrequest),

    .asi_ctrl_data              (runctl_if.data),
    .asi_ctrl_valid             (runctl_if.valid),
    .asi_ctrl_ready             (runctl_if.ready),

    .asi_real_data              (real_if.data),
    .asi_real_valid             (real_if.valid),
    .asi_real_error             (real_if.error),
    .asi_real_channel           (real_if.channel),
    .asi_real_startofpacket     (real_if.sop),
    .asi_real_endofpacket       (real_if.eop),
    .asi_real_endofrun          (real_if.eor),

    .asi_emu_data               (emu_if.data),
    .asi_emu_valid              (emu_if.valid),
    .asi_emu_error              (emu_if.error),
    .asi_emu_channel            (emu_if.channel),
    .asi_emu_startofpacket      (emu_if.sop),
    .asi_emu_endofpacket        (emu_if.eop),
    .asi_emu_endofrun           (emu_if.eor),

    .aso_data                   (egress_if.data),
    .aso_valid                  (egress_if.valid),
    .aso_error                  (egress_if.error),
    .aso_channel                (egress_if.channel),
    .aso_startofpacket          (egress_if.sop),
    .aso_endofpacket            (egress_if.eop),
    .aso_endofrun               (egress_if.eor)
  );

  initial begin
    env_cfg = arb_hit_type0_env_cfg::type_id::create("env_cfg");
    env_cfg.reset_vif  = reset_if;
    env_cfg.real_vif   = real_if;
    env_cfg.emu_vif    = emu_if;
    env_cfg.egress_vif = egress_if;
    env_cfg.csr_vif    = csr_if;
    env_cfg.runctl_vif = runctl_if;
    uvm_config_db#(arb_hit_type0_env_cfg)::set(null, "*", "env_cfg", env_cfg);
    run_test();
  end
endmodule
