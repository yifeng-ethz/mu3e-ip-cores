# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T07:05:13`
- SC link: `2`
- LVDS reset requested: `no`
- Configured ASICs: `none`
- Window: `250` ms
- Classification: `aligned_idle_no_frames`

## Final LVDS Snapshot

| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `adaptive` | 1 | 0 | 0 | `0x00004486` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 1 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 2 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 3 | `adaptive` | 1 | 0 | 0 | `0x00004F29` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 5 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 6 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 7 | `adaptive` | 1 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 832736794 | 831448160 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 829509705 | 829395629 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 829309588 | 829061755 | 0 | 0 | `0x15F` | `fatal_training` |
| 3 | 831370509 | 832398400 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 829709413 | 829005203 | 0 | 0 | `0x15F` | `fatal_training` |
| 5 | 827947568 | 827384237 | 0 | 0 | `0x15F` | `fatal_training` |
| 6 | 825592826 | 828958379 | 0 | 0 | `0x15F` | `fatal_training` |
| 7 | 826355322 | 825827737 | 0 | 0 | `0x15F` | `fatal_training` |
