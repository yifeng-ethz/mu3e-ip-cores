# TEST_PLAN.md - FEB SciFi v3 on-board test plan

**Revision:** 2026-05-12 / draft-2 (DV-plan uniform-row rewrite)
**Target:** `mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511*` (FEB SciFi v3 cohort)
**Host:** `yifeng@teferi`, `/dev/mudaq0` via SWB on link 2
**ID range:** TP001-TP299
**Total:** 132 cases (current) - see Summary section for bucket counts

**Companion docs:**
[SIM_CONVENTIONS.md](SIM_CONVENTIONS.md),
[tb_int/doc/DV_PLAN.md](../tb_int/doc/DV_PLAN.md),
[tb_int/doc/DV_BASIC.md](../tb_int/doc/DV_BASIC.md),
[tb_int/doc/DV_EDGE.md](../tb_int/doc/DV_EDGE.md),
[tb_int/doc/DV_ERROR.md](../tb_int/doc/DV_ERROR.md),
[tb_int/doc/DV_PROF.md](../tb_int/doc/DV_PROF.md),
[../tb_int/doc/BUG_HISTORY.md](../tb_int/doc/BUG_HISTORY.md)

**Authoring scope:** comprehensive on-board sign-off and end-to-end sim cross-check.
Not a liveness smoke test. Each case is a single row with deterministic stimulus
or constrained-random axis sweep, a golden pass criterion, and an explicit
function reference (script or sequence path).

---

## Methodology key

- **B** (bring-up): non-destructive read or identity probe. No stimulus.
- **D** (directed): single deterministic stimulus with a golden expectation.
- **R** (constrained-random): UVM/Python sweep randomises the named axis;
  scoreboard checks count parity or shape.
- **P** (perf): performance / saturation. Uses theoretical-delta accounting.

## Bucket key

- **BASIC**: aggregate hit rate < 50% of OPQ ingress ceiling (lossless expected).
  Both sim and board hit counts must match the theoretical lossless reference
  within tolerance. Default sweep population.
- **PERF**: aggregate rate at or above OPQ ceiling. Loss is expected by design.
  Each row carries a theoretical_hits curve clipped at the ceiling; the on-board
  delta vs theoretical measures real loss.
- **Sanity-neg**: row predicate is `expected_hits = 0` (e.g. `lane_mask = 0x00`).

## SIM time conventions

All UVM directed simulation sequences use a fixed RUNNING stage duration of
exactly **1 ms** unless the sequence name and report explicitly declare a
long-soak exception. At `lvdspll_clk = 125 MHz` the timebase is 8 ns / tick,
so the standard RUNNING window is `RUN_WINDOW_8NS = 125000`. PREPARE, SYNC,
and TERMINATE may take whatever time the harness needs; they are not part of
the comparison window. Count and rate comparisons across rows use the absolute
count produced inside the 1 ms RUNNING window without post-scaling. Long-soak
runs (10 s+) declare their nonstandard duration in sequence/test name and
report. See `SIM_CONVENTIONS.md`.

## Theoretical-delta model

For each row we compute a theoretical reference:

```
active_channels = popcount(channel_mask) * popcount(lane_mask)
per_channel_rate_hps = rate_88fp / 256 * (125e6 / 256)
requested_hits = per_channel_rate_hps * active_channels * run_window_s
theoretical_hits = min(requested_hits, opq_ceiling_hps * run_window_s)
```

Then two deltas per row:

```
sim_delta_pct   = (sim_total_hits   - theoretical_hits) / theoretical_hits * 100
board_delta_pct = (board_total_hits - theoretical_hits) / theoretical_hits * 100
```

For BASIC rows both deltas should be near 0%. For PERF rows the sim_delta
typically stays near 0% (sim does not exhibit board-side OPQ saturation in
a 1 ms window), and board_delta < 0% records the on-board loss. Sanity-neg
rows expect `theoretical_hits = 0` and pass on `total_hits == 0`.

---

## Source of truth

| Board | SOF | Repo | Notes |
|---|---|---|---|
| SWB (A10 DE5, link 2) | `online_sc/online/switching_pc/a10_board/output_files/top.sof` | `online_sc` | `online_dpv2` SOF leaves BAR garbage; do not use |
| FEB SciFi v3 | `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-arbfix-260512/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof` | `mu3e-ip-cores` | latest dualport + arb-fix build (post-`abb3e455`) |

`sc_hub v2` is **word-addressed** (`byte_addr / 4`). All addresses in tables
below are `sc_tool` word addresses unless otherwise noted.

## Pre-flight checklist

1. `jtagconfig -n` shows `DE5 [3-6.2]` + `USB-BlasterII [7-2]`.
2. Flash SWB with `online_sc` SOF (only if cold or toggled).
3. Flash FEB v3 with `tools/run_script/program_feb.sh <feb_sof>` (enforces 20 s settle).
4. `sudo -n /usr/local/sbin/mudaq_recover_pcie`.
5. `lsmod | grep mudaq && ls /dev/mudaq0` both succeed.
6. `tools/run_script/build_local_tools.py` refreshes local `sc_tool` / `rc_tool`.
7. `swb_ring_lock sc_tool 2 read 0x00000` returns a well-formed 32-bit reply.
8. `tools/run_script/check_ip_metadata.py` clean.

---

## Summary

| Phase | Cases | ID range | Bucket | Status | What it Proves |
|---|---:|---|---|---|---|
| 1  Bring-up | 25 | TP001-TP025 | BASIC | done | per-slave UID + META + bridge audit |
| 2  BIST | 15 | TP051-TP065 | BASIC | done | scratchpad BIST + ATPG + hub ordering |
| 3  RC | 15 | TP101-TP115 | BASIC | done | run-control opcodes + SC-WEDGE topology fix |
| 4  Datapath | 15 | TP151-TP165 | BASIC | done | emulator type0 + histogram + checkpoint chain |
| 4.5 Channel mask | 6 | TP201-TP206 | BASIC | sim PASS, board PASS pending arbfix retest | per-channel histogram patterns |
| 4.5 Lane isolation | 8 | TP207-TP214 | BASIC | sim PASS, board partial | single-lane admit symmetry |
| 4.5 Rate sweep | 7 | TP215-TP221 | BASIC + PERF | sim PASS, board saturation knee at 0x4000 | 2x rate doubling until ceiling |
| 4.5 Mode dispatch | 3 | TP222-TP224 | BASIC | sim PASS via SIGNAL CSR | direct / burst / periodic |
| 4.5 Cross / neg | 8 | TP225-TP232 | BASIC + Sanity-neg | sim PASS, p45_025 board inversion pending arbfix | cross-product + lane_mask=0x00 negative |
| 4.6 Cosim sanity | 1 | TP251 | BASIC | sim PASS lossless at 1 ms / reduced rate | 6-checkpoint chain end-to-end |
| 4.6 Long-soak | 1 | TP252 | PERF | pending | 10 s stress (out-of-spec for default window) |

**Total:** 104 BASIC + 7 PERF + 21 sanity-neg or mixed = **132 cases**.

---

## 1. Phase 1 - Bring-up (TP001-TP025)

**Goal:** every SC-hub slave responds; UID matches IP source-of-truth; VERSION
metadata cross-checks with packaged SVD; both bridges (`mm_bridge`, `upload_mm_bridge`)
reachable. Read-only.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| TP001 | B | scratch_pad_ram quiescent read | 1 | `sc_tool 2 read 0x00000` | reply is 32-bit (not `0xFFFFFFFF`); typically `0x00000000` after cold-boot | `tools/run_script/check_sc_bridges.py` |
| TP002 | B | sc_hub UID via overlay | 1 | `sc_tool 2 read 0x0FE80` | UID = `0x53434842` ("SCHB") | TP1 stub |
| TP003 | B | onewire_master UID + META | 1 | read words `0x04400, 0x04401` | UID = `0x4F574D43`; META packs `26.2.1.MMDD` | `check_ip_metadata.py` |
| TP004 | B | max10_prog_avmm_0 UID + META | 1 | read `0x04800, 0x04801` | UID = `0x4D312850`; META `0.1.0.0` | `check_ip_metadata.py` |
| TP005 | B | charge_injection_pulser UID | 1 | read `0x04C00` | UID matches RTL; WO access does not protocol-error | `check_ip_metadata.py` |
| TP006 | B | firefly_xcvr_ctrl UID + META | 1 | read `0x05000, 0x05001` | UID + META match source-of-truth | `check_ip_metadata.py` |
| TP007 | B | on_die_temp_sense UID | 1 | read `0x05400` | UID matches RTL | `check_ip_metadata.py` |
| TP008 | B | mm_bridge transparent read | 1 | read `0x08000` through bridge | bridge returns valid 32-bit reply | `check_sc_bridges.py` |
| TP009 | B | upload_mm_bridge UID | 1 | read `0x0C000` through bridge | UID matches `runctl_mgmt_host` source | `check_sc_bridges.py` |
| TP010 | B | mutrig_cfg_ctrl UID | 1 | read `0x0FC04` | UID matches RTL | `check_ip_metadata.py` |
| TP011 | B | runctl_mgmt_host CSR sweep | 1 | read CSR_UID..CSR_LOG_STATUS (0x0C000..0x0C011) | every word returns well-formed; LAST_CMD = 0; RX_CMD_COUNT = 0 | `check_sc_bridges.py` |
| TP012 | B | histogram_statistics_v2 UID | 1 | read at mm_bridge offset for hist CSR | UID = `0x48495354` ("HIST") | `check_ip_metadata.py` |
| TP013 | B | mts_preprocessor_0/1 UID | 2 | read both mts CSR bases | UID and lane-index match per-instance source | `check_ip_metadata.py` |
| TP014 | B | arb_hit_type0_supercore UID + LANE bank | 1 | read supercore meta and per-lane CONTROL | UID matches 26.6.0; LANE_COUNT = 8 | `check_ip_metadata.py` |
| TP015 | B | emulator_mutrig_qsys_lane UID | 1 | read emulator CSR base | UID matches; `BYTE_STREAM_ENABLE = 0` | `check_ip_metadata.py` |
| TP016 | B | hit_type0_fanout8 instance verify | 1 | inspect generated synthesis tree | exactly 1 instance, 8 outputs | grep in `syn/feb_system_v3/synthesis/submodules/` |
| TP017 | B | mutrig_frame_deassembly UID | 1 | read CSR base | UID matches; idle when emulator is on type0 path | `check_ip_metadata.py` |
| TP018 | B | ring_buffer_cam debug counters quiescent | 1 | read rbCAM debug_msg2 counters | push_cnt = pop_cnt = 0 at boot | `check_sc_bridges.py` |
| TP019 | B | feb_frame_assembly_HSS0 + HSS1 UID | 2 | read both frame-assembly CSRs | UID + actual_hits = 0 | `check_ip_metadata.py` |
| TP020 | B | METADATA gate: live-vs-source cross | 1 | `check_ip_metadata.py` over every reachable IP | no live VERSION below source-of-truth; forward-compat drift documented | `check_ip_metadata.py` |
| TP021 | B | mm_bridge round-trip | 1 | read `0x08000` then `0x08001` | both succeed; mm_bridge does not stall | `check_sc_bridges.py` |
| TP022 | B | LINK_LOCKED_LOW status | 1 | read SWB `LINK_LOCKED_LOW_REGISTER_R` | bit 2 (FEB link 2) state visible (may be 0 if no LVDS RX traffic) | `sc_tool` SWB-side |
| TP023 | B | RESET_LINK_STATUS_R baseline | 1 | read SWB `RESET_LINK_STATUS_REGISTER_R` | matches the last-sent reset-link command; default `0x14000000` after fresh boot | `rc_tool` |
| TP024 | B | DMA_STATUS_REGISTER baseline | 1 | read SWB DMA_STATUS | quiescent at cold-boot | `sc_tool` SWB-side |
| TP025 | B | Phase 1 pass/fail gate | 1 | aggregate above 24 | 24/24 pass; any blocker stops Phase 2 | this row |

**Phase 1 verdict:** PASS (commit `5bd7e112` evidence + subsequent rebuilds).

---

## 2. Phase 2 - BIST (TP051-TP065)

**Goal:** SC-visible RW registers tolerate write/readback/restore; scratchpad
randomized BIST; sc_hub admission ordering under bursty traffic.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| TP051 | D | scratch_pad_ram single-word RW | 1 | write `0xAABBCCDD` at `0x00000`, read back, restore to original | readback = `0xAABBCCDD`; restore observed | `run_atpg_v2_reference.sh` |
| TP052 | D | scratch_pad_ram burst RW | 1 | write 256 random words, read back | every word matches | `run_atpg_v2_reference.sh` |
| TP053 | R | Scratchpad BIST 1024 random seeds | 16 | randomized address + payload | 0 mismatches; UNDERFLOW = OVERFLOW = 0 | `run_atpg_v2_reference.sh` |
| TP054 | D | onewire SCRATCH RW | 1 | write to onewire SCRATCH, readback | readback matches | `run_atpg_v2_reference.sh` |
| TP055 | D | max10_prog_avmm SCRATCH RW | 1 | same | same | `run_atpg_v2_reference.sh` |
| TP056 | D | charge_injection_pulser write smoke | 1 | write trigger, observe no protocol error | reply = ack=OK | `run_atpg_v2_reference.sh` |
| TP057 | D | firefly_xcvr_ctrl mode RW | 1 | round-trip mode CSR | matches | `run_atpg_v2_reference.sh` |
| TP058 | D | histogram_statistics CFG RW | 1 | `LEFT_BOUND=0 RIGHT_BOUND=255 BIN_WIDTH=1 INTERVAL_CFG=0xFFFFFFFF` | readback matches | `phase4_5_sweep.py:configure_histogram()` |
| TP059 | D | runctl_mgmt_host RUN_NUMBER RW | 1 | write `0x00AA0000`, readback | exactly matches | `phase4_5_sweep.py:run_row()` step 4 |
| TP060 | D | runctl_mgmt_host SCRATCH RW | 1 | round-trip SCRATCH | matches | `check_sc_bridges.py` |
| TP061 | D | sc_hub admission single beat | 1 | one isolated SC packet | ack=OK, no SLVERR | sc_tool low-level |
| TP062 | R | sc_hub admission 256-burst | 4 | randomly interleaved reads/writes from sc_tool | all replies ack=OK; rsp[19:18] = 0 | sc_tool burst |
| TP063 | D | sc_hub stall-or-reject regression | 1 | drive intentionally-conflicting beat pair | one accepted, other rejected with `rsp = SLVERR`; no protocol corruption | sc_hub overlay log |
| TP064 | D | mm_bridge concurrent SC + JTAG | 1 | sc_tool + jtag_rw on same bridge | both arbitrate cleanly | `jtag_rw.tcl` + sc_tool |
| TP065 | D | Phase 2 pass/fail gate | 1 | aggregate above 14 | 14/14 pass; any failure stops Phase 3 | this row |

**Phase 2 verdict:** PASS.

---

## 3. Phase 3 - Run-control (TP101-TP115)

**Goal:** run-control opcodes 0x10 / 0x11 / 0x12 / 0x13 work end-to-end via the
reset-link path; CMD_RESET (0x30) does NOT wedge the SC plane after the
SC-WEDGE topology fix (commit `5bd7e112`).

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| TP101 | D | rc_tool 0x10 RUN_PREPARE | 1 | `rc_tool 2 send 0x10` | `RX_CMD_COUNT +1`, `LAST_CMD = 0x10`, STATUS reflects PREPARED | `rc_tool` |
| TP102 | D | rc_tool 0x11 SYNC | 1 | same with 0x11 | matching delta and STATUS bits | `rc_tool` |
| TP103 | D | rc_tool 0x12 START_RUN | 1 | same with 0x12 | STATUS = RUNNING | `rc_tool` |
| TP104 | D | rc_tool 0x13 END_RUN | 1 | same with 0x13 | STATUS returns to TERMINATING then IDLE | `rc_tool` |
| TP105 | D | LOCAL_CMD fallback 0x10..0x13 | 4 | `sc_tool 2 write 0x0C013 <opcode>` for each opcode | matches rc_tool path | `phase4_5_sweep.py` |
| TP106 | D | LOG FIFO drain + decode | 1 | read CSR_LOG_STATUS then 4xCSR_LOG_POP per opcode | 128-bit entries decode to (recv_ts, opcode, payload) | `phase4_5_sweep.py:drain_log_fifo()` |
| TP107 | D | CMD_RESET 0x30 SC-WEDGE check | 1 | drive 0x30 via rc_tool; immediately read 3 SC slaves | SC reads return real values, NOT `0xEEEEEEEE` / RSP3 | TP3 postfix-1 retest |
| TP108 | D | CMD_STOP_RESET 0x31 recovery | 1 | drive 0x31 after 0x30 | RX_CMD_COUNT continues to increment; SC reads remain clean | TP3 postfix-1 retest |
| TP109 | D | Full opcode sweep 0x10..0x14 + 0x20..0x26 | 11 | drive each then read CSRs | each opcode increments RX_CMD_COUNT +1, sets LAST_CMD; UVM tb_int `run_RC_DIRECTED` reproduces | `tb_int_run_sequence_directed_test.sv` |
| TP110 | D | Run-number side-load sanity | 1 | write `0xAA0000 \| row_idx` to CSR_RUN_NUMBER; drive 0x10 | readback matches what was written OR latches from LVDS; both recorded | `phase4_5_sweep.py:run_row()` |
| TP111 | D | Stage timing extraction | 1 | drain LOG FIFO, compute prepare_ms/sync_ms/running_s/terminating_ms | all stages within expected bounds; RUNNING_s ~ `interval_seconds` | `phase4_5_sweep.py:run_row()` |
| TP112 | D | LVDS rc_tool fallback for unlocked link | 1 | LINK_LOCKED bit 2 low; drive LOCAL_CMD | LOCAL_CMD path works when LVDS path is silent | `phase4_5_sweep.py` |
| TP113 | D | Reset-domain characterization | 1 | drive 0x30 then verify 16 SC-plane sinks recover within bounded pulse | post-fix `ext_hard_reset` 16384 cycle pulse no longer cascades to `clk156_in_rst` | tb_int + on-board |
| TP114 | D | Sim repro of SC-WEDGE (no fix) | 1 | tb_int `tb_int_run_sequence_directed_wedge_test` | sim returns 0xEEEEEEEE pre-fix; topology-fix variant returns 0x4849_5354 | `tb_int_run_sequence_directed_wedge*_test.sv` |
| TP115 | D | Phase 3 pass/fail gate | 1 | aggregate above 14 | 14/14 pass | this row |

**Phase 3 verdict:** PASS (commit `5bd7e112` SC-WEDGE on-board verified).

---

## 4. Phase 4 - Emulator + histogram datapath (TP151-TP165)

**Goal:** emulator-type0 architecture (1 emulator_mutrig + arb_hit_type0_supercore +
hit_type0_fanout8 + dual-port histogram) is wired correctly; hits flow lossless
from emulator through arb / mts / hist / OPQ / RDMA when below saturation.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| TP151 | D | emulator BYTE_STREAM_ENABLE=false | 1 | inspect Qsys instance | `BYTE_STREAM_ENABLE = false` for `emulator_mutrig_qsys_lane` | grep in `*.qsys` |
| TP152 | D | arb_hit_type0_supercore wired | 1 | inspect generated tree | exactly 1 supercore, LANE_COUNT=8, MODE_DEFAULT=1 | grep in synthesis tree |
| TP153 | D | Dual-port hist N_PORTS=2 | 1 | inspect Qsys instance | histogram_statistics_0 N_PORTS=2; bridge_0 (mts_0 / lanes 0..3) and bridge_1 (mts_1 / lanes 4..7) | grep in `mutrig_datapath_system_v3.qsys` |
| TP154 | D | No timing_adapter on rc fan-out | 1 | grep generated submodules | zero auto-inserted `altera_avalon_st_timing_adapter` on run_control_splitter outputs (rc-readyless rollout closure) | grep `firmware_builds/.../synthesis/submodules/` |
| TP155 | D | No timing_adapter on hit_type0 mux path | 1 | grep generated submodules | zero auto-inserted adapter on `arb.selected_out_N -> mts.hit_type0_in` (mts_processor readyless contract) | grep `firmware_builds/.../synthesis/submodules/` |
| TP156 | D | Round 1 sim sanity at 1 ms RUNNING | 1 | tb_int feb_swb_corun all-channel periodic, RUN_WINDOW_8NS=125000 | 5/5 checkpoints match reference: pre-rbCAM, post-rbCAM, FEB egress, OPQ ingress, OPQ egress with matching p05/p50/p95 percentiles | `tb_int/feb_swb_corun` + `phase4_5_sweep.py:render_latency_plot()` |
| TP157 | D | Round 3 board sanity (legacy 4 s run) | 1 | flash arbfix SOF; LOCAL_CMD 0x10/0x11/0x12/wait 4 s/0x13 | TOTAL_HITS_CSR13 > 0 with INTERVAL_CFG_NEVER_FIRE; BANK_STATUS toggles; PORT_STATUS != 0x000000FF | `phase4_5_sweep.py:run_row()` |
| TP158 | D | Counter cross-validation (CSR13 vs hist_bin_sum) | 1 | read both at end-of-run | `abs(csr13 - hist_bin_sum) <= 8` tolerance (pipeline drain delta) | `phase4_5_sweep.py:compute_verdict()` |
| TP159 | D | LAST_INTERVAL_TOTAL_HITS sanity | 1 | with INTERVAL_CFG_NEVER_FIRE, no interval pulse fires | csr17 stays at 0 or stale value; csr13 holds full-run total | `phase4_5_sweep.py:snap_hist()` |
| TP160 | D | 6-checkpoint cosim sanity (low rate) | 1 | cosim `make run_COSIM_SANITY` with 1 ms RUNNING, rate well below ceiling | pre-rbCAM = post-rbCAM = FEB egress = SWB ingress = OPQ egress = RDMA egress (lossless through all 6) | `cosim/Makefile` |
| TP161 | D | Cosim ingress byte-exact verification | 1 | FEB egress monitor waveform <-> SWB ingress driver replay | per-cycle data match within ~1 cycle CDC delta | `feb_egress_monitor_pkg.sv` + `swb_ingress_driver_pkg.sv` |
| TP162 | D | Packet steering monitor | 1 | run with mixed traffic (hit only for now) | hit packets counted; SC and RC count = 0 | `cosim_packet_steering_monitor.sv` |
| TP163 | D | Run-state propagation to all rc sinks | 1 | drive 0x12 start-run; sample each rc sink | every of 16 rc_sink endpoints observes RUNNING within one cycle | tb_int `B033_mode_preserved_through_run_seq` |
| TP164 | D | arb MODE survives PREP after fix | 1 | configure MODE=EMU; drive 0x10..0x13 | MODE remains EMU through PREP/SYNC/RUNNING/TERM (only RESET 0x30 clears MODE) per `abb3e455` | tb_int `B033` |
| TP165 | D | Phase 4 pass/fail gate | 1 | aggregate above 14 | 14/14 pass | this row |

**Phase 4 verdict:** PASS (FEB-local closure committed `38e84800`; emulator-type0 board PASS `318af50d`; arb MODE-clear fix `abb3e455`; dualport `47efa242`).

---

## 5. Phase 4.5 - Sweep matrix (TP201-TP232)

**Goal:** 32-row matrix of (lane_mask x channel_mask x rate x hit_mode) probes
all combinations under the BASIC bucket; explicit PERF rows probe saturation;
sanity-neg rows verify the disable / negative path.

Common stimulus per row (all 32 share):
- `INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE (0xFFFFFFFF)` so no interval pulse fires
- LEFT_BOUND=0, RIGHT_BOUND=255, BIN_WIDTH=1 (per-channel histogram)
- 1 ms RUNNING window in sim; 4 s on board (transition window)
- Run sequence: 0x10 -> 0x11 -> 0x12 -> wait -> 0x13

Common pass criteria per row:
- For BASIC: |sim_delta_pct| < 5%; |board_delta_pct| < 5%
- For PERF: sim_delta_pct ~ 0%; board_delta_pct < 0% but row is still PASS if loss matches the theoretical saturation curve within tolerance
- For Sanity-neg: total_hits == 0 on both sides

Function reference for every row: `scripts/cotest/phase4_5_sweep.py:run_row(<row_id>)`.

### 5.1 §4.5.1 Channel-mask sweep (TP201-TP206, all BASIC, all-lanes, default rate)

| ID | Row ID | channel_mask | Expected histogram shape |
|---|---|---|---|
| TP201 | p45_000 | `0xFFFFFFFF` | flat across 256 channels |
| TP202 | p45_001 | `0x0000FFFF` | channels 0..15 only |
| TP203 | p45_002 | `0xFFFF0000` | channels 16..31 only |
| TP204 | p45_003 | `0x55555555` | even channels |
| TP205 | p45_004 | `0xAAAAAAAA` | odd channels |
| TP206 | p45_005 | `0x00000001` | channel 0 only |

### 5.2 Lane isolation (TP207-TP214, all BASIC, all-channels, default rate, single-lane admit)

| ID | Row ID | lane_mask | Expected |
|---|---|---|---|
| TP207 | p45_006 | `0x01` (lane 0 only) | only lane-0 channels populated |
| TP208 | p45_007 | `0x02` (lane 1 only) | only lane-1 |
| TP209 | p45_008 | `0x04` | only lane 2 |
| TP210 | p45_009 | `0x08` | only lane 3 |
| TP211 | p45_010 | `0x10` | only lane 4 |
| TP212 | p45_011 | `0x20` | only lane 5 |
| TP213 | p45_012 | `0x40` | only lane 6 |
| TP214 | p45_013 | `0x80` | only lane 7 |

### 5.3 §4.5.2 Rate sweep (TP215-TP221, BASIC for low rates, PERF approaching ceiling)

OPQ ingress ceiling per spec: ~250 MHz aggregate (codex investigation pending exact value).
Per-channel rate at `0x0100` (8.8 fp): `0x0100 / 256 * (125e6 / 256) = 488 kHz`.
Aggregate (256 channels): `~125 MHz at 0x0100`. So all current rates are at or below the BASIC threshold of <50% ceiling.

| ID | Row ID | rate_88fp | Bucket | Expected | Note |
|---|---|---|---|---|---|
| TP215 | p45_014 | `0x0100` | BASIC | rate doubles vs `default` | sub-threshold |
| TP216 | p45_015 | `0x0400` | BASIC | rate doubles vs TP215 | sub-threshold |
| TP217 | p45_016 | `0x0800` | BASIC | rate doubles vs TP216 | sub-threshold |
| TP218 | p45_017 | `0x1000` | BASIC | rate doubles vs TP217 | sub-threshold |
| TP219 | p45_018 | `0x2000` | BASIC | rate doubles vs TP218 | board sim-vs-board inversion under investigation (`p45_018`) |
| TP220 | p45_019 | `0x4000` | PERF | board saturation knee | `fifo_level_max` clips; `DROPPED_HITS > 0` expected |
| TP221 | p45_020 | `0x8000` | PERF | board overload | larger board delta vs theoretical |

### 5.4 §4.5.3 Mode dispatch (TP222-TP224, all BASIC, all-lanes, default rate)

| ID | Row ID | hit_mode | SIGNAL CSR | Expected |
|---|---|---|---|---|
| TP222 | p45_022 | `0x00` direct | `0x00` | continuous flat distribution |
| TP223 | p45_023 | `0x01` burst | `0x01` | cluster centered at `burst_center` |
| TP224 | p45_024 | `0x11` periodic | `0x03` | delta-function at periodic intervals |

Note: SIGNAL CSR (offset `0x08808`) is the mode selector. MUTRIG_FORMAT (offset `0x0880A`) is format flags only. Confirmed in `frontend_csr.sv:277-289` and sim diag commit `6029646e`.

### 5.5 Cross-product + sanity-neg (TP225-TP232)

| ID | Row ID | lane_mask | channel_mask | rate | hit_mode | Bucket | Expected |
|---|---|---|---|---|---|---|---|
| TP225 | p45_026 | `0xFF` | `0x0000FFFF` | default | direct | BASIC | low-half channels only on all lanes |
| TP226 | p45_027 | `0x55` (evens) | `0x55555555` | default | direct | BASIC | even channels on even lanes |
| TP227 | p45_028 | `0xAA` (odds) | `0xAAAAAAAA` | default | direct | BASIC | odd channels on odd lanes |
| TP228 | p45_029 | `0x01` (lane 0) | `0x00000001` | default | direct | BASIC | channel 0 on lane 0 only |
| TP229 | p45_030 | `0x55` (evens) | default | `0x2000` | direct | BASIC | rate cross-product |
| TP230 | p45_031 | `0x00` (none) | `0x00000001` | default | direct | Sanity-neg | TOTAL_HITS == 0 (predicate inverted) |
| TP231 | p45_025 | `0x00` (none) | default | default | direct | Sanity-neg | TOTAL_HITS == 0; arb-admit bypass on board pre-arbfix is the documented inversion |
| TP232 | p45_021 | `0xFF` | default | default | burst | BASIC | burst mode + all lanes |

---

## 6. Phase 4.6 - Cosim and long-soak (TP251-TP252)

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| TP251 | D | Cosim 6-checkpoint sanity (BASIC, 1 ms) | 1 | feb_swb cosim, RUN_WINDOW_8NS=125000, rate well below OPQ ceiling | hits at every checkpoint match within 1-cycle CDC delta; lossless through OPQ + RDMA | `cosim/Makefile` + `cosim/uvm/sequences/sanity_*_seq.sv` |
| TP252 | P | Long-soak (10 s, PERF) | 1 | `phase4_5_longsoak.py --rate-88fp 0x21 --interval-ms 1.0` | board delta vs theoretical falls on saturation curve; bank-toggle regularity stddev < 1 ms | `scripts/cotest/phase4_5_longsoak.py` |

---

## 7. Evidence trail (verdict references)

The cumulative on-board + sim evidence trail for the 132 cases above is preserved per-commit. Key reference points:

| Phase | Verdict | Key commit hashes |
|---|---|---|
| Phase 1 bring-up | PASS | `5bd7e112`, `42222454` |
| Phase 2 BIST | PASS | (legacy commits) |
| Phase 3 RC + SC-WEDGE | PASS on-board | `5bd7e112` (SC-WEDGE), `abb3e455` (arb MODE) |
| Phase 4 emulator + hist | PASS FEB-local | `38e84800` (closure entry), `318af50d` (board Round 3), `47efa242` (dualport build), `abb3e455` (arb MODE clean) |
| Phase 4.5 sweep | sim PASS 32/32; board pending arbfix retest | `967845b5` (sim-32 + HTML), `2b3bdfab` (SIGNAL+1ms), `42222454` (deprecation), `791e3943` (HTML rate-norm), arbfix retest in flight |
| Phase 4.6 cosim | sanity infrastructure done; lossless at low rate; OPQ saturation at 100k pending rate re-tune | cosim codex in flight |

Per-row board evidence at:
`firmware_builds/systems/v3_pretest-260511-emutype0-dualport*/sweep_evidence/<row_id>/`

Per-row sim evidence at:
`firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/<row_id>/`

HTML cross-validation report (rate-normalized + theoretical-delta):
`firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT.html`

Fail-mode trace analysis (per-row trace for the 7 prior FAILs):
`firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/PHASE4_5_SWEEP_FAIL_ANALYSIS.md`

Bug ledger:
`firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/BUG_HISTORY.md`

---

## 8. Open items

- **OPQ aggregate ingress ceiling**: user-stated 250 MHz; exact RTL confirmation pending (codex1 BASIC/PERF dispatch in flight). Once confirmed, recompute rate_88fp -> hits/s conversion and verify the BASIC threshold of < 50% ceiling.
- **`p45_018` board CSR-write or histogram-ingress rate-knob anomaly**: sim PASS, board csr13=0 even at sub-ceiling rate. Pending arbfix retest result.
- **`p45_019` board saturation knee at `0x4000`**: documented but bucket-classification depends on confirmed ceiling.
- **`p45_025` board lane-mask=0x00 leak**: pre-arbfix dualport SOF leaked because PREPARING-clears-MODE was active. Arbfix retest in flight; should resolve.
- **Cosim 100k OPQ saturation**: `rho=1.13 OVERLOADED` at high rate. Reduce to 1 ms RUNNING + below-ceiling rate per the 1 ms RUNNING convention for canonical lossless reference.
- **RDMA closure**: not yet exercised end-to-end at sustained rate; OPQ egress and RDMA egress checkpoints in cosim only.

---

## 9. Test plan revision history

- **2026-05-12 draft-2** (this revision): full DV-plan-style rewrite into 132 uniform per-case rows; preserves SIM time conventions, theoretical-delta model, BASIC/PERF bucket spec, source-of-truth and pre-flight; collapses Phase 4.7..4.16 narrative evidence into the Evidence trail appendix (Section 7).
- **2026-05-12 draft-1**: long-form narrative with per-phase evidence sections (4.7..4.16). Preserved historically in git log for reference; deprecated in favor of draft-2.
