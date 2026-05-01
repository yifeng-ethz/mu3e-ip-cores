// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// $Id: //acds/rel/18.1std/ip/merlin/altera_merlin_router/altera_merlin_router.sv.terp#1 $
// $Revision: #1 $
// $Date: 2018/07/18 $
// $Author: psgswbuild $

// -------------------------------------------------------
// Merlin Router
//
// Asserts the appropriate one-hot encoded channel based on 
// either (a) the address or (b) the dest id. The DECODER_TYPE
// parameter controls this behaviour. 0 means address decoder,
// 1 means dest id decoder.
//
// In the case of (a), it also sets the destination id.
// -------------------------------------------------------

`timescale 1 ns / 1 ns

module scifi_datapath_system_v3_pipe_mm_interconnect_0_router_001_default_decode
  #(
     parameter DEFAULT_CHANNEL = 18,
               DEFAULT_WR_CHANNEL = -1,
               DEFAULT_RD_CHANNEL = -1,
               DEFAULT_DESTID = 23 
   )
  (output [106 - 101 : 0] default_destination_id,
   output [56-1 : 0] default_wr_channel,
   output [56-1 : 0] default_rd_channel,
   output [56-1 : 0] default_src_channel
  );

  assign default_destination_id = 
    DEFAULT_DESTID[106 - 101 : 0];

  generate
    if (DEFAULT_CHANNEL == -1) begin : no_default_channel_assignment
      assign default_src_channel = '0;
    end
    else begin : default_channel_assignment
      assign default_src_channel = 56'b1 << DEFAULT_CHANNEL;
    end
  endgenerate

  generate
    if (DEFAULT_RD_CHANNEL == -1) begin : no_default_rw_channel_assignment
      assign default_wr_channel = '0;
      assign default_rd_channel = '0;
    end
    else begin : default_rw_channel_assignment
      assign default_wr_channel = 56'b1 << DEFAULT_WR_CHANNEL;
      assign default_rd_channel = 56'b1 << DEFAULT_RD_CHANNEL;
    end
  endgenerate

endmodule


module scifi_datapath_system_v3_pipe_mm_interconnect_0_router_001
(
    // -------------------
    // Clock & Reset
    // -------------------
    input clk,
    input reset,

    // -------------------
    // Command Sink (Input)
    // -------------------
    input                       sink_valid,
    input  [120-1 : 0]    sink_data,
    input                       sink_startofpacket,
    input                       sink_endofpacket,
    output                      sink_ready,

    // -------------------
    // Command Source (Output)
    // -------------------
    output                          src_valid,
    output reg [120-1    : 0] src_data,
    output reg [56-1 : 0] src_channel,
    output                          src_startofpacket,
    output                          src_endofpacket,
    input                           src_ready
);

    // -------------------------------------------------------
    // Local parameters and variables
    // -------------------------------------------------------
    localparam PKT_ADDR_H = 67;
    localparam PKT_ADDR_L = 36;
    localparam PKT_DEST_ID_H = 106;
    localparam PKT_DEST_ID_L = 101;
    localparam PKT_PROTECTION_H = 110;
    localparam PKT_PROTECTION_L = 108;
    localparam ST_DATA_W = 120;
    localparam ST_CHANNEL_W = 56;
    localparam DECODER_TYPE = 0;

    localparam PKT_TRANS_WRITE = 70;
    localparam PKT_TRANS_READ  = 71;

    localparam PKT_ADDR_W = PKT_ADDR_H-PKT_ADDR_L + 1;
    localparam PKT_DEST_ID_W = PKT_DEST_ID_H-PKT_DEST_ID_L + 1;



    // -------------------------------------------------------
    // Figure out the number of bits to mask off for each slave span
    // during address decoding
    // -------------------------------------------------------
    localparam PAD0 = log2ceil(64'h2000 - 64'h0); 
    localparam PAD1 = log2ceil(64'h3000 - 64'h2000); 
    localparam PAD2 = log2ceil(64'h4000 - 64'h3000); 
    localparam PAD3 = log2ceil(64'h5000 - 64'h4000); 
    localparam PAD4 = log2ceil(64'h6000 - 64'h5000); 
    localparam PAD5 = log2ceil(64'h7000 - 64'h6000); 
    localparam PAD6 = log2ceil(64'h8000 - 64'h7000); 
    localparam PAD7 = log2ceil(64'h8020 - 64'h8000); 
    localparam PAD8 = log2ceil(64'h10910 - 64'h10900); 
    localparam PAD9 = log2ceil(64'h11100 - 64'h11000); 
    localparam PAD10 = log2ceil(64'h11910 - 64'h11900); 
    localparam PAD11 = log2ceil(64'h12910 - 64'h12900); 
    localparam PAD12 = log2ceil(64'h13910 - 64'h13900); 
    localparam PAD13 = log2ceil(64'h14910 - 64'h14900); 
    localparam PAD14 = log2ceil(64'h15910 - 64'h15900); 
    localparam PAD15 = log2ceil(64'h16910 - 64'h16900); 
    localparam PAD16 = log2ceil(64'h17910 - 64'h17900); 
    localparam PAD17 = log2ceil(64'h21000 - 64'h20000); 
    localparam PAD18 = log2ceil(64'h21080 - 64'h21000); 
    localparam PAD19 = log2ceil(64'h21100 - 64'h21080); 
    localparam PAD20 = log2ceil(64'h21180 - 64'h21100); 
    localparam PAD21 = log2ceil(64'h21200 - 64'h21180); 
    localparam PAD22 = log2ceil(64'h22040 - 64'h22000); 
    localparam PAD23 = log2ceil(64'h23080 - 64'h23000); 
    localparam PAD24 = log2ceil(64'h23100 - 64'h23080); 
    localparam PAD25 = log2ceil(64'h23180 - 64'h23100); 
    localparam PAD26 = log2ceil(64'h23200 - 64'h23180); 
    localparam PAD27 = log2ceil(64'h25080 - 64'h25000); 
    // -------------------------------------------------------
    // Work out which address bits are significant based on the
    // address range of the slaves. If the required width is too
    // large or too small, we use the address field width instead.
    // -------------------------------------------------------
    localparam ADDR_RANGE = 64'h25080;
    localparam RANGE_ADDR_WIDTH = log2ceil(ADDR_RANGE);
    localparam OPTIMIZED_ADDR_H = (RANGE_ADDR_WIDTH > PKT_ADDR_W) ||
                                  (RANGE_ADDR_WIDTH == 0) ?
                                        PKT_ADDR_H :
                                        PKT_ADDR_L + RANGE_ADDR_WIDTH - 1;

    localparam RG = RANGE_ADDR_WIDTH-1;
    localparam REAL_ADDRESS_RANGE = OPTIMIZED_ADDR_H - PKT_ADDR_L;

      reg [PKT_ADDR_W-1 : 0] address;
      always @* begin
        address = {PKT_ADDR_W{1'b0}};
        address [REAL_ADDRESS_RANGE:0] = sink_data[OPTIMIZED_ADDR_H : PKT_ADDR_L];
      end   

    // -------------------------------------------------------
    // Pass almost everything through, untouched
    // -------------------------------------------------------
    assign sink_ready        = src_ready;
    assign src_valid         = sink_valid;
    assign src_startofpacket = sink_startofpacket;
    assign src_endofpacket   = sink_endofpacket;
    wire [PKT_DEST_ID_W-1:0] default_destid;
    wire [56-1 : 0] default_src_channel;






    scifi_datapath_system_v3_pipe_mm_interconnect_0_router_001_default_decode the_default_decode(
      .default_destination_id (default_destid),
      .default_wr_channel   (),
      .default_rd_channel   (),
      .default_src_channel  (default_src_channel)
    );

    always @* begin
        src_data    = sink_data;
        src_channel = default_src_channel;
        src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = default_destid;

        // --------------------------------------------------
        // Address Decoder
        // Sets the channel and destination ID based on the address
        // --------------------------------------------------

    // ( 0x0 .. 0x2000 )
    if ( {address[RG:PAD0],{PAD0{1'b0}}} == 18'h0   ) begin
            src_channel = 56'b0000000001000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 23;
    end

    // ( 0x2000 .. 0x3000 )
    if ( {address[RG:PAD1],{PAD1{1'b0}}} == 18'h2000   ) begin
            src_channel = 56'b0000000010000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 19;
    end

    // ( 0x3000 .. 0x4000 )
    if ( {address[RG:PAD2],{PAD2{1'b0}}} == 18'h3000   ) begin
            src_channel = 56'b0000000100000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 25;
    end

    // ( 0x4000 .. 0x5000 )
    if ( {address[RG:PAD3],{PAD3{1'b0}}} == 18'h4000   ) begin
            src_channel = 56'b0000001000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 26;
    end

    // ( 0x5000 .. 0x6000 )
    if ( {address[RG:PAD4],{PAD4{1'b0}}} == 18'h5000   ) begin
            src_channel = 56'b0000010000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 27;
    end

    // ( 0x6000 .. 0x7000 )
    if ( {address[RG:PAD5],{PAD5{1'b0}}} == 18'h6000   ) begin
            src_channel = 56'b0000100000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 28;
    end

    // ( 0x7000 .. 0x8000 )
    if ( {address[RG:PAD6],{PAD6{1'b0}}} == 18'h7000   ) begin
            src_channel = 56'b0001000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 29;
    end

    // ( 0x8000 .. 0x8020 )
    if ( {address[RG:PAD7],{PAD7{1'b0}}} == 18'h8000   ) begin
            src_channel = 56'b0010000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 24;
    end

    // ( 0x10900 .. 0x10910 )
    if ( {address[RG:PAD8],{PAD8{1'b0}}} == 18'h10900   ) begin
            src_channel = 56'b0000000000000000000000000001;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 32;
    end

    // ( 0x11000 .. 0x11100 )
    if ( {address[RG:PAD9],{PAD9{1'b0}}} == 18'h11000   ) begin
            src_channel = 56'b0000000000000000000000000100;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 18;
    end

    // ( 0x11900 .. 0x11910 )
    if ( {address[RG:PAD10],{PAD10{1'b0}}} == 18'h11900   ) begin
            src_channel = 56'b0000000000000000000000000010;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 34;
    end

    // ( 0x12900 .. 0x12910 )
    if ( {address[RG:PAD11],{PAD11{1'b0}}} == 18'h12900   ) begin
            src_channel = 56'b0000000000000000000100000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 36;
    end

    // ( 0x13900 .. 0x13910 )
    if ( {address[RG:PAD12],{PAD12{1'b0}}} == 18'h13900   ) begin
            src_channel = 56'b0000000000000000000010000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 38;
    end

    // ( 0x14900 .. 0x14910 )
    if ( {address[RG:PAD13],{PAD13{1'b0}}} == 18'h14900   ) begin
            src_channel = 56'b0000000000000000000001000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 40;
    end

    // ( 0x15900 .. 0x15910 )
    if ( {address[RG:PAD14],{PAD14{1'b0}}} == 18'h15900   ) begin
            src_channel = 56'b0000000000000000000000100000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 42;
    end

    // ( 0x16900 .. 0x16910 )
    if ( {address[RG:PAD15],{PAD15{1'b0}}} == 18'h16900   ) begin
            src_channel = 56'b0000000000000000000000010000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 44;
    end

    // ( 0x17900 .. 0x17910 )
    if ( {address[RG:PAD16],{PAD16{1'b0}}} == 18'h17900   ) begin
            src_channel = 56'b0000000000000000000000001000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 46;
    end

    // ( 0x20000 .. 0x21000 )
    if ( {address[RG:PAD17],{PAD17{1'b0}}} == 18'h20000   ) begin
            src_channel = 56'b0100000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 20;
    end

    // ( 0x21000 .. 0x21080 )
    if ( {address[RG:PAD18],{PAD18{1'b0}}} == 18'h21000   ) begin
            src_channel = 56'b0000000000000000100000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 9;
    end

    // ( 0x21080 .. 0x21100 )
    if ( {address[RG:PAD19],{PAD19{1'b0}}} == 18'h21080   ) begin
            src_channel = 56'b0000000000000010000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 10;
    end

    // ( 0x21100 .. 0x21180 )
    if ( {address[RG:PAD20],{PAD20{1'b0}}} == 18'h21100   ) begin
            src_channel = 56'b0000000000001000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 11;
    end

    // ( 0x21180 .. 0x21200 )
    if ( {address[RG:PAD21],{PAD21{1'b0}}} == 18'h21180   ) begin
            src_channel = 56'b0000000000100000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 12;
    end

    // ( 0x22000 .. 0x22040 )
    if ( {address[RG:PAD22],{PAD22{1'b0}}} == 18'h22000   ) begin
            src_channel = 56'b0000000000000000001000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 47;
    end

    // ( 0x23000 .. 0x23080 )
    if ( {address[RG:PAD23],{PAD23{1'b0}}} == 18'h23000   ) begin
            src_channel = 56'b0000000000000000010000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 13;
    end

    // ( 0x23080 .. 0x23100 )
    if ( {address[RG:PAD24],{PAD24{1'b0}}} == 18'h23080   ) begin
            src_channel = 56'b0000000000000001000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 14;
    end

    // ( 0x23100 .. 0x23180 )
    if ( {address[RG:PAD25],{PAD25{1'b0}}} == 18'h23100   ) begin
            src_channel = 56'b0000000000000100000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 15;
    end

    // ( 0x23180 .. 0x23200 )
    if ( {address[RG:PAD26],{PAD26{1'b0}}} == 18'h23180   ) begin
            src_channel = 56'b0000000000010000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 16;
    end

    // ( 0x25000 .. 0x25080 )
    if ( {address[RG:PAD27],{PAD27{1'b0}}} == 18'h25000   ) begin
            src_channel = 56'b1000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 21;
    end

end


    // --------------------------------------------------
    // Ceil(log2()) function
    // --------------------------------------------------
    function integer log2ceil;
        input reg[65:0] val;
        reg [65:0] i;

        begin
            i = 1;
            log2ceil = 0;

            while (i < val) begin
                log2ceil = log2ceil + 1;
                i = i << 1;
            end
        end
    endfunction

endmodule


