class csr_agent extends uvm_agent;
  `uvm_component_utils(csr_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  virtual arb_hit_type0_csr_if vif;
  csr_driver    drv;
  csr_monitor   mon;
  csr_sequencer seqr;

  function new(string name = "csr_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));
    if (!uvm_config_db#(virtual arb_hit_type0_csr_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing CSR interface")
    end
    uvm_config_db#(virtual arb_hit_type0_csr_if)::set(this, "*", "vif", vif);
    mon = csr_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      drv  = csr_driver::type_id::create("drv", this);
      seqr = csr_sequencer::type_id::create("seqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction
endclass
