# FEB SciFi v3 — system Qsys overview (2026-05-19, v4 cut, RESETTING contract refresh)

Snapshot of the Qsys hierarchy and IP versions for `feb_system_v4`, the rewired
top of the 260518-feb-ok build. Companion to
[`V4_REWIRE_SPEC.md`](V4_REWIRE_SPEC.md) (per-slave SC-hub address map)
and [`BUG_HISTORY.md`](BUG_HISTORY.md). The 2026-05-19 refresh adds the
[`CONTRACT.md`](CONTRACT.md) "RESETTING-State Self-Exit Contract" section
and pushes three contract-aware IP bumps; the on-board verification is
captured in [`reports/feb_v4_resetting_contract_180200.md`](reports/feb_v4_resetting_contract_180200.md).

## Top + subsystems

| Instance | Kind | Version | Source | Role |
|---|---|---|---|---|
| `feb_system_v4` (top) | `feb_system_v4` | `26.4.0.0518` | `firmware_builds/systems/260518-feb-ok/generated/qsys/feb_system_v4.qsys` (local seed) | board top; instantiates the 3 subsystems + clocks |
| `control_path_subsystem` | `debug_sc_system_v4` | `26.4.0.0518` | `quartus_systems/debug_sc_system_v4.qsys` | sc_hub + slow-control fabric, hosts Region A slaves |
| `data_path_subsystem` | `scifi_datapath_system_v4` | `26.4.0.0518` | `firmware_builds/systems/260518-feb-ok/generated/qsys/scifi_datapath_system_v4.qsys` (local patched) + `quartus_systems/scifi_datapath_system_v4.qsys` (mirror) | MuTRiG receive + arbitration + hist, hosts Region B slaves |
| `upload_subsystem` | `upload_system_v4` | `26.4.0.0518` | `quartus_systems/upload_system_v4.qsys` | run-control mgmt host + upload mux, hosts Region C |
| `bringup_subsystem` | `feb_bringup_system` | `26.0.0.0518` | `quartus_systems/feb_bringup_system.qsys` | Nios II + JTAG UART for bring-up (bumped from 1.0) |

All v3 predecessors (`feb_system_v3*`, `debug_sc_system_v3*`, `scifi_datapath_system_v3*`, `upload_system_v3*`, `mutrig_datapath_system_v3` snapshot copies of the variants) are parked under `quartus_systems/deprecated/`.

## Region A — ctrl-path slaves (instances inside `control_path_subsystem`)

See [`V4_REWIRE_SPEC.md`](V4_REWIRE_SPEC.md) for the SC-hub byte map.

| Instance | Kind | Version | Status |
|---|---|---|---|
| `scratch_pad_ram` | `altera_avalon_onchip_memory2` | `18.1` | vendor |
| `onewire_master_controller_0` | `onewire_master_controller` | `26.2.1.0428` | OK |
| `onewire_master_0` (link layer, private bus only) | `onewire_master` | `26.2.1.0428` | OK |
| `max10_prog_avmm_0` | `max10_prog_avmm` | `26.0.0.0518` | bumped from 0.2.0 |
| `firefly_xcvr_ctrl_0` | `firefly_xcvr_ctrl` | `26.2.0423` | OK |
| `on_die_temp_sense_ctrl` | `altera_temp_sense_ctrl` | `1.1` | vendor |
| `mutrig_cfg_ctrl_0` | `mutrig_cfg_ctrl` | `24.1.0423` | OK (also owns dangling `avmm_cnt` master, to be wired into the new `ctrl2data_mm_bridge`) |
| `sc_hub` | `sc_hub_v2` | `26.6.10.0423` | OK |
| `pll_156t40` | `altera_pll` | `18.1` | vendor |
| `pll_reset_inactive` | `inactive_reset_source` | `26.0.0.0425` | OK |
| `mm_bridge` (sc_hub → data_path) | `altera_avalon_mm_bridge` | `18.1` | DROPPED span widen pending; ADDRESS_WIDTH=15 (128 KiB) MAX_BURST_SIZE=256 in v4 rewire |
| `upload_mm_bridge` (sc_hub → upload) | `altera_avalon_mm_bridge` | `18.1` | ADDRESS_WIDTH=14 (64 KiB) in v4 rewire |
| `jtag_master` | `altera_jtag_avalon_master` | `18.1` | vendor; local Region A reach |

**Dropped in v4 rewire** (commit `c788ee7f`):
- `legacy_firefly_bridge` — orphan, no slaves; removed from `debug_sc_system_v4.qsys`

## Region B — data-path slaves (instances inside `data_path_subsystem`)

| Instance | Kind | Version | Status |
|---|---|---|---|
| `lvds_rx_28nm_0` | `altera_lvds_rx_28nm` | `24.0.1110` | vendor (separate Qsys block, NOT yet folded into the controller IP) |
| `mu3e_lvds_controller_0` | `mu3e_lvds_controller` | `26.2.2.0519` | **swap landed** (commit `0f929e58`, contract-rename bump `caecaeb`). The 2026-05-19 on-board read returns UID=`0x4C564453`/"LVDS" but VERSION=`0x1A021506`=26.2.1.1286 — the feb_system_v4 wrapper still carries OLD instance generics (`PATCH=1, BUILD=1286, DATE=20260518`) while the subsystem qsys + standalone wrapper carry the new 26.2.2.1305 generics; see "qsys cache propagation" note below. Contract rename: `TRAIN_RESETTING_DPA` -> `TRAIN_ASSERTING_DPA_RESET`, `TRAIN_RESETTING_FIFO` -> `TRAIN_ASSERTING_FIFO_RESET` per the new [`CONTRACT.md`](CONTRACT.md) RESETTING contract. |
| `mutrig_datapath_subsystem_{0..7}` | `mutrig_datapath_system_v4` | `26.4.0.0518` | sub-subsystem, renamed v3→v4 + bumped |
| `mutrig_datapath_subsystem_{0..7}.mutrig_frame_deassembly_0` | `mutrig_frame_deassembly` | `26.2.0.0511` | OK |
| `mutrig_datapath_subsystem_{0..7}.backpressure_fifo` | `altera_avalon_sc_fifo` | `18.1` | vendor |
| `mts_preprocessor_0` | `mts_preprocessor` | `26.3.5.0518` | OK |
| `mts_preprocessor_1` | `mts_preprocessor` | `26.3.5.0518` | OK |
| `hist_type0_lane{0..7}_tap` | `hit_type0_tap2` | `26.0.0.0517` | OK |
| `hist_type1_up_tap` / `hist_type1_down_tap` | `avst_snoop_splitter` | `26.0.0.0502` | OK |
| `hist_post_splitter_0` / `hist_post_cdc_0` | vendor splitter / DC-FIFO | `18.1` | vendor |
| `emulator_mutrig_qsys_inst` | `emulator_mutrig` | `26.3.3.0517` | kind OK; live 2026-05-19 reads still return `0x00000000` for UID + VERSION. NOT the RESETTING-contract failure mode (CSR is unreachable, not in reset). Lives on `mm_pipeline_lvds_csr_emu_dbg` which sits past the working low-bridge address window. See "Region B CSR-deafness" below. |
| `emulator_hit_type0_fanout` | `hit_type0_fanout8` | `26.0.1.0517` | OK |
| `emulator_inject_fanout` | `pulse_fanout8` | `26.0.0.0518` | bumped from 1.2; tiny 1→8 fanout buffer for the calibration injection pulse |
| `mutrig_injector_0` | `mutrig_injector_multiheader` | `26.1.3.0519` | **contract fix landed** (commit `28b3fb9`): `header_injector` + `random_injector` FSMs now route non-reset idle to a new `WAITING` state instead of forcing `state <= RESETTING`; this preserves the [`CONTRACT.md`](CONTRACT.md) RESETTING reservation for hardware-reset hold and run-control `RESET` cmd. Closes BUG-002-R. Live 2026-05-19 read still returns `0x00000000` for UID + VERSION — bridge-deafness root cause, not RESETTING. |
| `mutrig_reset_controller_0` | `mutrig_reset_controller` | `26.0.0.0518` | bumped from 1.1.0 |
| `mux_mutrig2processor` / `mux_mutrig2processor_0` | `hit_type0_readyless_mux4` | `26.1.0.0516` | OK |
| `arb_hit_type0_supercore_0` (wrapper) | `arb_hit_type0_supercore` | `1.0` (kept) | **kept at 1.0** to avoid collision with the IP-Builder `arb_hit_type0_supercore_hw.tcl` variant (also kind=`arb_hit_type0_supercore`) that carries `26.6.5.0518` — bumping the qsys subsystem to a matching version makes Qsys's kind resolver pick the wrong (IP-Builder) variant and break port resolution |
| `arb_hit_type0_supercore_0.lane_{0..7}` | `arb_hit_type0` | `26.6.5.0518` | OK |
| `histogram_statistics_0` | `histogram_statistics_v2` | `26.3.7.0519` | **kind OK + contract fix** (commit `630ef5b`): removed the `gts_reset_reg` latch process and `gts_counter_rst` signal; the `gts_counter_clear` pulse is now combinational on `i_rst or runctl_reset_hold or runctl_sync_start or runctl_run_start`, preserving SYNC-entry semantics with no latch. Closes BUG-011-R (standalone syn +0.465 ns @ 1.1x F_target). The `_v2`-named hw.tcl implements the v3 ingress contract (`type0_lane0..7` + `type1_up`/`type1_down` + 48-bit ts sideband). Live 2026-05-19 read returns `0x00000000` for UID + VERSION — bridge-deafness on `mm_pipeline_lvds_csr_hist`, NOT RESETTING. |
| `hit_stack_subsystem_{0,1}` | `hit_stack_system_v4` | `26.4.0.0518` | sub-subsystem, bumped from 1.0 |
| `hit_stack_subsystem_{0,1}.feb_frame_assembly_0` | `feb_frame_assembly` | `26.0.0328` | OK |
| `hit_stack_subsystem_{0,1}.ring_buffer_cam_{0..3}` | `ring_buffer_cam` | `26.2.13.0516` | OK |
| `master_datapath` | `altera_jtag_avalon_master` | `18.1` | vendor; local Region B JTAG reach |

**Dropped in v4 rewire** (commit `c788ee7f`):
- `dbg_mm2runctrl_0` — replaced by `runctl_mgmt_host_0.runctl` AvST source; removed from `scifi_datapath_system_v4.qsys`

## Region C — upload-subsystem slaves (inside `upload_subsystem`)

| Instance | Kind | Version | Status |
|---|---|---|---|
| `runctl_mgmt_host_0` | `runctl_mgmt_host` | `26.3.2.0513` | OK; AvST `runctl` source already injects run-control commands |
| `upload_pkt_mux` | `multiplexer` | `18.1` | vendor |
| `upload_cdc_fifo` / `upload_sc_cdc_fifo` | `altera_avalon_dc_fifo` | `18.1` | vendor |
| `csr_bridge` | `altera_avalon_mm_bridge` | `18.1` | vendor |
| `upload_system_jtag_master` | `altera_jtag_avalon_master` | `18.1` | vendor; local Region C JTAG reach |

## Versioning convention

Every Qsys element in this build uses the `ip-packaging` skill format
`YY.MINOR.PATCH.MMDD`:

- **Subsystem qsys with a `_v<N>` suffix in the name** (`feb_system_v4`,
  `debug_sc_system_v4`, `scifi_datapath_system_v4`, `upload_system_v4`,
  `mutrig_datapath_system_v4`) — `MINOR` matches the v-suffix `N`. The
  v4 cut therefore uses `26.4.*.MMDD` (YY=26, MINOR=4, PATCH increments
  on a fix, BUILD=`MMDD`). First-cut value is `26.4.0.0518`.
- **Leaf IPs (no v-suffix in the kind)** — `26.MINOR.PATCH.MMDD` where
  MINOR/PATCH track the IP's own feature/fix history. First-cut value
  for a previously-unversioned IP is `26.0.0.MMDD`.

## Completed version bumps (2026-05-18)

- `max10_prog_avmm` 0.2.0 → 26.0.0.0518 (leaf IP)
- `mutrig_reset_controller` 1.1.0 → 26.0.0.0518 (leaf IP)
- `pulse_fanout8` 1.2 → 26.0.0.0518 (leaf IP)
- `feb_bringup_system` 1.0 → 26.0.0.0518 (subsystem without v-suffix)
- `hit_stack_system` 1.0 → 26.0.0.0518 (subsystem without v-suffix)
- `mutrig_datapath_system_v3` 1.0 → `mutrig_datapath_system_v4` 26.4.0.0518 (renamed + bumped)
- `arb_hit_type0_supercore_hw.tcl` VERSION_DATE 20260516 → 20260518 (matching lanes)
- v4 subsystems (`feb_system_v4`, `debug_sc_system_v4`, `scifi_datapath_system_v4`, `upload_system_v4`, `mutrig_datapath_system_v4`) → 26.4.0.0518

## Completed version bumps (2026-05-19, RESETTING contract refresh)

- `mu3e_lvds_controller` 26.2.1.0506 → **26.2.2.0519** (training-state rename, commit `caecaeb`)
- `mutrig_injector_multiheader` 26.1.2.0517 → **26.1.3.0519** (WAITING-state addition, commit `28b3fb9`)
- `histogram_statistics_v2` 26.3.5.0518 → **26.3.7.0519** (gts_reset_reg removal, commit `630ef5b`; intermediate 26.3.6 broken SYNC-entry semantics, caught and re-fixed)

Companion infrastructure changes in commit `008c9447`:
- New [`CONTRACT.md`](CONTRACT.md) "RESETTING-State Self-Exit Contract" section
  fixing the FSM convention that RESETTING is reserved for active hardware
  reset or run-control RESET command; non-reset idle uses a separate
  WAITING / IDLE state.
- New Make targets in `syn/board_projects/fe_scifi_feb_v3/Makefile`:
  - `make qsys-refresh` - load+save subsystem `.qsys` files so nested
    instance generic snapshots pick up fresh leaf-IP versions. Refreshes
    `scifi_datapath_system_v4` only; `feb_system_v4` is excluded as
    destructive (load+save on the top drops 18 slaves).
  - `make qsys-validate` - audit each `.qsys` file's `version="X.Y.Z.WWWW"`
    attribute against the latest catalog `_hw.tcl`. Useful gate but does
    NOT walk into nested-subsystem instance snapshots (see "qsys cache
    propagation finding" above).
- STP scratch generator + check infra under `script/signaltap/` (held-in-reset triplet capture).
- Auto-memory entry `feedback_resetting_state_contract.md` documenting the contract.

Kept at `1.0`:
- `arb_hit_type0_supercore.qsys` (subsystem wrapper) — collision with the
  `arb_hit_type0_supercore_hw.tcl` IP-Builder variant (also kind=`arb_hit_type0_supercore`,
  version `26.6.5.0518`); any version bump on the subsystem makes Qsys's kind resolver
  flip to the IP-Builder variant and the subsystem's per-lane ports disappear at
  qsys-generate. Documented in this row of Region B above.

Vendor IPs (`altera_*`, `altera_avalon_*`, `multiplexer`) stay on the Quartus 18.1 stamp.

## Wrong-IP findings (2026-05-18 drift audit, 2026-05-19 update)

See [`reports/feb_v4_csr_drift_audit.md`](reports/feb_v4_csr_drift_audit.md)
for the full SVD-vs-RTL audit. The "wrong-IP" entries closed by the
2026-05-19 contract refresh:

| current instance | kind | status |
|---|---|---|
| `mu3e_lvds_controller_0` | `mu3e_lvds_controller` v`26.2.2.0519` | **swap landed** in `0f929e58`; contract rename + bump in `caecaeb`. On-board UID reads "LVDS" - kind is correct in the SOF. |

Two "IP held in reset" findings re-diagnosed by the 2026-05-19 STP capture
and on-board re-probe (see [`reports/feb_v4_resetting_contract_180200.md`](reports/feb_v4_resetting_contract_180200.md)):

| instance | kind | original symptom | revised root cause |
|---|---|---|---|
| `mutrig_injector_0` | `mutrig_injector_multiheader` v`26.1.3.0519` | RW writes did not stick on 2026-05-18 (sc_tool 2 write 0x0A803 0xCAFE -> read returns 0) | RTL **was** contract-violating (forced `RESETTING` for non-reset idle); fixed in `28b3fb9` with new `WAITING` state. After 2026-05-19 recompile + reprogram the CSR still reads all-zero - root cause re-attributed to the bridge-deafness finding below, not the RESETTING contract. |
| `emulator_mutrig_qsys_inst` | `emulator_mutrig` v`26.3.3.0517` | UID offset 0 reads `0x00000000` instead of `0x454D5554`/"EMUT" | Bridge-deafness, same root cause as injector (lives on `mm_pipeline_lvds_csr_emu_dbg`). Awaiting bridge-width repair. |

## qsys cache propagation finding (2026-05-19, NEW)

`feb_system_v4.qsys` silently caches its subsystem-instance generic snapshot.
When the subsystem (`scifi_datapath_system_v4.qsys`) gets fresh leaf-IP
versions via the parameter pin, the wrapper that Quartus actually compiles
into the SOF
(`generated/synthesis/feb_system_v4/synthesis/submodules/feb_system_v4_data_path_subsystem.vhd`)
keeps stale generics:

| IP | scifi_datapath_system_v4 (subsystem standalone) | feb_system_v4 wrapper (compiled into SOF) | live readback |
|---|---|---|---|
| `mu3e_lvds_controller_0` | `PATCH=2, BUILD=1305, DATE=20260519` | `PATCH=1, BUILD=1286, DATE=20260518` | 26.2.1.1286 (matches old cache) |
| `histogram_statistics_0` | `PATCH=7, BUILD=519, DATE=20260519` | `PATCH=4, BUILD=517, DATE=20260517` | n/a (CSR-deaf) |
| `mutrig_injector_0` | `PATCH=3, BUILD=519, DATE=20260519` | `PATCH=1, BUILD=517, DATE=20260517` | n/a (CSR-deaf) |

The `make qsys-validate` target (added in `008c9447`) checks
`scifi_datapath_system_v4.qsys` + `feb_system_v4.qsys` and reports them in
sync; it does NOT walk into the nested-subsystem instance generic snapshot,
so the cache miss goes unflagged. The `make qsys-refresh` target only
refreshes the SUBSYSTEM (top excluded as destructive) so the top stays
stale.

Effect: cosmetic on RTL behavior (contract fix RTL is in the SOF, verified
in the submodule sources) but every on-board IP inventory tool that keys
on the VERSION word reads the wrong value.

Fix path queued for next session:
- (a) hand-patch `feb_system_v4.qsys` to add a parameterized
  `set_instance_parameter_value data_path_subsystem ...` Tcl that forces
  the new generics (no `save_system` on the top so no slave drop).
- (b) extend `validate_qsys_ip_versions.py` to walk into nested
  subsystems' Auto generic snapshots and at least warn.

## Region B CSR-deafness finding (2026-05-19, NEW)

Post-recompile reprobe shows the LVDS CSR (`mm_pipeline_lvds_csr_low`,
offset 0x0000 inside the cross-clock master) responds with valid UID +
VERSION, while every Region B slave behind a different
`mm_pipeline_lvds_csr_*` bridge returns all-zero payloads:

| slave | bridge | offset in cross-clock master | live read |
|---|---|---|---|
| `mu3e_lvds_controller_0.csr` | `mm_pipeline_lvds_csr_low` | 0x0000 | OK (UID + VERSION valid) |
| `emulator_mutrig_qsys_inst.csr` | `mm_pipeline_lvds_csr_emu_dbg` | 0x2000 | all zeros |
| `mts_preprocessor_0.csr` | `mm_pipeline_lvds_csr_mutrig4_mts0` | 0x4000 | all zeros |
| `histogram_statistics_0.csr` | `mm_pipeline_lvds_csr_hist` | 0xA000 (slave inside @ 0x400) | all zeros |
| `mutrig_injector_0.csr` | `mm_pipeline_lvds_csr_hitstack_ring` | 0xB000 (slave inside @ 0x200) | all zeros |

sc_hub_v2 internal diagnostic reports `ERR_FLAGS=0, ERR_COUNT=0` after the
deaf probes - bridges acknowledge the cycle but the slave datapath returns
zero. The bridge parameters that differ from the working low-bridge:
- `mm_pipeline_lvds_csr_low`: ADDRESS_WIDTH=13, SYSINFO_ADDR_WIDTH=13 (match)
- `mm_pipeline_lvds_csr_emu_dbg`: ADDRESS_WIDTH=12, SYSINFO_ADDR_WIDTH=12 (match)
- `mm_pipeline_lvds_csr_hist`: ADDRESS_WIDTH=12, SYSINFO_ADDR_WIDTH=11 (**MISMATCH**)
- `mm_pipeline_lvds_csr_hitstack_ring`: ADDRESS_WIDTH=12, SYSINFO_ADDR_WIDTH=10 (**MISMATCH**)

Suspect bridge address-aperture mis-decode. Fix path queued for next
session: re-elaborate the inner bridges with `USE_AUTO_ADDRESS_WIDTH=0`
and explicit matching widths, or move these slaves onto the
`mm_pipeline_lvds_csr_low` bridge (proven to work).

This is **NOT** the RESETTING contract bug. The contract-fix RTL was
verified to be in the SOF submodule sources before the on-board re-probe.

## Files moved to `quartus_systems/deprecated/` (2026-05-18 v3→v4 cut)

- `debug_sc_system_v3.qsys`, `debug_sc_system_v3_lvdsctrl.qsys`, `debug_sc_system_v3_lvdsctrl_cbb.qsys`
- `scifi_datapath_system_v3.qsys`, `scifi_datapath_system_v3_pipe.qsys`, `scifi_datapath_system_v3_lat4.qsys`
- `upload_system_v3.qsys`, `upload_system_v3_lvdsctrl.qsys`
- `feb_system_v3.qsys`, `feb_system_v3_pipe.qsys`, `feb_system_v3_pipe_lvdsctrl.qsys`, `feb_system_v3_lat4.qsys`

`mutrig_datapath_system_v3.qsys` stays in `quartus_systems/` because it is a
sub-subsystem inside `scifi_datapath_system_v4` that this rewire does not
touch — the kind reference remains `mutrig_datapath_system_v3`.

## Live readback evidence

- **Pre-rewire (v3 build)**: [`tb_int/reports/feb_inventory_20260518_150948.md`](../tb_int/reports/feb_inventory_20260518_150948.md) — 11 of 14 endpoints reachable via sc_hub, 3 OUT-OF-BRIDGE (hist_csr, hist_bin, mutrig_injector).
- **Post-rewire (v4 build, on-board 2026-05-18)**: 22 of 22 endpoints reachable (hist_csr/hist_bin/mutrig_injector now inside the widened ctrl2data bridge window). Per-IP readback files under [`reports/20260518/`](reports/20260518/SYSTEM_OVERVIEW.md). Cross-IP rollup + drift hot-spots: [`reports/feb_v4_csr_report_summary.md`](reports/feb_v4_csr_report_summary.md). Full SVD-vs-RTL drift audit (which IPs have REAL drift): [`reports/feb_v4_csr_drift_audit.md`](reports/feb_v4_csr_drift_audit.md).
- **Post-RESETTING-contract rebuild (2026-05-19 18:02)**: [`reports/feb_v4_resetting_contract_180200.md`](reports/feb_v4_resetting_contract_180200.md). LVDS responds with stale generics (qsys cache); hist + injector + emulator + mts0 are deaf on Region B (bridge address-aperture mismatch). RESETTING contract RTL verified in submodule sources; on-board exercise blocked by bridge deafness. Both findings queued as next-session priorities.
