# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T19:43:49`
- SC link: `2`
- LVDS reset requested: `yes`
- Pre-config run-control reset/stop-reset: `yes`
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
| 2 | `bit_slip` | 0 | 0 | 0 | `0x586EC102` | `n/a` | `3` | `0x15F` | `parity_error` |
| 3 | `bit_slip` | 0 | 0 | 0 | `0x00000002` | `n/a` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `bit_slip` | 0 | 0 | 0 | `0x594A8E63` | `n/a` | `3` | `0x15F` | `parity_error` |
| 5 | `bit_slip` | 0 | 0 | 0 | `0x5560137B` | `n/a` | `3` | `0x15F` | `parity_error` |
| 6 | `bit_slip` | 0 | 0 | 0 | `0x5A50B57E` | `n/a` | `3` | `0x15F` | `parity_error` |
| 7 | `bit_slip` | 0 | 0 | 0 | `0x5ACC9302` | `n/a` | `3` | `0x15F` | `parity_error` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 825638489 | 828852854 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 828042852 | 825890172 | 0 | 0 | `0x15F` | `fatal_training` |
| 2 | 806939761 | 808945747 | 0 | 0 | `0x15F` | `parity_error` |
| 3 | 813617405 | 812861725 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 806349838 | 806265665 | 0 | 0 | `0x15F` | `parity_error` |
| 5 | 807835677 | 808521346 | 0 | 0 | `0x15F` | `parity_error` |
| 6 | 808283414 | 809736371 | 0 | 0 | `0x15F` | `parity_error` |
| 7 | 811976513 | 809723021 | 0 | 0 | `0x15F` | `parity_error` |

## Pre-Config Run-Control

```text
info: cmd=0x30 (reset) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000030
info: before: CTL=0x00000000 STATUS=0x13000000
info: after : CTL=0x00000000 STATUS=0x30000000
info: ok: o_state_out echoes 0x30
```
```text
info: cmd=0x31 (stop-reset) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000031
info: before: CTL=0x00000000 STATUS=0x30000000
info: after : CTL=0x00000000 STATUS=0x31000000
info: ok: o_state_out echoes 0x31
```


## Configuration Commands

| ASIC | Opcode | Words | Status | Polls | Result |
|---:|---:|---:|---:|---:|---|
| 0 | `0x01100054` | 84 | `0x00000000` | 1 | `PASS` |
