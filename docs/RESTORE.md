# Restore Notes

## Scope

This note summarizes the recovery work after Claude deleted submodule worktrees and local IP catalog content under `mu3e-ip-cores`.

The goal of the restore was:

- recover missing submodule worktrees and git tracking
- restore missing `_hw.tcl` and RTL sources
- make the FE SciFi Platform Designer systems open and generate again
- re-align restored IP source trees with the generated `fe_scifi` outputs used by the current firmware flow
- add targeted FEB-level debug coverage for the slow-control burst-read issue now under investigation

## What Broke

The damage was not just missing files. There were two distinct failure modes:

- submodule worktrees had tracked files deleted from inside them
- some submodules also lost their local `.git` link / gitdir attachment, so the superproject still referenced them but the local checkout was no longer a working git repo

This affected both custom RTL IP and the local Quartus IP catalog layout.

## Recovery Sources Used

Recovery was done from the best surviving source available per IP:

1. Existing local submodule gitdirs under `.git/modules/*`
2. Upstream `yifeng-ethz/*` submodule remotes
3. Older local IP copies under:
   - `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores`
4. Generated Platform Designer outputs under:
   - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/*/synthesis`
   - especially `submodules/` content for exact RTL recovery
5. Quartus vendor IP content where needed, notably for `altera_lvds`
6. Claude local session artifacts under `~/.claude` as a tracker for which folders/files had been deleted

Rule used during restore:

- generated FE SciFi synthesis RTL was treated as the source of truth for active v2 IP behavior
- older `online/mu3e-ip-cores` copies were treated as the starting point for `_hw.tcl` packaging, GUI metadata, and legacy component structure

## Repo Layout Changes

To make the catalog easier to maintain after recovery, the top-level layout was cleaned up.

Quartus catalog collateral now lives under:

- `firmware_builds/components.ipx`
- `firmware_builds/mu3e_ip_cores.ipx`
- `firmware_builds/regenerate_ipx_catalog.sh`
- `firmware_builds/normalize_ipx_catalog.py`
- `firmware_builds/debug_sc_system_v2.qsys`
- `firmware_builds/logo/`

Local helper IP that is not carried as a dedicated submodule now lives under:

- `misc/conduit2rst`
- `misc/dbg_counter_fab`
- `misc/dbg_issp_fab`

Other cleanup:

- `onewire_sense_vector_bridge_26p0p330_hw.tcl` was moved into `onewire_temp_sense/`
- legacy `max10_prog_avmm` was folded under `feb_max10_comm/legacy/max10_prog_avmm`

## Platform Designer Source Of Truth

These are the active FE SciFi Platform Designer inputs used during restore and verification:

- main FE system:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/feb_system.qsys`
- active compile target:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/feb_system_v2.qsys`
- top-level project include list:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/top.qip`

`top.qip` currently includes:

- `scifi_datapath_system/synthesis/scifi_datapath_system.qip`
- `feb_system_v2/synthesis/feb_system_v2.qip`

For active v2 IP recovery, the main generated source-of-truth tree was:

- `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/feb_system_v2/synthesis`

Additional generated references used during restore included:

- `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/scifi_datapath_v2_system/synthesis/submodules`
- `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/debug_sc_system_v2.qsys`
- `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/debug_sc_system_v2.tcl`

## Restore Outcome

The restore brought the repo back to a usable state for Platform Designer and synthesis-source recovery.

Main outcome:

- broken submodule worktrees were reattached or recloned as proper `yifeng-ethz` submodules
- missing `_hw.tcl` and RTL were restored IP by IP
- `feb_system.qsys` was brought back to error-free open/generate
- `feb_system_v2.qsys` was regenerated in scratch and checked against the existing synthesis tree

For `feb_system_v2`, compile-relevant generated outputs are now effectively restored:

- HDL, SDC, HEX, and similar synthesis inputs regenerate byte-identically
- the only remaining generated drift is in `feb_system_v2.qip`
- that `qip` drift is metadata-only:
  - scratch-path references to copied `.qsys` / `.sopcinfo`
  - regenerated `GENERATION_ID`
  - catalog metadata text/order

There are also stale extra files in the old live synthesis tree that are not referenced by the generated `qip` and are not compile inputs.

## Firmware Compile Check

A scratch Quartus compile was run using the restored/generated inputs.

Observed result:

- synthesis-side structure is stable
- compile-relevant generated sources match the live `feb_system_v2/synthesis` tree
- final fitter output and final firmware images are not bit-identical

So the restore is sufficient for source-level regeneration equivalence, but not yet for guaranteed fitter/bitstream identity across full Quartus compilation.

## Slow-Control Burst Debug Coverage

The active functional issue still under investigation is the slow-control burst-read behavior where reading address `N+1` may return the data from address `N`.

Current hypothesis space:

- restored `_hw.tcl` interface contract mismatch causes wrong interconnect generation
- or the RTL already contains the bug

To support this, FEB-level debug coverage was expanded here:

- DV plan:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/tb/scifi_dp/doc/cases/feb_system/DV_PLAN.md`
- main bench:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/tb/scifi_dp/cases/feb_system/sc_dp_burst_vs_single/tb_sc_dp_burst_vs_single.vhd`
- run script:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/tb/scifi_dp/cases/feb_system/sc_dp_burst_vs_single/run_questa.sh`
- latest partial rerun log:
  - `/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/tb/scifi_dp/cases/feb_system/sc_dp_burst_vs_single/rerun.log`

Added FEB cases:

- `SC-37` Burst-vs-single slave matrix
- `SC-38` Random in-aperture burst read sweep
- `SC-39` Boundary-tail burst-vs-single sweep
- `SC-40` Cross-slave burst characterization
- `SC-41` SC-hub burst path contract check

What the FEB bench checks now:

- compare burst read payloads against equivalent sequential single-word reads
- sweep all active control-path and datapath CSR slaves
- exercise in-aperture random addressing
- exercise end-of-window boundary reads
- intentionally inject cross-boundary bursts and classify behavior
- observe SC-hub arm/done cadence and path usage counters

Important limitation:

- this FEB harness still issues one SC burst packet at a time
- observed counters so far stay at:
  - `hub_tracked_max=1`
  - `hub_pending_pkt_max=1`
  - `hub_pending_ext_max=1`
- so it does not yet prove 4 concurrent outstanding SC transactions
- the standalone `slow-control_hub` UVM remains the better place for full outstanding-depth stress

## Current Debug Finding

The FEB bench reproduces the burst-vs-single mismatch in RTL simulation on the restored system.

Examples seen in the partial rerun:

- matched so far:
  - `scratch_pad_ram`
  - `max10_prog_avmm_0`
  - `lvds_rx_controller_pro_0`
  - `backpressure_fifo_0..7`
- mismatched so far:
  - `mutrig_cfg_ctrl_0`
  - `onewire_master_controller_0`
  - `mts_preprocessor_0/1`
  - `mutrig_frame_deassembly_0..4`

Earlier longer runs also showed the same pattern propagating into:

- `ring_buffer_cam`
- `mutrig_injector`
- `feb_frame_assembly`

That means the problem is reproducible in simulation and is not only a hardware symptom.

## Suggested Next Use

Use this file as the recovery entry point before touching any restored IP again.

Recommended order when debugging further:

1. confirm whether the failing slave is wrong for single reads, burst reads, or only SC-hub burst forwarding
2. check the corresponding `_hw.tcl` Avalon slave contract against the old generated interconnect assumptions
3. diff the restored source RTL against the generated v2 RTL used as truth during this restore
4. only after that, change interface metadata or RTL behavior

## Status

At the time this note was written:

- `mu3e-ip-cores` has been restored to a usable catalog + submodule state
- FE SciFi Platform Designer generation is working again
- the slow-control burst-read issue remains an open functional debug item
