class real_st_monitor extends uvm_monitor;
  `uvm_component_utils(real_st_monitor)

  virtual arb_hit_type0_hit_if vif;
  uvm_analysis_port #(hit_type0_seq_item) ap;

  function new(string name = "real_st_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_hit_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing real hit interface")
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
        txn = hit_type0_seq_item::type_id::create("real_ingress_txn", this);
        txn.source_emu = 1'b0;
        txn.valid      = 1'b1;
        txn.data       = vif.data;
        txn.error      = vif.error;
        txn.channel    = vif.channel;
        txn.sop        = vif.sop;
        txn.eop        = vif.eop;
        txn.eor        = vif.eor;
        if (vif.channel > 4'd7) begin
          `uvm_warning(get_type_name(), $sformatf("Real source channel 0x%0h outside [0..7]", vif.channel))
        end
        ap.write(txn);
      end
    end
  endtask
endclass
