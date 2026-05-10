class arb_hit_type0_edge_base_seq extends arb_hit_type0_base_vseq;
  `uvm_object_utils(arb_hit_type0_edge_base_seq)

  arb_hit_type0_env_cfg    cfg;
  arb_hit_type0_scoreboard scoreboard;

  function new(string name = "arb_hit_type0_edge_base_seq");
    super.new(name);
  endfunction

  task automatic require_handles();
    if (cfg == null) begin
      `uvm_fatal(get_type_name(), "EDGE sequence missing cfg handle")
    end
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) begin
      @(posedge cfg.reset_vif.clk);
    end
  endtask

  task automatic drive_source_idle(input bit source_emu);
    if (source_emu) begin
      cfg.emu_vif.valid      <= 1'b0;
      cfg.emu_vif.data       <= 45'd0;
      cfg.emu_vif.error      <= 3'd0;
      cfg.emu_vif.channel    <= 4'd0;
      cfg.emu_vif.sop        <= 1'b0;
      cfg.emu_vif.eop        <= 1'b0;
      cfg.emu_vif.eor        <= 1'b0;
    end else begin
      cfg.real_vif.valid      <= 1'b0;
      cfg.real_vif.data       <= 45'd0;
      cfg.real_vif.error      <= 3'd0;
      cfg.real_vif.channel    <= 4'd0;
      cfg.real_vif.sop        <= 1'b0;
      cfg.real_vif.eop        <= 1'b0;
      cfg.real_vif.eor        <= 1'b0;
    end
  endtask

  task automatic drive_all_idle();
    @(negedge cfg.reset_vif.clk);
    drive_source_idle(1'b0);
    drive_source_idle(1'b1);
    cfg.csr_vif.address      <= 5'd0;
    cfg.csr_vif.write        <= 1'b0;
    cfg.csr_vif.read         <= 1'b0;
    cfg.csr_vif.writedata    <= 32'd0;
  endtask

  task automatic drive_source_packet(
    input bit         source_emu,
    input int unsigned start_delay,
    input int unsigned beat_count,
    input bit [3:0]   channel,
    input bit [2:0]   error,
    input bit [44:0]  data_base,
    input bit         eor_last = 1'b0,
    input bit         sop_only = 1'b0
  );
    require_handles();
    wait_cycles(start_delay);

    for (int unsigned idx = 0; idx < beat_count; idx++) begin
      @(negedge cfg.reset_vif.clk);
      if (source_emu) begin
        cfg.emu_vif.valid      <= 1'b1;
        cfg.emu_vif.data       <= data_base + 45'(idx);
        cfg.emu_vif.error      <= error;
        cfg.emu_vif.channel    <= channel;
        cfg.emu_vif.sop        <= (idx == 0);
        cfg.emu_vif.eop        <= sop_only ? 1'b0 : (idx == (beat_count - 1));
        cfg.emu_vif.eor        <= sop_only ? 1'b0 : (eor_last && (idx == (beat_count - 1)));
      end else begin
        cfg.real_vif.valid      <= 1'b1;
        cfg.real_vif.data       <= data_base + 45'(idx);
        cfg.real_vif.error      <= error;
        cfg.real_vif.channel    <= channel;
        cfg.real_vif.sop        <= (idx == 0);
        cfg.real_vif.eop        <= sop_only ? 1'b0 : (idx == (beat_count - 1));
        cfg.real_vif.eor        <= sop_only ? 1'b0 : (eor_last && (idx == (beat_count - 1)));
      end
    end

    @(negedge cfg.reset_vif.clk);
    drive_source_idle(source_emu);
  endtask

  task automatic drive_single_beat(
    input bit        source_emu,
    input bit [44:0] data,
    input bit [2:0]  error,
    input bit [3:0]  channel,
    input bit        eor = 1'b0
  );
    drive_source_packet(source_emu, 0, 1, channel, error, data, eor, 1'b0);
  endtask

  task automatic drive_source_singletons(
    input bit         source_emu,
    input int unsigned start_delay,
    input int unsigned beat_count,
    input bit [3:0]   channel,
    input bit [2:0]   error,
    input bit [44:0]  data_base,
    input bit         eor_last = 1'b0
  );
    require_handles();
    wait_cycles(start_delay);

    for (int unsigned idx = 0; idx < beat_count; idx++) begin
      @(negedge cfg.reset_vif.clk);
      if (source_emu) begin
        cfg.emu_vif.valid      <= 1'b1;
        cfg.emu_vif.data       <= data_base + 45'(idx);
        cfg.emu_vif.error      <= error;
        cfg.emu_vif.channel    <= channel;
        cfg.emu_vif.sop        <= 1'b1;
        cfg.emu_vif.eop        <= 1'b1;
        cfg.emu_vif.eor        <= eor_last && (idx == (beat_count - 1));
      end else begin
        cfg.real_vif.valid      <= 1'b1;
        cfg.real_vif.data       <= data_base + 45'(idx);
        cfg.real_vif.error      <= error;
        cfg.real_vif.channel    <= channel;
        cfg.real_vif.sop        <= 1'b1;
        cfg.real_vif.eop        <= 1'b1;
        cfg.real_vif.eor        <= eor_last && (idx == (beat_count - 1));
      end
    end

    @(negedge cfg.reset_vif.clk);
    drive_source_idle(source_emu);
  endtask

  task automatic csr_write_direct(input bit [4:0] address, input bit [31:0] data);
    require_handles();
    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.address      <= address;
    cfg.csr_vif.writedata    <= data;
    cfg.csr_vif.write        <= 1'b1;
    cfg.csr_vif.read         <= 1'b0;

    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.write        <= 1'b0;
    cfg.csr_vif.address      <= 5'd0;
    cfg.csr_vif.writedata    <= 32'd0;
  endtask

  task automatic csr_read_direct(input bit [4:0] address, output bit [31:0] data);
    require_handles();
    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.address      <= address;
    cfg.csr_vif.writedata    <= 32'd0;
    cfg.csr_vif.write        <= 1'b0;
    cfg.csr_vif.read         <= 1'b1;

    @(posedge cfg.reset_vif.clk);
    #1step;
    data = cfg.csr_vif.readdata;
    cfg.csr_vif.read       <= 1'b0;
    cfg.csr_vif.address    <= 5'd0;
  endtask

  task automatic csr_read_pair_direct(input bit [4:0] addr_lo, output bit [63:0] data64);
    bit [31:0] lo_v;
    bit [31:0] hi_v;

    csr_read_direct(addr_lo, lo_v);
    csr_read_direct(addr_lo + 5'd1, hi_v);
    data64 = {hi_v, lo_v};
  endtask

  task automatic set_mode(input bit [1:0] mode);
    csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(mode));
    wait_cycles(2);
  endtask

  task automatic write_mode_after_egress_seen(input bit [1:0] mode, input int unsigned seen_before_write);
    int unsigned seen_v;

    seen_v = 0;
    for (int unsigned cycle = 0; cycle < 128; cycle++) begin
      @(posedge cfg.reset_vif.clk);
      #1step;
      if (cfg.egress_vif.valid === 1'b1) begin
        seen_v++;
      end
      if (seen_v >= seen_before_write) begin
        cfg.csr_vif.address      <= ARB_REG_CONTROL_ADDR;
        cfg.csr_vif.writedata    <= arb_control_word(mode);
        cfg.csr_vif.write        <= 1'b1;
        cfg.csr_vif.read         <= 1'b0;
        @(posedge cfg.reset_vif.clk);
        cfg.csr_vif.write        <= 1'b0;
        cfg.csr_vif.address      <= 5'd0;
        cfg.csr_vif.writedata    <= 32'd0;
        return;
      end
    end
    `uvm_error(get_type_name(), $sformatf("Timed out waiting for %0d egress beats before mode write", seen_before_write))
  endtask

  task automatic clear_counters();
    csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST, 1'b1));
    wait_cycles(2);
  endtask

  task automatic wait_egress_count(
    input int unsigned expected,
    input int unsigned max_cycles,
    output int unsigned beats,
    output int unsigned sop_count,
    output int unsigned eop_count,
    output int unsigned eor_count,
    output bit [44:0]  last_data,
    output bit [2:0]   last_error,
    output bit [3:0]   last_channel
  );
    beats        = 0;
    sop_count    = 0;
    eop_count    = 0;
    eor_count    = 0;
    last_data    = 45'd0;
    last_error   = 3'd0;
    last_channel = 4'd0;

    for (int unsigned cycle = 0; cycle < max_cycles; cycle++) begin
      @(posedge cfg.reset_vif.clk);
      #1step;
      if (cfg.egress_vif.valid === 1'b1) begin
        beats++;
        sop_count   += cfg.egress_vif.sop ? 1 : 0;
        eop_count   += cfg.egress_vif.eop ? 1 : 0;
        eor_count   += cfg.egress_vif.eor ? 1 : 0;
        last_data    = cfg.egress_vif.data;
        last_error   = cfg.egress_vif.error;
        last_channel = cfg.egress_vif.channel;
        if (beats >= expected) begin
          return;
        end
      end
    end

    `uvm_error(get_type_name(), $sformatf("Timed out after %0d cycles waiting for %0d egress beats; saw %0d", max_cycles, expected, beats))
  endtask

  task automatic check_no_egress(input int unsigned cycles, input string label_text);
    for (int unsigned cycle = 0; cycle < cycles; cycle++) begin
      @(posedge cfg.reset_vif.clk);
      #1step;
      if (cfg.egress_vif.valid === 1'b1) begin
        `uvm_error(get_type_name(), $sformatf("%s: unexpected egress data=0x%011h ch=0x%0h", label_text, cfg.egress_vif.data, cfg.egress_vif.channel))
      end
    end
  endtask

  task automatic expect_status_mask(input bit [31:0] mask, input bit [31:0] expected, input string label_text);
    bit [31:0] status_v;

    csr_read_direct(ARB_REG_STATUS_ADDR, status_v);
    if ((status_v & mask) !== (expected & mask)) begin
      `uvm_error(get_type_name(), $sformatf("%s: STATUS mask mismatch mask=0x%08h expected=0x%08h observed=0x%08h", label_text, mask, expected, status_v))
    end
  endtask

  task automatic expect_counter(input bit [4:0] addr_lo, input bit [63:0] expected, input string label_text);
    bit [63:0] observed_v;

    csr_read_pair_direct(addr_lo, observed_v);
    if (observed_v !== expected) begin
      `uvm_error(get_type_name(), $sformatf("%s: counter mismatch addr=0x%02h expected=0x%016h observed=0x%016h", label_text, addr_lo, expected, observed_v))
    end
  endtask

  task automatic expect_counter_nonzero(input bit [4:0] addr_lo, input string label_text);
    bit [63:0] observed_v;

    csr_read_pair_direct(addr_lo, observed_v);
    if (observed_v == 64'd0) begin
      `uvm_error(get_type_name(), $sformatf("%s: counter at addr=0x%02h remained zero", label_text, addr_lo))
    end
  endtask

  task automatic preload_counter(input bit [4:0] addr_lo, input bit [63:0] value);
    uvm_hdl_data_t hdl_value;
    string         hdl_path;

    hdl_value        = '0;
    hdl_value[63:0]  = value;
    case (addr_lo)
      ARB_REG_INGRESS_REAL_HITS_L_ADDR: hdl_path = "tb_top.dut.u_csr.csr.ingress_real_hits";
      ARB_REG_INGRESS_EMU_HITS_L_ADDR:  hdl_path = "tb_top.dut.u_csr.csr.ingress_emu_hits";
      ARB_REG_EGRESS_REAL_HITS_L_ADDR:  hdl_path = "tb_top.dut.u_csr.csr.egress_real_hits";
      ARB_REG_EGRESS_EMU_HITS_L_ADDR:   hdl_path = "tb_top.dut.u_csr.csr.egress_emu_hits";
      default:                          hdl_path = "";
    endcase

    if (hdl_path == "") begin
      `uvm_error(get_type_name(), $sformatf("Unsupported preload counter addr=0x%02h", addr_lo))
      return;
    end
    if (!uvm_hdl_deposit(hdl_path, hdl_value)) begin
      `uvm_error(get_type_name(), $sformatf("uvm_hdl_deposit failed for %s", hdl_path))
    end
    if (scoreboard != null) begin
      scoreboard.predict_counter_preload(addr_lo, value);
    end
    wait_cycles(1);
  endtask

  task automatic case_E001_single_beat_packet();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    drive_all_idle();
    drive_single_beat(1'b0, 45'h1A2B3C4D5E6, 3'd0, 4'h0);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    if ((sop_v != 1) || (eop_v != 1) || (eor_v != 0) || (data_v != 45'h1A2B3C4D5E6)) begin
      `uvm_error(get_type_name(), "E001 single-beat packet shape mismatch")
    end
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd1, "E001 ingress real hits");
  endtask

  task automatic case_E002_max_channel();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_EMU_CONST);
    drive_single_beat(1'b1, 45'h0000000000F, 3'd0, 4'hF);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    if (channel_v != 4'hF) begin
      `uvm_error(get_type_name(), $sformatf("E002 channel mismatch observed=0x%0h", channel_v))
    end
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd1, "E002 ingress emu hits");
  endtask

  task automatic case_E003_all_error_bits_set();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    drive_single_beat(1'b0, 45'h00000000033, 3'b111, 4'h1);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    if (error_v != 3'b111) begin
      `uvm_error(get_type_name(), $sformatf("E003 error sideband mismatch observed=0x%0h", error_v))
    end
  endtask

  task automatic case_E004_eor_only_packet();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    drive_single_beat(1'b0, 45'h00000000044, 3'd0, 4'h2, 1'b1);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    if ((sop_v != 1) || (eop_v != 1) || (eor_v != 1)) begin
      `uvm_error(get_type_name(), "E004 EOR single-beat packet did not close with EOR")
    end
    drive_single_beat(1'b0, 45'h00000000045, 3'd0, 4'h2);
    check_no_egress(16, "E004 merged_locked");
  endtask

  task automatic case_E005_long_packet_at_fifo_depth();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    fork
      drive_source_packet(1'b0, 0, 16, 4'h3, 3'd0, 45'h00000001000);
      wait_egress_count(16, 128, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    if ((sop_v != 1) || (eop_v != 1) || (eor_v != 0)) begin
      `uvm_error(get_type_name(), "E005 16-beat packet boundary count mismatch")
    end
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "E005 real drops");
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd16, "E005 ingress real hits");
  endtask

  task automatic case_E006_switch_on_eop_clock_real_to_emu();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_REAL_CONST);
    fork
      drive_source_packet(1'b0, 0, 4, 4'h0, 3'd0, 45'h00000002000);
      write_mode_after_egress_seen(ARB_MODE_EMU_CONST, 3);
    join
    wait_cycles(6);
    if (scoreboard != null) begin
      scoreboard.predict_mode_boundary(ARB_MODE_EMU_CONST);
    end
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd4, "E006 egress real hits before switch");
    drive_single_beat(1'b1, 45'h00000002080, 3'd0, 4'h8);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    if (channel_v != 4'h8) begin
      `uvm_error(get_type_name(), "E006 next granted packet was not emulator sourced")
    end
  endtask

  task automatic case_E007_switch_on_eop_real_to_mix_rr();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_REAL_CONST);
    fork
      drive_source_packet(1'b0, 0, 4, 4'h0, 3'd0, 45'h00000003000);
      write_mode_after_egress_seen(ARB_MODE_MIX_RR_CONST, 3);
    join
    wait_cycles(6);
    if (scoreboard != null) begin
      scoreboard.predict_mode_boundary(ARB_MODE_MIX_RR_CONST);
    end
    expect_status_mask(32'h00000003, 32'h00000002, "E007 mode committed to MIX_RR");
    fork
      drive_source_singletons(1'b0, 0, 1, 4'h0, 3'd0, 45'h00000003040);
      drive_source_singletons(1'b1, 0, 1, 4'h8, 3'd0, 45'h00000003080);
    join
    wait_egress_count(2, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
  endtask

  task automatic case_E008_switch_just_after_eop();
    bit [31:0] control_v;
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_REAL_CONST);
    fork
      drive_source_packet(1'b0, 0, 2, 4'h0, 3'd0, 45'h00000004000);
      wait_egress_count(2, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_EMU_CONST));
    wait_cycles(2);
    csr_read_direct(ARB_REG_CONTROL_ADDR, control_v);
    if (control_v[1:0] != ARB_MODE_EMU_CONST) begin
      `uvm_error(get_type_name(), $sformatf("E008 CONTROL did not read back EMU: 0x%08h", control_v))
    end
  endtask

  task automatic case_E009_fifo_full_to_empty();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_EMU_CONST);
    drive_source_packet(1'b0, 0, 16, 4'h1, 3'd0, 45'h00000005000);
    wait_cycles(4);
    expect_status_mask(32'h00000180, 32'h00000080, "E009 real FIFO full");
    set_mode(ARB_MODE_REAL_CONST);
    wait_cycles(40);
    expect_status_mask(32'h00000180, 32'h00000100, "E009 real FIFO empty");
  endtask

  task automatic case_E010_simultaneous_full_both_sources();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_EMU_CONST);
    drive_source_packet(1'b0, 0, 16, 4'h1, 3'd0, 45'h00000006000);
    wait_cycles(4);
    expect_status_mask(32'h00000080, 32'h00000080, "E010 real FIFO full precondition");
    set_mode(ARB_MODE_REAL_CONST);
    drive_source_packet(1'b1, 0, 16, 4'h8, 3'd0, 45'h00000006800);
    wait_cycles(4);
    expect_status_mask(32'h00000200, 32'h00000200, "E010 emu FIFO full precondition");
    set_mode(ARB_MODE_MIX_RR_CONST);
    wait_cycles(48);
    expect_status_mask(32'h00000600, 32'h00000500, "E010 FIFOs empty after MIX_RR drain");
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "E010 real drops");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd0, "E010 emu drops");
  endtask

  task automatic case_E011_alternating_single_beat_packets_mix_rr();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_singletons(1'b0, 0, 4, 4'h0, 3'd0, 45'h00000007000);
      drive_source_singletons(1'b1, 0, 4, 4'h8, 3'd0, 45'h00000007800);
      wait_egress_count(8, 128, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    if ((sop_v != 8) || (eop_v != 8)) begin
      `uvm_error(get_type_name(), "E011 single-beat packets did not preserve per-beat SOP/EOP")
    end
  endtask

  task automatic case_E012_one_source_silent_other_drains();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_packet(1'b0, 0, 8, 4'h0, 3'd0, 45'h00000008000);
      wait_egress_count(8, 128, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    expect_status_mask(32'h00000800, 32'h00000000, "E012 last_grant remains real");
  endtask

  task automatic case_E012b_overlapping_frames_merged_into_one_packet();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_packet(1'b0, 0, 8, 4'h0, 3'd0, 45'h00000009000);
      drive_source_packet(1'b1, 3, 6, 4'h8, 3'd0, 45'h00000009800);
      wait_egress_count(14, 192, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    if ((sop_v != 1) || (eop_v != 1) || (eor_v != 0)) begin
      `uvm_error(get_type_name(), "E012b overlapping frames were not merged into one packet")
    end
  endtask

  task automatic case_E012c_eor_after_other_active();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_packet(1'b0, 0, 6, 4'h0, 3'd0, 45'h0000000A000, 1'b1);
      drive_source_packet(1'b1, 3, 8, 4'h8, 3'd0, 45'h0000000A800, 1'b1);
      wait_egress_count(14, 192, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    if ((eop_v != 1) || (eor_v != 1)) begin
      `uvm_error(get_type_name(), "E012c merged EOR was not held until the final closing beat")
    end
    check_no_egress(12, "E012c merged_locked after final EOR");
  endtask

  task automatic case_E012d_eor_simultaneous_at_egress();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_packet(1'b0, 0, 2, 4'h0, 3'd0, 45'h0000000B000, 1'b1);
      drive_source_packet(1'b1, 0, 2, 4'h8, 3'd0, 45'h0000000B800, 1'b1);
      wait_egress_count(4, 96, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    if ((sop_v != 1) || (eop_v != 1) || (eor_v != 1)) begin
      `uvm_error(get_type_name(), "E012d adjacent EOR grants did not produce one merged EOR")
    end
  endtask

  task automatic case_E012e_watchdog_synthesizes_eor_one_sided();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;
    bit [63:0]  emu_hits_before_v;
    bit [63:0]  emu_hits_after_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    csr_write_direct(ARB_REG_WATCHDOG_ADDR, 32'd8);
    fork
      drive_source_packet(1'b1, 0, 1, 4'h8, 3'd0, 45'h0000000C800, 1'b0, 1'b1);
      drive_single_beat(1'b0, 45'h0000000C000, 3'd0, 4'h0, 1'b1);
      wait_egress_count(2, 96, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    csr_read_pair_direct(ARB_REG_EGRESS_EMU_HITS_L_ADDR, emu_hits_before_v);
    if (scoreboard != null) begin
      scoreboard.predict_watchdog_synthesized(1'b1, 4'h8);
    end
    wait_egress_count(1, 96, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    if ((data_v != 45'd0) || (error_v != 3'b100) || (channel_v != 4'h8) || (eop_v != 1) || (eor_v != 1)) begin
      `uvm_error(get_type_name(), "E012e watchdog synthesized beat fields mismatch")
    end
    csr_read_pair_direct(ARB_REG_EGRESS_EMU_HITS_L_ADDR, emu_hits_after_v);
    if (emu_hits_after_v != emu_hits_before_v) begin
      `uvm_error(get_type_name(), "E012e watchdog synthesized beat incremented EGRESS_EMU_HITS")
    end
    expect_status_mask(32'h00020000, 32'h00020000, "E012e watchdog synthesized emu sticky");
    check_no_egress(12, "E012e merged_locked after synthesized EOR");
  endtask

  task automatic case_E012f_watchdog_disabled_leaves_packet_open();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    csr_write_direct(ARB_REG_WATCHDOG_ADDR, 32'd0);
    fork
      drive_source_packet(1'b1, 0, 1, 4'h8, 3'd0, 45'h0000000D800, 1'b0, 1'b1);
      drive_single_beat(1'b0, 45'h0000000D000, 3'd0, 4'h0, 1'b1);
      wait_egress_count(2, 96, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
    join
    check_no_egress(40, "E012f watchdog disabled");
    expect_status_mask(32'h00000010, 32'h00000010, "E012f merged packet remains open");
  endtask

  task automatic case_E013_low_word_saturation();
    bit [63:0] expected_v;

    set_mode(ARB_MODE_EMU_CONST);
    preload_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'h00000000_FFFFFFF8);
    drive_source_singletons(1'b0, 0, 16, 4'h0, 3'd0, 45'h0000000E000);
    wait_cycles(8);
    expected_v = 64'h00000001_00000008;
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, expected_v, "E013 low-word rollover");
  endtask

  task automatic case_E014_full_64_bit_saturation_clamp();
    set_mode(ARB_MODE_EMU_CONST);
    preload_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'hFFFF_FFFF_FFFF_FFFD);
    drive_source_singletons(1'b0, 0, 4, 4'h0, 3'd0, 45'h0000000F000);
    wait_cycles(8);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'hFFFF_FFFF_FFFF_FFFF, "E014 full counter saturation");
  endtask

  task automatic case_E015_w1p_clear_during_traffic();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_REAL_CONST);
    fork
      drive_source_singletons(1'b0, 0, 8, 4'h0, 3'd0, 45'h00000010000);
      begin
        wait_egress_count(3, 96, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
        csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST, 1'b1));
      end
    join
    wait_cycles(8);
    expect_counter_nonzero(ARB_REG_INGRESS_REAL_HITS_L_ADDR, "E015 ingress after W1P clear");
    expect_counter_nonzero(ARB_REG_EGRESS_REAL_HITS_L_ADDR, "E015 egress after W1P clear");
  endtask

  task automatic case_E016_csr_address_aliasing();
    bit [31:0] data_v;

    for (int unsigned idx = 0; idx < 4; idx++) begin
      csr_write_direct(ARB_REG_META_ADDR, 32'(idx));
      csr_read_direct(ARB_REG_META_ADDR, data_v);
    end
    for (int unsigned addr = 0; addr < 32; addr++) begin
      csr_read_direct(addr[4:0], data_v);
      if ((addr >= 30) && (data_v != 32'd0)) begin
        `uvm_error(get_type_name(), $sformatf("E016 reserved CSR addr=0x%02h returned 0x%08h", addr, data_v))
      end
    end
  endtask

  task automatic case_E017_read_during_writeable_field_change();
    bit [31:0] control_v;

    csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(1);
    csr_read_direct(ARB_REG_CONTROL_ADDR, control_v);
    if (control_v[1:0] != ARB_MODE_MIX_RR_CONST) begin
      `uvm_error(get_type_name(), $sformatf("E017 CONTROL readback mismatch observed=0x%08h", control_v))
    end
  endtask

  task automatic case_E018_status_live_packet_flags();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  data_v;
    bit [2:0]   error_v;
    bit [3:0]   channel_v;

    set_mode(ARB_MODE_REAL_CONST);
    fork
      drive_source_packet(1'b0, 0, 16, 4'h0, 3'd0, 45'h00000012000);
      begin
        wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, data_v, error_v, channel_v);
        expect_status_mask(32'h00000030, 32'h00000030, "E018 live merged/real open flags");
      end
    join
    wait_cycles(16);
    expect_status_mask(32'h00000030, 32'h00000000, "E018 packet flags cleared after EOP");
  endtask
endclass
