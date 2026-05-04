class E009_fifo_full_to_empty_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E009_fifo_full_to_empty_seq)

  function new(string name = "E009_fifo_full_to_empty_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E009_fifo_full_to_empty();
  endtask
endclass
