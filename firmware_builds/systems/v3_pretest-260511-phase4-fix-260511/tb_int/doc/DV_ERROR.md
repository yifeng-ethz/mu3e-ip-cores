# DV_ERROR.md - tb_int ERROR bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** X001-X192
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- **D** directed - single deterministic stimulus with a golden expectation.
- **R** constrained-random - UVM sequence randomises the named axis and the scoreboard checks count parity.

This file is the ERROR bucket. It records recovery-path and protocol-violation cases for later implementation after BASIC and EDGE closure.

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| RC | 32 | X001-X032 | mid-flight RESET and malformed run-control words cleanly recover | 0/32 |
| SC | 32 | X033-X064 | illegal SC accesses report errors or documented defaults without false success | 0/32 |
| DT | 128 | X065-X192 | bad frames, drops, collisions, and FEB upload stalls are detected and recovered | 0/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X001 | D | Mid-flight RESET during arb_hit_type0 merge-packet close | 1 | trigger RESET while arb_hit_type0 is closing a multi-hit merge | all consumers return to IDLE and no lane hangs | TBD |
| X002 | D | RESET during rbCAM drain | 1 | trigger RESET while rbCAM is mid-drain | rbCAM returns to IDLE and no hit_type2 leaks after IDLE | TBD |
| X003 | D | RESET during legacy FEB upload packet push | 1 | drive hit then RESET while upload_pkt_mux has an in-flight packet | upload path drains or clears without leaking a stale hit after IDLE | TBD |
| X004 | D | Back-to-back RESETs without intervening IDLE | 1 | drive RESET twice in adjacent cycles | runctl_mgmt_host handles double RESET and all consumers stay IDLE | TBD |
| X005 | D | Truncated state word on synclink | 1 | runctl_phy_agent drives a malformed state word | runctl_mgmt_host rejects it and state does not change | TBD |
| X006 | R | Randomised mid-flight RESET and RC protocol violation seed 1 | 1 | RC error sequence randomises reset timing and malformed state word for seed 1 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X007 | R | Randomised mid-flight RESET and RC protocol violation seed 2 | 1 | RC error sequence randomises reset timing and malformed state word for seed 2 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X008 | R | Randomised mid-flight RESET and RC protocol violation seed 3 | 1 | RC error sequence randomises reset timing and malformed state word for seed 3 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X009 | R | Randomised mid-flight RESET and RC protocol violation seed 4 | 1 | RC error sequence randomises reset timing and malformed state word for seed 4 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X010 | R | Randomised mid-flight RESET and RC protocol violation seed 5 | 1 | RC error sequence randomises reset timing and malformed state word for seed 5 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X011 | R | Randomised mid-flight RESET and RC protocol violation seed 6 | 1 | RC error sequence randomises reset timing and malformed state word for seed 6 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X012 | R | Randomised mid-flight RESET and RC protocol violation seed 7 | 1 | RC error sequence randomises reset timing and malformed state word for seed 7 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X013 | R | Randomised mid-flight RESET and RC protocol violation seed 8 | 1 | RC error sequence randomises reset timing and malformed state word for seed 8 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X014 | R | Randomised mid-flight RESET and RC protocol violation seed 9 | 1 | RC error sequence randomises reset timing and malformed state word for seed 9 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X015 | R | Randomised mid-flight RESET and RC protocol violation seed 10 | 1 | RC error sequence randomises reset timing and malformed state word for seed 10 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X016 | R | Randomised mid-flight RESET and RC protocol violation seed 11 | 1 | RC error sequence randomises reset timing and malformed state word for seed 11 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X017 | R | Randomised mid-flight RESET and RC protocol violation seed 12 | 1 | RC error sequence randomises reset timing and malformed state word for seed 12 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X018 | R | Randomised mid-flight RESET and RC protocol violation seed 13 | 1 | RC error sequence randomises reset timing and malformed state word for seed 13 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X019 | R | Randomised mid-flight RESET and RC protocol violation seed 14 | 1 | RC error sequence randomises reset timing and malformed state word for seed 14 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X020 | R | Randomised mid-flight RESET and RC protocol violation seed 15 | 1 | RC error sequence randomises reset timing and malformed state word for seed 15 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X021 | R | Randomised mid-flight RESET and RC protocol violation seed 16 | 1 | RC error sequence randomises reset timing and malformed state word for seed 16 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X022 | R | Randomised mid-flight RESET and RC protocol violation seed 17 | 1 | RC error sequence randomises reset timing and malformed state word for seed 17 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X023 | R | Randomised mid-flight RESET and RC protocol violation seed 18 | 1 | RC error sequence randomises reset timing and malformed state word for seed 18 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X024 | R | Randomised mid-flight RESET and RC protocol violation seed 19 | 1 | RC error sequence randomises reset timing and malformed state word for seed 19 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X025 | R | Randomised mid-flight RESET and RC protocol violation seed 20 | 1 | RC error sequence randomises reset timing and malformed state word for seed 20 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X026 | R | Randomised mid-flight RESET and RC protocol violation seed 21 | 1 | RC error sequence randomises reset timing and malformed state word for seed 21 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X027 | R | Randomised mid-flight RESET and RC protocol violation seed 22 | 1 | RC error sequence randomises reset timing and malformed state word for seed 22 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X028 | R | Randomised mid-flight RESET and RC protocol violation seed 23 | 1 | RC error sequence randomises reset timing and malformed state word for seed 23 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X029 | R | Randomised mid-flight RESET and RC protocol violation seed 24 | 1 | RC error sequence randomises reset timing and malformed state word for seed 24 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X030 | R | Randomised mid-flight RESET and RC protocol violation seed 25 | 1 | RC error sequence randomises reset timing and malformed state word for seed 25 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X031 | R | Randomised mid-flight RESET and RC protocol violation seed 26 | 1 | RC error sequence randomises reset timing and malformed state word for seed 26 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |
| X032 | R | Randomised mid-flight RESET and RC protocol violation seed 27 | 1 | RC error sequence randomises reset timing and malformed state word for seed 27 | cleanup path leaves no hung consumer and error accounting is consistent | TBD |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X033 | D | Burst overrun aperture | 1 | SC bridge issues 4097-word burst to scratch_pad_ram | bridge rejects or truncates without aliasing another slave | TBD |
| X034 | D | Read of undefined address inside slave aperture | 1 | SC reads an unmapped offset | response is documented error or zero default | TBD |
| X035 | D | Write to read-only field | 1 | SC writes the UID field | write is rejected or ignored and subsequent read is unchanged | TBD |
| X036 | D | Read of write-one-pulse field | 1 | SC reads a W1P field | field reads as zero or documented deasserted value | TBD |
| X037 | D | SC issued during RC RESET | 1 | drive RESET then SC read inside reset window | SC bridge holds or reports error and recovers cleanly | TBD |
| X038 | R | Randomised illegal-address and SC protocol violation seed 1 | 1 | SC error sequence randomises address, access type, and timing for seed 1 | error syndrome is covered and no false success is reported | TBD |
| X039 | R | Randomised illegal-address and SC protocol violation seed 2 | 1 | SC error sequence randomises address, access type, and timing for seed 2 | error syndrome is covered and no false success is reported | TBD |
| X040 | R | Randomised illegal-address and SC protocol violation seed 3 | 1 | SC error sequence randomises address, access type, and timing for seed 3 | error syndrome is covered and no false success is reported | TBD |
| X041 | R | Randomised illegal-address and SC protocol violation seed 4 | 1 | SC error sequence randomises address, access type, and timing for seed 4 | error syndrome is covered and no false success is reported | TBD |
| X042 | R | Randomised illegal-address and SC protocol violation seed 5 | 1 | SC error sequence randomises address, access type, and timing for seed 5 | error syndrome is covered and no false success is reported | TBD |
| X043 | R | Randomised illegal-address and SC protocol violation seed 6 | 1 | SC error sequence randomises address, access type, and timing for seed 6 | error syndrome is covered and no false success is reported | TBD |
| X044 | R | Randomised illegal-address and SC protocol violation seed 7 | 1 | SC error sequence randomises address, access type, and timing for seed 7 | error syndrome is covered and no false success is reported | TBD |
| X045 | R | Randomised illegal-address and SC protocol violation seed 8 | 1 | SC error sequence randomises address, access type, and timing for seed 8 | error syndrome is covered and no false success is reported | TBD |
| X046 | R | Randomised illegal-address and SC protocol violation seed 9 | 1 | SC error sequence randomises address, access type, and timing for seed 9 | error syndrome is covered and no false success is reported | TBD |
| X047 | R | Randomised illegal-address and SC protocol violation seed 10 | 1 | SC error sequence randomises address, access type, and timing for seed 10 | error syndrome is covered and no false success is reported | TBD |
| X048 | R | Randomised illegal-address and SC protocol violation seed 11 | 1 | SC error sequence randomises address, access type, and timing for seed 11 | error syndrome is covered and no false success is reported | TBD |
| X049 | R | Randomised illegal-address and SC protocol violation seed 12 | 1 | SC error sequence randomises address, access type, and timing for seed 12 | error syndrome is covered and no false success is reported | TBD |
| X050 | R | Randomised illegal-address and SC protocol violation seed 13 | 1 | SC error sequence randomises address, access type, and timing for seed 13 | error syndrome is covered and no false success is reported | TBD |
| X051 | R | Randomised illegal-address and SC protocol violation seed 14 | 1 | SC error sequence randomises address, access type, and timing for seed 14 | error syndrome is covered and no false success is reported | TBD |
| X052 | R | Randomised illegal-address and SC protocol violation seed 15 | 1 | SC error sequence randomises address, access type, and timing for seed 15 | error syndrome is covered and no false success is reported | TBD |
| X053 | R | Randomised illegal-address and SC protocol violation seed 16 | 1 | SC error sequence randomises address, access type, and timing for seed 16 | error syndrome is covered and no false success is reported | TBD |
| X054 | R | Randomised illegal-address and SC protocol violation seed 17 | 1 | SC error sequence randomises address, access type, and timing for seed 17 | error syndrome is covered and no false success is reported | TBD |
| X055 | R | Randomised illegal-address and SC protocol violation seed 18 | 1 | SC error sequence randomises address, access type, and timing for seed 18 | error syndrome is covered and no false success is reported | TBD |
| X056 | R | Randomised illegal-address and SC protocol violation seed 19 | 1 | SC error sequence randomises address, access type, and timing for seed 19 | error syndrome is covered and no false success is reported | TBD |
| X057 | R | Randomised illegal-address and SC protocol violation seed 20 | 1 | SC error sequence randomises address, access type, and timing for seed 20 | error syndrome is covered and no false success is reported | TBD |
| X058 | R | Randomised illegal-address and SC protocol violation seed 21 | 1 | SC error sequence randomises address, access type, and timing for seed 21 | error syndrome is covered and no false success is reported | TBD |
| X059 | R | Randomised illegal-address and SC protocol violation seed 22 | 1 | SC error sequence randomises address, access type, and timing for seed 22 | error syndrome is covered and no false success is reported | TBD |
| X060 | R | Randomised illegal-address and SC protocol violation seed 23 | 1 | SC error sequence randomises address, access type, and timing for seed 23 | error syndrome is covered and no false success is reported | TBD |
| X061 | R | Randomised illegal-address and SC protocol violation seed 24 | 1 | SC error sequence randomises address, access type, and timing for seed 24 | error syndrome is covered and no false success is reported | TBD |
| X062 | R | Randomised illegal-address and SC protocol violation seed 25 | 1 | SC error sequence randomises address, access type, and timing for seed 25 | error syndrome is covered and no false success is reported | TBD |
| X063 | R | Randomised illegal-address and SC protocol violation seed 26 | 1 | SC error sequence randomises address, access type, and timing for seed 26 | error syndrome is covered and no false success is reported | TBD |
| X064 | R | Randomised illegal-address and SC protocol violation seed 27 | 1 | SC error sequence randomises address, access type, and timing for seed 27 | error syndrome is covered and no false success is reported | TBD |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X065 | D | Bad CRC on virtual-MuTRiG frame | 1 | mutrig_phy_agent injects one frame with one byte XORed | mutrig_frame_deassembly rejects it and no garbage hit appears downstream | TBD |
| X066 | D | Dropped frame mid-cluster | 1 | drop a frame after cluster start | frame_drop_err increments and no partial cluster reaches FEB-egress | TBD |
| X067 | D | SOP without EOP | 1 | inject SOP byte and suppress EOP | frame_format_err increments and frame is discarded | TBD |
| X068 | D | Double EOP without intervening SOP | 1 | inject EOP twice | format_err increments and second EOP is ignored | TBD |
| X069 | D | RUN_PREP issued mid-frame | 1 | drive RUN_PREP while MuTRiG frame is in flight | mid-frame hits are not exported and transition succeeds | TBD |
| X070 | D | Emulator and real channels collide on same channel ID | 1 | inject real and emulator hit on channel 8 at same T_coarse | scoreboard flags lane collision and watchdog fires | TBD |
| X071 | D | Watchdog fires exactly at timeout boundary | 1 | drive hits up to timeout minus one then idle | watchdog state and flush behavior match boundary expectation | TBD |
| X072 | D | upload_pkt_mux egress backpressure timeout | 1 | drive FEB-egress packet and hold ready low beyond budget | timeout/error accounting increments and subsequent upload traffic recovers | TBD |
| X073 | R | Randomised datapath failure injection seed 1 | 1 | randomise failure type, source, rate, and run state for seed 1 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X074 | R | Randomised datapath failure injection seed 2 | 1 | randomise failure type, source, rate, and run state for seed 2 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X075 | R | Randomised datapath failure injection seed 3 | 1 | randomise failure type, source, rate, and run state for seed 3 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X076 | R | Randomised datapath failure injection seed 4 | 1 | randomise failure type, source, rate, and run state for seed 4 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X077 | R | Randomised datapath failure injection seed 5 | 1 | randomise failure type, source, rate, and run state for seed 5 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X078 | R | Randomised datapath failure injection seed 6 | 1 | randomise failure type, source, rate, and run state for seed 6 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X079 | R | Randomised datapath failure injection seed 7 | 1 | randomise failure type, source, rate, and run state for seed 7 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X080 | R | Randomised datapath failure injection seed 8 | 1 | randomise failure type, source, rate, and run state for seed 8 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X081 | R | Randomised datapath failure injection seed 9 | 1 | randomise failure type, source, rate, and run state for seed 9 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X082 | R | Randomised datapath failure injection seed 10 | 1 | randomise failure type, source, rate, and run state for seed 10 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X083 | R | Randomised datapath failure injection seed 11 | 1 | randomise failure type, source, rate, and run state for seed 11 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X084 | R | Randomised datapath failure injection seed 12 | 1 | randomise failure type, source, rate, and run state for seed 12 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X085 | R | Randomised datapath failure injection seed 13 | 1 | randomise failure type, source, rate, and run state for seed 13 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X086 | R | Randomised datapath failure injection seed 14 | 1 | randomise failure type, source, rate, and run state for seed 14 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X087 | R | Randomised datapath failure injection seed 15 | 1 | randomise failure type, source, rate, and run state for seed 15 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X088 | R | Randomised datapath failure injection seed 16 | 1 | randomise failure type, source, rate, and run state for seed 16 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X089 | R | Randomised datapath failure injection seed 17 | 1 | randomise failure type, source, rate, and run state for seed 17 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X090 | R | Randomised datapath failure injection seed 18 | 1 | randomise failure type, source, rate, and run state for seed 18 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X091 | R | Randomised datapath failure injection seed 19 | 1 | randomise failure type, source, rate, and run state for seed 19 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X092 | R | Randomised datapath failure injection seed 20 | 1 | randomise failure type, source, rate, and run state for seed 20 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X093 | R | Randomised datapath failure injection seed 21 | 1 | randomise failure type, source, rate, and run state for seed 21 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X094 | R | Randomised datapath failure injection seed 22 | 1 | randomise failure type, source, rate, and run state for seed 22 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X095 | R | Randomised datapath failure injection seed 23 | 1 | randomise failure type, source, rate, and run state for seed 23 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X096 | R | Randomised datapath failure injection seed 24 | 1 | randomise failure type, source, rate, and run state for seed 24 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X097 | R | Randomised datapath failure injection seed 25 | 1 | randomise failure type, source, rate, and run state for seed 25 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X098 | R | Randomised datapath failure injection seed 26 | 1 | randomise failure type, source, rate, and run state for seed 26 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X099 | R | Randomised datapath failure injection seed 27 | 1 | randomise failure type, source, rate, and run state for seed 27 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X100 | R | Randomised datapath failure injection seed 28 | 1 | randomise failure type, source, rate, and run state for seed 28 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X101 | R | Randomised datapath failure injection seed 29 | 1 | randomise failure type, source, rate, and run state for seed 29 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X102 | R | Randomised datapath failure injection seed 30 | 1 | randomise failure type, source, rate, and run state for seed 30 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X103 | R | Randomised datapath failure injection seed 31 | 1 | randomise failure type, source, rate, and run state for seed 31 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X104 | R | Randomised datapath failure injection seed 32 | 1 | randomise failure type, source, rate, and run state for seed 32 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X105 | R | Randomised datapath failure injection seed 33 | 1 | randomise failure type, source, rate, and run state for seed 33 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X106 | R | Randomised datapath failure injection seed 34 | 1 | randomise failure type, source, rate, and run state for seed 34 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X107 | R | Randomised datapath failure injection seed 35 | 1 | randomise failure type, source, rate, and run state for seed 35 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X108 | R | Randomised datapath failure injection seed 36 | 1 | randomise failure type, source, rate, and run state for seed 36 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X109 | R | Randomised datapath failure injection seed 37 | 1 | randomise failure type, source, rate, and run state for seed 37 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X110 | R | Randomised datapath failure injection seed 38 | 1 | randomise failure type, source, rate, and run state for seed 38 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X111 | R | Randomised datapath failure injection seed 39 | 1 | randomise failure type, source, rate, and run state for seed 39 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X112 | R | Randomised datapath failure injection seed 40 | 1 | randomise failure type, source, rate, and run state for seed 40 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X113 | R | Randomised datapath failure injection seed 41 | 1 | randomise failure type, source, rate, and run state for seed 41 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X114 | R | Randomised datapath failure injection seed 42 | 1 | randomise failure type, source, rate, and run state for seed 42 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X115 | R | Randomised datapath failure injection seed 43 | 1 | randomise failure type, source, rate, and run state for seed 43 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X116 | R | Randomised datapath failure injection seed 44 | 1 | randomise failure type, source, rate, and run state for seed 44 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X117 | R | Randomised datapath failure injection seed 45 | 1 | randomise failure type, source, rate, and run state for seed 45 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X118 | R | Randomised datapath failure injection seed 46 | 1 | randomise failure type, source, rate, and run state for seed 46 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X119 | R | Randomised datapath failure injection seed 47 | 1 | randomise failure type, source, rate, and run state for seed 47 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X120 | R | Randomised datapath failure injection seed 48 | 1 | randomise failure type, source, rate, and run state for seed 48 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X121 | R | Randomised datapath failure injection seed 49 | 1 | randomise failure type, source, rate, and run state for seed 49 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X122 | R | Randomised datapath failure injection seed 50 | 1 | randomise failure type, source, rate, and run state for seed 50 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X123 | R | Randomised datapath failure injection seed 51 | 1 | randomise failure type, source, rate, and run state for seed 51 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X124 | R | Randomised datapath failure injection seed 52 | 1 | randomise failure type, source, rate, and run state for seed 52 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X125 | R | Randomised datapath failure injection seed 53 | 1 | randomise failure type, source, rate, and run state for seed 53 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X126 | R | Randomised datapath failure injection seed 54 | 1 | randomise failure type, source, rate, and run state for seed 54 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X127 | R | Randomised datapath failure injection seed 55 | 1 | randomise failure type, source, rate, and run state for seed 55 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X128 | R | Randomised datapath failure injection seed 56 | 1 | randomise failure type, source, rate, and run state for seed 56 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X129 | R | Randomised datapath failure injection seed 57 | 1 | randomise failure type, source, rate, and run state for seed 57 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X130 | R | Randomised datapath failure injection seed 58 | 1 | randomise failure type, source, rate, and run state for seed 58 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X131 | R | Randomised datapath failure injection seed 59 | 1 | randomise failure type, source, rate, and run state for seed 59 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X132 | R | Randomised datapath failure injection seed 60 | 1 | randomise failure type, source, rate, and run state for seed 60 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X133 | R | Randomised datapath failure injection seed 61 | 1 | randomise failure type, source, rate, and run state for seed 61 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X134 | R | Randomised datapath failure injection seed 62 | 1 | randomise failure type, source, rate, and run state for seed 62 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X135 | R | Randomised datapath failure injection seed 63 | 1 | randomise failure type, source, rate, and run state for seed 63 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X136 | R | Randomised datapath failure injection seed 64 | 1 | randomise failure type, source, rate, and run state for seed 64 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X137 | R | Randomised datapath failure injection seed 65 | 1 | randomise failure type, source, rate, and run state for seed 65 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X138 | R | Randomised datapath failure injection seed 66 | 1 | randomise failure type, source, rate, and run state for seed 66 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X139 | R | Randomised datapath failure injection seed 67 | 1 | randomise failure type, source, rate, and run state for seed 67 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X140 | R | Randomised datapath failure injection seed 68 | 1 | randomise failure type, source, rate, and run state for seed 68 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X141 | R | Randomised datapath failure injection seed 69 | 1 | randomise failure type, source, rate, and run state for seed 69 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X142 | R | Randomised datapath failure injection seed 70 | 1 | randomise failure type, source, rate, and run state for seed 70 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X143 | R | Randomised datapath failure injection seed 71 | 1 | randomise failure type, source, rate, and run state for seed 71 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X144 | R | Randomised datapath failure injection seed 72 | 1 | randomise failure type, source, rate, and run state for seed 72 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X145 | R | Randomised datapath failure injection seed 73 | 1 | randomise failure type, source, rate, and run state for seed 73 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X146 | R | Randomised datapath failure injection seed 74 | 1 | randomise failure type, source, rate, and run state for seed 74 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X147 | R | Randomised datapath failure injection seed 75 | 1 | randomise failure type, source, rate, and run state for seed 75 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X148 | R | Randomised datapath failure injection seed 76 | 1 | randomise failure type, source, rate, and run state for seed 76 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X149 | R | Randomised datapath failure injection seed 77 | 1 | randomise failure type, source, rate, and run state for seed 77 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X150 | R | Randomised datapath failure injection seed 78 | 1 | randomise failure type, source, rate, and run state for seed 78 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X151 | R | Randomised datapath failure injection seed 79 | 1 | randomise failure type, source, rate, and run state for seed 79 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X152 | R | Randomised datapath failure injection seed 80 | 1 | randomise failure type, source, rate, and run state for seed 80 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X153 | R | Randomised datapath failure injection seed 81 | 1 | randomise failure type, source, rate, and run state for seed 81 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X154 | R | Randomised datapath failure injection seed 82 | 1 | randomise failure type, source, rate, and run state for seed 82 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X155 | R | Randomised datapath failure injection seed 83 | 1 | randomise failure type, source, rate, and run state for seed 83 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X156 | R | Randomised datapath failure injection seed 84 | 1 | randomise failure type, source, rate, and run state for seed 84 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X157 | R | Randomised datapath failure injection seed 85 | 1 | randomise failure type, source, rate, and run state for seed 85 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X158 | R | Randomised datapath failure injection seed 86 | 1 | randomise failure type, source, rate, and run state for seed 86 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X159 | R | Randomised datapath failure injection seed 87 | 1 | randomise failure type, source, rate, and run state for seed 87 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X160 | R | Randomised datapath failure injection seed 88 | 1 | randomise failure type, source, rate, and run state for seed 88 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X161 | R | Randomised datapath failure injection seed 89 | 1 | randomise failure type, source, rate, and run state for seed 89 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X162 | R | Randomised datapath failure injection seed 90 | 1 | randomise failure type, source, rate, and run state for seed 90 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X163 | R | Randomised datapath failure injection seed 91 | 1 | randomise failure type, source, rate, and run state for seed 91 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X164 | R | Randomised datapath failure injection seed 92 | 1 | randomise failure type, source, rate, and run state for seed 92 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X165 | R | Randomised datapath failure injection seed 93 | 1 | randomise failure type, source, rate, and run state for seed 93 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X166 | R | Randomised datapath failure injection seed 94 | 1 | randomise failure type, source, rate, and run state for seed 94 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X167 | R | Randomised datapath failure injection seed 95 | 1 | randomise failure type, source, rate, and run state for seed 95 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X168 | R | Randomised datapath failure injection seed 96 | 1 | randomise failure type, source, rate, and run state for seed 96 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X169 | R | Randomised datapath failure injection seed 97 | 1 | randomise failure type, source, rate, and run state for seed 97 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X170 | R | Randomised datapath failure injection seed 98 | 1 | randomise failure type, source, rate, and run state for seed 98 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X171 | R | Randomised datapath failure injection seed 99 | 1 | randomise failure type, source, rate, and run state for seed 99 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X172 | R | Randomised datapath failure injection seed 100 | 1 | randomise failure type, source, rate, and run state for seed 100 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X173 | R | Randomised datapath failure injection seed 101 | 1 | randomise failure type, source, rate, and run state for seed 101 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X174 | R | Randomised datapath failure injection seed 102 | 1 | randomise failure type, source, rate, and run state for seed 102 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X175 | R | Randomised datapath failure injection seed 103 | 1 | randomise failure type, source, rate, and run state for seed 103 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X176 | R | Randomised datapath failure injection seed 104 | 1 | randomise failure type, source, rate, and run state for seed 104 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X177 | R | Randomised datapath failure injection seed 105 | 1 | randomise failure type, source, rate, and run state for seed 105 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X178 | R | Randomised datapath failure injection seed 106 | 1 | randomise failure type, source, rate, and run state for seed 106 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X179 | R | Randomised datapath failure injection seed 107 | 1 | randomise failure type, source, rate, and run state for seed 107 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X180 | R | Randomised datapath failure injection seed 108 | 1 | randomise failure type, source, rate, and run state for seed 108 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X181 | R | Randomised datapath failure injection seed 109 | 1 | randomise failure type, source, rate, and run state for seed 109 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X182 | R | Randomised datapath failure injection seed 110 | 1 | randomise failure type, source, rate, and run state for seed 110 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X183 | R | Randomised datapath failure injection seed 111 | 1 | randomise failure type, source, rate, and run state for seed 111 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X184 | R | Randomised datapath failure injection seed 112 | 1 | randomise failure type, source, rate, and run state for seed 112 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X185 | R | Randomised datapath failure injection seed 113 | 1 | randomise failure type, source, rate, and run state for seed 113 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X186 | R | Randomised datapath failure injection seed 114 | 1 | randomise failure type, source, rate, and run state for seed 114 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X187 | R | Randomised datapath failure injection seed 115 | 1 | randomise failure type, source, rate, and run state for seed 115 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X188 | R | Randomised datapath failure injection seed 116 | 1 | randomise failure type, source, rate, and run state for seed 116 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X189 | R | Randomised datapath failure injection seed 117 | 1 | randomise failure type, source, rate, and run state for seed 117 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X190 | R | Randomised datapath failure injection seed 118 | 1 | randomise failure type, source, rate, and run state for seed 118 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X191 | R | Randomised datapath failure injection seed 119 | 1 | randomise failure type, source, rate, and run state for seed 119 | target error counter is sampled and recovery path returns to normal operation | TBD |
| X192 | R | Randomised datapath failure injection seed 120 | 1 | randomise failure type, source, rate, and run state for seed 120 | target error counter is sampled and recovery path returns to normal operation | TBD |
