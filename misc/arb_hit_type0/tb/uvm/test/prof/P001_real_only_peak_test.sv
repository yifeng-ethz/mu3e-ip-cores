class prof_test_base extends arb_hit_type0_base_test;
  function new(string name = "prof_test_base", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task automatic run_prof_sequence(prof_direct_seq_base seq, uvm_phase phase);
    phase.raise_objection(this);
    wait_reset_release();
    seq.cfg        = cfg;
    seq.scoreboard = env.scoreboard;
    seq.seed       = cfg.seed;
    seq.start(env.vseqr);
    repeat (16) @(cfg.reset_vif.mon_cb);
    `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

class P001_real_only_peak_test extends prof_test_base;
  `uvm_component_utils(P001_real_only_peak_test)

  function new(string name = "P001_real_only_peak_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P001_real_only_peak_seq seq;

    seq = P001_real_only_peak_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
