module arb_hit_type0_assertions (
    input logic        clk,
    input logic        rst,
    input logic        aso_valid,
    input logic        aso_startofpacket,
    input logic        aso_endofpacket,
    input logic        aso_endofrun,
    input logic        real_open,
    input logic        emu_open,
    input logic        merged_open,
    input logic        merged_locked,
    input logic [1:0]  csr_mode,
    input logic [1:0]  csr_mode_pending,
    input logic        real_push_drop,
    input logic        emu_push_drop,
    input logic [63:0] drops_real,
    input logic [63:0] drops_emu,
    input logic        egress_valid,
    input logic        egress_source_emu,
    input logic        egress_synthesized,
    input logic [63:0] egress_real_hits,
    input logic [63:0] egress_emu_hits,
    input logic [63:0] ingress_real_frames,
    input logic [63:0] ingress_emu_frames,
    input logic [63:0] egress_real_frames,
    input logic [63:0] egress_emu_frames
);

    property merged_open_consistent_p;
        @(posedge clk) disable iff (rst)
        merged_open == (real_open | emu_open);
    endproperty

    property no_nested_merged_packet_p;
        @(posedge clk) disable iff (rst)
        (aso_valid && aso_startofpacket && !aso_endofpacket)
        |=> !(aso_valid && aso_startofpacket) until_with (aso_valid && aso_endofpacket);
    endproperty

    property mode_switch_deferred_p;
        @(posedge clk) disable iff (rst)
        (merged_open && (csr_mode != csr_mode_pending)) |=> (csr_mode == $past(csr_mode));
    endproperty

    property eor_final_lock_p;
        @(posedge clk) disable iff (rst)
        (aso_valid && aso_endofpacket && aso_endofrun) |=> (!aso_valid && merged_locked);
    endproperty

    property real_drop_accounting_p;
        @(posedge clk) disable iff (rst)
        (real_push_drop && (drops_real != 64'hFFFF_FFFF_FFFF_FFFF))
        |=> (drops_real >= ($past(drops_real) + 64'd1));
    endproperty

    property emu_drop_accounting_p;
        @(posedge clk) disable iff (rst)
        (emu_push_drop && (drops_emu != 64'hFFFF_FFFF_FFFF_FFFF))
        |=> (drops_emu >= ($past(drops_emu) + 64'd1));
    endproperty

    property egress_real_counter_coherence_p;
        @(posedge clk) disable iff (rst)
        (egress_valid && !egress_synthesized && !egress_source_emu &&
         (egress_real_hits != 64'hFFFF_FFFF_FFFF_FFFF))
        |=> (egress_real_hits >= ($past(egress_real_hits) + 64'd1));
    endproperty

    property egress_emu_counter_coherence_p;
        @(posedge clk) disable iff (rst)
        (egress_valid && !egress_synthesized && egress_source_emu &&
         (egress_emu_hits != 64'hFFFF_FFFF_FFFF_FFFF))
        |=> (egress_emu_hits >= ($past(egress_emu_hits) + 64'd1));
    endproperty

    property ingress_real_frames_cover_egress_real_frames_p;
        @(posedge clk) disable iff (rst)
        ingress_real_frames >= egress_real_frames;
    endproperty

    property ingress_emu_frames_cover_egress_emu_frames_p;
        @(posedge clk) disable iff (rst)
        ingress_emu_frames >= egress_emu_frames;
    endproperty

    assert property (merged_open_consistent_p)
        else $error("arb_hit_type0 merged_open inconsistent with source-open flags");

    assert property (no_nested_merged_packet_p)
        else $error("arb_hit_type0 emitted nested merged packet SOP");

    assert property (mode_switch_deferred_p)
        else $error("arb_hit_type0 mode changed while merged_open was asserted");

    assert property (eor_final_lock_p)
        else $error("arb_hit_type0 did not lock immediately after final EOR beat");

    assert property (real_drop_accounting_p)
        else $error("arb_hit_type0 real drop counter failed to advance");

    assert property (emu_drop_accounting_p)
        else $error("arb_hit_type0 emu drop counter failed to advance");

    assert property (egress_real_counter_coherence_p)
        else $error("arb_hit_type0 real egress counter failed to advance");

    assert property (egress_emu_counter_coherence_p)
        else $error("arb_hit_type0 emu egress counter failed to advance");

    assert property (ingress_real_frames_cover_egress_real_frames_p)
        else $error("arb_hit_type0 real frame counter egress exceeded ingress");

    assert property (ingress_emu_frames_cover_egress_emu_frames_p)
        else $error("arb_hit_type0 emu frame counter egress exceeded ingress");
endmodule

bind arb_hit_type0 arb_hit_type0_assertions u_arb_hit_type0_assertions (
    .clk                  (clk),
    .rst                  (rst),
    .aso_valid            (aso_valid),
    .aso_startofpacket    (aso_startofpacket),
    .aso_endofpacket      (aso_endofpacket),
    .aso_endofrun         (aso_endofrun),
    .real_open            (arbiter_real_open),
    .emu_open             (arbiter_emu_open),
    .merged_open          (arbiter_merged_open),
    .merged_locked        (arbiter_merged_locked),
    .csr_mode             (u_csr.csr.mode),
    .csr_mode_pending     (u_csr.csr.mode_pending),
    .real_push_drop       (real_push_drop),
    .emu_push_drop        (emu_push_drop),
    .drops_real           (u_csr.csr.drops_real),
    .drops_emu            (u_csr.csr.drops_emu),
    .egress_valid         (arbiter_egress_valid),
    .egress_source_emu    (arbiter_egress_source_emu),
    .egress_synthesized   (arbiter_egress_synthesized),
    .egress_real_hits     (u_csr.csr.egress_real_hits),
    .egress_emu_hits      (u_csr.csr.egress_emu_hits),
    .ingress_real_frames  (u_csr.csr.ingress_real_frames),
    .ingress_emu_frames   (u_csr.csr.ingress_emu_frames),
    .egress_real_frames   (u_csr.csr.egress_real_frames),
    .egress_emu_frames    (u_csr.csr.egress_emu_frames)
);
