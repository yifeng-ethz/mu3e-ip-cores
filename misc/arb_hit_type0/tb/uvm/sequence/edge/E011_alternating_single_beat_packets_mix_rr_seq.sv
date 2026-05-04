class E011_alternating_single_beat_packets_mix_rr_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E011_alternating_single_beat_packets_mix_rr_seq)

  function new(string name = "E011_alternating_single_beat_packets_mix_rr_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E011_alternating_single_beat_packets_mix_rr();
  endtask
endclass
