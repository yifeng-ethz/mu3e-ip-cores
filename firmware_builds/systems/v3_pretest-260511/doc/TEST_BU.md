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
| BU002 | B | sc_hub UID via overlay | 1 | `sc_tool 2 read 0x0FE80` | UID = 0x53434842 ("SCHB") | overlay |
| BU003 | B | onewire_master UID + META | 1 | read 0x04400 + 0x04401 | UID = 0x4F574D43; META `26.2.1.MMDD` | `check_ip_metadata.py` |
| BU004 | B | max10_prog_avmm UID + META | 1 | read 0x04800 + 0x04801 | UID = 0x4D312850; META `0.1.0.0` | `check_ip_metadata.py` |
| BU005 | B | charge_injection_pulser UID | 1 | read 0x04C00 | UID matches RTL; WO access does not protocol-error | `check_ip_metadata.py` |
| BU006 | B | firefly_xcvr_ctrl UID + META | 1 | read 0x05000 + 0x05001 | UID + META match source | `check_ip_metadata.py` |
| BU007 | B | on_die_temp_sense UID | 1 | read 0x05400 | UID matches RTL | `check_ip_metadata.py` |
| BU008 | B | mm_bridge transparent read | 1 | read 0x08000 | bridge returns valid reply | `check_sc_bridges.py` |
| BU009 | B | upload_mm_bridge UID | 1 | read 0x0C000 | UID matches runctl_mgmt_host source | `check_sc_bridges.py` |
| BU010 | B | mutrig_cfg_ctrl UID | 1 | read 0x0FC04 | UID matches RTL | `check_ip_metadata.py` |
| BU011 | B | runctl_mgmt_host CSR sweep | 1 | read CSR_UID..CSR_LOG_STATUS | LAST_CMD = 0; RX_CMD_COUNT = 0 | `check_sc_bridges.py` |
| BU012 | B | histogram_statistics_v2 UID | 1 | read hist CSR | UID = 0x48495354 ("HIST") | `check_ip_metadata.py` |
| BU013 | B | mts_preprocessor_0 / _1 UID | 2 | read both mts CSR bases | UID + lane index per-instance | `check_ip_metadata.py` |
| BU014 | B | arb_hit_type0_supercore META | 1 | read supercore META + per-lane MODE | UID 26.6.0; LANE_COUNT = 8 | `check_ip_metadata.py` |
| BU015 | B | emulator_mutrig_qsys_lane UID | 1 | read emulator CSR base | UID matches; `BYTE_STREAM_ENABLE = 0` | `check_ip_metadata.py` |
| BU016 | B | hit_type0_fanout8 instance | 1 | inspect synthesis tree | 1 instance, 8 outputs | grep submodules |
| BU017 | B | mutrig_frame_deassembly UID | 1 | read CSR base | UID matches; idle when emulator on type0 path | `check_ip_metadata.py` |
| BU018 | B | ring_buffer_cam debug counters | 1 | read rbCAM debug_msg2 | push_cnt = pop_cnt = 0 at cold-boot | `check_sc_bridges.py` |
| BU019 | B | feb_frame_assembly_HSS0 / 1 UID | 2 | read both frame-asm CSRs | UID match; actual_hits = 0 | `check_ip_metadata.py` |
| BU020 | B | live-vs-source metadata gate | 1 | full `check_ip_metadata.py` sweep | no live VERSION below source; forward-compat drift documented | `check_ip_metadata.py` |
| BU021 | B | mm_bridge round-trip | 1 | read 0x08000 then 0x08001 | both succeed | `check_sc_bridges.py` |
| BU022 | B | LINK_LOCKED_LOW status | 1 | read SWB link-lock low | bit 2 (FEB link 2) state visible | `sc_tool` SWB-side |
| BU023 | B | RESET_LINK_STATUS baseline | 1 | read SWB RESET_LINK_STATUS_R | matches last-sent reset-link cmd; default 0x14000000 | `rc_tool` |
| BU024 | B | DMA_STATUS baseline | 1 | read SWB DMA_STATUS | quiescent at cold-boot | `sc_tool` SWB-side |
| BU025 | B | BU gate | 1 | aggregate BU001-024 | 24/24 pass | this row |

---

## 3. Verdict

**BU bucket verdict: PASS** (commits `5bd7e112` + `42222454`).
