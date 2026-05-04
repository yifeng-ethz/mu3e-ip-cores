`timescale 1ns/1ps

module tb_mutrig_lane_source_mux_direct;
    localparam int FIFO_DEPTH = 4;

    logic        clk = 1'b0;
    logic        rst = 1'b1;

    logic [3:0]  avs_csr_address;
    logic        avs_csr_write;
    logic        avs_csr_read;
    logic [31:0] avs_csr_writedata;
    logic [31:0] avs_csr_readdata;
    logic        avs_csr_waitrequest;

    logic [8:0]  asi_real_data;
    logic        asi_real_valid;
    logic [2:0]  asi_real_error;
    logic [3:0]  asi_real_channel;

    logic [8:0]  asi_emu_data;
    logic        asi_emu_valid;
    logic [2:0]  asi_emu_error;
    logic [3:0]  asi_emu_channel;

    logic [8:0]  aso_data;
    logic        aso_valid;
    logic [2:0]  aso_error;
    logic [3:0]  aso_channel;

    logic [3:0]  vl_csr_address;
    logic        vl_csr_write;
    logic        vl_csr_read;
    logic [31:0] vl_csr_writedata;
    logic [31:0] vl_csr_readdata;
    logic        vl_csr_waitrequest;

    logic [8:0]  vl_real_data;
    logic        vl_real_valid;
    logic [2:0]  vl_real_error;
    logic [3:0]  vl_real_channel;

    logic [8:0]  vl_emu_data;
    logic        vl_emu_valid;
    logic [2:0]  vl_emu_error;
    logic [3:0]  vl_emu_channel;

    logic [8:0]  vl_aso_data;
    logic        vl_aso_valid;
    logic [2:0]  vl_aso_error;
    logic [3:0]  vl_aso_channel;

    int pass_count;
    int fail_count;

    always #4 clk = ~clk;

    mutrig_lane_source_mux #(
        .SELECT_EMULATOR(0),
        .FIFO_DEPTH(FIFO_DEPTH),
        .REAL_ALWAYS_VALID(0),
        .VERSION_PATCH(1),
        .BUILD(503),
        .VERSION_DATE(20260503),
        .INSTANCE_ID(99)
    ) dut_valid_qualified (
        .clk(clk),
        .rst(rst),
        .avs_csr_address(avs_csr_address),
        .avs_csr_write(avs_csr_write),
        .avs_csr_read(avs_csr_read),
        .avs_csr_writedata(avs_csr_writedata),
        .avs_csr_readdata(avs_csr_readdata),
        .avs_csr_waitrequest(avs_csr_waitrequest),
        .asi_real_data(asi_real_data),
        .asi_real_valid(asi_real_valid),
        .asi_real_error(asi_real_error),
        .asi_real_channel(asi_real_channel),
        .asi_emu_data(asi_emu_data),
        .asi_emu_valid(asi_emu_valid),
        .asi_emu_error(asi_emu_error),
        .asi_emu_channel(asi_emu_channel),
        .aso_data(aso_data),
        .aso_valid(aso_valid),
        .aso_error(aso_error),
        .aso_channel(aso_channel)
    );

    mutrig_lane_source_mux #(
        .SELECT_EMULATOR(0),
        .FIFO_DEPTH(FIFO_DEPTH),
        .REAL_ALWAYS_VALID(1),
        .VERSION_PATCH(1),
        .BUILD(503),
        .VERSION_DATE(20260503),
        .INSTANCE_ID(100)
    ) dut_validless_real (
        .clk(clk),
        .rst(rst),
        .avs_csr_address(vl_csr_address),
        .avs_csr_write(vl_csr_write),
        .avs_csr_read(vl_csr_read),
        .avs_csr_writedata(vl_csr_writedata),
        .avs_csr_readdata(vl_csr_readdata),
        .avs_csr_waitrequest(vl_csr_waitrequest),
        .asi_real_data(vl_real_data),
        .asi_real_valid(vl_real_valid),
        .asi_real_error(vl_real_error),
        .asi_real_channel(vl_real_channel),
        .asi_emu_data(vl_emu_data),
        .asi_emu_valid(vl_emu_valid),
        .asi_emu_error(vl_emu_error),
        .asi_emu_channel(vl_emu_channel),
        .aso_data(vl_aso_data),
        .aso_valid(vl_aso_valid),
        .aso_error(vl_aso_error),
        .aso_channel(vl_aso_channel)
    );

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check(input string name, input bit cond);
        begin
            if (cond) begin
                pass_count++;
                $display("[PASS] %s", name);
            end else begin
                fail_count++;
                $display("[FAIL] %s", name);
            end
        end
    endtask

    task automatic idle_inputs;
        begin
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

            vl_csr_address    = 4'd0;
            vl_csr_write      = 1'b0;
            vl_csr_read       = 1'b0;
            vl_csr_writedata  = 32'd0;
            vl_real_data      = 9'd0;
            vl_real_valid     = 1'b0;
            vl_real_error     = 3'd0;
            vl_real_channel   = 4'd0;
            vl_emu_data       = 9'd0;
            vl_emu_valid      = 1'b0;
            vl_emu_error      = 3'd0;
            vl_emu_channel    = 4'd0;
        end
    endtask

    task automatic csr_read32(input logic [3:0] addr, output logic [31:0] data);
        begin
            avs_csr_address = addr;
            avs_csr_read    = 1'b1;
            #1;
            data            = avs_csr_readdata;
            avs_csr_read    = 1'b0;
            avs_csr_address = 4'd0;
            #1;
        end
    endtask

    task automatic csr_write32(input logic [3:0] addr, input logic [31:0] data);
        begin
            avs_csr_address   = addr;
            avs_csr_writedata = data;
            avs_csr_write     = 1'b1;
            tick();
            avs_csr_write     = 1'b0;
            avs_csr_writedata = 32'd0;
            avs_csr_address   = 4'd0;
        end
    endtask

    task automatic vl_csr_read32(input logic [3:0] addr, output logic [31:0] data);
        begin
            vl_csr_address = addr;
            vl_csr_read    = 1'b1;
            #1;
            data           = vl_csr_readdata;
            vl_csr_read    = 1'b0;
            vl_csr_address = 4'd0;
            #1;
        end
    endtask

    task automatic vl_csr_write32(input logic [3:0] addr, input logic [31:0] data);
        begin
            vl_csr_address   = addr;
            vl_csr_writedata = data;
            vl_csr_write     = 1'b1;
            tick();
            vl_csr_write     = 1'b0;
            vl_csr_writedata = 32'd0;
            vl_csr_address   = 4'd0;
        end
    endtask

    task automatic expect_counter(input string name, input logic [3:0] addr, input logic [31:0] expected);
        logic [31:0] data;
        begin
            csr_read32(addr, data);
            check(name, data == expected);
        end
    endtask

    task automatic push_real(input logic [8:0] data);
        begin
            asi_real_data    = data;
            asi_real_valid   = 1'b1;
            asi_real_channel = 4'h3;
            asi_real_error   = 3'b001;
            tick();
            check("real beat appears in real mode", aso_valid && aso_data == data);
            check("real sideband is forwarded", aso_channel == 4'h3 && aso_error == 3'b001);
            asi_real_valid   = 1'b0;
        end
    endtask

    task automatic push_emu(input logic [8:0] data);
        begin
            asi_emu_data    = data;
            asi_emu_valid   = 1'b1;
            asi_emu_channel = 4'h9;
            asi_emu_error   = 3'b010;
            tick();
            check("emulator beat appears in emulator mode", aso_valid && aso_data == data);
            check("emulator sideband is forwarded", aso_channel == 4'h9 && aso_error == 3'b010);
            asi_emu_valid   = 1'b0;
        end
    endtask

    initial begin
        logic [31:0] data;

        pass_count = 0;
        fail_count = 0;
        idle_inputs();

        repeat (4) tick();
        rst = 1'b0;
        repeat (2) tick();

        csr_read32(4'h0, data);
        check("UID reads MLSM", data == 32'h4D4C534D);
        csr_read32(4'h2, data);
        check("reset mode is real", data[2:0] == 3'd0);
        check("CSR never stalls", avs_csr_waitrequest == 1'b0);
        check("valid-qualified real stream is idle without valid", !aso_valid);
        expect_counter("valid-qualified real counter starts at zero", 4'h4, 32'd0);

        push_real(9'h12a);
        expect_counter("real input counter increments once", 4'h4, 32'd1);
        expect_counter("selected counter increments once", 4'h6, 32'd1);
        expect_counter("real selected counter increments once", 4'hc, 32'd1);
        tick();
        check("real output deasserts when valid drops", !aso_valid);
        expect_counter("real counter holds with valid low", 4'h4, 32'd1);

        csr_write32(4'h2, 32'h0000_0002);
        expect_counter("CONTROL[1] clears real counter", 4'h4, 32'd0);
        expect_counter("CONTROL[1] clears selected counter", 4'h6, 32'd0);

        csr_write32(4'h2, 32'h0000_0001);
        csr_read32(4'h2, data);
        check("emulator mode applies", data[0] == 1'b1 && data[2] == 1'b0);
        push_emu(9'h055);
        expect_counter("emulator input counter increments once", 4'h5, 32'd1);
        expect_counter("emulator selected counter increments once", 4'hd, 32'd1);

        csr_write32(4'h2, 32'h0000_0006);
        csr_read32(4'h2, data);
        check("round-robin mode applies", data[2] == 1'b1);
        expect_counter("mode-change clear removes emulator count", 4'h5, 32'd0);

        asi_real_data    = 9'h001;
        asi_real_valid   = 1'b1;
        asi_real_channel = 4'h1;
        asi_real_error   = 3'b000;
        asi_emu_data     = 9'h102;
        asi_emu_valid    = 1'b1;
        asi_emu_channel  = 4'h2;
        asi_emu_error    = 3'b011;
        tick();
        check("round-robin presents real first after enqueue", aso_valid && aso_data == 9'h001);
        asi_real_valid   = 1'b0;
        asi_emu_valid    = 1'b0;
        tick();
        check("round-robin presents emulator second", aso_valid && aso_data == 9'h102);
        tick();
        check("round-robin drains both FIFOs", !aso_valid);
        expect_counter("round-robin real selected count", 4'hc, 32'd1);
        expect_counter("round-robin emulator selected count", 4'hd, 32'd1);

        vl_csr_read32(4'h0, data);
        check("validless UID reads MLSM", data == 32'h4D4C534D);
        check("validless CSR never stalls", vl_csr_waitrequest == 1'b0);
        vl_real_data    = 9'h155;
        vl_real_valid   = 1'b0;
        vl_real_channel = 4'ha;
        vl_real_error   = 3'b101;
        #1;
        check("REAL_ALWAYS_VALID drives output valid with input valid low", vl_aso_valid);
        check("REAL_ALWAYS_VALID forwards current real byte", vl_aso_data == 9'h155);
        check("REAL_ALWAYS_VALID forwards current real sideband", vl_aso_channel == 4'ha && vl_aso_error == 3'b101);
        vl_csr_read32(4'h3, data);
        check("status reports effective real valid", data[1] == 1'b1 && data[3] == 1'b1);

        vl_csr_write32(4'h2, 32'h0000_0002);
        vl_csr_read32(4'h4, data);
        check("validless clear can zero real counter", data == 32'd0);
        vl_real_data = 9'h1aa;
        tick();
        vl_csr_read32(4'h4, data);
        check("validless real counter increments with input valid low", data == 32'd1);
        check("validless output remains real path", vl_aso_valid && vl_aso_data == 9'h1aa);

        vl_csr_write32(4'h2, 32'h0000_0001);
        vl_emu_valid = 1'b0;
        #1;
        check("emulator selection still honors emulator valid", !vl_aso_valid);

        $display("Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count != 0) begin
            $fatal(1, "mutrig_lane_source_mux direct test failed");
        end
        $finish;
    end
endmodule
