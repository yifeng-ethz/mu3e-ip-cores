# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T19:39:45`
- SC link: `2`
- LVDS reset requested: `yes`
- Configured ASICs: `[0, 3]`
- Channel enable override: `0x00010000`
- TDC-test channel override: `0x00010000`
- Window: `250` ms
- Classification: `aligned_idle_no_frames`

## Final LVDS Snapshot

| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 1 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 2 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 3 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 5 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 6 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 7 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 850953873 | 846488727 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 843172664 | 844420072 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 836600120 | 836139187 | 0 | 0 | `0x15F` | `fatal_training` |
| 3 | 834323451 | 838232785 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 835610459 | 834178355 | 0 | 0 | `0x15F` | `fatal_training` |
| 5 | 831428518 | 830357126 | 0 | 0 | `0x15F` | `fatal_training` |
| 6 | 828880994 | 828708285 | 0 | 0 | `0x15F` | `fatal_training` |
| 7 | 834334365 | 834494578 | 0 | 0 | `0x15F` | `fatal_training` |

## Configuration Commands

| ASIC | Opcode | Words | Status | Polls | Result |
|---:|---:|---:|---:|---:|---|
| 0 | `0x01100054` | 84 | `0x00000000` | 1 | `PASS` |
| 3 | `0x01130054` | 84 | `0x00000000` | 1 | `PASS` |
