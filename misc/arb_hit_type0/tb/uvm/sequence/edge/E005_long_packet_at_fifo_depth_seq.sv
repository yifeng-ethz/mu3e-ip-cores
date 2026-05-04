class E005_long_packet_at_fifo_depth_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E005_long_packet_at_fifo_depth_seq)

  function new(string name = "E005_long_packet_at_fifo_depth_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E005_long_packet_at_fifo_depth();
  endtask
endclass
