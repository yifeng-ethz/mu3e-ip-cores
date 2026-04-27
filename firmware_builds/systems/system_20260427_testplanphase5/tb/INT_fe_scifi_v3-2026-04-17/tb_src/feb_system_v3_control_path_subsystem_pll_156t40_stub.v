`timescale 1ps/1ps

// Harness-local PLL replacement for long-soak simulation.
//
// The Intel behavioral PLL model keeps its configured absolute output
// frequency even when the testbench stretches the incoming reference clock.
// For cycle-equivalent soak runs we instead derive the control clock directly
// from the scaled refclk so the SC path keeps the same relative timing.
module feb_system_v3_control_path_subsystem_pll_156t40 (
    input  wire refclk,
    input  wire rst,
    output reg  outclk_0,
    output reg  locked
);
    reg [2:0] lock_count;
    reg [1:0] div_count;

    initial begin
        outclk_0  = 1'b0;
        locked    = 1'b0;
        lock_count = 3'd0;
        div_count  = 2'd0;
    end

    always @(posedge refclk or posedge rst) begin
        if (rst) begin
            outclk_0   <= 1'b0;
            locked     <= 1'b0;
            lock_count <= 3'd0;
            div_count  <= 2'd0;
        end else begin
            if (!locked) begin
                if (lock_count == 3'd4) begin
                    locked <= 1'b1;
                end else begin
                    lock_count <= lock_count + 3'd1;
                end
            end

            if (div_count == 2'd1) begin
                div_count <= 2'd0;
                outclk_0  <= ~outclk_0;
            end else begin
                div_count <= div_count + 2'd1;
            end
        end
    end
endmodule
