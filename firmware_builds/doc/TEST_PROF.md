# TEST_PROF.md — Phase-5 PROF bucket (performance / rate-pressure)

**Companion**: [`TEST_PLAN_PHASE5.md`](TEST_PLAN_PHASE5.md) §1.6, §3
**Sibling buckets**: [`TEST_BASIC.md`](TEST_BASIC.md) · [`TEST_EDGE.md`](TEST_EDGE.md) · [`TEST_ERROR.md`](TEST_ERROR.md)
**Catalog ID range**: `TPB5PRO001` … `TPB5PRO144` (entry catalog; long-term target 500–3000 cases)
**Intent**: prove the chain stays clean across the IP boundaries of §3.2 under **rate pressure** — hit propagation must remain bit-exact at high emulator rate, real-MuTRiG mode-2 free-running rate, FIFO-fill skew, and sustained soak. Each row identifies which boundary's queueing surface is being stressed and which counter / fill-level signal is the primary observable.

## How to read this catalog

Same row schema as `TEST_BASIC.md`. PROF bucket adds two columns implicit in the per-case evidence:

- the IP whose **fill-level / occupancy** is the primary observable (e.g. `backpressure_fifo[k].filllevel` or `ring_buffer_cam[k].filllevel`),
- the rate point being probed in Mhit/s per MuTRiG (or aggregate, where noted).

PROF cases use **2048 × 4 segment** depth at the IP being stressed (so a fill-level ramp is captured fully), and **1024 × 4** at the other taps. Captures are GTS-armed at four equally-spaced points in the run window (the four segments) so the fill-level trajectory is observed at four temporal samples.

## Execution scoreboard

Status vocabulary is defined in `TEST_PLAN_PHASE5.md` §1.7. This table is the first-level record of what has actually run; keep it updated after every SignalTap or board run. Ranged rows are not marked `PASS` unless every case in the range passed.

| Group | Cases | Status | PASS | FAIL | BLOCKED | Last evidence | Notes |
|---|---:|---|---:|---:|---:|---|---|
| P1 | 32 | not-run | 0 | 0 | 0 | none | emulator hit-rate sweep |
| P2 | 16 | not-run | 0 | 0 | 0 | none | hot-lane stress |
| P3 | 16 | not-run | 0 | 0 | 0 | none | channel-rate skew |
| P4 | 16 | BLOCKED | 0 | 0 | 16 | [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_mts_valid_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_mts_valid_stp_20260429.md) | lanes 0/3 produce real hits and can reach histogram statistics; sweep remains blocked until repeated zero-discard evidence and lane 1/2/4/5/6/7 policy |
| P5 | 16 | not-run | 0 | 0 | 0 | none | ring-CAM fill pressure |
| P6 | 8 | not-run | 0 | 0 | 0 | none | backpressure-FIFO pressure |
| P7 | 8 | not-run | 0 | 0 | 0 | none | emulator sustained soak |
| P8 | 8 | BLOCKED | 0 | 0 | 8 | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real_alllanes_sc_recovered_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real_alllanes_sc_recovered_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_asic0_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_asic0_20260429.md) | real-MuTRiG sustained soak blocked by MuTRiG cfg/LVDS lock |
| P9 | 8 | BLOCKED | 0 | 0 | 8 | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_lane0_rate_sweep_sc_recovered_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_lane0_rate_sweep_sc_recovered_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_asic0_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_mutrig_config_asic0_20260429.md) | emulator half is live; mixed-source operation remains blocked by the real-MuTRiG half |
| P10 | 16 | not-run | 0 | 0 | 0 | none | subsystem-boundary pressure variants |

## Wiring and prerequisites

Same as TEST_BASIC.md. Additionally:

- `histogram_statistics_0.OVERFLOW_COUNT`, `DROPPED_HITS`, `UNDERFLOW_COUNT` snapshotted before and after each case via `probe_phase4_stage_counters.py`. PROF cases tolerate up to wire-cap behavior; they do **not** tolerate `OVERFLOW_COUNT` increments.
- `INTERVAL_CFG` adjusted per case so the histogram ping-pong does not confound the fill-level capture.

## Injector path debug gate

The following gate is not part of the 144 PROF-case denominator, but it blocks P4, P8, and P9 because those groups require live `mutrig_injector_0` traffic. The plaintext SignalTap contract lives in [`TEST_INJECTOR_PATH.md`](TEST_INJECTOR_PATH.md).

| Gate | Status | Evidence | Next action |
|---|---|---|---|
| RTL integration sim, mode-2 injector, all eight emulator lanes | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_datapath_sim_20260428.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_datapath_sim_20260428.md) | keep as current-RTL reference |
| Live board, emulator sources selected, mode-2 injector | `PASS` | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_lane0_sc_recovered_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_lane0_sc_recovered_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_lane0_rate_sweep_sc_recovered_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_emulator_lane0_rate_sweep_sc_recovered_20260429.md) | use this as the current live reference for PROF injector-dependent emulator checks |
| Live board, real sources selected, mode-2 injector | `BLOCKED` | [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_mts_valid_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_mts_valid_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real_mutrig_mts_tserr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real_mutrig_mts_tserr_debug_20260429.md) | lanes 0/3 are injector-correlated after ASIC0/3 channel-16 cfg and can reach the histogram-statistics accepted-hit boundary; real-source sweeps are not closure-clean until repeated windows show zero MTS discards/input-errors and remaining real lanes have lock/waiver |
| SignalTap pulse proof | `PASS_WITH_METHOD_NOTE` | [`../systems/system_20260427_testplanphase5/reports/phase5_injector_prearmed_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_prearmed_stp_20260429.md), [`../systems/system_20260427_testplanphase5/captures/phase5_injector_path_prearmed_periodic_20260429.vcd`](../systems/system_20260427_testplanphase5/captures/phase5_injector_path_prearmed_periodic_20260429.vcd), [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md) | pre-arm injector over SC for pulse-only captures; the concurrent wrapper is usable again when it leaves SC synchronization enabled and does not force `--no-reset` |

## Catalog

### Group P1 — emulator hit-rate sweep, 32 cases

Stimulus: all 8 emulator lanes at the same `csr_hit_rate`. 32 log-spaced rate points in 8.8 fixed-point. The grid: `0x0010, 0x0014, 0x0018, 0x0020, 0x0028, 0x0030, 0x0040, 0x0050, 0x0060, 0x0080, 0x00A0, 0x00C0, 0x0100, 0x0140, 0x0180, 0x0200, 0x0280, 0x0300, 0x0400, 0x0500, 0x0600, 0x0800, 0x0A00, 0x0C00, 0x1000, 0x1400, 0x1800, 0x2000, 0x2800, 0x3000, 0x4000, 0x8000` (≈ 32 points spanning ~0.06..128 hits/frame). The per-emulator hit rate in Mhit/s is `(rate_word/0x0100) × FRAME_RATE`.

| case_id | rate_word | trigger | taps (deepened) | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5PRO001..008 | sweep_word ∈ rate_grid[0..7] (≈ 0.06..0.5 hits/frame) | GTS-arm at four equally-spaced points in a 200 ms run window | T2 (2048×4), all others 1024×4 | `histogram_statistics_0.TOTAL_HITS` rate-doubling ratio holds 2.0 ± 5% across adjacent pairs; `backpressure_fifo[k].filllevel` peak < 16 (well under 128); `OVERFLOW_COUNT delta = 0`; `DROPPED_HITS = 0` | pending |
| TPB5PRO009..016 | sweep_word ∈ rate_grid[8..15] (≈ 0.5..2 hits/frame) | same | same | rate-doubling ratio holds; `filllevel` peak < 32 | pending |
| TPB5PRO017..024 | sweep_word ∈ rate_grid[16..23] (≈ 2..6 hits/frame) | same | T6 (2048×4), others 1024×4 | rate-doubling ratio holds; ring-CAM `filllevel` peak < 128; `aso_filllevel_data` rises gracefully | pending |
| TPB5PRO025..032 | sweep_word ∈ rate_grid[24..31] (≈ 6..128 hits/frame, includes the wire-cap region) | same | T6 (2048×4), T7 (4096×4) | rate-doubling ratio holds up to the knee, then plateaus at the 200 Mhit/s aggregate cap; ring-CAM `filllevel` peak < 256 (half the 512-entry depth); `OVERFLOW_COUNT delta = 0`; the wire-cap is documented for the case | pending |

### Group P2 — per-lane rate skew (one lane at peak, others at floor), 16 cases

Stimulus: one lane at saturation `rate_word = 0x4000` (≈ 64 hits/frame), the other 7 lanes at `rate_word = 0x0040` (≈ 0.25 hits/frame). 8 lanes × 2 saturations (`0x4000` and `0x8000`) = 16 cases. Tests whether one lane saturating its own backpressure path interferes with the other lanes' propagation through the shared `mux_mutrig2processor` and `histogram_ingress_bridge_0`.

| case_id | hot_lane | hot_rate | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|---|
| TPB5PRO033..040 | lane k ∈ {0..7} | 0x4000 | GTS-arm | T2[k] (2048×4), T6 (2048×4), T7 (4096×4), others 1024×4 | only lane-k slice of histogram saturates; other 7 lanes' bin rates within Poisson 3σ of the floor; T2 of lane k shows `filllevel` peak ≥ 64; T6 partition fill is dominated by lane-k payloads but other partitions still admit and drain correctly | pending |
| TPB5PRO041..048 | lane k ∈ {0..7} | 0x8000 | same | same | hot lane's accepted rate plateaus at the wire-cap; `DROPPED_HITS` may advance at the MuTRiG side (real) or at the emulator boundary, but `OVERFLOW_COUNT` on `histogram_statistics_0` stays at 0 | pending |

### Group P3 — channel-rate skew on a single ASIC, 16 cases

Stimulus: emulator lane 0 only, `csr_inject_channel_mask` selects N channels with N ∈ {1, 2, 4, 8, 16, 32}; single-mask cases hold the lane at saturation `rate_word = 0x4000`, distributed across the unmasked channels. 6 N values × cycling per-lane bit position = 16 cases.

| case_id | active channels | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5PRO049 | lane 0, 1 channel (ch 0) at rate_word=0x4000 | GTS-arm | T2[0], T6, T7 deepened | per-channel rate concentrated on bin 0; ring-CAM partition-0 fill rises proportionally; one-channel queueing tail visible in T6 capture | pending |
| TPB5PRO050..052 | lane 0, 2 channels @ rate_word=0x2000 ea., spread vs adjacent | GTS-arm | same | per-channel rate halved relative to TPB5PRO049 | pending |
| TPB5PRO053..056 | lane 0, 4 channels @ rate_word=0x1000 ea. | GTS-arm | same | two ring-CAM partitions used (channel[1:0] modulo 4); per-channel rate 0x1000 each | pending |
| TPB5PRO057..060 | lane 0, 8 channels @ rate_word=0x0800 ea. | GTS-arm | same | all 4 ring-CAM partitions used | pending |
| TPB5PRO061..062 | lane 0, 16 channels @ rate_word=0x0400 ea. | GTS-arm | same | all 4 partitions roughly equal | pending |
| TPB5PRO063..064 | lane 0, 32 channels @ rate_word=0x0200 ea. | GTS-arm | same | all 4 partitions roughly equal; uniform per-bin rate within Poisson 3σ | pending |

### Group P4 — real-MuTRiG mode-2 free-running rate sweep, 16 cases

Stimulus: real MuTRiG, §2 baseline cfg, all channels active, `mutrig_injector_0.mode = 2 (periodic)`. Sweep `pulse_interval` over a 16-point log grid covering ≈ 1..25 Mhit/s per MuTRiG (on top of the dark-rate floor): `pulse_interval ∈ {16384, 8192, 4096, 2048, 1024, 512, 256, 200, 160, 128, 100, 80, 64, 50, 40, 32}` cycles at 125 MHz emulator/datapath clock.

Current status: `BLOCKED`. The injector path gate passes on the emulator side and the real-source mode-2 precheck now proves lanes 0/3 are injector-correlated after ASIC0/ASIC3 channel-16 configuration. The recompiled frame/MTS/histogram SignalTap image also captured real-lane accepted hits at `histogram_statistics_0.asi_hist_fill_in_valid`. Do not start the P4 real-rate sweep for closure until repeated real windows have zero MTS discards, zero ring input errors, zero histogram drops, and the real-lane mask/waiver policy is explicit.

| case_id | pulse_interval | requested rate | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|---|
| TPB5PRO065..080 | sweep | ≈ 1..25 Mhit/s | GTS-arm at four equally-spaced points | T6 (2048×4), T7 (4096×4), others 1024×4 | `histogram_statistics_0.TOTAL_HITS` rate scales as expected; ring-CAM peak `filllevel` rises monotonically and stays < 256 up to the wire-cap; `OVERFLOW_COUNT delta = 0`; SWB per-link counter rate matches FEB-egress rate within 1% | pending |

### Group P5 — ring-CAM fill-level pressure (deterministic preload), 16 cases

Stimulus: emulator burst-mode hits arranged so a single ring-CAM partition fills to 25%, 50%, 75%, 100% of its 512-entry depth before the consumer drains. Achieved by pulsing `csr_hit_rate` then halting the consumer briefly (via run-control SYNC stall). 4 fill targets × 4 partitions = 16 cases.

| case_id | partition | fill_target | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|---|
| TPB5PRO081..084 | partition 0, fill ∈ {25%, 50%, 75%, 100%} | (4 cases) | GTS-arm to capture fill ramp | T6 partition 0 (4096×4), T7 (4096×4) | T6 `aso_filllevel_data[15:0]` reaches the configured target; partition still drains correctly when consumer resumes; no overflow into a different partition; `OVERFLOW_COUNT delta = 0`; T7 `frame_cnt` advances normally afterwards | pending |
| TPB5PRO085..088 | partition 1, same fill grid | (4 cases) | same | T6 partition 1, T7 | same evidence pattern, partition 1 | pending |
| TPB5PRO089..092 | partition 2, same fill grid | (4 cases) | same | T6 partition 2, T7 | same evidence, partition 2 | pending |
| TPB5PRO093..096 | partition 3, same fill grid | (4 cases) | same | T6 partition 3, T7 | same evidence, partition 3 | pending |

### Group P6 — backpressure-FIFO fill-level pressure, 8 cases

Stimulus: emulator lane k saturated at `rate_word = 0x8000` while the downstream `mux_mutrig2processor` is briefly stalled (via run-control SYNC). The 128-entry `backpressure_fifo` for that lane fills toward 25%, 50%, 75%, 100% of capacity. Verifies upstream back-pressure to the emulator is correctly observed and no hit is dropped silently.

| case_id | lane | fill_target | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|---|
| TPB5PRO097..104 | lane k ∈ {0..7} | 75% (96/128), one case per lane to keep 128 | GTS-arm to capture fill ramp | T2[k] (4096×4), T0 1024×4 | T2 `filllevel` reaches 96 ± 4; T0 emulator `aso_tx8b1k_valid` deasserts on cycles where the upstream is back-pressured; downstream consumption resumes cleanly; no payload loss on T1, T6, T7 | pending |

### Group P7 — sustained soak at 200 Mhit/s aggregate, 8 cases

Stimulus: 8 emulator lanes at `rate_word = 0x4000` each, `csr_short_mode = 1`. The aggregate is at the 200 Mhit/s design target. Run a 60 s soak and capture four 1-segment traces at start / 25% / 50% / 75% / end of the window.

| case_id | window phase | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5PRO105 | 0..60 s soak, segment at t=0 s | K-symbol arm at T8 (K28.0), GTS-arm elsewhere | T6 (2048×4), T7 (4096×4), T8 (1024×4), TS | first segment shows nominal traffic; `OVERFLOW_COUNT delta = 0` | pending |
| TPB5PRO106 | t=15 s | same | same | second segment same nominal traffic; no counter drift | pending |
| TPB5PRO107 | t=30 s | same | same | third segment | pending |
| TPB5PRO108 | t=45 s | same | same | fourth segment | pending |
| TPB5PRO109 | t=60 s end-of-soak | same | same | end-of-soak: `OVERFLOW_COUNT delta = 0`, `DROPPED_HITS delta = 0`, `UNDERFLOW_COUNT delta = 0` over the full 60 s | pending |
| TPB5PRO110 | 60 s soak, post-end flush | post-CMD_END_RUN (run_state = TERMINATING → IDLE) | T7 (4096×4) | post-end flush captures the `terminating_marker_*` propagation; `frame_cnt` increments stop within the documented `TERMINATING_IDLE_GUARD_CONST = 2048` cycles | pending |
| TPB5PRO111 | 120 s soak (extension) | GTS-arm at end | T6, T7, T8 | extends TPB5PRO105..110 to 120 s; same pass criteria | pending |
| TPB5PRO112 | 300 s soak (long extension) | GTS-arm at end | T6, T7, T8 | 5-minute soak; cumulative `OVERFLOW_COUNT delta = 0` | pending |

### Group P8 — real-MuTRiG sustained soak with mode-2 injector, 8 cases

Stimulus: real MuTRiG, all 8 ASICs, `mutrig_injector_0.mode = 2` at `pulse_interval = 50` cycles ≈ wire-cap. Run a 60 s soak. 8 cases × different (ASIC subset, channel mask) configurations.

Current status: `BLOCKED` for the same real-MuTRiG cfg/LVDS gate as P4.

| case_id | active subset | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5PRO113 | REAL all 8 ASICs, all channels, full sat | GTS-arm | T6, T7, T8, TS | sustained accepted rate ≈ 200 Mhit/s; `OVERFLOW_COUNT delta = 0`; SWB per-link rate matches | pending |
| TPB5PRO114 | REAL all 8 ASICs, channel mask = lower-half | GTS-arm | same | per-channel rate doubles for active channels; aggregate accepted rate halved relative to TPB5PRO113 | pending |
| TPB5PRO115 | REAL ASIC subset 0..3 only, full channel mask | GTS-arm | T6(M=0,K=0..3), T7(M=0), T8(M=0) | only hit_stack_subsystem_0 sees traffic; hit_stack_subsystem_1 quiescent | pending |
| TPB5PRO116 | REAL ASIC subset 4..7 only, full channel mask | GTS-arm | T6(M=1,K=0..3), T7(M=1), T8(M=1) | only hit_stack_subsystem_1 active | pending |
| TPB5PRO117 | REAL ASIC subset {0, 2, 4, 6}, full mask | GTS-arm | T6, T7, T8 | per-MuTRiG rate same as wire-cap; aggregate halved | pending |
| TPB5PRO118 | REAL alternating ASIC enable (0, 1) per lane | GTS-arm | T6, T7, T8 | per-MuTRiG fill consistent across all enabled ASICs | pending |
| TPB5PRO119 | REAL all 8 ASICs but ASIC 7 stuck at TTH=63 | GTS-arm | T6, T7, T8 | only 7 ASICs contribute; aggregate rate = 7 × 25 Mhit/s = 175 Mhit/s | pending |
| TPB5PRO120 | REAL all 8 ASICs, mode-2 with `pulse_interval = 32` (deliberate over-rate) | GTS-arm | T6, T7, T8, TS | accepted rate plateaus at the wire-cap; the **excess** is dropped at the MuTRiG side (per `csr.dropped_count` if exposed); `OVERFLOW_COUNT` on histogram = 0; SWB per-link counter rate matches the FEB egress (no FEB-side drop) | pending |

### Group P9 — emulator + real-MuTRiG simultaneous (mixed-source), 8 cases

Stimulus: 4 emulator lanes (0..3) at `rate_word = 0x4000` plus 4 real ASICs (4..7) at `mutrig_injector_0.mode = 2, pulse_interval = 50`. Verifies mixed-source operation.

Current status: `BLOCKED`. The emulator half is now usable through the live `mutrig_injector_0` path and passes a monotonic interval sweep; the real-MuTRiG half is still blocked by missing frame-deassembly lock after XML cfg.

| case_id | mix | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5PRO121..128 | EMU lanes 0..3 + REAL ASIC 4..7, 8 sub-cases varying total rate (50%, 75%, 100% of wire-cap, 110% over-rate, plus 4 cases varying per-half rate ratios) | GTS-arm | T6 (2048×4), T7 (4096×4), T8 (1024×4), TS | both halves contribute; per-lane/ASIC rate matches expected; aggregate accepted rate matches the design budget; `OVERFLOW_COUNT delta = 0` (except the deliberate over-rate case where the documented per-source drop is noted but the histogram does not overflow) | pending |

### Group P10 — subsystem-boundary pressure and selector robustness, 16 cases

Stimulus: pressure the lane 3/4 boundary and the histogram pre/post selector under load. These cases are aimed at plausible bugs where high-rate traffic on the M=1 half is accidentally counted through the M=0 histogram bridge, or where the T6/T7 capture plan misses one hit-stack subsystem under simultaneous pressure.

| case_id | pressure pattern | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5PRO129..136 | EMU lane pair {3, 4}, rate_word pairs {(0x4000,0x0400), (0x0400,0x4000), (0x8000,0x1000), (0x1000,0x8000)} with `histogram_ingress_bridge_0.select_post ∈ {0,1}` | GTS-arm at four equally-spaced points | T4(M=0/1), T5, T6(M=0/1, 2048×4), T7(M=0/1, 4096×4), TS | M=0 and M=1 rates scale independently; toggling `select_post` changes only the histogram-bridge observation surface and does not move M=1 traffic into T5; `OVERFLOW_COUNT delta = 0` | pending |
| TPB5PRO137..144 | hot-pair matrix {0,4}, {1,5}, {2,6}, {3,7} at 75% and 110% aggregate requested rate | GTS-arm | T2 for both active lanes, T6(M=0/1), T7(M=0/1), T8, TS | both hit-stack subsystems show the expected fill-level ratio; over-rate plateaus without FEB-side loss; SWB per-link rate equals accepted FEB egress rate | pending |

## Closure aggregator

PROF bucket PASSES when:

- Every TPB5PRO### row's primary observable (rate, fill-level, drop counter) matches the predicted scaling.
- `OVERFLOW_COUNT delta = 0` across every PROF case.
- The 60 s and 300 s soak cases (P7, P8) close with no counter drift.
- For long-term closure, every row's `MATCH:` resolves to a passing `tb_int/` integration-sim case.

PROF bucket FAILS if a rate-doubling ratio collapses below the wire-cap (regression vs the historical 135 Mhit/s knee), if `OVERFLOW_COUNT` advances, or if any sustained-soak case shows cumulative drift in any of the three histogram counters.
