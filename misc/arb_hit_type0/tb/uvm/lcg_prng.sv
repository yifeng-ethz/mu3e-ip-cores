package lcg_prng_pkg;
  typedef struct packed {
    bit [31:0] state;
  } lcg_prng_state_t;

  localparam bit [31:0] LCG_A_CONST = 32'd1664525;
  localparam bit [31:0] LCG_C_CONST = 32'd1013904223;

  function automatic lcg_prng_state_t lcg_init(input bit [31:0] seed);
    lcg_prng_state_t prng;

    prng.state = (seed == 32'd0) ? 32'h1ACE_B00C : seed;
    return prng;
  endfunction

  function automatic bit [31:0] lcg_next(ref lcg_prng_state_t prng);
    prng.state = (prng.state * LCG_A_CONST) + LCG_C_CONST;
    return prng.state;
  endfunction

  function automatic int unsigned lcg_range(
    ref lcg_prng_state_t prng,
    input int unsigned   limit
  );
    bit [31:0] value;

    value = lcg_next(prng);
    if (limit == 0) begin
      return 0;
    end
    return int'(value % limit);
  endfunction
endpackage
