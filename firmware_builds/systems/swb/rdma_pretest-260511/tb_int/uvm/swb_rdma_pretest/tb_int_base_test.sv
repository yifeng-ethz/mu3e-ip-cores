`ifndef SWB_TB_INT_BASE_TEST_SV
`define SWB_TB_INT_BASE_TEST_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class tb_int_base_test extends uvm_test;
    `uvm_component_utils(tb_int_base_test)

    int unsigned ingress_count;
    int unsigned drop_count;
    int unsigned egress_count;

    function new(string name = "tb_int_base_test", uvm_component parent = null);
        super.new(name, parent);
        ingress_count = 0;
        drop_count = 0;
        egress_count = 0;
    endfunction

    function void check_swb_ledger(
        int unsigned expected_ingress,
        int unsigned expected_drop,
        int unsigned expected_egress
    );
        if (ingress_count != expected_ingress) begin
            `uvm_error("SWB_LEDGER", $sformatf("ingress_count=%0d expected=%0d", ingress_count, expected_ingress))
        end
        if (drop_count != expected_drop) begin
            `uvm_error("SWB_LEDGER", $sformatf("drop_count=%0d expected=%0d", drop_count, expected_drop))
        end
        if (egress_count != expected_egress) begin
            `uvm_error("SWB_LEDGER", $sformatf("egress_count=%0d expected=%0d", egress_count, expected_egress))
        end
    endfunction
endclass

`endif
