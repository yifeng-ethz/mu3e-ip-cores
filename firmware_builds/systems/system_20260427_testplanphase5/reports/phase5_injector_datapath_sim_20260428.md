# Phase 5 Injector Datapath Integration-Sim Report

- Date: `2026-04-28`
- Updated: `2026-04-29`
- Harness: `firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_injector_authentic.sh`
- Mode: periodic `mutrig_injector_0.mode = 2`
- Pulse interval: `12500`
- Pulse high cycles: `5`
- Run cycles: `250000`
- Source: authentic generated `feb_system_v3_pipe` path, eight emulator lanes selected through `mutrig_lane_source_mux_[0..7]`, no forced decoded-din bypass, generated run-control fanout, no background hits, one injected hit centered on channel 16 per active lane
- Result: `PASS`

## Evidence

| Metric | Value |
|---|---:|
| `source_mux_control_readback[0..7]` | `0x00000001` |
| `mutrig_injector.mode/period/high` | `2 / 12500 / 5` |
| `injector_top_pulse`, `injector_qsys_pulse` | `110`, `110` |
| `injector_fanout_pulse[0..7]` | `110` each |
| `emulator_inject_pin_count[0..7]` | `110` each |
| `emulator_hit_wr_count[0..7]` | `20` each |
| `ext_emu_word_count` | 2301696 |
| `dp_hit0_word_count` | 400 |
| `dp_hit0_payload_fire_count` | 160 |
| `mts_type1_word_count` | 160 |
| `hit_stack_ingress_word_count` | 160 |
| `hit_stack_ingress_payload_word_count` | 160 |
| `emulator_dispatch_latency_hist TOTAL_HITS` | 160 |
| `histogram TOTAL_HITS` | 160 |
| `histogram DROPPED_HITS` | 0 |
| `histogram UNDERFLOW_COUNT` | 0 |
| `histogram OVERFLOW_COUNT` | 0 |
| `payload_clean` | 160 |
| `payload_error` | 0 |

Per lane, the pre-RBCAM measurement reported `mts_asic = 20`, `mts_ch16 = 20`, `hist_flush = 20`, and `hist_flush_ch16 = 20` for lanes 0 through 7. The rate histogram peak is bin 16 on ASIC 0; all eight ASIC lanes are active with `min_nonzero = 20` and `max_nonzero = 20`. The latency histogram also reported `TOTAL_HITS = 160`, `DROPPED_HITS = 0`, `UNDERFLOW_COUNT = 0`, and `OVERFLOW_COUNT = 0`.

The authentic rerun fixed two harness-side issues:

1. The generated lane-source mux CSR must be programmed to select emulator sources before the `TB_DP_NO_FORCE_DECODED_DIN` path is meaningful.
2. `hit_type0_endofpacket` is a payload sideband on valid frame-tail hits, not a marker to discard. The TB monitor now counts accepted `valid && ready` type0 transfers even when `endofpacket` is asserted.

## Pass Lines

```text
[PASS] Pre-RBCAM measurement produced type0 dispatch words
[PASS] Pre-RBCAM measurement produced accepted type1 words
[PASS] Pre-RBCAM rate histogram CSR reported no configuration error
[PASS] Pre-RBCAM latency histogram CSR reported no configuration error
Results: 4 PASSED, 0 FAILED
```

## 2026-04-29 Regenerated-Qsys Rerun

After the histogram timing fixes were regenerated into `scifi_datapath_system_v3_pipe` and `feb_system_v3_pipe`, the same authentic integration sim was rerun with `TB_DP_AUTH_RUN_CYCLES=250000`. The rerun preserved the generated Qsys path and boundary-agent model: no decoded-din force path, generated run-control fanout, emulator lane-source selection through the generated CSRs.

Result: `PASS`, with the same closure numbers: `top_pulse=110`, `qsys_pulse=110`, 20 injected hits per lane, 160 accepted type0 transfers, 160 MTS type1 outputs, 160 pre-RBCAM rate-hist hits, 160 latency-hist hits, and zero histogram drops/underflows/overflows. The copied runner log timestamp is `2026-04-29 01:19:53 +0200`.

## 2026-04-29 No-Aux Fanout Rerun

After the deprecated charge-injection / `inject_aux` path was removed from
`pulse_fanout8` packaging and from the Phase-5 datapath Qsys exports, the same
authentic integration sim was rerun with `TB_DP_AUTH_RUN_CYCLES=250000`.

Result: `PASS`. The generated no-aux image reports `top_pulse=110`,
`qsys_pulse=110`, `fanout=110`, `emu_pin=110`, `emu_edge=22`, and
`hit_wr=20` on every emulator lane. The downstream closure numbers remain
unchanged: 160 accepted type0 transfers, 160 MTS type1 outputs, 160 hit-stack
ingress payload words, 160 pre-RBCAM rate-hist hits, 160 latency-hist hits,
and zero drops/underflows/overflows. The copied runner log timestamp is
`2026-04-29 04:13:12 +0200`.

## Artifacts

| Artifact | Path |
|---|---|
| Authentic runner log | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_short_250k_20260428.log` |
| Questa log copied by runner | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic.log` |
| Transcript | `tb/INT_fe_scifi_v3-2026-04-17/work/dp/transcript` |
| Pre-RBCAM rate CSV | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/pre_rbcam_rate_hist.csv` |
| Emulator-dispatch latency CSV | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/emulator_dispatch_latency_hist.csv` |

## Interpretation

The authentic generated-system simulation propagates `mutrig_injector_0.mode = 2` pulses through the generated injector/fanout/emulator/source-mux/frame-deassembly/MTS/histogram path. The matching live-board checks still fail before accepted decoded hits reach MTS/histogram. After the histogram timing fixes were regenerated into Qsys, the no-STP baseline and rebuilt injector micro SignalTap revision both pass STA. The rebuilt STP SOF was programmed successfully, but the first capture attempt is blocked by the host SC path: `sc_tool` returned all-ones status and the PCIe rescan rebound the endpoint to `/dev/uio0` instead of the required `/dev/mudaq0`.

Residual debug note: the timestamp-trace diagnostic still reports an internal `mts_out_delta` off-by-one/two comparison against `mts_processor.int_aso_debug_ts_data`. It is not a pass/fail criterion for this gate; rate, accepted-hit, and histogram accounting are closed by the counters above.
