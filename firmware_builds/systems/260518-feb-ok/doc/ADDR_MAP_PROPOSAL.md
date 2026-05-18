# FEB SciFi v3 — proposed SC-hub address map (2026-05-18)

Status: **PROPOSAL** — awaiting approval before qsys rewiring.

## Bridge architecture summary

Three regions on `sc_hub_cmd_pipe.m0`, all inside the 18-bit sc_tool word range (0x0..0x3FFFF):

| Region | sc-byte | sc-word | Span | Bridge | Notes |
|---|---|---|---|---|---|
| **A. Direct ctrl-path slaves** | 0x00000–0x0FFFF | 0x00000–0x03FFF | 64 KB | none | 4 KB slot per slave, function-grouped |
| **B. Data-path bridge window** | 0x10000–0x2FFFF | 0x04000–0x0BFFF | 128 KB | `ctrl2data_mm_bridge` | sc_hub + `mcc.avmm_cnt` share via Qsys arbiter; **max burst = 256 words** |
| **C. Upload bridge window** | 0x30000–0x3FFFF | 0x0C000–0x0FFFF | 64 KB | `ctrl2upload_mm_bridge` | sc_hub only |
| (hub-special) | — | 0x0FE80–0x0FE9F | 128 B (32 words) | hub-internal | sc_hub_v2's own CSR (UID/META/CTRL/STATUS/ERR_*/SCRATCH/GTS_SNAP_*/FIFO_*/EXT_*/LAST_*/OOO_*/ORD_*/DBG_*/FEB_TYPE/HUB_CAP) |

Three local JTAG masters (one per subsystem) connect to their own slaves only, skipping cross-subsystem bridges and skipping the link-layer IPs that sit on private internal buses (`onewire_master_0.ctrl` is reached only by `onewire_master_controller_0.ctrl` master; not on sc_hub or any JTAG):

| Subsystem | JTAG master | View base | Slaves reached |
|---|---|---|---|
| ctrl_path  | `control_path_subsystem.jtag_master` | 0x00000 | Region A (all 6 slaves, incl. `onewire_master_controller_0.csr`) |
| data_path  | `data_path_subsystem.master_datapath` | 0x00000 | Region B (all 9 slaves) |
| upload     | `upload_subsystem.upload_system_jtag_master` | 0x00000 | Region C (1 slave) |

Cross-subsystem master:
- `control_path_subsystem.mutrig_cfg_ctrl_0.avmm_cnt` joins the `ctrl2data_mm_bridge` slave side (alongside `sc_hub_cmd_pipe.m0`) so it can burst-read `histogram_statistics_0.hist_bin` across the subsystem boundary.

## UID identity convention

- Mu3e IPs expose a software-visible 32-bit `UID` register at offset `0x00`, default ASCII 4-char code.
- Vendor IPs (Altera onchip RAM, mm_bridge, temp_sense_ctrl) do not have a UID register.
- A few legacy Mu3e IPs (`firefly_xcvr_ctrl`, `mutrig_cfg_ctrl`, `mutrig_reset_controller`) also do not have the standard identity header; offset 0x00 carries a different functional register on those.

Where there is no UID, the table shows `—`.

## Region A — ctrl-path subsystem (64 KB, function-grouped)

`sc_hub` and `control_path_subsystem.jtag_master` see Region A directly.

| sc-byte | sc-word | ctrl_jtag byte | slave | UID (hex) | UID (ASCII) | span | functional group |
|---|---|---|---|---|---|---|---|
| `0x00000` | `0x00000` | `0x00000` | `scratch_pad_ram.s1` | — | — | 1 KB | bring-up scratch |
| `0x01000` | `0x00400` | `0x01000` | `max10_prog_avmm_0.csr_avmm` | `0x4D313050` | `M10P` | 4 KB | board hw — MAX10 ICE programmer |
| `0x02000` | `0x00800` | `0x02000` | `on_die_temp_sense_ctrl.csr` | — | — | 4 B | board hw — FPGA junction temp |
| `0x03000` | `0x00C00` | `0x03000` | `onewire_master_controller_0.csr` | `0x4F574D43` | `OWMC` | 64 B | board hw — DS18B20 controller (drives private onewire_master link layer) |
| `0x04000` | `0x01000` | `0x04000` | `firefly_xcvr_ctrl_0.firefly` | — | — | 128 B | optics — Firefly I2C controller |
| `0x05000` | `0x01400` | `0x05000` | `mutrig_cfg_ctrl_0.avmm_csr` | — | — | 16 B | MuTRiG slow control (also owns `avmm_cnt` master) |
| — | `0x0FE80–0x0FE9F` | — | `sc_hub_v2` internal CSR (32 words) | `0x53434842` | `SCHB` | 128 B | hub-special; not in either jtag view |

Region A footprint = 24 KB out of 64 KB. `legacy_firefly_bridge` is **dropped** (orphan `altera_avalon_mm_bridge` v18.1 — its m0 master reached no slave, so reads/writes through it died silently).

> **Note**: `onewire_master_0.ctrl` (the link-layer IP, 64 B at private base `0x0000`) is reached only via `onewire_master_controller_0.ctrl` master and is **not on Region A's bus**; sc_hub and JTAG drive the controller, the controller drives the link layer.

## Region B — data-path subsystem (128 KB, flow-ordered)

`sc_hub` view = `ctrl2data_mm_bridge` base 0x10000 + internal offset. `data_jtag` (`master_datapath`) view = internal directly. `mutrig_cfg_ctrl_0.avmm_cnt` shares the bridge with `sc_hub`.

| sc-byte | sc-word | data_jtag byte | slave | UID (hex) | UID (ASCII) | span | flow stage |
|---|---|---|---|---|---|---|---|
| `0x10000` | `0x04000` | `0x00000` | `lvds_rx_controller_pro_0.csr` | `0x4C564453` | `LVDS` | 64 B | 1. INPUT — LVDS receiver |
| `0x11000` | `0x04400` | `0x01000` | `mutrig_reset_controller_0.reconfig_mgmt` | — | — | 256 B | 2. SOURCE RESET — chip resets upstream |
| `0x12000` | `0x04800` | `0x02000` | `mutrig_injector_0.csr` | `0x4D494E4A` | `MINJ` | 64 B | 3. SOURCE STIMULUS — calibration injector |
| `0x13000` | `0x04C00` | `0x03000` | `emulator_mutrig_qsys_inst.csr` | `0x454D5554` | `EMUT` | 256 B | 4. ALT SOURCE — synthetic MuTRiG hits |
| `0x14000` | `0x05000` | `0x04000` | `mts_preprocessor_0.csr` | `0x4D545350` | `MTSP` | 32 B | 5a. TIMESTAMP — bank A |
| `0x15000` | `0x05400` | `0x05000` | `mts_preprocessor_1.csr` | `0x4D545350` | `MTSP` | 32 B | 5b. TIMESTAMP — bank B |
| `0x16000` | `0x05800` | `0x06000` | `arb_hit_type0_supercore_0` (lane 0..7 csr) | `0x41485430` | `AHT0` | 8 × 128 B = 1 KB | 6. ARBITRATION — lane 0..7 csr |
| `0x17000` | `0x05C00` | `0x07000` | `histogram_statistics_0.csr` | `0x48495354` | `HIST` | 17 words (68 B) | 7. MONITOR — identity header at words 0-1, control/status at words 2-16 |
| `0x18000` | `0x06000` | `0x08000` | `histogram_statistics_0.hist_bin` | — | — | 256 words (1 KB) | 8. MONITOR DATA — clean bin[0..255] burst aperture, no header |

Region B footprint = 36 KB out of 128 KB. `dbg_mm2runctrl_0` is **dropped** (replaced by `runctl_mgmt_host_0.runctl` AvST source which already injects run-control commands).

`histogram_statistics_0.hist_bin` at internal `0x08000` (sc-byte `0x18000`) is 8 KB-aligned, leaving the entire low 256-word burst window unambiguous for both `sc_hub` and `mutrig_cfg_ctrl_0.avmm_cnt`.

## Region C — upload subsystem (64 KB)

| sc-byte | sc-word | upload_jtag byte | slave | UID (hex) | UID (ASCII) | span | note |
|---|---|---|---|---|---|---|---|
| `0x30000` | `0x0C000` | `0x00000` | `runctl_mgmt_host_0.csr` | `0x52434D48` | `RCMH` | 128 B | run-control command injection lives on the IP's own `runctl` AvST source; CSR is the host-side knob |

Region C footprint = 128 B out of 64 KB.

## Reach summary by master

| master | own view | reach |
|---|---|---|
| `sc_hub_cmd_pipe.m0` | A: 0x00000..0x05FFF; B: 0x10000..0x18FFF; C: 0x30000..0x3007F | 6 + 9 + 1 = 16 slave endpoints |
| `control_path_subsystem.jtag_master` | A direct, minus both cross-subsystem bridges | 6 slaves |
| `data_path_subsystem.master_datapath` | B local: 0x00000..0x08FFF | 9 slaves |
| `upload_subsystem.upload_system_jtag_master` | C local: 0x00000..0x0007F | 1 slave |
| `mutrig_cfg_ctrl_0.avmm_cnt` | B only (uses the same 0x10000-offset view as sc_hub) | 1 burst target (`hist_bin` at sc-byte `0x18000`) |

## Rationale

- **4 KB stride everywhere there is headroom** — every slave is at a 4-digit-hex address, easy to remember.
- **Region B in flow order** — first slot is the receiver, last slot is the histogram readout; matches the way you would debug a hit through the system.
- **Region A grouped by hardware role** — scratch / board / optics / MuTRiG SC.
- **`hist_bin` at internal `0x08000`** — 8 KB aligned, two-decade margin over the 1 KB burst window.
- **`dbg_mm2runctrl_0` removed** — `runctl_mgmt_host_0.runctl` AvST source already injects run-control commands.

## Linked DV cases

- `DV_BASIC.md` B003 — SC-hub direct slave probe at every Region A/B/C address.
- `DV_BASIC.md` B004 — Per-subsystem JTAG reach (3 local masters, no bridges, no onewire).
- `DV_EDGE.md` E002 — sc_hub burstcount=256 read of `hist_bin` at sc-byte `0x18000`.
- `DV_CROSS.md` C002 — `mutrig_cfg_ctrl_0.avmm_cnt` 256-word burst read of `hist_bin` through the shared `ctrl2data_mm_bridge`.
