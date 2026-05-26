# MTS Inline ASIC-ID Fix + Type1-Down Debug Round

Date: 2026-05-26

## Verdict

- Track 1: **TRACK1_STILL_BROKEN**.
- Track 2: **TRACK2_DEFERRED_AFTER_TRACK1_GATE**; RTL trace completed, no on-board CSR sweep was run because Track 1 failed the STP gate.
- Per-ASIC histogram loop: **skipped by gate**. The post-fix STP did not show `0..3` / `4..7` ASIC IDs, so no histogram filter measurement was attempted.

## Track 1 Implementation

Edited MTS source:

- `mutrig_timestamp_processor/mts_processor.vhd`
  - version header bumped to `26.3.10`.
  - accepted-hit assignment now inlines the intended sideband derivation:
    - `BANK=UP`: `"00" & asi_hit_type0_channel(5 downto 4)`
    - `BANK=DW/DOWN`: `"01" & asi_hit_type0_channel(5 downto 4)`
  - `mux_slot_to_global_asic()` is still present for auditability but no longer called at the accepted-hit site.
- `mutrig_timestamp_processor/mts_processor_hw.tcl`
  - package version bumped to `26.3.10`.
- `mutrig_timestamp_processor/tb/mts_processor_asic_id_tb.vhd`
  - strengthened so payload channel low nibble intentionally differs from mux slot.
- `mutrig_timestamp_processor/BUG_HISTORY.md`
  - BUG-022-R extended with the 2026-05-26 STP-confirmed follow-up.

Diff stat:

```text
BUG_HISTORY.md       | 43 +++++++++++++++++++++++++
mts_processor.vhd    | 91 +++++++++++++++++++++++++++++++++++++++++++++++++---
mts_processor_hw.tcl |  7 ++--
3 files changed, 134 insertions(+), 7 deletions(-)
```

Generated-copy sync:

- `generated/synthesis/feb_system_v4/synthesis/submodules/mts_processor.vhd`
- `generated/synthesis/scifi_datapath_system_v4/synthesis/submodules/mts_processor.vhd`

Both generated copies contain `Version : 26.3.10` and the inline assignments at lines 1828/1830.

## Standalone Verification

- Directed sim: `make run_asic_id`
  - `mts_processor_asic_id_tb PASSED bank=UP`
  - `mts_processor_asic_id_tb PASSED bank=DW`
  - simulator `Errors: 0`
- Static screen:
  - Lint `Error (0)`
  - CDC `Violations (0)`
  - RDC `Violation (0)`
- Standalone Quartus synthesis:
  - `quartus_sh --flow compile mts_processor_syn -c mts_processor_syn`
  - full compilation successful, `0 errors`.
  - worst setup slack >= `1.272 ns`.
  - worst hold slack >= `0.158 ns`.

Important caveat: the standalone test still did not predict the board behavior after this inline fix. The next test must check every pipeline stage between `asi_hit_type0_channel[5:4]` and Type1 `data[38:35]`, not just final output in an isolated path.

## FEB Compile + Program

- `make qsys-syn`: passed, regenerated `arb_hit_type0_supercore`, `scifi_datapath_system_v4`, and `feb_system_v4`.
- `quartus_sh --flow compile top -c top`: passed.
  - Full compilation: `0 errors, 1642 warnings`.
  - Fitter: `0 errors, 40 warnings`.
  - SOF SHA256: `0092fb93399f50564f6afc03290ef61d038e27e375f381d6342231c7be87e5d4`.
  - Programmer checksum: `0x1A0A4220`.
  - Slow 1100 mV 85 C STA:
    - setup slack `0.387 ns`
    - hold slack `0.192 ns`
  - Worst reported across visible models:
    - setup slack `0.387 ns`
    - hold slack `0.059 ns`
- FEB programmed via `USB-BlasterII [7-2]`; programming passed with `0 errors`.
- `/dev/mudaq0` remained present after the required 20 s settle.
- Lane-8 soft reset write:
  - `sc_tool 2 write 0x04006 0x00000100`
  - response `OK`.
- MuTRiG configure:
  - canonical v4-address script
  - `SUMMARY pass=24 fail=0`.
- DPALOCK sanity:
  - `sc_tool 2 read 0x0400E 1`
  - payload `0x000001FF`.

## STP Capture

Capture:

- STP file: `syn/board_projects/fe_scifi_feb_v3/mutrig_cfg_lvds.stp`
- instance: `lvds_decoded`
- sample depth: 4096
- capture CSV: `STP/mts_inline_capture.csv`
- capture result: `stp_rc=0`
- stimulus:
  - injector mode `1`, header interval `1`, multiplicity `1`, header delay `100`, channel `0`, pulse high `5`.
  - `rc_tool send start-sequence --run 6000`.

The run-control sequence itself worked:

```text
after run-prepare STATUS=0x00001770 state=0x00
after sync        STATUS=0x11000003 state=0x11
after start-run   STATUS=0x12000004 state=0x12
after end-run     STATUS=0x13000000 state=0x13
```

## STP Decode

Key histograms from valid samples:

```text
MTS0 input slot channel[5:4] hist:
  0x0:240 0x3:186 0x2:166 0x1:125

MTS0 stp_hit_out_asic hist:
  0x0:190 0x8:94 0xC:60 0xE:59 0xD:51 0x4:48 0xA:40 0x7:33
  0x6:28 0x3:27 0x1:21 0xB:20 0x5:20 0xF:13 0x9:13

MTS0 Type1 out data[38:35] normalized hist:
  0x0:193 0x8:93 0xE:61 0xC:59 0xD:52 0x4:48 0xA:39 0x7:31
  0x6:27 0x3:25 0x1:21 0xB:20 0x5:20 0x9:14 0xF:12

Hist Type1-up tap data[38:35] normalized hist:
  0x0:190 0x8:95 0xE:59 0xC:59 0xD:51 0x4:48 0xA:40 0x7:33
  0x6:27 0x3:27 0xB:20 0x1:20 0x5:19 0xF:13 0x9:13
```

For the down bank:

```text
MTS1 input slot channel[5:4] hist:
  0x0:235 0x3:185 0x2:179 0x1:124

MTS1 stp_hit_out_asic hist:
  0x0:194 0x8:92 0xE:60 0xC:60 0xD:52 0x4:44 0xA:41 0x7:35
  0x6:27 0x3:27 0xB:20 0x1:20 0x5:19 0xF:14 0x9:13

Hist Type1-down tap data[38:35] normalized hist:
  0x0:193 0x8:91 0xC:61 0xE:59 0xD:52 0x4:48 0xA:40 0x7:33
  0x3:29 0x6:27 0x5:22 0x1:20 0xB:19 0xF:13 0x9:13
```

Expected after the fix:

- MTS0 `hit_out.asic` and Type1 `data[38:35]`: only `0,1,2,3`.
- MTS1 `hit_out.asic` and Type1 `data[38:35]`: only `4,5,6,7`.

Observed:

- Mux sideband `[5:4]` is healthy and carries all four slots.
- MTS `hit_out.asic` is still not mux-slot-derived.
- Type1 `data[38:35]` and hist taps match the bad `hit_out.asic` values.

Classification:

- **BUG_AT_MTS_PROPAGATION**, before histogram filtering.
- More precise than the earlier classification: the mux sideband is good; the accepted-hit inline assignment is present in the compiled source; the value is still wrong by `hit_out.asic`, so the remaining bug is inside the MTS hit pipeline between `hit_in.asic` and `hit_out.asic`, or in how the debug/test path observes that record field.

## Track 2 RTL Trace

`histogram_statistics_v2.vhd` control decode:

- source select constants:
  - `0`: Type0
  - `1`: Type1_up
  - `2`: Type1_down
- input port constants:
  - `0`: fill/direct
  - `1`: EXT0
  - `2`: EXT1
- CONTROL fields:
  - `[7:4]`: mode
  - `[3:2]`: in_port
  - `[8]`: key_unsigned
  - `[12]`: filter_enable
  - `[13]`: filter_reject
  - `[17:16]`: source_select
  - `[0]`: apply pulse

Relevant source evidence:

- fixed Type1 filter bits: `histogram_statistics_v2.vhd:427-441`, Type1 filter compares `data[38:35]`.
- EXT input routing: `histogram_statistics_v2.vhd:976-1013`, EXT0/EXT1 select the 87-bit extended streams and their `[86:39]` timestamps.
- ingress sampling: `histogram_statistics_v2.vhd:1293-1317`, EXT0/EXT1 are sampled readyless when `cfg_in_port` is EXT0/EXT1.
- filter call: `histogram_statistics_v2.vhd:1376-1388`.
- CONTROL write decode: `histogram_statistics_v2.vhd:2097-2125`.

Track 2 conclusion from RTL only:

- `CONTROL=0x00021019` is internally consistent for signed mode-1 Type1-down on EXT1 with filter enabled.
- `CONTROL=0x00020019` is the bounded first CSR experiment for Type1-down EXT1 with filter disabled.
- `CONTROL=0x00021119` is a useful secondary candidate only to test `key_unsigned=1`; it should not be the signed default range setting.
- Direct Type1-down through `in_port=0` is suspicious because `ingress_comb` has no explicit direct Type1-up/down sample branch; it samples Type0 or EXT0/EXT1. That is a likely separate histogram RTL bug, but not the active blocker in this round.

No Track 2 on-board CSR sweep was run because Track 1 failed the STP gate and the user asked to stop after failed STP rather than proceed to hist loops.

## Proposed Next Fix

Do not spend another board loop on the histogram filter yet. The filter is reading the bad Type1 field faithfully.

Smallest next RTL direction:

1. Add a dedicated `source_asic` pipeline that is independent of the existing `hit_type0_t` / `hit_type1_t` record propagation:
   - derive once from `asi_hit_type0_channel(5 downto 4)` plus BANK on the accepted transfer.
   - shift it beside the existing valid pipeline through padding, prediv, totcalc, and `hit_div`.
   - pack `aso_hit_type1_data[38:35]` and `extended_data_v[38:35]` from this dedicated sideband, not from `hit_out.asic`.
2. Add one-cycle STP shadows for each stage:
   - accepted `source_asic`
   - `hit_in.asic`
   - `hit_padding.asic`
   - `hit_prediv.asic`
   - `hit_totcalc.asic`
   - `hit_div(0).asic`
   - `hit_div(LPM_DIV_PIPELINE).asic`
   - final packed Type1 `data[38:35]`
3. Strengthen the standalone TB again to check continuous accepted hits with differing mux slot and payload low nibble on every cycle, not only isolated packets.

Expected result after that fix:

- MTS0 STP: only `0,1,2,3`.
- MTS1 STP: only `4,5,6,7`.
- Hist Type1-up/down taps: same values.
- Only then run per-ASIC `KEY_VALUE=i<<16` hist loops.

## Artifacts

- Compile summary: `compile_summary.txt`
- Program log: `quartus_pgm.log`
- MuTRiG configure log: `configure_mutrig.log`
- DPALOCK read: `dpalock_read.log`
- STP capture: `STP/mts_inline_capture.csv`
- STP decode summaries:
  - `STP/stp_decode_summary.txt`
  - `STP/stp_decode_crosscheck.txt`
- Final clean stop: `final_stop_sequence.log`
