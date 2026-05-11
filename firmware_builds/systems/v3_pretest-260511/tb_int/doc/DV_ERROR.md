# DV_ERROR.md — tb_int ERROR bucket

**Companion docs:** [DV_INT_PLAN.md](DV_INT_PLAN.md), [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_PROF.md](DV_PROF.md), [TEST_PLAN.md](../../doc/TEST_PLAN.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** DV_INT_PLAN.md
**ID Range:** X001..X192 (32 RC + 32 SC + 128 DT)
**Total:** 192 cases (0 implemented / 0 waived)

**Methodology key:**
- `D` directed.
- `R` constrained-random.

ERROR bucket verifies the recovery path for every recorded upstream-bug surface and the protocol-violation rejection paths. BASIC + EDGE closure are prerequisites. Maps to TEST_PLAN.md Phase 2 ATPG (bad-value coverage) + Phase 3 mid-flight RESET + Phase 4 frame-error injection.

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| 2. RC | 32 | X001..X032 | mid-flight RESET while an IP is mid-flush; back-to-back RESETs without intervening IDLE; truncated state words | 0/32 |
| 3. SC | 32 | X033..X064 | burst overruns aperture; illegal address; write to RO field; read of W1P field; SC during RC RESET | 0/32 |
| 4. DT | 128 | X065..X192 | bad CRC on virtual-MuTRiG frames; dropped frames mid-cluster; RUN_PREP mid-frame; emu+real channel collision; SOP without EOP; double-EOP | 0/128 |

## 2. RC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X001 | D | Mid-flight RESET during arb_hit_type0 merge-packet close | 1 | trigger RESET while arb is in the middle of a multi-hit merge | every consumer returns to IDLE; arb error counter increments; no hung lane | TBD |
| X002 | D | RESET during rbCAM drain (post-rbCAM busy) | 1 | trigger RESET while rbCAM is mid-drain | rbCAM returns to IDLE; drain abandoned; no hit_type2 leak after IDLE | TBD |
| X003 | D | RESET during rdma_subsystem SQE push | 1 | drive a hit then RESET while SQE in flight | rdma_dma_engine aborts in-flight SQE; CQE returns error code or never returns; runctl shadow consistent | TBD |
| X004 | D | Back-to-back RESETs without intervening IDLE | 1 | drive RESET twice in adjacent cycles | runctl_mgmt_host handles double-RESET; all consumers stay at IDLE | TBD |
| X005 | D | Truncated state word on synclink | 1 | runctl_phy_agent drives a 5-bit word with the 9-bit one-hot violated | runctl_mgmt_host rejects; error counter increments; state does NOT change | TBD |
| X006..X032 | R | Randomised mid-flight RESET timings + protocol violations | 27 | UVM seq | every IP's RESET-cleanup path exercised; no hung consumer | TBD |

## 3. SC

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X033 | D | Burst overrun aperture (4 KB single-slave limit) | 1 | SC bridge issues 4097-word burst to scratch_pad_ram | bridge truncates or rejects; no slave alias | TBD |
| X034 | D | Read of an undefined address inside slave aperture | 1 | SC read at an unmapped offset | returns ack=DECODE_ERR or zero with rsp=BAD per slave spec | TBD |
| X035 | D | Write to RO field | 1 | SC write to UID field | write rejected with rsp=SLVERR or silent ignore; subsequent read confirms unchanged | TBD |
| X036 | D | Read of W1P (write-1-pulse) field | 1 | SC read | returns deasserted (read-as-zero) per spec | TBD |
| X037 | D | SC issued during RC RESET | 1 | drive RESET, then SC read within the reset window | SC bridge either holds or returns error; no protocol violation when RESET deasserts | TBD |
| X038..X064 | R | Randomised illegal-address / protocol violations | 27 | UVM seq | every error syndrome covered; no false success | TBD |

## 4. DT

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X065 | D | Bad CRC on virtual-MuTRiG frame | 1 | mutrig_phy_agent injects a frame with one byte XORed | mutrig_frame_deassembly rejects; crc_err counter increments; no garbage hit appears downstream | TBD |
| X066 | D | Dropped frame mid-cluster | 1 | drop a frame after cluster start | frame_drop_err counter increments; rest of cluster discarded; no partial cluster at FEB-egress | TBD |
| X067 | D | SOP without EOP | 1 | inject SOP byte; do NOT send EOP | frame_format_err counter increments; frame discarded | TBD |
| X068 | D | Double-EOP without intervening SOP | 1 | inject EOP twice | format_err counter increments; second EOP ignored | TBD |
| X069 | D | RUN_PREP issued mid-frame | 1 | drive RUN_PREP while a MuTRiG frame is in flight | mid-frame hits NOT exported; state transition succeeds; drain quiesces | TBD |
| X070 | D | Emulator and real channels collide on the same channel ID (violates [0..7]/[8..15] convention) | 1 | inject one real hit on ch=8 and one emu hit on ch=8 at same T_coarse | scoreboard flags lane_collision; arb_hit_type0 watchdog fires | TBD |
| X071 | D | Watchdog fires exactly at timeout boundary | 1 | drive hits up to the watchdog timeout - 1, then idle | watchdog stays armed; correct flush behavior at the boundary cycle | TBD |
| X072 | D | rdma_subsystem CQE timeout | 1 | drive SQE then suppress CQE writeback for >budget | timeout counter increments; rdma_dma_engine recovers; subsequent SQEs succeed | TBD |
| X073..X192 | R | Randomised failure injection x source x rate x state | 120 | UVM seq | every error counter triggered at least once; recovery path verified | TBD |

## 5. Bring-up order

After EDGE closure: X001..X008 RC RESET cleanup, then X033..X037 SC protocol violations, then X065..X072 DT failure injection, then randomised X009..X032, X038..X064, X073..X192.

## 6. Status

All cases pending implementation.
