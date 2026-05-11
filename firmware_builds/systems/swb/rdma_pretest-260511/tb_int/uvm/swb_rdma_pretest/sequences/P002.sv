// P002.sv
// PROF selected sequence wrapper.

package tb_int_P002_sequence_pkg;

    import uvm_pkg::*;
    import tb_int_swb_case_sequences_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_P002_sequence extends swb_case_sequence;
        `uvm_object_utils(tb_int_P002_sequence)

        function new(string name = "tb_int_P002_sequence");
            super.new(name);
        endfunction

        task automatic start_case();
            drive_case("P002");
        endtask
    endclass

endpackage
