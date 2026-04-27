Self-contained local SciFi FEB Quartus project for the current v3 datapath/control system.

This project exists to restore the missing board-level peripherals that were outside the v3 Qsys comparison:
- `fe_block_v2` for the Arria-V transceiver/Firefly/slow-control sidecar
- the generated `nios` system and its memory-init payload
- the exact FE base plus SciFi pin assignments extracted into local Tcl files

Layout:
- `top.qsf`, `top.qpf`, `top.qip`: local Quartus project glue
- `assignments/`: extracted exact pin/device settings
- `src/`: board top, legacy FEB support RTL, shared common firmware, and the v3 wrapper
- `generated/`: local Nios hardware/software artifacts and legacy helper-IP QIPs used by `fe_block_v2`
- `ip/`, `bts/`: board-local helper IPs instantiated directly by `top.vhd`

Build notes:
- The project is wired only to this repo and uses the local `firmware_builds/*_v3` synthesis QIPs.
- If any local `firmware_builds/*_v3/synthesis/*.qip` outputs are missing, regenerate them before compile.
- Build from this directory with `quartus_sh --flow compile top`.
