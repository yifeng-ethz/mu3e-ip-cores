# Streaming Debug Plane - FEB v3 Type-0 Contract

Status: Qsys/cosim Type-0 arbitration implemented on the 2026-05-15 snapshot worktree; corrected FEB host-run waveform generated with split emulator commit/egress/rbCAM checkpoints; STP compile emits a SOF but STA setup timing is not closed; on-board capture still pending
Owner: yifeng wang
Target repo: `mu3e-ip-cores`
Scope: `feb_system_v3`, `emulator_mutrig`, `arb_hit_type0`, `mutrig_timestamp_processor`, `histogram_statistics_v2`

---

## 1. Motivation

FEB v3 needs one debug/control contract for real MuTRiG hits and emulator
hits before they enter MTS and the histogram path. The previous decoded-lane
source-mux/byte-stream approach selected too early in the pipeline and could
mask the real issue: the emulator must feed the same Type-0 hit atom boundary
as the real frame-deassembly output.

The active contract is therefore:

- `emulator_mutrig` is Type-0 only in Qsys. `BYTE_STREAM_ENABLE` is permanently
  disabled by package validation and by the FEB v3 Tcl generators.
- Real MuTRiG traffic stays on the LVDS decoded-lane path until
  `mutrig_frame_deassembly_<n>.hit_type0_out`.
- `arb_hit_type0_<n>` arbitrates between real post-deassembly Type-0 atoms and
  emulator Type-0 atoms per lane.
- `hit_type0_readyless_mux4` combines the selected lane outputs into the two
  MTS banks.
- DEBUG_LEVEL=2 sidecar metadata is enabled only in simulation so the old
  dual-UVM scoreboard can track per-hit lineage through the mux and MTS.
- Generated synthesis Qsys is forced to DEBUG_LEVEL=0 and checked top-down;
  STP probes the functional Type-0/MTS/histogram datapath and counters.
- `histogram_statistics_v2` owns histogram source selection internally through
  `CONTROL.in_port[3:2]`; the external histogram ingress bridge is retired.

---

## 2. Active Topology

### 2.1 Type-0 Arbitration Point

```text
LVDS decoded lane N
  -> mutrig_datapath_subsystem_N
  -> mutrig_frame_deassembly_N.hit_type0_out
  -> arb_hit_type0_N.real_in

emulator_mutrig_N.hit_type0
  -> arb_hit_type0_N.emu_in

arb_hit_type0_N.selected_out
  -> hit_type0_readyless_mux4 bank input
  -> mts_preprocessor_<bank>.hit_type0_in

arb_hit_type0_N.selected_hit_debug      (simulation DEBUG_LEVEL=2 only)
  -> hit_type0_readyless_mux4 metadata input
  -> mts_preprocessor_<bank>.hit_type0_sidecar
```

Lanes 0-3 feed `mts_preprocessor_0`; lanes 4-7 feed
`mts_preprocessor_1`. The old `mutrig_lane_source_mux_<n>` instances are not
part of the active topology.

The generated FEB synthesis graph omits the debug sidecar connections above
and must pass `check_feb_synthesis_debug_levels.py` with `allowed_debug=[0]`.

### 2.2 Emulator Contract

`emulator_mutrig` still carries legacy `tx8b1k` HDL ports, but the Platform
Designer package now rejects active byte-stream use:

- `_hw.tcl` validation reports an error if `BYTE_STREAM_ENABLE=true`;
- elaboration forces `BYTE_STREAM_ENABLE=false`;
- generated FEB v3 Qsys wrappers leave `tx8b1k` unconnected;
- the cosim scoreboard checks `emu_tx_count=0` while Type-0 hits continue to
  fill the histogram path.

### 2.3 Run-Control And Reset Contract

`arb_hit_type0` mode selection is runtime-programmable:

- default reset mode in FEB v3 is `EMU`;
- `RUN_PREP` must not reset the selected mode;
- mode can switch during `RUNNING`;
- only RESET/hard reset returns mode and sticky configuration to defaults.

The FEB v3 Tcl adds `run_control_type0_arb_splitter` so the arbs receive the
same run-control stream without stealing the existing MTS, frame-deassembly,
histogram, or hit-stack fanout paths.

### 2.4 MTS And Histogram Debug Plane

```text
mts_processor
  |-- aso_hit_type1            : type1[38:0]
  |-- aso_hit_type1_extended_0 : { true_ts[47:0], type1[38:0] }
  `-- aso_hit_type1_extended_1 : { true_ts[47:0], type1[38:0] }

aso_hit_type1
  -> splitter / hit_stack upper and lower banks
  -> rbCAM
  -> feb_frame_assembly

aso_hit_type1_extended_0/1
  -> histogram_statistics_v2.asi_hit_type1_extended_0/1
```

The main MTS Type-1 output stays at the original 39-bit payload width. The
87-bit extended streams are readyless observability/fill sources for the
histogram IP.

---

## 3. Retired IP And Removed Paths

`histogram_ingress_bridge` is no longer part of FEB v3 and should not be used
as a selectable source. The histogram IP now owns source selection:

| `CONTROL.in_port[3:2]` | source |
|---:|---|
| `0` | normal `hist_fill_in` / `fill_in_1..7` path |
| `1` | `asi_hit_type1_extended_0` |
| `2` | `asi_hit_type1_extended_1` |
| `3` | rejected, `csr_error_info = 0x2` |

The FEB v3 Tcl also removes stale `mutrig_lane_source_mux_*`, `tx8b1k`, and
bridge/snoop selector connections from older `.qsys` files before rebuilding
the Type-0 graph.

---

## 4. SC Address Contract

Data-path offsets below are inside `data_path_subsystem.avmm_port`. For SC
tool word addresses, add the SC bridge byte base `0x20000` and divide by 4.

| block | datapath byte offset | top/SC byte | `sc_tool` word |
|---|---:|---:|---:|
| `emulator_mutrig_<k>.csr` | `0x2000 + k*0x100` | `0x22000 + k*0x100` | `0x08800 + k*0x40` |
| `dbg_mm2runctrl_0.csr` | `0x2800` | `0x22800` | `0x08A00` |
| `mutrig_datapath_subsystem_<k>.csr` | `0x2A80 + k*0x10` | `0x22A80 + k*0x10` | `0x08AA0 + k*0x4` |
| `arb_hit_type0_<k>.csr` | `0x3000 + k*0x80` | `0x23000 + k*0x80` | `0x08C00 + k*0x20` |
| `mts_preprocessor_0.csr` | `0x4000` | `0x24000` | `0x09000` |
| `mts_preprocessor_1.csr` | `0x8000` | `0x28000` | `0x0A000` |
| `histogram_statistics_0.hist_bin` | `0xA000` | `0x2A000` | `0x0A800` |
| `histogram_statistics_0.csr` | `0xA400` | `0x2A400` | `0x0A900` |

The removed source-mux CSR range is not a valid FEB v3 control surface.

---

## 5. Implemented Files

| area | implemented change |
|---|---|
| `emulator_mutrig` | package validation permanently disables `BYTE_STREAM_ENABLE`; Qsys exposes Type-0 output only |
| `scifi_datapath_system_v3` Tcl | inserts 8 `arb_hit_type0` instances after frame deassembly; removes stale source mux and byte-stream paths |
| `hit_type0_readyless_mux4` | carries selected-hit DEBUG_LEVEL=2 metadata sidecars in simulation; synthesis Qsys is forced to DEBUG_LEVEL=0 |
| `mts_processor` | accepts Type-0 sidecar metadata and limits DEBUG report spam to explicit debug builds |
| `histogram_statistics_v2` | owns source selection through `CONTROL.in_port`; no external histogram bridge |
| `live_hist_sideband_capture.py` | programs `arb_hit_type0` mode/watchdog counters and histogram source selection directly |
| `stream_debug_hist_path.stp` | probes emulator output, real post-deassembly Type-0, arb selection, mux metadata, MTS sidecar, and histogram fill/counters |

---

## 6. Verification Evidence

All evidence below is from the 2026-05-15 Type-0 arbitration worktree.
The earlier `sim_feb_checkpoint_wave_realistic_20260515` waveform is retired:
it drove a shortcut one-hot run-state model instead of the real
`runctl_mgmt_host` synclink input. Current FEB checkpoint evidence is the
`sim_feb_host_runctl_split_egress_20260516` run below.

| area | artifact | result |
|---|---|---|
| Qsys apply | `syn/qsys_type0_sidecar_apply_20260515.log` | PASS, no errors; all emulator instances force `BYTE_STREAM_ENABLE=false` |
| Qsys generate | `syn/feb_system_v3_qsys_generate_20260515_type0_sidecar_isolated.status` | PASS, `exit_code=0`, `error_count=0` |
| synthesis debug-level checker | `script/check_feb_synthesis_debug_levels.py` | PASS, checked 5 generated Qsys/VHDL artifacts with `allowed_debug=[0]` |
| directed Type-0 switch cosim | `tb_int/sim_type0_arb_switch2_20260515/TYPE0_ARB_HIST/transcript` | PASS, runtime EMU->REAL->EMU switching, `emu_tx_count=0`, `hist_total_hits=5392`, `hist_dropped_hits=0` |
| 32x8 rate-mode model | `tb_int/sim_type0_arb_32x8_rate_20260515/TYPE0_ARB_HIST_RATE/transcript` | PASS, `lane_scale=8`, `q16_rate=52`, `hist_total_hits=3168`, zero arb/hist drops |
| 32x8 latency-mode model | `tb_int/sim_type0_arb_32x8_latency_20260515/TYPE0_ARB_HIST_LATENCY/transcript` | PASS, `lane_scale=8`, `q16_rate=52`, `hist_total_hits=3168`, zero arb/hist drops |
| waveform cosim | `tb_int/sim_type0_arb_wave_20260515/TYPE0_ARB_HIST_WAVE/type0_arb_mts_hist.{vcd,fst}` and `tb_int/waves/gtkw/type0_arb_mts_hist.gtkw` | PASS transcript; waveform captures emulator Type-0, real Type-0, arb metadata, MTS sidecar, and histogram counters |
| realistic FEB checkpoint waveform | `tb_int/sim_feb_host_runctl_split_egress_20260516/RC_EMUL_REALISTIC/feb_host_runctl_realistic.{vcd,fst}` and `tb_int/waves/gtkw/feb_host_runctl_emulator_rbcam_realistic.gtkw` | PASS, real `runctl_mgmt_host` input protocol through generated Qsys run-control splitters; explicit reset/configure/long `RUN_PREP`/`RUN_SYNC`/`RUNNING`/`END_RUN`/collection phases; one channel at 100 kHz; split checkpoints for emulator commit, emulator egress, rbCAM ingress, rbCAM egress, and FEB egress |
| rbCAM lifetime report | `tb_int/sim_feb_host_runctl_split_egress_20260516/RC_EMUL_REALISTIC/rbcam_lifetime_report.{md,csv}` | PASS, 16/16 hits at rbCAM ingress = 835 cycles within `[0,2000]`; 16/16 hits at rbCAM egress = 2070 cycles within `[2000,2300]`; emulator commit->egress = 600 cycles, egress->ingress = 235 cycles |
| old dual UVM BASIC | `make regress_basic SIM_ROOT=sim_feb_host_runctl_split_egress_regress_basic_20260516 SEED=1` | PASS B065-B069, UVM_ERROR/FATAL 0 |
| old dual UVM RC/emulator | `make run_RC_EMUL run_RC_EMUL_FIXED SIM_ROOT=sim_uvm_type0_rcemul_20260515` | PASS; fixed case reads `TOTAL_HITS=0x10` |
| SignalTap import | `syn/quartus_stp_stream_debug_hist_20260515_type0_remap.log` | PASS, `quartus_stp` accepted the current STP with 0 errors and 0 warnings |
| SignalTap pre-synthesis nodes | `signaltap/stream_debug_hist_path_nodes_top_stp_stream_debug_hist.md` | PASS, 282 probes found, 0 missing |
| STP firmware compile | `syn/board_projects/fe_scifi_feb_v3/output_files_stp_stream_debug_hist/top_stp_stream_debug_hist.sof` | SOF generated; fitter/assembler successful; not timing-closed because STA reports setup WNS = -2.391 ns on the LVDS `pll_sclk` domain and -0.462 ns on `lvds_firefly_clk` |

Per-hit scoreboard evidence:

| run | closed hits | key evidence |
|---|---:|---|
| `B065` | 16 | `debug_obs SRC/PRE/POST/FEB=16/16/16/16`, duplicate IDs 0 |
| `B066` | 16 | `debug_obs SRC/PRE/POST/FEB=16/16/16/16`, duplicate IDs 0 |
| `B067` | 100 | `debug_obs SRC/PRE/POST/FEB=100/100/100/100`, duplicate IDs 0 |
| `B068` | 1024 | `debug_obs SRC/PRE/POST/FEB=1024/1024/1024/1024`, duplicate IDs 0 |
| `B069` | 1 | `debug_obs SRC/PRE/POST/FEB=1/1/1/1`, duplicate IDs 0 |
| `RC_EMUL` | 16 | real host command path; no shortcut one-hot drive; scoreboard closes 16 hits |
| `RC_EMUL_FIXED` | 16 | real host command path reads `TOTAL_HITS=0x00000010`, `LAST_CMD=0x12`, `RUN_NUMBER=0x20260515`, `RX_CMD_COUNT=3`; scoreboard closes 16 hits |
| `RC_EMUL_REALISTIC` | 16 | one channel, 100 kHz periodic; 5000-cycle/40 us `RUN_PREP` flush; collection reads `TOTAL_HITS=0x00000010`, `LAST_CMD=0x13`, `RUN_NUMBER=0x20260515`, `RX_CMD_COUNT=4`; `debug_obs SRC/PRE/POST/FEB=16/16/16/16`; rbCAM ingress/egress lifetimes are 835/2070 cycles for every hit |
| `TYPE0_ARB_HIST` | 5392 | metadata count equals selected count; `metadata_alignment_errors=0`; MTS sidecar and histogram totals match selected hits |

The rate/latency cosims use a single-lane RTL slice with `LANE_SCALE=8` to
check the 32x8 100 kHz model. They are not a full eight-instantiated-lane
firmware simulation.

---

## 7. Non-Claims And Remaining Work

- Post-map STP connectivity is not closed yet. Pre-synthesis node finder
  resolves 282/282 probes, but the current `top_stp_stream_debug_hist` image
  still needs post-fit probe review before board use.
- The fresh full FEB compile produced `top_stp_stream_debug_hist.sof`, but STA
  is red: setup WNS is -2.391 ns in the LVDS `pll_sclk` domain and -0.462 ns
  on `lvds_firefly_clk`. Treat the SOF as debug-only until timing is closed or
  explicitly waived.
- On-board SC/histogram capture is not claimed yet.
- UCDB/code coverage closure is not claimed by these tb_int runs.
- The old bridge-free STP bitstream evidence remains historical and must not
  be used as signoff for the current Type-0 arbitration/STP graph.

---

## 8. Migration Risks

| risk | mitigation |
|---|---|
| byte-stream mode reappears through an old script | emulator `_hw.tcl` validation rejects `BYTE_STREAM_ENABLE=true`; FEB Tcl writes `false`; generated Qsys is grepped for stale `tx8b1k` connections |
| source selection happens before frame deassembly | Qsys connects emulator and real traffic only at `arb_hit_type0.real_in/emu_in` after `mutrig_frame_deassembly.hit_type0_out` |
| `RUN_PREP` resets runtime source mode | cosim checks RUN_PREP preservation and RESET/hard reset default restoration |
| per-hit lineage is lost through muxing | arb `selected_hit_debug` is carried through mux metadata and MTS sidecar; cosim requires metadata count and source counts to match |
| host scripts read removed source-mux CSRs | `live_hist_sideband_capture.py` now programs `arb_hit_type0` CSRs at `0x08C00 + k*0x20` |
| histogram bridge references survive in docs/builds | active docs mark `histogram_ingress_bridge` retired; Qsys updater removes stale instances and source-selector paths |
