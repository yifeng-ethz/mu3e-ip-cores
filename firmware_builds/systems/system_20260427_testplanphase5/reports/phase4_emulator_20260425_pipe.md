# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T08:30:47`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.500 s`
- Histogram TOTAL_HITS delta: `0`
- Histogram DROPPED_HITS delta: `0`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000C03`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 46296 | 62534 | 16238 | 63 | PASS |
| 1 | 50873 | 2365 | 17028 | 63 | PASS |
| 2 | 55741 | 6874 | 16669 | 63 | PASS |
| 3 | 60224 | 11432 | 16744 | 63 | PASS |
| 4 | 64734 | 15988 | 16790 | 63 | PASS |
| 5 | 4049 | 21070 | 17021 | 63 | PASS |
| 6 | 8410 | 28769 | 20359 | 63 | PASS |
| 7 | 12766 | 35535 | 22769 | 63 | PASS |

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
| `r0100` | `0x0100` | 0 | 0 | 0 | - | FAIL |
| `r0200` | `0x0200` | 0 | 0 | 0 | - | FAIL |
| `r0400` | `0x0400` | 0 | 0 | 0 | - | FAIL |
| `r0800` | `0x0800` | 0 | 0 | 0 | - | FAIL |
| `r1000` | `0x1000` | 0 | 0 | 0 | - | FAIL |
| `r2000` | `0x2000` | 0 | 0 | 0 | - | FAIL |
| `r4000` | `0x4000` | 0 | 0 | 0 | - | FAIL |
| `r8000` | `0x8000` | 0 | 0 | 0 | - | FAIL |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- Emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas because the live counters are sampled while the run is active.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
- rate point r0100
- rate point r0200
- rate point r0400
- rate point r0800
- rate point r1000
- rate point r2000
- rate point r4000
- rate point r8000
- rate ratio r0100->r0200 has zero hit delta
- rate ratio r0200->r0400 has zero hit delta
- rate ratio r0400->r0800 has zero hit delta
- rate ratio r0800->r1000 has zero hit delta
- rate ratio r1000->r2000 has zero hit delta
- rate ratio r2000->r4000 has zero hit delta
- rate ratio r4000->r8000 has zero hit delta
