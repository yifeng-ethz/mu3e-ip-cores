class P007_pair_read_under_traffic_seq extends prof_direct_seq_base;
  `uvm_object_utils(P007_pair_read_under_traffic_seq)

  localparam int unsigned BEATS_PER_SOURCE_CONST = 12000;

  function new(string name = "P007_pair_read_under_traffic_seq");
    super.new(name);
  endfunction

  task automatic read_every_pair_once();
    bit [63:0] data_v;

    direct_csr_read_pair_checked(ARB_REG_INGRESS_REAL_HITS_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_INGRESS_EMU_HITS_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_DROPS_REAL_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_DROPS_EMU_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_EGRESS_REAL_HITS_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_EGRESS_EMU_HITS_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_INGRESS_REAL_FRAMES_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_INGRESS_EMU_FRAMES_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_EGRESS_REAL_FRAMES_L_ADDR, data_v);
    direct_csr_read_pair_checked(ARB_REG_EGRESS_EMU_FRAMES_L_ADDR, data_v);
  endtask

  task body();
    bit [63:0] ingress_real_hits_v;
    bit [63:0] ingress_emu_hits_v;
    bit [63:0] drops_real_v;
    bit [63:0] drops_emu_v;
    bit [63:0] egress_real_hits_v;
    bit [63:0] egress_emu_hits_v;

    init_case(32'h0070_0007);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_MIX_RR_CONST));
    wait_cycles(8);

    fork
      drive_periodic_hits(1'b0, BEATS_PER_SOURCE_CONST, 0);
      drive_periodic_hits(1'b1, BEATS_PER_SOURCE_CONST, 0);
      begin
        for (int unsigned pass_idx = 0; pass_idx < 4; pass_idx++) begin
          wait_cycles(25 + rand_range(200));
          read_every_pair_once();
        end
      end
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
