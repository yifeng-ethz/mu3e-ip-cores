// tb_int_b006_test.sv
// BASIC B006: SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap.

package tb_int_b006_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_B006_sequence_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_b006_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_b006_test)

        function new(string name = "tb_int_b006_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            tb_int_B006_sequence seq;

            phase.raise_objection(this);
            seq = tb_int_B006_sequence::type_id::create("seq");
            run_configured_sequence("B006", seq);
            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
