class E012d_eor_simultaneous_at_egress_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E012d_eor_simultaneous_at_egress_test)

  function new(string name = "E012d_eor_simultaneous_at_egress_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E012d_eor_simultaneous_at_egress_seq seq;

    seq = E012d_eor_simultaneous_at_egress_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
