# BUG_HISTORY.md - mutrig_lane_source_mux DV bug ledger

Class legend:
- `R` = RTL / DUT bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal traffic, about `50%` link load, iid per-lane behavior, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus
- detailed `min / p50 / max` first-hit sim-time studies may still appear inside individual bug sections; current measured mixed-soak encounter data is not yet archived for this IP

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- No historical formal entries are recorded for this IP-local mux bench yet.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-H](#bug-001-h-validless-csr-snapshot-readback-was-not-coherent-while-real-counter-ran) | H | non-datapath-refactor | `directed-only (harness readback)` | fixed | `mlsm_directed_test` case 32/48 bring-up | `pending` | Validless tests initially read multi-word CSR snapshots while the real input counter advanced every clock. |

## 2026-05-03

### BUG-001-H: Validless CSR snapshot readback was not coherent while real counter ran
- First seen in:
  - `mlsm_directed_test` case 32 and case 48 while bringing up
    `REAL_ALWAYS_VALID=1`
- Symptom:
  - selected-source counter checks could fail by one count when the harness
    read several CSR words across active clock edges
  - the DUT behavior was consistent with the validless contract: the real input
    counter is always-running when `REAL_ALWAYS_VALID=1`
- Root cause:
  - the harness treated the validless real input counter as if it were a static
    valid-qualified snapshot
- Fix status:
  - state:
    - fixed in the UVM harness
  - mechanism:
    - validless direct and switching checks move the selected-output side idle
      before selected-source CSR checks
    - raw real input count is checked as nonzero/monotonic rather than
      cycle-exact in validless mode
  - before_fix_outcome:
    - case 32/48 could report one-count CSR mismatches
  - after_fix_outcome:
    - validless cases 56-63 and focused case 50 pass; directed32_rav1 reaches
      the final switching bucket after the snapshot repair
    - three long soaks with `SOAK_ITERS=150000` pass at 34s, 37s, and 36s
  - potential_hazard:
    - closed for current UVM harness; future CSR snapshot tests should continue
      to quiesce selected-output traffic before cycle-exact multi-word reads
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - affects harness readback only; no RTL change was required
- Commit:
  - pending
