# Lane 7 Health Classification - 2026-05-25

## Scope

On-board only diagnostic against the already-programmed FEB image `0x1901CA52`.
No compile, reprogram, RTL edit, or LVDS burst read was performed.

## Source Map

LVDS controller base is SC word `0x04000`. The relative CSR constants are from
`mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv:121-130` and read mux lines
`888-913`.

| Register | Relative word | SC word | Source |
|---|---:|---:|---|
| `PHY_LOSN_STATUS` | `12` | `0x0400C` | `CSR_PHY_LOSN_STATUS_ADDR_CONST`, read as `redriver_losn_control_d2 & ACTIVE_LANE_MASK_CONST` |
| `PHY_DPALOCK_STATUS` | `14` | `0x0400E` | `CSR_PHY_DPALOCK_STATUS_ADDR_CONST`, read as `dpalock_control_d2 & ACTIVE_LANE_MASK_CONST` |
| `LANE_SELECT` | `16` | `0x04010` | selected-lane snapshot selector |
| `LANE_TRAIN_STATUS` | `27` | `0x0401B` | selected-lane snapshot |

`LANE_TRAIN_STATUS` is selected-lane, not packed per-lane. Source
`mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv:1235-1248` packs:

| Bits | Field |
|---:|---|
| `[0]` | `lane_go` |
| `[1]` | `pll_lock` |
| `[2]` | `redriver_losn` |
| `[3]` | `dpa_locked` |
| `[4]` | `dpa_reset` |
| `[5]` | `dpa_lock_reset` |
| `[6]` | `dpa_hold` |
| `[7]` | `fifo_reset` |
| `[8]` | `bitslip` |
| `[12:9]` | `train_state` |
| `[20:13]` | `lane_good_count` |
| `[22:21]` | `lane_mode` |
| `[23]` | `soft_reset_req` |

Training-state enum is from `mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv:162-171`:
`0=IDLING`, `1=WAITING_PLL`, `2=ASSERTING_DPA_RESET`, `3=WAITING_DPA`,
`4=ASSERTING_FIFO_RESET`, `5=BITSLIPPING`, `6=LOCKING`, `7=HOLDING_LOCK`,
`8=DEGRADING`.

## Read Discipline

Commands used `~/.local/bin/swb_ring_lock sc_tool 2 ... --quiet`.
Aggregate LVDS reads were one word each with 5 s spacing. Because
`LANE_TRAIN_STATUS` is selected-lane, each lane was selected once via
`LANE_SELECT` and read once, again with 5 s spacing between read transactions.
No `0xEEEEEEEE` timeout pad was observed; no retry was needed.

One lane-select write for lane 5 reported extra secondary-ring traffic, but the
matched write packet itself returned `rsp=OK` and the following selected-lane
read returned `rsp=OK`.

## Raw Readback

| Register | SC word | Value |
|---|---:|---:|
| `PHY_LOSN_STATUS` | `0x0400C` | `0x000001FF` |
| `PHY_DPALOCK_STATUS` | `0x0400E` | `0x000001FF` |

| Lane | `LOSN` bit | `DPALOCK` bit | `LANE_TRAIN_STATUS` | `lane_go` | `pll` | selected `losn` | selected `dpa` | `train_state` | `lane_good_count` | `bitslip` | resets/holds |
|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---|
| 0 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 1 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 2 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 3 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 4 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 5 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 6 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |
| 7 | 1 | 1 | `0x00000A0F` | 1 | 1 | 1 | 1 | `5 BITSLIPPING` | 0 | 0 | all 0 |
| 8 | 1 | 1 | `0x00010E0F` | 1 | 1 | 1 | 1 | `7 HOLDING_LOCK` | 8 | 0 | all 0 |

## Verdict

`ANOMALY`.

Lane 7 is not `PHYSICAL_NO_SIGNAL`: `LOSN[7]=1` means signal present and
`DPALOCK[7]=1` means the PHY reports DPA lock. It is also not
`LVDS_HEALTHY`, because the selected-lane training FSM is
`TRAIN_BITSLIPPING`, while lanes 0-6 and lane 8 are all `HOLDING_LOCK`.

This points to a lane-7-only alignment/8b10b stream issue after signal
presence and DPA lock, or to MuTRiG7 not emitting the legal idle/data stream
the controller expects. It does not support a dead cable/redriver no-signal
classification.

## Next Debug By Verdict Variant

| Verdict variant | Next debug |
|---|---|
| `PHYSICAL_NO_SIGNAL` | Inspect ASIC7 cable/redriver/ASIC output path and power before touching RTL. |
| `ELECTRICAL_DPA_FAIL` | Re-run DPA/phase training evidence and check signal integrity/timing margin. |
| `LVDS_HEALTHY` | Move upstream to MuTRiG configuration, header generation, and frame_deassembly setup. |
| `ANOMALY` observed here | Widen `lvds_decoded` STP for lane 7 raw 10-bit symbol, decoded byte, decoded error, and train-state bits. If raw symbols are valid but decoded errors persist, inspect lane-7 8b10b ordering/polarity/config. If raw symbols are malformed despite DPA lock, inspect MuTRiG7 output/configuration and redriver lane mapping. |
