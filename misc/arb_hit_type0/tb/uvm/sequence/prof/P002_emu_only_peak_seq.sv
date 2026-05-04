class P002_emu_only_peak_seq extends prof_direct_seq_base;
  `uvm_object_utils(P002_emu_only_peak_seq)

  localparam int unsigned BEAT_COUNT_CONST  = 100000;
  localparam int unsigned PACKET_LEN_CONST  = 4;
  localparam int unsigned FRAME_COUNT_CONST = BEAT_COUNT_CONST / PACKET_LEN_CONST;

  function new(string name = "P002_emu_only_peak_seq");
    super.new(name);
  endfunction

  task body();
    bit [63:0] ingress_real_hits_v;
    bit [63:0] ingress_emu_hits_v;
    bit [63:0] drops_real_v;
    bit [63:0] drops_emu_v;
    bit [63:0] egress_real_hits_v;
    bit [63:0] egress_emu_hits_v;
    bit [63:0] ingress_real_frames_v;
    bit [63:0] ingress_emu_frames_v;
    bit [63:0] egress_real_frames_v;
    bit [63:0] egress_emu_frames_v;

    init_case(32'h0020_0002);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_EMU_CONST));
    wait_cycles(8);
    drive_packet_train(1'b1, BEAT_COUNT_CONST, PACKET_LEN_CONST);
    wait_cycles(128);

    read_hit_drop_counters(
      ingress_real_hits_v,
      ingress_emu_hits_v,
      drops_real_v,
      drops_emu_v,
      egress_real_hits_v,
      egress_emu_hits_v
    );
    read_frame_counters(
      ingress_real_frames_v,
      ingress_emu_frames_v,
      egress_real_frames_v,
      egress_emu_frames_v
    );

    expect64("INGRESS_EMU_HITS", ingress_emu_hits_v, BEAT_COUNT_CONST);
    expect64("EGRESS_EMU_HITS", egress_emu_hits_v, BEAT_COUNT_CONST);
    expect64("INGRESS_EMU_FRAMES", ingress_emu_frames_v, FRAME_COUNT_CONST);
    expect64("EGRESS_EMU_FRAMES", egress_emu_frames_v, FRAME_COUNT_CONST);
    expect_zero64("INGRESS_REAL_HITS", ingress_real_hits_v);
    expect_zero64("EGRESS_REAL_HITS", egress_real_hits_v);
    expect_zero64("INGRESS_REAL_FRAMES", ingress_real_frames_v);
    expect_zero64("EGRESS_REAL_FRAMES", egress_real_frames_v);
    expect_zero64("DROPS_REAL", drops_real_v);
    expect_zero64("DROPS_EMU", drops_emu_v);
    check_status_clean();
  endtask
endclass
