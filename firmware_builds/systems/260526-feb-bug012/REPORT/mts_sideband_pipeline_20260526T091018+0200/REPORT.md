# MTS Source ASIC Sideband Pipeline Verification

## Scope

- RTL change: `mutrig_timestamp_processor/mts_processor.vhd` now carries a dedicated `source_asic_pipe` sideband from accepted Type0 input through padding, prediv, totcalc, divider, and hit-out stages.
- Version: `mutrig_timestamp_processor` bumped to `26.3.11`.
- Type1 output pack now uses `source_asic_pipe(SOURCE_ASIC_HIT_OUT_STAGE_CONST)` for `data[38:35]` instead of `hit_out.asic`.
- No commits or pushes were made in this round.

## Key RTL Locations

| Item | File:line |
|---|---|
| Version `26.3.11` changelog | `mutrig_timestamp_processor/mts_processor.vhd:136` |
| `source_asic_pipe` stage constants/type/signal | `mutrig_timestamp_processor/mts_processor.vhd:448`, `:456`, `:457` |
| STP shadow signals | `mutrig_timestamp_processor/mts_processor.vhd:460` |
| Accepted-transfer derivation from `asi_hit_type0_channel[5:4]` + `BANK` | `mutrig_timestamp_processor/mts_processor.vhd:1940`, `:1943` |
| Sideband stage shifts | `mutrig_timestamp_processor/mts_processor.vhd:1959`, `:1978`, `:1999`, `:2022`, `:2052` |
| Type1 ASIC field pack from sideband | `mutrig_timestamp_processor/mts_processor.vhd:2213`, `:2219`, `:2230` |

## Standalone Verification

| Check | Result |
|---|---|
| Directed sim `mts_processor_asic_id_tb` | PASS for `BANK=UP` and `BANK=DW`; `Errors: 0` |
| Full standalone TB `make run_all` | PASS; `Errors: 0` |
| Questa static screen | PASS; lint `Error (0)`, CDC `Violations (0)`, RDC `Violation (0)` |
| Standalone Quartus syn | PASS; 0 errors |
| Standalone timing | slow85 setup `+1.587 ns`, slow85 hold `+0.279 ns`; all checked corners positive |

Artifacts:
- `mutrig_timestamp_processor/tb/mts_processor_asic_id_20260526_sideband.log`
- `mutrig_timestamp_processor/tb/mts_processor_run_all_20260526_sideband.log`
- `mutrig_timestamp_processor/syn/quartus/static_screen_20260526_sideband.log`
- `mutrig_timestamp_processor/syn/quartus/mts_processor_syn_20260526_sideband.log`

## FEB Integration

| Step | Result |
|---|---|
| Generated-tree sync | Patched `mts_processor.vhd` copied into both `generated/synthesis/feb_system_v4/.../submodules/` and `generated/synthesis/scifi_datapath_system_v4/.../submodules/` |
| `make qsys-syn` | PASS; `qsys-generate succeeded` |
| FEB compile | PASS; 0 errors, 1665 warnings |
| SOF checksum | Quartus programmer checksum `0x1BD3702F`; `output_files/top.sof` SHA256 `f0c1a288be1adecbfece3d202870a50a3b24afede00ad6ee088a53a5466938ac` |
| FEB resources | 56,613 ALMs, 96,187 registers, 7,785,868 block-memory bits, 997 RAM blocks, 0 DSP |
| FEB timing | slow85 setup `+0.340 ns`, hold `+0.244 ns`; slow0 setup `+0.541 ns`, hold `+0.226 ns`; fast85 setup `+2.182 ns`, hold `+0.152 ns`; fast0 setup `+2.269 ns`, hold `+0.127 ns` |
| Program + restore | `quartus_pgm` PASS; lane-8 soft reset write OK; MuTRiG configure `SUMMARY pass=24 fail=0`; DPALOCK read `0x000001FF` |

Artifacts:
- `qsys_syn_20260526_sideband.log`
- `quartus_compile_20260526_sideband_stpcrc.log`
- `quartus_pgm_stpcrc.log`
- `configure_mutrig_after_stpcrc.log`
- `dpalock_stpcrc.log`

## SignalTap Captures

The initial triggers on `hist_type1_up_tap_out1_valid` and `mux_mutrig2processor_out_valid` both timed out. A subsequent active-run capture used an always-true lane-0-locked trigger and captured valid internal MTS samples while the run was active.

### Aggregate From Active-Run STP Burst

Files:
- `mts_sideband_capture_active_window.csv`
- `mts_sideband_capture_active_burst_0.csv` ... `mts_sideband_capture_active_burst_4.csv`
- `stp_burst_aggregate.json`
- `stp_input_accept_aggregate.json`

| Probe | Valid samples | Histogram |
|---|---:|---|
| `mts_preprocessor_0.stp_asi_hit_type0_accept_q` gated `stp_asi_hit_type0_channel_q[5:4]` | 1804 | `0x0: 1804` |
| `mts_preprocessor_0.stp_asi_hit_type0_accept_q` gated `stp_asi_hit_type0_channel_q[3:0]` | 1804 | `0x0: 1804` |
| `mts0 source_asic_stage0` | 1797 | `0x0: 1797` |
| `mts0 source_asic_stage_last` | 1797 | `0x0: 1797` |
| `mts0 stp_aso_hit_type1_asic_q` | 1797 | `0x0: 1797` |
| `mts1 source_asic_stage0` | 0 | no valid samples |
| `mts1 source_asic_stage_last` | 0 | no valid samples |
| `mts1 stp_aso_hit_type1_asic_q` | 0 | no valid samples |

Interpretation:
- The sideband itself did not corrupt the observed source ID: accepted input `0x0` propagated as `0x0` through stage0, stage_last, and the Type1 ASIC pack.
- The capture did not observe source IDs `1..3` or `4..7`; the first limiting point is the accepted input into MTS, not the sideband pipeline.
- The top-level mux and hist tap probes stayed zero-valid in this image even while internal MTS valid and histogram counters were active, so they are not reliable proof points for this specific capture.

## Per-ASIC Histogram Loop

Config:
- Range: `LEFT_BOUND=-1000`, `RIGHT_BOUND=3096`, `BIN_WIDTH=16`, `N_BINS=256`.
- Filter enabled, `KEY_VALUE = ASIC_INDEX << 16`.
- Type1-up control: `0x00011015`.
- Type1-down control: `0x00021019`.
- Injector: mode=1 header-sync, header_interval=1, multiplicity=1, header_delay=100, header_ch=0, pulse_high=5.

| ASIC | Bank | KEY_VALUE | Total counts | Peak cycle | FWHM cycles | Active TOTAL_HITS | Verdict |
|---:|---|---:|---:|---:|---:|---:|---|
| 0 | Type1-up | `0x00000000` | 3,235,099 | 1248 | 928 | 1,048,575 | counts, broad/multi-peak |
| 1 | Type1-up | `0x00010000` | 0 | NA | NA | 1,048,575 | filter rejects |
| 2 | Type1-up | `0x00020000` | 0 | NA | NA | 1,048,575 | filter rejects |
| 3 | Type1-up | `0x00030000` | 0 | NA | NA | 1,048,575 | filter rejects |
| 4 | Type1-down | `0x00040000` | 0 | NA | NA | 0 | bank silent |
| 5 | Type1-down | `0x00050000` | 0 | NA | NA | 0 | bank silent |
| 6 | Type1-down | `0x00060000` | 0 | NA | NA | 0 | bank silent |
| 7 | Type1-down | `0x00070000` | 0 | NA | NA | 0 | bank silent |

Type1-down no-filter smoke:
- Control `0x00020019`, `KEY_VALUE=0`.
- Active `TOTAL_HITS=0`, active `LAST_INTERVAL_TOTAL_HITS=0`, bin total `0`.
- Verdict: `BANK_SILENT`.

Artifacts:
- `HIST_REPORT.md`
- `phase5_results.json`
- `phase5_transcript.log`
- `ASIC0/bins.csv` ... `ASIC7/bins.csv`
- `TYPE1_DOWN_NOFILTER/bins.csv`

## Verdict

`PARTIAL: SIDE_BAND_OK_FOR_OBSERVED_ASIC0_ONLY`

The sideband pipeline is not the first failing point in the captured active window: MTS accepted input already carried only channel/slot `0x00`, and the sideband preserved that value through the output pack. The per-ASIC histogram loop still only accepts KEY=0 because this run did not present ASIC1..3 IDs to `mts_preprocessor_0`; Type1-down remains independently silent even with filtering disabled.

## Recommended Next Debug

1. Treat ASIC1..3 as an upstream stimulus or mux-source issue until a capture shows `stp_asi_hit_type0_channel_q[5:4]` values `1..3` at `mts_preprocessor_0`.
2. Use the already-added `stp_asi_hit_type0_accept_q` / `stp_asi_hit_type0_channel_q[5:0]` shadows as the primary next STP proof point; the Qsys-level mux and hist tap probes were zero-valid in this capture despite active internal MTS and histogram counters.
3. Debug Type1-down separately: `mts_preprocessor_1` had no internal valid samples and the histogram Type1-down no-filter smoke had `TOTAL_HITS=0`.
