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
  run_control_splitter_formal_tb UUT (

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
    UUT.f_past_valid = 1'b0;
    UUT.f_reset_sr = 2'b11;
    UUT.prev_accept = 1'b0;
    UUT.prev_accept_data = 9'b000000000;

    // state 0
    UUT.in0_valid = 1'b1;
    UUT.out_ready = 16'b0000000000000000;
    UUT.in0_data = 9'b000000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.in0_valid <= 1'b1;
      UUT.out_ready <= 16'b0000000000000000;
      UUT.in0_data <= 9'b000000000;
    end

    // state 2
    if (cycle == 1) begin
      UUT.in0_valid <= 1'b1;
      UUT.out_ready <= 16'b1111111111111111;
      UUT.in0_data <= 9'b000000001;
    end

    genclock <= cycle < 2;
    cycle <= cycle + 1;
  end
endmodule
