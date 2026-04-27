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
  sc_decode_formal_tb UUT (

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
    // UUT.dut.$auto$async2sync.\cc:107:execute$1315  = 1'b0;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1307  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1313  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1319  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1325  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1331  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1337  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1343  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1355  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1361  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1367  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1373  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$1379  = 1'b1;
    UUT.f_past_valid = 1'b0;
    UUT.f_reset_sr = 2'b11;

    // state 0
    UUT.cmd_accept = 1'b1;
    UUT.cmd_addr = 18'b000000000000000000;
    UUT.cmd_burstcount = 9'b000000000;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      UUT.cmd_accept <= 1'b0;
      UUT.cmd_addr <= 18'b000000001111000000;
      UUT.cmd_burstcount <= 9'b101011000;
    end

    // state 2
    if (cycle == 1) begin
      UUT.cmd_accept <= 1'b1;
      UUT.cmd_addr <= 18'b010001000000000001;
      UUT.cmd_burstcount <= 9'b000000010;
    end

    // state 3
    if (cycle == 2) begin
      UUT.cmd_accept <= 1'b1;
      UUT.cmd_addr <= 18'b000000000000000000;
      UUT.cmd_burstcount <= 9'b000000001;
    end

    genclock <= cycle < 3;
    cycle <= cycle + 1;
  end
endmodule
