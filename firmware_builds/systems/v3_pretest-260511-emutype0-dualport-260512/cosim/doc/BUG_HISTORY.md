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

(initial empty; entries appended as cosim fail-mode analysis lands)

---

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
