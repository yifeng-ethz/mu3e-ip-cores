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

module feb_system_v3_data_path_subsystem_mm_interconnect_1_router_default_decode
  #(
     parameter DEFAULT_CHANNEL = 29,
               DEFAULT_WR_CHANNEL = -1,
               DEFAULT_RD_CHANNEL = -1,
               DEFAULT_DESTID = 10 
   )
  (output [106 - 101 : 0] default_destination_id,
   output [44-1 : 0] default_wr_channel,
   output [44-1 : 0] default_rd_channel,
   output [44-1 : 0] default_src_channel
  );

  assign default_destination_id = 
    DEFAULT_DESTID[106 - 101 : 0];

  generate
    if (DEFAULT_CHANNEL == -1) begin : no_default_channel_assignment
      assign default_src_channel = '0;
    end
    else begin : default_channel_assignment
      assign default_src_channel = 44'b1 << DEFAULT_CHANNEL;
    end
  endgenerate

  generate
    if (DEFAULT_RD_CHANNEL == -1) begin : no_default_rw_channel_assignment
      assign default_wr_channel = '0;
      assign default_rd_channel = '0;
    end
    else begin : default_rw_channel_assignment
      assign default_wr_channel = 44'b1 << DEFAULT_WR_CHANNEL;
      assign default_rd_channel = 44'b1 << DEFAULT_RD_CHANNEL;
    end
  endgenerate

endmodule


module feb_system_v3_data_path_subsystem_mm_interconnect_1_router
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
    output reg [44-1 : 0] src_channel,
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
    localparam ST_CHANNEL_W = 44;
    localparam DECODER_TYPE = 0;

    localparam PKT_TRANS_WRITE = 70;
    localparam PKT_TRANS_READ  = 71;

    localparam PKT_ADDR_W = PKT_ADDR_H-PKT_ADDR_L + 1;
    localparam PKT_DEST_ID_W = PKT_DEST_ID_H-PKT_DEST_ID_L + 1;



    // -------------------------------------------------------
    // Figure out the number of bits to mask off for each slave span
    // during address decoding
    // -------------------------------------------------------
    localparam PAD0 = log2ceil(64'h40 - 64'h0); 
    localparam PAD1 = log2ceil(64'h300 - 64'h200); 
    localparam PAD2 = log2ceil(64'h870 - 64'h860); 
    localparam PAD3 = log2ceil(64'h910 - 64'h900); 
    localparam PAD4 = log2ceil(64'h1870 - 64'h1860); 
    localparam PAD5 = log2ceil(64'h1910 - 64'h1900); 
    localparam PAD6 = log2ceil(64'h2040 - 64'h2000); 
    localparam PAD7 = log2ceil(64'h2080 - 64'h2040); 
    localparam PAD8 = log2ceil(64'h20c0 - 64'h2080); 
    localparam PAD9 = log2ceil(64'h2100 - 64'h20c0); 
    localparam PAD10 = log2ceil(64'h2140 - 64'h2100); 
    localparam PAD11 = log2ceil(64'h2180 - 64'h2140); 
    localparam PAD12 = log2ceil(64'h21c0 - 64'h2180); 
    localparam PAD13 = log2ceil(64'h2200 - 64'h21c0); 
    localparam PAD14 = log2ceil(64'h2240 - 64'h2200); 
    localparam PAD15 = log2ceil(64'h2870 - 64'h2860); 
    localparam PAD16 = log2ceil(64'h2910 - 64'h2900); 
    localparam PAD17 = log2ceil(64'h3870 - 64'h3860); 
    localparam PAD18 = log2ceil(64'h3910 - 64'h3900); 
    localparam PAD19 = log2ceil(64'h4020 - 64'h4000); 
    localparam PAD20 = log2ceil(64'h4870 - 64'h4860); 
    localparam PAD21 = log2ceil(64'h4910 - 64'h4900); 
    localparam PAD22 = log2ceil(64'h5870 - 64'h5860); 
    localparam PAD23 = log2ceil(64'h5910 - 64'h5900); 
    localparam PAD24 = log2ceil(64'h6870 - 64'h6860); 
    localparam PAD25 = log2ceil(64'h6910 - 64'h6900); 
    localparam PAD26 = log2ceil(64'h7870 - 64'h7860); 
    localparam PAD27 = log2ceil(64'h7910 - 64'h7900); 
    localparam PAD28 = log2ceil(64'h8020 - 64'h8000); 
    localparam PAD29 = log2ceil(64'ha400 - 64'ha000); 
    localparam PAD30 = log2ceil(64'ha480 - 64'ha400); 
    localparam PAD31 = log2ceil(64'hac00 - 64'ha800); 
    localparam PAD32 = log2ceil(64'hac80 - 64'hac00); 
    localparam PAD33 = log2ceil(64'hb080 - 64'hb000); 
    localparam PAD34 = log2ceil(64'hb100 - 64'hb080); 
    localparam PAD35 = log2ceil(64'hb180 - 64'hb100); 
    localparam PAD36 = log2ceil(64'hb200 - 64'hb180); 
    localparam PAD37 = log2ceil(64'hb240 - 64'hb200); 
    localparam PAD38 = log2ceil(64'hb480 - 64'hb400); 
    localparam PAD39 = log2ceil(64'hb500 - 64'hb480); 
    localparam PAD40 = log2ceil(64'hb580 - 64'hb500); 
    localparam PAD41 = log2ceil(64'hb600 - 64'hb580); 
    localparam PAD42 = log2ceil(64'hd040 - 64'hd000); 
    localparam PAD43 = log2ceil(64'hd080 - 64'hd040); 
    // -------------------------------------------------------
    // Work out which address bits are significant based on the
    // address range of the slaves. If the required width is too
    // large or too small, we use the address field width instead.
    // -------------------------------------------------------
    localparam ADDR_RANGE = 64'hd080;
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
    wire [44-1 : 0] default_src_channel;






    feb_system_v3_data_path_subsystem_mm_interconnect_1_router_default_decode the_default_decode(
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

    // ( 0x0 .. 0x40 )
    if ( {address[RG:PAD0],{PAD0{1'b0}}} == 16'h0   ) begin
            src_channel = 44'b00000000000000000000000000000000000000000001;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 23;
    end

    // ( 0x200 .. 0x300 )
    if ( {address[RG:PAD1],{PAD1{1'b0}}} == 16'h200   ) begin
            src_channel = 44'b00000000000000000000000000000000000000000010;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 24;
    end

    // ( 0x860 .. 0x870 )
    if ( {address[RG:PAD2],{PAD2{1'b0}}} == 16'h860   ) begin
            src_channel = 44'b00000000000000000000000000000000000000000100;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 27;
    end

    // ( 0x900 .. 0x910 )
    if ( {address[RG:PAD3],{PAD3{1'b0}}} == 16'h900   ) begin
            src_channel = 44'b00000000000000000000001000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 28;
    end

    // ( 0x1860 .. 0x1870 )
    if ( {address[RG:PAD4],{PAD4{1'b0}}} == 16'h1860   ) begin
            src_channel = 44'b00000000000000000000000000000000000000001000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 29;
    end

    // ( 0x1900 .. 0x1910 )
    if ( {address[RG:PAD5],{PAD5{1'b0}}} == 16'h1900   ) begin
            src_channel = 44'b00000000000000000000010000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 30;
    end

    // ( 0x2000 .. 0x2040 )
    if ( {address[RG:PAD6],{PAD6{1'b0}}} == 16'h2000   ) begin
            src_channel = 44'b00000000000000000000000000000000000001000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 1;
    end

    // ( 0x2040 .. 0x2080 )
    if ( {address[RG:PAD7],{PAD7{1'b0}}} == 16'h2040   ) begin
            src_channel = 44'b00000000000000000000000000000000000010000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 2;
    end

    // ( 0x2080 .. 0x20c0 )
    if ( {address[RG:PAD8],{PAD8{1'b0}}} == 16'h2080   ) begin
            src_channel = 44'b00000000000000000000000000000000000100000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 3;
    end

    // ( 0x20c0 .. 0x2100 )
    if ( {address[RG:PAD9],{PAD9{1'b0}}} == 16'h20c0   ) begin
            src_channel = 44'b00000000000000000000000000000000001000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 4;
    end

    // ( 0x2100 .. 0x2140 )
    if ( {address[RG:PAD10],{PAD10{1'b0}}} == 16'h2100   ) begin
            src_channel = 44'b00000000000000000000000000000000010000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 5;
    end

    // ( 0x2140 .. 0x2180 )
    if ( {address[RG:PAD11],{PAD11{1'b0}}} == 16'h2140   ) begin
            src_channel = 44'b00000000000000000000000000000000100000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 6;
    end

    // ( 0x2180 .. 0x21c0 )
    if ( {address[RG:PAD12],{PAD12{1'b0}}} == 16'h2180   ) begin
            src_channel = 44'b00000000000000000000000000000001000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 7;
    end

    // ( 0x21c0 .. 0x2200 )
    if ( {address[RG:PAD13],{PAD13{1'b0}}} == 16'h21c0   ) begin
            src_channel = 44'b00000000000000000000000000000010000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 8;
    end

    // ( 0x2200 .. 0x2240 )
    if ( {address[RG:PAD14],{PAD14{1'b0}}} == 16'h2200   ) begin
            src_channel = 44'b00000000000000000000000000000100000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 0;
    end

    // ( 0x2860 .. 0x2870 )
    if ( {address[RG:PAD15],{PAD15{1'b0}}} == 16'h2860   ) begin
            src_channel = 44'b00000000000000000000000000000000000000010000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 31;
    end

    // ( 0x2900 .. 0x2910 )
    if ( {address[RG:PAD16],{PAD16{1'b0}}} == 16'h2900   ) begin
            src_channel = 44'b00000000000000000000100000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 32;
    end

    // ( 0x3860 .. 0x3870 )
    if ( {address[RG:PAD17],{PAD17{1'b0}}} == 16'h3860   ) begin
            src_channel = 44'b00000000000000000000000000000000000000100000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 33;
    end

    // ( 0x3900 .. 0x3910 )
    if ( {address[RG:PAD18],{PAD18{1'b0}}} == 16'h3900   ) begin
            src_channel = 44'b00000000000000000001000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 34;
    end

    // ( 0x4000 .. 0x4020 )
    if ( {address[RG:PAD19],{PAD19{1'b0}}} == 16'h4000   ) begin
            src_channel = 44'b00000000000000000000000000001000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 25;
    end

    // ( 0x4860 .. 0x4870 )
    if ( {address[RG:PAD20],{PAD20{1'b0}}} == 16'h4860   ) begin
            src_channel = 44'b00000000000000000000000000010000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 35;
    end

    // ( 0x4900 .. 0x4910 )
    if ( {address[RG:PAD21],{PAD21{1'b0}}} == 16'h4900   ) begin
            src_channel = 44'b00000000000000000010000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 36;
    end

    // ( 0x5860 .. 0x5870 )
    if ( {address[RG:PAD22],{PAD22{1'b0}}} == 16'h5860   ) begin
            src_channel = 44'b00000000000000000000000000100000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 37;
    end

    // ( 0x5900 .. 0x5910 )
    if ( {address[RG:PAD23],{PAD23{1'b0}}} == 16'h5900   ) begin
            src_channel = 44'b00000000000000000100000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 38;
    end

    // ( 0x6860 .. 0x6870 )
    if ( {address[RG:PAD24],{PAD24{1'b0}}} == 16'h6860   ) begin
            src_channel = 44'b00000000000000000000000001000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 39;
    end

    // ( 0x6900 .. 0x6910 )
    if ( {address[RG:PAD25],{PAD25{1'b0}}} == 16'h6900   ) begin
            src_channel = 44'b00000000000000001000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 40;
    end

    // ( 0x7860 .. 0x7870 )
    if ( {address[RG:PAD26],{PAD26{1'b0}}} == 16'h7860   ) begin
            src_channel = 44'b00000000000000000000000010000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 41;
    end

    // ( 0x7900 .. 0x7910 )
    if ( {address[RG:PAD27],{PAD27{1'b0}}} == 16'h7900   ) begin
            src_channel = 44'b00000000000000010000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 42;
    end

    // ( 0x8000 .. 0x8020 )
    if ( {address[RG:PAD28],{PAD28{1'b0}}} == 16'h8000   ) begin
            src_channel = 44'b00000000000000000000000100000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 26;
    end

    // ( 0xa000 .. 0xa400 )
    if ( {address[RG:PAD29],{PAD29{1'b0}}} == 16'ha000   ) begin
            src_channel = 44'b00000000000000100000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 10;
    end

    // ( 0xa400 .. 0xa480 )
    if ( {address[RG:PAD30],{PAD30{1'b0}}} == 16'ha400   ) begin
            src_channel = 44'b00000000000001000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 9;
    end

    // ( 0xa800 .. 0xac00 )
    if ( {address[RG:PAD31],{PAD31{1'b0}}} == 16'ha800   ) begin
            src_channel = 44'b00000000000010000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 12;
    end

    // ( 0xac00 .. 0xac80 )
    if ( {address[RG:PAD32],{PAD32{1'b0}}} == 16'hac00   ) begin
            src_channel = 44'b00000000000100000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 11;
    end

    // ( 0xb000 .. 0xb080 )
    if ( {address[RG:PAD33],{PAD33{1'b0}}} == 16'hb000   ) begin
            src_channel = 44'b00000000001000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 14;
    end

    // ( 0xb080 .. 0xb100 )
    if ( {address[RG:PAD34],{PAD34{1'b0}}} == 16'hb080   ) begin
            src_channel = 44'b00000000010000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 15;
    end

    // ( 0xb100 .. 0xb180 )
    if ( {address[RG:PAD35],{PAD35{1'b0}}} == 16'hb100   ) begin
            src_channel = 44'b00000000100000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 16;
    end

    // ( 0xb180 .. 0xb200 )
    if ( {address[RG:PAD36],{PAD36{1'b0}}} == 16'hb180   ) begin
            src_channel = 44'b00000001000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 17;
    end

    // ( 0xb200 .. 0xb240 )
    if ( {address[RG:PAD37],{PAD37{1'b0}}} == 16'hb200   ) begin
            src_channel = 44'b00000010000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 43;
    end

    // ( 0xb400 .. 0xb480 )
    if ( {address[RG:PAD38],{PAD38{1'b0}}} == 16'hb400   ) begin
            src_channel = 44'b00000100000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 19;
    end

    // ( 0xb480 .. 0xb500 )
    if ( {address[RG:PAD39],{PAD39{1'b0}}} == 16'hb480   ) begin
            src_channel = 44'b00001000000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 20;
    end

    // ( 0xb500 .. 0xb580 )
    if ( {address[RG:PAD40],{PAD40{1'b0}}} == 16'hb500   ) begin
            src_channel = 44'b00010000000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 21;
    end

    // ( 0xb580 .. 0xb600 )
    if ( {address[RG:PAD41],{PAD41{1'b0}}} == 16'hb580   ) begin
            src_channel = 44'b00100000000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 22;
    end

    // ( 0xd000 .. 0xd040 )
    if ( {address[RG:PAD42],{PAD42{1'b0}}} == 16'hd000   ) begin
            src_channel = 44'b01000000000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 13;
    end

    // ( 0xd040 .. 0xd080 )
    if ( {address[RG:PAD43],{PAD43{1'b0}}} == 16'hd040   ) begin
            src_channel = 44'b10000000000000000000000000000000000000000000;
            src_data[PKT_DEST_ID_H:PKT_DEST_ID_L] = 18;
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


