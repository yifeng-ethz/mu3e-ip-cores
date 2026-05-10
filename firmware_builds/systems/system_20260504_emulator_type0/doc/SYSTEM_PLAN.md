# `system_20260504_emulator_type0` — Focused single-lane bring-up build

**Top:** `top_nostp_emulator_type0`
**Date:** 2026-05-04
**Status:** Draft. Awaiting design approval.

## 1. Why a new build, not a fork

The Phase-6 closure system (`firmware_builds/systems/system_20260427_testplanphase5/`) is the active full-FEB build. Inheriting from it for the `arb_hit_type0` bring-up means we drag eight lanes of LVDS, eight emulator instances, full hit-stack, MTS, ring-CAM, frame-assembly, packet scheduler, and SignalTap probes into a debug exercise that only needs the pre-rbCAM stage. Compile turn-around is then ~50 min per iteration and every regression on those eight lanes is noise we did not ask for.

This focus build is a fresh single-lane Qsys system carrying only the known-good slow-control and run-control plumbing plus the minimum datapath needed to capture a pre-rbCAM histogram for **one** real ASIC and **one** emulator lane. Compiles fit in single-digit minutes and the failure surface is small enough that a regression points at exactly one IP.

The 8-lane integration is reapplied later as a separate Qsys-Tcl recipe once `arb_hit_type0` is signed off in this focus build and the contact-sheet-style golden references for real and emulated ASIC0 / emulator0 are recorded.

## 2. Topology

```
+-------------+       +-----------------------+
|  JTAG /     |       |  run_control_splitter |--> dp/ct hard reset, run-state
|  SC bridge  |       +-----------------------+
+-------------+              |
       |                      |  runctl AVST
       v                      v
+-----------------+   +-----------------------+
|  mm_bridge      |-->|  emulator_mutrig_qsys |   (LANE_COUNT=1, BYTE_STREAM_ENABLE=0)
|  (SC fanout)    |   |  _lane     "emu0"      |   exposes aso_hit_type0
+-----------------+   +-----------------------+
       |                                 |  hit_type0 (45b)
       |                                 v
       |   +-------------------+   +---------------------+
       +-->| mutrig_controller |   |  arb_hit_type0_0    |--> selected hit_type0
       |   | (SPI to ASIC0)    |   |  (REAL/EMU/MIX_RR)  |
       |   +-------------------+   +---------------------+
       |                                 ^
       |                                 |  hit_type0 (45b)
       |   +-------------------+   +-----------------------+
       +-->| mutrig_injector_0 |   | mutrig_frame_deassembly_0 |
       |   | (charge inject)   |   +-----------------------+
       |   +-------------------+         ^
       |                                 |  rx8b1k (9b)
       |   +-------------------+         |
       +-->| lvds_rx_controller_pro_0 (N_LANE=1)  |
           +-------------------+
                        ^
                        |  decoded LVDS
                +---------------+
                |  ASIC0 LVDS   |
                +---------------+

selected hit_type0 (45b) ---> backpressure_fifo (depth 128) ---> histogram_ingress_bridge_0 (pre-tap)
                                                            |
                                                            v
                                                histogram_statistics_0 (pre-rbCAM tap only;
                                                                        no MTS, no rbCAM, no
                                                                        hit-stack downstream)
```

Key omissions versus the legacy 8-lane system (intentional, to keep the build minimal):

- 7 of 8 lanes
- MTS preprocessor, ring-CAM, hit-stack, packet scheduler, framing, FEB frame assembly
- SignalTap probes outside the `arb_hit_type0` boundary (one focused STP at `selected_out`, see §4)

Kept verbatim from `system_20260427_testplanphase5` (known-good):

- `mm_bridge` SC fanout
- `run_control_splitter` (run-control broadcast)
- `lvds_rx_controller_pro` register set, with `N_LANE = 1`
- `mutrig_frame_deassembly` register set, single instance
- `mutrig_controller`, `onewire_master`, `firefly_xcvr_ctrl`, `max10_prog_avmm`, `charge_injection_pulser`, `mutrig_injector` — every IP that the existing `sc_tool` and `rc_tool` already address by name

## 3. Topology contract

- All edits to the focus build's qsys files go through `script/build_emulator_type0_system.tcl`. **Hard rule** (`AGENTS.md`): no direct XML edits. The Tcl recipe `chmod -R a-w` the generated `*.qsys`, `*.sopcinfo`, and `synthesis/` tree on success.
- The system carries one `arb_hit_type0_0` instance only. Adding more is the integration step, not the focus step.
- Histogram ingress is forced to the **pre-rbCAM stream** (`histogram_ingress_bridge_0.DEFAULT_SELECT_POST = 0`) so the captured plot is directly comparable to the contact-sheet shape.

## 4. SignalTap

One STP authored under `signaltap/` and packaged via the `signaltap-creation-co-debug` skill, sampling `arb_hit_type0_0.selected_out.{data,valid,sop,eop,eor,channel,error,last_grant}` plus the two ingress FIFO depths and `STATUS.in_packet_active`. The same probe set is mirrored in the integration testbench (`tb_int/`) so the sim and board waveforms can be compared frame-for-frame.

## 5. Bring-up sequence

1. **Generate qsys** through `build_emulator_type0_system.tcl`. Open Platform Designer GUI as the second pass to fix any elaboration warnings raised after Tcl-driven instantiation; commit the GUI's saved deltas back into the Tcl recipe rather than keeping GUI-only state.
2. **Compile Quartus** at the focus revision. Clip-name `top_nostp_emulator_type0`. On a passing compile + standalone bench, append `_ok` to the revision name and snapshot the project via Quartus' "Project → Archive Project" (`.qar` saved into `reports/<date>/`).
3. **Program SWB** from `online_sc/.../top.sof` (per `firmware_builds/doc/SETUP.md`) and **program FEB** from `output_files/top_nostp_emulator_type0_ok.sof`.
4. **Recover `/dev/mudaq0`** with `sudo -n /usr/local/sbin/mudaq_recover_pcie` after FEB reflash.
5. **Probe**: `sc_tool 2 read 0x00000` for the scratchpad, then `sc_tool 2 read <UID_word>` for `arb_hit_type0_0.UID` (= `0x41485430`).
6. **Single-lane focus tests** (rate and multiplicity sweeps for asic0 and emulator0 separately):
   - **real-rate sweep**: keep `arb_hit_type0_0.mode = REAL`. Drive `mutrig_injector_0` periodic mode 2 at 10k / 100k / 500k / 1M Hz with `pulse_high_cycles = 5`. Capture the pre-rbCAM `delay_hit_t` histogram per rate point. Render via the existing DISLIN contact-sheet pipeline (single-lane variant) into `reports/<date>/asic0_real_rate_contact_sheet.png`.
   - **real-multiplicity sweep**: same rates, with the MuTRiG XML configured for cluster sizes (1, 4, 8, 16, 32) channels via the `--channel-enable-mask` and `--tdctest-channel-mask` knobs. Render into `reports/<date>/asic0_real_multiplicity_contact_sheet.png`.
   - **emu-rate sweep**: switch `arb_hit_type0_0.mode = EMU`. Drive `emulator_mutrig_qsys_lane.frontend_csr` for the matching internal Poisson rate set (10k / 100k / 500k / 1M Hz) using the central-trigger plan's CSR contract. Capture the pre-rbCAM histogram. Render into `reports/<date>/emu0_emu_rate_contact_sheet.png`.
   - **emu-multiplicity sweep**: same rates, vary `cluster_geom_mode` and `cluster_size_random` per the central-trigger plan. Render into `reports/<date>/emu0_emu_multiplicity_contact_sheet.png`.

Reference for the rate sweep: the legacy contact sheet `firmware_builds/systems/system_20260427_testplanphase5/reports/assets/phase6_periodic_mode2_delay_rate_sweep_20260502/phase6_periodic_mode2_delay_rate_contact_sheet.png` is the architectural shape to match; the single-lane real-rate plot from this build replaces it as the **golden reference** for ASIC0.

## 6. SC / RC discipline

`sc_tool` and `rc_tool` are both single-outstanding on the SWB. Two hard rules:

1. **Never multi-thread on the SWB.** A second outstanding SC/RC command corrupts the PCIe ring, then `/dev/mudaq0` returns all-ones and the only recovery is a SWB reflash. The bring-up runner serialises every command through one channel.
2. **Always wait for the previous command's ack** before issuing the next. The runner records the ack token (`STATUS.last_cmd_ack` or the per-IP equivalent) before continuing; if the ack does not arrive in time-out, the runner aborts and dumps the SC bridge state for inspection. JTAG is the safe failover.

## 7. Approval gate

Approval is required on all of:

- `misc/arb_hit_type0/doc/RTL_PLAN.md`
- `misc/arb_hit_type0/tb/DV_PLAN.md`, `DV_HARNESS.md`, `DV_BASIC.md`, `DV_EDGE.md`, `DV_PROF.md`, `DV_ERROR.md`, `DV_CROSS.md`, `DV_COV.md`, `BUG_HISTORY.md`
- `firmware_builds/systems/system_20260504_emulator_type0/doc/SYSTEM_PLAN.md` (this file)

Until approval lands, no Qsys-Tcl recipe writes to disk, no compile is started, and no board is reprogrammed.
