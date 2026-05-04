class E018_status_live_packet_flags_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E018_status_live_packet_flags_seq)

  function new(string name = "E018_status_live_packet_flags_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E018_status_live_packet_flags();
  endtask
endclass
