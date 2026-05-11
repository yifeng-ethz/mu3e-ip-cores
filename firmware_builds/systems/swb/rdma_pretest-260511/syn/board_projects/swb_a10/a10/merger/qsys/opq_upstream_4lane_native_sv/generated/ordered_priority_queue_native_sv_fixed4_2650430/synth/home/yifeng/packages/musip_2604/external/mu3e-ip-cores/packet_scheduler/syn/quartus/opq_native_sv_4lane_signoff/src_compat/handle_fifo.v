module handle_fifo
#(parameter DATA_WIDTH = 40, parameter ADDR_WIDTH = 4)
(
  input [(DATA_WIDTH-1):0] data,
  input [(ADDR_WIDTH-1):0] read_addr, write_addr,
  input we, clk,
  output [(DATA_WIDTH-1):0] q
);

  localparam DEPTH = (1 << ADDR_WIDTH);

  wire [(DATA_WIDTH-1):0] ram_q;

  // Match the lane FIFO signoff policy here as well so handle storage stays on
  // dedicated M20K blocks instead of LUT/MLAB fabric.
  altsyncram handle_fifo_ram (
    .address_a (write_addr),
    .address_b (read_addr),
    .clock0    (clk),
    .data_a    (data),
    .q_b       (ram_q),
    .wren_a    (we)
  );

  defparam
    handle_fifo_ram.address_reg_b = "CLOCK0",
    handle_fifo_ram.clock_enable_input_a = "BYPASS",
    handle_fifo_ram.clock_enable_input_b = "BYPASS",
    handle_fifo_ram.clock_enable_output_b = "BYPASS",
    handle_fifo_ram.indata_reg_b = "CLOCK0",
    handle_fifo_ram.intended_device_family = "Arria 10",
    handle_fifo_ram.lpm_type = "altsyncram",
    handle_fifo_ram.numwords_a = DEPTH,
    handle_fifo_ram.numwords_b = DEPTH,
    handle_fifo_ram.operation_mode = "DUAL_PORT",
    handle_fifo_ram.outdata_aclr_b = "NONE",
    handle_fifo_ram.outdata_reg_b = "UNREGISTERED",
    handle_fifo_ram.power_up_uninitialized = "FALSE",
    handle_fifo_ram.ram_block_type = "M20K",
    handle_fifo_ram.read_during_write_mode_mixed_ports = "OLD_DATA",
    handle_fifo_ram.width_a = DATA_WIDTH,
    handle_fifo_ram.width_b = DATA_WIDTH,
    handle_fifo_ram.width_byteena_a = 1,
    handle_fifo_ram.widthad_a = ADDR_WIDTH,
    handle_fifo_ram.widthad_b = ADDR_WIDTH;

  assign q = (we && (read_addr == write_addr)) ? data : ram_q;

endmodule
