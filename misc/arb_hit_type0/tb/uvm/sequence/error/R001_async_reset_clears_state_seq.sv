`ifndef ARB_HIT_TYPE0_ERROR_IN_PKG
import uvm_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`endif

class R_error_base_seq extends arb_hit_type0_base_vseq;
  `uvm_object_utils(R_error_base_seq)

  arb_hit_type0_env_cfg cfg_h;
  lcg_prng_state_t      prng_h;

  function new(string name = "R_error_base_seq");
    super.new(name);
  endfunction

  task pre_body();
    super.pre_body();
    if (!uvm_config_db#(arb_hit_type0_env_cfg)::get(null, "*", "env_cfg", cfg_h)) begin
      `uvm_fatal(get_type_name(), "missing env_cfg")
    end
    prng_h = lcg_init(cfg_h.seed);
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) begin
      @(cfg_h.reset_vif.mon_cb);
    end
  endtask

  task automatic pulse_hard_reset(input int unsigned cycles = 4);
    if (!uvm_hdl_force("tb_top.rst", 1'b1)) begin
      `uvm_error(get_type_name(), "failed to force tb_top.rst")
    end
    wait_cycles(cycles);
    if (!uvm_hdl_force("tb_top.rst", 1'b0)) begin
      `uvm_error(get_type_name(), "failed to drive tb_top.rst low")
    end
    wait_cycles(2);
    if (!uvm_hdl_release("tb_top.rst")) begin
      `uvm_error(get_type_name(), "failed to release tb_top.rst")
    end
    wait_cycles(6);
  endtask

  task automatic drive_hit(
    input arb_source_e source,
    input bit [44:0]  data,
    input bit [2:0]   error,
    input bit [3:0]   channel,
    input bit         sop,
    input bit         eop,
    input bit         eor,
    input int unsigned idle_cycles = 0
  );
    hit_type0_seq_item item_h;

    item_h             = hit_type0_seq_item::type_id::create("error_hit");
    item_h.data        = data;
    item_h.error       = error;
    item_h.channel     = channel;
    item_h.sop         = sop;
    item_h.eop         = eop;
    item_h.eor         = eor;
    item_h.valid       = 1'b1;
    item_h.idle_cycles = idle_cycles;
    item_h.source_emu  = (source == ARB_SRC_EMU);

    if (source == ARB_SRC_EMU) begin
      start_item(item_h, -1, vseqr.emu_seqr);
    end else begin
      start_item(item_h, -1, vseqr.real_seqr);
    end
    finish_item(item_h);
  endtask

  task automatic drive_packet(
    input arb_source_e source,
    input int unsigned beats,
    input bit [44:0]  base_data,
    input bit [2:0]   error,
    input bit [3:0]   channel,
    input bit         eor_last = 1'b0
  );
    int unsigned idx;

    for (idx = 0; idx < beats; idx++) begin
      drive_hit(
        source,
        base_data + idx,
        error,
        channel,
        (idx == 0),
        (idx == (beats - 1)),
        eor_last && (idx == (beats - 1))
      );
    end
  endtask

  task automatic expect32(input string label, input bit [31:0] actual, input bit [31:0] expected);
    if (actual !== expected) begin
      `uvm_error(get_type_name(), $sformatf("%s expected=0x%08h observed=0x%08h", label, expected, actual))
    end
  endtask

  task automatic expect64(input string label, input bit [63:0] actual, input bit [63:0] expected);
    if (actual !== expected) begin
      `uvm_error(get_type_name(), $sformatf("%s expected=0x%016h observed=0x%016h", label, expected, actual))
    end
  endtask

  task automatic expect_status_mask(input bit [31:0] mask, input bit [31:0] expected);
    bit [31:0] status_v;

    csr_read(ARB_REG_STATUS_ADDR, status_v);
    if ((status_v & mask) !== (expected & mask)) begin
      `uvm_error(
        get_type_name(),
        $sformatf("STATUS mask=0x%08h expected=0x%08h observed=0x%08h", mask, expected & mask, status_v & mask)
      )
    end
  endtask

  task automatic expect_csr32(input bit [4:0] address, input bit [31:0] expected, input string label);
    bit [31:0] data_v;

    csr_read(address, data_v);
    expect32(label, data_v, expected);
  endtask

  task automatic drive_protocol_violation_real(input bit [2:0] second_error = 3'b010);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST));
    wait_cycles(4);
    drive_hit(ARB_SRC_REAL, 45'h001_0000_0001, 3'b001, 4'h1, 1'b1, 1'b0, 1'b0);
    wait_cycles(4);
    drive_hit(ARB_SRC_REAL, 45'h001_0000_0002, second_error, 4'h1, 1'b1, 1'b1, 1'b0);
    wait_cycles(12);
  endtask

  task automatic drive_real_ingress_mid_packet_drop();
    int unsigned idx;

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_EMU_CONST, 1'b1, 1'b1, 1'b1, 1'b1));
    wait_cycles(4);
    drive_hit(ARB_SRC_REAL, 45'h007_0000_0000, 3'b001, 4'h2, 1'b1, 1'b0, 1'b0);
    for (idx = 0; idx < 20; idx++) begin
      drive_hit(
        ARB_SRC_REAL,
        45'h007_0000_0010 + idx,
        3'b101,
        4'h2,
        1'b0,
        (idx == 19),
        1'b0
      );
    end
    wait_cycles(10);
  endtask

  function automatic bit [31:0] protocol_syndrome_real_second_sop(input bit [2:0] error);
    bit [31:0] syndrome_v;

    syndrome_v        = 32'd0;
    syndrome_v[3:0]   = 4'h1;
    syndrome_v[5]     = 1'b1;
    syndrome_v[7]     = 1'b1;
    syndrome_v[8]     = 1'b1;
    syndrome_v[11:9]  = error;
    syndrome_v[14:12] = 3'd0;
    return syndrome_v;
  endfunction

  task automatic poke_csr_state(input string leaf, input bit [31:0] value);
    string path_v;

    path_v = {"tb_top.dut.u_csr.csr.", leaf};
    if (!uvm_hdl_deposit(path_v, value)) begin
      `uvm_error(get_type_name(), $sformatf("failed to deposit %s", path_v))
    end
    wait_cycles(1);
  endtask

  task automatic sync_scoreboard_error_state(
    input bit [31:0] protocol_count,
    input bit [31:0] drop_count,
    input bit [31:0] protocol_syndrome,
    input bit [31:0] drop_syndrome
  );
    uvm_component comp_h;
    arb_hit_type0_scoreboard sb_h;

    comp_h = uvm_top.find("uvm_test_top.env.scoreboard");
    if (!$cast(sb_h, comp_h)) begin
      `uvm_error(get_type_name(), "failed to find scoreboard")
      return;
    end
    sb_h.error_count_protocol        = protocol_count;
    sb_h.error_count_drop_mid_packet = drop_count;
    sb_h.syndrome_protocol           = protocol_syndrome;
    sb_h.syndrome_drop_mid_packet    = drop_syndrome;
  endtask

  task automatic predict_watchdog_real(input bit [3:0] channel);
    uvm_component comp_h;
    arb_hit_type0_scoreboard sb_h;

    comp_h = uvm_top.find("uvm_test_top.env.scoreboard");
    if (!$cast(sb_h, comp_h)) begin
      `uvm_error(get_type_name(), "failed to find scoreboard")
      return;
    end
    sb_h.predict_watchdog_synthesized(1'b0, channel);
  endtask
endclass

class R001_async_reset_clears_state_seq extends R_error_base_seq;
  `uvm_object_utils(R001_async_reset_clears_state_seq)

  function new(string name = "R001_async_reset_clears_state_seq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] uid_v;
    bit [63:0] hits_v;

    drive_packet(ARB_SRC_REAL, 3, 45'h001_0000_0100, 3'b000, 4'h1);
    wait_cycles(16);
    csr_read_pair(ARB_REG_INGRESS_REAL_HITS_L_ADDR, hits_v);
    expect64("pre-reset ingress real hits", hits_v, 64'd3);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_RESERVED_CONST));
    wait_cycles(4);
    pulse_hard_reset();
    csr_read(ARB_REG_UID_ADDR, uid_v);
    expect32("UID after hard reset", uid_v, ARB_UID_CONST);
    expect_status_mask(32'h0003_3FFF, 32'h0000_0500);
    csr_read_pair(ARB_REG_INGRESS_REAL_HITS_L_ADDR, hits_v);
    expect64("ingress real hits after hard reset", hits_v, 64'd0);
  endtask
endclass
