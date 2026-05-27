# BUG_HISTORY.md - 260518-feb-ok tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT integration bug exposed by the tb_int harness
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does
  not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and
  typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or
  naming/accounting consistency work with no direct packet-contract
  effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index
  must say how likely a reader is to hit the bug in normal use rather
  than only when it first appeared in one simulation log
- nominal datapath operation = legal FEB v3 ingress, hist_dualport
  Type0/Type1 traffic, run-control idle, no forced error injection
- nominal control-path operation = bring-up / CSR program / readback /
  clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup,
  but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long
  runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or
  corner profile
- `directed-only (...)` = requires targeted error injection,
  formal/probe flow, reporting-only flow, or another non-operational
  stimulus

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness
  behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence
  showing what changed
- `potential_hazard` = whether the fix looks permanent or is still
  provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use
  `pending / not run` until that review has actually happened

Historical formal note:
- This ledger starts with the 260518-feb-ok integration harness on
  2026-05-18.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-mts_preprocessor-hit_type1_ts-conduit-missing-from-master) | R | hard stuck error | `common (every V3 histogram delay-mode integration run)` | fixed-rtl / sim-validated | `make qsys` on 260518-feb-ok, 2026-05-18 | `45d8d58` (mutrig_timestamp_processor master) | The mts_preprocessor IP on master did not declare hit_type1_ts; only the unmerged eb67302 commit had it. qsys-generate could not bind scifi_datapath_system_v3.qsys's mts_preprocessor.hit_type1_ts to histogram_statistics_v2.type1_*_ts connection. Manually merged additive on master, IP version bumped to 26.3.5.0518, .qsys forward-bumped. |

## 2026-05-18

### BUG-001-R: mts_preprocessor hit_type1_ts conduit missing from master

- First seen in:
  - `firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/`
    `make qsys` run, 2026-05-18 12:11
  - `generated/synthesis/scifi_datapath_system_v3/scifi_datapath_system_v3_generation.rpt`
    line `Error: scifi_datapath_system_v3.mts_preprocessor_0.hit_type1_ts / histogram_statistics_0.type1_up_ts: Missing connection start`
- Symptom:
  - `qsys-generate` exited `Error: null` after `Error: scifi_datapath_system_v3.mts_preprocessor_0: Component mts_preprocessor 26.3.3.517 not found or could not be instantiated`.
  - sopcinfo carried `mts_preprocessor_{0,1}` as `kind="missing_module"`.
  - The hit_type1_ts conduit was never declared in master's
    `mutrig_timestamp_processor/mts_processor_hw.tcl`; only the
    `hit_type1_extended_{0,1}` AvalonST sources from `1e4e619` were
    present.
- Root cause:
  - Commit `eb67302 [PATCH] MTS: split Type1 timestamp sideband` on
    branch `backup/codex/stream-debug-plane-feb-v3-20260515` added the
    `hit_type1_ts` conduit interface but the branch was never merged to
    master. The `.qsys` was generated against eb67302-era IP and
    requested an interface that does not exist on the master IP.
- Fix:
  - state = fixed-rtl / sim-validated
  - mechanism = manual additive merge of eb67302's
    `add_interface hit_type1_ts conduit ...` block into master's
    `mts_processor_hw.tcl`; matching `coe_hit_type1_ts : out
    std_logic_vector(47 downto 0)` port added to `mts_processor.vhd`
    and driven from `hit_out_debug_timestamp` when `hit_out.valid`;
    syn wrappers + tb files wired through; IP VERSION bumped to
    `26.3.5.0518`; `.qsys` mts_preprocessor ref bumped from
    `26.3.4.0515` to `26.3.5.0518`.
  - before_fix_outcome = qsys-generate exit_code=1 with
    `Error: scifi_datapath_system_v3.mts_preprocessor_0: Component
    mts_preprocessor 26.3.3.517 not found`; sopcinfo had 26
    `kind="missing_module"` entries.
  - after_fix_outcome = `make qsys-syn` reaches Done on all 3 systems;
    sopcinfo has 0 `missing_module` entries; HDL trees emitted for
    arb_hit_type0_supercore (63 files), scifi_datapath_system_v3
    (584 files), feb_system_v3 (369 files).
  - potential_hazard = `hit_type1_extended_{0,1}` AvalonST paths and
    `hit_type1_ts` conduit now both exist; future RTL changes must
    keep both consistent.
  - Claude Opus 4.7 xhigh review decision = pending / not run
- Reproduction:
  - `cd firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3`
  - `make qsys`
- Validation:
  - `make -C mutrig_timestamp_processor/tb run_all` completed with
    `Errors: 0` and the `mts_processor_terminating_tb PASSED` marker on
    2026-05-18 12:44.
- Commit hashes:
  - `mutrig_timestamp_processor` submodule master: `45d8d58`
  - parent submodule pointer commit: pending in the next parent commit
