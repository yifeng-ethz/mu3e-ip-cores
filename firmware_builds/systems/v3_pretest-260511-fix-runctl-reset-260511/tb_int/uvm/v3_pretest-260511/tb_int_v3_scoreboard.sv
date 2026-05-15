// tb_int_v3_scoreboard.sv
// v3_pretest additions around the reusable per-bucket ledger scoreboard.

package tb_int_v3_scoreboard_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    import tb_int_scoreboard_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_debug_l2_sidecar)
    `uvm_analysis_imp_decl(_debug_pre_sidecar)
    `uvm_analysis_imp_decl(_debug_post_sidecar)
    `uvm_analysis_imp_decl(_debug_feb_sidecar)

    class tb_int_v3_ledger_scoreboard extends per_bucket_ledger_scoreboard;
        `uvm_component_utils(tb_int_v3_ledger_scoreboard)

        uvm_analysis_imp_debug_l2_sidecar#(hit_record, tb_int_v3_ledger_scoreboard) debug_l2_sidecar_imp;
        uvm_analysis_imp_debug_pre_sidecar#(hit_record, tb_int_v3_ledger_scoreboard) debug_pre_sidecar_imp;
        uvm_analysis_imp_debug_post_sidecar#(hit_record, tb_int_v3_ledger_scoreboard) debug_post_sidecar_imp;
        uvm_analysis_imp_debug_feb_sidecar#(hit_record, tb_int_v3_ledger_scoreboard) debug_feb_sidecar_imp;
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            debug_l2_sidecar_imp = new("debug_l2_sidecar_imp", this);
            debug_pre_sidecar_imp = new("debug_pre_sidecar_imp", this);
            debug_post_sidecar_imp = new("debug_post_sidecar_imp", this);
            debug_feb_sidecar_imp = new("debug_feb_sidecar_imp", this);
        endfunction

        function automatic void normalize_sidecar_record(
            hit_record item,
            observation_point_e point,
            string stage_name
        );
            if (item == null)
                return;
            item.observation_point = point;
            if (!item.monitor_debug_valid && item.root_hit_id_valid) begin
                item.monitor_debug_valid = 1'b1;
                item.monitor_debug_id = item.root_hit_id;
            end
            if (!item.monitor_debug_valid && item.hit_id != 64'd0) begin
                item.monitor_debug_valid = 1'b1;
                item.monitor_debug_id = item.hit_id;
                item.root_hit_id_valid = 1'b1;
                item.root_hit_id = item.hit_id;
            end
            if (item.monitor_debug_valid && !item.root_hit_id_valid) begin
                item.root_hit_id_valid = 1'b1;
                item.root_hit_id = item.monitor_debug_id;
            end
            if (!item.monitor_debug_valid)
                `uvm_warning("TB_INT_V3_SB",
                             $sformatf("sidecar record without debug id at %s: %s",
                                       stage_name, item.describe()))
        endfunction

        virtual function void write_debug_l2_sidecar(hit_record item);
            if (item == null)
                return;
            normalize_sidecar_record(item, OBS_DEBUG_SOURCE, "debug_l2");
            push_debug_obs(stage_debug_source_ledger, item, "debug_l2");
            if (item.monitor_debug_valid)
                total_debug_source++;
        endfunction

        virtual function void write_debug_pre_sidecar(hit_record item);
            if (item == null)
                return;
            normalize_sidecar_record(item, OBS_STAGE_PRE_RBCAM, "debug_pre_rbcam");
            push_debug_obs(stage_pre_rbcam_debug_ledger, item, "debug_pre_rbcam");
            if (item.monitor_debug_valid)
                total_debug_pre_rbcam++;
        endfunction

        virtual function void write_debug_post_sidecar(hit_record item);
            if (item == null)
                return;
            normalize_sidecar_record(item, OBS_STAGE_POST_RBCAM, "debug_post_rbcam");
            push_debug_obs(stage_post_rbcam_debug_ledger, item, "debug_post_rbcam");
            if (item.monitor_debug_valid)
                total_debug_post_rbcam++;
        endfunction

        virtual function void write_debug_feb_sidecar(hit_record item);
            if (item == null)
                return;
            normalize_sidecar_record(item, OBS_STAGE_FEB_EGRESS, "debug_feb_egress");
            push_debug_obs(stage_feb_egress_debug_ledger, item, "debug_feb_egress");
            if (item.monitor_debug_valid)
                total_debug_feb_egress++;
        endfunction

    endclass

endpackage
