# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T16:15:01`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.100 s`
- Measurement mode: `after-end quiet readback`
- Histogram TOTAL_HITS delta: `0`
- Histogram DROPPED_HITS delta: `0`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 16106 | 24320 | 8214 | 63 | PASS |
| 1 | 16106 | 24320 | 8214 | 63 | PASS |
| 2 | 16106 | 24320 | 8214 | 63 | PASS |
| 3 | 16106 | 24320 | 8214 | 63 | PASS |
| 4 | 16106 | 24320 | 8214 | 63 | PASS |
| 5 | 16106 | 24320 | 8214 | 63 | PASS |
| 6 | 16106 | 24320 | 8214 | 63 | PASS |
| 7 | 16106 | 24320 | 8214 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x000000FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00000000` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000000` | `0x00000000` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 72 | 720 | 0 | - | PASS |
| `r0200` | `0x0200` | 0 | 0 | 0 | 0.000 | FAIL |
| `r0400` | `0x0400` | 2099882 | 20998820 | 0 | - | PASS |
| `r0800` | `0x0800` | 6300652 | 63006520 | 436 | 3.000 | KNEE |
| `r1000` | `0x1000` | 100418 | 1004180 | 0 | 0.016 | CLIPPED |
| `r2000` | `0x2000` | 6003533 | 60035330 | 4769 | 59.785 | CLIPPED |
| `r4000` | `0x4000` | 0 | 0 | 0 | 0.000 | FAIL |
| `r8000` | `0x8000` | 0 | 0 | 0 | - | FAIL |

- Saturation knee: `r0800` / `0x0800` (`DROPPED_HITS` delta 436).

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas; with `--measure-after-end`, counters are read after traffic is stopped so SC replies are not competing with sustained event data.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
- rate point r0200
- rate point r4000
- rate point r8000
- rate ratio r0100->r0200 has zero hit delta
- rate ratio r0200->r0400 has zero hit delta
