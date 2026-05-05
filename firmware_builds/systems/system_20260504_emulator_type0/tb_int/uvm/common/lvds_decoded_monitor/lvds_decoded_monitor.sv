// lvds_decoded_monitor.sv
// Passive pre-rbCAM hit_type0 observation monitor.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable decoded hit_type0 monitor for pre-rbCAM taps.

package tb_int_lvds_decoded_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_run_window_pkg::*;
    `include "uvm_macros.svh"

    class lvds_decoded_monitor extends uvm_component;
        `uvm_component_utils(lvds_decoded_monitor)

        virtual hit_tap_if vif;
        uvm_analysis_port#(hit_record) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual hit_tap_if)::get(this, "", "vif", vif))
                `uvm_fatal("LVDS_MON", "hit_tap_if not found")
        endfunction

        virtual task run_phase(uvm_phase phase);
            forever begin
                @(posedge vif.clk);
                if (vif.rst === 1'b1)
                    continue;
                if (vif.valid === 1'b1) begin
                    hit_record rec;

                    rec = hit_record::type_id::create("pre_rbcam_hit");
                    rec.set_from_hit0(vif.hit_id_valid ? vif.hit_id : 64'd0,
                                      vif.lane_id,
                                      vif.payload,
                                      $time,
                                      OBS_STAGE_PRE_RBCAM);
                    rec.root_hit_id_valid = vif.root_hit_id_valid;
                    rec.root_hit_id       = vif.root_hit_id;
                    rec.run_origin        = vif.run_origin |
                                            tb_int_run_window_db::is_stable_origin($time);
                    ap.write(rec);
                end
            end
        endtask
    endclass

endpackage
