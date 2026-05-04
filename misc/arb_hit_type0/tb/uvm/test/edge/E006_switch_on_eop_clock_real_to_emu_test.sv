class E006_switch_on_eop_clock_real_to_emu_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E006_switch_on_eop_clock_real_to_emu_test)

  function new(string name = "E006_switch_on_eop_clock_real_to_emu_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E006_switch_on_eop_clock_real_to_emu_seq seq;

    seq = E006_switch_on_eop_clock_real_to_emu_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
