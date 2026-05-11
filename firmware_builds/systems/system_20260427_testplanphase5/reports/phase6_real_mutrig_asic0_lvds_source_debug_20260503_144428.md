# Phase-6 Real ASIC0 LVDS/Source Debug

- JSON: `firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_real_mutrig_asic0_lvds_source_debug_20260503_144428.json`
- Run: `70145`
- Stimulus: periodic injector mode=2, interval=12500 cycles (10 kHz), pulse_high=5, multiplicity=1; ASIC0 TDC mask was loaded before this run.

## before snapshot
- LVDS lane_go=0x1ff, mode_mask=0x1ff, soft_reset=0x000, fatal_lanes=[1, 3, 6, 7], symbol_errors=[0, 4294967295, 0, 4294967295, 0, 0, 4294967295, 4294967295, 0], dpa_unlocks=[0, 0, 0, 0, 0, 0, 0, 0, 0]
- Frame deassembly: L0:ctrl=0x00000001/crc=0/delta=0, L1:ctrl=0x00000001/crc=0/delta=0, L2:ctrl=0x00000001/crc=0/delta=0, L3:ctrl=0x00000001/crc=0/delta=0, L4:ctrl=0x00000001/crc=0/delta=0, L5:ctrl=0x00000001/crc=0/delta=0, L6:ctrl=0x00000001/crc=0/delta=0, L7:ctrl=0x00000001/crc=0/delta=0
- Source mux: L0:R=0 E=0 S=884740 RS=0 ES=0 ctrl=0x00000000, L1:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L2:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L3:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L4:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L5:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L6:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L7:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000
- rbCAM: L0:push=0 pop=0 inerr=0, L1:push=0 pop=0 inerr=0, L2:push=0 pop=0 inerr=0, L3:push=0 pop=0 inerr=0, L4:push=0 pop=0 inerr=0, L5:push=0 pop=0 inerr=0, L6:push=0 pop=0 inerr=0, L7:push=0 pop=0 inerr=0
- MTS: M0:hits=0 disc=0 ctrl=0x20000010, M1:hits=0 disc=0 ctrl=0x20000010

## after snapshot
- LVDS lane_go=0x1ff, mode_mask=0x1ff, soft_reset=0x000, fatal_lanes=[1, 3, 6, 7], symbol_errors=[2, 4294967295, 2, 4294967295, 2, 2, 4294967295, 4294967295, 0], dpa_unlocks=[0, 0, 0, 0, 0, 0, 0, 0, 0]
- Frame deassembly: L0:ctrl=0x00000001/crc=0/delta=0, L1:ctrl=0x00000001/crc=0/delta=0, L2:ctrl=0x00000001/crc=0/delta=0, L3:ctrl=0x00000001/crc=0/delta=0, L4:ctrl=0x00000001/crc=0/delta=0, L5:ctrl=0x00000001/crc=0/delta=0, L6:ctrl=0x00000001/crc=0/delta=0, L7:ctrl=0x00000001/crc=0/delta=0
- Source mux: L0:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L1:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L2:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L3:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L4:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L5:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L6:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000, L7:R=0 E=0 S=0 RS=0 ES=0 ctrl=0x00000000
- rbCAM: L0:push=0 pop=0 inerr=0, L1:push=0 pop=0 inerr=0, L2:push=0 pop=0 inerr=0, L3:push=0 pop=0 inerr=0, L4:push=0 pop=0 inerr=0, L5:push=0 pop=0 inerr=0, L6:push=0 pop=0 inerr=0, L7:push=0 pop=0 inerr=0
- MTS: M0:hits=0 disc=0 ctrl=0x20000011, M1:hits=0 disc=0 ctrl=0x20000011

## 1 s deltas
| Lane | LVDS symbol error status after | source real_in | source emu_in | selected | frame_delta | rbCAM push | rbCAM pop |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `0x00000002` | 0 | 0 | 4294082556 | 0 | 0 | 0 |
| 1 | `0xffffffff` | 0 | 0 | 0 | 0 | 0 | 0 |
| 2 | `0x00000002` | 0 | 0 | 0 | 0 | 0 | 0 |
| 3 | `0xffffffff` | 0 | 0 | 0 | 0 | 0 | 0 |
| 4 | `0x00000002` | 0 | 0 | 0 | 0 | 0 | 0 |
| 5 | `0x00000002` | 0 | 0 | 0 | 0 | 0 | 0 |
| 6 | `0xffffffff` | 0 | 0 | 0 | 0 | 0 | 0 |
| 7 | `0xffffffff` | 0 | 0 | 0 | 0 | 0 | 0 |

Interpretation rule: for this real-mode test, ASIC0 should show nonzero source real_in and selected beats near 320k hits/s for a 10 kHz pulse with 32 active TDC channels. If emu_in advances but real_in does not, the FPGA injector pulse path is alive while the real decoded MuTRiG stream is not reaching the source mux.
