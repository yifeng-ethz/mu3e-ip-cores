`timescale 1ns/1ps

module feb_swb_musip_uvm_driver (
  input logic         swb_clk,
  input logic         swb_reset,
  input logic [127:0] adapter_data,
  input logic [15:0]  adapter_datak,
  input logic [3:0]   adapter_valid,
  input logic [3:0]   adapter_debug_valid,
  input logic [255:0] adapter_debug_meta,

  feb_ingress_if      feb_if0,
  feb_ingress_if      feb_if1,
  feb_ingress_if      feb_if2,
  feb_ingress_if      feb_if3
);
  always_ff @(posedge swb_clk or posedge swb_reset) begin
    if (swb_reset) begin
      feb_if0.valid <= 1'b0;
      feb_if0.data <= '0;
      feb_if0.datak <= '0;
      feb_if0.sideband_debug_valid <= 1'b0;
      feb_if0.sideband_debug_meta <= '0;

      feb_if1.valid <= 1'b0;
      feb_if1.data <= '0;
      feb_if1.datak <= '0;
      feb_if1.sideband_debug_valid <= 1'b0;
      feb_if1.sideband_debug_meta <= '0;

      feb_if2.valid <= 1'b0;
      feb_if2.data <= '0;
      feb_if2.datak <= '0;
      feb_if2.sideband_debug_valid <= 1'b0;
      feb_if2.sideband_debug_meta <= '0;

      feb_if3.valid <= 1'b0;
      feb_if3.data <= '0;
      feb_if3.datak <= '0;
      feb_if3.sideband_debug_valid <= 1'b0;
      feb_if3.sideband_debug_meta <= '0;
    end else begin
      feb_if0.valid <= adapter_valid[0];
      feb_if0.data <= adapter_data[0 +: 32];
      feb_if0.datak <= adapter_datak[0 +: 4];
      feb_if0.sideband_debug_valid <= adapter_debug_valid[0];
      feb_if0.sideband_debug_meta <= adapter_debug_meta[0 +: 64];

      feb_if1.valid <= adapter_valid[1];
      feb_if1.data <= adapter_data[32 +: 32];
      feb_if1.datak <= adapter_datak[4 +: 4];
      feb_if1.sideband_debug_valid <= adapter_debug_valid[1];
      feb_if1.sideband_debug_meta <= adapter_debug_meta[64 +: 64];

      feb_if2.valid <= adapter_valid[2];
      feb_if2.data <= adapter_data[64 +: 32];
      feb_if2.datak <= adapter_datak[8 +: 4];
      feb_if2.sideband_debug_valid <= adapter_debug_valid[2];
      feb_if2.sideband_debug_meta <= adapter_debug_meta[128 +: 64];

      feb_if3.valid <= adapter_valid[3];
      feb_if3.data <= adapter_data[96 +: 32];
      feb_if3.datak <= adapter_datak[12 +: 4];
      feb_if3.sideband_debug_valid <= adapter_debug_valid[3];
      feb_if3.sideband_debug_meta <= adapter_debug_meta[192 +: 64];
    end
  end
endmodule
