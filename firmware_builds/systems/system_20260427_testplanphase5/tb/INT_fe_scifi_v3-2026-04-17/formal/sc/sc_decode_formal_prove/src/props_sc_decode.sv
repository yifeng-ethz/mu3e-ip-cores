`include "debug_sc_system_v3_map.svh"

module props_sc_decode (
    input  wire        clk,
    input  wire        rst,
    input  wire        f_past_valid,
    input  wire        cmd_accept,
    input  wire [17:0] cmd_addr,
    input  wire [8:0]  cmd_burstcount
);
    localparam int unsigned JTAG_FIRST = 0;
    localparam int unsigned JTAG_LAST  = 8;
    localparam int unsigned SC_FIRST   = 9;
    localparam int unsigned SC_LAST    = 16;
    localparam int unsigned INVALID_IDX = 31;

    wire [31:0] cmd_addr_w     = {14'd0, cmd_addr};
    wire [31:0] burstcount_w   = {23'd0, cmd_burstcount};
    wire [31:0] burst_end_addr = cmd_addr_w + burstcount_w - 32'd1;

    function automatic [31:0] map_base(input int unsigned idx);
        begin
            case (idx)
                FE_SC_IDX_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1;
                FE_SC_IDX_JTAG_MASTER_MASTER_SC_HUB_CSR: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_SC_HUB_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM;
                FE_SC_IDX_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY;
                FE_SC_IDX_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM;
                FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT: map_base = FE_SC_BASE_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR: map_base = FE_SC_BASE_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR;
                default: map_base = 32'hFFFFFFFF;
            endcase
        end
    endfunction

    function automatic [31:0] map_end(input int unsigned idx);
        begin
            case (idx)
                FE_SC_IDX_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1: map_end = FE_SC_END_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1;
                FE_SC_IDX_JTAG_MASTER_MASTER_SC_HUB_CSR: map_end = FE_SC_END_JTAG_MASTER_MASTER_SC_HUB_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM: map_end = FE_SC_END_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM;
                FE_SC_IDX_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY: map_end = FE_SC_END_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY;
                FE_SC_IDX_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR: map_end = FE_SC_END_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR: map_end = FE_SC_END_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM: map_end = FE_SC_END_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM;
                FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR: map_end = FE_SC_END_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR;
                FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT: map_end = FE_SC_END_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0;
                FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR: map_end = FE_SC_END_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR;
                default: map_end = 32'h00000000;
            endcase
        end
    endfunction

    function automatic logic map_hit(input int unsigned idx, input logic [31:0] addr);
        map_hit = (addr >= map_base(idx)) && (addr <= map_end(idx));
    endfunction

    function automatic [5:0] hit_count_range(
        input int unsigned first,
        input int unsigned last,
        input logic [31:0] addr
    );
        integer i;
        begin
            hit_count_range = 6'd0;
            for (i = first; i <= last; i = i + 1) begin
                if (map_hit(i, addr)) begin
                    hit_count_range = hit_count_range + 6'd1;
                end
            end
        end
    endfunction

    function automatic [4:0] first_hit_index(
        input int unsigned first,
        input int unsigned last,
        input logic [31:0] addr
    );
        integer i;
        begin
            first_hit_index = INVALID_IDX[4:0];
            for (i = first; i <= last; i = i + 1) begin
                if ((first_hit_index == INVALID_IDX[4:0]) && map_hit(i, addr)) begin
                    first_hit_index = i[4:0];
                end
            end
        end
    endfunction

    function automatic logic sc_hits_control(input logic [31:0] addr);
        begin
            sc_hits_control =
                map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1, addr) ||
                map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR, addr) ||
                map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM, addr) ||
                map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM, addr) ||
                map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY, addr) ||
                map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR, addr);
        end
    endfunction

    function automatic logic sc_hits_datapath(input logic [31:0] addr);
        sc_hits_datapath = map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0, addr);
    endfunction

    function automatic logic sc_hits_mutrig_cfg(input logic [31:0] addr);
        sc_hits_mutrig_cfg = map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR, addr);
    endfunction

    function automatic logic jtag_hits_control(input logic [31:0] addr);
        begin
            jtag_hits_control =
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_SCRATCH_PAD_RAM_S1, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_SC_HUB_CSR, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_CHARGE_INJECTION_PULSER_0_CSR_AVMM, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_FIREFLY_XCVR_CTRL_0_FIREFLY, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_ON_DIE_TEMP_SENSE_CTRL_CSR, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_ONEWIRE_MASTER_CONTROLLER_0_CSR, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_MAX10_PROG_AVMM_0_CSR_AVMM, addr);
        end
    endfunction

    function automatic logic jtag_hits_mutrig_cfg(input logic [31:0] addr);
        begin
            jtag_hits_mutrig_cfg =
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR, addr) ||
                map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_SCANRESULT, addr);
        end
    endfunction

    wire [5:0] sc_start_hit_count   = hit_count_range(SC_FIRST, SC_LAST, cmd_addr_w);
    wire [5:0] sc_end_hit_count     = hit_count_range(SC_FIRST, SC_LAST, burst_end_addr);
    wire [5:0] jtag_start_hit_count = hit_count_range(JTAG_FIRST, JTAG_LAST, cmd_addr_w);

    wire [4:0] sc_start_idx = first_hit_index(SC_FIRST, SC_LAST, cmd_addr_w);
    wire [4:0] sc_end_idx   = first_hit_index(SC_FIRST, SC_LAST, burst_end_addr);

    wire sc_start_control    = sc_hits_control(cmd_addr_w);
    wire sc_start_datapath   = sc_hits_datapath(cmd_addr_w);
    wire sc_start_mutrig_cfg = sc_hits_mutrig_cfg(cmd_addr_w);
    wire sc_start_any        = sc_start_control || sc_start_datapath || sc_start_mutrig_cfg;

    wire sc_end_control    = sc_hits_control(burst_end_addr);
    wire sc_end_datapath   = sc_hits_datapath(burst_end_addr);
    wire sc_end_mutrig_cfg = sc_hits_mutrig_cfg(burst_end_addr);
    wire sc_end_any        = sc_end_control || sc_end_datapath || sc_end_mutrig_cfg;

    wire sc_unmapped        = !sc_start_any;
    wire sc_crosses_window  = (cmd_burstcount > 9'd1) && (sc_start_idx != sc_end_idx);
    wire sc_crosses_aperture =
        (cmd_burstcount > 9'd1) &&
        ((sc_start_control    != sc_end_control)    ||
         (sc_start_datapath   != sc_end_datapath)   ||
         (sc_start_mutrig_cfg != sc_end_mutrig_cfg));

    genvar idx;
    generate
        for (idx = JTAG_FIRST; idx < JTAG_LAST; idx = idx + 1) begin : g_jtag_map_order
            always @(*) begin
                assert(map_base(idx) <= map_end(idx));
                assert(map_end(idx) < map_base(idx + 1));
            end
        end
        for (idx = SC_FIRST; idx < SC_LAST; idx = idx + 1) begin : g_sc_map_order
            always @(*) begin
                assert(map_base(idx) <= map_end(idx));
                assert(map_end(idx) < map_base(idx + 1));
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (f_past_valid && !rst) begin
            assume(cmd_burstcount != 9'd0);
            assume(burst_end_addr <= 32'h0003FFFF);

            assert(sc_start_hit_count <= 6'd1);
            assert(sc_end_hit_count <= 6'd1);
            assert(jtag_start_hit_count <= 6'd1);

            assert(!(sc_start_control && sc_start_datapath));
            assert(!(sc_start_control && sc_start_mutrig_cfg));
            assert(!(sc_start_datapath && sc_start_mutrig_cfg));

            assert(sc_unmapped == !sc_start_any);
            assert(sc_start_any == (sc_start_hit_count == 6'd1));
            assert(sc_end_any == (sc_end_hit_count == 6'd1));

            if (cmd_accept) begin
                if (sc_start_any && !sc_crosses_window) begin
                    assert(sc_end_any);
                    assert(sc_start_idx == sc_end_idx);
                end

                if (sc_crosses_aperture) begin
                    assert(sc_crosses_window);
                end
            end

            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_SCRATCH_PAD_RAM_S1, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ONEWIRE_MASTER_CONTROLLER_0_CSR, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MAX10_PROG_AVMM_0_CSR_AVMM, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_CHARGE_INJECTION_PULSER_0_CSR_AVMM, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_FIREFLY_XCVR_CTRL_0_FIREFLY, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_ON_DIE_TEMP_SENSE_CTRL_CSR, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MM_BRIDGE_S0, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_SC_HUB_CMD_PIPE_M0_MUTRIG_CFG_CTRL_0_AVMM_CSR, cmd_addr_w));
            cover(cmd_accept && sc_unmapped);
            cover(cmd_accept && sc_crosses_aperture);
            cover(cmd_accept && sc_crosses_window && !sc_crosses_aperture);
            cover(cmd_accept && map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_SC_HUB_CSR, cmd_addr_w));
            cover(cmd_accept && map_hit(FE_SC_IDX_JTAG_MASTER_MASTER_MUTRIG_CFG_CTRL_0_AVMM_CSR, cmd_addr_w));
        end
    end

endmodule
