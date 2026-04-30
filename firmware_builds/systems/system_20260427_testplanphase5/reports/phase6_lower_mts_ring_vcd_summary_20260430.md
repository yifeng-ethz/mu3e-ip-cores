# Phase 6 Lower MTS/Ring SignalTap VCD Summary

- VCD: `firmware_builds/systems/system_20260427_testplanphase5/captures/phase6_lower_mts_ring_p6b010_20260430_1758.vcd`
- Samples: `801`
- Time window: `0` to `1023500` ps
- Tracked scalar probes: `1085` (deasm0=57, deasm1=28, deasm2=28, deasm3=28, deasm4=28, deasm5=28, deasm6=28, deasm7=28, hist_ingress=96, hist_stats=59, hit_stack1=219, mts0=153, mts1=153, mux0=19, mux1=19, mux2=19, mux3=19, mux4=19, mux5=19, mux6=19, mux7=19)

## First Observed Events

| Signal | First high ps | Rising edges | Ever high |
|---|---:|---:|---:|
| `mux5.aso_valid` | 500 | 1 | 1 |
| `mux6.aso_valid` | 500 | 1 | 1 |
| `deasm5.aso_hit_type0_valid` | 111500 | 2 | 1 |
| `deasm6.aso_hit_type0_valid` | 111500 | 2 | 1 |
| `mts1.asi_hit_type0_valid` | 116500 | 1 | 1 |
| `mts1.aso_hit_type1_valid` | 127500 | 1 | 1 |
| `mts1.aso_hit_type1_error` | 128500 | 1 | 1 |
| `mts1.hit_out_delay_error` | 127500 | 1 | 1 |
| `hit_stack1.hit_type_1_valid` | 127500 | 1 | 1 |
| `hit_stack1.hit_type_1_error[0]` | 128500 | 1 | 1 |

## Active Lower Lane Streams

- `mux5.aso_valid` first=500 rises=1 ever=1; data=0x1BC, 0x11C, 0x0C8, 0x092, 0x0C4, 0x001, 0x0E4, 0x0F9, 0x0A0, 0x008, 0x039, 0x19C; channel=0x5; error=0x0
  - `mux5.asi_real_valid` first=500 rises=1 ever=1
  - `mux5.asi_emu_valid` first=500 rises=1 ever=1
- `deasm5.aso_hit_type0_valid` first=111500 rises=2 ever=1; data=0x0000; channel=0x5; error=0x0
  - `deasm5.asi_rx8b1k_valid` first=500 rises=1 ever=1
- `mux6.aso_valid` first=500 rises=1 ever=1; data=0x1BC, 0x11C, 0x0C8, 0x092, 0x0C4, 0x001, 0x05C, 0x0E0, 0x080, 0x057, 0x099, 0x19C; channel=0x6; error=0x0
  - `mux6.asi_real_valid` first=500 rises=1 ever=1
  - `mux6.asi_emu_valid` first=500 rises=1 ever=1
- `deasm6.aso_hit_type0_valid` first=111500 rises=2 ever=1; data=0x0000; channel=0x6; error=0x0
  - `deasm6.asi_rx8b1k_valid` first=500 rises=1 ever=1

## MTS 1

- `mts1.asi_hit_type0_valid` first=116500 rises=1 ever=1; data=0x0A0793E60000, 0x0C0573820000; channel=0x15, 0x26; error=0x0
- `mts1.aso_hit_type1_valid` first=127500 rises=1 ever=1; data=0x28074C0C00, 0x30279B0000; channel=0x2, 0x0; error_scalar=first=128500 rises=1 ever=1
- `mts1.hit_out_delay_error` first=127500 rises=1 ever=1
- `mts1.aso_debug_ts_valid` first=127500 rises=1 ever=1 values=0x1383, 0x035D
- `mts1.aso_debug_burst_valid` first=128500 rises=1 ever=1 values=0xB471, 0x0200
- First `aso_hit_type1_error` context: `time=128500 asi_hit_type0_data=0x0C0573820000 asi_hit_type0_channel=0x26 asi_hit_type0_error=0x0 aso_hit_type1_data=0x30279B0000 aso_hit_type1_channel=0x0 aso_debug_ts_data=0x035D aso_debug_burst_data=0xB471`

## Hit Stack 1 / Ring

- `hit_stack1.hit_type_1_valid` first=127500 rises=1 ever=1; data=0x28074C0C00, 0x30279B0400; channel=0x2, 0x0; error=0x0, 0x1
- `hit_stack1.frame_debug_ts_valid` first=111500 rises=1 ever=1 values=0x0836
- `hit_stack1.frame_debug_burst_valid` first=- rises=0 ever=0 values=-
- `hit_stack1.frame_ts_delta_valid` first=- rises=0 ever=0 values=-
- `hit_stack1.ring_buffer_cam_0_filllevel_valid` first=500 rises=1 ever=1 values=0x0000
- `hit_stack1.ring_buffer_cam_1_filllevel_valid` first=500 rises=1 ever=1 values=0x0000
- `hit_stack1.ring_buffer_cam_2_filllevel_valid` first=500 rises=1 ever=1 values=0x0001, 0x0000
- `hit_stack1.ring_buffer_cam_3_filllevel_valid` first=500 rises=1 ever=1 values=0x0000
- First ring input-error context: `time=128500 hit_type_1_data=0x30279B0400 hit_type_1_channel=0x0 hit_type_1_error=0x1 frame_debug_ts_data=0x0836`

## Diagnostic Conclusion

- The lower MTS output error sideband is visible in this capture, so the run is not just a ring-local reject.
- The downstream hit stack/ring input error is also visible in the same exported window.
- Interpret this together with the live counters; the capture log reported `PRE (0 triggers seen)`, so this VCD is supporting evidence, not a standalone pass/fail gate.

