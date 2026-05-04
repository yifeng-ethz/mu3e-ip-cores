package arb_hit_type0_basic_pkg;
  import uvm_pkg::*;
  import arb_hit_type0_reg_pkg::*;
  import arb_hit_type0_pkg::*;
  `include "uvm_macros.svh"

class B000_basic_base_seq extends arb_hit_type0_base_vseq;
  `uvm_object_utils(B000_basic_base_seq)

  localparam bit [31:0] STATUS_MODE_MASK_CONST        = 32'h00000003;
  localparam bit [31:0] STATUS_MODE_PENDING_MASK_CONST = 32'h0000000F;
  localparam bit [31:0] STATUS_OPEN_MASK_CONST        = 32'h00000070;
  localparam bit [31:0] STATUS_REAL_FULL_MASK_CONST   = 32'h00000080;
  localparam bit [31:0] STATUS_REAL_EMPTY_MASK_CONST  = 32'h00000100;
  localparam bit [31:0] STATUS_EMU_FULL_MASK_CONST    = 32'h00000200;
  localparam bit [31:0] STATUS_EMU_EMPTY_MASK_CONST   = 32'h00000400;
  localparam bit [31:0] STATUS_LAST_GRANT_MASK_CONST  = 32'h00000800;

  arb_hit_type0_env_cfg    cfg;
  arb_hit_type0_scoreboard scoreboard;

  function new(string name = "B000_basic_base_seq");
    super.new(name);
  endfunction

  task pre_body();
    uvm_component comp_h;

    super.pre_body();
    if (!uvm_config_db#(arb_hit_type0_env_cfg)::get(null, "*", "env_cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "missing env_cfg")
    end

    comp_h = uvm_top.find("uvm_test_top.env.scoreboard");
    if (comp_h != null) begin
      void'($cast(scoreboard, comp_h));
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
    @(posedge cfg.reset_vif.clk);
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
    wait_cycles(start_delay);

    for (int unsigned idx = 0; idx < beat_count; idx++) begin
      @(posedge cfg.reset_vif.clk);
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

    @(posedge cfg.reset_vif.clk);
    drive_source_idle(source_emu);
  endtask

  task automatic drive_source_packet_tail(
    input bit         source_emu,
    input int unsigned start_delay,
    input int unsigned beat_count,
    input bit [3:0]   channel,
    input bit [2:0]   error,
    input bit [44:0]  data_base,
    input bit         eor_last = 1'b0
  );
    wait_cycles(start_delay);

    for (int unsigned idx = 0; idx < beat_count; idx++) begin
      @(posedge cfg.reset_vif.clk);
      if (source_emu) begin
        cfg.emu_vif.valid      <= 1'b1;
        cfg.emu_vif.data       <= data_base + 45'(idx);
        cfg.emu_vif.error      <= error;
        cfg.emu_vif.channel    <= channel;
        cfg.emu_vif.sop        <= 1'b0;
        cfg.emu_vif.eop        <= (idx == (beat_count - 1));
        cfg.emu_vif.eor        <= eor_last && (idx == (beat_count - 1));
      end else begin
        cfg.real_vif.valid      <= 1'b1;
        cfg.real_vif.data       <= data_base + 45'(idx);
        cfg.real_vif.error      <= error;
        cfg.real_vif.channel    <= channel;
        cfg.real_vif.sop        <= 1'b0;
        cfg.real_vif.eop        <= (idx == (beat_count - 1));
        cfg.real_vif.eor        <= eor_last && (idx == (beat_count - 1));
      end
    end

    @(posedge cfg.reset_vif.clk);
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
    wait_cycles(start_delay);

    for (int unsigned idx = 0; idx < beat_count; idx++) begin
      @(posedge cfg.reset_vif.clk);
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

    @(posedge cfg.reset_vif.clk);
    drive_source_idle(source_emu);
  endtask

  task automatic drive_valid_low_beat(
    input bit        source_emu,
    input bit [44:0] data,
    input bit [2:0]  error,
    input bit [3:0]  channel
  );
    @(posedge cfg.reset_vif.clk);
    if (source_emu) begin
      cfg.emu_vif.valid      <= 1'b0;
      cfg.emu_vif.data       <= data;
      cfg.emu_vif.error      <= error;
      cfg.emu_vif.channel    <= channel;
      cfg.emu_vif.sop        <= 1'b1;
      cfg.emu_vif.eop        <= 1'b1;
      cfg.emu_vif.eor        <= 1'b0;
    end else begin
      cfg.real_vif.valid      <= 1'b0;
      cfg.real_vif.data       <= data;
      cfg.real_vif.error      <= error;
      cfg.real_vif.channel    <= channel;
      cfg.real_vif.sop        <= 1'b1;
      cfg.real_vif.eop        <= 1'b1;
      cfg.real_vif.eor        <= 1'b0;
    end

    @(posedge cfg.reset_vif.clk);
    drive_source_idle(source_emu);
  endtask

  task automatic wait_egress_count(
    input int unsigned expected,
    input int unsigned max_cycles,
    output int unsigned beats,
    output int unsigned sop_count,
    output int unsigned eop_count,
    output int unsigned eor_count,
    output bit [44:0]  first_data,
    output bit [44:0]  last_data,
    output bit [2:0]   last_error,
    output bit [3:0]   last_channel,
    output bit [15:0]  channel_mask
  );
    beats        = 0;
    sop_count    = 0;
    eop_count    = 0;
    eor_count    = 0;
    first_data    = 45'd0;
    last_data     = 45'd0;
    last_error    = 3'd0;
    last_channel  = 4'd0;
    channel_mask  = 16'd0;

    for (int unsigned cycle = 0; cycle < max_cycles; cycle++) begin
      @(posedge cfg.reset_vif.clk);
      #1step;
      if (cfg.egress_vif.valid === 1'b1) begin
        if (beats == 0) begin
          first_data = cfg.egress_vif.data;
        end
        beats++;
        sop_count   += cfg.egress_vif.sop ? 1 : 0;
        eop_count   += cfg.egress_vif.eop ? 1 : 0;
        eor_count   += cfg.egress_vif.eor ? 1 : 0;
        last_data    = cfg.egress_vif.data;
        last_error   = cfg.egress_vif.error;
        last_channel = cfg.egress_vif.channel;
        channel_mask[cfg.egress_vif.channel] = 1'b1;
        if (beats >= expected) begin
          return;
        end
      end
    end

    `uvm_error(
      get_type_name(),
      $sformatf("Timed out after %0d cycles waiting for %0d egress beats; saw %0d", max_cycles, expected, beats)
    )
  endtask

  task automatic wait_egress_simple(input int unsigned expected, input int unsigned max_cycles);
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    wait_egress_count(
      expected,
      max_cycles,
      beats_v,
      sop_v,
      eop_v,
      eor_v,
      first_data_v,
      last_data_v,
      last_error_v,
      last_channel_v,
      channel_mask_v
    );
  endtask

  task automatic check_no_egress(input int unsigned cycles, input string label_text);
    for (int unsigned cycle = 0; cycle < cycles; cycle++) begin
      @(posedge cfg.reset_vif.clk);
      #1step;
      if (cfg.egress_vif.valid === 1'b1) begin
        `uvm_error(
          get_type_name(),
          $sformatf("%s: unexpected egress data=0x%011h ch=0x%0h", label_text, cfg.egress_vif.data, cfg.egress_vif.channel)
        )
      end
    end
  endtask

  task automatic expect32(input string label_text, input bit [31:0] actual, input bit [31:0] expected);
    if (actual !== expected) begin
      `uvm_error(
        get_type_name(),
        $sformatf("%s expected=0x%08h observed=0x%08h", label_text, expected, actual)
      )
    end
  endtask

  task automatic expect64(input string label_text, input bit [63:0] actual, input bit [63:0] expected);
    if (actual !== expected) begin
      `uvm_error(
        get_type_name(),
        $sformatf("%s expected=0x%016h observed=0x%016h", label_text, expected, actual)
      )
    end
  endtask

  task automatic expect_csr32(input bit [4:0] address, input bit [31:0] expected, input string label_text);
    bit [31:0] data_v;

    csr_read(address, data_v);
    expect32(label_text, data_v, expected);
  endtask

  task automatic expect_counter(input bit [4:0] addr_lo, input bit [63:0] expected, input string label_text);
    bit [63:0] observed_v;

    csr_read_pair(addr_lo, observed_v);
    expect64(label_text, observed_v, expected);
  endtask

  task automatic expect_status_mask(input bit [31:0] mask, input bit [31:0] expected, input string label_text);
    bit [31:0] status_v;

    csr_read(ARB_REG_STATUS_ADDR, status_v);
    if ((status_v & mask) !== (expected & mask)) begin
      `uvm_error(
        get_type_name(),
        $sformatf(
          "%s STATUS mask=0x%08h expected=0x%08h observed=0x%08h",
          label_text,
          mask,
          expected & mask,
          status_v & mask
        )
      )
    end
  endtask

  task automatic expect_status_mask_unchecked(input bit [31:0] mask, input bit [31:0] expected, input string label_text);
    bit [31:0] status_v;

    if (scoreboard != null) begin
      scoreboard.suppress_next_csr_read_check();
    end
    csr_read(ARB_REG_STATUS_ADDR, status_v);
    if ((status_v & mask) !== (expected & mask)) begin
      `uvm_error(
        get_type_name(),
        $sformatf(
          "%s STATUS mask=0x%08h expected=0x%08h observed=0x%08h",
          label_text,
          mask,
          expected & mask,
          status_v & mask
        )
      )
    end
  endtask

  task automatic expect_status_mode(input bit [1:0] mode_value, input string label_text);
    bit [31:0] expected_v;

    expected_v        = 32'd0;
    expected_v[1:0]   = mode_value;
    expected_v[3:2]   = mode_value;
    expect_status_mask(STATUS_MODE_PENDING_MASK_CONST, expected_v, label_text);
  endtask

  task automatic set_mode(input bit [1:0] mode_value);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(mode_value));
    wait_cycles(4);
  endtask

  task automatic clear_all(input bit [1:0] mode_value = ARB_MODE_REAL_CONST);
    csr_write(
      ARB_REG_CONTROL_ADDR,
      arb_control_word(mode_value, 1'b1, 1'b1, 1'b1, 1'b1)
    );
    wait_cycles(4);
  endtask

  task automatic csr_write_direct(input bit [4:0] address, input bit [31:0] data);
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

  task automatic csr_write_three_adjacent(
    input bit [4:0]  address0,
    input bit [31:0] data0,
    input bit [4:0]  address1,
    input bit [31:0] data1,
    input bit [4:0]  address2,
    input bit [31:0] data2
  );
    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.address      <= address0;
    cfg.csr_vif.writedata    <= data0;
    cfg.csr_vif.write        <= 1'b1;
    cfg.csr_vif.read         <= 1'b0;

    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.address      <= address1;
    cfg.csr_vif.writedata    <= data1;

    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.address      <= address2;
    cfg.csr_vif.writedata    <= data2;

    @(posedge cfg.reset_vif.clk);
    cfg.csr_vif.write        <= 1'b0;
    cfg.csr_vif.address      <= 5'd0;
    cfg.csr_vif.writedata    <= 32'd0;
  endtask

  task automatic preload_counter(input bit [4:0] addr_lo, input bit [63:0] value);
    uvm_hdl_data_t hdl_value;
    string         hdl_path;

    hdl_value       = '0;
    hdl_value[63:0] = value;
    case (addr_lo)
      ARB_REG_INGRESS_REAL_HITS_L_ADDR:   hdl_path = "tb_top.dut.u_csr.csr.ingress_real_hits";
      ARB_REG_INGRESS_EMU_HITS_L_ADDR:    hdl_path = "tb_top.dut.u_csr.csr.ingress_emu_hits";
      ARB_REG_DROPS_REAL_L_ADDR:          hdl_path = "tb_top.dut.u_csr.csr.drops_real";
      ARB_REG_DROPS_EMU_L_ADDR:           hdl_path = "tb_top.dut.u_csr.csr.drops_emu";
      ARB_REG_EGRESS_REAL_HITS_L_ADDR:    hdl_path = "tb_top.dut.u_csr.csr.egress_real_hits";
      ARB_REG_EGRESS_EMU_HITS_L_ADDR:     hdl_path = "tb_top.dut.u_csr.csr.egress_emu_hits";
      ARB_REG_INGRESS_REAL_FRAMES_L_ADDR: hdl_path = "tb_top.dut.u_csr.csr.ingress_real_frames";
      ARB_REG_INGRESS_EMU_FRAMES_L_ADDR:  hdl_path = "tb_top.dut.u_csr.csr.ingress_emu_frames";
      ARB_REG_EGRESS_REAL_FRAMES_L_ADDR:  hdl_path = "tb_top.dut.u_csr.csr.egress_real_frames";
      ARB_REG_EGRESS_EMU_FRAMES_L_ADDR:   hdl_path = "tb_top.dut.u_csr.csr.egress_emu_frames";
      default:                            hdl_path = "";
    endcase

    if (hdl_path == "") begin
      `uvm_error(get_type_name(), $sformatf("Unsupported counter preload addr=0x%02h", addr_lo))
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

  task automatic preload_error_state();
    uvm_hdl_data_t hdl_value;

    hdl_value       = '0;
    hdl_value[31:0] = 32'd5;
    if (!uvm_hdl_deposit("tb_top.dut.u_csr.csr.error_count_protocol", hdl_value)) begin
      `uvm_error(get_type_name(), "failed to preload error_count_protocol")
    end
    hdl_value[31:0] = 32'd7;
    if (!uvm_hdl_deposit("tb_top.dut.u_csr.csr.error_count_drop_mid_packet", hdl_value)) begin
      `uvm_error(get_type_name(), "failed to preload error_count_drop_mid_packet")
    end
    hdl_value[31:0] = 32'h0000_1234;
    if (!uvm_hdl_deposit("tb_top.dut.u_csr.csr.syndrome_protocol", hdl_value)) begin
      `uvm_error(get_type_name(), "failed to preload syndrome_protocol")
    end
    hdl_value[31:0] = 32'h0000_5678;
    if (!uvm_hdl_deposit("tb_top.dut.u_csr.csr.syndrome_drop_mid_packet", hdl_value)) begin
      `uvm_error(get_type_name(), "failed to preload syndrome_drop_mid_packet")
    end
    if (scoreboard != null) begin
      scoreboard.error_count_protocol        = 32'd5;
      scoreboard.error_count_drop_mid_packet = 32'd7;
      scoreboard.syndrome_protocol           = 32'h0000_1234;
      scoreboard.syndrome_drop_mid_packet    = 32'h0000_5678;
    end
    wait_cycles(1);
  endtask

  task automatic check_all_counter_pairs_zero(input string label_text);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd0, {label_text, " ingress real hits"});
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd0, {label_text, " ingress emu hits"});
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, {label_text, " drops real"});
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd0, {label_text, " drops emu"});
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd0, {label_text, " egress real hits"});
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd0, {label_text, " egress emu hits"});
    expect_counter(ARB_REG_INGRESS_REAL_FRAMES_L_ADDR, 64'd0, {label_text, " ingress real frames"});
    expect_counter(ARB_REG_INGRESS_EMU_FRAMES_L_ADDR, 64'd0, {label_text, " ingress emu frames"});
    expect_counter(ARB_REG_EGRESS_REAL_FRAMES_L_ADDR, 64'd0, {label_text, " egress real frames"});
    expect_counter(ARB_REG_EGRESS_EMU_FRAMES_L_ADDR, 64'd0, {label_text, " egress emu frames"});
  endtask

  task automatic case_B001_uid_read();
    drive_all_idle();
    expect_csr32(ARB_REG_UID_ADDR, ARB_UID_CONST, "B001 UID");
    check_no_egress(8, "B001 idle output");
  endtask

  task automatic case_B002_uid_write_ignored();
    bit [31:0] uid_v;

    csr_read(ARB_REG_UID_ADDR, uid_v);
    expect32("B002 UID before write", uid_v, ARB_UID_CONST);
    csr_write(ARB_REG_UID_ADDR, 32'hDEAD_BEEF);
    csr_read(ARB_REG_UID_ADDR, uid_v);
    expect32("B002 UID after write", uid_v, ARB_UID_CONST);
  endtask

  task automatic case_B003_meta_versioning();
    bit [31:0] expected_v;
    bit [31:0] data_v;

    for (int unsigned sel = 0; sel < 4; sel++) begin
      csr_write(ARB_REG_META_ADDR, 32'(sel));
      csr_read(ARB_REG_META_ADDR, data_v);
      case (sel)
        0:       expected_v = ARB_VERSION_WORD_CONST;
        1:       expected_v = ARB_DATE_WORD_CONST;
        2:       expected_v = ARB_GIT_WORD_CONST;
        default: expected_v = ARB_INSTANCE_ID_WORD_CONST;
      endcase
      expect32($sformatf("B003 META sel %0d", sel), data_v, expected_v);
    end
  endtask

  task automatic case_B004_default_mode_real();
    bit [31:0] expected_v;

    expected_v      = 32'd0;
    expected_v[8]   = 1'b1;
    expected_v[10]  = 1'b1;
    expect_status_mask(
      STATUS_MODE_PENDING_MASK_CONST |
      STATUS_OPEN_MASK_CONST |
      STATUS_REAL_FULL_MASK_CONST |
      STATUS_REAL_EMPTY_MASK_CONST |
      STATUS_EMU_FULL_MASK_CONST |
      STATUS_EMU_EMPTY_MASK_CONST |
      STATUS_LAST_GRANT_MASK_CONST,
      expected_v,
      "B004 reset STATUS"
    );
  endtask

  task automatic case_B005_set_mode_emu();
    set_mode(ARB_MODE_EMU_CONST);
    expect_status_mode(ARB_MODE_EMU_CONST, "B005 EMU mode");
  endtask

  task automatic case_B006_set_mode_mix_rr();
    set_mode(ARB_MODE_MIX_RR_CONST);
    expect_status_mode(ARB_MODE_MIX_RR_CONST, "B006 MIX_RR mode");
  endtask

  task automatic case_B007_real_only_drain();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    fork
      drive_source_packet(1'b0, 0, 4, 4'h0, 3'd1, 45'h0000_0001_0000);
      drive_source_packet(1'b1, 0, 4, 4'h8, 3'd2, 45'h0000_0002_0000);
      wait_egress_count(4, 96, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    if ((sop_v != 1) || (eop_v != 1) || (channel_mask_v != 16'h0001)) begin
      `uvm_error(get_type_name(), $sformatf("B007 REAL egress shape/channel mismatch mask=0x%04h", channel_mask_v))
    end
    check_no_egress(16, "B007 emu blocked in REAL mode");
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd4, "B007 ingress real hits");
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd4, "B007 ingress emu hits");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd4, "B007 egress real hits");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd0, "B007 egress emu hits");
    expect_status_mask(STATUS_EMU_EMPTY_MASK_CONST, 32'd0, "B007 emu FIFO retained");
  endtask

  task automatic case_B008_emu_only_drain();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    set_mode(ARB_MODE_EMU_CONST);
    fork
      drive_source_packet(1'b0, 0, 4, 4'h0, 3'd1, 45'h0000_0003_0000);
      drive_source_packet(1'b1, 0, 4, 4'h8, 3'd2, 45'h0000_0004_0000);
      wait_egress_count(4, 96, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    if ((sop_v != 1) || (eop_v != 1) || (channel_mask_v != 16'h0100)) begin
      `uvm_error(get_type_name(), $sformatf("B008 EMU egress shape/channel mismatch mask=0x%04h", channel_mask_v))
    end
    check_no_egress(16, "B008 real blocked in EMU mode");
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd4, "B008 ingress real hits");
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd4, "B008 ingress emu hits");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd0, "B008 egress real hits");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd4, "B008 egress emu hits");
    expect_status_mask(STATUS_REAL_EMPTY_MASK_CONST, 32'd0, "B008 real FIFO retained");
  endtask

  task automatic case_B009_mix_rr_merged_packet_alternation();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_packet(1'b0, 0, 4, 4'h0, 3'd1, 45'h0000_0005_0000);
      drive_source_packet(1'b1, 0, 2, 4'h8, 3'd2, 45'h0000_0006_0000);
      wait_egress_count(6, 128, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    if ((beats_v != 6) || (sop_v != 1) || (eop_v != 1) || (eor_v != 0) || ((channel_mask_v & 16'h0101) != 16'h0101)) begin
      `uvm_error(get_type_name(), $sformatf("B009 merged RR mismatch beats=%0d sop=%0d eop=%0d mask=0x%04h", beats_v, sop_v, eop_v, channel_mask_v))
    end
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd4, "B009 ingress real hits");
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd2, "B009 ingress emu hits");
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd4, "B009 egress real hits");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd2, "B009 egress emu hits");
  endtask

  task automatic case_B010_mix_rr_single_beat_absorbed();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      begin
        drive_source_packet(1'b0, 0, 1, 4'h0, 3'd0, 45'h0000_0007_0000, 1'b0, 1'b1);
        wait_cycles(4);
        drive_source_packet_tail(1'b0, 0, 5, 4'h0, 3'd0, 45'h0000_0007_0001);
      end
      drive_source_packet(1'b1, 4, 1, 4'h8, 3'd0, 45'h0000_0008_0000);
      wait_egress_count(7, 160, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    if ((sop_v != 1) || (eop_v != 1) || ((channel_mask_v & 16'h0100) == 0)) begin
      `uvm_error(get_type_name(), $sformatf("B010 absorbed singleton mismatch sop=%0d eop=%0d mask=0x%04h", sop_v, eop_v, channel_mask_v))
    end
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd1, "B010 ingress emu singleton");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd1, "B010 egress emu singleton");
  endtask

  task automatic case_B011_mix_rr_single_beat_both_idle();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    drive_single_beat(1'b0, 45'h0000_0009_0000, 3'd0, 4'h0);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    if ((sop_v != 1) || (eop_v != 1) || (last_data_v != 45'h0000_0009_0000)) begin
      `uvm_error(get_type_name(), "B011 single-beat idle packet mismatch")
    end
    expect_status_mask(STATUS_OPEN_MASK_CONST, 32'd0, "B011 merged open returned idle");
  endtask

  task automatic case_B012_switch_at_idle();
    set_mode(ARB_MODE_EMU_CONST);
    expect_status_mode(ARB_MODE_EMU_CONST, "B012 idle switch to EMU");
    set_mode(ARB_MODE_MIX_RR_CONST);
    expect_status_mode(ARB_MODE_MIX_RR_CONST, "B012 idle switch to MIX_RR");
    set_mode(ARB_MODE_REAL_CONST);
    expect_status_mode(ARB_MODE_REAL_CONST, "B012 idle switch back to REAL");
  endtask

  task automatic case_B013_switch_during_packet_defers();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;
    bit [31:0]  expected_v;
    event        two_beats_seen_ev;

    fork
      drive_source_packet(1'b0, 0, 6, 4'h0, 3'd0, 45'h0000_000A_0000);
      begin
        wait_egress_count(2, 96, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
        -> two_beats_seen_ev;
        wait_egress_count(4, 128, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
      end
      begin
        @two_beats_seen_ev;
        csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_EMU_CONST));
        expected_v      = 32'd0;
        expected_v[1:0] = ARB_MODE_REAL_CONST;
        expected_v[3:2] = ARB_MODE_EMU_CONST;
        expected_v[4]   = 1'b1;
        expected_v[5]   = 1'b1;
        expect_status_mask_unchecked(
          STATUS_MODE_PENDING_MASK_CONST | STATUS_OPEN_MASK_CONST,
          expected_v,
          "B013 deferred mode pending"
        );
      end
    join
    wait_cycles(8);
    expect_status_mode(ARB_MODE_EMU_CONST, "B013 committed after EOP");
    drive_single_beat(1'b1, 45'h0000_000A_0800, 3'd0, 4'h8);
    wait_egress_simple(1, 64);
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd1, "B013 post-switch emu egress");
  endtask

  task automatic case_B014_switch_back_to_back();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;
    event        first_pair_seen_ev;
    event        second_pair_seen_ev;

    fork
      drive_source_packet(1'b0, 0, 8, 4'h0, 3'd0, 45'h0000_000B_0000);
      begin
        wait_egress_count(2, 96, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
        -> first_pair_seen_ev;
        wait_egress_count(2, 96, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
        -> second_pair_seen_ev;
        wait_egress_count(4, 128, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
      end
      begin
        @first_pair_seen_ev;
        csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_EMU_CONST));
        @second_pair_seen_ev;
        csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
      end
    join
    wait_cycles(8);
    expect_status_mode(ARB_MODE_MIX_RR_CONST, "B014 latest pending mode committed");
    fork
      drive_single_beat(1'b0, 45'h0000_000B_0100, 3'd0, 4'h0);
      drive_single_beat(1'b1, 45'h0000_000B_0800, 3'd0, 4'h8);
      wait_egress_simple(2, 80);
    join
  endtask

  task automatic case_B015_switch_mix_rr_to_real_drains_outstanding_emu();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;
    event        two_beats_seen_ev;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      drive_source_packet(1'b0, 0, 4, 4'h0, 3'd0, 45'h0000_000C_0000);
      drive_source_packet(1'b1, 0, 4, 4'h8, 3'd0, 45'h0000_000C_0800);
      begin
        wait_egress_count(2, 96, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
        -> two_beats_seen_ev;
        wait_egress_count(6, 160, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
      end
      begin
        @two_beats_seen_ev;
        csr_write_direct(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST));
      end
    join
    wait_cycles(8);
    expect_status_mode(ARB_MODE_REAL_CONST, "B015 mode committed after both packets closed");
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd4, "B015 outstanding emu drained");
    fork
      drive_single_beat(1'b0, 45'h0000_000C_0100, 3'd0, 4'h0);
      drive_single_beat(1'b1, 45'h0000_000C_0900, 3'd0, 4'h8);
      wait_egress_simple(1, 64);
    join
    check_no_egress(12, "B015 emu blocked after REAL commit");
  endtask

  task automatic case_B016_real_fifo_fill_drain();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    set_mode(ARB_MODE_EMU_CONST);
    drive_source_singletons(1'b0, 0, 16, 4'h0, 3'd0, 45'h0000_000D_0000);
    wait_cycles(4);
    expect_status_mask(STATUS_REAL_FULL_MASK_CONST, STATUS_REAL_FULL_MASK_CONST, "B016 real FIFO full");
    fork
      csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST));
      wait_egress_count(16, 192, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    wait_cycles(4);
    expect_status_mask(STATUS_REAL_EMPTY_MASK_CONST, STATUS_REAL_EMPTY_MASK_CONST, "B016 real FIFO empty");
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd0, "B016 real drops");
  endtask

  task automatic case_B017_emu_fifo_fill_drain();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    drive_source_singletons(1'b1, 0, 16, 4'h8, 3'd0, 45'h0000_000E_0800);
    wait_cycles(4);
    expect_status_mask(STATUS_EMU_FULL_MASK_CONST, STATUS_EMU_FULL_MASK_CONST, "B017 emu FIFO full");
    fork
      csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_EMU_CONST));
      wait_egress_count(16, 192, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    wait_cycles(4);
    expect_status_mask(STATUS_EMU_EMPTY_MASK_CONST, STATUS_EMU_EMPTY_MASK_CONST, "B017 emu FIFO empty");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd0, "B017 emu drops");
  endtask

  task automatic case_B018_idle_does_not_consume();
    drive_valid_low_beat(1'b0, 45'h0000_000F_0000, 3'd7, 4'h0);
    drive_valid_low_beat(1'b1, 45'h0000_000F_0800, 3'd7, 4'h8);
    wait_cycles(12);
    check_no_egress(8, "B018 valid-low beats");
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd0, "B018 ingress real");
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd0, "B018 ingress emu");
  endtask

  task automatic case_B019_ingress_real_hit_counter();
    for (int unsigned frame = 0; frame < 10; frame++) begin
      drive_source_packet(1'b0, 0, 10, 4'h1, 3'd0, 45'h0000_0010_0000 + (45'(frame) << 8));
    end
    wait_cycles(64);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd100, "B019 ingress real hits");
  endtask

  task automatic case_B020_ingress_emu_hit_counter();
    set_mode(ARB_MODE_EMU_CONST);
    for (int unsigned frame = 0; frame < 10; frame++) begin
      drive_source_packet(1'b1, 0, 10, 4'h8, 3'd0, 45'h0000_0011_0000 + (45'(frame) << 8));
    end
    wait_cycles(64);
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd100, "B020 ingress emu hits");
  endtask

  task automatic case_B021_drop_real_counter();
    set_mode(ARB_MODE_EMU_CONST);
    drive_source_singletons(1'b0, 0, 17, 4'h0, 3'd0, 45'h0000_0012_0000);
    wait_cycles(12);
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd16, "B021 accepted real hits");
    expect_counter(ARB_REG_DROPS_REAL_L_ADDR, 64'd1, "B021 real drop count");
  endtask

  task automatic case_B022_drop_emu_counter();
    drive_source_singletons(1'b1, 0, 17, 4'h8, 3'd0, 45'h0000_0013_0800);
    wait_cycles(12);
    expect_counter(ARB_REG_INGRESS_EMU_HITS_L_ADDR, 64'd16, "B022 accepted emu hits");
    expect_counter(ARB_REG_DROPS_EMU_L_ADDR, 64'd1, "B022 emu drop count");
  endtask

  task automatic case_B023_egress_real_counter();
    fork
      drive_source_packet(1'b0, 0, 9, 4'h2, 3'd0, 45'h0000_0014_0000);
      wait_egress_simple(9, 128);
    join
    expect_counter(ARB_REG_EGRESS_REAL_HITS_L_ADDR, 64'd9, "B023 egress real hits");
  endtask

  task automatic case_B024_egress_emu_counter();
    set_mode(ARB_MODE_EMU_CONST);
    fork
      drive_source_packet(1'b1, 0, 9, 4'h8, 3'd0, 45'h0000_0015_0800);
      wait_egress_simple(9, 128);
    join
    expect_counter(ARB_REG_EGRESS_EMU_HITS_L_ADDR, 64'd9, "B024 egress emu hits");
  endtask

  task automatic case_B025_low_high_pair_atomicity();
    bit [31:0] lo_v;
    bit [31:0] hi_v;

    preload_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'h0000_0002_FFFF_FFF0);
    csr_read(ARB_REG_INGRESS_REAL_HITS_L_ADDR, lo_v);
    expect32("B025 low word snapshot", lo_v, 32'hFFFF_FFF0);
    drive_source_singletons(1'b0, 0, 20, 4'h0, 3'd0, 45'h0000_0016_0000);
    wait_cycles(24);
    csr_read(ARB_REG_INGRESS_REAL_HITS_H_ADDR, hi_v);
    expect32("B025 high word stayed latched", hi_v, 32'h0000_0002);
  endtask

  task automatic case_B026_w1p_clear_counters();
    fork
      drive_source_packet(1'b0, 0, 5, 4'h0, 3'd0, 45'h0000_0017_0000);
      wait_egress_simple(5, 96);
    join
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd5, "B026 pre-clear ingress");
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST, 1'b1));
    wait_cycles(4);
    check_all_counter_pairs_zero("B026 W1P clear");
    expect_status_mode(ARB_MODE_REAL_CONST, "B026 mode preserved");
  endtask

  task automatic case_B027_csr_back_to_back_writes();
    bit [31:0] control_v;

    csr_write_three_adjacent(
      ARB_REG_META_ADDR,
      32'd1,
      ARB_REG_WATCHDOG_ADDR,
      32'd37,
      ARB_REG_CONTROL_ADDR,
      arb_control_word(ARB_MODE_MIX_RR_CONST)
    );
    wait_cycles(4);
    expect_csr32(ARB_REG_META_ADDR, ARB_DATE_WORD_CONST, "B027 META adjacent write");
    expect_csr32(ARB_REG_WATCHDOG_ADDR, 32'd37, "B027 WATCHDOG adjacent write");
    csr_read(ARB_REG_CONTROL_ADDR, control_v);
    if (control_v[1:0] != ARB_MODE_MIX_RR_CONST) begin
      `uvm_error(get_type_name(), $sformatf("B027 CONTROL adjacent write mismatch 0x%08h", control_v))
    end
  endtask

  task automatic case_B028_channel_convention();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;

    set_mode(ARB_MODE_MIX_RR_CONST);
    fork
      begin
        drive_single_beat(1'b0, 45'h0000_0018_0000, 3'd0, 4'h0);
        drive_single_beat(1'b0, 45'h0000_0018_0003, 3'd0, 4'h3);
        drive_single_beat(1'b0, 45'h0000_0018_0007, 3'd0, 4'h7);
      end
      begin
        drive_single_beat(1'b1, 45'h0000_0018_0808, 3'd0, 4'h8);
        drive_single_beat(1'b1, 45'h0000_0018_080B, 3'd0, 4'hB);
        drive_single_beat(1'b1, 45'h0000_0018_080F, 3'd0, 4'hF);
      end
      wait_egress_count(6, 160, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    join
    if (channel_mask_v != 16'h8989) begin
      `uvm_error(get_type_name(), $sformatf("B028 channel histogram mismatch observed=0x%04h", channel_mask_v))
    end
  endtask

  task automatic case_B029_watchdog_threshold_default();
    expect_csr32(ARB_REG_WATCHDOG_ADDR, 32'd500, "B029 watchdog default");
  endtask

  task automatic case_B030_run_control_run_prep_resets_state();
    int unsigned beats_v;
    int unsigned sop_v;
    int unsigned eop_v;
    int unsigned eor_v;
    bit [44:0]  first_data_v;
    bit [44:0]  last_data_v;
    bit [2:0]   last_error_v;
    bit [3:0]   last_channel_v;
    bit [15:0]  channel_mask_v;
    bit [31:0]  expected_v;

    drive_source_packet(1'b0, 0, 1, 4'h0, 3'd0, 45'h0000_0019_0000, 1'b0, 1'b1);
    wait_egress_count(1, 64, beats_v, sop_v, eop_v, eor_v, first_data_v, last_data_v, last_error_v, last_channel_v, channel_mask_v);
    if ((sop_v != 1) || (eop_v != 0)) begin
      `uvm_error(get_type_name(), "B030 pre-RUN_PREP packet was not open")
    end
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd1, "B030 pre-RUN_PREP ingress");
    send_runctl(runctl_seq_item::RUN_PREPARING_WORD_CONST);
    wait_cycles(10);
    expected_v      = 32'd0;
    expected_v[8]   = 1'b1;
    expected_v[10]  = 1'b1;
    expect_status_mask(
      STATUS_MODE_PENDING_MASK_CONST |
      STATUS_OPEN_MASK_CONST |
      STATUS_REAL_EMPTY_MASK_CONST |
      STATUS_EMU_EMPTY_MASK_CONST,
      expected_v,
      "B030 RUN_PREP cleared stream state"
    );
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd1, "B030 RUN_PREP preserved counters");
    check_no_egress(8, "B030 no packet leak after RUN_PREP");
  endtask

  task automatic case_B031_run_control_reset_clears_counters();
    fork
      drive_source_packet(1'b0, 0, 3, 4'h0, 3'd0, 45'h0000_001A_0000);
      wait_egress_simple(3, 96);
    join
    preload_error_state();
    expect_counter(ARB_REG_INGRESS_REAL_HITS_L_ADDR, 64'd3, "B031 pre-RESET ingress");
    send_runctl(runctl_seq_item::RUN_RESETTING_WORD_CONST);
    wait_cycles(10);
    check_all_counter_pairs_zero("B031 RUN_RESET");
    expect_csr32(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, 32'd0, "B031 protocol errors cleared");
    expect_csr32(ARB_REG_ERROR_COUNT_DROP_MID_ADDR, 32'd0, "B031 drop-mid errors cleared");
    expect_csr32(ARB_REG_SYNDROME_PROTOCOL_ADDR, 32'd0, "B031 protocol syndrome cleared");
    expect_csr32(ARB_REG_SYNDROME_DROP_MID_ADDR, 32'd0, "B031 drop syndrome cleared");
  endtask

  task automatic case_B032_frame_counters_native_eop();
    fork
      begin
        drive_source_packet(1'b0, 0, 1, 4'h0, 3'd0, 45'h0000_001B_0000);
        drive_source_packet(1'b0, 0, 2, 4'h1, 3'd0, 45'h0000_001B_0100);
        drive_source_packet(1'b0, 0, 3, 4'h2, 3'd0, 45'h0000_001B_0200);
      end
      wait_egress_simple(6, 160);
    join
    set_mode(ARB_MODE_EMU_CONST);
    fork
      begin
        drive_source_packet(1'b1, 0, 1, 4'h8, 3'd0, 45'h0000_001B_0800);
        drive_source_packet(1'b1, 0, 4, 4'h9, 3'd0, 45'h0000_001B_0900);
      end
      wait_egress_simple(5, 160);
    join
    expect_counter(ARB_REG_INGRESS_REAL_FRAMES_L_ADDR, 64'd3, "B032 ingress real frames");
    expect_counter(ARB_REG_EGRESS_REAL_FRAMES_L_ADDR, 64'd3, "B032 egress real frames");
    expect_counter(ARB_REG_INGRESS_EMU_FRAMES_L_ADDR, 64'd2, "B032 ingress emu frames");
    expect_counter(ARB_REG_EGRESS_EMU_FRAMES_L_ADDR, 64'd2, "B032 egress emu frames");
  endtask
endclass

class B000_basic_base_test extends arb_hit_type0_base_test;
  `uvm_component_utils(B000_basic_base_test)

  function new(string name = "B000_basic_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task automatic run_basic_sequence(uvm_phase phase, B000_basic_base_seq seq_h);
    phase.raise_objection(this);
    wait_reset_release();
    seq_h.start(env.vseqr);
    repeat (40) @(cfg.reset_vif.mon_cb);
    if (env.scoreboard != null) begin
      env.scoreboard.check_counter_consistency();
    end
    `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

endpackage
