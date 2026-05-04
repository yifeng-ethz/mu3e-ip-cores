class E012b_overlapping_frames_merged_into_one_packet_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E012b_overlapping_frames_merged_into_one_packet_test)

  function new(string name = "E012b_overlapping_frames_merged_into_one_packet_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E012b_overlapping_frames_merged_into_one_packet_seq seq;

    seq = E012b_overlapping_frames_merged_into_one_packet_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
