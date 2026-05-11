# DV_PROF.md — tb_int PROF bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** P001..P192 (32 RC + 32 SC + 128 DT)
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- `D` directed.
- `R` constrained-random.

PROF bucket runs LAST. Sustained throughput / soak / peak. BASIC + EDGE + ERROR closure are prerequisites. Maps to TEST_PLAN.md Phase 4 sustained traffic + the rdma_subsystem PROF-INT-002 5s targets (matches the reference plan's `run_prof_int_002_full_pipeline_100khz_per_channel_5s`).

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| 2. RC | 32 | P001..P032 | long RUNNING durations (10^5 cycles), sustained RUN_NUMBER increments, watchdog overlap | 0/32 |
| 3. SC | 32 | P033..P064 | sustained back-to-back SC traffic at max bridge rate; soak | 0/32 |
| 4. DT | 128 | P065..P192 | sustained Poisson at 1 MHz x 32ch x 8lane for 1s stable window inside 5s outer window; rdma SQE production at line rate; CQE turnaround budget | 0/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P001 | D | RUNNING for 10^5 cycles | 1 | drive RUNNING; hold 100k cycles | run_window_db stable_start/end consistent; no spurious state change | TBD |
| P002 | D | RUN_NUMBER bumped 32 times during one outer run | 1 | drive 32 IDLE -> RUN_PREP cycles | RUN_NUMBER monotonically increments; runctl_mgmt_host CSR consistent | TBD |
| P003 | D | Watchdog enabled during sustained RUNNING | 1 | drive RUNNING with traffic that loads arb_hit_type0 above watchdog threshold | watchdog fires correctly; counters increment; no hung lane | TBD |
| P004..P032 | R | Randomised long-run RC stress | 29 | UVM seq with 10^5-cycle RUNNING windows | every state observed for at least 10^5 cycles aggregate | TBD |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P033 | D | Sustained SC reads at max bridge rate, single slave | 1 | back-to-back reads of scratch_pad_ram for 10^4 cycles | no protocol violation; mm_bridge backpressure correct | TBD |
| P034 | D | Sustained SC writes at max bridge rate, single slave | 1 | back-to-back writes | same | TBD |
| P035 | D | Interleaved SC + RC traffic for 10^5 cycles | 1 | drive SC and RC concurrently | both control planes independent; no aliasing | TBD |
| P036..P064 | R | Randomised soak SC patterns | 29 | UVM seq | sustained throughput holds; no aging effects | TBD |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P065 | D | PROF-INT-002 1-lane virtual MuTRiG, 100 kHz/channel, 5s outer, 1s stable | 1 | mutrig_phy_agent at 100 kHz per channel x 16 channels x 1 lane x 5s | stable_closed >= 95%; per-stage latency CDFs within budget; histogram cross-check passes | TBD |
| P066 | D | PROF-INT-002 8-lane virtual MuTRiG, 100 kHz/channel, 5s | 1 | 8 active lanes | same gates; per-lane reconciliation parity | TBD |
| P067 | D | PROF-INT-002 emulator full8lane, 100 kHz/channel, 5s | 1 | emulator_mutrig_force_agent at 100 kHz x 32 channels x 8 lanes | same gates | TBD |
| P068 | D | Sustained 1 MHz/channel x 32 channels x 8 lanes for 1s stable | 1 | mutrig_phy_agent at peak rate | scoreboard residuals < per-case threshold; rdma_subsystem keeps up at SQE rate; CQE turnaround < budget | TBD |
| P069 | D | rdma_subsystem CQE turnaround under sustained load | 1 | continuous SQE push for 1s stable | every CQE returned within budget; 0 timeouts | TBD |
| P070 | D | Cross-source MIX_RR at 1 hit / 3.5 cycles ceiling | 1 | mix REAL+EMU per arb_hit_type0 MIX_RR mode | scoreboard reconciles per-source; no deadlock | TBD |
| P071 | D | Long-soak with mid-run RUN_NUMBER bumps | 1 | drive 10s window with RUN_NUMBER bumped every 1s | each segment's stable_window reconciles independently | TBD |
| P072..P192 | R | Randomised sustained Poisson at various rates / channel-masks / lane-masks | 121 | UVM seq with 5s outer windows | per-stage CDFs Python-side; histogram cross-check at every checkpoint | TBD |

## 5. PROF-INT-002 5s targets (canonical)

Per TEST_PLAN.md and the Apr 27 reference plan's PROF-INT-002 envelopes:

- `TB_INT_RUN_CYCLES=625000000` (5 s @ 125 MHz)
- `TB_INT_DRAIN_CYCLES=16384`
- `TB_INT_STABLE_WINDOW_CYCLES=125000000` (1 s stable origin window)
- `TB_INT_STABLE_ONLY_EXPORT=1`
- `TB_INT_RUNCTL_CPP_GAP_CYCLES=125000` (1 ms software-scale command gap)

These match the Apr 27 reference's 5s targets. The combined sign-off run is
`make run_prof_int_002_full_pipeline_100khz_per_channel_5s` once the Makefile lands under codex1.

## 6. Bring-up order

After BASIC + EDGE + ERROR closure: P001 RC long-run, then P033 SC soak, then P065 -> P069 PROF-INT-002 baseline, then P068 + P070 peak, then randomised P072..P192.

## 7. Status

All cases pending implementation. PROF-INT-002 makefile targets are reused from the Apr 27 reference (`tb_int/Makefile`) and rebound to the v3_pretest-260511 DUT path.
