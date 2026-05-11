# Phase 6 ASIC0 Locked SignalTap Capture

- Timestamp: `2026-05-01T21:05`
- FEB STP image: `output_files_pipe_phase5_frame_hist_stp/top_stp_pipe_phase5_frame_hist.sof`
- FEB STP checksum at program time: `0x173CFF8D`
- Matching live STP trigger CRC: `0x239310A0`
- SWB recovery: reprogrammed `/home/yifeng/packages/online_sc/online/switching_pc/a10_board/output_files/top.sof`, checksum `0x31A72852`, then recovered `/dev/mudaq0`
- SC check after recovery: MTS UID at link 2, address `0x08890`, returned `0x4D4C534D`

## ASIC0 Configuration

- Config report: `phase6_signaltap_asic0_locked_config_20260501.md`
- ASICs configured: `[0]`
- Channel enable mask: `0xFFFFFFFF`
- TDC-test channel mask: `0xFFFFFFFF`
- Configuration result: `PASS`
- Frame delta after config: `0`

## SignalTap Captures

1. `phase6_frame_boundary_path_auto_stripped.stp`, trigger `histogram_ingress_bridge_0|aso_hist_valid == rising edge`
   - Result: timeout after 120 s, zero triggers.
   - Interpretation: no histogram ingress valid event reached the compiled trigger point.

2. Runtime trigger copy `phase6_frame_boundary_path_asic0_rxvalid_runtime_20260501.stp`, trigger `deasm0|asi_rx8b1k_valid == rising edge`
   - Result: timeout after 60 s, zero rising-edge triggers.
   - Interpretation: `asi_rx8b1k_valid` was already high/static, not a useful edge trigger in this state.

3. Runtime trigger copy `phase6_frame_boundary_path_asic0_mux_aso_valid_high_runtime_20260501.stp`, trigger `mutrig_lane_source_mux_0|aso_valid == high`
   - Result: capture succeeded.
   - VCD: `../captures/phase6_asic0_locked_mux_aso_valid_mts_ingress_egress_20260501.vcd`
   - WaveDrom summary: `phase6_signaltap_asic0_locked_capture_20260501.wavedrom.json`

## Captured Data Summary

The successful VCD captures the selected lane-source output plus frame-deassembly and MTS hit-processor probes.

Observed steady values in the capture:

| Stage | Signal | Value |
|---|---|---|
| lane mux 0 | `aso_valid` | `1` |
| lane mux 0 | `aso_channel` | `0x0` |
| lane mux 0 | `aso_error` | `0x0` |
| lane mux 0 | `aso_data` | `0x1BC` |
| deassembly 0 input | `asi_rx8b1k_valid` | `1` |
| deassembly 0 output | `aso_hit_type0_valid` | `0` |
| MTS0 input | `asi_hit_type0_valid` | `0` |
| MTS0 output | `aso_hit_type1_valid` | `0` |
| MTS0 decoded TS debug | `aso_debug_ts_valid` | `0` |
| MTS0 delay error | `hit_out_delay_error` | `0` |

The other selected lanes were also valid at the mux, but only carried idle/training-looking words:

- even lanes: `aso_data=0x1BC`, `aso_error=0x0`
- odd lanes 1/3/6/7: `aso_data=0x15F`, `aso_error=0x4`

## Independent LVDS Debug Cross-Check

Report: `phase6_signaltap_asic0_locked_link_debug_20260501.md`

- Classification: `aligned_idle_no_frames`
- 1 s window frame delta: `0` on all lanes
- ASIC0/lane0 final state: `aligned_idle`, last data `0x1BC`, real error `0`
- Lanes 1/3/6/7 final state: `fatal_training`, last data `0x15F`, real error `4`

## Interpretation

This run did not contain a decoded MuTRiG data frame. The SignalTap capture shows the raw selected stream is live, but it is idle/control data at the frame deassembly input. Because the deassembler never asserts `aso_hit_type0_valid`, the hit processor ingress, hit processor egress, decoded-TS debug, and histogram ingress valid points cannot assert.

The current STP image does not include the new 48-bit global timestamp counter probe. A new STP compile is needed to observe `counter_gts_8n` or the widened 48-bit MTS timestamp directly in hardware.
