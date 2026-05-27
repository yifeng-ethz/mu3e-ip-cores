# Legal SWB Reset-Link Sequence Proof
Timestamp: `20260525T064323Z`
No compile, programming, RTL edit, STP source edit, commit, or push was performed. All SC/RC commands were wrapped with `~/.local/bin/swb_ring_lock`. The only FEB LVDS CSR access was the allowed write `sc_tool 2 write 0x0401C 0x00000000 --quiet` to force `RX_BITREV[8]=0`.
## Verdict
**DIAGNOSIS CONFIRMED:** the earlier `rc_tool send start-run` failure was command-order/state, not FEB lane-8 decode. After returning the SWB reset-link FSM to idle and issuing the legal sequence, FEB lane 8 captured clean D-bytes with `RX_BITREV[8]=0`, `runctl_mgmt_host` accepted the commands, `LAST_CMD=0x12`, and `RX_CMD_COUNT` advanced.
Note: the ASIC1 frame-deassembly raw 4-word snapshot at `0x04628` stayed `0x00000001 0x00000000 0x00000000 0x00000000`; this readback did not show `dbg_header` movement even though the run-control host output pulse is visible in STP.
## CSR Snapshots
| Snapshot | LAST_CMD | RUN_NUMBER | RX_CMD_COUNT | RX_ERR_COUNT | ACK_SYMBOLS | SWB RESET_LINK_STATUS | ASIC1 raw 4 words |
|---|---:|---:|---:|---:|---:|---:|---|
| baseline after cleanup | `0x13` | `0x00000000` | `1` | `0xFFFFFFFF` | `0xFDFE` | `0x13000000` | `0x00000001 0x00000000 0x00000000 0x00000000` |
| post requested legal sequence | `0x12` | `0x00000001` | `4` | `0xFFFFFFFF` | `0xFDFE` | `0x12000004` | `0x00000001 0x00000000 0x00000000 0x00000000` |
| post requested legal sequence +5s | `0x12` | `0x00000001` | `4` | `0xFFFFFFFF` | `0xFDFE` | `-` | `-` |
| final after targeted sync/start captures | `0x12` | `0x00000001` | `8` | `0xFFFFFFFF` | `0xFDFE` | `0x12000004` | `0x00000001 0x00000000 0x00000000 0x00000000` |

- Baseline was taken after `end-run` returned the SWB FSM to idle; that cleanup command itself was received (`LAST_CMD=0x13`, `RX_CMD_COUNT=1`).
- Requested legal sequence result: `run-prepare --run 1`, `sync`, `start-run` advanced `RX_CMD_COUNT` from `1` to `4` and latched `LAST_CMD=0x12`.
- `RX_ERR_COUNT` was already saturated at `0xFFFFFFFF` before this proof, so it cannot be used for a delta check in this run. SignalTap shows `stp_decoded_error_q[8]=0` and `asi_synclink_error=0` for every valid sample in all three command captures.
## SignalTap Captures
### CAP_LEGAL_RUN_PREPARE
CSV: `CAP_LEGAL/lvds_decoded_legal_20260525T064323Z.csv`

Excerpt CSV: `CAP_LEGAL/lvds_decoded_legal_20260525T064323Z_trigger_excerpt.csv`

Trigger fired: yes; valid samples: 4097; first decoded non-idle tick: `513`; decoded non-idle sequence: `0x010, 0x001, 0x000, 0x000, 0x000`.

| Metric | Histogram |
|---|---|
| `raw` | 0x0FA:2047, 0x305:2045, 0x274:3, 0x1B4:1, 0x1D4:1 |
| `decoded` | 0x1BC:4092, 0x000:3, 0x010:1, 0x001:1 |
| `error` | 0x0:4097 |
| `synclink_data` | 0x1BC:4092, 0x000:3, 0x010:1, 0x001:1 |
| `synclink_error` | 0x0:4097 |
| `asi_data` | 0x1BC:4092, 0x000:3, 0x010:1, 0x001:1 |
| `asi_error` | 0x0:4097 |
| `recv_state` | 0x00:4088, 0x01:4, 0x02:4, 0x04:1 |
| `aso_data` | 0x002:3579, 0x010:518 |
| `host_state` | 0x00:4094, 0x02:2, 0x01:1 |
| `rx_bitrev_data_d2[8]` | {0: 4097} |
| `aso_runctl_valid` | {0: 4096, 1: 1} |

| off | tick | raw | decoded | err | synclink | asi | recv_state | recv_cmd | pipe_start | pipe_done | aso_valid | aso_data | host_state |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| -8 | 505 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x00` | `0x13` | `0` | `0` | `0` | `0x010` | `0x00` |
| -1 | 512 | `0x274` | `0x1BC` | `0x0` | `0x010` | `0x010` | `0x00` | `0x13` | `0` | `0` | `0` | `0x010` | `0x00` |
| 0 | 513 | `0x274` | `0x010` | `0x0` | `0x001` | `0x001` | `0x01` | `0x10` | `0` | `0` | `0` | `0x010` | `0x00` |
| 1 | 514 | `0x0FA` | `0x001` | `0x0` | `0x000` | `0x000` | `0x01` | `0x10` | `0` | `0` | `0` | `0x010` | `0x00` |
| 2 | 515 | `0x305` | `0x000` | `0x0` | `0x000` | `0x000` | `0x01` | `0x10` | `0` | `0` | `0` | `0x010` | `0x00` |
| 3 | 516 | `0x0FA` | `0x000` | `0x0` | `0x000` | `0x000` | `0x01` | `0x10` | `0` | `0` | `0` | `0x010` | `0x00` |
| 4 | 517 | `0x305` | `0x000` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x10` | `0` | `0` | `0` | `0x010` | `0x00` |
| 5 | 518 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x10` | `1` | `0` | `0` | `0x010` | `0x00` |
| 6 | 519 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x10` | `1` | `0` | `1` | `0x002` | `0x01` |
| 7 | 520 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x10` | `1` | `1` | `0` | `0x002` | `0x02` |
| 8 | 521 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x04` | `0x10` | `0` | `1` | `0` | `0x002` | `0x02` |
| 17 | 530 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x00` | `0x10` | `0` | `0` | `0` | `0x002` | `0x00` |

### CAP_SYNC
CSV: `CAP_SYNC/lvds_decoded_sync_20260525T064323Z.csv`

Excerpt CSV: `CAP_SYNC/lvds_decoded_sync_20260525T064323Z_trigger_excerpt.csv`

Trigger fired: yes; valid samples: 4097; first decoded non-idle tick: `513`; decoded non-idle sequence: `0x011`.

| Metric | Histogram |
|---|---|
| `raw` | 0x305:2049, 0x0FA:2047, 0x23B:1 |
| `decoded` | 0x1BC:4096, 0x011:1 |
| `error` | 0x0:4097 |
| `synclink_data` | 0x1BC:4096, 0x011:1 |
| `synclink_error` | 0x0:4097 |
| `asi_data` | 0x1BC:4096, 0x011:1 |
| `asi_error` | 0x0:4097 |
| `recv_state` | 0x00:4092, 0x02:4, 0x04:1 |
| `aso_data` | 0x004:3583, 0x002:514 |
| `host_state` | 0x00:4094, 0x02:2, 0x01:1 |
| `rx_bitrev_data_d2[8]` | {0: 4097} |
| `aso_runctl_valid` | {0: 4096, 1: 1} |

| off | tick | raw | decoded | err | synclink | asi | recv_state | recv_cmd | pipe_start | pipe_done | aso_valid | aso_data | host_state |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| -8 | 505 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x00` | `0x10` | `0` | `0` | `0` | `0x002` | `0x00` |
| -1 | 512 | `0x305` | `0x1BC` | `0x0` | `0x011` | `0x011` | `0x00` | `0x10` | `0` | `0` | `0` | `0x002` | `0x00` |
| 0 | 513 | `0x0FA` | `0x011` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x11` | `0` | `0` | `0` | `0x002` | `0x00` |
| 1 | 514 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x11` | `1` | `0` | `0` | `0x002` | `0x00` |
| 2 | 515 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x11` | `1` | `0` | `1` | `0x004` | `0x01` |
| 3 | 516 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x11` | `1` | `1` | `0` | `0x004` | `0x02` |
| 4 | 517 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x04` | `0x11` | `0` | `1` | `0` | `0x004` | `0x02` |
| 13 | 526 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x00` | `0x11` | `0` | `0` | `0` | `0x004` | `0x00` |

### CAP_START
CSV: `CAP_START/lvds_decoded_start_20260525T064323Z.csv`

Excerpt CSV: `CAP_START/lvds_decoded_start_20260525T064323Z_trigger_excerpt.csv`

Trigger fired: yes; valid samples: 4097; first decoded non-idle tick: `513`; decoded non-idle sequence: `0x012`.

| Metric | Histogram |
|---|---|
| `raw` | 0x0FA:2049, 0x305:2047, 0x134:1 |
| `decoded` | 0x1BC:4096, 0x012:1 |
| `error` | 0x0:4097 |
| `synclink_data` | 0x1BC:4096, 0x012:1 |
| `synclink_error` | 0x0:4097 |
| `asi_data` | 0x1BC:4096, 0x012:1 |
| `asi_error` | 0x0:4097 |
| `recv_state` | 0x00:4092, 0x02:4, 0x04:1 |
| `aso_data` | 0x008:3583, 0x004:514 |
| `host_state` | 0x00:4094, 0x02:2, 0x01:1 |
| `rx_bitrev_data_d2[8]` | {0: 4097} |
| `aso_runctl_valid` | {0: 4096, 1: 1} |

| off | tick | raw | decoded | err | synclink | asi | recv_state | recv_cmd | pipe_start | pipe_done | aso_valid | aso_data | host_state |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| -8 | 505 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x00` | `0x11` | `0` | `0` | `0` | `0x004` | `0x00` |
| -1 | 512 | `0x0FA` | `0x1BC` | `0x0` | `0x012` | `0x012` | `0x00` | `0x11` | `0` | `0` | `0` | `0x004` | `0x00` |
| 0 | 513 | `0x305` | `0x012` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x12` | `0` | `0` | `0` | `0x004` | `0x00` |
| 1 | 514 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x12` | `1` | `0` | `0` | `0x004` | `0x00` |
| 2 | 515 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x12` | `1` | `0` | `1` | `0x008` | `0x01` |
| 3 | 516 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x02` | `0x12` | `1` | `1` | `0` | `0x008` | `0x02` |
| 4 | 517 | `0x305` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x04` | `0x12` | `0` | `1` | `0` | `0x008` | `0x02` |
| 13 | 526 | `0x0FA` | `0x1BC` | `0x0` | `0x1BC` | `0x1BC` | `0x00` | `0x12` | `0` | `0` | `0` | `0x008` | `0x00` |

## Interpretation
- `RX_BITREV[8]=0` is confirmed at the data-domain tap in all captures.
- Lane 8 raw symbols are mostly alternating K28.5 (`0x0FA` / `0x305`) with clean non-idle 8b/10b symbols only around the triggered command bytes.
- The requested legal sequence cannot fit into one 4096-sample capture when commands are separated by 1 second; therefore `CAP_LEGAL_RUN_PREPARE` captures `0x10 + run_number`, and the additional no-compile targeted captures capture `0x11` and `0x12`.
- The SWB FSM status after the requested sequence is `0x12000004`, exactly the expected `START_RUN` accepted / wait-for-`END_RUN` state.
## Cheapest Follow-Up
Patch `rc_tool` ergonomics rather than RTL: either add a `start-sequence --run <N>` command that emits `end-run`/`abort-run` recovery as needed followed by `run-prepare`, `sync`, `start-run`, or make bare `send start-run` check `RESET_LINK_STATUS_REGISTER_R` and refuse with a state-specific hint when the SWB FSM is not in the start-run wait state.
