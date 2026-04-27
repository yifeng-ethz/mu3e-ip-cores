# Phase 2 BIST Report

- Timestamp: `2026-04-24T08:35:45`
- SC link: `2`
- Image under test: `firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/output_files_pipe/top_nostp_pipe.sof`
- Runner: `firmware_builds/board_test/script/run_atpg_v2_reference.sh`
- Raw log: `firmware_builds/board_test/reports/feb_scifi_sc_dv_20260424_083545.log`
- Result: `PASS` for the executed reference ATPG suite

## Summary

| Metric | Count |
|---|---:|
| Total checks | 66 |
| Pass | 65 |
| Fail | 0 |
| Skip | 1 |

The single skip is expected: `T6c sc_hub SCRATCH` attempts a non-4-aligned burst that crosses `ERR_COUNT` read-only CSR space, so the hub aborts the write and the scratch value remains `0x00000000`.

## Coverage

| Area | Evidence |
|---|---|
| Scratchpad burst sizes | `T1` passed burst lengths 1, 2, 3, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 191, 192, 254, 255, 256 |
| Scratchpad alignment | `T2` passed offsets 0, 4, 8, 64, 124, 128, 200, 240 |
| Scratchpad patterns | `T3` passed walking-1, walking-0, checkerboard, inverse checkerboard, all-ones, all-zeros, address-data, inverted-address |
| MAX10 page buffer | `T4` passed 64-word address-data, 64-word constant, and 8/16/32-word sub-bursts |
| Identity/status reads | `T5` passed MAX10 ID `0x4D312850`, MAX10 status ready, SC hub UID `0x53434842`, hub status no-error, hub cap `0x0000000E`, onewire cap `0x00000006`, Firefly temp/status, and on-die temp `49C` |
| Mixed interleave | `T6` passed scratchpad/MAX10 interleaving and max10 scratch readback |
| Back-to-back stress | `T7` passed 20/20 256-word reads |
| Non-incrementing read | `T8` passed 4x `0xFACEFACE` from scratchpad word 0 |
| SC hub diagnostics | `T9` passed fresh `ERR_FLAGS=0`, `PKT_DROP_CNT=0`, nonzero traffic counters |

## Restore

After the destructive runner completed:

| Target | Restore action | Verification |
|---|---|---|
| `scratch_pad_ram[0..255]` | Wrote all zeros | Readback of `[0..15]` returned all `0x00000000`, matching Phase 1 baseline |
| `max10_prog_avmm_0.PAGE_DATA[0..63]` | Wrote all zeros | Readback of `[0..7]` returned all `0x00000000` |
| `max10_prog_avmm_0.SCRATCH` | Wrote `0x00000000` | Readback returned `0x00000000` |

## Caveat

This report captures the existing v2 reference ATPG suite, path-hardened for the local board-test tools. It does not yet implement the full SVD-wide RW-register enumeration described in `TEST_PLAN.md` section 2.2.
