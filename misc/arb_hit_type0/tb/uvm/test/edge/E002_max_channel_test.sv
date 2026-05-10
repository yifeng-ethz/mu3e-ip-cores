class E002_max_channel_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E002_max_channel_test)

  function new(string name = "E002_max_channel_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E002_max_channel_seq seq;

    seq = E002_max_channel_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
