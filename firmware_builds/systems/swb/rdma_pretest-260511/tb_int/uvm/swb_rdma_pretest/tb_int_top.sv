`timescale 1ns/1ps

`include "rdma_sqe_ingress_if.sv"
`include "opq_lane_if.sv"
`include "pcie_x8_egress_if.sv"

module tb_int_top;
    timeunit 1ns;
    timeprecision 1ps;

    logic clk_50_b2j;
    logic clkusr_100;
    logic pcie_refclk_p;
    logic cpu_reset_n;
    logic pcie_perst_n;

    logic [3:0] button;
    logic [1:0] sw;
    logic [6:0] hex0_d;
    logic [6:0] hex1_d;
    logic [3:0] led;
    logic [3:0] led_bracket;
    logic       sma_clkout;
    logic       sma_clkin;
    logic       rs422_de;
    logic       rs422_din;
    logic       rs422_dout;
    logic       rj45_led_r;

    tri fan_i2c_scl;
    tri fan_i2c_sda;
    tri power_monitor_i2c_scl;
    tri power_monitor_i2c_sda;
    tri temp_i2c_scl;
    tri temp_i2c_sda;
    tri pcie_smbdat;

    logic [26:1] flash_a;
    tri   [31:0] flash_d;
    tri          flash_oe_n;
    logic        flash_we_n;
    logic [1:0]  flash_ce_n;
    logic        flash_adv_n;
    logic        flash_clk;
    logic        flash_reset_n;

    logic [3:0] qsfpa_tx_p;
    logic [3:0] qsfpb_tx_p;
    logic [3:0] qsfpc_tx_p;
    logic [3:0] qsfpd_tx_p;
    logic [3:0] qsfpa_rx_p;
    logic [3:0] qsfpb_rx_p;
    logic [3:0] qsfpc_rx_p;
    logic [3:0] qsfpd_rx_p;
    logic       qsfpa_refclk_p;
    logic       qsfpb_refclk_p;
    logic       qsfpc_refclk_p;
    logic       qsfpd_refclk_p;
    logic       qsfpa_lp_mode;
    logic       qsfpb_lp_mode;
    logic       qsfpc_lp_mode;
    logic       qsfpd_lp_mode;
    logic       qsfpa_mod_sel_n;
    logic       qsfpb_mod_sel_n;
    logic       qsfpc_mod_sel_n;
    logic       qsfpd_mod_sel_n;
    logic       qsfpa_rst_n;
    logic       qsfpb_rst_n;
    logic       qsfpc_rst_n;
    logic       qsfpd_rst_n;

    logic [7:0] pcie_rx_p;
    logic [7:0] pcie_tx_p;
    logic       pcie_smbclk;
    logic       pcie_wake_n;

    rdma_sqe_ingress_if rdma_sqe_ingress(clk_50_b2j, cpu_reset_n);
    opq_lane_if         opq_lane0(clk_50_b2j, cpu_reset_n);
    pcie_x8_egress_if   pcie_x8_egress(clk_50_b2j, cpu_reset_n);

    initial begin
        clk_50_b2j    = 1'b0;
        clkusr_100    = 1'b0;
        pcie_refclk_p = 1'b0;
        sma_clkin     = 1'b0;
        qsfpa_refclk_p = 1'b0;
        qsfpb_refclk_p = 1'b0;
        qsfpc_refclk_p = 1'b0;
        qsfpd_refclk_p = 1'b0;
        forever #10 clk_50_b2j = ~clk_50_b2j;
    end

    always #5  clkusr_100    = ~clkusr_100;
    always #4  pcie_refclk_p = ~pcie_refclk_p;
    always #4  sma_clkin     = ~sma_clkin;
    always #3  qsfpa_refclk_p = ~qsfpa_refclk_p;
    always #3  qsfpb_refclk_p = ~qsfpb_refclk_p;
    always #3  qsfpc_refclk_p = ~qsfpc_refclk_p;
    always #3  qsfpd_refclk_p = ~qsfpd_refclk_p;

    initial begin
        cpu_reset_n  = 1'b0;
        pcie_perst_n = 1'b0;
        button       = 4'hf;
        sw           = 2'b00;
        rs422_din    = 1'b0;
        qsfpa_rx_p   = 4'h0;
        qsfpb_rx_p   = 4'h0;
        qsfpc_rx_p   = 4'h0;
        qsfpd_rx_p   = 4'h0;
        pcie_rx_p    = 8'h00;
        pcie_smbclk  = 1'b0;
        repeat (16) @(posedge clk_50_b2j);
        cpu_reset_n  = 1'b1;
        pcie_perst_n = 1'b1;
    end

    top dut (
        .BUTTON(button),
        .SW(sw),
        .HEX0_D(hex0_d),
        .HEX1_D(hex1_d),
        .LED(led),
        .LED_BRACKET(led_bracket),
        .SMA_CLKOUT(sma_clkout),
        .SMA_CLKIN(sma_clkin),
        .RS422_DE(rs422_de),
        .RS422_DIN(rs422_din),
        .RS422_DOUT(rs422_dout),
        .RJ45_LED_R(rj45_led_r),
        .FAN_I2C_SCL(fan_i2c_scl),
        .FAN_I2C_SDA(fan_i2c_sda),
        .FLASH_A(flash_a),
        .FLASH_D(flash_d),
        .FLASH_OE_n(flash_oe_n),
        .FLASH_WE_n(flash_we_n),
        .FLASH_CE_n(flash_ce_n),
        .FLASH_ADV_n(flash_adv_n),
        .FLASH_CLK(flash_clk),
        .FLASH_RESET_n(flash_reset_n),
        .POWER_MONITOR_I2C_SCL(power_monitor_i2c_scl),
        .POWER_MONITOR_I2C_SDA(power_monitor_i2c_sda),
        .TEMP_I2C_SCL(temp_i2c_scl),
        .TEMP_I2C_SDA(temp_i2c_sda),
        .QSFPA_TX_p(qsfpa_tx_p),
        .QSFPB_TX_p(qsfpb_tx_p),
        .QSFPC_TX_p(qsfpc_tx_p),
        .QSFPD_TX_p(qsfpd_tx_p),
        .QSFPA_RX_p(qsfpa_rx_p),
        .QSFPB_RX_p(qsfpb_rx_p),
        .QSFPC_RX_p(qsfpc_rx_p),
        .QSFPD_RX_p(qsfpd_rx_p),
        .QSFPA_REFCLK_p(qsfpa_refclk_p),
        .QSFPB_REFCLK_p(qsfpb_refclk_p),
        .QSFPC_REFCLK_p(qsfpc_refclk_p),
        .QSFPD_REFCLK_p(qsfpd_refclk_p),
        .QSFPA_LP_MODE(qsfpa_lp_mode),
        .QSFPB_LP_MODE(qsfpb_lp_mode),
        .QSFPC_LP_MODE(qsfpc_lp_mode),
        .QSFPD_LP_MODE(qsfpd_lp_mode),
        .QSFPA_MOD_SEL_n(qsfpa_mod_sel_n),
        .QSFPB_MOD_SEL_n(qsfpb_mod_sel_n),
        .QSFPC_MOD_SEL_n(qsfpc_mod_sel_n),
        .QSFPD_MOD_SEL_n(qsfpd_mod_sel_n),
        .QSFPA_RST_n(qsfpa_rst_n),
        .QSFPB_RST_n(qsfpb_rst_n),
        .QSFPC_RST_n(qsfpc_rst_n),
        .QSFPD_RST_n(qsfpd_rst_n),
        .PCIE_RX_p(pcie_rx_p),
        .PCIE_TX_p(pcie_tx_p),
        .PCIE_PERST_n(pcie_perst_n),
        .PCIE_REFCLK_p(pcie_refclk_p),
        .PCIE_SMBCLK(pcie_smbclk),
        .PCIE_SMBDAT(pcie_smbdat),
        .PCIE_WAKE_n(pcie_wake_n),
        .CLKUSR_100(clkusr_100),
        .CPU_RESET_n(cpu_reset_n),
        .CLK_50_B2J(clk_50_b2j)
    );
endmodule
