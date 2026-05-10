class P004_emulator_raw_3p5_cycles_per_hit_test extends prof_test_base;
  `uvm_component_utils(P004_emulator_raw_3p5_cycles_per_hit_test)

  function new(string name = "P004_emulator_raw_3p5_cycles_per_hit_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P004_emulator_raw_3p5_cycles_per_hit_seq seq;

    seq = P004_emulator_raw_3p5_cycles_per_hit_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
