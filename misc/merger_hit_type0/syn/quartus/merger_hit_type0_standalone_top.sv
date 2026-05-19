// merger_hit_type0_standalone_top.sv
// Thin standalone wrapper that flattens merger_hit_type0 entity ports to
// pins for Quartus standalone synthesis + STA sanity. No constraints other
// than the device-default 125 MHz clock.

`timescale 1ns/1ps

module merger_hit_type0_standalone_top (
    input  logic        clk_125mhz,
    input  logic        rst,

    input  logic [2:0]  csr_addr,
    input  logic        csr_read,
    input  logic        csr_write,
    input  logic [31:0] csr_writedata,
    output logic [31:0] csr_readdata,
    output logic        csr_waitrequest,

    input  logic [44:0] real_data,
    input  logic        real_valid,
    input  logic [3:0]  real_channel,
    input  logic [2:0]  real_error,
    input  logic        real_sop,
    input  logic        real_eop,
    input  logic        real_eor,

    input  logic [44:0] emu_data,
    input  logic        emu_valid,
    input  logic [3:0]  emu_channel,
    input  logic [2:0]  emu_error,
    input  logic        emu_sop,
    input  logic        emu_eop,
    input  logic        emu_eor,

    output logic [44:0] out_data,
    output logic        out_valid,
    output logic [3:0]  out_channel,
    output logic [2:0]  out_error,
    output logic        out_sop,
    output logic        out_eop,
    output logic        out_eor
);

    merger_hit_type0 #(
        .INSTANCE_ID(0),
        .SOURCE_SEL_DEFAULT(0)
    ) u_dut (
        .clk(clk_125mhz),
        .rst(rst),

        .avs_csr_address     (csr_addr),
        .avs_csr_read        (csr_read),
        .avs_csr_write       (csr_write),
        .avs_csr_writedata   (csr_writedata),
        .avs_csr_readdata    (csr_readdata),
        .avs_csr_waitrequest (csr_waitrequest),

        .asi_real_data           (real_data),
        .asi_real_valid          (real_valid),
        .asi_real_channel        (real_channel),
        .asi_real_error          (real_error),
        .asi_real_startofpacket  (real_sop),
        .asi_real_endofpacket    (real_eop),
        .asi_real_endofrun       (real_eor),

        .asi_emu_data            (emu_data),
        .asi_emu_valid           (emu_valid),
        .asi_emu_channel         (emu_channel),
        .asi_emu_error           (emu_error),
        .asi_emu_startofpacket   (emu_sop),
        .asi_emu_endofpacket     (emu_eop),
        .asi_emu_endofrun        (emu_eor),

        .aso_out_data           (out_data),
        .aso_out_valid          (out_valid),
        .aso_out_channel        (out_channel),
        .aso_out_error          (out_error),
        .aso_out_startofpacket  (out_sop),
        .aso_out_endofpacket    (out_eop),
        .aso_out_endofrun       (out_eor)
    );

endmodule
