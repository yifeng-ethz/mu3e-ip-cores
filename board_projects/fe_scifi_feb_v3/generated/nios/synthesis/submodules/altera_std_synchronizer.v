// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other
// software and tools, and its AMPP partner logic functions, and any output
// files from any of the foregoing (including device programming or simulation
// files), and any associated documentation or information are expressly subject
// to the terms and conditions of the Intel Program License Subscription
// Agreement, Intel FPGA IP License Agreement, or other applicable
// license agreement, including, without limitation, that your use is for the
// sole purpose of programming logic devices manufactured by Intel and sold by
// Intel or its authorized distributors. Please refer to the applicable
// agreement for further details.

// Local board-project copy of the standard Intel primitive so the generated
// Nios system binds this module inside the "nios" library instead of relying
// on unrelated Qsys libraries that happen to export the same symbol.

`timescale 1ns / 1ns

module altera_std_synchronizer (
                                clk,
                                reset_n,
                                din,
                                dout
                                );

   parameter depth = 3;

   input  clk;
   input  reset_n;
   input  din;
   output dout;

   (* altera_attribute = {"-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name SDC_STATEMENT \"set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]\" "} *) reg din_s1;
   (* altera_attribute = {"-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON"} *) reg [depth-2:0] dreg;

   // synthesis translate_off
   initial begin
      if (depth < 2) begin
         $display("%m: Error: synchronizer length: %0d less than 2.", depth);
      end
   end

`ifdef __ALTERA_STD__METASTABLE_SIM
   reg [31:0] RANDOM_SEED = 123456;
   wire       next_din_s1;
   wire       dout;
   reg        din_last;
   reg        random;
   event      metastable_event;

   initial begin
      $display("%m: Info: Metastable event injection simulation mode enabled");
   end

   always @(posedge clk) begin
      if (reset_n == 0)
         random <= $random(RANDOM_SEED);
      else
         random <= $random;
   end

   assign next_din_s1 = (din_last ^ din) ? random : din;

   always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
         din_last <= 1'b0;
      else
         din_last <= din;
   end

   always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
         din_s1 <= 1'b0;
      else
         din_s1 <= next_din_s1;
   end
`else
   // synthesis translate_on
   always @(posedge clk or negedge reset_n) begin
      if (reset_n == 0)
         din_s1 <= 1'b0;
      else
         din_s1 <= din;
   end
   // synthesis translate_off
`endif

`ifdef __ALTERA_STD__METASTABLE_SIM_VERBOSE
   always @(*) begin
      if (reset_n && (din_last != din) && (random != din)) begin
         $display("%m: Verbose Info: metastable event @ time %t", $time);
         -> metastable_event;
      end
   end
`endif

   // synthesis translate_on
   generate
      if (depth < 3) begin
         always @(posedge clk or negedge reset_n) begin
            if (reset_n == 0)
               dreg <= {depth-1{1'b0}};
            else
               dreg <= din_s1;
         end
      end else begin
         always @(posedge clk or negedge reset_n) begin
            if (reset_n == 0)
               dreg <= {depth-1{1'b0}};
            else
               dreg <= {dreg[depth-3:0], din_s1};
         end
      end
   endgenerate

   assign dout = dreg[depth-2];

endmodule
