# SC-Hub System SVD Audit

Date: 2026-05-06

Generated SVD:

- `firmware_builds/systems/system_20260504_full8lane_type0/svd/full8lane_type0_system_sc_hub.svd`

Generator:

- `firmware_builds/systems/system_20260504_full8lane_type0/script/generate_sc_hub_system_svd.py`

## Address Reference

All `baseAddress` values in the generated SVD are offsets in the SC-hub command
address space downstream of `sc_hub.hub` / `sc_hub_cmd_pipe.m0`.

- Direct control-path slaves use the compiled `sc_hub_cmd_pipe.m0` base.
- Datapath-local slaves use `0x00020000 + AUTO_AVMM_PORT_ADDRESS_MAP.start`.
- Upload-local slaves use `0x00030000 + AUTO_UPLOAD_AVMM_PORT_ADDRESS_MAP.start`.
- `sc_hub.csr` is not listed because it is the upstream JTAG-side CSR aperture,
  not a downstream SC-hub command-space slave.

The LVDS controller therefore appears at SC-hub-relative `0x00029000`
(`mm_bridge.s0` `0x00020000` plus datapath-local `0x9000`). This is distinct
from the direct LVDS debug/JTAG master aperture in the build Tcl.

## Description And RTL Match

Copied source SVDs with meaningful register descriptions:

- `toolkits/infra/cmsis_svd/generic/scratch_pad_ram.svd`
- `onewire_temp_sense/script/onewire_master_controller.svd`
- `feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd`
- `charge_injection/legacy/charge_injection_pulser.svd`
- `firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd`
- `mutrig_controller/mutrig_cfg_ctrl.svd`
- `toolkits/infra/cmsis_svd/generic/backpressure_fifo_window.svd`
- `mutrig_frame_deassembly/script/mutrig_frame_deassembly.svd`
- `emulator_mutrig/emulator_mutrig.svd`
- `toolkits/infra/cmsis_svd/generic/histogram_bin_window.svd`
- `histogram_statistics/histogram_statistics.svd`
- `histogram_statistics/histogram_ingress_bridge.svd`
- `charge_injection/script/mutrig_injector.svd`
- `run-control_mgmt/runctl_mgmt_host.svd`

RTL-derived SVD content:

- `data_path_subsystem_lvds_rx_controller_pro_0.csr`: generated from
  `mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv`. The standalone
  `mu3e_lvds_controller/lvds_rx_controller_pro.svd` is also regenerated from
  the current SV controller map through
  `mu3e_lvds_controller/lvds_rx_controller_pro_cmsis_svd.tcl`.
- `data_path_subsystem_arb_hit_type0_supercore_0_lane_[0..7].csr`: generated
  from `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv` and the per-lane child
  modules in `syn/arb_hit_type0_supercore.qsys`.

Raw placeholder windows are present where the compiled Qsys map exposes a slave
but this worktree does not contain a semantic source SVD matching that block:

- `on_die_temp_sense_ctrl.csr`
- `legacy_firefly_bridge.s0`
- `data_path_subsystem_mutrig_reset_controller_0.reconfig_mgmt`
- `data_path_subsystem_dbg_mm2runctrl_0.csr`
- `data_path_subsystem_mts_preprocessor_[0..1].csr`
- `data_path_subsystem_hit_stack_subsystem_*_ring_buffer_cam_*.csr`
- `data_path_subsystem_hit_stack_subsystem_*_feb_frame_assembly_0.csr`

Those raw windows are intentionally named as undecoded words so software does
not infer field semantics that were not verified against RTL.

## Version Notes

The generated SVD embeds the compiled Qsys kind/version and the visible
`VERSION_*`, `BUILD`, `IP_UID`, and `INSTANCE_ID` parameters in each peripheral
description when present in the compiled `.qsys`.

Important mismatches called out in the generated SVD:

- LVDS compiled module version is `26.2.1.506`. The Tcl build supplies
  `BUILD=0x506` and `VERSION_DATE=0x20260506`, which Qsys serializes as decimal
  `BUILD=1286` and `VERSION_DATE=539362566`.
- The build Tcl requests `runctl_mgmt_host_readyless_version=26.3.0.505`, while
  the generated top-system HTML reports `upload_subsystem_runctl_mgmt_host_0`
  as `runctl_mgmt_host 26.2.6.425`. The copied source SVD is
  `run-control_mgmt/runctl_mgmt_host.svd` version `26.3.0.0505`.

## Validation

The generated SVD was parsed successfully after generation. The validation
checked:

- 60 peripherals and 1519 registers are emitted.
- Key SC-hub-relative bases match the compiled Qsys maps:
  - LVDS CSR: `0x00029000`
  - run-control upload CSR: `0x00030000`
  - histogram statistics CSR: `0x0002A400`
  - histogram ingress bridge CSR: `0x0002AC00`
  - type0 arbiter lane 0 CSR: `0x00022280`
  - scratchpad RAM: `0x00000000`
  - MuTRiG config controller CSR: `0x0003F010`
- No register extends beyond its peripheral address block.
- No generated peripheral address blocks overlap.
