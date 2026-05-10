class P005_basic_soak_1m_cycles_test extends prof_test_base;
  `uvm_component_utils(P005_basic_soak_1m_cycles_test)

  function new(string name = "P005_basic_soak_1m_cycles_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P005_basic_soak_1m_cycles_seq seq;

    seq = P005_basic_soak_1m_cycles_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
