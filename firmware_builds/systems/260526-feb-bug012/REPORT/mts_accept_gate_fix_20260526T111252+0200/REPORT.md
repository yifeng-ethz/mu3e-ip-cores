# MTS Accept-Gate Fix Round

## Objective

Locate and fix the MTS input-acceptance gate that rejected mux slots 1..3 after the mux had already proven that `channel[5:4]` carried slots 0..3.

## RTL Audit

| Location | Classification | Verdict |
|---|---|---|
| `mutrig_timestamp_processor/mts_processor.vhd:247` | data path | `asi_hit_type0_channel[5:0]` is a packed sideband: `[5:4]` is the mux slot, `[3:0]` is the local MuTRiG channel. |
| `mutrig_timestamp_processor/mts_processor.vhd:1607-1615` | gate | Added `proc_hit_type0_channel_gate_comb`; it compares only `asi_hit_type0_channel[3:0]` against `ENABLED_CHANNEL_LO..HI`. |
| `mutrig_timestamp_processor/mts_processor.vhd:1646-1654` | gate | `hit_in_ok` now requires `hit_type0_low_channel_in_window=1`, so slot bits no longer reject valid local channels and out-of-window low channels are still rejected. |
| `mutrig_timestamp_processor/mts_processor.vhd:1956-1963` | data path | Accepted-hit ASIC sideband still derives from `asi_hit_type0_channel[5:4]` plus `BANK`. |
| `mutrig_timestamp_processor/mts_processor.vhd:2231-2249` | data path | Type1 `data[38:35]` and STP shadows pack `source_asic_pipe(last)`. |
| `mutrig_timestamp_processor/mts_processor.vhd:2288-2297` | gate / packet tracking | Packet-open tracking now indexes from `asi_hit_type0_channel[3:0]`, not the full 6-bit mux-qualified channel. |

## RTL Changes

- Bumped MTS IP packaging to `26.3.12` in `mts_processor_hw.tcl`.
- Updated `BUG_HISTORY.md` BUG-022-R follow-up with the missed acceptance-gate diagnosis.
- Strengthened `tb/mts_processor_asic_id_tb.vhd`:
  - accepts slot 1 / low channel 1 (`channel=17`),
  - accepts slot 2 / low channel 2 (`channel=34`),
  - accepts slot 3 / low channel 3 (`channel=51`),
  - rejects slot 1 / low channel 4 (`channel=20`) for enabled window 0..3.

## Standalone Verification

| Check | Result | Evidence |
|---|---:|---|
| Prefix test before RTL fix | FAIL as expected | `tb/mts_processor_asic_id_prefix_20260526_accept_gate.log` caught slot1/low4 behavior. |
| Directed sim after fix | PASS | `tb/mts_processor_asic_id_20260526_accept_gate.log`: `PASSED bank=UP`, `PASSED bank=DW`, simulator `Errors: 0`. |
| RTL style checker | Legacy baseline fail | `rtl_style_check.py` reports pre-existing style debt; not refactored in this focused fix. |
| Questa static screen | PASS | `syn/quartus/static_screen_20260526_accept_gate.log`: Lint Error 0, CDC Violations 0, RDC Violation 0. |
| Standalone synthesis | PASS | `syn/quartus/mts_processor_syn_20260526_accept_gate.log`: worst setup slack `+1.606 ns`, worst hold slack `+0.153 ns` across reported corners. |

## FEB Integration

| Step | Result |
|---|---|
| Generated RTL sync | `feb_system_v4` and `scifi_datapath_system_v4` generated `submodules/mts_processor.vhd` both contain `26.3.12` and the low-nibble acceptance gate. |
| `make qsys-syn` | PASS; Qsys picked up `mts_preprocessor 26.3.12.526`. |
| FEB compile | PASS; 0 errors, 1665 warnings. |
| FEB resources | 56,941 ALMs, 96,135 registers, 7,785,868 block memory bits, 997 RAM blocks, 0 DSP. |
| FEB timing | worst setup slack `+2.376 ns`, worst hold slack `+0.118 ns` in the compile log. |
| Programmed SOF | `output_files/top.sof`, programmer checksum `0x1BD421E4`, sha256 `4bf1a1d8a675163113fbb0f5b0451d544d266f3641f1e787bd8e17a8b0c2bea8`. |
| Board recovery | `/dev/mudaq0` present; no PCIe recovery needed. |
| Lane 8 soft-reset | `sc_tool 2 write 0x04006 0x00000100 --quiet` returned OK. |
| MuTRiG configure | `SUMMARY pass=24 fail=0`. |
| DPALOCK sanity | `sc_tool 2 read 0x0400E 1 --quiet`: `0x000001FF`. |

## SignalTap Attempt

The active `.stp` contains only one instance, `lvds_decoded`; the stale helper `stp_acquire_mts.tcl` pointed at a non-existent `mts_input_probe` instance and failed. Acquisition was retried through `stp_acquire_lvds.tcl`.

Three captures exported successfully but did not trigger current MTS activity:

| Capture | Trigger attempted | Outcome |
|---|---|---|
| `mts_accept_gate_capture_lvds.csv` | original `hist_type1_up_tap_out1_valid` | timeout, 0 accepted samples decoded |
| `mts_accept_gate_capture_muxtrig_after_reconfig.csv` | runtime-edited mux valid expression | timeout, 0 mux-valid / accepted samples decoded |
| `mts_accept_gate_capture_first_run.csv` | mux valid after hist/injector preconfig | timeout, 0 mux-valid / accepted samples decoded |

Because the histogram counters and bins prove Type1-up traffic exists under the same image, these timeout CSVs are not accepted as valid post-fix STP proof. The likely issue is SignalTap trigger/session metadata or the single `lvds_decoded` sample-clock instance not being a reliable MTS-domain acquisition point. A dedicated MTS-clock SignalTap instance is the next clean visibility fix.

## On-Board Histogram Result

Per-ASIC loop used the canonical range `LEFT=-1000`, `RIGHT=3096`, `BIN_WIDTH=16`, filter enabled, `KEY_VALUE = ASIC_INDEX << 16`.

| ASIC | Bank | KEY_VALUE | Peak cycle | FWHM cycles | Total counts | Active TOTAL_HITS | Verdict |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 | Type1-up | `0x00000000` | 1024.0 | 928 | 3,142,999 | 1,048,575 | counts |
| 1 | Type1-up | `0x00010000` | NA | NA | 0 | 1,048,575 | filter rejects |
| 2 | Type1-up | `0x00020000` | NA | NA | 0 | 1,048,575 | filter rejects |
| 3 | Type1-up | `0x00030000` | NA | NA | 0 | 1,048,575 | filter rejects |
| 4 | Type1-down | `0x00040000` | NA | NA | 0 | 0 | bank silent |
| 5 | Type1-down | `0x00050000` | NA | NA | 0 | 0 | bank silent |
| 6 | Type1-down | `0x00060000` | NA | NA | 0 | 0 | bank silent |
| 7 | Type1-down | `0x00070000` | NA | NA | 0 | 0 | bank silent |

Type1-down no-filter smoke also produced `TOTAL_HITS=0`, bin total 0: `BANK_SILENT`.

## Verdict

`STANDALONE_FIX_PASS_BOARD_STILL_BROKEN`.

The low-nibble acceptance-gate fix is correct in RTL simulation/static/synthesis and is present in the programmed FEB image, but the board histogram result still only accepts `KEY=0` on Type1-up. Since ASIC1..3 have saturated Type1-up `TOTAL_HITS` but zero bins for `KEY=i<<16`, the next bug is still in the source-ID path or histogram fixed-filter interpretation, not in Type1-up traffic generation. Type1-down remains a separate bank-silent bug.

## Recommended Next Step

Compile a dedicated MTS-clock SignalTap instance, not folded into `lvds_decoded`, with probes:

- MTS0: `asi_hit_type0_valid/ready/channel[5:0]`, `hit_in_ok`, `stp_asi_hit_type0_accept_q`, `source_asic_pipe(0)`, `source_asic_pipe(last)`, `stp_aso_hit_type1_asic_q`, `aso_hit_type1_extended_0_data[38:35]`.
- MTS1: same set for the down bank.
- Histogram: the exact fixed-filter key slice and compare result around the Type1-up path.

That capture should be triggered on `asi_hit_type0_valid && asi_hit_type0_ready` in the MTS clock domain.
