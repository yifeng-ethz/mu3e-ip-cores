// Local board-project copy of the Intel bundle synchronizer primitive used by
// the generated Nios IRQ clock crosser. Keeping it beside the Nios sources
// avoids accidental binding through unrelated subsystem libraries.

module altera_std_synchronizer_bundle (
                                        clk,
                                        reset_n,
                                        din,
                                        dout
                                        );

   parameter width = 1;
   parameter depth = 3;

   input              clk;
   input              reset_n;
   input  [width-1:0] din;
   output [width-1:0] dout;

   generate
      genvar i;
      for (i = 0; i < width; i = i + 1) begin : sync
         altera_std_synchronizer #(.depth(depth)) u (
                                                     .clk(clk),
                                                     .reset_n(reset_n),
                                                     .din(din[i]),
                                                     .dout(dout[i])
                                                     );
      end
   endgenerate

endmodule
