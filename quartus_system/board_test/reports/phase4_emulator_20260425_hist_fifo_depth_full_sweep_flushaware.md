# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T21:22:51`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/quartus_system/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/quartus_system/board_test/bin/rc_tool`
- Result: `PASS`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.100 s`
- Measurement mode: `live terminal sample plus post-end flush check`
- Histogram TOTAL_HITS delta: `13075621`
- Histogram DROPPED_HITS delta: `0`
- Post-end histogram FIFO/queue empty: `yes`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 56700 | 14573 | 23409 | 63 | PASS |
| 1 | 56700 | 19240 | 28076 | 63 | PASS |
| 2 | 56700 | 24187 | 33023 | 63 | PASS |
| 3 | 56700 | 28529 | 37365 | 63 | PASS |
| 4 | 56700 | 33332 | 42168 | 63 | PASS |
| 5 | 56700 | 38394 | 47230 | 63 | PASS |
| 6 | 56700 | 42984 | 51820 | 63 | PASS |
| 7 | 56700 | 47463 | 56299 | 63 | PASS |

## Histogram Snapshot

| Register | Before | Sample | Post-End |
|---|---:|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x00FF00FF` | `0x00FF00FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00C784A5` | `0x00D86EFB` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000000` | `0x00000100` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 2623117 | 26231170 | 0 | - | PASS |
| `r0200` | `0x0200` | 4942183 | 49421830 | 0 | 1.884 | PASS |
| `r0400` | `0x0400` | 9590545 | 95905450 | 0 | 1.941 | PASS |
| `r0800` | `0x0800` | 12825226 | 128252260 | 0 | 1.337 | PASS |
| `r1000` | `0x1000` | 13536002 | 135360020 | 0 | 1.055 | KNEE |
| `r2000` | `0x2000` | 12898662 | 128986620 | 0 | 0.953 | CLIPPED |
| `r4000` | `0x4000` | 13079435 | 130794350 | 0 | 1.014 | CLIPPED |
| `r8000` | `0x8000` | 12497280 | 124972800 | 0 | 0.955 | CLIPPED |

- Saturation knee: `r1000` / `0x1000` (`DROPPED_HITS` delta 0, throughput 135360020 hits/s).

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.
