// tb_scifi_v4_wrapper.sv
// Wrapper-only integration TB for FEB SciFi v4 - practices "no driver
// inside the DUT" per LESSONS_LEARNT_BUG027.md.
//
// DUT = scifi_datapath_system_v4 (qsys subsystem wrapper). The
// wrapper-strip bug (BUG-027-I: asi_type1_*_ready) lives in THIS
// wrapper, so this TB is the right level to catch the regression in
// sim. The next level out is feb_system_v4 (which adds sc_hub +
// upload_subsystem); a follow-on TB will move up there once an SC
// packet driver is written.
//
// What the TB drives at the wrapper boundary:
//   * 4 clocks: avmm_clk, monitor_clock_125_in, osc_clock_50_in,
//     lvds_pll_inclock, xcvr_clock
//   * resets: avmm_rst_reset, monitor_reset_in_reset_n,
//     xcvr_reset_reset_n, counter_sclr_reset
//   * avmm_port (Avalon-MM SLAVE on the wrapper) - the TB acts as a
//     tiny AVMM MASTER driving address/writedata/byteenable, capturing
//     readdata/readdatavalid. This is the "virtual SWB driver" channel
//     for in-DUT CSR access. Real SC packet construction belongs at
//     the feb_system_v4 level (download_sc_*) and is queued for the
//     next harness commit.
//   * runctl_mgmt_host AvST sink - the TB pushes 9-bit one-hot runctl
//     opcodes (IDLE/PREP/SYNC/RUN/...). This is the equivalent of
//     runctl_mgmt_host_0 inside the next-level-out feb_system_v4.
//   * inject_aux_pulse - tied low.
//   * redriver_losn - tied to all-not-lost.
//   * serial_data - tied 0 (no LVDS link).
//
// What the TB observes at the wrapper boundary:
//   * avmm_port_readdata / readdatavalid
//   * hit_type3_upper_*, hit_type3_lower_* (always-ready sinks)
//   * rstlink_* (runctl back-channel)
//   * lvds_outclock_clk (so the TB can see if the LVDS PLL came up)
//   * mutrig_reset, inject_pulse, inject_masked_pulse (just monitored)
//
// What the TB does NOT do:
//   * Reach inside the DUT with `dut.u_inner.signal` references.
//   * Compile any leaf IP source file independently. The vcom file
//     list is owned entirely by the qsys-generated msim_setup.tcl.

`timescale 1ns/1ps

// Shared probe accumulators. Bound probe instances (by module name) write
// per-channel hit-beat counts here; the TB reads them. Using a package with
// static storage avoids needing the exact bind-instance hierarchical path and
// avoids driving TB nets from a bind port map.
package tb_chan_probe_pkg;
    longint unsigned emit_total = 0;
    int unsigned     emit_ch [0:31];
    longint unsigned ing_total = 0;
    int unsigned     ing_ch  [0:31];
    // arb egress source accounting: how many selected hits came from emu vs real.
    longint unsigned arb_emu = 0;
    longint unsigned arb_real = 0;
    // DIAG: histogram of the actual divider input key (low 8 bits) and the
    // raw 8-bit [43:36] slice of the ingress data, to localise the bin-0
    // collapse (key path vs data-field position).
    longint unsigned key_total = 0;
    int unsigned     key_hist [0:255];
    longint unsigned slice_total = 0;
    int unsigned     slice_hist [0:255];
    longint unsigned slice_asic_x = 0, slice_asic_ok = 0;
    longint unsigned slice_ch_x = 0,   slice_ch_ok = 0;
    // DIAG-ASIC: track the emulator core asic config + per-lane emitter asic
    // field, to localise the asic[44:41]=X collapse (cfg vs emitter vs interconnect).
    logic [3:0]      diag_cfg_asic_base = 4'hF; // last sampled cfg_lane_enable_asic_id_base
    longint unsigned diag_cfg_x = 0,   diag_cfg_ok = 0;
    longint unsigned diag_emit_asic_x = 0, diag_emit_asic_ok = 0;
    longint unsigned diag_emit_beats = 0;
    longint unsigned diag_asicid_x = 0, diag_asicid_ok = 0;
    longint unsigned diag_emit_d44_x = 0, diag_emit_d4341_x = 0;
    logic [3:0]      diag_last_asicid = 4'hF;
    longint unsigned diag_core_x = 0, diag_core_ok = 0;
    logic [3:0]      diag_core_asic_base = 4'hF;
    // ----------------------------------------------------------------
    // TYPE0 stall localisation chain (lane 0). All five counters are
    // driven by the bind into merger_hit_type0 INSTANCE_ID==0:
    //   mrg_emu_in_valid  : merger asi_emu_valid (== emulator
    //                       aso_hit_type0_0_valid net per generated wrapper)
    //   mrg_src_is_emu_h  : cycles cfg_source_is_emu==1 (reset SOURCE_SEL_DEFAULT)
    //   mrg_out_valid     : merger aso_out_valid (== arb real_in_0_valid net)
    // emu_out / arb_in are bookkeeping copies of the same beats so the
    // report can print one number per chain stage.
    longint unsigned mrg_emu_out_valid = 0;  // emulator aso_hit_type0_0_valid
    longint unsigned mrg_emu_in_valid  = 0;  // merger_0 asi_emu_valid
    longint unsigned mrg_src_is_emu_h  = 0;  // cycles cfg_source_is_emu==1
    longint unsigned mrg_out_valid     = 0;  // merger_0 aso_out_valid
    longint unsigned mrg_arb_in_valid  = 0;  // arb real_in_0_valid
    logic            mrg_src_is_emu_last = 1'bx;
    function automatic void clear_diag_asic();
        diag_cfg_x = 0; diag_cfg_ok = 0;
        diag_emit_asic_x = 0; diag_emit_asic_ok = 0; diag_emit_beats = 0;
        diag_asicid_x = 0; diag_asicid_ok = 0;
        diag_emit_d44_x = 0; diag_emit_d4341_x = 0;
        diag_core_x = 0; diag_core_ok = 0;
    endfunction
    function automatic void clear_all();
        emit_total = 0; ing_total = 0; arb_emu = 0; arb_real = 0;
        mrg_emu_out_valid = 0; mrg_emu_in_valid = 0; mrg_src_is_emu_h = 0;
        mrg_out_valid = 0; mrg_arb_in_valid = 0;
        key_total = 0; slice_total = 0;
        slice_asic_x = 0; slice_asic_ok = 0; slice_ch_x = 0; slice_ch_ok = 0;
        for (int i = 0; i < 32; i++) begin emit_ch[i] = 0; ing_ch[i] = 0; end
        for (int i = 0; i < 256; i++) begin key_hist[i] = 0; slice_hist[i] = 0; end
    endfunction
endpackage

module tb_scifi_v4_wrapper;

    localparam real AVMM_CLK_NS    = 6.4;   // 156.25 MHz
    localparam real MONITOR_CLK_NS = 8.0;   // 125 MHz
    localparam real LVDS_REF_NS    = 8.0;   // 125 MHz
    localparam real XCVR_CLK_NS    = 6.4;   // 156.25 MHz
    localparam real OSC50_NS       = 20.0;  // 50 MHz

    // ------------------------- clocks ------------------------------
    logic avmm_clk_clk            = 1'b0;
    logic monitor_clock_125_in_clk= 1'b0;
    logic lvds_pll_inclock_clk    = 1'b0;
    logic xcvr_clock_clk          = 1'b0;
    logic osc_clock_50_in_clk     = 1'b0;

    always #(AVMM_CLK_NS    / 2) avmm_clk_clk             = ~avmm_clk_clk;
    always #(MONITOR_CLK_NS / 2) monitor_clock_125_in_clk = ~monitor_clock_125_in_clk;
    always #(LVDS_REF_NS    / 2) lvds_pll_inclock_clk     = ~lvds_pll_inclock_clk;
    always #(XCVR_CLK_NS    / 2) xcvr_clock_clk           = ~xcvr_clock_clk;
    always #(OSC50_NS       / 2) osc_clock_50_in_clk      = ~osc_clock_50_in_clk;

    // ------------------------- resets ------------------------------
    logic avmm_rst_reset                = 1'b1;
    logic monitor_reset_in_reset_reset_n = 1'b0;
    logic xcvr_reset_reset_n            = 1'b0;
    logic counter_sclr_reset            = 1'b1;

    initial begin
        // Hold every reset for 200 ns, then release.
        avmm_rst_reset                  = 1'b1;
        monitor_reset_in_reset_reset_n  = 1'b0;
        xcvr_reset_reset_n              = 1'b0;
        counter_sclr_reset              = 1'b1;
        #1_000;
        avmm_rst_reset                  = 1'b0;
        monitor_reset_in_reset_reset_n  = 1'b1;
        xcvr_reset_reset_n              = 1'b1;
        counter_sclr_reset              = 1'b0;
    end

    // -------------------- avmm tiny master -------------------------
    logic [13:0]  avmm_port_address    = '0;
    logic [31:0]  avmm_port_writedata  = '0;
    logic [3:0]   avmm_port_byteenable = 4'hF;
    logic         avmm_port_write      = 1'b0;
    logic         avmm_port_read       = 1'b0;
    logic [8:0]   avmm_port_burstcount = 9'd1;
    logic         avmm_port_debugaccess= 1'b0;
    wire          avmm_port_waitrequest;
    wire  [31:0]  avmm_port_readdata;
    wire          avmm_port_readdatavalid;

    task automatic avmm_write(input [13:0] addr, input [31:0] data);
        @(posedge avmm_clk_clk);
        avmm_port_address    <= addr;
        avmm_port_writedata  <= data;
        avmm_port_byteenable <= 4'hF;
        avmm_port_write      <= 1'b1;
        avmm_port_burstcount <= 9'd1;
        @(posedge avmm_clk_clk);
        while (avmm_port_waitrequest) @(posedge avmm_clk_clk);
        avmm_port_write <= 1'b0;
    endtask

    task automatic avmm_read(input [13:0] addr, output [31:0] data);
        @(posedge avmm_clk_clk);
        avmm_port_address    <= addr;
        avmm_port_read       <= 1'b1;
        avmm_port_byteenable <= 4'hF;
        avmm_port_burstcount <= 9'd1;
        @(posedge avmm_clk_clk);
        while (avmm_port_waitrequest) @(posedge avmm_clk_clk);
        avmm_port_read <= 1'b0;
        // wait readdatavalid
        for (int t = 0; t < 256; t++) begin
            if (avmm_port_readdatavalid) break;
            @(posedge avmm_clk_clk);
        end
        data = avmm_port_readdata;
    endtask

    // ----------------- hist_bin burst readout (Monitor A) ----------------
    //  The histogram SRAM is read out through a SECOND Avalon-MM slave
    //  (hist_bin), NOT the csr slave. The csr slave only exposes scalar
    //  status (TOTAL_HITS etc). To get the per-bin distribution -- which
    //  is the per-channel rate (value mode) and the delay distribution
    //  (delay mode) -- the host must burst-read the 256-word bin array.
    //
    //  qsys address map (generated/qsys/scifi_datapath_system_v4.qsys):
    //    histogram_statistics_0.csr      baseAddress = 132096 = 0x20400 B
    //    histogram_statistics_0.hist_bin baseAddress = 131072 = 0x20000 B
    //  The csr aperture is verified to land at wrapper word 0x2900 (byte
    //  0xA400). hist_bin sits 0x400 bytes (0x100 words) below it:
    //    HIST_BIN word base = 0x2900 - 0x100 = 0x2800.
    //  pingpong_sram.vhd: a single read returns 1 bin word (count); a
    //  read with burstcount=N streams N consecutive bins. We do per-bin
    //  single reads here for protocol simplicity (avmm master is 1-beat).
    localparam [13:0] HIST_BIN_BASE = 14'h2800;
    localparam int    N_BINS        = 256;

    // Absolute-address word read with waitrequest handling.
    task automatic avmm_read_abs(input [13:0] addr, output [31:0] data);
        @(posedge avmm_clk_clk);
        avmm_port_address    <= addr;
        avmm_port_read       <= 1'b1;
        avmm_port_byteenable <= 4'hF;
        avmm_port_burstcount <= 9'd1;
        @(posedge avmm_clk_clk);
        while (avmm_port_waitrequest) @(posedge avmm_clk_clk);
        avmm_port_read <= 1'b0;
        for (int t = 0; t < 512; t++) begin
            if (avmm_port_readdatavalid) break;
            @(posedge avmm_clk_clk);
        end
        data = avmm_port_readdata;
    endtask

    // hist_bin single-bin read: bin index relative to HIST_BIN_BASE.
    task automatic hist_bin_read(input [13:0] bin_idx, output [31:0] data);
        avmm_read_abs(HIST_BIN_BASE + bin_idx, data);
    endtask

    // Monitor A state: bins read from the histogram SRAM.
    int unsigned monA_bin   [0:N_BINS-1];
    longint unsigned monA_sum;

    // Read the full 256-bin frozen histogram. The clean snapshot is
    // produced by the TERMINATING run command (see runctl_terminate_flush
    // in the run sequence): force_interval_pulse swaps active->inactive
    // WITHOUT wiping (histogram_statistics_v2.vhd:1158-1166 ->
    // pingpong_sram.vhd:449 interval swap). A write of 0 to hist_bin is
    // NOT used: pingpong_sram.vhd:359 i_clear is a full accumulator reset
    // (active_bank<=0, valid bitmap wiped) and returns all-zero reads.
    task automatic monA_read_all_bins();
        logic [31:0] v;
        monA_sum = 0;
        for (int b = 0; b < N_BINS; b++) begin
            hist_bin_read(b[13:0], v);
            monA_bin[b] = v[19:0];   // MAX_COUNT_BITS = 20
            monA_sum   += v[19:0];
        end
    endtask

    // -------------------- runctl AvST source -----------------------
    logic [8:0] runctl_mgmt_host_data  = 9'h001; // IDLE
    logic       runctl_mgmt_host_valid = 1'b0;
    // The readyless run-control qsys (run_control_mux removed; runctl source
    // feeds run_control_splitter.in directly; run_control_splitter +
    // emulator_ctrl_splitter are USE_READY=0) no longer exports a
    // runctl_mgmt_host.ready back-channel from scifi_datapath_system_v4. The
    // DUT port list is now valid+data only (confirmed: vopt-2912 Port
    // 'runctl_mgmt_host_ready' not found, 2026-05-21 regen). Model the host's
    // view of a no-backpressure sink with a constant ready so the existing
    // runctl_hold_until_ready handshake degrades to a fixed min_hold settle.
    // This is a HARNESS-only change to match the actual DUT boundary; it does
    // NOT touch the design.
    wire        runctl_mgmt_host_ready = 1'b1;

    task automatic runctl_send(input [8:0] op);
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= op;
        runctl_mgmt_host_valid <= 1'b1;
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_valid <= 1'b0;
    endtask

    // Hold a run-control opcode asserted for HOLD cycles. The run-control
    // distribution (run_control_splitter) is backpressure-capable and the
    // frame-assembly run-control agent samples the opcode only while
    // valid=1; a single-cycle pulse can be dropped under backpressure or
    // across the reset->monitor CDC. Holding valid is the documented host
    // contract (feb_frame_assembly.vhd:1976 "the host must assert the
    // valid until all ack by the agents are received").
    task automatic runctl_hold(input [8:0] op, input int hold);
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= op;
        runctl_mgmt_host_valid <= 1'b1;
        repeat (hold) @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_valid <= 1'b0;
    endtask

    // Hold an opcode asserted until the runctl back-channel acknowledges
    // (runctl_mgmt_host_ready) AND a minimum settle has elapsed. This is
    // required for RUN_PREPARE: each of the 4 ring_buffer_cam lanes runs a
    // 512-entry CAM+RAM flush on PREP entry and only raises asi_ctrl_ready
    // (=prep_ready_latched) when that flush completes
    // (ring_buffer_cam_core.sv:813-848). The run_control_splitter ANDs all
    // consumer readies, so the host-side ready only rises once every lane
    // has finished. A 16-cycle PREP pulse (the old stimulus) deasserts
    // valid mid-flush; the splitter never completes the handshake and the
    // downstream agents never cleanly arm -> no frame is ever assembled
    // (hit_type3 dead). max_wait bounds the wait so a genuinely stuck
    // handshake still ends the test instead of hanging.
    task automatic runctl_hold_until_ready(input [8:0] op, input int min_hold,
                                            input int max_wait);
        int waited;
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= op;
        runctl_mgmt_host_valid <= 1'b1;
        // Hold at least min_hold cycles, then continue until ready or timeout.
        repeat (min_hold) @(posedge monitor_clock_125_in_clk);
        waited = 0;
        while (!runctl_mgmt_host_ready && waited < max_wait) begin
            @(posedge monitor_clock_125_in_clk);
            waited++;
        end
        // One extra cycle with valid&ready to guarantee the beat is consumed.
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_valid <= 1'b0;
        $display("[tb] runctl op=0x%03h handshake: ready=%b after min_hold+%0d cyc",
                 op, runctl_mgmt_host_ready, waited);
    endtask

    // TERMINATING produces the clean ping-pong snapshot: the histogram
    // arms term_flush on RUN entry and asserts force_interval_pulse when
    // run_state_cmd reaches TERMINATING (histogram_statistics_v2.vhd:1158).
    // That swaps the accumulated bank to the readable (inactive) side and
    // latches csr_last_interval_total_hits (CSR reg 17).
    // TERMINATING also drains the frame-assembly readout. The
    // feb_frame_assembly emit gate during RUNNING needs ALL 4 interleaved
    // CAM lanes to hold a valid showahead subheader at the same instant; at
    // modest occupancy that AND-reduce rarely fires. During TERMINATING the
    // gate relaxes to an OR-reduce ("drain whatever lanes still have heads",
    // feb_frame_assembly.vhd:1391-1431), so the buffered frames flush out as
    // hit_type3 beats here. Hold TERMINATING long enough for the 4 lanes to
    // drain (each lane walks its 512-entry ring at the read pointer cadence)
    // and keep Monitor B's window OPEN across it (caller must not clear
    // monB_active before this returns).
    task automatic runctl_terminate_flush();
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h010;   // TERMINATING
        runctl_mgmt_host_valid <= 1'b1;
        repeat (4096) @(posedge monitor_clock_125_in_clk);   // drain window
        runctl_mgmt_host_valid <= 1'b0;
        repeat (256) @(posedge avmm_clk_clk);
    endtask

    // ---------------- idle tie-offs / always-ready sinks -----------
    logic       inject_aux_pulse      = 1'b0;
    logic [8:0] redriver_losn         = 9'h000; // not lost
    logic [8:0] serial_data           = 9'h000;

    logic       hit_type3_upper_ready = 1'b1;
    logic       hit_type3_lower_ready = 1'b1;

    wire [35:0] hit_type3_upper_data;
    wire        hit_type3_upper_valid;
    wire        hit_type3_upper_startofpacket;
    wire        hit_type3_upper_endofpacket;
    wire [0:0]  hit_type3_upper_empty;
    wire [35:0] hit_type3_lower_data;
    wire        hit_type3_lower_valid;
    wire        hit_type3_lower_startofpacket;
    wire        hit_type3_lower_endofpacket;
    wire [8:0]  rstlink_data;
    wire [3:0]  rstlink_channel;
    wire [2:0]  rstlink_error;
    wire        lvds_outclock_clk;
    wire        inject_pulse;
    wire        inject_masked_pulse;
    wire [1:0]  mutrig_reset_reset;

    // ----------- Monitor B: hit_type3 wrapper-boundary parser ------------
    //  The ONLY data-bearing AvST output at the scifi_datapath_system_v4
    //  wrapper boundary that derives from the Type1 hit stream is
    //  hit_type3_upper / hit_type3_lower (36-bit MIDAS frame stream).
    //  Frame layout (feb_frame_assembly.vhd:54-57):
    //    data[35:32] = byte_is_k : 0x1 = sub-header (K-word), 0x0 = hit
    //    sub-header  : [31:24]=ts[11:4] [15:8]=hit_cnt [7:0]=K23.7
    //    hit         : [31:0] = specbook MuTRiG hit format
    //  These come from hist_type1_{up,down}_tap.out0 -> hit_stack ->
    //  feb_frame_assembly, i.e. the SAME tap whose out1 feeds the
    //  histogram (via MTS extended plane). So a hit counted here is an
    //  independent observation of a hit the histogram should also count.
    int upper_beats = 0;
    int lower_beats = 0;

    // Independent hit / subheader / frame tallies from the boundary.
    int monB_up_hits   = 0;   // data[35:32]==0 beats on upper
    int monB_dn_hits   = 0;
    int monB_up_subhdr = 0;   // data[35:32]==1 beats on upper
    int monB_dn_subhdr = 0;
    int monB_up_sop    = 0;
    int monB_dn_sop    = 0;
    int monB_up_eop    = 0;
    logic monB_active  = 1'b0;  // gate counting to the measurement window

    always @(posedge monitor_clock_125_in_clk) begin
        if (hit_type3_upper_valid && hit_type3_upper_ready) begin
            upper_beats <= upper_beats + 1;
            if (monB_active) begin
                if (hit_type3_upper_data[35:32] == 4'h0) monB_up_hits   <= monB_up_hits   + 1;
                if (hit_type3_upper_data[35:32] == 4'h1) monB_up_subhdr <= monB_up_subhdr + 1;
                if (hit_type3_upper_startofpacket)       monB_up_sop    <= monB_up_sop    + 1;
                if (hit_type3_upper_endofpacket)         monB_up_eop    <= monB_up_eop    + 1;
            end
        end
        if (hit_type3_lower_valid && hit_type3_lower_ready) begin
            lower_beats <= lower_beats + 1;
            if (monB_active) begin
                if (hit_type3_lower_data[35:32] == 4'h0) monB_dn_hits   <= monB_dn_hits   + 1;
                if (hit_type3_lower_data[35:32] == 4'h1) monB_dn_subhdr <= monB_dn_subhdr + 1;
                if (hit_type3_lower_startofpacket)       monB_dn_sop    <= monB_dn_sop    + 1;
            end
        end
    end

    // ------------------------- DUT ---------------------------------
    scifi_datapath_system_v4 dut (
        .avmm_clk_clk                  (avmm_clk_clk),
        .avmm_port_waitrequest         (avmm_port_waitrequest),
        .avmm_port_readdata            (avmm_port_readdata),
        .avmm_port_readdatavalid       (avmm_port_readdatavalid),
        .avmm_port_burstcount          (avmm_port_burstcount),
        .avmm_port_writedata           (avmm_port_writedata),
        .avmm_port_address             (avmm_port_address),
        .avmm_port_write               (avmm_port_write),
        .avmm_port_read                (avmm_port_read),
        .avmm_port_byteenable          (avmm_port_byteenable),
        .avmm_port_debugaccess         (avmm_port_debugaccess),
        .avmm_rst_reset                (avmm_rst_reset),
        .counter_sclr_reset            (counter_sclr_reset),
        .hit_type3_lower_data          (hit_type3_lower_data),
        .hit_type3_lower_valid         (hit_type3_lower_valid),
        .hit_type3_lower_ready         (hit_type3_lower_ready),
        .hit_type3_lower_startofpacket (hit_type3_lower_startofpacket),
        .hit_type3_lower_endofpacket   (hit_type3_lower_endofpacket),
        .hit_type3_upper_ready         (hit_type3_upper_ready),
        .hit_type3_upper_valid         (hit_type3_upper_valid),
        .hit_type3_upper_startofpacket (hit_type3_upper_startofpacket),
        .hit_type3_upper_endofpacket   (hit_type3_upper_endofpacket),
        .hit_type3_upper_empty         (hit_type3_upper_empty),
        .hit_type3_upper_data          (hit_type3_upper_data),
        .inject_pulse                  (inject_pulse),
        .inject_masked_pulse           (inject_masked_pulse),
        .inject_aux_pulse              (inject_aux_pulse),
        .lvds_outclock_clk             (lvds_outclock_clk),
        .lvds_pll_inclock_clk          (lvds_pll_inclock_clk),
        .monitor_clock_125_in_clk      (monitor_clock_125_in_clk),
        .monitor_reset_in_reset_reset_n(monitor_reset_in_reset_reset_n),
        .mutrig_reset_reset            (mutrig_reset_reset),
        .osc_clock_50_in_clk           (osc_clock_50_in_clk),
        .redriver_losn                 (redriver_losn),
        .rstlink_data                  (rstlink_data),
        .rstlink_channel               (rstlink_channel),
        .rstlink_error                 (rstlink_error),
        .runctl_mgmt_host_data         (runctl_mgmt_host_data),
        .runctl_mgmt_host_valid        (runctl_mgmt_host_valid),
        // .runctl_mgmt_host_ready removed: readyless RC DUT no longer exports it.
        .serial_data                   (serial_data),
        .xcvr_clock_clk                (xcvr_clock_clk),
        .xcvr_reset_reset_n            (xcvr_reset_reset_n)
    );

    // ===============================================================
    //  Histogram CSR map (wrapper-boundary view).
    //  avmm_port is WORD-addressed (14-bit addr, 4-byte words). The hist
    //  CSR aperture lands at byte 0xA400 (mm_pipeline_lvds_csr_hist @
    //  0xA000 + histogram_statistics_0.csr @ 0x0400) = word 0x2900.
    //  Hist CSR register N (5-bit avs_csr_address) is at word 0x2900+N.
    //  Verified: read @0x2900 returns IP_UID = ASCII "HIST" = 0x48495354.
    //  Register offsets are taken verbatim from histogram_statistics_v2.vhd
    //  csr_read_comb / csr_reg (NOT reverse-engineered from sim output).
    // ===============================================================
    // ===============================================================
    //  Emulator (emulator_mutrig) CSR map (wrapper-boundary view).
    //  avmm_port -> mm_clock_crossing_bridge -> mm_pipeline_lvds_csr_emu_dbg
    //  bridge @ byte 0x2000 (qsys), emulator csr at +0x0000 within it.
    //  => emulator CSR byte base 0x2000 = WORD base 0x800.
    //  Verified by qsys connection (scifi_datapath_system_v4.qsys:2158-2162).
    //  6-bit avs_csr_address => register N at word 0x800 + N.
    //  Register map from frontend_csr.sv:
    //    0x00 UID      (= "EMUT" = 0x454D5554)
    //    0x07 CENTRAL  bit0 = global_enable (default 1)
    //    0x08 SIGNAL   bit0=hit_mode_sig(0=internal) bit1=internal_sub_mode
    //                  (0=random,1=periodic) bit2=cluster_geom_mode
    //    0x0B RATES    [15:0]=hit_rate [31:16]=noise_rate
    //    0x0F TIMEBASE [14:0]=tcc_seed [30:16]=ecc_seed (write reloads LFSR)
    //    0x12 LANE_EN  [7:0]=lane_enable_mask [11:8]=asic_id_base
    // ===============================================================
    localparam [13:0] EMU_CSR_BASE     = 14'h0800;
    localparam [13:0] EMU_UID          = EMU_CSR_BASE + 14'd0;
    localparam [13:0] EMU_CENTRAL      = EMU_CSR_BASE + 14'd7;
    localparam [13:0] EMU_SIGNAL       = EMU_CSR_BASE + 14'd8;
    localparam [13:0] EMU_RATES        = EMU_CSR_BASE + 14'd11;
    localparam [13:0] EMU_TIMEBASE     = EMU_CSR_BASE + 14'd15;
    localparam [13:0] EMU_LANE_ENABLE  = EMU_CSR_BASE + 14'd18;
    localparam [13:0] EMU_CLUSTER_FIX  = EMU_CSR_BASE + 14'd12;  // 0x80C

    localparam [13:0] HIST_CSR_BASE  = 14'h2900;
    localparam [13:0] HIST_UID       = HIST_CSR_BASE + 14'd0;
    localparam [13:0] HIST_CONTROL   = HIST_CSR_BASE + 14'd2;
    localparam [13:0] HIST_TOTAL_HITS= HIST_CSR_BASE + 14'd13;
    localparam [13:0] HIST_DROPPED   = HIST_CSR_BASE + 14'd14;
    localparam [13:0] HIST_PORT_STAT = HIST_CSR_BASE + 14'd12;
    localparam [13:0] HIST_LAST_INT_HITS = HIST_CSR_BASE + 14'd17; // LAST_INTERVAL_TOTAL_HITS

    // CONTROL field encodings per histogram_statistics_v2.vhd.
    //   bit0        = commit/apply
    //   bits[3:2]   = in_port  (READBACK csr_in_port): 00=FILL,01=EXT0,10=EXT1
    //   bits[7:4]   = mode (signed 4-bit): 0=value hist, 1=delay hist
    //   bit8        = key_unsigned
    //   bit12       = filter_enable
    //   bit13       = filter_reject
    //   bits[17:16] = source_select (csr_source_select): 00=TYPE0,01=T1up,10=T1down
    // The contract under test: "CONTROL.in_port = EXT0/EXT1" selects the
    // 87-bit same-cycle-ts Type1 extended plane on hist port 0.
    function automatic [31:0] mk_control(input [1:0] in_port,
                                         input [3:0] mode,
                                         input [1:0] source_sel,
                                         input        commit);
        logic [31:0] w;
        w = '0;
        w[0]      = commit;
        w[3:2]    = in_port;     // documented in_port field
        w[7:4]    = mode;
        w[17:16]  = source_sel;  // source_select field (what the write
                                 // decode actually latches)
        return w;
    endfunction

    int unsigned fail_count = 0;
    task automatic expect_eq(input string what, input [31:0] got,
                             input [31:0] exp);
        if (got !== exp) begin
            $display("[FAIL] %s: got 0x%08h expected 0x%08h", what, got, exp);
            fail_count++;
        end else begin
            $display("[ OK ] %s: 0x%08h", what, got);
        end
    endtask

    task automatic check_true(input string what, input bit cond);
        if (cond) $display("[ OK ] %s", what);
        else begin
            $display("[FAIL] %s", what);
            fail_count++;
        end
    endtask

    // RUN window length in monitor (125 MHz) cycles. ~64 us; long enough
    // for several 1.6 us frame boundaries to fire on hit_type3.
    localparam int RUN_CYCLES = 8192;
    // SCENARIO 3 high-statistics window. The prior 8192-cyc run gave only
    // ~6-12 hits/channel, which cannot distinguish "CH0-2 fire normally"
    // from "CH0-2 near-dead". On HW each CH3..31 saw ~93k hits while CH0-2
    // were a clean ZERO. To make the sim a fair test we run long enough
    // that every channel that fires would accumulate HUNDREDS of hits.
    // 256 scan positions * (1 fire + 1 drain) ~= 512 cyc per full ASIC0
    // sweep at near-100% fire; only 32 of 256 positions are ASIC0, so a
    // full wrap deposits ~32 ASIC0 hits. 1.5M cyc => ~3000 wraps =>
    // O(thousands) hits per ASIC0 channel.
    // 400k cyc (~3.2 ms) still deposits hundreds of hits per ASIC0 channel
    // (decisive for the CH0-2 question) while leaving wall-clock budget for
    // the S6 per-ASIC sweep that follows. Override via +S3_CYCLES if a
    // higher-statistics S3 read is wanted.
    localparam int RUN_CYCLES_S3_HISTAT_DEF = 400_000;
    // S5 periodic single-channel window: ~200k monitor cyc is enough for a
    // decisive delta (100kHz over ~1.6ms => hundreds of hits on one bin)
    // while keeping the wrapper sim tractable.
    localparam int RUN_CYCLES_S5_DEF        = 200_000;
    // Both windows are plusarg-overridable so a focused S5 diagnostic pass
    // can shrink the slow S3 high-stat window without mutating the committed
    // regression default. +S3_CYCLES=<n> +S5_CYCLES=<n>.
    int RUN_CYCLES_S3_HISTAT = RUN_CYCLES_S3_HISTAT_DEF;
    int RUN_CYCLES_S5        = RUN_CYCLES_S5_DEF;
    // Periodic-mode rate sweep override for SCENARIO 1 (Type1 EXT0/EXT1 delay).
    // emu_config_periodic() uses this 16-bit hit_rate so the same scenario can
    // be re-run at 10k/100k/500k/1M hits/s. Default 0x0100 (256) preserves the
    // committed regression behaviour (no plusarg => unchanged). Periodic fire
    // period = 65536 / hit_rate cycles on the 156.25 MHz emulator data clock.
    int S1_HITRATE = 16'h0100;
    // SCENARIO 1 RUN window (monitor 125 MHz cycles). Defaults to RUN_CYCLES so
    // the committed regression is unchanged, but at low periodic rates the fire
    // period (65536/hit_rate emulator cycles) exceeds 8192 cyc, giving an EMPTY
    // delay histogram. +S1_CYCLES=<n> lengthens the window for the rate sweep.
    int RUN_CYCLES_S1 = RUN_CYCLES;
    initial begin
        int v;
        if ($value$plusargs("S3_CYCLES=%d", v)) RUN_CYCLES_S3_HISTAT = v;
        if ($value$plusargs("S5_CYCLES=%d", v)) RUN_CYCLES_S5        = v;
        if ($value$plusargs("S1_HITRATE=%d", v)) S1_HITRATE          = v;
        if ($value$plusargs("S1_CYCLES=%d", v)) RUN_CYCLES_S1        = v;
    end
    // Delay-histogram bin width (cycles per bin). Must match the BIN_WIDTH
    // written to CSR reg5 for scenario 1. The delay value of an occupied
    // bin b is b*S1_DELAY_BIN_W cycles, so the cycle spread is
    // (maxbin-minbin)*S1_DELAY_BIN_W.
    localparam int S1_DELAY_BIN_W = 64;
    // project_cosim_delay_bounds: periodic-mode spread bound (~900 cyc).
    // Quantised to the delay bin width so a 1-bin edge straddle does not
    // false-trip: 14 bins * 64 cyc = 896 cyc, the bin-grid value closest to
    // the documented 900-cyc periodic bound. This is the published bound,
    // not a number tuned to the observed data.
    localparam int S1_DELAY_PERIODIC_BOUND = 14 * S1_DELAY_BIN_W; // 896 cyc

    // Per-scenario measurement registers.
    longint unsigned s1_total_delta, s1_monA_sum, s1_delay_pop;
    int              s1_delay_minbin, s1_delay_maxbin;
    longint unsigned s2_total_delta, s2_monA_sum;
    int              s2_nz_chans;
    // Scenario 3 (TYPE0/bkg) measurement state.
    longint unsigned s3_total_delta;
    int unsigned     s3_bin [0:N_BINS-1];
    // Scenario 4 (RC reliability) state.
    int              s4_runs_ok;
    longint unsigned s4_run_hits [0:4];
    // Scenario 5 (PERIODIC single-channel delta) state.
    int unsigned     s5_bin [0:N_BINS-1];
    int              s5_nz_bins;
    int              s5_peak_bin;
    longint unsigned s5_peak_cnt, s5_total;
    int              s5_target_ch = 10;   // channel N under test
    bit              s5_all_residue_ok;
    // Scenario 6 (per-ASIC independent-addressing sweep) state.
    //  Representative global channels across ALL 8 ASICs. The falsifiable
    //  contract: channel N -> exactly ONE histogram delta at bin N (single
    //  nonzero bin), independently per ASIC. With the broadcast fanout this
    //  MUST fail (one channel would light all 8 bins {N&31, 32+N&31, ...}).
    localparam int   S6_N = 10;
    int              s6_chan   [0:S6_N-1] = '{0, 10, 31, 32, 40, 63, 96, 128, 200, 255};
    int              s6_peak_bin  [0:S6_N-1];
    int              s6_nz_bins   [0:S6_N-1];
    longint unsigned s6_peak_cnt  [0:S6_N-1];
    int              s6_pass_cnt;
    // Scenario 7 (NEW single-channel-mode per-(ASIC,CH) sweep) state.
    //  The fix under test: LANE_ENABLE mask = 1<<asic picks the ASIC;
    //  SIGNAL.single_channel picks the local CH. Each (asic,ch) MUST light
    //  exactly bin asic*32+ch (nz==1). Representative (asic,ch) spanning all
    //  8 ASICs per the task brief.
    localparam int   S7_N = 8;
    int              s7_asic [0:S7_N-1] = '{0,  0,  1, 3, 4, 7,  2,  5};
    int              s7_ch   [0:S7_N-1] = '{0, 31,  8, 5, 0, 31, 16, 20};
    int              s7_pass_cnt;

    // Scenario 8 (EXTENDED-PLANE all-channel coverage) state.
    //  Background scan fires all 8 lanes x 32 channels. EXT0 reads the
    //  UPPER bank (mts_preprocessor_0, ASIC0-3 => key bits[37:30] in
    //  0..127); EXT1 reads the LOWER bank (mts_preprocessor_1, ASIC4-7 =>
    //  key 128..255). Bank UP packs ASIC[2:0] of {0,1,2,3}; bank DW packs
    //  ASIC[2:0] of {4,5,6,7} so the two reads do not alias.
    longint unsigned s8_ext0_bin [0:255];
    longint unsigned s8_ext1_bin [0:255];
    longint unsigned s8_ext0_total, s8_ext1_total;
    int              s8_ext0_nz, s8_ext1_nz;

    // --- Bind-probe channel-trace state (driven by tb_chan_probe binds) ---
    //  Two probe instances bind to (a) the emulator type0 emitter output and
    //  (b) the histogram type0_lane0 input, counting per-channel hit beats.
    //  This is the EXACT-stage evidence: emitted-CH vs ingress-CH vs binned-CH.
    //  A bind is not a TB-body hierarchical reference; it is a standard SV
    //  verification attachment and does not violate the no-driver/no-leaf rule
    //  (it observes only, drives nothing, and is compiled separately).
    logic         s3_probe_clear = 1'b0;
    int unsigned  s3_emit_ch  [0:31];
    int unsigned  s3_ing_ch   [0:31];
    longint unsigned s3_emit_total, s3_ing_total;
    longint unsigned s3_arb_emu, s3_arb_real;
    // TYPE0 stall-localisation chain snapshot (lane 0), captured over the
    // S3 RUNNING window.
    longint unsigned s3_mrg_emu_out, s3_mrg_emu_in, s3_mrg_src_emu;
    longint unsigned s3_mrg_out, s3_mrg_arb_in;

    // DUAL-MONITOR agreement check (A = histogram SRAM, B = hit_type3
    // boundary stream). Tolerance: Monitor B emits Type3 *frames*
    // (header/sub-header/hit/trailer), so its hit-word count can differ
    // from the raw accepted-hit population by the framing overhead and by
    // hits that landed in a frame still open at the window edge. We
    // therefore compare the COUNT of per-hit beats (data[35:32]==0) to the
    // histogram bin-sum and allow a +/-5% framing/edge tolerance. The
    // agreement is the falsifiable gate: a gross divergence (e.g. B==0
    // while A>0) trips regardless of tolerance.
    task automatic check_monitor_agreement();
        longint unsigned a_pop;
        int              b_hits;
        real             rel;
        a_pop  = s1_total_delta + s2_total_delta;       // total A population
        b_hits = monB_up_hits + monB_dn_hits;           // total B hit-words
        $display("[tb] AGREEMENT: MonitorA accepted-hit population = %0d ; MonitorB hit_type3 hit-words = %0d",
                 a_pop, b_hits);
        if (b_hits == 0) begin
            // Either the boundary stream is dead, or hit_type3 never framed
            // during the window. This is a *finding*, not a tunable: the
            // intended independent observable produced nothing.
            $display("[FAIL] DUAL-MONITOR: Monitor B observed ZERO hit_type3 hit-words while Monitor A counted %0d hits.",
                     a_pop);
            $display("[FAIL] DUAL-MONITOR: hit_type3 carries no per-hit population at the wrapper boundary in this run -> independent cross-check is NOT satisfiable here (see report).");
            fail_count++;
            return;
        end
        rel = (b_hits > a_pop) ? real'(b_hits - a_pop) / real'(b_hits)
                               : real'(a_pop - b_hits) / real'(a_pop);
        $display("[tb] AGREEMENT: relative difference = %.3f (tolerance 0.05)", rel);
        check_true("DUAL-MONITOR A vs B agree within 5%", rel <= 0.05);
    endtask

    // ---------------- emulator timebase configuration -------------------
    //  The histogram delay key is gts_8n - hit_ts, where hit_ts is the
    //  MTS-reconstructed 48-bit hit timestamp (decoded MuTRiG coarse
    //  counter + local epoch). For that delta to be the bounded buffering
    //  latency (the quantity the project_cosim_delay_bounds rule covers),
    //  the emulator's coarse timebase must be a DEFINED linear ramp that
    //  resets with the histogram gts at SYNC. Two stimulus conditions:
    //    1. emulator timebase seeded to LFSR15_INIT (=1), reloaded on the
    //       0x0F write (and again on the SYNC-driven emu_rst).
    //    2. emulator in PERIODIC internal mode (SIGNAL.internal_sub_mode=1)
    //       at a modest hit_rate so hits are evenly spaced and the L2/
    //       ticket FIFOs never backpressure (backpressure would inflate the
    //       latency tail). hit_mode_sig=0 keeps the central internal engine
    //       (not the geometry/cluster path).
    //  This does NOT touch the hit VALUE (channel key) - scenario 2's value
    //  histogram is unchanged; it only fixes the TIME axis the delay mode
    //  measures.
    task automatic emu_config_periodic();
        logic [31:0] v;
        avmm_read(EMU_UID, v);
        $display("[tb] emulator UID @word0x%04h = 0x%08h (expect EMUT=0x454D5554)", EMU_UID, v);
        // Re-seed the coarse/encoder LFSRs to the known init (tcc=ecc=1).
        avmm_write(EMU_TIMEBASE, {1'b0, 15'd1, 1'b0, 15'd1});
        // SIGNAL: hit_mode_sig=0 (internal), internal_sub_mode=1 (periodic),
        // cluster_geom_mode=0.
        avmm_write(EMU_SIGNAL, 32'h0000_0002);
        // RATES: periodic phase increment. internal_fire when the 16-bit
        // phase accumulator overflows: fires every ceil(65536/hit_rate)
        // cycles. hit_rate=0x0100 (256) => ~256-cycle period per launch,
        // well below any FIFO fill that would distort the latency. Keep
        // noise_rate low so background does not crowd the signal lanes.
        avmm_write(EMU_RATES, {16'h0040 /*noise*/, S1_HITRATE[15:0] /*hit*/});
        // Keep global_enable set (default), all 8 lanes enabled (default).
        avmm_write(EMU_CENTRAL, 32'h0000_0001);
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(EMU_SIGNAL, v);
        $display("[tb] emulator SIGNAL readback = 0x%08h (sub_mode[1]=%b)", v, v[1]);
        avmm_read(EMU_RATES, v);
        $display("[tb] emulator RATES readback = 0x%08h (hit_rate=%0d => ~%0.0f Hz, period ~%0.0f cyc @156.25MHz)",
                 v, v[15:0], 156.25e6 * real'(v[15:0]) / 65536.0,
                 (v[15:0] != 0) ? 65536.0 / real'(v[15:0]) : 0.0);
    endtask

    // --- emulator BACKGROUND-mode config (reproduces the HW CH0-2 test) ---
    //  CSR map (frontend_csr.sv):
    //    0x07 CENTRAL    bit0  = global_enable
    //    0x09 BACKGROUND bit0  = cfg_hit_mode_bkg
    //    0x0A MUTRIG_FMT bit0=short_mode bit1=gen_idle bits[4:2]=tx_mode
    //                    bit5=enable_type0_stream
    //    0x0B RATES      [15:0]=hit_rate [31:16]=noise_rate
    //    0x12 LANE_EN    [7:0]=lane_enable_mask [11:8]=asic_id_base
    //  frontend_bkg_generator.sv scans scan_pos 0..255 round-robin; lane =
    //  scan_pos[7:5], channel = scan_pos[4:0]. The qsys lane wrapper
    //  (emulator_mutrig_qsys_lane.sv:117) hardwires LANE_COUNT=1, so only
    //  scan_pos[7:5]==0 (ASIC0, CH0..31) can fire (fire_value requires
    //  lane_index_value < LANE_COUNT). noise_rate sets the per-visit fire
    //  threshold (folded_noise_threshold). All 8 lane-mask bits set.
    localparam [13:0] EMU_BACKGROUND = EMU_CSR_BASE + 14'd9;
    localparam [13:0] EMU_MUTRIG_FMT = EMU_CSR_BASE + 14'd10;
    task automatic emu_config_background();
        logic [31:0] v;
        // Re-seed coarse/encoder LFSRs so ts fields are defined.
        avmm_write(EMU_TIMEBASE, {1'b0, 15'd1, 1'b0, 15'd1});
        // Internal-signal engine OFF; we want pure background scan hits.
        // SIGNAL bit0=hit_mode_sig(0=internal). Leave hit_rate=0 below.
        avmm_write(EMU_SIGNAL, 32'h0000_0000);
        // BACKGROUND mode ON.
        avmm_write(EMU_BACKGROUND, 32'h0000_0001);
        // MUTRIG_FORMAT: keep enable_type0_stream(bit5)=1, gen_idle(bit1)=0
        // so the lane backend drains on its own pacer, short_mode(bit0)=0.
        avmm_write(EMU_MUTRIG_FMT, 32'h0000_0020);
        // RATES: hit_rate=0 (no signal engine), noise_rate sets bkg fire
        // probability. folded_noise_threshold(rate) = rate<<8 (clamped). At
        // rate=0xFF => threshold = 0xFF00 (~99.6% fire/visit). This is the
        // HIGH-STATISTICS setting: with the scan visiting every position at
        // near-100% fire and a long RUN window, every channel that CAN fire
        // accumulates hundreds-to-thousands of hits. That is what makes the
        // CH0-2 question decisive (6-12 hits/ch could not).
        avmm_write(EMU_RATES, {16'h00FF /*noise*/, 16'h0000 /*hit*/});
        // All 8 lanes enabled (only lane0 exists in the LANE_COUNT=1 wrapper,
        // but the mask gate is checked against scan_pos[7:5]).
        avmm_write(EMU_LANE_ENABLE, 32'h0000_00FF);
        avmm_write(EMU_CENTRAL, 32'h0000_0001);
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(EMU_BACKGROUND, v);
        $display("[tb] emulator BACKGROUND readback = 0x%08h (bkg=%b)", v, v[0]);
        avmm_read(EMU_MUTRIG_FMT, v);
        $display("[tb] emulator MUTRIG_FORMAT readback = 0x%08h (type0_stream[5]=%b gen_idle[1]=%b)", v, v[5], v[1]);
    endtask

    // --- emulator INTERNAL/PERIODIC single-channel config ---------------
    //  This is the acceptance recipe under debug: ONE channel N at a known
    //  rate must produce a clean DELTA at bin N. Uses FIXED cluster geometry
    //  (cfg_cluster_geom_mode=0), CLUSTER_FIX left low=high=N enable.
    //    SIGNAL  (0x08): hit_mode_sig=0 internal, internal_sub_mode=1 periodic,
    //                    cluster_geom_mode=0 (bit2=0) => FIXED geometry.
    //    CLUSTER_FIX(0x0C): (1<<14)|(N<<7)|N  (left_en, left_high=N, left_low=N)
    //    RATES   (0x0B): [15:0]=hit_rate; periodic fire = f_clk*hit_rate/65536.
    //                    The emulator data_clock = mu3e_lvds_controller_0.outclock
    //                    = 156.25 MHz, so hit_rate=42 => 100.14 kHz on ONE channel.
    //    BACKGROUND(0x09)=0 (no bkg scan), CENTRAL(0x07) bit0=1 global_enable.
    //  Global channel N (0..255) selects the engine geometry: the core
    //  maps cfg_hit_channel = {side, local[6:0]} where side=N[7] picks the
    //  CLUSTER_FIX left half (N<128) or right half (N>=128) and local =
    //  N[6:0]. With LANE_COUNT=8 + asic_id_base=0, the trigger engine
    //  dispatches that global channel to lane = N>>5 (local CH = N&31,
    //  asic_id = N>>5), so the emitted hit_type0 key data[43:36] = N. After
    //  the 8-lane independent datapath, channel N must produce exactly ONE
    //  histogram delta at bin N.
    task automatic emu_config_periodic_single(input int n_chan, input [15:0] rate);
        logic [31:0] v;
        logic [31:0] cluster_fix_v;
        logic [6:0]  local_v;
        avmm_write(EMU_TIMEBASE, {1'b0, 15'd1, 1'b0, 15'd1});
        // BACKGROUND off so only the signal engine fires.
        avmm_write(EMU_BACKGROUND, 32'h0000_0000);
        // SIGNAL: internal(0) + periodic(1) + FIXED geom(0) => 0x02.
        avmm_write(EMU_SIGNAL, 32'h0000_0002);
        // CLUSTER_FIX dual-side: low=high=local on the half N belongs to.
        //   left  : left_low[6:0]  left_high[13:7]  left_enable[14]
        //   right : right_low[22:16] right_high[29:23] right_enable[30]
        local_v = n_chan[6:0];
        if (n_chan < 128) begin
            cluster_fix_v = (32'h1 << 14) | ({25'b0, local_v} << 7) | {25'b0, local_v};
        end else begin
            cluster_fix_v = (32'h1 << 30) | ({25'b0, local_v} << 23) | ({25'b0, local_v} << 16);
        end
        avmm_write(EMU_CLUSTER_FIX, cluster_fix_v);
        // RATES: hit_rate sets periodic fire; noise_rate=0 (bkg already off).
        avmm_write(EMU_RATES, {16'h0000 /*noise*/, rate /*hit*/});
        // Keep type0 stream enabled, gen_idle off.
        avmm_write(EMU_MUTRIG_FMT, 32'h0000_0020);
        avmm_write(EMU_LANE_ENABLE, 32'h0000_00FF);
        avmm_write(EMU_CENTRAL, 32'h0000_0001);
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(EMU_SIGNAL, v);
        $display("[tb] S5 emulator SIGNAL readback = 0x%08h (sig[0]=%b sub[1]=%b geom[2]=%b)",
                 v, v[0], v[1], v[2]);
        avmm_read(EMU_CLUSTER_FIX, v);
        $display("[tb] S5 emulator CLUSTER_FIX readback = 0x%08h (N=%0d local=%0d side=%0d L_en=%b R_en=%b)",
                 v, n_chan, local_v, (n_chan >= 128), v[14], v[30]);
        avmm_read(EMU_RATES, v);
        $display("[tb] S5 emulator RATES readback = 0x%08h (hit_rate=%0d)", v, v[15:0]);
    endtask

    // --- emulator SINGLE-CHANNEL-MODE config (the NEW last-stage gate) ---
    //  This is the on-board acceptance recipe AFTER the fix. The (ASIC,CH)
    //  target is picked by:
    //    LANE_ENABLE(0x12)[7:0] = 1<<asic        (the ASIC = which lane emits)
    //    SIGNAL(0x08) bit3 = single_channel_mode = 1
    //                 bits[12:8] = single_channel = local CH (0..31)
    //                 bit1 = internal_sub_mode = 1 (periodic)
    //                 bit0 = hit_mode_sig = 0 (internal)
    //    RATES(0x0B)[15:0] = hit_rate (periodic fire)
    //    BACKGROUND(0x09) = 0, CENTRAL(0x07) bit0 = 1.
    //  The trigger engine's last frontend stage shreds the launch to exactly
    //  the lanes in LANE_ENABLE, each at local channel single_channel, so the
    //  emitted type0 key {asic_id, channel} = asic*32 + ch lights exactly one
    //  histogram bin. No cluster geometry, no global-position shred, no
    //  round-robin spread. CLUSTER_FIX is irrelevant in this mode.
    task automatic emu_config_periodic_single_mode(input int asic, input int local_ch,
                                                    input [15:0] rate);
        logic [31:0] v;
        logic [31:0] sig_v;
        avmm_write(EMU_TIMEBASE, {1'b0, 15'd1, 1'b0, 15'd1});
        avmm_write(EMU_BACKGROUND, 32'h0000_0000);
        // SIGNAL: internal(0) + periodic(1) + geom irrelevant(0) +
        //         single_channel_mode(bit3=1) + single_channel(bits[12:8]).
        sig_v = 32'h0000_0002 | (32'h1 << 3) | ({27'b0, local_ch[4:0]} << 8);
        avmm_write(EMU_SIGNAL, sig_v);
        avmm_write(EMU_RATES, {16'h0000 /*noise*/, rate /*hit*/});
        avmm_write(EMU_MUTRIG_FMT, 32'h0000_0020);
        // LANE_ENABLE mask = 1<<asic picks the ASIC (which lane emits).
        avmm_write(EMU_LANE_ENABLE, (32'h1 << asic[2:0]));
        avmm_write(EMU_CENTRAL, 32'h0000_0001);
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(EMU_SIGNAL, v);
        $display("[tb] S7 SIGNAL readback = 0x%08h (sub[1]=%b sc_mode[3]=%b sc[12:8]=%0d)",
                 v, v[1], v[3], v[12:8]);
        avmm_read(EMU_LANE_ENABLE, v);
        $display("[tb] S7 LANE_ENABLE readback = 0x%08h (mask=0x%02h => ASIC %0d)",
                 v, v[7:0], asic);
    endtask

    // --- S7: drive ONE (ASIC,CH) via the NEW single-channel mode, run a
    //  window, read the frozen TYPE0 value histogram. Channel-mask picks the
    //  ASIC; SIGNAL.single_channel picks the local CH. Expect exactly ONE
    //  histogram delta at bin asic*32+ch.
    task automatic run_single_channel_mode_check(input int    asic,
                                                 input int    local_ch,
                                                 input [15:0] rate,
                                                 input int    run_cycles,
                                                 output int   peak_bin,
                                                 output int   nz_bins,
                                                 output longint unsigned peak_cnt);
        logic [31:0] li;
        int exp_bin;
        exp_bin = asic*32 + local_ch;
        emu_config_periodic_single_mode(asic, local_ch, rate);
        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);     // LEFT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd256);   // RIGHT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd1);     // BIN_WIDTH
        avmm_write(HIST_CONTROL, 32'h0000_0001 | 32'h0000_0100); // TYPE0/value/commit/key_unsigned
        repeat (8) @(posedge avmm_clk_clk);
        runctl_hold(9'h001, 16);                     // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);  // PREP
        runctl_hold(9'h004, 32);                     // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;            // RUNNING
        runctl_mgmt_host_valid <= 1'b1;
        repeat (run_cycles) @(posedge monitor_clock_125_in_clk);
        runctl_terminate_flush();
        avmm_read(HIST_LAST_INT_HITS, li);
        monA_read_all_bins();
        peak_bin = -1; nz_bins = 0; peak_cnt = 0;
        for (int b = 0; b < N_BINS; b++) begin
            if (monA_bin[b] != 0) begin
                nz_bins++;
                if (monA_bin[b] > peak_cnt) begin peak_cnt = monA_bin[b]; peak_bin = b; end
            end
        end
        $display("[tb] S7 (ASIC=%0d CH=%0d => exp bin %0d): LAST_INT_HITS=%0d nz_bins=%0d peak_bin=%0d peak_cnt=%0d",
                 asic, local_ch, exp_bin, li, nz_bins, peak_bin, peak_cnt);
        for (int b = 0; b < N_BINS; b++)
            if (monA_bin[b] != 0)
                $display("[tb]     S7 nonzero bin[%0d] (ASIC=%0d CH=%0d) = %0d hits",
                         b, b/32, b%32, monA_bin[b]);
    endtask

    // --- S6: drive ONE global channel, run a window, read the frozen
    //  TYPE0 value histogram, and return the peak bin / nonzero-bin count.
    //  This is the per-ASIC independent-addressing primitive: with the
    //  8-lane datapath, channel N must light exactly bin N (nz==1, peak==N).
    task automatic run_single_channel_check(input int    n_chan,
                                            input [15:0]  rate,
                                            input int     run_cycles,
                                            output int    peak_bin,
                                            output int    nz_bins,
                                            output longint unsigned peak_cnt);
        logic [31:0] ctrl_rb;
        logic [31:0] li;
        tb_chan_probe_pkg::clear_all();
        tb_chan_probe_pkg::clear_diag_asic();
        emu_config_periodic_single(n_chan, rate);
        // TYPE0 value histogram, bins [0,256) width 1 => bin == data[43:36].
        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);     // LEFT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd256);   // RIGHT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd1);     // BIN_WIDTH
        avmm_write(HIST_CONTROL, 32'h0000_0001 | 32'h0000_0100); // TYPE0/value/commit/key_unsigned
        repeat (8) @(posedge avmm_clk_clk);
        runctl_hold(9'h001, 16);                     // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);  // PREP
        runctl_hold(9'h004, 32);                     // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;            // RUNNING
        runctl_mgmt_host_valid <= 1'b1;
        repeat (run_cycles) @(posedge monitor_clock_125_in_clk);
        runctl_terminate_flush();
        avmm_read(HIST_LAST_INT_HITS, li);
        monA_read_all_bins();
        peak_bin = -1; nz_bins = 0; peak_cnt = 0;
        for (int b = 0; b < N_BINS; b++) begin
            if (monA_bin[b] != 0) begin
                nz_bins++;
                if (monA_bin[b] > peak_cnt) begin peak_cnt = monA_bin[b]; peak_bin = b; end
            end
        end
        $display("[tb] S6 ch=%0d (ASIC=%0d local=%0d): LAST_INT_HITS=%0d nz_bins=%0d peak_bin=%0d peak_cnt=%0d",
                 n_chan, n_chan/32, n_chan%32, li, nz_bins, peak_bin, peak_cnt);
        for (int b = 0; b < N_BINS; b++)
            if (monA_bin[b] != 0)
                $display("[tb]     S6 ch=%0d nonzero bin[%0d] (ASIC=%0d CH=%0d) = %0d hits",
                         n_chan, b, b/32, b%32, monA_bin[b]);
        // DIAG dump: divider input key histogram + raw [43:36] slice histogram.
        $display("[tb] S6 DIAG ch=%0d key_total=%0d slice_total=%0d asic[44:41]{X=%0d ok=%0d} ch[40:36]{X=%0d ok=%0d}",
                 n_chan, tb_chan_probe_pkg::key_total, tb_chan_probe_pkg::slice_total,
                 tb_chan_probe_pkg::slice_asic_x, tb_chan_probe_pkg::slice_asic_ok,
                 tb_chan_probe_pkg::slice_ch_x, tb_chan_probe_pkg::slice_ch_ok);
        $display("[tb] S6 DIAG-ASIC ch=%0d cfg_asic_base=0x%01h cfg{X=%0d ok=%0d} emit_beats=%0d emit_asic{X=%0d ok=%0d}",
                 n_chan, tb_chan_probe_pkg::diag_cfg_asic_base,
                 tb_chan_probe_pkg::diag_cfg_x, tb_chan_probe_pkg::diag_cfg_ok,
                 tb_chan_probe_pkg::diag_emit_beats,
                 tb_chan_probe_pkg::diag_emit_asic_x, tb_chan_probe_pkg::diag_emit_asic_ok);
        $display("[tb] S6 DIAG-ASIC2 ch=%0d asic_id_in{X=%0d ok=%0d} last_asicid=0x%01h data44{X=%0d} data43_41{X=%0d}",
                 n_chan, tb_chan_probe_pkg::diag_asicid_x, tb_chan_probe_pkg::diag_asicid_ok,
                 tb_chan_probe_pkg::diag_last_asicid,
                 tb_chan_probe_pkg::diag_emit_d44_x, tb_chan_probe_pkg::diag_emit_d4341_x);
        $display("[tb] S6 DIAG-ASIC3 ch=%0d core_wire cfg_asic_id_base=0x%01h core{X=%0d ok=%0d}",
                 n_chan, tb_chan_probe_pkg::diag_core_asic_base,
                 tb_chan_probe_pkg::diag_core_x, tb_chan_probe_pkg::diag_core_ok);
        for (int v = 0; v < 256; v++)
            if (tb_chan_probe_pkg::key_hist[v] != 0)
                $display("[tb]     S6 DIAG ch=%0d divider_in_key[%0d] = %0d beats",
                         n_chan, v, tb_chan_probe_pkg::key_hist[v]);
        for (int v = 0; v < 256; v++)
            if (tb_chan_probe_pkg::slice_hist[v] != 0)
                $display("[tb]     S6 DIAG ch=%0d data[43:36]=%0d : %0d beats",
                         n_chan, v, tb_chan_probe_pkg::slice_hist[v]);
        tb_chan_probe_pkg::clear_all();
    endtask

    // --- S8: EXTENDED-PLANE all-channel coverage under BACKGROUND scan.
    //  Drive the emulator background scanner (all 8 lanes, all 32 channels),
    //  hold a RUN window, then read the frozen value histogram once per
    //  in_port (EXT0, then EXT1). The extended sinks key on Type1 payload
    //  bits[37:30] = ASIC[2:0]<<5 | CH[4:0]. EXT0 must populate ASIC0-3
    //  (keys 0..127), EXT1 must populate ASIC4-7 (keys 128..255). This is
    //  the falsifiable per-channel Type1-rate read the histogram needs.
    //  in_port chooses the extended sink; source_select(T1up/T1down) is set
    //  to match but is NOT itself sampled by the ingress (only TYPE0 and
    //  EXT0/EXT1 are - see histogram_statistics_v2.vhd port_valid mux).
    task automatic run_ext_background_read(input [1:0] in_port,
                                           output longint unsigned tot,
                                           output int              nz,
                                           ref    longint unsigned binv [0:255]);
        logic [31:0] ctrl_rb, li;
        emu_config_background();
        // Value histogram, bins [0,256) width 1 => bin == key. key_unsigned
        // so the 8-bit ASIC+CH key is a non-negative channel id.
        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);     // LEFT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd256);   // RIGHT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd1);     // BIN_WIDTH
        avmm_write(HIST_CONTROL, (mk_control(in_port, 4'd0 /*value*/,
                                  (in_port == 2'b01) ? 2'b01 : 2'b10 /*T1up/down*/,
                                  1'b1 /*commit*/) | 32'h0000_0100 /*key_unsigned*/));
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(HIST_CONTROL, ctrl_rb);
        $display("[tb] S8 in_port=%02b CONTROL readback = 0x%08h (in_port[3:2]=%02b)",
                 in_port, ctrl_rb, ctrl_rb[3:2]);
        runctl_hold(9'h001, 16);                      // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);   // PREP
        runctl_hold(9'h004, 32);                      // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;             // RUNNING
        runctl_mgmt_host_valid <= 1'b1;
        repeat (200_000) @(posedge monitor_clock_125_in_clk);
        runctl_terminate_flush();
        avmm_read(HIST_LAST_INT_HITS, li);
        tot = li;
        monA_read_all_bins();
        nz = 0;
        for (int b = 0; b < 256; b++) begin
            binv[b] = monA_bin[b];
            if (monA_bin[b] != 0) nz++;
        end
    endtask

    // ------------------------- run sequence ------------------------
    logic [31:0] readback;
    logic [31:0] ctrl_rb;
    logic [31:0] total_before, total_after;
    initial begin
        $display("[tb_scifi_v4_wrapper] starting; DUT = scifi_datapath_system_v4 (no leaf-IP source in vcom list)");

        // Allow reset to release.
        #2_000;

        // ---- sanity: avmm path to hist alive (UID = "HIST") ----------
        avmm_read(HIST_UID, readback);
        expect_eq("hist UID @0x2900", readback, 32'h4849_5354);

        // ---- F2: put the emulator into a DEFINED periodic timebase so the
        //      delay-mode histogram measures the bounded buffering latency,
        //      not the free-running PRBS-vs-gts scatter. ------------------
        emu_config_periodic();

        // ============================================================
        //  SCENARIO 1 - mode 1 (delay histogram) on EXT0 (upper bank).
        //  Per the contract this routes hist port 0 from the 87-bit
        //  same-cycle-ts extended sink fed by mts_preprocessor_0.
        // ============================================================
        $display("--- SCENARIO 1: CONTROL.in_port=EXT0, mode=1 (delay) ---");
        // Configure the histogram window to cover the delay range. The
        // default window is [0,256) bin_width=1; the measured delay
        // (gts - true_ts) overflowed it (OVERFLOW ~= TOTAL_HITS, bins
        // empty). Widen to [0,4096) bin_width=16 (power-of-2 required by
        // POWER2_BIN_WIDTH_ONLY). 256 bins * 16 cyc = 4096-cycle span.
        // These bounds are applied together with the CONTROL commit.
        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);      // LEFT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd16384);  // RIGHT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd64);     // BIN_WIDTH (pow2)
        avmm_write(HIST_CONTROL, mk_control(2'b01 /*EXT0*/, 4'd1 /*delay*/,
                                            2'b01 /*T1up*/, 1'b1 /*commit*/));
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(HIST_CONTROL, ctrl_rb);
        $display("[tb] CONTROL readback = 0x%08h (in_port[3:2]=%02b mode[7:4]=%01h src[17:16]=%02b err[24]=%b)",
                 ctrl_rb, ctrl_rb[3:2], ctrl_rb[7:4], ctrl_rb[17:16], ctrl_rb[24]);
        // FALSIFIABLE: the documented in_port field MUST read back EXT0.
        // If the RTL has no write path to csr_in_port this trips.
        expect_eq("CONTROL.in_port reads EXT0 after write", {30'b0, ctrl_rb[3:2]}, 32'h0000_0001);
        expect_eq("CONTROL.mode reads 1 (delay)",            {28'b0, ctrl_rb[7:4]}, 32'h0000_0001);
        expect_eq("CONTROL.commit cleared no error",         {31'b0, ctrl_rb[24]}, 32'h0000_0000);

        // Drive run-control to RUNNING and HOLD it for the whole window.
        // RUN entry clears the histogram (run_start_clear_pulse), so the
        // accumulated population over the window == the frozen interval
        // total. Open Monitor B's window over the SAME run.
        //
        // PREP must be held until the ring_buffer_cam 512-entry flush
        // completes (see runctl_hold_until_ready). A 16-cycle PREP left the
        // CAM mid-flush so the readout side never armed and hit_type3 stayed
        // dead. Hold >= 768 cycles (> 512 flush + handshake margin).
        runctl_hold(9'h001, 16);                     // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);  // PREP (await flush ack)
        runctl_hold(9'h004, 32);                     // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;   // RUNNING - held for the window
        runctl_mgmt_host_valid <= 1'b1;
        monB_active = 1'b1;
        repeat (RUN_CYCLES_S1) @(posedge monitor_clock_125_in_clk);
        // DIAGNOSTIC (live, before flush resets them): why are bins empty
        // while TOTAL_HITS counts accepts? underflow/overflow => the delay
        // key fell outside [left_bound,right_bound]; dropped => coalescing
        // backpressure.
        begin
            logic [31:0] th, uf, ov, dr, coal, bank, port;
            avmm_read(HIST_TOTAL_HITS,        th);
            avmm_read(HIST_CSR_BASE + 14'd8,  uf);
            avmm_read(HIST_CSR_BASE + 14'd9,  ov);
            avmm_read(HIST_DROPPED,           dr);
            avmm_read(HIST_CSR_BASE + 14'd15, coal);
            avmm_read(HIST_CSR_BASE + 14'd11, bank);
            avmm_read(HIST_PORT_STAT,         port);
            $display("[diag] live TOTAL_HITS=%0d UNDERFLOW=%0d OVERFLOW=%0d DROPPED=%0d COAL=0x%08h BANK=0x%08h PORT=0x%08h",
                     th, uf, ov, dr, coal, bank, port);
        end
        // Clean snapshot via TERMINATING (no wipe). reg17 latches the
        // frozen interval's accepted-hit total.
        runctl_terminate_flush();
        avmm_read(HIST_LAST_INT_HITS, total_after);
        s1_total_delta = total_after;   // frozen-interval accepted hits

        // Monitor A: read the full 256-bin frozen delay histogram.
        monA_read_all_bins();
        s1_monA_sum     = monA_sum;
        s1_delay_minbin = -1;
        s1_delay_maxbin = -1;
        s1_delay_pop    = 0;
        for (int b = 0; b < N_BINS; b++) begin
            if (monA_bin[b] != 0) begin
                if (s1_delay_minbin < 0) s1_delay_minbin = b;
                s1_delay_maxbin = b;
                s1_delay_pop    = s1_delay_pop + monA_bin[b];
            end
        end

        $display("[tb] EXT0/delay: hist TOTAL_HITS delta(A scalar)=%0d  monA bin-sum=%0d",
                 s1_total_delta, s1_monA_sum);
        $display("[tb] EXT0/delay: monA occupied delay bins [%0d .. %0d] => delay [%0d .. %0d] cyc, spread=%0d cyc  pop=%0d (overflow excluded)",
                 s1_delay_minbin, s1_delay_maxbin,
                 (s1_delay_minbin>=0)? s1_delay_minbin*S1_DELAY_BIN_W : 0,
                 (s1_delay_maxbin>=0)? s1_delay_maxbin*S1_DELAY_BIN_W : 0,
                 (s1_delay_maxbin >= 0) ? (s1_delay_maxbin - s1_delay_minbin)*S1_DELAY_BIN_W : 0, s1_delay_pop);
        $display("[tb] EXT0/delay: MonitorB boundary  hit_type3 upper beats=%0d (hits=%0d subhdr=%0d sop=%0d eop=%0d)  lower beats=%0d (hits=%0d subhdr=%0d)",
                 upper_beats, monB_up_hits, monB_up_subhdr, monB_up_sop, monB_up_eop,
                 lower_beats, monB_dn_hits, monB_dn_subhdr);
        // Machine-parseable full-bin dump for the off-line latency plotter.
        // Format: "S1DELAYBIN <bin> <delay_cyc> <count>" for every nonzero bin.
        // bin b -> delay = b*S1_DELAY_BIN_W cycles.
        $display("[tb] S1DELAY_META hitrate=%0d bin_w=%0d nbins=%0d total=%0d port=EXT0_T1up",
                 S1_HITRATE, S1_DELAY_BIN_W, N_BINS, s1_total_delta);
        for (int b = 0; b < N_BINS; b++)
            if (monA_bin[b] != 0)
                $display("[tb] S1DELAYBIN %0d %0d %0d", b, b*S1_DELAY_BIN_W, monA_bin[b]);
        $display("[tb] S1DELAY_END");

        // ============================================================
        //  SCENARIO 2 - mode 0 (value histogram) on EXT1 (lower bank).
        //  Value mode keys on the Type1 ASIC+CH slice => per-channel
        //  occupancy. Sum over bins = total accepted hits.
        // ============================================================
        $display("--- SCENARIO 2: CONTROL.in_port=EXT1, mode=0 (value) ---");
        // Value mode keys on the Type1 ASIC+CH slice (0..255). Window
        // [0,256) bin_width=1 => bin index == channel key. key_unsigned=1
        // (bit8) so the 8-bit key is treated as a non-negative channel id.
        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);     // LEFT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd256);   // RIGHT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd1);     // BIN_WIDTH
        avmm_write(HIST_CONTROL, (mk_control(2'b10 /*EXT1*/, 4'd0 /*value*/,
                                            2'b10 /*T1down*/, 1'b1 /*commit*/) | 32'h0000_0100 /*key_unsigned*/));
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(HIST_CONTROL, ctrl_rb);
        $display("[tb] CONTROL readback = 0x%08h (in_port[3:2]=%02b mode[7:4]=%01h src[17:16]=%02b err[24]=%b)",
                 ctrl_rb, ctrl_rb[3:2], ctrl_rb[7:4], ctrl_rb[17:16], ctrl_rb[24]);
        expect_eq("CONTROL.in_port reads EXT1 after write", {30'b0, ctrl_rb[3:2]}, 32'h0000_0002);

        // Re-enter the run cleanly: IDLE -> PREP -> SYNC -> RUNNING re-arms
        // term_flush and clears the histogram for the new EXT1/value run.
        // Same handshake-aware PREP as scenario 1 so the CAM readout arms.
        runctl_hold(9'h001, 16);                     // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);  // PREP (await flush ack)
        runctl_hold(9'h004, 32);                     // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;   // RUNNING
        runctl_mgmt_host_valid <= 1'b1;
        monB_active = 1'b1;
        repeat (RUN_CYCLES) @(posedge monitor_clock_125_in_clk);
        begin
            logic [31:0] th, uf, ov, dr;
            avmm_read(HIST_TOTAL_HITS,        th);
            avmm_read(HIST_CSR_BASE + 14'd8,  uf);
            avmm_read(HIST_CSR_BASE + 14'd9,  ov);
            avmm_read(HIST_DROPPED,           dr);
            $display("[diag] S2 live TOTAL_HITS=%0d UNDERFLOW=%0d OVERFLOW=%0d DROPPED=%0d",
                     th, uf, ov, dr);
        end
        runctl_terminate_flush();
        // Close Monitor B's window after both RUN windows AND both
        // TERMINATING drains have completed. hit_type3 frames flush during
        // the drains (OR-reduce gate), so the window must span them.
        monB_active = 1'b0;
        avmm_read(HIST_LAST_INT_HITS, total_after);
        s2_total_delta = total_after;

        monA_read_all_bins();
        s2_monA_sum   = monA_sum;
        s2_nz_chans   = 0;
        for (int b = 0; b < N_BINS; b++)
            if (monA_bin[b] != 0) s2_nz_chans = s2_nz_chans + 1;

        $display("[tb] EXT1/value: hist TOTAL_HITS delta(A scalar)=%0d  monA bin-sum=%0d  occupied channels=%0d",
                 s2_total_delta, s2_monA_sum, s2_nz_chans);
        for (int b = 0; b < N_BINS; b++)
            if (monA_bin[b] != 0)
                $display("[tb]     value-bin[%0d] (ASIC+CH key) = %0d hits", b, monA_bin[b]);

        // ============================================================
        //  SCENARIO 3 - TYPE0 source, emulator BACKGROUND mode, value
        //  histogram. This reproduces the on-hardware CH0-2 drop test.
        //  source_select=TYPE0(00), in_port=FILL(00), mode=0(value),
        //  key_unsigned=1, bins [0,256) width 1 => bin == data[43:36]
        //  == {asic_id[2:0], channel[4:0]} == ASIC<<5 | CH.
        // ============================================================
        $display("--- SCENARIO 3: source=TYPE0, emulator BACKGROUND, value hist (CH0-2 repro) ---");
        emu_config_background();

        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);     // LEFT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd256);   // RIGHT_BOUND
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd1);     // BIN_WIDTH
        // CONTROL: source=TYPE0(00), in_port=FILL(00), mode=0, key_unsigned, commit.
        avmm_write(HIST_CONTROL, 32'h0000_0001 /*commit*/ | 32'h0000_0100 /*key_unsigned*/);
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(HIST_CONTROL, ctrl_rb);
        $display("[tb] S3 CONTROL readback = 0x%08h (in_port[3:2]=%02b mode[7:4]=%01h src[17:16]=%02b err[24]=%b)",
                 ctrl_rb, ctrl_rb[3:2], ctrl_rb[7:4], ctrl_rb[17:16], ctrl_rb[24]);

        // Reset the bind-probe per-channel emitter/ingress tallies for a clean
        // measurement window aligned to this RUN.
        s3_probe_clear = 1'b1;
        repeat (4) @(posedge monitor_clock_125_in_clk);
        s3_probe_clear = 1'b0;

        runctl_hold(9'h001, 16);                     // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);  // PREP
        runctl_hold(9'h004, 32);                     // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;            // RUNNING
        runctl_mgmt_host_valid <= 1'b1;
        // HIGH-STATISTICS run window (the "different read" at high stats).
        repeat (RUN_CYCLES_S3_HISTAT) @(posedge monitor_clock_125_in_clk);
        begin
            logic [31:0] th, uf, ov, dr;
            avmm_read(HIST_TOTAL_HITS,        th);
            avmm_read(HIST_CSR_BASE + 14'd8,  uf);
            avmm_read(HIST_CSR_BASE + 14'd9,  ov);
            avmm_read(HIST_DROPPED,           dr);
            $display("[diag] S3 live TOTAL_HITS=%0d UNDERFLOW=%0d OVERFLOW=%0d DROPPED=%0d", th, uf, ov, dr);
        end
        runctl_terminate_flush();
        avmm_read(HIST_LAST_INT_HITS, total_after);
        s3_total_delta = total_after;

        monA_read_all_bins();
        for (int b = 0; b < N_BINS; b++) s3_bin[b] = monA_bin[b];

        // Per-channel report for ASIC0 (bins 0..31).
        $display("[tb] S3 TYPE0/bkg: LAST_INTERVAL_HITS=%0d  monA bin-sum=%0d", s3_total_delta, monA_sum);
        for (int b = 0; b < 32; b++)
            $display("[tb]     S3 ASIC0 CH%0d = bin[%0d] = %0d hits", b, b, s3_bin[b]);
        // The falsifiable CH0-2 question:
        $display("[tb] S3 CH0=%0d CH1=%0d CH2=%0d  | CH3=%0d CH4=%0d CH5=%0d ... CH31=%0d",
                 s3_bin[0], s3_bin[1], s3_bin[2], s3_bin[3], s3_bin[4], s3_bin[5], s3_bin[31]);
        // Bind-probe evidence: did the emulator EMIT CH0-2, and did the
        // histogram type0_lane0 ingress SEE CH0-2?
        $display("[tb] S3 PROBE emulator emitted per-CH (ASIC0): CH0=%0d CH1=%0d CH2=%0d CH3=%0d  total=%0d",
                 s3_emit_ch[0], s3_emit_ch[1], s3_emit_ch[2], s3_emit_ch[3], s3_emit_total);
        $display("[tb] S3 PROBE hist type0_lane0 ingress per-CH: CH0=%0d CH1=%0d CH2=%0d CH3=%0d  total=%0d",
                 s3_ing_ch[0], s3_ing_ch[1], s3_ing_ch[2], s3_ing_ch[3], s3_ing_total);
        $display("[tb] S3 PROBE merger egress source: emu=%0d real=%0d (merger SOURCE_SEL_DEFAULT=EMU; arb supercore removed in #63)",
                 s3_arb_emu, s3_arb_real);
        // TYPE0 stall-localisation chain (lane 0). First stage reading 0
        // while its upstream is nonzero is the break.
        $display("[tb] S3 TYPE0-CHAIN(lane0): emu_aso_valid=%0d -> merger_asi_emu_valid=%0d | cfg_source_is_emu(cycles=1)=%0d (last=%b) | merger_aso_out_valid=%0d -> hist_type0_lane0_tap.in=%0d",
                 s3_mrg_emu_out, s3_mrg_emu_in, s3_mrg_src_emu,
                 tb_chan_probe_pkg::mrg_src_is_emu_last,
                 s3_mrg_out, s3_mrg_arb_in);
        // Full per-channel emit / ingress / binned table for ASIC0 (CH0..31)
        // at high statistics. This is the decisive read: if bin/ingress/emit
        // for CH0,1,2 are ~0 while CH3..31 are large => CH0-2 reproduced-dead.
        $display("[tb] S3 HISTAT per-channel (ASIC0) CH : emit / ingress / bin");
        for (int c = 0; c < 32; c++)
            $display("[tb]     S3 HISTAT CH%0d : emit=%0d ing=%0d bin=%0d",
                     c, s3_emit_ch[c], s3_ing_ch[c], s3_bin[c]);

        // ============================================================
        //  SCENARIO 4 - RC-host reliability: 5 repeated run cycles in one
        //  sim, deterministic runctl. Each cycle must enter RUNNING and
        //  accumulate (>0 hits) on the TYPE0/bkg config left configured
        //  above. This tests the user's claim that the RC host is reliable
        //  and the on-board flakiness is host-side SC methodology.
        // ============================================================
        $display("--- SCENARIO 4: RC-host reliability, 5 repeated run cycles ---");
        s4_runs_ok = 0;
        for (int cyc = 0; cyc < 5; cyc++) begin
            logic [31:0] li;
            runctl_hold(9'h001, 16);                     // IDLE
            runctl_hold_until_ready(9'h002, 768, 2048);  // PREP
            runctl_hold(9'h004, 32);                     // SYNC
            @(posedge monitor_clock_125_in_clk);
            runctl_mgmt_host_data  <= 9'h008;            // RUNNING
            runctl_mgmt_host_valid <= 1'b1;
            repeat (RUN_CYCLES) @(posedge monitor_clock_125_in_clk);
            runctl_terminate_flush();
            avmm_read(HIST_LAST_INT_HITS, li);
            s4_run_hits[cyc] = li;
            if (li > 0) s4_runs_ok++;
            $display("[tb] S4 run cycle %0d: LAST_INTERVAL_HITS=%0d (%s)",
                     cyc, li, (li > 0) ? "ENTERED RUNNING + accumulated" : "ZERO HITS");
        end
        $display("[tb] S4 RC-host reliability: %0d / 5 run cycles accumulated hits", s4_runs_ok);

        // ============================================================
        //  SCENARIO 5 - PERIODIC single-channel DELTA (the on-board
        //  acceptance test). Emulator INTERNAL/PERIODIC, FIXED cluster
        //  geometry, CLUSTER_FIX low=high=N. TYPE0 value histogram,
        //  bins [0,256) width 1 => bin == data[43:36] == ASIC<<5|CH.
        //  EXPECT: exactly ONE nonzero bin, at index N, count == the
        //  periodic rate * run-time. This is the clean delta the HW
        //  failed to produce (HW: 10->bin7 saturated, 20->nothing).
        // ============================================================
        $display("--- SCENARIO 5: PERIODIC single-channel delta, N=%0d ---", s5_target_ch);
        // hit_rate=42 => 156.25MHz*42/65536 = 100.14 kHz on ONE channel.
        emu_config_periodic_single(s5_target_ch, 16'd42);

        avmm_write(HIST_CSR_BASE + 14'd3, 32'd0);     // LEFT_BOUND = 0
        avmm_write(HIST_CSR_BASE + 14'd4, 32'd256);   // RIGHT_BOUND = 256
        avmm_write(HIST_CSR_BASE + 14'd5, 32'd1);     // BIN_WIDTH = 1
        // CONTROL: source=TYPE0(00), in_port=FILL(00), mode=0(value),
        // key_unsigned, commit.
        avmm_write(HIST_CONTROL, 32'h0000_0001 | 32'h0000_0100);
        repeat (8) @(posedge avmm_clk_clk);
        avmm_read(HIST_CONTROL, ctrl_rb);
        $display("[tb] S5 CONTROL readback = 0x%08h (in_port[3:2]=%02b mode[7:4]=%01h src[17:16]=%02b)",
                 ctrl_rb, ctrl_rb[3:2], ctrl_rb[7:4], ctrl_rb[17:16]);

        runctl_hold(9'h001, 16);                     // IDLE
        runctl_hold_until_ready(9'h002, 768, 2048);  // PREP
        runctl_hold(9'h004, 32);                     // SYNC
        @(posedge monitor_clock_125_in_clk);
        runctl_mgmt_host_data  <= 9'h008;            // RUNNING
        runctl_mgmt_host_valid <= 1'b1;
        repeat (RUN_CYCLES_S5) @(posedge monitor_clock_125_in_clk);
        runctl_terminate_flush();
        avmm_read(HIST_LAST_INT_HITS, total_after);
        s5_total = total_after;

        monA_read_all_bins();
        for (int b = 0; b < N_BINS; b++) s5_bin[b] = monA_bin[b];
        s5_nz_bins = 0; s5_peak_bin = -1; s5_peak_cnt = 0;
        for (int b = 0; b < N_BINS; b++) begin
            if (s5_bin[b] != 0) begin
                s5_nz_bins++;
                if (s5_bin[b] > s5_peak_cnt) begin s5_peak_cnt = s5_bin[b]; s5_peak_bin = b; end
            end
        end
        $display("[tb] S5 PERIODIC single-ch: LAST_INTERVAL_HITS=%0d  monA bin-sum=%0d  nonzero_bins=%0d  peak_bin=%0d (count=%0d)",
                 s5_total, monA_sum, s5_nz_bins, s5_peak_bin, s5_peak_cnt);
        for (int b = 0; b < N_BINS; b++)
            if (s5_bin[b] != 0)
                $display("[tb]     S5 nonzero bin[%0d] (ASIC=%0d CH=%0d) = %0d hits", b, b/32, b%32, s5_bin[b]);
        // v4 DATAPATH (8-lane independent): emulator_mutrig_qsys8 exposes 8
        // asic-tagged lane sources; lane k -> arb emu_in_k (no broadcast
        // fanout). A FIXED single-channel periodic config on global channel
        // N=s5_target_ch (<128 => left half) fires lane N>>5, local CH N&31,
        // asic_id=N>>5 => emitted key data[43:36] = N. So channel N must
        // light exactly ONE bin == N. (Under the OLD broadcast fanout the
        // same channel lit all 8 bins {N&31, 32+N&31, ...}; this assertion
        // is the falsifiable per-ASIC independence gate.)
        begin
            bit all_at_n;
            all_at_n = 1'b1;
            for (int b = 0; b < N_BINS; b++)
                if (s5_bin[b] != 0 && b != s5_target_ch) all_at_n = 1'b0;
            s5_all_residue_ok = all_at_n;
        end
        // Expected count: RUN_CYCLES_S3_HISTAT monitor(125MHz) cycles is the
        // run-control window; the emulator runs on the 156.25MHz data_clock.
        // The sim wrapper drives a single clock domain crossing; report the
        // measured count and the analytic 156.25MHz expectation for the
        // 125MHz run window converted to time.
        begin
            real run_us, exp_hits;
            // run window length uses the S5 constant (not the S3 one).
            run_us  = real'(RUN_CYCLES_S5) * MONITOR_CLK_NS / 1000.0;  // us
            exp_hits = 100.14e3 * (run_us / 1.0e6);  // 100.14 kHz * seconds
            $display("[tb] S5 run window ~= %0.1f us => expected ~%0.0f hits @100.14kHz (one channel)",
                     run_us, exp_hits);
        end

        // ============================================================
        //  SCENARIO 6L - LONG-RUN cluster[0,0] DURATION experiment.
        //  Reproduce the EXACT on-board legacy single-channel config
        //  (cluster_geom_mode=0, CLUSTER_FIX left low=high=0 -> cluster[0,0],
        //  all 8 lanes enabled, periodic) and run a window ~37x the normal
        //  S6 dwell (1.5M monitor cyc ~= 12 ms) so the periodic engine fires
        //  thousands of times. Question: does cluster[0,0] EVER spread to
        //  lanes>0 given enough time? run_single_channel_check dumps every
        //  nonzero histogram bin AND the per-key (data[43:36]=ASIC<<5|CH)
        //  DIAG table, which IS the per-lane emit count (ASIC == lane). If
        //  only bin 0 / key 0 populates over 1.5M cyc, the on-board 8-bins
        //  is NOT a duration/statistics artifact.
        // ============================================================
        $display("--- SCENARIO 6L: LONG-RUN cluster[0,0] duration experiment (1.5M cyc, all 8 lanes enabled) ---");
        begin
            int pk_l, nz_l;
            longint unsigned pc_l;
            run_single_channel_check(0, 16'd128, 1_500_000, pk_l, nz_l, pc_l);
            $display("[tb] S6L cluster[0,0] LONG-RUN: nz_bins=%0d peak_bin=%0d peak_cnt=%0d",
                     nz_l, pk_l, pc_l);
            if (nz_l == 1 && pk_l == 0) begin
                $display("[tb] S6L VERDICT: ONLY lane 0 / bin 0 fired over 1.5M cyc -> on-board 8-bins is NOT duration.");
            end else begin
                $display("[tb] S6L VERDICT: lanes>0 fired over the long window -> DURATION/STATISTICS effect (nz=%0d).", nz_l);
            end
        end

        // ============================================================
        //  SCENARIO 6 - PER-ASIC INDEPENDENT ADDRESSING sweep.
        //  Fire, one at a time, representative global channels spanning all
        //  8 ASICs. Each MUST produce exactly ONE histogram delta at bin N
        //  (nz_bins==1, peak_bin==N). This is the falsifiable 8-ASIC
        //  independence test: with the 8-lane datapath channel N -> bin N
        //  only; with the OLD broadcast fanout channel N would light 8 bins.
        //  channels: 0,10,31 (ASIC0); 32,40,63 (ASIC1); 96 (ASIC3);
        //            128 (ASIC4); 200 (ASIC6); 255 (ASIC7).
        // ============================================================
        $display("--- SCENARIO 6: per-ASIC independent addressing sweep (channel N -> bin N) ---");
        s6_pass_cnt = 0;
        for (int k = 0; k < S6_N; k++) begin
            int pk, nz;
            longint unsigned pc;
            // 40k monitor cyc (~0.32 ms) at hit_rate=128 (~512-cyc period on
            // the 156.25 MHz data clock) gives O(100) hits on the one fired
            // channel -- ample for a clean single-bin delta while keeping the
            // 10-channel sweep inside the watchdog.
            run_single_channel_check(s6_chan[k], 16'd128, 40_000, pk, nz, pc);
            s6_peak_bin[k] = pk;
            s6_nz_bins[k]  = nz;
            s6_peak_cnt[k] = pc;
            if ((nz == 1) && (pk == s6_chan[k]) && (pc > 0)) begin
                s6_pass_cnt++;
                $display("[tb] S6 ch=%0d -> bin=%0d  [ OK ] single clean delta (ASIC %0d independently addressable)",
                         s6_chan[k], pk, s6_chan[k]/32);
            end else begin
                $display("[tb] S6 ch=%0d -> nz=%0d peak=%0d  [FAIL] expected single delta at bin %0d",
                         s6_chan[k], nz, pk, s6_chan[k]);
            end
        end
        $display("[tb] S6 per-ASIC sweep: %0d / %0d channels produced a single clean delta at bin N",
                 s6_pass_cnt, S6_N);

        // ============================================================
        //  SCENARIO 7 - NEW SINGLE-CHANNEL-MODE per-(ASIC,CH) sweep. This
        //  is the on-board fix: LANE_ENABLE mask = 1<<asic picks the ASIC,
        //  SIGNAL.single_channel picks the local CH, gated at the last
        //  frontend stage. Each (asic,ch) MUST light exactly bin asic*32+ch
        //  (single clean delta). This is the recipe the 256-channel scan
        //  will script on silicon.
        // ============================================================
        $display("--- SCENARIO 7: single-channel-mode per-(ASIC,CH) sweep (mask=1<<asic, SIGNAL.single_channel=ch) ---");
        s7_pass_cnt = 0;
        for (int k = 0; k < S7_N; k++) begin
            int pk, nz, exp_bin;
            longint unsigned pc;
            exp_bin = s7_asic[k]*32 + s7_ch[k];
            run_single_channel_mode_check(s7_asic[k], s7_ch[k], 16'd128, 40_000, pk, nz, pc);
            if ((nz == 1) && (pk == exp_bin) && (pc > 0)) begin
                s7_pass_cnt++;
                $display("[tb] S7 (ASIC=%0d,CH=%0d) -> bin=%0d  [ OK ] single clean delta",
                         s7_asic[k], s7_ch[k], pk);
            end else begin
                $display("[tb] S7 (ASIC=%0d,CH=%0d) -> nz=%0d peak=%0d  [FAIL] expected single delta at bin %0d",
                         s7_asic[k], s7_ch[k], nz, pk, exp_bin);
            end
        end
        $display("[tb] S7 single-channel-mode sweep: %0d / %0d (ASIC,CH) produced a single clean delta",
                 s7_pass_cnt, S7_N);

        // ============================================================
        //  SCENARIO 8 - EXTENDED-PLANE all-channel coverage. BACKGROUND
        //  scan fires all 8 lanes x 32 channels; read EXT0 (upper bank,
        //  ASIC0-3) then EXT1 (lower bank, ASIC4-7). This is the decisive
        //  per-channel Type1-rate read across BOTH banks.
        // ============================================================
        $display("--- SCENARIO 8: EXTENDED-PLANE all-channel coverage (background, EXT0 then EXT1) ---");
        run_ext_background_read(2'b01 /*EXT0*/, s8_ext0_total, s8_ext0_nz, s8_ext0_bin);
        $display("[tb] S8 EXT0 (upper bank ASIC0-3): LAST_INT_HITS=%0d nz_keys=%0d", s8_ext0_total, s8_ext0_nz);
        run_ext_background_read(2'b10 /*EXT1*/, s8_ext1_total, s8_ext1_nz, s8_ext1_bin);
        $display("[tb] S8 EXT1 (lower bank ASIC4-7): LAST_INT_HITS=%0d nz_keys=%0d", s8_ext1_total, s8_ext1_nz);
        // Per-key tables (only nonzero, grouped by bank).
        $display("[tb] S8 EXT0 nonzero keys (key=ASIC[2:0]<<5|CH):");
        for (int b = 0; b < 256; b++)
            if (s8_ext0_bin[b] != 0)
                $display("[tb]     S8 EXT0 key[%0d] (ASIC=%0d CH=%0d) = %0d hits", b, b/32, b%32, s8_ext0_bin[b]);
        $display("[tb] S8 EXT1 nonzero keys (key=ASIC[2:0]<<5|CH):");
        for (int b = 0; b < 256; b++)
            if (s8_ext1_bin[b] != 0)
                $display("[tb]     S8 EXT1 key[%0d] (ASIC=%0d CH=%0d) = %0d hits", b, b/32, b%32, s8_ext1_bin[b]);
        // Coverage summary: count distinct channels seen on each bank.
        begin
            int e0_cov, e1_cov;
            e0_cov = 0; e1_cov = 0;
            for (int b = 0; b < 256; b++) begin
                if (s8_ext0_bin[b] != 0) e0_cov++;
                if (s8_ext1_bin[b] != 0) e1_cov++;
            end
            $display("[tb] S8 COVERAGE EXT0=%0d/128 keys EXT1=%0d/128 keys (each bank serves 4 ASIC x 32 CH)",
                     e0_cov, e1_cov);
        end

        // ============================================================
        //  FALSIFIABLE ASSERTIONS
        // ============================================================
        $display("--- ASSERTIONS ---");

        // (S3) TYPE0/bkg CH0-2 reproduction. Evidence-driven, no tolerance.
        check_true("S3 TYPE0/bkg rate > 0 (type0 path not stalled)", s3_total_delta > 0);
        check_true("S3 emulator EMITTED CH0,1,2 (bkg generator low scan_pos)",
                   (s3_emit_ch[0] > 0) && (s3_emit_ch[1] > 0) && (s3_emit_ch[2] > 0));
        check_true("S3 histogram type0_lane0 ingress SAW CH0,1,2",
                   (s3_ing_ch[0] > 0) && (s3_ing_ch[1] > 0) && (s3_ing_ch[2] > 0));
        check_true("S3 histogram BINNED CH0,1,2 (bins 0,1,2 non-empty)",
                   (s3_bin[0] > 0) && (s3_bin[1] > 0) && (s3_bin[2] > 0));

        // (S4) RC host reliability.
        check_true("S4 RC host entered RUNNING + accumulated on ALL 5 cycles", s4_runs_ok == 5);

        // (S5) PERIODIC single-channel CLEAN DELTA. The decisive acceptance
        // check: exactly ONE nonzero bin, and it is at index N. This is what
        // the hardware FAILED (10->bin7, 20->nothing). If the RTL is correct
        // these hold; a failure here would localise a real channel->bin bug.
        check_true("S5 periodic single-ch produced hits (rate > 0)", s5_total > 0);
        // 8-lane independent datapath: channel N -> exactly ONE bin == N.
        // If any nonzero bin != N, the per-ASIC routing is broken (broadcast
        // residual, offset, or spread bug).
        check_true("S5 channel N lights exactly bin N (single clean delta)",
                   s5_all_residue_ok && s5_nz_bins == 1);
        check_true("S5 peak bin == N (channel-correct)",
                   s5_peak_bin == s5_target_ch);
        // (S6) PER-ASIC INDEPENDENT ADDRESSING sweep. The decisive 8-ASIC
        // gate: each representative global channel N across all 8 ASICs must
        // produce exactly ONE histogram delta at bin N. This MUST fail under
        // the broadcast fanout (channel 40 would also light bin 8, 72, ...).
        check_true("S6 all representative channels produced a single clean delta at bin N (8-ASIC independent)",
                   s6_pass_cnt == S6_N);
        // (S7) NEW single-channel-mode per-(ASIC,CH) gate. mask=1<<asic +
        // SIGNAL.single_channel must isolate to exactly one bin asic*32+ch.
        // This is the on-board fix for "cluster[0,0] fires all 8 lanes" and
        // "mask=0x08 -> 0 hits": with the last-stage gate the masked lane is
        // fed and emits exactly the configured local channel.
        check_true("S7 single-channel mode: every (ASIC,CH) lights exactly bin asic*32+ch",
                   s7_pass_cnt == S7_N);

        // (S8) EXTENDED-PLANE all-channel coverage. Under a background scan
        //  that fires all 8 lanes x 32 channels, BOTH banks must populate
        //  their extended sink. EXT0 covers ASIC0-3 (keys 0..127), EXT1
        //  covers ASIC4-7 (keys 128..255 packed as ASIC[2:0]). The on-board
        //  symptom (EXT0 partial, EXT1 zero) was a STIMULUS artefact: the
        //  periodic single-cluster engine only fires ASIC0. With the full
        //  background scan both banks must emit. Demand broad coverage
        //  (>=24 of the 32 channels per ASIC group, allowing for the PRNG
        //  scan + window-edge to leave a few cold) and a populated EXT1.
        begin
            int e0_cov, e1_cov;
            e0_cov = 0; e1_cov = 0;
            for (int b = 0; b < 256; b++) begin
                if (s8_ext0_bin[b] != 0) e0_cov++;
                if (s8_ext1_bin[b] != 0) e1_cov++;
            end
            check_true("S8 EXT0 (upper bank) Type1 rate > 0", s8_ext0_total > 0);
            check_true("S8 EXT1 (lower bank) Type1 rate > 0 (NOT stalled)", s8_ext1_total > 0);
            check_true("S8 EXT0 broad channel coverage (>=96 of 128 keys)", e0_cov >= 96);
            check_true("S8 EXT1 broad channel coverage (>=96 of 128 keys)", e1_cov >= 96);
        end

        // (1) Monitor A self-consistency: the scalar LAST_INTERVAL_TOTAL_HITS
        //     counter (CSR reg 17) and the frozen SRAM bin-sum are two
        //     independent read paths in the IP (csr stats counter vs
        //     hist_bin SRAM), both latched by the SAME TERMINATING flush.
        //     They MUST agree exactly. Tolerance 0. A mismatch is an RTL
        //     accounting bug.
        check_true("S1 monA bin-sum == LAST_INTERVAL_HITS (delay mode)",
                   s1_monA_sum == s1_total_delta);
        check_true("S2 monA bin-sum == LAST_INTERVAL_HITS (value mode)",
                   s2_monA_sum == s2_total_delta);

        // (2) RATE non-stall: with the emulator free-running and the run
        //     held in RUNNING for RUN_CYCLES, the histogram MUST accumulate
        //     hits on both EXT0 and EXT1. Zero => the extended-plane select
        //     or the MTS feed stalled (a real defect).
        check_true("S1 delay-mode rate > 0 (EXT0 not stalled)", s1_total_delta > 0);
        check_true("S2 value-mode rate > 0 (EXT1 not stalled)", s2_total_delta > 0);

        // (2b) PER-CHANNEL RATE uniformity (value mode). The emulator drives
        //      every enabled channel at the same configured rate, so the
        //      per-channel occupancy (each non-zero value bin) must be
        //      EQUAL across channels. A stalled / dropped channel falls to 0
        //      or below its peers and trips this. Tolerance: +/-1 hit to
        //      absorb the +/-1 window-edge quantisation (a hit emitted just
        //      before the TERMINATING flush may or may not be counted). This
        //      is a counting tolerance, not a tuned magic number.
        begin
            longint cmin, cmax;       // signed 64-bit to avoid mixed-sign cmp
            bit seen;
            cmin = 0; cmax = 0; seen = 1'b0;
            for (int b = 0; b < N_BINS; b++) begin
                if (monA_bin[b] != 0) begin
                    longint cv;
                    cv = monA_bin[b];
                    if (!seen) begin cmin = cv; cmax = cv; seen = 1'b1; end
                    else begin
                        if (cv < cmin) cmin = cv;
                        if (cv > cmax) cmax = cv;
                    end
                end
            end
            $display("[tb] S2 per-channel occupancy: min=%0d max=%0d over %0d channels", cmin, cmax, s2_nz_chans);
            check_true("S2 per-channel rate uniform across enabled channels (max-min<=1)",
                       seen && ((cmax - cmin) <= 1));
        end

        // (3) DELAY measurement. Two distinct things:
        //   (3a) FALSIFIABLE, in-scope here: the delay distribution must be
        //        fully captured by the configured window (no overflow), i.e.
        //        every accepted hit landed in a bin. This is exactly the
        //        bin-sum==LAST_INTERVAL equality already asserted in (1),
        //        which only holds when OVERFLOW==0. We re-assert the window
        //        coverage explicitly so a truncated delay tail trips here.
        check_true("S1 delay fully captured in window (no overflow tail)",
                   s1_delay_pop == s1_total_delta);
        //   (3b) project_cosim_delay_bounds: the delay-spread bound depends
        //        on the emulator mode. The TB now puts the emulator in
        //        PERIODIC internal mode (emu_config_periodic), whose
        //        documented bound is ~900 cycles (headersync would be ~300;
        //        both grow with pulses-per-frame). With a DEFINED periodic
        //        timebase AND the MTS coarse-time decode ROM loaded (run
        //        script stages dual_port_rom_init.txt), the histogram delay
        //        gts_8n - hit_ts is the bounded buffering latency, not the
        //        free-running PRBS-vs-gts scatter that produced the 6656-cyc
        //        spread. We assert the periodic bound and let it stand.
        if (s1_delay_minbin >= 0) begin
            int spread_cyc;
            spread_cyc = (s1_delay_maxbin - s1_delay_minbin)*S1_DELAY_BIN_W;
            $display("[tb] S1 delay spread = %0d cyc (periodic bound = %0d cyc)",
                     spread_cyc, S1_DELAY_PERIODIC_BOUND);
            check_true("S1 delay spread <= periodic bound (cosim_delay_bounds)",
                       spread_cyc <= S1_DELAY_PERIODIC_BOUND);
        end else begin
            $display("[FAIL] S1 delay histogram empty - no delay bins populated");
            fail_count++;
        end

        // (4) DUAL-MONITOR AGREEMENT (Monitor A vs Monitor B).
        //     Monitor B reconstructs the hit population independently from
        //     the hit_type3 boundary stream. If hit_type3 carried per-hit
        //     beats, monB hit-count should equal monA bin-sum within a
        //     small framing tolerance. This is the no-magic-number gate.
        check_monitor_agreement();

        // ---- final tally --------------------------------------------
        $display("[tb_scifi_v4_wrapper] FINAL hit_type3_upper beats=%0d lower=%0d",
                 upper_beats, lower_beats);
        if (fail_count == 0) begin
            $display("*** SCIFI_V4_WRAPPER SCENARIO PASSED (all asserts held) ***");
        end else begin
            $display("*** SCIFI_V4_WRAPPER SCENARIO FAILED: %0d check(s) tripped ***", fail_count);
        end
        $finish;
    end

    initial begin
        // Watchdog. SCENARIO 3 high-stat window is RUN_CYCLES_S3_HISTAT
        // (1.5M) monitor clk @ 8ns = 12ms, plus S1/S2/S4 + prep/drain. Set
        // the ceiling well above the worst-case so the run reaches the
        // final tally instead of being killed mid-window.
        #90_000_000;
        $display("[tb_scifi_v4_wrapper] timeout");
        $finish;
    end

    // -----------------------------------------------------------------
    //  Bind-probe aggregation. The two probe modules below are bound by
    //  MODULE NAME into (a) the emulator type0 emitter and (b) the
    //  histogram. They observe the channel field of accepted hit beats and
    //  expose per-channel counters. The TB samples those counters by the
    //  bind-instance hierarchical name. This is a verification observation
    //  attachment (drives nothing in the DUT), used here only to localise
    //  the exact datapath stage at which CH0-2 are lost. The permanent
    //  wrapper-boundary regression (scenarios 1/2) does not depend on it.
    // -----------------------------------------------------------------
    // Pull the bound probes' package counters into the TB arrays every monitor
    // edge. s3_probe_clear zeroes the shared package accumulators at window open.
    always @(posedge monitor_clock_125_in_clk) begin
        if (s3_probe_clear) begin
            tb_chan_probe_pkg::clear_all();
            s3_emit_total <= 0;
            s3_ing_total  <= 0;
            s3_mrg_emu_out <= 0; s3_mrg_emu_in <= 0; s3_mrg_src_emu <= 0;
            s3_mrg_out <= 0; s3_mrg_arb_in <= 0;
            for (int c = 0; c < 32; c++) begin
                s3_emit_ch[c] <= 0;
                s3_ing_ch[c]  <= 0;
            end
        end else begin
            s3_emit_total <= tb_chan_probe_pkg::emit_total;
            s3_ing_total  <= tb_chan_probe_pkg::ing_total;
            s3_arb_emu    <= tb_chan_probe_pkg::arb_emu;
            s3_arb_real   <= tb_chan_probe_pkg::arb_real;
            s3_mrg_emu_out <= tb_chan_probe_pkg::mrg_emu_out_valid;
            s3_mrg_emu_in  <= tb_chan_probe_pkg::mrg_emu_in_valid;
            s3_mrg_src_emu <= tb_chan_probe_pkg::mrg_src_is_emu_h;
            s3_mrg_out     <= tb_chan_probe_pkg::mrg_out_valid;
            s3_mrg_arb_in  <= tb_chan_probe_pkg::mrg_arb_in_valid;
            for (int c = 0; c < 32; c++) begin
                s3_emit_ch[c] <= tb_chan_probe_pkg::emit_ch[c];
                s3_ing_ch[c]  <= tb_chan_probe_pkg::ing_ch[c];
            end
        end
    end

endmodule

// =====================================================================
//  Channel-trace probe for the emulator type0 emitter (45-bit packed
//  hit_type0). data[40:36] is the channel field (pack_hit_type0 ->
//  hit_word[47:43]); data[44:41] is asic_id. Counts accepted beats
//  (valid & data[35:32]==hit, i.e. byte_is_k semantics do not apply on
//  the 45-bit type0 plane -- every valid beat with valid=1 is a hit).
// =====================================================================
module tb_type0_emit_probe (
    input  logic        clk,
    input  logic        valid,
    input  logic [44:0] data
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        if (valid) begin
            emit_total = emit_total + 1;
            emit_ch[data[40:36]] = emit_ch[data[40:36]] + 1;
        end
    end
endmodule

// =====================================================================
//  Channel-trace probe for the histogram type0_lane0 INGRESS. Bound into
//  histogram_statistics_v2; observes asi_type0_lane0_{valid,data}. Counts
//  a beat as ingressed when valid=1 AND the source select is TYPE0 AND the
//  port-0 ready is asserted (the histogram samples on port_valid & ready).
//  data[40:36] is the channel field on the 45-bit type0 plane.
// =====================================================================
module tb_type0_ingress_probe (
    input  logic        clk,
    input  logic        valid,
    input  logic [44:0] data
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        if (valid) begin
            ing_total = ing_total + 1;
            ing_ch[data[40:36]] = ing_ch[data[40:36]] + 1;
        end
    end
endmodule

// =====================================================================
//  TYPE0 stall-localisation probe. Bound into merger_hit_type0; gated to
//  the lane-0 instance via INSTANCE_ID==0 (bind-by-module-name otherwise
//  attaches to all 8 mergers). Counts, over the active window, the
//  per-stage valid beats of the lane-0 chain:
//    asi_emu_valid  == emulator aso_hit_type0_0_valid net (generated wrapper)
//    cfg_source_is_emu : merger CSR source-select state (1=EMU)
//    aso_out_valid  == arb_hit_type0_supercore_0 real_in_0_valid net
//  The first stage that reads 0 while its upstream is nonzero is the break.
// =====================================================================
module tb_merger_chain_probe #(
    parameter integer INSTANCE_ID = 0
) (
    input logic clk,
    input logic asi_emu_valid,
    input logic cfg_source_is_emu,
    input logic aso_out_valid
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        if (INSTANCE_ID == 0) begin
            if (asi_emu_valid === 1'b1) begin
                mrg_emu_out_valid = mrg_emu_out_valid + 1; // emulator output net
                mrg_emu_in_valid  = mrg_emu_in_valid  + 1; // merger emu input
            end
            if (cfg_source_is_emu === 1'b1)
                mrg_src_is_emu_h = mrg_src_is_emu_h + 1;
            mrg_src_is_emu_last = cfg_source_is_emu;
            if (aso_out_valid === 1'b1) begin
                mrg_out_valid    = mrg_out_valid    + 1; // merger output
                mrg_arb_in_valid = mrg_arb_in_valid + 1; // arb real_in_0 net
            end
        end
    end
endmodule

bind merger_hit_type0 tb_merger_chain_probe #(.INSTANCE_ID(INSTANCE_ID)) u_merger_chain_probe (
    .clk               (clk),
    .asi_emu_valid     (asi_emu_valid),
    .cfg_source_is_emu (cfg_source_is_emu),
    .aso_out_valid     (aso_out_valid)
);

// Egress source probe: counts emu vs real selected hit beats. Post-#63 the
// arb_hit_type0_supercore is removed and merger_hit_type0.out is the TYPE0
// egress straight into the histogram tap, so this binds into the merger and
// classifies each output beat by the merger's source-select state.
module tb_arb_egress_probe (
    input  logic clk,
    input  logic valid,
    input  logic source_emu
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        if (valid) begin
            if (source_emu) arb_emu  = arb_emu  + 1;
            else            arb_real = arb_real + 1;
        end
    end
endmodule

// Bind the egress probe by module name into merger_hit_type0. One merger
// instance per lane (8 lanes); binding by module name attaches to ALL of them,
// so arb_emu/arb_real aggregate across lanes - fine for the emu-vs-real source
// question. aso_out_valid is the merger egress (now feeding the hist tap),
// cfg_source_is_emu is the merger's runtime source-select.
bind merger_hit_type0 tb_arb_egress_probe u_arb_egress_probe (
    .clk        (clk),
    .valid      (aso_out_valid),
    .source_emu (cfg_source_is_emu)
);

// Bind the emitter probe by module name. be_mutrig_lane_type0_emit has a
// single elaborated instance (LANE_COUNT=1). aso_hit_type0_valid/data are
// the registered emitter outputs.
bind be_mutrig_lane_type0_emit tb_type0_emit_probe u_emit_chan_probe (
    .clk   (clk),
    .valid (aso_hit_type0_valid),
    .data  (aso_hit_type0_data)
);

// Bind the ingress probe by module name into the histogram. It samples the
// type0 lane0 input. In TYPE0/FILL mode port-0 ready is constant 1
// (stream_ready_v := '1' at histogram_statistics_v2.vhd:1279), so lane0
// valid == port-0 accept. data is the 45-bit lane0 payload.
bind histogram_statistics_v2 tb_type0_ingress_probe u_ing_chan_probe (
    .clk   (i_clk),
    .valid (asi_type0_lane0_valid),
    .data  (asi_type0_lane0_data)
);

// DIAG: capture the actual divider input key (the value that becomes the bin)
// and the raw [43:36] slice of the lane0 ingress data, to separate a key-path
// bug from a data-field-position bug behind the bin-0 collapse.
module tb_hist_key_probe (
    input  logic        clk,
    input  logic        key_valid,
    input  logic [20:0] key_val,
    input  logic        slice_valid,
    input  logic [44:0] slice_data
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        if (key_valid) begin
            key_total = key_total + 1;
            key_hist[key_val[7:0]] = key_hist[key_val[7:0]] + 1;
        end
        if (slice_valid) begin
            slice_total = slice_total + 1;
            // Record X-ness of the asic field [44:41] vs channel field [40:36]
            // separately. ^x === 1'bx is true iff any bit of x is X.
            if (^slice_data[44:41] === 1'bx) slice_asic_x  = slice_asic_x  + 1;
            else                              slice_asic_ok = slice_asic_ok + 1;
            if (^slice_data[40:36] === 1'bx) slice_ch_x    = slice_ch_x    + 1;
            else                              slice_ch_ok   = slice_ch_ok   + 1;
            if (^slice_data[43:36] !== 1'bx)
                slice_hist[slice_data[43:36]] = slice_hist[slice_data[43:36]] + 1;
        end
    end
endmodule

bind histogram_statistics_v2 tb_hist_key_probe u_hist_key_probe (
    .clk         (i_clk),
    .key_valid   (divider_in_valid),
    .key_val     (divider_in_key),
    .slice_valid (asi_type0_lane0_valid),
    .slice_data  (asi_type0_lane0_data)
);

// =====================================================================
//  DIAG-ASIC probes: localise the asic[44:41]=X collapse. One samples the
//  emulator CSR's cfg_lane_enable_asic_id_base directly inside frontend_csr;
//  the other samples each be_mutrig_lane_type0_emit's asic_id input + the
//  packed data[44:41] on every emitted beat.
// =====================================================================
module tb_diag_csr_asic_probe (
    input logic       clk,
    input logic [3:0] cfg_asic_base
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        diag_cfg_asic_base = cfg_asic_base;
        if (^cfg_asic_base === 1'bx) diag_cfg_x  = diag_cfg_x  + 1;
        else                          diag_cfg_ok = diag_cfg_ok + 1;
    end
endmodule

bind frontend_csr tb_diag_csr_asic_probe u_diag_csr_asic_probe (
    .clk            (i_clk),
    .cfg_asic_base  (cfg_lane_enable_asic_id_base)
);

// Probe the emulator_mutrig core wire cfg_asic_id_base (the net feeding
// lane_asic_id), to confirm whether the X is on the core wire or born in
// the lane_asic_id function evaluation.
module tb_diag_core_asic_probe (
    input logic       clk,
    input logic [3:0] core_asic_base
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        if (^core_asic_base === 1'bx) diag_core_x  = diag_core_x  + 1;
        else                           diag_core_ok = diag_core_ok + 1;
        diag_core_asic_base = core_asic_base;
    end
endmodule

bind emulator_mutrig tb_diag_core_asic_probe u_diag_core_asic_probe (
    .clk             (i_clk),
    .core_asic_base  (cfg_asic_id_base)
);

module tb_diag_emit_asic_probe (
    input logic        clk,
    input logic        valid,
    input logic [3:0]  asic_id_in,
    input logic [44:0] data
);
    import tb_chan_probe_pkg::*;
    always @(posedge clk) begin
        // asic_id is a combinational input; sample its X-ness every cycle.
        if (^asic_id_in === 1'bx) diag_asicid_x = diag_asicid_x + 1;
        else                       diag_asicid_ok = diag_asicid_ok + 1;
        if (valid) begin
            diag_emit_beats = diag_emit_beats + 1;
            if (^data[44:41] === 1'bx) diag_emit_asic_x  = diag_emit_asic_x  + 1;
            else                        diag_emit_asic_ok = diag_emit_asic_ok + 1;
            if (data[44] === 1'bx)      diag_emit_d44_x   = diag_emit_d44_x   + 1;
            if (^data[43:41] === 1'bx)  diag_emit_d4341_x = diag_emit_d4341_x + 1;
            diag_last_asicid = asic_id_in;
        end
    end
endmodule

bind be_mutrig_lane_type0_emit tb_diag_emit_asic_probe u_diag_emit_asic_probe (
    .clk        (clk),
    .valid      (aso_hit_type0_valid),
    .asic_id_in (asic_id),
    .data       (aso_hit_type0_data)
);
