package arb_hit_type0_reg_pkg;
  localparam bit [4:0] ARB_REG_UID_ADDR                       = 5'h00;
  localparam bit [4:0] ARB_REG_META_ADDR                      = 5'h01;
  localparam bit [4:0] ARB_REG_CONTROL_ADDR                   = 5'h02;
  localparam bit [4:0] ARB_REG_STATUS_ADDR                    = 5'h03;
  localparam bit [4:0] ARB_REG_WATCHDOG_ADDR                  = 5'h04;
  localparam bit [4:0] ARB_REG_IDLE_CYCLES_ADDR               = 5'h05;
  localparam bit [4:0] ARB_REG_ERROR_COUNT_PROTOCOL_ADDR      = 5'h06;
  localparam bit [4:0] ARB_REG_ERROR_COUNT_DROP_MID_ADDR      = 5'h07;
  localparam bit [4:0] ARB_REG_SYNDROME_PROTOCOL_ADDR         = 5'h08;
  localparam bit [4:0] ARB_REG_SYNDROME_DROP_MID_ADDR         = 5'h09;
  localparam bit [4:0] ARB_REG_INGRESS_REAL_HITS_L_ADDR       = 5'h0A;
  localparam bit [4:0] ARB_REG_INGRESS_REAL_HITS_H_ADDR       = 5'h0B;
  localparam bit [4:0] ARB_REG_INGRESS_EMU_HITS_L_ADDR        = 5'h0C;
  localparam bit [4:0] ARB_REG_INGRESS_EMU_HITS_H_ADDR        = 5'h0D;
  localparam bit [4:0] ARB_REG_DROPS_REAL_L_ADDR              = 5'h0E;
  localparam bit [4:0] ARB_REG_DROPS_REAL_H_ADDR              = 5'h0F;
  localparam bit [4:0] ARB_REG_DROPS_EMU_L_ADDR               = 5'h10;
  localparam bit [4:0] ARB_REG_DROPS_EMU_H_ADDR               = 5'h11;
  localparam bit [4:0] ARB_REG_EGRESS_REAL_HITS_L_ADDR        = 5'h12;
  localparam bit [4:0] ARB_REG_EGRESS_REAL_HITS_H_ADDR        = 5'h13;
  localparam bit [4:0] ARB_REG_EGRESS_EMU_HITS_L_ADDR         = 5'h14;
  localparam bit [4:0] ARB_REG_EGRESS_EMU_HITS_H_ADDR         = 5'h15;
  localparam bit [4:0] ARB_REG_INGRESS_REAL_FRAMES_L_ADDR     = 5'h16;
  localparam bit [4:0] ARB_REG_INGRESS_REAL_FRAMES_H_ADDR     = 5'h17;
  localparam bit [4:0] ARB_REG_INGRESS_EMU_FRAMES_L_ADDR      = 5'h18;
  localparam bit [4:0] ARB_REG_INGRESS_EMU_FRAMES_H_ADDR      = 5'h19;
  localparam bit [4:0] ARB_REG_EGRESS_REAL_FRAMES_L_ADDR      = 5'h1A;
  localparam bit [4:0] ARB_REG_EGRESS_REAL_FRAMES_H_ADDR      = 5'h1B;
  localparam bit [4:0] ARB_REG_EGRESS_EMU_FRAMES_L_ADDR       = 5'h1C;
  localparam bit [4:0] ARB_REG_EGRESS_EMU_FRAMES_H_ADDR       = 5'h1D;

  localparam bit [31:0] ARB_UID_CONST                         = 32'h4148_5430;
  localparam bit [31:0] ARB_VERSION_WORD_CONST                = 32'h1A02_01F8;
  localparam bit [31:0] ARB_DATE_WORD_CONST                   = 32'd20260504;
  localparam bit [31:0] ARB_GIT_WORD_CONST                    = 32'h0000_0000;
  localparam bit [31:0] ARB_INSTANCE_ID_WORD_CONST            = 32'h0000_0000;

  localparam bit [1:0] ARB_MODE_REAL_CONST                    = 2'd0;
  localparam bit [1:0] ARB_MODE_EMU_CONST                     = 2'd1;
  localparam bit [1:0] ARB_MODE_MIX_RR_CONST                  = 2'd2;
  localparam bit [1:0] ARB_MODE_RESERVED_CONST                = 2'd3;

  function automatic bit [31:0] arb_control_word(
    input bit [1:0] mode,
    input bit       clear_counters       = 1'b0,
    input bit       clear_sticky         = 1'b0,
    input bit       clear_error_counters = 1'b0,
    input bit       clear_syndromes      = 1'b0
  );
    bit [31:0] word_v;

    word_v       = 32'd0;
    word_v[1:0]  = mode;
    word_v[2]    = clear_counters;
    word_v[3]    = clear_sticky;
    word_v[4]    = clear_error_counters;
    word_v[5]    = clear_syndromes;
    return word_v;
  endfunction

  function automatic bit [1:0] arb_sanitize_mode(input bit [1:0] raw_mode);
    case (raw_mode)
      ARB_MODE_REAL_CONST:   return ARB_MODE_REAL_CONST;
      ARB_MODE_EMU_CONST:    return ARB_MODE_EMU_CONST;
      ARB_MODE_MIX_RR_CONST: return ARB_MODE_MIX_RR_CONST;
      default:               return ARB_MODE_REAL_CONST;
    endcase
  endfunction

  function automatic bit arb_is_counter_low_addr(input bit [4:0] addr);
    return (addr == ARB_REG_INGRESS_REAL_HITS_L_ADDR) ||
           (addr == ARB_REG_INGRESS_EMU_HITS_L_ADDR)  ||
           (addr == ARB_REG_DROPS_REAL_L_ADDR)        ||
           (addr == ARB_REG_DROPS_EMU_L_ADDR)         ||
           (addr == ARB_REG_EGRESS_REAL_HITS_L_ADDR)  ||
           (addr == ARB_REG_EGRESS_EMU_HITS_L_ADDR)   ||
           (addr == ARB_REG_INGRESS_REAL_FRAMES_L_ADDR) ||
           (addr == ARB_REG_INGRESS_EMU_FRAMES_L_ADDR)  ||
           (addr == ARB_REG_EGRESS_REAL_FRAMES_L_ADDR)  ||
           (addr == ARB_REG_EGRESS_EMU_FRAMES_L_ADDR);
  endfunction
endpackage
