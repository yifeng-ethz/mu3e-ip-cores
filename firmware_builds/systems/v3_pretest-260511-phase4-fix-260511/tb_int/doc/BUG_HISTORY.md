# BUG_HISTORY.md - v3_pretest-260511 tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT integration bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal traffic, routine FEB SciFi bring-up, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL, integration, or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- This ledger starts with the v3_pretest-260511 tb_int harness bring-up on 2026-05-11.
- Historical standalone IP formal notes remain in the source IP repositories.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-rdma-upload-boundary-not-applicable-to-v3-pretest-feb-only-tb-int) | R | non-datapath-refactor | `directed-only (scope correction / task split)` | redesignated / not-applicable for FEB-only tb_int | `B065` structural preflight | `pending` | v3_pretest-260511 FEB-only tb_int correctly binds the legacy upload_pkt_mux path; RDMA cosim is task #48. |

## 2026-05-11

No active DUT bug remains from the original BUG-001-R observation; it is redesignated below.

## Resolved / Redesignated

### BUG-001-R: RDMA upload boundary not applicable to v3_pretest FEB-only tb_int
- First seen in:
  - `make check_dut_contract` from `firmware_builds/systems/v3_pretest-260511/tb_int`
  - inherited first RDMA-bound datapath case assumption: `B065`
- Symptom:
  - the generated synthesis tree under `syn/feb_system_v3/synthesis/` contains no FEB-side `rdma_subsystem` hierarchy
  - the upload subsystem correctly compiles through the legacy `feb_frame_assembly` plus `upload_pkt_mux` path for this FEB-only build
  - the inherited harness treated the absence of RDMA SQE/CQE signals as a blocking bug
- Root cause:
  - scope error in the prior tb_int brief; RDMA lives on the SWB side and belongs to a separate FEB+SWB cosim effort
  - v3_pretest-260511 FEB-only tb_int must observe `upload_pkt_mux`, matching the Apr 27 reference layout
- Fix status:
  - state:
    - redesignated / not-applicable for FEB-only tb_int
  - mechanism:
    - rebind the FEB-egress monitor to the legacy `upload_pkt_mux` egress and leave RDMA cosim to task #48
  - before_fix_outcome:
    - `tb_int/sim/logs/dut_structural_check.log` recorded the inherited RDMA preflight block
  - after_fix_outcome:
    - `make -C tb_int run_B065` passed with the corrected `upload_pkt_mux` egress binding; scoreboard reconciled `A=16 PRE=16 POST=16 FEB=16 closed=16`
  - potential_hazard:
    - low for FEB-only smoke once the harness excludes RDMA SQE/CQE scaffolding from the active compile path
  - review decision:
    - pending / not run
