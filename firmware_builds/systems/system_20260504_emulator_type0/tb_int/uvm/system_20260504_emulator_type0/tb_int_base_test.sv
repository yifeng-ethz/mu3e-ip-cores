// tb_int_base_test.sv
// Base UVM test for focus-build integration tb_int.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add base test with reset-per-test and continuous-frame hooks.

package tb_int_base_test_pkg;

    import uvm_pkg::*;
    import tb_int_env_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        TB_INT_EXEC_ISOLATED,
        TB_INT_EXEC_BUCKET_FRAME,
        TB_INT_EXEC_ALL_BUCKETS_FRAME
    } tb_int_exec_mode_e;

    class tb_int_base_test extends uvm_test;
        `uvm_component_utils(tb_int_base_test)

        tb_int_env env;
        tb_int_exec_mode_e exec_mode;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            exec_mode = TB_INT_EXEC_ISOLATED;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            string mode_name;

            super.build_phase(phase);
            if ($value$plusargs("TB_INT_EXEC_MODE=%s", mode_name)) begin
                if (mode_name == "bucket_frame")
                    exec_mode = TB_INT_EXEC_BUCKET_FRAME;
                else if (mode_name == "all_buckets_frame")
                    exec_mode = TB_INT_EXEC_ALL_BUCKETS_FRAME;
                else
                    exec_mode = TB_INT_EXEC_ISOLATED;
            end
            env = tb_int_env::type_id::create("env", this);
        endfunction

        virtual task reset_per_test_delay();
            if (exec_mode == TB_INT_EXEC_ISOLATED)
                tb_int_run_window_db::reset();
        endtask
    endclass

endpackage
