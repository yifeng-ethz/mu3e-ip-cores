// tb_int_swb_feb_steering_sweep_test.sv
// Trial the SWB FEB RX demux/OPQ lane-selection rules across logical links.

package tb_int_swb_feb_steering_sweep_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_swb_feb_steering_sweep_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_swb_feb_steering_sweep_test)

        localparam bit [7:0] K285 = 8'hbc;
        localparam bit [5:0] SCIFI_HEADER_ID = 6'b111000;
        localparam bit [5:0] MUPIX_HEADER_ID = 6'b111010;
        localparam bit [5:0] FEB_V3_HEADER_ID = 6'b101001;
        localparam logic [31:0] FEB_V3_SOP_WORD = 32'hA50000BC;
        localparam int unsigned FEB_V3_REPLAY_FRAMES = 64;
        localparam int unsigned FEB_V3_FRAME_PERIOD_CYCLES = 2048;

        function new(string name = "tb_int_swb_feb_steering_sweep_test",
                     uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function automatic int unsigned physical_lane_for_logical(int unsigned logical_lane);
            case (logical_lane)
                0: return 0;
                1: return 4;
                2: return 8;
                3: return 12;
                4: return 1;
                5: return 5;
                6: return 9;
                7: return 13;
                default: return 32'hffff_ffff;
            endcase
        endfunction

        function automatic bit swb_data_demerger_accepts_dt(logic [31:0] sop_word,
                                                            logic [3:0] datak);
            return (datak == 4'b0001) &&
                   (sop_word[7:0] == K285) &&
                   ((sop_word[31:29] == 3'b111) ||
                    (sop_word[31:29] == 3'b110) ||
                    (sop_word[31:26] == FEB_V3_HEADER_ID));
        endfunction

        function virtual opq_lane_if opq_lane_for_logical(int unsigned logical_lane);
            case (logical_lane)
                0: return opq_lane0_vif;
                1: return opq_lane1_vif;
                2: return opq_lane2_vif;
                3: return opq_lane3_vif;
                default: return opq_lane0_vif;
            endcase
        endfunction

        function automatic bit is_opq_eligible(int unsigned logical_lane,
                                               bit [3:0] link_mask);
            return (logical_lane < 4) && link_mask[logical_lane];
        endfunction

        task automatic route_frame_trial(int unsigned logical_lane,
                                         bit [3:0] link_mask,
                                         logic [31:0] sop_word,
                                         int unsigned trial_idx,
                                         output bit expected_route,
                                         output bit observed_route);
            virtual opq_lane_if vif;
            int unsigned before_hits;
            int unsigned after_hits;
            bit demux_accepts_dt;

            demux_accepts_dt = swb_data_demerger_accepts_dt(sop_word, 4'b0001);
            expected_route = demux_accepts_dt && is_opq_eligible(logical_lane, link_mask);

            before_hits = env.scoreboard.opq_frame_ingress_hits;
            if (expected_route) begin
                vif = opq_lane_for_logical(logical_lane);
                vif.drive_mu3e_frame_with_sop(sop_word,
                                              {logical_lane[7:0], link_mask, trial_idx[19:0]},
                                              1'b1,
                                              1'b0,
                                              1);
                repeat (3) @(posedge vif.clk);
            end else begin
                repeat (2) @(posedge opq_lane0_vif.clk);
            end
            after_hits = env.scoreboard.opq_frame_ingress_hits;
            observed_route = (after_hits > before_hits);

            $display("[SWB_STEER] logical=%0d physical=%0d role=%s mask=0x%0h header=0x%0h demux_dt=%0b expected_opq=%0b observed_opq=%0b hits_before=%0d hits_after=%0d",
                     logical_lane,
                     physical_lane_for_logical(logical_lane),
                     (logical_lane < 4) ? "primary-opq" : "secondary-no-opq",
                     link_mask,
                     sop_word,
                     demux_accepts_dt,
                     expected_route,
                     observed_route,
                     before_hits,
                     after_hits);
        endtask

        function automatic int unsigned mu3e_frame_drive_cycles(int unsigned hits_this_frame);
            return (5 + 128 + hits_this_frame + 1) * 2;
        endfunction

        task automatic wait_frame_period(virtual opq_lane_if vif,
                                         int unsigned hits_this_frame,
                                         int unsigned frame_idx,
                                         int unsigned frames);
            int unsigned drive_cycles;
            if (frame_idx + 1 >= frames)
                return;
            drive_cycles = mu3e_frame_drive_cycles(hits_this_frame);
            if (FEB_V3_FRAME_PERIOD_CYCLES > drive_cycles)
                repeat (FEB_V3_FRAME_PERIOD_CYCLES - drive_cycles) @(posedge vif.clk);
        endtask

        task automatic route_exact_feb_v3_replay(ref bit pass);
            virtual opq_lane_if vif;
            int unsigned before_hits;
            int unsigned after_hits;
            int unsigned observed_hits;
            int unsigned frame_idx;
            bit expected_route;
            bit demux_accepts_dt;

            vif = opq_lane_for_logical(2);
            demux_accepts_dt = swb_data_demerger_accepts_dt(FEB_V3_SOP_WORD, 4'b0001);
            expected_route = demux_accepts_dt && is_opq_eligible(2, 4'h4);
            before_hits = env.scoreboard.opq_frame_ingress_hits;

            if (expected_route) begin
                for (frame_idx = 0; frame_idx < FEB_V3_REPLAY_FRAMES; frame_idx++) begin
                    vif.drive_mu3e_frame_with_sop(FEB_V3_SOP_WORD,
                                                  {8'h02, 4'h4, frame_idx[19:0]},
                                                  1'b1,
                                                  1'b0,
                                                  1);
                    wait_frame_period(vif, 1, frame_idx, FEB_V3_REPLAY_FRAMES);
                end
                repeat (8) @(posedge vif.clk);
            end

            after_hits = env.scoreboard.opq_frame_ingress_hits;
            observed_hits = after_hits - before_hits;
            $display("[SWB_FEB_V3_REPLAY] logical=2 physical=%0d mask=0x4 sop=0x%08h frames=%0d frame_period_cycles=%0d demux_dt=%0b expected_route=%0b observed_hits=%0d",
                     physical_lane_for_logical(2),
                     FEB_V3_SOP_WORD,
                     FEB_V3_REPLAY_FRAMES,
                     FEB_V3_FRAME_PERIOD_CYCLES,
                     demux_accepts_dt,
                     expected_route,
                     observed_hits);

            if (!expected_route || observed_hits != FEB_V3_REPLAY_FRAMES) begin
                pass = 1'b0;
                `uvm_error("SWB_FEB_V3_REPLAY",
                           $sformatf("FEB v3 replay did not reach OPQ ingress: expected_route=%0b observed_hits=%0d expected_hits=%0d",
                                     expected_route,
                                     observed_hits,
                                     FEB_V3_REPLAY_FRAMES))
            end
        endtask

        virtual task run_phase(uvm_phase phase);
            bit pass;
            bit expected_route;
            bit observed_route;
            int unsigned logical_lane;
            int unsigned mask_i;
            int unsigned trial_idx;

            phase.raise_objection(this);
            wait (opq_lane0_vif.reset_n === 1'b1);
            repeat (4) @(posedge opq_lane0_vif.clk);

            env.scoreboard.start_case("SWB_FEB_STEERING_SWEEP");
            pass = 1'b1;
            trial_idx = 0;

            for (logical_lane = 0; logical_lane < 8; logical_lane++) begin
                for (mask_i = 0; mask_i < 16; mask_i++) begin
                    route_frame_trial(logical_lane,
                                      mask_i[3:0],
                                      {SCIFI_HEADER_ID, 2'b00, 16'h0001, K285},
                                      trial_idx,
                                      expected_route,
                                      observed_route);
                    if (expected_route != observed_route) begin
                        pass = 1'b0;
                        `uvm_error("SWB_STEER",
                                   $sformatf("logical=%0d physical=%0d mask=0x%0h expected_opq=%0b observed_opq=%0b",
                                             logical_lane,
                                             physical_lane_for_logical(logical_lane),
                                             mask_i[3:0],
                                             expected_route,
                                             observed_route))
                    end
                    trial_idx++;
                end
            end

            route_frame_trial(2, 4'h4, {SCIFI_HEADER_ID, 2'b00, 16'h0001, K285}, trial_idx,
                              expected_route, observed_route);
            if (!(expected_route && observed_route)) begin
                pass = 1'b0;
                `uvm_error("SWB_STEER",
                           "FEB link 2 check failed: logical lane 2 with SWB_LINK_MASK_SCIFI=0x4 did not reach OPQ")
            end
            trial_idx++;

            route_frame_trial(2, 4'h4, {MUPIX_HEADER_ID, 2'b00, 16'h0001, K285}, trial_idx,
                              expected_route, observed_route);
            if (!(expected_route && observed_route)) begin
                pass = 1'b0;
                `uvm_error("SWB_STEER",
                           "MUPIX-compatible data preamble should also route through logical lane 2 mask 0x4")
            end

            if (env.scoreboard.opq_frame_ts_invalid != 0) begin
                pass = 1'b0;
                `uvm_error("SWB_STEER",
                           $sformatf("steering sweep saw %0d OPQ hits without reconstructed timestamp",
                                     env.scoreboard.opq_frame_ts_invalid))
            end

            route_exact_feb_v3_replay(pass);

            if (pass)
                $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
