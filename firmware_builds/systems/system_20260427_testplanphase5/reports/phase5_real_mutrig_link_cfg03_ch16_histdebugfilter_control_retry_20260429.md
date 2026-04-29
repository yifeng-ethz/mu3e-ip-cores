# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T19:27:20`
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
| 0 | 833770429 | 839016704 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 836817725 | 838305344 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 841288125 | 840146427 | 0 | 0 | `0x15F` | `fatal_training` |
| 3 | 845034351 | 841394680 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 845245811 | 844476980 | 0 | 0 | `0x15F` | `fatal_training` |
| 5 | 844732191 | 846866769 | 0 | 0 | `0x15F` | `fatal_training` |
| 6 | 850399534 | 853403699 | 0 | 0 | `0x15F` | `fatal_training` |
| 7 | 841971074 | 843945065 | 0 | 0 | `0x15F` | `fatal_training` |

## Configuration Commands

| ASIC | Opcode | Words | Status | Polls | Result |
|---:|---:|---:|---:|---:|---|
| 0 | `0x01100054` | 84 | `0x00000000` | 1 | `PASS` |
| 3 | `0x01130054` | 84 | `0x00000000` | 1 | `PASS` |
