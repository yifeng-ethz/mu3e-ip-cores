`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  upload_pkt_mux_formal_tb UUT (

  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.dut.$auto$async2sync.\cc:253:execute$1159  = 2'b00;
    UUT.dut._witness_.anyinit_procdff_1134 = 1'b0;
    UUT.dut.outpipe._witness_.anyinit_procdff_1114 = 1'b0;
    UUT.dut.outpipe._witness_.anyinit_procdff_1119 = 40'b0000000000000000000000000000000000000001;
    UUT.f_cycle = 6'b000000;
    UUT.f_past_valid = 1'b0;
    UUT.f_reset_sr = 2'b11;
    UUT.frame_in_progress = 1'b0;
    UUT.out_count0 = 2'b00;
    UUT.out_count1 = 2'b00;
    UUT.out_count2 = 2'b00;
    UUT.out_stall_ctr = 4'b0000;
    UUT.src0_active = 1'b0;
    UUT.src0_beat = 1'b0;
    UUT.src0_started = 1'b0;
    UUT.src1_active = 1'b0;
    UUT.src1_beat = 1'b0;
    UUT.src1_started = 1'b0;
    UUT.src2_active = 1'b0;
    UUT.src2_beat = 1'b0;
    UUT.src2_started = 1'b0;
    UUT.long1 = 1'b0;
    UUT.long2 = 1'b0;
    UUT.start0 = 2'b00;
    UUT.start1 = 2'b01;
    UUT.start2 = 2'b00;
    UUT.long0 = 1'b1;

    // state 0
    UUT.out_ready = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.out_ready <= 1'b0;
    end

    // state 2
    if (cycle == 1) begin
      UUT.out_ready <= 1'b0;
    end

    // state 3
    if (cycle == 2) begin
      UUT.out_ready <= 1'b0;
    end

    // state 4
    if (cycle == 3) begin
      UUT.out_ready <= 1'b1;
    end

    // state 5
    if (cycle == 4) begin
      UUT.out_ready <= 1'b0;
    end

    genclock <= cycle < 5;
    cycle <= cycle + 1;
  end
endmodule
