# DV_EDGE.md — tb_int EDGE bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** E001..E192 (32 RC + 32 SC + 128 DT)
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- `D` directed.
- `R` constrained-random.

EDGE bucket targets boundary conditions per axis. BASIC closure is a prerequisite. Maps to TEST_PLAN.md Phase 1 boundary reads + Phase 2 BIST (write/readback/restore + ATPG sweep) + Phase 3 reset-domain characterization.

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| 2. RC | 32 | E001..E032 | back-to-back transitions with zero gap; transitions on the same cycle as a CSR write; reset boundaries | 0/32 |
| 3. SC | 32 | E033..E064 | burst length boundaries (1, 2, aperture-size, exactly-half); writes at the last legal address; cross-slave back-to-back without gap | 0/32 |
| 4. DT | 128 | E065..E192 | hits aligned to frame start / end / boundary; max-cluster all-in-one-frame; FIFO-full induced drops at watchdog edge | 0/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E001 | D | Back-to-back IDLE->RUN_PREP->SYNC->RUNNING with zero gap | 1 | runctl_phy_agent drives four transitions in 4 adjacent cycles | every consumer transitions through all four states in correct order; no skip | TBD |
| E002 | D | State change on the same cycle as a CSR write | 1 | drive RUNNING while SC writes a CSR | both observed; no order inversion at scoreboard | TBD |
| E003 | D | TERMINATING -> RUN_PREP (skip IDLE) shortcut | 1 | drive shortcut | runctl_mgmt_host accepts; RUN_NUMBER NOT incremented | TBD |
| E004 | D | RUN_PREP -> RESET shortcut | 1 | drive RESET from RUN_PREP | every consumer returns to IDLE | TBD |
| E005 | D | SYNC -> RESET shortcut | 1 | drive RESET from SYNC | same | TBD |
| E006..E032 | R | Randomised back-to-back transition patterns + reset boundaries | 27 | UVM seq | every reachable state-pair-with-zero-gap exercised; run_window_db consistent | TBD |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E033 | D | Single-word burst at every CSR slave (burst-len=1) | 1 | SC bridge issues 1-word burst to scratch_pad_ram | succeeds | TBD |
| E034 | D | 2-word burst at scratch_pad_ram | 1 | burst-len=2 | succeeds; both words verified | TBD |
| E035 | D | Aperture-size burst at scratch_pad_ram (4 KB) | 1 | full-aperture burst | succeeds; no overrun | TBD |
| E036 | D | Aperture-size-minus-1 burst | 1 | burst-len = 1023 | succeeds | TBD |
| E037 | D | Exactly-half-aperture burst (low half) | 1 | 0x000..0x07F | succeeds | TBD |
| E038 | D | Exactly-half-aperture burst (high half) | 1 | 0x080..0x0FF | succeeds | TBD |
| E039 | D | Write at last legal address of every RW slave | 8 | SC writes at slave's max RW offset | round-trips correctly at every slave | TBD |
| E040 | D | Read at last legal address of every slave | 8 | read at slave's max RO offset | returns expected | TBD |
| E041 | D | Cross-slave back-to-back without gap | 1 | write scratch_pad_ram then read firefly_xcvr_ctrl_0 in adjacent SC bridge cycles | both succeed; mm_bridge arbitration correct | TBD |
| E042..E064 | R | Randomised burst-length sweep + cross-slave patterns | 23 | UVM seq | all aperture boundaries hit; no protocol violation | TBD |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E065 | D | Hit aligned to frame start (T_coarse mod 256 = 0) | 1 | inject 1 hit at frame boundary | hit propagates with correct frame tag at FEB-egress | TBD |
| E066 | D | Hit aligned to frame end (T_coarse mod 256 = 255) | 1 | inject 1 hit at frame end | hit propagates; either last-of-frame or first-of-next-frame depending on rbCAM hold window | TBD |
| E067 | D | Hit straddling frame boundary | 1 | inject hit with T_fine causing frame straddle | scoreboard handles by FIFO-bucket count parity | TBD |
| E068 | D | Cluster-size 32 in one frame, single lane | 1 | inject 32 hits at the same T_coarse, 32 different channels | post-rbCAM produces 32 hit_type2; FEB-egress packs them; no drop | TBD |
| E069 | D | Cluster across all 8 lanes (8 ASICs, 1 channel each) | 1 | 8 hits same T_coarse, different lanes | scoreboard reconciles per-lane; FEB-egress packs cross-lane | TBD |
| E070 | D | Back-to-back single-channel saturation | 1 | drive 256 hits at consecutive T_coarse, same channel | rbCAM bucket fills then drains; no missing | TBD |
| E071 | D | FIFO-full induced drop at watchdog edge | 1 | drive hits at the rbCAM capacity boundary | drops detected by scoreboard count residual; watchdog fires; error counter increments | TBD |
| E072 | D | Run-state edge: hit at exact SYNC -> RUNNING cycle | 1 | drive hit on the cycle of state transition | hit's run_origin set per run_window_db is_stable_origin; strict reconciliation pass excludes correctly | TBD |
| E073..E192 | R | Randomised boundary cases per axis (rate / multiplicity / spatial / temporal) | 120 | UVM seq | edge cases reconciled; sidecar lineage preserved at boundaries | TBD |

## 5. Bring-up order

After BASIC closure: E001..E008 RC zero-gap, then E033..E041 SC bursts, then E065..E072 DT boundary, then randomised E009..E032, E042..E064, E073..E192.

## 6. Status

All cases pending implementation.
