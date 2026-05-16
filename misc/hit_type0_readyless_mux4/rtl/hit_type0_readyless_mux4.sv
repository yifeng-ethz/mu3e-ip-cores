// hit_type0_readyless_mux4.sv
// Four-input readyless Avalon-ST hit_type0 mux for the FEB type0 bank path.
//
// The Intel Avalon-ST multiplexer exposes ready on its inputs and output. On
// the type0 path that forces Platform Designer timing adapters between
// readyless lane sources and the MTS preprocessor. This mux keeps the same
// channel tagging used by the Intel mux, but owns small per-input FIFOs and
// exposes no ready signal.

module hit_type0_readyless_mux4 #(
    parameter int FIFO_DEPTH = 16,
    parameter int DEBUG_LEVEL = 0
) (
    input  logic        clk,
    input  logic        rst,

    input  logic [44:0] asi_in0_data,
    input  logic        asi_in0_valid,
    input  logic [2:0]  asi_in0_error,
    input  logic [3:0]  asi_in0_channel,
    input  logic        asi_in0_startofpacket,
    input  logic        asi_in0_endofpacket,
    input  logic        asi_in0_endofrun,
    input  logic [63:0] asi_in0_metadata,
    input  logic        asi_in0_metadata_valid,

    input  logic [44:0] asi_in1_data,
    input  logic        asi_in1_valid,
    input  logic [2:0]  asi_in1_error,
    input  logic [3:0]  asi_in1_channel,
    input  logic        asi_in1_startofpacket,
    input  logic        asi_in1_endofpacket,
    input  logic        asi_in1_endofrun,
    input  logic [63:0] asi_in1_metadata,
    input  logic        asi_in1_metadata_valid,

    input  logic [44:0] asi_in2_data,
    input  logic        asi_in2_valid,
    input  logic [2:0]  asi_in2_error,
    input  logic [3:0]  asi_in2_channel,
    input  logic        asi_in2_startofpacket,
    input  logic        asi_in2_endofpacket,
    input  logic        asi_in2_endofrun,
    input  logic [63:0] asi_in2_metadata,
    input  logic        asi_in2_metadata_valid,

    input  logic [44:0] asi_in3_data,
    input  logic        asi_in3_valid,
    input  logic [2:0]  asi_in3_error,
    input  logic [3:0]  asi_in3_channel,
    input  logic        asi_in3_startofpacket,
    input  logic        asi_in3_endofpacket,
    input  logic        asi_in3_endofrun,
    input  logic [63:0] asi_in3_metadata,
    input  logic        asi_in3_metadata_valid,

    output logic [44:0] aso_out_data,
    output logic        aso_out_valid,
    output logic [2:0]  aso_out_error,
    output logic [5:0]  aso_out_channel,
    output logic        aso_out_startofpacket,
    output logic        aso_out_endofpacket,
    output logic        aso_out_endofrun,
    output logic [63:0] coe_selected_metadata,
    output logic        coe_selected_metadata_valid
);

    localparam int N_INPUTS = 4;
    localparam int PAYLOAD_WIDTH = 45 + 1 + 1 + 1 + 3 + 4 + 64 + 1;
    localparam int PTR_WIDTH = (FIFO_DEPTH <= 2) ? 1 : $clog2(FIFO_DEPTH);
    localparam int COUNT_WIDTH = $clog2(FIFO_DEPTH + 1);
    localparam logic [COUNT_WIDTH-1:0] FIFO_DEPTH_COUNT = FIFO_DEPTH;
    localparam bit DEBUG_METADATA_ENABLE = (DEBUG_LEVEL >= 2);

    logic [PAYLOAD_WIDTH-1:0] fifo_mem [N_INPUTS][FIFO_DEPTH];
    logic [PTR_WIDTH-1:0]     wr_ptr   [N_INPUTS];
    logic [PTR_WIDTH-1:0]     rd_ptr   [N_INPUTS];
    logic [COUNT_WIDTH-1:0]   count    [N_INPUTS];

    logic [44:0] in_data          [N_INPUTS];
    logic [2:0]  in_error         [N_INPUTS];
    logic [3:0]  in_channel       [N_INPUTS];
    logic        in_valid         [N_INPUTS];
    logic        in_startofpacket [N_INPUTS];
    logic        in_endofpacket   [N_INPUTS];
    logic        in_endofrun      [N_INPUTS];
    logic [63:0] in_metadata      [N_INPUTS];
    logic        in_metadata_valid [N_INPUTS];

    logic [N_INPUTS-1:0] push_accept;
    logic [N_INPUTS-1:0] pop_lane;
    logic [N_INPUTS-1:0] lane_empty;
    logic [1:0]          last_grant;
    logic [1:0]          grant_idx;
    logic                grant_valid;
    logic [PAYLOAD_WIDTH-1:0] grant_payload;

    assign in_data[0]          = asi_in0_data;
    assign in_error[0]         = asi_in0_error;
    assign in_channel[0]       = asi_in0_channel;
    assign in_valid[0]         = asi_in0_valid;
    assign in_startofpacket[0] = asi_in0_startofpacket;
    assign in_endofpacket[0]   = asi_in0_endofpacket;
    assign in_endofrun[0]      = asi_in0_endofrun;
    assign in_metadata[0]      = asi_in0_metadata;
    assign in_metadata_valid[0]= asi_in0_metadata_valid;

    assign in_data[1]          = asi_in1_data;
    assign in_error[1]         = asi_in1_error;
    assign in_channel[1]       = asi_in1_channel;
    assign in_valid[1]         = asi_in1_valid;
    assign in_startofpacket[1] = asi_in1_startofpacket;
    assign in_endofpacket[1]   = asi_in1_endofpacket;
    assign in_endofrun[1]      = asi_in1_endofrun;
    assign in_metadata[1]      = asi_in1_metadata;
    assign in_metadata_valid[1]= asi_in1_metadata_valid;

    assign in_data[2]          = asi_in2_data;
    assign in_error[2]         = asi_in2_error;
    assign in_channel[2]       = asi_in2_channel;
    assign in_valid[2]         = asi_in2_valid;
    assign in_startofpacket[2] = asi_in2_startofpacket;
    assign in_endofpacket[2]   = asi_in2_endofpacket;
    assign in_endofrun[2]      = asi_in2_endofrun;
    assign in_metadata[2]      = asi_in2_metadata;
    assign in_metadata_valid[2]= asi_in2_metadata_valid;

    assign in_data[3]          = asi_in3_data;
    assign in_error[3]         = asi_in3_error;
    assign in_channel[3]       = asi_in3_channel;
    assign in_valid[3]         = asi_in3_valid;
    assign in_startofpacket[3] = asi_in3_startofpacket;
    assign in_endofpacket[3]   = asi_in3_endofpacket;
    assign in_endofrun[3]      = asi_in3_endofrun;
    assign in_metadata[3]      = asi_in3_metadata;
    assign in_metadata_valid[3]= asi_in3_metadata_valid;

    function automatic logic [PTR_WIDTH-1:0] ptr_next(input logic [PTR_WIDTH-1:0] ptr);
        if (ptr == FIFO_DEPTH - 1) begin
            ptr_next = '0;
        end else begin
            ptr_next = ptr + {{(PTR_WIDTH-1){1'b0}}, 1'b1};
        end
    endfunction

    genvar gi;
    generate
        for (gi = 0; gi < N_INPUTS; gi = gi + 1) begin : fifo_status
            assign lane_empty[gi] = (count[gi] == '0);
        end
    endgenerate

    always_comb begin
        grant_valid = 1'b0;
        grant_idx = 2'd0;

        unique case (last_grant)
            2'd0: begin
                if (!lane_empty[0]) begin grant_valid = 1'b1; grant_idx = 2'd0; end
                if (!lane_empty[3]) begin grant_valid = 1'b1; grant_idx = 2'd3; end
                if (!lane_empty[2]) begin grant_valid = 1'b1; grant_idx = 2'd2; end
                if (!lane_empty[1]) begin grant_valid = 1'b1; grant_idx = 2'd1; end
            end
            2'd1: begin
                if (!lane_empty[1]) begin grant_valid = 1'b1; grant_idx = 2'd1; end
                if (!lane_empty[0]) begin grant_valid = 1'b1; grant_idx = 2'd0; end
                if (!lane_empty[3]) begin grant_valid = 1'b1; grant_idx = 2'd3; end
                if (!lane_empty[2]) begin grant_valid = 1'b1; grant_idx = 2'd2; end
            end
            2'd2: begin
                if (!lane_empty[2]) begin grant_valid = 1'b1; grant_idx = 2'd2; end
                if (!lane_empty[1]) begin grant_valid = 1'b1; grant_idx = 2'd1; end
                if (!lane_empty[0]) begin grant_valid = 1'b1; grant_idx = 2'd0; end
                if (!lane_empty[3]) begin grant_valid = 1'b1; grant_idx = 2'd3; end
            end
            default: begin
                if (!lane_empty[3]) begin grant_valid = 1'b1; grant_idx = 2'd3; end
                if (!lane_empty[2]) begin grant_valid = 1'b1; grant_idx = 2'd2; end
                if (!lane_empty[1]) begin grant_valid = 1'b1; grant_idx = 2'd1; end
                if (!lane_empty[0]) begin grant_valid = 1'b1; grant_idx = 2'd0; end
            end
        endcase
    end

    always_comb begin
        pop_lane = '0;
        if (grant_valid) begin
            pop_lane[grant_idx] = 1'b1;
        end

        for (int lane = 0; lane < N_INPUTS; lane = lane + 1) begin
            push_accept[lane] = in_valid[lane] &&
                ((count[lane] != FIFO_DEPTH_COUNT) || pop_lane[lane]);
        end
    end

    assign grant_payload = fifo_mem[grant_idx][rd_ptr[grant_idx]];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int lane = 0; lane < N_INPUTS; lane = lane + 1) begin
                wr_ptr[lane] <= '0;
                rd_ptr[lane] <= '0;
                count[lane]  <= '0;
            end

            last_grant             <= 2'd0;
            aso_out_data           <= 45'd0;
            aso_out_valid          <= 1'b0;
            aso_out_error          <= 3'd0;
            aso_out_channel        <= 6'd0;
            aso_out_startofpacket  <= 1'b0;
            aso_out_endofpacket    <= 1'b0;
            aso_out_endofrun       <= 1'b0;
            coe_selected_metadata  <= 64'd0;
            coe_selected_metadata_valid <= 1'b0;
        end else begin
            for (int lane = 0; lane < N_INPUTS; lane = lane + 1) begin
                if (push_accept[lane]) begin
                    fifo_mem[lane][wr_ptr[lane]] <= {
                        in_data[lane],
                        in_startofpacket[lane],
                        in_endofpacket[lane],
                        in_endofrun[lane],
                        in_error[lane],
                        in_channel[lane],
                        (DEBUG_METADATA_ENABLE ? in_metadata[lane] : 64'd0),
                        (DEBUG_METADATA_ENABLE ? in_metadata_valid[lane] : 1'b0)
                    };
                    wr_ptr[lane] <= ptr_next(wr_ptr[lane]);
                end

                if (pop_lane[lane]) begin
                    rd_ptr[lane] <= ptr_next(rd_ptr[lane]);
                end

                unique case ({push_accept[lane], pop_lane[lane]})
                    2'b10: count[lane] <= count[lane] + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
                    2'b01: count[lane] <= count[lane] - {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
                    default: count[lane] <= count[lane];
                endcase
            end

            aso_out_valid <= grant_valid;
            if (grant_valid) begin
                last_grant <= grant_idx;
                {
                    aso_out_data,
                    aso_out_startofpacket,
                    aso_out_endofpacket,
                    aso_out_endofrun,
                    aso_out_error,
                    aso_out_channel[3:0],
                    coe_selected_metadata,
                    coe_selected_metadata_valid
                } <= grant_payload;
                aso_out_channel[5:4] <= grant_idx;
            end else begin
                last_grant            <= 2'd0;
                aso_out_data          <= 45'd0;
                aso_out_error         <= 3'd0;
                aso_out_channel       <= 6'd0;
                aso_out_startofpacket <= 1'b0;
                aso_out_endofpacket   <= 1'b0;
                aso_out_endofrun      <= 1'b0;
                coe_selected_metadata <= 64'd0;
                coe_selected_metadata_valid <= 1'b0;
            end
        end
    end

endmodule
