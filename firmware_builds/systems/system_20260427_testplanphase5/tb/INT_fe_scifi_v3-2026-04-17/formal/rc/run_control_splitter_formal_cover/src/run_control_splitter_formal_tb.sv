`include "formal_defs.svh"

module run_control_splitter_formal_tb;
    (* gclk *) reg gclk;

    reg       f_past_valid = 1'b0;
    reg [1:0] f_reset_sr   = 2'b11;
    wire      rst          = f_reset_sr[1];

    (* anyseq *) reg        in0_valid;
    (* anyseq *) reg [8:0]  in0_data;
    (* anyseq *) reg [15:0] out_ready;

    wire       in0_ready;
    wire [15:0] out_valid;
    wire [8:0]  out_data [0:15];
    wire        out_channel [0:15];
    wire        out_error [0:15];
    wire        out_sop [0:15];
    wire        out_eop [0:15];
    wire        out_empty [0:15];

    reg        prev_accept = 1'b0;
    reg [8:0]  prev_accept_data = 9'd0;

    integer i;

    altera_avalon_st_splitter #(
        .NUMBER_OF_OUTPUTS (16),
        .QUALIFY_VALID_OUT (0),
        .DATA_WIDTH        (9),
        .BITS_PER_SYMBOL   (9),
        .USE_PACKETS       (0),
        .CHANNEL_WIDTH     (1),
        .ERROR_WIDTH       (1),
        .EMPTY_WIDTH       (1)
    ) dut (
        .in0_ready         (in0_ready),
        .in0_valid         (in0_valid),
        .in0_data          (in0_data),
        .in0_channel       (1'b0),
        .in0_error         (1'b0),
        .in0_startofpacket (1'b0),
        .in0_endofpacket   (1'b0),
        .in0_empty         (1'b0),
        .out0_ready        (out_ready[0]),
        .out0_valid        (out_valid[0]),
        .out0_data         (out_data[0]),
        .out0_channel      (out_channel[0]),
        .out0_error        (out_error[0]),
        .out0_startofpacket(out_sop[0]),
        .out0_endofpacket  (out_eop[0]),
        .out0_empty        (out_empty[0]),
        .out1_ready        (out_ready[1]),
        .out1_valid        (out_valid[1]),
        .out1_data         (out_data[1]),
        .out1_channel      (out_channel[1]),
        .out1_error        (out_error[1]),
        .out1_startofpacket(out_sop[1]),
        .out1_endofpacket  (out_eop[1]),
        .out1_empty        (out_empty[1]),
        .out2_ready        (out_ready[2]),
        .out2_valid        (out_valid[2]),
        .out2_data         (out_data[2]),
        .out2_channel      (out_channel[2]),
        .out2_error        (out_error[2]),
        .out2_startofpacket(out_sop[2]),
        .out2_endofpacket  (out_eop[2]),
        .out2_empty        (out_empty[2]),
        .out3_ready        (out_ready[3]),
        .out3_valid        (out_valid[3]),
        .out3_data         (out_data[3]),
        .out3_channel      (out_channel[3]),
        .out3_error        (out_error[3]),
        .out3_startofpacket(out_sop[3]),
        .out3_endofpacket  (out_eop[3]),
        .out3_empty        (out_empty[3]),
        .out4_ready        (out_ready[4]),
        .out4_valid        (out_valid[4]),
        .out4_data         (out_data[4]),
        .out4_channel      (out_channel[4]),
        .out4_error        (out_error[4]),
        .out4_startofpacket(out_sop[4]),
        .out4_endofpacket  (out_eop[4]),
        .out4_empty        (out_empty[4]),
        .out5_ready        (out_ready[5]),
        .out5_valid        (out_valid[5]),
        .out5_data         (out_data[5]),
        .out5_channel      (out_channel[5]),
        .out5_error        (out_error[5]),
        .out5_startofpacket(out_sop[5]),
        .out5_endofpacket  (out_eop[5]),
        .out5_empty        (out_empty[5]),
        .out6_ready        (out_ready[6]),
        .out6_valid        (out_valid[6]),
        .out6_data         (out_data[6]),
        .out6_channel      (out_channel[6]),
        .out6_error        (out_error[6]),
        .out6_startofpacket(out_sop[6]),
        .out6_endofpacket  (out_eop[6]),
        .out6_empty        (out_empty[6]),
        .out7_ready        (out_ready[7]),
        .out7_valid        (out_valid[7]),
        .out7_data         (out_data[7]),
        .out7_channel      (out_channel[7]),
        .out7_error        (out_error[7]),
        .out7_startofpacket(out_sop[7]),
        .out7_endofpacket  (out_eop[7]),
        .out7_empty        (out_empty[7]),
        .out8_ready        (out_ready[8]),
        .out8_valid        (out_valid[8]),
        .out8_data         (out_data[8]),
        .out8_channel      (out_channel[8]),
        .out8_error        (out_error[8]),
        .out8_startofpacket(out_sop[8]),
        .out8_endofpacket  (out_eop[8]),
        .out8_empty        (out_empty[8]),
        .out9_ready        (out_ready[9]),
        .out9_valid        (out_valid[9]),
        .out9_data         (out_data[9]),
        .out9_channel      (out_channel[9]),
        .out9_error        (out_error[9]),
        .out9_startofpacket(out_sop[9]),
        .out9_endofpacket  (out_eop[9]),
        .out9_empty        (out_empty[9]),
        .out10_ready       (out_ready[10]),
        .out10_valid       (out_valid[10]),
        .out10_data        (out_data[10]),
        .out10_channel     (out_channel[10]),
        .out10_error       (out_error[10]),
        .out10_startofpacket(out_sop[10]),
        .out10_endofpacket (out_eop[10]),
        .out10_empty       (out_empty[10]),
        .out11_ready       (out_ready[11]),
        .out11_valid       (out_valid[11]),
        .out11_data        (out_data[11]),
        .out11_channel     (out_channel[11]),
        .out11_error       (out_error[11]),
        .out11_startofpacket(out_sop[11]),
        .out11_endofpacket (out_eop[11]),
        .out11_empty       (out_empty[11]),
        .out12_ready       (out_ready[12]),
        .out12_valid       (out_valid[12]),
        .out12_data        (out_data[12]),
        .out12_channel     (out_channel[12]),
        .out12_error       (out_error[12]),
        .out12_startofpacket(out_sop[12]),
        .out12_endofpacket (out_eop[12]),
        .out12_empty       (out_empty[12]),
        .out13_ready       (out_ready[13]),
        .out13_valid       (out_valid[13]),
        .out13_data        (out_data[13]),
        .out13_channel     (out_channel[13]),
        .out13_error       (out_error[13]),
        .out13_startofpacket(out_sop[13]),
        .out13_endofpacket (out_eop[13]),
        .out13_empty       (out_empty[13]),
        .out14_ready       (out_ready[14]),
        .out14_valid       (out_valid[14]),
        .out14_data        (out_data[14]),
        .out14_channel     (out_channel[14]),
        .out14_error       (out_error[14]),
        .out14_startofpacket(out_sop[14]),
        .out14_endofpacket (out_eop[14]),
        .out14_empty       (out_empty[14]),
        .out15_ready       (out_ready[15]),
        .out15_valid       (out_valid[15]),
        .out15_data        (out_data[15]),
        .out15_channel     (out_channel[15]),
        .out15_error       (out_error[15]),
        .out15_startofpacket(out_sop[15]),
        .out15_endofpacket (out_eop[15]),
        .out15_empty       (out_empty[15]),
        .clk               (gclk),
        .reset             (rst)
    );

    always @(posedge gclk) begin
        f_past_valid <= 1'b1;

        if (!f_past_valid) begin
            assume(rst);
        end

        if (f_reset_sr != 2'b00) begin
            f_reset_sr <= {f_reset_sr[0], 1'b0};
        end

        if (!rst) begin
            assume(!in0_valid || $onehot(in0_data));

            assert(in0_ready == &out_ready);

            for (i = 0; i < 16; i = i + 1) begin
                assert(out_valid[i] == in0_valid);
                assert(out_data[i] == in0_data);
                assert(out_channel[i] == 1'b0);
                assert(out_error[i] == 1'b0);
                assert(out_sop[i] == 1'b0);
                assert(out_eop[i] == 1'b0);
                assert(out_empty[i] == 1'b0);
            end

            if (in0_valid && !(&out_ready)) begin
                assert(!in0_ready);
            end

            if (in0_valid && in0_ready) begin
                for (i = 0; i < 16; i = i + 1) begin
                    assert(out_valid[i] && out_ready[i]);
                    assert(out_data[i] == in0_data);
                end
            end

            cover(in0_valid && in0_ready);
            cover(in0_valid && !in0_ready && out_ready == 16'hFFFE);
            cover(in0_valid && !in0_ready && out_ready == 16'h7FFF);
            cover(prev_accept && in0_valid && in0_ready && in0_data != prev_accept_data);
        end

        prev_accept <= !rst && in0_valid && in0_ready;
        if (!rst && in0_valid && in0_ready) begin
            prev_accept_data <= in0_data;
        end
    end

endmodule
