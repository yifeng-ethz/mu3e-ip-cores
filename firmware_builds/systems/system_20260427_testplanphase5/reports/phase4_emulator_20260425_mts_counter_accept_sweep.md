# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T20:14:55`
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
- Histogram TOTAL_HITS delta: `3565152`
- Histogram DROPPED_HITS delta: `436`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000503`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 14509 | 14182 | 65209 | 63 | PASS |
| 1 | 14509 | 14182 | 65209 | 63 | PASS |
| 2 | 14509 | 14182 | 65209 | 63 | PASS |
| 3 | 14509 | 14182 | 65209 | 63 | PASS |
| 4 | 14509 | 14182 | 65209 | 63 | PASS |
| 5 | 14509 | 14182 | 65209 | 63 | PASS |
| 6 | 14509 | 14182 | 65209 | 63 | PASS |
| 7 | 14509 | 14182 | 65209 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x000000FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00366660` |
| `DROPPED_HITS` | `0x00000000` | `0x000001B4` |
| `COAL_STATUS` | `0x00000000` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 750450 | 7504500 | 0 | - | PASS |
| `r0200` | `0x0200` | 1430490 | 14304900 | 0 | 1.906 | PASS |
| `r0400` | `0x0400` | 2717653 | 27176530 | 0 | 1.900 | PASS |
| `r0800` | `0x0800` | 3782776 | 37827760 | 470 | 1.392 | KNEE |

- Saturation knee: `r0800` / `0x0800` (`DROPPED_HITS` delta 470).

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas; with `--measure-after-end`, counters are read after traffic is stopped so SC replies are not competing with sustained event data.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
