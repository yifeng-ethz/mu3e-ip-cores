# FEB SciFi v3 Board Project - v3_pretest-260511-rc-readyless-260511

This directory is a self-contained Quartus board-project mint for the
`v3_pretest-260511-rc-readyless-260511` FEB SciFi candidate.

## Structure

- `top.qpf` / `top.qsf`: clean single-revision Quartus project for revision `top`.
- `top.qip`: board-local source manifest. Paths are resolved from `$::quartus(qip_path)` and the repo root.
- `src/`, `assignments/`, `util/`, `common/`, `fe/`, `ip/`, `bts/`, `firmware/`, `generated/`, `software/`: source-of-truth subtrees copied from the Apr 27 board project template.
- `REPORT.md`: compile evidence and current bring-up verdict.

SignalTap is intentionally not part of this project. `top.qsf` has no `USE_SIGNALTAP_FILE`, `ENABLE_SIGNALTAP`, `SLD_NODE_*`, or `CONNECT_TO_SLD_NODE_*` assignments.

## Qsys Generation

The generated FEB system QIP is expected at:

```text
firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/feb_system_v3/synthesis/feb_system_v3.qip
```

The local source symlink is:

```text
firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/feb_system_v3.qsys
```

Run qsys generation from the repo root or this workspace with the required catalog paths:

```bash
export QSYS_EXTRA_SEARCH_PATHS="/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/charge_injection/script:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/charge_injection/legacy:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/onewire_temp_sense/script:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/script:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/ring-buffer_cam/script:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/mu3e_lvds_controller/script:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/mutrig_frame_deassembly/script:/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/slow-control_hub/legacy"
export QSYS_ISOLATE_CATALOG=1
firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/script/generate_feb_system_v3.sh
```

The project-local qsys wrapper marks generated `*.qsys`, `*.sopcinfo`, and `synthesis/` outputs read-only after a successful generate.

## Quartus Compile

From this directory:

```bash
quartus_sh --flow compile top
```

The current compile evidence is recorded in `REPORT.md` after the rc-readyless
Qsys generation and Quartus compile complete.
