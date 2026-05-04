class E015_w1p_clear_during_traffic_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E015_w1p_clear_during_traffic_test)

  function new(string name = "E015_w1p_clear_during_traffic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E015_w1p_clear_during_traffic_seq seq;

    seq = E015_w1p_clear_during_traffic_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
