`timescale 1ns/1ps

package feb_swb_corun_pkg;
  parameter int FEB_SWB_CORUN_ACTIVE_LANES = 2;
  parameter logic [3:0] FEB_SWB_CORUN_ACTIVE_MASK = 4'h3;

  typedef enum logic [3:0] {
    FEB_SWB_SOURCE_UNKNOWN    = 4'h0,
    FEB_SWB_SOURCE_MUTRIG_EMU = 4'h1,
    FEB_SWB_SOURCE_REAL_LVDS  = 4'h2,
    FEB_SWB_SOURCE_FEB_FRAME  = 4'h3
  } feb_swb_source_id_e;

  typedef struct packed {
    logic [1:0] debug_level;
    logic [1:0] swb_lane;
    logic [3:0] source_id;
    logic [7:0] ps_tag;
    logic [15:0] ts_tag;
    logic [31:0] hit_id;
  } feb_swb_debug_meta_t;

  function automatic logic [63:0] feb_swb_pack_debug_meta(
      input feb_swb_debug_meta_t meta);
    return {
      meta.debug_level,
      meta.swb_lane,
      meta.source_id,
      meta.ps_tag,
      meta.ts_tag,
      meta.hit_id
    };
  endfunction

  function automatic feb_swb_debug_meta_t feb_swb_unpack_debug_meta(
      input logic [63:0] bits);
    feb_swb_debug_meta_t meta;
    meta.debug_level = bits[63:62];
    meta.swb_lane    = bits[61:60];
    meta.source_id   = bits[59:56];
    meta.ps_tag      = bits[55:48];
    meta.ts_tag      = bits[47:32];
    meta.hit_id      = bits[31:0];
    return meta;
  endfunction
endpackage
