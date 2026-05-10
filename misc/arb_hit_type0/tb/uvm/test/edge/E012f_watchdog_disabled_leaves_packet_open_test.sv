class E012f_watchdog_disabled_leaves_packet_open_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E012f_watchdog_disabled_leaves_packet_open_test)

  function new(string name = "E012f_watchdog_disabled_leaves_packet_open_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E012f_watchdog_disabled_leaves_packet_open_seq seq;

    seq = E012f_watchdog_disabled_leaves_packet_open_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
