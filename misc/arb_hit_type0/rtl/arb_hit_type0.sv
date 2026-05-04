// arb_hit_type0.sv
// Per-lane arbiter on the post-deassembly hit_type0 boundary. Selects between
// the real MuTRiG hit_type0 stream and the emulator hit_type0 stream with
// 16-deep ingress FIFOs per source and a packet-boundary round-robin
// arbiter. See doc/RTL_PLAN.md for the full architecture and tb/DV_PLAN.md
// for the verification contract.
//
// Implementation status: signature is frozen by RTL_PLAN.md and DV_PLAN.md;
// body is delegated to codex via the dv-workflow + rtl-writing skills once
// the design is approved (see misc/arb_hit_type0/tb/DV_BASIC.md, DV_EDGE.md,
// DV_PROF.md, DV_ERROR.md, DV_CROSS.md).
//
// Version : 26.2.0
// Date    : 20260504

module arb_hit_type0 #(
    parameter integer MODE_DEFAULT    = 0,            // 0=REAL, 1=EMU, 2=MIX_RR
    parameter integer FIFO_DEPTH      = 16,
    parameter integer IP_UID          = 32'h41485430, // ASCII "AHT0"
    parameter integer VERSION_MAJOR   = 26,
    parameter integer VERSION_MINOR   = 2,
    parameter integer VERSION_PATCH   = 0,
    parameter integer BUILD           = 504,
    parameter integer VERSION_DATE    = 20260504,
    parameter integer VERSION_GIT     = 32'h0000_0000,
    parameter integer INSTANCE_ID     = 0
) (
    input  logic        clk,
    input  logic        rst,

    // AVMM CSR slave (4-bit word, 32-bit data, 1-cycle read latency)
    input  logic [3:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    // Real MuTRiG hit_type0 (post-deassembly)
    input  logic [44:0] asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,
    input  logic        asi_real_startofpacket,
    input  logic        asi_real_endofpacket,
    input  logic        asi_real_endofrun,

    // Emulator hit_type0 (BYTE_STREAM_ENABLE = 0 path)
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
    output logic        aso_endofrun
);

    // -------------------------------------------------------------------
    // Body to be implemented by codex against:
    //   - misc/arb_hit_type0/doc/RTL_PLAN.md   (architecture)
    //   - misc/arb_hit_type0/tb/DV_PLAN.md     (verification contract)
    //   - misc/arb_hit_type0/tb/DV_HARNESS.md  (UVM harness)
    // The placeholder below keeps elaboration clean and steers the IP into
    // a known-quiescent state until the implementation lands.
    // -------------------------------------------------------------------

    assign avs_csr_readdata    = (avs_csr_address == 4'h0) ? IP_UID : 32'h0;
    assign avs_csr_waitrequest = 1'b0;

    assign aso_data          = '0;
    assign aso_valid         = 1'b0;
    assign aso_error         = 3'b000;
    assign aso_channel       = 4'h0;
    assign aso_startofpacket = 1'b0;
    assign aso_endofpacket   = 1'b0;
    assign aso_endofrun      = 1'b0;

    // synthesis translate_off
    initial begin
        $display("[arb_hit_type0] WARNING: stub body. RTL implementation pending against doc/RTL_PLAN.md.");
    end
    // synthesis translate_on

endmodule
