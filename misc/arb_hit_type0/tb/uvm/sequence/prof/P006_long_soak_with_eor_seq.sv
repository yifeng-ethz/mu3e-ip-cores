class P006_long_soak_with_eor_seq extends prof_direct_seq_base;
  `uvm_object_utils(P006_long_soak_with_eor_seq)

  localparam int unsigned SOAK_CYCLES_CONST = 1000000;
  localparam int unsigned RATE_DIV_CONST    = 8;

  function new(string name = "P006_long_soak_with_eor_seq");
    super.new(name);
  endfunction

  task body();
    longint unsigned real_expected_v;
    longint unsigned emu_expected_v;
    bit [63:0]       ingress_real_hits_v;
    bit [63:0]       ingress_emu_hits_v;
    bit [63:0]       drops_real_v;
    bit [63:0]       drops_emu_v;
    bit [63:0]       egress_real_hits_v;
    bit [63:0]       egress_emu_hits_v;
    bit [63:0]       egress_real_after_lock_v;
    bit [63:0]       egress_emu_after_lock_v;

    init_case(32'h0060_0006);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(8);
    drive_poisson_mixed(SOAK_CYCLES_CONST, RATE_DIV_CONST, real_expected_v, emu_expected_v);
    wait_cycles(64);

    drive_dual_single_beat(real_expected_v[31:0], emu_expected_v[31:0], 1'b1, 1'b1);
    real_expected_v++;
    emu_expected_v++;
    wait_cycles(64);

    read_hit_drop_counters(
      ingress_real_hits_v,
      ingress_emu_hits_v,
      drops_real_v,
      drops_emu_v,
      egress_real_hits_v,
      egress_emu_hits_v
    );

    expect64("INGRESS_REAL_HITS before lock probe", ingress_real_hits_v, real_expected_v);
    expect64("INGRESS_EMU_HITS before lock probe", ingress_emu_hits_v, emu_expected_v);
    expect64("EGRESS_REAL_HITS before lock probe", egress_real_hits_v, real_expected_v);
    expect64("EGRESS_EMU_HITS before lock probe", egress_emu_hits_v, emu_expected_v);
    expect_zero64("DROPS_REAL", drops_real_v);
    expect_zero64("DROPS_EMU", drops_emu_v);

    drive_dual_single_beat(real_expected_v[31:0], emu_expected_v[31:0], 1'b0, 1'b0);
    wait_cycles(64);

    csr_read_pair(ARB_REG_EGRESS_REAL_HITS_L_ADDR, egress_real_after_lock_v);
    csr_read_pair(ARB_REG_EGRESS_EMU_HITS_L_ADDR, egress_emu_after_lock_v);
    expect64("EGRESS_REAL_HITS after final EOR lock", egress_real_after_lock_v, egress_real_hits_v);
    expect64("EGRESS_EMU_HITS after final EOR lock", egress_emu_after_lock_v, egress_emu_hits_v);
  endtask
endclass
