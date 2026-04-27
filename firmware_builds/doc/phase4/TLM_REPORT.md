# Phase 4 TLM and RTL Simulation Report

Date: 2026-04-25

This report records the executable Phase 4 models, the current RTL simulation
evidence, and the specific discrepancy that still needs a refreshed injector
latency RTL run.

## Commands

Standalone HDL/TLM simulation:

```bash
bash firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/run_phase4_tlm.sh
```

Queue/MuTRiG TLM generation and DISLIN rendering:

```bash
bash firmware_builds/systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh
```

Current RTL datapath refresh command shape:

```bash
TB_DP_VSIM_ARGS='+TB_DP_PRE_RBCAM_MEAS +TB_DP_USE_PERIODIC_INJECTOR +TB_DP_INJECT_MODE=2 +TB_DP_INJECT_PERIOD=1250 +TB_DP_INJECT_HIGH=5 +TB_DP_RUN_CYCLES=625000 +TB_DP_SHORT_MODE=1 +TB_DP_HIT_RATE=0 +TB_DP_NOISE_RATE=0 +TB_DP_REPORT_DIR=/tmp/phase4_rtl_inject_refresh' \
  bash firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
```

The existing integration script
[`firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_hist_rate_sweep.sh`](../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_hist_rate_sweep.sh)
already uses `TB_DP_USE_PERIODIC_INJECTOR`, `TB_DP_INJECT_MODE=2`,
`TB_DP_SHORT_MODE=1`, and zero background hit rate for calibrated periodic
injection sweeps.

## HDL/TLM Result

Source:
[`tlm/phase4_latency_tlm.sv`](tlm/phase4_latency_tlm.sv)

Run log:
[`artifacts/phase4_tlm_run.log`](artifacts/phase4_tlm_run.log)

The HDL/TLM run used Questa Sim 2026.1_1 and completed with:

```text
PHASE4_TLM_DONE ... latency_total=249211
Errors: 0, Warnings: 0
```

Generated TLM artifacts:

| Artifact | Contents |
|---|---|
| [`artifacts/phase4_tlm_latency_hist.csv`](artifacts/phase4_tlm_latency_hist.csv) | short-frame latency histogram for `rate_word=0x0800` |
| [`artifacts/phase4_tlm_rate_sweep.csv`](artifacts/phase4_tlm_rate_sweep.csv) | generated/accepted/backlog rows for `0x0100..0x8000` |
| [`artifacts/phase4_tlm_summary.txt`](artifacts/phase4_tlm_summary.txt) | model constants |

TLM latency summary:

| Metric | Cycles |
|---|---:|
| minimum | 8 |
| p50 | 468 |
| p90 | 832 |
| p99 | 913 |
| maximum | 927 |

TLM rate summary:

| Rate word | Accepted rate |
|---:|---:|
| `0x0100` | 24.435938 Mhit/s |
| `0x0200` | 48.919531 Mhit/s |
| `0x0400` | 97.757031 Mhit/s |
| `0x0800` | 195.286719 Mhit/s |
| `0x1000` | 200.000000 Mhit/s |
| `0x2000` | 200.000000 Mhit/s |
| `0x4000` | 200.000000 Mhit/s |
| `0x8000` | 200.000000 Mhit/s |

The cap is now the physical `25 Mhit/s * 8 MuTRiG` limit. `0x0800` is below
the cap; clipping begins at `0x1000`.

## Queue and MuTRiG TLM

Source:
[`scripts/phase4_queue_tlm.py`](scripts/phase4_queue_tlm.py)

Generated artifacts:

| Artifact | Contents |
|---|---|
| [`artifacts/phase4_physical_rate_limits.csv`](artifacts/phase4_physical_rate_limits.csv) | physical cap and service-rate constants |
| [`artifacts/phase4_queue_sweep.csv`](artifacts/phase4_queue_sweep.csv) | deterministic coalescing-queue simulations over depth, rate, and traffic mode |
| [`artifacts/phase4_queue_depth_regions.csv`](artifacts/phase4_queue_depth_regions.csv) | 5%, 1%, and 1 ppm depth regions |
| [`artifacts/phase4_mutrig_latency_model.csv`](artifacts/phase4_mutrig_latency_model.csv) | injection-offset latency envelope for short and long frames |

The queue model follows the RTL coalescing contract in
[`histogram_statistics/rtl/coalescing_queue.vhd`](../../../histogram_statistics/rtl/coalescing_queue.vhd):
new tags allocate queue entries, repeated tags increment a saturating
`kick_count`, and full-queue new tags overflow. At the 200 Mhit/s target, depth
8 is sufficient only for a truly local 8-channel physical cluster; iid,
roaming-cluster, mixed, and all-channel injection modes need depth 256 for the
1 ppm no-drop region.

The MuTRiG timing model is tied to the source RTL constants and behavior in
[`emulator_mutrig/rtl/emulator_mutrig_pkg.sv`](../../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv),
[`emulator_mutrig/rtl/hit_generator.sv`](../../../emulator_mutrig/rtl/hit_generator.sv),
[`emulator_mutrig/rtl/emulator_mutrig.sv`](../../../emulator_mutrig/rtl/emulator_mutrig.sv),
and [`emulator_mutrig/rtl/frame_assembler.sv`](../../../emulator_mutrig/rtl/frame_assembler.sv).
For `FRAME_INTERVAL_SHORT=910`, the unsynchronized injection-mode envelope
spans 0 to 1 frame at low rate and 0 to 2 frames at saturation.

## RTL Simulation Evidence

Source directory:
[`inputs/rtl_ts_soak_exact5k_stable/`](inputs/rtl_ts_soak_exact5k_stable/)

Relevant files:

| Artifact | Contents |
|---|---|
| [`inputs/rtl_ts_soak_exact5k_stable/run.log`](inputs/rtl_ts_soak_exact5k_stable/run.log) | RTL integration-simulation transcript |
| [`artifacts/phase4_rtl_latency_hist.csv`](artifacts/phase4_rtl_latency_hist.csv) | copied RTL latency histogram used for plotting |

The RTL run reports:

```text
Results: 4 PASSED, 0 FAILED
Errors: 0, Warnings: 34, Suppressed Warnings: 2
```

RTL measured datapath counters:

| Quantity | Value |
|---|---:|
| accepted type1 words | 2432 |
| pre-RBCAM rate histogram total | 2432 |
| active rate bins | 256 |
| rate histogram dropped/under/over | 0 / 0 / 0 |
| latency histogram total | 1381 |
| latency histogram dropped/under/over | 0 / 0 / 0 |

RTL latency summary:

| Metric | Cycles |
|---|---:|
| minimum | 476 |
| p50 | 865 |
| p90 | 1252 |
| p99 | 1580 |
| maximum | 1589 |

This RTL latency shape is not accepted as the Phase 4 short-frame reference.
With `TB_DP_SHORT_MODE=1`, the model support should be about one 910-cycle
frame at low rate and at most two frames only when injection-mode queueing is
being intentionally driven near the 25 Mhit/s per-MuTRiG limit. The old
histogram has a p99 of 1580 cycles without the required offset-sweep setup, so
it is treated as stale/incorrect evidence for this question.

## Plots

![Phase 4 dispatch latency shape](artifacts/phase4_latency_tlm_vs_rtl.png)

![Phase 4 queue depth regions](artifacts/phase4_queue_depth_regions.png)

![MuTRiG injection latency envelope](artifacts/phase4_mutrig_latency_model.png)

DISLIN 11.5.2 produced PNG and SVG outputs with `Warnings: 0`:

- [`artifacts/phase4_dislin_png.log`](artifacts/phase4_dislin_png.log)
- [`artifacts/phase4_dislin_svg.log`](artifacts/phase4_dislin_svg.log)
