// tb_int_b001_test.sv
// BASIC B001: SWB RC firefly reset-link broadcast IDLE to RUN_PREP.

package tb_int_b001_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_B001_sequence_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_b001_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_b001_test)

        function new(string name = "tb_int_b001_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_B001_sequence seq;

            phase.raise_objection(this);
            seq = tb_int_B001_sequence::type_id::create("seq");
            run_configured_sequence("B001", seq);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
