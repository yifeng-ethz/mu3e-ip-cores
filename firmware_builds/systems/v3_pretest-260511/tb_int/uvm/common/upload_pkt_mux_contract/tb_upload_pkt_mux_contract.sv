// tb_upload_pkt_mux_contract.sv
// Focused generated-upload mux contract check.

`timescale 1ns/1ps

module tb_upload_pkt_mux_contract;
    localparam int unsigned DataWidth = 36;

    logic                 clk = 1'b0;
    logic                 reset_n = 1'b0;
    logic [DataWidth-1:0] out_data;
    logic                 out_valid;
    logic                 out_ready;
    logic                 out_sop;
    logic                 out_eop;
    logic [1:0]           out_channel;
    logic [DataWidth-1:0] in0_data;
    logic                 in0_valid;
    logic                 in0_ready;
    logic                 in0_sop;
    logic                 in0_eop;
    logic [DataWidth-1:0] in1_data;
    logic                 in1_valid;
    logic                 in1_ready;
    logic                 in1_sop;
    logic                 in1_eop;
    logic [DataWidth-1:0] in2_data;
    logic                 in2_valid;
    logic                 in2_ready;
    logic                 in2_sop;
    logic                 in2_eop;

    int unsigned          accepted_in0;
    int unsigned          checked_out;
    int unsigned          errors;
    int unsigned          cycle_count;
    logic [DataWidth-1:0] expect_data_q[$];
    logic                 expect_sop_q[$];
    logic                 expect_eop_q[$];
    int unsigned          expect_cycle_q[$];

    feb_system_v3_upload_subsystem_upload_pkt_mux dut (
        .clk(clk),
        .reset_n(reset_n),
        .out_channel(out_channel),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_data(out_data),
        .out_startofpacket(out_sop),
        .out_endofpacket(out_eop),
        .in0_valid(in0_valid),
        .in0_ready(in0_ready),
        .in0_data(in0_data),
        .in0_startofpacket(in0_sop),
        .in0_endofpacket(in0_eop),
        .in1_valid(in1_valid),
        .in1_ready(in1_ready),
        .in1_data(in1_data),
        .in1_startofpacket(in1_sop),
        .in1_endofpacket(in1_eop),
        .in2_valid(in2_valid),
        .in2_ready(in2_ready),
        .in2_data(in2_data),
        .in2_startofpacket(in2_sop),
        .in2_endofpacket(in2_eop)
    );

    always #4 clk = ~clk;

    task automatic drive_in0_frame(input int unsigned subheaders,
                                   input int unsigned hits_per_frame);
        int unsigned beat;

        in0_valid = 1'b1;
        in0_sop = 1'b1;
        in0_eop = 1'b0;
        in0_data = 36'h1_a500_00bc;
        @(posedge clk);
        in0_sop = 1'b0;

        in0_data = 36'h0_2026_0000;
        @(posedge clk);
        in0_data = 36'h0_0000_0000;
        @(posedge clk);
        in0_data = {4'h0, 8'h00, 16'(subheaders[15:0]), 8'h08};
        @(posedge clk);
        in0_data = {4'h0, 8'h00, 8'(hits_per_frame[7:0]), 8'h00, 8'h00};
        @(posedge clk);

        for (beat = 0; beat < subheaders; beat++) begin
            in0_data = {4'h1, beat[7:0], 16'h0000, 8'hf7};
            @(posedge clk);
        end

        for (beat = 0; beat < hits_per_frame; beat++) begin
            in0_data = {4'h0, 8'hc8, 8'h00, beat[7:0], 8'h91};
            @(posedge clk);
        end

        in0_data = {4'h1, 24'h0, 8'h9c};
        in0_eop = 1'b1;
        @(posedge clk);
        in0_valid = 1'b0;
        in0_eop = 1'b0;
        in0_data = '0;
    endtask

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            accepted_in0 <= 0;
            checked_out <= 0;
            errors <= 0;
            cycle_count <= 0;
            expect_data_q.delete();
            expect_sop_q.delete();
            expect_eop_q.delete();
            expect_cycle_q.delete();
        end else begin
            cycle_count <= cycle_count + 1'b1;
            if (in0_valid && in0_ready) begin
                accepted_in0 <= accepted_in0 + 1'b1;
                expect_data_q.push_back(in0_data);
                expect_sop_q.push_back(in0_sop);
                expect_eop_q.push_back(in0_eop);
                expect_cycle_q.push_back(cycle_count);
            end

            if (out_valid && out_ready) begin
                checked_out <= checked_out + 1'b1;
                if (expect_data_q.size() == 0) begin
                    $error("upload mux produced output without an accepted input");
                    errors <= errors + 1'b1;
                end else begin
                    logic [DataWidth-1:0] exp_data;
                    logic exp_sop;
                    logic exp_eop;
                    int unsigned exp_cycle;

                    exp_data = expect_data_q.pop_front();
                    exp_sop = expect_sop_q.pop_front();
                    exp_eop = expect_eop_q.pop_front();
                    exp_cycle = expect_cycle_q.pop_front();
                    if (out_data !== exp_data || out_sop !== exp_sop || out_eop !== exp_eop || out_channel !== 2'd0) begin
                        $error("upload mux contract mismatch out_data=0x%09h exp=0x%09h out_sop=%0b exp_sop=%0b out_eop=%0b exp_eop=%0b channel=%0d",
                               out_data, exp_data, out_sop, exp_sop, out_eop, exp_eop, out_channel);
                        errors <= errors + 1'b1;
                    end
                    if (cycle_count != exp_cycle + 1) begin
                        $error("upload mux latency mismatch out_cycle=%0d exp_cycle=%0d",
                               cycle_count, exp_cycle + 1);
                        errors <= errors + 1'b1;
                    end
                end
            end
        end
    end

    initial begin
        out_ready = 1'b1;
        in0_valid = 1'b0;
        in0_sop = 1'b0;
        in0_eop = 1'b0;
        in0_data = '0;
        in1_valid = 1'b0;
        in1_sop = 1'b0;
        in1_eop = 1'b0;
        in1_data = '0;
        in2_valid = 1'b0;
        in2_sop = 1'b0;
        in2_eop = 1'b0;
        in2_data = '0;

        repeat (4) @(posedge clk);
        reset_n = 1'b1;
        repeat (4) @(posedge clk);

        drive_in0_frame(128, 8);
        repeat (8) @(posedge clk);

        if (accepted_in0 != checked_out) begin
            $error("upload mux lost beats accepted_in0=%0d checked_out=%0d", accepted_in0, checked_out);
        end
        if (errors != 0 || accepted_in0 != checked_out) begin
            $fatal(1, "UPLOAD_MUX_CONTRACT_FAIL errors=%0d accepted=%0d checked=%0d",
                   errors, accepted_in0, checked_out);
        end
        $display("UPLOAD_MUX_CONTRACT_PASS accepted=%0d checked=%0d", accepted_in0, checked_out);
        $finish;
    end
endmodule
