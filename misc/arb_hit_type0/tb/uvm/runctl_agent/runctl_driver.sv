class runctl_driver extends uvm_driver #(runctl_seq_item);
  `uvm_component_utils(runctl_driver)

  localparam int unsigned MAX_WAIT_CYCLES = 32;

  virtual arb_hit_type0_runctl_if vif;

  function new(string name = "runctl_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_runctl_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing run-control interface")
    end
  endfunction

  task run_phase(uvm_phase phase);
    runctl_seq_item req;

    reset_outputs();
    forever begin
      wait_for_reset_release();
      seq_item_port.get_next_item(req);
      if (req == null) begin
        `uvm_error(get_type_name(), "Received null runctl_seq_item")
        seq_item_port.item_done();
        continue;
      end
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task automatic wait_for_reset_release();
    while (vif.rst === 1'b1) begin
      reset_outputs();
      @(posedge vif.clk);
    end
  endtask

  task automatic reset_outputs();
    vif.valid    <= 1'b0;
    vif.data     <= '0;
  endtask

  task automatic wait_for_ready();
    int unsigned cycles;

    cycles = 0;
    while (vif.ready !== 1'b1) begin
      @(posedge vif.clk);
      cycles++;
      if (cycles > MAX_WAIT_CYCLES) begin
        `uvm_fatal(get_type_name(), "run_ctrl ready remained low")
      end
    end
  endtask

  task automatic drive_item(runctl_seq_item item);
    repeat (item.idle_cycles) begin
      @(posedge vif.clk);
      reset_outputs();
    end

    @(posedge vif.clk);
    vif.valid    <= item.valid;
    vif.data     <= item.data;
    wait_for_ready();

    @(posedge vif.clk);
    reset_outputs();
  endtask
endclass
