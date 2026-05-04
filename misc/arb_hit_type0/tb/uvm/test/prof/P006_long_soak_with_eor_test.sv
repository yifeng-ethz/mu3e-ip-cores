class P006_long_soak_with_eor_test extends prof_test_base;
  `uvm_component_utils(P006_long_soak_with_eor_test)

  function new(string name = "P006_long_soak_with_eor_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P006_long_soak_with_eor_seq seq;

    seq = P006_long_soak_with_eor_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
