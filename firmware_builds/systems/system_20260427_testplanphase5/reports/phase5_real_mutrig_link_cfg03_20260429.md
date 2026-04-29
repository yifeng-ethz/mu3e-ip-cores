# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T07:06:39`
- SC link: `2`
- LVDS reset requested: `yes`
- Configured ASICs: `[0, 3]`
- Window: `500` ms
- Classification: `aligned_idle_no_frames`

## Final LVDS Snapshot

| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 1 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 2 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 3 | `adaptive` | 1 | 0 | 0 | `0x0000001A` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 5 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 6 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 7 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 880176115 | 881205364 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 885436980 | 886949740 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 890152446 | 879840609 | 0 | 0 | `0x15F` | `fatal_training` |
| 3 | 876236111 | 872994313 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 864059570 | 864774706 | 0 | 0 | `0x15F` | `fatal_training` |
| 5 | 866139457 | 878049630 | 0 | 0 | `0x15F` | `fatal_training` |
| 6 | 874686460 | 876150877 | 0 | 0 | `0x15F` | `fatal_training` |
| 7 | 880628935 | 880433819 | 0 | 0 | `0x15F` | `fatal_training` |

## Configuration Commands

| ASIC | Opcode | Words | Status | Polls | Result |
|---:|---:|---:|---:|---:|---|
| 0 | `0x01100054` | 84 | `0x00000000` | 1 | `PASS` |
| 3 | `0x01130054` | 84 | `0x00000000` | 1 | `PASS` |
