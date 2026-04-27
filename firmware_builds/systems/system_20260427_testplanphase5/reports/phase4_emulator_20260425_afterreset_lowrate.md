# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T07:22:49`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.500 s`
- Histogram TOTAL_HITS delta: `8780668`
- Histogram DROPPED_HITS delta: `0`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000003`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 48037 | 1674 | 19173 | 63 | PASS |
| 1 | 53755 | 7762 | 19543 | 63 | PASS |
| 2 | 58923 | 12584 | 19197 | 63 | PASS |
| 3 | 63630 | 20930 | 22836 | 63 | PASS |
| 4 | 3301 | 25972 | 22671 | 63 | PASS |
| 5 | 7779 | 30328 | 22549 | 63 | PASS |
| 6 | 12279 | 34821 | 22542 | 63 | PASS |
| 7 | 17378 | 39613 | 22235 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x008400FF` | `0x008400FF` |
| `TOTAL_HITS` | `0x00A1F420` | `0x0127EF9C` |
| `DROPPED_HITS` | `0x00000000` | `0x00000000` |
| `COAL_STATUS` | `0x00000100` | `0x00000100` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0010` | `0x0010` | 8451301 | 16902602 | 0 | - | PASS |
| `r0020` | `0x0020` | 8019558 | 16039116 | 0 | 0.949 | PASS |
| `r0040` | `0x0040` | 8358062 | 16716124 | 0 | 1.042 | PASS |
| `r0080` | `0x0080` | 8529934 | 17059868 | 0 | 1.021 | PASS |
| `r0100` | `0x0100` | 9026358 | 18052716 | 0 | 1.058 | PASS |
| `r0200` | `0x0200` | 8197718 | 16395436 | 0 | 0.908 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- Emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.
- The rate sweep compares per-run `TOTAL_HITS` deltas because the live counters are sampled while the run is active.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- rate ratio r0010->r0020 = 0.949, expected 2.000 +/- 35%
- rate ratio r0020->r0040 = 1.042, expected 2.000 +/- 35%
- rate ratio r0040->r0080 = 1.021, expected 2.000 +/- 35%
- rate ratio r0080->r0100 = 1.058, expected 2.000 +/- 35%
- rate ratio r0100->r0200 = 0.908, expected 2.000 +/- 35%
