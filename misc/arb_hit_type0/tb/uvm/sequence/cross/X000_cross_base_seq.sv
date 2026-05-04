import uvm_pkg::*;
import lcg_prng_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X000_cross_hit_stream_seq extends uvm_sequence #(hit_type0_seq_item);
  `uvm_object_utils(X000_cross_hit_stream_seq)

  bit [31:0]       seed;
  int unsigned     beat_count;
  int unsigned     packet_len;
  int unsigned     first_idle;
  int unsigned     beat_idle;
  bit [44:0]       data_base;
  bit [2:0]        error_value;
  bit [3:0]        channel_value;
  bit              source_emu;
  bit              eor_on_last;
  bit              valid_value;

  function new(string name = "X000_cross_hit_stream_seq");
    super.new(name);
    seed          = 32'd1;
    beat_count    = 1;
    packet_len    = 1;
    first_idle    = 0;
    beat_idle     = 0;
    data_base     = 45'd0;
    error_value   = 3'd0;
    channel_value = 4'd0;
    source_emu    = 1'b0;
    eor_on_last   = 1'b0;
    valid_value   = 1'b1;
  endfunction

  task body();
    lcg_prng_state_t prng_v;
    int unsigned     idx_v;
    int unsigned     local_packet_len_v;
    hit_type0_seq_item item_v;

    local_packet_len_v = (packet_len == 0) ? 1 : packet_len;
    prng_v             = lcg_init(seed);

    for (idx_v = 0; idx_v < beat_count; idx_v++) begin
      item_v = hit_type0_seq_item::type_id::create($sformatf("cross_hit_%0d", idx_v));
      item_v.valid       = valid_value;
      item_v.data        = data_base ^ {13'd0, lcg_next(prng_v)};
      item_v.error       = error_value;
      item_v.channel     = channel_value;
      item_v.sop         = ((idx_v % local_packet_len_v) == 0);
      item_v.eop         = (((idx_v + 1) % local_packet_len_v) == 0) || (idx_v == (beat_count - 1));
      item_v.eor         = eor_on_last && (idx_v == (beat_count - 1));
      item_v.idle_cycles = (idx_v == 0) ? first_idle : beat_idle;
      item_v.source_emu  = source_emu;
      start_item(item_v);
      finish_item(item_v);
    end
  endtask
endclass

class X000_cross_base_seq extends arb_hit_type0_base_vseq;
  `uvm_object_utils(X000_cross_base_seq)

  arb_hit_type0_env_cfg cfg;
  lcg_prng_state_t      prng;

  function new(string name = "X000_cross_base_seq");
    super.new(name);
  endfunction

  task pre_body();
    super.pre_body();
    if (!uvm_config_db#(arb_hit_type0_env_cfg)::get(null, vseqr.get_full_name(), "env_cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "missing env_cfg")
    end
    prng = lcg_init(cfg.seed);
  endtask

  task automatic wait_clocks(input int unsigned cycles);
    repeat (cycles) begin
      @(cfg.reset_vif.mon_cb);
    end
  endtask

  task automatic set_mode(input bit [1:0] mode_value);
    csr_write(ARB_REG_CONTROL_ADDR, arb_control_word(mode_value));
    wait_clocks(4);
  endtask

  task automatic clear_all(input bit [1:0] mode_value = ARB_MODE_REAL_CONST);
    csr_write(
      ARB_REG_CONTROL_ADDR,
      arb_control_word(
        mode_value,
        .clear_counters(1'b1),
        .clear_sticky(1'b1),
        .clear_error_counters(1'b1),
        .clear_syndromes(1'b1)
      )
    );
    wait_clocks(4);
  endtask

  task automatic read_status(output bit [31:0] status_value);
    csr_read(ARB_REG_STATUS_ADDR, status_value);
  endtask

  task automatic expect_status_mode(input bit [1:0] mode_value, input string label);
    bit [31:0] status_v;

    read_status(status_v);
    if (status_v[1:0] !== mode_value) begin
      `uvm_error(
        get_type_name(),
        $sformatf("%s STATUS.mode expected %0d observed %0d", label, mode_value, status_v[1:0])
      )
    end
  endtask

  task automatic expect_counter(input bit [4:0] addr_lo, input bit [63:0] expected_value, input string label);
    bit [63:0] actual_v;

    csr_read_pair(addr_lo, actual_v);
    if (actual_v !== expected_value) begin
      `uvm_error(
        get_type_name(),
        $sformatf("%s expected 0x%016h observed 0x%016h", label, expected_value, actual_v)
      )
    end
  endtask

  task automatic run_stream(
    input bit          source_emu,
    input int unsigned beat_count,
    input int unsigned packet_len,
    input bit [3:0]    channel_value,
    input bit [2:0]    error_value,
    input int unsigned first_idle,
    input int unsigned beat_idle,
    input bit          eor_on_last,
    input bit [44:0]   data_base,
    input bit [31:0]   seed_delta
  );
    X000_cross_hit_stream_seq stream_seq;

    stream_seq               = X000_cross_hit_stream_seq::type_id::create("stream_seq");
    stream_seq.seed          = cfg.seed ^ seed_delta;
    stream_seq.beat_count    = beat_count;
    stream_seq.packet_len    = packet_len;
    stream_seq.first_idle    = first_idle;
    stream_seq.beat_idle     = beat_idle;
    stream_seq.channel_value = channel_value;
    stream_seq.error_value   = error_value;
    stream_seq.source_emu    = source_emu;
    stream_seq.eor_on_last   = eor_on_last;
    stream_seq.data_base     = data_base;
    stream_seq.start(source_emu ? vseqr.emu_seqr : vseqr.real_seqr);
  endtask

  task automatic run_invalid_beat(
    input bit        source_emu,
    input bit [3:0]  channel_value,
    input bit [44:0] data_value
  );
    X000_cross_hit_stream_seq stream_seq;

    stream_seq               = X000_cross_hit_stream_seq::type_id::create("invalid_stream_seq");
    stream_seq.seed          = cfg.seed ^ 32'h1BAD_0001;
    stream_seq.beat_count    = 1;
    stream_seq.packet_len    = 1;
    stream_seq.channel_value = channel_value;
    stream_seq.data_base     = data_value;
    stream_seq.source_emu    = source_emu;
    stream_seq.valid_value   = 1'b0;
    stream_seq.start(source_emu ? vseqr.emu_seqr : vseqr.real_seqr);
  endtask

  task automatic run_resetting_subframe();
    send_runctl(runctl_seq_item::RUN_RESETTING_WORD_CONST);
    wait_clocks(8);
  endtask

  task automatic run_preparing_subframe();
    send_runctl(runctl_seq_item::RUN_PREPARING_WORD_CONST);
    wait_clocks(8);
  endtask

  task automatic poll_defined_csrs();
    bit [31:0] read_v;

    csr_read(ARB_REG_UID_ADDR, read_v);
    csr_read(ARB_REG_META_ADDR, read_v);
    csr_read(ARB_REG_CONTROL_ADDR, read_v);
    csr_read(ARB_REG_STATUS_ADDR, read_v);
    csr_read(ARB_REG_WATCHDOG_ADDR, read_v);
    csr_read(ARB_REG_ERROR_COUNT_PROTOCOL_ADDR, read_v);
    csr_read(ARB_REG_ERROR_COUNT_DROP_MID_ADDR, read_v);
  endtask
endclass
