# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-28T11:42:44`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/system_20260427_testplanphase5/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.250 s`
- Measurement mode: `live terminal sample plus post-end flush check`
- Histogram TOTAL_HITS delta: `15876641`
- Histogram DROPPED_HITS delta: `1167`
- Post-end histogram FIFO/queue empty: `yes`
- LVDS lane-go after reset release: `0x000001FF`
- MuTRiG lane source mux: `emulator` selected for lanes 0..7
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000403`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 53240 | 26230 | 38526 | 63 | PASS |
| 1 | 53240 | 30730 | 43026 | 63 | PASS |
| 2 | 53240 | 35259 | 47555 | 63 | PASS |
| 3 | 53240 | 40287 | 52583 | 63 | PASS |
| 4 | 53240 | 44614 | 56910 | 63 | PASS |
| 5 | 53240 | 49122 | 61418 | 63 | PASS |
| 6 | 53239 | 54222 | 983 | 63 | PASS |
| 7 | 53240 | 59295 | 6055 | 63 | PASS |

| Lane | Source Mux Base | Source | Real Beats | Emu Beats | Selected Beats |
|---:|---:|---|---:|---:|---:|
| 0 | `0x00008890` | `emulator` | 7692116 | 7692117 | 7692143 |
| 1 | `0x000088A0` | `emulator` | 10833862 | 10833863 | 10833889 |
| 2 | `0x000088B0` | `emulator` | 7896940 | 7896941 | 7896967 |
| 3 | `0x000088C0` | `emulator` | 8038247 | 8038248 | 8038274 |
| 4 | `0x000088D0` | `emulator` | 7457014 | 7457015 | 7457041 |
| 5 | `0x000088E0` | `emulator` | 7897540 | 7897541 | 7897567 |
| 6 | `0x000088F0` | `emulator` | 9319212 | 9319213 | 9319239 |
| 7 | `0x00008900` | `emulator` | 6924023 | 6924024 | 6924050 |

## Histogram Snapshot

| Register | Before | Sample | Post-End |
|---|---:|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x00FF00FF` | `0x00FF00FF` |
| `TOTAL_HITS` | `0x00000000` | `0x00F24221` | `0x01030895` |
| `DROPPED_HITS` | `0x00000000` | `0x0000048F` | `0x000004CF` |
| `COAL_STATUS` | `0x00000000` | `0x00000100` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 3463420 | 19241222 | 0 | - | PASS |
| `r0200` | `0x0200` | 5959246 | 33106922 | 0 | 1.721 | PASS |
| `r0400` | `0x0400` | 12950336 | 71946311 | 0 | 2.173 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- primary 8-lane emulator/histogram measurement
