`include "formal_defs.svh"

module sc_decode_formal_tb;
    (* gclk *) reg gclk;

    reg       f_past_valid = 1'b0;
    reg [1:0] f_reset_sr   = 2'b11;

    (* anyseq *) reg        cmd_accept;
    (* anyseq *) reg [17:0] cmd_addr;
    (* anyseq *) reg [8:0]  cmd_burstcount;

    wire rst = f_reset_sr[1];

    props_sc_decode dut (
        .clk          (gclk),
        .rst          (rst),
        .f_past_valid (f_past_valid),
        .cmd_accept   (cmd_accept),
        .cmd_addr     (cmd_addr),
        .cmd_burstcount(cmd_burstcount)
    );

    always @(posedge gclk) begin
        f_past_valid <= 1'b1;

        if (!f_past_valid) begin
            assume(rst);
        end

        if (f_reset_sr != 2'b00) begin
            f_reset_sr <= {f_reset_sr[0], 1'b0};
        end
    end

endmodule
