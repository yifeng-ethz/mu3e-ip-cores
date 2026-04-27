`include "formal_defs.svh"

module runctl_mgmt_host_rc_formal_tb;
    (* gclk *) reg gclk;

    reg        f_past_valid = 1'b0;
    reg [1:0]  f_reset_sr   = 2'b11;
    reg [5:0]  f_cycle      = 6'd0;

    wire rst = f_reset_sr[1];

    localparam int STIM_NOACK   = 0;
    localparam int STIM_PREPARE = 1;
    localparam int STIM_END     = 2;
    localparam int STIM_KCHAR   = 3;
    localparam int STIM_ERROR   = 4;

    localparam logic [7:0] CMD_RUN_PREPARE = 8'h10;
    localparam logic [7:0] CMD_RUN_SYNC    = 8'h11;
    localparam logic [7:0] CMD_START_RUN   = 8'h12;
    localparam logic [7:0] CMD_END_RUN     = 8'h13;
    localparam logic [7:0] CMD_ABORT_RUN   = 8'h14;
    localparam logic [7:0] CMD_RESET       = 8'h30;
    localparam logic [7:0] CMD_STOP_RESET  = 8'h31;
    localparam logic [7:0] CMD_ENABLE      = 8'h32;
    localparam logic [7:0] CMD_DISABLE     = 8'h33;

    (* anyconst *) reg [2:0]  stim_kind;
    (* anyconst *) reg [7:0]  noack_cmd;
    (* anyconst *) reg [31:0] prepare_run_number;
    (* anyconst *) reg [7:0]  kchar_byte;
    (* anyconst *) reg [2:0]  error_code;
    (* anyseq *)   reg        aso_runctl_ready;
    (* anyseq *)   reg        aso_upload_ready;

    reg  [8:0] asi_synclink_data;
    reg  [2:0] asi_synclink_error;

    wire [35:0] aso_upload_data;
    wire        aso_upload_valid;
    wire        aso_upload_startofpacket;
    wire        aso_upload_endofpacket;
    wire        aso_runctl_valid;
    wire [8:0]  aso_runctl_data;
    wire        dp_hard_reset;
    wire        ct_hard_reset;
    wire        ext_hard_reset;

    wire runctl_fire = aso_runctl_valid && aso_runctl_ready;
    wire upload_fire = aso_upload_valid && aso_upload_ready;

    reg [3:0] runctl_stall_ctr = 4'd0;
    reg [3:0] upload_stall_ctr = 4'd0;

    reg        expect_runctl = 1'b0;
    reg [8:0]  expected_runctl_data = 9'd0;
    reg [3:0]  runctl_deadline = 4'd0;
    reg        expect_ack = 1'b0;
    reg [35:0] expected_ack_data = 36'd0;
    reg [3:0]  ack_deadline = 4'd0;
    reg        expect_reset_assert = 1'b0;
    reg        expect_reset_clear  = 1'b0;
    reg [2:0]  reset_deadline = 3'd0;

    reg [1:0] runctl_fire_count = 2'd0;
    reg [1:0] upload_fire_count = 2'd0;

    reg        prev_runctl_valid = 1'b0;
    reg [8:0]  prev_runctl_data = 9'd0;
    reg        prev_runctl_ready = 1'b0;
    reg        prev_upload_valid = 1'b0;
    reg [35:0] prev_upload_data = 36'd0;
    reg        prev_upload_sop = 1'b0;
    reg        prev_upload_eop = 1'b0;
    reg        prev_upload_ready = 1'b0;

    function automatic [8:0] expected_runcode(input [7:0] cmd);
        case (cmd)
            CMD_RUN_PREPARE: expected_runcode = 9'b000000010;
            CMD_RUN_SYNC:    expected_runcode = 9'b000000100;
            CMD_START_RUN:   expected_runcode = 9'b000001000;
            CMD_END_RUN:     expected_runcode = 9'b000010000;
            CMD_ABORT_RUN:   expected_runcode = 9'b000000001;
            CMD_RESET:       expected_runcode = 9'b010000000;
            CMD_STOP_RESET:  expected_runcode = 9'b000000001;
            CMD_ENABLE:      expected_runcode = 9'b000000001;
            CMD_DISABLE:     expected_runcode = 9'b100000000;
            default:         expected_runcode = 9'b000000000;
        endcase
    endfunction

    function automatic [7:0] prepare_byte(input [31:0] word, input [2:0] idx);
        case (idx)
            3'd0: prepare_byte = word[31:24];
            3'd1: prepare_byte = word[23:16];
            3'd2: prepare_byte = word[15:8];
            default: prepare_byte = word[7:0];
        endcase
    endfunction

    always @* begin
        asi_synclink_data  = 9'h1BC;
        asi_synclink_error = 3'b000;

        if (!rst) begin
            case (stim_kind)
                STIM_NOACK: begin
                    if (f_cycle == 0) begin
                        asi_synclink_data = {1'b0, noack_cmd};
                    end
                end
                STIM_PREPARE: begin
                    if (f_cycle == 0) begin
                        asi_synclink_data = {1'b0, CMD_RUN_PREPARE};
                    end else if (f_cycle >= 1 && f_cycle <= 4) begin
                        asi_synclink_data = {1'b0, prepare_byte(prepare_run_number, f_cycle - 1'b1)};
                    end
                end
                STIM_END: begin
                    if (f_cycle == 0) begin
                        asi_synclink_data = {1'b0, CMD_END_RUN};
                    end
                end
                STIM_KCHAR: begin
                    if (f_cycle == 0) begin
                        asi_synclink_data = {1'b1, kchar_byte};
                    end
                end
                STIM_ERROR: begin
                    if (f_cycle == 0) begin
                        asi_synclink_data  = {1'b0, 8'h00};
                        asi_synclink_error = error_code;
                    end
                end
                default: begin
                    asi_synclink_data  = 9'h1BC;
                    asi_synclink_error = 3'b000;
                end
            endcase
        end
    end

    runctl_mgmt_host dut (
        .asi_synclink_data        (asi_synclink_data),
        .asi_synclink_error       (asi_synclink_error),
        .aso_upload_data          (aso_upload_data),
        .aso_upload_valid         (aso_upload_valid),
        .aso_upload_ready         (aso_upload_ready),
        .aso_upload_startofpacket (aso_upload_startofpacket),
        .aso_upload_endofpacket   (aso_upload_endofpacket),
        .aso_runctl_valid         (aso_runctl_valid),
        .aso_runctl_data          (aso_runctl_data),
        .aso_runctl_ready         (aso_runctl_ready),
        .avs_csr_address          (5'd0),
        .avs_csr_read             (1'b0),
        .avs_csr_readdata         (),
        .avs_csr_write            (1'b0),
        .avs_csr_writedata        (32'd0),
        .avs_csr_waitrequest      (),
        .dp_hard_reset            (dp_hard_reset),
        .ct_hard_reset            (ct_hard_reset),
        .ext_hard_reset           (ext_hard_reset),
        .mm_clk                   (gclk),
        .mm_reset                 (rst),
        .lvdspll_clk              (gclk),
        .lvdspll_reset            (rst)
    );

    always @(posedge gclk) begin
        f_past_valid <= 1'b1;

        if (!f_past_valid) begin
            assume(rst);
            assume(stim_kind <= STIM_ERROR);
            assume(
                (noack_cmd == CMD_RUN_SYNC)   ||
                (noack_cmd == CMD_START_RUN)  ||
                (noack_cmd == CMD_ABORT_RUN)  ||
                (noack_cmd == CMD_RESET)      ||
                (noack_cmd == CMD_STOP_RESET) ||
                (noack_cmd == CMD_ENABLE)     ||
                (noack_cmd == CMD_DISABLE)
            );
            assume(
                (kchar_byte == 8'hBC) ||
                (kchar_byte == 8'hF7) ||
                (kchar_byte == 8'h9C) ||
                (kchar_byte == 8'h1C) ||
                (kchar_byte == 8'h3C) ||
                (kchar_byte == 8'h7C) ||
                (kchar_byte == 8'hDC)
            );
            assume(
                (error_code == 3'b001) ||
                (error_code == 3'b010) ||
                (error_code == 3'b100)
            );
        end

        if (f_reset_sr != 2'b00) begin
            f_reset_sr <= {f_reset_sr[0], 1'b0};
            f_cycle    <= 6'd0;
        end else if (f_cycle != 6'h3F) begin
            f_cycle <= f_cycle + 6'd1;
        end

        if (rst) begin
            runctl_stall_ctr   <= 4'd0;
            upload_stall_ctr   <= 4'd0;
            expect_runctl      <= 1'b0;
            expected_runctl_data <= 9'd0;
            runctl_deadline    <= 4'd0;
            expect_ack         <= 1'b0;
            expected_ack_data  <= 36'd0;
            ack_deadline       <= 4'd0;
            expect_reset_assert <= 1'b0;
            expect_reset_clear  <= 1'b0;
            reset_deadline      <= 3'd0;
            runctl_fire_count  <= 2'd0;
            upload_fire_count  <= 2'd0;
            prev_runctl_valid  <= 1'b0;
            prev_runctl_data   <= 9'd0;
            prev_runctl_ready  <= 1'b0;
            prev_upload_valid  <= 1'b0;
            prev_upload_data   <= 36'd0;
            prev_upload_sop    <= 1'b0;
            prev_upload_eop    <= 1'b0;
            prev_upload_ready  <= 1'b0;
        end else begin
            prev_runctl_valid <= aso_runctl_valid;
            prev_runctl_data  <= aso_runctl_data;
            prev_runctl_ready <= aso_runctl_ready;
            prev_upload_valid <= aso_upload_valid;
            prev_upload_data  <= aso_upload_data;
            prev_upload_sop   <= aso_upload_startofpacket;
            prev_upload_eop   <= aso_upload_endofpacket;
            prev_upload_ready <= aso_upload_ready;

            if (aso_runctl_valid && !aso_runctl_ready) begin
                runctl_stall_ctr <= runctl_stall_ctr + 4'd1;
            end else begin
                runctl_stall_ctr <= 4'd0;
            end

            if (aso_upload_valid && !aso_upload_ready) begin
                upload_stall_ctr <= upload_stall_ctr + 4'd1;
            end else begin
                upload_stall_ctr <= 4'd0;
            end

            assume(runctl_stall_ctr < `FORMAL_READY_STALL_MAX);
            assume(upload_stall_ctr < `FORMAL_READY_STALL_MAX);

            if (f_cycle == 0) begin
                case (stim_kind)
                    STIM_NOACK: begin
                        expect_runctl <= 1'b1;
                        expected_runctl_data <= expected_runcode(noack_cmd);
                        runctl_deadline <= `FORMAL_CMD_LAT_MAX;
                    end
                    STIM_END: begin
                        expect_runctl <= 1'b1;
                        expected_runctl_data <= expected_runcode(CMD_END_RUN);
                        runctl_deadline <= `FORMAL_CMD_LAT_MAX;
                    end
                    default: begin
                    end
                endcase
            end

            if (f_cycle == 4 && stim_kind == STIM_PREPARE) begin
                expect_runctl <= 1'b1;
                expected_runctl_data <= expected_runcode(CMD_RUN_PREPARE);
                runctl_deadline <= `FORMAL_CMD_LAT_MAX;
            end

            if (expect_runctl) begin
                assert(runctl_deadline != 4'd0);
                runctl_deadline <= runctl_deadline - 4'd1;
            end
            if (expect_ack) begin
                assert(ack_deadline != 4'd0);
                ack_deadline <= ack_deadline - 4'd1;
            end
            if (expect_reset_assert || expect_reset_clear) begin
                assert(reset_deadline != 3'd0);
                reset_deadline <= reset_deadline - 3'd1;
            end

            if (runctl_fire) begin
                runctl_fire_count <= runctl_fire_count + 2'd1;
                assert(expect_runctl);
                assert(aso_runctl_data == expected_runctl_data);
                expect_runctl   <= 1'b0;
                runctl_deadline <= 4'd0;
                if (stim_kind == STIM_PREPARE) begin
                    expect_ack        <= 1'b1;
                    expected_ack_data <= {4'b0001, prepare_run_number[23:0], 8'hFE};
                    ack_deadline      <= `FORMAL_ACK_LAT_MAX;
                end
                if (stim_kind == STIM_END) begin
                    expect_ack        <= 1'b1;
                    expected_ack_data <= {4'b0001, 24'h000000, 8'hFD};
                    ack_deadline      <= `FORMAL_ACK_LAT_MAX;
                end
                if (stim_kind == STIM_NOACK && (noack_cmd == CMD_RESET)) begin
                    expect_reset_assert <= 1'b1;
                    reset_deadline      <= 3'd2;
                end
                if (stim_kind == STIM_NOACK && (noack_cmd == CMD_STOP_RESET)) begin
                    expect_reset_clear <= 1'b1;
                    reset_deadline     <= 3'd2;
                end
            end

            if (upload_fire) begin
                upload_fire_count <= upload_fire_count + 2'd1;
                assert(expect_ack);
                assert(aso_upload_data == expected_ack_data);
                assert(aso_upload_startofpacket);
                assert(aso_upload_endofpacket);
                expect_ack   <= 1'b0;
                ack_deadline <= 4'd0;
            end

            if (f_past_valid && prev_runctl_valid && !prev_runctl_ready) begin
                assert(aso_runctl_valid);
                assert(aso_runctl_data == prev_runctl_data);
            end

            if (f_past_valid && prev_upload_valid && !prev_upload_ready) begin
                assert(aso_upload_valid);
                assert(aso_upload_data == prev_upload_data);
                assert(aso_upload_startofpacket == prev_upload_sop);
                assert(aso_upload_endofpacket == prev_upload_eop);
            end

            assert(runctl_fire_count <= 2'd1);
            assert(upload_fire_count <= 2'd1);

            if (stim_kind == STIM_KCHAR || stim_kind == STIM_ERROR) begin
                assert(!runctl_fire);
                assert(!upload_fire);
            end

            if (expect_reset_assert) begin
                if (dp_hard_reset && ct_hard_reset && ext_hard_reset) begin
                    expect_reset_assert <= 1'b0;
                    reset_deadline      <= 3'd0;
                end
            end

            if (expect_reset_clear) begin
                if (!dp_hard_reset && !ct_hard_reset && !ext_hard_reset) begin
                    expect_reset_clear <= 1'b0;
                    reset_deadline     <= 3'd0;
                end
            end

            cover(stim_kind == STIM_KCHAR && f_cycle == 1);
            cover(stim_kind == STIM_ERROR && f_cycle == 1);
            cover(stim_kind == STIM_NOACK && runctl_fire && noack_cmd == CMD_START_RUN);
            cover(stim_kind == STIM_NOACK && runctl_fire && noack_cmd == CMD_RESET);
            cover(stim_kind == STIM_PREPARE && runctl_fire);
            cover(stim_kind == STIM_PREPARE && upload_fire);
            cover(stim_kind == STIM_END && runctl_fire);
            cover(stim_kind == STIM_END && upload_fire);
        end
    end

endmodule
