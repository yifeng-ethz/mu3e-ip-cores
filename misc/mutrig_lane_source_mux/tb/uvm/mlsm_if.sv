`timescale 1ns/1ps

interface mlsm_if(input logic clk);
    logic        rst = 1'b1;

    logic [3:0]  avs_csr_address = 4'd0;
    logic        avs_csr_write = 1'b0;
    logic        avs_csr_read = 1'b0;
    logic [31:0] avs_csr_writedata = 32'd0;
    logic [31:0] avs_csr_readdata;
    logic        avs_csr_waitrequest;

    logic [8:0]  asi_real_data = 9'd0;
    logic        asi_real_valid = 1'b0;
    logic [2:0]  asi_real_error = 3'd0;
    logic [3:0]  asi_real_channel = 4'd0;

    logic [8:0]  asi_emu_data = 9'd0;
    logic        asi_emu_valid = 1'b0;
    logic [2:0]  asi_emu_error = 3'd0;
    logic [3:0]  asi_emu_channel = 4'd0;

    logic [8:0]  aso_data;
    logic        aso_valid;
    logic [2:0]  aso_error;
    logic [3:0]  aso_channel;

    logic [31:0] probe_valid_count;
    logic [8:0]  probe_last_data;
    logic [2:0]  probe_last_error;
    logic [3:0]  probe_last_channel;
    logic        probe_clear = 1'b0;

    task automatic drive_quiet;
        avs_csr_address   = 4'd0;
        avs_csr_write     = 1'b0;
        avs_csr_read      = 1'b0;
        avs_csr_writedata = 32'd0;
        asi_real_data     = 9'd0;
        asi_real_valid    = 1'b0;
        asi_real_error    = 3'd0;
        asi_real_channel  = 4'd0;
        asi_emu_data      = 9'd0;
        asi_emu_valid     = 1'b0;
        asi_emu_error     = 3'd0;
        asi_emu_channel   = 4'd0;
        probe_clear       = 1'b0;
    endtask
endinterface
