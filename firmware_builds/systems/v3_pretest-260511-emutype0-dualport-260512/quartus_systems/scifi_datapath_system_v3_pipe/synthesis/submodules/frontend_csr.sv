// frontend_csr.sv
// CSR bank for the emulator_mutrig frontend.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add frontend CSR map and lane status aperture.

module frontend_csr #(
    parameter logic [31:0] IP_UID        = 32'h454D_5554,
    parameter int          VERSION_MAJOR = 26,
    parameter int          VERSION_MINOR = 2,
    parameter int          VERSION_PATCH = 0,
    parameter int          BUILD         = 502,
    parameter int          VERSION_DATE  = 32'h2026_0502,
    parameter logic [31:0] VERSION_GIT   = 32'h0000_0000,
    parameter logic [31:0] INSTANCE_ID   = 32'h0000_0000,
    parameter logic [3:0]  ASIC_ID_BASE_DEFAULT = 4'd0
) (
    input  logic              i_clk,
    input  logic              i_rst,

    input  logic [5:0]        avs_csr_address,
    input  logic              avs_csr_read,
    input  logic              avs_csr_write,
    input  logic [31:0]       avs_csr_writedata,
    output logic [31:0]       avs_csr_readdata,
    output logic              avs_csr_waitrequest,

    output logic              cfg_central_global_enable,
    output logic              cfg_signal_hit_mode_sig,
    output logic              cfg_signal_internal_sub_mode,
    output logic              cfg_signal_cluster_geom_mode,
    output logic              cfg_bkg_hit_mode_bkg,
    output logic              cfg_mutrig_format_short_mode,
    output logic              cfg_mutrig_format_gen_idle,
    output logic [2:0]        cfg_mutrig_format_tx_mode,
    output logic              cfg_mutrig_format_enable_type0_stream,
    output logic [15:0]       cfg_rates_hit_rate,
    output logic [15:0]       cfg_rates_noise_rate,
    output logic [6:0]        cfg_geom_fix_left_low,
    output logic [6:0]        cfg_geom_fix_left_high,
    output logic              cfg_geom_fix_left_enable,
    output logic [6:0]        cfg_geom_fix_right_low,
    output logic [6:0]        cfg_geom_fix_right_high,
    output logic              cfg_geom_fix_right_enable,
    output logic [7:0]        cfg_cluster_geom_random_cluster_size_random,
    output logic [1:0]        cfg_cluster_geom_random_mirror_mode,
    output logic signed [7:0] cfg_cluster_geom_random_mirror_offset,
    output logic [7:0]        cfg_cluster_geom_random_random_center_seed,
    output logic [31:0]       cfg_prng_seed,
    output logic [14:0]       cfg_timebase_seed_tcc_seed,
    output logic [14:0]       cfg_timebase_seed_ecc_seed,
    output logic [7:0]        cfg_lane_enable_lane_enable_mask,
    output logic [3:0]        cfg_lane_enable_asic_id_base,
    output logic [2:0]        cfg_error_inject_type0_error_inject_mask,
    output logic [7:0]        cfg_error_inject_lane_error_target_mask,
    output logic              fire_inject_pulse_csr,

    input  logic [7:0][63:0]  status_frame_count,
    input  logic [7:0][63:0]  status_hit_count,
    input  logic [7:0]        status_fifo_full_sticky,
    input  logic [7:0]        status_ticket_overflow_sticky,
    input  logic [15:0]       bank_ticket_overflow_count,
    input  logic [7:0]        bank_engine_busy_high_water,
    output logic [7:0]        clear_fifo_full_sticky,
    output logic [7:0]        clear_ticket_overflow_sticky
);

    localparam logic [5:0] ADDR_UID_CONST            = 6'h00;
    localparam logic [5:0] ADDR_META_CONST           = 6'h01;
    localparam logic [5:0] ADDR_SCRATCH_CONST        = 6'h02;
    localparam logic [5:0] ADDR_LAST_RD_ADDR_CONST   = 6'h03;
    localparam logic [5:0] ADDR_LAST_RD_DATA_CONST   = 6'h04;
    localparam logic [5:0] ADDR_LAST_WR_ADDR_CONST   = 6'h05;
    localparam logic [5:0] ADDR_LAST_WR_DATA_CONST   = 6'h06;
    localparam logic [5:0] ADDR_CENTRAL_CONST        = 6'h07;
    localparam logic [5:0] ADDR_SIGNAL_CONST         = 6'h08;
    localparam logic [5:0] ADDR_BACKGROUND_CONST     = 6'h09;
    localparam logic [5:0] ADDR_MUTRIG_FORMAT_CONST  = 6'h0A;
    localparam logic [5:0] ADDR_RATES_CONST          = 6'h0B;
    localparam logic [5:0] ADDR_CLUSTER_FIX_CONST    = 6'h0C;
    localparam logic [5:0] ADDR_CLUSTER_RANDOM_CONST = 6'h0D;
    localparam logic [5:0] ADDR_PRNG_SEED_CONST      = 6'h0E;
    localparam logic [5:0] ADDR_TIMEBASE_SEED_CONST  = 6'h0F;
    localparam logic [5:0] ADDR_LANE_ENABLE_CONST    = 6'h12;
    localparam logic [5:0] ADDR_FIRE_CONST           = 6'h13;
    localparam logic [5:0] ADDR_BANK_STATUS_CONST    = 6'h14;
    localparam logic [5:0] ADDR_ERROR_INJECT_CONST   = 6'h15;
    localparam logic [5:0] ADDR_LANE_BASE_CONST      = 6'h18;

    localparam logic [7:0]  VERSION_MAJOR_CONST = VERSION_MAJOR[7:0];
    localparam logic [7:0]  VERSION_MINOR_CONST = VERSION_MINOR[7:0];
    localparam logic [3:0]  VERSION_PATCH_CONST = VERSION_PATCH[3:0];
    localparam logic [11:0] BUILD_CONST         = BUILD[11:0];
    localparam logic [31:0] VERSION_DATE_CONST  = VERSION_DATE;

    logic [1:0]  meta_mux_q;
    logic [31:0] scratch_q;
    logic [5:0]  last_rd_addr_q;
    logic [31:0] last_rd_data_q;
    logic [5:0]  last_wr_addr_q;
    logic [31:0] last_wr_data_q;
    logic [31:0] meta_readdata;
    logic [31:0] csr_readdata;

    assign avs_csr_waitrequest = 1'b0;
    assign avs_csr_readdata    = csr_readdata;

    always_comb begin : meta_mux
        unique case (meta_mux_q)
            2'd0:    meta_readdata = {VERSION_MAJOR_CONST, VERSION_MINOR_CONST, VERSION_PATCH_CONST, BUILD_CONST};
            2'd1:    meta_readdata = VERSION_DATE_CONST;
            2'd2:    meta_readdata = VERSION_GIT;
            2'd3:    meta_readdata = INSTANCE_ID;
            default: meta_readdata = 32'h0000_0000;
        endcase
    end

    always_comb begin : read_mux
        int lane_addr;
        int lane_index;
        int lane_word;

        csr_readdata = 32'h0000_0000;
        lane_addr    = int'(avs_csr_address) - int'(ADDR_LANE_BASE_CONST);
        lane_index   = lane_addr >> 2;
        lane_word    = lane_addr & 3;

        unique case (avs_csr_address)
            ADDR_UID_CONST:          csr_readdata = IP_UID;
            ADDR_META_CONST:         csr_readdata = meta_readdata;
            ADDR_SCRATCH_CONST:      csr_readdata = scratch_q;
            ADDR_LAST_RD_ADDR_CONST: csr_readdata = {26'b0, last_rd_addr_q};
            ADDR_LAST_RD_DATA_CONST: csr_readdata = last_rd_data_q;
            ADDR_LAST_WR_ADDR_CONST: csr_readdata = {26'b0, last_wr_addr_q};
            ADDR_LAST_WR_DATA_CONST: csr_readdata = last_wr_data_q;
            ADDR_CENTRAL_CONST:      csr_readdata = {31'b0, cfg_central_global_enable};
            ADDR_SIGNAL_CONST: begin
                csr_readdata = {
                    29'b0,
                    cfg_signal_cluster_geom_mode,
                    cfg_signal_internal_sub_mode,
                    cfg_signal_hit_mode_sig
                };
            end
            ADDR_BACKGROUND_CONST: csr_readdata = {31'b0, cfg_bkg_hit_mode_bkg};
            ADDR_MUTRIG_FORMAT_CONST: begin
                csr_readdata = {
                    26'b0,
                    cfg_mutrig_format_enable_type0_stream,
                    cfg_mutrig_format_tx_mode,
                    cfg_mutrig_format_gen_idle,
                    cfg_mutrig_format_short_mode
                };
            end
            ADDR_RATES_CONST: csr_readdata = {cfg_rates_noise_rate, cfg_rates_hit_rate};
            ADDR_CLUSTER_FIX_CONST: begin
                csr_readdata = {
                    1'b0,
                    cfg_geom_fix_right_enable,
                    cfg_geom_fix_right_high,
                    cfg_geom_fix_right_low,
                    1'b0,
                    cfg_geom_fix_left_enable,
                    cfg_geom_fix_left_high,
                    cfg_geom_fix_left_low
                };
            end
            ADDR_CLUSTER_RANDOM_CONST: begin
                csr_readdata = {
                    5'b0,
                    cfg_cluster_geom_random_random_center_seed,
                    cfg_cluster_geom_random_mirror_offset,
                    1'b0,
                    cfg_cluster_geom_random_mirror_mode,
                    cfg_cluster_geom_random_cluster_size_random
                };
            end
            ADDR_PRNG_SEED_CONST:     csr_readdata = cfg_prng_seed;
            ADDR_TIMEBASE_SEED_CONST: csr_readdata = {1'b0, cfg_timebase_seed_ecc_seed, 1'b0, cfg_timebase_seed_tcc_seed};
            ADDR_LANE_ENABLE_CONST:   csr_readdata = {20'b0, cfg_lane_enable_asic_id_base, cfg_lane_enable_lane_enable_mask};
            ADDR_FIRE_CONST:          csr_readdata = 32'h0000_0000;
            ADDR_BANK_STATUS_CONST:   csr_readdata = {8'b0, bank_engine_busy_high_water, bank_ticket_overflow_count};
            ADDR_ERROR_INJECT_CONST: begin
                csr_readdata = {
                    21'b0,
                    cfg_error_inject_lane_error_target_mask,
                    cfg_error_inject_type0_error_inject_mask
                };
            end
            default: begin
                if ((lane_addr >= 0) && (lane_index < 8)) begin
                    unique case (lane_word)
                        0: csr_readdata = status_frame_count[lane_index][31:0];
                        1:       csr_readdata = status_frame_count[lane_index][63:32];
                        2:       csr_readdata = status_hit_count[lane_index][31:0];
                        3:       csr_readdata = status_hit_count[lane_index][63:32];
                        default: csr_readdata = 32'h0000_0000;
                    endcase
                end
            end
        endcase
    end

    always_ff @(posedge i_clk) begin : csr_regs
        if (i_rst) begin
            meta_mux_q                                     <= 2'd0;
            scratch_q                                      <= 32'h0000_0000;
            last_rd_addr_q                                 <= 6'h00;
            last_rd_data_q                                 <= 32'h0000_0000;
            last_wr_addr_q                                 <= 6'h00;
            last_wr_data_q                                 <= 32'h0000_0000;
            cfg_central_global_enable                      <= 1'b1;
            cfg_signal_hit_mode_sig                        <= 1'b0;
            cfg_signal_internal_sub_mode                   <= 1'b0;
            cfg_signal_cluster_geom_mode                   <= 1'b0;
            cfg_bkg_hit_mode_bkg                           <= 1'b0;
            cfg_mutrig_format_short_mode                   <= 1'b0;
            cfg_mutrig_format_gen_idle                     <= 1'b1;
            cfg_mutrig_format_tx_mode                      <= 3'b000;
            cfg_mutrig_format_enable_type0_stream          <= 1'b1;
            cfg_rates_hit_rate                             <= 16'h0800;
            cfg_rates_noise_rate                           <= 16'h0100;
            cfg_geom_fix_left_low                          <= 7'd0;
            cfg_geom_fix_left_high                         <= 7'd3;
            cfg_geom_fix_left_enable                       <= 1'b1;
            cfg_geom_fix_right_low                         <= 7'd0;
            cfg_geom_fix_right_high                        <= 7'd3;
            cfg_geom_fix_right_enable                      <= 1'b0;
            cfg_cluster_geom_random_cluster_size_random    <= 8'd4;
            cfg_cluster_geom_random_mirror_mode            <= 2'b10;
            cfg_cluster_geom_random_mirror_offset          <= 8'sd0;
            cfg_cluster_geom_random_random_center_seed     <= 8'h00;
            cfg_prng_seed                                  <= 32'hDEAD_BEEF;
            cfg_timebase_seed_tcc_seed                     <= 15'h0001;
            cfg_timebase_seed_ecc_seed                     <= 15'h0001;
            cfg_lane_enable_lane_enable_mask               <= 8'hFF;
            cfg_lane_enable_asic_id_base                   <= {1'b0, ASIC_ID_BASE_DEFAULT[2:0]};
            cfg_error_inject_type0_error_inject_mask       <= 3'b000;
            cfg_error_inject_lane_error_target_mask        <= 8'h00;
            fire_inject_pulse_csr                          <= 1'b0;
            clear_fifo_full_sticky                         <= 8'h00;
            clear_ticket_overflow_sticky                   <= 8'h00;
        end else begin
            int lane_addr;
            int lane_index;
            int lane_word;

            fire_inject_pulse_csr           <= 1'b0;
            clear_fifo_full_sticky          <= 8'h00;
            clear_ticket_overflow_sticky    <= 8'h00;
            lane_addr                       = int'(avs_csr_address) - int'(ADDR_LANE_BASE_CONST);
            lane_index                      = lane_addr >> 2;
            lane_word                       = lane_addr & 3;

            if (avs_csr_read &&
                (avs_csr_address != ADDR_LAST_RD_ADDR_CONST) &&
                (avs_csr_address != ADDR_LAST_RD_DATA_CONST)) begin
                last_rd_addr_q    <= avs_csr_address;
                last_rd_data_q    <= csr_readdata;
            end

            if (avs_csr_write) begin
                last_wr_addr_q    <= avs_csr_address;
                last_wr_data_q    <= avs_csr_writedata;

                unique case (avs_csr_address)
                    ADDR_META_CONST: begin
                        meta_mux_q    <= avs_csr_writedata[1:0];
                    end
                    ADDR_SCRATCH_CONST: begin
                        scratch_q    <= avs_csr_writedata;
                    end
                    ADDR_CENTRAL_CONST: begin
                        cfg_central_global_enable    <= avs_csr_writedata[0];
                    end
                    ADDR_SIGNAL_CONST: begin
                        cfg_signal_hit_mode_sig         <= avs_csr_writedata[0];
                        cfg_signal_internal_sub_mode    <= avs_csr_writedata[1];
                        cfg_signal_cluster_geom_mode    <= avs_csr_writedata[2];
                    end
                    ADDR_BACKGROUND_CONST: begin
                        cfg_bkg_hit_mode_bkg    <= avs_csr_writedata[0];
                    end
                    ADDR_MUTRIG_FORMAT_CONST: begin
                        cfg_mutrig_format_short_mode             <= avs_csr_writedata[0];
                        cfg_mutrig_format_gen_idle               <= avs_csr_writedata[1];
                        cfg_mutrig_format_tx_mode                <= avs_csr_writedata[4:2];
                        cfg_mutrig_format_enable_type0_stream    <= avs_csr_writedata[5];
                    end
                    ADDR_RATES_CONST: begin
                        cfg_rates_hit_rate      <= avs_csr_writedata[15:0];
                        cfg_rates_noise_rate    <= avs_csr_writedata[31:16];
                    end
                    ADDR_CLUSTER_FIX_CONST: begin
                        cfg_geom_fix_left_low       <= avs_csr_writedata[6:0];
                        cfg_geom_fix_left_high      <= avs_csr_writedata[13:7];
                        cfg_geom_fix_left_enable    <= avs_csr_writedata[14];
                        cfg_geom_fix_right_low      <= avs_csr_writedata[22:16];
                        cfg_geom_fix_right_high     <= avs_csr_writedata[29:23];
                        cfg_geom_fix_right_enable   <= avs_csr_writedata[30];
                    end
                    ADDR_CLUSTER_RANDOM_CONST: begin
                        cfg_cluster_geom_random_cluster_size_random    <= avs_csr_writedata[7:0];
                        cfg_cluster_geom_random_mirror_mode            <= avs_csr_writedata[9:8];
                        cfg_cluster_geom_random_mirror_offset          <= avs_csr_writedata[18:11];
                        cfg_cluster_geom_random_random_center_seed     <= avs_csr_writedata[26:19];
                    end
                    ADDR_PRNG_SEED_CONST: begin
                        cfg_prng_seed    <= avs_csr_writedata;
                    end
                    ADDR_TIMEBASE_SEED_CONST: begin
                        cfg_timebase_seed_tcc_seed    <= avs_csr_writedata[14:0];
                        cfg_timebase_seed_ecc_seed    <= avs_csr_writedata[30:16];
                    end
                    ADDR_LANE_ENABLE_CONST: begin
                        cfg_lane_enable_lane_enable_mask    <= avs_csr_writedata[7:0];
                        cfg_lane_enable_asic_id_base        <= avs_csr_writedata[11:8];
                    end
                    ADDR_FIRE_CONST: begin
                        fire_inject_pulse_csr    <= avs_csr_writedata[0];
                    end
                    ADDR_ERROR_INJECT_CONST: begin
                        cfg_error_inject_type0_error_inject_mask    <= avs_csr_writedata[2:0];
                        cfg_error_inject_lane_error_target_mask     <= avs_csr_writedata[10:3];
                    end
                    default: begin
                        if ((lane_addr >= 0) && (lane_index < 8) && (lane_word == 1)) begin
                            clear_fifo_full_sticky[lane_index]          <= avs_csr_writedata[28];
                            clear_ticket_overflow_sticky[lane_index]    <= avs_csr_writedata[29];
                        end
                    end
                endcase
            end
        end
    end

endmodule
