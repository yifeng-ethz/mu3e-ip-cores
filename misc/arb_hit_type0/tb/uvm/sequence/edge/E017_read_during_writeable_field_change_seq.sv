class E017_read_during_writeable_field_change_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E017_read_during_writeable_field_change_seq)

  function new(string name = "E017_read_during_writeable_field_change_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E017_read_during_writeable_field_change();
  endtask
endclass
