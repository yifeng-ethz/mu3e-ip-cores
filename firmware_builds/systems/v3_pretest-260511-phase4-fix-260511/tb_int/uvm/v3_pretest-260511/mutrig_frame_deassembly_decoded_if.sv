// mutrig_frame_deassembly_decoded_if.sv
// Decoded hit_type0 boundary tap for the virtual MuTRiG path.

interface mutrig_frame_deassembly_decoded_if (
    input logic clk,
    input logic rst
);
    logic        valid;
    logic        ready;
    logic [3:0]  lane_id;
    logic [44:0] hit_type0;
    logic [63:0] hit_id;
    logic        hit_id_valid;
    logic [63:0] root_hit_id;
    logic        root_hit_id_valid;
    logic [1:0]  debug_level;

    task automatic clear();
        valid = 1'b0;
        ready = 1'b1;
        lane_id = '0;
        hit_type0 = '0;
        hit_id = '0;
        hit_id_valid = 1'b0;
        root_hit_id = '0;
        root_hit_id_valid = 1'b0;
        debug_level = 2'd0;
    endtask
endinterface
