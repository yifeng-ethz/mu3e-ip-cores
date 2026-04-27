# Phase 4 Emulator/Histogram Report

- Timestamp: `2026-04-25T07:16:33`
- SC link: `2`
- Device: `/dev/mudaq0`
- FEB target: `7`
- SC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/sc_tool`
- RC tool: `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/board_test/bin/rc_tool`
- Result: `FAIL`

## Primary 8-Lane Run

- Hit rate: `0x0800`
- Sample spacing: `0.500 s`
- Histogram TOTAL_HITS delta: `8735604`
- Histogram DROPPED_HITS delta: `0`
- Histogram ingress source: `post`
- Histogram ingress status after reset release: `0x00000003`

| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |
|---:|---:|---:|---:|---:|---|
| 0 | 47078 | 201 | 18659 | 63 | PASS |
| 1 | 51749 | 5753 | 19540 | 63 | PASS |
| 2 | 56532 | 10869 | 19873 | 63 | PASS |
| 3 | 61344 | 17202 | 21394 | 63 | PASS |
| 4 | 931 | 22256 | 21325 | 63 | PASS |
| 5 | 5611 | 27027 | 21416 | 63 | PASS |
| 6 | 10153 | 31408 | 21255 | 63 | PASS |
| 7 | 15547 | 36188 | 20641 | 63 | PASS |

## Histogram Snapshot

| Register | Before | After |
|---|---:|---:|
| `UNDERFLOW_COUNT` | `0x00000000` | `0x00000000` |
| `OVERFLOW_COUNT` | `0x00A4604C` | `0x0129ABC0` |
| `INTERVAL_CFG` | `0x3FFFFFFF` | `0x3FFFFFFF` |
| `BANK_STATUS` | `0x00000000` | `0x00000000` |
| `PORT_STATUS` | `0x000000FF` | `0x000000FF` |
| `TOTAL_HITS` | `0x00A46365` | `0x0129AED9` |
| `DROPPED_HITS` | `0x00000319` | `0x00000319` |
| `COAL_STATUS` | `0x00000000` | `0x00000000` |

## Rate Sweep

| Label | Hit Rate | TOTAL_HITS | DROPPED_HITS | Result |
|---|---:|---:|---:|---|
| `r0100` | `0x0100` | 21271888 | 898 | PASS |
| `r0200` | `0x0200` | 21065684 | 837 | PASS |
| `r0400` | `0x0400` | 21626358 | 825 | PASS |

## Notes

- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.
- The histogram ingress bridge is explicitly switched to the post-hit-stack stream after `stop-reset` and before `run-prepare`.
- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.
- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.

## Failures

- rate sweep totals are not strictly increasing
