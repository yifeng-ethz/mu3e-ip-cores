# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-05-08T04:33:46`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.800 s`
- Measurement mode: `live terminal sample plus post-end flush check`
- Histogram TOTAL_HITS delta: `0`
- Histogram DROPPED_HITS delta: `0`
- Post-end histogram FIFO/queue empty: `yes`
- LVDS lane-go after reset release: `0x000001FF`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000E03`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 7 | 0 | 65529 | 0 | PASS |
| 1 | 15 | 0 | 65521 | 0 | PASS |
| 2 | 15 | 0 | 65521 | 0 | PASS |
| 3 | 15 | 0 | 65521 | 0 | PASS |
| 4 | 15 | 0 | 65521 | 0 | PASS |
| 5 | 15 | 0 | 65521 | 0 | PASS |
| 6 | 15 | 0 | 65521 | 0 | PASS |
| 7 | 15 | 0 | 65521 | 0 | PASS |

## Histogram Snapshot

| Register | Before | Sample | Post-End |
|---|---:|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x000000FF` | `0x000000FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
