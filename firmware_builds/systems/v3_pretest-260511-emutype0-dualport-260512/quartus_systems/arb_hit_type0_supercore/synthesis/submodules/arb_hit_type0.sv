// arb_hit_type0.sv
// Per-lane arbiter on the post-deassembly hit_type0 boundary. Selects
// between the real MuTRiG hit_type0 stream and the emulator hit_type0
// stream with 16-deep ingress FIFOs per source.
//
// Version : 26.6.0
// Date    : 20260512
// Change  : 26.4.1 (20260506) Preserve per-hit metadata valid through the
//                              selected DEBUG sideband.
//           26.5.0 (20260511) Drop run_ctrl ready output to match rc-network
//                              readyless contract. The original constant '1'
//                              driver inside arb_hit_type0_runctl.sv is no
//                              longer routed onto the entity boundary.
//           26.6.0 (20260512) Decouple stream_clear from RUN_PREPARING in the
//                              runctl submodule; MODE / sticky config now
//                              clear only on RUN_RESETTING. Fixes lane-admit
//                              asymmetry seen in on-board Phase 4.5 sweep
//                              (Qsys CSR/RC ordering race during run start).

module arb_hit_type0 #(
    parameter integer MODE_DEFAULT      = 0,            // 0=REAL, 1=EMU, 2=MIX_RR
    parameter integer FIFO_DEPTH        = 16,
    parameter integer DEBUG_LEVEL       = 0,            // 0=off, 1=FIFO levels, 2=hit metadata
    parameter integer WATCHDOG_DEFAULT  = 500,          // FAW threshold cycles, 0 disables
    parameter integer IP_UID            = 32'h41485430, // ASCII "AHT0"
    parameter integer VERSION_MAJOR     = 26,
    parameter integer VERSION_MINOR     = 6,
    parameter integer VERSION_PATCH     = 0,
    parameter integer BUILD             = 512,
    parameter integer VERSION_DATE      = 20260512,
    parameter integer VERSION_GIT       = 32'h0000_0000,
    parameter integer INSTANCE_ID       = 0
) (
    input  logic        clk,
    input  logic        rst,

    // AVMM CSR slave (5-bit word, 32-bit data, 1-cycle read latency)
    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    // Run-control sink (9-bit Avalon-ST, readyless broadcast: USE_READY=0)
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,

    // Real MuTRiG hit_type0 (post-deassembly); convention channel in [0..7]
    input  logic [44:0] asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,
    input  logic        asi_real_startofpacket,
    input  logic        asi_real_endofpacket,
    input  logic        asi_real_endofrun,

    // Emulator hit_type0 (BYTE_STREAM_ENABLE = 0); convention channel in [8..15]
    input  logic [44:0] asi_emu_data,
    input  logic        asi_emu_valid,
    input  logic [2:0]  asi_emu_error,
    input  logic [3:0]  asi_emu_channel,
    input  logic        asi_emu_startofpacket,
    input  logic        asi_emu_endofpacket,
    input  logic        asi_emu_endofrun,

    // Selected hit_type0 to downstream backpressure_fifo
    output logic [44:0] aso_data,
    output logic        aso_valid,
    output logic [2:0]  aso_error,
    output logic [3:0]  aso_channel,
    output logic        aso_startofpacket,
    output logic        aso_endofpacket,
    output logic        aso_endofrun,

    // Optional debug conduits. Tcl exposes these only when DEBUG_LEVEL enables them.
    output logic [4:0]  coe_debug_real_fifo_level,
    output logic [4:0]  coe_debug_emu_fifo_level,
    output logic [7:0]  coe_debug_fifo_flags,
    input  logic [63:0] coe_debug_real_hit_metadata,
    input  logic        coe_debug_real_hit_metadata_valid,
    input  logic [63:0] coe_debug_emu_hit_metadata,
    input  logic        coe_debug_emu_hit_metadata_valid,
    output logic [63:0] coe_debug_selected_hit_metadata,
    output logic        coe_debug_selected_hit_metadata_valid
);

    logic        runctl_reset_start;
    logic        runctl_stream_clear;
    logic        runctl_counter_clear;
    logic        runctl_reset_active;
    logic [2:0]  runctl_state;
    logic        stream_active;

    logic [1:0]  csr_mode;
    logic [15:0] csr_watchdog_cycles;

    logic        real_fifo_empty;
    logic        real_fifo_full;
    logic [4:0]  real_fifo_depth;
    logic        real_push_accept;
    logic        real_push_drop;
    logic        real_ingress_frame_pulse;
    logic        real_pop;
    logic        real_ingress_open;
    logic [15:0] real_idle_cycles;
    logic [3:0]  real_last_channel;
    logic [44:0] real_head_data;
    logic [2:0]  real_head_error;
    logic [3:0]  real_head_channel;
    logic        real_head_startofpacket;
    logic        real_head_endofpacket;
    logic        real_head_endofrun;
    logic [63:0] real_head_debug_metadata;
    logic        real_head_debug_metadata_valid;

    logic        emu_fifo_empty;
    logic        emu_fifo_full;
    logic [4:0]  emu_fifo_depth;
    logic        emu_push_accept;
    logic        emu_push_drop;
    logic        emu_ingress_frame_pulse;
    logic        emu_pop;
    logic        emu_ingress_open;
    logic [15:0] emu_idle_cycles;
    logic [3:0]  emu_last_channel;
    logic [44:0] emu_head_data;
    logic [2:0]  emu_head_error;
    logic [3:0]  emu_head_channel;
    logic        emu_head_startofpacket;
    logic        emu_head_endofpacket;
    logic        emu_head_endofrun;
    logic [63:0] emu_head_debug_metadata;
    logic        emu_head_debug_metadata_valid;

    logic        arbiter_real_open;
    logic        arbiter_emu_open;
    logic        arbiter_eor_seen_real;
    logic        arbiter_eor_seen_emu;
    logic        arbiter_merged_locked;
    logic        arbiter_last_grant;
    logic        arbiter_merged_open;
    logic        arbiter_mode_commit;
    logic        arbiter_egress_valid;
    logic        arbiter_egress_source_emu;
    logic        arbiter_egress_synthesized;
    logic [44:0] arbiter_egress_data;
    logic [2:0]  arbiter_egress_error;
    logic [3:0]  arbiter_egress_channel;
    logic        arbiter_egress_startofpacket;
    logic        arbiter_egress_endofpacket;
    logic        arbiter_egress_endofrun;
    logic        arbiter_egress_real_frame_pulse;
    logic        arbiter_egress_emu_frame_pulse;
    logic        arbiter_protocol_event;
    logic [2:0]  arbiter_selected_error;
    logic [3:0]  arbiter_selected_channel;
    logic        arbiter_selected_startofpacket;
    logic        arbiter_selected_endofpacket;

    logic        watchdog_fire_real;
    logic        watchdog_fire_emu;
    logic [63:0] debug_selected_hit_metadata;
    logic        debug_selected_hit_metadata_valid;

    assign stream_active = ~(runctl_reset_active | runctl_reset_start);
    assign debug_selected_hit_metadata =
        (arbiter_egress_valid & ~arbiter_egress_synthesized) ?
            (arbiter_egress_source_emu ? emu_head_debug_metadata : real_head_debug_metadata) :
            64'd0;
    assign debug_selected_hit_metadata_valid =
        (arbiter_egress_valid & ~arbiter_egress_synthesized) ?
            (arbiter_egress_source_emu ?
                emu_head_debug_metadata_valid : real_head_debug_metadata_valid) :
            1'b0;

    generate
        if (DEBUG_LEVEL >= 1) begin : debug_fifo_observability
            assign coe_debug_real_fifo_level = real_fifo_depth;
            assign coe_debug_emu_fifo_level  = emu_fifo_depth;
            assign coe_debug_fifo_flags      = {
                emu_pop,
                emu_push_accept,
                real_pop,
                real_push_accept,
                emu_fifo_full,
                emu_fifo_empty,
                real_fifo_full,
                real_fifo_empty
            };
        end else begin : no_debug_fifo_observability
            assign coe_debug_real_fifo_level = 5'd0;
            assign coe_debug_emu_fifo_level  = 5'd0;
            assign coe_debug_fifo_flags      = 8'd0;
        end
    endgenerate

    arb_hit_type0_runctl u_runctl (
        .clk                   (clk),
        .rst                   (rst),
        .asi_ctrl_data         (asi_ctrl_data),
        .asi_ctrl_valid        (asi_ctrl_valid),
        .reset_start           (runctl_reset_start),
        .stream_clear          (runctl_stream_clear),
        .counter_clear         (runctl_counter_clear),
        .reset_active          (runctl_reset_active),
        .run_state             (runctl_state)
    );

    arb_hit_type0_fifo #(
        .FIFO_DEPTH            (FIFO_DEPTH),
        .DEBUG_LEVEL           (DEBUG_LEVEL)
    ) u_real_fifo (
        .clk                   (clk),
        .rst                   (rst),
        .stream_clear          (runctl_stream_clear),
        .stream_active         (stream_active),
        .asi_data              (asi_real_data),
        .asi_valid             (asi_real_valid),
        .asi_error             (asi_real_error),
        .asi_channel           (asi_real_channel),
        .asi_startofpacket     (asi_real_startofpacket),
        .asi_endofpacket       (asi_real_endofpacket),
        .asi_endofrun          (asi_real_endofrun),
        .asi_debug_metadata        (coe_debug_real_hit_metadata),
        .asi_debug_metadata_valid  (coe_debug_real_hit_metadata_valid),
        .pop                   (real_pop),
        .head_data             (real_head_data),
        .head_error            (real_head_error),
        .head_channel          (real_head_channel),
        .head_startofpacket    (real_head_startofpacket),
        .head_endofpacket      (real_head_endofpacket),
        .head_endofrun         (real_head_endofrun),
        .head_debug_metadata   (real_head_debug_metadata),
        .head_debug_metadata_valid (real_head_debug_metadata_valid),
        .empty                 (real_fifo_empty),
        .full                  (real_fifo_full),
        .depth                 (real_fifo_depth),
        .push_accept           (real_push_accept),
        .push_drop             (real_push_drop),
        .ingress_frame_pulse   (real_ingress_frame_pulse),
        .ingress_open          (real_ingress_open),
        .idle_cycles           (real_idle_cycles),
        .last_channel          (real_last_channel)
    );

    arb_hit_type0_fifo #(
        .FIFO_DEPTH            (FIFO_DEPTH),
        .DEBUG_LEVEL           (DEBUG_LEVEL)
    ) u_emu_fifo (
        .clk                   (clk),
        .rst                   (rst),
        .stream_clear          (runctl_stream_clear),
        .stream_active         (stream_active),
        .asi_data              (asi_emu_data),
        .asi_valid             (asi_emu_valid),
        .asi_error             (asi_emu_error),
        .asi_channel           (asi_emu_channel),
        .asi_startofpacket     (asi_emu_startofpacket),
        .asi_endofpacket       (asi_emu_endofpacket),
        .asi_endofrun          (asi_emu_endofrun),
        .asi_debug_metadata        (coe_debug_emu_hit_metadata),
        .asi_debug_metadata_valid  (coe_debug_emu_hit_metadata_valid),
        .pop                   (emu_pop),
        .head_data             (emu_head_data),
        .head_error            (emu_head_error),
        .head_channel          (emu_head_channel),
        .head_startofpacket    (emu_head_startofpacket),
        .head_endofpacket      (emu_head_endofpacket),
        .head_endofrun         (emu_head_endofrun),
        .head_debug_metadata   (emu_head_debug_metadata),
        .head_debug_metadata_valid (emu_head_debug_metadata_valid),
        .empty                 (emu_fifo_empty),
        .full                  (emu_fifo_full),
        .depth                 (emu_fifo_depth),
        .push_accept           (emu_push_accept),
        .push_drop             (emu_push_drop),
        .ingress_frame_pulse   (emu_ingress_frame_pulse),
        .ingress_open          (emu_ingress_open),
        .idle_cycles           (emu_idle_cycles),
        .last_channel          (emu_last_channel)
    );

    arb_hit_type0_watchdog u_watchdog (
        .watchdog_cycles       (csr_watchdog_cycles),
        .grant_enable          (stream_active),
        .real_open             (arbiter_real_open),
        .emu_open              (arbiter_emu_open),
        .eor_seen_real         (arbiter_eor_seen_real),
        .eor_seen_emu          (arbiter_eor_seen_emu),
        .merged_locked         (arbiter_merged_locked),
        .idle_cycles_real      (real_idle_cycles),
        .idle_cycles_emu       (emu_idle_cycles),
        .fire_real             (watchdog_fire_real),
        .fire_emu              (watchdog_fire_emu)
    );

    arb_hit_type0_arbiter u_arbiter (
        .clk                       (clk),
        .rst                       (rst),
        .stream_clear              (runctl_stream_clear),
        .grant_enable              (stream_active),
        .mode                      (csr_mode),
        .real_empty                (real_fifo_empty),
        .real_head_data            (real_head_data),
        .real_head_error           (real_head_error),
        .real_head_channel         (real_head_channel),
        .real_head_startofpacket   (real_head_startofpacket),
        .real_head_endofpacket     (real_head_endofpacket),
        .real_head_endofrun        (real_head_endofrun),
        .emu_empty                 (emu_fifo_empty),
        .emu_head_data             (emu_head_data),
        .emu_head_error            (emu_head_error),
        .emu_head_channel          (emu_head_channel),
        .emu_head_startofpacket    (emu_head_startofpacket),
        .emu_head_endofpacket      (emu_head_endofpacket),
        .emu_head_endofrun         (emu_head_endofrun),
        .last_channel_real         (real_last_channel),
        .last_channel_emu          (emu_last_channel),
        .watchdog_fire_real        (watchdog_fire_real),
        .watchdog_fire_emu         (watchdog_fire_emu),
        .real_pop                  (real_pop),
        .emu_pop                   (emu_pop),
        .real_open                 (arbiter_real_open),
        .emu_open                  (arbiter_emu_open),
        .eor_seen_real             (arbiter_eor_seen_real),
        .eor_seen_emu              (arbiter_eor_seen_emu),
        .merged_locked             (arbiter_merged_locked),
        .last_grant                (arbiter_last_grant),
        .merged_open               (arbiter_merged_open),
        .mode_commit               (arbiter_mode_commit),
        .egress_valid              (arbiter_egress_valid),
        .egress_source_emu         (arbiter_egress_source_emu),
        .egress_synthesized        (arbiter_egress_synthesized),
        .egress_data               (arbiter_egress_data),
        .egress_error              (arbiter_egress_error),
        .egress_channel            (arbiter_egress_channel),
        .egress_startofpacket      (arbiter_egress_startofpacket),
        .egress_endofpacket        (arbiter_egress_endofpacket),
        .egress_endofrun           (arbiter_egress_endofrun),
        .egress_real_frame_pulse   (arbiter_egress_real_frame_pulse),
        .egress_emu_frame_pulse    (arbiter_egress_emu_frame_pulse),
        .protocol_event            (arbiter_protocol_event),
        .selected_error            (arbiter_selected_error),
        .selected_channel          (arbiter_selected_channel),
        .selected_startofpacket    (arbiter_selected_startofpacket),
        .selected_endofpacket      (arbiter_selected_endofpacket)
    );

    arb_hit_type0_csr #(
        .MODE_DEFAULT          (MODE_DEFAULT),
        .WATCHDOG_DEFAULT      (WATCHDOG_DEFAULT),
        .IP_UID                (IP_UID),
        .VERSION_MAJOR         (VERSION_MAJOR),
        .VERSION_MINOR         (VERSION_MINOR),
        .VERSION_PATCH         (VERSION_PATCH),
        .BUILD                 (BUILD),
        .VERSION_DATE          (VERSION_DATE),
        .VERSION_GIT           (VERSION_GIT),
        .INSTANCE_ID           (INSTANCE_ID)
    ) u_csr (
        .clk                       (clk),
        .rst                       (rst),
        .stream_clear              (runctl_stream_clear),
        .counter_clear             (runctl_counter_clear),
        .avs_csr_address           (avs_csr_address),
        .avs_csr_write             (avs_csr_write),
        .avs_csr_read              (avs_csr_read),
        .avs_csr_writedata         (avs_csr_writedata),
        .avs_csr_readdata          (avs_csr_readdata),
        .avs_csr_waitrequest       (avs_csr_waitrequest),
        .mode                      (csr_mode),
        .watchdog_cycles           (csr_watchdog_cycles),
        .run_state                 (runctl_state),
        .mode_commit               (arbiter_mode_commit),
        .real_full                 (real_fifo_full),
        .real_empty                (real_fifo_empty),
        .real_depth                (real_fifo_depth),
        .real_ingress_open         (real_ingress_open),
        .real_source_open          (arbiter_real_open),
        .real_idle_cycles          (real_idle_cycles),
        .emu_full                  (emu_fifo_full),
        .emu_empty                 (emu_fifo_empty),
        .emu_depth                 (emu_fifo_depth),
        .emu_ingress_open          (emu_ingress_open),
        .emu_source_open           (arbiter_emu_open),
        .emu_idle_cycles           (emu_idle_cycles),
        .merged_open               (arbiter_merged_open),
        .last_grant                (arbiter_last_grant),
        .real_push_accept          (real_push_accept),
        .emu_push_accept           (emu_push_accept),
        .real_push_drop            (real_push_drop),
        .emu_push_drop             (emu_push_drop),
        .ingress_real_frame_pulse  (real_ingress_frame_pulse),
        .ingress_emu_frame_pulse   (emu_ingress_frame_pulse),
        .egress_valid              (arbiter_egress_valid),
        .egress_source_emu         (arbiter_egress_source_emu),
        .egress_synthesized        (arbiter_egress_synthesized),
        .egress_real_frame_pulse   (arbiter_egress_real_frame_pulse),
        .egress_emu_frame_pulse    (arbiter_egress_emu_frame_pulse),
        .protocol_event            (arbiter_protocol_event),
        .selected_error            (arbiter_selected_error),
        .selected_channel          (arbiter_selected_channel),
        .selected_startofpacket    (arbiter_selected_startofpacket),
        .selected_endofpacket      (arbiter_selected_endofpacket),
        .watchdog_fire_real        (watchdog_fire_real),
        .watchdog_fire_emu         (watchdog_fire_emu),
        .asi_real_channel          (asi_real_channel),
        .asi_real_error            (asi_real_error),
        .asi_emu_channel           (asi_emu_channel),
        .asi_emu_error             (asi_emu_error)
    );

    always_ff @(posedge clk or posedge rst) begin : egress_register
        if (rst) begin
            aso_data             <= 45'd0;
            aso_error            <= 3'd0;
            aso_channel          <= 4'd0;
            aso_valid            <= 1'b0;
            aso_startofpacket    <= 1'b0;
            aso_endofpacket      <= 1'b0;
            aso_endofrun         <= 1'b0;
        end else if (runctl_stream_clear) begin
            aso_data             <= 45'd0;
            aso_error            <= 3'd0;
            aso_channel          <= 4'd0;
            aso_valid            <= 1'b0;
            aso_startofpacket    <= 1'b0;
            aso_endofpacket      <= 1'b0;
            aso_endofrun         <= 1'b0;
        end else begin
            aso_data             <= arbiter_egress_data;
            aso_error            <= arbiter_egress_error;
            aso_channel          <= arbiter_egress_channel;
            aso_valid            <= arbiter_egress_valid;
            aso_startofpacket    <= arbiter_egress_startofpacket;
            aso_endofpacket      <= arbiter_egress_endofpacket;
            aso_endofrun         <= arbiter_egress_endofrun;
        end
    end

    generate
        if (DEBUG_LEVEL >= 2) begin : debug_hit_metadata_export
            always_ff @(posedge clk or posedge rst) begin : debug_hit_metadata_register
                if (rst) begin
                    coe_debug_selected_hit_metadata          <= 64'd0;
                    coe_debug_selected_hit_metadata_valid    <= 1'b0;
                end else if (runctl_stream_clear) begin
                    coe_debug_selected_hit_metadata          <= 64'd0;
                    coe_debug_selected_hit_metadata_valid    <= 1'b0;
                end else begin
                    coe_debug_selected_hit_metadata          <= debug_selected_hit_metadata;
                    coe_debug_selected_hit_metadata_valid    <=
                        debug_selected_hit_metadata_valid;
                end
            end
        end else begin : no_debug_hit_metadata_export
            assign coe_debug_selected_hit_metadata       = 64'd0;
            assign coe_debug_selected_hit_metadata_valid = 1'b0;
        end
    endgenerate

    // synthesis translate_off
    initial begin : debug_parameter_guard
        if ((DEBUG_LEVEL < 0) || (DEBUG_LEVEL > 2)) begin
            $error("arb_hit_type0 supports DEBUG_LEVEL in the range 0..2");
        end
    end
    // synthesis translate_on

endmodule
