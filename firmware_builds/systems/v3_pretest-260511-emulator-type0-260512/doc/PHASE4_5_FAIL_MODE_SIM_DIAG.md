# Phase 4.5 Fail-Mode Sim Diagnosis

## Summary

Directed source-RTL sims do not reproduce the two live-sweep zero-hit failure signatures from commit `36f71604`. Lane admission is symmetric in sim, and the board-side MUTRIG_FORMAT writes `0x21` and `0x23` still produce type0 traffic in sim.

## Description

The sim baseline uses the tracked `system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm` harness derivative. It instantiates one `emulator_mutrig_qsys_lane` with `BYTE_STREAM_ENABLE=false`, fans its hit_type0 stream to eight `arb_hit_type0` lanes, and counts selected outputs as the histogram-facing observation surface.

The source RTL clears `arb_hit_type0` MODE on decoded PREPARING (`misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv:351`), so the directed tests drive decoded PREP/SYNC first and then write arb MODE before decoded RUNNING. If software writes MODE before the decoded PREPARING pulse on hardware, current source RTL would clear every lane, not only lanes 0/2/3/5/7.

Evidence note: in commit `36f71604`, the burst and periodic mode rows are `p45_021_all_lanes_default_default_burst` and `p45_022_all_lanes_default_default_periodic`. Rows `p45_023` and `p45_024` are lane-mask rows in that commit.

## File Structure

- `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm/phase4_5_fail_mode_if.sv`
- `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm/phase4_5_fail_mode_tb.sv`
- `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm/sequences/lane_admit_asymmetry_seq.sv`
- `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm/sequences/mode_dispatch_seq.sv`
- `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/REPORT/lane_admit_asymmetry/`
- `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/REPORT/mode_dispatch/`

## Usage

```sh
cd firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm
make run_LANE_ASYM
make run_MODE_DISPATCH
```

## Test

### Failure A: Lane-Admit Asymmetry

| lane | sim SELECTED_COUNT | sim hit_count | board total_hits (`36f71604`) |
|---:|---:|---:|---:|
| 0 | 7936 | 7936 | 0 |
| 1 | 7936 | 7936 | 2200990 |
| 2 | 7936 | 7936 | 0 |
| 3 | 7936 | 7936 | 0 |
| 4 | 7936 | 7936 | 8777371 |
| 5 | 7936 | 7936 | 0 |
| 6 | 7936 | 7936 | 7859448 |
| 7 | 7936 | 7936 | 0 |

Verdict: sim does not agree with the live sweep. The lane-asymmetry zero-hit pattern is not reproduced by the source RTL fanout plus arb admission path. Treat this as silicon-only or integration-only until proven otherwise: CSR address decode, readout timing, generated Qsys lane wiring, run-control reset ordering, or clock-domain race.

Source RTL audit points if the failure later becomes reproducible in sim:

- `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv:351`: decoded PREPARING clears MODE back to default REAL.
- `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv:394`: MODE write decode at CSR address `0x02`.
- `misc/arb_hit_type0/rtl/arb_hit_type0_arbiter.sv:162`: REAL/EMU/MIX_RR grant select.

### Failure B: Mode Dispatch

| mode | board MUTRIG_FORMAT | sim tx_count | sim hist_total | sim dist_shape | board total_hits (`36f71604`) |
|---|---:|---:|---:|---|---:|
| direct control | 0x20 | 7936 | 63488 | fixed_cluster_ch0_3 | 8777371 (`p45_010` lane-4 control) |
| burst row | 0x21 | 7936 | 63488 | fixed_cluster_ch0_3 | 0 (`p45_021`) |
| periodic row | 0x23 | 7936 | 63488 | fixed_cluster_ch0_3 | 0 (`p45_022`) |

Verdict for the zero-hit failure: sim does not agree with the live sweep. MUTRIG_FORMAT writes `0x21` and `0x23` do not suppress source-RTL type0 output, so the observed hardware zero is silicon-only or integration-only for the zero-hit symptom.

There is a separate mode-semantics mismatch: current source RTL does not decode burst or periodic behavior from MUTRIG_FORMAT. `frontend_csr.sv:277` through `frontend_csr.sv:280` decode the SIGNAL CSR, while `frontend_csr.sv:285` through `frontend_csr.sv:289` decode MUTRIG_FORMAT as short/gen-idle/tx-mode/type0-enable format bits. With SIGNAL left at zero in the committed sweep, all three sim rows use the same internal random fixed-cluster path in `frontend_trigger_engine.sv:278` through `frontend_trigger_engine.sv:284`.

## Documentation

The two directed sims passed under Questa One 2026.1 using the harness Make targets:

- `make run_LANE_ASYM`
- `make run_MODE_DISPATCH`

The transcript logs are saved in the corresponding REPORT directories. The comparison uses committed sweep evidence from `36f71604` via `git show`, not the locally modified `sweep_evidence/` working tree.
