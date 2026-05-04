class P002_emu_only_peak_test extends prof_test_base;
  `uvm_component_utils(P002_emu_only_peak_test)

  function new(string name = "P002_emu_only_peak_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P002_emu_only_peak_seq seq;

    seq = P002_emu_only_peak_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
