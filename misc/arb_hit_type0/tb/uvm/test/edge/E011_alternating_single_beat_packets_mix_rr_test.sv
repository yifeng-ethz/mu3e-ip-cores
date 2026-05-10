class E011_alternating_single_beat_packets_mix_rr_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E011_alternating_single_beat_packets_mix_rr_test)

  function new(string name = "E011_alternating_single_beat_packets_mix_rr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E011_alternating_single_beat_packets_mix_rr_seq seq;

    seq = E011_alternating_single_beat_packets_mix_rr_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
