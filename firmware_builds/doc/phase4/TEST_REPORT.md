# Phase 4 Board Test Report

Date: 2026-04-25

This report summarizes the available on-board Phase 4 emulator/histogram
evidence and compares it against the updated 25 Mhit/s per-MuTRiG physical
limit.

## Board Evidence

Primary board report:
[`inputs/board/phase4_emulator_20260425_hist_fifo_depth_full_sweep_flushaware.md`](inputs/board/phase4_emulator_20260425_hist_fifo_depth_full_sweep_flushaware.md)

Stage-counter report:
[`inputs/board/phase4_stage_probe_20260425_hist_fifo_depth_rate0800_flushaware.md`](inputs/board/phase4_stage_probe_20260425_hist_fifo_depth_rate0800_flushaware.md)

Board setup from the report:

| Field | Value |
|---|---|
| timestamp | `2026-04-25T21:22:51` |
| SC link | 2 |
| FEB target | 7 |
| device | `/dev/mudaq0` |
| reported result | PASS |

## Primary 8-Lane Run

The primary 8-lane run used `hit_rate=0x0800`, post ingress, and a live
pre-TERMINATING sample with post-end flush checking.

| Quantity | Value |
|---|---:|
| sample spacing | 0.100 s |
| `TOTAL_HITS` delta | 13075621 |
| `DROPPED_HITS` delta | 0 |
| post-end FIFO/queue empty | yes |
| lane-go after reset release | `0x000001FF` |
| histogram ingress status | `0x00000403` |
| underflow / overflow | 0 / 0 |

All eight emulator lanes reported advancing frame counters and nonzero event
counts.

## Rate Sweep

The plotted board rate sweep is generated from
[`artifacts/phase4_rate_sweep.csv`](artifacts/phase4_rate_sweep.csv).

![Phase 4 throughput sweep](artifacts/phase4_rate_sweep.png)

| Label | Hit rate | Board rate | Dropped | Result |
|---|---:|---:|---:|---|
| `r0100` | `0x0100` | 26.231170 Mhit/s | 0 | PASS |
| `r0200` | `0x0200` | 49.421830 Mhit/s | 0 | PASS |
| `r0400` | `0x0400` | 95.905450 Mhit/s | 0 | PASS |
| `r0800` | `0x0800` | 128.252260 Mhit/s | 0 | PASS |
| `r1000` | `0x1000` | 135.360020 Mhit/s | 0 | KNEE |
| `r2000` | `0x2000` | 128.986620 Mhit/s | 0 | CLIPPED |
| `r4000` | `0x4000` | 130.794350 Mhit/s | 0 | CLIPPED |
| `r8000` | `0x8000` | 124.972800 Mhit/s | 0 | CLIPPED |

The observed board knee is 135.360020 Mhit/s. Under the updated physical model,
the histogram should not clip until about 200 Mhit/s, so this board image does
not close the Phase 4 rate target. It remains useful functional evidence:
there were no dropped histogram hits and the post-end flush was clean.

## Stage Counter Probe

The stage probe ran two `0x0800` iterations and both classified as PASS.

| Iteration | MTS hits | Ring push | Ring pop | Frame actual | Hist total | Hist drop | Flush |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 71519429 | 83441992 | 83441718 | 95010808 | 49247643 | 0 | clean |
| 1 | 70854857 | 82759510 | 82759059 | 94776715 | 49209095 | 0 | clean |

The probe confirms that the high-rate path was active beyond the terminal
histogram counter and that post-end residue was clean in both iterations.

## Simulation Cross-Checks

TLM and RTL simulation details are in
[`TLM_REPORT.md`](TLM_REPORT.md).

Key cross-checks:

| Check | Result |
|---|---|
| HDL/TLM Questa run | 0 errors, 0 warnings |
| DISLIN render | 0 warnings |
| Physical cap | 25 Mhit/s per MuTRiG, 200 Mhit/s for 8 MuTRiG |
| TLM accepted rate at `0x0800` | 195.286719 Mhit/s |
| TLM cap from `0x1000` up | 200.000000 Mhit/s |
| Board knee | 135.360020 Mhit/s |
| RTL latency evidence | stale for short-frame injection signoff |

## Required Board Follow-Up

The next board run should use the updated target:

```bash
python3 firmware_builds/systems/system_20260427_testplanphase5/script/run_phase4_emulator.py \
  --measure-after-end \
  --output firmware_builds/systems/system_20260427_testplanphase5/reports/phase4_emulator_<date>_target200.md
```

Acceptance for the refreshed board run:

- no histogram drop/underflow/overflow status;
- clean post-end flush;
- monotonic rate growth through the `0x0800` point;
- clipping at the 200 Mhit/s physical histogram target, not near 135 Mhit/s.

The injection-mode latency board/RTL setup should enable one channel, sweep
the injection pulse offset across a full short frame, and then repeat at higher
background rate to show the envelope growing from 0 to 1 frame toward 0 to 2
frames.

## Verdict

Functional board evidence is PASS for 8-lane activity, histogram accumulation,
zero dropped histogram hits, and clean flush. Rate signoff is OPEN: the tested
board image clips near 135 Mhit/s, while the updated physical requirement is
200 Mhit/s for the 8-MuTRiG histogram input.
