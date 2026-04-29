# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T07:17:14`
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
| 0 | 825401888 | 827583062 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 825660144 | 825503991 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 838353718 | 833904203 | 0 | 0 | `0x15F` | `fatal_training` |
| 3 | 829944847 | 828810590 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 830005702 | 831304357 | 0 | 0 | `0x15F` | `fatal_training` |
| 5 | 836846646 | 838572726 | 0 | 0 | `0x15F` | `fatal_training` |
| 6 | 842213279 | 854047139 | 0 | 0 | `0x15F` | `fatal_training` |
| 7 | 854890818 | 858199936 | 0 | 0 | `0x15F` | `fatal_training` |

## Configuration Commands

| ASIC | Opcode | Words | Status | Polls | Result |
|---:|---:|---:|---:|---:|---|
| 0 | `0x01100054` | 84 | `0x00000000` | 1 | `PASS` |
| 3 | `0x01130054` | 84 | `0x00000000` | 1 | `PASS` |
