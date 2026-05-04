class P008_mode_switch_under_peak_test extends prof_test_base;
  `uvm_component_utils(P008_mode_switch_under_peak_test)

  function new(string name = "P008_mode_switch_under_peak_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P008_mode_switch_under_peak_seq seq;

    seq = P008_mode_switch_under_peak_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
