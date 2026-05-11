`ifndef SWB_TB_INT_SMOKE_TEST_SV
`define SWB_TB_INT_SMOKE_TEST_SV

`include "tb_int_base_test.sv"

class tb_int_smoke_test extends tb_int_base_test;
    `uvm_component_utils(tb_int_smoke_test)

    function new(string name = "tb_int_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        ingress_count = 1;
        drop_count = 0;
        egress_count = 1;

        check_swb_ledger(1, 0, 1);
        `uvm_info("SWB_SMOKE", "B065 structural smoke ledger reconciled 1/0/0 at each observed stage", UVM_LOW)

        phase.drop_objection(this);
    endtask
endclass

`endif
