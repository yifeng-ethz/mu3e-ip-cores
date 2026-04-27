// dbg_mm2runctrl.sv
// CSR-driven local run-control source for FE datapath bring-up.
//
// CSR map (word addresses):
//   0x0 ID          RO  0x4D325243 ("M2RC")
//   0x1 STATUS      RO  {gap_cycles[31:16], last_from_host, bad_cmd, overrun, script_busy, pending, local_enable}
//   0x2 CONTROL     RW  bit0=local_enable, bit1=flush pending/script (W1P), bit2=clear sticky flags (W1P)
//   0x3 HOST_CMD    WO  raw host command byte (0x10/0x11/0x12/0x13/0x14/0x30/0x31/0x32/0x33)
//   0x4 STATE_CMD   WO  direct one-hot run-state word [8:0]
//   0x5 SCRIPT      WO  1=start self-run script, 2=end-run, 3=abort-to-idle
//   0x6 GAP_CYCLES  RW  inter-command gap for SCRIPT sequencing
//   0x7 SENT_COUNT  RO  accepted AVST command count
//   0x8 LAST_SENT   RO  {host_cmd[17:10], from_host[9], state_word[8:0]}

module dbg_mm2runctrl (
    input  logic        i_clk,
    input  logic        i_rst,

    input  logic [3:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    output logic [8:0]  aso_ctrl_data,
    output logic        aso_ctrl_valid,
    input  logic        aso_ctrl_ready
);

    localparam logic [31:0] ID_WORD           = 32'h4D32_5243;
    localparam logic [15:0] GAP_CYCLES_DFLT   = 16'd4;

    localparam logic [7:0] CMD_RUN_PREPARE    = 8'h10;
    localparam logic [7:0] CMD_RUN_SYNC       = 8'h11;
    localparam logic [7:0] CMD_START_RUN      = 8'h12;
    localparam logic [7:0] CMD_END_RUN        = 8'h13;
    localparam logic [7:0] CMD_ABORT_RUN      = 8'h14;
    localparam logic [7:0] CMD_RESET          = 8'h30;
    localparam logic [7:0] CMD_STOP_RESET     = 8'h31;
    localparam logic [7:0] CMD_ENABLE         = 8'h32;
    localparam logic [7:0] CMD_DISABLE        = 8'h33;

    localparam logic [8:0] RC_IDLE            = 9'b000000001;
    localparam logic [8:0] RC_RUN_PREPARE     = 9'b000000010;
    localparam logic [8:0] RC_SYNC            = 9'b000000100;
    localparam logic [8:0] RC_RUNNING         = 9'b000001000;
    localparam logic [8:0] RC_TERMINATING     = 9'b000010000;
    localparam logic [8:0] RC_RESET           = 9'b010000000;
    localparam logic [8:0] RC_OUT_OF_DAQ      = 9'b100000000;

    localparam logic [2:0] SCRIPT_NONE        = 3'd0;
    localparam logic [2:0] SCRIPT_SELF_RUN    = 3'd1;
    localparam logic [2:0] SCRIPT_END_RUN     = 3'd2;
    localparam logic [2:0] SCRIPT_ABORT_IDLE  = 3'd3;

    logic        local_enable;
    logic        pending_valid;
    logic [8:0]  pending_state;
    logic [7:0]  pending_host_cmd;
    logic        pending_from_host;
    logic        sticky_overrun;
    logic        sticky_bad_cmd;
    logic [15:0] gap_cycles;
    logic [15:0] gap_count;
    logic [2:0]  script_kind;
    logic [2:0]  script_step;
    logic [31:0] sent_count;
    logic [8:0]  last_sent_state;
    logic [7:0]  last_sent_host_cmd;
    logic        last_sent_from_host;

    function automatic logic [9:0] decode_host_cmd(input logic [7:0] host_cmd);
        case (host_cmd)
            CMD_RUN_PREPARE: decode_host_cmd = {1'b1, RC_RUN_PREPARE};
            CMD_RUN_SYNC:    decode_host_cmd = {1'b1, RC_SYNC};
            CMD_START_RUN:   decode_host_cmd = {1'b1, RC_RUNNING};
            CMD_END_RUN:     decode_host_cmd = {1'b1, RC_TERMINATING};
            CMD_ABORT_RUN:   decode_host_cmd = {1'b1, RC_IDLE};
            CMD_RESET:       decode_host_cmd = {1'b1, RC_RESET};
            CMD_STOP_RESET:  decode_host_cmd = {1'b1, RC_IDLE};
            CMD_ENABLE:      decode_host_cmd = {1'b1, RC_IDLE};
            CMD_DISABLE:     decode_host_cmd = {1'b1, RC_OUT_OF_DAQ};
            default:         decode_host_cmd = 10'b0;
        endcase
    endfunction

    function automatic logic [8:0] script_host_cmd(input logic [2:0] kind, input logic [2:0] step);
        case (kind)
            SCRIPT_SELF_RUN: begin
                case (step)
                    3'd0: script_host_cmd = {1'b1, CMD_STOP_RESET};
                    3'd1: script_host_cmd = {1'b1, CMD_ENABLE};
                    3'd2: script_host_cmd = {1'b1, CMD_RUN_PREPARE};
                    3'd3: script_host_cmd = {1'b1, CMD_RUN_SYNC};
                    3'd4: script_host_cmd = {1'b1, CMD_START_RUN};
                    default: script_host_cmd = 9'b0;
                endcase
            end
            SCRIPT_END_RUN: begin
                case (step)
                    3'd0: script_host_cmd = {1'b1, CMD_END_RUN};
                    default: script_host_cmd = 9'b0;
                endcase
            end
            SCRIPT_ABORT_IDLE: begin
                case (step)
                    3'd0: script_host_cmd = {1'b1, CMD_ABORT_RUN};
                    default: script_host_cmd = 9'b0;
                endcase
            end
            default: script_host_cmd = 9'b0;
        endcase
    endfunction

    function automatic logic script_done(input logic [2:0] kind, input logic [2:0] step);
        case (kind)
            SCRIPT_SELF_RUN:   script_done = (step == 3'd4);
            SCRIPT_END_RUN:    script_done = (step == 3'd0);
            SCRIPT_ABORT_IDLE: script_done = (step == 3'd0);
            default:           script_done = 1'b1;
        endcase
    endfunction

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            local_enable       <= 1'b1;
            pending_valid      <= 1'b0;
            pending_state      <= '0;
            pending_host_cmd   <= '0;
            pending_from_host  <= 1'b0;
            sticky_overrun     <= 1'b0;
            sticky_bad_cmd     <= 1'b0;
            gap_cycles         <= GAP_CYCLES_DFLT;
            gap_count          <= '0;
            script_kind        <= SCRIPT_NONE;
            script_step        <= '0;
            sent_count         <= '0;
            last_sent_state    <= '0;
            last_sent_host_cmd <= '0;
            last_sent_from_host<= 1'b0;
        end else begin
            if (pending_valid && aso_ctrl_ready) begin
                pending_valid       <= 1'b0;
                last_sent_state     <= pending_state;
                last_sent_host_cmd  <= pending_host_cmd;
                last_sent_from_host <= pending_from_host;
                sent_count          <= sent_count + 32'd1;
            end

            if (!pending_valid && (script_kind != SCRIPT_NONE) && (gap_count != 16'd0)) begin
                gap_count <= gap_count - 16'd1;
            end

            if (avs_csr_write) begin
                case (avs_csr_address)
                    4'h2: begin
                        local_enable <= avs_csr_writedata[0];
                        if (avs_csr_writedata[1]) begin
                            pending_valid     <= 1'b0;
                            script_kind       <= SCRIPT_NONE;
                            script_step       <= '0;
                            gap_count         <= '0;
                        end
                        if (avs_csr_writedata[2]) begin
                            sticky_overrun    <= 1'b0;
                            sticky_bad_cmd    <= 1'b0;
                        end
                    end
                    4'h3: begin
                        logic [9:0] decoded_host;
                        decoded_host = decode_host_cmd(avs_csr_writedata[7:0]);
                        if (!local_enable || pending_valid || (script_kind != SCRIPT_NONE)) begin
                            sticky_overrun <= 1'b1;
                        end else if (!decoded_host[9]) begin
                            sticky_bad_cmd <= 1'b1;
                        end else begin
                            pending_valid     <= 1'b1;
                            pending_state     <= decoded_host[8:0];
                            pending_host_cmd  <= avs_csr_writedata[7:0];
                            pending_from_host <= 1'b1;
                        end
                    end
                    4'h4: begin
                        if (!local_enable || pending_valid || (script_kind != SCRIPT_NONE)) begin
                            sticky_overrun <= 1'b1;
                        end else if (avs_csr_writedata[8:0] == 9'b0) begin
                            sticky_bad_cmd <= 1'b1;
                        end else begin
                            pending_valid     <= 1'b1;
                            pending_state     <= avs_csr_writedata[8:0];
                            pending_host_cmd  <= 8'h00;
                            pending_from_host <= 1'b0;
                        end
                    end
                    4'h5: begin
                        if (!local_enable || pending_valid || (script_kind != SCRIPT_NONE)) begin
                            sticky_overrun <= 1'b1;
                        end else begin
                            case (avs_csr_writedata[2:0])
                                SCRIPT_SELF_RUN,
                                SCRIPT_END_RUN,
                                SCRIPT_ABORT_IDLE: begin
                                    script_kind <= avs_csr_writedata[2:0];
                                    script_step <= 3'd0;
                                    gap_count   <= 16'd0;
                                end
                                default: sticky_bad_cmd <= 1'b1;
                            endcase
                        end
                    end
                    4'h6: gap_cycles <= avs_csr_writedata[31:16];
                    default: begin
                    end
                endcase
            end

            if (local_enable && !pending_valid && (script_kind != SCRIPT_NONE) && (gap_count == 16'd0)) begin
                logic [8:0] next_host;
                logic [9:0] next_state;

                next_host  = script_host_cmd(script_kind, script_step);
                next_state = decode_host_cmd(next_host[7:0]);
                if (next_host[8] && next_state[9]) begin
                    pending_valid     <= 1'b1;
                    pending_state     <= next_state[8:0];
                    pending_host_cmd  <= next_host[7:0];
                    pending_from_host <= 1'b1;
                    if (script_done(script_kind, script_step)) begin
                        script_kind <= SCRIPT_NONE;
                        script_step <= 3'd0;
                    end else begin
                        script_step <= script_step + 3'd1;
                        gap_count   <= gap_cycles;
                    end
                end else begin
                    sticky_bad_cmd <= 1'b1;
                    script_kind    <= SCRIPT_NONE;
                    script_step    <= 3'd0;
                end
            end
        end
    end

    always_comb begin
        avs_csr_waitrequest = 1'b0;
        aso_ctrl_data       = pending_state;
        aso_ctrl_valid      = pending_valid;

        unique case (avs_csr_address)
            4'h0: avs_csr_readdata = ID_WORD;
            4'h1: avs_csr_readdata = {gap_cycles, 3'b000, last_sent_from_host, sticky_bad_cmd, sticky_overrun, (script_kind != SCRIPT_NONE), pending_valid, local_enable};
            4'h2: avs_csr_readdata = {29'd0, 1'b0, 1'b0, local_enable};
            4'h6: avs_csr_readdata = {gap_cycles, 16'h0};
            4'h7: avs_csr_readdata = sent_count;
            4'h8: avs_csr_readdata = {14'd0, last_sent_host_cmd, last_sent_from_host, last_sent_state};
            default: avs_csr_readdata = 32'h0;
        endcase

        if (!avs_csr_read) begin
            avs_csr_readdata = avs_csr_readdata;
        end
    end

endmodule
