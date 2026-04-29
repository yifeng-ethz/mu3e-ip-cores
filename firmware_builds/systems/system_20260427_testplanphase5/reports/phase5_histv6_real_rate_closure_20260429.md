# Phase 5 Histogram v26.1.6 Real-Rate Closure Checkpoint

Timestamp: 2026-04-29 21:50 local host time.

This report records the first timing-clean no-STP FEB image where the histogram
rate preset uses the v26.1.6 `LAST_INTERVAL_TOTAL_HITS` counter and where
scoped real-MuTRiG lane rate checks pass against the 1 s histogram window.
It is a Phase-5 checkpoint, not final Phase-5 closure.

## Firmware Image

| Item | Evidence |
|---|---|
| Quartus compile log | `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_nostp_pipe_histv6_20260429_205028.console.log` |
| Program log | `syn/board_projects/fe_scifi_feb_v3/program_top_nostp_pipe_histv6_20260429.log` |
| SOF | `syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof` |
| RBF | `syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.rbf` |
| Quartus programmer checksum | `0x13A9CC2D` |
| SOF `cksum` | `3252249893 12694619` |
| SOF `sha256` | `6dcf331d6fd8cc541dbd91b5d8ddedaee95d4a15baaeb41e4fd69e5e031832be` |
| RBF `cksum` | `783578099 7004012` |
| RBF `sha256` | `ace986f1024995341dfae43cbd3fa999cdd6dfa520b695ef2e86d19054d58b7f` |

Compile outcome:

| Gate | Result |
|---|---|
| Full compile | `0 errors, 1734 warnings`, elapsed `00:48:53` |
| Fit | successful, `0 errors, 29 warnings` |
| Logic utilization | `62,405 / 91,680 ALMs (68%)` |
| Registers | `83,044` |
| Block memory | `4,012,018 / 13,987,840 bits (29%)`, `546 / 1,366 RAM blocks (40%)` |
| PLLs | `7 / 21 (33%)` |
| Slow 85 C setup WNS | `+0.454 ns`, TNS `0.000` |
| Slow 85 C hold WNS | `+0.241 ns`, TNS `0.000` |
| Recovery / removal / min-pulse | `+1.156 ns` / `+0.464 ns` / `+0.160 ns`, all TNS `0.000` |

Programming outcome:

| Gate | Result |
|---|---|
| Cable | `USB-BlasterII [7-2]` |
| Device | `5AGXBA7D4F31@1` |
| JTAG ID | `0x02A020DD` |
| Programmer | successful, `0 errors, 0 warnings` |

## Post-Flash Gates

The SC path needed a run-control prime after FPGA reconfiguration:

```text
rc_tool reset feb=7
rc_tool address feb=2
rc_tool stop-reset feb=7
```

After that sequence, `check_sc_bridges.py --link 2 --skip-jtag --json` passed
all seven bridge checks in
`reports/phase5_sc_bridge_histv6_20260429_214107.json`.

| Check | Result |
|---|---|
| `histogram_statistics_0.UID` | `0x48495354` |
| `histogram_ingress_bridge_0.UID/STATUS` | `0x48495342` / `0x00000403` |
| `emulator_mutrig_0` reachability | UID raw `0x00000001`, version `0x01000800` |
| lane source muxes | all eight UIDs `0x4D4C534D` |
| `dbg_mm2runctrl_0` | `0x4D325243` |
| upload run-control | UID `0x52434D48`, version `0x1A0261A9` |

Environmental monitor evidence is
`reports/phase5_environment_histv6_20260429_214050.json`.

| Monitor gate | Result |
|---|---|
| Summary | `62 PASS / 1 WARN / 0 FAIL` |
| OneWire temperatures | `30.25`, `31.438`, `21.5`, `21.812`, `40.25`, `40.312` C |
| OneWire valid lines | `6` |
| Persistent WARN | `firefly.ff1.vcc_raw = 58`, kept as the known monitor-scaling interpretation warning |
| Firefly 2 | expected dangling-module sentinel handling remains accepted |

## Authentic Generated-System Simulation

The matching generated-system datapath simulation passed after the v26.1.6
histogram Qsys regeneration:

| Artifact | Result |
|---|---|
| Log | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/run_dp_injector_authentic_histv6_20260429_204902.console.log` |
| Rate CSV | `tb/INT_fe_scifi_v3-2026-04-17/REPORT/dp_injector_authentic/pre_rbcam_rate_hist.csv` |
| Summary | `4 PASSED, 0 FAILED` |
| Pre-RBCAM rate | total `160`, eight lanes active, `20` accepted samples per lane at channel 16 |
| Pre-RBCAM latency | total `160`, underflow events `0` |

This simulation remains a smoke/regression match for the generated Qsys image.
It does not replace the final raw-bin DISLIN/System Console plot closure.

## Real-MuTRiG Configuration State

The setup run
`reports/phase5_real_mutrig_link_histv6_cfg0_7_ch16_20260429_214128.md`
configured ASICs 0 through 7 with the channel-16 TDC-test override. Each
`CMD_MUTRIG_ASIC_CFG` row completed with final status `0x00000000`.

The link diagnostic classified the idle window as `aligned_idle_no_frames`.
That is acceptable as a setup observation before traffic is enabled, but it is
not full link-frame closure. Full transport validation still requires frame
deltas on all lanes or explicit lane waiver.

## Rate Evidence

All PASS rows below use histogram rate mode with a 1 s sampling window
(`INTERVAL_CFG = 125000000`) and the v26.1.6 `LAST_INTERVAL_TOTAL_HITS` source.
The pass tolerance is +/-1% of the expected aggregate count.

| Source / scope | Evidence | Mux emu select | LVDS mask | Hits | Expected | Error | Drops | MTS | MTS discard | Ring inerr | Status |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| emulator lane0 100 kHz | `phase5_hist_matrix_emulator_lane0_rate100k_histv6_20260429_214318.md/json` | `0xFF` | `0x1FF` | `99,842` | `100,000` | `-158` (`-0.158%`) | `0` | `314,320` | `0` | `0` | `PASS` |
| real lane0 100 kHz, pre-fix diagnostic | `phase5_hist_matrix_real_lane0_rate100k_histv6_20260429_214226.md/json` | `0x00` | `0x1` | `629,938` | `100,000` | `+529,938` (`+529.938%`) | `0` | `2,226,085` | `0` | `928,293` | `FAIL` |
| real lane0 100 kHz, mixed isolation cross-check | `phase5_hist_matrix_real_lane0_rate100k_histv6_isolated_20260429_214547.md/json` | `0xFE` | `0x1` | `99,841` | `100,000` | `-159` (`-0.159%`) | `0` | `317,783` | `0` | `0` | `PASS` |
| real lane0 100 kHz, runner source-scope fix | `phase5_hist_matrix_real_lane0_rate100k_histv6_real_scopefix_20260429_214703.md/json` | `0xFE` | `0x1` | `99,839` | `100,000` | `-161` (`-0.161%`) | `0` | `315,832` | `0` | `0` | `PASS` |
| real lane0 10 kHz, runner source-scope fix | `phase5_hist_matrix_real_lane0_rate10k_histv6_real_scopefix_20260429_214739.md/json` | `0xFE` | `0x1` | `9,998` | `10,000` | `-2` (`-0.020%`) | `0` | `32,229` | `0` | `0` | `PASS` |
| real lane3 100 kHz, runner source-scope fix | `phase5_hist_matrix_real_lane3_rate100k_histv6_real_scopefix_20260429_214807.md/json` | `0xF7` | `0x8` | `99,841` | `100,000` | `-159` (`-0.159%`) | `0` | `314,732` | `0` | `0` | `PASS` |
| real lane3 10 kHz, runner source-scope fix | `phase5_hist_matrix_real_lane3_rate10k_histv6_real_scopefix_20260429_214838.md/json` | `0xF7` | `0x8` | `9,999` | `10,000` | `-1` (`-0.010%`) | `0` | `31,794` | `0` | `0` | `PASS` |

The failed pre-fix row is kept intentionally. It showed that `--source real
--scope lane0` selected real source on all eight live muxes, so non-requested
live lanes continued into MTS and the histogram. The runner now parks
non-requested lanes on disabled emulator sources by returning
`(~lvds_lane_mask) & 0xFF` for scoped real-source runs.

## Real Pulse Source Boundary

The current Qsys `mutrig_injector_0.inject` conduit fans out only to
`emulator_mutrig_0..7.inject` through `emulator_inject_fanout`. The real
MuTRiG 100 kHz rate stimulus used in this checkpoint is the legacy FEB
`MUTRIG_CNT_CTRL_REGISTER_W[0]` path, which drives `pll_test_mode(0)` and
`o_pll_test` in `scifi_path.vhd`. This distinction matters for closure:
emulator rate rows exercise `mutrig_injector_0`, while real rate rows exercise
the MuTRiG TDC-test pulse path plus the real LVDS/MTS/histogram datapath.

## Independent Review Notes

Two review agents inspected the evidence and reached the same conclusion:

- The emulator v26.1.6 row proves the `LAST_INTERVAL_TOTAL_HITS` path is live.
- The old real lane0 row is a valid failed diagnostic and must not be counted as a pass.
- The real lane0 and lane3 scope-fix rows are valid scoped PASS evidence at both 100 kHz and 10 kHz.
- The evidence is not all-lane real closure and does not close delay/header-mode plots.

Residual risks:

- Full eight-lane real MuTRiG rate closure is still open.
- Full link-frame validation is still open because the setup diagnostic reported `aligned_idle_no_frames`.
- Delay and header-mode final closure still require raw-bin DISLIN plots or System Console histogram screenshots plus matching authentic `tb_int/` runs.
- `firefly.ff1.vcc_raw` remains a WARN-level environmental monitor interpretation issue.
