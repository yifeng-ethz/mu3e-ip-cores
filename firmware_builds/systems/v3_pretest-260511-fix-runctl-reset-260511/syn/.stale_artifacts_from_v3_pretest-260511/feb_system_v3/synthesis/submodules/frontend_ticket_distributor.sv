// frontend_ticket_distributor.sv
// Per-lane ticket ready/valid distributor for emulator_mutrig.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add signal/background ticket arbitration.

module frontend_ticket_distributor
    import frontend_ticket_bus_pkg::*;
#(
    parameter int LANE_COUNT = 8
) (
    input  logic             sig_offer_valid,
    input  logic [$clog2((LANE_COUNT > 1) ? LANE_COUNT : 2)-1:0] sig_offer_lane,
    input  frontend_ticket_t sig_offer_ticket,
    output logic             sig_offer_ready,

    input  logic             bkg_offer_valid,
    input  logic [$clog2((LANE_COUNT > 1) ? LANE_COUNT : 2)-1:0] bkg_offer_lane,
    input  frontend_ticket_t bkg_offer_ticket,
    output logic             bkg_offer_ready,

    output frontend_ticket_t fe_ticket_data [LANE_COUNT],
    output logic [LANE_COUNT-1:0] fe_ticket_valid,
    input  logic [LANE_COUNT-1:0] fe_ticket_ready
);

    always_comb begin
        sig_offer_ready = 1'b0;
        bkg_offer_ready = 1'b0;
        for (int lane_idx = 0; lane_idx < LANE_COUNT; lane_idx++) begin
            fe_ticket_data[lane_idx] = '0;
            fe_ticket_valid[lane_idx] = 1'b0;
        end

        if (sig_offer_valid && (int'(sig_offer_lane) < LANE_COUNT)) begin
            fe_ticket_data[sig_offer_lane] = sig_offer_ticket;
            fe_ticket_valid[sig_offer_lane] = 1'b1;
            sig_offer_ready = fe_ticket_ready[sig_offer_lane];
        end

        if (bkg_offer_valid && (int'(bkg_offer_lane) < LANE_COUNT)) begin
            if (!(sig_offer_valid && (sig_offer_lane == bkg_offer_lane))) begin
                fe_ticket_data[bkg_offer_lane] = bkg_offer_ticket;
                fe_ticket_valid[bkg_offer_lane] = 1'b1;
                bkg_offer_ready = fe_ticket_ready[bkg_offer_lane];
            end
        end
    end

endmodule
