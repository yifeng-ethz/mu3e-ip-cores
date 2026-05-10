import uvm_pkg::*;
import arb_hit_type0_pkg::*;
import arb_hit_type0_basic_pkg::*;
import B015_switch_mix_rr_to_real_drains_outstanding_emu_seq_pkg::*;
`include "uvm_macros.svh"

class B015_switch_mix_rr_to_real_drains_outstanding_emu_test extends B000_basic_base_test;
  `uvm_component_utils(B015_switch_mix_rr_to_real_drains_outstanding_emu_test)

  function new(string name = "B015_switch_mix_rr_to_real_drains_outstanding_emu_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    B015_switch_mix_rr_to_real_drains_outstanding_emu_seq seq_h;

    seq_h = B015_switch_mix_rr_to_real_drains_outstanding_emu_seq::type_id::create("seq_h");
    run_basic_sequence(phase, seq_h);
  endtask
endclass
