class arb_hit_type0_base_test extends uvm_test;
  `uvm_component_utils(arb_hit_type0_base_test)

  arb_hit_type0_env     env;
  arb_hit_type0_env_cfg cfg;

  function new(string name = "arb_hit_type0_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    int seed_v;

    super.build_phase(phase);
    if (!uvm_config_db#(arb_hit_type0_env_cfg)::get(this, "", "env_cfg", cfg)) begin
      `uvm_fatal(get_type_name(), "missing env_cfg")
    end
    if ($value$plusargs("ARB_SEED=%d", seed_v)) begin
      cfg.seed = seed_v;
    end
    uvm_config_db#(arb_hit_type0_env_cfg)::set(this, "env", "env_cfg", cfg);
    env = arb_hit_type0_env::type_id::create("env", this);
  endfunction

  task automatic wait_reset_release();
    while (cfg.reset_vif.rst !== 1'b0) begin
      @(cfg.reset_vif.mon_cb);
    end
    repeat (4) @(cfg.reset_vif.mon_cb);
  endtask

  task automatic csr_write(input bit [4:0] address, input bit [31:0] data);
    csr_write_seq seq;

    seq = csr_write_seq::type_id::create($sformatf("csr_write_%0h", address));
    seq.address   = address;
    seq.writedata = data;
    seq.start(env.csr_agent_h.seqr);
  endtask

  task automatic csr_read(input bit [4:0] address, output bit [31:0] data);
    csr_read_seq seq;

    seq = csr_read_seq::type_id::create($sformatf("csr_read_%0h", address));
    seq.address = address;
    seq.start(env.csr_agent_h.seqr);
    data = seq.readdata;
  endtask

  task automatic csr_read_pair(input bit [4:0] addr_lo, output bit [63:0] data64);
    bit [31:0] lo_v;
    bit [31:0] hi_v;

    csr_read(addr_lo, lo_v);
    csr_read(addr_lo + 5'd1, hi_v);
    data64 = {hi_v, lo_v};
  endtask

  task automatic send_runctl(input bit [8:0] data);
    runctl_word_seq seq;

    seq = runctl_word_seq::type_id::create($sformatf("runctl_%0h", data));
    seq.data = data;
    seq.start(env.runctl_agent_h.seqr);
  endtask

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if ((env != null) && (env.scoreboard != null)) begin
      env.scoreboard.check_counter_consistency();
    end
  endfunction
endclass
