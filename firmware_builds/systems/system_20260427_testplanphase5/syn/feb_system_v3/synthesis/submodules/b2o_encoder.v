module b2o_encoder 
#(parameter INPUT_W=6, OUTPUT_W=64)
(
	input  [INPUT_W-1:0] binary_code,
	output wire [OUTPUT_W-1:0] onehot_code
);

	
	assign	onehot_code = 1 << binary_code;
	
endmodule 