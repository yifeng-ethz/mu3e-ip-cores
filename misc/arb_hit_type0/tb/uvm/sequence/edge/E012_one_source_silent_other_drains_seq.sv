class E012_one_source_silent_other_drains_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E012_one_source_silent_other_drains_seq)

  function new(string name = "E012_one_source_silent_other_drains_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E012_one_source_silent_other_drains();
  endtask
endclass
