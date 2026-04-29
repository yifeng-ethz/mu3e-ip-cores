# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T07:05:49`
- SC link: `2`
- LVDS reset requested: `yes`
- Configured ASICs: `none`
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
| 0 | 803395028 | 803474660 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 809528740 | 810837053 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 809564510 | 807561766 | 0 | 0 | `0x15F` | `fatal_training` |
| 3 | 809700362 | 811480974 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 812481484 | 813783719 | 0 | 0 | `0x15F` | `fatal_training` |
| 5 | 814014753 | 813369339 | 0 | 0 | `0x15F` | `fatal_training` |
| 6 | 816022623 | 820633347 | 0 | 0 | `0x15F` | `fatal_training` |
| 7 | 825370076 | 824996466 | 0 | 0 | `0x15F` | `fatal_training` |
