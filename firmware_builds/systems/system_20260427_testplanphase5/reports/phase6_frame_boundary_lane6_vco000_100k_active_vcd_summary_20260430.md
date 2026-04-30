# Phase 6 Frame-Boundary SignalTap VCD Summary

- VCD: `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/captures/phase6_frame_boundary_lane6_vco000_100k_active_20260430.vcd`
- Hit stack: `1`
- Samples: `318`
- Time window ps: `[0, 1022500]`
- Tracked probes: `{'hs1': 108, 'hs1.rbcam0': 45, 'hs1.rbcam1': 45, 'hs1.rbcam2': 45, 'hs1.rbcam3': 45}`

## First Events

| Signal | First high ps | Rising edges |
|---|---:|---:|
| `hs1.hit_type3_endofpacket` | 248500 | 1 |
| `hs1.hit_type3_startofpacket` | 500 | 2 |
| `hs1.hit_type3_valid` | 500 | 1 |
| `hs1.rbcam0.aso_hit_type2_valid` | 29500 | 16 |
| `hs1.rbcam1.aso_hit_type2_valid` | 45500 | 16 |
| `hs1.rbcam2.aso_hit_type2_valid` | 61500 | 16 |
| `hs1.rbcam3.aso_hit_type2_valid` | 13500 | 16 |

## RBCAM Type2

- `hs1.rbcam0` events `16`, subheaders `16`, hits `0`, errors `0`, declared-hit hist `{'0': 16}`, observed-hit hist `{'0': 16}`, ts-delta hist `{'4': 15}`
- `hs1.rbcam1` events `16`, subheaders `16`, hits `0`, errors `0`, declared-hit hist `{'0': 16}`, observed-hit hist `{'0': 16}`, ts-delta hist `{'4': 15}`
- `hs1.rbcam2` events `16`, subheaders `16`, hits `0`, errors `0`, declared-hit hist `{'0': 16}`, observed-hit hist `{'0': 16}`, ts-delta hist `{'4': 15}`
- `hs1.rbcam3` events `16`, subheaders `16`, hits `0`, errors `0`, declared-hit hist `{'0': 16}`, observed-hit hist `{'0': 16}`, ts-delta hist `{'4': 15}`

## FEB Type3 Frames

- Events: `212`
- Frames: `1`
- Frame length histogram: `{'212': 1}`
- K-marker-looking words with data marker cleared: `1`
- frame @37500 ps len `212` first `0x1E00002BC` last `0x10000009C` header/trailer `True/True` debug sh/hit `10640/38960` decoded sh/hit `203/2` marker-cleared candidates `1`
