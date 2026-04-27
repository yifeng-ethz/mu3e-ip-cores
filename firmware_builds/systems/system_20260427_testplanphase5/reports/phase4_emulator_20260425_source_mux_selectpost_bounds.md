# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T07:19:57`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.500 s`
- Histogram TOTAL_HITS delta: `8374568`
- Histogram DROPPED_HITS delta: `0`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000003`
- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 46322 | 1422 | 20636 | 63 | PASS |
| 1 | 51009 | 6064 | 20591 | 63 | PASS |
| 2 | 55615 | 11082 | 21003 | 63 | PASS |
| 3 | 60299 | 16173 | 21410 | 63 | PASS |
| 4 | 1077 | 21245 | 20168 | 63 | PASS |
| 5 | 5724 | 26317 | 20593 | 63 | PASS |
| 6 | 10921 | 30907 | 19986 | 63 | PASS |
| 7 | 15757 | 35354 | 19597 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x000000FF` |
| `TOTAL_HITS` | `0x00FD3F35` | `0x017D085D` |
| `DROPPED_HITS` | `0x00000323` | `0x00000323` |
| `COAL_STATUS` | `0x00000400` | `0x00000400` |

## Rate Sweep

- Ratio tolerance: `35%`

| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |
|---|---:|---:|---:|---:|---:|---|
| `r0100` | `0x0100` | 6589850 | 21966167 | 0 | - | PASS |
| `r0200` | `0x0200` | 6954266 | 23180887 | 0 | 1.055 | PASS |
| `r0400` | `0x0400` | 7233522 | 24111740 | 0 | 1.040 | PASS |
| `r0800` | `0x0800` | 7415648 | 24718827 | 0 | 1.025 | PASS |
| `r1000` | `0x1000` | 8734818 | 29116060 | 0 | 1.178 | PASS |
| `r2000` | `0x2000` | 6986230 | 23287433 | 0 | 0.800 | PASS |
| `r4000` | `0x4000` | 7403596 | 24678653 | 0 | 1.060 | PASS |
| `r8000` | `0x8000` | 8563994 | 28546647 | 0 | 1.157 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- The histogram ingress bridge is explicitly switched to the post-hit-stack stream after `stop-reset` and before `run-prepare`.
- The rate sweep compares per-run `TOTAL_HITS` deltas because the live counters are sampled while the run is active.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- rate ratio r0100->r0200 = 1.055, expected 2.000 +/- 35%
- rate ratio r0200->r0400 = 1.040, expected 2.000 +/- 35%
- rate ratio r0400->r0800 = 1.025, expected 2.000 +/- 35%
- rate ratio r0800->r1000 = 1.178, expected 2.000 +/- 35%
- rate ratio r1000->r2000 = 0.800, expected 2.000 +/- 35%
- rate ratio r2000->r4000 = 1.060, expected 2.000 +/- 35%
- rate ratio r4000->r8000 = 1.157, expected 2.000 +/- 35%
