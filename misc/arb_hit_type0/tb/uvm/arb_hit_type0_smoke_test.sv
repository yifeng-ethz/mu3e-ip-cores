class arb_hit_type0_smoke_test extends arb_hit_type0_base_test;
  `uvm_component_utils(arb_hit_type0_smoke_test)

  function new(string name = "arb_hit_type0_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [31:0] uid_v;

    phase.raise_objection(this);
    wait_reset_release();
    csr_read(ARB_REG_UID_ADDR, uid_v);
    if (uid_v !== ARB_UID_CONST) begin
      `uvm_error(get_type_name(), $sformatf("UID mismatch expected=0x%08h observed=0x%08h", ARB_UID_CONST, uid_v))
    end
    repeat (8) @(cfg.reset_vif.mon_cb);
    `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
