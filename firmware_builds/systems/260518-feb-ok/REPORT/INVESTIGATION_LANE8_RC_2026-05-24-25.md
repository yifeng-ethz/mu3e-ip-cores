# Lane 8 Run-Control Investigation Summary

Date: `2026-05-24` to `2026-05-25`

This summary preserves the compact audit trail for the FEB lane-8
run-control investigation. The bulky SignalTap CSV exports remain in the
local report directories listed below and are intentionally not staged in the
parent repository.

## Verdict

The FEB lane-8 receive chain is healthy with `RX_BITREV[8]=0`. The accepted
start-run failure was caused by issuing a bare SWB `rc_tool send start-run`
while the SWB reset-link FSM was already in the post-start state waiting for
`end-run`; the legal sequence emits the expected bytes and the FEB
`runctl_mgmt_host` accepts them.

## Evidence Pointers

| Round | Local report path | Key result |
|---|---|---|
| Initial lane-8 STP | `REPORT/lane8_stp_capture_20260525T054728Z/` | With `RX_BITREV[8]=1`, raw lane 8 was clean K28.5 (`0x0FA/0x305`) but decoded as `0x000` with error, proving runtime bit-reversal was wrong for this image. |
| Triple characterization | `REPORT/lane8_stp_triple_20260525T060520Z/` | `RX_BITREV[8]=0` decoded K28.5 cleanly with no error in CAP_A and CAP_C; `RX_BITREV[8]=1` broke the same raw stream in CAP_B. |
| SWB reset-link trace | `REPORT/swb_rc_tx_20260525T062626Z/` | SWB status was `0x12000004`, meaning `START_RUN` had already been accepted and the FSM was waiting for `END_RUN`; repeated bare `start-run` produced no new non-idle byte. |
| Legal sequence proof | `REPORT/legal_sequence_20260525T064323Z/` | `run-prepare --run 1`, `sync`, `start-run` were captured on FEB lane 8 with decode error zero; `LAST_CMD=0x12`, `RUN_NUMBER=1`, `RX_CMD_COUNT=4`, and `ACK_SYMBOLS=0xFDFE`. |

## Firmware Changes Preserved By This Commit Set

- `mu3e_lvds_controller` 26.2.8 adds the default-off `RX_BITREV` CSR at word
  28 / byte offset `0x70` for future per-lane 10-bit symbol bit-order
  correction. It is not enabled for lane 8 in the verified FEB v4 image.
- The generated FEB wrapper instance passes `RUN_START_ACK_SYMBOL=0xFE` and
  `RUN_END_ACK_SYMBOL=0xFD` to match the SWB reset-link listener. This is an
  in-tree generated-build override and must not be wiped by `qsys-from-tcl`.
- The `lvds_decoded` SignalTap instance in `fe_scifi_feb_v3/top.qsf` captures
  lane-8 raw symbols, decoded bytes/errors, synclink data/errors, and
  `runctl_mgmt_host` receive/host FSM signals.

## Operational Notes

- Keep `RX_BITREV[8]=0` for this FEB image.
- Use the legal reset-link command sequence:
  `run-prepare --run <N>`, `sync`, `start-run`, then `end-run`.
- If SWB status top byte is stuck at `0x12`, send `end-run`; if state is
  unclear, send `abort-run` before starting a new sequence.
- The local fallback path remains available:
  `sc_tool 2 write 0x0C013 0x00000012`.
