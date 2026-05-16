// arb_hit_type0_fifo.sv
// Per-source configurable-depth ingress FIFO and ingress-side packet/drop tracking.
//
// Version : 26.6.4
// Date    : 20260516
// Change  : Preserve DEBUG_LEVEL=2 metadata valid beside the sidecar payload.
//           Support FIFO_DEPTH=2 for FEB resource-trim builds.

module arb_hit_type0_fifo #(
    parameter integer FIFO_DEPTH  = 16,
    parameter integer DEBUG_LEVEL = 0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        stream_clear,
    input  logic        stream_active,

    input  logic [44:0] asi_data,
    input  logic        asi_valid,
    input  logic [2:0]  asi_error,
    input  logic [3:0]  asi_channel,
    input  logic        asi_startofpacket,
    input  logic        asi_endofpacket,
    input  logic        asi_endofrun,
    input  logic [63:0] asi_debug_metadata,
    input  logic        asi_debug_metadata_valid,

    input  logic        pop,

    output logic [44:0] head_data,
    output logic [2:0]  head_error,
    output logic [3:0]  head_channel,
    output logic        head_startofpacket,
    output logic        head_endofpacket,
    output logic        head_endofrun,
    output logic [63:0] head_debug_metadata,
    output logic        head_debug_metadata_valid,

    output logic        empty,
    output logic        full,
    output logic [4:0]  depth,
    output logic        push_accept,
    output logic        push_drop,
    output logic        ingress_frame_pulse,
    output logic        ingress_open,
    output logic [15:0] idle_cycles,
    output logic [3:0]  last_channel
);

    localparam integer FIFO_DEPTH_CONST           = FIFO_DEPTH;
    localparam integer FIFO_PTR_WIDTH_CONST       = (FIFO_DEPTH_CONST <= 2) ? 1 : 4;
    localparam logic [4:0] FIFO_DEPTH_COUNT_CONST =
        (FIFO_DEPTH_CONST == 2) ? 5'd2 : 5'd16;

    typedef struct packed {
        logic [44:0] data;
        logic [2:0]  error;
        logic [3:0]  channel;
        logic        sop;
        logic        eop;
        logic        eor;
    } fifo_beat_t;

    (* ramstyle = "logic" *) fifo_beat_t fifo_mem [0:FIFO_DEPTH_CONST-1];

    fifo_beat_t head_beat;
    fifo_beat_t input_beat;
    logic [FIFO_PTR_WIDTH_CONST-1:0] read_ptr;
    logic [FIFO_PTR_WIDTH_CONST-1:0] write_ptr;
    logic [4:0] count;

    generate
        if (DEBUG_LEVEL >= 2) begin : debug_metadata_fifo
            (* ramstyle = "logic" *) logic [63:0] metadata_mem [0:FIFO_DEPTH_CONST-1];
            (* ramstyle = "logic" *) logic        metadata_valid_mem [0:FIFO_DEPTH_CONST-1];

            assign head_debug_metadata       = metadata_mem[read_ptr];
            assign head_debug_metadata_valid = metadata_valid_mem[read_ptr];

            always_ff @(posedge clk) begin : metadata_ram_writer
                if (push_accept) begin
                    metadata_mem[write_ptr]          <= asi_debug_metadata_valid ? asi_debug_metadata : 64'd0;
                    metadata_valid_mem[write_ptr]    <= asi_debug_metadata_valid;
                end
            end
        end else begin : no_debug_metadata_fifo
            assign head_debug_metadata       = 64'd0;
            assign head_debug_metadata_valid = 1'b0;
        end
    endgenerate

    assign input_beat = '{
        data:    asi_data,
        error:   asi_error,
        channel: asi_channel,
        sop:     asi_startofpacket,
        eop:     asi_endofpacket,
        eor:     asi_endofrun
    };

    assign head_beat          = fifo_mem[read_ptr];
    assign head_data          = head_beat.data;
    assign head_error         = head_beat.error;
    assign head_channel       = head_beat.channel;
    assign head_startofpacket = head_beat.sop;
    assign head_endofpacket   = head_beat.eop;
    assign head_endofrun      = head_beat.eor;

    assign empty              = (count == 5'd0);
    assign full               = (count == FIFO_DEPTH_COUNT_CONST);
    assign depth              = count;
    assign push_accept        = asi_valid & stream_active & ~full;
    assign push_drop          = asi_valid & stream_active & full;
    assign ingress_frame_pulse = asi_valid & asi_endofpacket;

    always_ff @(posedge clk or posedge rst) begin : fifo_state
        if (rst) begin
            read_ptr        <= '0;
            write_ptr       <= '0;
            count           <= 5'd0;
            ingress_open    <= 1'b0;
            idle_cycles     <= 16'd0;
            last_channel    <= 4'd0;
        end else if (stream_clear) begin
            read_ptr        <= '0;
            write_ptr       <= '0;
            count           <= 5'd0;
            ingress_open    <= 1'b0;
            idle_cycles     <= 16'd0;
            last_channel    <= 4'd0;
        end else if (stream_active) begin
            if (asi_valid) begin
                idle_cycles     <= 16'd0;
                last_channel    <= asi_channel;
            end else if (idle_cycles != 16'hFFFF) begin
                idle_cycles <= idle_cycles + 16'd1;
            end

            if (push_accept) begin
                write_ptr <= write_ptr + 1'b1;

                if (asi_startofpacket & ~(asi_endofpacket | asi_endofrun)) begin
                    ingress_open <= 1'b1;
                end else if (asi_endofpacket | asi_endofrun) begin
                    ingress_open <= 1'b0;
                end
            end

            if (pop) begin
                read_ptr <= read_ptr + 1'b1;
            end

            case ({push_accept, pop})
                2'b10:   count    <= count + 5'd1;
                2'b01:   count    <= count - 5'd1;
                default: count    <= count;
            endcase
        end
    end

    always_ff @(posedge clk) begin : fifo_ram_writer
        if (push_accept) begin
            fifo_mem[write_ptr] <= input_beat;
        end
    end

    // synthesis translate_off
    initial begin : parameter_guard
        if (!((FIFO_DEPTH == 2) || (FIFO_DEPTH == 16))) begin
            $error("arb_hit_type0_fifo supports FIFO_DEPTH=2 or FIFO_DEPTH=16 only");
        end
        if ((DEBUG_LEVEL < 0) || (DEBUG_LEVEL > 2)) begin
            $error("arb_hit_type0_fifo supports DEBUG_LEVEL in the range 0..2");
        end
    end
    // synthesis translate_on

endmodule
