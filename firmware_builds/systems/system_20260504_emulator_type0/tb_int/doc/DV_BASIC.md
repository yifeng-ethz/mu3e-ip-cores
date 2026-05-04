# tb_int BASIC — `system_20260504_emulator_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md) — see §3 for the per-bucket budget.

**Total: 192 cases.** `BASIC-RC-001..BASIC-RC-032`, `BASIC-SC-001..BASIC-SC-032`, `BASIC-DT-001..BASIC-DT-128`.

CSR addresses are owned by each IP's packaging (`<ip>_hw.tcl` / `reg_pkg.sv`); this file does not duplicate them.

---

## RC section (BASIC-RC-001..BASIC-RC-032)

A single case is one unique run-control combinatorial sequence. Every case must end with all IPs back at `IDLE` and the run-control box's `RUN_NUMBER` correctly tracked.

| ID | Sequence (RC state path) | Verifier |
|---|---|---|
| BASIC-RC-001 | `IDLE → RUN_PREP → IDLE` (single shortest cycle) | every IP `STATUS.run_state` matches; `RUN_NUMBER` unchanged |
| BASIC-RC-002 | `IDLE → RUN_PREP → SYNC → IDLE` | per-IP run-state observed at every transition |
| BASIC-RC-003 | `IDLE → RUN_PREP → SYNC → RUNNING → IDLE` | `RUN_NUMBER` incremented exactly once on `RUN_PREP` |
| BASIC-RC-004 | `IDLE → RUN_PREP → SYNC → RUNNING → TERMINATING → IDLE` | full canonical run; `endofrun` propagates |
| BASIC-RC-005 | Two back-to-back canonical runs | `RUN_NUMBER` increments twice; counters reset between |
| BASIC-RC-006 | Three canonical runs | sustained `RUN_NUMBER` tracking |
| BASIC-RC-007 | `IDLE → RUN_PREP → RESET → IDLE` (cancel before SYNC) | every IP returns to defaults; `RUN_NUMBER` does not increment |
| BASIC-RC-008 | `IDLE → RUN_PREP → SYNC → RESET → IDLE` (cancel before RUNNING) | same as 007 plus `partial_packet_drop_sticky` clears |
| BASIC-RC-009 | `IDLE → RUN_PREP → SYNC → RUNNING → RESET → IDLE` | mid-run abort; counters cleared per IP contract |
| BASIC-RC-010 | `RESET` from `TERMINATING` | force-close in-flight frames |
| BASIC-RC-011 | `RUN_PREP` re-entered from `RUN_PREP` (idempotent) | no duplicate `RUN_NUMBER` increment |
| BASIC-RC-012 | `SYNC` held for 100 cycles | sync stability window; no consumer drift |
| BASIC-RC-013 | `SYNC` held for 1000 cycles | longer stability window |
| BASIC-RC-014 | `RUNNING` held for 10000 cycles with no hits | run timer + frame counter advance correctly |
| BASIC-RC-015 | `TERMINATING` held for 100 cycles before `IDLE` | every consumer drains, `merged_locked` sets |
| BASIC-RC-016 | `IDLE → RUN_PREP → SYNC → RUNNING → SYNC → RUNNING → TERMINATING → IDLE` (re-sync mid-run) | re-sync stability; counters do not double-clear |
| BASIC-RC-017 | Canonical run with `RUN_NUMBER = 0` | identity-zero path |
| BASIC-RC-018 | Canonical run with `RUN_NUMBER = 0xFFFF_FFFE` (boundary) | counter near saturation |
| BASIC-RC-019 | Canonical run with `RUN_NUMBER = 0xFFFF_FFFF` (saturation) | saturating behaviour observable |
| BASIC-RC-020 | Run with mid-run RC commands while IPs are mid-flush | hard-reset during functional-reset entering |
| BASIC-RC-021 | Run with mid-run RC commands while IPs are mid-frame open | force-close path on `arb_hit_type0` watchdog |
| BASIC-RC-022 | Run with `RUN_PREP` re-asserted at the same cycle a frame closes | timing-edge path |
| BASIC-RC-023 | Run with `SYNC` held longer than the watchdog window | watchdog must not fire during SYNC |
| BASIC-RC-024 | Run with `RUNNING → SYNC → RUNNING` (sync mid-run) | counter snapshot semantics |
| BASIC-RC-025 | Run with two `RESET` events spaced 1 cycle apart | back-to-back reset robustness |
| BASIC-RC-026 | Run with two `RESET` events spaced 5000 cycles apart | longer sequencing |
| BASIC-RC-027 | Random sequence depth = 4 (LCG seed 0xA1) | seeded randomised path; uniqueness asserted by checksum |
| BASIC-RC-028 | Random sequence depth = 6 (LCG seed 0xB2) | |
| BASIC-RC-029 | Random sequence depth = 8 (LCG seed 0xC3) | |
| BASIC-RC-030 | Random sequence depth = 12 (LCG seed 0xD4) | |
| BASIC-RC-031 | Random sequence depth = 16 (LCG seed 0xE5) | |
| BASIC-RC-032 | Random sequence depth = 32 (LCG seed 0xF6) | longest BASIC-bucket path |

Each case asserts: every IP's `STATUS.run_state` matches the broadcast at every cycle observed; `runctl_mgmt_host.RUN_NUMBER` matches the host model; `arb_hit_type0` `ERROR_COUNT_*` and `STATUS.*_sticky` stay zero; UID readback unchanged across the run.

---

## SC section (BASIC-SC-001..BASIC-SC-032)

A single case is one SC-traffic pattern. CSR addresses come from `reg_pkg.sv`; this section never lists addresses.

| ID | Stimulus | Verifier |
|---|---|---|
| BASIC-SC-001 | Identity scan: read `UID` + `META(0..3)` from every IP slave in the focus build | every UID matches its IP's documented constant; META read returns version / date / git / instance |
| BASIC-SC-002 | Single-word write of every RW field, read-back | bit-exact match |
| BASIC-SC-003 | Single-word write of every W1P field, read STATUS for stickies | clear behaviour confirmed |
| BASIC-SC-004 | Single-word read of every RO field | non-zero where documented (or zero for reserved) |
| BASIC-SC-005 | Burst read across `arb_hit_type0_0`'s 32-word aperture (full slave) | bursts complete inside one slave; no cross-talk |
| BASIC-SC-006 | Burst read across `mutrig_frame_deassembly_0`'s aperture | |
| BASIC-SC-007 | Burst read across `lvds_rx_controller_pro_0`'s aperture | |
| BASIC-SC-008 | Burst read across `histogram_statistics_0`'s aperture | |
| BASIC-SC-009 | Burst read across `runctl_mgmt_host`'s aperture | |
| BASIC-SC-010 | Burst read of `0x00..0x0F` (first half of arb_hit_type0_0) | |
| BASIC-SC-011 | Burst read of `0x10..0x1F` (second half of arb_hit_type0_0) | half-aperture burst |
| BASIC-SC-012 | Burst read of `0x10..0x1D` (last half minus reserved) | |
| BASIC-SC-013 | Burst read of length 1 (degenerate) | |
| BASIC-SC-014 | Burst read of length 2 | |
| BASIC-SC-015 | Burst read of length 4 | |
| BASIC-SC-016 | Burst read of length 8 | |
| BASIC-SC-017 | Burst read of length 16 | |
| BASIC-SC-018 | Burst read of length 32 (full slave) | |
| BASIC-SC-019 | Burst write of length 4 to consecutive RW fields | |
| BASIC-SC-020 | Cross-slave back-to-back: read arb_hit_type0_0 UID then mutrig_frame_deassembly_0 UID | mm_bridge arbitration honoured |
| BASIC-SC-021 | 8 cross-slave back-to-back reads | |
| BASIC-SC-022 | 32 cross-slave back-to-back reads | |
| BASIC-SC-023 | Counter-pair atomic read pair: `_L` then `_H` for every 64-bit pair | atomicity preserved |
| BASIC-SC-024 | Counter-pair read with intervening write: read `_L`, write CONTROL clear, read `_H` | latched-on-read snapshot logic |
| BASIC-SC-025 | Concurrent SC + RC: SC burst while RC is in `RUNNING` | independent control planes |
| BASIC-SC-026 | Concurrent SC + RC: SC burst spanning `RUNNING → TERMINATING` | run-state change does not interrupt SC burst |
| BASIC-SC-027 | SC burst during `RUN_PREP` reset window | SC blocks until RUN_PREP commits, then completes |
| BASIC-SC-028 | SC during the watchdog firing window | watchdog synthesis is not blocked by SC |
| BASIC-SC-029 | Identity scan after a full canonical run | post-run identity unchanged |
| BASIC-SC-030 | Identity scan after a `RESET` | post-reset identity unchanged |
| BASIC-SC-031 | Identity scan after `arb_hit_type0` mode = MIX_RR | mode-change does not affect identity surfacing |
| BASIC-SC-032 | Mass read of every CSR slave's full aperture (one burst per slave) | full SC mapping confirmed |

Each case ends with `UVM_ERROR == 0` and the SC bridge arbitration logs zero stalls beyond the documented bound.

---

## DT section (BASIC-DT-001..BASIC-DT-128)

A single case is one (rate × multiplicity × spatial × temporal × phasing × source-mix) combination. The OoO scoreboard is primary-keyed on `uid` (per `DV_PLAN.md` §2.1). Every case asserts: zero ghost hits, zero unaccounted drops, four-stage latency CDFs within budget, histogram cross-check matches at every tap.

### DT-A: smoke + DUT-contract corners (BASIC-DT-001..BASIC-DT-016, 16 cases)

| ID | Stimulus | Verifier |
|---|---|---|
| BASIC-DT-001 | Single hit, channel 0, T_coarse=0, T_fine=0, REAL mode | end-to-end OoO closes; latency = expected per-stage budget |
| BASIC-DT-002 | Single hit, channel 7, T_coarse=100, T_fine=8, REAL | |
| BASIC-DT-003 | Single hit, channel 8 (emu), T_coarse=200, T_fine=12, EMU | |
| BASIC-DT-004 | Single hit, channel 15 (emu), max channel id, EMU | |
| BASIC-DT-005 | 4 hits same T_coarse, channels 0..3, REAL | cluster verification |
| BASIC-DT-006 | 4 hits same T_coarse, channels 8..11, EMU | |
| BASIC-DT-007 | 8 hits same T_coarse, channels 0..7, REAL | |
| BASIC-DT-008 | 16 hits same T_coarse, real on channels 0..7 + emu on channels 8..15 (split-source MIX_RR) | both sources contribute; per-channel demux at scoreboard |
| BASIC-DT-009 | 32 hits same T_coarse, channels 0..7 + 8..15 + repeats inside cluster, MIX_RR | maximum cluster |
| BASIC-DT-010 | Smoke with frame-boundary phasing offset 0 | hit at frame start cycle |
| BASIC-DT-011 | Smoke with frame-boundary phasing offset 800 | mid-frame anchor |
| BASIC-DT-012 | Smoke with frame-boundary phasing offset 1549 | hit at frame end −1 cycle |
| BASIC-DT-013 | **DT-MODE-SWITCH-001** REAL → EMU mid-merged-packet, with hits in flight from both | mode_pending stays != mode while merged_open=1; mode commits at next merged_open=0 |
| BASIC-DT-014 | **DT-MODE-SWITCH-002** EMU → MIX_RR mid-packet | mode_pending defer + arbiter ramp-up |
| BASIC-DT-015 | **DT-MODE-SWITCH-003** MIX_RR → REAL mid-packet (with both sources active) | merged packet completes before mode commits |
| BASIC-DT-016 | **DT-RES-MODE-001** Write `CONTROL.mode = 2'b11` (reserved) with REAL traffic flowing | `STATUS.mode_reserved_seen` sticky-set; arbiter behaves as REAL |

### DT-B: rate sweep + watchdog + counter assertions (BASIC-DT-017..BASIC-DT-064, 48 cases)

| ID | Stimulus shape |
|---|---|
| BASIC-DT-017..BASIC-DT-046 | The 30-cell `(rate × source × channel-set)` matrix: rate ∈ {10k, 100k, 500k, 1M, 2M Hz/ch} × source ∈ {REAL, EMU, MIX_RR} × channel-set ∈ {single-channel, full 32-channel scan}. 100 µs sim time per cell. |
| BASIC-DT-047..BASIC-DT-052 | 1 MHz sustained × cluster-size {1, 4, 8, 16, 32} × duty-cycle 50% (5 cells) plus 1 MHz × cluster 8 × duty-cycle 100% (1 cell) |
| BASIC-DT-053..BASIC-DT-058 | 1 MHz × cluster-size 4 × duty-cycle {30%, 70%} (2 cells) and 1 MHz × cluster-size 16 × duty-cycle {30%, 70%} (2 cells); 1 MHz "1 hit per frame" deterministic (1 cell); 0 Hz over a 1 ms run baseline (1 cell, asserts counter quiescence) |
| BASIC-DT-059 | **DT-WATCHDOG-001** `WATCHDOG_CYCLES = 0` (FAW disabled) over a clean MIX_RR run; assert `STATUS.watchdog_synthesized_*` stays 0 |
| BASIC-DT-060 | **DT-WATCHDOG-002** FAW = 500, real source EORs, emu silent for ≥ 500 cycles → FAW synthesizes EOP+EOR on emu; assert `STATUS.watchdog_synthesized_emu = 1`, `merged_locked = 1`, `EGRESS_EMU_HITS` unchanged |
| BASIC-DT-061 | **DT-FRAME-CTR-001** Clean MIX_RR run; assert `INGRESS_REAL_FRAMES = EGRESS_REAL_FRAMES` and `INGRESS_EMU_FRAMES = EGRESS_EMU_FRAMES` end-of-run via CSR pair-atomic reads |
| BASIC-DT-062 | **DT-FSM-ROW-001** Single-beat packet (sop=eop=1) from real while emu mid-packet; absorbed as middle beat in merged packet (egress sop=0, eop=0); INGRESS_REAL_HITS / INGRESS_REAL_FRAMES both +1 |
| BASIC-DT-063 | **DT-FSM-ROW-002** Real EOR on egress beat N, emu EOR on egress beat N+1 (adjacent); merged EOP+EOR fires once on beat N+1; `merged_locked = 1` after |
| BASIC-DT-064 | **DT-CHAN-CONV-001** REAL-only run with channel ∈ [8..15] (violates upstream convention); arbiter passes through unchanged; scoreboard logs the convention-violation observation but does NOT fail the test |

### DT-C: multiplicity + spatial + ergress / FSM corners (BASIC-DT-065..BASIC-DT-096, 32 cases)

| ID | Cluster size | Source | Spatial pattern |
|---|---:|---|---|
| BASIC-DT-065..BASIC-DT-067 | 2 | REAL / EMU / MIX_RR | random in space |
| BASIC-DT-068..BASIC-DT-070 | 4 | REAL / EMU / MIX_RR | random |
| BASIC-DT-071..BASIC-DT-073 | 8 | REAL / EMU / MIX_RR | random |
| BASIC-DT-074..BASIC-DT-076 | 16 | REAL / EMU / MIX_RR | random |
| BASIC-DT-077..BASIC-DT-079 | 32 | REAL / EMU / MIX_RR | random |
| BASIC-DT-080..BASIC-DT-083 | 4 | REAL / EMU / MIX_RR / MIX_RR-cross-source | clustered (contiguous channels 0..3 / 8..11) |
| BASIC-DT-084..BASIC-DT-086 | 8 | REAL / EMU / MIX_RR | clustered (channels 0..7 / 8..15) |
| BASIC-DT-087..BASIC-DT-088 | 16 | REAL / MIX_RR | stride-2 |
| BASIC-DT-089 | 8 | REAL | stride-4 |
| BASIC-DT-090 | 8 | EMU | stride-8 |
| BASIC-DT-091 | **DT-SPATIAL-001** Single-channel hot spot: channel 4 firing every cycle for 100 µs, all other channels silent | hot-spot per-channel propagation |
| BASIC-DT-092 | **DT-ERR-SIDEBAND-001** Real beat with `asi_real_error[2:0] = 3'b001` (loss_sync); arbiter passes `error` through to `aso_error` unchanged | error-sideband passthrough |
| BASIC-DT-093 | **DT-RC-DT-CROSS-001** Two back-to-back canonical runs (`RUN_NUMBER` = N then N+1) with DT hits in both; assert `RUN_PREP` flushed FIFO state but counters preserved per RTL_PLAN §2.6 | run-control × DT cross |
| BASIC-DT-094 | **DT-RC-DT-CROSS-002** Three back-to-back canonical runs with `RESET` between runs 2 and 3; assert `ERROR_COUNT_*` and `SYNDROME_*` cleared by `RESET` (not by `RUN_PREP`) | RESET vs RUN_PREP scope |
| BASIC-DT-095 | MIX_RR with sources at very different rates: real 1 MHz / emu 10 kHz | arbiter starvation / fairness |
| BASIC-DT-096 | MIX_RR with one source idle (real fires, emu silent for whole run) | arbiter degenerates to passthrough; FSM state still ticks |

### DT-D: temporal placement around state change (BASIC-DT-097..BASIC-DT-112, 16 cases)

| ID | Stimulus |
|---|---|
| BASIC-DT-097 | No hits at all during `RUNNING` (gate closed) |
| BASIC-DT-098 | First hit at the exact cycle `RUN_PREP → SYNC` transitions |
| BASIC-DT-099 | First hit at the exact cycle `SYNC → RUNNING` transitions |
| BASIC-DT-100 | Last hit at the exact cycle `RUNNING → TERMINATING` transitions |
| BASIC-DT-101 | Last hit at the exact cycle `TERMINATING → IDLE` transitions |
| BASIC-DT-102 | Hit at every cycle of `RUNNING` (saturation) |
| BASIC-DT-103 | Hit-at-cycle-0 of `RUNNING` only; rest silent |
| BASIC-DT-104 | Hit-at-cycle-N of `RUNNING` only; rest silent |
| BASIC-DT-105 | Hits gated before `RUNNING` (must be discarded by virtual MuTRiG) |
| BASIC-DT-106 | Hits draining after `TERMINATING` (must complete the in-flight frame and propagate `endofrun`) |
| BASIC-DT-107..BASIC-DT-112 | Mid-run gate / un-gate sequences with random timing |

### DT-E: Poisson distribution + cross-check (BASIC-DT-113..BASIC-DT-128, 16 cases)

| ID | Rate | Mean cluster size | Spatial spread |
|---|---|---:|---|
| BASIC-DT-113 | 10 kHz / channel | 4 | random |
| BASIC-DT-114 | 100 kHz / channel | 4 | random |
| BASIC-DT-115 | 500 kHz / channel | 4 | random |
| BASIC-DT-116 | 1 MHz / channel | 4 | random |
| BASIC-DT-117 | 100 kHz / channel | 8 | random |
| BASIC-DT-118 | 500 kHz / channel | 8 | random |
| BASIC-DT-119 | 1 MHz / channel | 8 | random |
| BASIC-DT-120 | 100 kHz / channel | 16 | random |
| BASIC-DT-121 | 500 kHz / channel | 16 | random |
| BASIC-DT-122 | 1 MHz / channel | 16 | random |
| BASIC-DT-123 | 500 kHz / channel | 32 | random |
| BASIC-DT-124 | 1 MHz / channel | 32 | random |
| BASIC-DT-125 | 100 kHz / channel | 4 | random + mixed temporal phase (sweep starts at frame offset {0, 400, 800, 1200} per repeat) |
| BASIC-DT-126 | 1 MHz / channel | 8 | random + mixed temporal phase |
| BASIC-DT-127 | TDC-injection deterministic header-synchronous (single channel, fixed cluster=1, exact frame phase) | 1 | single-channel | anchors histogram cross-check to a narrow delay peak |
| BASIC-DT-128 | TDC-injection deterministic with cluster=8 contiguous channels | 8 | clustered | anchors multi-channel histogram cross-check |

Histogram cross-check tolerance: each case asserts the scoreboard's per-bin reconstructed delay-bin counts match `histogram_statistics_0`'s observed bin counts within **0.1 %** of total hits, computed only over bins inside the rbCAM ingress window `[0, 2000]` cycles. Bins outside that window are reported but not gated.

---

## Plan drift notes

(none yet)
