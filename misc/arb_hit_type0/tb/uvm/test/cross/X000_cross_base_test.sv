import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

class X000_cross_base_test extends arb_hit_type0_base_test;
  `uvm_component_utils(X000_cross_base_test)

  function new(string name = "X000_cross_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task automatic run_cross_sequence(uvm_phase phase, arb_hit_type0_base_vseq seq);
    phase.raise_objection(this);
    wait_reset_release();
    seq.start(env.vseqr);
    repeat (80) @(cfg.reset_vif.mon_cb);
    if (env.scoreboard != null) begin
      env.scoreboard.check_counter_consistency();
    end
    `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
