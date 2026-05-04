class E012c_eor_after_other_active_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E012c_eor_after_other_active_test)

  function new(string name = "E012c_eor_after_other_active_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E012c_eor_after_other_active_seq seq;

    seq = E012c_eor_after_other_active_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
