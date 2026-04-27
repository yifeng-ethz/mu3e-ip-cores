# Phase 4 Math Report

Date: 2026-04-25

This report defines the Phase 4 model quantities used by the CSV artifacts and
DISLIN plots. Modeled quantities are kept separate from RTL simulation and
board measurements.

## Physical Limits

| Quantity | Value | Meaning |
|---|---:|---|
| MuTRiG wire limit | 25 Mhit/s | physical maximum per MuTRiG short-hit stream |
| one datapath | 100 Mhit/s | `25 Mhit/s * 4 MuTRiG` |
| histogram input | 200 Mhit/s | two datapaths, `25 Mhit/s * 8 MuTRiG` |
| histogram queue-element service | 78.125 M queue-elements/s | one bin update every 2 cycles at 156.25 MHz |
| required coalescing at 200 Mhit/s | 2.56 hits/element | `200 / 78.125` |

The histogram acceptance model therefore clips at 200 Mhit/s, not at the old
136.718750 Mhit/s reference. The old board sweep is retained as evidence, but
it is now interpreted as early clipping in the tested image.

## Generator Model

The standalone HDL/TLM rate generator uses the same sweep labels as the board
report:

```text
p_gen(R) = min(5 * R, 65535) / 65536
lambda_gen(R) = 8 * 156.25 MHz * p_gen(R)
lambda_acc(R) = min(lambda_gen(R), 200 Mhit/s)
```

At `0x0800`, the modeled offered rate is about 195.3 Mhit/s and should not yet
clip. At `0x1000` and above, it clips at the physical 8-MuTRiG limit.

## Coalescing Queue Model

The queue model follows
[`histogram_statistics/rtl/coalescing_queue.vhd`](../../../histogram_statistics/rtl/coalescing_queue.vhd):

- each element has a bin tag;
- a hit to an already queued tag increments that tag's `kick_count`;
- a hit to a new tag enqueues one element if there is room;
- overflow occurs only when a new tag arrives while the queue is full, or when
  `kick_count` saturates.

For a full backpressured queue with active tag support `M` and queue depth `K`,
the new-tag drop probability lower bound is:

```text
P_drop >= (M - K) / M
K_required(epsilon) = ceil(M * (1 - epsilon))
```

This bound explains why a fully random 256-channel dark-count field requires a
near-256 queue for ppm-level loss, while a local 8-channel physical cluster can
run at 200 Mhit/s with depth 8 if it truly stays local.

## Queue Depth Regions

The executable model is
[`scripts/phase4_queue_tlm.py`](scripts/phase4_queue_tlm.py), with raw output in:

- [`artifacts/phase4_queue_sweep.csv`](artifacts/phase4_queue_sweep.csv)
- [`artifacts/phase4_queue_depth_regions.csv`](artifacts/phase4_queue_depth_regions.csv)
- [`artifacts/phase4_physical_rate_limits.csv`](artifacts/phase4_physical_rate_limits.csv)

At 200 Mhit/s, the required depths are:

| Traffic mode | 5% region | 1% region | 1 ppm region |
|---|---:|---:|---:|
| iid over 256 bins | 244 | 254 | 256 |
| local physical cluster, 8 bins | 8 | 8 | 8 |
| roaming cluster-8 over 256 bins | 244 | 254 | 256 |
| 50/50 iid plus cluster-8 | 244 | 254 | 256 |
| all-256 injection burst | 256 | 256 | 256 |

![Phase 4 queue depth regions](artifacts/phase4_queue_depth_regions.png)

## MuTRiG Latency Model

The MuTRiG timing model is derived from the source RTL:

- [`emulator_mutrig_pkg.sv`](../../../emulator_mutrig/rtl/emulator_mutrig_pkg.sv)
  defines 32 channels per MuTRiG, 8 emulator lanes, `FRAME_INTERVAL_SHORT=910`,
  `FRAME_INTERVAL_LONG=1550`, and `RAW_FIFO_DEPTH=256`;
- [`hit_generator.sv`](../../../emulator_mutrig/rtl/hit_generator.sv) emits at most
  one candidate per active clock into a lane-local L2 FIFO, supports
  `HIT_MODE_POISSON_IID`, `HIT_MODE_PERIODIC`, cluster replay, and masked
  trigger injection;
- [`emulator_mutrig.sv`](../../../emulator_mutrig/rtl/emulator_mutrig.sv) gates
  frame starts from the frame interval counter and wires the injection pulses
  into the hit generator;
- [`frame_assembler.sv`](../../../emulator_mutrig/rtl/frame_assembler.sv) sends one
  byte per cycle and packs short hits in the fast frame.

For injection mode 2, where the injection pulse is not synchronized to the
MuTRiG frame mark, the model uses:

```text
wait_to_next_frame = FRAME_INTERVAL - offset
rho = min(rate_per_mutrig, 25 Mhit/s) / 25 Mhit/s
latency_max = pipe + wait_to_next_frame * (1 + rho)
```

Thus a single-channel, low-rate injection sweep spans about 0 to 1 short frame,
and saturation can grow the maximum envelope to about 0 to 2 short frames due
to L2 FIFO queueing behind the wire-speed limit.

![MuTRiG injection latency model](artifacts/phase4_mutrig_latency_model.png)

## Numerical Checks

From [`artifacts/phase4_summary.json`](artifacts/phase4_summary.json):

| Quantity | Value |
|---|---:|
| TLM latency total | 249211 |
| TLM latency min / p50 / p90 / p99 / max | 8 / 468 / 832 / 913 / 927 cycles |
| RTL latency total | 1381 |
| RTL latency min / p50 / p90 / p99 / max | 476 / 865 / 1252 / 1580 / 1589 cycles |
| TLM accepted rate at `0x0800` | 195.286719 Mhit/s |
| TLM accepted rate at `0x1000` | 200.000000 Mhit/s |
| Board observed knee | 135.360020 Mhit/s |

The RTL latency histogram is therefore not accepted as the short-frame latency
reference: its p99 and maximum exceed the 910-cycle short-frame model and match
the discrepancy seen in the previous dispatch-latency plot.

## DISLIN Outputs

![Phase 4 latency shape](artifacts/phase4_latency_tlm_vs_rtl.png)

![Phase 4 throughput sweep](artifacts/phase4_rate_sweep.png)
