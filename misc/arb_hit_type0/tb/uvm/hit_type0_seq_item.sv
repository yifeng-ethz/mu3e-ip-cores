class hit_type0_seq_item extends uvm_sequence_item;
  `uvm_object_utils(hit_type0_seq_item)

  rand bit [44:0]    data;
  rand bit [2:0]     error;
  rand bit [3:0]     channel;
  rand bit           sop;
  rand bit           eop;
  rand bit           eor;
  rand bit           valid;
  rand int unsigned  idle_cycles;
  bit                source_emu;

  constraint idle_reasonable_c {
    idle_cycles inside {[0:1024]};
  }

  function new(string name = "hit_type0_seq_item");
    super.new(name);
    valid       = 1'b1;
    idle_cycles = 0;
  endfunction

  function void do_copy(uvm_object rhs);
    hit_type0_seq_item rhs_t;

    if (!$cast(rhs_t, rhs)) begin
      return;
    end
    data        = rhs_t.data;
    error       = rhs_t.error;
    channel     = rhs_t.channel;
    sop         = rhs_t.sop;
    eop         = rhs_t.eop;
    eor         = rhs_t.eor;
    valid       = rhs_t.valid;
    idle_cycles = rhs_t.idle_cycles;
    source_emu  = rhs_t.source_emu;
  endfunction

  function string convert2string();
    return $sformatf(
      "src=%s valid=%0b data=0x%011h err=0x%0h ch=0x%0h sop=%0b eop=%0b eor=%0b idle=%0d",
      source_emu ? "emu" : "real",
      valid,
      data,
      error,
      channel,
      sop,
      eop,
      eor,
      idle_cycles
    );
  endfunction
endclass
