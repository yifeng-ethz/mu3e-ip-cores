// emulator_mutrig_pkg.sv
// MuTRiG 3 emulator constants and types
// Author: Yifeng Wang
// Version : 26.1.8
// Date    : 20260418
// Change  : Keep the raw-compatible field layout and compact shared-bank
//           release constants aligned with the true-A/B harness and the new
//           masked-trigger latency-injection path.
//
// Based on the MuTRiG 3 ASIC digital readout (Huangshan Chen, KIP Heidelberg)
// Reference: kbriggl-mutrig3-c3cce8d41dcb RTL

package emulator_mutrig_pkg;

    // ========================================
    // MuTRiG physical parameters
    // ========================================
    localparam int N_CHANNELS         = 32;       // 32 SiPM channels per ASIC
    localparam int CHANNEL_WIDTH      = 5;        // ceil(log2(32))
    localparam int N_GROUPS           = 4;        // raw MuTRiG datapath fan-in groups
    localparam int N_CHAN_PER_GROUP   = N_CHANNELS / N_GROUPS;
    localparam int MAX_EMU_LANES      = 8;        // FEB-facing emulation domain
    localparam int CLUSTER_LANE_WIDTH = 4;        // ceil(log2(8)) with margin
    localparam int GLOBAL_CHANNEL_WIDTH = 8;      // 8 lanes * 32 channels = 256 channels

    // ========================================
    // Clock and timing
    // ========================================
    // Architect-correct timing target:
    //   - the native MuTRiG datapath runs at 625 MHz
    //   - this emulator models that behavior at a 125 MHz byte-clock boundary
    //   - the datapath-observed short-frame period at the emulator boundary is
    //     910 byte-clock cycles
    //
    // Both frame intervals below are the architect-approved targets at the
    // 125 MHz emulator boundary.
    localparam int FRAME_INTERVAL_LONG  = 1550; // architect-correct long period at the 125 MHz emulator boundary
    localparam int FRAME_INTERVAL_SHORT = 910;  // architect-correct short period at the 125 MHz emulator boundary

    // ========================================
    // LFSR / PRBS-15 coarse counter
    // ========================================
    // The integrated MuTRiG timestamp processor decodes the dark coarse code
    // with the `dual_port_rom_init.txt` LUT used in the FEB datapath. That
    // LUT corresponds to the following 15-bit sequence:
    //   - seed      = 0x0001
    //   - next[0]   = ~(state[14] ^ state[13])
    //   - next[14:1]= state[13:0]
    //
    // Keep the emulator on that exact sequence so the downstream MTS decoder
    // reconstructs the true 1.6 ns timestamp without a phase remap.
    // Period:     2^15 - 1 = 32767
    localparam int TCC_WIDTH = 15;
    localparam logic [14:0] LFSR15_INIT = 15'h0001;
    localparam int MUTRIG_COARSE_STEPS_PER_CYCLE = 5;

    // ========================================
    // 8b/10b K-characters
    // ========================================
    localparam logic [7:0] K28_0 = 8'h1C;  // Header
    localparam logic [7:0] K28_4 = 8'h9C;  // Trailer
    localparam logic [7:0] K28_5 = 8'hBC;  // Comma / Idle

    // ========================================
    // TX modes (from MuTRiG slow control)
    // ========================================
    localparam logic [2:0] TX_MODE_LONG       = 3'b000;
    localparam logic [2:0] TX_MODE_PRBS_1     = 3'b001;  // single PRBS word per frame
    localparam logic [2:0] TX_MODE_PRBS_SAT   = 3'b010;  // saturating PRBS
    localparam logic [2:0] TX_MODE_SHORT      = 3'b100;  // short hit (no energy)

    // ========================================
    // Hit data record (L2 format, 48 bits)
    // ========================================
    // Long hit word (48 bits):
    //   [47:43] channel  (5)
    //   [42]    T_BadHit (1)
    //   [41:27] TCC      (15) -- LFSR-15 encoded
    //   [26:22] T_Fine   (5)
    //   [21]    E_BadHit (1)
    //   [20:6]  ECC      (15) -- LFSR-15 encoded
    //   [5:1]   E_Fine   (5)
    //   [0]     E_Flag   (1)
    localparam int HIT_LONG_WIDTH  = 48;
    localparam int HIT_SHORT_WIDTH = 28;
    localparam int HIT_L1_WIDTH    = 78;
    // Short hit word (28 bits):
    //   Note: the original 2016 MuTRiG ASIC RTL named these short-mode payload
    //   fields ECC/E_Fine. The current Mu3e online datapath contract treats the
    //   same bit positions as TCC/T_Fine for short "time-only" events, and this
    //   emulator follows that current Mu3e contract.
    //   [27:23] channel  (5)
    //   [22]    E_BadHit (1)
    //   [21:7]  TCC      (15) -- short mode carries time coarse, not energy coarse
    //   [6:2]   T_Fine   (5)
    //   [1]     E_Flag   (1)
    //   [0]     pad      (1)

    // N_BYTES_PER_WORD for frame packing
    localparam int N_BYTES_LONG  = 6;  // 48/8
    localparam int N_BYTES_SHORT = 3;  // ceil(28/8)=4, but packed 3.5 bytes → alternates 3/4

    // ========================================
    // Lane FIFO configuration
    // ========================================
    // The compact generator keeps one lane-local 48-bit L2 FIFO in RAM. The
    // historical group constants stay defined because the public package still
    // serves the compatibility single-lane wrapper and older references.
    localparam int RAW_FIFO_DEPTH            = 256;
    localparam int FIFO_ALMOST_FULL_MARGIN   = 3;
    localparam logic [4:0] MS_LIMITS_DEFAULT = 5'd16;

    // ========================================
    // Frame flags (6 bits in event count word)
    // ========================================
    // [5] gen_idle_signal
    // [4] fast_mode (tx_mode[2])
    // [3] prbs_debug (tx_mode[1])
    // [2] single_prbs (tx_mode[0])
    // [1] fifo_full
    // [0] pll_lol (inverted)

    // ========================================
    // Hit generator modes
    // ========================================
    typedef enum logic [1:0] {
        // Legacy compact mode: one folded Bernoulli decision per cycle, with
        // the current scan position selecting which local channel owns it.
        HIT_MODE_POISSON          = 2'b00,
        // Cluster replay / injected burst mode.
        HIT_MODE_BURST            = 2'b01,
        // Folded per-channel IID mode: each local channel owns an independent
        // PRNG stream and the configured per-channel rate is folded by the
        // number of local channels.
        HIT_MODE_POISSON_IID      = 2'b10,
        // Folded per-channel periodic mode: each local channel owns a phase
        // accumulator and the configured per-channel rate is folded by the
        // number of local channels.
        HIT_MODE_PERIODIC         = 2'b11
    } hit_mode_t;

    // Backward-compatible aliases kept for older benches and reports.
    localparam hit_mode_t HIT_MODE_NOISE = HIT_MODE_POISSON_IID;
    localparam hit_mode_t HIT_MODE_MIXED = HIT_MODE_PERIODIC;

    // ========================================
    // Helper functions
    // ========================================

    // Pack a long hit word
    function automatic logic [47:0] pack_hit_long(
        input logic [4:0]  channel,
        input logic        t_badhit,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic        e_badhit,
        input logic        e_flag,
        input logic [14:0] ecc,
        input logic [4:0]  e_fine
    );
        return {channel, t_badhit, tcc, t_fine, e_badhit, ecc, e_fine, e_flag};
    endfunction

    // Pack a short hit word
    function automatic logic [27:0] pack_hit_short(
        input logic [4:0]  channel,
        input logic        e_badhit,
        input logic [14:0] tcc,
        input logic [4:0]  t_fine,
        input logic        e_flag
    );
        return {channel, e_badhit, tcc, t_fine, e_flag, 1'b0};
    endfunction

    function automatic logic [77:0] pack_hit_l1(
        input logic [4:0]  channel,
        input logic [14:0] tcc_master,
        input logic [14:0] tcc_slave,
        input logic [4:0]  t_fine,
        input logic        t_badhit,
        input logic [14:0] ecc_master,
        input logic [14:0] ecc_slave,
        input logic [4:0]  e_fine,
        input logic        e_badhit,
        input logic        e_flag
    );
        return {
            channel,
            tcc_master,
            tcc_slave,
            t_fine,
            t_badhit,
            ecc_master,
            ecc_slave,
            e_fine,
            e_badhit,
            e_flag
        };
    endfunction

    function automatic logic prbs15_feedback(input logic [14:0] state);
        return ~(state[14] ^ state[13]);
    endfunction

    function automatic logic [14:0] prbs15_step(input logic [14:0] state);
        return {state[13:0], prbs15_feedback(state)};
    endfunction

    function automatic logic [14:0] prbs15_step_n(
        input logic [14:0] state,
        input int unsigned step_count
    );
        logic [14:0] state_v;

        state_v = state;
        for (int idx = 0; idx < step_count; idx++)
            state_v = prbs15_step(state_v);
        return state_v;
    endfunction

    function automatic logic [14:0] prbs15_prev(input logic [14:0] state);
        return {state[0] ^ state[1], state[14:1]};
    endfunction

    function automatic logic [1:0] group_from_channel(input logic [4:0] channel);
        return channel[4:3];
    endfunction

    function automatic logic select_master_cc(
        input logic [4:0] fine,
        input logic [4:0] limits,
        input logic       overwrite_sel
    );
        logic [4:0] fine_sub;
        fine_sub = fine - limits;
        return ~(fine_sub[4] ^ overwrite_sel);
    endfunction

    function automatic logic [47:0] l1_to_l2_word(
        input logic [77:0] l1_word,
        input logic [4:0]  limits,
        input logic        overwrite_sel
    );
        logic        t_sel_master;
        logic        e_sel_master;
        logic [14:0] tcc_selected;
        logic [14:0] ecc_selected;

        t_sel_master = select_master_cc(l1_word[42:38], limits, overwrite_sel);
        e_sel_master = select_master_cc(l1_word[6:2], limits, overwrite_sel);
        tcc_selected = t_sel_master ? l1_word[72:58] : l1_word[57:43];
        ecc_selected = e_sel_master ? l1_word[36:22] : l1_word[21:7];

        return pack_hit_long(
            .channel  (l1_word[77:73]),
            .t_badhit (l1_word[37]),
            .tcc      (tcc_selected),
            .t_fine   (l1_word[42:38]),
            .e_badhit (l1_word[1]),
            .e_flag   (l1_word[0]),
            .ecc      (ecc_selected),
            .e_fine   (l1_word[6:2])
        );
    endfunction

endpackage
