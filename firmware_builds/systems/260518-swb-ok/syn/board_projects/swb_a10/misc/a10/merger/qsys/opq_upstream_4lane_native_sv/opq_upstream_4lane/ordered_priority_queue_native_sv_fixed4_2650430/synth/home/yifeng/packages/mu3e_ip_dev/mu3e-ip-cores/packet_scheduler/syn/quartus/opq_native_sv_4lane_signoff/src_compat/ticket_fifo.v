module ticket_fifo
#(parameter DATA_WIDTH = 68, parameter ADDR_WIDTH = 4)
(
  input [(DATA_WIDTH-1):0] data,
  input [(ADDR_WIDTH-1):0] read_addr, write_addr,
  input we, clk,
  output [(DATA_WIDTH-1):0] q
);

  localparam DEPTH = (1 << ADDR_WIDTH);

  wire [(DATA_WIDTH-1):0] ram_q;

  // Keep the standalone signoff ticket FIFOs on M20Ks so small inferred
  // memories do not drift into MLABs and distort the resource/timing picture.
  altsyncram ticket_fifo_ram (
    .address_a (write_addr),
    .address_b (read_addr),
    .clock0    (clk),
    .data_a    (data),
    .q_b       (ram_q),
    .wren_a    (we)
  );

  defparam
    ticket_fifo_ram.address_reg_b = "CLOCK0",
    ticket_fifo_ram.clock_enable_input_a = "BYPASS",
    ticket_fifo_ram.clock_enable_input_b = "BYPASS",
    ticket_fifo_ram.clock_enable_output_b = "BYPASS",
    ticket_fifo_ram.indata_reg_b = "CLOCK0",
    ticket_fifo_ram.intended_device_family = "Arria 10",
    ticket_fifo_ram.lpm_type = "altsyncram",
    ticket_fifo_ram.numwords_a = DEPTH,
    ticket_fifo_ram.numwords_b = DEPTH,
    ticket_fifo_ram.operation_mode = "DUAL_PORT",
    ticket_fifo_ram.outdata_aclr_b = "NONE",
    ticket_fifo_ram.outdata_reg_b = "UNREGISTERED",
    ticket_fifo_ram.power_up_uninitialized = "FALSE",
    ticket_fifo_ram.ram_block_type = "M20K",
    ticket_fifo_ram.read_during_write_mode_mixed_ports = "OLD_DATA",
    ticket_fifo_ram.width_a = DATA_WIDTH,
    ticket_fifo_ram.width_b = DATA_WIDTH,
    ticket_fifo_ram.width_byteena_a = 1,
    ticket_fifo_ram.widthad_a = ADDR_WIDTH,
    ticket_fifo_ram.widthad_b = ADDR_WIDTH;

  assign q = (we && (read_addr == write_addr)) ? data : ram_q;

endmodule
