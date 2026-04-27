# TEST_PLAN_PUBLISH.md — Phase 4 publication-grade figure catalog

**Companion:** [`TEST_PLAN_BASIC.md`](TEST_PLAN_BASIC.md) · [`MATH_REPORT.md`](MATH_REPORT.md) · [`TLM_REPORT.md`](TLM_REPORT.md) · [`TEST_REPORT.md`](TEST_REPORT.md) · [`../TEST_PLAN.md`](../TEST_PLAN.md) · [`../../systems/system_20260427_testplanphase5/model/`](../../systems/system_20260427_testplanphase5/model/)
**Renderer:** DISLIN 11.5.2 (vendored at `packet_scheduler/.vendor/dislin`), invoked from `scripts/phase4_dislin_plots.c` and the case-specific renderers added under `scripts/publish/`.
**Skill enforced:** [`~/.codex/skills/scientific-plotting/SKILL.md`](~/.codex/skills/scientific-plotting/SKILL.md) — every figure in this catalog passes the rules in the skill (axis ranges centered on the regime where the response changes, sequential darker-is-worse palette for loss/risk, inline contour labels broken cleanly, color bar height matched to plot body, no overlapping titles or legends, sub-unit axes show enough decimal digits, DISLIN log `Warnings: 0`).
**Audience:** chief architect signoff. Each set is the golden reference for a published-grade plot — it doubles as the visual proof that the TPB and TPBH catalog cases produced the predicted physics behavior.

## Definitions used by every figure

Write the meaning of every axis and metric on the figure or in its caption. Definitions used throughout this catalog:

| Symbol | Meaning |
|---|---|
| `r` | per-MuTRiG ingress rate label (`r=1..7` matches slide 25 panels), `r=7` is the 25 Mhit/s wire-speed cap |
| `R_agg` | aggregate accepted rate at `histogram_statistics_0`, in Mhit/s (cap = 200 Mhit/s for the 8-MuTRiG histogram) |
| `header_delay` | injector pulse offset relative to the MuTRiG frame mark, in 8-ns byte-clock cycles, sweep range `[0, FRAME_INTERVAL_SHORT=910]` |
| `d_N` | per-hit pipeline latency (cycles, 1 cycle = 8 ns) — slide 23, 24, 25, 38 axis |
| `V` | delay-jitter envelope width (cycles); `V_flit + V_framing` per slide 26 |
| `T` | re-sequencing buffer timeout (cycles); per slide 26, `T = V` |
| `ε` | drop probability; pre-gate region levels `5 %`, `1 %`, `1 ppm` |
| `K` | coalescing-queue depth; `K = COAL_QUEUE_DEPTH` of `histogram_statistics_v2` (default 256) |
| `M` | active-tag support (number of distinct bins receiving hits in the observation window) |
| `B` | burstiness `B = (SCV − 1)/(SCV + 1)` (Goh–Barabási convention from slide 44) |
| `bin_idx` | absolute histogram bin index `0..255` (8 lanes × 32 channels) |

Layer abbreviations (used in every set): **T** = TLM, **S** = RTL SIM, **B** = on-board.

## Catalog layout

Each set is delivered as one published figure (one PNG and one matching SVG export, identical layout). Subplots inside a set are explicitly enumerated. Every set names the source CSV in `artifacts/`, the renderer in `scripts/publish/`, the upstream slide it reproduces, the TPB or TPBH case that supplies the data, and the chief-architect acceptance criteria.

The 28 sets below are ordered by the physics flow (rate → latency → ordering → queueing → drop probability → cross-layer signoff).

---

### Set 1 — Per-channel feature map (8×32 bin lattice)

- **Subplots:** 8 panels (one per MuTRiG lane), each 4×8 bin tile mapping `(lane, channel) → hit count` for the all-channels-on, dark-rate-only run.
- **CSV:** `artifacts/publish/set01_feature_map.csv`
- **Renderer:** `scripts/publish/set01_feature_map.c`
- **Slide reference:** the per-channel uniformity expected from the slide-31 MuTRiG architecture (32 channels per ASIC).
- **Source case:** TPB020 (mask=0xFFFFFFFF) on T, S, B.
- **Acceptance:** every tile inside Poisson 3σ of the lane mean; no per-channel deficit; sequential palette darker = lower count; color bar height matches plot body; bin labels readable at the export size.

### Set 2 — Single-channel-only proof tile

- **Subplots:** 4×8 small-multiples — 32 panels, one per channel index `ch ∈ [0,31]`, lane 0; each panel shows the 256-bin histogram with exactly one populated bin at the predicted absolute index.
- **CSV:** `artifacts/publish/set02_single_channel_tiles.csv`
- **Renderer:** `scripts/publish/set02_single_channel_tiles.c`
- **Slide reference:** none (this is the channel-mask correctness proof for the architect).
- **Source case:** TPB015 (32-run sweep) on S and B.
- **Acceptance:** every panel shows one and only one nonzero bin at the predicted index; non-bin regions saturate to zero (no Poisson-leak); identical pattern across S and B.

### Set 3 — Channel-mask geometry sweep

- **Subplots:** 6 panels, one per mask `{0xFFFFFFFF, 0x0000FFFF, 0xFFFF0000, 0x55555555, 0xAAAAAAAA, 0x00000001}` from `TEST_PLAN.md` §4.5.1; each panel overlays the 256-bin histogram for the same mask.
- **CSV:** `artifacts/publish/set03_mask_geometry.csv`
- **Renderer:** `scripts/publish/set03_mask_geometry.c`
- **Slide reference:** none (mask-applies-correctly proof).
- **Source case:** TPB020..TPB025 on S and B.
- **Acceptance:** each mask's predicted bin set populated, complement bins exactly zero, `OVERFLOW_COUNT = 0`, `UNDERFLOW_COUNT = 0`.

### Set 4 — Aggregate rate sweep (small multiples by emulator hit_mode)

- **Subplots:** 3 panels (`hit_mode=POISSON`, `POISSON_IID`, `PERIODIC`), each showing `R_agg` (Mhit/s) vs `csr[0x01].hit_rate` across `{0x0100..0x8000}` overlaying T (line), S (markers), B (markers).
- **CSV:** `artifacts/publish/set04_rate_sweep_by_mode.csv`
- **Renderer:** `scripts/publish/set04_rate_sweep_by_mode.c`
- **Slide reference:** `MATH_REPORT.md` model curves and `TEST_REPORT.md` rate sweep table.
- **Source case:** TPB080..TPB083 on T, S, B.
- **Acceptance:** monotone doubling holds 2.0 ± 5 % up to `0x0800`; clip at the 200 Mhit/s physical cap; the legacy 135 Mhit/s knee is explicitly absent on the published figure; B markers overlay T/S within tolerance.

### Set 5 — Per-MuTRiG rate scan (8 lanes overlaid)

- **Subplots:** 1 panel, 8 line series (`R_lane(r)` for lane 0..7), with the 25 Mhit/s wire-speed cap drawn as a horizontal reference line.
- **CSV:** `artifacts/publish/set05_per_lane_rate.csv`
- **Renderer:** `scripts/publish/set05_per_lane_rate.c`
- **Slide reference:** `MATH_REPORT.md` per-MuTRiG cap.
- **Source case:** TPB067 on B; TPB080 per-lane decomposition on S.
- **Acceptance:** all 8 lanes coincide within ±2 %; each clips at exactly 25 Mhit/s; reference line labeled.

### Set 6 — Latency PDF (injection mode 1, slide 24 reproduction)

- **Subplots:** 9 panels, one per `header_delay ∈ {100,200,300,400,500,600,700,800,900}` cycles, each panel overlays T (filled), S (line), B (markers) of `P(d_N)`.
- **CSV:** `artifacts/publish/set06_inj_mode1_latency_pdf.csv`
- **Renderer:** `scripts/publish/set06_inj_mode1_latency_pdf.c`
- **Slide reference:** slide 24 of `../../../docs/Archive/ethhw_reordering.pdf`.
- **Source case:** TPB036..TPB044 (live CMP TPB045) on T, S, B.
- **Acceptance:** delta pulse mode at `(910 − header_delay) ± 8` cycles in every panel; pulse width ≤ 100 cycles on T/S, ≤ 120 on B; small-multiples layout matches slide 24.

### Set 7 — Latency PDF (injection mode 2, slide 25 reproduction)

- **Subplots:** 7 panels, one per `r ∈ {1..7}`, each overlays T/S/B of `P(d_N)`.
- **CSV:** `artifacts/publish/set07_inj_mode2_latency_pdf.csv`
- **Renderer:** `scripts/publish/set07_inj_mode2_latency_pdf.c`
- **Slide reference:** slide 25.
- **Source case:** TPB056..TPB065 (live CMP TPB066).
- **Acceptance:** monotone widening of the right edge across panels; right edge at `r=7` ≤ `pipe + 2·FRAME_INTERVAL_SHORT`; T/S/B overlay within 5 %.

### Set 8 — Latency CDF (injection mode 2)

- **Subplots:** 1 panel, 7 CDF curves (`F(d_N | r)` for `r=1..7`) for each layer; layers in 3 line styles, rates in 7 colors. Reference vertical lines at `pipe`, `pipe + FRAME_INTERVAL_SHORT`, `pipe + 2·FRAME_INTERVAL_SHORT`.
- **CSV:** `artifacts/publish/set08_inj_mode2_latency_cdf.csv`
- **Renderer:** `scripts/publish/set08_inj_mode2_latency_cdf.c`
- **Slide reference:** slide 22 (RTO bound table) — same envelope as slide 25 in CDF form.
- **Source case:** same data as set 7.
- **Acceptance:** all 21 CDFs are monotone non-decreasing; `F⁻¹(0.99)` for `r=7` ≤ `pipe + 2·FRAME_INTERVAL_SHORT`; T/S/B coincide.

### Set 9 — Latency p50/p90/p99/max envelope

- **Subplots:** 1 panel, 4 quantile traces (p50, p90, p99, max) of `d_N` vs `r`, with T/S/B overlaid.
- **CSV:** `artifacts/publish/set09_latency_quantiles.csv`
- **Renderer:** `scripts/publish/set09_latency_quantiles.c`
- **Slide reference:** the V envelope on slide 23.
- **Source case:** derived from set 7 raw data.
- **Acceptance:** every quantile monotone non-decreasing with `r`; max trace bounded by the 0-to-2-frame envelope at `r=7`; T/S/B overlay within configured tolerance.

### Set 10 — Latency 2-D contour (header_delay × d_N) for injection mode 1

- **Subplots:** 1 contour panel `P(d_N | header_delay)`, x = `header_delay ∈ [0,909]` cycles, y = `d_N ∈ [0, FRAME_INTERVAL_SHORT]` cycles, z = log-scaled probability.
- **CSV:** `artifacts/publish/set10_inj_mode1_contour.csv`
- **Renderer:** `scripts/publish/set10_inj_mode1_contour.c`
- **Slide reference:** slide 24 small-multiples collapsed into a continuous map.
- **Source case:** TPB049 (full sweep stride 10) on S and B; T model overlay.
- **Acceptance:** the principal ridge follows `d_N = FRAME_INTERVAL_SHORT − header_delay` exactly; sequential darker-is-higher colormap; reference isoline `d_N = FRAME_INTERVAL_SHORT − header_delay` overlaid; vertical color bar height matches plot body; `Warnings: 0`.

### Set 11 — Latency 2-D contour (rate × d_N) for injection mode 2

- **Subplots:** 1 contour panel `P(d_N | r)`, x = `r ∈ [0, 1]` normalized to wire-speed, y = `d_N ∈ [0, 2·FRAME_INTERVAL_SHORT]` cycles, z = log-scaled probability.
- **CSV:** `artifacts/publish/set11_inj_mode2_contour.csv`
- **Renderer:** `scripts/publish/set11_inj_mode2_contour.c`
- **Slide reference:** slide 25 collapsed into continuous map.
- **Source case:** set 7 raw data.
- **Acceptance:** the right-edge isoline grows from ≈ FRAME_INTERVAL_SHORT at low `r` to ≈ 2·FRAME_INTERVAL_SHORT at `r=1`; reference isoline `d_N = FRAME_INTERVAL_SHORT(1+ρ)` overlaid; sequential palette; color bar matched.

### Set 12 — Ingress vs egress side-by-side (slide 38 reproduction)

- **Subplots:** 7 row-panels (`r=1..7`), each row has two columns (ingress vs egress); within each cell, T/S/B overlaid PDFs.
- **CSV:** `artifacts/publish/set12_ingress_vs_egress.csv`
- **Renderer:** `scripts/publish/set12_ingress_vs_egress.c`
- **Slide reference:** slide 38 Figure 4(a).
- **Source case:** TPB076, TPB077, TPB078 (live CMP TPB079).
- **Acceptance:** egress block shifted right by `T = V` and otherwise the same shape; T/S/B coincide; egress red arrow at `T = 2000` reproduced as a vertical reference line.

### Set 13 — Reordering (δ_arrival × δ_timestamp) ingress

- **Subplots:** 4 panels, one per random-injection rate `rdm ∈ {1000, 800, 600, 400}` (slide 32), x/y heatmap with on-time line drawn dashed.
- **CSV:** `artifacts/publish/set13_reorder_ingress.csv`
- **Renderer:** `scripts/publish/set13_reorder_ingress.c`
- **Slide reference:** slide 32.
- **Source case:** S (RTL ingress tap) and B (`histogram_ingress_bridge_0.pre_in`).
- **Acceptance:** the lagging-arrival lobe is visible at every rate; on-time line drawn; sequential palette; matches slide 32 visual layout.

### Set 14 — Reordering (δ_arrival × δ_timestamp) egress

- **Subplots:** 4 panels matching Set 13 rates, after re-sequencing.
- **CSV:** `artifacts/publish/set14_reorder_egress.csv`
- **Renderer:** `scripts/publish/set14_reorder_egress.c`
- **Slide reference:** slide 33.
- **Source case:** B (`histogram_ingress_bridge_0.post_in`) and S equivalent.
- **Acceptance:** lagging-arrival lobe disappears; concentrated on-time arrival; matches slide 33 visual layout. Side-by-side with Set 13 on the printed page is recommended.

### Set 15 — Ring-CAM fill-level PDF by inject_interval (slide 40 reproduction)

- **Subplots:** 4 stacked panels for `inject_interval ∈ {1000, 500, 250, 125}`, each PDF on log-y, x = CAM index `[0, 1024]`, with the maximum-fill mark labeled (`m`, `2m`, `4m`, `8m` per slide 40).
- **CSV:** `artifacts/publish/set15_cam_fill_by_interval.csv`
- **Renderer:** `scripts/publish/set15_cam_fill_by_interval.c`
- **Slide reference:** slide 40.
- **Source case:** TPBH026 on T, S, B.
- **Acceptance:** PDF tail bounded by the slide-40 maximum-fill envelope; T/S/B overlay; color order matches slide 40 (yellow → green → blue → purple).

### Set 16 — Ring-CAM fill-level PDF by CAM index, low vs high rate (slide 41)

- **Subplots:** 2 columns (`rate=1` vs `rate=7`), each with 4 stacked panels for `CAM index ∈ {100, 200, 300, 400}` at fixed `delay=100`, log-y.
- **CSV:** `artifacts/publish/set16_cam_fill_by_rate.csv`
- **Renderer:** `scripts/publish/set16_cam_fill_by_rate.c`
- **Slide reference:** slide 41.
- **Source case:** TPBH027 on T, S, B.
- **Acceptance:** rate-7 column shows wider tails than rate-1; per-CAM-index curves clearly separated; matches slide 41 layout.

### Set 17 — Ring-CAM fill-level PDF rate sweep + interval sweep (slide 42)

- **Subplots:** 2 panels — left = rate sweep `r=1..7` overlay, right = interval sweep `{1000, 500, 250, 125}` overlay (mirrors slide 42).
- **CSV:** `artifacts/publish/set17_cam_fill_dual.csv`
- **Renderer:** `scripts/publish/set17_cam_fill_dual.c`
- **Slide reference:** slide 42.
- **Source case:** TPBH028 on T, S, B.
- **Acceptance:** both panels match slide-42 visual layout; legend orders identical to upstream slide.

### Set 18 — Coalescing-queue peak-occupancy PDF by traffic mode

- **Subplots:** 5 panels (iid Poisson, local 8-cluster, roaming cluster-8, 50/50 mixed, all-256 burst) of `P(peak_occupancy)`, log-y, with the `K=8`, `K=16`, `K=64`, `K=256` reference lines.
- **CSV:** `artifacts/publish/set18_queue_peak_pdf.csv`
- **Renderer:** `scripts/publish/set18_queue_peak_pdf.c`
- **Slide reference:** `MATH_REPORT.md` queue-depth table.
- **Source case:** TPBH001..TPBH005 on T; TPBH013..TPBH017 on S; TPBH018..TPBH023 on B.
- **Acceptance:** for each pattern, peak-occupancy PDF stays below the K=256 line at 1 ppm; T/S/B coincide.

### Set 19 — Drop-probability surface (queue depth × ingress rate)

- **Subplots:** 1 contour panel, x = `K ∈ [8,256]`, y = `R_agg/R_cap ∈ [0,1]`, z = `ε(K, R)` log-scaled.
- **CSV:** `artifacts/publish/set19_drop_prob_surface.csv`
- **Renderer:** `scripts/publish/set19_drop_prob_surface.c`
- **Slide reference:** none (the architectural map for queue sizing).
- **Source case:** TPBH006 on T; cross-validated against TPBH012 and TPBH018.
- **Acceptance:** sequential darker-is-worse palette; reference isolines `ε ∈ {5%, 1%, 1 ppm}` overlaid with labels broken cleanly on the curve; vertical color bar height matched to plot body; matches `MATH_REPORT.md` table at the (256, 200 Mhit/s) operating point.

### Set 20 — Drop-probability vs queue depth at fixed rate (line plot)

- **Subplots:** 5 line series (one per traffic mode) of `ε(K)` at `R_agg = 200 Mhit/s`, log-y.
- **CSV:** `artifacts/publish/set20_drop_vs_depth.csv`
- **Renderer:** `scripts/publish/set20_drop_vs_depth.c`
- **Slide reference:** `MATH_REPORT.md` queue depth regions table.
- **Source case:** TPBH006 on T, TPBH012 on S, TPBH018..TPBH023 on B.
- **Acceptance:** reference horizontal lines at `5%`, `1%`, `1 ppm`; the local-cluster curve drops to zero at K=8; the iid/roaming/mixed/all-256 curves require K≈256 for 1 ppm; T/S/B coincide.

### Set 21 — Drop-probability vs ingress rate at fixed depth (line plot)

- **Subplots:** 5 line series (one per traffic mode) of `ε(R_agg/R_cap)` at `K=256`, log-y.
- **CSV:** `artifacts/publish/set21_drop_vs_rate.csv`
- **Renderer:** `scripts/publish/set21_drop_vs_rate.c`
- **Slide reference:** `MATH_REPORT.md`.
- **Source case:** TPBH006/TPBH012 cross.
- **Acceptance:** all curves stay below `1 ppm` until close to the cap; matches the architecture's "200 Mhit/s with no-drop iff K=256" claim.

### Set 22 — Burstiness–memory map (slide 45 reproduction)

- **Subplots:** 1 panel `(M, B)` scatter with the slide-45 trapezoidal envelope drawn in light grey; markers for `Poisson background`, `re-curling events`, `flow with bkg-like physics`, `flow with signal-like physics`, `charge-injection`, with annotation arrows matching slide 45.
- **CSV:** `artifacts/publish/set22_burstiness_memory.csv`
- **Renderer:** `scripts/publish/set22_burstiness_memory.c`
- **Slide reference:** slides 44, 45.
- **Source case:** the four physics regimes injected on the emulator (`hit_mode` and cluster controls) on S and B.
- **Acceptance:** every marker lands inside the regime predicted by the architect; trapezoidal envelope drawn but not overwhelming the markers; legend matches slide 45.

### Set 23 — Reordering Byte Offset (RBO) distribution

- **Subplots:** 1 panel `P(π)` of the per-packet RBO (slide 13 metric) at `r ∈ {1, 4, 7}` overlaid; reference `π = α(V) − 1` line drawn (slide 16 RBO bound).
- **CSV:** `artifacts/publish/set23_rbo_distribution.csv`
- **Renderer:** `scripts/publish/set23_rbo_distribution.c`
- **Slide reference:** slides 13, 16.
- **Source case:** S (ingress tap before re-sequencer), B equivalent.
- **Acceptance:** RBO distribution stays below the slide-16 bound at every rate; bound line labeled.

### Set 24 — RTO distribution (Reordering Time Offset)

- **Subplots:** 3 panels for `r ∈ {1, 4, 7}` of `P(λ)` overlaid with the `V` envelope (slide 22) and the `T = V` reference (slide 26).
- **CSV:** `artifacts/publish/set24_rto_distribution.csv`
- **Renderer:** `scripts/publish/set24_rto_distribution.c`
- **Slide reference:** slides 22, 26.
- **Source case:** S, B.
- **Acceptance:** `λ ≤ V` for every observation; `T = V` reference drawn; matches slide 22 visual.

### Set 25 — Ping-pong bank alternation regularity

- **Subplots:** 2 panels — top: bank-A vs bank-B occupancy time series; bottom: histogram of inter-swap interval (cycles).
- **CSV:** `artifacts/publish/set25_pingpong_alternation.csv`
- **Renderer:** `scripts/publish/set25_pingpong_alternation.c`
- **Slide reference:** none (correctness + readout-rate proof; per `TEST_PLAN.md` §4.5.4).
- **Source case:** TPB091 on B; integration tb on S.
- **Acceptance:** the inter-swap interval histogram has stddev < 1 interval; bank switching alternates regularly; no missed swap.

### Set 26 — Closure dependency stack (TLM ↔ SIM ↔ BOARD agreement matrix)

- **Subplots:** 1 heatmap, rows = TPB000..TPB100 (case ID), columns = {T, S, B, T-S, S-B, T-B}, cells = pass/fail (or numerical agreement ratio).
- **CSV:** `artifacts/publish/set26_closure_matrix.csv`
- **Renderer:** `scripts/publish/set26_closure_matrix.c`
- **Slide reference:** none (the chief-architect-facing scoreboard).
- **Source case:** the case-table from `TEST_PLAN_BASIC.md`.
- **Acceptance:** all cells PASS for closure; failing cells highlighted with a high-luminance hue separated from the sequential pass palette; row/column labels readable at the printed export size.

### Set 27 — Pre-gate sign-off summary (TPBH001..TPBH030 layered)

- **Subplots:** 1 panel — stacked bar per traffic mode (5 modes) showing `OVERFLOW_COUNT delta` on T (analytic = 0), S standalone, S integration, B; reference horizontal line at `0`.
- **CSV:** `artifacts/publish/set27_pregate_summary.csv`
- **Renderer:** `scripts/publish/set27_pregate_summary.c`
- **Slide reference:** none (TPBH gate evidence).
- **Source case:** TPBH001..TPBH029.
- **Acceptance:** every bar at 0; any bar > 0 is a hard fail and the bar is annotated with the case ID and the discrepancy.

### Set 28 — Phase 4 closure attestation page (golden-reference cover figure)

- **Subplots:** 2×2 grid — top-left: aggregate rate sweep (Set 4 collapsed), top-right: latency-vs-rate quantile envelope (Set 9), bottom-left: drop-probability surface (Set 19), bottom-right: closure matrix snapshot (Set 26).
- **CSV:** the four CSVs above (no new data).
- **Renderer:** `scripts/publish/set28_closure_cover.c`
- **Slide reference:** integrates slides 23, 25, 38, 40–42 into one chief-architect-facing cover.
- **Source case:** TPB100 attestation.
- **Acceptance:** every quadrant carries its short caption; layout passes the visual checklist (no overlap, color-bar height matched, sequential palette for the loss surface, decimal digits restored on sub-unit axes); DISLIN log `Warnings: 0`; matches the golden-reference rule sheet stored next to the figure.

---

## Layer / data provenance per figure

Every figure in this catalog is built from artifacts under `artifacts/publish/<setNN_*>.csv`, generated by:

- **T (TLM):** [`scripts/phase4_queue_tlm.py`](scripts/phase4_queue_tlm.py) plus a per-set extension under `scripts/publish/tlm_<setNN>.py` that emits the publish-grade CSV with the same modeling constants as `MATH_REPORT.md`.
- **S (RTL SIM):** Questa integration sim driven by [`../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh`](../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh) and `run_dp_hist_rate_sweep.sh` with the `TB_DP_*` plusargs of the matching TPB case, plus a per-set tap extractor under `scripts/publish/sim_<setNN>.py`.
- **B (BOARD):** runs from [`../../systems/system_20260427_testplanphase5/script/run_phase4_emulator.py`](../../systems/system_20260427_testplanphase5/script/run_phase4_emulator.py) and `probe_phase4_stage_counters.py`, then a per-set CSV reducer under `scripts/publish/board_<setNN>.py`.

The renderer for every set lives at `scripts/publish/setNN_<name>.c` (DISLIN), with a thin shell wrapper in `scripts/publish/render_publish.sh` that builds and runs all 28 sets, then re-runs the visual-checklist linter (per `~/.codex/skills/scientific-plotting/references/visual-checklist.md`) and fails the run if any of the rules below trips.

## Visual-checklist enforcement (must pass before signoff)

Every figure delivered for chief-architect review must pass these checks; the linter wrapper checks them per render.

1. Title band ≤ 2 lines; long definitions move to a caption beneath the plot body.
2. No overlap between titles, axis labels, ticks, legends, color bars; sub-unit axes show enough decimal digits.
3. Sequential palette darker-is-worse on every loss / drop / overflow / risk surface (sets 19, 20, 21, 27).
4. Color-bar vertical height matches the plot-body y-extent on every contour (sets 10, 11, 19).
5. Inline contour labels broken cleanly on the contour stroke; no grid line / isoline crossing the label (sets 10, 11, 19).
6. Reference isolines drawn 2–4 levels in the interior of the sampled range; not at the min/max edge (sets 10, 11, 19).
7. Axis range padded so the principal contour or pulse is not glued to the border (sets 6, 7, 10, 11, 13, 14).
8. Every set distinguishes T (modeled), S (simulated), B (measured) in legend or panel label.
9. DISLIN log reports `Warnings: 0` for every render; warnings treated as a layout bug until proven otherwise.
10. Each accepted figure is frozen as `artifacts/publish/golden/setNN_<name>.png` plus a one-page rule sheet `artifacts/publish/golden/setNN_<name>.rules.md` recording the exact accepted layout, scaling, labeling, and visual-balance constraints (per the skill).

## Acceptance for chief-architect signoff

The publish bundle is signed when:

- All 28 sets are rendered with `Warnings: 0` and pass the visual checklist.
- Every set's T, S, B traces overlay within the configured tolerance, or the discrepancy is recorded with the analytic explanation and routed per the disagreement protocol in [`TEST_PLAN_BASIC.md`](TEST_PLAN_BASIC.md).
- The 28 golden references and 28 rule sheets exist under `artifacts/publish/golden/`.
- The render wrapper `scripts/publish/render_publish.sh` exits 0 on a clean `make` from a fresh artifact directory.

Without this bundle signed, Phase 4 is not closed (this is in addition to the closure contract in [`../TEST_PLAN.md`](../TEST_PLAN.md) and the TPB / TPBH passes in [`TEST_PLAN_BASIC.md`](TEST_PLAN_BASIC.md)).
