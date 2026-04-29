// hit_type3_stream_merge.sv
// Packet-atomic two-input Avalon-ST merger for 36-bit hit_type3 packets.
//
// Version : 26.0.0
// Date    : 20260429
// Change  : Initial Phase-5 histogram tap merger.

module hit_type3_stream_merge (
    input  logic        clk,
    input  logic        reset,

    input  logic [35:0] asi_in0_data,
    input  logic        asi_in0_valid,
    output logic        asi_in0_ready,
    input  logic        asi_in0_startofpacket,
    input  logic        asi_in0_endofpacket,

    input  logic [35:0] asi_in1_data,
    input  logic        asi_in1_valid,
    output logic        asi_in1_ready,
    input  logic        asi_in1_startofpacket,
    input  logic        asi_in1_endofpacket,

    output logic [35:0] aso_out_data,
    output logic        aso_out_valid,
    input  logic        aso_out_ready,
    output logic        aso_out_startofpacket,
    output logic        aso_out_endofpacket
);

    typedef enum logic [1:0] {
        IDLING = 2'd0,
        DRAINING_IN0 = 2'd1,
        DRAINING_IN1 = 2'd2
    } merge_state_t;

    merge_state_t state;
    logic         last_grant;
    logic         grant_in1;
    logic         accepted;
    logic         accepted_eop;

    always_comb begin : grant_select
        grant_in1 = 1'b0;

        unique case (state)
            DRAINING_IN0: begin
                grant_in1 = 1'b0;
            end
            DRAINING_IN1: begin
                grant_in1 = 1'b1;
            end
            default: begin
                unique case ({asi_in1_valid, asi_in0_valid})
                    2'b10:   grant_in1 = 1'b1;
                    2'b11:   grant_in1 = ~last_grant;
                    default: grant_in1 = 1'b0;
                endcase
            end
        endcase
    end

    always_comb begin : stream_mux
        asi_in0_ready           = 1'b0;
        asi_in1_ready           = 1'b0;
        aso_out_data            = 36'd0;
        aso_out_valid           = 1'b0;
        aso_out_startofpacket   = 1'b0;
        aso_out_endofpacket     = 1'b0;

        if (grant_in1) begin
            aso_out_data          = asi_in1_data;
            aso_out_valid         = asi_in1_valid;
            aso_out_startofpacket = asi_in1_startofpacket;
            aso_out_endofpacket   = asi_in1_endofpacket;
            asi_in1_ready         = aso_out_ready;
        end else begin
            aso_out_data          = asi_in0_data;
            aso_out_valid         = asi_in0_valid;
            aso_out_startofpacket = asi_in0_startofpacket;
            aso_out_endofpacket   = asi_in0_endofpacket;
            asi_in0_ready         = aso_out_ready;
        end
    end

    assign accepted     = aso_out_valid & aso_out_ready;
    assign accepted_eop = accepted & aso_out_endofpacket;

    always_ff @(posedge clk or posedge reset) begin : packet_owner
        if (reset) begin
            state         <= IDLING;
            last_grant    <= 1'b1;
        end else if (accepted) begin
            last_grant <= grant_in1;

            unique case (state)
                IDLING: begin
                    if (!accepted_eop) begin
                        state <= grant_in1 ? DRAINING_IN1 : DRAINING_IN0;
                    end
                end
                DRAINING_IN0,
                DRAINING_IN1: begin
                    if (accepted_eop) begin
                        state <= IDLING;
                    end
                end
                default: begin
                    state <= IDLING;
                end
            endcase
        end
    end

endmodule
