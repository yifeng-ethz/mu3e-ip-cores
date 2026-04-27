# Run-Control Hit-Stack SignalTap Plan

## Goal

Localize the `STOP_RESET` / `0x001` ready-chain stall inside the FEB v3
hit-stack path without spending unnecessary ALMs on one oversized SignalTap
instance.

The FEB is already at `88,264 / 91,680 ALMs (96%)`, so each compile should
answer one narrow question.

## Pass Order

1. `hitstack0_stage`
   - Instrument the top-level `out6_valid/out6_ready` handoff into
     `hit_stack_subsystem_0`.
   - Instrument `run_control_splitter_0_out0..5_ready` inside the subsystem.
   - Instrument the CDC handoff only at handshake level:
     `run_control_splitter_0_out5_valid`,
     `run_ctrl_cdc_d2x_out_valid`,
     `run_ctrl_cdc_d2x_out_ready`,
     `rst_controller_001_reset_out_reset_ports_inv`.
   - Expected classification:
     - `out0..4_ready=1`, `out5_ready=0`: XCVR CDC leg is the blocker.
     - one of `out0..3_ready=0`: corresponding ring-buffer CAM path is the blocker.
     - `out4_ready=0`: `feb_frame_assembly` datapath leg is unexpectedly blocking.

2. `hitstack1_stage`
   - Same as pass 1, but for the top-level `out14_*` handoff into
     `hit_stack_subsystem_1`.
   - Use this if pass 1 shows asymmetry or if symmetry itself must be proven.

3. `targeted_followup`
   - If the CDC leg is the blocker, replace branch-level probes with a deeper
     FIFO-side pass around `run_ctrl_cdc_d2x`.
   - If a ring-buffer branch blocks, retarget the next pass to that
     `ring_buffer_cam_*` instance and its `asi_ctrl_ready` gating.

## Trigger Policy

- Default trigger: target top-level handoff valid high (`out6_valid` or
  `out14_valid`).
- Reason: the current failure is often already wedged when the capture arms, so
  `high` is more useful than `rising_edge` for first localization.

## Execution Notes

- Generate `.stp` files under `firmware_builds/systems/system_20260427_testplanphase5/signaltap/`.
- Validate probe names with `check_stp_nodes.py` before enabling the STP in the
  Quartus project.
- Import with `quartus_stp top -c top --enable --stp_file=<file>`.
- Compile with `watch_feb_quartus_compile.sh`; default heartbeat is 30 minutes,
  with a terminal bell and `notify-send` on completion.
