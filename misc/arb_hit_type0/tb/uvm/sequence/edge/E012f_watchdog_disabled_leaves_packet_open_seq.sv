class E012f_watchdog_disabled_leaves_packet_open_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E012f_watchdog_disabled_leaves_packet_open_seq)

  function new(string name = "E012f_watchdog_disabled_leaves_packet_open_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E012f_watchdog_disabled_leaves_packet_open();
  endtask
endclass
