# Phase 6 Packet-Path SignalTap Compile Evidence - 2026-05-02

## FEB packet-path STP

- STP: `firmware_builds/systems/system_20260427_testplanphase5/signaltap/phase6_feb_packet_path_pkt0001.stp`
- Revision: `top_stp_pipe_phase6_packet_path`
- Output directory: `firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe_phase6_packet_path_stp/`
- SOF: `top_stp_pipe_phase6_packet_path.sof`
- RBF: `top_stp_pipe_phase6_packet_path.rbf`
- Flow status: `Successful - Sat May  2 17:22:50 2026`
- Compile summary: `Quartus Prime Full Compilation was successful. 0 errors, 2114 warnings`
- SOF SHA256: `96d7afa18423e40b99a9280fb4b38cbd9d762c039c7a7ceeac83a717418236d9`
- RBF SHA256: `fb26d085780b4342302ac7d009e6b1c3dbeda7c2de6dc91aac3a817cab8c09ad`

The STP taps packet-path visibility after rbCAM, after frame assembly, the upload/Firefly XCVR path, and uses a packet-id trigger for synchronized arming before `RUNNING`.

NodeFinder result: `phase6_feb_packet_path_stp_nodecheck_20260502.md` reports 476/476 probes found, 0 missing.

## SWB packet-path STP

- STP: `/home/yifeng/packages/online_dpv2/online/switching_pc/a10_board/db/phase6_swb_packet_path_pkt0001.stp`
- Revision file prepared: `/home/yifeng/packages/online_dpv2/online/switching_pc/a10_board/top_phase6_packet_path.qsf`
- Trigger: packet id `0x0001` on the selected FEB RX packet header path.

NodeFinder result: `phase6_swb_packet_path_stp_nodecheck_20260502.md` reports 242/242 probes found, 0 missing.

## Timing

The STP revision is fit/assembler successful but not timing-clean:

- Setup critical warning at `top_stp_pipe_phase6_packet_path.sta.rpt:3043`, worst setup slack `-4.875 ns`.
- Setup critical warning at `top_stp_pipe_phase6_packet_path.sta.rpt:3825`, worst setup slack `-4.700 ns`.
- Hold slack is positive in the reported groups.
- The design is also reported as not fully constrained for setup and hold requirements.

This image should be treated as a debug image, not a timing signoff image.

## Live Hardware Status

Post-compile live status check was blocked by the same slow-control link failure seen earlier:

- `/dev/mudaq0` was absent.
- `/dev/uio0` was present.
- `sc_tool 2 diag --device /dev/uio0 --reply-timeout-ms 200 --main-timeout-ms 200` returned `err: timed out waiting for matching secondary reply`.
- Board status from the same probe:
  - `PLL_LOCKED_REGISTER_R = 0x00000000`
  - `LINK_LOCKED_LOW_REGISTER_R = 0x00000000`
  - `LINK_LOCKED_HIGH_REGISTER_R = 0x00000000`
  - `RESET_LINK_STATUS_REGISTER_R = 0x0000FFFF`
- `rc_tool status --device /dev/uio0 --feb 7 --settle-us 1000` only confirmed `RESET_LINK_STATUS_REGISTER_R = 0x0000FFFF`.

Because the SC path is not returning matched secondary replies and the link lock registers are zero, FEB-to-SWB packet delivery with the packet-id trigger has not been validated on live hardware in this run.
