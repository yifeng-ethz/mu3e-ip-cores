# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T07:21:40`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.500 s`
- Histogram TOTAL_HITS delta: `8510284`
- Histogram DROPPED_HITS delta: `0`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000003`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 45912 | 9567 | 29191 | 63 | PASS |
| 1 | 57373 | 14208 | 22371 | 63 | PASS |
| 2 | 62337 | 18821 | 22020 | 63 | PASS |
| 3 | 1343 | 24318 | 22975 | 63 | PASS |
| 4 | 6120 | 28701 | 22581 | 63 | PASS |
| 5 | 10689 | 33159 | 22470 | 63 | PASS |
| 6 | 15818 | 37714 | 21896 | 63 | PASS |
| 7 | 20380 | 42235 | 21855 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x000000FF` |
| `TOTAL_HITS` | `0x00FA7075` | `0x017C4BC1` |
| `DROPPED_HITS` | `0x00000379` | `0x00000379` |
| `COAL_STATUS` | `0x00000500` | `0x00000500` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0010` | `0x0010` | 8525142 | 17050284 | 0 | - | PASS |
| `r0020` | `0x0020` | 8510284 | 17020568 | 0 | 0.998 | PASS |
| `r0040` | `0x0040` | 8597006 | 17194012 | 0 | 1.010 | PASS |
| `r0080` | `0x0080` | 8719679 | 17439358 | 0 | 1.014 | PASS |
| `r0100` | `0x0100` | 8156322 | 16312644 | 0 | 0.935 | PASS |
| `r0200` | `0x0200` | 8517882 | 17035764 | 0 | 1.044 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- The histogram ingress bridge is explicitly switched to the post-hit-stack stream after `stop-reset` and before `run-prepare`.
- The rate sweep compares per-run `TOTAL_HITS` deltas because the live counters are sampled while the run is active.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- rate ratio r0010->r0020 = 0.998, expected 2.000 +/- 35%
- rate ratio r0020->r0040 = 1.010, expected 2.000 +/- 35%
- rate ratio r0040->r0080 = 1.014, expected 2.000 +/- 35%
- rate ratio r0080->r0100 = 0.935, expected 2.000 +/- 35%
- rate ratio r0100->r0200 = 1.044, expected 2.000 +/- 35%
