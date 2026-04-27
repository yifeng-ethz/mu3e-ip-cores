// frame_assembler.sv
// MuTRiG frame assembler — raw-frame_gen-compatible 8b/1k output
// Version : 26.1.7
// Date    : 20260418
// Change  : Replace the simplified packer with a literal raw-style state
//           machine and register the transmitted byte exactly like raw
//           frame_gen so short/long mode timing and frozen-count drain match
//           the MuTRiG VHDL semantics.

module frame_assembler
    import emulator_mutrig_pkg::*;
#(
    parameter int MAX_EVENTS_PER_FRAME = 120
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        frame_start_req,

    input  logic        cfg_short_mode,
    input  logic        cfg_gen_idle,
    input  logic [2:0]  cfg_tx_mode,

    output logic        fifo_rd_en,
    input  logic [47:0] fifo_data,
    input  logic [9:0]  event_count,
    input  logic        fifo_empty,
    input  logic        fifo_almost_full,

    output logic        frame_start,
    output logic [8:0]  tx_data,
    output logic        tx_valid
);

    localparam int EVENT_COUNT_WIDTH = 8;

    typedef enum logic [3:0] {
        FS_IDLE,
        FS_ENC_RESET0,
        FS_ENC_RESET1,
        FS_HEADER,
        FS_FRAMECOUNT,
        FS_EVENTCOUNT,
        FS_PACK,
        FS_PACK_EXTRA,
        FS_DELAY,
        FS_DELAY_EMIT,
        FS_CRC_REM,
        FS_TRAILER
    } fsm_t;

    fsm_t        p_state, n_state;
    logic [EVENT_COUNT_WIDTH-1:0] p_event_count, n_event_count;
    logic [EVENT_COUNT_WIDTH-1:0] p_event_cnt_decr, n_event_cnt_decr;
    logic [15:0] p_frame_count, n_frame_count;
    logic [2:0]  p_byte_count, n_byte_count;
    logic [47:0] p_event_data_srg, n_event_data_srg;
    logic        p_sc_fast_mode, n_sc_fast_mode;
    logic        p_pack_event_odd, n_pack_event_odd;
    logic        p_last_event, n_last_event;
    logic        p_fifo_full, n_fifo_full;
    logic        p_fifo_rd_en, n_fifo_rd_en;
    logic        p_dbyteisk, n_dbyteisk;
    logic [7:0]  p_dbyte, n_dbyte;
    logic        p_crc_rst, n_crc_rst;
    logic        p_crc_dvalid, n_crc_dvalid;
    logic        frame_start_next;

    logic        l_txmode_fast;
    logic [27:0] short_hit;
    logic [15:0] event_count_ext;
    logic [15:0] crc_result;
    logic [7:0]  tx_byte_q;
    logic        tx_isk_q;

    assign l_txmode_fast = (cfg_tx_mode == 3'b100);
    assign short_hit = {fifo_data[47:43], fifo_data[21], fifo_data[20:6], fifo_data[5:1], fifo_data[0], 1'b0};
    assign event_count_ext = {cfg_gen_idle, cfg_tx_mode, p_fifo_full, 1'b0, 2'b00, p_event_count};

    crc16_8 u_crc (
        .clk     (clk),
        .rst     (n_crc_rst),
        .d_valid (n_crc_dvalid),
        .din     (n_dbyte),
        .crc_reg (crc_result),
        .crc_8   ()
    );

    assign tx_data  = {tx_isk_q, tx_byte_q};
    assign tx_valid = 1'b1;
    assign fifo_rd_en = p_fifo_rd_en;

    always_ff @(posedge clk) begin
        if (rst) begin
            p_state          <= FS_IDLE;
            p_event_count    <= '0;
            p_event_cnt_decr <= '0;
            p_frame_count    <= '0;
            p_byte_count     <= '0;
            p_event_data_srg <= '0;
            p_sc_fast_mode   <= 1'b0;
            p_pack_event_odd <= 1'b0;
            p_last_event     <= 1'b0;
            p_fifo_full      <= 1'b0;
            p_fifo_rd_en     <= 1'b0;
            p_dbyteisk       <= 1'b1;
            p_dbyte          <= K28_5;
            p_crc_rst        <= 1'b1;
            p_crc_dvalid     <= 1'b0;
            frame_start      <= 1'b0;
            tx_byte_q        <= K28_5;
            tx_isk_q         <= 1'b1;
        end else begin
            p_state          <= n_state;
            p_event_count    <= n_event_count;
            p_event_cnt_decr <= n_event_cnt_decr;
            p_frame_count    <= n_frame_count;
            p_byte_count     <= n_byte_count;
            p_event_data_srg <= n_event_data_srg;
            p_sc_fast_mode   <= n_sc_fast_mode;
            p_pack_event_odd <= n_pack_event_odd;
            p_last_event     <= n_last_event;
            p_fifo_full      <= n_fifo_full;
            p_fifo_rd_en     <= n_fifo_rd_en;
            p_dbyteisk       <= n_dbyteisk;
            p_dbyte          <= n_dbyte;
            p_crc_rst        <= n_crc_rst;
            p_crc_dvalid     <= n_crc_dvalid;
            frame_start      <= frame_start_next;

            if ((p_state == FS_CRC_REM) || (p_state == FS_TRAILER)) begin
                tx_byte_q <= n_dbyte;
                tx_isk_q  <= n_dbyteisk;
            end else begin
                tx_byte_q <= p_dbyte;
                tx_isk_q  <= p_dbyteisk;
            end
        end
    end

    always_comb begin
        n_state          = p_state;
        n_event_count    = p_event_count;
        n_event_cnt_decr = p_event_cnt_decr;
        n_frame_count    = p_frame_count;
        n_byte_count     = p_byte_count;
        n_event_data_srg = p_event_data_srg;
        n_sc_fast_mode   = p_sc_fast_mode;
        n_pack_event_odd = p_pack_event_odd;
        n_last_event     = p_last_event;
        n_fifo_full      = p_fifo_full;
        n_fifo_rd_en     = 1'b0;
        n_dbyteisk       = p_dbyteisk;
        n_dbyte          = p_dbyte;
        n_crc_rst        = p_crc_rst;
        n_crc_dvalid     = p_crc_dvalid;
        frame_start_next = 1'b0;

        case (p_state)
            FS_IDLE: begin
                n_dbyte          = K28_5;
                n_dbyteisk       = 1'b1;
                n_event_count    = event_count[EVENT_COUNT_WIDTH-1:0];
                n_event_cnt_decr = event_count[EVENT_COUNT_WIDTH-1:0];
                n_pack_event_odd = 1'b0;
                n_last_event     = 1'b0;
                n_sc_fast_mode   = l_txmode_fast;
                n_fifo_full      = fifo_almost_full;
                n_crc_rst        = 1'b1;
                n_crc_dvalid     = 1'b0;

                if (frame_start_req) begin
                    frame_start_next = 1'b1;
                    if (cfg_gen_idle)
                        n_state = FS_HEADER;
                    else
                        n_state = FS_ENC_RESET0;
                end
            end

            FS_ENC_RESET0: begin
                n_dbyte    = K28_5;
                n_dbyteisk = 1'b1;
                n_state    = FS_ENC_RESET1;
            end

            FS_ENC_RESET1: begin
                n_dbyte    = K28_5;
                n_dbyteisk = 1'b1;
                n_state    = FS_HEADER;
            end

            FS_HEADER: begin
                n_dbyte     = K28_0;
                n_dbyteisk  = 1'b1;
                n_state     = FS_FRAMECOUNT;
                n_byte_count = 3'd2;
            end

            FS_FRAMECOUNT: begin
                n_dbyteisk   = 1'b0;
                n_crc_rst    = 1'b0;
                n_crc_dvalid = 1'b1;

                case (p_byte_count)
                    3'd2: begin
                        n_dbyte      = p_frame_count[15:8];
                        n_byte_count = 3'd1;
                        if (p_event_cnt_decr != '0) begin
                            n_fifo_rd_en     = 1'b1;
                            n_event_cnt_decr = p_event_cnt_decr - EVENT_COUNT_WIDTH'(1);
                        end
                    end
                    3'd1: begin
                        n_dbyte      = p_frame_count[7:0];
                        n_state      = FS_EVENTCOUNT;
                        n_byte_count = 3'd2;
                    end
                    default: begin
                        n_byte_count = 3'd2;
                    end
                endcase
            end

            FS_EVENTCOUNT: begin
                n_dbyteisk = 1'b0;

                case (p_byte_count)
                    3'd2: begin
                        n_dbyte      = event_count_ext[15:8];
                        n_byte_count = 3'd1;
                    end
                    3'd1: begin
                        n_dbyte = event_count_ext[7:0];
                        if (p_event_count != '0) begin
                            n_state = FS_PACK;
                            if (p_sc_fast_mode) begin
                                n_event_data_srg = {short_hit, 20'b0};
                                n_byte_count     = 3'd3;
                                if (p_event_cnt_decr != '0) begin
                                    n_fifo_rd_en     = 1'b1;
                                    n_event_cnt_decr = p_event_cnt_decr - EVENT_COUNT_WIDTH'(1);
                                    n_last_event     = 1'b0;
                                end else begin
                                    n_last_event = 1'b1;
                                end
                            end else begin
                                n_event_data_srg = fifo_data;
                                n_byte_count     = 3'd6;
                                if (p_event_cnt_decr == '0)
                                    n_last_event = 1'b1;
                                else
                                    n_last_event = 1'b0;
                            end
                        end else begin
                            n_state = FS_DELAY;
                        end
                    end
                    default: begin
                        n_byte_count = 3'd1;
                    end
                endcase
            end

            FS_PACK: begin
                n_dbyte          = p_event_data_srg[47:40];
                n_dbyteisk       = 1'b0;
                n_event_data_srg = {p_event_data_srg[39:0], 8'b0};
                n_byte_count     = p_byte_count - 3'd1;

                if (p_sc_fast_mode) begin
                    if (p_last_event) begin
                        if (p_byte_count == 3'd1)
                            n_state = FS_PACK_EXTRA;
                    end else if (p_byte_count == 3'd1) begin
                        if (!p_pack_event_odd) begin
                            n_event_data_srg[47:44] = p_event_data_srg[39:36];
                            n_event_data_srg[43:16] = short_hit;
                            n_event_data_srg[15:0]  = 16'b0;
                            n_byte_count            = 3'd3;
                            n_pack_event_odd        = 1'b1;
                            if (p_event_cnt_decr == '0) begin
                                n_last_event = 1'b1;
                            end else begin
                                n_fifo_rd_en     = 1'b1;
                                n_event_cnt_decr = p_event_cnt_decr - EVENT_COUNT_WIDTH'(1);
                                n_last_event     = 1'b0;
                            end
                        end else begin
                            n_state = FS_PACK_EXTRA;
                        end
                    end
                end else begin
                    if (p_last_event) begin
                        if (p_byte_count == 3'd1)
                            n_state = FS_DELAY;
                    end else if (p_event_cnt_decr != '0) begin
                        if (p_byte_count == 3'd4) begin
                            n_fifo_rd_en     = 1'b1;
                            n_event_cnt_decr = p_event_cnt_decr - EVENT_COUNT_WIDTH'(1);
                        end
                        if (p_byte_count == 3'd1) begin
                            n_event_data_srg = fifo_data;
                            n_byte_count     = 3'd6;
                        end
                    end else if (p_byte_count == 3'd1) begin
                        n_event_data_srg = fifo_data;
                        n_byte_count     = 3'd6;
                        n_last_event     = 1'b1;
                    end
                end
            end

            FS_PACK_EXTRA: begin
                n_dbyte    = p_event_data_srg[47:40];
                n_dbyteisk = 1'b0;

                if (p_last_event) begin
                    n_state = FS_DELAY;
                end else begin
                    n_event_data_srg = {short_hit, 20'b0};
                    n_byte_count     = 3'd3;
                    n_pack_event_odd = 1'b0;
                    n_state          = FS_PACK;
                    if (p_event_cnt_decr == '0) begin
                        n_last_event = 1'b1;
                    end else begin
                        n_fifo_rd_en     = 1'b1;
                        n_event_cnt_decr = p_event_cnt_decr - EVENT_COUNT_WIDTH'(1);
                        n_last_event     = 1'b0;
                    end
                end
            end

            FS_DELAY: begin
                n_dbyte      = 8'h00;
                n_dbyteisk   = 1'b0;
                n_crc_rst    = 1'b0;
                n_crc_dvalid = 1'b0;
                n_state      = FS_DELAY_EMIT;
            end

            FS_DELAY_EMIT: begin
                n_crc_rst    = 1'b0;
                n_crc_dvalid = 1'b0;
                n_state      = FS_CRC_REM;
                n_byte_count = 3'd2;
            end

            FS_CRC_REM: begin
                n_dbyteisk = 1'b0;
                case (p_byte_count)
                    3'd2: begin
                        n_dbyte      = crc_result[15:8];
                        n_byte_count = 3'd1;
                    end
                    3'd1: begin
                        n_dbyte      = crc_result[7:0];
                        n_state      = FS_TRAILER;
                        n_byte_count = 3'd2;
                    end
                    default: begin
                        n_byte_count = 3'd2;
                    end
                endcase
            end

            FS_TRAILER: begin
                n_byte_count = p_byte_count - 3'd1;
                if (p_byte_count != 3'd1) begin
                    n_dbyte    = K28_4;
                    n_dbyteisk = 1'b1;
                end else begin
                    n_frame_count    = p_frame_count + 16'd1;
                    n_dbyte          = K28_5;
                    n_dbyteisk       = 1'b1;
                    n_state          = FS_IDLE;
                    n_event_count    = event_count[EVENT_COUNT_WIDTH-1:0];
                    n_event_cnt_decr = event_count[EVENT_COUNT_WIDTH-1:0];
                    n_pack_event_odd = 1'b0;
                    n_last_event     = 1'b0;
                    n_sc_fast_mode   = l_txmode_fast;
                    n_fifo_full      = fifo_almost_full;
                    n_crc_rst        = 1'b1;
                    n_crc_dvalid     = 1'b0;

                    if (frame_start_req) begin
                        frame_start_next = 1'b1;
                        if (cfg_gen_idle)
                            n_state = FS_HEADER;
                        else
                            n_state = FS_ENC_RESET0;
                    end
                end
            end

            default: begin
                n_state = FS_IDLE;
            end
        endcase
    end

endmodule
