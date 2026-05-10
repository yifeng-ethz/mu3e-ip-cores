class csr_sequencer extends uvm_sequencer #(csr_seq_item);
  `uvm_component_utils(csr_sequencer)

  function new(string name = "csr_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
