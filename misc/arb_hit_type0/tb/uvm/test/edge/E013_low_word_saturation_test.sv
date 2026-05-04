class E013_low_word_saturation_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E013_low_word_saturation_test)

  function new(string name = "E013_low_word_saturation_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E013_low_word_saturation_seq seq;

    seq = E013_low_word_saturation_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
