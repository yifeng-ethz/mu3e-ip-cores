class runctl_word_seq extends uvm_sequence #(runctl_seq_item);
  `uvm_object_utils(runctl_word_seq)

  bit [8:0] data;

  function new(string name = "runctl_word_seq");
    super.new(name);
  endfunction

  task body();
    runctl_seq_item req;

    req = runctl_seq_item::type_id::create("req");
    start_item(req);
    req.valid = 1'b1;
    req.data  = data;
    finish_item(req);
  endtask
endclass
