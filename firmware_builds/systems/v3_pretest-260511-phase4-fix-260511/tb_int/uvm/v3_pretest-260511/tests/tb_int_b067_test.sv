// tb_int_b067_test.sv
// BASIC B067: DEBUG_LEVEL=2 sidecar lineage validation, lane 0.

package tb_int_b067_test_pkg;

    import uvm_pkg::*;
    import tb_int_base_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_b067_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_b067_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            run_basic_sequence("B067", 100);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
