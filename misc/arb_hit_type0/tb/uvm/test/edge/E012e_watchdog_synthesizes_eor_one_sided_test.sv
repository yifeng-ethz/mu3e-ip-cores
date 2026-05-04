class E012e_watchdog_synthesizes_eor_one_sided_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E012e_watchdog_synthesizes_eor_one_sided_test)

  function new(string name = "E012e_watchdog_synthesizes_eor_one_sided_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E012e_watchdog_synthesizes_eor_one_sided_seq seq;

    seq = E012e_watchdog_synthesizes_eor_one_sided_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
