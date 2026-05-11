// tb_int_e002_test.sv
// EDGE E002: state CSR co-write during RUN_PREP edge.

package tb_int_e002_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_E002_sequence_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_e002_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_e002_test)

        function new(string name = "tb_int_e002_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_E002_sequence seq;

            phase.raise_objection(this);
            seq = tb_int_E002_sequence::type_id::create("seq");
            run_configured_sequence("E002", seq);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
