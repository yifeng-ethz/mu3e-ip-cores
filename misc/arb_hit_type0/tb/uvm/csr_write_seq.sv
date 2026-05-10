class csr_write_seq extends uvm_sequence #(csr_seq_item);
  `uvm_object_utils(csr_write_seq)

  bit [4:0]  address;
  bit [31:0] writedata;

  function new(string name = "csr_write_seq");
    super.new(name);
  endfunction

  task body();
    csr_seq_item req;

    req = csr_seq_item::type_id::create("req");
    start_item(req);
    req.is_write  = 1'b1;
    req.address   = address;
    req.writedata = writedata;
    finish_item(req);
  endtask
endclass
