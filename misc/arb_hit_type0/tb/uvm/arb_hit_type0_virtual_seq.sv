class arb_hit_type0_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(arb_hit_type0_virtual_sequencer)

  real_st_sequencer   real_seqr;
  emu_st_sequencer    emu_seqr;
  csr_sequencer       csr_seqr;
  runctl_sequencer    runctl_seqr;

  function new(string name = "arb_hit_type0_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class arb_hit_type0_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(arb_hit_type0_base_vseq)

  arb_hit_type0_virtual_sequencer vseqr;

  function new(string name = "arb_hit_type0_base_vseq");
    super.new(name);
  endfunction

  task pre_body();
    if (!$cast(vseqr, m_sequencer)) begin
      `uvm_fatal(get_type_name(), "base virtual sequence requires arb_hit_type0_virtual_sequencer")
    end
  endtask

  task automatic csr_write(input bit [4:0] address, input bit [31:0] data);
    csr_write_seq seq;

    seq = csr_write_seq::type_id::create($sformatf("csr_write_%0h", address));
    seq.address   = address;
    seq.writedata = data;
    seq.start(vseqr.csr_seqr);
  endtask

  task automatic csr_read(input bit [4:0] address, output bit [31:0] data);
    csr_read_seq seq;

    seq = csr_read_seq::type_id::create($sformatf("csr_read_%0h", address));
    seq.address = address;
    seq.start(vseqr.csr_seqr);
    data = seq.readdata;
  endtask

  task automatic csr_read_pair(input bit [4:0] addr_lo, output bit [63:0] data64);
    bit [31:0] lo_v;
    bit [31:0] hi_v;

    csr_read(addr_lo, lo_v);
    csr_read(addr_lo + 5'd1, hi_v);
    data64 = {hi_v, lo_v};
  endtask

  task automatic send_runctl(input bit [8:0] data);
    runctl_word_seq seq;

    seq = runctl_word_seq::type_id::create($sformatf("runctl_%0h", data));
    seq.data = data;
    seq.start(vseqr.runctl_seqr);
  endtask
endclass
