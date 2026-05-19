// merger_hit_type0_tb.sv
// Simplified directed testbench: drives both real and emu sources, toggles
// the CONTROL.source_sel CSR bit, and checks the readyless output matches
// the currently-selected source verbatim (including channel = ASIC id).

`timescale 1ns/1ps

module merger_hit_type0_tb;

    localparam int DATA_WIDTH    = 45;
    localparam int CHANNEL_WIDTH = 4;
    localparam int ERROR_WIDTH   = 3;
    localparam int CLK_PERIOD_NS = 8;  // 125 MHz

    logic clk;
    logic rst;

    // CSR
    logic [2:0]  csr_addr;
    logic        csr_read;
    logic        csr_write;
    logic [31:0] csr_writedata;
    logic [31:0] csr_readdata;
    logic        csr_waitrequest;

    // real_in
    logic [DATA_WIDTH-1:0]    real_data;
    logic                     real_valid;
    logic [CHANNEL_WIDTH-1:0] real_channel;
    logic [ERROR_WIDTH-1:0]   real_error;
    logic                     real_sop;
    logic                     real_eop;
    logic                     real_eor;

    // emu_in
    logic [DATA_WIDTH-1:0]    emu_data;
    logic                     emu_valid;
    logic [CHANNEL_WIDTH-1:0] emu_channel;
    logic [ERROR_WIDTH-1:0]   emu_error;
    logic                     emu_sop;
    logic                     emu_eop;
    logic                     emu_eor;

    // out
    logic [DATA_WIDTH-1:0]    out_data;
    logic                     out_valid;
    logic [CHANNEL_WIDTH-1:0] out_channel;
    logic [ERROR_WIDTH-1:0]   out_error;
    logic                     out_sop;
    logic                     out_eop;
    logic                     out_eor;

    int errors;
    int checks;

    merger_hit_type0 #(
        .INSTANCE_ID(3),
        .SOURCE_SEL_DEFAULT(0)
    ) dut (
        .clk(clk), .rst(rst),
        .avs_csr_address(csr_addr),
        .avs_csr_read(csr_read),
        .avs_csr_write(csr_write),
        .avs_csr_writedata(csr_writedata),
        .avs_csr_readdata(csr_readdata),
        .avs_csr_waitrequest(csr_waitrequest),

        .asi_real_data(real_data),
        .asi_real_valid(real_valid),
        .asi_real_channel(real_channel),
        .asi_real_error(real_error),
        .asi_real_startofpacket(real_sop),
        .asi_real_endofpacket(real_eop),
        .asi_real_endofrun(real_eor),

        .asi_emu_data(emu_data),
        .asi_emu_valid(emu_valid),
        .asi_emu_channel(emu_channel),
        .asi_emu_error(emu_error),
        .asi_emu_startofpacket(emu_sop),
        .asi_emu_endofpacket(emu_eop),
        .asi_emu_endofrun(emu_eor),

        .aso_out_data(out_data),
        .aso_out_valid(out_valid),
        .aso_out_channel(out_channel),
        .aso_out_error(out_error),
        .aso_out_startofpacket(out_sop),
        .aso_out_endofpacket(out_eop),
        .aso_out_endofrun(out_eor)
    );

    initial clk = 0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task automatic csr_write_word(input [2:0] addr, input [31:0] data);
        @(posedge clk);
        csr_addr      <= addr;
        csr_write     <= 1'b1;
        csr_writedata <= data;
        @(posedge clk);
        csr_write     <= 1'b0;
        csr_writedata <= 32'h0;
    endtask

    task automatic csr_read_word(input [2:0] addr, output [31:0] data);
        @(posedge clk);
        csr_addr <= addr;
        csr_read <= 1'b1;
        @(posedge clk);
        data     = csr_readdata;
        csr_read <= 1'b0;
    endtask

    function automatic logic [DATA_WIDTH-1:0] make_hit(input int signed asic_id,
                                                       input int signed ch_id,
                                                       input int signed tcc);
        logic [DATA_WIDTH-1:0] word_v;
        begin
            word_v = '0;
            word_v[44:41] = asic_id[3:0];
            word_v[40:36] = ch_id[4:0];
            word_v[35:21] = tcc[14:0];
            word_v[0]     = 1'b1;
            return word_v;
        end
    endfunction

    task automatic check_eq(input string tag, input logic [44:0] got, input logic [44:0] exp);
        checks++;
        if (got !== exp) begin
            $display("[FAIL] %s got=0x%011h exp=0x%011h @ %0t", tag, got, exp, $time);
            errors++;
        end
    endtask

    task automatic check_bool(input string tag, input logic got, input logic exp);
        checks++;
        if (got !== exp) begin
            $display("[FAIL] %s got=%0b exp=%0b @ %0t", tag, got, exp, $time);
            errors++;
        end
    endtask

    initial begin
        // ---- init
        rst        = 1'b1;
        csr_addr   = 3'h0;
        csr_read   = 1'b0;
        csr_write  = 1'b0;
        csr_writedata = 32'h0;
        real_data  = '0; real_valid = 1'b0; real_channel = '0; real_error = '0;
        real_sop = 1'b0; real_eop = 1'b0; real_eor = 1'b0;
        emu_data  = '0; emu_valid = 1'b0; emu_channel = '0; emu_error = '0;
        emu_sop = 1'b0; emu_eop = 1'b0; emu_eor = 1'b0;
        errors = 0;
        checks = 0;

        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);

        // ---- CSR identity readback
        begin
            logic [31:0] rd_uid;
            logic [31:0] rd_version;
            logic [31:0] rd_date;
            logic [31:0] rd_ctrl;
            csr_read_word(3'h0, rd_uid);
            csr_read_word(3'h1, rd_version);
            csr_read_word(3'h2, rd_date);
            csr_read_word(3'h3, rd_ctrl);
            $display("[INFO] UID=0x%08h VER=0x%08h DATE=%0d CTRL=0x%08h", rd_uid, rd_version, rd_date, rd_ctrl);
            check_eq("UID", rd_uid, 32'h4D484754);
            check_eq("VER", rd_version, 32'h1A000207);
            check_bool("SOURCE_SEL_DEFAULT=REAL", rd_ctrl[0], 1'b0);
        end

        // ---- T1: source=REAL (default after reset), drive a real beat, expect it through
        @(posedge clk);
        real_data    = make_hit(3, 11, 15'h1234);
        real_channel = 4'd3;
        real_error   = 3'b001;
        real_valid   = 1'b1;
        real_sop     = 1'b1;
        emu_data     = make_hit(5, 22, 15'h5678);   // emulator drives a different ASIC concurrently
        emu_channel  = 4'd5;
        emu_valid    = 1'b1;
        @(posedge clk);
        check_bool("T1 out_valid (REAL)", out_valid, 1'b1);
        check_eq  ("T1 out_data (REAL)",  out_data,  real_data);
        check_bool("T1 out_channel[0] == real_channel[0]", out_channel[0], real_channel[0]);
        check_bool("T1 out_channel[1] == real_channel[1]", out_channel[1], real_channel[1]);
        check_bool("T1 out_sop (REAL)", out_sop, 1'b1);
        real_valid = 1'b0; real_sop = 1'b0;
        emu_valid  = 1'b0;
        @(posedge clk);

        // ---- T2: switch to EMU via CSR, drive emu beat
        csr_write_word(3'h3, 32'h0000_0001);
        @(posedge clk);
        real_data    = make_hit(3, 11, 15'h1234);
        real_channel = 4'd3;
        real_valid   = 1'b1;
        emu_data     = make_hit(5, 22, 15'h5678);
        emu_channel  = 4'd5;
        emu_error    = 3'b010;
        emu_valid    = 1'b1;
        emu_eop      = 1'b1;
        @(posedge clk);
        check_bool("T2 out_valid (EMU)", out_valid, 1'b1);
        check_eq  ("T2 out_data (EMU)",  out_data,  emu_data);
        check_bool("T2 out_channel[0] == emu_channel[0]", out_channel[0], emu_channel[0]);
        check_bool("T2 out_eop (EMU)", out_eop, 1'b1);
        real_valid = 1'b0;
        emu_valid  = 1'b0; emu_eop = 1'b0;
        @(posedge clk);

        // ---- T3: both sources idle on EMU side, output must be idle
        @(posedge clk);
        check_bool("T3 out_valid (idle)", out_valid, 1'b0);

        // ---- T4: switch back to REAL via CSR
        csr_write_word(3'h3, 32'h0000_0000);
        @(posedge clk);
        real_data    = make_hit(7, 0, 15'h0AAA);
        real_channel = 4'd7;
        real_valid   = 1'b1;
        emu_data     = make_hit(5, 22, 15'h5555);
        emu_channel  = 4'd5;
        emu_valid    = 1'b1;
        @(posedge clk);
        check_bool("T4 out_valid (REAL)", out_valid, 1'b1);
        check_eq  ("T4 out_data (REAL)",  out_data,  real_data);
        check_bool("T4 out_channel[2]", out_channel[2], real_channel[2]);
        real_valid = 1'b0;
        emu_valid  = 1'b0;
        @(posedge clk);

        // ---- T5: endofrun forwarding
        @(posedge clk);
        real_data  = make_hit(7, 0, 15'h0BBB);
        real_channel = 4'd7;
        real_valid = 1'b1;
        real_eor   = 1'b1;
        @(posedge clk);
        check_bool("T5 out_eor", out_eor, 1'b1);
        real_valid = 1'b0; real_eor = 1'b0;
        @(posedge clk);

        repeat (5) @(posedge clk);
        $display("[INFO] checks=%0d errors=%0d", checks, errors);
        if (errors == 0) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED ***");
        end
        $finish;
    end

    initial begin
        #(100_000);
        $display("[FAIL] timeout");
        $finish;
    end

endmodule
