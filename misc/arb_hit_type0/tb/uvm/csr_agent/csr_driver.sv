class csr_driver extends uvm_driver #(csr_seq_item);
  `uvm_component_utils(csr_driver)

  localparam int unsigned MAX_WAIT_CYCLES = 32;

  virtual arb_hit_type0_csr_if vif;

  function new(string name = "csr_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_csr_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing CSR interface")
    end
  endfunction

  task run_phase(uvm_phase phase);
    csr_seq_item req;

    reset_outputs();
    forever begin
      wait_for_reset_release();
      seq_item_port.get_next_item(req);
      if (req == null) begin
        `uvm_error(get_type_name(), "Received null csr_seq_item")
        seq_item_port.item_done();
        continue;
      end
      if (req.is_write) begin
        drive_write(req);
      end else begin
        drive_read(req);
      end
      seq_item_port.item_done();
    end
  endtask

  task automatic wait_for_reset_release();
    while (vif.rst === 1'b1) begin
      reset_outputs();
      @(posedge vif.clk);
    end
  endtask

  task automatic wait_for_accept();
    int unsigned cycles;

    cycles = 0;
    while (vif.waitrequest === 1'b1) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles > MAX_WAIT_CYCLES) begin
        `uvm_fatal(get_type_name(), "CSR waitrequest remained high")
      end
    end
  endtask

  task automatic reset_outputs();
    vif.address      <= '0;
    vif.write        <= 1'b0;
    vif.read         <= 1'b0;
    vif.writedata    <= '0;
  endtask

  task automatic drive_write(csr_seq_item item);
    @(posedge vif.clk);
    vif.address      <= item.address;
    vif.writedata    <= item.writedata;
    vif.write        <= 1'b1;
    vif.read         <= 1'b0;

    @(posedge vif.clk);
    wait_for_accept();
    reset_outputs();
  endtask

  task automatic drive_read(csr_seq_item item);
    @(posedge vif.clk);
    vif.address      <= item.address;
    vif.writedata    <= '0;
    vif.write        <= 1'b0;
    vif.read         <= 1'b1;

    @(posedge vif.clk);
    wait_for_accept();
    #1step;
    item.readdata = vif.readdata;
    reset_outputs();
  endtask
endclass
