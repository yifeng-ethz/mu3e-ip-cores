class E010_simultaneous_full_both_sources_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E010_simultaneous_full_both_sources_test)

  function new(string name = "E010_simultaneous_full_both_sources_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E010_simultaneous_full_both_sources_seq seq;

    seq = E010_simultaneous_full_both_sources_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
