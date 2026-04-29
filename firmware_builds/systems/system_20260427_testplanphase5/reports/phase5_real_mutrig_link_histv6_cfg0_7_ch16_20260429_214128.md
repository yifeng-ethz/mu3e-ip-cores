# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T21:41:28`
- SC link: `2`
- LVDS reset requested: `yes`
- Pre-config run-control reset/stop-reset: `yes`
- Configured ASICs: `[0, 1, 2, 3, 4, 5, 6, 7]`
- Channel enable override: `0x00010000`
- TDC-test channel override: `0x00010000`
- Window: `1000` ms
- Classification: `aligned_idle_no_frames`

## Final LVDS Snapshot

| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 1 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 2 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 3 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 4 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 5 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 6 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |
| 7 | `adaptive` | 1 | 0 | 0 | `0x00000000` | `0` | `0` | `0x1BC` | `aligned_idle` |

## Window Delta

| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 1060417952 | 1059658858 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 1059994498 | 1064783904 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 2 | 1064293437 | 1060822277 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 3 | 1060711768 | 1060283415 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 1055582114 | 1054943779 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 5 | 1053784289 | 1055288142 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 6 | 1053456229 | 1052245967 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 7 | 1050804548 | 1048688421 | 0 | 0 | `0x1BC` | `aligned_idle` |

## Pre-Config Run-Control

```text
info: cmd=0x30 (reset) feb=7 -> RESET_LINK_CTL_REGISTER_W=0xE0000030
info: before: CTL=0x00000000 STATUS=0x31000000
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
| 1 | `0x01110054` | 84 | `0x00000000` | 1 | `PASS` |
| 2 | `0x01120054` | 84 | `0x00000000` | 1 | `PASS` |
| 3 | `0x01130054` | 84 | `0x00000000` | 1 | `PASS` |
| 4 | `0x01140054` | 84 | `0x00000000` | 1 | `PASS` |
| 5 | `0x01150054` | 84 | `0x00000000` | 1 | `PASS` |
| 6 | `0x01160054` | 84 | `0x00000000` | 1 | `PASS` |
| 7 | `0x01170054` | 84 | `0x00000000` | 1 | `PASS` |
