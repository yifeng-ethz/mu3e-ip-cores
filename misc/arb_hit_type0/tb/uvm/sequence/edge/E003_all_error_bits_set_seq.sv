class E003_all_error_bits_set_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E003_all_error_bits_set_seq)

  function new(string name = "E003_all_error_bits_set_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E003_all_error_bits_set();
  endtask
endclass
