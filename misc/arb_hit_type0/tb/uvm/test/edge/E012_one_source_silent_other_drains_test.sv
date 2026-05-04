class E012_one_source_silent_other_drains_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E012_one_source_silent_other_drains_test)

  function new(string name = "E012_one_source_silent_other_drains_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E012_one_source_silent_other_drains_seq seq;

    seq = E012_one_source_silent_other_drains_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
