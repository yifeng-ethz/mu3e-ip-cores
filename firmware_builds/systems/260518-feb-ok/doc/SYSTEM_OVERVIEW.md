# FEB SciFi v3 — system Qsys overview (2026-05-18, v4 cut)

Snapshot of the Qsys hierarchy and IP versions for `feb_system_v4`, the rewired
top of the 260518-feb-ok build. Companion to
[`V4_REWIRE_SPEC.md`](V4_REWIRE_SPEC.md) (per-slave SC-hub address map)
and [`BUG_HISTORY.md`](BUG_HISTORY.md).

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
| `lvds_rx_controller_pro_0` | `lvds_rx_controller_pro` | `25.1.0631` | **WRONG IP** — should be `mu3e_lvds_controller` (kind `mu3e_lvds_controller`, v`26.2.1.0506`, `mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv`) which has META header (UID=`0x4C564453`/"LVDS") + the `mu3e_lvds_controller_phy_adapter` PHY HIP folded in. Confirmed by drift audit row +0x000 (SVD UID `0x4C564453` vs live `0x00FA0009`) |
| `mutrig_datapath_subsystem_{0..7}` | `mutrig_datapath_system_v4` | `26.4.0.0518` | sub-subsystem, renamed v3→v4 + bumped |
| `mutrig_datapath_subsystem_{0..7}.mutrig_frame_deassembly_0` | `mutrig_frame_deassembly` | `26.2.0.0511` | OK |
| `mutrig_datapath_subsystem_{0..7}.backpressure_fifo` | `altera_avalon_sc_fifo` | `18.1` | vendor |
| `mts_preprocessor_0` | `mts_preprocessor` | `26.3.5.0518` | OK |
| `mts_preprocessor_1` | `mts_preprocessor` | `26.3.5.0518` | OK |
| `hist_type0_lane{0..7}_tap` | `hit_type0_tap2` | `26.0.0.0517` | OK |
| `hist_type1_up_tap` / `hist_type1_down_tap` | `avst_snoop_splitter` | `26.0.0.0502` | OK |
| `hist_post_splitter_0` / `hist_post_cdc_0` | vendor splitter / DC-FIFO | `18.1` | vendor |
| `emulator_mutrig_qsys_inst` | `emulator_mutrig` | `26.3.3.0517` | kind OK, IP **likely held in reset on board** — META header in `frontend_csr.sv` should return IP_UID=`0x454D5554`/"EMUT" at offset 0 but live reads `0x00000000` plus reset values for all 6 documented regs. Same class of bug as `mutrig_injector_0` above |
| `emulator_hit_type0_fanout` | `hit_type0_fanout8` | `26.0.1.0517` | OK |
| `emulator_inject_fanout` | `pulse_fanout8` | `26.0.0.0518` | bumped from 1.2; tiny 1→8 fanout buffer for the calibration injection pulse |
| `mutrig_injector_0` | `mutrig_injector_multiheader` | `26.1.2.0517` | kind OK, IP **held in reset on board** — write to RW reg HEADER_DELAY did NOT stick (sc_tool 2 write 0x0A803 0xCAFE / readback 0x00000000). RTL is correct (META header at offset 0 returns IP_UID=`0x4D494E4A`/"MINJ"). Reset wiring debug needed (see `doc/reports/feb_v4_csr_drift_audit.md` section 2) |
| `mutrig_reset_controller_0` | `mutrig_reset_controller` | `26.0.0.0518` | bumped from 1.1.0 |
| `mux_mutrig2processor` / `mux_mutrig2processor_0` | `hit_type0_readyless_mux4` | `26.1.0.0516` | OK |
| `arb_hit_type0_supercore_0` (wrapper) | `arb_hit_type0_supercore` | `1.0` (kept) | **kept at 1.0** to avoid collision with the IP-Builder `arb_hit_type0_supercore_hw.tcl` variant (also kind=`arb_hit_type0_supercore`) that carries `26.6.5.0518` — bumping the qsys subsystem to a matching version makes Qsys's kind resolver pick the wrong (IP-Builder) variant and break port resolution |
| `arb_hit_type0_supercore_0.lane_{0..7}` | `arb_hit_type0` | `26.6.5.0518` | OK |
| `histogram_statistics_0` | `histogram_statistics_v2` | `26.3.5.0522` | **kind OK** — the `_v2`-named hw.tcl `histogram_statistics/histogram_statistics_v2_hw.tcl` already implements the v3 ingress contract (`type0_lane0..7` + `type1_up`/`type1_down` + 48-bit ts sideband per `histogram_statistics/RTL_V3_NOTE.md`) and stamps IP_UID `0x48495354` ("HIST") at offset 0. The kind WITHOUT the `_v2` suffix is the legacy generic-`hist_fill_in` IP and is now hard-blocked. Live readback returns all zeros — same held-in-reset symptom as the injector/emulator; CSR clock is `lvds_rx_28nm_0.outclock`. Expected to recover once the LVDS swap below lands. **NOTE: live sopcinfo still shows the forward-dated `0522` BUILD; the submodule was bumped to drop this to `0518` and the next qsys-generate will pick up `26.3.5.0518`.** |
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

Kept at `1.0`:
- `arb_hit_type0_supercore.qsys` (subsystem wrapper) — collision with the
  `arb_hit_type0_supercore_hw.tcl` IP-Builder variant (also kind=`arb_hit_type0_supercore`,
  version `26.6.5.0518`); any version bump on the subsystem makes Qsys's kind resolver
  flip to the IP-Builder variant and the subsystem's per-lane ports disappear at
  qsys-generate. Documented in this row of Region B above.

Vendor IPs (`altera_*`, `altera_avalon_*`, `multiplexer`) stay on the Quartus 18.1 stamp.

## Wrong-IP findings (2026-05-18 drift audit)

See [`reports/feb_v4_csr_drift_audit.md`](reports/feb_v4_csr_drift_audit.md)
for the full SVD-vs-RTL audit. Three "wrong IP in v4 qsys" findings that
need a swap + re-elaborate + full FEB compile cycle:

| current instance | current kind | should be | reason |
|---|---|---|---|
| `lvds_rx_controller_pro_0` | `lvds_rx_controller_pro` (v`25.1.0631`) | `mu3e_lvds_controller` (v`26.2.1.0506`) | new IP has META header (UID=`0x4C564453`/"LVDS") plus the `mu3e_lvds_controller_phy_adapter` PHY HIP folded in; the old kind is now hard-blocked at elaboration |

Two "IP held in reset" findings (RTL is correct, qsys reset wiring needs debug):

| instance | kind | symptom | RTL evidence |
|---|---|---|---|
| `mutrig_injector_0` | `mutrig_injector_multiheader` (v`26.1.2.0517`) | RW writes don't stick (sc_tool 2 write 0x0A803 0xCAFE -> read returns 0) | `charge_injection/rtl/vhdl/mutrig_injector_multiheader.vhd:517` returns IP_UID at offset 0 when not in reset |
| `emulator_mutrig_qsys_inst` | `emulator_mutrig` (v`26.3.3.0517`) | UID offset 0 reads `0x00000000` instead of `0x454D5554`/"EMUT" | `emulator_mutrig/rtl/frontend/frontend_csr.sv:130` has `ADDR_UID_CONST` returning IP_UID |

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
