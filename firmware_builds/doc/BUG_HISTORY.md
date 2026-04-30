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
| [P6-BUG-001-R](#p6-bug-001-r-swb-datagen-words-stayed-idle-before-the-musip-mux) | R | patched in online_sc; A&S passed; full compile/board rerun pending | 2026-04-30 | SWB datagen drove data/datak but left `link32_t.idle=1`, so MuSiP mux ignored every generated word and DMA stayed empty. |
| [P6-BUG-002-R](#p6-bug-002-r-lower-real-multi-asic-mutrig-streams-trip-mts-timestamp-errors-before-ring-buffer-cam) | R | open | 2026-04-30 | Lower real ASIC pairs pass alone but fail together with MTS timestamp errors before hit stack/ring. |
| [P6-BUG-003-H](#p6-bug-003-h-mu3e-online-dma-tools-are-not-closure-quality-evidence) | H | fixed by repo-owned probe for DMA | 2026-04-30 | `swb_dmatest`, `rw`, MIDAS, and libmudaq-backed tools hide register and cleanup boundaries; closure now uses direct-MMIO tools under `tools/`. |
| [P6-BUG-004-H](#p6-bug-004-h-frame-boundary-signaltap-window-is-not-yet-time-aligned-across-rbcam-and-feb-frame-assembly) | H | open | 2026-04-30 | Good-ASIC lane6 STP captures show clean FEB type-3 hit frames, but the same 1k-sample window does not yet catch the corresponding nonempty RBCAM type-2 beat. |

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
    patched in `/home/yifeng/packages/online_sc/online/common/firmware/a10/swb/swb_block.vhd`;
    Quartus Analysis & Synthesis passed; full compile, reflash, and board rerun
    are still required before closure.
  - mechanism:
    `swb_block` now decodes `gen_link.data/gen_link.datak` with
    `work.mu3e.to_link(...)` before assigning `rx_data_sim(i)`.
  - before_fix_outcome:
    all repo-owned datagen DMA probes reported `no_dma_words`.
  - after_fix_outcome:
    `make flow_map` in `online_sc/online/switching_pc/a10_board` passed with
    0 errors and 182 warnings on `2026-04-30`; full compile, reflash, and
    repeated datagen probe are pending.

### P6-BUG-002-R: lower real multi-ASIC MuTRiG streams trip MTS timestamp errors before ring buffer CAM

- First seen in:
  Phase-6 lower ASIC5/6 and ASIC6/7 real-MuTRiG runs on `2026-04-30`.
- Symptom:
  - ASIC5/lane5 and ASIC6/lane6 pass alone.
  - ASIC6/lane6 and ASIC7/lane7 also pass alone at
    `vncnt=0`, `vnvcodelay=0`, and `vnhitlogic=0`.
  - Real two-lane pairs fail with large `ring_inerr_delta` while LVDS and DPA
    error deltas remain zero.
  - SignalTap shows `mts1.aso_hit_type1_error` rising before
    `hit_stack1.hit_type_1_error[0]`.
- Root cause:
  open; current evidence points to cross-ASIC timestamp/epoch/order coherence
  before or inside lower MTS, not lane-local PLL lock.
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
  - ASIC6/lane6 single-channel, 100 kHz, zero-VCO-point stimulus passes the
    live FEB counters with zero MTS discards, zero ring input errors, zero
    histogram drops, zero frame CRC errors, and zero LVDS/DPA deltas.
  - The FEB `hit_type3` frame snapshot contains a legal frame header/trailer
    and nonzero subheader/hit content in the active injection window.
  - The simultaneously decoded RBCAM `hit_type2` taps in that 1k-sample
    window show only empty subheaders. This does not prove an RTL mismatch
    because the RBCAM output and frame-assembly drain are not guaranteed to be
    in the same short SignalTap window.
- Root cause:
  open. Current evidence points to an observability alignment gap: the
  histogram-valid trigger catches frame drain activity, while the matching
  nonempty RBCAM output likely occurred outside the sampled pre-trigger window.
  A runtime-only edit to trigger on `ring_buffer_cam_1.aso_hit_type2_data[8]`
  did not produce a reliable new boundary capture, so do not treat it as a
  closure-grade trigger update.
- Fix status:
  open. Close this with one of: a rebuilt STP trigger that keys on nonempty
  RBCAM subheaders with valid asserted, a deeper capture around both boundaries,
  or a focused simulation/VCD correlation proving the expected FIFO latency
  between RBCAM type-2 output and FEB type-3 frame output.
