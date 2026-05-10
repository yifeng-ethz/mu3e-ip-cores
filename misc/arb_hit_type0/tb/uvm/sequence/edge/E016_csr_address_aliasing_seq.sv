class E016_csr_address_aliasing_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E016_csr_address_aliasing_seq)

  function new(string name = "E016_csr_address_aliasing_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E016_csr_address_aliasing();
  endtask
endclass
