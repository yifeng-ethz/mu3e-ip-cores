class arb_hit_type0_edge_base_test extends arb_hit_type0_base_test;
  `uvm_component_utils(arb_hit_type0_edge_base_test)

  function new(string name = "arb_hit_type0_edge_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task automatic run_edge_sequence(uvm_phase phase, arb_hit_type0_edge_base_seq seq);
    phase.raise_objection(this);
    wait_reset_release();
    seq.cfg        = cfg;
    seq.scoreboard = env.scoreboard;
    seq.start(env.vseqr);
    repeat (16) @(cfg.reset_vif.mon_cb);
    `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
