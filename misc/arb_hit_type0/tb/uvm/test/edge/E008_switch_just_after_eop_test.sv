class E008_switch_just_after_eop_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E008_switch_just_after_eop_test)

  function new(string name = "E008_switch_just_after_eop_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E008_switch_just_after_eop_seq seq;

    seq = E008_switch_just_after_eop_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
