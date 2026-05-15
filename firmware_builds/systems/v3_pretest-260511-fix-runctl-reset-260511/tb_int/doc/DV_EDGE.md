# DV_EDGE.md - tb_int EDGE bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** E001-E192
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- **D** directed - single deterministic stimulus with a golden expectation.
- **R** constrained-random - UVM sequence randomises the named axis and the scoreboard checks count parity.

This file is the EDGE bucket. It records boundary-condition cases for later implementation after BASIC harness closure.

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| RC | 32 | E001-E032 | zero-gap transitions, shortcut transitions, and reset boundaries do not desynchronise consumers | 0/32 |
| SC | 32 | E033-E064 | SC burst boundaries and last-address accesses do not overrun or alias slaves | 0/32 |
| DT | 128 | E065-E192 | frame-edge hits, max clusters, and FIFO/watchdog boundaries preserve reconciliation | 0/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E001 | D | Back-to-back IDLE to RUN_PREP to SYNC to RUNNING with zero gap | 1 | runctl_phy_agent drives four transitions in adjacent cycles | every consumer transitions through all four states in order | TBD |
| E002 | D | State change on the same cycle as a CSR write | 1 | drive RUNNING while SC writes one CSR word | both operations observed with no scoreboard order inversion | TBD |
| E003 | D | TERMINATING to RUN_PREP shortcut | 1 | drive shortcut without intervening IDLE | runctl_mgmt_host accepts shortcut and RUN_NUMBER does not increment | TBD |
| E004 | D | RUN_PREP to RESET shortcut | 1 | drive RESET from RUN_PREP | every consumer returns to IDLE | TBD |
| E005 | D | SYNC to RESET shortcut | 1 | drive RESET from SYNC | every consumer returns to IDLE | TBD |
| E006 | R | Randomised zero-gap transition and reset boundary seed 1 | 1 | RC sequence randomises zero-gap transition pattern for seed 1 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E007 | R | Randomised zero-gap transition and reset boundary seed 2 | 1 | RC sequence randomises zero-gap transition pattern for seed 2 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E008 | R | Randomised zero-gap transition and reset boundary seed 3 | 1 | RC sequence randomises zero-gap transition pattern for seed 3 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E009 | R | Randomised zero-gap transition and reset boundary seed 4 | 1 | RC sequence randomises zero-gap transition pattern for seed 4 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E010 | R | Randomised zero-gap transition and reset boundary seed 5 | 1 | RC sequence randomises zero-gap transition pattern for seed 5 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E011 | R | Randomised zero-gap transition and reset boundary seed 6 | 1 | RC sequence randomises zero-gap transition pattern for seed 6 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E012 | R | Randomised zero-gap transition and reset boundary seed 7 | 1 | RC sequence randomises zero-gap transition pattern for seed 7 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E013 | R | Randomised zero-gap transition and reset boundary seed 8 | 1 | RC sequence randomises zero-gap transition pattern for seed 8 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E014 | R | Randomised zero-gap transition and reset boundary seed 9 | 1 | RC sequence randomises zero-gap transition pattern for seed 9 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E015 | R | Randomised zero-gap transition and reset boundary seed 10 | 1 | RC sequence randomises zero-gap transition pattern for seed 10 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E016 | R | Randomised zero-gap transition and reset boundary seed 11 | 1 | RC sequence randomises zero-gap transition pattern for seed 11 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E017 | R | Randomised zero-gap transition and reset boundary seed 12 | 1 | RC sequence randomises zero-gap transition pattern for seed 12 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E018 | R | Randomised zero-gap transition and reset boundary seed 13 | 1 | RC sequence randomises zero-gap transition pattern for seed 13 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E019 | R | Randomised zero-gap transition and reset boundary seed 14 | 1 | RC sequence randomises zero-gap transition pattern for seed 14 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E020 | R | Randomised zero-gap transition and reset boundary seed 15 | 1 | RC sequence randomises zero-gap transition pattern for seed 15 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E021 | R | Randomised zero-gap transition and reset boundary seed 16 | 1 | RC sequence randomises zero-gap transition pattern for seed 16 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E022 | R | Randomised zero-gap transition and reset boundary seed 17 | 1 | RC sequence randomises zero-gap transition pattern for seed 17 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E023 | R | Randomised zero-gap transition and reset boundary seed 18 | 1 | RC sequence randomises zero-gap transition pattern for seed 18 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E024 | R | Randomised zero-gap transition and reset boundary seed 19 | 1 | RC sequence randomises zero-gap transition pattern for seed 19 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E025 | R | Randomised zero-gap transition and reset boundary seed 20 | 1 | RC sequence randomises zero-gap transition pattern for seed 20 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E026 | R | Randomised zero-gap transition and reset boundary seed 21 | 1 | RC sequence randomises zero-gap transition pattern for seed 21 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E027 | R | Randomised zero-gap transition and reset boundary seed 22 | 1 | RC sequence randomises zero-gap transition pattern for seed 22 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E028 | R | Randomised zero-gap transition and reset boundary seed 23 | 1 | RC sequence randomises zero-gap transition pattern for seed 23 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E029 | R | Randomised zero-gap transition and reset boundary seed 24 | 1 | RC sequence randomises zero-gap transition pattern for seed 24 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E030 | R | Randomised zero-gap transition and reset boundary seed 25 | 1 | RC sequence randomises zero-gap transition pattern for seed 25 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E031 | R | Randomised zero-gap transition and reset boundary seed 26 | 1 | RC sequence randomises zero-gap transition pattern for seed 26 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |
| E032 | R | Randomised zero-gap transition and reset boundary seed 27 | 1 | RC sequence randomises zero-gap transition pattern for seed 27 | every reachable state-pair-with-zero-gap is legal and run_window_db is consistent | TBD |

Dedicated RC debug-fallback ID, outside the canonical numeric signoff bucket:

| ID | Method | Scenario | Stimulus | Pass Criteria |
|---|---|---|---|---|
| E-RC-CSR-001 | D | Firefly and CSR drive a transition in the same millisecond | runctl_seq_firefly and runctl_seq_csr overlap one state write | runctl_mgmt_host_0 broadcasts one coherent one-hot value per cycle with no shadow drift |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E033 | D | Single-word burst at every CSR slave | 1 | SC bridge issues burst-len 1 to scratch_pad_ram | burst succeeds | TBD |
| E034 | D | Two-word burst at scratch_pad_ram | 1 | SC bridge issues burst-len 2 | both words verify | TBD |
| E035 | D | Aperture-size burst at scratch_pad_ram | 1 | SC bridge issues a 4 KB aperture burst | burst completes with no overrun | TBD |
| E036 | D | Aperture-size-minus-one burst | 1 | SC bridge issues 1023-word burst | burst completes with no overrun | TBD |
| E037 | D | Exactly half-aperture burst in low half | 1 | SC bridge bursts over the low half aperture | burst completes and data verifies | TBD |
| E038 | D | Exactly half-aperture burst in high half | 1 | SC bridge bursts over the high half aperture | burst completes and data verifies | TBD |
| E039 | D | Write at last legal address of every RW slave | 8 | SC bridge writes at each max RW offset | every legal final word round-trips | TBD |
| E040 | D | Read at last legal address of every slave | 8 | SC bridge reads each max RO offset | read returns expected value or documented default | TBD |
| E041 | D | Cross-slave back-to-back access without gap | 1 | write scratch_pad_ram then read firefly_xcvr_ctrl_0 in adjacent cycles | both accesses complete and mm_bridge arbitration is correct | TBD |
| E042 | R | Randomised burst-length and cross-slave seed 1 | 1 | SC sequence randomises burst length and slave pair for seed 1 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E043 | R | Randomised burst-length and cross-slave seed 2 | 1 | SC sequence randomises burst length and slave pair for seed 2 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E044 | R | Randomised burst-length and cross-slave seed 3 | 1 | SC sequence randomises burst length and slave pair for seed 3 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E045 | R | Randomised burst-length and cross-slave seed 4 | 1 | SC sequence randomises burst length and slave pair for seed 4 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E046 | R | Randomised burst-length and cross-slave seed 5 | 1 | SC sequence randomises burst length and slave pair for seed 5 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E047 | R | Randomised burst-length and cross-slave seed 6 | 1 | SC sequence randomises burst length and slave pair for seed 6 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E048 | R | Randomised burst-length and cross-slave seed 7 | 1 | SC sequence randomises burst length and slave pair for seed 7 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E049 | R | Randomised burst-length and cross-slave seed 8 | 1 | SC sequence randomises burst length and slave pair for seed 8 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E050 | R | Randomised burst-length and cross-slave seed 9 | 1 | SC sequence randomises burst length and slave pair for seed 9 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E051 | R | Randomised burst-length and cross-slave seed 10 | 1 | SC sequence randomises burst length and slave pair for seed 10 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E052 | R | Randomised burst-length and cross-slave seed 11 | 1 | SC sequence randomises burst length and slave pair for seed 11 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E053 | R | Randomised burst-length and cross-slave seed 12 | 1 | SC sequence randomises burst length and slave pair for seed 12 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E054 | R | Randomised burst-length and cross-slave seed 13 | 1 | SC sequence randomises burst length and slave pair for seed 13 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E055 | R | Randomised burst-length and cross-slave seed 14 | 1 | SC sequence randomises burst length and slave pair for seed 14 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E056 | R | Randomised burst-length and cross-slave seed 15 | 1 | SC sequence randomises burst length and slave pair for seed 15 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E057 | R | Randomised burst-length and cross-slave seed 16 | 1 | SC sequence randomises burst length and slave pair for seed 16 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E058 | R | Randomised burst-length and cross-slave seed 17 | 1 | SC sequence randomises burst length and slave pair for seed 17 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E059 | R | Randomised burst-length and cross-slave seed 18 | 1 | SC sequence randomises burst length and slave pair for seed 18 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E060 | R | Randomised burst-length and cross-slave seed 19 | 1 | SC sequence randomises burst length and slave pair for seed 19 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E061 | R | Randomised burst-length and cross-slave seed 20 | 1 | SC sequence randomises burst length and slave pair for seed 20 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E062 | R | Randomised burst-length and cross-slave seed 21 | 1 | SC sequence randomises burst length and slave pair for seed 21 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E063 | R | Randomised burst-length and cross-slave seed 22 | 1 | SC sequence randomises burst length and slave pair for seed 22 | aperture boundaries are hit and no protocol violation occurs | TBD |
| E064 | R | Randomised burst-length and cross-slave seed 23 | 1 | SC sequence randomises burst length and slave pair for seed 23 | aperture boundaries are hit and no protocol violation occurs | TBD |

Dedicated SC debug-fallback ID, outside the canonical numeric signoff bucket:

| ID | Method | Scenario | Stimulus | Pass Criteria |
|---|---|---|---|---|
| E-SC-CONC-001 | D | Concurrent firefly and JTAG SC traffic arbitration | sc_seq_firefly and sc_seq_jtag issue overlapping reads | both observers complete and the arbitration log shows non-starving interleaving |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E065 | D | Hit aligned to frame start | 1 | inject one hit with T_coarse modulo 256 equal to 0 | hit propagates with correct frame tag at FEB-egress | TBD |
| E066 | D | Hit aligned to frame end | 1 | inject one hit with T_coarse modulo 256 equal to 255 | hit is assigned to the correct edge bucket | TBD |
| E067 | D | Hit straddling frame boundary | 1 | inject hit whose fine timestamp straddles a frame boundary | scoreboard handles the frame decision by count parity | TBD |
| E068 | D | Cluster-size 32 in one frame on one lane | 1 | inject 32 hits at same T_coarse across 32 channels | post-rbCAM emits 32 hit_type2 records and FEB-egress loses none | TBD |
| E069 | D | Cluster across all 8 lanes | 1 | inject eight same-T_coarse hits on different lanes | scoreboard reconciles each lane and FEB-egress packs cross-lane data | TBD |
| E070 | D | Back-to-back single-channel saturation | 1 | drive 256 hits at consecutive T_coarse on one channel | rbCAM fills and drains without missing a stable-window hit | TBD |
| E071 | D | FIFO-full induced drop at watchdog edge | 1 | drive hits at rbCAM capacity boundary | scoreboard reports residual drop and watchdog/error counter increments | TBD |
| E072 | D | Run-state edge at exact SYNC to RUNNING cycle | 1 | drive hit on the transition cycle | run_origin tagging follows run_window_db and strict reconciliation excludes correctly | TBD |
| E073 | R | Randomised datapath boundary axis seed 1 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 1 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E074 | R | Randomised datapath boundary axis seed 2 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 2 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E075 | R | Randomised datapath boundary axis seed 3 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 3 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E076 | R | Randomised datapath boundary axis seed 4 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 4 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E077 | R | Randomised datapath boundary axis seed 5 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 5 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E078 | R | Randomised datapath boundary axis seed 6 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 6 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E079 | R | Randomised datapath boundary axis seed 7 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 7 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E080 | R | Randomised datapath boundary axis seed 8 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 8 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E081 | R | Randomised datapath boundary axis seed 9 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 9 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E082 | R | Randomised datapath boundary axis seed 10 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 10 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E083 | R | Randomised datapath boundary axis seed 11 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 11 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E084 | R | Randomised datapath boundary axis seed 12 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 12 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E085 | R | Randomised datapath boundary axis seed 13 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 13 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E086 | R | Randomised datapath boundary axis seed 14 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 14 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E087 | R | Randomised datapath boundary axis seed 15 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 15 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E088 | R | Randomised datapath boundary axis seed 16 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 16 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E089 | R | Randomised datapath boundary axis seed 17 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 17 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E090 | R | Randomised datapath boundary axis seed 18 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 18 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E091 | R | Randomised datapath boundary axis seed 19 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 19 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E092 | R | Randomised datapath boundary axis seed 20 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 20 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E093 | R | Randomised datapath boundary axis seed 21 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 21 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E094 | R | Randomised datapath boundary axis seed 22 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 22 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E095 | R | Randomised datapath boundary axis seed 23 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 23 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E096 | R | Randomised datapath boundary axis seed 24 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 24 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E097 | R | Randomised datapath boundary axis seed 25 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 25 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E098 | R | Randomised datapath boundary axis seed 26 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 26 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E099 | R | Randomised datapath boundary axis seed 27 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 27 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E100 | R | Randomised datapath boundary axis seed 28 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 28 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E101 | R | Randomised datapath boundary axis seed 29 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 29 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E102 | R | Randomised datapath boundary axis seed 30 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 30 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E103 | R | Randomised datapath boundary axis seed 31 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 31 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E104 | R | Randomised datapath boundary axis seed 32 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 32 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E105 | R | Randomised datapath boundary axis seed 33 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 33 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E106 | R | Randomised datapath boundary axis seed 34 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 34 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E107 | R | Randomised datapath boundary axis seed 35 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 35 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E108 | R | Randomised datapath boundary axis seed 36 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 36 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E109 | R | Randomised datapath boundary axis seed 37 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 37 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E110 | R | Randomised datapath boundary axis seed 38 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 38 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E111 | R | Randomised datapath boundary axis seed 39 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 39 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E112 | R | Randomised datapath boundary axis seed 40 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 40 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E113 | R | Randomised datapath boundary axis seed 41 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 41 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E114 | R | Randomised datapath boundary axis seed 42 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 42 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E115 | R | Randomised datapath boundary axis seed 43 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 43 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E116 | R | Randomised datapath boundary axis seed 44 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 44 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E117 | R | Randomised datapath boundary axis seed 45 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 45 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E118 | R | Randomised datapath boundary axis seed 46 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 46 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E119 | R | Randomised datapath boundary axis seed 47 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 47 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E120 | R | Randomised datapath boundary axis seed 48 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 48 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E121 | R | Randomised datapath boundary axis seed 49 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 49 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E122 | R | Randomised datapath boundary axis seed 50 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 50 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E123 | R | Randomised datapath boundary axis seed 51 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 51 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E124 | R | Randomised datapath boundary axis seed 52 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 52 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E125 | R | Randomised datapath boundary axis seed 53 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 53 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E126 | R | Randomised datapath boundary axis seed 54 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 54 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E127 | R | Randomised datapath boundary axis seed 55 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 55 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E128 | R | Randomised datapath boundary axis seed 56 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 56 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E129 | R | Randomised datapath boundary axis seed 57 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 57 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E130 | R | Randomised datapath boundary axis seed 58 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 58 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E131 | R | Randomised datapath boundary axis seed 59 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 59 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E132 | R | Randomised datapath boundary axis seed 60 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 60 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E133 | R | Randomised datapath boundary axis seed 61 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 61 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E134 | R | Randomised datapath boundary axis seed 62 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 62 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E135 | R | Randomised datapath boundary axis seed 63 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 63 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E136 | R | Randomised datapath boundary axis seed 64 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 64 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E137 | R | Randomised datapath boundary axis seed 65 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 65 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E138 | R | Randomised datapath boundary axis seed 66 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 66 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E139 | R | Randomised datapath boundary axis seed 67 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 67 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E140 | R | Randomised datapath boundary axis seed 68 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 68 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E141 | R | Randomised datapath boundary axis seed 69 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 69 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E142 | R | Randomised datapath boundary axis seed 70 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 70 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E143 | R | Randomised datapath boundary axis seed 71 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 71 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E144 | R | Randomised datapath boundary axis seed 72 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 72 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E145 | R | Randomised datapath boundary axis seed 73 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 73 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E146 | R | Randomised datapath boundary axis seed 74 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 74 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E147 | R | Randomised datapath boundary axis seed 75 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 75 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E148 | R | Randomised datapath boundary axis seed 76 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 76 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E149 | R | Randomised datapath boundary axis seed 77 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 77 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E150 | R | Randomised datapath boundary axis seed 78 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 78 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E151 | R | Randomised datapath boundary axis seed 79 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 79 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E152 | R | Randomised datapath boundary axis seed 80 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 80 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E153 | R | Randomised datapath boundary axis seed 81 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 81 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E154 | R | Randomised datapath boundary axis seed 82 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 82 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E155 | R | Randomised datapath boundary axis seed 83 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 83 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E156 | R | Randomised datapath boundary axis seed 84 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 84 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E157 | R | Randomised datapath boundary axis seed 85 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 85 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E158 | R | Randomised datapath boundary axis seed 86 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 86 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E159 | R | Randomised datapath boundary axis seed 87 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 87 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E160 | R | Randomised datapath boundary axis seed 88 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 88 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E161 | R | Randomised datapath boundary axis seed 89 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 89 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E162 | R | Randomised datapath boundary axis seed 90 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 90 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E163 | R | Randomised datapath boundary axis seed 91 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 91 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E164 | R | Randomised datapath boundary axis seed 92 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 92 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E165 | R | Randomised datapath boundary axis seed 93 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 93 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E166 | R | Randomised datapath boundary axis seed 94 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 94 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E167 | R | Randomised datapath boundary axis seed 95 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 95 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E168 | R | Randomised datapath boundary axis seed 96 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 96 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E169 | R | Randomised datapath boundary axis seed 97 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 97 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E170 | R | Randomised datapath boundary axis seed 98 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 98 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E171 | R | Randomised datapath boundary axis seed 99 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 99 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E172 | R | Randomised datapath boundary axis seed 100 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 100 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E173 | R | Randomised datapath boundary axis seed 101 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 101 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E174 | R | Randomised datapath boundary axis seed 102 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 102 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E175 | R | Randomised datapath boundary axis seed 103 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 103 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E176 | R | Randomised datapath boundary axis seed 104 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 104 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E177 | R | Randomised datapath boundary axis seed 105 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 105 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E178 | R | Randomised datapath boundary axis seed 106 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 106 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E179 | R | Randomised datapath boundary axis seed 107 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 107 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E180 | R | Randomised datapath boundary axis seed 108 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 108 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E181 | R | Randomised datapath boundary axis seed 109 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 109 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E182 | R | Randomised datapath boundary axis seed 110 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 110 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E183 | R | Randomised datapath boundary axis seed 111 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 111 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E184 | R | Randomised datapath boundary axis seed 112 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 112 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E185 | R | Randomised datapath boundary axis seed 113 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 113 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E186 | R | Randomised datapath boundary axis seed 114 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 114 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E187 | R | Randomised datapath boundary axis seed 115 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 115 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E188 | R | Randomised datapath boundary axis seed 116 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 116 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E189 | R | Randomised datapath boundary axis seed 117 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 117 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E190 | R | Randomised datapath boundary axis seed 118 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 118 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E191 | R | Randomised datapath boundary axis seed 119 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 119 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
| E192 | R | Randomised datapath boundary axis seed 120 | 1 | randomise rate, multiplicity, spatial, and temporal boundary for seed 120 | edge case reconciles and sidecar lineage is preserved at boundary taps | TBD |
