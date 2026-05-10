class E014_full_64_bit_saturation_clamp_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E014_full_64_bit_saturation_clamp_seq)

  function new(string name = "E014_full_64_bit_saturation_clamp_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E014_full_64_bit_saturation_clamp();
  endtask
endclass
