// l2_fifo_commit_monitor.sv
// Passive Stage-A monitor for the emulator MuTRiG L2 FIFO commit point.
// Author: Yifeng Wang
// Version : 26.2.1
// Date    : 20260506
// Change  : Allow optional aggregate monitor slots to be left unbound.

package tb_int_l2_fifo_commit_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    // The durable hit commit point in be_mutrig_lane_emitter.sv is the cycle
    // pending_valid & l2_wr_ready is true. Do not sample a non-existent
    // commit_strobe. This per-stage monitor placement follows the precedent
    // from mutrig_timestamp_processor BUG_HISTORY.md R-2026-04-18-01, where
    // a pre-rbCAM monitor caught the wrong tcc_8n at coarse-counter wrap.
    class l2_fifo_commit_monitor extends uvm_component;
        `uvm_component_utils(l2_fifo_commit_monitor)

        virtual mutrig_l2_commit_if vif;
        uvm_analysis_port#(hit_record) ap;
        static bit [63:0] next_hit_id = 64'd0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual mutrig_l2_commit_if)::get(this, "", "vif", vif))
                `uvm_info("L2_COMMIT", "mutrig_l2_commit_if not configured; monitor disabled", UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1)
                    continue;
                if (vif.valid === 1'b1) begin
                    hit_record rec;

                    rec = hit_record::type_id::create("stage_a_hit");
                    rec.set_from_hit0(next_hit_id,
                                      vif.lane_id,
                                      vif.payload,
                                      $time,
                                      OBS_STAGE_A);
                    rec.root_hit_id_valid = 1'b1;
                    rec.root_hit_id       = next_hit_id;
                    rec.run_origin        = tb_int_run_window_db::is_stable_origin($time);
                    next_hit_id++;
                    ap.write(rec);
                end
            end
        endtask
    endclass

endpackage
