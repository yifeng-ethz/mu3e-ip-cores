# DV_BASIC.md — tb_int BASIC bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** B001..B192 (32 RC + 32 SC + 128 DT)
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- `D` directed — single, deterministic stimulus + golden expectation.
- `R` constrained-random — UVM sequence with randomised generators, asserted by scoreboard count parity per (lane, key).

This file is the BASIC bucket. Happy-path verification of the v3_pretest-260511 feb_system_v3 with rdma_subsystem-aware upload path. Every case in this bucket is a prerequisite for DV_EDGE / DV_ERROR / DV_PROF. The bucket maps directly to TEST_PLAN.md Phase 1 (per-slave register audit), Phase 3 happy-path (run-control deterministic transitions), and Phase 4 (emulator + histogram datapath smoke).

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| 2. RC (run-control) | 32 | B001..B032 | runctl_mgmt_host readyless broadcast reaches every consumer IP, all five state transitions covered | 0/32 |
| 3. SC (slow-control) | 32 | B033..B064 | sc_hub_v2 + mm_bridge can read identity headers (UID/META) and round-trip a single word at every CSR slave | 0/32 |
| 4. DT (datapath) | 128 | B065..B192 | virtual or emulator MuTRiG hits make it from source to rdma_subsystem SQE ingress with sidecar lineage preserved | 0/128 |

## 2. RC (run-control)

Maps to TEST_PLAN.md Phase 3 happy-path sequences. Run-control is `readyless` in this build; no consumer may backpressure a transition.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B001 | D | IDLE -> RUN_PREP transition broadcast reaches all consumers | 1 | runctl_phy_agent drives RUN_PREP after 1ms idle | every consumer's run_ctrl observed RUN_PREP within 1 cycle of broadcast; readyless contract honored | TBD |
| B002 | D | RUN_PREP -> SYNC transition | 1 | drive SYNC | every consumer transitions; no backpressure | TBD |
| B003 | D | SYNC -> RUNNING transition | 1 | drive RUNNING | every consumer transitions | TBD |
| B004 | D | RUNNING -> TERMINATING transition | 1 | drive TERMINATING | every consumer transitions | TBD |
| B005 | D | TERMINATING -> IDLE transition | 1 | drive IDLE | every consumer back to IDLE | TBD |
| B006 | D | Full happy path IDLE -> ... -> IDLE | 1 | drive five transitions with 1ms gap (TB_INT_RUNCTL_CPP_GAP_CYCLES) | run_window_db records all five states; stable_window opens 1s after RUNNING | TBD |
| B007 | D | RUN_NUMBER increment across cycle | 1 | increment RUN_NUMBER between IDLE and RUN_PREP | runctl_mgmt_host CSR reads back new RUN_NUMBER | TBD |
| B008 | R | Randomised state-pair traversal | 16 | UVM sequence draws random legal state pair per case | all reachable pairs observed; sequencer covers every transition at least once across the 16 iters | TBD |
| B009..B032 | R | Additional randomised RC sequences | 24 | UVM sequence | covers each state for at least 1ms, validates run_window_db markers | TBD |

## 3. SC (slow-control)

Maps to TEST_PLAN.md Phase 1 register audit. Each CSR slave is exercised once per its identity header + one RW field.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B033 | D | UID read of scratch_pad_ram | 1 | SC bridge reads word 0x00000 | UID matches the IP's RTL constant | TBD |
| B034 | D | UID read of onewire_master_controller_0 | 1 | SC bridge reads word 0x04400 | UID matches | TBD |
| B035 | D | UID read of max10_prog_avmm_0 | 1 | SC bridge reads word 0x04800 | UID matches | TBD |
| B036 | D | UID read of charge_injection_pulser_0 | 1 | SC bridge reads word 0x04C00 | UID matches; WO slave so subsequent write must complete without error | TBD |
| B037 | D | UID read of firefly_xcvr_ctrl_0 | 1 | SC bridge reads word 0x05000 | UID matches | TBD |
| B038 | D | UID read of on_die_temp_sense_ctrl | 1 | SC bridge reads word 0x05400 | UID matches | TBD |
| B039 | D | UID read of mm_bridge to data_path | 1 | SC bridge reads word 0x08000 | UID matches; cross-bridge access works | TBD |
| B040 | D | UID read of mutrig_cfg_ctrl_0.avmm_csr | 1 | SC bridge reads word 0xFC04 | UID matches | TBD |
| B041 | D | UID read of runctl_mgmt_host | 1 | SC bridge reads via upload_avmm aperture | UID matches; visible from BOTH local JTAG AND SWB sc_hub | TBD |
| B042 | D | UID read of rdma_subsystem control aperture | 1 | SC bridge reads via the rdma_subsystem CSR base | UID matches | TBD |
| B043 | D | Single-word RW round-trip on scratch_pad_ram | 1 | write 0xAABBCCDD then read | read returns the written value | TBD |
| B044..B064 | R | Randomised single-word RW round-trips | 21 | UVM seq picks a random RW slave + RW field per case | every RW field round-trips at least once across 21 iters; no aliasing | TBD |

## 4. DT (datapath)

Maps to TEST_PLAN.md Phase 4 emulator+histogram smoke + new rdma_subsystem SQE ingress check.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| B065 | D | 16-hit virtual MuTRiG smoke, lane 0, phase 100 | 1 | mutrig_phy_agent emits 16 hits at 100 kHz/channel, channel 0..1, RUNNING window 100us, stable 50us | scoreboard reconciles 16 at every stage; sidecar present at all 4 taps; rdma CQE returns 16 | TBD |
| B066 | D | 16-hit emulator_mutrig direct smoke, lane 0 | 1 | emulator_mutrig_force_agent injects 16 deterministic pulses at 100 kHz | same as B065 with EMU source | TBD |
| B067 | D | Sidecar lineage validation, lane 0 | 1 | inject 100 hits with known hit_id 0..99 | sidecar at L2 / pre-rbCAM / post-rbCAM / FEB-egress all carry the same hit_id; 0 missing | TBD |
| B068 | D | Histogram cross-check at pre-rbCAM, lane 0 | 1 | drive 1024 hits at 1 MHz, stable window | histogram_statistics_v2 bin counts match scoreboard's reconstructed delay distribution within DV_COV.md threshold | TBD |
| B069 | D | rdma_subsystem CQE round-trip for 1 SQE | 1 | drive 1 hit to FEB-egress, capture rdma SQE; SWB-side CQE writeback | CQE returned within rdma_subsystem turnaround budget; sidecar in CQE matches SQE | TBD |
| B070..B080 | D | Rate distribution sweep per lane (10k, 100k, 500k, 1M Hz/channel) | 11 | virtual MuTRiG at each rate, single channel, single lane | scoreboard 0 drops in stable window; histogram delta-shape matches expected per rate | TBD |
| B081..B112 | R | Randomised multiplicity x rate x channel-mask, single lane | 32 | UVM seq per case | reconcile count parity per (lane, key) within DV_COV.md threshold | TBD |
| B113..B144 | R | Spatial pattern sweep (random / clustered / hot-spot / uniform) | 32 | UVM seq per case, lane 0..7 | reconcile across all lanes; sidecar visible at every level-2 IP | TBD |
| B145..B176 | R | Source mix REAL / EMU / MIX_RR | 32 | UVM seq selects mode per case | arb_hit_type0 mode coverage; watchdog enable x mode cross | TBD |
| B177..B192 | D | Run-state-gated DT (hits before SYNC dropped; hits after TERMINATING propagate endofrun) | 16 | scripted state changes + hit injection | hits before SYNC do NOT appear at FEB-egress; hits after TERMINATING complete the in-flight rdma SQE | TBD |

## 5. Bring-up order within BASIC

1. B001..B007 — RC happy path (one direction at a time)
2. B033..B042 — SC identity scans (read-only)
3. B065 — virtual MuTRiG single-hit smoke
4. B066 — emulator_mutrig direct smoke
5. B067 — sidecar lineage validation
6. B068 — histogram cross-check
7. B069 — rdma CQE round-trip
8. B043..B064 — SC RW round-trips
9. B070..B080 — rate sweep
10. B081..B192 — randomised cases + state-gated cases

## 6. Coverage targets for closure

- All 32 RC state-pair transitions hit at least once.
- All 32 SC slaves identity-scanned at least once + at least one RW field round-trip per slave.
- 128 DT cases: per-(lane, key) reconciliation closes within DV_COV.md threshold; sidecar lineage 100% in stable window; histogram cross-check delta below threshold.
- Code coverage (BASIC alone): line >= 70%, branch >= 65%, toggle >= 60% across the v3_pretest-260511 hierarchy. Full closure gates are in DV_COV.md.

## 7. Status

All cases pending implementation. The harness is dispatched to codex1 (per DV_INT_PLAN.md §7). Implementation order follows §5 above.
