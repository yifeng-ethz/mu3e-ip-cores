// tb_int_p003_test.sv
// PROF P003: watchdog overlap while OPQ drains under load.

package tb_int_p003_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_P003_sequence_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_p003_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_p003_test)

        function new(string name = "tb_int_p003_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_P003_sequence seq;

            phase.raise_objection(this);
            seq = tb_int_P003_sequence::type_id::create("seq");
            run_configured_sequence("P003", seq);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
