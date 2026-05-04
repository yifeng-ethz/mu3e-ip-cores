class runctl_seq_item extends uvm_sequence_item;
  `uvm_object_utils(runctl_seq_item)

  localparam bit [8:0] RUN_IDLE_WORD_CONST        = 9'b0_0000_0000;
  localparam bit [8:0] RUN_PREPARING_WORD_CONST   = 9'b0_0000_0010;
  localparam bit [8:0] RUN_SYNCING_WORD_CONST     = 9'b0_0000_0100;
  localparam bit [8:0] RUN_RUNNING_WORD_CONST     = 9'b0_0000_1000;
  localparam bit [8:0] RUN_TERMINATING_WORD_CONST = 9'b0_0001_0000;
  localparam bit [8:0] RUN_TESTING0_WORD_CONST    = 9'b0_0010_0000;
  localparam bit [8:0] RUN_TESTING1_WORD_CONST    = 9'b0_0100_0000;
  localparam bit [8:0] RUN_RESETTING_WORD_CONST   = 9'b0_1000_0000;
  localparam bit [8:0] RUN_OUT_OF_DAQ_WORD_CONST  = 9'b1_0000_0000;

  rand bit [8:0] data;
  rand bit       valid;
  rand int unsigned idle_cycles;

  constraint runctl_idle_reasonable_c {
    idle_cycles inside {[0:1024]};
  }

  function new(string name = "runctl_seq_item");
    super.new(name);
    valid       = 1'b1;
    idle_cycles = 0;
  endfunction

  function string convert2string();
    return $sformatf("runctl valid=%0b data=0x%03h idle=%0d", valid, data, idle_cycles);
  endfunction
endclass
