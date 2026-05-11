module page_ram #(
  parameter DATA_WIDTH = 40,
  parameter ADDR_WIDTH = 16
) (
  input [(DATA_WIDTH-1):0] data,
  input [(ADDR_WIDTH-1):0] read_addr,
  input [(ADDR_WIDTH-1):0] write_addr,
  input we,
  input clk,
  output [(DATA_WIDTH-1):0] q
);
  localparam DEPTH = (1 << ADDR_WIDTH);

  wire [(DATA_WIDTH-1):0] ram_q;

  // Use an explicit Arria-10 M20K simple dual-port RAM for signoff so Quartus
  // does not remap the deep page store into smaller memory primitives.
  altsyncram page_ram_i (
    .address_a (write_addr),
    .address_b (read_addr),
    .clock0    (clk),
    .data_a    (data),
    .q_b       (ram_q),
    .wren_a    (we)
  );

  defparam
    page_ram_i.address_reg_b = "CLOCK0",
    page_ram_i.clock_enable_input_a = "BYPASS",
    page_ram_i.clock_enable_input_b = "BYPASS",
    page_ram_i.clock_enable_output_b = "BYPASS",
    page_ram_i.indata_reg_b = "CLOCK0",
    page_ram_i.intended_device_family = "Arria 10",
    page_ram_i.lpm_type = "altsyncram",
    page_ram_i.numwords_a = DEPTH,
    page_ram_i.numwords_b = DEPTH,
    page_ram_i.operation_mode = "DUAL_PORT",
    page_ram_i.outdata_aclr_b = "NONE",
    page_ram_i.outdata_reg_b = "UNREGISTERED",
    page_ram_i.power_up_uninitialized = "FALSE",
    page_ram_i.ram_block_type = "M20K",
    page_ram_i.read_during_write_mode_mixed_ports = "OLD_DATA",
    page_ram_i.width_a = DATA_WIDTH,
    page_ram_i.width_b = DATA_WIDTH,
    page_ram_i.width_byteena_a = 1,
    page_ram_i.widthad_a = ADDR_WIDTH,
    page_ram_i.widthad_b = ADDR_WIDTH;

  assign q = (we && (read_addr == write_addr)) ? data : ram_q;
endmodule
