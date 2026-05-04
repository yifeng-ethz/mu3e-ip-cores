class E001_single_beat_packet_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E001_single_beat_packet_seq)

  function new(string name = "E001_single_beat_packet_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E001_single_beat_packet();
  endtask
endclass
