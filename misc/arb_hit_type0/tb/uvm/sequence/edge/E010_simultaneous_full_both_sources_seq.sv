class E010_simultaneous_full_both_sources_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E010_simultaneous_full_both_sources_seq)

  function new(string name = "E010_simultaneous_full_both_sources_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E010_simultaneous_full_both_sources();
  endtask
endclass
