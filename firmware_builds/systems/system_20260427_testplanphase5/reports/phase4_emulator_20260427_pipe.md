# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-27T16:40:42`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.100 s`
- Measurement mode: `live terminal sample plus post-end flush check`
- Histogram TOTAL_HITS delta: `13360440`
- Histogram DROPPED_HITS delta: `977`
- Post-end histogram FIFO/queue empty: `yes`
- LVDS lane-go after reset release: `0x000001FF`
- MuTRiG lane source mux: `emulator` selected for lanes 0..7
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 0 | 13637 | 13637 | 63 | PASS |
| 1 | 0 | 18312 | 18312 | 63 | PASS |
| 2 | 0 | 22884 | 22884 | 63 | PASS |
| 3 | 0 | 27625 | 27625 | 63 | PASS |
| 4 | 0 | 32214 | 32214 | 63 | PASS |
| 5 | 0 | 37725 | 37725 | 63 | PASS |
| 6 | 0 | 42584 | 42584 | 63 | PASS |
| 7 | 0 | 48832 | 48832 | 63 | PASS |

| Lane | Source Mux Base | Source | Real Beats | Emu Beats | Selected Beats |
|---:|---:|---|---:|---:|---:|
| 0 | `0x00008890` | `emulator` | 7103673 | 7103674 | 7103700 |
| 1 | `0x000088A0` | `emulator` | 6800572 | 6800573 | 6800599 |
| 2 | `0x000088B0` | `emulator` | 6934028 | 6934029 | 6934055 |
| 3 | `0x000088C0` | `emulator` | 6895163 | 6895164 | 6895190 |
| 4 | `0x000088D0` | `emulator` | 7241668 | 7241669 | 7241695 |
| 5 | `0x000088E0` | `emulator` | 9238802 | 9238803 | 9238829 |
| 6 | `0x000088F0` | `emulator` | 8625372 | 8625373 | 8625399 |
| 7 | `0x00008900` | `emulator` | 7167143 | 7167144 | 7167170 |

## Histogram Snapshot

| Register | Before | Sample | Post-End |
|---|---:|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x00FF00FF` | `0x00FF00FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00CBDD38` | `0x00DDAAA8` |
| `DROPPED_HITS` | `0x00000000` | `0x000003D1` | `0x0000040D` |
| `COAL_STATUS` | `0x00000000` | `0x00000100` | `0x00000100` |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
