# Recover And Recapture - 26.2.9 Lane-7 STP Image

- Timestamp: `2026-05-25T20:24:56+02:00`
- Programmed image at start: `0x1A1178AE` 26.2.9 lane-7 STP debug SOF.
- Scope: no compile, no reprogram, no RTL edit, no commit.
- All `sc_tool` and `rc_tool` calls were wrapped with `~/.local/bin/swb_ring_lock`.
- Configure script internal SC calls used the local wrapper `sc_tool_locked`.
- LVDS CSR discipline: exactly 5 LVDS read transactions were used; no retry was needed.

## R1 - MuTRiG Reconfigure

| Item | Result |
|---|---|
| Configure script | `/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/system_20260427_testplanphase5/script/configure_mutrig_from_xml_v4addr.py` |
| MCC base in script | `0x01400` v4 address |
| SMB3 XML | `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/trash_bin/good_ribbon_0/config_smb3_tdc.txt` |
| SMB5 XML | `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/trash_bin/good_ribbon_0/config_smb5_tdc.txt` |
| Canonical CML sequence | start `0`, flush `8`, final `0`, `cml_sc=0` during flush/final |
| Result | `SUMMARY pass=24 fail=0` |

Artifacts:

- `configure_mutrig.log`
- `configure_mutrig.md`
- `configure_mutrig.json`

## R2 - LVDS CSR Sanity

Address references:

| Register | SC word | Source |
|---|---:|---|
| `PHY_LOSN_STATUS` | `0x0400C` | `CSR_PHY_LOSN_STATUS_ADDR_CONST = 10'd12` |
| `PHY_DPALOCK_STATUS` | `0x0400E` | `CSR_PHY_DPALOCK_STATUS_ADDR_CONST = 10'd14` |
| `LANE_SELECT` | `0x04010` | `CSR_LANE_SELECT_ADDR_CONST = 10'd16` |
| `LANE_TRAIN_STATUS` | `0x0401B` | `CSR_LANE_TRAIN_STATUS_ADDR_CONST = 10'd27` |

Raw readback:

| Read | Value |
|---|---:|
| `PHY_LOSN_STATUS @ 0x0400C` | `0x000001FF` |
| `PHY_DPALOCK_STATUS @ 0x0400E` | `0x000001FF` |
| lane 7 `LANE_TRAIN_STATUS @ 0x0401B` | `0x00010E0F` |
| lane 8 `LANE_TRAIN_STATUS @ 0x0401B` | `0x00010E0F` |
| lane 0 `LANE_TRAIN_STATUS @ 0x0401B` | `0x00010E0F` |

Selected-lane status decode:

| Lane | LOSN bit | DPALOCK bit | `LANE_TRAIN_STATUS` | lane_go | pll | selected_losn | selected_dpa | train_state | lane_good_count | bitslip | resets/holds |
|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---|
| 0 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 1 | 1 | 1 | not selected | - | - | - | - | not read | - | - | not read |
| 2 | 1 | 1 | not selected | - | - | - | - | not read | - | - | not read |
| 3 | 1 | 1 | not selected | - | - | - | - | not read | - | - | not read |
| 4 | 1 | 1 | not selected | - | - | - | - | not read | - | - | not read |
| 5 | 1 | 1 | not selected | - | - | - | - | not read | - | - | not read |
| 6 | 1 | 1 | not selected | - | - | - | - | not read | - | - | not read |
| 7 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 8 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |

This did not match the requested Case A/B/C split. Lane 7 is not BITSLIPPING after the reconfigure and is not in a no-signal state according to CSR. I classify the CSR state as:

```text
CASE D: RECOVERED_LANE7_HEALTHY_BY_CSR
```

## Lane 8 Runctl Re-Verify

After the same reconfigure, a legal reset-link sequence still did not latch at `runctl_mgmt_host`.

| Snapshot | SWB status | `LAST_CMD` | `RUN_NUMBER` | `RX_CMD_COUNT` | `RX_ERR_COUNT` | `ACK_SYMBOLS` |
|---|---:|---:|---:|---:|---:|---:|
| baseline before run 800 | `0x13000000` | `0x00` | `0` | `0` | `0xFFFFFFFF` | `0xFDFE` |
| after `start-sequence --run 800` | `0x12000004` | `0x00` | `0` | `0` | `0xFFFFFFFF` | `0xFDFE` |

The SWB FSM reached `0x12` as expected, so the command sequence was issued. The FEB run-control host did not accept any command in this 26.2.9 debug image.

## R3 - Lane-7 STP Recapture

Trigger used:

```text
stp_lane7_needs_bitslip_q == high
```

The first acquisition used the legacy fixed data-log name `lvds_cap` and produced a duplicate-data-log warning; that CSV matched the stale pre-recovery buffer and is not used for the verdict. I reran with a unique data-log name using `stp_acquire_lvds_unique.tcl`; this is the authoritative capture.

| Item | Value |
|---|---|
| Authoritative CSV | `lane7_after_reconfig_unique.csv` |
| Trigger result | timeout after 20 s; no `stp_lane7_needs_bitslip_q` high sample |
| Export | success; 4095 valid samples decoded |
| Stimulus during capture | `start-sequence --run 802`, then `stop-sequence` |

### Lane 7

| Signal | Histogram |
|---|---|
| `coe_parallel_data[79:70]` | `0x305:2028, 0x0FA:2027, other:40` |
| `stp_lane7_symbol_q[9:0]` | `0x305:2028, 0x0FA:2027, other:40` |
| `stp_decoded_data_q[7][8:0]` | `0x1BC:4055, other:40` |
| `stp_decoded_error_q[7][2:0]` | `0x0:4095` |
| `stp_lane7_train_state_q[3:0]` | `7:4095` |
| `stp_lane7_good_count_q[7:0]` | `8:4095` |
| `stp_lane7_ctrl_q[8:0]` | `0x00F:4095` |
| `stp_lane7_needs_bitslip_q` | `0:4095` |
| `stp_lane7_comma_seen_q` | `1:4055, 0:40` |

K28.5 classification:

| Raw value | Count | Meaning |
|---:|---:|---|
| `0x305` | 2028 | standard K28.5 RD+ |
| `0x0FA` | 2027 | standard K28.5 RD- |

Lane 7 is clean in the recapture: standard K28.5, no bit rotation, no decode errors, `HOLDING_LOCK`.

### Lane 0 Baseline

| Signal | Histogram |
|---|---|
| `stp_lane0_symbol_q[9:0]` | `0x0FA:2028, 0x305:2027, other:40` |
| `stp_decoded_data_q[0][8:0]` | `0x1BC:4055, other:40` |
| `stp_decoded_error_q[0][2:0]` | `0x0:4095` |
| `stp_lane0_train_state_q[3:0]` | `7:4095` |
| `stp_lane0_ctrl_q[8:0]` | `0x00F:4095` |

### Lane 8 / Runctl Path

| Signal | Histogram |
|---|---|
| `coe_parallel_data[89:80]` | `0x053:2048, 0x3AC:2047` |
| `stp_lane8_symbol_q[9:0]` | `0x3AC:2048, 0x053:2047` |
| `stp_decoded_data_q[8][8:0]` | `0x000:4095` |
| `stp_decoded_error_q[8][2:0]` | `0x1:4095` |
| `stp_lane8_train_state_q[3:0]` | `7:4095` |
| `synclink_data/error` | `0x000 / 0x1` for all 4095 samples |
| `asi_synclink_data/error` | `0x000 / 0x1` for all 4095 samples |
| `recv_run_command` | `0x00:4095` |
| `aso_runctl_valid` | `0:4095` |

Lane 8 is still the active blocker in this image. It reports `HOLDING_LOCK` at the training FSM, but the raw symbols are not any K28.5 standard or rotated variant and decode as code violations. That matches the runctl CSR non-latch.

## R4 - Histogram Remeasure

Skipped.

Reason: R4 was gated on Case A and lane 8 healthy. The post-reconfigure result is Case D (`lane7 recovered/healthy`) while lane 8/runctl is not healthy, so the ASIC0 histogram remeasure would not answer the requested question.

## Verdict

**RECOVERED_LANE7_HEALTHY; LANE8_STILL_BAD_IN_26.2.9_DEBUG_IMAGE.**

The MuTRiG reconfigure restored lane 7. CSR and SignalTap both show lane 7 receiving standard K28.5 `0x0FA/0x305`, decoding `9'h1BC`, and holding lock with no bitslip request. The remaining failure is lane 8/run-control: SWB sends the legal sequence and reaches `0x12`, but FEB lane 8 raw symbols are `0x053/0x3AC`, decode with `error[0]=1`, and `runctl_mgmt_host` never accepts the command.

## Recommended Next Debug

1. Keep the 26.2.9 debug image loaded.
2. Focus the next round on lane 8 raw symbol source/order in this image: compare the currently captured `0x053/0x3AC` pair against the prior known-good lane-8 legal-sequence capture and the SWB TX reset-link STP.
3. Do not chase lane 7 RTL right now; the recovered capture does not support a lane-7 firmware bitslip bug.
4. Defer histogram remeasure until lane 8 run-control latches again, because the run start is not currently reaching `runctl_mgmt_host`.

## Artifacts

- `lvds_sanity_reads.log`
- `runctl_lane8_verify.log`
- `quartus_stp_lane7_after_reconfig_unique.log`
- `lane7_after_reconfig_unique.csv`
- `stp_decode_after_reconfig_unique.txt`
- `stp_acquire_lvds_unique.tcl`
