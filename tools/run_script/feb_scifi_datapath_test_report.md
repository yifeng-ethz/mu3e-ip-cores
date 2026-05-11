# FEB SciFi Datapath IP Test Report (mm_bridge downstream)

All 34 slaves behind mm_bridge (SC word base 0x8000) tested via `sc_tool` only.

## Address Convention

mm_bridge at Qsys byte 0x20000 = SC packet word 0x8000.
Slave word addr = 0x8000 + (slave_qsys_byte_offset ÷ 4).
All addresses below are SC packet word addresses passed to `sc_tool`.

## Test Protocol

1. Single read of first word from each slave
2. Burst read of full CSR aperture
3. Write/readback test on IPs with RW registers (histogram SCRATCH, ring_buffer_cam CTRL, mutrig_injector)

Status: ✅ = responds correctly, ❌ = error/timeout, ⚠️ = partial

---

**Date**: 2026-04-16 11:32:11

## 1. lvds_rx_controller_pro (16 RO words)

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| lvds_rx_controller_pro_0                           | 0x08000 |  16 | 0x00FA0009   | any          | ✅ | ✅ |

Burst dump (16 words):
```
  [ 0] 0x00FA0009
  [ 1] 0x000001FF
  [ 2] 0x00000000
  [ 3] 0x00000000
  [ 4] 0x000001FF
  [ 5] 0xFFFFFFFF
  [ 6] 0xFFFFFFFF
  [ 7] 0xFFFFFFFF
  [ 8] 0xFFFFFFFF
  [ 9] 0xFFFFFFFF
  [10] 0xFFFFFFFF
  [11] 0xFFFFFFFF
  [12] 0xFFFFFFFF
  [13] 0x0009F259
  [14] 0x00000000
  [15] 0x00000000
```

## 2. mutrig_datapath_subsystem [0..7] (backpressure_fifo + frame_deassembly)

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| mutrig_dp_0/backpressure_fifo                      | 0x08218 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_0/frame_deassembly                       | 0x08240 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_1/backpressure_fifo                      | 0x08618 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_1/frame_deassembly                       | 0x08640 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_2/backpressure_fifo                      | 0x08A18 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_2/frame_deassembly                       | 0x08A40 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_3/backpressure_fifo                      | 0x08E18 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_3/frame_deassembly                       | 0x08E40 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_4/backpressure_fifo                      | 0x09218 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_4/frame_deassembly                       | 0x09240 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_5/backpressure_fifo                      | 0x09618 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_5/frame_deassembly                       | 0x09640 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_6/backpressure_fifo                      | 0x09A18 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_6/frame_deassembly                       | 0x09A40 |   4 | 0x00000001   | any          | ✅ | ✅ |
| mutrig_dp_7/backpressure_fifo                      | 0x09E18 |   4 | 0x00000000   | any          | ✅ | ✅ |
| mutrig_dp_7/frame_deassembly                       | 0x09E40 |   4 | 0x00000001   | any          | ✅ | ✅ |

## 3. mts_preprocessor [0..1] (8 RO words each)

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| mts_preprocessor_0                                 | 0x09000 |   8 | 0x20000010   | any          | ✅ | ✅ |
| mts_preprocessor_1                                 | 0x0A000 |   8 | 0x20000010   | any          | ✅ | ✅ |

## 4. histogram_statistics [0..1]

### CSR registers (UID=0x48495354 "HIST")

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| histogram_statistics_0.csr                         | 0x0A900 |  17 | 0x48495354   | 0x48495354   | ✅ | ✅ |
| histogram_statistics_1.csr                         | 0x0AB00 |  17 | 0x48495354   | 0x48495354   | ✅ | ✅ |

### hist_bin (256-word histogram bins)

**WARNING: hist_bin burst reads (burstcount >= 2) corrupt the entire datapath**
**subsystem — all IPs behind mm_bridge read 0xEEEEEEEE. Single-word reads only.**

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| histogram_statistics_0.hist_bin                    | 0x0A800 | 256 | 0x00000000   | any          | ✅ | SKIP(bug) |
| histogram_statistics_1.hist_bin                    | 0x0AA00 | 256 | 0x00000000   | any          | ✅ | SKIP(bug) |

### Write/readback test (histogram SCRATCH)

  - hist_0.SCRATCH @ 0x0A910: W=0xDEADBEEF RB=0xDEADBEEF ✅
  - hist_1.SCRATCH @ 0x0AB10: W=0xDEADBEEF RB=0xDEADBEEF ✅

## 5. hit_stack_subsystem [0..1]

### ring_buffer_cam (UID=0x5242434D "RBCM")

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| hit_stack_0/ring_buffer_cam_0                      | 0x0AC00 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_0/ring_buffer_cam_1                      | 0x0AC20 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_0/ring_buffer_cam_2                      | 0x0AC40 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_0/ring_buffer_cam_3                      | 0x0AC60 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_1/ring_buffer_cam_0                      | 0x0AD00 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_1/ring_buffer_cam_1                      | 0x0AD20 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_1/ring_buffer_cam_2                      | 0x0AD40 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |
| hit_stack_1/ring_buffer_cam_3                      | 0x0AD60 |  10 | 0x5242434D   | 0x5242434D   | ✅ | ✅ |

### feb_frame_assembly (16 RO words each)

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| hit_stack_0/feb_frame_assembly_0                   | 0x0B400 |  16 | 0x00000038   | any          | ✅ | ✅ |
| hit_stack_1/feb_frame_assembly_0                   | 0x0B410 |  16 | 0x00000038   | any          | ✅ | ✅ |

## 6. mutrig_injector_0 (16 RW words)

| Slave | Addr | Words | First Word | Expected | S | Burst |
|-------|------|-------|------------|----------|---|-------|
| mutrig_injector_0                                  | 0x0AC80 |  16 | 0x00000000   | any          | ✅ | ✅ |

### Write/readback test (mutrig_injector WORD000 + WORD001)

  - mutrig_injector_0.WORD000 @ 0x0AC80: W=0x0000000F RB=0x0000000F ✅
  - mutrig_injector_0.WORD001 @ 0x0AC84: W=0x0000000F RB=0x0000000F ✅

## 7. Detailed Register Dumps

### histogram_statistics_0.csr (17 words @ 0x0A900)

| WOff | Name | Value |
|------|------|-------|
| 0x00 | UID                  | 0x48495354   |
| 0x01 | META                 | 0x1A000000   |
| 0x02 | CONTROL              | 0x00000100   |
| 0x03 | LEFT_BOUND           | 0x00000000   |
| 0x04 | RIGHT_BOUND          | 0x00000100   |
| 0x05 | BIN_WIDTH            | 0x00000001   |
| 0x06 | KEY_LOC              | 0x28242824   |
| 0x07 | KEY_VALUE            | 0x00000000   |
| 0x08 | UNDERFLOW_COUNT      | 0x00000000   |
| 0x09 | OVERFLOW_COUNT       | 0x00000000   |
| 0x0A | INTERVAL_CFG         | 0x07735940   |
| 0x0B | BANK_STATUS          | 0x00000001   |
| 0x0C | PORT_STATUS          | 0x000000FF   |
| 0x0D | TOTAL_HITS           | 0x00000000   |
| 0x0E | DROPPED_HITS         | 0x00000000   |
| 0x0F | COAL_STATUS          | 0x00000000   |
| 0x10 | SCRATCH              | 0x00000000   |

### hit_stack_0/ring_buffer_cam_0 (10 words @ 0x0AC00)

| WOff | Name | Value |
|------|------|-------|
| 0x00 | UID                  | 0x5242434D   |
| 0x01 | META                 | 0x1A014192   |
| 0x02 | CTRL                 | 0x00000011   |
| 0x03 | EXPECTED_LATENCY     | 0x000007D0   |
| 0x04 | FILL_LEVEL           | 0x00000000   |
| 0x05 | INERR_COUNT          | 0x00000000   |
| 0x06 | PUSH_COUNT           | 0x00000000   |
| 0x07 | POP_COUNT            | 0x00000000   |
| 0x08 | OVERWRITE_COUNT      | 0x00000000   |
| 0x09 | CACHE_MISS_COUNT     | 0x00000000   |

## 8. ring_buffer_cam CTRL write/readback

**Note:** ring_buffer_cam CTRL registers have word addresses not divisible by 4
(e.g. 0x0AC02, 0x0AC22, ...), which sc_tool rejects. Skipping write/readback.

  - hs0/cam0.CTRL @ 0x0AC02: SKIP (addr%4!=0, sc_tool limitation)
  - hs0/cam1.CTRL @ 0x0AC22: SKIP (addr%4!=0, sc_tool limitation)
  - hs0/cam2.CTRL @ 0x0AC42: SKIP (addr%4!=0, sc_tool limitation)
  - hs0/cam3.CTRL @ 0x0AC62: SKIP (addr%4!=0, sc_tool limitation)
  - hs1/cam0.CTRL @ 0x0AD02: SKIP (addr%4!=0, sc_tool limitation)
  - hs1/cam1.CTRL @ 0x0AD22: SKIP (addr%4!=0, sc_tool limitation)
  - hs1/cam2.CTRL @ 0x0AD42: SKIP (addr%4!=0, sc_tool limitation)
  - hs1/cam3.CTRL @ 0x0AD62: SKIP (addr%4!=0, sc_tool limitation)

---

## Summary

| Metric | Count |
|--------|-------|
| ✅ Pass | 70 |
| ❌ Fail | 0 |
| — Skip | 10 |

**Total slaves tested**: 34

### Skip reasons

| Count | Reason |
|-------|--------|
| 8 | ring_buffer_cam CTRL word addresses not 4-byte aligned (sc_tool limitation) |
| 2 | histogram_statistics hist_bin burst reads trigger subsystem-wide corruption |

## Known Bug: hist_bin Burst Reads Corrupt Entire Datapath Subsystem

**Severity**: Critical (data-destroying side effect)

**Trigger**: Any SC burst read with burstcount >= 2 targeting the `histogram_statistics` `hist_bin` Avalon slave (word addresses 0x0A800 or 0x0AA00).

**Effect**: After the burst read, ALL registers in ALL IPs behind `mm_bridge` read 0xEEEEEEEE. Affected IPs include: lvds_rx_controller, all mutrig_datapath_subsystem instances, mts_preprocessor, histogram_statistics CSR, ring_buffer_cam, feb_frame_assembly, mutrig_injector.

**Not affected by**:
- Single-word reads from hist_bin (burstcount=1): safe
- Burst reads from histogram_statistics CSR (burstcount up to 17): safe
- Burst reads from all other bridge slaves: safe

**Recovery**: FEB reprogramming via `quartus_pgm` is required to restore register values.

**Root cause**: Not yet diagnosed. Likely a Qsys interconnect fabric issue where the `hist_bin` slave's burst interface generates spurious write transactions to the interconnect during multi-word reads. The 0xEEEEEEEE pattern (uniform across all registers of all IPs) suggests the interconnect fabric is broadcasting a write with that value to all slaves.

*Generated 2026-04-16 11:32:29*
