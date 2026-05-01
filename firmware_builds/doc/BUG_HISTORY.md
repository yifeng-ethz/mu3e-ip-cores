# Phase-6 Bug History

This ledger records integration blockers that affect Phase-6 FEB to SWB to DMA
closure. It is append-only: update status and evidence, but do not erase the
first-seen history.

Class legend:
- `R` = RTL / firmware behavior
- `H` = host tool / harness / reporting behavior

## Index

| bug_id | class | status | first seen | summary |
|---|---|---|---|---|
| [P6-BUG-001-R](#p6-bug-001-r-swb-datagen-words-stayed-idle-before-the-musip-mux) | R | fixed for stream-datagen raw DMA | 2026-04-30 | SWB datagen drove data/datak but left `link32_t.idle=1`, so MuSiP mux ignored every generated word and DMA stayed empty. |
| [P6-BUG-002-R](#p6-bug-002-r-lower-real-multi-asic-mutrig-streams-trip-mts-timestamp-errors-before-ring-buffer-cam) | R | open; lower ASIC5+6 pair reproduced | 2026-04-30 | Lower real ASIC5/lane5 and ASIC6/lane6 pass alone but fail together with MTS timestamp errors before hit stack/ring; latency-window and header-sync controls do not clear it. |
| [P6-BUG-003-H](#p6-bug-003-h-mu3e-online-dma-tools-are-not-closure-quality-evidence) | H | fixed by repo-owned probe for DMA | 2026-04-30 | `swb_dmatest`, `rw`, MIDAS, and libmudaq-backed tools hide register and cleanup boundaries; closure now uses direct-MMIO tools under `tools/`. |
| [P6-BUG-004-H](#p6-bug-004-h-frame-boundary-signaltap-window-is-not-yet-time-aligned-across-rbcam-and-feb-frame-assembly) | H | open; zero-VCO evidence invalidated | 2026-04-30 | Lane6 STP captures show FEB type-3 hit frames under a `vco000` label, but `vnvcodelay=0` should produce no hits; rerun with nonzero locked settings and a time-aligned RBCAM/FEB capture. |
| [P6-BUG-005-R](#p6-bug-005-r-swb-host-dma-now-has-raw-musip-payload-but-not-decoded-feb-hit-frames) | R | open; raw DMA partial pass only | 2026-04-30 | Fixed4 SWB image writes raw 256-bit stream-datagen payload to host DMA, but time-datagen is still empty and no real FEB-link/legacy-frame disk artifact exists. |
| [P6-BUG-006-H](#p6-bug-006-h-1-s-rate-plot-collapsed-to-bin-0-because-the-observation-path-was-wrong) | H | source patched; live rerun required | 2026-05-01 | The required 1 s rate plot was scientifically rendered but all 647,881 hits landed in bin 0; root cause is a wrong histogram observation contract, not a pass. |
| [P6-BUG-007-R](#p6-bug-007-r-full-feb-generated-system-tied-the-lower-histogram-fill-input-off) | R | fixed for FEB emulator observability; real-source tuning resumes at P6-BUG-002 | 2026-05-01 | The nested lower-histogram source passed simulation, but the full FEB generated top still tied `histogram_statistics_0.fill_in_1` to zero, so live all-lane emulator rate was exactly upper-side only. |
| [P6-BUG-008-R](#p6-bug-008-r-asic5-head-sync-delay-splits-only-when-mts-lapse-is-enabled) | R | open; points at MTS lapse/lookback tuning | 2026-05-01 | ASIC5 becomes a one-bin header-sync delta when MTS lapse is bypassed, but production lapse leaves a deterministic 79/21 two-bin split that runtime expected-latency writes do not move. |

## 2026-05-01

### P6-BUG-006-H: 1 s rate plot collapsed to bin 0 because the observation path was wrong

- First seen in:
  `phase5_rate_per_channel_1s_20260501.csv` and
  `reports/assets/phase5_mutrig_tuning_20260430/phase5_rate_per_channel_1s.png`.
- Symptom:
  - The required 1 s, 256-bin rate artifact was rendered, but visual
    inspection shows all `647881` hits in bin 0, one active ASIC aggregate,
    and zero counts in the other 255 bins.
  - That shape is physically wrong for an all-real 256-channel 100 kHz
    stimulus. A working all-lane rate plot should distribute hits across the
    selected `{ASIC, channel}` bins, and a channel mask should remove only the
    masked channels.
  - The HTML report now classifies this artifact as `ANOMALY`, not `PASS`.
- Root cause:
  mixed harness/firmware observation contract:
  - the live runner could select the post-hit-stack `hit_type3` stream while
    the toolkit rate preset expects the pre-RBCAM `hit_type1` key
    `{ASIC[3:0], channel[4:0]}`;
  - the lower MTS stream was not a first-class pre-RBCAM histogram source, so
    lower ASICs were not observable in the same 256-bin rate artifact;
  - slow SC per-bin reads can also miss the ping-pong histogram bin bank, so a
    nonzero last-interval counter with zero bins is a readout anomaly, not a
    data-path pass.
- Fix status:
  - source patched in `scifi_datapath_system_v3_pipe.tcl`: bridge 0 defaults
    to pre-RBCAM, `histogram_statistics_0` has two fill inputs with
    `CHANNELS_PER_PORT=0` global keys, and `hist_pre_lower_splitter_0` feeds
    both `hit_stack_subsystem_1` and `histogram_ingress_bridge_1`.
  - `histogram_ingress_bridge_1.pre_out` is drained through an Avalon-ST null
    sink so the lower tap copy cannot backpressure MTS.
  - Clean Qsys regeneration passes, and authentic integration simulation
    passes with all eight lanes visible: 20 MTS channel-16 payload hits and 20
    histogram flushes per lane, zero histogram drops.
  - live closure remains open. Rerun the board with the toolkit rate preset,
    1 s interval, burst/frozen bin readout, and a deliberate mask sanity check.
    Accept the artifact only after the plotted distribution matches the
    selected channels and all active ASICs.

### P6-BUG-007-R: full FEB generated system tied the lower histogram fill input off

- First seen in:
  live all-lane emulator replay after the lower histogram source patch.
- Symptom:
  - A 1 s all-lane emulator run at 10 kHz/lane produced about `39992`
    histogram hits instead of the expected `80000`; that is almost exactly the
    four upper lanes only.
  - The initially probed address `0x0AC10` read as zero because it was not the
    lower histogram bridge SC word address. The correct lower histogram bridge
    window is Qsys byte `0xAC10..0xAC20`, exposed through the SC hub at word
    base `0x0AB04`; `0x0AC00/0x0AD00` are ring-buffer CAM CSR bases.
  - The fitted/generated full FEB image still had
    `histogram_statistics_0.asi_fill_in_1_valid` tied to ground, so the lower
    MTS histogram copy could not reach the live histogram even though the
    nested datapath source and integration simulation were already fixed.
- Root cause:
  stale full-FEB generated output. The source-level
  `scifi_datapath_system_v3_pipe.qsys` fix was not sufficient until
  `feb_system_v3_pipe` was regenerated. Full Qsys generation was also blocked
  by obsolete one-wire component versions in `debug_sc_system_v3.qsys`:
  `onewire_master 24.0.911.1` and `onewire_master_controller 24.0.918`
  were no longer available from the active worktree catalog.
- Fix status:
  - state:
    fixed for FEB emulator observability; real MuTRiG lower-pair tuning remains
    the separate P6-BUG-002 blocker.
  - mechanism:
    `debug_sc_system_v3.qsys` now requests the active one-wire component
    version `26.2.1.428`, and full `feb_system_v3_pipe` Qsys generation
    succeeds.
  - generated evidence:
    `feb_system_v3_pipe_data_path_subsystem.vhd` now instantiates
    `histogram_ingress_bridge_1`, connects its `hist_out` to
    `histogram_statistics_0.fill_in_1`, and exposes
    `data_path_subsystem_histogram_ingress_bridge_1.csr` at `0xAC10..0xAC20`
    in `feb_system_v3_pipe.sopcinfo`.
  - build evidence:
    `top_nostp_pipe` compiled successfully on 2026-05-01 with SOF checksum
    `0x13E73362`, SOF SHA256
    `57ab5ec8338c54d8189b518c0ea61cf8453c4ff802290eeaa16f4ee1e4504fb6`,
    setup WNS `+0.277 ns`, hold slack `+0.123 ns`, and zero TNS in the
    reported timing groups.
  - live bridge evidence:
    after SWB reload/checksum `0x31A72852`, PCIe recovery, FEB programming,
    and reset/address/stop-reset, link-2 SC reads returned
    `histogram_ingress_bridge_0` UID/status at `0x0AB00..0x0AB03` and
    `histogram_ingress_bridge_1` UID/status at `0x0AB04..0x0AB07`; both UIDs
    were `0x48495342`.
  - live emulator evidence:
    1 s rate reruns with link mask `0x00000004` passed the expected physical
    masks: all lanes at 10 kHz/lane produced `79984` histogram hits and zero
    drops, upper-only produced `39996`, lower-only produced `39996`, all lanes
    at 100 kHz/lane produced `798728`, and the dual-MTS delay-profile smoke
    produced `409080` hits with zero drops.

### P6-BUG-008-R: ASIC5 head-sync delay splits only when MTS lapse is enabled

- First seen in:
  2026-05-01 JTAG histogram dumps after the lower-histogram full-FEB rebuild.
- Symptom:
  - ASIC5/lane5 default XML settings (`cnt/vcodelay/hitlogic=42/20/25`) under
    production MTS lapse produced `81759` JTAG delay-bin hits in six nonzero
    bins. The peak bin at 872 cycles carried only `44.914%` of hits, with
    large sidebands at 1736 and 1752 cycles.
  - ASIC5 tuned to `52/18/25` improved but did not pass the production-lapse
    delta criterion: `91574` hits split into two bins, `79.171%` at 8 cycles
    and `20.829%` at 408 cycles.
  - The same physical ASIC5 setting with `--mts-bypass-lapse on` collapsed to
    one bin: `91574` hits, one nonzero bin, `100%` peak at 8 cycles.
  - ASIC6/lane6 default XML settings with production lapse enabled also
    collapsed to one bin: `137362` hits, `100%` peak at 904 cycles.
  - LVDS error-counter and DPA-unlock deltas stayed zero in these controls.
  - Runtime sweeps of `--mts-expected-latency` from `800` through `2000`
    cycles did not move the ASIC5 `79/21` production-lapse split.
- Root cause:
  open. The physical ASIC5 TDC/LVDS path can produce a deterministic delta when
  the MTS lapse/GTS transform is bypassed, so blind MuTRiG VCO sweeping is no
  longer the best hypothesis. Source inspection shows the active
  `mutrig_timestamp_processor/mts_processor.vhd` derives the overflow lookback
  and padding threshold from the compile-time `MUTRIG_OVERFLOW_LOOKBACK_8N`
  parameter, not from the runtime expected-latency CSR. That explains why the
  runtime expected-latency sweep did not affect the split.
- Fix status:
  open. Next patch should either A/B compile a smaller
  `MUTRIG_OVERFLOW_LOOKBACK_8N` value or expose the lapse lookback/padding
  threshold through a documented CSR, then rerun standalone MTS TB/formal,
  standalone synthesis, full FEB compile, and the ASIC5/ASIC6 head-sync
  histogram comparison before claiming the lower real-source gate.

## 2026-04-30

### P6-BUG-001-R: SWB datagen words stayed idle before the MuSiP mux

- First seen in:
  `tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py` datagen captures on the
  programmed SWB image with version register `0xC796F4B6`.
- Symptom:
  - `time-datagen`, `stream-datagen`, minimal datagen, and TB-style
    `readout_state=0x00040003` runs all produced `no_dma_words`.
  - `EVENT_BUILD_CNT_EVENT_DMA`, `DMA_CNT_WORDS`, and mux/event-builder
    counters stayed zero.
  - DMA address/setup registers were nonzero, so the failure was upstream of
    host address programming.
- Root cause:
  - `data_generator_a10` starts each active cycle from `LINK32_IDLE` and only
    overrides `data` and `datak`.
  - The generated record therefore keeps `idle='1'`.
  - `musip_mux_4_1` only consumes words when `i_rx(i).idle='0'`, so datagen
    traffic was structurally invisible.
- Fix status:
  - state:
    fixed for the stream-datagen path in online_sc; this is not FEB-link or
    time-datagen closure.
  - mechanism:
    `swb_block` now decodes `gen_link.data/gen_link.datak` with
    `work.mu3e.to_link(...)` before assigning `rx_data_sim(i)`.
  - before_fix_outcome:
    all repo-owned datagen DMA probes reported `no_dma_words`.
  - after_fix_outcome:
    the later fixed4 SWB image passed full `make flow` with 0 errors and 298
    warnings, programmed checksum `0x31A72852`, recovered `/dev/mudaq0`, and a
    repo-owned stream-datagen probe captured raw host-DMA payload.

### P6-BUG-002-R: lower real multi-ASIC MuTRiG streams trip MTS timestamp errors before ring buffer CAM

- First seen in:
  Phase-6 lower ASIC5/6 and ASIC6/7 real-MuTRiG runs on `2026-04-30`.
- Symptom:
  - ASIC5/lane5 and ASIC6/lane6 pass alone.
  - Earlier ASIC6/lane6 and ASIC7/lane7 captures were labeled as passing alone
    at `vncnt=0`, `vnvcodelay=0`, and `vnhitlogic=0`. Those runs are no longer
    valid PLL-lock evidence: `vnvcodelay=0` should be a no-hit TDC-injection
    control. Treat the hit-producing zero-VCO data as stale configuration, bad
    override, or run-sequence artifact until the manifest proves otherwise.
  - Real two-lane pairs fail with large `ring_inerr_delta` while LVDS and DPA
    error deltas remain zero.
  - SignalTap shows `mts1.aso_hit_type1_error` rising before
    `hit_stack1.hit_type_1_error[0]`.
  - Fresh continued cycle
    `phase6_long_runs/20260430_live_continued_cycle1` reproduces the same
    split: P6B006 lane5 alone passes with `hist_total_delta=52627` and
    `ring_inerr_delta=0`; P6B007 lane6 alone passes with
    `hist_total_delta=81880` and `ring_inerr_delta=0`; P6B010 lower
    lanes5+6 one-channel fails with `hist_total_delta=144364`,
    `mts_total_delta=440880`, `mts_discard_delta=0`, and
    `ring_inerr_delta=563053`.
  - Opening the MTS expected-latency gate from `2000` to `4000` and `65535`
    cycles does not clear P6B010. The 65535-cycle probe still measured
    `hist_total_delta=155387`, `mts_total_delta=429181`,
    `mts_discard_delta=0`, `ring_inerr_delta=319653`, and
    `frame_actual_delta=442754`.
  - Header-synchronous injection does not clear the pair failure. Lower header
    channel 5 fails with `ring_inerr_delta=748701`; lower header channel 6
    fails with `ring_inerr_delta=782985`. The same header mode passes for
    lane5 alone and lane6 alone with zero ring input errors.
  - ASIC6 `vnvcodelay` values `23,25,27,29,31` around the XML default did not
    find a clean P6B010 point. The low value `23` underfilled badly, so blind
    delay sweeps are not a valid tuning strategy.
  - The 2026-05-01 head-sync JTAG histograms sharpen the diagnosis. ASIC5
    default production-lapse delay is not delta-like, ASIC5 `52/18/25` still
    splits `79/21` with lapse enabled, but ASIC5 `52/18/25` with
    `--mts-bypass-lapse on` becomes a one-bin delta. ASIC6 default production
    lapse is also a one-bin delta. This keeps P6-BUG-002 open but moves the
    next lever from blind PLL tuning toward P6-BUG-008 MTS lapse/lookback
    tuning.
  - The histogram-bin dumper returned zero nonzero bins in the live
    `latency65535_histbins` run despite live MTS/histogram counters. Treat that
    specific bin-read path as an unreliable observable until the readout is
    repaired.
- Root cause:
  open. Current nonzero-PLL evidence points to cross-ASIC timestamp/epoch/order
  coherence before or inside lower MTS. The lane6/7 `vco000` subset is still
  invalid for PLL/tuning conclusions and must be rerun with ASIC-specific
  nonzero defaults/restores and full `RUN_PREPARE` before it supports any
  lane6/7 claim, but the ASIC5/6 lower-pair blocker no longer depends on that
  stale zero-VCO premise.
- Fix status:
  open. Do not claim FEB output or downstream SWB/DMA closure until this stage
  has a clean boundary capture and matching offline evidence.

### P6-BUG-003-H: Mu3e online DMA tools are not closure-quality evidence

- First seen in:
  Phase-6 host-DMA bring-up on `2026-04-30`.
- Symptom:
  Mu3e online tools combine stale detector assumptions, ambiguous masks, and
  cleanup sequences that can clear the state needed to localize the first bad
  boundary.
- Root cause:
  tool behavior is coupled to production online assumptions rather than the
  pessimistic Phase-6 debug contract.
- Fix status:
  - state:
    fixed for the DMA evidence path; expanded to a repo-wide tooling policy.
  - mechanism:
    added `tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py`, which opens
    `/dev/mudaq0` and `/dev/mudaq0_dmabuf` directly, writes only explicit
    command-line registers, captures RW/RO register snapshots and SWB counter
    sweeps before cleanup, and dumps `dma_words.bin` plus JSON/Markdown
    summaries.
  - policy:
    `swb_dmatest`, `rw`, MIDAS, and libmudaq-backed Mu3e online utilities are
    reference-only for Phase-6 closure. New validation work must extend
    repo-owned tools under `tools/`; online software may supply legacy register
    or packing hints, but it is not a trusted oracle.

### P6-BUG-004-H: frame-boundary SignalTap window is not yet time-aligned across RBCAM and FEB frame assembly

- First seen in:
  `phase6_frame_boundary_lane6_vco000_100k_*_20260430` captures on the
  timing-closed FEB boundary SignalTap image, checksum `0x173CFF8D`.
- Symptom:
  - ASIC6/lane6 single-channel, 100 kHz, `vco000`-labeled stimulus passes the
    live FEB counters with zero MTS discards, zero ring input errors, zero
    histogram drops, zero frame CRC errors, and zero LVDS/DPA deltas.
  - That pass is invalid as PLL-lock evidence. With `vnvcodelay=0`, the MuTRiG
    should generate no TDC-injection hits. Any nonzero-hit `vco000` run is a
    configuration-state or run-sequence bug until the ASIC readback/manifest
    proves a nonzero `vnvcodelay` was actually loaded.
  - The FEB `hit_type3` frame snapshot contains a legal frame header/trailer
    and nonzero subheader/hit content in the active injection window.
  - The simultaneously decoded RBCAM `hit_type2` taps in that 1k-sample
    window show only empty subheaders. This does not prove an RTL mismatch
    because the RBCAM output and frame-assembly drain are not guaranteed to be
    in the same short SignalTap window.
- Root cause:
  open. Two issues are now separated:
  - the `vco000` data-quality premise is wrong and must be rerun with nonzero
    ASIC-specific PLL settings after a full run sequence;
  - after a valid locked run exists, the remaining observability task is to
    catch the same nonempty RBCAM output and later FEB frame drain in one
    capture or in a matched simulation/VCD replay.
  A runtime-only edit to trigger on `ring_buffer_cam_1.aso_hit_type2_data[8]`
  did not produce a reliable new boundary capture, so do not treat it as a
  closure-grade trigger update.
- Fix status:
  open. Close this with a rerun using ASIC-specific nonzero PLL values and
  full `RUN_PREPARE`, then one of: a rebuilt STP trigger that keys on nonempty
  RBCAM subheaders with valid asserted, a deeper capture around both
  boundaries, or a focused simulation/VCD correlation proving the expected FIFO
  latency between RBCAM type-2 output and FEB type-3 frame output.

### P6-BUG-005-R: SWB host DMA now has raw MuSiP payload but not decoded FEB hit frames

- First seen in:
  `post_compactor_fixed4_stream_datagen_generic_defaultstate` after programming
  the fixed4 SWB image on `2026-04-30`.
- Symptom:
  - stream-datagen with generic/default readout state produced host DMA data:
    960 nonzero words, 64 nonpadding words, first payload words like
    `0x0008884A`, and event-builder payload count low32 `0x10`.
  - Three fresh 10 s stream-datagen controls after the fixed4 SWB image each
    produced raw host DMA: `2048` nonzero words, `1024` nonpadding words, and
    `256` event-builder payload words. The first payload words differed across
    runs (`0x00088A0C`, `0x0008818F`, `0x0008894F`), so this is not
    stale-buffer reuse.
  - the old FEB/SWB frame reducer found zero legacy frame headers/trailers and
    now classifies this as `raw_payload_no_legacy_frames`.
  - `time-datagen` still produced `no_dma_words` with zero event-builder
    payload count and FEB-merge timeout activity; enabling all four generic
    lanes still left mux hit/subheader counters at zero while package counter
    index 8 advanced.
- Root cause:
  open. The active `musip_event_builder` writes raw 256-bit payload words to
  DMA; the legacy register names and old frame scanner do not imply FEB frame
  grammar. Source inspection shows the legacy `data_generator_a10` is not an
  OPQ-quality time-merge stimulus because its subheader hit-count field is not
  tied to the actual generated hit body. Treat time-datagen as a bad control
  until a generator with declared hit counts matching the payload exists.
- Fix status:
  - state:
    partial. The host DMA path is alive and repeatable for raw stream-datagen
    payload, but this is not end-to-end FEB hit evidence.
  - mechanism:
    `tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py` now decodes the
    active event-builder payload counters despite stale register names, and the
    repo-owned reducer reports `raw_payload_no_legacy_frames` when nonpadding
    DMA payload lacks old FEB/SWB frame control words.
  - next:
    decode the active MuSiP/OPQ payload contract or capture real FEB-link
    frames, then require 255 delivered same-timestamp hits plus one
    OPQ-accounted drop per 256-hit source bunch.
