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
| BUG-002-T | T | closure-blocker | swept | TBD | 2026-05-12 auto-report | n/a | 7585741f cosim row_config files still describe the 208-row layout after TEST_BASIC was trimmed to 194 rows at 786da8b2. |

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
- Fix status: TBD; auto-report preserves the evidence but marks mismatched
  rows as unresolved rather than treating stale counters as matching plan rows.
- Commit: n/a; requires a fresh cosim sweep or a reviewed row remap manifest.

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
