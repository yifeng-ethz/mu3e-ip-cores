interface arb_hit_type0_clk_rst_if(input logic clk, input logic rst);
  clocking mon_cb @(posedge clk);
    input rst;
  endclocking
endinterface

interface arb_hit_type0_hit_if(input logic clk, input logic rst);
  logic [44:0] data;
  logic        valid;
  logic [2:0]  error;
  logic [3:0]  channel;
  logic        sop;
  logic        eop;
  logic        eor;

  task automatic init_source();
    data       <= '0;
    valid      <= 1'b0;
    error      <= '0;
    channel    <= '0;
    sop        <= 1'b0;
    eop        <= 1'b0;
    eor        <= 1'b0;
  endtask
endinterface

interface arb_hit_type0_hit_mon_if(input logic clk, input logic rst);
  logic [44:0] data;
  logic        valid;
  logic [2:0]  error;
  logic [3:0]  channel;
  logic        sop;
  logic        eop;
  logic        eor;
endinterface

interface arb_hit_type0_csr_if(input logic clk, input logic rst);
  logic [4:0]  address;
  logic        write;
  logic        read;
  logic [31:0] writedata;
  logic [31:0] readdata;
  logic        waitrequest;

  task automatic init_master();
    address      <= '0;
    write        <= 1'b0;
    read         <= 1'b0;
    writedata    <= '0;
  endtask
endinterface

interface arb_hit_type0_runctl_if(input logic clk, input logic rst);
  logic [8:0] data;
  logic       valid;
  logic       ready;

  task automatic init_source();
    data     <= '0;
    valid    <= 1'b0;
  endtask
endinterface

package arb_hit_type0_pkg;
  import uvm_pkg::*;
  import lcg_prng_pkg::*;
  import arb_hit_type0_reg_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_real)
  `uvm_analysis_imp_decl(_emu)
  `uvm_analysis_imp_decl(_egress)
  `uvm_analysis_imp_decl(_csr)
  `uvm_analysis_imp_decl(_runctl)

  localparam int unsigned ARB_FIFO_DEPTH = 16;

  typedef enum bit [1:0] {
    ARB_MODE_REAL   = 2'd0,
    ARB_MODE_EMU    = 2'd1,
    ARB_MODE_MIX_RR = 2'd2
  } arb_mode_e;

  typedef enum bit {
    ARB_SRC_REAL = 1'b0,
    ARB_SRC_EMU  = 1'b1
  } arb_source_e;

  typedef enum int unsigned {
    ARB_FIFO_EMPTY = 0,
    ARB_FIFO_MID   = 1,
    ARB_FIFO_FULL  = 2
  } arb_fifo_state_e;

  function automatic string arb_mode_name(input bit [1:0] mode);
    case (mode)
      ARB_MODE_REAL_CONST:   return "REAL";
      ARB_MODE_EMU_CONST:    return "EMU";
      ARB_MODE_MIX_RR_CONST: return "MIX_RR";
      default:               return "RESERVED";
    endcase
  endfunction

  function automatic longint unsigned arb_sat_inc64(input longint unsigned value);
    if (value == 64'hFFFF_FFFF_FFFF_FFFF) begin
      return value;
    end
    return value + 64'd1;
  endfunction

  function automatic int unsigned arb_sat_inc32(input int unsigned value);
    if (value == 32'hFFFF_FFFF) begin
      return value;
    end
    return value + 32'd1;
  endfunction

  task automatic csr_read_pair(
    input virtual arb_hit_type0_csr_if vif,
    input bit [4:0]                    addr_lo,
    output bit [63:0]                  data64
  );
    bit [31:0] lo_v;
    bit [31:0] hi_v;

    @(posedge vif.clk);
    vif.address      <= addr_lo;
    vif.writedata    <= '0;
    vif.write        <= 1'b0;
    vif.read         <= 1'b1;
    @(posedge vif.clk);
    vif.read         <= 1'b0;
    @(posedge vif.clk);
    #1step;
    lo_v = vif.readdata;

    @(posedge vif.clk);
    vif.address    <= addr_lo + 5'd1;
    vif.read       <= 1'b1;
    @(posedge vif.clk);
    vif.read       <= 1'b0;
    @(posedge vif.clk);
    #1step;
    hi_v   = vif.readdata;
    data64 = {hi_v, lo_v};
  endtask

  class arb_hit_type0_env_cfg extends uvm_object;
    `uvm_object_utils(arb_hit_type0_env_cfg)

    virtual arb_hit_type0_clk_rst_if reset_vif;
    virtual arb_hit_type0_hit_if     real_vif;
    virtual arb_hit_type0_hit_if     emu_vif;
    virtual arb_hit_type0_hit_mon_if egress_vif;
    virtual arb_hit_type0_csr_if     csr_vif;
    virtual arb_hit_type0_runctl_if  runctl_vif;
    bit                              enable_scoreboard = 1'b1;
    bit                              enable_coverage   = 1'b1;
    int unsigned                     seed              = 1;

    function new(string name = "arb_hit_type0_env_cfg");
      super.new(name);
    endfunction
  endclass

  `include "hit_type0_seq_item.sv"
  `include "csr_seq_item.sv"
  `include "csr_write_seq.sv"
  `include "csr_read_seq.sv"
  `include "runctl_seq_item.sv"
  `include "runctl_word_seq.sv"
  `include "real_st_agent/real_st_sequencer.sv"
  `include "real_st_agent/real_st_driver.sv"
  `include "real_st_agent/real_st_monitor.sv"
  `include "real_st_agent/real_st_agent.sv"
  `include "emu_st_agent/emu_st_sequencer.sv"
  `include "emu_st_agent/emu_st_driver.sv"
  `include "emu_st_agent/emu_st_monitor.sv"
  `include "emu_st_agent/emu_st_agent.sv"
  `include "csr_agent/csr_sequencer.sv"
  `include "csr_agent/csr_driver.sv"
  `include "csr_agent/csr_monitor.sv"
  `include "csr_agent/csr_agent.sv"
  `include "runctl_agent/runctl_sequencer.sv"
  `include "runctl_agent/runctl_driver.sv"
  `include "runctl_agent/runctl_monitor.sv"
  `include "runctl_agent/runctl_agent.sv"
  `include "egress_st_agent/egress_st_monitor.sv"
  `include "egress_st_agent/egress_st_agent.sv"
  `include "arb_hit_type0_scoreboard.sv"
  `include "arb_hit_type0_virtual_seq.sv"
  `include "arb_hit_type0_env.sv"
  `include "arb_hit_type0_base_test.sv"
  `include "arb_hit_type0_smoke_test.sv"
  `include "sequence/edge/E000_edge_common_seq.sv"
  `include "sequence/edge/E001_single_beat_packet_seq.sv"
  `include "sequence/edge/E002_max_channel_seq.sv"
  `include "sequence/edge/E003_all_error_bits_set_seq.sv"
  `include "sequence/edge/E004_eor_only_packet_seq.sv"
  `include "sequence/edge/E005_long_packet_at_fifo_depth_seq.sv"
  `include "sequence/edge/E006_switch_on_eop_clock_real_to_emu_seq.sv"
  `include "sequence/edge/E007_switch_on_eop_real_to_mix_rr_seq.sv"
  `include "sequence/edge/E008_switch_just_after_eop_seq.sv"
  `include "sequence/edge/E009_fifo_full_to_empty_seq.sv"
  `include "sequence/edge/E010_simultaneous_full_both_sources_seq.sv"
  `include "sequence/edge/E011_alternating_single_beat_packets_mix_rr_seq.sv"
  `include "sequence/edge/E012_one_source_silent_other_drains_seq.sv"
  `include "sequence/edge/E012b_overlapping_frames_merged_into_one_packet_seq.sv"
  `include "sequence/edge/E012c_eor_after_other_active_seq.sv"
  `include "sequence/edge/E012d_eor_simultaneous_at_egress_seq.sv"
  `include "sequence/edge/E012e_watchdog_synthesizes_eor_one_sided_seq.sv"
  `include "sequence/edge/E012f_watchdog_disabled_leaves_packet_open_seq.sv"
  `include "sequence/edge/E013_low_word_saturation_seq.sv"
  `include "sequence/edge/E014_full_64_bit_saturation_clamp_seq.sv"
  `include "sequence/edge/E015_w1p_clear_during_traffic_seq.sv"
  `include "sequence/edge/E016_csr_address_aliasing_seq.sv"
  `include "sequence/edge/E017_read_during_writeable_field_change_seq.sv"
  `include "sequence/edge/E018_status_live_packet_flags_seq.sv"
  `include "test/edge/E000_edge_common_test.sv"
  `include "test/edge/E001_single_beat_packet_test.sv"
  `include "test/edge/E002_max_channel_test.sv"
  `include "test/edge/E003_all_error_bits_set_test.sv"
  `include "test/edge/E004_eor_only_packet_test.sv"
  `include "test/edge/E005_long_packet_at_fifo_depth_test.sv"
  `include "test/edge/E006_switch_on_eop_clock_real_to_emu_test.sv"
  `include "test/edge/E007_switch_on_eop_real_to_mix_rr_test.sv"
  `include "test/edge/E008_switch_just_after_eop_test.sv"
  `include "test/edge/E009_fifo_full_to_empty_test.sv"
  `include "test/edge/E010_simultaneous_full_both_sources_test.sv"
  `include "test/edge/E011_alternating_single_beat_packets_mix_rr_test.sv"
  `include "test/edge/E012_one_source_silent_other_drains_test.sv"
  `include "test/edge/E012b_overlapping_frames_merged_into_one_packet_test.sv"
  `include "test/edge/E012c_eor_after_other_active_test.sv"
  `include "test/edge/E012d_eor_simultaneous_at_egress_test.sv"
  `include "test/edge/E012e_watchdog_synthesizes_eor_one_sided_test.sv"
  `include "test/edge/E012f_watchdog_disabled_leaves_packet_open_test.sv"
  `include "test/edge/E013_low_word_saturation_test.sv"
  `include "test/edge/E014_full_64_bit_saturation_clamp_test.sv"
  `include "test/edge/E015_w1p_clear_during_traffic_test.sv"
  `include "test/edge/E016_csr_address_aliasing_test.sv"
  `include "test/edge/E017_read_during_writeable_field_change_test.sv"
  `include "test/edge/E018_status_live_packet_flags_test.sv"
  `include "sequence/prof/P001_real_only_peak_seq.sv"
  `include "sequence/prof/P002_emu_only_peak_seq.sv"
  `include "sequence/prof/P003_mix_rr_peak_seq.sv"
  `include "sequence/prof/P004_emulator_raw_3p5_cycles_per_hit_seq.sv"
  `include "sequence/prof/P005_basic_soak_1m_cycles_seq.sv"
  `include "sequence/prof/P006_long_soak_with_eor_seq.sv"
  `include "sequence/prof/P007_pair_read_under_traffic_seq.sv"
  `include "sequence/prof/P008_mode_switch_under_peak_seq.sv"
  `include "test/prof/P001_real_only_peak_test.sv"
  `include "test/prof/P002_emu_only_peak_test.sv"
  `include "test/prof/P003_mix_rr_peak_test.sv"
  `include "test/prof/P004_emulator_raw_3p5_cycles_per_hit_test.sv"
  `include "test/prof/P005_basic_soak_1m_cycles_test.sv"
  `include "test/prof/P006_long_soak_with_eor_test.sv"
  `include "test/prof/P007_pair_read_under_traffic_test.sv"
  `include "test/prof/P008_mode_switch_under_peak_test.sv"
endpackage
