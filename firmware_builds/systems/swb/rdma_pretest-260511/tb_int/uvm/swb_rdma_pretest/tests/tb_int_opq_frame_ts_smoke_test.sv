// tb_int_opq_frame_ts_smoke_test.sv
// Auxiliary smoke for the OPQ frame timestamp monitors.

package tb_int_opq_frame_ts_smoke_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_opq_frame_ts_smoke_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_opq_frame_ts_smoke_test)

        localparam bit [7:0] K285 = 8'hbc;
        localparam bit [7:0] K284 = 8'h9c;
        localparam bit [7:0] K237 = 8'hf7;
        localparam int unsigned EXPECTED_SUBHEADERS = 128;

        function new(string name = "tb_int_opq_frame_ts_smoke_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task automatic drive_opq_beat(
            virtual opq_lane_if vif,
            input bit egress,
            input logic [31:0] data,
            input logic [3:0] datak,
            input logic sop,
            input logic eop
        );
            @(posedge vif.clk);
            if (egress) begin
                vif.egress_valid <= 1'b1;
                vif.egress_ready <= 1'b1;
                vif.egress_sop <= sop;
                vif.egress_eop <= eop;
                vif.egress_data <= data;
                vif.egress_datak <= datak;
            end else begin
                vif.ingress_valid <= 1'b1;
                vif.ingress_ready <= 1'b1;
                vif.ingress_sop <= sop;
                vif.ingress_eop <= eop;
                vif.ingress_data <= data;
                vif.ingress_datak <= datak;
            end
            @(posedge vif.clk);
            if (egress) begin
                vif.egress_valid <= 1'b0;
                vif.egress_ready <= 1'b0;
                vif.egress_sop <= 1'b0;
                vif.egress_eop <= 1'b0;
                vif.egress_datak <= 4'h0;
            end else begin
                vif.ingress_valid <= 1'b0;
                vif.ingress_ready <= 1'b0;
                vif.ingress_sop <= 1'b0;
                vif.ingress_eop <= 1'b0;
                vif.ingress_datak <= 4'h0;
            end
        endtask

        task automatic drive_opq_frame(
            virtual opq_lane_if vif,
            input bit egress,
            input logic [15:0] ts_tag,
            input logic [31:0] payload
        );
            int unsigned shd;

            drive_opq_beat(vif, egress, {8'ha5, 2'b00, 14'd0, K285},
                           4'b0001, 1'b1, 1'b0);
            drive_opq_beat(vif, egress, 32'h00000000,
                           4'b0000, 1'b0, 1'b0);
            drive_opq_beat(vif, egress, {ts_tag[15:12], 12'h000, 16'd1},
                           4'b0000, 1'b0, 1'b0);
            drive_opq_beat(vif, egress, {1'b0, 15'd128, 16'd1},
                           4'b0000, 1'b0, 1'b0);
            drive_opq_beat(vif, egress, 32'hc0010000,
                           4'b0000, 1'b0, 1'b0);
            for (shd = 0; shd < EXPECTED_SUBHEADERS; shd++) begin
                drive_opq_beat(vif, egress,
                               {shd[7:0],
                                ((shd[7:0] == ts_tag[11:4]) ? 16'd1 : 16'd0),
                                K237},
                               4'b0001, 1'b0, 1'b0);
                if (shd[7:0] == ts_tag[11:4]) begin
                    drive_opq_beat(vif, egress, {ts_tag[3:0], payload[27:0]},
                                   4'b0000, 1'b0, 1'b0);
                end
            end
            drive_opq_beat(vif, egress, {24'h0, K284},
                           4'b0001, 1'b0, 1'b1);
        endtask

        virtual task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            wait (opq_lane0_vif.reset_n === 1'b1);
            repeat (4) @(posedge opq_lane0_vif.clk);

            env.scoreboard.start_case("OPQ_FRAME_TS_SMOKE");
            drive_opq_frame(opq_lane0_vif, 1'b0, 16'h3456, 32'h00010001);
            drive_opq_frame(opq_lane0_vif, 1'b1, 16'h3456, 32'h00010001);
            repeat (4) @(posedge opq_lane0_vif.clk);

            if (env.scoreboard.opq_frame_ingress_hits != 1) begin
                `uvm_error("OPQ_FRAME_TS_SMOKE",
                           $sformatf("ingress frame hits=%0d expected=1",
                                     env.scoreboard.opq_frame_ingress_hits))
            end
            if (env.scoreboard.opq_frame_egress_hits != 1) begin
                `uvm_error("OPQ_FRAME_TS_SMOKE",
                           $sformatf("egress frame hits=%0d expected=1",
                                     env.scoreboard.opq_frame_egress_hits))
            end
            if (env.scoreboard.opq_frame_ts_invalid != 0) begin
                `uvm_error("OPQ_FRAME_TS_SMOKE",
                           $sformatf("invalid reconstructed timestamps=%0d",
                                     env.scoreboard.opq_frame_ts_invalid))
            end

            $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
