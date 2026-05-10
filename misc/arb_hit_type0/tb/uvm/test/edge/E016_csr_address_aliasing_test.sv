class E016_csr_address_aliasing_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E016_csr_address_aliasing_test)

  function new(string name = "E016_csr_address_aliasing_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E016_csr_address_aliasing_seq seq;

    seq = E016_csr_address_aliasing_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
