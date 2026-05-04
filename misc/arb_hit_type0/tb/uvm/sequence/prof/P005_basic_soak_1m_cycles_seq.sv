class P005_basic_soak_1m_cycles_seq extends prof_direct_seq_base;
  `uvm_object_utils(P005_basic_soak_1m_cycles_seq)

  localparam int unsigned SOAK_CYCLES_CONST = 1000000;
  localparam int unsigned RATE_DIV_CONST    = 8;

  function new(string name = "P005_basic_soak_1m_cycles_seq");
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

    init_case(32'h0050_0005);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(8);
    drive_poisson_mixed(SOAK_CYCLES_CONST, RATE_DIV_CONST, real_expected_v, emu_expected_v);
    wait_cycles(512);

    read_hit_drop_counters(
      ingress_real_hits_v,
      ingress_emu_hits_v,
      drops_real_v,
      drops_emu_v,
      egress_real_hits_v,
      egress_emu_hits_v
    );

    expect64("INGRESS_REAL_HITS", ingress_real_hits_v, real_expected_v);
    expect64("INGRESS_EMU_HITS", ingress_emu_hits_v, emu_expected_v);
    expect64("EGRESS_REAL_HITS", egress_real_hits_v, real_expected_v);
    expect64("EGRESS_EMU_HITS", egress_emu_hits_v, emu_expected_v);
    expect_zero64("DROPS_REAL", drops_real_v);
    expect_zero64("DROPS_EMU", drops_emu_v);
    check_status_clean();
  endtask
endclass
