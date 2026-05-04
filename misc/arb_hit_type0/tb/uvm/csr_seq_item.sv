class csr_seq_item extends uvm_sequence_item;
  `uvm_object_utils(csr_seq_item)

  rand bit        is_write;
  rand bit [4:0]  address;
  rand bit [31:0] writedata;
  bit [31:0]      readdata;

  constraint csr_addr_width_c {
    address inside {[5'h00:5'h1F]};
  }

  function new(string name = "csr_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    if (is_write) begin
      return $sformatf("CSR WRITE addr=0x%02h data=0x%08h", address, writedata);
    end
    return $sformatf("CSR READ addr=0x%02h data=0x%08h", address, readdata);
  endfunction
endclass
