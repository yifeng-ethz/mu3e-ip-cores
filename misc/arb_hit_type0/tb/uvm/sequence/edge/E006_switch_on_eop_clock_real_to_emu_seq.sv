class E006_switch_on_eop_clock_real_to_emu_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E006_switch_on_eop_clock_real_to_emu_seq)

  function new(string name = "E006_switch_on_eop_clock_real_to_emu_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E006_switch_on_eop_clock_real_to_emu();
  endtask
endclass
