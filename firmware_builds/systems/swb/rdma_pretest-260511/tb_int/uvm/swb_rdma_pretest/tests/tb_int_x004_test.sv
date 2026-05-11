// tb_int_x004_test.sv
// ERROR X004: truncated run-control state word is rejected.

package tb_int_x004_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_X004_sequence_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_x004_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_x004_test)

        function new(string name = "tb_int_x004_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_X004_sequence seq;

            phase.raise_objection(this);
            seq = tb_int_X004_sequence::type_id::create("seq");
            run_configured_sequence("X004", seq);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
