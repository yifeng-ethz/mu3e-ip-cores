// debug_post_rbcam_sidecar_monitor.sv
// DEBUG_LEVEL=2 sidecar monitor at post-rbCAM.

package tb_int_debug_post_rbcam_sidecar_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    class debug_post_rbcam_sidecar_monitor extends uvm_component;
        `uvm_component_utils(debug_post_rbcam_sidecar_monitor)

        virtual hit_tap_if vif;
        uvm_analysis_port#(hit_record) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "vif", vif))
                `uvm_info("DBG_POST", "hit_tap_if not configured; monitor disabled", UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                time sample_time;

                @(posedge vif.clk);
                sample_time = $time;
                #1ps;
                if (vif.rst === 1'b1)
                    continue;
                if (vif.valid === 1'b1 && (vif.hit_id_valid || vif.root_hit_id_valid)) begin
                    hit_record rec;

                    rec = hit_record::type_id::create("debug_post_rbcam_hit");
                    rec.set_from_hit0(vif.hit_id_valid ? vif.hit_id : vif.root_hit_id,
                                      vif.lane_id,
                                      vif.payload,
                                      sample_time,
                                      OBS_STAGE_POST_RBCAM);
                    rec.root_hit_id_valid = 1'b1;
                    rec.root_hit_id = vif.root_hit_id_valid ? vif.root_hit_id : vif.hit_id;
                    rec.true_hit_ts_valid = vif.true_hit_ts_valid;
                    rec.true_hit_ts = vif.true_hit_ts;
                    rec.monitor_debug_valid = 1'b1;
                    rec.monitor_debug_id = rec.root_hit_id;
                    rec.monitor_debug_level = vif.debug_level;
                    rec.run_origin = vif.run_origin |
                                     tb_int_run_window_db::is_stable_origin($time);
                    ap.write(rec);
                end
            end
        endtask
    endclass

endpackage
