# Soft-Reset Lane 8 + ASIC0 Histogram Remeasure

Date: 2026-05-25

Scope: no compile, no reprogram, no RTL edit, no commit. Every `sc_tool` and `rc_tool` command was wrapped with `~/.local/bin/swb_ring_lock`. LVDS CSR use was limited to one SOFT_RESET write and one DPALOCK read.

## Phase 1 - Lane 8 Soft Reset

### SOFT_RESET CSR

| Item | Value | Evidence |
|---|---:|---|
| LVDS CSR base | `0x04000` | v4 SC address map |
| `CSR_SOFT_RESET_ADDR_CONST` | word `6`, absolute SC word `0x04006` | `mu3e_lvds_controller.sv:111-118` |
| Reset request storage | `csr.soft_reset_req[31:0]` and data-domain mirror | `mu3e_lvds_controller.sv:189-206`, `:1277-1279` |
| Write semantics | ORs in written lane mask, masked by `ACTIVE_LANE_MASK_CONST` | `mu3e_lvds_controller.sv:1046-1050` |
| Completion semantics | RTL clears each requested bit after the request is observed idle for `SOFT_RESET_HOLD_CYCLES_CONST=8` | `mu3e_lvds_controller.sv:90`, `:1009-1017` |
| Reset effect | selected lane restarts training at `TRAIN_ASSERTING_DPA_RESET`, clears counters, asserts DPA/lock/fifo resets | `mu3e_lvds_controller.sv:1477-1494` |

This is a per-lane mask, not global. I wrote only lane 8:

```text
sc_tool 2 write 0x04006 0x00000100 --quiet
```

One DPALOCK sanity read after the reset:

```text
PHY_DPALOCK_STATUS @ 0x0400E = 0x000001FF
```

### Lane 8 SignalTap Recapture

SignalTap file: report-local copy `mutrig_cfg_lvds_lane8_kflag.stp`. I patched only the report-local trigger expression to:

```text
stp_decoded_data_q[8][8] == high
```

Acquisition completed immediately (`DONE`, no timeout), confirming the K flag was visible.

| Signal | Histogram |
|---|---|
| `coe_parallel_data[89:80]` | `0x305:2049`, `0x0FA:2048` |
| `stp_lane8_symbol_q[9:0]` | `0x0FA:2049`, `0x305:2048` |
| `stp_decoded_data_q[8][8:0]` | `0x1BC:4097` |
| `stp_decoded_error_q[8][2:0]` | `0x0:4097` |
| `stp_lane8_train_state_q[3:0]` | `0x7:4097` |
| `stp_lane8_good_count_q[7:0]` | `0x08:4097` |
| `stp_lane8_ctrl_q[8:0]` | `0x00F:4097` |
| `rx_bitrev_data_d2[8]` | `0x0:4097` |

Verdict: **LANE8_RECOVERED**. The 26.2.9 image can recover from the locked-to-nonsense lane-8 phase using the per-lane SOFT_RESET bit.

## Phase 2 - Histogram Remeasure

MuTRiG was reconfigured before the histogram run:

```text
SUMMARY pass=24 fail=0
```

Because lane 8 recovered, run-control used the normal SWB path:

```text
rc_tool send start-sequence --run 1000 --quiet
```

Run-control proof after start:

| Field | Value |
|---|---:|
| `LAST_CMD` | `0x12` |
| `RUN_NUMBER` | `1000` |
| `RX_CMD_COUNT` | `3` |
| `ACK_SYMBOLS` | `0x0000FDFE` |

Histogram config:

| Field | Value |
|---|---:|
| `LEFT_BOUND` | `0xFFFFFC18` (`-1000`) |
| `RIGHT_BOUND` | `0x00000C18` (`3096`) |
| `BIN_WIDTH` | `16` |
| `KEY_VALUE` | `0x00000000` |
| `CONTROL` write/readback | `0x00011015` / `0x00011014` |
| Injector | mode 1, interval 1, multiplicity 1, delay 100, channel 0, high 5 |

### Primary ASIC0 Result

CSV: `ASIC0_bins.csv`

| Metric | Value |
|---|---:|
| Total bin counts | `3171167` |
| Nonzero bins | `80` |
| Peak bin | `125` |
| Peak cycle center | `1008.0` |
| Weighted center | `1122.09` |
| Median | `1120.0` |
| Std dev | `276.95` cycles |
| P5 / P95 | `672.0 / 1552.0` |
| FWHM | `928` cycles |
| Shape | `MULTI_PEAK` |

Top bins:

| Rank | Bin | Cycle center | Count |
|---:|---:|---:|---:|
| 1 | 125 | 1008.0 | 56799 |
| 2 | 126 | 1024.0 | 56479 |
| 3 | 128 | 1056.0 | 56397 |
| 4 | 129 | 1072.0 | 56395 |
| 5 | 153 | 1456.0 | 55930 |
| 6 | 142 | 1280.0 | 55839 |
| 7 | 139 | 1232.0 | 55805 |
| 8 | 127 | 1040.0 | 55642 |
| 9 | 138 | 1216.0 | 55579 |
| 10 | 140 | 1248.0 | 55522 |

Comparison to prior ASIC0 default-range run: **SAME**. Prior FWHM was `928` cycles with the same `MULTI_PEAK` classification and essentially the same weighted center (`1122.00` vs `1122.09`).

### Quick Variants

| Variant | Run | Header delay | Multiplicity | Total counts | Peak cycle | Weighted center | FWHM | Shape | Interpretation |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Primary | 1000 | 100 | 1 | 3171167 | 1008.0 | 1122.09 | 928 | `MULTI_PEAK` | baseline |
| `ASIC0_mult4_delay100` | 1001 | 100 | 4 | 3860143 | 1120.0 | 1177.93 | 800 | `MULTI_PEAK` | more pulses changed weighting but did not make a delta |
| `ASIC0_mult1_delay50` | 1002 | 50 | 1 | 3030207 | 1264.0 | 1122.10 | 928 | `MULTI_PEAK` | no meaningful center/FWHM shift |
| `ASIC0_mult1_delay25` | 1003 | 25 | 1 | 3192075 | 1024.0 | 1121.92 | 928 | `MULTI_PEAK` | no meaningful center/FWHM shift |

The shorter header-delay tests did not move the weighted center. Multiplicity 4 changed the occupancy weighting and reduced FWHM to `800` cycles, but the distribution remained multi-peak and broad.

Final reset-link status:

```text
RESET_LINK_CTL_REGISTER_W        = 0x00000000
RESET_LINK_STATUS_REGISTER_R     = 0x13000000
RESET_LINK_RUN_NUMBER_REGISTER_W = 0x000003EB
last state byte                  = 0x13 (end-run)
```

## Verdict

**LANE8_RECOVERED; HIST_SHAPE_SAME.**

The lane-8 issue in the 26.2.9 debug image is recoverable with a per-lane LVDS soft reset. After recovery, the normal `rc_tool start-sequence` path latches `LAST_CMD=0x12` again. The ASIC0 histogram remains broad and multi-peak after fresh MuTRiG configure and clean run-control, so the 928-cycle FWHM is not caused by lane-8 bad training or stale run-control sequencing.

## Recommended Next Step

Use `sc_tool 2 write 0x04006 0x00000100` as the immediate lane-8 recovery step after programming this debug image. For the histogram width, the next useful debug is inside the histogram/type1 input path: probe or log the actual mode-1 key (`GTS - ts_sideband`) and the Type1-up source/tag fields, because changing header delay did not shift the measured center.

## Artifacts

- `soft_reset_lane8.log`
- `lane8_after_softreset_idle.csv`
- `lane8_after_softreset_idle_decode.json`
- `configure_mutrig.log`
- `configure_mutrig.md`
- `configure_mutrig.json`
- `hist_asic0_transcript.log`
- `hist_asic0_result.json`
- `ASIC0_bins.csv`
- `ASIC0_mult4_delay100/bins.csv`
- `ASIC0_mult1_delay50/bins.csv`
- `ASIC0_mult1_delay25/bins.csv`
- `final_stop_status.log`
