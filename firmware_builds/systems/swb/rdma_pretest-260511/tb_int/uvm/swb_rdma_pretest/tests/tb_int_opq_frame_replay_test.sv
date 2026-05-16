// tb_int_opq_frame_replay_test.sv
// Replay a SignalTap-decoded Mu3e frame memory into the OPQ frame monitors.

package tb_int_opq_frame_replay_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_opq_frame_replay_test extends tb_int_base_test;
        `uvm_component_utils(tb_int_opq_frame_replay_test)

        string replay_mem_path;
        int unsigned replay_lane;
        bit drive_ingress;
        bit drive_egress;
        bit expect_ingress_hits;
        bit expect_egress_hits;
        int unsigned min_ingress_hits;
        int unsigned min_egress_hits;

        function new(string name = "tb_int_opq_frame_replay_test",
                     uvm_component parent = null);
            super.new(name, parent);
            replay_mem_path = "";
            replay_lane = 0;
            drive_ingress = 1'b1;
            drive_egress = 1'b0;
            expect_ingress_hits = 1'b1;
            expect_egress_hits = 1'b0;
            min_ingress_hits = 1;
            min_egress_hits = 1;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            string side;

            super.build_phase(phase);
            if (!$value$plusargs("TB_INT_STP_REPLAY_MEM=%s", replay_mem_path))
                `uvm_fatal("OPQ_REPLAY", "TB_INT_STP_REPLAY_MEM=<path> is required")
            void'($value$plusargs("TB_INT_STP_REPLAY_LANE=%d", replay_lane));
            if ($value$plusargs("TB_INT_STP_REPLAY_SIDE=%s", side)) begin
                drive_ingress = (side == "ingress") || (side == "both");
                drive_egress = (side == "egress") || (side == "both");
            end
            expect_ingress_hits = $test$plusargs("TB_INT_REPLAY_EXPECT_INGRESS_HITS");
            expect_egress_hits = $test$plusargs("TB_INT_REPLAY_EXPECT_EGRESS_HITS");
            void'($value$plusargs("TB_INT_REPLAY_MIN_INGRESS_HITS=%d", min_ingress_hits));
            void'($value$plusargs("TB_INT_REPLAY_MIN_EGRESS_HITS=%d", min_egress_hits));
            replay_lane &= 32'h3;
        endfunction

        function virtual opq_lane_if selected_lane();
            case (replay_lane)
                0: return opq_lane0_vif;
                1: return opq_lane1_vif;
                2: return opq_lane2_vif;
                3: return opq_lane3_vif;
                default: return opq_lane0_vif;
            endcase
        endfunction

        task automatic drive_replay_mem(virtual opq_lane_if vif);
            int fd;
            int rc;
            int unsigned rows;
            int delta_cycles;
            logic [31:0] data;
            logic [3:0] datak;
            int sop_i;
            int eop_i;
            string junk;

            fd = $fopen(replay_mem_path, "r");
            if (fd == 0)
                `uvm_fatal("OPQ_REPLAY", $sformatf("failed to open %s", replay_mem_path))

            rows = 0;
            while (!$feof(fd)) begin
                rc = $fscanf(fd, "%d %h %h %d %d\n",
                             delta_cycles, data, datak, sop_i, eop_i);
                if (rc != 5) begin
                    void'($fgets(junk, fd));
                    continue;
                end
                if (delta_cycles < 1)
                    delta_cycles = 1;
                repeat (delta_cycles) @(posedge vif.clk);
                vif.drive_mu3e_beat(drive_ingress,
                                    drive_egress,
                                    data,
                                    datak,
                                    sop_i != 0,
                                    eop_i != 0);
                rows++;
            end
            $fclose(fd);
            `uvm_info("OPQ_REPLAY",
                      $sformatf("replayed %0d STP words from %s lane=%0d ingress=%0b egress=%0b",
                                rows,
                                replay_mem_path,
                                replay_lane,
                                drive_ingress,
                                drive_egress),
                      UVM_LOW)
        endtask

        virtual task run_phase(uvm_phase phase);
            virtual opq_lane_if vif;
            bit pass;

            phase.raise_objection(this);
            vif = selected_lane();
            wait (vif.reset_n === 1'b1);
            repeat (4) @(posedge vif.clk);

            env.scoreboard.start_case("OPQ_FRAME_STP_REPLAY");
            drive_replay_mem(vif);
            repeat (16) @(posedge vif.clk);

            pass = 1'b1;
            if (expect_ingress_hits && (env.scoreboard.opq_frame_ingress_hits < min_ingress_hits)) begin
                pass = 1'b0;
                `uvm_error("OPQ_REPLAY",
                           $sformatf("ingress replay hits=%0d expected at least %0d",
                                     env.scoreboard.opq_frame_ingress_hits,
                                     min_ingress_hits))
            end
            if (expect_egress_hits && (env.scoreboard.opq_frame_egress_hits < min_egress_hits)) begin
                pass = 1'b0;
                `uvm_error("OPQ_REPLAY",
                           $sformatf("egress replay hits=%0d expected at least %0d",
                                     env.scoreboard.opq_frame_egress_hits,
                                     min_egress_hits))
            end
            if (env.scoreboard.opq_frame_ts_invalid != 0) begin
                pass = 1'b0;
                `uvm_error("OPQ_REPLAY",
                           $sformatf("replay saw %0d hits without reconstructed packet timestamp",
                                     env.scoreboard.opq_frame_ts_invalid))
            end

            if (pass)
                $display("*** TEST PASSED ***");
            phase.drop_objection(this);
        endtask
    endclass

endpackage
