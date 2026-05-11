# Phase 5 Real MuTRiG Link Debug Report

- Timestamp: `2026-04-29T22:42:48`
- SC link: `2`
- LVDS reset requested: `yes`
- Pre-config run-control reset/stop-reset: `yes`
- Configured ASICs: `[0, 1, 2, 3, 4, 5, 6, 7]`
- Channel enable override: `0xFFFFFFFF`
- TDC-test channel override: `0xFFFFFFFF`
- Window: `250` ms
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
| 0 | 965689357 | 964496074 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 1 | 964631158 | 966750572 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 2 | 965685847 | 965542359 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 3 | 962950676 | 963044272 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 4 | 964480970 | 964908293 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 5 | 974979190 | 974095275 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 6 | 980262138 | 979917557 | 0 | 0 | `0x1BC` | `aligned_idle` |
| 7 | 980501180 | 978175135 | 0 | 0 | `0x1BC` | `aligned_idle` |

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
| 1 | `0x01110054` | 84 | `0x00000000` | 1 | `PASS` |
| 2 | `0x01120054` | 84 | `0x00000000` | 1 | `PASS` |
| 3 | `0x01130054` | 84 | `0x00000000` | 1 | `PASS` |
| 4 | `0x01140054` | 84 | `0x00000000` | 1 | `PASS` |
| 5 | `0x01150054` | 84 | `0x00000000` | 1 | `PASS` |
| 6 | `0x01160054` | 84 | `0x00000000` | 1 | `PASS` |
| 7 | `0x01170054` | 84 | `0x00000000` | 1 | `PASS` |
