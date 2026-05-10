// error_sc_019_write_ro_status_test.sv
// ERROR bucket directed test for ERROR-SC-019.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260505
// Change  : Add bucket-isolated ERROR case test.

import uvm_pkg::*;
import tb_int_base_test_pkg::*;
`include "uvm_macros.svh"

class error_sc_019_write_ro_status_test extends tb_int_base_test;
    `uvm_component_utils(error_sc_019_write_ro_status_test)

    localparam int unsigned ERROR_MAX_RESIDUAL = 0;
    localparam int unsigned ERROR_EXPECTED_CLOSED = 4;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        uvm_object seq_obj;
        uvm_sequence_base seq;

        phase.raise_objection(this);
        reset_per_test_delay();
        env.scoreboard.require_zero_residual = (ERROR_MAX_RESIDUAL == 0);
        env.scoreboard.expected_closed_records = ERROR_EXPECTED_CLOSED;
        seq_obj = uvm_factory::get().create_object_by_name("error_sc_019_write_ro_status_seq", "", "error_sc_019_write_ro_status_seq");
        if (!$cast(seq, seq_obj))
            `uvm_fatal("ERROR_TEST", "factory could not create error_sc_019_write_ro_status_seq")
        seq.start(null);
        $display("*** TEST PASSED ***");
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        int unsigned residual;

        super.report_phase(phase);
        residual = env.scoreboard.total_missing_pre +
                   env.scoreboard.total_ghost_pre +
                   env.scoreboard.total_missing_post +
                   env.scoreboard.total_ghost_post +
                   env.scoreboard.total_missing_feb +
                   env.scoreboard.total_ghost_feb;
        if (residual > ERROR_MAX_RESIDUAL) begin
            `uvm_error("ERROR_TEST",
                       $sformatf("residual above case threshold residual=%0d max=%0d",
                                 residual,
                                 ERROR_MAX_RESIDUAL))
        end
        `uvm_info("ERROR_TEST",
                  $sformatf("residual=%0d max=%0d closed=%0d expected_closed=%0d",
                            residual,
                            ERROR_MAX_RESIDUAL,
                            env.scoreboard.total_closed_records,
                            ERROR_EXPECTED_CLOSED),
                  UVM_LOW)
    endfunction
endclass

module error_sc_019_write_ro_status_test_factory_anchor;
    uvm_object_wrapper anchor_wrapper = error_sc_019_write_ro_status_test::type_id::get();
endmodule

bind tb_int_top error_sc_019_write_ro_status_test_factory_anchor u_error_sc_019_write_ro_status_test_factory_anchor();
