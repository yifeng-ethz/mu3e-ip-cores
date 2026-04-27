# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T21:20:16`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `PASS`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.100 s`
- Measurement mode: `live terminal sample plus post-end flush check`
- Histogram TOTAL_HITS delta: `13158532`
- Histogram DROPPED_HITS delta: `0`
- Post-end histogram FIFO/queue empty: `yes`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 5275 | 14558 | 9283 | 63 | PASS |
| 1 | 5275 | 19282 | 14007 | 63 | PASS |
| 2 | 5275 | 24266 | 18991 | 63 | PASS |
| 3 | 5275 | 29058 | 23783 | 63 | PASS |
| 4 | 5275 | 33590 | 28315 | 63 | PASS |
| 5 | 5275 | 38248 | 32973 | 63 | PASS |
| 6 | 5275 | 43304 | 38029 | 63 | PASS |
| 7 | 5275 | 47909 | 42634 | 57 | PASS |

## Histogram Snapshot

| Register | Before | Sample | Post-End |
|---|---:|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x00FF00FF` | `0x00FF00FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00C8C884` | `0x00DA7E48` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000000` | `0x00000100` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 3312020 | 33120200 | 0 | - | PASS |
| `r0200` | `0x0200` | 5131956 | 51319560 | 0 | 1.549 | PASS |
| `r0400` | `0x0400` | 10241194 | 102411940 | 0 | 1.996 | PASS |
| `r0800` | `0x0800` | 14016828 | 140168280 | 0 | 1.369 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.
