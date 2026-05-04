class P003_mix_rr_peak_seq extends prof_direct_seq_base;
  `uvm_object_utils(P003_mix_rr_peak_seq)

  localparam int unsigned BEATS_PER_SOURCE_CONST = 20000;

  function new(string name = "P003_mix_rr_peak_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] ingress_real_hits_v;
    bit [63:0] ingress_emu_hits_v;
    bit [63:0] drops_real_v;
    bit [63:0] drops_emu_v;
    bit [63:0] egress_real_hits_v;
    bit [63:0] egress_emu_hits_v;

    init_case(32'h0030_0003);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(8);

    fork
      drive_periodic_hits(1'b0, BEATS_PER_SOURCE_CONST, 0);
      drive_periodic_hits(1'b1, BEATS_PER_SOURCE_CONST, 0);
    join

    wait_cycles(256);
    read_hit_drop_counters(
      ingress_real_hits_v,
      ingress_emu_hits_v,
      drops_real_v,
      drops_emu_v,
      egress_real_hits_v,
      egress_emu_hits_v
    );

    expect64("INGRESS_REAL_HITS", ingress_real_hits_v, BEATS_PER_SOURCE_CONST);
    expect64("INGRESS_EMU_HITS", ingress_emu_hits_v, BEATS_PER_SOURCE_CONST);
    expect64("EGRESS_REAL_HITS", egress_real_hits_v, BEATS_PER_SOURCE_CONST);
    expect64("EGRESS_EMU_HITS", egress_emu_hits_v, BEATS_PER_SOURCE_CONST);
    expect_zero64("DROPS_REAL", drops_real_v);
    expect_zero64("DROPS_EMU", drops_emu_v);
    check_status_clean();
  endtask
endclass
