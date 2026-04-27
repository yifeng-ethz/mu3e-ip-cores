# FEB SciFi v3 Pipe Test Blockers

- Timestamp: `2026-04-24T09:18:00+02:00`
- Target SOF/JDI: `board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof`, `top_nostp_pipe.jdi`
- Live FEB JTAG hash: `768B16B404A0AA5F62D5`
- Expected pipe JDI hash: `768B16B404A0AA5F62D5`
- SWB reset-link state left released: `RESET_LINK_STATUS_REGISTER_R = 0x31000000`

## Result

Phase 1 is not clean on the corrected pipe image, so TEST_PLAN Phase 2/3/4 should remain blocked.

The earlier `phase1_bringup_20260424_pipe.md` and `phase2_bist_20260424_pipe.md` should not be treated as pipe sign-off evidence because the board was previously live with the non-pipe `top.sof` hash `2270259588886FB6FD82`.

## Evidence

- Reprogrammed FEB with `top_nostp_pipe.sof`; `jtagconfig -n` reports USB-BlasterII hash `768B16B404A0AA5F62D5`.
- Added a Phase 1 image guard in `run_phase1_bringup.py`; the corrected report now records both expected and live hashes before probing.
- Added `--enable-mask` support through `sc_tool` and the Python Phase 1 helpers so link-specific SC tests can avoid the all-links secondary-ring flood.
- Masked Phase 1 report: `firmware_builds/board_test/reports/phase1_bringup_20260424_pipe_mask0x4.md`.

## Current Observations

- Control-path JTAG works when SWB reset-link state is released:
  - `SC hub UID = 0x53434842`
  - `runctl UID = 0x52434D48`
  - `runctl META = 0x1A0221A7`
  - `runctl STATUS = 0x80000003`
- Leaving SWB reset-link state at `0x30` holds the control path in reset after reprogramming; `rc_tool send stop-reset --feb 7` restores JTAG access.
- With `--enable-mask 0x4`, some local SC reads can return, but the run is not stable enough for sign-off:
  - scratchpad/max10/onewire/legacy bridge were observed responding in the masked Phase 1 report.
  - `firefly_xcvr_ctrl_0`, `on_die_temp_sense_ctrl`, `mutrig_cfg_ctrl_0`, `histogram_statistics_0`, `dbg_mm2runctrl_0`, and `upload_mm_bridge.runctl.sc` still failed in that report.
  - A follow-up masked scratchpad sweep immediately after the report returned no matching secondary replies for masks `0x4`, `0x100`, `0x200`, `0x400`, `0x800`, and `0xF00`; all-links mode produced only invalid/noisy secondary candidates.
- SWB link-lock low was `0x00000F00` after the latest masked tests, so the previously seen `0x00004F00` bit 14 is not currently locked.
- `rc_tool send enable --feb 7` updates the SWB echo to `0x32`, but `runctl_mgmt_host_0` still shows `LAST_CMD = 0` and no RX command count increment over JTAG.
- The legacy Firefly RX monitor bridge currently returns `0xCCCCCCCC`; inspection shows `firefly_xcvr_subsystem` feeds `firefly_reg_mapping` with `x"00" & i_mon_address`, while that register map compares against `0xFFxx` constants. That path is not a reliable RX monitor until the address high byte is fixed.

## Blocker

The remaining issue is no longer the 125 MHz control-plane timing closure. The pipe image is timing-clean and JTAG-visible, but SWB-to-FEB ingress is not proven:

- SC replies on link 2 are absent or unstable after masking to the intended link.
- Reset-link commands echo at the SWB, but `runctl_mgmt_host_0` does not count or log them.

## Next Probe

Build a pipe-specific SignalTap image that observes the actual ingress boundary before the SC hub/runctl logic:

- Firefly RX lane words/dataks and `sc_downlink_cdc_bridge` FIFO write/read/valid.
- `control_path_subsystem.sc_hub_hub_sc_packet_downlink_*`.
- `upload_subsystem_runctl_mgmt_host_0.synclink` and decoded command accept/count signals.
- Reset release state around `ext_reset_merge_async` and control-path reset.

Do not spend the next compile on the previous ready-chain stall trigger set until this ingress path is localized.
