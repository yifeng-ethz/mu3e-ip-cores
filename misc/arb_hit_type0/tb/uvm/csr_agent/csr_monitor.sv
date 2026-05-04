class csr_monitor extends uvm_monitor;
  `uvm_component_utils(csr_monitor)

  virtual arb_hit_type0_csr_if vif;
  uvm_analysis_port #(csr_seq_item) ap;

  function new(string name = "csr_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_csr_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing CSR interface")
    end
  endfunction

  task run_phase(uvm_phase phase);
    csr_seq_item pending_read;
    bit          pending_read_valid;
    bit          read_seen_prev;
    csr_seq_item txn;

    pending_read       = null;
    pending_read_valid = 1'b0;
    read_seen_prev     = 1'b0;

    forever begin
      @(posedge vif.clk);
      #1step;

      if (vif.rst === 1'b1) begin
        pending_read       = null;
        pending_read_valid = 1'b0;
        read_seen_prev     = 1'b0;
        continue;
      end

      if (pending_read_valid) begin
        pending_read.readdata = vif.readdata;
        ap.write(pending_read);
        pending_read       = null;
        pending_read_valid = 1'b0;
      end

      if ((vif.write === 1'b1) && (vif.waitrequest !== 1'b1)) begin
        txn = csr_seq_item::type_id::create("csr_write_txn", this);
        txn.is_write  = 1'b1;
        txn.address   = vif.address;
        txn.writedata = vif.writedata;
        txn.readdata  = '0;
        ap.write(txn);
      end

      if ((vif.read === 1'b1) && (vif.waitrequest !== 1'b1) && !read_seen_prev) begin
        pending_read = csr_seq_item::type_id::create("csr_read_txn", this);
        pending_read.is_write  = 1'b0;
        pending_read.address   = vif.address;
        pending_read.writedata = '0;
        pending_read.readdata  = '0;
        pending_read_valid     = 1'b1;
      end
      read_seen_prev = ((vif.read === 1'b1) && (vif.waitrequest !== 1'b1));
    end
  endtask
endclass
