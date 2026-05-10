class E004_eor_only_packet_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E004_eor_only_packet_seq)

  function new(string name = "E004_eor_only_packet_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E004_eor_only_packet();
  endtask
endclass
