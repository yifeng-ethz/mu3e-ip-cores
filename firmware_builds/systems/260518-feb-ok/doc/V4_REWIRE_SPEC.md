# FEB SciFi v3 — v4 rewire address-map spec (2026-05-18)

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

## Region B — data-path subsystem (128 KB, flow-ordered + TEST group)

`sc_hub` view = `ctrl2data_mm_bridge` base 0x10000 + internal offset. `data_jtag` (`master_datapath`) view = internal directly. `mutrig_cfg_ctrl_0.avmm_cnt` shares the bridge with `sc_hub`.

Flow order follows the actual MuTRiG → LVDS → arb → preprocessor → frame-assembly → monitor chain. The TEST group (chip-side stimulus IPs) is parked at the end so it never appears in the main data-path debug walk.

| sc-byte | sc-word | data_jtag byte | slave | UID (hex) | UID (ASCII) | span | flow stage |
|---|---|---|---|---|---|---|---|
| `0x10000` | `0x04000` | `0x00000` | `lvds_rx_controller_pro_0.csr` | `0x4C564453` | `LVDS` | 64 B | 1. INPUT — LVDS receiver |
| `0x11000` | `0x04400` | `0x01000` | `emulator_mutrig_qsys_inst.csr` | `0x454D5554` | `EMUT` | 256 B | 2. ALT SOURCE — synthetic MuTRiG hits |
| `0x12000` | `0x04800` | `0x02000` | `arb_hit_type0_supercore_0` (lane 0..7 csr in 8 × 128 B sub-slots) | `0x41485430` | `AHT0` | 1 KB | 3. ARBITRATION — lane 0..7 csr |
| `0x13000` | `0x04C00` | `0x03000` | `mts_preprocessor_0.csr` | `0x4D545350` | `MTSP` | 32 B | 4a. TIMESTAMP — bank A |
| `0x14000` | `0x05000` | `0x04000` | `mts_preprocessor_1.csr` | `0x4D545350` | `MTSP` | 32 B | 4b. TIMESTAMP — bank B |
| `0x15000` | `0x05400` | `0x05000` | `hit_stack_subsystem_0` (5 slaves in sub-slots; see below) | mixed | mixed | 1 KB | 5a. FRAME ASSEMBLY — bank 0 |
| `0x16000` | `0x05800` | `0x06000` | `hit_stack_subsystem_1` (5 slaves in sub-slots; see below) | mixed | mixed | 1 KB | 5b. FRAME ASSEMBLY — bank 1 |
| `0x17000` | `0x05C00` | `0x07000` | `histogram_statistics_0.csr` | `0x48495354` | `HIST` | 17 words (68 B) | 6. MONITOR — identity header at words 0-1, control/status at words 2-16 |
| `0x18000` | `0x06000` | `0x08000` | `histogram_statistics_0.hist_bin` | — | — | 256 words (1 KB) | 7. MONITOR DATA — clean bin[0..255] burst aperture, no header |
| `0x19000` | `0x06400` | `0x09000` | `mutrig_reset_controller_0.reconfig_mgmt` | — | — | 256 B | 8. TEST — chip resets upstream |
| `0x1A000` | `0x06800` | `0x0A000` | `mutrig_injector_0.csr` | `0x4D494E4A` | `MINJ` | 64 B | 9. TEST — calibration injector |

Region B footprint = 44 KB out of 128 KB. `dbg_mm2runctrl_0` is **dropped** (replaced by `runctl_mgmt_host_0.runctl` AvST source which already injects run-control commands).

`histogram_statistics_0.hist_bin` at internal `0x08000` (sc-byte `0x18000`) is 8 KB-aligned, leaving the entire low 256-word burst window unambiguous for both `sc_hub` and `mutrig_cfg_ctrl_0.avmm_cnt`.

### hit_stack_subsystem_{0,1} sub-slot layout (1 KB per subsystem, inside its 4 KB Region B slot)

| sub-offset | slave | UID (hex) | UID (ASCII) | span |
|---|---|---|---|---|
| `+0x000` | `feb_frame_assembly_0.csr` | — (no identity header) | `—` | 64 B (16 words, all read-only) |
| `+0x100` | `ring_buffer_cam_0.csr` | `0x5242434D` | `RBCM` | 128 B (10 words used, padded to 128 B) |
| `+0x200` | `ring_buffer_cam_1.csr` | `0x5242434D` | `RBCM` | 128 B |
| `+0x300` | `ring_buffer_cam_2.csr` | `0x5242434D` | `RBCM` | 128 B |
| `+0x400` | `ring_buffer_cam_3.csr` | `0x5242434D` | `RBCM` | 128 B |

The 8 hit_stack slaves per subsystem (4 RBCAM + 1 FFA, × 2 subsystems = 10 endpoints) are reachable via sc_hub through the widened `ctrl2data_mm_bridge`, and via `data_path_subsystem.master_datapath` JTAG at the same internal offsets. The hit_stack DC FIFOs (`run_ctrl_cdc_d2x` per subsystem) have **no avmm aperture** — they are pure data-path crossings.

#### Inside view: `ring_buffer_cam.csr` (UID `RBCM`, 10 words / 40 B used, 128 B aperture)

Source: `ring-buffer_cam/script/ring_buffer_cam.svd`.

| word | offset | name | access | description |
|---|---|---|---|---|
| `0x00` | `0x00` | `UID` | RO | Software-visible IP identifier. Default ASCII `RBCM` (`0x5242434D`). |
| `0x01` | `0x04` | `META` | RW | Read-multiplexed metadata word. Write `page_sel` (0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID). |
| `0x02` | `0x08` | `CTRL` | RW | `go`, `soft_reset`, `filter_inerr` control bits. |
| `0x03` | `0x0C` | `EXPECTED_LATENCY` | RW | Read-pointer delay target in cycles. |
| `0x04` | `0x10` | `FILL_LEVEL` | RO | Live fill-level estimate from push / pop / overwrite. |
| `0x05` | `0x14` | `INERR_COUNT` | RO | Count of filtered ingress timestamp-error hits. |
| `0x06` | `0x18` | `PUSH_COUNT` | RO | Total accepted push operations. |
| `0x07` | `0x1C` | `POP_COUNT` | RO | Total drained hits. |
| `0x08` | `0x20` | `OVERWRITE_COUNT` | RO | Total overwrite events. |
| `0x09` | `0x24` | `CACHE_MISS_COUNT` | RO | Total cache-miss / empty-search events. |
| `0x0A..0x1F` | `0x28..0x7C` | (reserved) | — | Reserved padding in 128 B aperture. |

#### Inside view: `feb_frame_assembly.csr` (no identity header, 16 words / 64 B opaque RO)

Source: `feb_frame_assembly/feb_frame_assembly.svd`.

| word | offset | name | access | description |
|---|---|---|---|---|
| `0x00..0x0F` | `0x00..0x3C` | `WORD000..WORD015` | RO | Opaque FEB frame-assembly status snapshot, 16 read-only words. |

Note: `feb_frame_assembly` does not currently carry the standard Mu3e identity header (UID at offset 0x00 returns one of the WORDxxx values, not an ASCII tag). Adopting the identity header is a follow-up IP-packaging task tracked in `SYSTEM_OVERVIEW.md`.

## Region C — upload subsystem (64 KB)

| sc-byte | sc-word | upload_jtag byte | slave | UID (hex) | UID (ASCII) | span | note |
|---|---|---|---|---|---|---|---|
| `0x30000` | `0x0C000` | `0x00000` | `runctl_mgmt_host_0.csr` | `0x52434D48` | `RCMH` | 128 B | run-control command injection lives on the IP's own `runctl` AvST source; CSR is the host-side knob |

Region C footprint = 128 B out of 64 KB.

## Reach summary by master

| master | own view | reach |
|---|---|---|
| `sc_hub_cmd_pipe.m0` | A: 0x00000..0x05FFF; B: 0x10000..0x1AFFF; C: 0x30000..0x3007F | 6 (A) + 26 (B) + 1 (C) = 33 slave endpoints |
| `control_path_subsystem.jtag_master` | A direct, minus both cross-subsystem bridges | 6 slaves |
| `data_path_subsystem.master_datapath` | B local: 0x00000..0x0AFFF | 26 slave endpoints (1 lvds + 1 emu + 8 arb-lane csr + 2 mts + 10 hit_stack + 2 hist + 1 reset_ctrl + 1 injector) |
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

