class prof_direct_seq_base extends arb_hit_type0_base_vseq;
  `uvm_object_utils(prof_direct_seq_base)

  arb_hit_type0_env_cfg cfg;
  arb_hit_type0_scoreboard scoreboard;
  int unsigned          seed = 1;
  lcg_prng_state_t      prng;

  function new(string name = "prof_direct_seq_base");
    super.new(name);
  endfunction

  task body();
    `uvm_fatal(get_type_name(), "prof_direct_seq_base must not run directly")
  endtask

  function void init_case(input int unsigned seed_offset);
    if (cfg == null) begin
      `uvm_fatal(get_type_name(), "PROF sequence missing env cfg")
    end
    prng = lcg_init(seed + seed_offset);
  endfunction

  function bit [44:0] make_data(
    input bit          source_emu,
    input int unsigned beat_idx,
    input bit [3:0]    channel
  );
    bit [31:0] payload_v;

    payload_v = source_emu ? (32'hE000_0000 ^ beat_idx ^ seed) :
                             (32'h1000_0000 ^ beat_idx ^ seed);
    return {source_emu, channel, beat_idx[7:0], payload_v};
  endfunction

  function bit [3:0] source_channel(input bit source_emu, input int unsigned beat_idx);
    int unsigned lane_v;
    bit [3:0]    channel_v;

    lane_v = beat_idx % 8;
    if (source_emu) begin
      channel_v = 4'h8 + lane_v[3:0];
    end else begin
      channel_v = lane_v[3:0];
    end
    return channel_v;
  endfunction

  function int unsigned rand_range(input int unsigned limit);
    return lcg_range(prng, limit);
  endfunction

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) begin
      @(posedge cfg.reset_vif.clk);
    end
  endtask

  task automatic set_all_idle();
    cfg.real_vif.valid      <= 1'b0;
    cfg.real_vif.data       <= '0;
    cfg.real_vif.error      <= '0;
    cfg.real_vif.channel    <= '0;
    cfg.real_vif.sop        <= 1'b0;
    cfg.real_vif.eop        <= 1'b0;
    cfg.real_vif.eor        <= 1'b0;
    cfg.emu_vif.valid       <= 1'b0;
    cfg.emu_vif.data        <= '0;
    cfg.emu_vif.error       <= '0;
    cfg.emu_vif.channel     <= '0;
    cfg.emu_vif.sop         <= 1'b0;
    cfg.emu_vif.eop         <= 1'b0;
    cfg.emu_vif.eor         <= 1'b0;
  endtask

  task automatic drive_source_idle(input bit source_emu);
    if (source_emu) begin
      @(posedge cfg.emu_vif.clk);
      cfg.emu_vif.valid      <= 1'b0;
      cfg.emu_vif.data       <= '0;
      cfg.emu_vif.error      <= '0;
      cfg.emu_vif.channel    <= '0;
      cfg.emu_vif.sop        <= 1'b0;
      cfg.emu_vif.eop        <= 1'b0;
      cfg.emu_vif.eor        <= 1'b0;
    end else begin
      @(posedge cfg.real_vif.clk);
      cfg.real_vif.valid      <= 1'b0;
      cfg.real_vif.data       <= '0;
      cfg.real_vif.error      <= '0;
      cfg.real_vif.channel    <= '0;
      cfg.real_vif.sop        <= 1'b0;
      cfg.real_vif.eop        <= 1'b0;
      cfg.real_vif.eor        <= 1'b0;
    end
  endtask

  task automatic drive_source_beat(
    input bit          source_emu,
    input int unsigned beat_idx,
    input bit          sop,
    input bit          eop,
    input bit          eor
  );
    bit [3:0] channel_v;
    bit [44:0] data_v;

    channel_v = source_channel(source_emu, beat_idx);
    data_v    = make_data(source_emu, beat_idx, channel_v);
    if (source_emu) begin
      @(posedge cfg.emu_vif.clk);
      cfg.emu_vif.valid      <= 1'b1;
      cfg.emu_vif.data       <= data_v;
      cfg.emu_vif.error      <= 3'd0;
      cfg.emu_vif.channel    <= channel_v;
      cfg.emu_vif.sop        <= sop;
      cfg.emu_vif.eop        <= eop;
      cfg.emu_vif.eor        <= eor;
    end else begin
      @(posedge cfg.real_vif.clk);
      cfg.real_vif.valid      <= 1'b1;
      cfg.real_vif.data       <= data_v;
      cfg.real_vif.error      <= 3'd0;
      cfg.real_vif.channel    <= channel_v;
      cfg.real_vif.sop        <= sop;
      cfg.real_vif.eop        <= eop;
      cfg.real_vif.eor        <= eor;
    end
  endtask

  task automatic drive_packet_train(
    input bit          source_emu,
    input int unsigned beat_count,
    input int unsigned packet_len
  );
    for (int unsigned beat_idx = 0; beat_idx < beat_count; beat_idx++) begin
      drive_source_beat(
        source_emu,
        beat_idx,
        (beat_idx % packet_len) == 0,
        (beat_idx % packet_len) == (packet_len - 1),
        1'b0
      );
    end
    drive_source_idle(source_emu);
  endtask

  task automatic drive_periodic_hits(
    input bit          source_emu,
    input int unsigned beat_count,
    input int unsigned start_offset
  );
    for (int unsigned offset_idx = 0; offset_idx < start_offset; offset_idx++) begin
      drive_source_idle(source_emu);
    end

    for (int unsigned beat_idx = 0; beat_idx < beat_count; beat_idx++) begin
      int unsigned period_v;

      drive_source_beat(source_emu, beat_idx, 1'b1, 1'b1, 1'b0);
      period_v = (beat_idx[0] == 1'b0) ? 3 : 4;
      for (int unsigned idle_idx = 1; idle_idx < period_v; idle_idx++) begin
        drive_source_idle(source_emu);
      end
    end
    drive_source_idle(source_emu);
  endtask

  task automatic drive_poisson_mixed(
    input int unsigned cycles,
    input int unsigned rate_divisor,
    output longint unsigned real_hits,
    output longint unsigned emu_hits
  );
    real_hits = 64'd0;
    emu_hits  = 64'd0;
    for (int unsigned cycle_idx = 0; cycle_idx < cycles; cycle_idx++) begin
      bit real_fire_v;
      bit emu_fire_v;

      real_fire_v = (rand_range(rate_divisor) == 0);
      emu_fire_v  = (rand_range(rate_divisor) == 0);
      @(posedge cfg.reset_vif.clk);

      cfg.real_vif.valid      <= real_fire_v;
      cfg.real_vif.data       <= make_data(1'b0, real_hits[31:0], source_channel(1'b0, real_hits[31:0]));
      cfg.real_vif.error      <= 3'd0;
      cfg.real_vif.channel    <= source_channel(1'b0, real_hits[31:0]);
      cfg.real_vif.sop        <= real_fire_v;
      cfg.real_vif.eop        <= real_fire_v;
      cfg.real_vif.eor        <= 1'b0;

      cfg.emu_vif.valid      <= emu_fire_v;
      cfg.emu_vif.data       <= make_data(1'b1, emu_hits[31:0], source_channel(1'b1, emu_hits[31:0]));
      cfg.emu_vif.error      <= 3'd0;
      cfg.emu_vif.channel    <= source_channel(1'b1, emu_hits[31:0]);
      cfg.emu_vif.sop        <= emu_fire_v;
      cfg.emu_vif.eop        <= emu_fire_v;
      cfg.emu_vif.eor        <= 1'b0;

      if (real_fire_v) begin
        real_hits++;
      end
      if (emu_fire_v) begin
        emu_hits++;
      end
    end
    @(posedge cfg.reset_vif.clk);
    set_all_idle();
  endtask

  task automatic drive_dual_single_beat(
    input int unsigned real_idx,
    input int unsigned emu_idx,
    input bit          real_eor,
    input bit          emu_eor
  );
    bit [3:0] real_channel_v;
    bit [3:0] emu_channel_v;

    real_channel_v = source_channel(1'b0, real_idx);
    emu_channel_v  = source_channel(1'b1, emu_idx);
    @(posedge cfg.reset_vif.clk);
    cfg.real_vif.valid      <= 1'b1;
    cfg.real_vif.data       <= make_data(1'b0, real_idx, real_channel_v);
    cfg.real_vif.error      <= 3'd0;
    cfg.real_vif.channel    <= real_channel_v;
    cfg.real_vif.sop        <= 1'b1;
    cfg.real_vif.eop        <= 1'b1;
    cfg.real_vif.eor        <= real_eor;
    cfg.emu_vif.valid       <= 1'b1;
    cfg.emu_vif.data        <= make_data(1'b1, emu_idx, emu_channel_v);
    cfg.emu_vif.error       <= 3'd0;
    cfg.emu_vif.channel     <= emu_channel_v;
    cfg.emu_vif.sop         <= 1'b1;
    cfg.emu_vif.eop         <= 1'b1;
    cfg.emu_vif.eor         <= emu_eor;
    @(posedge cfg.reset_vif.clk);
    set_all_idle();
  endtask

  task automatic read_hit_drop_counters(
    output bit [63:0] ingress_real_hits,
    output bit [63:0] ingress_emu_hits,
    output bit [63:0] drops_real,
    output bit [63:0] drops_emu,
    output bit [63:0] egress_real_hits,
    output bit [63:0] egress_emu_hits
  );
    csr_read_pair(ARB_REG_INGRESS_REAL_HITS_L_ADDR, ingress_real_hits);
    csr_read_pair(ARB_REG_INGRESS_EMU_HITS_L_ADDR, ingress_emu_hits);
    csr_read_pair(ARB_REG_DROPS_REAL_L_ADDR, drops_real);
    csr_read_pair(ARB_REG_DROPS_EMU_L_ADDR, drops_emu);
    csr_read_pair(ARB_REG_EGRESS_REAL_HITS_L_ADDR, egress_real_hits);
    csr_read_pair(ARB_REG_EGRESS_EMU_HITS_L_ADDR, egress_emu_hits);
  endtask

  task automatic read_frame_counters(
    output bit [63:0] ingress_real_frames,
    output bit [63:0] ingress_emu_frames,
    output bit [63:0] egress_real_frames,
    output bit [63:0] egress_emu_frames
  );
    csr_read_pair(ARB_REG_INGRESS_REAL_FRAMES_L_ADDR, ingress_real_frames);
    csr_read_pair(ARB_REG_INGRESS_EMU_FRAMES_L_ADDR, ingress_emu_frames);
    csr_read_pair(ARB_REG_EGRESS_REAL_FRAMES_L_ADDR, egress_real_frames);
    csr_read_pair(ARB_REG_EGRESS_EMU_FRAMES_L_ADDR, egress_emu_frames);
  endtask

  task automatic direct_csr_read_checked(input bit [4:0] address, output bit [31:0] data);
    bit [31:0] expected_v;

    if (scoreboard == null) begin
      `uvm_fatal(get_type_name(), "PROF direct CSR prediction requires scoreboard")
    end

    expected_v = scoreboard.predict_external_csr_read(address);
    scoreboard.suppress_next_csr_read_check();

    @(posedge cfg.csr_vif.clk);
    cfg.csr_vif.address      <= address;
    cfg.csr_vif.writedata    <= '0;
    cfg.csr_vif.write        <= 1'b0;
    cfg.csr_vif.read         <= 1'b1;

    @(posedge cfg.csr_vif.clk);
    #1step;
    data = cfg.csr_vif.readdata;
    cfg.csr_vif.address      <= '0;
    cfg.csr_vif.writedata    <= '0;
    cfg.csr_vif.write        <= 1'b0;
    cfg.csr_vif.read         <= 1'b0;

    if ((data !== expected_v) &&
        !(arb_is_counter_low_addr(address) &&
          ((data == (expected_v + 32'd1)) || ((data + 32'd1) == expected_v)))) begin
      `uvm_error(
        get_type_name(),
        $sformatf("direct CSR read mismatch addr=0x%02h expected=0x%08h observed=0x%08h",
                  address,
                  expected_v,
                  data)
      )
    end
  endtask

  task automatic direct_csr_read_pair_checked(input bit [4:0] addr_lo, output bit [63:0] data64);
    bit [31:0] lo_v;
    bit [31:0] hi_v;

    direct_csr_read_checked(addr_lo, lo_v);
    direct_csr_read_checked(addr_lo + 5'd1, hi_v);
    data64 = {hi_v, lo_v};
  endtask

  function void expect64(
    input string label,
    input longint unsigned observed,
    input longint unsigned expected
  );
    if (observed !== expected) begin
      `uvm_error(get_type_name(), $sformatf("%s expected=%0d observed=%0d", label, expected, observed))
    end
  endfunction

  function void expect_zero64(input string label, input bit [63:0] observed);
    expect64(label, observed, 64'd0);
  endfunction

  task automatic check_status_clean();
    bit [31:0] status_v;

    csr_read(ARB_REG_STATUS_ADDR, status_v);
    if (status_v[17:12] != 6'd0) begin
      `uvm_error(get_type_name(), $sformatf("unexpected sticky/error status bits 17:12 = 0x%02h", status_v[17:12]))
    end
  endtask
endclass

class P001_real_only_peak_seq extends prof_direct_seq_base;
  `uvm_object_utils(P001_real_only_peak_seq)

  localparam int unsigned BEAT_COUNT_CONST  = 100000;
  localparam int unsigned PACKET_LEN_CONST  = 4;
  localparam int unsigned FRAME_COUNT_CONST = BEAT_COUNT_CONST / PACKET_LEN_CONST;

  function new(string name = "P001_real_only_peak_seq");
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

    init_case(32'h0010_0001);
    set_all_idle();
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(ARB_MODE_REAL_CONST));
    wait_cycles(8);
    drive_packet_train(1'b0, BEAT_COUNT_CONST, PACKET_LEN_CONST);
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

    expect64("INGRESS_REAL_HITS", ingress_real_hits_v, BEAT_COUNT_CONST);
    expect64("EGRESS_REAL_HITS", egress_real_hits_v, BEAT_COUNT_CONST);
    expect64("INGRESS_REAL_FRAMES", ingress_real_frames_v, FRAME_COUNT_CONST);
    expect64("EGRESS_REAL_FRAMES", egress_real_frames_v, FRAME_COUNT_CONST);
    expect_zero64("INGRESS_EMU_HITS", ingress_emu_hits_v);
    expect_zero64("EGRESS_EMU_HITS", egress_emu_hits_v);
    expect_zero64("INGRESS_EMU_FRAMES", ingress_emu_frames_v);
    expect_zero64("EGRESS_EMU_FRAMES", egress_emu_frames_v);
    expect_zero64("DROPS_REAL", drops_real_v);
    expect_zero64("DROPS_EMU", drops_emu_v);
    check_status_clean();
  endtask
endclass
