// File name: cam_primitive_m10k_sv.sv
// Author  : Yifeng Wang (yifenwan@phys.ethz.ch), Codex
// Version : 26.2.11
// Date    : 20260511
// Change  : add Arria V M10K simple dual-port RAM and CAM bitmap wrappers

module cam_primitive_m10k_sv #(
  parameter int DATA_WIDTH = 8,
  parameter int ADDR_WIDTH = 6,
  parameter int DEPTH      = (1 << ADDR_WIDTH)
) (
  input  logic                  clock,
  input  logic [ADDR_WIDTH-1:0] write_addr,
  input  logic [DATA_WIDTH-1:0] write_data,
  input  logic                  write_enable,
  input  logic [ADDR_WIDTH-1:0] read_addr,
  output logic [DATA_WIDTH-1:0] read_data
);
  // Quartus 18.1 Verilog template "Simple Dual Port RAM (single clock)"
  // uses one clocked write and one clocked read, with old-data
  // read-during-write from nonblocking assignments.  The memory array has no
  // reset; clear operations must walk the write port.
  (* ramstyle = "M10K" *) logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

  initial begin
    for (int i = 0; i < DEPTH; i++) begin
      memory[i] = '0;
    end
  end

  always @(posedge clock) begin
    if (write_enable) begin
      memory[write_addr] <= write_data;
    end
    read_data <= memory[read_addr];
  end
endmodule

module cam_mixed_width_m10k_sv #(
  parameter int READ_WIDTH       = 32,
  parameter int READ_ADDR_WIDTH  = 8,
  parameter int WRITE_WIDTH      = 1,
  parameter int WRITE_ADDR_WIDTH = READ_ADDR_WIDTH + $clog2(READ_WIDTH / WRITE_WIDTH),
  parameter int READ_DEPTH       = (1 << READ_ADDR_WIDTH)
) (
  input  logic                        clock,
  input  logic [WRITE_ADDR_WIDTH-1:0] write_addr,
  input  logic [WRITE_WIDTH-1:0]      write_data,
  input  logic                        write_enable,
  input  logic [READ_ADDR_WIDTH-1:0]  read_addr,
  output logic [READ_WIDTH-1:0]       read_data
);
  localparam int RATIO_CONST = READ_WIDTH / WRITE_WIDTH;

  // Quartus 18.1 SystemVerilog template "Mixed-Width Port RAM" models
  // a smaller write port and a wider synchronous read port with a packed
  // multidimensional array.  The rbCAM bitmap writes one address bit and
  // reads one 32-address page per search key.
  (* ramstyle = "M10K" *) logic [RATIO_CONST-1:0][WRITE_WIDTH-1:0] memory [0:READ_DEPTH-1];

  initial begin
    for (int i = 0; i < READ_DEPTH; i++) begin
      memory[i] = '0;
    end
  end

  always @(posedge clock) begin
    if (write_enable) begin
      memory[write_addr / RATIO_CONST][write_addr % RATIO_CONST] <= write_data;
    end
    read_data <= memory[read_addr];
  end
endmodule

module cam_lookup_m10k_sv #(
  parameter int KEY_WIDTH = 8,
  parameter int N_ENTRY   = 512,
  parameter int ADDR_WIDTH = (N_ENTRY <= 2) ? 1 : $clog2(N_ENTRY)
) (
  input  logic                     clock,
  input  logic [ADDR_WIDTH-1:0]    write_addr,
  input  logic [KEY_WIDTH-1:0]     write_key,
  input  logic                     write_bit,
  input  logic                     write_enable,
  input  logic [KEY_WIDTH-1:0]     read_key,
  output logic [N_ENTRY-1:0]       match_addr
);
  localparam int PAGE_BITS_CONST  = 5;
  localparam int PAGE_SIZE_CONST  = 1 << PAGE_BITS_CONST;
  localparam int PAGE_COUNT_CONST = (N_ENTRY + PAGE_SIZE_CONST - 1) / PAGE_SIZE_CONST;
  localparam int PAGE_SEL_WIDTH_CONST =
    (PAGE_COUNT_CONST <= 2) ? 1 : $clog2(PAGE_COUNT_CONST);
  localparam int KEY_DEPTH_CONST = 1 << KEY_WIDTH;

  logic [PAGE_COUNT_CONST-1:0][PAGE_SIZE_CONST-1:0] page_match;
  logic [PAGE_COUNT_CONST-1:0] page_write_enable;
  logic [PAGE_SEL_WIDTH_CONST-1:0] write_page;
  logic [PAGE_BITS_CONST-1:0] write_bit_index;
  logic [KEY_WIDTH+PAGE_BITS_CONST-1:0] page_write_addr;

  assign write_page = PAGE_SEL_WIDTH_CONST'(write_addr >> PAGE_BITS_CONST);
  assign write_bit_index = write_addr[PAGE_BITS_CONST-1:0];
  assign page_write_addr = {write_key, write_bit_index};

  genvar page;
  generate
    for (page = 0; page < PAGE_COUNT_CONST; page = page + 1) begin : gen_cam_page
      logic [PAGE_SIZE_CONST-1:0] page_read_data;

      always_comb begin
        page_write_enable[page] =
          write_enable &&
          (write_page == PAGE_SEL_WIDTH_CONST'(page));
      end

      cam_mixed_width_m10k_sv #(
        .READ_WIDTH(PAGE_SIZE_CONST),
        .READ_ADDR_WIDTH(KEY_WIDTH),
        .WRITE_WIDTH(1),
        .WRITE_ADDR_WIDTH(KEY_WIDTH + PAGE_BITS_CONST),
        .READ_DEPTH(KEY_DEPTH_CONST)
      ) page_ram (
        .clock(clock),
        .write_addr(page_write_addr),
        .write_data(write_bit),
        .write_enable(page_write_enable[page]),
        .read_addr(read_key),
        .read_data(page_read_data)
      );

      assign page_match[page] = page_read_data;
    end
  endgenerate

  always_ff @(posedge clock) begin
    for (int page = 0; page < PAGE_COUNT_CONST; page++) begin
      for (int bit_idx = 0; bit_idx < PAGE_SIZE_CONST; bit_idx++) begin
        if ((page * PAGE_SIZE_CONST + bit_idx) < N_ENTRY) begin
          match_addr[page * PAGE_SIZE_CONST + bit_idx] <= page_match[page][bit_idx];
        end
      end
    end
  end
endmodule
