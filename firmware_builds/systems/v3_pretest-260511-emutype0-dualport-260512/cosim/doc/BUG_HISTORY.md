# BUG_HISTORY.md - FEB SWB cosim history ledger

Bugs and accepted limitations found via the dual-UVM FEB <-> SWB cosim
runs at this build dir.

## Class legend
- `R` = RTL / DUT bug (touches design RTL, would also show on silicon)
- `H` = harness / cosim infrastructure (sim-only, no silicon impact)
- `T` = test plan / theory model (the theoretical_hits or pass criterion
  was incorrect; the design and harness are fine)

## Severity legend
- `closure-blocker` = blocks RN.BASIC PASS criteria; must close before
  the cosim evidence stream is trusted
- `expected-ceiling` = real saturation point or known sim-only ceiling;
  document the row range affected and the on-board fall-back, no fix
- `cosim-only-noise` = sim infrastructure quirk that does not match
  on-board behaviour; needs cosim patch but no design change

## Encounterability legend
- `swept` = visible in the standard cosim sweep
  (`make run_BASIC PARALLEL=<N>`)
- `directed-only` = requires targeted re-run with custom row config

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| BUG-001-H | H | closure-blocker | swept | TBD | 2026-05-12 auto-report | n/a | p45 board sweep rows are PERF/4 s evidence and cannot be mapped as BASIC/1 ms measured data. |
| BUG-002-T | T | closure-blocker | swept | fixed | 2026-05-12 auto-report | 1d946b02 | 7585741f cosim row_config files still describe the 208-row layout after TEST_BASIC was trimmed to 194 rows at 786da8b2. |
| BUG-003-H | H | closure-blocker | swept | fixed | 2026-05-12 iter 2 slice 3 rerun | cfae13e1 | Onclick sanity rows carried expected_pulses=10 but the cosim source emitted one pulse per 1 ms window. |
| BUG-004-H | H | closure-blocker | swept | fixed | 2026-05-12 iter 3 slice 4 rerun | 254d7c87 | Four-ASIC RN.BASIC masks were compressed onto two SWB physical lanes and checked against the stale two-lane oracle. |
| BUG-005-R | R | closure-blocker | swept | fixed | 2026-05-12 iter 4 RN.BASIC.163 | 4e798bc/02679b20 | Native-signoff OPQ src_compat left page_allocator.handle_credit_update_valid_i unconnected, corrupting full-mask backlog payload identity. |
| BUG-006-H | H | closure-blocker | swept | fixed | 2026-05-12 iter 4 RN.BASIC.163 | a073596b/e9eaeaea | Native-signoff lossless traces were failed by stale generated-OPQ summary assumptions and non-closure defaults. |
| BUG-007-H | H | closure-blocker | swept | fixed | 2026-05-12 iter 5 slice 2 | 1c30b766 | Header-sync cosim source advanced on the virtual short-frame interval instead of the RN.BASIC pulse interval. |
| BUG-008-H | H | closure-blocker | swept | fixed | 2026-05-12 iter 6 RN.BASIC.082 | 59663d3c | Single-ASIC periodic row kept empty physical lanes enabled and decoded the native SciFi header alias as MuPix. |
| BUG-009-T | T | closure-blocker | swept | fixed | 2026-05-13 per-checkpoint review | be528d5a/9b527599 | Single global delay bound replaced with 5 per-checkpoint bounds (pre-rbCAM, post-rbCAM, FEB egress, OPQ ingress, OPQ egress) per injector mode. |
| BUG-010-H | H | closure-blocker | swept | fixed | 2026-05-13 per-checkpoint review | be528d5a | Analyzer reported delay_max_cycles = delay_min_cycles = 0 because it subtracted abs_ts_8ns from itself instead of joining upstream/downstream checkpoint traces on hit_id. |
| BUG-009-R | R | closure-blocker | swept | fixed in IP standalone; integration re-fit pending | 2026-05-13 integration STA trace #103 | run-control_mgmt 24be671 | snap_*_lvds -> snap_*_mm_q0 CDC missing synchronized update/valid handshake; STA timed the multi-bit crossing as a normal setup endpoint. |

---

## 2026-05-13

### BUG-009-R: run-control snapshot CSR CDC timed as a normal setup path

- First seen: integration STA setup trace #103 for
  `v3_pretest-260511-pulserdrop-260512` at commit `9b6dcf7a`.
- Symptom: all 40 worst-10-per-corner setup failures pointed at
  `run-control_mgmt/runctl_mgmt_host`; worst Slow85 slack was `-3.220 ns` on
  `snap_exec_ts_lvds[9] -> snap_exec_ts_mm_q0[9]`.
- Root cause: `snap_*_lvds -> snap_*_mm_q0` CDC missing synchronized
  update/valid handshake; STA times the multi-bit crossing as a normal setup
  endpoint and reports `-3.220 ns` Slow85 setup.
- Fix status: fixed in `run-control_mgmt` commit `24be671`; the LVDS snapshot
  now waits through a five-cycle stable phase, toggles a single-bit update
  notice, and captures the multi-bit snapshot bus in `mm_clk` only on the
  synchronized update pulse. Standalone 1.1x STA closed in iteration 3 with
  setup, hold, recovery, and removal nonnegative in all four corners.
  potential_hazard: integration closure still depends on clean Qsys
  regeneration and a full top re-fit of the pulser-drop build.
- Commit: run-control_mgmt `24be671`
  `[FIX] HW: gate runctl snapshot CDC`.

### BUG-009-T: single global delay bound hides per-checkpoint failures

- First seen: per-checkpoint review of the final RN.BASIC cosim auto-report at
  `92184df7`.
- Symptom: the generated report used one row-level delay target
  (300 cycles for header-sync, 900 cycles for periodic-like rows) and checked
  only `abs(delay_max_cycles - delay_min_cycles)`, so a row could pass without
  proving the five FEB->SWB checkpoint contracts independently.
- Root cause: the report model collapsed pre-rbCAM, post-rbCAM, FEB egress,
  OPQ ingress, and OPQ egress into one global delay spread instead of using the
  per-mode checkpoint envelopes.
- Fix status: fixed; `scripts/cotest/cosim_delay_bounds.py` defines
  per-mode checkpoint bounds and the auto-report now emits
  `delay_pre`, `delay_post`, `delay_feb`, `delay_ing`, and `delay_opq`
  PASS/FAIL columns. The header-sync OPQ lower edge is row-derived for sparse
  lane/channel masks, while the dense all-ASIC/all-channel anchor remains
  `[4356.0, 99133.5]`. after_fix_outcome: refreshed DUT sweep
  `make run_BASIC PARALLEL=16
  WORK_ROOT=/data2/cosim_work_per_checkpoint_20260513_iter2` completed
  194/194 PASS, with all five delay columns PASS for every row and
  DISLIN lifetime reports generated under
  `reports/rn_basic_194_per_checkpoint_20260513_iter2_h9b527599/`.
  potential_hazard: periodic and emul-only OPQ bounds remain conservative
  until reviewer anchor numbers are published.
- Commit: be528d5a `[PATCH] HW: v3_pretest-260511 per-checkpoint delay evidence`;
  9b527599 `[PATCH] HW: v3_pretest-260511 derive rn basic opq bounds`.

### BUG-010-H: lifetime analyzer subtracts a checkpoint timestamp from itself

- First seen: per-checkpoint review of
  `feb_swb_lifetime_hist_stats.csv` from the final RN.BASIC evidence.
- Symptom: every row could report `delay_min_cycles = delay_max_cycles = 0`
  for the delay-bound evidence even though the checkpoint traces contain real
  per-hit timing spread.
- Root cause: the analyzer path used a single scoreboard/post-rbCAM timestamp
  surface and did not join checkpoint records on `hit_id`; the resulting
  subtraction collapsed to zero and the global spread check passed vacuously.
- Fix status: fixed; `scripts/cotest/cosim_lifetime_analyzer.py`
  materializes per-checkpoint hit CSVs, joins the five checkpoints by
  `hit_id`, computes non-flat per-checkpoint lifetime percentiles, and writes
  `feb_swb_range_validation.csv` for the auto-report. after_fix_outcome:
  the refreshed DUT sweep generated nonzero min/p05/p50/p95/max for all five
  checkpoints in every RN.BASIC row, produced zero flat-distribution errors,
  and closed 194/194 PASS with the multi-panel DISLIN lifetime PDFs present
  for all rows. potential_hazard: stale pre-`be528d5a` row directories must be
  regenerated before they can be used as closure evidence.
- Commit: be528d5a `[PATCH] HW: v3_pretest-260511 per-checkpoint delay evidence`.

## 2026-05-12

### BUG-001-H: p45 board evidence is not BASIC-compatible

- First seen: `scripts/cotest/cosim_auto_report.py` dry inspection of
  `sweep_evidence/p45_*` for the RN.BASIC auto-report.
- Symptom: every live p45 row reports `bucket=PERF` with
  `theoretical_window_ms=4000.0`; no row can be used as a 1 ms RN.BASIC board
  measurement without changing the theory comparison.
- Root cause: the board sweep tree is an older pre-arbfix PERF-style sweep,
  not a row-compatible BASIC evidence stream for the 194-row TEST_BASIC plan.
- Fix status: TBD; auto-report marks measured board totals as unresolved and
  does not silently compare PERF/4 s data against BASIC/1 ms expectations.
- Commit: n/a; requires a compatible board sweep or an explicit normalization
  contract.

### BUG-002-T: cosim evidence row_config is stale for the 194-row plan

- First seen: `scripts/cotest/cosim_auto_report.py` dry inspection of
  `cosim/REPORT/RN.BASIC.NNN/row_config.json`.
- Symptom: rows 161 onward carry the 7585741f 208-row layout metadata, while
  `TEST_BASIC.md` at 786da8b2 defines only two onclick cases and moves
  RN.BASIC.163-194 to emulator-only cases.
- Root cause: the cosim sweep evidence predates the TEST_BASIC reshape commit
  and was not regenerated after the plan changed.
- Fix status: fixed; `rn_basic_cosim.py` now parses contiguous
  RN.BASIC.001-194 from `TEST_BASIC.md`, uses rows 161-162 for onclick,
  rows 163-194 for emulator-only, and ignores stale saved `row_config.json`
  when selecting a row. The summary path is now `RN.BASIC.194_summary.json`;
  after_fix_outcome: dry-run ends at RN.BASIC.194 with slice 3 and slice 4
  remapped to the 194-row plan; potential_hazard: old untracked row evidence
  directories remain stale until overwritten by targeted or full reruns.
- Commit: 1d946b02 `[PATCH] HW: v3_pretest-260511 rn basic 194 runner`.

### BUG-003-H: onclick cosim source emits one pulse instead of expected_pulses

- First seen: `make run_BASIC SLICE=3 PARALLEL=16
  WORK_ROOT=/data2/cosim_work_iter1_slice3_20260512` after BUG-002-T parser
  repair.
- Symptom: RN.BASIC.161 reported 256 hits against 2,560 theoretical hits, and
  RN.BASIC.162 reported 8 hits against 80 theoretical hits. Delay and RDMA
  parity passed because the generated smaller source stream was internally
  conserved.
- Root cause: `RnBasicRow.sim_hit_period_8ns()` forced slice 3 to
  `RUN_WINDOW_8NS`, so the periodic source emitted one pulse per selected
  channel in the 1 ms window even though the onclick sanity rows encode
  `expected_pulses=10`.
- Fix status: fixed; slice 3 now derives source period from
  `RUN_WINDOW_8NS // expected_pulses`, yielding ten generated pulses per
  selected channel. after_fix_outcome: slice 3 rerun went 0/2 PASS to 2/2
  PASS; RN.BASIC.161 reports 2,560 hits and RN.BASIC.162 reports 80 hits with
  rate/delay/RDMA all PASS. potential_hazard: the source-mode approximation
  still models onclick as deterministic periodic source evidence rather than
  an RTL mode-write edge sequence.
- Commit: cfae13e1 `[PATCH] HW: v3_pretest-260511 onclick pulse count`.

### BUG-004-H: four-ASIC masks compress onto two physical SWB lanes

- First seen: `make run_BASIC SLICE=4 PARALLEL=16
  WORK_ROOT=/data2/cosim_work_iter3_slice4_20260512` after the 194-row runner
  and onclick repairs.
- Symptom: RN.BASIC.167-174 delivered source/FEB/SWB counts at theory but
  lost hits at OPQ/RDMA when 0x55 and 0xAA lane masks were driven. A directed
  4-lane probe moved the failure to trace-only lane mismatches, proving the
  data path could conserve those rows once all four physical SWB lanes were
  exercised.
- Root cause: `feb_swb_corun_plain_tb.sv` still used a two-lane source map and
  the trace analyzer expected that same stale map. Even/odd four-ASIC masks
  therefore landed on only two physical lanes instead of using the four-lane
  OPQ wrapper.
- Fix status: fixed; the harness now drives four lanes, maps adjacent ASIC
  pairs onto physical lanes 0..3, derives the adapter enable mask from
  `ACTIVE_LANES`, and checks traces against the same lane oracle.
  after_fix_outcome: RN.BASIC.167 directed rerun passed, and slice 4 improved
  from 20/32 PASS to 28/32 PASS. potential_hazard: RN.BASIC.163-166 remain
  open as a separate full-8-lane OPQ/RDMA ceiling cluster.
- Commit: 254d7c87 `[PATCH] HW: v3_pretest-260511 corun lane compaction`.

### BUG-005-R: OPQ src_compat wrapper drops handle credit return

- First seen: `make run_BASIC SLICE=4 PARALLEL=16
  WORK_ROOT=/data2/cosim_work_iter3_slice4_20260512`, then isolated with
  RN.BASIC.163 native-signoff directed reruns.
- Symptom: RN.BASIC.163-166 full-mask rows reached OPQ ingress with 125,138
  generated hits, but the default profile emitted only 75,217 OPQ/RDMA hits.
  With enlarged OPQ memories the endpoint count recovered to 125,138, but
  8,422 expected DMA payloads were replaced by zero-payload ghost hits.
- Root cause: `packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv`
  had drifted from the maintained OPQ RTL and did not connect
  `block_path_lane_credit_update_valid` to
  `page_allocator.handle_credit_update_valid_i`. The allocator therefore had
  stale handle FIFO credit information under full-mask backlog and could
  recycle handle storage before the block mover had consumed the old handle.
- Fix status: fixed; the source-compat wrapper now wires the handle credit
  return and closes the adjacent unconnected debug ports so compile warnings
  do not hide future functional port drift. after_fix_outcome: RN.BASIC.163
  moved from 116,716/125,138 matched hits with 8,422 ghosts to
  125,138/125,138 matched hits with zero ghosts; RN.BASIC.163-166 all pass
  rate, delay, and RDMA after the paired analyzer/defaults fixes.
  potential_hazard: the closure evidence uses the native-signoff OPQ profile
  documented in `COSIM_USAGE.md`; smaller generated/default OPQ profiles remain
  capacity probes, not RN.BASIC closure evidence.
- Commit: packet_scheduler 4e798bc
  `[PATCH] HW: v3_pretest-260511 opq handle credit`; parent pointer 02679b20
  `[PATCH] HW: v3_pretest-260511 packet scheduler pointer`.

### BUG-006-H: native-signoff OPQ traces failed stale generated-summary checks

- First seen: RN.BASIC.163 rerun after BUG-005-R fixed OPQ payload identity.
- Symptom: the trace analyzer returned FAIL with `issue_count=2` solely because
  `run_swb_corun.log` did not contain `OPQ_NATIVE_SUMMARY` and
  `OPQ_NATIVE_LANE_SUMMARY`, even though the per-hit lineage showed
  OPQ ingress = OPQ egress = DMA = 125,138 and zero ghosts.
- Root cause: `tb_int/feb_swb_corun/scripts/analyze_feb_swb_trace.py` treated
  generated-OPQ text summaries as mandatory for every lossless run. The
  RN.BASIC make target also still defaulted to the stale generated/default OPQ
  profile and `PARALLEL=30`, which did not match the safe closure setup.
- Fix status: fixed; missing native summary text is waived only when the trace
  itself proves lossless OPQ/DMA bijection with every hit row PASS, and
  `cosim/Makefile` now exports the native-signoff OPQ profile, repo-root source
  path, `/data2` build root, and `PARALLEL=16` default. after_fix_outcome:
  analyzer replay on the row-163 trace returns `TRACE_DEBUG_PASS`; RN.BASIC.163
  rerun returns rate/delay/RDMA PASS; RN.BASIC.163-166 all pass with
  `issue_count=0`. potential_hazard: nonzero OPQ drop/ghost evidence remains
  fatal; this fix only suppresses missing text-summary issues when the trace is
  otherwise bijective.
- Commit: a073596b
  `[PATCH] HW: v3_pretest-260511 opq lossless analyzer`; e9eaeaea
  `[PATCH] HW: v3_pretest-260511 rn basic opq defaults`.

### BUG-007-H: header-sync source cadence uses short-frame interval

- First seen: full RN.BASIC.194 sweep at
  `/data2/cosim_work_full_20260512_iter4closure` after BUG-005-R and
  BUG-006-H closure.
- Symptom: all 32 slice-2 rows failed only the rate checkpoint. RN.BASIC.129
  reported 35,328 generated/post-rbCAM/RDMA hits against 125,000 theoretical
  hits, while trace, FIFO, ghost, missing, and downstream conservation errors
  were all zero.
- Root cause: `generate_header_sync_source_model()` emitted one burst per
  `VIRTUAL_MUTRIG_SHORT_FRAME_8NS` interval, producing about 138 samples per
  selected channel in 1 ms. RN.BASIC slice 2 is specified as header-sync mode
  at `rate=0x0100`, so the cosim source must preserve the header phase while
  advancing on the row `HIT_PERIOD_8NS` cadence.
- Fix status: fixed; the source model now advances header-sync bursts by
  `HIT_PERIOD_8NS`, and the trace analyzer validates the same
  phase-plus-period schedule. after_fix_outcome: `make run_BASIC SLICE=2
  PARALLEL=16 WORK_ROOT=/data2/cosim_work_iter5_slice2_20260512` went 0/32 to
  32/32 PASS; RN.BASIC.129 reports 124,928/125,000 hits with zero trace/corun
  errors. potential_hazard: this is a cosim stimulus repair only; the final
  board-compatible BASIC sweep remains tracked by BUG-001-H.
- Commit: 1c30b766 `[PATCH] HW: v3_pretest-260511 headersync cadence`.

### BUG-008-H: single-lane native OPQ SciFi alias is decoded as MuPix

- First seen: full RN.BASIC.194 sweep at
  `/data2/cosim_work_full_20260512_iter4closure`, then isolated with
  `make run_BASIC ROW=RN.BASIC.082 PARALLEL=16
  WORK_ROOT=/data2/cosim_work_iter6_row082_20260512 KEEP_RAW_TRACES=1`.
- Symptom: RN.BASIC.082 generated and delivered 7,808 hits through FEB egress,
  SWB ingress, and OPQ ingress, but per-hit matching reported one missing DMA
  hit and one ghost DMA hit. The raw OPQ egress trace replaced the final
  channel-31 payload from subheader 8 with the first channel-0 payload from
  subheader 40 under the old timestamp, then emitted that channel-0 payload
  again after the correct subheader.
- Root cause: the corun SWB register shim kept all four physical OPQ lanes
  enabled even when the RN.BASIC row selected only one ASIC lane. That let
  enabled empty-lane traffic perturb the native OPQ merge boundary. When the
  lane mask was corrected, the native-SV OPQ wrapper exposed the second
  harness bug: its external VHDL adapter treated unknown K28.5 package header
  aliases as `MUPIX_HEADER_ID`, so the downstream MuSiP mux decoded the SciFi
  payload in the wrong 64-bit detector format.
- Fix status: fixed; `rn_basic_cosim.py` now compiles the RN.BASIC corun with
  a local SciFi-only native OPQ adapter, the harness derives the SWB enable
  mask from the selected RN.BASIC physical lanes, and the local adapter maps
  unknown native K28.5 header aliases back to `SCIFI_HEADER_ID`. after_fix_outcome:
  RN.BASIC.082 directed rerun reports 7,808/7,808 pass hits, zero fail hits,
  zero ghosts, `issue_count=0`, and delay min/p05/p50/p95/max all 0 cycles.
  potential_hazard: this adapter is intentionally SciFi-only for RN.BASIC
  closure; mixed-detector MuSiP coruns must use a detector-aware adapter.
- Commit: 59663d3c
  `[PATCH] HW: v3_pretest-260511 native opq scifi shim`.

## Format for new entries

Append each new bug as a `## YYYY-MM-DD` section dated by first-seen
plus a sub-section per bug_id matching the index row. Each sub-section
follows the same template used in the charge_injection IP and the
tb_int integration ledgers:

- First seen: where, which sweep
- Symptom: what the rate / delay / rdma checkpoint reported
- Root cause: which IP / which signal / which CSR
- Fix status: state + mechanism + after_fix_outcome + potential_hazard
- Commit: SHA + one-line subject

### BUG-011-H: 5-tab evidence popups silently rendered empty bodies

- First seen: user reported that clicking evidence View buttons in
  `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT_5TAB.html`
  showed no popup content despite the dummy RN.BASIC.001 evidence being
  embedded.
- Symptom: every click on a `.ev-btn` opened the modal element but the
  modal body remained empty; no console error surfaced because the
  parser failure was swallowed by a try/catch fallback to `EV = {}`.
- Root cause: the inlined evidence JSON was wrapped through
  `html.escape()` before being placed in a `<script type="application/json">`
  block. HTML5 treats script-element bodies as raw text and does NOT
  decode entity references, so `textContent` returned the literal
  `&quot;` etc strings, which JSON.parse threw on.
- Fix status: fixed; emit the evidence JSON without `html.escape()`, only
  neutralising `</` against premature script termination via `<\/`. The
  generator at `scripts/cotest/phase4_5_html_5tab.py:basic_rows_html()`
  now uses `json.dumps(...).replace("</", "<\\/")`.
- Validation: headless chromium click test on all 5 buttons returns
  `OPEN=true` with non-empty body lengths (counter 4612, delay 629,
  rdma 11393, scoreboard 1379, runlog 2689). The embedded basic-evidence
  blob now starts with `{"RN.BASIC.001":{...}}` literal characters.
- Commit: this commit `[FIX] HW: v3_pretest-260511 5-tab evidence popup
  JSON parse fix`.
