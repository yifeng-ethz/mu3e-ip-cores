class real_st_sequencer extends uvm_sequencer #(hit_type0_seq_item);
  `uvm_component_utils(real_st_sequencer)

  function new(string name = "real_st_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
