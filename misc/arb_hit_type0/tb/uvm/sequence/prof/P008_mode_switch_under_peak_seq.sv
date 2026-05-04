class P008_mode_switch_under_peak_seq extends prof_direct_seq_base;
  `uvm_object_utils(P008_mode_switch_under_peak_seq)

  localparam int unsigned SWITCH_COUNT_CONST     = 80;
  localparam int unsigned SWITCH_PERIOD_CONST    = 1000;

  function new(string name = "P008_mode_switch_under_peak_seq");
    super.new(name);
  endfunction

  task automatic next_switch_mode(input int unsigned switch_idx, output bit [1:0] mode);
    case (switch_idx % 3)
      0:       mode = ARB_MODE_REAL_CONST;
      1:       mode = ARB_MODE_EMU_CONST;
      default: mode = ARB_MODE_MIX_RR_CONST;
    endcase
  endtask

  task automatic drive_mode_segment(
    input bit [1:0]     mode,
    input int unsigned  cycles,
    ref int unsigned    real_idx,
    ref int unsigned    emu_idx
  );
    for (int unsigned cycle_idx = 0; cycle_idx < cycles; cycle_idx++) begin
      bit       pattern_hit_v;
      bit       real_fire_v;
      bit       emu_fire_v;
      bit [3:0] real_channel_v;
      bit [3:0] emu_channel_v;

      pattern_hit_v  = ((cycle_idx % 7) == 0) || ((cycle_idx % 7) == 3);
      real_fire_v    = pattern_hit_v &&
                       ((mode == ARB_MODE_REAL_CONST) || (mode == ARB_MODE_MIX_RR_CONST));
      emu_fire_v     = pattern_hit_v &&
                       ((mode == ARB_MODE_EMU_CONST) || (mode == ARB_MODE_MIX_RR_CONST));
      real_channel_v = source_channel(1'b0, real_idx);
      emu_channel_v  = source_channel(1'b1, emu_idx);

      @(posedge cfg.reset_vif.clk);
      cfg.real_vif.valid      <= real_fire_v;
      cfg.real_vif.data       <= make_data(1'b0, real_idx, real_channel_v);
      cfg.real_vif.error      <= 3'd0;
      cfg.real_vif.channel    <= real_channel_v;
      cfg.real_vif.sop        <= real_fire_v;
      cfg.real_vif.eop        <= real_fire_v;
      cfg.real_vif.eor        <= 1'b0;
      cfg.emu_vif.valid       <= emu_fire_v;
      cfg.emu_vif.data        <= make_data(1'b1, emu_idx, emu_channel_v);
      cfg.emu_vif.error       <= 3'd0;
      cfg.emu_vif.channel     <= emu_channel_v;
      cfg.emu_vif.sop         <= emu_fire_v;
      cfg.emu_vif.eop         <= emu_fire_v;
      cfg.emu_vif.eor         <= 1'b0;

      if (real_fire_v) begin
        real_idx++;
      end
      if (emu_fire_v) begin
        emu_idx++;
      end
    end
    @(posedge cfg.reset_vif.clk);
    set_all_idle();
  endtask

  task automatic switch_modes_under_load();
    bit [1:0] mode_v;
    int unsigned real_idx_v;
    int unsigned emu_idx_v;

    real_idx_v = 0;
    emu_idx_v  = 0;
    for (int unsigned switch_idx = 0; switch_idx < SWITCH_COUNT_CONST; switch_idx++) begin
      next_switch_mode(switch_idx, mode_v);
      csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(mode_v));
      wait_cycles(4);
      drive_mode_segment(mode_v, SWITCH_PERIOD_CONST, real_idx_v, emu_idx_v);
    end
  endtask

  task body();
    bit [63:0] ingress_real_hits_v;
    bit [63:0] ingress_emu_hits_v;
    bit [63:0] drops_real_v;
    bit [63:0] drops_emu_v;
    bit [63:0] egress_real_hits_v;
    bit [63:0] egress_emu_hits_v;

    init_case(32'h0080_0008);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(8);

    switch_modes_under_load();

    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(2048);
    read_hit_drop_counters(
      ingress_real_hits_v,
      ingress_emu_hits_v,
      drops_real_v,
      drops_emu_v,
      egress_real_hits_v,
      egress_emu_hits_v
    );

    expect64("accepted real hits drain after mode switches", egress_real_hits_v, ingress_real_hits_v);
    expect64("accepted emu hits drain after mode switches", egress_emu_hits_v, ingress_emu_hits_v);
    expect_zero64("DROPS_REAL", drops_real_v);
    expect_zero64("DROPS_EMU", drops_emu_v);
    check_status_clean();
  endtask
endclass
