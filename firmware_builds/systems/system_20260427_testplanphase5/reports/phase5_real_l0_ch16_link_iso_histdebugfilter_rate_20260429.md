# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T19:41:40`
- SC link: `2`
- LVDS reset requested: `yes`
- Configured ASICs: `[0]`
- Channel enable override: `0x00010000`
- TDC-test channel override: `0x00010000`
- Window: `100` ms
- Classification: `aligned_idle_no_frames`

## Final LVDS Snapshot

| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 1 | `bit_slip` | 0 | 0 | 0 | `0xFFFFFFFF` | `n/a` | `4` | `0x15F` | `fatal_training` |
| 2 | `bit_slip` | 0 | 0 | 0 | `0xA45D16D1` | `n/a` | `3` | `0x15F` | `parity_error` |
| 3 | `bit_slip` | 0 | 0 | 0 | `0x00000002` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `bit_slip` | 0 | 0 | 0 | `0xA56648B3` | `n/a` | `3` | `0x15F` | `parity_error` |
| 5 | `bit_slip` | 0 | 0 | 0 | `0xA53923DC` | `n/a` | `3` | `0x15F` | `parity_error` |
| 6 | `bit_slip` | 0 | 0 | 0 | `0xA6519707` | `n/a` | `3` | `0x15F` | `parity_error` |
| 7 | `bit_slip` | 0 | 0 | 0 | `0xA705F1B9` | `n/a` | `3` | `0x15F` | `parity_error` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 839950040 | 835468484 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 832101593 | 832221539 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 835456367 | 834848193 | 0 | 0 | `0x15F` | `parity_error` |
| 3 | 835428420 | 836906590 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 833934405 | 833487001 | 0 | 0 | `0x15F` | `parity_error` |
| 5 | 835591577 | 835643228 | 0 | 0 | `0x15F` | `parity_error` |
| 6 | 831679566 | 831513906 | 0 | 0 | `0x15F` | `parity_error` |
| 7 | 827257522 | 825865036 | 0 | 0 | `0x15F` | `parity_error` |

## Configuration Commands

| ASIC | Opcode | Words | Status | Polls | Result |
|---:|---:|---:|---:|---:|---|
| 0 | `0x01100054` | 84 | `0x00000000` | 1 | `PASS` |
