// merger_hit_type0.sv
// Per-lane readyless 2:1 mux between the real MuTRiG hit_type0 stream
// (post mutrig_frame_deassembly) and the emulator hit_type0 stream.
//
// FEB SciFi v4 design intent (2026-05-19):
//   - Real path:   mutrig_datapath_subsystem.hit_type0_out (one per ASIC lane)
//                  carries the decoded Type0 hit with ASIC field already set
//                  to the physical lane id (no remap on FEB).
//   - Emulator:    a per-lane stream that also carries ASIC = lane id.
//   - Merger:      runtime CSR-selectable forward of either source.
//
// The merger is intentionally minimal: ONE control bit (CONTROL.source_sel)
// picks REAL (0) or EMU (1). No FIFOs, no watchdog, no MIX. The Avalon-ST
// channel field is forwarded verbatim and is the authoritative ASIC ID for
// downstream (histogram, hit_stack, etc.). All streaming ports are readyless
// per the FEB hit_type0 plane convention so Platform Designer does not insert
// timing_adapter / channel_adapter wrappers on this path.
//
// Replaces the 8-way emulator_hit_type0_fanout broadcast pattern that was
// the root cause of FEB BUG-028-I (per-lane emulator broadcast collisions
// at hist ingress).
//
// CSR map (32-bit words, 3-bit address):
//   word 0 : UID         (read-only, 0x4D484754 = "MHGT" Merger Hit type Gen Type0)
//   word 1 : VERSION     ({MAJOR[8], MINOR[8], PATCH[4], BUILD[12]})
//   word 2 : VERSION_DATE
//   word 3 : CONTROL     (bit  0 : source_sel, 0=REAL 1=EMU)
//                       (bit 31 : reserved)

`timescale 1ns/1ps

module merger_hit_type0 #(
    parameter integer DATA_WIDTH    = 45,
    parameter integer CHANNEL_WIDTH = 4,
    parameter integer ERROR_WIDTH   = 3,
    parameter integer VERSION_MAJOR = 26,
    parameter integer VERSION_MINOR = 0,
    parameter integer VERSION_PATCH = 0,
    parameter integer BUILD         = 519,
    parameter integer VERSION_DATE  = 20260519,
    parameter integer IP_UID        = 32'h4D484754,
    parameter integer INSTANCE_ID   = 0,
    parameter integer SOURCE_SEL_DEFAULT = 0  // 0=REAL, 1=EMU at reset
) (
    input  logic                     clk,
    input  logic                     rst,

    // CSR (Avalon-MM slave, 4 words)
    input  logic [2:0]               avs_csr_address,
    input  logic                     avs_csr_read,
    input  logic                     avs_csr_write,
    input  logic [31:0]              avs_csr_writedata,
    output logic [31:0]              avs_csr_readdata,
    output logic                     avs_csr_waitrequest,

    // real_in: readyless Avalon-ST sink (post mutrig_frame_deassembly)
    input  logic [DATA_WIDTH-1:0]    asi_real_data,
    input  logic                     asi_real_valid,
    input  logic [CHANNEL_WIDTH-1:0] asi_real_channel,
    input  logic [ERROR_WIDTH-1:0]   asi_real_error,
    input  logic                     asi_real_startofpacket,
    input  logic                     asi_real_endofpacket,
    input  logic                     asi_real_endofrun,

    // emu_in: readyless Avalon-ST sink (from emulator_mutrig hit_type0)
    input  logic [DATA_WIDTH-1:0]    asi_emu_data,
    input  logic                     asi_emu_valid,
    input  logic [CHANNEL_WIDTH-1:0] asi_emu_channel,
    input  logic [ERROR_WIDTH-1:0]   asi_emu_error,
    input  logic                     asi_emu_startofpacket,
    input  logic                     asi_emu_endofpacket,
    input  logic                     asi_emu_endofrun,

    // out: readyless Avalon-ST source
    output logic [DATA_WIDTH-1:0]    aso_out_data,
    output logic                     aso_out_valid,
    output logic [CHANNEL_WIDTH-1:0] aso_out_channel,
    output logic [ERROR_WIDTH-1:0]   aso_out_error,
    output logic                     aso_out_startofpacket,
    output logic                     aso_out_endofpacket,
    output logic                     aso_out_endofrun
);

    localparam logic [7:0]  VERSION_MAJOR_BYTE = VERSION_MAJOR[7:0];
    localparam logic [7:0]  VERSION_MINOR_BYTE = VERSION_MINOR[7:0];
    localparam logic [3:0]  VERSION_PATCH_NIBBLE = VERSION_PATCH[3:0];
    localparam logic [11:0] BUILD_FIELD          = BUILD[11:0];

    localparam logic [31:0] VERSION_WORD =
        {VERSION_MAJOR_BYTE, VERSION_MINOR_BYTE, VERSION_PATCH_NIBBLE, BUILD_FIELD};

    // ----------------------------------------------------------------
    // CSR
    // ----------------------------------------------------------------
    logic [31:0] csr_control;
    logic        cfg_source_is_emu;

    assign avs_csr_waitrequest = 1'b0;
    assign cfg_source_is_emu   = csr_control[0];

    always_ff @(posedge clk or posedge rst) begin : csr_regs
        if (rst) begin
            csr_control <= 32'h0;
            csr_control[0] <= SOURCE_SEL_DEFAULT[0];
        end else if (avs_csr_write && avs_csr_address == 3'd3) begin
            csr_control <= avs_csr_writedata;
        end
    end

    always_comb begin : csr_read_mux
        unique case (avs_csr_address)
            3'd0:    avs_csr_readdata = IP_UID;
            3'd1:    avs_csr_readdata = VERSION_WORD;
            3'd2:    avs_csr_readdata = VERSION_DATE;
            3'd3:    avs_csr_readdata = csr_control;
            default: avs_csr_readdata = 32'h0;
        endcase
    end

    // ----------------------------------------------------------------
    // Datapath: purely combinational 2:1 readyless mux
    // ----------------------------------------------------------------
    always_comb begin : route_hit_type0
        if (cfg_source_is_emu) begin
            aso_out_data          = asi_emu_data;
            aso_out_valid         = asi_emu_valid;
            aso_out_channel       = asi_emu_channel;
            aso_out_error         = asi_emu_error;
            aso_out_startofpacket = asi_emu_startofpacket;
            aso_out_endofpacket   = asi_emu_endofpacket;
            aso_out_endofrun      = asi_emu_endofrun;
        end else begin
            aso_out_data          = asi_real_data;
            aso_out_valid         = asi_real_valid;
            aso_out_channel       = asi_real_channel;
            aso_out_error         = asi_real_error;
            aso_out_startofpacket = asi_real_startofpacket;
            aso_out_endofpacket   = asi_real_endofpacket;
            aso_out_endofrun      = asi_real_endofrun;
        end
    end

    // synthesis translate_off
    initial begin : parameter_guard
        if (DATA_WIDTH != 45 || CHANNEL_WIDTH != 4 || ERROR_WIDTH != 3) begin
            $error("merger_hit_type0 only supports the FEB hit_type0 stream profile (DATA=45, CH=4, ERR=3)");
        end
    end
    // synthesis translate_on

endmodule
