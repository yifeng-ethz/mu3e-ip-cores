// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


`timescale 1 ps / 1 ps

module altera_lvds_core14
#(
    parameter NUM_CHANNELS = 1,
    parameter J_FACTOR = 10,
    parameter EXTERNAL_PLL = "false",
    parameter USE_BITSLIP = "false",
    parameter TX_OUTCLOCK_NON_STD_PHASE_SHIFT = "false", 
    parameter SILICON_REV = "20nm5",
       
    parameter pll_input_clock_frequency = "0 ps",
    parameter pll_vco_clock_frequency = "0 ps", 
    
    parameter pll_output_clock_frequency_0 = "0.0 MHz", 
    parameter pll_output_clock_frequency_1 = "0.0 MHz", 
    parameter pll_output_clock_frequency_2 = "0.0 MHz", 
    parameter pll_output_clock_frequency_3 = "0.0 MHz", 
    parameter pll_output_clock_frequency_4 = "0.0 MHz", 
    parameter pll_output_clock_frequency_5 = "0.0 MHz", 
    parameter pll_output_clock_frequency_6 = "0.0 MHz", 
    parameter pll_output_clock_frequency_7 = "0.0 MHz", 
    parameter pll_output_clock_frequency_8 = "0.0 MHz", 
    parameter pll_output_duty_cycle_0 = 50, 
    parameter pll_output_duty_cycle_1 = 50, 
    parameter pll_output_duty_cycle_2 = 50, 
    parameter pll_output_duty_cycle_3 = 50, 
    parameter pll_output_duty_cycle_4 = 50, 
    parameter pll_output_duty_cycle_5 = 50, 
    parameter pll_output_duty_cycle_6 = 50, 
    parameter pll_output_duty_cycle_7 = 50, 
    parameter pll_output_duty_cycle_8 = 50, 
    parameter pll_output_phase_shift_0 = "0 ps", 
    parameter pll_output_phase_shift_1 = "0 ps", 
    parameter pll_output_phase_shift_2 = "0 ps", 
    parameter pll_output_phase_shift_3 = "0 ps", 
    parameter pll_output_phase_shift_4 = "0 ps", 
    parameter pll_output_phase_shift_5 = "0 ps", 
    parameter pll_output_phase_shift_6 = "0 ps", 
    parameter pll_output_phase_shift_7 = "0 ps", 
    parameter pll_output_phase_shift_8 = "0 ps", 
    
    parameter SERDES_DPA_MODE = "OFF_MODE",
    parameter ALIGN_TO_RISING_EDGE_ONLY = "false",
    parameter LOSE_LOCK_ON_ONE_CHANGE = "false",
    parameter RESET_FIFO_AT_FIRST_LOCK = "false",
    parameter ENABLE_CLOCK_PIN_MODE = "false",
    parameter LOOPBACK_MODE = 0,
    parameter NET_PPM_VARIATION = "0",
    parameter IS_NEGATIVE_PPM_DRIFT = "false",
    parameter REGISTER_PARALLEL_DATA = "false",
    parameter USE_FALLING_CLOCK_EDGE = "false", 
    parameter TX_OUTCLOCK_ENABLED = "false",
    parameter TX_OUTCLOCK_BYPASS_SERIALIZER = "false",
    parameter TX_OUTCLOCK_USE_FALLING_CLOCK_EDGE = "false", 
    parameter TX_REGISTER_CLOCK = "tx_coreclock", 
    parameter TX_OUTCLOCK_DIV_WORD = 0, 
    parameter VCO_DIV_EXPONENT = 0,
    parameter VCO_FREQUENCY = 0,
    parameter RX_BITSLIP_ROLLOVER = J_FACTOR,

    parameter pll_clk_out_en_0 = "false",
    parameter pll_clk_out_en_1 = "false",
    parameter pll_clk_out_en_2 = "false",
    parameter pll_clk_out_en_3 = "false",
    parameter pll_clk_out_en_4 = "false",
    parameter pll_clk_out_en_5 = "false",
    parameter pll_clk_out_en_6 = "false",
    parameter pll_clk_out_en_7 = "false",
    parameter pll_clk_out_en_8 = "false",
    parameter m_cnt_hi_div = 3,
    parameter m_cnt_lo_div = 2,
    parameter n_cnt_hi_div = 256,
    parameter n_cnt_lo_div = 256,
    parameter m_cnt_bypass_en = "false",
    parameter n_cnt_bypass_en = "true",
    parameter m_cnt_odd_div_duty_en = "true",
    parameter n_cnt_odd_div_duty_en = "false",
    parameter c_cnt_hi_div0 = 256,
    parameter c_cnt_lo_div0 = 256,
    parameter c_cnt_prst0 = 1,
    parameter c_cnt_ph_mux_prst0 = 4,
    parameter c_cnt_bypass_en0 = "true",
    parameter c_cnt_odd_div_duty_en0 = "false",
    parameter c_cnt_hi_div1 = 5,
    parameter c_cnt_lo_div1 = 5,
    parameter c_cnt_prst1 = 1,
    parameter c_cnt_ph_mux_prst1 = 4,
    parameter c_cnt_bypass_en1 = "false",
    parameter c_cnt_odd_div_duty_en1 = "false",
    parameter c_cnt_hi_div2 = 1,
    parameter c_cnt_lo_div2 = 9,
    parameter c_cnt_prst2 = 9,
    parameter c_cnt_ph_mux_prst2 = 0,
    parameter c_cnt_bypass_en2 = "false",
    parameter c_cnt_odd_div_duty_en2 = "false",
    parameter c_cnt_hi_div3 = 256,
    parameter c_cnt_lo_div3 = 256,
    parameter c_cnt_prst3 = 1,
    parameter c_cnt_ph_mux_prst3 = 0,
    parameter c_cnt_bypass_en3 = "true",
    parameter c_cnt_odd_div_duty_en3 = "false",
    parameter c_cnt_hi_div4 = 256,
    parameter c_cnt_lo_div4 = 256,
    parameter c_cnt_prst4 = 1,
    parameter c_cnt_ph_mux_prst4 = 0,
    parameter c_cnt_bypass_en4 = "true",
    parameter c_cnt_odd_div_duty_en4 = "false",
    parameter c_cnt_hi_div5 = 256,
    parameter c_cnt_lo_div5 = 256,
    parameter c_cnt_prst5 = 1,
    parameter c_cnt_ph_mux_prst5 = 0,
    parameter c_cnt_bypass_en5 = "true",
    parameter c_cnt_odd_div_duty_en5 = "false",
    parameter c_cnt_hi_div6 = 256,
    parameter c_cnt_lo_div6 = 256,
    parameter c_cnt_prst6 = 1,
    parameter c_cnt_ph_mux_prst6 = 0,
    parameter c_cnt_bypass_en6 = "true",
    parameter c_cnt_odd_div_duty_en6 = "false",
    parameter c_cnt_hi_div7 = 256,
    parameter c_cnt_lo_div7 = 256,
    parameter c_cnt_prst7 = 1,
    parameter c_cnt_ph_mux_prst7 = 0,
    parameter c_cnt_bypass_en7 = "true",
    parameter c_cnt_odd_div_duty_en7 = "false",
    parameter c_cnt_hi_div8 = 256,
    parameter c_cnt_lo_div8 = 256,
    parameter c_cnt_prst8 = 1,
    parameter c_cnt_ph_mux_prst8 = 0,
    parameter c_cnt_bypass_en8 = "true",
    parameter c_cnt_odd_div_duty_en8 = "false",
    parameter pll_cp_current = "pll_cp_setting0",
    parameter pll_bwctrl = "pll_bw_res_setting0",
    parameter pll_fbclk_mux_1 = "pll_fbclk_mux_1_lvds",
    parameter pll_fbclk_mux_2 = "pll_fbclk_mux_2_fb_1",
    parameter pll_m_cnt_in_src = "c_m_cnt_in_src_ph_mux_clk",
    parameter pll_bw_sel = "",
    parameter pll_bw_ctrl = "",
    parameter pll_cp_setting = ""

) (
    input                                               ext_coreclock, 
    input                                               ext_fclk,
    input                                               ext_loaden,
    input                                               ext_tx_outclock_fclk,
    input                                               ext_tx_outclock_loaden,
    input       [7:0]                                   ext_vcoph,
    input                                               ext_pll_locked,
    input                                               inclock, 
    input       [NUM_CHANNELS-1:0]                      loopback_in,
    input                                               pll_areset,
    input       [NUM_CHANNELS-1:0]                      rx_bitslip_reset,
    input       [NUM_CHANNELS-1:0]                      rx_bitslip_ctrl,
    input       [NUM_CHANNELS-1:0]                      rx_dpa_reset,
    input       [NUM_CHANNELS-1:0]                      rx_dpa_hold,
    input       [NUM_CHANNELS-1:0]                      rx_fifo_reset,
    input       [NUM_CHANNELS-1:0]                      rx_in,
    input       [NUM_CHANNELS*J_FACTOR-1:0]             tx_in,

    
    output      [NUM_CHANNELS-1:0]                      rx_bitslip_max, 
    output      [NUM_CHANNELS-1:0]                      loopback_out,
    output      [NUM_CHANNELS-1:0]                      rx_dpa_locked,
    output      [NUM_CHANNELS-1:0]                      rx_divfwdclk, 
    output      [NUM_CHANNELS*J_FACTOR-1:0]             rx_out,
    output                                              rx_coreclock,
    output                                              tx_coreclock, 
    output      [NUM_CHANNELS-1:0]                      tx_out,
    output                                              tx_outclock,
    output                                              pll_locked,
    output                                              pll_extra_clock0,
    output                                              pll_extra_clock1,
    output                                              pll_extra_clock2,
    output                                              pll_extra_clock3
);

    wire                                                clock_tree_loaden;
    wire                                                clock_tree_fclk;
    wire                                                tx_outclock_fclk;
    wire                                                pll_tx_outclock_fclk;
    wire                                                pll_tx_outclock_loaden;
    wire                                                fclk;    
    wire                                                loaden;    
    wire        [7:0]                                   vcoph;   
    wire                                                coreclock; 
    wire                                                dprio_clk; 
    wire                                                dprio_rst_n; 
    wire        [NUM_CHANNELS-1:0]                      rx_dpa_reset_internal;

    wire                                                pll_areset_coreclock;
    wire        [NUM_CHANNELS-1:0]                      rx_dpa_hold_wire;


    localparam PLL_COMPENSATION_MODE = (SERDES_DPA_MODE == "non_dpa_mode") ? "lvds" : "direct";
    localparam SYNC_STAGES = 3;
    localparam DPRIO_ENABLED = "false";
    
    assign rx_coreclock  = coreclock; 
    assign tx_coreclock  = coreclock; 
    
    generate
        if (EXTERNAL_PLL == "true")
        begin : breakout_clock_connections
            assign fclk                     = ext_fclk; 
            assign loaden                   = ext_loaden; 
            assign vcoph                    = ext_vcoph; 
            assign coreclock                = ext_coreclock;
            assign pll_tx_outclock_fclk     = ext_tx_outclock_fclk;
            assign pll_tx_outclock_loaden   = ext_tx_outclock_loaden;
            assign pll_locked               = ext_pll_locked;
        end
        else
        begin : internal_pll 
            wire [8:0] pll_outclock;
            wire [1:0] pll_lvds_clk;
            wire [1:0] pll_loaden;
            
            if (SERDES_DPA_MODE == "tx_mode")
            begin
                assign fclk   = pll_lvds_clk[1]; 
                assign loaden = pll_loaden[1];
                
                if (TX_OUTCLOCK_ENABLED == "true" && TX_OUTCLOCK_NON_STD_PHASE_SHIFT == "true")
                begin
                    assign pll_tx_outclock_fclk   = pll_lvds_clk[0];
                    assign pll_tx_outclock_loaden = pll_loaden[0];
                end
            end
            else 
            begin
                assign fclk = pll_lvds_clk[0]; 
                if (SERDES_DPA_MODE != "dpa_mode_cdr")
                    assign loaden = pll_loaden[0];
            end
            
            assign coreclock        = pll_outclock[4];
            assign pll_extra_clock0 = pll_outclock[5];
            assign pll_extra_clock1 = pll_outclock[6];
            assign pll_extra_clock2 = pll_outclock[7];
            assign pll_extra_clock3 = pll_outclock[8];
        
            stratix10_altera_iopll #(
                .reference_clock_frequency       (pll_input_clock_frequency),
                .pll_type                        ("S10_Physical"),
                .pll_subtype                     ("General"),
                .number_of_clocks                (9),
                .operation_mode                  (PLL_COMPENSATION_MODE),
                .output_clock_frequency0         (pll_output_clock_frequency_0),
                .phase_shift0                    (pll_output_phase_shift_0),
                .duty_cycle0                     (pll_output_duty_cycle_0),
                .output_clock_frequency1         (pll_output_clock_frequency_1),
                .phase_shift1                    (pll_output_phase_shift_1),
                .duty_cycle1                     (pll_output_duty_cycle_1),
                .output_clock_frequency2         (pll_output_clock_frequency_2),
                .phase_shift2                    (pll_output_phase_shift_2),
                .duty_cycle2                     (pll_output_duty_cycle_2),
                .output_clock_frequency3         (pll_output_clock_frequency_3),
                .phase_shift3                    (pll_output_phase_shift_3),
                .duty_cycle3                     (pll_output_duty_cycle_3),
                .output_clock_frequency4         (pll_output_clock_frequency_4),
                .phase_shift4                    (pll_output_phase_shift_4),
                .duty_cycle4                     (pll_output_duty_cycle_4),
                .output_clock_frequency5         (pll_output_clock_frequency_5),
                .phase_shift5                    (pll_output_phase_shift_5),
                .duty_cycle5                     (pll_output_duty_cycle_5),
                .output_clock_frequency6         (pll_output_clock_frequency_6),
                .phase_shift6                    (pll_output_phase_shift_6),
                .duty_cycle6                     (pll_output_duty_cycle_6),
                .output_clock_frequency7         (pll_output_clock_frequency_7),
                .phase_shift7                    (pll_output_phase_shift_7),
                .duty_cycle7                     (pll_output_duty_cycle_7),
                .output_clock_frequency8         (pll_output_clock_frequency_8),
                .phase_shift8                    (pll_output_phase_shift_8),
                .duty_cycle8                     (pll_output_duty_cycle_8),
                .m_cnt_hi_div                    (m_cnt_hi_div),
                .m_cnt_lo_div                    (m_cnt_lo_div),
                .m_cnt_bypass_en                 (m_cnt_bypass_en),
                .m_cnt_odd_div_duty_en           (m_cnt_odd_div_duty_en),
                .n_cnt_hi_div                    (n_cnt_hi_div),
                .n_cnt_lo_div                    (n_cnt_lo_div),
                .n_cnt_bypass_en                 (n_cnt_bypass_en),
                .n_cnt_odd_div_duty_en           (n_cnt_odd_div_duty_en),
                .c_cnt_hi_div0                   (c_cnt_hi_div0), 
                .c_cnt_lo_div0                   (c_cnt_lo_div0),
                .c_cnt_bypass_en0                (c_cnt_bypass_en0),
                .c_cnt_in_src0                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en0          (c_cnt_odd_div_duty_en0),
                .c_cnt_prst0                     (c_cnt_prst0),
                .c_cnt_ph_mux_prst0              (c_cnt_ph_mux_prst0),
                .c_cnt_hi_div1                   (c_cnt_hi_div1), 
                .c_cnt_lo_div1                   (c_cnt_lo_div1),
                .c_cnt_bypass_en1                (c_cnt_bypass_en1),
                .c_cnt_in_src1                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en1          (c_cnt_odd_div_duty_en1),
                .c_cnt_prst1                     (c_cnt_prst1),
                .c_cnt_ph_mux_prst1              (c_cnt_ph_mux_prst1),
                .c_cnt_hi_div2                   (c_cnt_hi_div2), 
                .c_cnt_lo_div2                   (c_cnt_lo_div2),
                .c_cnt_bypass_en2                (c_cnt_bypass_en2),
                .c_cnt_in_src2                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en2          (c_cnt_odd_div_duty_en2),
                .c_cnt_prst2                     (c_cnt_prst2),
                .c_cnt_ph_mux_prst2              (c_cnt_ph_mux_prst2),
                .c_cnt_hi_div3                   (c_cnt_hi_div3), 
                .c_cnt_lo_div3                   (c_cnt_lo_div3),
                .c_cnt_bypass_en3                (c_cnt_bypass_en3),
                .c_cnt_in_src3                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en3          (c_cnt_odd_div_duty_en3),
                .c_cnt_prst3                     (c_cnt_prst3),
                .c_cnt_ph_mux_prst3              (c_cnt_ph_mux_prst3),
                .c_cnt_hi_div4                   (c_cnt_hi_div4), 
                .c_cnt_lo_div4                   (c_cnt_lo_div4),
                .c_cnt_bypass_en4                (c_cnt_bypass_en4),
                .c_cnt_in_src4                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en4          (c_cnt_odd_div_duty_en4),
                .c_cnt_prst4                     (c_cnt_prst4),
                .c_cnt_ph_mux_prst4              (c_cnt_ph_mux_prst4),
                .c_cnt_hi_div5                   (c_cnt_hi_div5), 
                .c_cnt_lo_div5                   (c_cnt_lo_div5),
                .c_cnt_bypass_en5                (c_cnt_bypass_en5),
                .c_cnt_in_src5                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en5          (c_cnt_odd_div_duty_en5),
                .c_cnt_prst5                     (c_cnt_prst5),
                .c_cnt_ph_mux_prst5              (c_cnt_ph_mux_prst5),
                .c_cnt_hi_div6                   (c_cnt_hi_div6), 
                .c_cnt_lo_div6                   (c_cnt_lo_div6),
                .c_cnt_bypass_en6                (c_cnt_bypass_en6),
                .c_cnt_in_src6                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en6          (c_cnt_odd_div_duty_en6),
                .c_cnt_prst6                     (c_cnt_prst6),
                .c_cnt_ph_mux_prst6              (c_cnt_ph_mux_prst6),
                .c_cnt_hi_div7                   (c_cnt_hi_div7), 
                .c_cnt_lo_div7                   (c_cnt_lo_div7),
                .c_cnt_bypass_en7                (c_cnt_bypass_en7),
                .c_cnt_in_src7                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en7          (c_cnt_odd_div_duty_en7),
                .c_cnt_prst7                     (c_cnt_prst7),
                .c_cnt_ph_mux_prst7              (c_cnt_ph_mux_prst7),
                .c_cnt_hi_div8                   (c_cnt_hi_div8), 
                .c_cnt_lo_div8                   (c_cnt_lo_div8),
                .c_cnt_bypass_en8                (c_cnt_bypass_en8),
                .c_cnt_in_src8                   ("ph_mux_clk"),
                .c_cnt_odd_div_duty_en8          (c_cnt_odd_div_duty_en8),
                .c_cnt_prst8                     (c_cnt_prst8),
                .c_cnt_ph_mux_prst8              (c_cnt_ph_mux_prst8),
                .merging_permitted               ("true"),
                .pll_slf_rst                     ("false"),
                .pll_output_clk_frequency        (pll_vco_clock_frequency),
                .pll_cp_current                  (pll_cp_current),
                .pll_bwctrl                      (pll_bwctrl),
                .pll_fbclk_mux_1                 (pll_fbclk_mux_1),
                .pll_fbclk_mux_2                 (pll_fbclk_mux_2),
                .pll_m_cnt_in_src                (pll_m_cnt_in_src),
                .pll_clkin_0_src                 ("clk_0"),
                .pll_clkin_1_src                 ("clk_0"),
                .pll_clk_loss_sw_en              ("false"),
                .pll_auto_clk_sw_en              ("false"),
                .pll_manu_clk_sw_en              ("false"), 
                .pll_clk_sw_dly                  (0),
                .pll_extclk_0_cnt_src            ("pll_extclk_cnt_src_vss"),	
                .pll_extclk_1_cnt_src            ("pll_extclk_cnt_src_vss")
            ) pll_inst ( 
                .refclk(inclock),
                .rst(pll_areset),
                
                .outclk(pll_outclock),
                .locked(pll_locked),
                .phout(vcoph),
                .lvds_clk(pll_lvds_clk),
                .loaden(pll_loaden),
                
                .refclk1(1'b0),
                .fbclk(1'b0),
                .phase_en(1'b0),
                .updn(1'b0),
                .num_phase_shifts(3'b000),
                .scanclk(1'b0),
                .cntsel(5'b00000),
                .reconfig_to_pll(30'd0),
                .extswitch(1'b0),
                .adjpllin(1'b0)
            );
        end
    endgenerate     

    
    

    generate 
        if  (ENABLE_CLOCK_PIN_MODE == "true" && (SERDES_DPA_MODE == "tx_mode" || SERDES_DPA_MODE == "non_dpa_mode")
            || SERDES_DPA_MODE == "dpa_mode_cdr") 
        begin : clock_pin_lvds_clock_tree
            fourteennm_lvds_clock_tree lvds_clock_tree_inst (
                .lvdsfclk_in(fclk),
                .lvdsfclk_out(clock_tree_fclk)
                );
        end
        else if (SERDES_DPA_MODE == "tx_mode" || SERDES_DPA_MODE == "non_dpa_mode" || SERDES_DPA_MODE == "dpa_mode_fifo")
        begin : default_lvds_clock_tree  
                fourteennm_lvds_clock_tree lvds_clock_tree_inst (
                .lvdsfclk_in(fclk),
                .loaden_in(loaden),
                .lvdsfclk_out(clock_tree_fclk),
                .loaden_out(clock_tree_loaden)
                );
        end
    endgenerate 

    generate 
       if (SERDES_DPA_MODE == "non_dpa_mode" || SERDES_DPA_MODE == "dpa_mode_fifo" || SERDES_DPA_MODE == "dpa_mode_cdr" || SERDES_DPA_MODE == "tx_mode" && TX_REGISTER_CLOCK == "tx_coreclock")
       begin
           reset_synchronizer_active_high pll_areset_sync_coreclk (
               .async_reset(pll_areset),
               .clock(coreclock),
               .sync_reset(pll_areset_coreclock)
           );
       end
       else if (SERDES_DPA_MODE == "tx_mode")
       begin
           reset_synchronizer_active_high pll_areset_sync_coreclk (
               .async_reset(pll_areset),
               .clock(inclock),
               .sync_reset(pll_areset_coreclock)
           );
       end
    endgenerate

    genvar CH_INDEX;
    generate
        for (CH_INDEX=0;CH_INDEX<NUM_CHANNELS;CH_INDEX=CH_INDEX+1)
        begin : channels
            if (SERDES_DPA_MODE == "tx_mode")
            begin : tx                
                reg [J_FACTOR-1:0] tx_reg /* synthesis syn_preserve=1*/ ;
                wire [9:0] inv_tx_in = tx_in[(J_FACTOR*(CH_INDEX+1)-1):J_FACTOR*CH_INDEX];
                wire tx_core_reg_clk = (TX_REGISTER_CLOCK == "tx_coreclock")? coreclock : inclock;
                
                genvar i; 
                for (i=0; i<J_FACTOR; i=i+1)
                begin : input_reg
                    always @(posedge tx_core_reg_clk or posedge pll_areset_coreclock)
                    begin
                        if (pll_areset_coreclock == 1'b1)
                            tx_reg[i] <= 1'b0; 
                        else
                            tx_reg[i] <= inv_tx_in[J_FACTOR-1-i];
                    end     
                end
                fourteennm_io_serdes_dpa #(
                    .mode(SERDES_DPA_MODE),
                    .data_width(J_FACTOR),
                    .enable_clock_pin_mode(ENABLE_CLOCK_PIN_MODE),
                    .loopback_mode(LOOPBACK_MODE),
                    .vco_frequency(VCO_FREQUENCY),
                    .silicon_rev(SILICON_REV)
                ) serdes_dpa_inst (
                    .fclk(clock_tree_fclk),
                    .loaden(clock_tree_loaden),
                    .txdata(tx_reg),
                    .loopbackin(loopback_in[CH_INDEX]), 
                    .lvdsout(tx_out[CH_INDEX]),
                    .loopbackout(loopback_out[CH_INDEX])
                );
            end 
            else if (SERDES_DPA_MODE == "non_dpa_mode")
            begin : rx_non_dpa
                wire [9:0] inv_rx_data;
                reg [J_FACTOR-1:0] rx_reg /* synthesis syn_preserve=1*/; 
                wire rx_bitslip_max_wire;

                fourteennm_io_serdes_dpa #(
                    .mode(SERDES_DPA_MODE),
                    .bitslip_rollover(RX_BITSLIP_ROLLOVER-1),
                    .data_width(J_FACTOR),
                    .enable_clock_pin_mode(ENABLE_CLOCK_PIN_MODE),
                    .loopback_mode(LOOPBACK_MODE),
                    .vco_frequency(VCO_FREQUENCY),
                    .silicon_rev(SILICON_REV)
                ) serdes_dpa_inst (
                    .bitslipcntl(rx_bitslip_ctrl[CH_INDEX]),
                    .bitslipreset(pll_areset|rx_bitslip_reset[CH_INDEX]),
                    .fclk(clock_tree_fclk),
                    .loaden(clock_tree_loaden),
                    .lvdsin(rx_in[CH_INDEX]),
                    .loopbackin(loopback_in[CH_INDEX]),
                    .bitslipmax(rx_bitslip_max_wire),
                    .rxdata(inv_rx_data), 
                    .loopbackout(loopback_out[CH_INDEX])
                );

                genvar i; 
                for (i=0; i<J_FACTOR; i=i+1)
                begin : output_reg 
                    always @(posedge coreclock or posedge pll_areset_coreclock)
                    begin
                        if (pll_areset_coreclock)
                            rx_reg[J_FACTOR-1-i] <= 1'b0; 
                        else 
                            rx_reg[J_FACTOR-1-i] <= inv_rx_data[J_FACTOR-1-i];
                    end
                end

                assign rx_out[(J_FACTOR*(CH_INDEX+1)-1):J_FACTOR*CH_INDEX] = rx_reg; 
                
                data_synchronizer #(.SYNC_LENGTH(SYNC_STAGES)) rx_bitslip_max_sync_inst (
                    .data_in(rx_bitslip_max_wire),
                    .clock(coreclock),
                    .reset(pll_areset_coreclock),
                    .data_out(rx_bitslip_max[CH_INDEX])
                ); 
           end
           else if (SERDES_DPA_MODE == "dpa_mode_fifo")
           begin : dpa_fifo
                wire [9:0] inv_rx_data;
                reg [J_FACTOR-1:0] rx_reg /* synthesis syn_preserve=1*/; 
                wire rx_bitslip_max_wire;
                wire rx_dpa_locked_wire;

                fourteennm_io_serdes_dpa #(
                    .mode(SERDES_DPA_MODE),
                    .align_to_rising_edge_only(ALIGN_TO_RISING_EDGE_ONLY),
                    .bitslip_rollover(RX_BITSLIP_ROLLOVER-1),
                    .data_width(J_FACTOR),
                    .lose_lock_on_one_change(LOSE_LOCK_ON_ONE_CHANGE),
                    .reset_fifo_at_first_lock(RESET_FIFO_AT_FIRST_LOCK),
                    .vco_div_exponent(VCO_DIV_EXPONENT),
                    .loopback_mode(LOOPBACK_MODE),
                    .vco_frequency(VCO_FREQUENCY),
                    .silicon_rev(SILICON_REV)
                ) serdes_dpa_inst (
                    .bitslipcntl(rx_bitslip_ctrl[CH_INDEX]),
                    .bitslipreset(pll_areset|rx_bitslip_reset[CH_INDEX]),
                    .dpahold(rx_dpa_hold[CH_INDEX]),
                    .dpareset(pll_areset|rx_dpa_reset_internal[CH_INDEX]),
                    .fclk(clock_tree_fclk),
                    .dpafiforeset(pll_areset|rx_fifo_reset[CH_INDEX]),
                    .loaden(clock_tree_loaden),
                    .lvdsin(rx_in[CH_INDEX]),
                    .dpaclk(vcoph),
                    .loopbackin(loopback_in[CH_INDEX]),
                    .bitslipmax(rx_bitslip_max_wire),
                    .dpalock(rx_dpa_locked_wire),
                    .rxdata(inv_rx_data), 
                    .dprio_clk(dprio_clk),
                    .dprio_rst_n(dprio_rst_n),
                    .loopbackout(loopback_out[CH_INDEX])
                );

                genvar i; 
                for (i=0; i<J_FACTOR; i=i+1)
                begin : output_reg 
                    always @(posedge coreclock or posedge pll_areset_coreclock)
                    begin
                        if (pll_areset_coreclock)
                            rx_reg[J_FACTOR-1-i] <= 1'b0; 
                        else 
                            rx_reg[J_FACTOR-1-i] <= inv_rx_data[J_FACTOR-1-i];
                    end
                end

                assign rx_out[(J_FACTOR*(CH_INDEX+1)-1):J_FACTOR*CH_INDEX] = rx_reg; 
                
                data_synchronizer #(.SYNC_LENGTH(SYNC_STAGES)) rx_bitslip_max_sync_inst (
                    .data_in(rx_bitslip_max_wire),
                    .clock(coreclock),
                    .reset(pll_areset_coreclock),
                    .data_out(rx_bitslip_max[CH_INDEX])
                ); 

                data_synchronizer #(.SYNC_LENGTH(SYNC_STAGES)) rx_dpa_locked_sync_inst (
                    .data_in(rx_dpa_locked_wire),
                    .clock(coreclock),
                    .reset(pll_areset_coreclock),
                    .data_out(rx_dpa_locked[CH_INDEX])
                ); 
                
           end
           else if (SERDES_DPA_MODE == "dpa_mode_cdr")
           begin : soft_cdr
                wire [9:0] rx_data; 
                wire divfwdclk;
                reg [J_FACTOR-1:0] cdr_sync_reg /* synthesis syn_preserve=1*/;
                reg [J_FACTOR-1:0] rx_reg /* synthesis syn_preserve=1*/; 
                wire rx_bitslip_max_wire;
                wire rx_dpa_locked_wire;
                wire pll_areset_divfwdclk;
                wire pll_areset_rxdivfwdclk;

                fourteennm_io_serdes_dpa #(
                    .mode(SERDES_DPA_MODE),
                    .align_to_rising_edge_only(ALIGN_TO_RISING_EDGE_ONLY),
                    .bitslip_rollover(RX_BITSLIP_ROLLOVER-1),
                    .data_width(J_FACTOR),
                    .lose_lock_on_one_change(LOSE_LOCK_ON_ONE_CHANGE),
                    .reset_fifo_at_first_lock(RESET_FIFO_AT_FIRST_LOCK),
                    .enable_clock_pin_mode(ENABLE_CLOCK_PIN_MODE),
                    .loopback_mode(LOOPBACK_MODE),
                    .net_ppm_variation(NET_PPM_VARIATION),
                    .vco_div_exponent(VCO_DIV_EXPONENT),
                    .is_negative_ppm_drift(IS_NEGATIVE_PPM_DRIFT),
                    .vco_frequency(VCO_FREQUENCY),
                    .silicon_rev(SILICON_REV)
                ) serdes_dpa_inst (
                    .bitslipcntl(rx_bitslip_ctrl[CH_INDEX]),
                    .bitslipreset(pll_areset|rx_bitslip_reset[CH_INDEX]),
                    .dpahold(rx_dpa_hold[CH_INDEX]),
                    .dpareset(pll_areset|rx_dpa_reset_internal[CH_INDEX]),
                    .fclk(clock_tree_fclk), 
                    .lvdsin(rx_in[CH_INDEX]),
                    .dpaclk(vcoph),
                    .loopbackin(loopback_in[CH_INDEX]),
                    .bitslipmax(rx_bitslip_max_wire),
                    .dpalock(rx_dpa_locked_wire),
                    .rxdata(rx_data),
                    .pclk(divfwdclk), 
                    .dprio_clk(dprio_clk),
                    .dprio_rst_n(dprio_rst_n),
                    .loopbackout(loopback_out[CH_INDEX])
                );
                assign rx_divfwdclk[CH_INDEX] = ~divfwdclk;  

                reset_synchronizer_active_high pll_areset_sync_divfwdclk (
                    .async_reset(pll_areset),
                    .clock(divfwdclk),
                    .sync_reset(pll_areset_divfwdclk)
                );

                genvar i; 
                for (i=0; i<J_FACTOR; i=i+1)
                begin : cdr_sync
                    always @(posedge divfwdclk or posedge pll_areset_divfwdclk)
                    begin
                        if (pll_areset_divfwdclk)
                            cdr_sync_reg[i] <= 1'b0; 
                        else 
                            cdr_sync_reg[i] <= rx_data[i];
                    end
                end

                reset_synchronizer_active_high pll_areset_sync_rxdivfwdclk (
                    .async_reset(pll_areset),
                    .clock(rx_divfwdclk[CH_INDEX]),
                    .sync_reset(pll_areset_rxdivfwdclk)
                );

               
                always @(posedge rx_divfwdclk[CH_INDEX] or posedge pll_areset_rxdivfwdclk)
                begin 
                    if (pll_areset_rxdivfwdclk)
                        rx_reg <= {J_FACTOR{1'b0}}; 
                    else 
                        rx_reg <= cdr_sync_reg;
                end

                assign rx_out[(J_FACTOR*(CH_INDEX+1)-1):J_FACTOR*CH_INDEX] = rx_reg; 
                
                data_synchronizer #(.SYNC_LENGTH(SYNC_STAGES)) rx_bitslip_max_sync_inst (
                    .data_in(rx_bitslip_max_wire),
                    .clock(rx_divfwdclk[CH_INDEX]),
                    .reset(pll_areset_rxdivfwdclk),
                    .data_out(rx_bitslip_max[CH_INDEX])
                ); 

                data_synchronizer #(.SYNC_LENGTH(SYNC_STAGES)) rx_dpa_locked_sync_inst (
                    .data_in(rx_dpa_locked_wire),
                    .clock(rx_divfwdclk[CH_INDEX]),
                    .reset(pll_areset_rxdivfwdclk),
                    .data_out(rx_dpa_locked[CH_INDEX])
                ); 

            end    
        end
    endgenerate 

    
    generate 
        if (SERDES_DPA_MODE == "tx_mode" && TX_OUTCLOCK_ENABLED == "true" && TX_OUTCLOCK_NON_STD_PHASE_SHIFT == "false") 
        begin : std_tx_outclock_serdes
        
            wire [9:0] tx_outclock_div_word = TX_OUTCLOCK_DIV_WORD;
            
            wire [9:0] tx_outclock_div_word_cell;
            genvar i; 
            for (i=0; i<J_FACTOR; i=i+1)
            begin : div_word_cells
                lcell div_word_wirelut (
                    .in(tx_outclock_div_word[i]),
                    .out(tx_outclock_div_word_cell[i])
                ) /* synthesis syn_keep = 1 */;
            end
            
            fourteennm_io_serdes_dpa #(
                .mode("tx_mode"),
                .data_width(J_FACTOR),
                .enable_clock_pin_mode(ENABLE_CLOCK_PIN_MODE),
                .bypass_serializer(TX_OUTCLOCK_BYPASS_SERIALIZER),
                .use_falling_clock_edge(TX_OUTCLOCK_USE_FALLING_CLOCK_EDGE), 
                .loopback_mode(LOOPBACK_MODE),
                .vco_frequency(VCO_FREQUENCY),
                .silicon_rev(SILICON_REV)
            ) serdes_dpa_tx_outclock (
                .fclk(clock_tree_fclk),
                .loaden(clock_tree_loaden),
                .txdata(tx_outclock_div_word_cell),
                .lvdsout(tx_outclock)
                );
        end
        else if (SERDES_DPA_MODE == "tx_mode" && TX_OUTCLOCK_ENABLED == "true" && TX_OUTCLOCK_NON_STD_PHASE_SHIFT == "true")
        begin : phase_shifted_tx_outclock_serdes 
            
            wire [9:0] tx_outclock_div_word = TX_OUTCLOCK_DIV_WORD;
            wire [9:0] tx_outclock_div_word_cell;
            genvar i; 
            for (i=0; i<J_FACTOR; i=i+1)
            begin : div_word_cells
                lcell div_word_wirelut (
                    .in(tx_outclock_div_word[i]),
                    .out(tx_outclock_div_word_cell[i])
                ) /* synthesis syn_keep = 1 */;
            end
            
            wire clock_tree_tx_outclock;
            wire clock_tree_tx_outclock_loaden;
            
            fourteennm_lvds_clock_tree outclock_tree (
                .lvdsfclk_in(pll_tx_outclock_fclk),
                .loaden_in(pll_tx_outclock_loaden),
                .lvdsfclk_out(clock_tree_tx_outclock),
                .loaden_out(clock_tree_tx_outclock_loaden)
                );

            fourteennm_io_serdes_dpa #(
                .mode("tx_mode"),
                .bypass_serializer(TX_OUTCLOCK_BYPASS_SERIALIZER),
                .loopback_mode(LOOPBACK_MODE),
                .vco_frequency(VCO_FREQUENCY),
                .is_tx_outclock("true"),
                .silicon_rev(SILICON_REV)
            ) serdes_dpa_tx_outclock (
                .fclk(clock_tree_tx_outclock),
                .loaden(clock_tree_tx_outclock_loaden),
                .txdata(tx_outclock_div_word_cell),
                .lvdsout(tx_outclock)
                );
        end
    endgenerate 
    
    generate
        if  (SERDES_DPA_MODE == "dpa_mode_cdr")
        begin
            (* noprune *) reg cdr_dummy_flop; 
            always @(posedge coreclock or posedge pll_areset_coreclock)
            begin
                if (pll_areset_coreclock)
                    cdr_dummy_flop <= 1'b0;
                else 
                    cdr_dummy_flop <= 1'b1;
            end
        end
    endgenerate
    
    generate
        if  ((SERDES_DPA_MODE == "dpa_mode_fifo" || SERDES_DPA_MODE == "dpa_mode_cdr") && DPRIO_ENABLED == "true")
        begin : dprio_clk_gen
            
            wire pll_areset_coreclock_dprio;
            lcell pll_areset_coreclock_wirelut (
                .in(pll_areset_coreclock),
                .out(pll_areset_coreclock_dprio)
            ) /* synthesis syn_keep = 1 */;
            
            reg dprio_done;
            reg dprio_start;
            
            
            wire dprio_clk_source = coreclock;
            reg [1:0] dprio_div_counter;
            wire dprio_gen_reset = ~pll_locked | dprio_done | pll_areset_coreclock_dprio;
            
            always @(posedge dprio_clk_source or posedge dprio_gen_reset)
            begin
                if (dprio_gen_reset)
                    dprio_div_counter <= 2'd0; 
                else
                    dprio_div_counter <= dprio_div_counter + 2'd1;
            end
            
            assign dprio_clk = dprio_div_counter[1];
            assign dprio_rst_n = ~dprio_gen_reset & dprio_start;
            

            reg [7:0] dprio_cycle_counter;
            
            always @(posedge dprio_clk or posedge dprio_gen_reset)
            begin
                if (dprio_gen_reset)
                    dprio_cycle_counter <= 7'd0; 
                else
                    dprio_cycle_counter <= dprio_cycle_counter + 7'd1;
            end

            always @(posedge dprio_clk or posedge pll_areset_coreclock_dprio)
            begin
                if (pll_areset_coreclock_dprio)
                    dprio_start <= 1'b0;
                else if (&dprio_cycle_counter[1:0])
                    dprio_start <= 1'b1;
                    
                if (pll_areset_coreclock_dprio)
                    dprio_done <= 1'b0;
                else if (&dprio_cycle_counter)
                    dprio_done <= 1'b1;
            end
            
            assign rx_dpa_reset_internal = rx_dpa_reset | {NUM_CHANNELS{~dprio_done}};
        end
        else
        begin
            assign rx_dpa_reset_internal = rx_dpa_reset;
        end
    endgenerate 

endmodule

module reset_synchronizer_active_high
#(
   parameter RESET_SYNC_LENGTH = 2
) (
   input async_reset,
   input clock,
   output sync_reset
);
    wire reset_n = ~async_reset;
    altera_std_synchronizer_nocut #(.depth(RESET_SYNC_LENGTH), .rst_value(1)) sync_inst (
        .clk(clock), 
        .reset_n(reset_n), 
        .din(1'b0), 
        .dout(sync_reset)
    );
endmodule

module data_synchronizer
#(
    parameter SYNC_LENGTH = 2
) (
    input data_in,
    input clock,
    input reset,
    output data_out
);
    wire reset_n = ~reset;
    altera_std_synchronizer_nocut #(.depth(SYNC_LENGTH)) sync_inst (
        .clk(clock), 
        .reset_n(reset_n), 
        .din(data_in), 
        .dout(data_out)
    );
endmodule

