// debug_hit_sidecar_bank_bridge.sv
// Aligns four lane-local DEBUG metadata conduits with a 4-input hit_type0 mux.
//
// Version : 26.0.1
// Date    : 20260506
// Change  : Export per-lane sidecar FIFO fill levels and sticky overflow flags.

module debug_hit_sidecar_bank_bridge #(
    parameter int DATA_WIDTH = 45,
    parameter int CHANNEL_WIDTH = 6,
    parameter int ERROR_WIDTH = 3,
    parameter int METADATA_WIDTH = 64,
    parameter int FIFO_DEPTH = 256
) (
    input  logic                      i_clk,
    input  logic                      i_rst,

    input  logic [DATA_WIDTH-1:0]     asi_hit_type0_data,
    input  logic                      asi_hit_type0_valid,
    output logic                      asi_hit_type0_ready,
    input  logic [ERROR_WIDTH-1:0]    asi_hit_type0_error,
    input  logic [CHANNEL_WIDTH-1:0]  asi_hit_type0_channel,
    input  logic                      asi_hit_type0_startofpacket,
    input  logic                      asi_hit_type0_endofpacket,
    input  logic                      asi_hit_type0_endofrun,

    output logic [DATA_WIDTH-1:0]     aso_hit_type0_data,
    output logic                      aso_hit_type0_valid,
    input  logic                      aso_hit_type0_ready,
    output logic [ERROR_WIDTH-1:0]    aso_hit_type0_error,
    output logic [CHANNEL_WIDTH-1:0]  aso_hit_type0_channel,
    output logic                      aso_hit_type0_startofpacket,
    output logic                      aso_hit_type0_endofpacket,
    output logic                      aso_hit_type0_endofrun,

    input  logic [METADATA_WIDTH-1:0] coe_lane0_metadata,
    input  logic                      coe_lane0_valid,
    input  logic [METADATA_WIDTH-1:0] coe_lane1_metadata,
    input  logic                      coe_lane1_valid,
    input  logic [METADATA_WIDTH-1:0] coe_lane2_metadata,
    input  logic                      coe_lane2_valid,
    input  logic [METADATA_WIDTH-1:0] coe_lane3_metadata,
    input  logic                      coe_lane3_valid,

    output logic [METADATA_WIDTH-1:0] coe_hit_type0_sidecar_metadata,
    output logic                      coe_hit_type0_sidecar_valid,

    output logic [39:0]               coe_debug_fifo_levels,
    output logic [3:0]                coe_debug_fifo_empty,
    output logic [3:0]                coe_debug_fifo_full,
    output logic [3:0]                coe_debug_fifo_overflow
);

    localparam int LANE_COUNT_CONST = 4;
    localparam int FIFO_ADDR_WIDTH_CONST = $clog2(FIFO_DEPTH);
    localparam logic [FIFO_ADDR_WIDTH_CONST:0] FIFO_DEPTH_COUNT_CONST = FIFO_DEPTH;

    logic [LANE_COUNT_CONST-1:0][METADATA_WIDTH-1:0] lane_metadata;
    logic [LANE_COUNT_CONST-1:0] lane_valid;
    logic [METADATA_WIDTH-1:0] fifo_mem [LANE_COUNT_CONST][FIFO_DEPTH];
    logic [LANE_COUNT_CONST-1:0][FIFO_ADDR_WIDTH_CONST-1:0] fifo_wr_ptr;
    logic [LANE_COUNT_CONST-1:0][FIFO_ADDR_WIDTH_CONST-1:0] fifo_rd_ptr;
    logic [LANE_COUNT_CONST-1:0][FIFO_ADDR_WIDTH_CONST:0] fifo_count;
    logic [1:0] selected_lane;
    logic transfer;
    logic selected_metadata_present;
    logic [LANE_COUNT_CONST-1:0] sidecar_read_accept;
    logic [LANE_COUNT_CONST-1:0] sidecar_write_accept;
    logic [LANE_COUNT_CONST-1:0] sidecar_overflow_pulse;
    logic [LANE_COUNT_CONST-1:0][9:0] debug_fifo_level;

    assign lane_metadata[0] = coe_lane0_metadata;
    assign lane_metadata[1] = coe_lane1_metadata;
    assign lane_metadata[2] = coe_lane2_metadata;
    assign lane_metadata[3] = coe_lane3_metadata;
    assign lane_valid = {
        coe_lane3_valid,
        coe_lane2_valid,
        coe_lane1_valid,
        coe_lane0_valid
    };

    assign asi_hit_type0_ready = aso_hit_type0_ready;
    assign aso_hit_type0_data = asi_hit_type0_data;
    assign aso_hit_type0_valid = asi_hit_type0_valid;
    assign aso_hit_type0_error = asi_hit_type0_error;
    assign aso_hit_type0_channel = asi_hit_type0_channel;
    assign aso_hit_type0_startofpacket = asi_hit_type0_startofpacket;
    assign aso_hit_type0_endofpacket = asi_hit_type0_endofpacket;
    assign aso_hit_type0_endofrun = asi_hit_type0_endofrun;

    assign transfer = asi_hit_type0_valid && aso_hit_type0_ready;
    assign selected_lane = asi_hit_type0_channel[CHANNEL_WIDTH-1 -: 2];

    always_comb begin : select_sidecar
        coe_hit_type0_sidecar_metadata = '0;
        selected_metadata_present = 1'b0;
        unique case (selected_lane)
            2'd0: begin
                coe_hit_type0_sidecar_metadata = fifo_mem[0][fifo_rd_ptr[0]];
                selected_metadata_present = (fifo_count[0] != '0);
            end
            2'd1: begin
                coe_hit_type0_sidecar_metadata = fifo_mem[1][fifo_rd_ptr[1]];
                selected_metadata_present = (fifo_count[1] != '0);
            end
            2'd2: begin
                coe_hit_type0_sidecar_metadata = fifo_mem[2][fifo_rd_ptr[2]];
                selected_metadata_present = (fifo_count[2] != '0);
            end
            default: begin
                coe_hit_type0_sidecar_metadata = fifo_mem[3][fifo_rd_ptr[3]];
                selected_metadata_present = (fifo_count[3] != '0);
            end
        endcase
    end

    assign coe_hit_type0_sidecar_valid =
        transfer && !asi_hit_type0_endofrun && selected_metadata_present;
    assign coe_debug_fifo_levels = {
        debug_fifo_level[3],
        debug_fifo_level[2],
        debug_fifo_level[1],
        debug_fifo_level[0]
    };
    assign coe_debug_fifo_empty = {
        fifo_count[3] == '0,
        fifo_count[2] == '0,
        fifo_count[1] == '0,
        fifo_count[0] == '0
    };
    assign coe_debug_fifo_full = {
        fifo_count[3] == FIFO_DEPTH_COUNT_CONST,
        fifo_count[2] == FIFO_DEPTH_COUNT_CONST,
        fifo_count[1] == FIFO_DEPTH_COUNT_CONST,
        fifo_count[0] == FIFO_DEPTH_COUNT_CONST
    };

    always_comb begin : select_queue_ops
        sidecar_read_accept = '0;
        sidecar_write_accept = '0;
        sidecar_overflow_pulse = '0;
        debug_fifo_level = '0;
        for (int lane_idx = 0; lane_idx < LANE_COUNT_CONST; lane_idx++) begin
            debug_fifo_level[lane_idx][FIFO_ADDR_WIDTH_CONST:0] = fifo_count[lane_idx];
            sidecar_read_accept[lane_idx] =
                transfer
                && !asi_hit_type0_endofrun
                && (selected_lane == lane_idx[1:0])
                && (fifo_count[lane_idx] != '0);
            sidecar_write_accept[lane_idx] =
                lane_valid[lane_idx]
                && ((fifo_count[lane_idx] != FIFO_DEPTH_COUNT_CONST)
                    || sidecar_read_accept[lane_idx]);
            sidecar_overflow_pulse[lane_idx] =
                lane_valid[lane_idx] && !sidecar_write_accept[lane_idx];
        end
    end

    always_ff @(posedge i_clk or posedge i_rst) begin : metadata_queues
        if (i_rst) begin
            fifo_wr_ptr                <= '0;
            fifo_rd_ptr                <= '0;
            fifo_count                 <= '0;
            coe_debug_fifo_overflow    <= '0;
        end else begin
            for (int lane_idx = 0; lane_idx < LANE_COUNT_CONST; lane_idx++) begin
                if (sidecar_write_accept[lane_idx]) begin
                    fifo_mem[lane_idx][fifo_wr_ptr[lane_idx]]    <= lane_metadata[lane_idx];
                    fifo_wr_ptr[lane_idx]                        <= fifo_wr_ptr[lane_idx] + 1'b1;
                end

                if (sidecar_read_accept[lane_idx]) begin
                    fifo_rd_ptr[lane_idx] <= fifo_rd_ptr[lane_idx] + 1'b1;
                end

                unique case ({sidecar_write_accept[lane_idx], sidecar_read_accept[lane_idx]})
                    2'b10:   fifo_count[lane_idx]    <= fifo_count[lane_idx] + 1'b1;
                    2'b01:   fifo_count[lane_idx]    <= fifo_count[lane_idx] - 1'b1;
                    default: fifo_count[lane_idx]    <= fifo_count[lane_idx];
                endcase

                if (sidecar_overflow_pulse[lane_idx]) begin
                    coe_debug_fifo_overflow[lane_idx] <= 1'b1;
                end
            end
        end
    end

    // synthesis translate_off
    initial begin : parameter_guard
        if (DATA_WIDTH != 45) begin
            $error("debug_hit_sidecar_bank_bridge requires DATA_WIDTH=45");
        end
        if (CHANNEL_WIDTH != 6) begin
            $error("debug_hit_sidecar_bank_bridge requires CHANNEL_WIDTH=6");
        end
        if (ERROR_WIDTH != 3) begin
            $error("debug_hit_sidecar_bank_bridge requires ERROR_WIDTH=3");
        end
        if (METADATA_WIDTH != 64) begin
            $error("debug_hit_sidecar_bank_bridge requires METADATA_WIDTH=64");
        end
        if (FIFO_DEPTH <= 1 || (FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0) begin
            $error("debug_hit_sidecar_bank_bridge requires power-of-two FIFO_DEPTH");
        end
    end
    // synthesis translate_on

endmodule
