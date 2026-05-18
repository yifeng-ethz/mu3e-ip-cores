`timescale 1ns/1ps

module feb_swb_serial_line_adapter_stub #(
  parameter bit ENABLE_PIN_LEVEL = 1'b0
) (
  input  logic         serial_clk,
  input  logic         serial_reset,
  input  logic [1:0]   firefly_rx_p,
  input  logic [1:0]   firefly_rx_n,

  input  logic         swb_clk,
  input  logic         swb_reset,
  output logic [127:0] swb_data,
  output logic [15:0]  swb_datak,
  output logic [3:0]   swb_valid,
  output logic [3:0]   swb_enable_mask
);
  initial begin
    if (ENABLE_PIN_LEVEL) begin
      $fatal(1,
          "Pin-level FEB Firefly to SWB XCVR simulation requires the Arria XCVR/CDR model and 8b10b receive path. Use feb_swb_parallel_cdc_adapter until that PHY model is available.");
    end
  end

  always_comb begin
    swb_data = 128'h0;
    swb_datak = 16'h0;
    swb_valid = 4'h0;
    swb_enable_mask = 4'h3;
  end

  wire unused_inputs = serial_clk ^ serial_reset ^ swb_clk ^ swb_reset ^
                       ^firefly_rx_p ^ ^firefly_rx_n;
endmodule
