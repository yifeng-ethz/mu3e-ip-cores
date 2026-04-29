# TEST_ERROR.md — Phase-5 ERROR bucket (negative-path / error-injection)

**Companion**: [`TEST_PLAN_PHASE5.md`](TEST_PLAN_PHASE5.md) §1.6, §3
**Sibling buckets**: [`TEST_BASIC.md`](TEST_BASIC.md) · [`TEST_PROF.md`](TEST_PROF.md) · [`TEST_EDGE.md`](TEST_EDGE.md)
**Catalog ID range**: `TPB5ERR001` … `TPB5ERR144` (entry catalog; long-term target 500–3000 cases)
**Intent**: prove that **errors are observable and contained**. Each row injects one specific defect or fault and verifies (a) the negative-path trigger fires, (b) the per-IP `*_error` flag, decoder counter, or overflow counter advances exactly as documented, and (c) the chain recovers cleanly without corrupting downstream lanes.

## How to read this catalog

Same row schema as the other bucket files. ERROR cases differ from BASIC/PROF/EDGE in two ways:

- The trigger is the **error condition itself** — the negative trigger from Phase-4 §4.3 (`SOP_NO_EOP`, `CRC_ERR`, `RR_VIOL`, `SC_TORN`, `INJ_ARM`, `UNDR_INC`, `OVRFL_INC`, `DROP_INC`) plus per-IP `*_error` flag triggers. The trigger **must** fire; if it does not, the case fails (the error did not get injected as expected).
- The bucket has both **positive observability** rows (the error fires and is correctly observed) and **negative containment** rows (an injected error on lane k must not corrupt the captured AVST stream on the other lanes).

ERROR cases use **2048 × 4** at the IP whose error path is being tested, **1024 × 4** elsewhere.

## Execution scoreboard

Status vocabulary is defined in `TEST_PLAN_PHASE5.md` §1.7. This table is the first-level record of what has actually run; keep it updated after every SignalTap or board run. Ranged rows are not marked `PASS` unless every case in the range passed.

| Group | Cases | Status | PASS | FAIL | BLOCKED | Last evidence | Notes |
|---|---:|---|---:|---:|---:|---|---|
| X1 | 32 | not-run | 0 | 0 | 0 | none | 8b/10b code/disp error |
| X2 | 16 | not-run | 0 | 0 | 0 | none | torn frame |
| X3 | 16 | not-run | 0 | 0 | 0 | none | extended frame timeout |
| X4 | 16 | not-run | 0 | 0 | 0 | none | bad CRC |
| X5 | 16 | not-run | 0 | 0 | 0 | none | MTS timestamp glitch |
| X6 | 8 | not-run | 0 | 0 | 0 | none | backpressure FIFO overflow attempt |
| X7 | 8 | not-run | 0 | 0 | 0 | none | ring-CAM search miss/overflow |
| X8 | 8 | not-run | 0 | 0 | 0 | none | ring-CAM 100% fill |
| X9 | 8 | not-run | 0 | 0 | 0 | none | TERMINATING idle-guard violation |
| X10 | 16 | not-run | 0 | 0 | 0 | none | cross-subsystem error containment |

## Wiring and prerequisites

Same as TEST_BASIC.md. Additionally:

- `histogram_statistics_0.OVERFLOW_COUNT`, `DROPPED_HITS`, `UNDERFLOW_COUNT` snapshotted before/after; ERROR cases tolerate the documented advances per case but **never** an unexpected advance on a non-related counter.
- Bit-flip / disp-err / code-err injection is via the `lvds_error_counter_fabric` IP if instrumentation is exposed; otherwise, the case is tagged `injection-tooling-pending` and the listed evidence is what would be captured once the injection path is live.

## Catalog

### Group X1 — 8b/10b code-err / disp-err at deassembler ingress, 32 cases

Stimulus: a single byte of the 8b/10b stream into `mutrig_frame_deassembly_N` is corrupted so the SWB-side or FEB-side decoder reports `code_err` or `disp_err`. 8 lanes × 4 byte positions per frame (within K28.0 SOP, mid-payload, last-payload, K28.4 EOP) = 32 cases. The relevant Phase-4 trigger is `SC_TORN` (memory `sc_hub_word_addressed`) for SC-ring path and the Phase-3 ingress LVDS error-counter for the run-control side; here the equivalent for the data-path 8b/10b is the `lvds_error_counter_fabric` per-link counters and the per-IP `aso_hit_type0_error[2:0]` decoder error flag at the deassembler output (per `frame_rcv_ip.vhd:90`).

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR001..004 | inject code-err / disp-err at SOP byte / mid-payload / last-payload / EOP byte of a frame on lane 0 | T1 trigger on `aso_hit_type0_error[2:0] != 3'b000` | T0 (2048×4), T1 (2048×4), T7 (4096×4) | T1 captures the error flag asserted on the corrupted frame; the corrupted frame is dropped (no `aso_hit_type0_endofpacket`), the next K28.0 starts cleanly; no error propagates to T7 / T8 (frame discarded upstream) | pending |
| TPB5ERR005..008 | same on lane 1 | same | same | error flag asserts on lane 1; lane 0 captures unaffected | pending |
| TPB5ERR009..012 | same on lane 2 | same | same | error flag asserts on lane 2 | pending |
| TPB5ERR013..016 | same on lane 3 | same | same | error flag asserts on lane 3 | pending |
| TPB5ERR017..020 | same on lane 4 (hit_stack_subsystem_1 path) | same | same | error flag asserts on lane 4; hit_stack_subsystem_0 traffic unaffected | pending |
| TPB5ERR021..024 | same on lane 5 | same | same | error flag asserts on lane 5 | pending |
| TPB5ERR025..028 | same on lane 6 | same | same | error flag asserts on lane 6 | pending |
| TPB5ERR029..032 | same on lane 7 | same | same | error flag asserts on lane 7 | pending |

### Group X2 — torn frame (K28.0 inside in-progress packet), 16 cases

Stimulus: emulator forced to emit a K28.0 SOP inside an open packet (no preceding K28.4 EOP). This is the Phase-4 §4.3 `SOP_NO_EOP` negative trigger. 8 lanes × 2 timing positions of the spurious SOP within the open packet = 16 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR033..040 | spurious K28.0 at mid-payload of an open frame on lane k (k=0..7) | T0 trigger on `aso_tx8b1k_data == 9'h11C && in_frame_q` | T0 (2048×4), T1 (2048×4), T7 (4096×4) | T0 captures the spurious K28.0 inside `in_frame_q`; T1 deassembler discards the open frame and starts a new one; no torn-frame data leaks past T1; SWB-CHK delta drops by exactly the discarded frame's hit count | pending |
| TPB5ERR041..048 | spurious K28.0 right before the legitimate K28.4 (last cycle) on lane k | same | same | same evidence; the legitimate EOP is consumed normally on the new frame | pending |

### Group X3 — extended frame (no K28.4 within timeout), 16 cases

Stimulus: emulator emits a frame longer than `FRAME_INTERVAL_LONG = 1550` cycles by withholding the trailing K28.4. The deassembler must time out (per `frame_rcv_ip.vhd` `TERMINATING_IDLE_GUARD_CONST` policy applied to runtime ingress) and report a frame error. 8 lanes × 2 timeout durations (`{1550 + 100, 2 × FRAME_INTERVAL_LONG}` cycles) = 16 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR049..056 | lane k, frame extended by +100 cycles (just past `FRAME_INTERVAL_LONG`) | T1 trigger on `aso_hit_type0_error[2:0] != 3'b000` | T0 (2048×4), T1 (2048×4) | T1 error flag asserts on the timeout; deassembler discards the partial frame and starts on the next K28.0 cleanly | pending |
| TPB5ERR057..064 | lane k, frame extended by 2× the long interval | same | same | same evidence; no spurious downstream traffic during the timeout window | pending |

### Group X4 — bad CRC frame (`crc16_calc.vhd` mismatch), 16 cases

Stimulus: emulator emits a frame whose payload CRC byte is corrupted. The deassembler's `crc16_calc` (per `mutrig_frame_deassembly/crc16_calc.vhd`) detects the mismatch and asserts the CRC error flag on `aso_hit_type0_error`. 8 lanes × 2 corruption patterns (one bit flip vs full corruption) = 16 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR065..072 | lane k, single-bit flip in CRC byte | T1 trigger on `aso_hit_type0_error[2:0] != 3'b000` (CRC error sub-flag) | T0 (2048×4), T1 (2048×4) | T1 error flag asserts; frame is discarded; deassembler increments its internal CRC error counter (CSR shadow) | pending |
| TPB5ERR073..080 | lane k, full corruption of CRC byte | same | same | same evidence | pending |

### Group X5 — `tsglitcherr` on `mts_processor`, 16 cases

Stimulus: emulator inserts a hit whose intra-frame timestamp goes backward relative to the previous hit on the same channel. `mts_processor` detects the glitch and asserts `aso_hit_type1_error` (`tsglitcherr` per the comment at `ring_buffer_cam.vhd:60`). 8 lanes × 2 timestamp glitch deltas (1-cycle and full-frame) = 16 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR081..088 | lane k, hit with TS - 1 of previous hit | T4 trigger on `aso_hit_type1_error == 1'b1` | T1 (2048×4), T4 (2048×4) | T4 error flag asserts on the glitched hit; the glitched hit is still emitted (does not silently drop) but is tagged; downstream ring-CAM may or may not include it depending on CSR debug-mode (per `frame_rcv_ip.vhd:39` "debug mode to bypass/ignore errors/exceptions") | pending |
| TPB5ERR089..096 | lane k, hit with TS - FRAME_INTERVAL_SHORT (full frame backwards) | same | same | same evidence; full-frame backward TS is the worst case | pending |

### Group X6 — backpressure_fifo overflow attempt, 8 cases

Stimulus: emulator lane k saturated at `rate_word = 0x8000` while the consumer is held in SYNC for >> 128 cycles. The 128-entry `backpressure_fifo` should saturate and apply back-pressure to the upstream emulator; **no hit must be silently dropped** at the deassembler boundary. 8 lanes = 8 cases. Phase-4 `DROP_INC` trigger applies here.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR097..104 | lane k saturated, consumer in SYNC stall | T2 trigger on `filllevel == 7'd128` (full) | T0 (2048×4), T1, T2 (4096×4) | T2 captures `filllevel` reaching 128; T0 emulator `aso_tx8b1k_valid` deasserts on cycles where the upstream is back-pressured; no payload loss when the consumer resumes; `DROP_INC` on histogram does not fire | pending |

### Group X7 — ring-CAM search miss / overflow, 8 cases

Stimulus: emulator emits hits with timestamps older than the current `search_min_timestamp` of `ring_buffer_cam_K`. Per `ring_buffer_cam.vhd:22` the IP can flag input-FIFO overflow if the cache time-interleaving factor is too small; per the design, the hit either drops or routes to overflow. 4 partitions × 2 stimulus profiles (single late hit vs sustained late hits) = 8 cases.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR105..108 | partition K (K=0..3), single late hit | T6 trigger on partition-K overflow flag (or `aso_filllevel_data` saturation) | T6 partition K (4096×4) | the late hit is logged as an overflow; partition-K fill spike captured; other partitions unaffected | pending |
| TPB5ERR109..112 | partition K (K=0..3), sustained late hits at saturation | same | same | partition-K overflow counter advances; the chain recovers when the late hit stream stops; no cross-partition leak | pending |

### Group X8 — ring-CAM 100% fill, 8 cases

Stimulus: deliberately fill ring_buffer_cam partition K to 512/512 entries before the consumer drains. 4 partitions × 2 fill profiles (single saturating burst vs slow ramp) = 8 cases. The IP should emit `aso_filllevel_data = 0x0200` (= 512) and the upstream FIFO must apply back-pressure.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR113..116 | partition K, fast saturating burst | T6 trigger on `aso_filllevel_data == 16'h0200` | T6 partition K (4096×4) | partition reaches 512; back-pressure asserted upstream; no `OVERFLOW_COUNT` advance on histogram (the back-pressure prevents loss); chain drains correctly when consumer resumes | pending |
| TPB5ERR117..120 | partition K, slow ramp to saturation | same | same | partition reaches 512 over a longer window; identical recovery | pending |

### Group X9 — TERMINATING idle-guard violation, 8 cases

Stimulus: keep the upstream byte stream busy past the `TERMINATING_IDLE_GUARD_CONST = 2048` cycles. The fallback path at `frame_rcv_ip.vhd:29` ("Close TERMINATING on the first empty frame and keep the idle guard only as a fallback") should still cleanly close the run.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR121..124 | held busy 2049, 4096, 8192, 16384 cycles after CMD_END_RUN | T1 trigger on `terminating_idle_guard_cnt == 2048` | T1 (4096×4), T7 (4096×4) | the guard fires at 2048; deassembler closes; T7 `terminating_done` asserts; chain returns to IDLE; SWB-CHK does not see ghost hits | pending |
| TPB5ERR125..128 | held busy with deliberate empty-frame markers between bursts | same | same | the empty-frame fallback closes TERMINATING earlier than 2048; both close paths exercised | pending |

### Group X10 — cross-subsystem error containment, 16 cases

Stimulus: inject a contained error on one side of the lane 3/4 hit-stack boundary while a clean reference hit flows on the other side. These cases target likely bugs where an error flag, reset pulse, or dropped-frame side effect leaks across hit_stack_subsystem_0/1 or corrupts the shared upload/SWB accounting.

| case_id | stimulus | trigger | taps | evidence | MATCH |
|---|---|---|---|---|---|
| TPB5ERR129..136 | lane 3 has a torn-frame or CRC error while lane 4 emits a clean single hit; 8 variants across error kind and channel {0,31} | T1 error trigger on lane 3 plus GTS-arm on lane 4 | T1[3], T1[4], T4(M=0/1), T6(M=0/1), T7(M=0/1), TS | lane 3 error is observable and contained before SWB; lane 4 clean hit reaches T7/TS exactly once; hit_stack_subsystem_1 counters do not inherit M=0 error state | pending |
| TPB5ERR137..144 | lane 4 has a torn-frame or CRC error while lane 3 emits a clean single hit; 8 variants across error kind and channel {0,31} | T1 error trigger on lane 4 plus GTS-arm on lane 3 | same | lane 4 error is observable and contained; lane 3 clean hit reaches T7/TS exactly once; `histogram_ingress_bridge_0` does not report the M=1 error as a pre-bridge event | pending |

## Closure aggregator

ERROR bucket PASSES when:

- Every TPB5ERR### row's negative trigger fires (the injected error is observable),
- The per-IP `*_error` flag, decoder counter, or overflow counter advances exactly as documented,
- No collateral counter advances on unrelated lanes / partitions,
- The chain recovers cleanly to IDLE after the error window,
- For long-term closure, every row's `MATCH:` resolves to a passing `tb_int/` integration-sim case.

ERROR bucket FAILS if:

- a negative trigger does **not** fire (the error injection failed; no observability),
- collateral counters advance,
- the chain does not recover to IDLE,
- any error type silently propagates past its containment IP.

Failures route per the §6 first-pass debug ladder. The ERROR bucket is the bucket whose pass/fail polarity is inverted from the others — passing cases imply the error path works, not that the design is error-free.
