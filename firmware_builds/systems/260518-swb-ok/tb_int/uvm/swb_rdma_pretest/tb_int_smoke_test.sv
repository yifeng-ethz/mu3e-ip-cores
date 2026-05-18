// tb_int_smoke_test.sv
// Default smoke wrapper for BASIC B065.

package tb_int_swb_smoke_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_smoke_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_smoke_test)

        function new(string name = "tb_int_smoke_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            run_selected_case("B065");
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
