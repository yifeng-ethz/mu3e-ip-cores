# Phase 6 Packet Path STP And Runtime Mux Status - 2026-05-02

## SignalTap Coverage

- FEB packet-path STP:
  `signaltap/phase6_feb_packet_path_pkt0001.stp`
- SWB packet-path STP:
  `/home/yifeng/packages/online_dpv2/online/switching_pc/a10_board/db/phase6_swb_packet_path_pkt0001.stp`
- Trigger packet id: `0x0001`, intended for arm-before-RUNNING correlation across FEB/SWB boards.
- FEB node check: `476/476` probes found.
- SWB node check: `242/242` probes found.

FEB tap groups include post-rbCAM, frame assembly, upload subsystem, and the
Firefly/XCVR packet path. SWB taps include FEB RX ingress and DMA-side packet
visibility.

The FEB STP debug image compiled as
`top_stp_pipe_phase6_packet_path`, but timing is not clean. The worst setup
slack recorded in the compile report is about `-4.875 ns`, so this image is
debug-only and should not be used as timing evidence.

## Runtime Mux / Histogram Snoop

Source IPs now present:

- `misc/mutrig_lane_source_mux`: per-lane real/emulator/round-robin source mux,
  default FIFO depth 16, 64-bit real/emu in/out/drop counters, clear on reset,
  RUN_SYNC, CSR word 0 write, or `CONTROL[8]`.
- `misc/histogram_snoop_selector`: nonblocking histogram observation selector,
  runtime switch between hit-processor output and rbCAM type-2 snoop.

Packaging lints passed:

- `mutrig_lane_source_mux_hw.tcl` vs `rtl/mutrig_lane_source_mux.sv`
- `histogram_snoop_selector_hw.tcl` vs `rtl/histogram_snoop_selector.sv`

The generated FEB datapath VHDL contains the intended histogram path:

```text
mts_preprocessor_0.hit_type1_out
  -> hist_hp_splitter_0
  -> hit_stack_subsystem_0.hit_type_1

hist_hp_splitter_0.out1
  -> histogram_snoop_selector_0.hp_in

hit_stack_subsystem_0.ring_buffer_cam_0_hit_type2_snoop
  -> histogram_snoop_selector_0.rb_in

histogram_snoop_selector_0.hist_out
  -> histogram_statistics_0.hist_fill_in
```

The current histogram rbCAM snoop is upper-side rbCAM0 only. Lower-side
visibility is covered by the SignalTap packet-path STP, but not by the single
histogram selector instance yet.

## Integration Blocker

The standalone `scifi_datapath_system_v3_pipe` generated simulation VHDL is
stale relative to the 26.3 source mux. A fresh `qsys-generate` attempt selected
the emulator rewrite-in-progress catalog and failed before producing a clean
system:

- missing `emulator_mutrig/rtl/emulator_mutrig_pkg.sv`
- emulator `_hw.tcl` references a missing `FIFO_DEPTH` parameter
- dangling emulator CSR/control/clock/reset/inject connections

Because of that, the `+TB_DP_HIST_SNOOP_TOGGLE` integration simulation case is
implemented in the TB source but not signed off against a freshly generated
standalone datapath image. I did not hand-edit generated VHDL.

## Live Board Snapshot

SC access through `/dev/uio0` works. Current live status is not suitable for a
real MuTRiG post-rbCAM delay plot:

- `PLL_LOCKED_REGISTER_R = 0x00000000`
- `LINK_LOCKED_LOW_REGISTER_R = 0x00000F00`
- `LINK_LOCKED_HIGH_REGISTER_R = 0x00000000`
- all `mutrig_lane_source_mux` real/emu input/output/drop counters read zero

The bench ticket used for this check was released after the snapshot.
