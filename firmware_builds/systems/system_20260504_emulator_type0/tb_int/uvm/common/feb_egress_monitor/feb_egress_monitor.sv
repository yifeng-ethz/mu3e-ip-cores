// feb_egress_monitor.sv
// Passive FEB-egress framed-payload observation monitor.
// Author: Yifeng Wang
// Version : 26.2.2
// Date    : 20260506
// Change  : Preserve source-supplied debug lineage when available.

package tb_int_feb_egress_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    class feb_egress_monitor extends uvm_component;
        `uvm_component_utils(feb_egress_monitor)

        virtual hit_tap_if vif;
        uvm_analysis_port#(hit_record) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "vif", vif))
                `uvm_info("FEB_MON", "hit_tap_if not configured; monitor disabled", UVM_LOW)
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

                    rec = hit_record::type_id::create("feb_egress_hit");
                    rec.set_from_hit0(vif.hit_id_valid ? vif.hit_id : 64'd0,
                                      vif.lane_id,
                                      vif.payload,
                                      $time,
                                      OBS_STAGE_FEB_EGRESS);
                    rec.root_hit_id_valid = vif.root_hit_id_valid;
                    rec.root_hit_id       = vif.root_hit_id;
                    rec.monitor_debug_valid = vif.root_hit_id_valid | vif.hit_id_valid;
                    rec.monitor_debug_id = vif.root_hit_id_valid ? vif.root_hit_id :
                                           (vif.hit_id_valid ? vif.hit_id : 64'd0);
                    rec.monitor_debug_level = vif.debug_level;
                    rec.run_origin        = vif.run_origin |
                                            tb_int_run_window_db::is_stable_origin($time);
                    ap.write(rec);
                end
            end
        endtask
    endclass

endpackage
