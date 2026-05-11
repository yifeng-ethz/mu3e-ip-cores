# Phase 6 RTL Histogram And Post-RBCAM Evidence - 2026-05-02

## Scope

This note records local RTL evidence after the emulator ticket-FIFO update and
the histogram mode-1 timestamp-wrap fix. It does not claim board closure.
Hardware was not used for these runs. A bench ticket was queued later for the
remaining board plots, but it was not acquired and was released during this
local RTL pass.

## Histogram Mode 1 And Debug-TS Equivalence

Command:

```sh
make -C histogram_statistics/tb clean run_all
```

Result:

- `histogram_statistics_v2`: `62 PASS, 0 FAIL`
- `B14_delay_mode1_matches_debug_ts`: mode `+1` delay bins match `debug_ts`
  mode `-1` bins.
- `B15_delay_mode1_wrap_matches_debug_ts`: mode `+1` still matches
  `debug_ts` after the 13-bit hit timestamp has wrapped.
- `tb_histogram_ingress_bridge PASS`: the post-hit-stack bridge forwards only
  real post-frame hit words, suppresses zero-hit/protocol words, and preserves
  backpressure.

## Generated Post-RBCAM Wiring

Checked generated Qsys:

- `histogram_ingress_bridge_0.DEFAULT_SELECT_POST = 1`
- `histogram_ingress_bridge_0.FILTER_POST_HIT_WORDS = 1`
- `hit_stack_subsystem_0.hit_type3 -> hist_post_splitter_0.in`
- `hist_post_cdc_0.out -> histogram_ingress_bridge_0.post_in`
- `histogram_ingress_bridge_0.hist_out -> histogram_statistics_0.hist_fill_in`

The standalone bridge regression covers the filtering behavior on this post
stream. The DP smoke below exercises the generated histogram instance on the
post/RBCAM path.

## DP Integration Smoke On Generated Histogram

Command:

```sh
TB_DP_SOURCE_OVERRIDES=1 \
TB_DP_VSIM_ARGS='+TB_DP_SMOKE_HIT_RATE=0800 +TB_DP_SMOKE_NOISE_RATE=0000 +TB_DP_SMOKE_SHORT_MODE=1 +TB_DP_SMOKE_MIN_TOTAL=8 +TB_DP_SMOKE_MIN_ACTIVE=1 +TB_DP_SMOKE_TIMEOUT_US=500 +TB_DP_SMOKE_POLL_US=25' \
firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
```

Artifact:

- `model/phase4/inputs/rtl_post_rbcam_smoke_20260502/run.log`

Key result:

- `TB_HIST total=2024 active=8 min_nonzero=253 max_nonzero=253`
- `TB_HIST_STATUS ctrl=0x00000000 ... dropped=0x00000000 under=0x00000000 over=0x00000000`
- `Results: 7 PASSED, 0 FAILED`

## Focused ASIC0 Post-RBCAM Delay Smoke

Command:

```sh
TB_DP_SOURCE_OVERRIDES=1 \
TB_DP_VSIM_ARGS='+TB_DP_POST_RBCAM_MEAS +TB_DP_ACTIVE_LANE_MASK=01 +TB_DP_USE_PERIODIC_INJECTOR +TB_DP_INJECT_MODE=1 +TB_DP_INJECT_HIGH=1 +TB_DP_HIT_RATE=0000 +TB_DP_NOISE_RATE=0000 +TB_DP_HIT_RATE_LANE0=0000 +TB_DP_NOISE_RATE_LANE0=0000 +TB_DP_HIT_MODE_LANE0=1 +TB_DP_BURST_SIZE_LANE0=5 +TB_DP_BURST_CENTER_LANE0=16 +TB_DP_SHORT_MODE=1 +TB_DP_RUN_CYCLES=50000 +TB_DP_REPORT_DIR=<artifact-dir>' \
firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
```

Artifact:

- `model/phase4/inputs/rtl_asic0_post_rbcam_smoke_abs_20260502_wide/`
- `reports/assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_hist.png`
- `reports/assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_modes.png`
- `reports/assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_summary.json`

![RTL ASIC0 post-rbCAM delay](assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_hist.png)

Key result:

- only ASIC0 emulator was active; lanes 1..7 stayed at zero frames/events
- pre-rbCAM stream: `pre_fire=1525`, `payload=1525`, `error=0`
- post-rbCAM bridge: `bridge_fire=1525`, `queue_hit=1093`
- histogram: `total=1525`, `csv_total=1099`, `active=108`, `over=426`
- rbCAM window `[0,2000]`: `in=747 (48.983607%)`,
  `out=778 (51.016393%)`, configured high-side overflow
  `426 (27.934426%)`
- `Results: 6 PASSED, 0 FAILED`

## Focused ASIC0 Post-RBCAM Periodic Mode-2 Smoke

Command:

```sh
TB_DP_SOURCE_OVERRIDES=1 \
TB_DP_VSIM_ARGS='+TB_DP_POST_RBCAM_MEAS +TB_DP_ACTIVE_LANE_MASK=01 +TB_DP_USE_PERIODIC_INJECTOR +TB_DP_INJECT_MODE=2 +TB_DP_INJECT_PERIOD=1250 +TB_DP_INJECT_HIGH=1 +TB_DP_HIT_RATE=0000 +TB_DP_NOISE_RATE=0000 +TB_DP_HIT_RATE_LANE0=0000 +TB_DP_NOISE_RATE_LANE0=0000 +TB_DP_HIT_MODE_LANE0=0 +TB_DP_BURST_SIZE_LANE0=31 +TB_DP_BURST_CENTER_LANE0=16 +TB_DP_SHORT_MODE=1 +TB_DP_RUN_CYCLES=50000 +TB_DP_REPORT_DIR=<artifact-dir>' \
firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
```

Artifact:

- `model/phase4/inputs/rtl_asic0_post_rbcam_rate100k_20260502/`
- `reports/assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_periodic100k_delay_hist.png`
- `reports/assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_modes.png`
- `reports/assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_summary.json`

![RTL ASIC0 post-rbCAM periodic 100 kHz delay](assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_periodic100k_delay_hist.png)

![RTL ASIC0 post-rbCAM delay mode comparison](assets/phase6_rtl_post_rbcam_20260502/rtl_asic0_post_rbcam_delay_modes.png)

Key result:

- periodic injector mode `2`, `pulse_interval=1250`, `pulse_high=1`
- only ASIC0 emulator was active; lanes 1..7 stayed at zero frames/events
- pre-rbCAM stream: `pre_fire=1240`, `payload=1240`, `error=0`
- post-rbCAM bridge: `bridge_fire=1240`, `queue_hit=899`
- histogram: `total=1240`, `csv_total=899`, `active=81`, `over=341`
- rbCAM window `[0,2000]`: `in=580 (46.774194%)`,
  `out=660 (53.225806%)`, configured high-side overflow
  `341 (27.500000%)`
- `Results: 6 PASSED, 0 FAILED`

## Emulator Ticket-FIFO / Dispatch-Latency Integration

Command:

```sh
TB_DP_SOURCE_OVERRIDES=1 \
TB_DP_VSIM_ARGS='+TB_DP_PRE_RBCAM_MEAS +TB_DP_RUN_CYCLES=2000 +TB_DP_HIT_RATE=0000 +TB_DP_NOISE_RATE=0000 +TB_DP_SHORT_MODE=1 +TB_DP_HIT_RATE_LANE0=0800 +TB_DP_HIT_MODE_LANE0=3 +TB_DP_BURST_SIZE_LANE0=5 +TB_DP_BURST_CENTER_LANE0=16 +TB_DP_REPORT_DIR=<artifact-dir>' \
firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
```

Artifact:

- `model/phase4/inputs/rtl_ticket_fifo_periodic5_2k_20260502/`

Key result:

- lane 0 only: `mts_asic=168`, all other lanes zero
- rate histogram: `total=168`, `active=32`, dropped/under/over all zero
- dispatch-latency histogram: `total=165`, `active=63`, no underflow
- latency summary from CSV: min `922`, p50 `922`, p90 `1143`, p99 `1215`,
  max `1220` cycles
- `Results: 4 PASSED, 0 FAILED`

## Timestamp Trace Equivalence

Command:

```sh
TB_DP_SOURCE_OVERRIDES=1 \
TB_DP_VSIM_ARGS='+TB_DP_PRE_RBCAM_MEAS +TB_DP_RUN_CYCLES=500 +TB_DP_HIT_RATE=0000 +TB_DP_NOISE_RATE=0000 +TB_DP_SHORT_MODE=1 +TB_DP_HIT_RATE_LANE0=0800 +TB_DP_HIT_MODE_LANE0=3 +TB_DP_BURST_SIZE_LANE0=5 +TB_DP_BURST_CENTER_LANE0=16 +TB_DP_TS_TRACE +TB_DP_TS_TRACE_MAX_MISMATCH=32 +TB_DP_REPORT_DIR=<artifact-dir>' \
firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh
```

Artifact:

- `model/phase4/inputs/rtl_ticket_fifo_trace_500_20260502/`

Key result:

- `TB_TS_TRACE_SUMMARY enabled=1 ... type0_mismatch=0 mts_in_mismatch=0 mts_out_channel=0 mts_out_tcc=0 mts_out_delta=0 mts_out_error=0 mts_out_delta_offset=-2`
- The generated hit timestamp, type-0 ingress word, MTS ingress word, and MTS
  egress word agree cycle-for-cycle after accounting for the fixed `-2` cycle
  debug-delta offset at MTS output.
- The two `mts_out_under` events occur at the trace boundary/drain and do not
  correspond to accepted hit-word mismatches.
- Latency summary from the trace run: min `927`, p50 `1071`, p90 `1191`,
  p99 `1220`, max `1220` cycles.
- `Results: 4 PASSED, 0 FAILED`

## RTL ASIC0 Emulator Groups

Artifact:

- `reports/phase6_rtl_asic0_emulator_groups_20260502.md`
- `reports/assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_emulator_groups.html`

Key result:

- `TB_DP_ACTIVE_LANE_MASK=0x01` keeps lanes 1..7 at zero while preserving the
  injector fanout.
- Header-sync multiplicity scales accepted hits as `54 * M`; latency active
  bins grow from 1 to 4 for multiplicity 2..5.
- Periodic rates are exact at 10 kHz/channel and 100 kHz/channel; 500 kHz/channel
  and 1 MHz/channel saturate at about `280.5 kHz/channel` in this RTL integration
  path.
- Histogram CSR dropped/under/over status remains zero for all local rate cases.

## Existing ASIC0 MuTRiG Emulator JTAG Groups

Artifact:

- `reports/phase6_emulator_asic0_groups_20260502.md`
- `reports/assets/phase6_emulator_asic0_20260502/phase6_emulator_asic0_groups.html`

Key result:

- Existing ASIC0 emulator JTAG CSV captures were re-rendered into rate and
  header-sync delay groups; no new hardware access was taken for this render.
- The hardware-emulator rate group tracks 10 kHz/channel and 100 kHz/channel,
  then saturates at the same aggregate count for 500 kHz/channel and 1 MHz/channel.
- Header-sync delay is inside the rbCAM `[0,2000]` cycle window for
  multiplicities 1..3. Multiplicities 4 and 5 show a `1.327990%` high-side
  out tail.

## Remaining Gaps Before Closure

- The board image still needs to be rebuilt/programmed before claiming
  hardware evidence for the new ticket-FIFO and mode-1 fixes.
- The full hit stream was not widened to carry a physical 48-bit MTS field;
  the implemented low-risk fix reconstructs the narrow timestamp into the
  histogram local epoch for mode `+1`.
- ASIC0 rate/header-sync plots from the updated hardware image are not yet
  regenerated. The JTAG emulator plots above are existing captures from the
  current programmed image, not evidence for a newly rebuilt bitstream.
