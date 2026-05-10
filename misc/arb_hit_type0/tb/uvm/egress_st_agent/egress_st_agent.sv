class egress_st_agent extends uvm_agent;
  `uvm_component_utils(egress_st_agent)

  virtual arb_hit_type0_hit_mon_if vif;
  egress_st_monitor mon;

  function new(string name = "egress_st_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_hit_mon_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing egress hit interface")
    end
    uvm_config_db#(virtual arb_hit_type0_hit_mon_if)::set(this, "*", "vif", vif);
    mon = egress_st_monitor::type_id::create("mon", this);
  endfunction
endclass
