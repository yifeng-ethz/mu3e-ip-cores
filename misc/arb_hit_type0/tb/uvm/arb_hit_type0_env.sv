class arb_hit_type0_env extends uvm_env;
  `uvm_component_utils(arb_hit_type0_env)

  arb_hit_type0_env_cfg           cfg;
  real_st_agent                   real_agent;
  emu_st_agent                    emu_agent;
  csr_agent                       csr_agent_h;
  runctl_agent                    runctl_agent_h;
  egress_st_agent                 egress_agent;
  arb_hit_type0_scoreboard        scoreboard;
  arb_hit_type0_virtual_sequencer vseqr;

  function new(string name = "arb_hit_type0_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(arb_hit_type0_env_cfg)::get(this, "", "env_cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "missing env_cfg")
    end

    uvm_config_db#(virtual arb_hit_type0_hit_if)::set(this, "real_agent", "vif", cfg.real_vif);
    uvm_config_db#(virtual arb_hit_type0_hit_if)::set(this, "emu_agent", "vif", cfg.emu_vif);
    uvm_config_db#(virtual arb_hit_type0_hit_mon_if)::set(this, "egress_agent", "vif", cfg.egress_vif);
    uvm_config_db#(virtual arb_hit_type0_csr_if)::set(this, "csr_agent_h", "vif", cfg.csr_vif);
    uvm_config_db#(virtual arb_hit_type0_runctl_if)::set(this, "runctl_agent_h", "vif", cfg.runctl_vif);
    uvm_config_db#(arb_hit_type0_env_cfg)::set(this, "*", "env_cfg", cfg);

    real_agent       = real_st_agent::type_id::create("real_agent", this);
    emu_agent        = emu_st_agent::type_id::create("emu_agent", this);
    csr_agent_h      = csr_agent::type_id::create("csr_agent_h", this);
    runctl_agent_h   = runctl_agent::type_id::create("runctl_agent_h", this);
    egress_agent     = egress_st_agent::type_id::create("egress_agent", this);
    vseqr            = arb_hit_type0_virtual_sequencer::type_id::create("vseqr", this);
    if (cfg.enable_scoreboard) begin
      scoreboard = arb_hit_type0_scoreboard::type_id::create("scoreboard", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vseqr.real_seqr   = real_agent.seqr;
    vseqr.emu_seqr    = emu_agent.seqr;
    vseqr.csr_seqr    = csr_agent_h.seqr;
    vseqr.runctl_seqr = runctl_agent_h.seqr;

    if (cfg.enable_scoreboard) begin
      real_agent.mon.ap.connect(scoreboard.real_imp);
      emu_agent.mon.ap.connect(scoreboard.emu_imp);
      egress_agent.mon.ap.connect(scoreboard.egress_imp);
      csr_agent_h.mon.ap.connect(scoreboard.csr_imp);
      runctl_agent_h.mon.ap.connect(scoreboard.runctl_imp);
    end
  endfunction
endclass
