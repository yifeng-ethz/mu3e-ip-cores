# system_20260427_testplanphase5/script

Host-side tooling for FEB SciFi v3 board bring-up and sign-off. This directory
is the authoritative home for the board-test software; sources may have
originated in `online_dpv2`, but the copies here are the ones to edit, build,
and review against `firmware_builds/doc/TEST_PLAN.md`.

| File | Origin | Purpose |
|---|---|---|
| `sc_tool.cpp` | `online_dpv2` base, hardened locally | Issue SC hub transactions through the SWB secondary ring. |
| `rc_tool.cpp` | `online_dpv2` base, hardened locally | Send reset-link bytes from the SWB and read back the FEB run-state echo. |
| `build_local_tools.py` | local | Build `sc_tool` and `rc_tool` from the local sources into `../bin/`, while reusing the already-built MuDAQ dependency stack from `online_dpv2`. |
| `common.sh` | local | Shared shell guardrails: tool discovery, JDI resolution, report directories, zero-trust environment checks. |
| `headless_jtag_common.tcl` | local | Shared headless System Console helpers for deterministic master selection and claim/release handling. |
| `jtag_rw.tcl` | local | Generic headless 32-bit AVMM read/write helper for the JTAG master path. |
| `inject_runcmd.tcl` | legacy idea, rewritten locally | Headless fallback for directly writing `runctl_mgmt_host_0.CSR_LOCAL_CMD` via the upload-subsystem JTAG master. |
| `phase5_injector_jtag_preset.tcl` | local guard | Disabled for datapath CSR use in the current Qsys topology because `jtag_master.master` is not connected to `mm_bridge.s0`; use `sc_tool` word addresses instead. |
| `extract_svd_inventory.py` | local | Walk a Qsys system, resolve SVD files for each reachable IP, and emit a JSON inventory with SC/JTAG base addresses plus VERSION/GIT capability hints. |
| `extract_full_svd_map.py` | local | Resolve the generated Qsys address map to SVD register/field details and emit the full SC-visible Phase-5 map. |
| `check_ip_metadata.py` | local | Bring-up metadata audit. Compares live VERSION and GIT readback over SC and JTAG against the SVD and Qsys metadata for reachable IPs. |
| `check_sc_bridges.py` | local | Phase-1 bridge audit for the SC-exposed datapath and upload apertures. Verifies histogram UIDs, upload/runctl UID+META, and bridge reachability into emulator/debug/source-mux windows. |
| `set_mutrig_lane_sources.py` | local | Runtime select real MuTRiG, emulator, or mixed lane sources through `mutrig_lane_source_mux_[0..7].csr`; bit N of `--mask` selects emulator for lane N. |
| `configure_mutrig_from_xml.py` | local | Pack FE SciFi MuTRiG XML into the 84-word MuTRiG3 stream, stage it in scratchpad RAM, issue `mutrig_cfg_ctrl_0` commands, and verify frame-deassembly progress. Optional `--channel-enable-mask` and `--tdctest-channel-mask` apply in-memory per-channel overrides without editing source XML. |
| `phase5_real_mutrig_link_debug.py` | local | Serialized real-MuTRiG boundary debug. Snapshots LVDS controller state, source-mux live symbols, and frame-deassembly counters around optional LVDS reset and ASIC configuration; accepts the same channel override masks as the XML configurator. |
| `run_phase5_injector_datapath_sanity.py` | local | Live SC/RC injector gate for emulator, real, rate-sweep, and negative-control runs. Defaults to broadcast FEB target `--feb 7`, supports `--lvds-lane-mask`, and records diagnostic MTS/ring overrides (`--mts-expected-latency`, `--mts-delay-ts-field`, `--mts-drop-delay-error`, `--ring-filter-inerr`) in each report. |
| `run_phase5_histogram_matrix.py` | local | Quick Phase-5 histogram source/scope/scenario matrix runner. It is for CSR triage; final closure uses raw histogram-bin DISLIN plots. |
| `phase5_histogram_bin_dump.tcl` | local | Headless System Console histogram-bin dumper. It configures the 1 s rate/delay/header preset, clears `hist_bin`, waits one interval, and writes a 256-bin CSV for DISLIN rendering. In debug delay/header mode, `--lane-filter` selects the upper/lower MTS debug source through the 26.1.5 synthetic filter word; individual lane isolation still comes from source masks. |
| `build_phase5_histogram_sanity_csvs.sh` | local | Shell/awk assembler that turns raw single-run histogram dumps into the three wide CSVs required by the DISLIN sanity renderer. |
| `render_phase5_histogram_sanity_dislin.sh` / `.c` | local | DISLIN-only renderer for the three required sanity figures: 256-channel 10k/100k rate overlay, header 1/2/5 overlay, and eight-lane delay overlay. Input CSVs live under `../reports/phase5_histogram_sanity_data_<date>/`; no Python/matplotlib plotting is used. |
| `run_phase5_injector_signaltap_capture.py` | local | Concurrent SignalTap/stimulus wrapper retained for debug. Current safe method is SC pre-arm, SignalTap capture, then SC stop. |
| `run_phase1_bringup.py` | local | Phase-1 report runner. Calls the metadata/bridge gates, performs the read-only slave audit, and writes `../systems/system_20260427_testplanphase5/reports/phase1_bringup_<date>_pipe.md`. |
| `check_run_control.py` | local | Phase-3 reset-link audit. Drives `rc_tool` command pulses and verifies `runctl_mgmt_host_0` readback over the SC upload bridge with exact command-count and last-command checks. |
| `run_atpg_v2_reference.sh` | v2 flow, path-hardened locally | Reference Phase-2 scratchpad/CSR stress runner. |
| `run_rc_reg_v2_reference.sh` | v2 flow, path-hardened locally | Reference Phase-3 reset-domain runner. |

## Build

Build local binaries into `../bin/`:

```
./build_local_tools.py --verbose
```

This keeps the source of truth in this directory while reusing the already
configured MuDAQ dependency closure from `/home/yifeng/packages/online_dpv2/online/build`.
If that external build tree is missing or stale, rebuild it first.

Typical operator flow:

```
./build_local_tools.py
./extract_svd_inventory.py --output ../generated/debug_sc_system_v3_inventory.json
./check_ip_metadata.py --inventory-out ../generated/debug_sc_system_v3_inventory.json
./check_sc_bridges.py
./set_mutrig_lane_sources.py --mode real
./run_phase1_bringup.py
./check_run_control.py
```

## SWB firmware constraint

`rc_tool` addresses `RESET_LINK_CTL_REGISTER_W = 0x29` / `_STATUS = 0x35`
pinned to the `online_sc` A10 SWB build. The SWB **must** be programmed from
the `online_sc` repo (not `online_dpv2`). See root `CLAUDE.md` "Switching PC
Firmware Source of Truth".
