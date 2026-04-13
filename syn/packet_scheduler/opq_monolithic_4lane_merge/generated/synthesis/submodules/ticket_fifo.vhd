module ticket_fifo
#(parameter DATA_WIDTH=68, parameter ADDR_WIDTH=4)
(
	input [(DATA_WIDTH-1):0] data,
	input [(ADDR_WIDTH-1):0] read_addr, write_addr,
	input we, clk,
	output reg [(DATA_WIDTH-1):0] q
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

`ifndef SYNTHESIS
	integer init_i;
	initial begin
		for (init_i = 0; init_i < (1 << ADDR_WIDTH); init_i = init_i + 1)
			ram[init_i] = {DATA_WIDTH{1'b0}};
	end
`endif

	always @ (posedge clk)
	begin
		// Write
		if (we)
			ram[write_addr] <= data;

		// Read (bypass on same-address read/write).
		if (we && (read_addr == write_addr))
			q <= data;
		else
			q <= ram[read_addr];
	end

endmodule
