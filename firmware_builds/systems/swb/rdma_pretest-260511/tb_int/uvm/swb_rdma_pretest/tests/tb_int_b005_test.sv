// tb_int_b005_test.sv
// BASIC B005: SWB RC TERMINATING to IDLE after bounded drain.

package tb_int_b005_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_B005_sequence_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_b005_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_b005_test)

        function new(string name = "tb_int_b005_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_B005_sequence seq;

            phase.raise_objection(this);
            seq = tb_int_B005_sequence::type_id::create("seq");
            run_configured_sequence("B005", seq);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
