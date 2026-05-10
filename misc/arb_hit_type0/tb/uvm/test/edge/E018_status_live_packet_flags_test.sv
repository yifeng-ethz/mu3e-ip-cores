class E018_status_live_packet_flags_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E018_status_live_packet_flags_test)

  function new(string name = "E018_status_live_packet_flags_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E018_status_live_packet_flags_seq seq;

    seq = E018_status_live_packet_flags_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
