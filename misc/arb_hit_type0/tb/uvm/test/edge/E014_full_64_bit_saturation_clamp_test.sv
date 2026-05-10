class E014_full_64_bit_saturation_clamp_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E014_full_64_bit_saturation_clamp_test)

  function new(string name = "E014_full_64_bit_saturation_clamp_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E014_full_64_bit_saturation_clamp_seq seq;

    seq = E014_full_64_bit_saturation_clamp_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
