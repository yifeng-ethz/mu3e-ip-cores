class emu_st_agent extends uvm_agent;
  `uvm_component_utils(emu_st_agent)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  virtual arb_hit_type0_hit_if vif;
  emu_st_driver    drv;
  emu_st_monitor   mon;
  emu_st_sequencer seqr;

  function new(string name = "emu_st_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));
    if (!uvm_config_db#(virtual arb_hit_type0_hit_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing emulator hit interface")
    end
    uvm_config_db#(virtual arb_hit_type0_hit_if)::set(this, "*", "vif", vif);
    mon = emu_st_monitor::type_id::create("mon", this);
    if (is_active == UVM_ACTIVE) begin
      drv  = emu_st_driver::type_id::create("drv", this);
      seqr = emu_st_sequencer::type_id::create("seqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(seqr.seq_item_export);
    end
  endfunction
endclass
