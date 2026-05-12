class arb_hit_type0_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(arb_hit_type0_scoreboard)

  arb_hit_type0_env_cfg cfg;

  uvm_analysis_imp_real   #(hit_type0_seq_item, arb_hit_type0_scoreboard) real_imp;
  uvm_analysis_imp_emu    #(hit_type0_seq_item, arb_hit_type0_scoreboard) emu_imp;
  uvm_analysis_imp_egress #(hit_type0_seq_item, arb_hit_type0_scoreboard) egress_imp;
  uvm_analysis_imp_csr    #(csr_seq_item,       arb_hit_type0_scoreboard) csr_imp;
  uvm_analysis_imp_runctl #(runctl_seq_item,    arb_hit_type0_scoreboard) runctl_imp;

  hit_type0_seq_item real_fifo[$];
  hit_type0_seq_item emu_fifo[$];
  hit_type0_seq_item expected_egress_q[$];
  time               real_fifo_time[$];
  time               emu_fifo_time[$];

  bit [1:0]          mode;
  bit [1:0]          mode_pending;
  bit [1:0]          meta_select;
  bit [15:0]         watchdog_cycles;
  bit                real_open;
  bit                emu_open;
  bit                real_ingress_open;
  bit                emu_ingress_open;
  bit                eor_seen_real;
  bit                eor_seen_emu;
  bit                merged_locked;
  bit                last_grant;
  bit                partial_packet_drop_sticky;
  bit                mode_reserved_seen;
  bit                protocol_violation_sticky;
  bit                drop_mid_packet_sticky;
  bit                watchdog_synthesized_real;
  bit                watchdog_synthesized_emu;
  longint unsigned   ingress_real_hits;
  longint unsigned   ingress_emu_hits;
  longint unsigned   ingress_real_frames;
  longint unsigned   ingress_emu_frames;
  longint unsigned   drops_real;
  longint unsigned   drops_emu;
  longint unsigned   egress_real_hits;
  longint unsigned   egress_emu_hits;
  longint unsigned   egress_real_frames;
  longint unsigned   egress_emu_frames;
  int unsigned       error_count_protocol;
  int unsigned       error_count_drop_mid_packet;
  bit [31:0]         syndrome_protocol;
  bit [31:0]         syndrome_drop_mid_packet;
  bit [31:0]         ingress_real_hits_h_snap;
  bit [31:0]         ingress_emu_hits_h_snap;
  bit [31:0]         ingress_real_frames_h_snap;
  bit [31:0]         ingress_emu_frames_h_snap;
  bit [31:0]         drops_real_h_snap;
  bit [31:0]         drops_emu_h_snap;
  bit [31:0]         egress_real_hits_h_snap;
  bit [31:0]         egress_emu_hits_h_snap;
  bit [31:0]         egress_real_frames_h_snap;
  bit [31:0]         egress_emu_frames_h_snap;
  bit [2:0]          run_state;
  int unsigned       coverage_mode_fifo_bins[3][3][3];
  int unsigned       coverage_mode_transition_bins[3][3];
  int unsigned       suppressed_csr_read_checks;

  function new(string name = "arb_hit_type0_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    real_imp   = new("real_imp", this);
    emu_imp    = new("emu_imp", this);
    egress_imp = new("egress_imp", this);
    csr_imp    = new("csr_imp", this);
    runctl_imp = new("runctl_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(arb_hit_type0_env_cfg)::get(this, "", "env_cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "missing env_cfg")
    end
    reset_model();
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(cfg.reset_vif.mon_cb);
      if (cfg.reset_vif.rst === 1'b1) begin
        reset_model();
      end
    end
  endtask

  function void reset_model();
    real_fifo.delete();
    emu_fifo.delete();
    expected_egress_q.delete();
    real_fifo_time.delete();
    emu_fifo_time.delete();
    mode                          = ARB_MODE_REAL_CONST;
    mode_pending                  = ARB_MODE_REAL_CONST;
    meta_select                   = 2'd0;
    watchdog_cycles               = 16'd500;
    real_open                     = 1'b0;
    emu_open                      = 1'b0;
    real_ingress_open             = 1'b0;
    emu_ingress_open              = 1'b0;
    eor_seen_real                 = 1'b0;
    eor_seen_emu                  = 1'b0;
    merged_locked                 = 1'b0;
    last_grant                    = 1'b0;
    partial_packet_drop_sticky    = 1'b0;
    mode_reserved_seen            = 1'b0;
    protocol_violation_sticky     = 1'b0;
    drop_mid_packet_sticky        = 1'b0;
    watchdog_synthesized_real     = 1'b0;
    watchdog_synthesized_emu      = 1'b0;
    ingress_real_hits             = 64'd0;
    ingress_emu_hits              = 64'd0;
    ingress_real_frames           = 64'd0;
    ingress_emu_frames            = 64'd0;
    drops_real                    = 64'd0;
    drops_emu                     = 64'd0;
    egress_real_hits              = 64'd0;
    egress_emu_hits               = 64'd0;
    egress_real_frames            = 64'd0;
    egress_emu_frames             = 64'd0;
    error_count_protocol          = 32'd0;
    error_count_drop_mid_packet   = 32'd0;
    syndrome_protocol             = 32'd0;
    syndrome_drop_mid_packet      = 32'd0;
    ingress_real_hits_h_snap      = 32'd0;
    ingress_emu_hits_h_snap       = 32'd0;
    ingress_real_frames_h_snap    = 32'd0;
    ingress_emu_frames_h_snap     = 32'd0;
    drops_real_h_snap             = 32'd0;
    drops_emu_h_snap              = 32'd0;
    egress_real_hits_h_snap       = 32'd0;
    egress_emu_hits_h_snap        = 32'd0;
    egress_real_frames_h_snap     = 32'd0;
    egress_emu_frames_h_snap      = 32'd0;
    run_state                     = 3'd0;
    suppressed_csr_read_checks    = 0;
  endfunction

  function hit_type0_seq_item clone_hit(hit_type0_seq_item item, string name);
    hit_type0_seq_item copy_v;

    copy_v = hit_type0_seq_item::type_id::create(name);
    copy_v.copy(item);
    return copy_v;
  endfunction

  function arb_fifo_state_e fifo_state(input int unsigned depth);
    if (depth == 0) begin
      return ARB_FIFO_EMPTY;
    end
    if (depth >= ARB_FIFO_DEPTH) begin
      return ARB_FIFO_FULL;
    end
    return ARB_FIFO_MID;
  endfunction

  function bit mode_eor_complete(input bit [1:0] mode_value, input bit real_seen, input bit emu_seen);
    case (mode_value)
      ARB_MODE_EMU_CONST:    return emu_seen;
      ARB_MODE_MIX_RR_CONST: return real_seen & emu_seen;
      default:               return real_seen;
    endcase
  endfunction

  function void write_real(hit_type0_seq_item txn);
    hit_type0_seq_item copy_v;

    copy_v = clone_hit(txn, "real_fifo_item");
    copy_v.source_emu = 1'b0;
    if (txn.eop) begin
      ingress_real_frames = arb_sat_inc64(ingress_real_frames);
    end
    if (real_fifo.size() < ARB_FIFO_DEPTH) begin
      real_fifo.push_back(copy_v);
      real_fifo_time.push_back($time);
      ingress_real_hits = arb_sat_inc64(ingress_real_hits);
      if (txn.sop && !(txn.eop || txn.eor)) begin
        real_ingress_open = 1'b1;
      end else if (txn.eop || txn.eor) begin
        real_ingress_open = 1'b0;
      end
    end else begin
      drops_real = arb_sat_inc64(drops_real);
      if (real_ingress_open) begin
        partial_packet_drop_sticky = 1'b1;
      end
      // R007: drop-mid-packet keys off the ingress-open flag (FIFO mid-packet),
      // not the egress-side `real_open` which lags whenever the arbiter is
      // draining the other source. Mirrors the RTL fix in arb_hit_type0_csr.sv.
      if (real_ingress_open) begin
        if (!drop_mid_packet_sticky) begin
          syndrome_drop_mid_packet = make_drop_syndrome(1'b0, txn, real_fifo.size(), real_ingress_open);
        end
        drop_mid_packet_sticky      = 1'b1;
        error_count_drop_mid_packet = arb_sat_inc32(error_count_drop_mid_packet);
      end
    end
  endfunction

  function void write_emu(hit_type0_seq_item txn);
    hit_type0_seq_item copy_v;

    copy_v = clone_hit(txn, "emu_fifo_item");
    copy_v.source_emu = 1'b1;
    if (txn.eop) begin
      ingress_emu_frames = arb_sat_inc64(ingress_emu_frames);
    end
    if (emu_fifo.size() < ARB_FIFO_DEPTH) begin
      emu_fifo.push_back(copy_v);
      emu_fifo_time.push_back($time);
      ingress_emu_hits = arb_sat_inc64(ingress_emu_hits);
      if (txn.sop && !(txn.eop || txn.eor)) begin
        emu_ingress_open = 1'b1;
      end else if (txn.eop || txn.eor) begin
        emu_ingress_open = 1'b0;
      end
    end else begin
      drops_emu = arb_sat_inc64(drops_emu);
      if (emu_ingress_open) begin
        partial_packet_drop_sticky = 1'b1;
      end
      // R007 mirror: see write_real() above.
      if (emu_ingress_open) begin
        if (!drop_mid_packet_sticky) begin
          syndrome_drop_mid_packet = make_drop_syndrome(1'b1, txn, emu_fifo.size(), emu_ingress_open);
        end
        drop_mid_packet_sticky      = 1'b1;
        error_count_drop_mid_packet = arb_sat_inc32(error_count_drop_mid_packet);
      end
    end
  endfunction

  function void write_egress(hit_type0_seq_item txn);
    hit_type0_seq_item exp;

    ensure_expected_available();
    if (expected_egress_q.size() == 0) begin
      `uvm_error(get_type_name(), $sformatf("Unexpected egress beat: %s", txn.convert2string()))
      return;
    end

    exp = expected_egress_q.pop_front();
    if ((exp.data    !== txn.data)    ||
        (exp.error   !== txn.error)   ||
        (exp.channel !== txn.channel) ||
        (exp.sop     !== txn.sop)     ||
        (exp.eop     !== txn.eop)     ||
        (exp.eor     !== txn.eor)) begin
      `uvm_error(
        get_type_name(),
        $sformatf("Egress mismatch expected {%s} observed {%s}", exp.convert2string(), txn.convert2string())
      )
    end
  endfunction

  function void write_csr(csr_seq_item txn);
    bit [31:0] expected_v;

    if (txn.is_write) begin
      note_csr_write(txn);
    end else begin
      if (suppressed_csr_read_checks != 0) begin
        suppressed_csr_read_checks--;
        return;
      end
      expected_v = expected_csr_read(txn.address);
      if (txn.readdata !== expected_v) begin
        `uvm_error(
          get_type_name(),
          $sformatf(
            "CSR read mismatch addr=0x%02h expected=0x%08h observed=0x%08h",
            txn.address,
            expected_v,
            txn.readdata
          )
        )
      end
    end
  endfunction

  function void suppress_next_csr_read_check();
    suppressed_csr_read_checks++;
  endfunction

  function bit [31:0] predict_external_csr_read(input bit [4:0] addr);
    return expected_csr_read(addr);
  endfunction

  function void write_runctl(runctl_seq_item txn);
    run_state = decode_run_state(txn.data);
    // stream_clear fires only on RUN_RESETTING ([7]) per 26.4.0 RTL:
    // returns MODE / sticky config to defaults AND clears FIFO/arbiter
    // stream-shape state. RUN_PREPARING ([1]) preserves user MODE config
    // and stream-shape state (this is the lane-admit asymmetry fix).
    // RUN_PREPARING still triggers the FSM state transition (run_state)
    // and the staged reset FSM via reset_start, but no clears.
    if (txn.data[7]) begin
      real_fifo.delete();
      emu_fifo.delete();
      expected_egress_q.delete();
      real_fifo_time.delete();
      emu_fifo_time.delete();
      real_open                 = 1'b0;
      emu_open                  = 1'b0;
      real_ingress_open         = 1'b0;
      emu_ingress_open          = 1'b0;
      eor_seen_real             = 1'b0;
      eor_seen_emu              = 1'b0;
      merged_locked             = 1'b0;
      last_grant                = 1'b0;
      mode                      = ARB_MODE_REAL_CONST;
      mode_pending              = ARB_MODE_REAL_CONST;
      partial_packet_drop_sticky = 1'b0;
      mode_reserved_seen        = 1'b0;
      protocol_violation_sticky = 1'b0;
      drop_mid_packet_sticky    = 1'b0;
      watchdog_synthesized_real = 1'b0;
      watchdog_synthesized_emu  = 1'b0;
    end
    if (txn.data[7]) begin
      ingress_real_hits           = 64'd0;
      ingress_emu_hits            = 64'd0;
      ingress_real_frames         = 64'd0;
      ingress_emu_frames          = 64'd0;
      drops_real                  = 64'd0;
      drops_emu                   = 64'd0;
      egress_real_hits            = 64'd0;
      egress_emu_hits             = 64'd0;
      egress_real_frames          = 64'd0;
      egress_emu_frames           = 64'd0;
      error_count_protocol        = 32'd0;
      error_count_drop_mid_packet = 32'd0;
      syndrome_protocol           = 32'd0;
      syndrome_drop_mid_packet    = 32'd0;
    end
  endfunction

  function bit [2:0] decode_run_state(input bit [8:0] data);
    if (data[7]) begin
      return 3'd5;
    end
    if (data[1]) begin
      return 3'd1;
    end
    if (data[2]) begin
      return 3'd2;
    end
    if (data[3]) begin
      return 3'd3;
    end
    if (data[4]) begin
      return 3'd4;
    end
    if (data[8]) begin
      return 3'd7;
    end
    if (data[5] || data[6]) begin
      return 3'd6;
    end
    return 3'd0;
  endfunction

  function void note_csr_write(csr_seq_item txn);
    bit [1:0] old_mode_v;

    case (txn.address)
      ARB_REG_META_ADDR: begin
        meta_select = txn.writedata[1:0];
      end
      ARB_REG_CONTROL_ADDR: begin
        old_mode_v = mode_pending;
        if (txn.writedata[2]) begin
          ingress_real_hits        = 64'd0;
          ingress_emu_hits         = 64'd0;
          ingress_real_frames      = 64'd0;
          ingress_emu_frames       = 64'd0;
          drops_real               = 64'd0;
          drops_emu                = 64'd0;
          egress_real_hits         = 64'd0;
          egress_emu_hits          = 64'd0;
          egress_real_frames       = 64'd0;
          egress_emu_frames        = 64'd0;
          ingress_real_hits_h_snap = 32'd0;
          ingress_emu_hits_h_snap  = 32'd0;
          ingress_real_frames_h_snap = 32'd0;
          ingress_emu_frames_h_snap  = 32'd0;
          drops_real_h_snap        = 32'd0;
          drops_emu_h_snap         = 32'd0;
          egress_real_hits_h_snap  = 32'd0;
          egress_emu_hits_h_snap   = 32'd0;
          egress_real_frames_h_snap = 32'd0;
          egress_emu_frames_h_snap  = 32'd0;
        end
        if (txn.writedata[3]) begin
          partial_packet_drop_sticky = 1'b0;
          mode_reserved_seen         = 1'b0;
          protocol_violation_sticky  = 1'b0;
          drop_mid_packet_sticky     = 1'b0;
          watchdog_synthesized_real  = 1'b0;
          watchdog_synthesized_emu   = 1'b0;
        end
        if (txn.writedata[4]) begin
          error_count_protocol        = 32'd0;
          error_count_drop_mid_packet = 32'd0;
        end
        if (txn.writedata[5]) begin
          syndrome_protocol      = 32'd0;
          syndrome_drop_mid_packet = 32'd0;
        end
        mode_pending = arb_sanitize_mode(txn.writedata[1:0]);
        if (txn.writedata[1:0] == ARB_MODE_RESERVED_CONST) begin
          mode_reserved_seen = 1'b1;
        end
        if (!(real_open || emu_open)) begin
          mode = mode_pending;
        end
        sample_mode_transition(old_mode_v, mode_pending);
      end
      ARB_REG_WATCHDOG_ADDR: begin
        watchdog_cycles = txn.writedata[15:0];
      end
      default: begin
      end
    endcase
  endfunction

  function bit [31:0] expected_csr_read(input bit [4:0] addr);
    bit [31:0] value_v;

    case (addr)
      ARB_REG_UID_ADDR: value_v = ARB_UID_CONST;
      ARB_REG_META_ADDR: begin
        case (meta_select)
          2'd0: value_v = ARB_VERSION_WORD_CONST;
          2'd1: value_v = ARB_DATE_WORD_CONST;
          2'd2: value_v = ARB_GIT_WORD_CONST;
          2'd3: value_v = ARB_INSTANCE_ID_WORD_CONST;
          default: value_v = 32'd0;
        endcase
      end
      ARB_REG_CONTROL_ADDR: value_v = {30'd0, mode_pending};
      ARB_REG_STATUS_ADDR: begin
        value_v        = 32'd0;
        value_v[1:0]   = mode;
        value_v[3:2]   = mode_pending;
        value_v[4]     = real_open | emu_open;
        value_v[5]     = real_open;
        value_v[6]     = emu_open;
        value_v[7]     = (real_fifo.size() >= ARB_FIFO_DEPTH);
        value_v[8]     = (real_fifo.size() == 0);
        value_v[9]     = (emu_fifo.size() >= ARB_FIFO_DEPTH);
        value_v[10]    = (emu_fifo.size() == 0);
        value_v[11]    = last_grant;
        value_v[12]    = partial_packet_drop_sticky;
        value_v[13]    = mode_reserved_seen;
        value_v[14]    = protocol_violation_sticky;
        value_v[15]    = drop_mid_packet_sticky;
        value_v[16]    = watchdog_synthesized_real;
        value_v[17]    = watchdog_synthesized_emu;
        value_v[20:18] = run_state;
        sample_mode_fifo();
      end
      ARB_REG_WATCHDOG_ADDR: value_v = {16'd0, watchdog_cycles};
      ARB_REG_IDLE_CYCLES_ADDR: value_v = cfg.csr_vif.readdata;
      ARB_REG_ERROR_COUNT_PROTOCOL_ADDR: value_v = error_count_protocol;
      ARB_REG_ERROR_COUNT_DROP_MID_ADDR: value_v = error_count_drop_mid_packet;
      ARB_REG_SYNDROME_PROTOCOL_ADDR: value_v = syndrome_protocol;
      ARB_REG_SYNDROME_DROP_MID_ADDR: value_v = syndrome_drop_mid_packet;
      ARB_REG_INGRESS_REAL_HITS_L_ADDR: begin
        value_v = ingress_real_hits[31:0];
        ingress_real_hits_h_snap = ingress_real_hits[63:32];
      end
      ARB_REG_INGRESS_REAL_HITS_H_ADDR: value_v = ingress_real_hits_h_snap;
      ARB_REG_INGRESS_EMU_HITS_L_ADDR: begin
        value_v = ingress_emu_hits[31:0];
        ingress_emu_hits_h_snap = ingress_emu_hits[63:32];
      end
      ARB_REG_INGRESS_EMU_HITS_H_ADDR: value_v = ingress_emu_hits_h_snap;
      ARB_REG_DROPS_REAL_L_ADDR: begin
        value_v = drops_real[31:0];
        drops_real_h_snap = drops_real[63:32];
      end
      ARB_REG_DROPS_REAL_H_ADDR: value_v = drops_real_h_snap;
      ARB_REG_DROPS_EMU_L_ADDR: begin
        value_v = drops_emu[31:0];
        drops_emu_h_snap = drops_emu[63:32];
      end
      ARB_REG_DROPS_EMU_H_ADDR: value_v = drops_emu_h_snap;
      ARB_REG_EGRESS_REAL_HITS_L_ADDR: begin
        value_v = egress_real_hits[31:0];
        egress_real_hits_h_snap = egress_real_hits[63:32];
      end
      ARB_REG_EGRESS_REAL_HITS_H_ADDR: value_v = egress_real_hits_h_snap;
      ARB_REG_EGRESS_EMU_HITS_L_ADDR: begin
        value_v = egress_emu_hits[31:0];
        egress_emu_hits_h_snap = egress_emu_hits[63:32];
      end
      ARB_REG_EGRESS_EMU_HITS_H_ADDR: value_v = egress_emu_hits_h_snap;
      ARB_REG_INGRESS_REAL_FRAMES_L_ADDR: begin
        value_v = ingress_real_frames[31:0];
        ingress_real_frames_h_snap = ingress_real_frames[63:32];
      end
      ARB_REG_INGRESS_REAL_FRAMES_H_ADDR: value_v = ingress_real_frames_h_snap;
      ARB_REG_INGRESS_EMU_FRAMES_L_ADDR: begin
        value_v = ingress_emu_frames[31:0];
        ingress_emu_frames_h_snap = ingress_emu_frames[63:32];
      end
      ARB_REG_INGRESS_EMU_FRAMES_H_ADDR: value_v = ingress_emu_frames_h_snap;
      ARB_REG_EGRESS_REAL_FRAMES_L_ADDR: begin
        value_v = egress_real_frames[31:0];
        egress_real_frames_h_snap = egress_real_frames[63:32];
      end
      ARB_REG_EGRESS_REAL_FRAMES_H_ADDR: value_v = egress_real_frames_h_snap;
      ARB_REG_EGRESS_EMU_FRAMES_L_ADDR: begin
        value_v = egress_emu_frames[31:0];
        egress_emu_frames_h_snap = egress_emu_frames[63:32];
      end
      ARB_REG_EGRESS_EMU_FRAMES_H_ADDR: value_v = egress_emu_frames_h_snap;
      default: value_v = 32'd0;
    endcase
    return value_v;
  endfunction

  function void ensure_expected_available();
    int unsigned guard_v;

    guard_v = 0;
    while ((expected_egress_q.size() == 0) && can_pump_model() && (guard_v < 1024)) begin
      pump_model_once();
      guard_v++;
    end
  endfunction

  function bit can_pump_model();
    bit real_ready_v;
    bit emu_ready_v;

    if (!(real_open || emu_open)) begin
      mode = mode_pending;
    end
    if (merged_locked) begin
      return 1'b0;
    end
    real_ready_v = (real_fifo.size() != 0) && (real_fifo_time[0] < $time);
    emu_ready_v  = (emu_fifo.size() != 0) && (emu_fifo_time[0] < $time);
    case (mode)
      ARB_MODE_EMU_CONST:    return emu_ready_v;
      ARB_MODE_MIX_RR_CONST: return real_ready_v || emu_ready_v;
      default:               return real_ready_v;
    endcase
  endfunction

  function void pump_model_once();
    bit grant_emu_v;
    bit real_ready_v;
    bit emu_ready_v;
    hit_type0_seq_item beat_v;
    hit_type0_seq_item exp_v;
    bit was_open_self_v;
    bit was_open_other_v;
    bit self_open_next_v;

    grant_emu_v = 1'b0;
    real_ready_v = (real_fifo.size() != 0) && (real_fifo_time[0] < $time);
    emu_ready_v  = (emu_fifo.size() != 0) && (emu_fifo_time[0] < $time);
    case (mode)
      ARB_MODE_EMU_CONST: begin
        grant_emu_v = emu_ready_v;
      end
      ARB_MODE_MIX_RR_CONST: begin
        if (real_ready_v && emu_ready_v) begin
          grant_emu_v = ~last_grant;
        end else if (emu_ready_v) begin
          grant_emu_v = 1'b1;
        end
      end
      default: begin
        grant_emu_v = 1'b0;
      end
    endcase

    if (grant_emu_v) begin
      if (emu_fifo.size() == 0) begin
        return;
      end
      beat_v = emu_fifo.pop_front();
      void'(emu_fifo_time.pop_front());
    end else begin
      if (real_fifo.size() == 0) begin
        return;
      end
      beat_v = real_fifo.pop_front();
      void'(real_fifo_time.pop_front());
    end

    exp_v = clone_hit(beat_v, "expected_egress");
    exp_v.source_emu = grant_emu_v;
    exp_v.sop        = 1'b0;
    exp_v.eop        = 1'b0;
    exp_v.eor        = 1'b0;

    was_open_self_v  = grant_emu_v ? emu_open : real_open;
    was_open_other_v = grant_emu_v ? real_open : emu_open;
    self_open_next_v = was_open_self_v;

    if (beat_v.sop && !(beat_v.eop || beat_v.eor)) begin
      self_open_next_v = 1'b1;
      exp_v.sop        = !was_open_self_v && !was_open_other_v;
    end else if (!beat_v.sop && (beat_v.eop || beat_v.eor)) begin
      self_open_next_v = 1'b0;
      exp_v.eop        = !was_open_other_v;
    end else if (beat_v.sop && (beat_v.eop || beat_v.eor)) begin
      self_open_next_v = 1'b0;
      exp_v.sop        = !was_open_other_v;
      exp_v.eop        = !was_open_other_v;
    end

    if (grant_emu_v) begin
      emu_open     = self_open_next_v;
      eor_seen_emu = eor_seen_emu | beat_v.eor;
      egress_emu_hits = arb_sat_inc64(egress_emu_hits);
      if (beat_v.eop) begin
        egress_emu_frames = arb_sat_inc64(egress_emu_frames);
      end
    end else begin
      real_open     = self_open_next_v;
      eor_seen_real = eor_seen_real | beat_v.eor;
      egress_real_hits = arb_sat_inc64(egress_real_hits);
      if (beat_v.eop) begin
        egress_real_frames = arb_sat_inc64(egress_real_frames);
      end
    end

    if (beat_v.sop && was_open_self_v) begin
      if (!protocol_violation_sticky) begin
        syndrome_protocol = make_protocol_syndrome(grant_emu_v, beat_v, was_open_self_v, was_open_other_v);
      end
      protocol_violation_sticky = 1'b1;
      error_count_protocol      = arb_sat_inc32(error_count_protocol);
    end

    exp_v.eor      = exp_v.eop && mode_eor_complete(mode, eor_seen_real, eor_seen_emu);
    merged_locked  = merged_locked | exp_v.eor;
    last_grant     = grant_emu_v;
    if (!(real_open || emu_open)) begin
      mode = mode_pending;
    end
    expected_egress_q.push_back(exp_v);
  endfunction

  function bit [31:0] make_protocol_syndrome(
    input bit             source_emu_v,
    input hit_type0_seq_item beat_v,
    input bit             was_open_self_v,
    input bit             was_open_other_v
  );
    bit [31:0] syndrome_v;

    syndrome_v        = 32'd0;
    syndrome_v[3:0]   = beat_v.channel;
    syndrome_v[4]     = source_emu_v;
    syndrome_v[5]     = source_emu_v ? was_open_other_v : was_open_self_v;
    syndrome_v[6]     = source_emu_v ? was_open_self_v : was_open_other_v;
    syndrome_v[7]     = beat_v.sop;
    syndrome_v[8]     = beat_v.eop | beat_v.eor;
    syndrome_v[11:9]  = beat_v.error;
    syndrome_v[14:12] = run_state;
    return syndrome_v;
  endfunction

  function bit [31:0] make_drop_syndrome(
    input bit             source_emu_v,
    input hit_type0_seq_item beat_v,
    input int unsigned    fifo_depth_v,
    input bit             source_open_v
  );
    bit [31:0] syndrome_v;

    syndrome_v         = 32'd0;
    syndrome_v[3:0]    = beat_v.channel;
    syndrome_v[4]      = source_emu_v;
    syndrome_v[9:5]    = fifo_depth_v[4:0];
    syndrome_v[10]     = source_open_v;
    syndrome_v[13:11]  = beat_v.error;
    syndrome_v[16:14]  = run_state;
    return syndrome_v;
  endfunction

  function void sample_mode_fifo();
    if (!cfg.enable_coverage) begin
      return;
    end
    if (mode < 3) begin
      coverage_mode_fifo_bins[mode][fifo_state(real_fifo.size())][fifo_state(emu_fifo.size())]++;
    end
  endfunction

  function void sample_mode_transition(input bit [1:0] from_mode, input bit [1:0] to_mode);
    if (!cfg.enable_coverage) begin
      return;
    end
    if ((from_mode < 3) && (to_mode < 3)) begin
      coverage_mode_transition_bins[from_mode][to_mode]++;
    end
  endfunction

  function void predict_counter_preload(input bit [4:0] addr_lo, input longint unsigned value);
    case (addr_lo)
      ARB_REG_INGRESS_REAL_HITS_L_ADDR: begin
        ingress_real_hits        = value;
        ingress_real_hits_h_snap = value[63:32];
      end
      ARB_REG_INGRESS_EMU_HITS_L_ADDR: begin
        ingress_emu_hits        = value;
        ingress_emu_hits_h_snap = value[63:32];
      end
      ARB_REG_DROPS_REAL_L_ADDR: begin
        drops_real        = value;
        drops_real_h_snap = value[63:32];
      end
      ARB_REG_DROPS_EMU_L_ADDR: begin
        drops_emu        = value;
        drops_emu_h_snap = value[63:32];
      end
      ARB_REG_EGRESS_REAL_HITS_L_ADDR: begin
        egress_real_hits        = value;
        egress_real_hits_h_snap = value[63:32];
      end
      ARB_REG_EGRESS_EMU_HITS_L_ADDR: begin
        egress_emu_hits        = value;
        egress_emu_hits_h_snap = value[63:32];
      end
      ARB_REG_INGRESS_REAL_FRAMES_L_ADDR: begin
        ingress_real_frames        = value;
        ingress_real_frames_h_snap = value[63:32];
      end
      ARB_REG_INGRESS_EMU_FRAMES_L_ADDR: begin
        ingress_emu_frames        = value;
        ingress_emu_frames_h_snap = value[63:32];
      end
      ARB_REG_EGRESS_REAL_FRAMES_L_ADDR: begin
        egress_real_frames        = value;
        egress_real_frames_h_snap = value[63:32];
      end
      ARB_REG_EGRESS_EMU_FRAMES_L_ADDR: begin
        egress_emu_frames        = value;
        egress_emu_frames_h_snap = value[63:32];
      end
      default: begin
        `uvm_error(get_type_name(), $sformatf("Unsupported counter preload addr=0x%02h", addr_lo))
      end
    endcase
  endfunction

  function void predict_mode_boundary(input bit [1:0] new_mode);
    mode_pending = arb_sanitize_mode(new_mode);
    if (!(real_open || emu_open)) begin
      mode = mode_pending;
    end
  endfunction

  function void predict_watchdog_synthesized(input bit source_emu, input bit [3:0] channel);
    hit_type0_seq_item exp_v;
    bit                eor_v;

    if (source_emu) begin
      emu_open                  = 1'b0;
      eor_seen_emu              = eor_seen_emu | eor_seen_real;
      watchdog_synthesized_emu  = 1'b1;
    end else begin
      real_open                 = 1'b0;
      eor_seen_real             = eor_seen_real | eor_seen_emu;
      watchdog_synthesized_real = 1'b1;
    end

    eor_v = mode_eor_complete(mode, eor_seen_real, eor_seen_emu);

    exp_v = hit_type0_seq_item::type_id::create("watchdog_expected_egress");
    exp_v.valid      = 1'b1;
    exp_v.source_emu = source_emu;
    exp_v.data       = 45'd0;
    exp_v.error      = 3'b100;
    exp_v.channel    = channel;
    exp_v.sop        = 1'b0;
    exp_v.eop        = 1'b1;
    exp_v.eor        = eor_v;
    expected_egress_q.push_back(exp_v);

    merged_locked = merged_locked | eor_v;
    if (!(real_open || emu_open)) begin
      mode = mode_pending;
    end
  endfunction

  function void check_counter_consistency();
    if (expected_egress_q.size() != 0) begin
      `uvm_warning(get_type_name(), $sformatf("%0d expected egress beats remain queued", expected_egress_q.size()))
    end
  endfunction
endclass
