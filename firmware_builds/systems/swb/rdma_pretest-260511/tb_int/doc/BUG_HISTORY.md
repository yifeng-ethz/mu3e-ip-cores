# BUG_HISTORY.md - swb rdma_pretest-260511 tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT integration bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal SWB RDMA ingress, OPQ four-lane traffic, event-builder packing, host DMA push, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- This ledger starts with the SWB rdma_pretest-260511 integration harness on 2026-05-11.
- Historical standalone IP formal notes remain in the source IP repositories.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-H](#bug-001-h-swb-tb-int-had-no-local-synthesis-tree-for-basic-smoke) | H | non-datapath-refactor | `directed-only (harness preflight)` | fixed | `B065` structural preflight | `pending` | SWB tb_int could not run its first BASIC smoke until a local staged board project and Qsys synthesis outputs existed. |

## 2026-05-11

### BUG-001-H: SWB tb_int had no local synthesis tree for BASIC smoke
- First seen in:
  - `B065` structural preflight for `swb/rdma_pretest-260511/tb_int`
- Symptom:
  - the mu3e-ip-cores workspace had no SWB-local staged board project under
    `firmware_builds/systems/swb/rdma_pretest-260511/`
  - BASIC smoke could not bind against a durable local Qsys synthesis tree
- Root cause:
  - the SWB project still lived in the read-only `online_sc` source location
    and had not been minted into the mu3e-ip-cores firmware-build layout
- Fix status:
  - state:
    - fixed for the structural B065 preflight
  - mechanism:
    - staged the SWB board project locally
    - copied the SWB-owned OPQ Platform Designer Tcl/Qsys files into
      `quartus_systems/swb/`
    - added the SWB `tb_int` plan, bucket files, and first BASIC smoke
      harness
  - before_fix_outcome:
    - no local SWB `syn/board_projects/swb_a10` tree existed
  - after_fix_outcome:
    - qsys-generate preflight exits `0`; see
      `firmware_builds/systems/swb/rdma_pretest-260511/syn/swb_qsys_generate_20260511_1232.status`
    - BASIC B065 structural smoke passes `1/0/0` at each observed stage; see
      `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim/logs/swb_basic_b065_smoke.log`
  - potential_hazard:
    - low for structural preflight; full live UVM closure still depends on
      later bind-point refinement against generated hierarchy names
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - first case implemented is `B065`
  - remaining bucket cases are planned and pending implementation
- Commit:
  - pending
