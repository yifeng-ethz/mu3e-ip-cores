// arb_hit_type0_csr_profiled.sv
// Compile-time selector for the full and resource-trimmed CSR profiles.
//
// Version : 26.6.5
// Date    : 20260516
// Change  : Add COUNTER_PROFILE=1 trim3 CSR profile for standalone FEB
//           resource comparison and production integration.

module arb_hit_type0_csr_profiled #(
    parameter integer COUNTER_PROFILE  = 0,
    parameter integer MODE_DEFAULT     = 0,
    parameter integer WATCHDOG_DEFAULT = 500,
    parameter integer IP_UID           = 32'h41485430,
    parameter integer VERSION_MAJOR    = 26,
    parameter integer VERSION_MINOR    = 6,
    parameter integer VERSION_PATCH    = 5,
    parameter integer BUILD            = 518,
    parameter integer VERSION_DATE     = 20260516,
    parameter integer VERSION_GIT      = 32'h0000_0000,
    parameter integer INSTANCE_ID      = 0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        stream_clear,
    input  logic        counter_clear,

    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    output logic [1:0]  mode,
    output logic [15:0] watchdog_cycles,

    input  logic [2:0]  run_state,
    input  logic        mode_commit,

    input  logic        real_full,
    input  logic        real_empty,
    input  logic [4:0]  real_depth,
    input  logic        real_ingress_open,
    input  logic        real_source_open,
    input  logic [15:0] real_idle_cycles,

    input  logic        emu_full,
    input  logic        emu_empty,
    input  logic [4:0]  emu_depth,
    input  logic        emu_ingress_open,
    input  logic        emu_source_open,
    input  logic [15:0] emu_idle_cycles,

    input  logic        merged_open,
    input  logic        last_grant,

    input  logic        real_push_accept,
    input  logic        emu_push_accept,
    input  logic        real_push_drop,
    input  logic        emu_push_drop,
    input  logic        ingress_real_frame_pulse,
    input  logic        ingress_emu_frame_pulse,
    input  logic        egress_valid,
    input  logic        egress_source_emu,
    input  logic        egress_synthesized,
    input  logic        egress_real_frame_pulse,
    input  logic        egress_emu_frame_pulse,
    input  logic        protocol_event,
    input  logic [2:0]  selected_error,
    input  logic [3:0]  selected_channel,
    input  logic        selected_startofpacket,
    input  logic        selected_endofpacket,
    input  logic        watchdog_fire_real,
    input  logic        watchdog_fire_emu,

    input  logic [3:0]  asi_real_channel,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_emu_channel,
    input  logic [2:0]  asi_emu_error
);

    generate
        if (COUNTER_PROFILE == 0) begin : full_counter_profile
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
                .stream_clear              (stream_clear),
                .counter_clear             (counter_clear),
                .avs_csr_address           (avs_csr_address),
                .avs_csr_write             (avs_csr_write),
                .avs_csr_read              (avs_csr_read),
                .avs_csr_writedata         (avs_csr_writedata),
                .avs_csr_readdata          (avs_csr_readdata),
                .avs_csr_waitrequest       (avs_csr_waitrequest),
                .mode                      (mode),
                .watchdog_cycles           (watchdog_cycles),
                .run_state                 (run_state),
                .mode_commit               (mode_commit),
                .real_full                 (real_full),
                .real_empty                (real_empty),
                .real_depth                (real_depth),
                .real_ingress_open         (real_ingress_open),
                .real_source_open          (real_source_open),
                .real_idle_cycles          (real_idle_cycles),
                .emu_full                  (emu_full),
                .emu_empty                 (emu_empty),
                .emu_depth                 (emu_depth),
                .emu_ingress_open          (emu_ingress_open),
                .emu_source_open           (emu_source_open),
                .emu_idle_cycles           (emu_idle_cycles),
                .merged_open               (merged_open),
                .last_grant                (last_grant),
                .real_push_accept          (real_push_accept),
                .emu_push_accept           (emu_push_accept),
                .real_push_drop            (real_push_drop),
                .emu_push_drop             (emu_push_drop),
                .ingress_real_frame_pulse  (ingress_real_frame_pulse),
                .ingress_emu_frame_pulse   (ingress_emu_frame_pulse),
                .egress_valid              (egress_valid),
                .egress_source_emu         (egress_source_emu),
                .egress_synthesized        (egress_synthesized),
                .egress_real_frame_pulse   (egress_real_frame_pulse),
                .egress_emu_frame_pulse    (egress_emu_frame_pulse),
                .protocol_event            (protocol_event),
                .selected_error            (selected_error),
                .selected_channel          (selected_channel),
                .selected_startofpacket    (selected_startofpacket),
                .selected_endofpacket      (selected_endofpacket),
                .watchdog_fire_real        (watchdog_fire_real),
                .watchdog_fire_emu         (watchdog_fire_emu),
                .asi_real_channel          (asi_real_channel),
                .asi_real_error            (asi_real_error),
                .asi_emu_channel           (asi_emu_channel),
                .asi_emu_error             (asi_emu_error)
            );
        end else begin : trim3_counter_profile
            arb_hit_type0_csr_trim3 #(
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
                .stream_clear              (stream_clear),
                .counter_clear             (counter_clear),
                .avs_csr_address           (avs_csr_address),
                .avs_csr_write             (avs_csr_write),
                .avs_csr_read              (avs_csr_read),
                .avs_csr_writedata         (avs_csr_writedata),
                .avs_csr_readdata          (avs_csr_readdata),
                .avs_csr_waitrequest       (avs_csr_waitrequest),
                .mode                      (mode),
                .watchdog_cycles           (watchdog_cycles),
                .run_state                 (run_state),
                .mode_commit               (mode_commit),
                .real_full                 (real_full),
                .real_empty                (real_empty),
                .real_depth                (real_depth),
                .real_ingress_open         (real_ingress_open),
                .real_source_open          (real_source_open),
                .real_idle_cycles          (real_idle_cycles),
                .emu_full                  (emu_full),
                .emu_empty                 (emu_empty),
                .emu_depth                 (emu_depth),
                .emu_ingress_open          (emu_ingress_open),
                .emu_source_open           (emu_source_open),
                .emu_idle_cycles           (emu_idle_cycles),
                .merged_open               (merged_open),
                .last_grant                (last_grant),
                .real_push_accept          (real_push_accept),
                .emu_push_accept           (emu_push_accept),
                .real_push_drop            (real_push_drop),
                .emu_push_drop             (emu_push_drop),
                .ingress_real_frame_pulse  (ingress_real_frame_pulse),
                .ingress_emu_frame_pulse   (ingress_emu_frame_pulse),
                .egress_valid              (egress_valid),
                .egress_source_emu         (egress_source_emu),
                .egress_synthesized        (egress_synthesized),
                .egress_real_frame_pulse   (egress_real_frame_pulse),
                .egress_emu_frame_pulse    (egress_emu_frame_pulse),
                .protocol_event            (protocol_event),
                .selected_error            (selected_error),
                .selected_channel          (selected_channel),
                .selected_startofpacket    (selected_startofpacket),
                .selected_endofpacket      (selected_endofpacket),
                .watchdog_fire_real        (watchdog_fire_real),
                .watchdog_fire_emu         (watchdog_fire_emu),
                .asi_real_channel          (asi_real_channel),
                .asi_real_error            (asi_real_error),
                .asi_emu_channel           (asi_emu_channel),
                .asi_emu_error             (asi_emu_error)
            );
        end
    endgenerate

    // synthesis translate_off
    initial begin : csr_profile_guard
        if (!((COUNTER_PROFILE == 0) || (COUNTER_PROFILE == 1))) begin
            $error("arb_hit_type0_csr_profiled supports COUNTER_PROFILE=0 or 1");
        end
    end
    // synthesis translate_on

endmodule
