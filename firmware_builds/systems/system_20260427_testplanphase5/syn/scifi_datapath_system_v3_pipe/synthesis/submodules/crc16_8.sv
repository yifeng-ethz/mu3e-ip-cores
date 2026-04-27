// crc16_8.sv
// CRC-16 calculator for 8-bit inputs
// CRC-16-ANSI, MSBF/normal polynomial 0x8005
// Bit-exact match to MuTRiG ASIC crc16_8.vhd

module crc16_8 (
    input  logic        clk,
    input  logic        rst,
    input  logic        d_valid,
    input  logic [7:0]  din,
    output logic [15:0] crc_reg,
    output logic [7:0]  crc_8
);

    logic [15:0] p_crc, n_crc;
    logic [7:0]  d;

    assign d = din;
    assign crc_reg = ~p_crc;
    assign crc_8   = ~n_crc[15:8];

    // Combinational CRC-16 next-state (polynomial 0x8005, CRC-16-ANSI)
    // Matches the VHDL exactly
    always_comb begin
        n_crc[0]  = p_crc[15]^d[7] ^ p_crc[14]^d[6] ^ p_crc[13]^d[5] ^ p_crc[12]^d[4] ^
                    p_crc[11]^d[3] ^ p_crc[10]^d[2] ^ p_crc[9]^d[1]  ^ p_crc[8]^d[0];
        n_crc[1]  = p_crc[15]^d[7] ^ p_crc[14]^d[6] ^ p_crc[13]^d[5] ^ p_crc[12]^d[4] ^
                    p_crc[11]^d[3] ^ p_crc[10]^d[2] ^ p_crc[9]^d[1];
        n_crc[2]  = p_crc[9]^d[1]  ^ p_crc[8]^d[0];
        n_crc[3]  = p_crc[10]^d[2] ^ p_crc[9]^d[1];
        n_crc[4]  = p_crc[11]^d[3] ^ p_crc[10]^d[2];
        n_crc[5]  = p_crc[12]^d[4] ^ p_crc[11]^d[3];
        n_crc[6]  = p_crc[13]^d[5] ^ p_crc[12]^d[4];
        n_crc[7]  = p_crc[14]^d[6] ^ p_crc[13]^d[5];
        n_crc[8]  = p_crc[15]^d[7] ^ p_crc[14]^d[6] ^ p_crc[0];
        n_crc[9]  = p_crc[15]^d[7] ^ p_crc[1];
        n_crc[10] = p_crc[2];
        n_crc[11] = p_crc[3];
        n_crc[12] = p_crc[4];
        n_crc[13] = p_crc[5];
        n_crc[14] = p_crc[6];
        n_crc[15] = p_crc[15]^d[7] ^ p_crc[14]^d[6] ^ p_crc[13]^d[5] ^ p_crc[12]^d[4] ^
                    p_crc[11]^d[3] ^ p_crc[10]^d[2] ^ p_crc[9]^d[1]  ^ p_crc[8]^d[0]  ^ p_crc[7];
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            p_crc <= 16'hFFFF;
        end else if (d_valid) begin
            p_crc <= n_crc;
        end
    end

endmodule
