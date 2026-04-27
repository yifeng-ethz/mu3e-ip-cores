# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T11:15:02`
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
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000C03`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 46062 | 5648 | 25122 | 63 | PASS |
| 1 | 51633 | 12033 | 25936 | 63 | PASS |
| 2 | 58093 | 18754 | 26197 | 63 | PASS |
| 3 | 64405 | 26888 | 28019 | 63 | PASS |
| 4 | 5316 | 33223 | 27907 | 63 | PASS |
| 5 | 10227 | 39516 | 29289 | 63 | PASS |
| 6 | 14910 | 45852 | 30942 | 63 | PASS |
| 7 | 19832 | 52486 | 32654 | 63 | PASS |

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

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas because the live counters are sampled while the run is active.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
