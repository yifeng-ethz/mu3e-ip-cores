# Phase 4.5 Lane-Admit Asymmetry Directed Sim

## Summary

- Verdict: PASS
- Window: 1 ms at 125 MHz after decoded RUNNING.
- Emulator MUTRIG_FORMAT: 0x20.
- Expected lane spread: within 10 percent.
- Observed selected-count span: min=7936 max=7936.

## Description

The test instantiates one BYTE_STREAM_ENABLE=false emulator_mutrig_qsys_lane and fans its hit_type0 stream to eight arb_hit_type0 lanes. For each row, the decoded PREP/SYNC reset phase is driven first, then one arb lane is set to EMU while all others remain REAL before decoded RUNNING.

## File Structure

- `lane_NN_counts.json`: per-lane selected counter and payload-channel bins.
- `summary.md`: pass/fail table and spread check.

## Usage

Run from `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm`:

```sh
make run_LANE_ASYM
```

## Test

| lane | SELECTED_COUNT | hit_count |
|---:|---:|---:|
| 0 | 7936 | 7936 |
| 1 | 7936 | 7936 |
| 2 | 7936 | 7936 |
| 3 | 7936 | 7936 |
| 4 | 7936 | 7936 |
| 5 | 7936 | 7936 |
| 6 | 7936 | 7936 |
| 7 | 7936 | 7936 |

## Documentation

This is a sim-only baseline for the Phase 4.5 live-sweep lane-isolation rows p45_006 through p45_013 from commit 36f71604.
