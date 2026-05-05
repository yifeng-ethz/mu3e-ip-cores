# `system_20260504_full8lane_type0` - Full 8-lane FEB SciFi Type0 build

**Top:** `top_nostp_full8lane`
**Date:** 2026-05-04
**Status:** Integration build for the production-shaped 8-lane datapath.

## 1. Purpose

This build is the full-FEB parallel path to the single-lane focus image at
`firmware_builds/systems/system_20260504_emulator_type0/`. The focus image keeps
compile latency low for pre-rbCAM `arb_hit_type0` bring-up; this image preserves
the production-shaped 8-lane topology so the same IP can be signed against the
eventual FEB datapath.

The topology is derived from
`firmware_builds/systems/system_20260427_testplanphase5/syn/scifi_datapath_system_v3_pipe.qsys`
and generated only through `syn/build_full8lane_system.tcl`. The reference
system under `system_20260427_testplanphase5/` is read-only for this work.

## 2. Topology

```
JTAG / SC bridge -> mm_bridge -+-> emulator_mutrig_0..7
                               |        | hit_type0 (45b)
                               |        v
run_control_splitter ----------+-> arb_hit_type0_supercore_0 (LANE_COUNT=8)
                               |        ^
                               |        | real hit_type0 (45b)
                               +-> lvds_rx_controller_pro_0 (N_LANE=8)
                                      -> mutrig_frame_deassembly_0..7

arb_hit_type0_supercore_0.selected_out_0..7
    -> backpressure_fifo_0..7
    -> mux_mutrig2processor / mux_mutrig2processor_0
    -> mts_preprocessor_0..1
    -> hit_stack_subsystem_0..1
    -> packet scheduler / FEB egress
```

The production slow-control, run-control, LVDS, histogram, MTS, hit-stack,
packet scheduler, Firefly, MAX10, one-wire, temperature, and scratch-pad blocks
remain inherited from the 2026-04-27 8-lane reference. The legacy byte-stream
source mux and nested `mutrig_datapath_subsystem_*` lane wrappers are removed in
the generated local datapath because `arb_hit_type0_supercore` selects between
real and emulator sources after `mutrig_frame_deassembly` on the 45-bit Type0
stream.

## 3. Qsys Contract

- `syn/build_full8lane_system.tcl` is the canonical recipe.
- `script/regen_full8lane_system.sh` regenerates `components.ipx`, the local
  supercore subsystem, the full inner datapath, and the FEB wrapper system.
- Generated `*.qsys`, `*.sopcinfo`, and `synthesis/` outputs are made read-only
  after a successful regeneration.
- Direct edits to generated Qsys XML, SOPCINFO, IPX, or synthesis output are
  forbidden.

## 4. Type0 Integration

`arb_hit_type0_supercore_0` is configured as:

- `LANE_COUNT = 8`
- `MODE_DEFAULT = 0` (`REAL`)
- `WATCHDOG_DEFAULT = 500`
- one 32-word Avalon-MM CSR aperture per lane

Per-lane CSR apertures are mapped on 0x80-byte boundaries under the existing
debug aperture:

| Lane | Local CSR | JTAG master CSR |
|---:|---:|---:|
| 0 | `0x0280` | `0x2280` |
| 1 | `0x0300` | `0x2300` |
| 2 | `0x0380` | `0x2380` |
| 3 | `0x0400` | `0x2400` |
| 4 | `0x0480` | `0x2480` |
| 5 | `0x0500` | `0x2500` |
| 6 | `0x0580` | `0x2580` |
| 7 | `0x0600` | `0x2600` |

The existing emulator CSR windows stay at the inherited per-lane offsets. The
frame-deassembly and backpressure-FIFO CSR windows reuse the 8-lane reference
addresses so board scripts can keep the same lane indexing discipline.

## 5. Board Project

The Quartus project lives at
`syn/board_projects/fe_scifi_full8lane/` and uses the fixed FE SciFi pinout from
`fe_scifi_feb_v3`. The local `top.qip` points at
`../../full8lane_type0_system/synthesis/full8lane_type0_system.qip`; it does not
reference the 2026-04-27 generated Qsys output.

The timing target is the production 125 MHz board/LVDS clock set with datapath
sign-off at 1.1x, 137.5 MHz. The passing gate is slow 1100 mV 0 C setup and hold
closure across all clocks, ALM use at or below 90%, no new-IP Critical Warnings,
and a produced `output_files_full8lane/top_nostp_full8lane.sof`.

## 6. Bring-up Checks

1. Regenerate through `script/regen_full8lane_system.sh`.
2. Compile `top_nostp_full8lane`.
3. Confirm the scratch pad and histogram UID through slow control.
4. Confirm `arb_hit_type0_supercore_0.csr_0..7` UID/mode/status windows.
5. Exercise real mode first, then emulator mode, then mixed mode only after the
   per-lane real/emulator paths independently match the single-lane focus build.
