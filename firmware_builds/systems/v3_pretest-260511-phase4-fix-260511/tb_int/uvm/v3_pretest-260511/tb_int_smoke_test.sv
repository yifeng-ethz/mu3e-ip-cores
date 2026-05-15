// tb_int_smoke_test.sv
// Compatibility alias: default smoke runs BASIC B065.

package tb_int_smoke_test_pkg;

    import uvm_pkg::*;
    import tb_int_b065_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_smoke_test extends tb_int_b065_test;
        `uvm_component_utils(tb_int_smoke_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

endpackage
