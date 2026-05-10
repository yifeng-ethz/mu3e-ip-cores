# system_20260504_full8lane_type0

Full 8-lane FEB SciFi Type0 integration build.

Authoritative build notes live in `doc/SYSTEM_PLAN.md`. The Platform Designer
systems are generated from Tcl; do not hand-edit generated `.qsys`, `.sopcinfo`,
IPX, or `synthesis/` output.

## Qsys Regeneration

Regenerate the full system through the wrapper script:

```bash
firmware_builds/systems/system_20260504_full8lane_type0/script/regen_full8lane_system.sh
```

The wrapper applies `syn/build_full8lane_system.tcl`, refreshes the generated
Qsys/SOPC artifacts, and makes generated Platform Designer output read-only on
success.

## SC-Hub System SVD

After Qsys regeneration, emit the grouped CMSIS-SVD address map:

```bash
python3 firmware_builds/systems/system_20260504_full8lane_type0/script/generate_sc_hub_system_svd.py
```

Output:

```text
firmware_builds/systems/system_20260504_full8lane_type0/svd/full8lane_type0_system_sc_hub.svd
```

Every `baseAddress` in this SVD is relative to the SC-hub command address
space. The generator reads the compiled Qsys maps and expands:

- direct `sc_hub_cmd_pipe.m0` control-path slaves at their compiled bases,
- datapath-local `AUTO_AVMM_PORT_ADDRESS_MAP` slaves below `0x00020000`,
- upload-local `AUTO_UPLOAD_AVMM_PORT_ADDRESS_MAP` slaves below `0x00030000`.

The generated SVD intentionally excludes the upstream JTAG-side `sc_hub.csr`
aperture. See `doc/SVD_AUDIT.md` for the register-description audit, RTL-derived
windows, missing semantic SVD placeholders, and version notes.

## Standalone SV LVDS SVD

The current SystemVerilog LVDS controller has a UID/META-based CSR layout. Its
standalone relative SVD is regenerated with:

```bash
tclsh mu3e_lvds_controller/lvds_rx_controller_pro_cmsis_svd.tcl \
  -o mu3e_lvds_controller/lvds_rx_controller_pro.svd
```

For this full8lane build the defaults are `N_LANE=9`, `N_ENGINE=1`,
`ROUTING_TOPOLOGY=1`, and `AVMM_ADDR_W=10`, matching the SV LVDS controller
configuration used by `syn/build_full8lane_system.tcl`.
