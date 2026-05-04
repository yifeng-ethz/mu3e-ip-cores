class E013_low_word_saturation_seq extends arb_hit_type0_edge_base_seq;
  `uvm_object_utils(E013_low_word_saturation_seq)

  function new(string name = "E013_low_word_saturation_seq");
    super.new(name);
  endfunction

  task body();
    require_handles();
    case_E013_low_word_saturation();
  endtask
endclass
