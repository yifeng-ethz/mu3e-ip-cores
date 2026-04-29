# Phase 5 Histogram Sanity DISLIN Contract

Date: 2026-04-29

This is the plotting contract for the Phase-5 collective histogram sanity evidence. It is not a measurement report by itself.

## Required Input CSVs

Directory: `reports/phase5_histogram_sanity_data_20260429/`

| File | Columns | Meaning |
|---|---|---|
| `phase5_rate_10k_100k_256ch.csv` | `channel,10 kHz,100 kHz` | 256 global-channel bins, where `channel = ASIC * 32 + local_channel`, sampled with `INTERVAL_CFG = 125000000` clocks. |
| `phase5_header_1_2_5.csv` | `delay_cycles,1/header,2/header,5/header` | Header-mode delay histograms for 1, 2, and 5 injected hits per observed header. |
| `phase5_delay_lanes.csv` | `delay_cycles,lane0,lane1,lane2,lane3,lane4,lane5,lane6,lane7` | Eight isolated lane delay histograms. `histogram_statistics_v2` 26.1.5 can filter negative debug modes by synthetic debug source (`debug_1`/`debug_2`); lane-level isolation still requires source/lane masking unless a future lane-tagged debug stream is wired. |

## Renderer

Raw single-run bin dumps can be captured with `script/phase5_histogram_bin_dump.tcl` from System Console. The final three CSVs are wide overlays assembled from those raw dumps by `script/build_phase5_histogram_sanity_csvs.sh`; keep both the raw dumps and the wide CSVs in the evidence directory.

Run:

```bash
firmware_builds/systems/system_20260427_testplanphase5/script/render_phase5_histogram_sanity_dislin.sh \
  --input-dir firmware_builds/systems/system_20260427_testplanphase5/reports/phase5_histogram_sanity_data_20260429 \
  --output-dir firmware_builds/systems/system_20260427_testplanphase5/reports/phase5_histogram_sanity_20260429
```

The renderer compiles `render_phase5_histogram_sanity_dislin.c` against the vendored DISLIN library and writes:

- `phase5_rate_10k_100k_256ch.png`
- `phase5_header_1_2_5.png`
- `phase5_delay_lanes.png`

Closure plots must show `DISLIN Warnings: 0` in `render_phase5_histogram_sanity_dislin.log`.
