class E008_switch_just_after_eop_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E008_switch_just_after_eop_seq)

  function new(string name = "E008_switch_just_after_eop_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E008_switch_just_after_eop();
  endtask
endclass
