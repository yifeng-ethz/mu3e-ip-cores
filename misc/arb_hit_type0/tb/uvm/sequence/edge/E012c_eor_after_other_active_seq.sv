class E012c_eor_after_other_active_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E012c_eor_after_other_active_seq)

  function new(string name = "E012c_eor_after_other_active_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E012c_eor_after_other_active();
  endtask
endclass
