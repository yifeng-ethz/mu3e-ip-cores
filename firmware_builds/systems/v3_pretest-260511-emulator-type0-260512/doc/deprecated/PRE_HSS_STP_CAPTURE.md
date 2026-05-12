# Pre-HSS SignalTap Capture Report

Build: `v3_pretest-260511-rc-readyless-260511`
Date: 2026-05-12
Revision: `top_stp_phase4_pre_hss_gap`
STP instance: `phase4_pre_hss_gap_lvds`

## Status

The Phase 4 pre-HSS SignalTap image has now been programmed and captured in
two FEB/SWB hardware loops. This still does not close Phase 4.

The first loop used the original JTAG setup tuple with `SIGNAL=1`; it proved
that reset-link `start-run` reached lane 0 but that the byte-stream source
stayed dark. The follow-up sim reproduced that exact symptom and showed why:
`SIGNAL[0]=1` selects signal/external mode while the setup supplies no matching
external inject pulse.

The second loop corrected the stimulus class by using the fresh programmed
image's default internal-random `SIGNAL=0` state and triggered directly on
`emulator_mutrig_0.aso_tx8b1k_valid`. That capture moves the active blocker
downstream:

- reset-link `start-run` reaches the FEB and the emulator run-control logic;
- lane 0 `run_generating` asserts;
- `emulator_mutrig_0.aso_tx8b1k_valid` asserts and reaches the
  adapter/mux/FIFO valids;
- `mutrig_datapath_subsystem_0.headerinfo_valid` and
  `hit_type0_out_valid` never assert;
- MTS, histogram pre, histogram post, and HSS counters remain zero.

The earlier post-selected histogram activity is still word-counter smoke, not
legal hit-flow closure.

## Artifacts

Capture directory:

```text
signaltap/captures/phase4_pre_hss_gap_20260512_050729/
```

Key files:

| Artifact | Purpose |
|---|---|
| `program_feb.log` | programs the pre-HSS STP SOF |
| `mudaq_recover_pcie.log` | SWB PCIe driver recover/rebind |
| `jtag_setup_pre_skip_start_explicit_master.log` | first JTAG setup with explicit masters |
| `start_run_capture_retry.log` | original decoded-mux-valid trigger attempt |
| `jtag_setup_run_generating_after_cleanup.log` | clean setup for the retargeted trigger |
| `phase4_pre_hss_gap_trigger_run_generating.stp` | copied STP with trigger retargeted to `run_generating` rising edge |
| `run_generating_capture.log` | successful SignalTap capture and VCD export |
| `run_generating_start_run.vcd` | captured waveform |
| `run_generating_vcd_summary.log` | parsed handshake summary |
| `sc_*_after_stp_*.log` | post-capture CSR counter snapshots |
| `tb_int/tb_pre_hss_axis_hwstim.sv` | exact-stimulus sim mirror for the captured CSR tuple |
| `tb_int/sim_pre_hss_hwstim_20260512/` | directed sim logs and transcript |

Programmed SOF:

```text
syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.sof
```

The compile report records SHA-256
`bbb2b17af1a65c63394acfae40606968565dd562f54d5606ca6ce2aa77dd939c`.
`program_feb.log` shows Quartus programmed device `5AGXBA7D4F31@1`
successfully with checksum `0x147FE76A`, `0` errors, `0` warnings, followed by
the mandatory 20 s settle.

## Bench Setup

The bench was claimed with the shared bench queue before programming and was
released after teardown. PCIe recovery used:

```text
sudo -n /usr/local/sbin/mudaq_recover_pcie
```

`mudaq_recover_pcie.log` shows `mudaq` unloaded and reloaded for endpoint
`0000:0b:00.0` (`0x1172:0x0004`).

The successful JTAG setup needed explicit master patterns:

- data master:
  `*#7-2*/phy_1/data_path_subsystem_master_datapath.master`
- upload master:
  `*#7-2*/phy_2/upload_subsystem_upload_system_jtag_master.master`

The first valid setup used:

- `source_mode=emulator`
- `hist_snoop_source=pre`
- `active_lane=0`
- `emu_hit_rate=0x00000800`
- `emu_control=0x00000001`
- `emu_signal=0x00000001`
- `emu_cluster_width=1`
- `skip_runctl_start=1`

The cleanup/retry setup after the timed-out first capture used run number
`66105`, the same active lane and emulator settings, and reported
`PHASE6_JTAG_CASE_RESULT status=OK`.

## Capture Attempts

### Original Decoded-Mux Trigger

After setup, `rc_tool` sent `run-prepare`, `sync`, then the capture script
issued `start-run` while SignalTap was armed on the original
`decoded_mux_valid_rise` trigger.

`start_run_capture_retry.log` shows:

- reset-link status advanced from `0x11000003` to `0x12000004`;
- SignalTap reached `TIMEOUT`;
- the trigger did not occur within 120 s;
- no `start_run.vcd` was exported.

This is negative hardware evidence: no new decoded-mux valid rising edge was
seen after arming under that stimulus.

### Retargeted Run-Generating Trigger

The STP was copied to:

```text
phase4_pre_hss_gap_trigger_run_generating.stp
```

Only the trigger expression was changed, from decoded-mux output valid rising
edge to the lane-0 frontend `run_generating` rising edge. The trigger name in
the STP remains `decoded_mux_valid_rise`.

Before retrying, the run state was cleaned up with reset-link commands:

- `end-run`: status `0x12000004 -> 0x13000000`
- `reset`: status `0x13000000 -> 0x30000000`
- `stop-reset`: status `0x30000000 -> 0x31000000`

Then setup, `run-prepare`, and `sync` were repeated. The successful capture
issued `start-run`, advanced reset-link status from `0x11000003` to
`0x12000004`, reached SignalTap `DONE`, and exported:

```text
run_generating_start_run.vcd
```

Quartus SignalTap completed with `0` errors and `0` warnings.

## VCD Summary

`run_generating_vcd_summary.log` reports `77` signals and `2050` timestamps.
The connected handshake valids are the useful evidence; payload/channel/error
fields are not trusted because the STP compile was partially connected for
wide payload aliases.

| Signal | First high | Rises | Final | Interpretation |
|---|---:|---:|---:|---|
| `emulator_mutrig_0.asi_ctrl_valid` | `127500 ps` | `1` | `0` | start-run control reached emulator |
| `emulator_mutrig_0.asi_ctrl_ready` | `500 ps` | `1` | `1` | sink ready |
| `run_generating` | `128500 ps` | `1` | `1` | emulator run state asserted |
| `frame_rst` | `500 ps` | `1` | `0` | frame reset deasserted |
| `emulator_mutrig_0.aso_tx8b1k_valid` | never | `0` | `0` | byte-stream source dark |
| `avalon_st_adapter_032.in_0_valid` | never | `0` | `0` | no source valid into adapter |
| `avalon_st_adapter_032.out_0_valid` | never | `0` | `0` | no source valid out of adapter |
| `decoded_lane_mux_0.in1_valid` | never | `0` | `0` | byte-stream mux input dark |
| `mutrig_datapath_subsystem_0.hit_type0_out_valid` | never | `0` | `0` | no decoded type0 output |
| `mux_mutrig2processor.out_valid` | never | `0` | `0` | no MTS input stream |
| `mts_preprocessor_0.aso_hit_type1_valid` | never | `0` | `0` | no pre-HSS hit stream |
| `histogram_ingress_bridge_0.asi_pre_valid` | never | `0` | `0` | pre histogram input dark |
| `histogram_ingress_bridge_0.aso_hist_valid` | never | `0` | `0` | histogram stream dark |
| `hist_post_cdc_0.out_valid` | never | `0` | `0` | post path dark in this capture |

Some downstream valids (`decoded_lane_mux_0.out_valid`,
`decoded_lane_fifo_0.in_valid`, and `decoded_lane_fifo_0.out_valid`) were high
or toggled from the first captured sample even though the upstream
`tx8b1k_valid` and mux input were never valid. Treat those as stale, other-path,
or invalid-state observations, not as proof of legal hit flow.

## Post-Capture Counters

After the successful STP capture, SC reads still showed no legal hit movement:

| Readback | Evidence |
|---|---|
| Histogram stats `0x0A908`, 11 words | `PORT_STATUS=0x000000FF`, `TOTAL_HITS=0`, drops/underflow/overflow all `0` |
| `mts_preprocessor_0` `0x09000`, 5 words | visible totals zero; payload words `[1]`, `[3]`, `[4]` are `0` |
| `mts_preprocessor_1` `0x0A000`, 5 words | visible totals zero; extra secondary traffic warning recorded |
| HSS0 `0x0B400`, 8 words | type/id `0x38/0x2`; declared/actual/missing counters all `0` |
| HSS1 `0x0B410`, 8 words | type/id `0x38/0x2`; declared/actual/missing counters all `0` |
| Runctl LAST_CMD `0x0C004` | `0x00020012` |
| Runctl RX_CMD_COUNT `0x0C00F` | `0x00000010` |

Teardown sent `end-run`; `jtag_teardown_pre_end_run.log` reports
`runctl_last_cmd=0x00020013`, `runctl_status=0x00000003`, and
`PHASE6_JTAG_CASE_RESULT status=OK`.

## Interim Conclusion After SIGNAL=1 Capture

The first capture was the current hardware source of truth until the
corrected-stimulus run below:

1. The reset-link and JTAG setup path can put lane 0 into run-generating state.
2. Under that same board stimulus, the byte-stream valid source
   `emulator_mutrig_0.aso_tx8b1k_valid` does not assert.
3. No legal pre-HSS, MTS, histogram, rbCAM, HSS, or RDMA closure can be claimed
   until the byte-stream source is understood and a positive hit-flow capture
   exists.

## Directed Sim Confirmation

The follow-up directed sim uses the exact hardware CSR/stimulus tuple from this
capture:

- `active_lane=0`
- `source_mode=emulator`
- `hist_snoop_source=pre`
- `emu_hit_rate=0x00000800`
- `emu_control=0x00000001`
- `emu_signal=0x00000001`
- `MUTRIG_FORMAT=0x00000020`
- `cluster_fix=0x00004000`
- reset-link `run-prepare -> sync -> start-run`

Testbench:

```text
tb_int/tb_pre_hss_axis_hwstim.sv
```

Run directory:

```text
tb_int/sim_pre_hss_hwstim_20260512/
```

Result:

```text
PRE_HSS_HWSTIM_EXACT signal=0x1 format=0x20 cluster_fix=0x4000 tx_valid=0 type0=0 hit_debug=0 first_tx_ps=0 first_type0_ps=0 final_tx_data=0x1bc
PRE_HSS_HWSTIM_CONTROL signal=0x0 format=0x20 cluster_fix=0x4000 tx_valid=3038 type0=481 hit_debug=0 first_tx_ps=253324000 first_type0_ps=253340000 final_tx_data=0x1bc
*** PRE_HSS_HWSTIM PASSED: signal=1 reproduces zero tx_valid; signal=0 restores tx_valid ***
Errors: 0, Warnings: 6
```

Interpretation: the hardware symptom reproduces in RTL when the setup writes
`SIGNAL=0x1`. In `frontend_trigger_engine.sv`, internal random-hit launch is
enabled only when `!cfg_hit_mode_sig`; writing `SIGNAL[0]=1` selects signal
mode and disables that internal launch path. The current bench setup does not
provide a matching external inject pulse, so no tickets reach the lane emitter,
`tx8b1k_valid` stays zero, and the VCD matches hardware.

Changing only `SIGNAL` to `0x0` with the same `MUTRIG_FORMAT=0x20` and
`cluster_fix=0x4000` restores byte-stream valid and type0 records in sim. The
next hardware pass should therefore rerun the pre-HSS capture with
`emu_signal=0` for internal random-hit generation, or deliberately supply the
external signal/inject source required by `emu_signal=1`. Do not move to
rbCAM/HSS/RDMA closure until that corrected-stimulus run shows positive legal
pre-HSS hit flow.

## Corrected-Stimulus Hardware Run

Capture directory:

```text
signaltap/captures/phase4_pre_hss_signal0_20260512_053323/
```

The explicit System Console setup with `--emu-signal 0` failed twice before
run start with a Java `ThreadPoolExecutor` rejection. A readback after the
failed setup showed lane 0 partially in the desired class (`SIGNAL=0`) but
with default-ish settings (`MUTRIG_FORMAT=0x22`, default rates/cluster fields),
so it was not a clean replay of the sim tuple `format=0x20/cluster_fix=0x4000`.

A reset attempt then wedged the SC leaf path: subsequent reads returned
`RSP3` and `0xEEEEEEEE`. The board was reprogrammed with the same STP SOF,
PCIe was recovered, and the run used the fresh image's default internal-random
`SIGNAL=0` state instead of relying on further SC writes. From that state:

- `rc_run_prepare_default_signal0.log`: reset-link status
  `0x31000000 -> 0x00010299`;
- `rc_sync_default_signal0.log`: `0x00010299 -> 0x11000003`;
- `txvalid_capture_default_signal0.log`: armed SignalTap and issued
  `start-run`, `0x11000003 -> 0x12000004`;
- SignalTap reached `DONE`, exported `txvalid_start_run_default_signal0.vcd`,
  and Quartus reported `0` errors, `0` warnings.

The STP trigger was copied to:

```text
phase4_pre_hss_gap_trigger_txvalid.stp
```

Only the trigger condition changed, from decoded-mux valid to
`emulator_mutrig_0.aso_tx8b1k_valid` rising edge. The trigger name in the STP
remains `decoded_mux_valid_rise`.

`txvalid_vcd_summary.log` reports the latest hardware boundary:

| Signal | First high | Rises | One samples | Final | Interpretation |
|---|---:|---:|---:|---:|---|
| `run_generating` | `500 ps` | `1` | `2049` | `1` | run state already active by first captured sample |
| `emulator_mutrig_0.aso_tx8b1k_valid` | `128500 ps` | `1` | `1408` | `0` | byte-stream source restored under `SIGNAL=0` default stimulus |
| `avalon_st_adapter_032.in_0_valid` | `128500 ps` | `1` | `1408` | `0` | source valid reaches adapter input |
| `avalon_st_adapter_032.out_0_valid` | `128500 ps` | `1` | `1408` | `0` | adapter forwards valid |
| `decoded_lane_mux_0.in1_valid` | `128500 ps` | `1` | `1408` | `0` | lane-0 mux input sees source valid |
| `decoded_lane_fifo_0.out_valid` | `500 ps` | `512` | `1024` | `0` | FIFO output toggles, but payload probes are not trusted |
| `mutrig_datapath_subsystem_0.headerinfo_valid` | never | `0` | `0` | `0` | parser/header path still dark |
| `mutrig_datapath_subsystem_0.hit_type0_out_valid` | never | `0` | `0` | `0` | no legal type0 output |
| `mux_mutrig2processor.out_valid` | never | `0` | `0` | `0` | no MTS input stream |
| `mts_preprocessor_0.aso_hit_type1_valid` | never | `0` | `0` | `0` | no pre-HSS hit stream |
| `histogram_ingress_bridge_0.asi_pre_valid` | never | `0` | `0` | `0` | pre histogram input dark |
| `histogram_ingress_bridge_0.aso_hist_valid` | never | `0` | `0` | `0` | histogram stream dark |
| `hist_post_cdc_0.out_valid` | never | `0` | `0` | `0` | post path dark |

The post-capture SC reads matched cleanly after reprogramming:

| Readback | Evidence |
|---|---|
| Histogram stats `0x0A908`, 11 words | `PORT_STATUS=0x000000FF`, `TOTAL_HITS=0`, drops/underflow/overflow all `0` |
| `mts_preprocessor_0` `0x09000`, 5 words | visible totals zero; payload words `[1]`, `[3]`, `[4]` are `0` |
| `mts_preprocessor_1` `0x0A000`, 5 words | visible totals zero; extra secondary traffic warning recorded |
| HSS0 `0x0B400`, 8 words | type/id `0x38/0x2`; declared/actual/missing counters all `0` |
| HSS1 `0x0B410`, 8 words | type/id `0x38/0x2`; declared/actual/missing counters all `0` |
| Runctl LAST_CMD `0x0C004` | `0x00000012` |
| Runctl RX_CMD_COUNT `0x0C00F` | `0x00000003` |

Teardown sent only `end-run` to avoid the reset wedge. The status advanced
`0x12000004 -> 0x13000000` and `o_state_out` echoed `0x13`.

## Current Conclusion

The corrected-stimulus hardware pass supersedes the earlier conclusion that
the immediate blocker is the byte-stream source. With the default internal
`SIGNAL=0` stimulus, byte-stream valid now reaches the adapter, mux input, and
decoded-lane FIFO boundary. The first still-dark legal-hit boundary is
`mutrig_datapath_subsystem_0.headerinfo_valid` /
`hit_type0_out_valid`; everything downstream through MTS, histogram, HSS, and
RDMA remains unproven.

The next iterative-debug pass should keep hardware as the source of truth and
probe the payload/parser side of this new gap: emitted `tx8b1k` words,
decoded-lane FIFO output payload/control, frame receiver parser state,
header/type0 valid generation, and reset/CSR mode inside
`mutrig_datapath_subsystem_0`. A robust SC/JTAG setup path is also required to
replay the exact `SIGNAL=0`, `MUTRIG_FORMAT=0x20`, `cluster_fix=0x4000` tuple;
the current positive-source capture used default internal stimulus after the
SC setup and reset paths became unreliable.
