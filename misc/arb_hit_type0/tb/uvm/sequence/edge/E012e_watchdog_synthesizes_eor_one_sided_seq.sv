class E012e_watchdog_synthesizes_eor_one_sided_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E012e_watchdog_synthesizes_eor_one_sided_seq)

  function new(string name = "E012e_watchdog_synthesizes_eor_one_sided_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E012e_watchdog_synthesizes_eor_one_sided();
  endtask
endclass
