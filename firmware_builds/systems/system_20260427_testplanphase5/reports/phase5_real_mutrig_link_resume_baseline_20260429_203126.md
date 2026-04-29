# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T20:31:27`
- SC link: `2`
- LVDS reset requested: `no`
- Pre-config run-control reset/stop-reset: `yes`
- Configured ASICs: `none`
- Channel enable override: `none`
- TDC-test channel override: `none`
- Window: `500` ms
- Classification: `aligned_idle_no_frames`

## Final LVDS Snapshot

| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `adaptive` | 1 | 0 | 0 | `0x00000010` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 1 | `bit_slip` | 0 | 0 | 0 | `0xFFFFFFFF` | `0` | `4` | `0x15F` | `fatal_training` |
| 2 | `bit_slip` | 0 | 0 | 0 | `0x736ABC8E` | `0` | `3` | `0x15F` | `parity_error` |
| 3 | `bit_slip` | 0 | 0 | 0 | `0x00000012` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `bit_slip` | 0 | 0 | 0 | `0x7506248D` | `0` | `3` | `0x15F` | `parity_error` |
| 5 | `bit_slip` | 0 | 0 | 0 | `0x1F042EE9` | `0` | `3` | `0x15F` | `parity_error` |
| 6 | `bit_slip` | 0 | 0 | 0 | `0x75FF5861` | `0` | `3` | `0x15F` | `parity_error` |
| 7 | `bit_slip` | 0 | 0 | 0 | `0x766878C8` | `0` | `3` | `0x15F` | `parity_error` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 1164766717 | 1166354376 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 1159950391 | 1160501331 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 1156429795 | 1157409892 | 0 | 0 | `0x15F` | `parity_error` |
| 3 | 1154493582 | 1155786658 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 1154058266 | 1153533213 | 0 | 0 | `0x15F` | `parity_error` |
| 5 | 1149234330 | 1146436873 | 0 | 0 | `0x15F` | `parity_error` |
| 6 | 1148335978 | 1149326037 | 0 | 0 | `0x15F` | `parity_error` |
| 7 | 1008051754 | 1007543830 | 0 | 0 | `0x15F` | `parity_error` |
