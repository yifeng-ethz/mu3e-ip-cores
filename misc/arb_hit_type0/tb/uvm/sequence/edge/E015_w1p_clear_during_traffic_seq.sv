class E015_w1p_clear_during_traffic_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E015_w1p_clear_during_traffic_seq)

  function new(string name = "E015_w1p_clear_during_traffic_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E015_w1p_clear_during_traffic();
  endtask
endclass
