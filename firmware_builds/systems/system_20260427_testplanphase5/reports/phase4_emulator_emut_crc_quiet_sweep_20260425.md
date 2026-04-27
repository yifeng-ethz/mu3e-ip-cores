# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T16:13:16`
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
- Histogram TOTAL_HITS delta: `38151`
- Histogram DROPPED_HITS delta: `0`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000503`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 38816 | 15965 | 42685 | 63 | PASS |
| 1 | 43232 | 15965 | 38269 | 63 | PASS |
| 2 | 47863 | 15965 | 33638 | 63 | PASS |
| 3 | 52786 | 15965 | 28715 | 63 | PASS |
| 4 | 57953 | 15965 | 23548 | 63 | PASS |
| 5 | 62979 | 15965 | 18522 | 63 | PASS |
| 6 | 2746 | 15965 | 13219 | 63 | PASS |
| 7 | 7751 | 15965 | 8214 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x001400FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00009507` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000000` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 817952 | 8179520 | 0 | - | PASS |
| `r0200` | `0x0200` | 1165073 | 11650730 | 0 | 1.424 | PASS |
| `r0400` | `0x0400` | 0 | 0 | 0 | 0.000 | FAIL |
| `r0800` | `0x0800` | 0 | 0 | 0 | - | FAIL |
| `r1000` | `0x1000` | 0 | 0 | 0 | - | FAIL |
| `r2000` | `0x2000` | 0 | 0 | 0 | - | FAIL |
| `r4000` | `0x4000` | 3957588 | 39575880 | 22095 | - | KNEE |
| `r8000` | `0x8000` | 4130276 | 41302760 | 39381 | 1.044 | CLIPPED |

- Saturation knee: `r4000` / `0x4000` (`DROPPED_HITS` delta 22095).

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas; with `--measure-after-end`, counters are read after traffic is stopped so SC replies are not competing with sustained event data.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- rate point r0400
- rate point r0800
- rate point r1000
- rate point r2000
- rate ratio r0200->r0400 has zero hit delta
- rate ratio r0400->r0800 has zero hit delta
- rate ratio r0800->r1000 has zero hit delta
- rate ratio r1000->r2000 has zero hit delta
