# Phase 4 Math/TLM/RTL/Board Test Plan

Date: 2026-04-25

This plan extends the canonical Phase 4 board plan in
[`../doc/TEST_PLAN.md`](../doc/TEST_PLAN.md) with a reproducible math,
TLM, RTL-simulation, DISLIN plotting, and on-board evidence chain for the
FE SciFi emulator/histogram datapath.

## Scope

The Phase 4 question is whether the 8-lane `emulator_mutrig` traffic source,
the downstream buffering/reordering path, and `histogram_statistics_0` behave
as a bounded-latency, bounded-throughput path at the physical MuTRiG wire
limit:

```text
25 Mhit/s per MuTRiG
100 Mhit/s per 4-MuTRiG datapath
200 Mhit/s into the 8-MuTRiG histogram
```

## Architect Requirements Captured

The Phase 4 evidence must explicitly implement and check the following review
requirements:

- the allowed physical rate is capped at 25 Mhit/s per MuTRiG, from the
  MuTRiG wire-speed limit and short-hit size;
- each 4-MuTRiG datapath is therefore capped at `25 * 4 = 100 Mhit/s`;
- the histogram consumes two datapaths, so the full histogram target is
  `25 * 8 = 200 Mhit/s`;
- histogram clipping before 200 Mhit/s is a failure of the target-rate
  evidence, even if the run reports zero dropped hits;
- the RTL architecture is expected to support 200 Mhit/s if coalescing is
  correct, because 8 MuTRiG map to 256 channels and each channel is one bin;
- the histogram update path may write only one channel every 2 cycles, but the
  coalescing queue must merge repeated hits by tag while backpressured;
- each coalescing queue element is `(tag, kick_count)`, and a new incoming hit
  to an existing tag increments that element's `kick_count` rather than
  allocating a new queue entry;
- the TLM must model deterministic histogram drain and continuous incoming hit
  trains for iid channel Poisson dark noise, 8-channel physical clusters,
  mixed iid/cluster traffic, and injection/all-channel super-bursts;
- queue-depth reporting must include either no-drop minimal depth or practical
  depth regions for 5%, 1%, and 1 ppm drop probability;
- the MuTRiG emulator latency model must be derived from the MuTRiG source RTL,
  not from the previously observed RTL latency histogram alone;
- the existing RTL dispatch-latency histogram is treated as discrepant because
  it does not obey the short-frame timing expected from the Mu3e slides and the
  current emulator RTL constants;
- the injector setup must support one channel enabled and injection pulse
  offset sweeps relative to the MuTRiG frame preamble/frame mark;
- for each injection offset, the expected response is a deterministic delta
  delay function, and sweeping the offset should cover the full frame range;
- in injection mode 2, the injection pulse is not synchronized to the MuTRiG
  frame, so low-rate latency spans 0 to 1 frame;
- as rate increases toward the MuTRiG wire-speed limit, L2 FIFO queueing can
  grow the observed span toward 0 to 2 frames.

Covered here:

- math model for generator probability, physical rate cap, coalescing queue
  depth, and injection latency support;
- standalone HDL/TLM simulation for rate and short-frame latency reference
  curves;
- Python TLM for the tag/kick-count coalescing queue and MuTRiG injection
  latency envelope;
- RTL source references for MuTRiG frame timing, L2 FIFO behavior, injection
  modes, and histogram coalescing;
- existing RTL integration-simulation evidence from `ts_soak_exact5k_stable`;
- DISLIN plots generated from CSV artifacts;
- board Phase 4 emulator/histogram and stage-counter evidence.

Not closed by the current evidence:

- board rate signoff at 200 Mhit/s; the existing board image clips near
  135 Mhit/s;
- refreshed RTL injection offset sweep proving the 0-to-1-frame low-rate span
  and 0-to-2-frame saturation span;
- Phase 4.3 SignalTap trigger captures in a nostp image.

## Source Artifacts

| Layer | Artifact |
|---|---|
| Math report | [`MATH_REPORT.md`](MATH_REPORT.md) |
| TLM/RTL report | [`TLM_REPORT.md`](TLM_REPORT.md) |
| Board report | [`TEST_REPORT.md`](TEST_REPORT.md) |
| HDL/TLM model | [`tlm/phase4_latency_tlm.sv`](tlm/phase4_latency_tlm.sv) |
| Queue/MuTRiG TLM | [`scripts/phase4_queue_tlm.py`](scripts/phase4_queue_tlm.py) |
| Plot renderer | [`scripts/phase4_dislin_plots.c`](scripts/phase4_dislin_plots.c) |
| Artifact collector | [`scripts/collect_phase4_artifacts.py`](scripts/collect_phase4_artifacts.py) |
| Generated artifacts | [`artifacts/`](artifacts/) |
| MuTRiG source RTL | [`../../../emulator_mutrig/rtl/`](../../../emulator_mutrig/rtl/) |
| Histogram coalescing RTL | [`../../../histogram_statistics/rtl/coalescing_queue.vhd`](../../../histogram_statistics/rtl/coalescing_queue.vhd) |
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

2. Generate the queue-depth and MuTRiG injection-latency model artifacts.

   ```bash
   python3 quartus_system/board_test/phase4/scripts/phase4_queue_tlm.py
   ```

   Expected outputs:

   - `artifacts/phase4_physical_rate_limits.csv`
   - `artifacts/phase4_queue_sweep.csv`
   - `artifacts/phase4_queue_depth_regions.csv`
   - `artifacts/phase4_mutrig_latency_model.csv`

3. Re-run the RTL datapath measurement if the existing evidence needs to be
   refreshed.

   ```bash
   TB_DP_VSIM_ARGS='+TB_DP_PRE_RBCAM_MEAS +TB_DP_RUN_CYCLES=5000 +TB_DP_HIT_RATE=ffff +TB_DP_SHORT_MODE=1 +TB_DP_REPORT_DIR=/tmp/phase4_rtl_refresh' \
     bash quartus_system/tb_int/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
   ```

   Copy the refreshed `emulator_dispatch_latency_hist.csv` and `run.log` into a
   reviewed report directory before changing the collector's RTL input path.
   The current reports intentionally use the already reviewed
   `ts_soak_exact5k_stable` run copied under
   `quartus_system/board_test/phase4/inputs/`.

4. Run the calibrated periodic-injector RTL sweep for injection mode 2.

   ```bash
   bash quartus_system/tb_int/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_hist_rate_sweep.sh
   ```

   Required refresh for latency signoff:

   - one channel enabled;
   - `TB_DP_USE_PERIODIC_INJECTOR`;
   - `TB_DP_INJECT_MODE=2`;
   - `TB_DP_SHORT_MODE=1`;
   - zero background hit rate for the low-rate offset sweep;
   - higher per-MuTRiG background rate points up to 25 Mhit/s to expose L2 FIFO
     queueing delay;
   - a full injection offset sweep across `FRAME_INTERVAL_SHORT=910`.

5. Collect RTL and board evidence and render DISLIN figures.

   ```bash
   bash quartus_system/board_test/phase4/scripts/render_phase4_plots.sh
   ```

   Expected outputs:

   - `artifacts/phase4_summary.json`
   - `artifacts/phase4_rate_sweep.csv`
   - `artifacts/phase4_rtl_latency_hist.csv`
   - `artifacts/phase4_latency_tlm_vs_rtl.png`
   - `artifacts/phase4_rate_sweep.png`
   - `artifacts/phase4_queue_depth_regions.png`
   - `artifacts/phase4_mutrig_latency_model.png`
   - matching SVG files for all plots.

6. Confirm plotting quality before accepting the report.

   Acceptance criteria:

   - DISLIN logs report `Warnings: 0`;
   - no curve, legend, axis label, caption, or tick text is clipped;
   - latency plot uses cycles on x and probability per cycle bin on y;
   - rate plot uses `rate_word / 0x0100` on x and accepted histogram rate in
     Mhit/s on y;
   - queue plot labels the 1 ppm depth region and does not present the model as
     board evidence;
   - injection plot uses normalized frame axes and labels the 25 Mhit/s physical
     clip.

7. Board test commands for a new run, using the established Phase 4 scripts:

   ```bash
   python3 quartus_system/board_test/script/run_phase4_emulator.py \
     --measure-after-end \
     --output quartus_system/board_test/reports/phase4_emulator_<date>_target200.md

   python3 quartus_system/board_test/script/probe_phase4_stage_counters.py \
     --hit-rate 0x0800 \
     --iterations 2 \
     --output quartus_system/board_test/reports/phase4_stage_probe_<date>.md
   ```

   The existing evidence files from 2026-04-25 are current functional reference
   inputs, but not rate signoff inputs for the 200 Mhit/s target.

## Pass Criteria

The Phase 4 math/TLM/RTL/board reporting package passes when:

- the TLM run finishes with 0 errors and 0 warnings;
- the DISLIN renderer finishes with 0 warnings;
- the histogram model clips at 200 Mhit/s, derived from 25 Mhit/s per MuTRiG;
- queue-depth regions are reported for iid dark noise, local 8-channel physical
  clusters, roaming clusters, mixed traffic, and all-channel injection;
- RTL injection-mode evidence covers one-channel offset sweep and saturation
  queueing;
- RTL integration simulation has no failing checks and reports no
  histogram-underflow, histogram-overflow, or dropped-hit status in the measured
  path;
- the board primary run reports `DROPPED_HITS delta = 0` and a clean post-end
  flush;
- the refreshed board sweep grows through the 195 Mhit/s `0x0800` model point
  and clips only at the 200 Mhit/s physical target.
