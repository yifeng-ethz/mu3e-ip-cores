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
| `extract_svd_inventory.py` | local | Walk a Qsys system, resolve SVD files for each reachable IP, and emit a JSON inventory with SC/JTAG base addresses plus VERSION/GIT capability hints. |
| `pull_current_ip_inventory.py` | local | Walk the current datapath Qsys, resolve each JTAG-master and SC-hub reachable aperture, classify header/config/status/port-mapped register regions from SVD, and optionally live-read UID/VERSION/DATE/GIT over both transports. |
| `check_ip_metadata.py` | local | Bring-up metadata audit. Compares live VERSION and GIT readback over SC and JTAG against the SVD and Qsys metadata for reachable IPs. |
| `check_sc_bridges.py` | local | Phase-1 bridge audit for the SC-exposed datapath and upload apertures. Verifies histogram UIDs, upload/runctl UID+META, and bridge reachability into emulator/debug windows. |
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
./pull_current_ip_inventory.py --filter 'mutrig_lane_source_mux|histogram_statistics'
./check_ip_metadata.py --inventory-out ../generated/debug_sc_system_v3_inventory.json
./check_sc_bridges.py
./run_phase1_bringup.py
./check_run_control.py
```

## SWB firmware constraint

`rc_tool` addresses `RESET_LINK_CTL_REGISTER_W = 0x29` / `_STATUS = 0x35`
pinned to the `online_sc` A10 SWB build. The SWB **must** be programmed from
the `online_sc` repo (not `online_dpv2`). See root `CLAUDE.md` "Switching PC
Firmware Source of Truth".
