# Phase 4.5 Sweep Fail Analysis

## Summary

The dual-port on-board sweep at commit `47efa242` has 25 PASS rows and
7 FAIL rows. The 7 FAIL rows split into three root-cause families: histogram
ingress saturation at high effective rate, run-control command coherence
where the row never reaches RUNNING, and arb lane-mask programming through
the wrong CSR word.

All 7 FAIL rows PASS in the local compact sim evidence from
`6029646e/local`. The failures are therefore board/integration/sweep
programming divergences, not sim-reproduced RTL failures in the current
compact harness.

## Description

This report is trace-level analysis of the current, non-`.bak` board evidence
under:

```text
firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/sweep_evidence/<row_id>/
```

and the local sim evidence under:

```text
firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/<row_id>/
```

The 32-row plan was exported from `scripts/cotest/phase4_5_sweep.py` with
`--export-plan`. The script was read only; it was not edited.

The board counter schema does not expose `SELECTED_COUNT` by name. For board
stage isolation this report uses the per-lane `egress_emu_hits` delta as the
selected-output equivalent. The board MTS schema exposes `status_control`,
`total_hits`, `discard_hits`, and `expected_latency`; it does not expose named
`PORT_STATUS`, `PROCESSOR_STATUS`, accept-count, or hit-type valid-toggle
fields.

Every failing board row has `hist_bin.csv` sum zero and no nonzero channel
bins. That means the current board sweep does not provide retained per-channel
localization after END_RUN. This matches the residual noted in
`DUALPORT_HISTOGRAM_SIGNOFF.md`: per-row bin evidence must be sampled while
RUNNING on this image.

Failure categories used below:

| Category | Meaning |
|---|---|
| (a) | Mode dispatch CSR mismatch |
| (b) | Saturation knee |
| (c) | Channel-mask routing |
| (d) | Bank-1 path issue |
| (e) | Sanity-negative verdict bug |
| (f) | Other |

Table of contents:

- [p45_017_all_lanes_default_0x1000_dir](#p45_017_all_lanes_default_0x1000_dir)
- [p45_018_all_lanes_default_0x2000_dir](#p45_018_all_lanes_default_0x2000_dir)
- [p45_019_all_lanes_default_0x4000_dir](#p45_019_all_lanes_default_0x4000_dir)
- [p45_020_all_lanes_default_0x8000_dir](#p45_020_all_lanes_default_0x8000_dir)
- [p45_025_lane_none_default_default_dir](#p45_025_lane_none_default_default_dir)
- [p45_030_lane_evens_default_0x2000_dir](#p45_030_lane_evens_default_0x2000_dir)
- [p45_031_lane_none_0x00000001_default_dir](#p45_031_lane_none_0x00000001_default_dir)

## File Structure

- This report:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/PHASE4_5_SWEEP_FAIL_ANALYSIS.md`
- Topology context:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/DUALPORT_HISTOGRAM_SIGNOFF.md`
- Board evidence:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/sweep_evidence/<row_id>/`
- Sim evidence:
  `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/<row_id>/`
- Plan source:
  `scripts/cotest/phase4_5_sweep.py`

## Usage

Read each row from A through F:

A. Expected behavior from the exported sweep plan.

B. Board observation from `verdict.json`, `counters.json`, `hist_bin.csv`, and
`tool_calls.log`.

C. Sim cross-reference for the same `row_id`.

D. Stage isolation using deltas from pre/post board snapshots.

E. Root-cause hypothesis and category.

F. Concrete remediation.

The key stage-isolation rule is: if arb and MTS deltas match
`histogram_statistics.TOTAL_HITS`, the traffic reached histogram ingress. If
`DROPPED_HITS` rises with `PORT_STATUS[23:16] == 0xff`, the drop is in
histogram ingress buffering rather than the arb or MTS stages. If arb deltas
are zero, the drop point is upstream of `arb_hit_type0_supercore`.

## Test

The analyzed FAIL rows are:

| row_id | lane_mask | channel_mask | rate | mode | board failure_mode | category |
|---|---:|---:|---:|---:|---|---|
| `p45_017_all_lanes_default_0x1000_dir` | `0xFF` | `0xFFFFFFFF` | `0x1000` | `00` | `HIST_DROPPED_HITS_NONZERO` | (b) |
| `p45_018_all_lanes_default_0x2000_dir` | `0xFF` | `0xFFFFFFFF` | `0x2000` | `00` | `TOTAL_HITS_ZERO` | (f) |
| `p45_019_all_lanes_default_0x4000_dir` | `0xFF` | `0xFFFFFFFF` | `0x4000` | `00` | `HIST_DROPPED_HITS_NONZERO` | (b) |
| `p45_020_all_lanes_default_0x8000_dir` | `0xFF` | `0xFFFFFFFF` | `0x8000` | `00` | `TOTAL_HITS_ZERO` | (f) |
| `p45_025_lane_none_default_default_dir` | `0x00` | `0xFFFFFFFF` | `0x0800` | `00` | `TOTAL_HITS_NOT_EXPECTED_FOR_SANITY_NEG` | (f) |
| `p45_030_lane_evens_default_0x2000_dir` | `0x55` | `0xFFFFFFFF` | `0x2000` | `00` | `HIST_DROPPED_HITS_NONZERO` | (b) |
| `p45_031_lane_none_0x00000001_default_dir` | `0x00` | `0x00000001` | `0x0800` | `00` | `TOTAL_HITS_NOT_EXPECTED_FOR_SANITY_NEG` | (f) |

All 7 rows have sim verdict `PASS` in local `sim_evidence`.

## Row Analyses

### p45_017_all_lanes_default_0x1000_dir

#### A. What Was Expected

Plan row: `lane_mask=0xFF`, `channel_mask=0xFFFFFFFF`, `rate_88fp=0x1000`,
`hit_mode=00`.

Expected behavior: section 4.5.2 rate `0x1000`; ratio to previous rate row
approximately doubles until the throughput knee.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 504756832 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 13809340 |
| `run_number_writeback_ok` | true |
| `failure_mode` | `HIST_DROPPED_HITS_NONZERO` |

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 63094604 | 63094604 | 0 |
| 1 | 63094604 | 63094604 | 0 |
| 2 | 63094604 | 63094604 | 0 |
| 3 | 63094604 | 63094604 | 0 |
| 4 | 63094604 | 63094604 | 0 |
| 5 | 63094604 | 63094604 | 0 |
| 6 | 63094604 | 63094604 | 0 |
| 7 | 63094604 | 63094604 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 252378416 | 0 |
| 1 | `0x20000010` | 252378416 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0xff00ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0xff` |
| `COAL_STATUS` | `0x00000200` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

Ring-buffer counters are not root-cause evidence for this row. The histogram
already accepted 504756832 hits and recorded drops before any downstream
ring-buffer interpretation matters.

`tool_calls.log` has no nonzero `RC:` entries and no retry attempts.

#### C. Cross-Reference Sim

Sim verdict: PASS. `sim_total_hits=1649912`, `sim_hist_bin_sum=1649912`, and
the sim CSV has all 32 bins nonzero, roughly 51560 per bin.

The compact sim does not reproduce the board failure. It also does not
instantiate the MTS preprocessor and runs a much shorter compact traffic
window than the 4 second board row.

#### D. Stage Isolation

The arb sum, MTS sum, and histogram total all match at 504756832 accepted
hits. `arb drops_emu` and `MTS discard_hits` stay zero. The first failing
stage is therefore inside `histogram_statistics_v2` ingress buffering:
`DROPPED_HITS` rises by 13809340 and `PORT_STATUS[23:16]` saturates at
`0xff`.

This is not a bank-1 wiring failure. Both MTS banks contribute the same
252378416-hit delta.

#### E. Root Cause Hypothesis

Category (b), saturation knee. The board effective rate exceeds the
histogram ingress FIFO or shared histogram service capacity. The coalescing
queue itself is not the first suspect because `COAL_STATUS=0x00000200`
reports a small max queue occupancy and no upper-word overflow count.

#### F. Concrete Remediation

Fix in RTL if this row is required to be lossless: deepen the enabled
`histogram_statistics_v2` ingress FIFO, increase service parallelism, or add a
verified backpressure/throttle point before the histogram bridge.

Fix in test/sim before closing: extend the compact sim to a board-equivalent
stress run with MTS and dual-port histogram present, or explicitly mark
`0x1000` as the measured saturation onset in the sweep plan.

### p45_018_all_lanes_default_0x2000_dir

#### A. What Was Expected

Plan row: `lane_mask=0xFF`, `channel_mask=0xFFFFFFFF`, `rate_88fp=0x2000`,
`hit_mode=00`.

Expected behavior: section 4.5.2 rate `0x2000`; ratio to previous rate row
approximately doubles until the throughput knee. Even at a saturation knee,
the board should produce nonzero accepted hits unless the source never runs.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 0 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 0 |
| `run_number_writeback_ok` | true |
| `failure_mode` | `TOTAL_HITS_ZERO` |

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 0 | 0 | 0 |
| 1 | 0 | 0 | 0 |
| 2 | 0 | 0 | 0 |
| 3 | 0 | 0 | 0 |
| 4 | 0 | 0 | 0 |
| 5 | 0 | 0 | 0 |
| 6 | 0 | 0 | 0 |
| 7 | 0 | 0 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 0 | 0 |
| 1 | `0x20000010` | 0 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0x000000ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0x00` |
| `COAL_STATUS` | `0x00000000` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

Run-control trace:

| Trace item | Value |
|---|---|
| `cmd_traces` RUNNING write | `cmd=0x12`, `word=0x00000012` |
| immediate `LAST_CMD` after RUNNING write | `0x00000013` |
| log FIFO run commands | `[16, 19]` |

`tool_calls.log` has no nonzero `RC:` entries and no retry attempts.

#### C. Cross-Reference Sim

Sim verdict: PASS. `sim_total_hits=1649912`, `sim_hist_bin_sum=1649912`, and
all 32 sim bins are nonzero.

#### D. Stage Isolation

No arb counter moves, no MTS counter moves, and no histogram counter moves.
The drop point is upstream of `arb_hit_type0_supercore`. The tool trace shows
the board did not latch RUNNING for this row: after writing `0x12`, `LAST_CMD`
already reports `0x13`, and the log FIFO lacks a RUNNING command entry.

#### E. Root Cause Hypothesis

Category (f), run-control/SC command coherence. This row did not fail because
of datapath saturation; it failed because the board source path never entered
the RUNNING traffic interval.

#### F. Concrete Remediation

Fix in script: after the RUNNING write, require `LAST_CMD == 0x12` and a
RUNNING state/log observation before starting the row timer. If the readback
shows `0x13` or a stale command, retry RUNNING and record the retry as a row
warning. Also drain or snapshot the run-control log before each row so stale
termination entries cannot be mistaken for current-row state.

Fix in RTL only if the hardened script still observes this signature: inspect
`run_control_mgmt` or the SC hub command path for stale `LAST_CMD` readback or
write ordering hazards.

### p45_019_all_lanes_default_0x4000_dir

#### A. What Was Expected

Plan row: `lane_mask=0xFF`, `channel_mask=0xFFFFFFFF`, `rate_88fp=0x4000`,
`hit_mode=00`.

Expected behavior: section 4.5.2 rate `0x4000`; ratio to previous rate row
approximately doubles until the throughput knee.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 670029536 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 162926609 |
| `run_number_writeback_ok` | false |
| `failure_mode` | `HIST_DROPPED_HITS_NONZERO` |

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 83753692 | 83753692 | 0 |
| 1 | 83753692 | 83753692 | 0 |
| 2 | 83753692 | 83753692 | 0 |
| 3 | 83753692 | 83753692 | 0 |
| 4 | 83753692 | 83753692 | 0 |
| 5 | 83753692 | 83753692 | 0 |
| 6 | 83753692 | 83753692 | 0 |
| 7 | 83753692 | 83753692 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 335014768 | 0 |
| 1 | `0x20000010` | 335014768 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0xff00ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0xff` |
| `COAL_STATUS` | `0x00000200` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

Run-control trace shows stale readback on PREP (`LAST_CMD=0x13` after the
`0x10` write), but RUNNING later latches (`LAST_CMD=0x12`) and traffic flows.
`tool_calls.log` has no nonzero `RC:` entries and no retry attempts.

#### C. Cross-Reference Sim

Sim verdict: PASS. `sim_total_hits=1649912`, `sim_hist_bin_sum=1649912`, and
all 32 sim bins are nonzero.

#### D. Stage Isolation

The arb sum, MTS sum, and histogram total all match at 670029536 accepted
hits. Arb drops and MTS discards stay zero. Histogram `DROPPED_HITS` rises by
162926609 while `PORT_STATUS[23:16]` saturates at `0xff`.

Both MTS banks contribute exactly 335014768 hits, so this is not a bank-1 path
loss.

#### E. Root Cause Hypothesis

Category (b), saturation knee. The histogram ingress stage is overdriven. The
false `run_number_writeback_ok` is secondary SC/run-control readback evidence,
not the primary datapath drop, because traffic did flow.

#### F. Concrete Remediation

Fix in RTL or test expectation as for row `p45_017`. Additionally, harden the
sweep script so a stale PREP readback or failed run-number writeback marks the
row as "control-plane suspect" instead of being mixed into datapath evidence.

### p45_020_all_lanes_default_0x8000_dir

#### A. What Was Expected

Plan row: `lane_mask=0xFF`, `channel_mask=0xFFFFFFFF`, `rate_88fp=0x8000`,
`hit_mode=00`.

Expected behavior: section 4.5.2 rate `0x8000`; ratio to previous rate row
approximately doubles until the throughput knee. Nonzero accepted hits are
still expected if RUNNING is entered.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 0 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 0 |
| `run_number_writeback_ok` | true |
| `failure_mode` | `TOTAL_HITS_ZERO` |

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 0 | 0 | 0 |
| 1 | 0 | 0 | 0 |
| 2 | 0 | 0 | 0 |
| 3 | 0 | 0 | 0 |
| 4 | 0 | 0 | 0 |
| 5 | 0 | 0 | 0 |
| 6 | 0 | 0 | 0 |
| 7 | 0 | 0 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 0 | 0 |
| 1 | `0x20000010` | 0 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0x000000ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0x00` |
| `COAL_STATUS` | `0x00000000` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

Run-control trace:

| Trace item | Value |
|---|---|
| `cmd_traces` RUNNING write | `cmd=0x12`, `word=0x00000012` |
| immediate `LAST_CMD` after RUNNING write | `0x00000013` |
| log FIFO run commands | `[16, 19]` |
| nonzero tool return codes | one `RC: 2`, retried once |

#### C. Cross-Reference Sim

Sim verdict: PASS. `sim_total_hits=1649912`, `sim_hist_bin_sum=1649912`, and
all 32 sim bins are nonzero.

#### D. Stage Isolation

No traffic reaches the arb stage. As with row `p45_018`, the trace points to
the source/run-control boundary, not to histogram saturation.

#### E. Root Cause Hypothesis

Category (f), run-control/SC command coherence. The row is a zero-hit board
artifact because RUNNING is not observed as latched.

#### F. Concrete Remediation

Same script fix as row `p45_018`: do not start the run timer until RUNNING is
confirmed. Because this row also has one `RC: 2` retry, keep the retry ledger
in the verdict and force a rerun if a control command retry occurs between
PREP and RUNNING.

### p45_025_lane_none_default_default_dir

#### A. What Was Expected

Plan row: `lane_mask=0x00`, `channel_mask=0xFFFFFFFF`, `rate_88fp=0x0800`,
`hit_mode=00`.

Expected behavior: sanity-negative; all lanes blocked, so `TOTAL_HITS == 0`.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 255039040 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 0 |
| `run_number_writeback_ok` | true |
| `failure_mode` | `TOTAL_HITS_NOT_EXPECTED_FOR_SANITY_NEG` |

The lane-mask programming trace is the key observation. The sweep writes
`0x00000000` for every lane, but the readback from each target address is
`0x00100D05`, the arb STATUS word, not a disabled CONTROL value.

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 31879880 | 31879880 | 0 |
| 1 | 31879880 | 31879880 | 0 |
| 2 | 31879880 | 31879880 | 0 |
| 3 | 31879880 | 31879880 | 0 |
| 4 | 31879880 | 31879880 | 0 |
| 5 | 31879880 | 31879880 | 0 |
| 6 | 31879880 | 31879880 | 0 |
| 7 | 31879880 | 31879880 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 127519520 | 0 |
| 1 | `0x20000010` | 127519520 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0x9a00ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0x9a` |
| `COAL_STATUS` | `0x00000100` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

`tool_calls.log` has no nonzero `RC:` entries and no retry attempts.

#### C. Cross-Reference Sim

Sim verdict: PASS. The sim correctly applies the negative lane mask:
`sim_total_hits=0`, `sim_hist_bin_sum=0`, and all sim bins are zero.

#### D. Stage Isolation

Traffic is not dropped. It is admitted by every arb lane, split equally
through both MTS banks, and counted by the histogram. The failed assumption is
the lane-disable programming itself.

#### E. Root Cause Hypothesis

Category (f), arb lane-mask CSR mismatch. This is a sanity-negative symptom,
but not a verdict bug: the verdict correctly fails because `TOTAL_HITS` is
nonzero.

The sweep currently programs `ARB_MODE_OFFSET_W = 0x03`. The arb CSR plan says
word `0x02` is CONTROL and word `0x03` is STATUS. Writes to the STATUS word do
not disable the lane, so all lanes remain in EMU mode.

#### F. Concrete Remediation

Fix in script: change the arb lane-control write offset to CONTROL word
`0x02`, keep STATUS word `0x03` for readback, and decode STATUS bits
`mode[1:0]`/`mode_pending[3:2]` to confirm the live mode.

Also write arb mode after decoded PREP. Source RTL clears `arb_hit_type0`
MODE on stream clear in `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv`, so a
pre-PREP write can be erased before RUNNING.

Fix in topology only if CONTROL word `0x02` writes still do not affect all
per-lane CSR apertures.

### p45_030_lane_evens_default_0x2000_dir

#### A. What Was Expected

Plan row: `lane_mask=0x55`, `channel_mask=0xFFFFFFFF`, `rate_88fp=0x2000`,
`hit_mode=00`.

Expected behavior: even lanes only at high rate; per-lane saturation check.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 666319584 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 162024475 |
| `run_number_writeback_ok` | true |
| `failure_mode` | `HIST_DROPPED_HITS_NONZERO` |

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 83289948 | 83289948 | 0 |
| 1 | 83289948 | 83289948 | 0 |
| 2 | 83289948 | 83289948 | 0 |
| 3 | 83289948 | 83289948 | 0 |
| 4 | 83289948 | 83289948 | 0 |
| 5 | 83289948 | 83289948 | 0 |
| 6 | 83289948 | 83289948 | 0 |
| 7 | 83289948 | 83289948 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 333159792 | 0 |
| 1 | `0x20000010` | 333159792 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0xff00ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0xff` |
| `COAL_STATUS` | `0x00000200` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

`tool_calls.log` has no nonzero `RC:` entries and no retry attempts.

#### C. Cross-Reference Sim

Sim verdict: PASS. `sim_total_hits=824956`, `sim_hist_bin_sum=824956`, and all
32 sim bins are nonzero at about 25780 counts per bin.

The sim total is half of the all-lane compact rows, consistent with the
intended even-lane mask. The board is not respecting that mask.

#### D. Stage Isolation

All eight board lanes move by the same 83289948 hits, even though only lanes
0, 2, 4, and 6 should be admitted. The unintended all-lane effective traffic
then saturates histogram ingress: `DROPPED_HITS=162024475` and
`PORT_STATUS[23:16]=0xff`.

Both MTS banks contribute equally, so this is not a bank-1 loss.

#### E. Root Cause Hypothesis

Category (b), saturation knee, with the lane-mask CSR bug as the trigger that
doubles the intended high-rate load. The direct failure predicate is
histogram drops, but the row is overdriven because odd lanes were not disabled.

#### F. Concrete Remediation

First fix the arb lane-mask CONTROL write as described for row `p45_025` and
rerun this row. If row `p45_030` still drops with only even lanes active, then
the residual is a true four-lane high-rate histogram saturation point and
should be handled by histogram FIFO/service changes or by documenting the
expected knee.

### p45_031_lane_none_0x00000001_default_dir

#### A. What Was Expected

Plan row: `lane_mask=0x00`, `channel_mask=0x00000001`, `rate_88fp=0x0800`,
`hit_mode=00`.

Expected behavior: sanity-negative; lane mask supersedes channel mask, so
`TOTAL_HITS == 0`.

#### B. What Was Observed

Board verdict:

| Signal | Value |
|---|---:|
| `TOTAL_HITS_CSR13` | 270238464 |
| `hist_bin_sum` | 0 |
| nonzero `hist_bin.csv` bins | none |
| `LAST_INTERVAL_TOTAL_HITS` CSR17 | 0 |
| `DROPPED_HITS` CSR14 | 0 |
| `run_number_writeback_ok` | false |
| `failure_mode` | `TOTAL_HITS_NOT_EXPECTED_FOR_SANITY_NEG` |

All lane-control writes are recorded as `written=0x00000000` and
`readback=0x00100D05`, again reading STATUS at word `0x03` rather than
programming CONTROL at word `0x02`.

Arb selected-output equivalent:

| lane | `egress_emu_hits` delta | `ingress_emu_hits` delta | `drops_emu` delta |
|---:|---:|---:|---:|
| 0 | 33779808 | 33779808 | 0 |
| 1 | 33779808 | 33779808 | 0 |
| 2 | 33779808 | 33779808 | 0 |
| 3 | 33779808 | 33779808 | 0 |
| 4 | 33779808 | 33779808 | 0 |
| 5 | 33779808 | 33779808 | 0 |
| 6 | 33779808 | 33779808 | 0 |
| 7 | 33779808 | 33779808 | 0 |

MTS:

| MTS | `status_control` | `total_hits` delta | `discard_hits` delta |
|---:|---:|---:|---:|
| 0 | `0x20000010` | 135119232 | 0 |
| 1 | `0x20000010` | 135119232 | 0 |

Histogram:

| Register | Value |
|---|---:|
| `PORT_STATUS` | `0x9a00ff` |
| decoded empty mask | `0xff` |
| decoded max FIFO level | `0x9a` |
| `COAL_STATUS` | `0x00000200` |
| `UNDERFLOW` | 0 |
| `OVERFLOW` | 0 |

Run-control trace has `run_number_writeback_ok=false`, but RUNNING does latch
and traffic moves. `tool_calls.log` has no nonzero `RC:` entries and no retry
attempts.

#### C. Cross-Reference Sim

Sim verdict: PASS. The sim correctly applies the negative lane mask:
`sim_total_hits=0`, `sim_hist_bin_sum=0`, and all sim bins are zero.

#### D. Stage Isolation

Every arb lane emits traffic, both MTS banks count traffic, and the histogram
accepts traffic. The stage isolation is the same as row `p45_025`: the lane
disable never takes effect.

The channel mask cannot be validated from this board row because
`hist_bin.csv` is all zero after END_RUN and the lane mask failure dominates
the expected negative predicate.

#### E. Root Cause Hypothesis

Category (f), arb lane-mask CSR mismatch. The verdict is correct; the
programmed negative condition was not actually applied on board.

#### F. Concrete Remediation

Same as row `p45_025`: write CONTROL word `0x02`, read STATUS word `0x03`,
and verify all lane modes after PREP and before RUNNING. After that fix, rerun
both sanity-negative rows and require per-lane arb deltas to stay zero.

## Meta Findings

Common patterns:

| Pattern | Rows | Interpretation |
|---|---|---|
| Histogram ingress saturation | `p45_017`, `p45_019`, `p45_030` | Traffic reaches histogram, arb/MTS drops stay zero, `PORT_STATUS[23:16]` saturates |
| RUNNING not latched | `p45_018`, `p45_020` | Arb/MTS/hist deltas stay zero; `LAST_CMD` reports `0x13` after RUNNING write |
| Lane-mask CSR write mismatch | `p45_025`, `p45_031`; also affects `p45_030` | Sweep writes arb word `0x03` STATUS instead of word `0x02` CONTROL |
| Bank-1 path issue | none | Saturation rows have equal MTS0/MTS1 totals |
| Mode-dispatch CSR mismatch | none of the 7 FAIL rows | Burst/periodic rows are not in the FAIL set |
| Channel-mask routing root cause | not proven | Board bin CSVs are all zero after END_RUN, so channel localization is unavailable |

Sim-board agreement:

- Sim FAIL and board FAIL: 0 of 7.
- Sim PASS and board FAIL: 7 of 7.
- The compact sim is useful for intent checks, but it is not a closure-level
  reproduction of the board failures because it omits MTS and does not stress
  the 4 second board traffic volume.

Important secondary issue: the sweep verdict treats `hist_bin_sum != CSR13` as
a warning, but every failing board row has empty bin CSVs. Channel-mask claims
from this sweep should remain unclosed until the runner samples bins while
RUNNING or preserves the active bank through END_RUN.

## Remediation Plan

1. Fix the arb lane-mask programming first. Change the sweep runner to write
   arb CONTROL word `0x02`, read STATUS word `0x03`, write after PREP, and
   require the live mode bits to match the requested lane mask before RUNNING.
   This directly fixes the two sanity-negative failures and removes the
   overdrive multiplier from `p45_030`.

2. Harden run-control command confirmation. The runner must not start the row
   timer until RUNNING is confirmed by `LAST_CMD == 0x12` and/or a decoded
   RUNNING state/log entry. Rows with stale `LAST_CMD=0x13`, command retries,
   or failed run-number writeback should rerun automatically or be reported as
   control-plane failures, not datapath failures.

3. Re-measure the high-rate knee after the script fixes. If rows `p45_017`,
   `p45_019`, or the repaired even-lane `p45_030` still show
   `DROPPED_HITS_NONZERO`, decide whether the Phase 4.5 contract requires
   lossless operation at that rate. If yes, change RTL around
   `histogram_statistics_v2` ingress FIFO/service capacity or add upstream
   throttling/backpressure. If no, document the knee and adjust the rate-row
   predicates.

4. Extend sim coverage. Add a board-equivalent stress target that includes
   MTS plus dual-port histogram and runs long enough to hit the same FIFO
   pressure. Keep the compact per-row sim as a fast intent check, but do not
   use it as saturation signoff.

5. Fix the histogram-bin evidence timing. Sample bins while RUNNING or preserve
   the active bank through END_RUN so channel-mask and channel-routing rows can
   be evaluated from actual per-channel counts.

## Documentation

Cross-references:

- Board sweep evidence:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/sweep_evidence/`
- Sim evidence:
  `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/`
- Dual-port topology:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/DUALPORT_HISTOGRAM_SIGNOFF.md`
- Prior fail-mode sim diagnosis:
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/PHASE4_5_FAIL_MODE_SIM_DIAG.md`
- Arb CSR contract:
  `misc/arb_hit_type0/doc/RTL_PLAN.md`
- Arb source audit points:
  `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv`,
  `misc/arb_hit_type0/rtl/arb_hit_type0_arbiter.sv`
- Emulator mode dispatch audit point:
  `emulator_mutrig/rtl/frontend/frontend_csr.sv`

Sign-off block:

```text
Generated by codex1 sweep-fail-analysis on 2026-05-12.
Evidence from board commit 47efa242.
Sim evidence from 6029646e/local.
Edited files: PHASE4_5_SWEEP_FAIL_ANALYSIS.md only.
```
