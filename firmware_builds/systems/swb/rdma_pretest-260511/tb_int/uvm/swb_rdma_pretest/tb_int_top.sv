`timescale 1ns/1ps

module tb_int_top;
    timeunit 1ns;
    timeprecision 1ps;

    import uvm_pkg::*;
    import tb_int_runctl_phy_agent_pkg::*;
    import tb_int_sc_phy_agent_pkg::*;
    import tb_int_swb_stage_pkg::*;
    import tb_int_rdma_rqe_ingress_monitor_pkg::*;
    import tb_int_rdma_cqe_egress_monitor_pkg::*;
    import tb_int_opq_lane_fill_monitor_pkg::*;
    import tb_int_pcie_dma_egress_monitor_pkg::*;
    import tb_int_swb_case_model_pkg::*;
    import tb_int_swb_scoreboard_pkg::*;
    import tb_int_swb_dual_env_pkg::*;
    import tb_int_swb_case_sequences_pkg::*;
    import tb_int_swb_base_test_pkg::*;
    import tb_int_swb_smoke_test_pkg::*;
    import tb_int_swb_selected_tests_pkg::*;
`include "uvm_macros.svh"

    logic clk_50_b2j;
    logic clkusr_100;
    logic pcie_refclk_p;
    logic cpu_reset_n;
    logic pcie_perst_n;
    logic rst;

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

    assign rst = !cpu_reset_n;

    runctl_phy_if       runctl_phy(clk_50_b2j, rst);
    sc_avmm_if          sc_phy(clk_50_b2j, rst);
    rdma_rqe_ingress_if rdma_rqe_ingress(clk_50_b2j, cpu_reset_n);
    rdma_cqe_egress_if  rdma_cqe_egress(clk_50_b2j, cpu_reset_n);
    opq_lane_if         opq_lane0(clk_50_b2j, cpu_reset_n);
    opq_lane_if         opq_lane1(clk_50_b2j, cpu_reset_n);
    opq_lane_if         opq_lane2(clk_50_b2j, cpu_reset_n);
    opq_lane_if         opq_lane3(clk_50_b2j, cpu_reset_n);
    pcie_dma_egress_if  pcie_dma_egress(clk_50_b2j, cpu_reset_n);

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
        runctl_phy.clear();
        sc_phy.clear_master();
        sc_phy.waitrequest = 1'b0;
        rdma_rqe_ingress.clear();
        rdma_cqe_egress.clear();
        opq_lane0.clear();
        opq_lane1.clear();
        opq_lane2.clear();
        opq_lane3.clear();
        pcie_dma_egress.clear();
        repeat (16) @(posedge clk_50_b2j);
        cpu_reset_n  = 1'b1;
        pcie_perst_n = 1'b1;
    end

    always_ff @(posedge clk_50_b2j or negedge cpu_reset_n) begin
        if (!cpu_reset_n) begin
            sc_phy.readdatavalid <= 1'b0;
            sc_phy.readdata <= 32'h0000_0000;
        end else begin
            sc_phy.readdatavalid <= sc_phy.read;
            sc_phy.readdata <= 32'h4849_5354;
        end
    end

`ifdef TB_INT_BIND_REAL_DUT
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
`endif

    initial begin
        uvm_config_db#(virtual runctl_phy_if)::set(null,
                                                   "uvm_test_top.env.nominal.runctl_phy.drv",
                                                   "vif",
                                                   runctl_phy);
        uvm_config_db#(virtual sc_avmm_if)::set(null,
                                                "uvm_test_top.env.nominal.sc_phy.drv",
                                                "vif",
                                                sc_phy);
        uvm_config_db#(virtual rdma_rqe_ingress_if)::set(null,
                                                         "uvm_test_top.env.nominal.rdma_rqe_mon",
                                                         "vif",
                                                         rdma_rqe_ingress);
        uvm_config_db#(virtual rdma_cqe_egress_if)::set(null,
                                                        "uvm_test_top.env.debug.rdma_cqe_mon",
                                                        "vif",
                                                        rdma_cqe_egress);
        uvm_config_db#(virtual opq_lane_if)::set(null,
                                                 "uvm_test_top.env.nominal.opq_lane_mon0",
                                                 "vif",
                                                 opq_lane0);
        uvm_config_db#(virtual opq_lane_if)::set(null,
                                                 "uvm_test_top.env.nominal.opq_lane_mon1",
                                                 "vif",
                                                 opq_lane1);
        uvm_config_db#(virtual opq_lane_if)::set(null,
                                                 "uvm_test_top.env.nominal.opq_lane_mon2",
                                                 "vif",
                                                 opq_lane2);
        uvm_config_db#(virtual opq_lane_if)::set(null,
                                                 "uvm_test_top.env.nominal.opq_lane_mon3",
                                                 "vif",
                                                 opq_lane3);
        uvm_config_db#(virtual pcie_dma_egress_if)::set(null,
                                                        "uvm_test_top.env.nominal.pcie_dma_mon",
                                                        "vif",
                                                        pcie_dma_egress);

        uvm_config_db#(virtual rdma_rqe_ingress_if)::set(null, "uvm_test_top", "rdma_rqe_vif", rdma_rqe_ingress);
        uvm_config_db#(virtual rdma_cqe_egress_if)::set(null, "uvm_test_top", "rdma_cqe_vif", rdma_cqe_egress);
        uvm_config_db#(virtual opq_lane_if)::set(null, "uvm_test_top", "opq_lane0_vif", opq_lane0);
        uvm_config_db#(virtual opq_lane_if)::set(null, "uvm_test_top", "opq_lane1_vif", opq_lane1);
        uvm_config_db#(virtual opq_lane_if)::set(null, "uvm_test_top", "opq_lane2_vif", opq_lane2);
        uvm_config_db#(virtual opq_lane_if)::set(null, "uvm_test_top", "opq_lane3_vif", opq_lane3);
        uvm_config_db#(virtual pcie_dma_egress_if)::set(null, "uvm_test_top", "pcie_dma_vif", pcie_dma_egress);
        run_test();
    end
endmodule
