# FEB SciFi v3 — system Qsys overview (2026-05-18, v4 cut)

Snapshot of the Qsys hierarchy and IP versions for `feb_system_v4`, the rewired
top of the 260518-feb-ok build. Companion to
[`ADDR_MAP_PROPOSAL.md`](ADDR_MAP_PROPOSAL.md) (per-slave SC-hub address map)
and [`BUG_HISTORY.md`](BUG_HISTORY.md).

## Top + subsystems

| Instance | Kind | Version | Source | Role |
|---|---|---|---|---|
| `feb_system_v4` (top) | `feb_system_v4` | `26.4.0.0518` | `firmware_builds/systems/260518-feb-ok/generated/qsys/feb_system_v4.qsys` (local seed) | board top; instantiates the 3 subsystems + clocks |
| `control_path_subsystem` | `debug_sc_system_v4` | `26.4.0.0518` | `quartus_systems/debug_sc_system_v4.qsys` | sc_hub + slow-control fabric, hosts Region A slaves |
| `data_path_subsystem` | `scifi_datapath_system_v4` | `26.4.0.0518` | `firmware_builds/systems/260518-feb-ok/generated/qsys/scifi_datapath_system_v4.qsys` (local patched) + `quartus_systems/scifi_datapath_system_v4.qsys` (mirror) | MuTRiG receive + arbitration + hist, hosts Region B slaves |
| `upload_subsystem` | `upload_system_v4` | `26.4.0.0518` | `quartus_systems/upload_system_v4.qsys` | run-control mgmt host + upload mux, hosts Region C |
| `bringup_subsystem` | `feb_bringup_system` | `1.0` (TODO bump to `26.x.y.0518`) | `quartus_systems/feb_bringup_system.qsys` | Nios II + JTAG UART for bring-up |

All v3 predecessors (`feb_system_v3*`, `debug_sc_system_v3*`, `scifi_datapath_system_v3*`, `upload_system_v3*`, `mutrig_datapath_system_v3` snapshot copies of the variants) are parked under `quartus_systems/deprecated/`.

## Region A — ctrl-path slaves (instances inside `control_path_subsystem`)

See [`ADDR_MAP_PROPOSAL.md`](ADDR_MAP_PROPOSAL.md) for the SC-hub byte map.

| Instance | Kind | Version | Status |
|---|---|---|---|
| `scratch_pad_ram` | `altera_avalon_onchip_memory2` | `18.1` | vendor |
| `onewire_master_controller_0` | `onewire_master_controller` | `26.2.1.0428` | OK |
| `onewire_master_0` (link layer, private bus only) | `onewire_master` | `26.2.1.0428` | OK |
| `max10_prog_avmm_0` | `max10_prog_avmm` | `0.2.0` (TODO bump to `26.x.y.0518`) | bad version format |
| `firefly_xcvr_ctrl_0` | `firefly_xcvr_ctrl` | `26.2.0423` | OK |
| `on_die_temp_sense_ctrl` | `altera_temp_sense_ctrl` | `1.1` | vendor |
| `mutrig_cfg_ctrl_0` | `mutrig_cfg_ctrl` | `24.1.0423` | OK (also owns dangling `avmm_cnt` master, to be wired into the new `ctrl2data_mm_bridge`) |
| `sc_hub` | `sc_hub_v2` | `26.6.10.0423` | OK |
| `pll_156t40` | `altera_pll` | `18.1` | vendor |
| `pll_reset_inactive` | `inactive_reset_source` | `26.0.0.0425` | OK |
| `legacy_firefly_bridge` | `altera_avalon_mm_bridge` | `18.1` | **to drop** — orphan, m0 reaches no slave |
| `mm_bridge` (sc_hub → data_path) | `altera_avalon_mm_bridge` | `18.1` | **rename `ctrl2data_mm_bridge` + widen to 128 KB max-burst 256** |
| `upload_mm_bridge` (sc_hub → upload) | `altera_avalon_mm_bridge` | `18.1` | **rename `ctrl2upload_mm_bridge` + widen to 64 KB** |
| `jtag_master` | `altera_jtag_avalon_master` | `18.1` | vendor; local Region A reach |

## Region B — data-path slaves (instances inside `data_path_subsystem`)

| Instance | Kind | Version | Status |
|---|---|---|---|
| `lvds_rx_28nm_0` | `altera_lvds_rx_28nm` | `24.0.1110` | vendor |
| `lvds_rx_controller_pro_0` | `lvds_rx_controller_pro` | `25.1.0631` | OK |
| `mutrig_datapath_subsystem_{0..7}` | `mutrig_datapath_system_v3` | `1.0` (TODO bump) | sub-subsystem, version pending |
| `mutrig_datapath_subsystem_{0..7}.mutrig_frame_deassembly_0` | `mutrig_frame_deassembly` | `26.2.0.0511` | OK |
| `mutrig_datapath_subsystem_{0..7}.backpressure_fifo` | `altera_avalon_sc_fifo` | `18.1` | vendor |
| `mts_preprocessor_0` | `mts_preprocessor` | `26.3.5.0518` | OK |
| `mts_preprocessor_1` | `mts_preprocessor` | `26.3.5.0518` | OK |
| `hist_type0_lane{0..7}_tap` | `hit_type0_tap2` | `26.0.0.0517` | OK |
| `hist_type1_up_tap` / `hist_type1_down_tap` | `avst_snoop_splitter` | `26.0.0.0502` | OK |
| `hist_post_splitter_0` / `hist_post_cdc_0` | vendor splitter / DC-FIFO | `18.1` | vendor |
| `emulator_mutrig_qsys_inst` | `emulator_mutrig` | `26.3.3.0517` | OK |
| `emulator_hit_type0_fanout` | `hit_type0_fanout8` | `26.0.1.0517` | OK |
| `emulator_inject_fanout` | `pulse_fanout8` | `1.2` (TODO bump) | bad version |
| `mutrig_injector_0` | `mutrig_injector_multiheader` | `26.1.2.0517` | OK |
| `mutrig_reset_controller_0` | `mutrig_reset_controller` | `1.1.0` (TODO bump) | bad version |
| `mux_mutrig2processor` / `mux_mutrig2processor_0` | `hit_type0_readyless_mux4` | `26.1.0.0516` | OK |
| `arb_hit_type0_supercore_0` (wrapper) | `arb_hit_type0_supercore` | `1.0` (TODO bump) | bad version on wrapper; lanes OK below |
| `arb_hit_type0_supercore_0.lane_{0..7}` | `arb_hit_type0` | `26.6.5.0518` | OK |
| `histogram_statistics_0` | `histogram_statistics_v2` | `26.3.5.0522` | OK; **hist_bin 256-word burst aperture target** |
| `hit_stack_subsystem_{0,1}` | `hit_stack_system` | `1.0` (TODO bump) | sub-subsystem, version pending |
| `hit_stack_subsystem_{0,1}.feb_frame_assembly_0` | `feb_frame_assembly` | `26.0.0328` | OK |
| `hit_stack_subsystem_{0,1}.ring_buffer_cam_{0..3}` | `ring_buffer_cam` | `26.2.13.0516` | OK |
| `dbg_mm2runctrl_0` | `dbg_mm2runctrl` | `1.0.0` | **to drop** — replaced by `runctl_mgmt_host_0.runctl` AvST source |
| `master_datapath` | `altera_jtag_avalon_master` | `18.1` | vendor; local Region B JTAG reach |

## Region C — upload-subsystem slaves (inside `upload_subsystem`)

| Instance | Kind | Version | Status |
|---|---|---|---|
| `runctl_mgmt_host_0` | `runctl_mgmt_host` | `26.3.2.0513` | OK; AvST `runctl` source already injects run-control commands |
| `upload_pkt_mux` | `multiplexer` | `18.1` | vendor |
| `upload_cdc_fifo` / `upload_sc_cdc_fifo` | `altera_avalon_dc_fifo` | `18.1` | vendor |
| `csr_bridge` | `altera_avalon_mm_bridge` | `18.1` | vendor |
| `upload_system_jtag_master` | `altera_jtag_avalon_master` | `18.1` | vendor; local Region C JTAG reach |

## Pending version bumps (ip-packaging skill format `YY.MINOR.PATCH.MMDD`)

Visible badge `1.0` / `1.2` / `0.2.0` / `1.1.0` IPs scheduled for an identity-header pass:
- `max10_prog_avmm` (`0.2.0`)
- `mutrig_reset_controller` (`1.1.0`)
- `pulse_fanout8` (`1.2`)
- `dbg_mm2runctrl` (`1.0.0`) — moot, will be removed
- `feb_bringup_system` (`1.0`) — wrapper subsystem
- `arb_hit_type0_supercore` wrapper (`1.0`) — wrapper subsystem, lanes already at 26.6.5.0518
- `mutrig_datapath_system_v3` (`1.0`) — wrapper subsystem
- `hit_stack_system` (`1.0`) — wrapper subsystem

The four kept-at-`v18.1` items (`altera_*`, `altera_avalon_*`, `multiplexer`) are vendor IPs and stay on the Quartus 18.1 stamp.

## Files moved to `quartus_systems/deprecated/` (2026-05-18 v3→v4 cut)

- `debug_sc_system_v3.qsys`, `debug_sc_system_v3_lvdsctrl.qsys`, `debug_sc_system_v3_lvdsctrl_cbb.qsys`
- `scifi_datapath_system_v3.qsys`, `scifi_datapath_system_v3_pipe.qsys`, `scifi_datapath_system_v3_lat4.qsys`
- `upload_system_v3.qsys`, `upload_system_v3_lvdsctrl.qsys`
- `feb_system_v3.qsys`, `feb_system_v3_pipe.qsys`, `feb_system_v3_pipe_lvdsctrl.qsys`, `feb_system_v3_lat4.qsys`

`mutrig_datapath_system_v3.qsys` stays in `quartus_systems/` because it is a
sub-subsystem inside `scifi_datapath_system_v4` that this rewire does not
touch — the kind reference remains `mutrig_datapath_system_v3`.

## Live readback evidence

- On-board probe of the v3 build (pre-rewire): [`tb_int/reports/feb_inventory_20260518_150948.md`](../tb_int/reports/feb_inventory_20260518_150948.md) — 11 of 14 endpoints reachable via sc_hub, 3 OUT-OF-BRIDGE (hist_csr, hist_bin, mutrig_injector). The v4 rewire is targeted to make those 3 reachable.
