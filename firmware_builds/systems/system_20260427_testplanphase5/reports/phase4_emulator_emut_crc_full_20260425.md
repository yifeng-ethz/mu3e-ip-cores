# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T16:07:47`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.050 s`
- Histogram TOTAL_HITS delta: `0`
- Histogram DROPPED_HITS delta: `0`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 10488 | 62573 | 52085 | 63 | PASS |
| 1 | 15761 | 1538 | 51313 | 63 | PASS |
| 2 | 20581 | 5819 | 50774 | 63 | PASS |
| 3 | 30037 | 11285 | 46784 | 63 | PASS |
| 4 | 34702 | 16454 | 47288 | 63 | PASS |
| 5 | 39087 | 21088 | 47537 | 63 | PASS |
| 6 | 43845 | 25501 | 47192 | 63 | PASS |
| 7 | 48325 | 30295 | 47506 | 63 | PASS |

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
| `r0100` | `0x0100` | 907616 | 18152320 | 0 | - | PASS |
| `r0200` | `0x0200` | 0 | 0 | 0 | 0.000 | FAIL |
| `r0400` | `0x0400` | 0 | 0 | 0 | - | FAIL |
| `r0800` | `0x0800` | 0 | 0 | 0 | - | FAIL |
| `r1000` | `0x1000` | 13007431 | 260148620 | 26166 | - | FAIL |
| `r2000` | `0x2000` | 11207308 | 224146160 | 18454 | 0.862 | FAIL |
| `r4000` | `0x4000` | 11423624 | 228472480 | 63692 | 1.019 | FAIL |
| `r8000` | `0x8000` | 190876 | 3817520 | 0 | 0.017 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas because the live counters are sampled while the run is active.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
- rate point r0200
- rate point r0400
- rate point r0800
- rate point r1000
- rate point r2000
- rate point r4000
- rate ratio r0100->r0200 has zero hit delta
- rate ratio r0200->r0400 has zero hit delta
- rate ratio r0400->r0800 has zero hit delta
- rate ratio r0800->r1000 has zero hit delta
- rate ratio r1000->r2000 = 0.862, expected 2.000 +/- 35%
- rate ratio r2000->r4000 = 1.019, expected 2.000 +/- 35%
- rate ratio r4000->r8000 = 0.017, expected 2.000 +/- 35%
