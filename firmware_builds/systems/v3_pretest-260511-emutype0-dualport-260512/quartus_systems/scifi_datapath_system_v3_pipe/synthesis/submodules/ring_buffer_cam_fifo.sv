// File name: ring_buffer_cam_fifo.sv
// Author  : Yifeng Wang (yifenwan@phys.ethz.ch), Codex migration
// Version : 26.2.7
// Date    : 20260506
// Change  : add synthesizable show-ahead FIFO used by the SV rbCAM port

module ring_buffer_cam_fifo #(
  parameter int WIDTH = 40,
  parameter int DEPTH = 64
) (
  input  logic                         clk,
  input  logic                         rst,
  input  logic                         sclr,
  input  logic                         wrreq,
  input  logic                         rdack,
  input  logic [WIDTH-1:0]             din,
  output logic [WIDTH-1:0]             dout,
  output logic                         empty,
  output logic                         full,
  output logic [$clog2(DEPTH+1)-1:0]   usedw
);
  localparam int ADDR_W_CONST = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [ADDR_W_CONST-1:0] wr_ptr;
  logic [ADDR_W_CONST-1:0] rd_ptr;

  wire do_write = wrreq && !full;
  wire do_read  = rdack && !empty;

  assign empty = (usedw == '0);
  assign full  = (usedw == DEPTH[$bits(usedw)-1:0]);
  assign dout  = empty ? '0 : mem[rd_ptr];

  function automatic logic [ADDR_W_CONST-1:0] ptr_inc(
    input logic [ADDR_W_CONST-1:0] ptr
  );
    if (ptr == DEPTH - 1) begin
      return '0;
    end
    return ptr + {{(ADDR_W_CONST-1){1'b0}}, 1'b1};
  endfunction

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      usedw  <= '0;
`ifdef FORMAL
      for (int i = 0; i < DEPTH; i++) begin
        mem[i] <= '0;
      end
`endif
    end else if (sclr) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      usedw  <= '0;
`ifdef FORMAL
      for (int i = 0; i < DEPTH; i++) begin
        mem[i] <= '0;
      end
`endif
    end else begin
      if (do_write) begin
        mem[wr_ptr] <= din;
        wr_ptr <= ptr_inc(wr_ptr);
      end
      if (do_read) begin
        rd_ptr <= ptr_inc(rd_ptr);
      end
      unique case ({do_write, do_read})
        2'b10: usedw <= usedw + {{($bits(usedw)-1){1'b0}}, 1'b1};
        2'b01: usedw <= usedw - {{($bits(usedw)-1){1'b0}}, 1'b1};
        default: begin
        end
      endcase
    end
  end
endmodule
