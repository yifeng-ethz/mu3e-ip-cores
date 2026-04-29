# TEST_EDGE.md — Phase-5 EDGE bucket (run-state and boundary corner cases)

**Companion**: [`TEST_PLAN_PHASE5.md`](TEST_PLAN_PHASE5.md) §1.6, §3
**Sibling buckets**: [`TEST_BASIC.md`](TEST_BASIC.md) · [`TEST_PROF.md`](TEST_PROF.md) · [`TEST_ERROR.md`](TEST_ERROR.md)
**Catalog ID range**: `TPB5EDG001` … `TPB5EDG144` (entry catalog; long-term target 500–3000 cases)
**Intent**: prove the chain stays correct at **boundaries** — first hit after RUNNING, last hit before TERMINATING idle-guard close, frame-counter rollover, GTS rollover, MTS subheader-timestamp wrap, abort/reset during run, and run-state transitions. Each row exercises one specific corner condition and verifies the per-IP propagation evidence still holds.

## How to read this catalog

Same row schema as `TEST_BASIC.md` and `TEST_PROF.md`. EDGE bucket emphasises:

- **state-arm** triggers (`run_state_cmd → X`) for run-state-transition cases,
- **GTS-arm** triggers at near-rollover values for counter-wrap cases,
- explicit checks of the `TERMINATING_IDLE_GUARD_CONST = 2048` cycles documented at `mutrig_frame_deassembly/rtl/frame_rcv_ip.vhd:134` and the `terminating_marker_*` propagation at `feb_frame_assembly.vhd:518..525`,
- explicit checks of `endofrun` on the per-deassembly aso_hit_type0 bus.

Run states (per `frame_rcv_ip.vhd:240, mts_processor.vhd:345, ring_buffer_cam.vhd:340..345, feb_frame_assembly.vhd:551`):
`IDLE, RUN_PREPARE, SYNC, RUNNING, TERMINATING, LINK_TEST, SYNC_TEST, RESET, OUT_OF_DAQ, ERROR`.

EDGE cases generally use **2048 × 4** at the IP whose run-state transition is being captured, and **1024 × 4** elsewhere.

## Execution scoreboard

Status vocabulary is defined in `TEST_PLAN_PHASE5.md` §1.7. This table is the first-level record of what has actually run; keep it updated after every SignalTap or board run. Ranged rows are not marked `PASS` unless every case in the range passed.

| Group | Cases | Status | PASS | FAIL | BLOCKED | Last evidence | Notes |
|---|---:|---|---:|---:|---:|---|---|
| E1 | 32 | not-run | 0 | 0 | 0 | none | first hit after RUNNING |
| E2 | 32 | not-run | 0 | 0 | 0 | none | last hit before TERMINATING |
| E3 | 16 | not-run | 0 | 0 | 0 | none | stale-hit flush |
| E4 | 16 | not-run | 0 | 0 | 0 | none | in-flight hits at end run |
| E5 | 8 | not-run | 0 | 0 | 0 | none | frame-counter rollover |
| E6 | 8 | not-run | 0 | 0 | 0 | none | GTS and MTS timestamp wrap |
| E7 | 8 | not-run | 0 | 0 | 0 | none | abort/reset during run |
| E8 | 8 | not-run | 0 | 0 | 0 | none | run-control fan-out edges |
| E9 | 16 | not-run | 0 | 0 | 0 | none | trigger-boundary and segmented-capture variants |

## Wiring and prerequisites

Same as TEST_BASIC.md. Additionally:

- The full RUN sequence is exercised for every EDGE case: `IDLE → RUN_PREPARE → SYNC → RUNNING → TERMINATING → IDLE`.
- For abort/reset cases, `rc_tool` issues the abort while `RUNNING`, after the captured stimulus has been emitted.
- For GTS-rollover cases, the run window length is set by stimulus to bring `gts_8n_counter` close to a chosen wrap point (low-bit slice for the SignalTap captures).

## Catalog

### Group E1 — first hit after RUNNING (`RUN_START` first hit), 32 cases

Stimulus: each case enters RUNNING with the chosen (ASIC, channel) about to emit its first hit. The first emitted hit is positioned at one of {1, 2, 3, 4} hit slots into the first frame after RUN_START. 8 ASICs × 4 first-hit positions = 32 cases. Verifies that the run_control_splitter `out0..out6` fan-out releases all consumers before the first valid hit is admitted.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG001..004 | EMU lane 0, ch 0, first hit at slot {1, 2, 3, 4} | state-arm `run_state_cmd → RUNNING` | T1 (2048×4), T6, T7, T8, TS | T1 captures the very first `aso_hit_type0_valid` post-RUNNING; `aso_hit_type0_startofpacket` aligns with the first frame's K28.0; `aso_hit_type0_data` carries the configured slot's hit; downstream taps preserve the same hit; SWB-CHK delta = 1 on the matching frame | pending |
| TPB5EDG005..008 | EMU lane 1, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 1 | pending |
| TPB5EDG009..012 | EMU lane 2, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 2 | pending |
| TPB5EDG013..016 | EMU lane 3, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 3 | pending |
| TPB5EDG017..020 | EMU lane 4, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 4; crossing into hit_stack_subsystem_1 | pending |
| TPB5EDG021..024 | EMU lane 5, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 5 | pending |
| TPB5EDG025..028 | EMU lane 6, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 6 | pending |
| TPB5EDG029..032 | EMU lane 7, ch 0, first hit at slot {1, 2, 3, 4} | same | same | ASIC ID = 7; lane-7 crosses the 4-MuTRiG-datapath partition boundary at the first frame | pending |

### Group E2 — last hit before TERMINATING (`RUN_END` last hit), 32 cases

Stimulus: each case has the chosen (ASIC, channel) emit its last hit just before `rc_tool` issues CMD_END_RUN. The last hit is positioned at one of {1, 2, 3, 4} hit slots from the end of the last frame. 8 ASICs × 4 last-hit positions = 32 cases. Verifies that `endofrun` on `aso_hit_type0_endofrun` (deassembly), the `terminating_marker_*` chain in `feb_frame_assembly`, and the post-end flush all preserve the hit.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG033..036 | EMU lane 0, ch 0, last hit at slot {-1, -2, -3, -4} from frame end | state-arm `run_state_cmd → TERMINATING` | T1 (2048×4), T7 (4096×4), T8, TS | T1 `aso_hit_type0_endofrun` asserts on the last frame; `aso_hit_type0_endofpacket` co-asserts; T7 `terminating_marker_valid` propagates through all 4 lanes of the active partition before TERMINATING completes; `frame_cnt` increments on the last frame and freezes; SWB-CHK delta includes the last hit | pending |
| TPB5EDG037..040 | EMU lane 1, same last-hit grid | same | same | ASIC ID = 1 | pending |
| TPB5EDG041..044 | EMU lane 2, same last-hit grid | same | same | ASIC ID = 2 | pending |
| TPB5EDG045..048 | EMU lane 3, same last-hit grid | same | same | ASIC ID = 3 | pending |
| TPB5EDG049..052 | EMU lane 4, same last-hit grid | same | same | ASIC ID = 4 | pending |
| TPB5EDG053..056 | EMU lane 5, same last-hit grid | same | same | ASIC ID = 5 | pending |
| TPB5EDG057..060 | EMU lane 6, same last-hit grid | same | same | ASIC ID = 6 | pending |
| TPB5EDG061..064 | EMU lane 7, same last-hit grid | same | same | ASIC ID = 7 | pending |

### Group E3 — RUN_PREPARE → SYNC → RUNNING flush sequence, 16 cases

Stimulus: 16 different "in-flight hits at SYNC" preconditions. The lane is configured to emit hits **before** RUN_PREPARE (which is illegal but the deassembler ignores them per IDLE-state policy). The case verifies that:

- the RUN_PREPARE → SYNC → RUNNING transition flushes any stale state in `mutrig_frame_deassembly` (per the `RESET` reset_flow at `mts_processor.vhd:610..611`),
- the first post-RUNNING hit is correctly admitted,
- no stale hit from before RUNNING leaks into the captured AVST stream.

| case_id | stale-hit count | first-real-hit slot | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|---|
| TPB5EDG065..072 | stale ∈ {0, 1, 2, 3, 4, 8, 16, 32} hits before RUN_PREPARE | slot 1 of the first RUNNING frame | state-arm at the `RUNNING` entry edge | T1 (2048×4), T4 (mts_processor), T7 (4096×4), TS | no stale hit appears at T1, T4, T7, TS; the first captured hit at T1 is the first real-hit slot; `mts_processor.processor_state` transitions through `RESET` then `IDLE` then `RUNNING` between RUN_PREPARE and RUNNING | pending |
| TPB5EDG073..080 | stale ∈ {0, 1, 2, 3, 4, 8, 16, 32} hits before RUN_PREPARE | slot 4 of the first RUNNING frame | state-arm | same | same flush expectation; the first real hit is at slot 4 (other 3 slots show K28.5 idle in the captured byte stream) | pending |

### Group E4 — RUNNING → TERMINATING with various in-flight hits, 16 cases

Stimulus: various counts of in-flight hits in the chain at the moment CMD_END_RUN is issued. Verifies that `feb_frame_assembly` correctly drains all in-flight hits before `terminating_done` is asserted, and that `aso_hit_type3` carries the final beat with `eop = '1'`. Also verifies the `TERMINATING_IDLE_GUARD_CONST = 2048` cycle guard at `frame_rcv_ip.vhd:134` is honoured: if the upstream byte stream stays quiet for 2048 cycles, `terminating_empty_frame_done` fires.

| case_id | in-flight count | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG081..088 | in-flight ∈ {0, 1, 2, 4, 8, 16, 32, 64} hits at CMD_END_RUN | state-arm `run_state_cmd → TERMINATING` | T1 (2048×4), T6, T7 (4096×4), T8 | every in-flight hit is observed at T7 before `terminating_done`; `aso_hit_type3_endofpacket` asserts on the final beat; `frame_cnt` increments to count the in-flight frames; `terminating_idle_guard_cnt` reaches 2048 on the empty-frame fallback cases | pending |
| TPB5EDG089..096 | in-flight = 64 hits with TERMINATING applied at varying offsets {0, 50, 100, 200, 400, 700, 909, 1500} cycles into the final frame | state-arm | same | the partial-frame is correctly closed; `terminating_marker_sop` and `terminating_marker_lane[ROUTE_LANE_BITS_CONST-1:0]` propagate; no ghost hits appear after `terminating_done` | pending |

### Group E5 — frame-counter rollover at deassembler, 8 cases

Stimulus: each case runs long enough to roll the deassembler's `csr.frame_counter_head` (32-bit) over a chosen low-bit boundary (8-bit, 12-bit, 16-bit, 20-bit). The lane-counter sweep is run on lanes 0, 2, 5, 7. 4 wrap-points × 2 lanes = 8 cases.

| case_id | wrap-point | lane | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|---|
| TPB5EDG097 | 8-bit boundary (frame_counter_head 0xFF→0x100) | lane 0 | GTS-arm at `gts_8n_lo == TARGET` matching the wrap | T1 (2048×4), T7 | T1 capture spans the wrap; `frame_counter_head` increments monotonically through the wrap; T7 `frame_cnt` also wraps without a dropped frame | pending |
| TPB5EDG098 | 12-bit boundary | lane 0 | same | same | wrap clean | pending |
| TPB5EDG099 | 16-bit boundary | lane 0 | same | same | wrap clean | pending |
| TPB5EDG100 | 20-bit boundary | lane 0 | same | same | wrap clean | pending |
| TPB5EDG101 | 8-bit boundary | lane 7 | same | same | wrap clean | pending |
| TPB5EDG102 | 12-bit boundary | lane 7 | same | same | wrap clean | pending |
| TPB5EDG103 | 16-bit boundary | lane 7 | same | same | wrap clean | pending |
| TPB5EDG104 | 20-bit boundary | lane 7 | same | same | wrap clean | pending |

### Group E6 — GTS counter rollover and MTS subheader-timestamp wrap, 8 cases

Stimulus: per `mts_processor.vhd:586..587, 547..549`, `d_gts_counter` is 48-bit (8 ns step) and `delta_timestamp` is 12-bit. The 48-bit counter rolls over on the order of years; this bucket targets the **observable low-bit slices** instead — slices that are exposed to SignalTap and to the MTS subheader timestamp:

- 8-bit slice → wraps every 256 × 8 ns = ~2 µs.
- 12-bit slice → ~33 µs.
- 16-bit slice → ~524 µs.
- the MTS subheader timestamp `SUBHEADER_TIMESTAMP_WIDTH = 8` (per `mts_processor.vhd:290..291`) is the most-tested boundary: the subheader timestamp wraps on every short-frame interval, and the wrap_id+1 logic must roll cleanly.

| case_id | wrap-bit | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG105 | 8-bit GTS slice wrap | GTS-arm at the 8-bit wrap edge | T4 (2048×4), T6, T7 | `delta_timestamp` increments correctly across the wrap; no `tsglitcherr` asserted | pending |
| TPB5EDG106 | 12-bit GTS slice wrap | same | same | same | pending |
| TPB5EDG107 | 16-bit GTS slice wrap | same | same | same | pending |
| TPB5EDG108 | MTS subheader wrap, hit positioned at slot 0 | GTS-arm | T4 (2048×4) | the captured `delta_timestamp` reflects wrap_id+1 mapping; no out-of-order; the `mts_processor.processor_state` does not assert `error` | pending |
| TPB5EDG109 | MTS subheader wrap, hit positioned at slot 5 | same | same | same | pending |
| TPB5EDG110 | MTS subheader wrap, hit positioned at slot 7 (most stressful) | same | same | same | pending |
| TPB5EDG111 | two consecutive subheader wraps within one capture window | same | same | both wraps are captured; both produce monotone `delta_timestamp` outputs | pending |
| TPB5EDG112 | a hit lands exactly at the wrap edge (cycle 909 of the short frame) | same | same | hit is correctly attributed to the post-wrap frame | pending |

### Group E7 — abort / reset during RUN, 8 cases

Stimulus: while RUNNING with steady traffic, issue CMD_ABORT_RUN, CMD_RESET, or CMD_OUT_OF_DAQ via `rc_tool`. Verifies the chain enters RESET / TERMINATING / OUT_OF_DAQ as documented and the captured AVST shows the run-state propagation.

| case_id | abort opcode | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG113 | CMD_ABORT_RUN at t = 50 ms into RUN | state-arm `run_state_cmd → ERROR` (or `RESET` per opcode mapping) | T1 (2048×4), T4, T6, T7 | every IP captures the run_state transition; in-flight hits flushed correctly; no ghost hits after | pending |
| TPB5EDG114 | CMD_RESET at t = 50 ms into RUN | state-arm | same | reset propagates; ring-CAM partition fill goes to 0; `frame_cnt` resets | pending |
| TPB5EDG115 | CMD_OUT_OF_DAQ at t = 50 ms | state-arm | same | OUT_OF_DAQ state captured; downstream IPs honour the state | pending |
| TPB5EDG116 | CMD_ABORT_RUN at t = 1 µs (first frame still in flight) | state-arm | same | very early abort cleanly handled | pending |
| TPB5EDG117 | CMD_RESET at t = end-of-run-1ms (close to TERMINATING) | state-arm | same | reset wins over the natural TERMINATING; chain enters RESET cleanly | pending |
| TPB5EDG118 | CMD_OUT_OF_DAQ during high-rate RUN (rate_word=0x4000) | state-arm | T6 (2048×4), T7 (4096×4) | OUT_OF_DAQ captured under load; in-flight hits flushed correctly | pending |
| TPB5EDG119 | RESET while ring-CAM is at 75% fill | state-arm | T6 (2048×4) | partition fill drops to 0 at the RESET edge; no spurious overflow counter advance | pending |
| TPB5EDG120 | back-to-back RUN-ABORT-RUN sequence (3 RUN windows) | state-arm | T1, T7 | each RUN window opens cleanly; each ABORT cleanly drains; no state leaks across the three windows | pending |

### Group E8 — run_control fan-out edge cases, 8 cases

Stimulus: corner cases of `run_control_splitter` and the per-IP `asi_ctrl_*_ready` handshake — particularly relevant to the v3-pipe build's `USE_READY=0` choice on the top splitter (per `scifi_datapath_system_v3.qsys` line 285 era note).

| case_id | scenario | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG121 | one consumer's `asi_ctrl_ready` latches low for 64 cycles during RUN_PREPARE | state-arm | T1, T4, T6, T7 | the broadcast still propagates `RUN_PREPARE` to every other consumer; the held consumer enters RUN_PREPARE on its own as soon as ready latches high | pending |
| TPB5EDG122 | back-to-back state transitions IDLE→RUN_PREPARE→IDLE | state-arm | T1, T7 | both transitions cleanly captured; no consumer ends up in an inconsistent state | pending |
| TPB5EDG123 | LINK_TEST entered and exited cleanly | state-arm `run_state_cmd → LINK_TEST` | T1, T4, T6, T7 | every IP enters LINK_TEST; no hits processed during LINK_TEST; clean exit | pending |
| TPB5EDG124 | SYNC_TEST entered and exited | state-arm | same | same handling for SYNC_TEST | pending |
| TPB5EDG125 | run_control_splitter sees one consumer drop out of RUN sequence (e.g. `mts_processor` enters its own ERROR state) | state-arm | T1, T4 | the splitter still distributes the host's run-state command; the failing consumer is observable on its own state output; the other consumers continue | pending |
| TPB5EDG126 | RUN_PREPARE sent twice in a row without intervening IDLE | state-arm | T1, T7 | second RUN_PREPARE is benign (idempotent at the `mts_processor` reset_flow=SCLR) | pending |
| TPB5EDG127 | SYNC sent without prior RUN_PREPARE | state-arm | T1, T4, T7 | the chain rejects the out-of-order SYNC and stays in IDLE; no ghost activity | pending |
| TPB5EDG128 | END_RUN sent during IDLE | state-arm | T1, T7 | benign; no state change | pending |

### Group E9 — trigger-boundary and segmented-capture variants, 16 cases

Stimulus: place the event under test exactly on or one cycle away from the trigger condition used by the SignalTap row. These cases guard against off-by-one trigger placement and segmented-buffer evidence loss, especially where a single global trigger expression is reused for all four segments.

| case_id | scenario | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5EDG129..136 | first valid hit occurs at `TARGET_GTS + delta`, with `delta ∈ {-1, 0, +1, +2}` on lane 3 and lane 4 | GTS-arm and state-arm pair, repeated in separate acquisitions | T1 (2048×4), T4, T6(M=0/1), T7(M=0/1), TS | the hit is present in the correct segment for every delta; lane 3 stays in M=0 and lane 4 stays in M=1; no false empty segment is accepted as evidence | pending |
| TPB5EDG137..144 | CMD_END_RUN is issued at `K28.4 + delta`, with `delta ∈ {-1, 0, +1, +2}` on lane 0 and lane 7 | K-symbol arm at T1 plus state-arm at T7 | T1 (4096×4), T6, T7 (4096×4), T8 | the last packet is either fully accepted before TERMINATING or cleanly closed after TERMINATING; `terminating_marker_*` and `endofrun` agree; no duplicate final hit at SWB | pending |

## Closure aggregator

EDGE bucket PASSES when:

- Every TPB5EDG### row's run-state transition propagates as documented; `endofrun` and `terminating_marker_*` are observable per case.
- First-hit-after-RUNNING and last-hit-before-TERMINATING cases pass the `MATCH:` per-IP boundary test.
- Counter-rollover cases produce monotone deltas through the wrap.
- For long-term closure, every row's `MATCH:` resolves to a passing `tb_int/` integration-sim case.

EDGE bucket FAILS if any first-hit is dropped, any last-hit is dropped, the `terminating_idle_guard_cnt` exceeds 2048 cycles without firing the empty-frame fallback, or a counter wraps incorrectly. Failures route per the §6 first-pass debug ladder.
