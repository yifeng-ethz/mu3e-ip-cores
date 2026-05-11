// E065.sv
// EDGE selected sequence wrapper.

package tb_int_E065_sequence_pkg;

    import uvm_pkg::*;
    import tb_int_swb_case_sequences_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_E065_sequence extends swb_case_sequence;
        `uvm_object_utils(tb_int_E065_sequence)

        function new(string name = "tb_int_E065_sequence");
            super.new(name);
        endfunction

        task automatic start_case();
            drive_case("E065");
        endtask
    endclass

endpackage
