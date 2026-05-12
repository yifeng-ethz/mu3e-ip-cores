# Phase 4.5 Mode-Dispatch Directed Sim

## Summary

- Verdict: PASS
- Window: 1 ms at 125 MHz after decoded RUNNING.
- Admitted lanes: all eight arb_hit_type0 lanes in EMU mode.
- Channel mask model: all payload channels counted.

## Description

The test reproduces the board-side MUTRIG_FORMAT writes 0x20, 0x21, and 0x23 against the current emulator_mutrig CSR map. The decoded PREP/SYNC reset phase is driven first, then all arb lanes are set to EMU before decoded RUNNING. In this RTL, those MUTRIG_FORMAT bits are format controls, while signal random/periodic dispatch is controlled by the SIGNAL CSR at address 0x08.

## File Structure

- `mode_NN_counts.json`: per-mode tx count, selected total, and payload-channel bins.
- `summary.md`: pass/fail table and shape classification.

## Usage

Run from `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/uvm`:

```sh
make run_MODE_DISPATCH
```

## Test

| mode | MUTRIG_FORMAT | tx_count | hist_total | dist_shape |
|---|---:|---:|---:|---|
| 0x00 direct | 0x20 | 7936 | 63488 | fixed_cluster_ch0_3 |
| 0x01 burst-board-write | 0x21 | 7936 | 63488 | fixed_cluster_ch0_3 |
| 0x11 periodic-board-write | 0x23 | 7936 | 63488 | fixed_cluster_ch0_3 |

## Documentation

This is a sim-only baseline for the Phase 4.5 live-sweep mode rows p45_023 and p45_024 from commit 36f71604, plus direct 0x20 as the control mode.
