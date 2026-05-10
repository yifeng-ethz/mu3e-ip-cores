// arb_hit_type0_runctl.sv
// 9-bit Avalon-ST run-control sink and staged reset orchestrator.
//
// Version : 26.2.0
// Date    : 20260504
// Change  : Register counter clear from the staged reset controller.

module arb_hit_type0_runctl (
    input  logic       clk,
    input  logic       rst,

    input  logic [8:0] asi_ctrl_data,
    input  logic       asi_ctrl_valid,
    output logic       asi_ctrl_ready,

    output logic       reset_start,
    output logic       stream_clear,
    output logic       counter_clear,
    output logic       reset_active,
    output logic [2:0] run_state
);

    localparam logic [2:0] RUN_IDLE_CONST             = 3'd0;
    localparam logic [2:0] RUN_PREPARING_CONST        = 3'd1;
    localparam logic [2:0] RUN_SYNCING_CONST          = 3'd2;
    localparam logic [2:0] RUN_RUNNING_CONST          = 3'd3;
    localparam logic [2:0] RUN_TERMINATING_CONST      = 3'd4;
    localparam logic [2:0] RUN_RESETTING_CONST        = 3'd5;
    localparam logic [2:0] RUN_TESTING_CONST          = 3'd6;
    localparam logic [2:0] RUN_OUT_OF_DAQ_CONST       = 3'd7;

    localparam logic [1:0] RESET_STAGE_IDLE_CONST     = 2'd0;
    localparam logic [1:0] RESET_STAGE_COUNTERS_CONST = 2'd1;
    localparam logic [1:0] RESET_STAGE_FINISH_CONST   = 2'd2;

    logic       reset_counters;
    logic [1:0] reset_stage;

    function automatic logic [2:0] decode_run_state(input logic [8:0] ctrl_word);
        if (ctrl_word[7]) begin
            decode_run_state = RUN_RESETTING_CONST;
        end else if (ctrl_word[1]) begin
            decode_run_state = RUN_PREPARING_CONST;
        end else if (ctrl_word[2]) begin
            decode_run_state = RUN_SYNCING_CONST;
        end else if (ctrl_word[3]) begin
            decode_run_state = RUN_RUNNING_CONST;
        end else if (ctrl_word[4]) begin
            decode_run_state = RUN_TERMINATING_CONST;
        end else if (ctrl_word[8]) begin
            decode_run_state = RUN_OUT_OF_DAQ_CONST;
        end else if (ctrl_word[5] | ctrl_word[6]) begin
            decode_run_state = RUN_TESTING_CONST;
        end else begin
            decode_run_state = RUN_IDLE_CONST;
        end
    endfunction

    assign asi_ctrl_ready = 1'b1;
    assign reset_start    = asi_ctrl_valid & (asi_ctrl_data[1] | asi_ctrl_data[7]) & ~reset_active;
    assign stream_clear   = reset_start;
    always_ff @(posedge clk or posedge rst) begin : runctl_state
        if (rst) begin
            run_state         <= RUN_IDLE_CONST;
            reset_active      <= 1'b0;
            reset_counters    <= 1'b0;
            reset_stage       <= RESET_STAGE_IDLE_CONST;
            counter_clear     <= 1'b0;
        end else if (reset_active) begin
            counter_clear     <= 1'b0;
            if (reset_stage == RESET_STAGE_COUNTERS_CONST) begin
                reset_stage       <= RESET_STAGE_FINISH_CONST;
            end else begin
                reset_active      <= 1'b0;
                reset_counters    <= 1'b0;
                reset_stage       <= RESET_STAGE_IDLE_CONST;
            end
        end else if (reset_start) begin
            run_state         <= decode_run_state(asi_ctrl_data);
            reset_active      <= 1'b1;
            reset_counters    <= asi_ctrl_data[7];
            reset_stage       <= RESET_STAGE_COUNTERS_CONST;
            counter_clear     <= asi_ctrl_data[7];
        end else if (asi_ctrl_valid) begin
            counter_clear     <= 1'b0;
            run_state <= decode_run_state(asi_ctrl_data);
        end else begin
            counter_clear     <= 1'b0;
        end
    end

endmodule
