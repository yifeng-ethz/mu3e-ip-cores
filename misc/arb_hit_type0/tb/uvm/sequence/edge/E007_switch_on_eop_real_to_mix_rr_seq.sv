class E007_switch_on_eop_real_to_mix_rr_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E007_switch_on_eop_real_to_mix_rr_seq)

  function new(string name = "E007_switch_on_eop_real_to_mix_rr_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E007_switch_on_eop_real_to_mix_rr();
  endtask
endclass
