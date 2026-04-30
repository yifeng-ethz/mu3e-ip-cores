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
| [P6-BUG-002-R](#p6-bug-002-r-lower-real-multi-asic-mutrig-streams-trip-mts-timestamp-errors-before-ring-buffer-cam) | R | open; zero-VCO captures invalidated | 2026-04-30 | Lower real ASIC pairs pass alone but fail together with MTS timestamp errors before hit stack/ring; rerun lane6/7 with nonzero PLL settings before assigning root cause. |
| [P6-BUG-003-H](#p6-bug-003-h-mu3e-online-dma-tools-are-not-closure-quality-evidence) | H | fixed by repo-owned probe for DMA | 2026-04-30 | `swb_dmatest`, `rw`, MIDAS, and libmudaq-backed tools hide register and cleanup boundaries; closure now uses direct-MMIO tools under `tools/`. |
| [P6-BUG-004-H](#p6-bug-004-h-frame-boundary-signaltap-window-is-not-yet-time-aligned-across-rbcam-and-feb-frame-assembly) | H | open; zero-VCO evidence invalidated | 2026-04-30 | Lane6 STP captures show FEB type-3 hit frames under a `vco000` label, but `vnvcodelay=0` should produce no hits; rerun with nonzero locked settings and a time-aligned RBCAM/FEB capture. |
| [P6-BUG-005-R](#p6-bug-005-r-swb-host-dma-now-has-raw-musip-payload-but-not-decoded-feb-hit-frames) | R | open; raw DMA partial pass only | 2026-04-30 | Fixed4 SWB image writes raw 256-bit stream-datagen payload to host DMA, but time-datagen is still empty and no real FEB-link/legacy-frame disk artifact exists. |

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
- Root cause:
  open; current nonzero-PLL evidence still points to cross-ASIC
  timestamp/epoch/order coherence before or inside lower MTS, but the lane6/7
  `vco000` subset must be rerun with ASIC-specific nonzero defaults/restores
  and full `RUN_PREPARE` before it can support that conclusion.
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
    partial. The host DMA path is alive for raw stream-datagen payload, but this
    is not end-to-end FEB hit evidence.
  - mechanism:
    `tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py` now decodes the
    active event-builder payload counters despite stale register names, and the
    repo-owned reducer reports `raw_payload_no_legacy_frames` when nonpadding
    DMA payload lacks old FEB/SWB frame control words.
  - next:
    decode the active MuSiP/OPQ payload contract or capture real FEB-link
    frames, then require 255 delivered same-timestamp hits plus one
    OPQ-accounted drop per 256-hit source bunch.
