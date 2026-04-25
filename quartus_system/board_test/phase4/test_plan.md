# Phase 4 Math/TLM/RTL/Board Test Plan

Date: 2026-04-25

This plan extends the canonical Phase 4 board plan in
[`../doc/TEST_PLAN.md`](../doc/TEST_PLAN.md) with a reproducible math,
TLM, RTL-simulation, plotting, and on-board evidence chain for the
FE SciFi emulator/histogram datapath.

## Scope

The Phase 4 question is whether the 8-lane `emulator_mutrig` traffic source,
the downstream buffering/reordering path, and `histogram_statistics_0` behave
as a bounded-latency, bounded-throughput path under the tested rate sweep.

Covered here:

- math model for generator probability, histogram acceptance cap, and dispatch
  latency support;
- standalone HDL/TLM simulation for rate and latency reference curves;
- RTL integration-simulation evidence from `ts_soak_exact5k_stable`;
- DISLIN plots generated from CSV artifacts;
- board Phase 4 emulator/histogram and stage-counter evidence.

Not closed by this plan:

- Phase 4.3 SignalTap trigger captures in a nostp image;
- literal host-driven channel-mask sweep until the active emulator path exposes
  a masked-pulse source or equivalent CSR/conduit driver.

## Source Artifacts

| Layer | Artifact |
|---|---|
| Math report | [`MATH_REPORT.md`](MATH_REPORT.md) |
| TLM/RTL report | [`TLM_REPORT.md`](TLM_REPORT.md) |
| Board report | [`TEST_REPORT.md`](TEST_REPORT.md) |
| HDL/TLM model | [`tlm/phase4_latency_tlm.sv`](tlm/phase4_latency_tlm.sv) |
| Plot renderer | [`scripts/phase4_dislin_plots.c`](scripts/phase4_dislin_plots.c) |
| Artifact collector | [`scripts/collect_phase4_artifacts.py`](scripts/collect_phase4_artifacts.py) |
| Generated artifacts | [`artifacts/`](artifacts/) |
| Existing RTL sim run inputs | [`inputs/rtl_ts_soak_exact5k_stable/`](inputs/rtl_ts_soak_exact5k_stable/) |
| Existing board Phase 4 run input | [`inputs/board/phase4_emulator_20260425_hist_fifo_depth_full_sweep_flushaware.md`](inputs/board/phase4_emulator_20260425_hist_fifo_depth_full_sweep_flushaware.md) |
| Existing stage probe input | [`inputs/board/phase4_stage_probe_20260425_hist_fifo_depth_rate0800_flushaware.md`](inputs/board/phase4_stage_probe_20260425_hist_fifo_depth_rate0800_flushaware.md) |

## Procedure

1. Run the standalone HDL/TLM model.

   ```bash
   bash quartus_system/board_test/phase4/scripts/run_phase4_tlm.sh
   ```

   Expected outputs:

   - `artifacts/phase4_tlm_latency_hist.csv`
   - `artifacts/phase4_tlm_rate_sweep.csv`
   - `artifacts/phase4_tlm_summary.txt`
   - `artifacts/phase4_tlm_run.log`

2. Re-run the RTL datapath measurement if the existing
   `ts_soak_exact5k_stable` evidence needs to be refreshed.

   ```bash
   TB_DP_VSIM_ARGS='+TB_DP_PRE_RBCAM_MEAS +TB_DP_RUN_CYCLES=5000 +TB_DP_HIT_RATE=ffff +TB_DP_SHORT_MODE=1 +TB_DP_REPORT_DIR=/tmp/phase4_rtl_refresh' \
     bash quartus_system/tb_int/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
   ```

   Copy the refreshed `emulator_dispatch_latency_hist.csv` and `run.log` into a
   reviewed report directory before changing the collector's RTL input path.
   The current reports intentionally use the already reviewed
   `ts_soak_exact5k_stable` run copied under
   `quartus_system/board_test/phase4/inputs/`.

3. Collect RTL and board evidence and render DISLIN figures.

   ```bash
   bash quartus_system/board_test/phase4/scripts/render_phase4_plots.sh
   ```

   Expected outputs:

   - `artifacts/phase4_summary.json`
   - `artifacts/phase4_rate_sweep.csv`
   - `artifacts/phase4_rtl_latency_hist.csv`
   - `artifacts/phase4_latency_tlm_vs_rtl.png`
   - `artifacts/phase4_latency_tlm_vs_rtl.svg`
   - `artifacts/phase4_rate_sweep.png`
   - `artifacts/phase4_rate_sweep.svg`

4. Confirm plotting quality before accepting the report.

   Acceptance criteria:

   - DISLIN logs report `Warnings: 0`;
   - no curve, legend, axis label, caption, or tick text is clipped;
   - latency plot uses cycles on x and probability per cycle bin on y;
   - rate plot uses `rate_word / 0x0100` on x and accepted histogram rate in
     Mhit/s on y;
   - model curves are explicitly labeled as model evidence, not board or RTL
     measurements.

5. Board test commands for a new run, using the established Phase 4 scripts:

   ```bash
   python3 quartus_system/board_test/script/run_phase4_emulator.py \
     --measure-after-end \
     --output quartus_system/board_test/reports/phase4_emulator_<date>.md

   python3 quartus_system/board_test/script/probe_phase4_stage_counters.py \
     --hit-rate 0x0800 \
     --iterations 2 \
     --output quartus_system/board_test/reports/phase4_stage_probe_<date>.md
   ```

   The existing evidence files from 2026-04-25 are the current reference inputs
   for this report set.

## Pass Criteria

The Phase 4 math/TLM/RTL/board reporting package passes when:

- the TLM run finishes with 0 errors and 0 warnings;
- RTL integration simulation has no failing checks and reports no
  histogram-underflow, histogram-overflow, or dropped-hit status in the measured
  path;
- the TLM saturation cap and board knee agree to within a few percent after
  accounting for board path overhead;
- the board primary run reports `DROPPED_HITS delta = 0` and a clean post-end
  flush;
- the board rate sweep doubles up to the knee and documents the saturation
  point;
- reports link to reproducible CSVs, logs, and DISLIN PNG/SVG plots.
