class E007_switch_on_eop_real_to_mix_rr_test extends arb_hit_type0_edge_base_test;
  `uvm_component_utils(E007_switch_on_eop_real_to_mix_rr_test)

  function new(string name = "E007_switch_on_eop_real_to_mix_rr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    E007_switch_on_eop_real_to_mix_rr_seq seq;

    seq = E007_switch_on_eop_real_to_mix_rr_seq::type_id::create("seq");
    run_edge_sequence(phase, seq);
  endtask
endclass
