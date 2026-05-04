class E002_max_channel_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E002_max_channel_seq)

  function new(string name = "E002_max_channel_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E002_max_channel();
  endtask
endclass
