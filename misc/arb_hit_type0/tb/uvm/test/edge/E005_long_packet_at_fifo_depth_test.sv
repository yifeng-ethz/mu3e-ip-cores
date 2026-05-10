class E005_long_packet_at_fifo_depth_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E005_long_packet_at_fifo_depth_test)

  function new(string name = "E005_long_packet_at_fifo_depth_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E005_long_packet_at_fifo_depth_seq seq;

    seq = E005_long_packet_at_fifo_depth_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
