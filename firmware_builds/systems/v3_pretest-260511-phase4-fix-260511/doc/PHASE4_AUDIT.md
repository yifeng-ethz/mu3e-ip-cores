# Phase 4 Datapath Audit: USE_READY=0 Splitter B002 Hunt

Build dir: `firmware_builds/systems/v3_pretest-260511-phase4-fix-260511/`
Audit date: 2026-05-11
Audit scope: `quartus_systems/scifi_datapath_system_v3_pipe.qsys` and
the cone reaching `mts_preprocessor_{0,1}` ingress.

## 1. Observed Phase 4 symptom

After Phase 4 section 4.3 drove `start-run (0x12)` to the FEB on the
`v3_pretest-260511-fix-runctl-reset-260511` baseline:

| Indicator | Value | Source |
|---|---|---|
| `runctl_mgmt_host_0.RX_CMD_COUNT` | increments +1 cleanly | SC CSR |
| `histogram_statistics_0.TOTAL_HITS` | 0 | SC CSR |
| `histogram_statistics_0.BANK_STATUS` | unchanged | SC CSR |
| `mts_preprocessor_0.PORT_STATUS` | `0x000000FF` (all 8 ingress FIFOs empty) | SC CSR |

The 0xFF on `PORT_STATUS` means every input AVST FIFO into the
preprocessor was empty for the entire >4s observation window. The
start-run command itself is being decoded at the management host (the
RX counter ticks), so the SC plane is healthy. The data plane (or the
control beat into the data plane) is stuck.

## 2. Hypothesis under audit

Memory `feedback_qsys_terminate_dangling` (B002 pattern):

> Un-terminated Avalon-ST interface inputs synthesize as 0 (AND default)
> or 1 (OR default). For USE_READY=0 splitter outputs, the downstream
> sink may have USE_READY=1, and Qsys auto-inserts a timing/channel
> adapter whose source-side `ready` defaults to 0, silently halting the
> entire broadcast.

The first place to look is `run_control_splitter` on the
runctl broadcast cone, because every `start-run` beat traverses it.

## 3. Splitters inventoried

In `scifi_datapath_system_v3_pipe.qsys` (master, version 3.0.1.0511):

| Splitter | USE_READY | NUMBER_OF_OUTPUTS | All outputs connected? |
|---|---|---|---|
| `emulator_ctrl_splitter` (line 1213) | 1 | 8 | yes (8/8 to emulator_mutrig_*.ctrl) |
| `hist_post_splitter_0` (line 1441) | 0 | 2 | yes (out0 exported, out1 -> hist_post_cdc_0) |
| `run_control_splitter` (line 2063) | 0 | 16 | yes (16/16, see below) |

USE_READY=1 splitter `emulator_ctrl_splitter` is not a B002 risk.

`hist_post_splitter_0` (USE_READY=0, 2 outputs):
- `out0` -> external interface `hit_type3_upper` (top-level)
- `out1` -> `hist_post_cdc_0.in`
- No dangling output.

`run_control_splitter` (USE_READY=0, 16 outputs):

| Out | Sink | Sink IP `run_ctrl` ready policy |
|---|---|---|
| out0 | `histogram_statistics_0.ctrl` | asi_ctrl_ready output (USE_READY=1) |
| out1 | `mts_preprocessor_0.run_ctrl` | asi_ctrl_ready output (USE_READY=1) |
| out2..5 | `mutrig_datapath_subsystem_{0,1,2,3}.run_ctrl` | USE_READY=1 |
| out6 | `hit_stack_subsystem_0.run_control_signal` | USE_READY=1 |
| out7 | `mutrig_reset_controller_0.runcontrol` | USE_READY=1 |
| out8..11 | `mutrig_datapath_subsystem_{4,5,6,7}.run_ctrl` | USE_READY=1 |
| out12 | `mts_preprocessor_1.run_ctrl` | USE_READY=1 |
| out13 | `mutrig_injector_0.runctl` | USE_READY=1 |
| out14 | `hit_stack_subsystem_1.run_control_signal` | USE_READY=1 |
| out15 | `emulator_ctrl_splitter.in` | USE_READY=1 |

All 16 outputs are connected. The mismatch between USE_READY=0 (splitter)
and USE_READY=1 (every sink) is the textbook B002 trigger condition.

## 4. Generated-RTL inspection

`feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_run_control_splitter.vhd`
is the Qsys wrapper around `altera_avalon_st_splitter`. The wrapper
exposes `out0_ready..out15_ready` as actual input ports (not terminated
inside the wrapper). The system stitcher wires each `outN_ready` to the
corresponding sink's `asi_ctrl_ready` (or `run_control_signal_ready`,
etc.) output - directly, with NO timing adapter in-between (data and
valid widths match, so Qsys decides no adapter is needed).

The wrapped IP `altera_avalon_st_splitter.sv` core logic (verified
against `/data1/intelFPGA/18.1/ip/altera/avalon_st/altera_avalon_st_splitter/altera_avalon_st_splitter.sv`):

```
QUALIFY_VALID_OUT == 0 (this instance) branch:
    OutValid[0..15] = in0_valid (unconditional - ignores OutReady)

assign in0_ready = &(OutReady[NUMBER_OF_OUTPUTS-1:0])
```

The implication is critical:
- The splitter broadcasts `valid` to all 16 outputs unconditionally
  whenever its `in0_valid` is asserted. The `outN_ready` inputs are
  *not* in the `outN_valid` cone - the data fires regardless of whether
  any sink is ready.
- The `outN_ready` inputs are only ANDed back into `in0_ready`. That
  feeds the upstream `run_control_mux.out_ready` (through
  `avalon_st_adapter_017`, an auto-inserted channel adapter).

Tracing the back-pressure path upward from the splitter:

```
run_control_splitter.in0_ready (= &OutReady)
  -> avalon_st_adapter_017.out_0_ready
  -> avalon_st_adapter_017.in_0_ready  (passes through)
  -> run_control_mux.out_ready
  -> run_control_mux.in0_ready  (when select=in0)
  -> runctl_mgmt_host_0.aso_runctl ready input
```

But `runctl_mgmt_host_hw.tcl` (line 531-533) declares the `runctl` AVST
source with `aso_runctl_data` + `aso_runctl_valid` only - NO
`aso_runctl_ready`. The IP documentation states:

> `runctl` is a 9-bit AVST source emitting one-hot decoded run-control
> states to all on-FPGA agents. The stream is readyless: valid marks a
> one-cycle broadcast beat and downstream agents cannot backpressure it.

So even if the splitter's `in0_ready` were stuck low (which it is, when
*any* sink ready is low at any moment), the upstream IP has no ready
input to receive that signal. The back-pressure is correctly absorbed
as a dangling input on the multiplexer's `in0_ready` output, and the
`aso_runctl_valid` will continue to fire at the multiplexer's `in0_valid`
input regardless.

## 5. B002 verdict for run_control_splitter

**No B002 pattern present.** The splitter is configured for
`QUALIFY_VALID_OUT=0`, which means each output's `valid` is the
unconditional copy of `in0_valid`. The `outN_ready` signals are wired
back to `in0_ready` only for the AND-of-readys, which in turn dies in
the readyless `aso_runctl` source. The splitter cannot halt the
broadcast in this configuration.

This matches the original design intent stated in `runctl_mgmt_host_hw.tcl`:
the runctl stream is intentionally fire-and-forget.

## 6. Phase 4 root cause is elsewhere

The Phase 4 `start-run` symptom (`PORT_STATUS = 0x000000FF`) is NOT
caused by the run-control AVST broadcast being silently halted by a
dangling splitter ready. Other candidate root causes that this audit
does not rule out:

1. **mts_preprocessor isn't sourcing hits from upstream.** The ingress
   FIFOs are downstream of `lvds_rx_controller_pro_0` decoded lanes /
   `decoded_lane_mux` / `mutrig_datapath_subsystem_*`. If the lvds
   front-end was not aligned (lock not asserted) or the emulator
   bypass wasn't engaged, no hits would arrive to fill the ingress
   FIFOs.
2. **mts_preprocessor `run_ctrl` decoded state never entered the
   accept-data state.** Even with the broadcast firing, the
   one-hot decode inside `mts_preprocessor_0` could be stuck in
   `IDLE` or `PRE_RUN` and gate the ingress. This is internal-state,
   not splitter-broadcast.
3. **Path between `lvds_rx_controller_pro_0` decoded lanes and
   `mts_preprocessor.ingress_*` carries a separate B002-like dangling
   ready** - that audit was NOT performed here because the splitter
   audit was the explicit scope. It is the obvious next item to
   audit if Phase 4 still fails after this rebuild.

## 7. Fix applied

NONE on Phase 4 audit. The compile bundles only:

- Hist-debug-disconnect on `scifi_datapath_system_v3.qsys` and
  `scifi_datapath_system_v3_pipe.qsys` (already on master, verified).
- Hist-debug-disconnect on `scifi_datapath_system_v3_lat4.qsys`
  (newly applied during this task for consistency, version bumped
  to 3.0.1.0511).
- SC-WEDGE fix on `feb_system_v3.qsys` master (copied from the
  on-board-verified syn-local fix in
  `firmware_builds/systems/v3_pretest-260511-fix-runctl-reset-260511/syn/feb_system_v3.qsys`,
  version bumped to 3.0.1.0511).

## 8. Recommended next investigation if Phase 4 still fails

1. Probe `mts_preprocessor_0` internal FSM via SignalTap:
   `asi_ctrl_valid`, `asi_ctrl_data`, and the decoded run-state
   register. Confirm whether the `start-run` beat propagates to the
   one-hot state register.
2. Probe `mts_preprocessor_0` ingress port valid signals (8 channels)
   with SignalTap. If they are stuck at 0, the gating is internal;
   if they pulse but `PORT_STATUS` stays 0xFF, the FIFO write-enable
   path has the bug.
3. Audit `decoded_lane_fifo_*` -> `decoded_lane_mux_*` -> `mux_mutrig2processor*`
   chain for un-terminated splitter/mux ready inputs (the same B002
   pattern but on the data plane).
