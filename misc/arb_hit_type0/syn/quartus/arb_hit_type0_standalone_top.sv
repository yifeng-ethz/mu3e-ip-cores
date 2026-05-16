// arb_hit_type0_standalone_top.sv
// Pin-level standalone synthesis wrapper for resource profile comparison.
//
// Version : 26.6.5
// Date    : 20260516
// Change  : Add full-vs-trim3 synthesis tops for Arria V standalone fits.

module arb_hit_type0_standalone_top #(
    parameter integer FIFO_DEPTH      = 16,
    parameter integer COUNTER_PROFILE = 0
) (
    input  logic        clk,
    input  logic        rst,

    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,

    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,

    input  logic [44:0] asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,
    input  logic        asi_real_startofpacket,
    input  logic        asi_real_endofpacket,
    input  logic        asi_real_endofrun,

    input  logic [44:0] asi_emu_data,
    input  logic        asi_emu_valid,
    input  logic [2:0]  asi_emu_error,
    input  logic [3:0]  asi_emu_channel,
    input  logic        asi_emu_startofpacket,
    input  logic        asi_emu_endofpacket,
    input  logic        asi_emu_endofrun,

    output logic [44:0] aso_data,
    output logic        aso_valid,
    output logic [2:0]  aso_error,
    output logic [3:0]  aso_channel,
    output logic        aso_startofpacket,
    output logic        aso_endofpacket,
    output logic        aso_endofrun
);

    arb_hit_type0 #(
        .MODE_DEFAULT       (1),
        .FIFO_DEPTH         (FIFO_DEPTH),
        .COUNTER_PROFILE    (COUNTER_PROFILE),
        .DEBUG_LEVEL        (0),
        .WATCHDOG_DEFAULT   (500),
        .VERSION_PATCH      (5)
    ) u_dut (
        .clk                                (clk),
        .rst                                (rst),
        .avs_csr_address                    (avs_csr_address),
        .avs_csr_write                      (avs_csr_write),
        .avs_csr_read                       (avs_csr_read),
        .avs_csr_writedata                  (avs_csr_writedata),
        .avs_csr_readdata                   (avs_csr_readdata),
        .avs_csr_waitrequest                (avs_csr_waitrequest),
        .asi_ctrl_data                      (asi_ctrl_data),
        .asi_ctrl_valid                     (asi_ctrl_valid),
        .asi_real_data                      (asi_real_data),
        .asi_real_valid                     (asi_real_valid),
        .asi_real_error                     (asi_real_error),
        .asi_real_channel                   (asi_real_channel),
        .asi_real_startofpacket             (asi_real_startofpacket),
        .asi_real_endofpacket               (asi_real_endofpacket),
        .asi_real_endofrun                  (asi_real_endofrun),
        .asi_emu_data                       (asi_emu_data),
        .asi_emu_valid                      (asi_emu_valid),
        .asi_emu_error                      (asi_emu_error),
        .asi_emu_channel                    (asi_emu_channel),
        .asi_emu_startofpacket              (asi_emu_startofpacket),
        .asi_emu_endofpacket                (asi_emu_endofpacket),
        .asi_emu_endofrun                   (asi_emu_endofrun),
        .aso_data                           (aso_data),
        .aso_valid                          (aso_valid),
        .aso_error                          (aso_error),
        .aso_channel                        (aso_channel),
        .aso_startofpacket                  (aso_startofpacket),
        .aso_endofpacket                    (aso_endofpacket),
        .aso_endofrun                       (aso_endofrun),
        .coe_debug_real_fifo_level          (),
        .coe_debug_emu_fifo_level           (),
        .coe_debug_fifo_flags               (),
        .coe_debug_real_hit_metadata        (64'd0),
        .coe_debug_real_hit_metadata_valid  (1'b0),
        .coe_debug_emu_hit_metadata         (64'd0),
        .coe_debug_emu_hit_metadata_valid   (1'b0),
        .coe_debug_selected_hit_metadata    (),
        .coe_debug_selected_hit_metadata_valid ()
    );

endmodule

module arb_hit_type0_standalone_full16_top (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    input  logic [44:0] asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,
    input  logic        asi_real_startofpacket,
    input  logic        asi_real_endofpacket,
    input  logic        asi_real_endofrun,
    input  logic [44:0] asi_emu_data,
    input  logic        asi_emu_valid,
    input  logic [2:0]  asi_emu_error,
    input  logic [3:0]  asi_emu_channel,
    input  logic        asi_emu_startofpacket,
    input  logic        asi_emu_endofpacket,
    input  logic        asi_emu_endofrun,
    output logic [44:0] aso_data,
    output logic        aso_valid,
    output logic [2:0]  aso_error,
    output logic [3:0]  aso_channel,
    output logic        aso_startofpacket,
    output logic        aso_endofpacket,
    output logic        aso_endofrun
);

    arb_hit_type0_standalone_top #(
        .FIFO_DEPTH      (16),
        .COUNTER_PROFILE (0)
    ) u_top (.*);

endmodule

module arb_hit_type0_standalone_trim3_fifo2_top (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  avs_csr_address,
    input  logic        avs_csr_write,
    input  logic        avs_csr_read,
    input  logic [31:0] avs_csr_writedata,
    output logic [31:0] avs_csr_readdata,
    output logic        avs_csr_waitrequest,
    input  logic [8:0]  asi_ctrl_data,
    input  logic        asi_ctrl_valid,
    input  logic [44:0] asi_real_data,
    input  logic        asi_real_valid,
    input  logic [2:0]  asi_real_error,
    input  logic [3:0]  asi_real_channel,
    input  logic        asi_real_startofpacket,
    input  logic        asi_real_endofpacket,
    input  logic        asi_real_endofrun,
    input  logic [44:0] asi_emu_data,
    input  logic        asi_emu_valid,
    input  logic [2:0]  asi_emu_error,
    input  logic [3:0]  asi_emu_channel,
    input  logic        asi_emu_startofpacket,
    input  logic        asi_emu_endofpacket,
    input  logic        asi_emu_endofrun,
    output logic [44:0] aso_data,
    output logic        aso_valid,
    output logic [2:0]  aso_error,
    output logic [3:0]  aso_channel,
    output logic        aso_startofpacket,
    output logic        aso_endofpacket,
    output logic        aso_endofrun
);

    arb_hit_type0_standalone_top #(
        .FIFO_DEPTH      (2),
        .COUNTER_PROFILE (1)
    ) u_top (.*);

endmodule
