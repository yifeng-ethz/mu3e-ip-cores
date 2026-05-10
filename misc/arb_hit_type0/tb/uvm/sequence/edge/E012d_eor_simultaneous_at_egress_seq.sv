class E012d_eor_simultaneous_at_egress_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E012d_eor_simultaneous_at_egress_seq)

  function new(string name = "E012d_eor_simultaneous_at_egress_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E012d_eor_simultaneous_at_egress();
  endtask
endclass
