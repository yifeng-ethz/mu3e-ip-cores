# TEST_BASIC.md — Phase-5 BASIC bucket (directed end-to-end hit propagation)

**Companion**: [`TEST_PLAN_PHASE5.md`](TEST_PLAN_PHASE5.md) §1.6, §3
**Sibling buckets**: [`TEST_PROF.md`](TEST_PROF.md) · [`TEST_EDGE.md`](TEST_EDGE.md) · [`TEST_ERROR.md`](TEST_ERROR.md)
**Catalog ID range**: `TPB5BAS001` … `TPB5BAS144` (entry catalog; long-term target 500–3000 cases)
**Intent**: prove a hit emitted at one (ASIC, channel) propagates through every IP boundary of the §3.2 chain and arrives at the SWB. Each case names a stimulus configuration, the SignalTap instances that must be armed, the GTS / packet-boundary trigger condition per instance, and the per-IP boundary evidence the case attests.

## How to read this catalog

Every row implements the §3.3 multi-instance arming model:

- **stimulus** — emulator CSR / real-MuTRiG cfg knob and the activated lane / channel.
- **trigger** — GTS-arm (`gts_8n_lo == TARGET_GTS`), K-symbol arm (K28.0/K28.4/sub-header), or state-arm (`run_state_cmd == X`). Same trigger applied to every armed instance unless noted; cross-IP alignment is via the captured GTS slice.
- **taps** — the §3.4 tap stations that must be armed (T0..T8 + TS). All cases include T0, T1, T7, T8, TS as the minimum chain end-points; intermediate taps are added per case.
- **evidence** — the per-IP AVST signal or CSR counter delta that confirms the hit reached this boundary.
- **MATCH** — the corresponding `tb_int/` integration-sim case the BOARD evidence must match in long-term closure (`pending` until the tb is added).

`SWB-CHK` in the evidence column means the SWB per-link hit counter delta matches the FEB-egress hit count, per §3.9.

## Execution scoreboard

Status vocabulary is defined in `TEST_PLAN_PHASE5.md` §1.7. This table is the first-level record of what has actually run; keep it updated after every SignalTap or board run. If a ranged row partially runs, record the exact subrange in the notes or split the catalog row before marking it `PASS`.

| Group | Cases | Status | PASS | FAIL | BLOCKED | Last evidence | Notes |
|---|---:|---|---:|---:|---:|---|---|
| A1 | 32 | not-run | 0 | 0 | 0 | none | single-channel emulator burst |
| A2 | 32 | BLOCKED | 0 | 0 | 32 | [`../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat12_250ms_fda0_hiterr_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat12_250ms_fda0_hiterr_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat40_250ms_post_hiterr_timeout_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_injector_real03_ch16_repeat40_250ms_post_hiterr_timeout_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_frame_hist_mts_histstats_stp_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md) | lanes 0/3 now produce injector-correlated real hits after ASIC0/3 XML cfg and channel-16 override. Earlier repeated windows showed intermittent one-discard events with zero histogram drops, ring input errors, or frame CRC errors; SignalTap localized that discard to a lane-0 `mutrig_frame_deassembly_0.aso_hit_type0_error[0]` beat for ASIC0/channel16 before MTS. A fresh runctl/MTS-stage trigger did not reproduce the hiterr and 52 follow-up windows passed with zero MTS discards or downstream errors, but the group remains blocked pending a longer accepted zero-discard soak and lanes 1/2/4/5/6/7 link/fatal accounting |
| A3 | 16 | not-run | 0 | 0 | 0 | none | multi-hit per frame |
| A4 | 8 | not-run | 0 | 0 | 0 | none | channel mask expansion |
| A5 | 8 | not-run | 0 | 0 | 0 | none | ASIC mask expansion |
| A6 | 16 | not-run | 0 | 0 | 0 | none | burst-size sweep |
| A7 | 8 | not-run | 0 | 0 | 0 | none | frame-interval extremes |
| A8 | 8 | not-run | 0 | 0 | 0 | none | frame-counter cross-IP increment |
| A9A | 8 | not-run | 0 | 0 | 0 | none | emulator hit-stack boundary and bridge-bypass variants |
| A9B | 8 | BLOCKED | 0 | 0 | 8 | [`../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_runctl_mts_stage_hiterr_followup_20260429.md), [`../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md`](../systems/system_20260427_testplanphase5/reports/phase5_real03_mts_input_hiterr_debug_20260429.md) | mixed EMU/REAL variants remain blocked until the real-MuTRiG lane mask/waiver policy is explicit; latest 52-window lane0/3 follow-up is clean but does not cover the full mixed-source lane-pair matrix |

## Wiring and prerequisites

Every BASIC case assumes:

- Phase 4 closure attested (`TPB100`).
- §2 baseline cfg loaded for any case using real MuTRiG; cases tagged `EMU` use `emulator_mutrig_N` with `csr.enable=1, hit_mode=01 (burst), short_mode=1, csr_burst_size`/`hit_rate` set per case.
- `histogram_ingress_bridge_0.select_post = 0` (pre-hit-stack tap) for channel-rate cases; `= 1` (post-hit-stack tap) for delay cases. BASIC bucket is mostly pre-tap.
- `histogram_statistics_0`: `LEFT_BOUND = 0, RIGHT_BOUND = 255, BIN_WIDTH = 1` so each bin is one global-channel ID; `INTERVAL_CFG` ≥ 2¹⁸ so one ping-pong interval contains many hits per active bin.
- Run-control: `IDLE → RUN_PREPARE → SYNC → RUNNING → TERMINATING → IDLE` per case; default RUN window 200 ms.

## Catalog

### Group A1 — single (ASIC, channel) emulator burst, 32 cases

Stimulus: emulator `csr.hit_mode = 01 (burst)`, `csr_burst_size = 1`, `csr_burst_center = 16`, `csr_inject_channel_mask = (1 << ch)`. One channel emits exactly one hit per frame; rest are silent. `csr_hit_rate = 0x0040` (≈ 0.25 hits/frame, well below saturation). 8 emulator lanes × 4 representative channels each = 32 cases. The 4 channel choices per lane are `{0, 7, 16, 31}` to cover lane-base, mid-low, mid-high, lane-top corners.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS001 | EMU lane 0, ch 0 | K-symbol arm at T0 (K28.0); GTS-arm at T1..T8, TS | T0..T8, TS | T0 sees one K28.0..K28.4 frame containing one hit byte sequence with `channel = 0`; T1 `aso_hit_type0_data` with `channel = 0`, `sop = '1'` once; T2 `filllevel` rises by exactly 1 on the matching cycle; T3 muxed AVST shows lane-0 select; T4 `aso_hit_type1_channel = 4'h0`, ASIC ID embedded in payload `data[38:35] = 4'h0`; T6 ring-CAM partition-0 stores the entry, `filllevel` rises by 1 then drops on read; T7 `aso_hit_type3` carries the hit on its way to upload; T8 byte-stream egresses; SWB-CHK delta = 1 | pending |
| TPB5BAS002 | EMU lane 0, ch 7 | same | same | T1 channel=7; T6 partition-1 stores it (channel[1:0]=01 selects partition); other taps as TPB5BAS001 with channel=7 | pending |
| TPB5BAS003 | EMU lane 0, ch 16 | same | same | T1 channel=16; T6 partition-0 (channel[1:0]=00) stores it | pending |
| TPB5BAS004 | EMU lane 0, ch 31 | same | same | T1 channel=31; T6 partition-3 (channel[1:0]=11) stores it; bin 31 of histogram populated | pending |
| TPB5BAS005..008 | EMU lane 1, ch ∈ {0, 7, 16, 31} | same | same | identical evidence pattern, ASIC ID = 1, lane-1 slice (bins 32..63) of histogram populated | pending |
| TPB5BAS009..012 | EMU lane 2, ch ∈ {0, 7, 16, 31} | same | same | ASIC ID = 2, bins 64..95 | pending |
| TPB5BAS013..016 | EMU lane 3, ch ∈ {0, 7, 16, 31} | same | same | ASIC ID = 3, bins 96..127 | pending |
| TPB5BAS017..020 | EMU lane 4, ch ∈ {0, 7, 16, 31} | same | same | ASIC ID = 4, bins 128..159; this lane is the first lane in hit_stack_subsystem_1 | pending |
| TPB5BAS021..024 | EMU lane 5, ch ∈ {0, 7, 16, 31} | same | same | ASIC ID = 5, bins 160..191 | pending |
| TPB5BAS025..028 | EMU lane 6, ch ∈ {0, 7, 16, 31} | same | same | ASIC ID = 6, bins 192..223 | pending |
| TPB5BAS029..032 | EMU lane 7, ch ∈ {0, 7, 16, 31} | same | same | ASIC ID = 7, bins 224..255; lane-7 ch-31 lands at the absolute top bin (255) | pending |

### Group A2 — single (ASIC, channel) real-MuTRiG mode-4 onClick, 32 cases

Stimulus: real MuTRiG, §2 baseline cfg with all channels at TTH=63 (silent) **except** the case's selected channel at the §2.5 known-good TTH. `mutrig_injector_0` is configured for one onClick: write `csr.mode = 4` (onclick) once, with `pulse_high_cycles = 8`. The injector emits exactly one pulse, which the live ASIC converts into one hit on the unmasked channel. 8 ASICs × 4 channels = 32 cases. Same channel choices as A1.

Current status: `BLOCKED`. The 2026-04-29 SC-recovered emulator gate proves the injector/fanout/emulator path with histogram/MTS hits, monotonic interval sweep, and negative controls. The real-source state has advanced: after ASIC0/ASIC3 XML configuration and channel-16-only overrides, lanes 0/3 produce injector-correlated histogram hits with no frame CRC errors and no histogram drops. The recompiled frame/MTS/histogram SignalTap image captured both `mts_preprocessor_0.aso_hit_type1_valid` and the downstream `histogram_statistics_0.asi_hist_fill_in_valid` boundary. Earlier repeated 250 ms windows showed one MTS discard in a 5-window run and one in an 8-window input-hiterr-triggered run, with `ring_inerr_delta=0` and `frame_crc_delta=0`; that VCD showed the bad beat was already flagged at `mutrig_frame_deassembly_0.aso_hit_type0_error[0]` on ASIC0/channel16 before it reached MTS, so MTS correctly discarded it under `discard_hiterr=1`. A fresh runctl/MTS-stage rebuild then timed out on the same hiterr trigger while the paired 12-window run passed, followed by a 40-window SC-only soak with zero MTS discards, zero ring input errors, zero histogram drops, zero frame CRC errors, and zero missing hits. Keep A2 blocked until a longer accepted zero-discard soak exists and the remaining real lanes 1/2/4/5/6/7 are recovered or waived.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS033..036 | REAL ASIC 0, ch ∈ {0, 7, 16, 31}, onClick | T0 K-symbol arm; GTS-arm elsewhere | T0..T8, TS | T0 byte stream from real ASIC 0 (post-cfg); T1..T8 same per-IP boundary evidence as A1 with `aso_hit_type0_error[2:0] = 0`; the `INJ_ARM` SignalTap negative trigger from `TEST_PLAN.md` §4.3 must not fire; SWB-CHK delta = 1 | pending |
| TPB5BAS037..040 | REAL ASIC 1, ch ∈ {0, 7, 16, 31}, onClick | same | same | same evidence pattern, ASIC ID = 1 | pending |
| TPB5BAS041..044 | REAL ASIC 2, ch ∈ {0, 7, 16, 31}, onClick | same | same | ASIC ID = 2 | pending |
| TPB5BAS045..048 | REAL ASIC 3, ch ∈ {0, 7, 16, 31}, onClick | same | same | ASIC ID = 3 | pending |
| TPB5BAS049..052 | REAL ASIC 4, ch ∈ {0, 7, 16, 31}, onClick | same | same | ASIC ID = 4 | pending |
| TPB5BAS053..056 | REAL ASIC 5, ch ∈ {0, 7, 16, 31}, onClick | same | same | ASIC ID = 5 | pending |
| TPB5BAS057..060 | REAL ASIC 6, ch ∈ {0, 7, 16, 31}, onClick | same | same | ASIC ID = 6 | pending |
| TPB5BAS061..064 | REAL ASIC 7, ch ∈ {0, 7, 16, 31}, onClick | same | same | ASIC ID = 7 | pending |

### Group A3 — multi-hit per frame, single ASIC, 16 cases

Stimulus: emulator `csr.hit_mode = 01 (burst)`, `csr_burst_size ∈ {2, 3, 4}`, `csr_inject_channel_mask` chosen so exactly the configured channels participate. Verifies that ring_buffer_cam reordering is correct when more than one hit per frame lands on the same lane. 8 ASICs × 2 channel-pairs/triples per ASIC = 16 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS065..072 | EMU lane k (k=0..7), 2 channels (ch=0, ch=15) | GTS-arm | T0..T8, TS | T1 `aso_hit_type0` shows two hits per K28.0..K28.4 packet; T6 `aso_hit_type2` shows two hits ordered by timestamp; T7 `aso_hit_type3` shows two payload bytes; SWB-CHK delta = 2 per packet | pending |
| TPB5BAS073..080 | EMU lane k (k=0..7), 3 channels (ch=0, 11, 22) | GTS-arm | T0..T8, TS | T1 three hits per packet; ring_buffer_cam_{0,1,2} each see one hit (channel[1:0] partitions across CAMs); T7 three payload bytes; SWB-CHK delta = 3 | pending |

### Group A4 — incremental channel unmask, single ASIC, 8 cases

Stimulus: emulator lane 0, `csr_hit_rate = 0x0100` Poisson, `inject_channel_mask` widening: `{0x00000001, 0x00000003, 0x0000000F, 0x000000FF, 0x0000FFFF, 0x00FFFFFF, 0x7FFFFFFF, 0xFFFFFFFF}`. The number of populated histogram bins must scale linearly with bit-popcount of the mask. 8 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS081 | EMU lane 0, mask=0x00000001 | GTS-arm | T0..T8, TS | bin 0 of histogram populated; bins 1..31 = 0; T6 only partition-0 sees hits | pending |
| TPB5BAS082 | EMU lane 0, mask=0x00000003 | GTS-arm | same | bins 0..1 populated; bins 2..31 = 0 | pending |
| TPB5BAS083 | EMU lane 0, mask=0x0000000F | GTS-arm | same | bins 0..3 populated | pending |
| TPB5BAS084 | EMU lane 0, mask=0x000000FF | GTS-arm | same | bins 0..7 populated | pending |
| TPB5BAS085 | EMU lane 0, mask=0x0000FFFF | GTS-arm | same | bins 0..15 populated | pending |
| TPB5BAS086 | EMU lane 0, mask=0x00FFFFFF | GTS-arm | same | bins 0..23 populated | pending |
| TPB5BAS087 | EMU lane 0, mask=0x7FFFFFFF | GTS-arm | same | bins 0..30 populated | pending |
| TPB5BAS088 | EMU lane 0, mask=0xFFFFFFFF | GTS-arm | same | bins 0..31 populated | pending |

### Group A5 — incremental ASIC unmask, all channels, 8 cases

Stimulus: emulator, all channels per lane, lanes activated incrementally `{0x01, 0x03, 0x07, 0x0F, 0x1F, 0x3F, 0x7F, 0xFF}` (csr.enable bit asserted per active lane; deasserted on muted lanes). The number of populated histogram bin slices must scale 32-bins-per-active-lane.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS089 | EMU lanes_active = 0x01 (lane 0 only) | GTS-arm | T0..T8, TS | bins 0..31 populated, 32..255 = 0; only T1[0], T2[0], T6[0..3] for lane 0 | pending |
| TPB5BAS090 | EMU lanes_active = 0x03 | GTS-arm | same | bins 0..63 populated | pending |
| TPB5BAS091 | EMU lanes_active = 0x07 | GTS-arm | same | bins 0..95 populated | pending |
| TPB5BAS092 | EMU lanes_active = 0x0F | GTS-arm | same | bins 0..127 populated; lane 3 completes hit_stack_subsystem_0 and hit_stack_subsystem_1 remains quiet | pending |
| TPB5BAS093 | EMU lanes_active = 0x1F | GTS-arm | same | bins 0..159 populated; lane 4 is the first active lane in hit_stack_subsystem_1 | pending |
| TPB5BAS094 | EMU lanes_active = 0x3F | GTS-arm | same | bins 0..191 populated | pending |
| TPB5BAS095 | EMU lanes_active = 0x7F | GTS-arm | same | bins 0..223 populated | pending |
| TPB5BAS096 | EMU lanes_active = 0xFF | GTS-arm | same | bins 0..255 populated | pending |

### Group A6 — hit-spacing per frame, deterministic burst, 16 cases

Stimulus: emulator lane 0, single channel ch=0, `csr.hit_mode = 01 (burst)` with `csr_burst_size ∈ {1..16}`. Verifies that the hit_stack subsystem ordered output matches the timestamp-ordered input across an increasing number of hits per frame. 16 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS097..112 | EMU lane 0, ch 0, burst_size = N (N=1..16) | GTS-arm | T0..T8, TS | T1 sees N hits per K28.0..K28.4 packet; T6 sees N hits in order on partition-0; T7 emits N hits per packet; SWB-CHK delta = N | pending |

### Group A7 — minimum and maximum frame interval, 8 cases

Stimulus: emulator with `csr_short_mode ∈ {0, 1}`, lane 0, ch 0, single hit per frame. `csr_short_mode = 1 → FRAME_INTERVAL_SHORT = 910`; `csr_short_mode = 0 → FRAME_INTERVAL_LONG = 1550`. Repeat for lanes 0, 2, 5, 7 (4 lanes × 2 modes = 8 cases).

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS113 | EMU lane 0, short_mode = 1 | K-symbol arm (K28.0) at T0 | T0..T8, TS | cycle distance between consecutive K28.0 captures at T0 = 910 ± 1 | pending |
| TPB5BAS114 | EMU lane 0, short_mode = 0 | K-symbol arm (K28.0) at T0 | T0..T8, TS | cycle distance = 1550 ± 1 | pending |
| TPB5BAS115 | EMU lane 2, short_mode = 1 | same | same | distance = 910 ± 1 | pending |
| TPB5BAS116 | EMU lane 2, short_mode = 0 | same | same | distance = 1550 ± 1 | pending |
| TPB5BAS117 | EMU lane 5, short_mode = 1 | same | same | distance = 910 ± 1 | pending |
| TPB5BAS118 | EMU lane 5, short_mode = 0 | same | same | distance = 1550 ± 1 | pending |
| TPB5BAS119 | EMU lane 7, short_mode = 1 | same | same | distance = 910 ± 1 | pending |
| TPB5BAS120 | EMU lane 7, short_mode = 0 | same | same | distance = 1550 ± 1 | pending |

### Group A8 — frame-counter increment cross-IP, 8 cases

Stimulus: emulator all 8 lanes, all channels, low rate (`csr_hit_rate = 0x0100`). Captures the per-deassembler `csr.frame_counter_head` at T1 and the `feb_frame_assembly.frame_cnt` at T7 for **two consecutive triggered acquisitions** in the segmented buffer. Across the four-segment capture, both counters must increment by exactly 1 per segment pair. 8 cases (one per lane).

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS121..128 | EMU lane k (k=0..7), low rate | K-symbol arm (K28.4) at T1 (one trigger per frame) | T1, T7 (4-segment each) | for each adjacent pair of segments: `csr.frame_counter_head` advanced by 1 at T1; `frame_cnt` advanced by 1 at T7; both increments are matched (no missed frame between deassembly and assembly) | pending |

### Group A9A — emulator hit-stack subsystem boundary and histogram-bridge bypass, 8 cases

Stimulus: low-rate single-hit packets placed at the subsystem boundary. These cases target two likely integration bugs: an off-by-one lane-to-hit-stack decode at lane 3/4, and accidental routing of hit_stack_subsystem_1 traffic through the histogram ingress bridge that only feeds hit_stack_subsystem_0.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS129..136 | EMU lane pair {3, 4}, ch ∈ {0, 7, 16, 31}, one lane active per sub-case | GTS-arm | T4, T5, T6(M=0,K), T6(M=1,K), T7(M=0), T7(M=1), T8, TS | lane 3 appears only on hit_stack_subsystem_0 and exercises `histogram_ingress_bridge_0.pre_in/pre_out`; lane 4 appears only on hit_stack_subsystem_1 and bypasses the bridge; SWB-CHK delta = 1 | pending |

### Group A9B — mixed-source hit-stack boundary variants, 8 cases

Current status: `BLOCKED`. These rows intentionally combine one emulator-side and one real-MuTRiG-side source at the hit-stack subsystem boundary. The emulator half of the injector path is live, and lanes 0/3 of the real half now produce injector-correlated hits after ASIC0/ASIC3 channel-16 configuration. The latest 52-window follow-up did not reproduce the earlier lane-0 frame-deassembly `error[0]` discard, but the lane-pair matrix still requires a longer accepted zero-discard soak and the remaining real lanes to be locked or explicitly waived.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5BAS137..144 | mixed EMU/REAL source pairs {0, 4}, {1, 5}, {2, 6}, {3, 7} with ch ∈ {0, 31} | GTS-arm | T1, T4, T5, T6(M=0,K), T6(M=1,K), T7(M=0), T7(M=1), TS | both hit-stack subsystems carry exactly one hit when both sources are enabled; `histogram_ingress_bridge_0` sees only the M=0 side; M=1 evidence is present at T6/T7 with no duplicate at T5 | pending |

## Closure aggregator

BASIC bucket PASSES when:

- Every TPB5BAS### row produces the listed evidence on every armed tap station.
- No `*_error` AVST flag asserts, no `OVERFLOW_COUNT`/`DROPPED_HITS`/`UNDERFLOW_COUNT` increment.
- The SWB per-link counter delta matches the FEB egress hit count for every case (§3.9).
- For long-term closure, every row's `MATCH:` resolves to a passing `tb_int/` integration-sim case.

BASIC bucket FAILS if any case shows a downstream tap missing a hit that an upstream tap captured (lost hit), a counter mismatch, or an unexpected `*_error` assertion. Failures route per the §6 first-pass debug ladder.
