# FE SciFi System Console Toolkit

This folder is the tracked source of truth for the FE SciFi System Console runtime payload.

Authoritative path:

- `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/toolkits/fe_scifi`

Compatibility path consumed by the FE SciFi project:

- `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores/toolkits/fe_scifi`

That compatibility path is expected to resolve through:

- `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores -> mu3e-ip-cores_snapshot_20260408`
- `/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores/toolkits -> /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/toolkits`

Do not add new toolkit edits under the deprecated snapshot tree
`/home/yifeng/packages/online_dpv2/online/mu3e-ip-cores/toolkits/`.

It intentionally contains only the files needed to launch and maintain the toolkit:

- `board_bring_up/`: Board Bring Up (Datapath) toolkit, CSR metadata, and debug-only launch hooks.
- `system_console/`: shared Tcl packages, BSP bindings, figures, and bundled Tcl XML/DOM runtime files.
- `bts/`: registered toolkit entry points used by `register_toolboxes.tcl`.

The FE SciFi project keeps extra local `bts/` artifacts such as STP files and generation scripts. Those are not duplicated here unless they are part of the live System Console runtime.

Design notes:

- Project-specific compiled inventory is always taken from the FE SciFi build tree `.sopcinfo`, not from this shared folder.
- Debug-only launch helpers stay under `board_bring_up/debug/` and are disabled by default.
- Future FE SciFi bring-up toolkits can be added as siblings under this folder without changing the runtime layout expected by System Console.

Debug helpers:

- `board_bring_up/debug/board_bring_up_debug_desktop.tcl`: debug-only GUI launcher that keeps the normal desktop flow unchanged, then runs the post-launch runtime probe.
- `board_bring_up/debug/board_bring_up_runtime_probe.tcl`: toolkit-runtime probe that writes `/tmp/board_bring_up_runtime_probe.txt`.
- `board_bring_up/debug/board_bring_up_cli_probe.tcl`: CLI-only inventory probe. Example:
  `system-console --script=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/toolkits/fe_scifi/board_bring_up/debug/board_bring_up_cli_probe.tcl`
