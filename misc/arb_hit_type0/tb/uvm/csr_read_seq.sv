class csr_read_seq extends uvm_sequence #(csr_seq_item);
  `uvm_object_utils(csr_read_seq)

  bit [4:0]  address;
  bit [31:0] readdata;

  function new(string name = "csr_read_seq");
    super.new(name);
  endfunction

  task body();
    csr_seq_item req;

    req = csr_seq_item::type_id::create("req");
    start_item(req);
    req.is_write  = 1'b0;
    req.address   = address;
    req.writedata = '0;
    finish_item(req);
    readdata = req.readdata;
  endtask
endclass
