# TEST_BU.md - Bring-up bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BASIC.md](TEST_BASIC.md), [TEST_PERF.md](TEST_PERF.md), [TEST_ERROR.md](TEST_ERROR.md), [TEST_EDGE.md](TEST_EDGE.md)
**ID range:** BU001-BU025
**Total:** 25 cases (24 directed reads + 1 gate)

**Methodology key:** **B** (bring-up): non-destructive read or identity probe; no stimulus.

**Bucket purpose:** every SC-hub slave responds; UID matches IP source-of-truth;
VERSION metadata cross-checks with packaged SVD; both bridges reachable. Must
pass before any later bucket is trusted.

**Evidence model (BU):** UID literal match + META `VERSION_MAJOR.MINOR.PATCH` match +
RO status reads consistent with quiescent board.

---

## 1. Summary

| Section | Cases | ID range | What it Proves |
|---|---:|---|---|
| Identity | 17 | BU001-BU017 | UID + META of each SC-hub slave matches source-of-truth |
| Live-vs-source | 3 | BU018-BU020 | rbCAM debug counters + metadata gate + bridge round-trip |
| Quiescent state | 4 | BU021-BU024 | SWB-side counters quiescent at cold-boot |
| Gate | 1 | BU025 | aggregate Phase 1 pass/fail |

---

## 2. Cases

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| BU001 | B | scratch_pad_ram quiescent | 1 | `sc_tool 2 read 0x00000` | well-formed 32-bit reply (not 0xFFFFFFFF) | `check_sc_bridges.py` |
| BU002 | B | sc_hub UID via overlay | 1 | `sc_tool 2 read 0x0FE80` | matches `sc_hub_0` row in Section 2.5 | overlay |
| BU003 | B | onewire_master UID + META | 1 | read 0x04400 + 0x04401 | matches `onewire_master_controller_0` row in Section 2.5 | `check_ip_metadata.py` |
| BU004 | B | max10_prog_avmm UID + META | 1 | read 0x04800 + 0x04801 | matches `max10_prog_avmm_0` row in Section 2.5 | `check_ip_metadata.py` |
| BU005 | B | charge_injection_pulser UID | 1 | read 0x04C00 | legacy row is `charge_injection_pulser_0`; slot 4 is free if dropped | `check_ip_metadata.py` |
| BU006 | B | firefly_xcvr_ctrl UID + META | 1 | read 0x05000 + 0x05001 | matches `firefly_xcvr_ctrl_0` row in Section 2.5 | `check_ip_metadata.py` |
| BU007 | B | on_die_temp_sense UID | 1 | read 0x05400 | matches `on_die_temp_sense_ctrl` row in Section 2.5 | `check_ip_metadata.py` |
| BU008 | B | mm_bridge transparent read | 1 | read 0x08000 | bridge returns valid reply; `mm_bridge` row documents map | `check_sc_bridges.py` |
| BU009 | B | upload_mm_bridge UID | 1 | read 0x0C000 | matches `runctl_mgmt_host_0` through `upload_mm_bridge` row in Section 2.5 | `check_sc_bridges.py` |
| BU010 | B | mutrig_cfg_ctrl UID | 1 | read 0x0FC04 | matches `mutrig_cfg_ctrl_0` row in Section 2.5 | `check_ip_metadata.py` |
| BU011 | B | runctl_mgmt_host CSR sweep | 1 | read CSR_UID..CSR_LOG_STATUS | LAST_CMD = 0; RX_CMD_COUNT = 0 | `check_sc_bridges.py` |
| BU012 | B | histogram_statistics_v2 UID | 1 | read hist CSR | matches `histogram_statistics_0` row in Section 2.5 | `check_ip_metadata.py` |
| BU013 | B | mts_preprocessor_0 / _1 UID | 2 | read both mts CSR bases | matches `mts_preprocessor_0` and `_1` rows in Section 2.5 | `check_ip_metadata.py` |
| BU014 | B | arb_hit_type0_supercore META | 1 | read supercore META + per-lane MODE | matches `arb_hit_type0_supercore_0`; LANE_COUNT = 8 | `check_ip_metadata.py` |
| BU015 | B | emulator_mutrig_qsys_lane UID | 1 | read emulator CSR base | matches `emulator_mutrig_0`..`_7` rows; `BYTE_STREAM_ENABLE = 0` | `check_ip_metadata.py` |
| BU016 | B | hit_type0_fanout8 instance | 1 | inspect synthesis tree | 1 instance, 8 outputs | grep submodules |
| BU017 | B | mutrig_frame_deassembly UID | 1 | read CSR base | `mutrig_frame_deassembly_0` row documents current map status | `check_ip_metadata.py` |
| BU018 | B | ring_buffer_cam debug counters | 1 | read rbCAM debug_msg2 | rbCAM rows in Section 2.5; push_cnt = pop_cnt = 0 at cold-boot | `check_sc_bridges.py` |
| BU019 | B | feb_frame_assembly_HSS0 / 1 UID | 2 | read both frame-asm CSRs | matches `feb_frame_assembly_0` and `_1` rows; actual_hits = 0 | `check_ip_metadata.py` |
| BU020 | B | live-vs-source metadata gate | 1 | full `check_ip_metadata.py` sweep | no live VERSION below Section 2.5 source; drift documented | `check_ip_metadata.py` |
| BU021 | B | mm_bridge round-trip | 1 | read 0x08000 then 0x08001 | both succeed | `check_sc_bridges.py` |
| BU022 | B | LINK_LOCKED_LOW status | 1 | read SWB link-lock low | bit 2 (FEB link 2) state visible | `sc_tool` SWB-side |
| BU023 | B | RESET_LINK_STATUS baseline | 1 | read SWB RESET_LINK_STATUS_R | matches last-sent reset-link cmd; default 0x14000000 | `rc_tool` |
| BU024 | B | DMA_STATUS baseline | 1 | read SWB DMA_STATUS | quiescent at cold-boot | `sc_tool` SWB-side |
| BU025 | B | BU gate | 1 | aggregate BU001-024 | 24/24 pass | this row |

---

## 2.5. IP UID / version master table

The table records the source-of-truth `_hw.tcl` module identity, the software
UID literal when one exists in the package/RTL, and the live SC-hub address map
used by the BU cases. `SC addr` is shown as byte address / packet word.
Built-in Platform Designer bridges are included because the BU bucket probes
them directly. The legacy charge-injection pulser is retained as a provenance
row because the working `debug_sc_system_v3.qsys` marks slot 4 free; no matching
drop commit appears in the most recent 20 commits.

| IP | kind | UID | version | author | build date | SC addr | csr base | note |
|---|---|---|---|---|---|---|---|---|
| scratch_pad_ram | TBD | TBD | TBD | TBD | TBD | 0x00000 / 0x00000 | 0x00000000 | built-in memory; BU bridge smoke |
| sc_hub_0 | sc_hub_v2 | 0x53434842 | 26.6.10.0423 | Yifeng Wang | 2026-04-23 | 0x3FA00 / 0x0FE80 | overlay | SC-hub UID overlay |
| onewire_master_controller_0 | onewire_master_controller | 0x4F574D43 | 26.2.1.0428 | Yifeng Wang | 2026-04-28 | 0x11000 / 0x04400 | 0x00011000 |  |
| onewire_master_0 | onewire_master | TBD | 26.2.1.0428 | Yifeng Wang | 2024-09-06 | no SC | controller-only | no SC, controller-only |
| max10_prog_avmm_0 | max10_prog_avmm | 0x4D312850 | 0.2.0 | Yifeng Wang | 2026-04-07 | 0x12000 / 0x04800 | 0x00012000 |  |
| charge_injection_pulser_0 | charge_injection_pulser | TBD | 4.0.5 | Yifeng Wang | 2024-07-16 | DROPPED (slot 4 free) | DROPPED | LEGACY; DROPPED (slot 4 free; no drop commit in last 20) |
| mutrig_injector_0 | mutrig_injector_multiheader | 0x4D494E4A | 26.1.0.0511 | Yifeng Wang | 2026-05-11 | 0x2B200 / 0x0AC80 | 0x0000B200 | ACTIVE |
| firefly_xcvr_ctrl_0 | firefly_xcvr_ctrl | TBD | 26.2.423 | Yifeng Wang | 2026-03-30 | 0x14000 / 0x05000 | 0x00014000 |  |
| legacy_firefly_bridge | altera_avalon_mm_bridge | TBD | 18.1 | Intel/Altera | Qsys built-in | 0x16000 / 0x05800 | 0x00016000 | Platform Designer bridge in SC map |
| on_die_temp_sense_ctrl | altera_temp_sense_ctrl | TBD | 1.1 | Yifeng Wang | 2024-05-22 | 0x15000 / 0x05400 | 0x00015000 |  |
| mutrig_cfg_ctrl_0 | mutrig_cfg_ctrl | TBD | 24.1.423 | Yifeng Wang | 2024-08-16 | 0x3F010 / 0x0FC04 | 0x0003F010 |  |
| mm_bridge | altera_avalon_mm_bridge | TBD | 18.1 | Intel/Altera | Qsys built-in | 0x20000 / 0x08000 | 0x00020000 | Platform Designer bridge to datapath map |
| upload_mm_bridge | altera_avalon_mm_bridge | TBD | 18.1 | Intel/Altera | Qsys built-in | 0x30000 / 0x0C000 | 0x00030000 | Platform Designer bridge to upload map |
| runctl_mgmt_host_0 | runctl_mgmt_host | 0x52434D48 | 26.3.0.0505 | Yifeng Wang | 2026-05-05 | 0x30000 / 0x0C000 | 0x00000000 |  |
| lvds_rx_controller_pro_0 | lvds_rx_controller_pro | TBD | 25.1.0631 | Yifeng Wang | 2025-01-24 | 0x20000 / 0x08000 | 0x00000000 |  |
| mutrig_reset_controller_0 | mutrig_reset_controller | TBD | 1.1.0 | Yifeng Wang | 2024-07-25 | 0x20200 / 0x08080 | 0x00000200 |  |
| emulator_mutrig_0 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x22000 / 0x08800 | 0x00002000 |  |
| emulator_mutrig_1 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x22040 / 0x08810 | 0x00002040 |  |
| emulator_mutrig_2 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x22080 / 0x08820 | 0x00002080 |  |
| emulator_mutrig_3 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x220C0 / 0x08830 | 0x000020C0 |  |
| emulator_mutrig_4 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x22100 / 0x08840 | 0x00002100 |  |
| emulator_mutrig_5 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x22140 / 0x08850 | 0x00002140 |  |
| emulator_mutrig_6 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x22180 / 0x08860 | 0x00002180 |  |
| emulator_mutrig_7 | emulator_mutrig | 0x454D5554 | 26.3.0.0506 | Yifeng Wang | 2026-05-06 | 0x221C0 / 0x08870 | 0x000021C0 |  |
| arb_hit_type0_supercore_0 | arb_hit_type0_supercore | 0x41485430 | 26.6.0.0512 | Mu3e IP team | 2026-05-12 | 0x22280 / 0x088A0 | 0x000022A0 | rc-readyless supercore; lane CSR contents are arb_hit_type0 |
| arb_hit_type0_0 | arb_hit_type0 | 0x41485430 | 26.6.0.0512 | Mu3e IP team | 2026-05-12 | 0x22280 / 0x088A0 | 0x000022A0 | per-lane CSR behind supercore |
| arb_hit_type0_runctl_0 | TBD | TBD | TBD | TBD | TBD | inside arb_hit_type0_supercore_0 | no separate aperture | TBD: no standalone _hw.tcl found; RTL block under misc/arb_hit_type0/rtl |
| mts_preprocessor_0 | mts_preprocessor | 0x4D546350 | 26.3.0.0512 | Yifeng Wang | 2026-05-12 | 0x24000 / 0x09000 | 0x00004000 |  |
| mts_preprocessor_1 | mts_preprocessor | 0x4D546350 | 26.3.0.0512 | Yifeng Wang | 2026-05-12 | 0x28000 / 0x0A000 | 0x00008000 |  |
| histogram_statistics_0 | histogram_statistics_v2 | 0x48495354 | 26.2.0.0511 | Yifeng Wang | 2026-05-11 | 0x2A400 / 0x0A900 | 0x0000A400 |  |
| histogram_ingress_bridge_0 | histogram_ingress_bridge | 0x48495342 | 26.0.2.0425 | OpenAI Codex | 2026-04-25 | 0x2AC00 / 0x0AB00 | 0x0000AC00 |  |
| ring_buffer_cam_0 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B000 / 0x0AC00 | 0x0000B000 |  |
| ring_buffer_cam_1 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B080 / 0x0AC20 | 0x0000B080 |  |
| ring_buffer_cam_2 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B100 / 0x0AC40 | 0x0000B100 |  |
| ring_buffer_cam_3 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B180 / 0x0AC60 | 0x0000B180 |  |
| ring_buffer_cam_4 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B400 / 0x0AD00 | 0x0000B400 |  |
| ring_buffer_cam_5 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B480 / 0x0AD20 | 0x0000B480 |  |
| ring_buffer_cam_6 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B500 / 0x0AD40 | 0x0000B500 |  |
| ring_buffer_cam_7 | ring_buffer_cam | 0x5242434D | 26.2.11.0511 | Yifeng Wang | 2026-05-11 | 0x2B580 / 0x0AD60 | 0x0000B580 |  |
| feb_frame_assembly_0 | feb_frame_assembly | TBD | 26.0.328 | Yifeng Wang | 2024-08-11 | 0x34000 / 0x0D000 | 0x0000D000 |  |
| feb_frame_assembly_1 | feb_frame_assembly | TBD | 26.0.328 | Yifeng Wang | 2024-08-11 | 0x34040 / 0x0D010 | 0x0000D040 |  |
| mutrig_frame_deassembly_0 | mutrig_frame_deassembly | 0x46526356 | 26.2.0.0511 | Yifeng Wang | 2026-05-11 | not mapped in v3_pretest AUTO map | TBD |  |

---

## 3. Verdict

**BU bucket verdict: PASS** (commits `5bd7e112` + `42222454`).
