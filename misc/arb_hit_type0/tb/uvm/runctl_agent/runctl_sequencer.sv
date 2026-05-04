class runctl_sequencer extends uvm_sequencer #(runctl_seq_item);
  `uvm_component_utils(runctl_sequencer)

  function new(string name = "runctl_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
