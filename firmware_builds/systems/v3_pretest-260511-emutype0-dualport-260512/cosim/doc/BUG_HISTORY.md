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

---

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
