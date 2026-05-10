class E009_fifo_full_to_empty_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E009_fifo_full_to_empty_test)

  function new(string name = "E009_fifo_full_to_empty_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E009_fifo_full_to_empty_seq seq;

    seq = E009_fifo_full_to_empty_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
