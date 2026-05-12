# RC-Readyless SignalTap Capture Report

Build: `v3_pretest-260511-rc-readyless-260511`
Date: 2026-05-12
Revision: `top_stp_phase4_rc_readyless_gap`

## Status

The focused Phase 4 SignalTap gap capture is complete. It disproves the
remaining run-control broadcast hypothesis: start-run reaches the emulator
control leaf, the lane-0 emulator enters `run_generating`, and `frame_rst`
deasserts. The zero-hit blocker is now at the first byte-stream output:
`aso_tx8b1k_valid` never asserts and `aso_tx8b1k_data` stays at idle `0x1bc`.

Preliminary simulation/source confirmation matches the board: the generated
Qsys instance leaves `BYTE_STREAM_ENABLE=false`, while the downstream datapath
is wired to `emulator_mutrig_N.tx8b1k`. In RTL, that build axis intentionally
ties `aso_tx8b1k_valid` to `0` and drives K28.5 idle.

## Artifacts

Capture directory:

```text
signaltap/captures/phase4_rc_readyless_gap_20260512_042348
```

Primary files:

- `preflight.log` - programmed-image hash, SWB link-lock sampling, SC sanity.
- `precondition_local.log` - `LOCAL_CMD=0x10` and `0x11` accepted before the
  capture.
- `local_start_run_stim.log` - capture stimulus, `LOCAL_CMD=0x12`.
- `local_start_run_stp.log` - SignalTap arm/capture/export log.
- `local_start_run.vcd` - exported SignalTap VCD.
- `local_start_run_vcd_summary.log` - parsed first-high and final-value
  summary.
- `post_capture_counters.log` - post-capture histogram, HSS, emulator CSR, and
  cleanup reads.
- `sim_byte_stream_disable.log` - minimal Questa confirmation of the disabled
  byte-stream build axis.

Programming and STP hashes:

- STP SOF:
  `7dd7f9303a7551d4b0074136a38f2b818ad37e1d20ec4a9decfd6dd21e7f03ad`
- STP file:
  `a21b5a3fb46d31fa26bf797cbf819f2313161fb1fb14a4ae120fc05d1b51a3b7`

## Hardware Capture Result

The capture was triggered by rising
`run_control_splitter|out15_valid` while issuing `LOCAL_CMD=0x12` through the
System Console `LOCAL_CMD` CSR path.

First-high timing from `local_start_run_vcd_summary.log`:

| Signal | First high |
|---|---:|
| `runctl_mgmt_host_valid` | `127500 ps` |
| `run_control_mux.out_valid` | `128500 ps` |
| `run_control_splitter.out15_valid` | `128500 ps` |
| `emulator_ctrl_splitter.out0_valid` | `128500 ps` |
| `emulator_mutrig_0.asi_ctrl_valid` | `128500 ps` |
| `run_generating` | `129500 ps` |
| `emulator_mutrig_0.aso_tx8b1k_valid` | never |

Values at the `out15_valid` trigger:

| Signal | Value |
|---|---:|
| `run_control_mux.out_data` | `0x008` |
| `run_control_splitter.out15_data` | `0x008` |
| `emulator_ctrl_splitter.out0_data` | `0x008` |
| `emulator_mutrig_0.asi_ctrl_data` | `0x008` |
| `ctrl_state_q` | `0x004` |
| `aso_tx8b1k_data` | `0x1bc` |

Final values:

| Signal | Value |
|---|---:|
| `run_generating` | `1` |
| `frame_rst` | `0` |
| `aso_tx8b1k_valid` | `0` |
| `aso_tx8b1k_data` | `0x1bc` |

Post-capture counters still show zero hit flow:

- Histogram snapshot `0x0A90B..0x0A911`: `BANK_STATUS=1`,
  `PORT_STATUS=0xFF`, `TOTAL_HITS=0`, drops/underflow/overflow all `0`.
- HSS0 and HSS1 frame-assembly actual-hit counters remain `0`.
- Emulator lane-0 CSR is sane: UID `0x454D5554`, meta `0x1A0301FA`,
  `CENTRAL=1`, `MUTRIG_FORMAT=0x00000022`, `RATES=0x01000800`,
  `PRNG_SEED=0xDEADBEEF`, `LANE_ENABLE=0x00010001`.
- End-run cleanup via `LOCAL_CMD=0x13` was accepted.

## Integration Root Cause Candidate

Generated Qsys evidence:

- `syn/feb_system_v3.sopcinfo` reports `BYTE_STREAM_ENABLE=false` for
  `data_path_subsystem_emulator_mutrig_0` and the other emulator instances.
- The same `.sopcinfo` wires
  `data_path_subsystem_emulator_mutrig_N.tx8b1k` to
  `data_path_subsystem_decoded_lane_mux_N.in1` for lanes `0..7`.

RTL evidence:

- `emulator_mutrig/rtl/emulator_mutrig.sv` generates the byte-stream frame
  assembler only when `BYTE_STREAM_ENABLE` is true.
- In the `no_byte_stream_gen` branch, the RTL ties
  `aso_tx8b1k_data` to `{1'b1, K28_5}` and
  `aso_tx8b1k_valid` to `1'b0`.
- `emulator_mutrig/rtl/emulator_mutrig_qsys_lane.sv` defaults
  `BYTE_STREAM_ENABLE` to `1'b0` and passes it through to the core.

Simulation confirmation:

- `sim_byte_stream_disable.log` elaborates `emulator_mutrig` with
  `LANE_COUNT=1` and `BYTE_STREAM_ENABLE=0`.
- With start-run held on the control input, Questa reports
  `tx_valid=0` and `tx_data=1bc`.

The hardware and RTL/sim facts are now coherent: the system consumes the
optional byte stream, but the emulator instances are built in the direct
`hit_type0` output mode where the byte stream is intentionally disabled.

## Next Fix Loop

The next rc-readyless integration fix should choose exactly one datapath
contract and then rebuild/retest:

1. If the current decoded-lane mux path is kept, set
   `BYTE_STREAM_ENABLE=true` on all eight `emulator_mutrig_N` Qsys instances,
   regenerate `feb_system_v3`, compile a new debug image, and rerun the same
   STP/counter gate.
2. If the intended production path is the newer direct `hit_type0` stream,
   rewire the datapath to consume `emulator_mutrig_N.hit_type0` instead of
   `tx8b1k`, then regenerate, compile, and retest.

The previous readyless splitter blocker is closed. Phase 4 remains failed until
hardware shows positive hit flow and the downstream histogram/HSS/SWB/RDMA
ledger closes.

## Follow-Up Fix Candidate

The next loop selected option 1 above: keep the current decoded-lane mux path
and enable the optional byte-stream output on every emulator instance.

Evidence recorded so far:

- Qsys recipe:
  `firmware_builds/systems/v3_pretest-260511/script/update_v3_byte_stream_contract.tcl`.
- Regeneration status:
  `syn/feb_system_v3_qsys_generate_20260512_044214_byte_stream_fix_isolated.status`,
  `exit_code=0`, `error_count=0`.
- Regenerated `.sopcinfo`: eight `BYTE_STREAM_ENABLE` parameters under
  `data_path_subsystem_emulator_mutrig_N` and the existing
  `tx8b1k -> decoded_lane_mux_N.in1` lane wiring preserved.
- Directed sim:
  `tb_int/sim_byte_stream_axis_20260512_0443/summary.txt`; the disabled build
  has zero valid pulses, while the enabled build has 16 valid pulses with first
  valid at `12708000 ps`.

Compile and hardware retest evidence:

- Non-STP compile:
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_top_20260512_0445_byte_stream_fix.console.log`,
  `Quartus Prime Full Compilation was successful. 0 errors, 1587 warnings`.
- SOF SHA-256:
  `c8239ef1ab2f0bc21da91e0de41ca4c452531cb363677c43c9fb3f7930712dcd`.
- Hardware smoke directory:
  `hw_smoke/phase4_byte_stream_fix_20260512_0526/`.
- JTAG run-control smoke:
  `jtag_setup_start.log` reaches `runctl_last_cmd=0x00020012`; teardown reaches
  `runctl_last_cmd=0x00020013`.
- Rate-configured post-selected histogram:
  `hist_rate_dump.log` reports `underflow_count 0`, `overflow_count 0`,
  `dropped_hits 0`, and `last_interval_total_hits 7995716`; the matching
  `hist_rate_bins.csv` sums to `7995716`. The bridge was selected to `post`
  with `post_hit_filter_enabled 0`, so this is word-counter activity, not
  legal-hit conservation evidence.
- Remaining blocker:
  `sc_hss0_after_hist_rate.log` and `sc_hss1_after_hist_rate.log` keep
  frame-assembly declared/actual/missing counters at zero.
- Follow-up pre-HSS probe:
  `hw_smoke/phase4_pre_hss_probe_20260512_0541/` selected
  `hist_snoop_source=pre`; `hist_pre_rate_dump.log` reports
  `live_select_post 0` and all histogram stats zero, while
  `hist_pre_rate_bins.csv` has `sum(count)=0`. MTS-visible totals, rbCAM
  payload counters, and HSS counters also remain zero.

This accepts the byte-stream Qsys contract as the fix for the captured
`aso_tx8b1k_valid=0` boundary, but it does not close Phase 4. The next STP/CSR
gap is upstream of the pre-HSS stream: post-selected histogram word-counter
activity is nonzero, while `histogram_ingress_bridge_0.pre_in` /
`mts_preprocessor_0.hit_type1_out`, rbCAM, and HSS remain zero.

Prepared STP source for that next gap:

- Generator:
  `script/generate_phase4_pre_hss_gap_stp.py`.
- STP:
  `signaltap/phase4_pre_hss_gap.stp`.
- Node Finder report:
  `signaltap/phase4_pre_hss_gap_nodes.md`, `76/76` probes found and `0`
  missing against the current mapped Quartus database.

This is not yet a compiled or loadable STP image. The next compile loop should
import it into a dedicated pre-HSS SignalTap revision, preferably
`top_stp_phase4_pre_hss_gap`, before programming.
