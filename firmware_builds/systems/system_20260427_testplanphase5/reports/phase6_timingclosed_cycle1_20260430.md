# Phase 6 Timing-Closed SWB and Bounded Cycle 1 - 2026-04-30

## Result

`BLOCKED` at FEB MTS/ring. The timing-fixed SWB image closes the old host-visible
SC-return blocker, but no FEB/SWB/DMA/disk hit closure exists yet.

## SWB Checkpoint

| Check | Result | Observation |
|---|---|---|
| online_sc checkpoint | `PASS` | commit `11eada541` on `mf_stack` |
| SWB full compile | `PASS` | `make flow` completed with 0 errors and 300 warnings |
| TimeQuest slow 900 mV 100C | `PASS` | setup `+0.054 ns`, hold `+0.038 ns` |
| TimeQuest slow 900 mV 0C | `PASS` | setup `+0.059 ns`, hold `+0.035 ns` |
| TimeQuest fast 900 mV 100C | `PASS` | setup `+0.799 ns`, hold `+0.014 ns` |
| TimeQuest fast 900 mV 0C | `PASS` | setup `+0.803 ns`, hold `+0.012 ns` |
| programming | `PASS` | `top.sof` programmed on `DE5 [3-6.2]`, Quartus checksum `0x31A704E1` |
| SOF identity | `PASS` | SHA256 `15826df9f66187a6ffca1c2dd812334d1036c267a2f4f6899c833084761ef003` |
| PCIe recovery | `PASS` | `mudaq_recover_pcie` restored `/dev/mudaq0` |
| SC link 2 smoke read | `PASS_SC` | `sc_tool 2 read 0x00000 1 --quiet` returned a valid secondary packet in about 69 us, payload `0` |
| SC link 2 FEB UID read | `PASS_SC` | `sc_tool 2 read 0x0C000 1` returned `0x52434D48` (`RCMH`) in about 68 us |

This supersedes the earlier `ada3aea38` live preflight for the SC-return
blocker. The older SignalTap report remains useful history, but it no longer
describes the current SWB SC state.

## Runner Fix

The first bounded cycle was invalid because the MuTRiG XML submodule files were
missing, configuration failed, and the runner still executed injector/DMA cases
against stale state. That produced diagnostic noise only, including a
`swb_dmatest` `rc=-11` with no `memory_content.txt`; it is not DMA evidence.

The runner now:

| Fix | Result |
|---|---|
| pins SMB3 XML | `board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt` |
| pins SMB5 XML | `board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt` |
| preflights XML files | missing XML fails before hardware cases |
| short-circuits failed config | records `classification=config_failed` and skips the injector |
| reports config failures as hard failures | `config_failed` sets the runner exit code nonzero |

`python3 -m py_compile` passes on the updated runner.

## Valid Bounded Cycle

Run directory:

```text
firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_long_runs/20260430_timingclosed_cycle1_cfgfixed/
```

Raw files are intentionally ignored by git. This reduced report is the durable
evidence.

| Case | Stimulus | Config | Result | Key counters |
|---|---|---|---|---|
| P6B010 | lower lanes5+6, one TDC-test channel per ASIC, pulse-high 4, 100 kHz | ASIC5/6 from explicit SMB5 XML, `rc=0` | `unexpected_fail` | `hist_total_delta=106592`, `mts_total_delta=412235`, `mts_discard_delta=0`, `ring_inerr_delta=535108`, LVDS error/DPA deltas `0`, `post_end_clean=true` |
| P6B020 | lower lanes5+6, full 32 TDC-test channels per ASIC, pulse-high 4, 100 kHz | ASIC0..7 full32 from explicit SMB3/SMB5 XML, `rc=0` | `expected_fail` | `hist_total_delta=2916694`, `mts_total_delta=10191992`, `mts_discard_delta=0`, `ring_inerr_delta=9022633`, LVDS error/DPA deltas `0`, `post_end_clean=true` |
| P6E010 | lower lanes5+6, full 32 TDC-test channels per ASIC, pulse-high 3, 100 kHz | reused full32 config | `underfilled` | `hist_total_delta=42343`, `mts_total_delta=122418`, `mts_discard_delta=0`, `ring_inerr_delta=0`, LVDS error/DPA deltas `0`, `phase5_classification=PASS` |

## Interpretation

The current first failure is FEB-local. The SWB SC path is healthy enough for
control and CSR reads, but P6B010 proves the lower-pair MTS/ring path is not
stable even before full 32-channel multiplicity. LVDS error and DPA-unlock
deltas stay zero in these cases, so the next useful probe is MTS timestamp-delay
and ring input-error causality, not host DMA.

Do not claim SWB OPQ, host DMA, or disk timestamp closure from this checkpoint.
The next closure gate is P6-MTS-RING with zero MTS discard, zero ring input
errors, and accepted latency inside `0..2000` cycles for the same configured
ASIC/channel set.

## Continued Live Evidence

Run directory:

```text
firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_long_runs/20260430_live_continued_cycle1/
```

Raw files are intentionally ignored by git. This section is the reduced durable
checkpoint for the continued run.

| Case | Stimulus | Result | Key counters |
|---|---|---|---|
| P6B006 | ASIC5/lane5, one TDC-test channel, pulse-high 4, 100 kHz | `PASS` | `hist_total_delta=52627`, `mts_total_delta=168411`, `mts_discard_delta=0`, `ring_inerr_delta=0` |
| P6B007 | ASIC6/lane6, one TDC-test channel, pulse-high 4, 100 kHz | `PASS` | `hist_total_delta=81880`, `mts_total_delta=247011`, `mts_discard_delta=0`, `ring_inerr_delta=0` |
| P6B010 | lower ASIC5+6, one TDC-test channel each, pulse-high 4, 100 kHz | `unexpected_fail` | `hist_total_delta=144364`, `mts_total_delta=440880`, `mts_discard_delta=0`, `ring_inerr_delta=563053` |
| P6B020 | lower ASIC5+6, full 32 TDC-test channels each, pulse-high 4, 100 kHz | `expected_fail` | `hist_total_delta=168789`, `mts_total_delta=10226858`, `mts_discard_delta=0`, `ring_inerr_delta=7146776` |
| P6E010 | lower ASIC5+6, full 32 TDC-test channels each, pulse-high 3, 100 kHz | `underfilled` | `hist_total_delta=1462`, `mts_total_delta=6652`, `mts_discard_delta=0`, `ring_inerr_delta=0` |

Additional direct probes after this cycle:

| Probe | Result | Observation |
|---|---|---|
| lower ASIC5+6 one-channel expected latency `2000` | `FAIL` | `ring_inerr_delta=534743` |
| lower ASIC5+6 one-channel expected latency `4000` | `FAIL` | `ring_inerr_delta=368030` |
| lower ASIC5+6 one-channel expected latency `65535` | `FAIL` | `ring_inerr_delta=319653`; this is not a small positive-latency tail |
| lower ASIC5+6 header-sync, header channel 5 | `FAIL` | `ring_inerr_delta=748701` |
| lower ASIC5+6 header-sync, header channel 6 | `FAIL` | `ring_inerr_delta=782985` |
| lane5 header-sync control | `PASS` | `ring_inerr_delta=0` |
| lane6 header-sync control | `PASS` | `ring_inerr_delta=0` |

The header-sync controls are important: the injection mode can be clean for
each ASIC alone, but the pair still trips MTS/ring. That keeps the first blocker
at cross-ASIC timestamp/epoch/order coherence before or inside lower MTS.

Three 10 s stream-datagen SWB host-DMA controls also passed as raw-DMA partials:
each run captured `2048` nonzero words, `1024` nonpadding words, and `256`
event-builder payload words. First payload words differed
(`0x00088A0C`, `0x0008818F`, `0x0008894F`), so the buffer is not stale. The
offline reducer still reports `raw_payload_no_legacy_frames`, so this is not
FEB-link or disk timestamp closure.
