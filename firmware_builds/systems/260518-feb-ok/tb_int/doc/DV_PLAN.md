# DV_PLAN.md - 260518-feb-ok tb_int

Integration DV plan for the FEB SciFi v3 firmware build under
`firmware_builds/systems/260518-feb-ok/`. Drives the UVM harness in
`tb_int/uvm/` against the authentic generated firmware at
`firmware_builds/systems/260518-feb-ok/generated/simulation/feb_system_v3/`
per dv-workflow rule 19.

## Verification targets

| Bucket | File | What it proves | Closure gate |
|---|---|---|---|
| Basic    | [DV_BASIC.md](DV_BASIC.md)  | Normal data + SC + run-control reach the upload/PCIe boundary cleanly | All B-cases pass in isolated + bucket_frame |
| Edge     | [DV_EDGE.md](DV_EDGE.md)    | Corner conditions (boundary timestamps, single-channel, empty frame) | All E-cases pass in isolated; bucket_frame allowed to PARTIAL with documented limits |
| Profile  | [DV_PROF.md](DV_PROF.md)    | Soak / sustained-rate / 4-bank dual-port throughput | One soak run logs hit_count = expected within tolerance |
| Error    | [DV_ERROR.md](DV_ERROR.md)  | Reset / fault / illegal / recovery | Recovery is deterministic; no stuck FSM |
| Cross    | [DV_CROSS.md](DV_CROSS.md)  | `bucket_frame` and `all_buckets_frame` baselines (dv-workflow rule 9) | Merged coverage reported separately from isolated; deltas explained |

Coverage tracking: [DV_COV.md](DV_COV.md).
Bug ledger: [BUG_HISTORY.md](BUG_HISTORY.md).
Harness reference: [DV_HARNESS.md](DV_HARNESS.md).

## Coverage intent

- Statement / branch / condition / FSM / toggle on the generated wrapper
  paths exposed at the Qsys boundary.
- Functional coverage on:
  - Upload mux ingress arbitration (in0 = data, in1 = SC, in2 = idle).
  - Histogram bank ping-pong + ARB CSR mode transitions.
  - SC packet round-trip (sc_downlink_cdc_bridge handoff timing).
  - mts_preprocessor `hit_type1_ts` conduit timestamp delivery to
    histogram_statistics_v2 (the IP-level interface added by commit
    eb67302 + merged into master per
    `mutrig_timestamp_processor/mts_processor_hw.tcl` 26.3.5.0518).

## Required execution modes (dv-workflow rule 8)

- `isolated` - default; each case in its own fresh DUT timeframe.
- `bucket_frame` - all cases in a bucket in ID order, single continuous
  timeframe, no restart.
- `all_buckets_frame` - every sign-off bucket in bucket order, single
  continuous timeframe.

Merged code-coverage totals are reported per mode and never overwrite
each other; see [DV_COV.md](DV_COV.md).

## Sign-off gates

1. `isolated` UCDBs for every case in [DV_BASIC.md](DV_BASIC.md) +
   [DV_ERROR.md](DV_ERROR.md) reach pass.
2. `bucket_frame` runs for B and X buckets pass with merged coverage
   tabulated.
3. `all_buckets_frame` reaches the closure stop without UVM_ERROR /
   UVM_FATAL.
4. [BUG_HISTORY.md](BUG_HISTORY.md) reaches `fixed` or
   `deferred-with-blocking-reason` for every recorded R / I bug.
5. `dv_bucket_format_check.py` passes on every bucket file.

## Provenance

Sister doc set on the FEB v3 source-of-truth system:
`firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/doc/`
(legacy scenarios live there pre-restructure). The 260518-feb-ok system
is a fresh dated cut per the `daily-worktree-convention`.
