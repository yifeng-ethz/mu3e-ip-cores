# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T21:21:01`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.100 s`
- Measurement mode: `live terminal sample plus post-end flush check`
- Histogram TOTAL_HITS delta: `13308875`
- Histogram DROPPED_HITS delta: `0`
- Post-end histogram FIFO/queue empty: `yes`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 60582 | 14631 | 19585 | 63 | PASS |
| 1 | 60582 | 19255 | 24209 | 63 | PASS |
| 2 | 60582 | 23806 | 28760 | 63 | PASS |
| 3 | 60582 | 28373 | 33327 | 63 | PASS |
| 4 | 60582 | 33675 | 38629 | 63 | PASS |
| 5 | 60582 | 38448 | 43402 | 63 | PASS |
| 6 | 60582 | 43396 | 48350 | 63 | PASS |
| 7 | 60582 | 48182 | 53136 | 63 | PASS |

## Histogram Snapshot

| Register | Before | Sample | Post-End |
|---|---:|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x00FF00FE` | `0x00FF00FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00CB13CB` | `0x00DCD388` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000000` | `0x00000101` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 2648369 | 26483690 | 0 | - | PASS |
| `r0200` | `0x0200` | 5315233 | 53152330 | 0 | 2.007 | PASS |
| `r0400` | `0x0400` | 9849080 | 98490800 | 0 | 1.853 | PASS |
| `r0800` | `0x0800` | 13216327 | 132163270 | 0 | 1.342 | PASS |
| `r1000` | `0x1000` | 13198716 | 131987160 | 0 | 0.999 | PASS |
| `r2000` | `0x2000` | 13269292 | 132692920 | 0 | 1.005 | PASS |
| `r4000` | `0x4000` | 13133883 | 131338830 | 0 | 0.990 | PASS |
| `r8000` | `0x8000` | 13063372 | 130633720 | 0 | 0.995 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- rate ratio r0800->r1000 = 0.999, expected 2.000 +/- 35%
- rate ratio r1000->r2000 = 1.005, expected 2.000 +/- 35%
- rate ratio r2000->r4000 = 0.990, expected 2.000 +/- 35%
- rate ratio r4000->r8000 = 0.995, expected 2.000 +/- 35%
