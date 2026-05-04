class egress_st_monitor extends uvm_monitor;
  `uvm_component_utils(egress_st_monitor)

  virtual arb_hit_type0_hit_mon_if vif;
  uvm_analysis_port #(hit_type0_seq_item) ap;

  function new(string name = "egress_st_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_hit_mon_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing egress hit interface")
    end
  endfunction

  task run_phase(uvm_phase phase);
    hit_type0_seq_item txn;

    forever begin
      @(posedge vif.clk);
      #1step;
      if (vif.rst === 1'b1) begin
        continue;
      end
      if (vif.valid === 1'b1) begin
        txn = hit_type0_seq_item::type_id::create("egress_txn", this);
        txn.valid   = 1'b1;
        txn.data    = vif.data;
        txn.error   = vif.error;
        txn.channel = vif.channel;
        txn.sop     = vif.sop;
        txn.eop     = vif.eop;
        txn.eor     = vif.eor;
        ap.write(txn);
      end
    end
  endtask
endclass
