class runctl_monitor extends uvm_monitor;
  `uvm_component_utils(runctl_monitor)

  virtual arb_hit_type0_runctl_if vif;
  uvm_analysis_port #(runctl_seq_item) ap;

  function new(string name = "runctl_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_runctl_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing run-control interface")
    end
  endfunction

  task run_phase(uvm_phase phase);
    runctl_seq_item txn;

    forever begin
      @(posedge vif.clk);
      #1step;
      if (vif.rst === 1'b1) begin
        continue;
      end
      if ((vif.valid === 1'b1) && (vif.ready === 1'b1)) begin
        txn = runctl_seq_item::type_id::create("runctl_txn", this);
        txn.valid = 1'b1;
        txn.data  = vif.data;
        ap.write(txn);
      end
    end
  endtask
endclass
