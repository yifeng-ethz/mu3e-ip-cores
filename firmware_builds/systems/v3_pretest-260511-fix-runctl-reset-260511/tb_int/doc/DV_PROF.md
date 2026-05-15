# DV_PROF.md - tb_int PROF bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** P001-P192
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- **D** directed - single deterministic stimulus with a golden expectation.
- **R** constrained-random - UVM sequence randomises the named axis and the scoreboard checks count parity.

This file is the PROF bucket. It records sustained throughput, soak, and peak-rate cases for later implementation after BASIC, EDGE, and ERROR closure.

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| RC | 32 | P001-P032 | long RUNNING windows and repeated RUN_NUMBER changes remain stable | 0/32 |
| SC | 32 | P033-P064 | sustained SC traffic at max bridge rate does not age or alias | 0/32 |
| DT | 128 | P065-P192 | sustained MuTRiG plus legacy FEB upload profiles meet latency and loss targets | 0/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P001 | D | RUNNING for 100000 cycles | 1 | drive RUNNING and hold for 100000 cycles | run_window_db stable_start and stable_end remain consistent | TBD |
| P002 | D | RUN_NUMBER bumped 32 times during one outer run | 1 | drive 32 IDLE to RUN_PREP cycles | RUN_NUMBER monotonically increments and CSR view is consistent | TBD |
| P003 | D | Watchdog enabled during sustained RUNNING | 1 | drive sustained traffic above arb_hit_type0 watchdog threshold | watchdog fires correctly and no lane hangs | TBD |
| P004 | R | Randomised long-run RC stress seed 1 | 1 | RC sequence runs long RUNNING windows for seed 1 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P005 | R | Randomised long-run RC stress seed 2 | 1 | RC sequence runs long RUNNING windows for seed 2 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P006 | R | Randomised long-run RC stress seed 3 | 1 | RC sequence runs long RUNNING windows for seed 3 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P007 | R | Randomised long-run RC stress seed 4 | 1 | RC sequence runs long RUNNING windows for seed 4 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P008 | R | Randomised long-run RC stress seed 5 | 1 | RC sequence runs long RUNNING windows for seed 5 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P009 | R | Randomised long-run RC stress seed 6 | 1 | RC sequence runs long RUNNING windows for seed 6 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P010 | R | Randomised long-run RC stress seed 7 | 1 | RC sequence runs long RUNNING windows for seed 7 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P011 | R | Randomised long-run RC stress seed 8 | 1 | RC sequence runs long RUNNING windows for seed 8 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P012 | R | Randomised long-run RC stress seed 9 | 1 | RC sequence runs long RUNNING windows for seed 9 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P013 | R | Randomised long-run RC stress seed 10 | 1 | RC sequence runs long RUNNING windows for seed 10 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P014 | R | Randomised long-run RC stress seed 11 | 1 | RC sequence runs long RUNNING windows for seed 11 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P015 | R | Randomised long-run RC stress seed 12 | 1 | RC sequence runs long RUNNING windows for seed 12 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P016 | R | Randomised long-run RC stress seed 13 | 1 | RC sequence runs long RUNNING windows for seed 13 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P017 | R | Randomised long-run RC stress seed 14 | 1 | RC sequence runs long RUNNING windows for seed 14 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P018 | R | Randomised long-run RC stress seed 15 | 1 | RC sequence runs long RUNNING windows for seed 15 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P019 | R | Randomised long-run RC stress seed 16 | 1 | RC sequence runs long RUNNING windows for seed 16 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P020 | R | Randomised long-run RC stress seed 17 | 1 | RC sequence runs long RUNNING windows for seed 17 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P021 | R | Randomised long-run RC stress seed 18 | 1 | RC sequence runs long RUNNING windows for seed 18 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P022 | R | Randomised long-run RC stress seed 19 | 1 | RC sequence runs long RUNNING windows for seed 19 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P023 | R | Randomised long-run RC stress seed 20 | 1 | RC sequence runs long RUNNING windows for seed 20 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P024 | R | Randomised long-run RC stress seed 21 | 1 | RC sequence runs long RUNNING windows for seed 21 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P025 | R | Randomised long-run RC stress seed 22 | 1 | RC sequence runs long RUNNING windows for seed 22 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P026 | R | Randomised long-run RC stress seed 23 | 1 | RC sequence runs long RUNNING windows for seed 23 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P027 | R | Randomised long-run RC stress seed 24 | 1 | RC sequence runs long RUNNING windows for seed 24 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P028 | R | Randomised long-run RC stress seed 25 | 1 | RC sequence runs long RUNNING windows for seed 25 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P029 | R | Randomised long-run RC stress seed 26 | 1 | RC sequence runs long RUNNING windows for seed 26 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P030 | R | Randomised long-run RC stress seed 27 | 1 | RC sequence runs long RUNNING windows for seed 27 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P031 | R | Randomised long-run RC stress seed 28 | 1 | RC sequence runs long RUNNING windows for seed 28 | state ledger remains stable and aggregate hold coverage increases | TBD |
| P032 | R | Randomised long-run RC stress seed 29 | 1 | RC sequence runs long RUNNING windows for seed 29 | state ledger remains stable and aggregate hold coverage increases | TBD |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P033 | D | Sustained SC reads at max bridge rate, single slave | 1 | back-to-back reads of scratch_pad_ram for 10000 cycles | no protocol violation and bridge backpressure is correct | TBD |
| P034 | D | Sustained SC writes at max bridge rate, single slave | 1 | back-to-back writes for 10000 cycles | writes complete and readback verifies | TBD |
| P035 | D | Interleaved SC and RC traffic for 100000 cycles | 1 | drive SC traffic and RC transitions concurrently | control planes remain independent with no aliasing | TBD |
| P036 | R | Randomised SC soak seed 1 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 1 | sustained throughput holds and no aging effect is observed | TBD |
| P037 | R | Randomised SC soak seed 2 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 2 | sustained throughput holds and no aging effect is observed | TBD |
| P038 | R | Randomised SC soak seed 3 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 3 | sustained throughput holds and no aging effect is observed | TBD |
| P039 | R | Randomised SC soak seed 4 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 4 | sustained throughput holds and no aging effect is observed | TBD |
| P040 | R | Randomised SC soak seed 5 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 5 | sustained throughput holds and no aging effect is observed | TBD |
| P041 | R | Randomised SC soak seed 6 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 6 | sustained throughput holds and no aging effect is observed | TBD |
| P042 | R | Randomised SC soak seed 7 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 7 | sustained throughput holds and no aging effect is observed | TBD |
| P043 | R | Randomised SC soak seed 8 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 8 | sustained throughput holds and no aging effect is observed | TBD |
| P044 | R | Randomised SC soak seed 9 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 9 | sustained throughput holds and no aging effect is observed | TBD |
| P045 | R | Randomised SC soak seed 10 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 10 | sustained throughput holds and no aging effect is observed | TBD |
| P046 | R | Randomised SC soak seed 11 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 11 | sustained throughput holds and no aging effect is observed | TBD |
| P047 | R | Randomised SC soak seed 12 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 12 | sustained throughput holds and no aging effect is observed | TBD |
| P048 | R | Randomised SC soak seed 13 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 13 | sustained throughput holds and no aging effect is observed | TBD |
| P049 | R | Randomised SC soak seed 14 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 14 | sustained throughput holds and no aging effect is observed | TBD |
| P050 | R | Randomised SC soak seed 15 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 15 | sustained throughput holds and no aging effect is observed | TBD |
| P051 | R | Randomised SC soak seed 16 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 16 | sustained throughput holds and no aging effect is observed | TBD |
| P052 | R | Randomised SC soak seed 17 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 17 | sustained throughput holds and no aging effect is observed | TBD |
| P053 | R | Randomised SC soak seed 18 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 18 | sustained throughput holds and no aging effect is observed | TBD |
| P054 | R | Randomised SC soak seed 19 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 19 | sustained throughput holds and no aging effect is observed | TBD |
| P055 | R | Randomised SC soak seed 20 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 20 | sustained throughput holds and no aging effect is observed | TBD |
| P056 | R | Randomised SC soak seed 21 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 21 | sustained throughput holds and no aging effect is observed | TBD |
| P057 | R | Randomised SC soak seed 22 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 22 | sustained throughput holds and no aging effect is observed | TBD |
| P058 | R | Randomised SC soak seed 23 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 23 | sustained throughput holds and no aging effect is observed | TBD |
| P059 | R | Randomised SC soak seed 24 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 24 | sustained throughput holds and no aging effect is observed | TBD |
| P060 | R | Randomised SC soak seed 25 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 25 | sustained throughput holds and no aging effect is observed | TBD |
| P061 | R | Randomised SC soak seed 26 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 26 | sustained throughput holds and no aging effect is observed | TBD |
| P062 | R | Randomised SC soak seed 27 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 27 | sustained throughput holds and no aging effect is observed | TBD |
| P063 | R | Randomised SC soak seed 28 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 28 | sustained throughput holds and no aging effect is observed | TBD |
| P064 | R | Randomised SC soak seed 29 | 1 | SC soak sequence randomises slave, access type, and cadence for seed 29 | sustained throughput holds and no aging effect is observed | TBD |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P065 | D | PROF-INT-002 one-lane virtual MuTRiG at 100 kHz per channel | 1 | mutrig_phy_agent drives 100 kHz per channel for 5 s outer and 1 s stable | stable_closed at least 95 percent and latency CDFs stay within budget | TBD |
| P066 | D | PROF-INT-002 eight-lane virtual MuTRiG at 100 kHz per channel | 1 | eight active lanes run the 5 s profile | same gates plus per-lane reconciliation parity | TBD |
| P067 | D | PROF-INT-002 emulator full8lane at 100 kHz per channel | 1 | emulator source drives 32 channels x 8 lanes for 5 s | same gates on emulator source | TBD |
| P068 | D | Sustained 1 MHz per channel x 32 channels x 8 lanes for 1 s stable | 1 | virtual MuTRiG drives peak-rate stable window | scoreboard residuals stay below threshold and upload_pkt_mux egress keeps up | TBD |
| P069 | D | upload_pkt_mux sustained egress turnaround under load | 1 | continuous FEB upload packet push for 1 s stable | every packet exits within budget and timeout count stays zero | TBD |
| P070 | D | Cross-source MIX_RR at one hit per 3.5 cycles ceiling | 1 | mix REAL and EMU sources in arb_hit_type0 MIX_RR mode | per-source reconciliation closes without deadlock | TBD |
| P071 | D | Long-soak with mid-run RUN_NUMBER bumps | 1 | drive 10 s window with RUN_NUMBER bumped every 1 s | each segment stable window reconciles independently | TBD |
| P072 | R | Randomised sustained Poisson profile seed 1 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 1 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P073 | R | Randomised sustained Poisson profile seed 2 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 2 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P074 | R | Randomised sustained Poisson profile seed 3 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 3 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P075 | R | Randomised sustained Poisson profile seed 4 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 4 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P076 | R | Randomised sustained Poisson profile seed 5 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 5 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P077 | R | Randomised sustained Poisson profile seed 6 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 6 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P078 | R | Randomised sustained Poisson profile seed 7 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 7 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P079 | R | Randomised sustained Poisson profile seed 8 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 8 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P080 | R | Randomised sustained Poisson profile seed 9 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 9 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P081 | R | Randomised sustained Poisson profile seed 10 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 10 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P082 | R | Randomised sustained Poisson profile seed 11 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 11 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P083 | R | Randomised sustained Poisson profile seed 12 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 12 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P084 | R | Randomised sustained Poisson profile seed 13 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 13 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P085 | R | Randomised sustained Poisson profile seed 14 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 14 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P086 | R | Randomised sustained Poisson profile seed 15 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 15 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P087 | R | Randomised sustained Poisson profile seed 16 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 16 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P088 | R | Randomised sustained Poisson profile seed 17 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 17 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P089 | R | Randomised sustained Poisson profile seed 18 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 18 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P090 | R | Randomised sustained Poisson profile seed 19 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 19 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P091 | R | Randomised sustained Poisson profile seed 20 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 20 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P092 | R | Randomised sustained Poisson profile seed 21 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 21 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P093 | R | Randomised sustained Poisson profile seed 22 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 22 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P094 | R | Randomised sustained Poisson profile seed 23 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 23 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P095 | R | Randomised sustained Poisson profile seed 24 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 24 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P096 | R | Randomised sustained Poisson profile seed 25 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 25 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P097 | R | Randomised sustained Poisson profile seed 26 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 26 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P098 | R | Randomised sustained Poisson profile seed 27 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 27 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P099 | R | Randomised sustained Poisson profile seed 28 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 28 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P100 | R | Randomised sustained Poisson profile seed 29 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 29 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P101 | R | Randomised sustained Poisson profile seed 30 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 30 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P102 | R | Randomised sustained Poisson profile seed 31 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 31 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P103 | R | Randomised sustained Poisson profile seed 32 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 32 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P104 | R | Randomised sustained Poisson profile seed 33 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 33 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P105 | R | Randomised sustained Poisson profile seed 34 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 34 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P106 | R | Randomised sustained Poisson profile seed 35 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 35 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P107 | R | Randomised sustained Poisson profile seed 36 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 36 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P108 | R | Randomised sustained Poisson profile seed 37 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 37 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P109 | R | Randomised sustained Poisson profile seed 38 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 38 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P110 | R | Randomised sustained Poisson profile seed 39 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 39 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P111 | R | Randomised sustained Poisson profile seed 40 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 40 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P112 | R | Randomised sustained Poisson profile seed 41 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 41 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P113 | R | Randomised sustained Poisson profile seed 42 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 42 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P114 | R | Randomised sustained Poisson profile seed 43 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 43 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P115 | R | Randomised sustained Poisson profile seed 44 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 44 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P116 | R | Randomised sustained Poisson profile seed 45 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 45 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P117 | R | Randomised sustained Poisson profile seed 46 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 46 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P118 | R | Randomised sustained Poisson profile seed 47 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 47 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P119 | R | Randomised sustained Poisson profile seed 48 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 48 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P120 | R | Randomised sustained Poisson profile seed 49 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 49 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P121 | R | Randomised sustained Poisson profile seed 50 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 50 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P122 | R | Randomised sustained Poisson profile seed 51 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 51 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P123 | R | Randomised sustained Poisson profile seed 52 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 52 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P124 | R | Randomised sustained Poisson profile seed 53 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 53 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P125 | R | Randomised sustained Poisson profile seed 54 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 54 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P126 | R | Randomised sustained Poisson profile seed 55 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 55 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P127 | R | Randomised sustained Poisson profile seed 56 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 56 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P128 | R | Randomised sustained Poisson profile seed 57 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 57 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P129 | R | Randomised sustained Poisson profile seed 58 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 58 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P130 | R | Randomised sustained Poisson profile seed 59 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 59 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P131 | R | Randomised sustained Poisson profile seed 60 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 60 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P132 | R | Randomised sustained Poisson profile seed 61 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 61 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P133 | R | Randomised sustained Poisson profile seed 62 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 62 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P134 | R | Randomised sustained Poisson profile seed 63 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 63 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P135 | R | Randomised sustained Poisson profile seed 64 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 64 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P136 | R | Randomised sustained Poisson profile seed 65 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 65 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P137 | R | Randomised sustained Poisson profile seed 66 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 66 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P138 | R | Randomised sustained Poisson profile seed 67 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 67 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P139 | R | Randomised sustained Poisson profile seed 68 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 68 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P140 | R | Randomised sustained Poisson profile seed 69 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 69 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P141 | R | Randomised sustained Poisson profile seed 70 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 70 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P142 | R | Randomised sustained Poisson profile seed 71 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 71 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P143 | R | Randomised sustained Poisson profile seed 72 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 72 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P144 | R | Randomised sustained Poisson profile seed 73 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 73 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P145 | R | Randomised sustained Poisson profile seed 74 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 74 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P146 | R | Randomised sustained Poisson profile seed 75 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 75 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P147 | R | Randomised sustained Poisson profile seed 76 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 76 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P148 | R | Randomised sustained Poisson profile seed 77 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 77 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P149 | R | Randomised sustained Poisson profile seed 78 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 78 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P150 | R | Randomised sustained Poisson profile seed 79 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 79 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P151 | R | Randomised sustained Poisson profile seed 80 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 80 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P152 | R | Randomised sustained Poisson profile seed 81 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 81 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P153 | R | Randomised sustained Poisson profile seed 82 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 82 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P154 | R | Randomised sustained Poisson profile seed 83 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 83 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P155 | R | Randomised sustained Poisson profile seed 84 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 84 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P156 | R | Randomised sustained Poisson profile seed 85 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 85 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P157 | R | Randomised sustained Poisson profile seed 86 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 86 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P158 | R | Randomised sustained Poisson profile seed 87 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 87 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P159 | R | Randomised sustained Poisson profile seed 88 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 88 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P160 | R | Randomised sustained Poisson profile seed 89 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 89 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P161 | R | Randomised sustained Poisson profile seed 90 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 90 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P162 | R | Randomised sustained Poisson profile seed 91 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 91 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P163 | R | Randomised sustained Poisson profile seed 92 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 92 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P164 | R | Randomised sustained Poisson profile seed 93 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 93 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P165 | R | Randomised sustained Poisson profile seed 94 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 94 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P166 | R | Randomised sustained Poisson profile seed 95 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 95 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P167 | R | Randomised sustained Poisson profile seed 96 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 96 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P168 | R | Randomised sustained Poisson profile seed 97 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 97 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P169 | R | Randomised sustained Poisson profile seed 98 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 98 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P170 | R | Randomised sustained Poisson profile seed 99 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 99 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P171 | R | Randomised sustained Poisson profile seed 100 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 100 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P172 | R | Randomised sustained Poisson profile seed 101 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 101 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P173 | R | Randomised sustained Poisson profile seed 102 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 102 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P174 | R | Randomised sustained Poisson profile seed 103 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 103 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P175 | R | Randomised sustained Poisson profile seed 104 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 104 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P176 | R | Randomised sustained Poisson profile seed 105 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 105 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P177 | R | Randomised sustained Poisson profile seed 106 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 106 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P178 | R | Randomised sustained Poisson profile seed 107 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 107 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P179 | R | Randomised sustained Poisson profile seed 108 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 108 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P180 | R | Randomised sustained Poisson profile seed 109 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 109 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P181 | R | Randomised sustained Poisson profile seed 110 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 110 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P182 | R | Randomised sustained Poisson profile seed 111 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 111 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P183 | R | Randomised sustained Poisson profile seed 112 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 112 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P184 | R | Randomised sustained Poisson profile seed 113 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 113 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P185 | R | Randomised sustained Poisson profile seed 114 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 114 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P186 | R | Randomised sustained Poisson profile seed 115 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 115 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P187 | R | Randomised sustained Poisson profile seed 116 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 116 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P188 | R | Randomised sustained Poisson profile seed 117 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 117 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P189 | R | Randomised sustained Poisson profile seed 118 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 118 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P190 | R | Randomised sustained Poisson profile seed 119 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 119 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P191 | R | Randomised sustained Poisson profile seed 120 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 120 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
| P192 | R | Randomised sustained Poisson profile seed 121 | 1 | 5 s outer-window sequence randomises rate, channel mask, and lane mask for seed 121 | per-stage CDFs and histogram checkpoints remain inside DV_COV.md thresholds | TBD |
