# TEST_PLAN_BASIC.md — Phase 4 emulator + histogram basic-bucket catalog

**Companion:** [`MATH_REPORT.md`](MATH_REPORT.md) · [`TLM_REPORT.md`](TLM_REPORT.md) · [`TEST_REPORT.md`](TEST_REPORT.md) · [`../TEST_PLAN.md`](../TEST_PLAN.md) · [`../../systems/system_20260427_testplanphase5/model/`](../../systems/system_20260427_testplanphase5/model/)
**Canonical ID range:** `TPB000`–`TPB100` (basic) plus `TPBH001`–`TPBH030` (histogram-overflow pre-gate, hard prerequisite for Phase 4 closure)
**Intent:** the basic functional bucket every Phase 4 build must close before edge, profile, or error buckets become meaningful. Each case has a TLM, RTL-SIM, and on-board form, and a cross-layer DISLIN in-situ comparison that has to agree before the case passes.
**Upstream art-of-truth:** the MuTRiG delay-distribution slides at [`../../../docs/Archive/ethhw_reordering.pdf`](../../../docs/Archive/ethhw_reordering.pdf) (slide 23 random injection, slide 24 frame-synchronous header-delay sweep, slide 25 rate sweep, slide 38 ingress/egress comparison, slides 40–42 ring-CAM fill-level). The TLM model is calibrated to match these distributions; if SIM or board disagrees with TLM, debug starts at SIM/RTL — never edit the TLM to match a buggy SIM.

## Method / implementation legend

- **method** — `D` = directed (one deterministic stimulus configuration per case) · `R` = random (multi-seed)
- **implementation** — `live TLM` = Python/HDL TLM in [`../../systems/system_20260427_testplanphase5/model/phase4/scripts/`](../../systems/system_20260427_testplanphase5/model/phase4/scripts/) and [`../../systems/system_20260427_testplanphase5/model/phase4/tlm/`](../../systems/system_20260427_testplanphase5/model/phase4/tlm/) · `live SIM` = RTL integration sim driven by [`../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh`](../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_e2e.sh) and [`../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_hist_rate_sweep.sh`](../../systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/scripts/run_dp_hist_rate_sweep.sh) · `live BOARD` = on-board run via [`../../systems/system_20260427_testplanphase5/script/run_phase4_emulator.py`](../../systems/system_20260427_testplanphase5/script/run_phase4_emulator.py) and [`../../systems/system_20260427_testplanphase5/script/probe_phase4_stage_counters.py`](../../systems/system_20260427_testplanphase5/script/probe_phase4_stage_counters.py) · `live CMP` = DISLIN cross-layer compare via [`../../systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh`](../../systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh) · `planned` = stimulus exists, runner not yet wired
- **stage** — `T` = TLM (Python + HDL TLM) · `S` = RTL SIM (Questa integration tb_int) · `B` = on-board (FEB SciFi v3 via SWB) · `C` = cross-layer DISLIN compare (TLM ↔ SIM ↔ BOARD agree within tolerance)

## Wiring contract — emulator + injector + histogram

Every case below assumes the following datapath is verified live before the case starts. This is the explicit precondition the `TPB000` group enforces; if any item fails, no case in this catalog runs.

| Block | Source | Sink | Confirmation |
|---|---|---|---|
| 8 × `emulator_mutrig_N` (N=0..7) | `lvds_rx_28nm_0.outclock`, `master_datapath.master_reset` | per-lane `aso_tx8b1k` into hit_stack subsystem | `emulator_mutrig_N.csr[0x05]` `frame_count` increments (per `TEST_PLAN.md` §4.2) |
| `mutrig_injector` / `charge_injection_pulser` | SC writes via `mm_bridge` aperture | `coe_inject_pulse` / `coe_inject_masked_pulse` per emulator (see `emulator_mutrig.sv:55..57`) | injector arm bit observable, `INJ_ARM` SignalTap trigger never fires outside `RUNNING` |
| 7 × `hist_rate_splitter_N.out1 → histogram_statistics_0.fill_in_N` and `histogram_ingress_bridge_0.hist_out → histogram_statistics_0.hist_fill_in` | `scifi_datapath_system_v3.qsys` lines 2353, 2365–2395 | `histogram_statistics_0.csr[0x34]` `TOTAL_HITS` advances together with the SWB per-link counter | `TEST_PLAN.md` §4.4 |
| `coalescing_queue` inside `histogram_statistics_0` | `bin_divider` per-bin update stream | `pingpong_sram` updates | `histogram_statistics/rtl/coalescing_queue.vhd` `o_overflow_count` stays at 0 in the basic bucket; any tick is logged and gates Phase 4 closure |

## Catalog

<!-- columns:
  case_id          = TPB### canonical id (TPB000..TPB100, then TPBH001..TPBH030)
  method           = D (directed) / R (random multi-seed)
  implementation   = live TLM / live SIM / live BOARD / live CMP / planned
  scenario         = one-line stimulus description anchored on the emulator/injector/histogram CSR field map
  primary checks   = pass contract this case exercises, expressed in the same language as the slide observables and the IP CSR fields
  stage            = T (TLM) / S (RTL SIM) / B (BOARD) / C (cross-layer DISLIN compare)
-->

### TPB000 — wiring preflight (must pass before any other TPB case)

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB000 | D | live BOARD | preflight `TEST_PLAN.md` §0 + §4.1 — flash SWB from `online_sc`, FEB SciFi v3 from this repo, recover `/dev/mudaq0`, `script/build_local_tools.py`, `sc_tool read 0x00000` returns OK, `histogram_statistics_0.UID = 0x48495354` | every step in §0 passes; bridged read of `histogram_statistics_0` UID succeeds; emulator+injector instances are reachable through `mm_bridge` | B |
| TPB001 | D | live SIM | RTL integration tb wires `emulator_mutrig_0..7`, `mutrig_injector`, `histogram_ingress_bridge_0`, `histogram_statistics_0` (verify against `scifi_datapath_system_v3.qsys` instance list) | tb compiles; `TB_DP_RUN_CYCLES=2000` smoke run prints `INFO: hit_stack` plus `INFO: hist_fill` taps active; no protocol error | S |
| TPB002 | D | live TLM | Python TLM model runs via [`scripts/run_phase4_tlm.sh`](scripts/run_phase4_tlm.sh) and [`scripts/phase4_queue_tlm.py`](scripts/phase4_queue_tlm.py); produces the four CSV artifacts in §1 of [`MATH_REPORT.md`](MATH_REPORT.md) | TLM finishes `Errors: 0, Warnings: 0`; `phase4_tlm_summary.txt` records `FRAME_INTERVAL_SHORT=910`, `25 Mhit/s` per MuTRiG, `200 Mhit/s` aggregate | T |
| TPB003 | D | live CMP | DISLIN render via [`../../systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh`](../../systems/system_20260427_testplanphase5/model/phase4/scripts/render_phase4_plots.sh) produces the four required plots | DISLIN log reports `Warnings: 0`; PNG and SVG present for latency, rate, queue depth, MuTRiG injection | C |

### TPB004–TPB019 — single-channel-only sweep (one channel enabled per MuTRiG, all others masked)

For each case the emulator under test programs `csr[0x06].inject_channel_mask = (1<<ch)` for the chosen `ch`, all other lanes hold `inject_channel_mask=0`, `csr[0x00].enable=1`, `hit_mode=POISSON_IID`, `short_mode=1`, `csr[0x01].hit_rate=0x0100` (≈ wire-floor), `noise_rate=0`. Injection is off in this group; the channel-mask path is exercised through dark-rate Poisson hits.

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB004 | D | live SIM, live BOARD | lane 0, `ch=0` only; all other lanes muted | `histogram_statistics_0.hist_bin[0]` is the only nonzero bin among the 32 lane-0 bins (offset 0..31); `TOTAL_HITS` advances; `OVERFLOW_COUNT=0`, `UNDERFLOW_COUNT=0`, `DROPPED_HITS=0` | S/B |
| TPB005 | D | live SIM, live BOARD | lane 0, `ch=15` only | only bin 15 in lane-0 slice nonzero; lane offsets per `histogram_statistics/rtl/histogram_statistics.vhd` port-offset rule | S/B |
| TPB006 | D | live SIM, live BOARD | lane 0, `ch=31` (top-of-lane corner) | only bin 31 nonzero; verifies channel `[4:0]=0x1F` does not alias to lane 1 base | S/B |
| TPB007 | D | live SIM, live BOARD | lane 1, `ch=0` only | only the bin at `lane_index*N_CHAN_PER_LANE + 0` is nonzero; verifies port-offset addition (DV_BASIC §1 case B012 analog) | S/B |
| TPB008 | D | live SIM, live BOARD | lane 1, `ch=31` | exactly one bin nonzero at the predicted offset | S/B |
| TPB009 | D | live SIM, live BOARD | lane 2, `ch=0` | exactly one bin nonzero | S/B |
| TPB010 | D | live SIM, live BOARD | lane 3, `ch=0` | exactly one bin nonzero | S/B |
| TPB011 | D | live SIM, live BOARD | lane 4, `ch=0` | exactly one bin nonzero | S/B |
| TPB012 | D | live SIM, live BOARD | lane 5, `ch=0` | exactly one bin nonzero | S/B |
| TPB013 | D | live SIM, live BOARD | lane 6, `ch=0` | exactly one bin nonzero | S/B |
| TPB014 | D | live SIM, live BOARD | lane 7, `ch=31` | exactly one bin nonzero at the absolute top index 255; confirms channel concatenation across all 8 lanes covers 256 bins | S/B |
| TPB015 | R | live SIM, live BOARD | for `ch ∈ {0..31}` swept on lane 0 over 32 successive runs (campaign seed 260425) | each run lights exactly one expected bin; bin index across runs covers `0..31` exhaustively | S/B |
| TPB016 | R | live SIM, live BOARD | sweep `(lane, ch)` over all 256 combinations | each run lights exactly one bin at the predicted absolute index; aggregate run hits every bin in `0..255` exactly once | S/B |
| TPB017 | D | live TLM | TLM single-channel injection-mode-off Poisson, replicates per-bin landing distribution for one channel | TLM bin-population PDF agrees with the analytic single-channel Poisson estimate within 1σ | T |
| TPB018 | D | live CMP | TLM bin distribution from TPB017 vs SIM bin distribution from TPB016 vs BOARD bin distribution from TPB016 — DISLIN single-bin overlay plot | three curves coincide within configured tolerance; if not, debug SIM first then RTL — TLM is the truth | C |
| TPB019 | D | live SIM, live BOARD | inverse mask: `inject_channel_mask = 0xFFFFFFFE` on lane 0 (channel 0 disabled, all others enabled) | bin 0 of lane-0 slice stays 0; bins 1..31 of lane-0 slice all advance; cross-check against `OVERFLOW_COUNT` ≥ 0 invariant | S/B |

### TPB020–TPB031 — channel-mask patterns

Every emulator programmed with the same mask. `hit_mode=POISSON_IID`, `hit_rate=0x0100`, `noise_rate=0`, `short_mode=1`, no injection.

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB020 | D | live SIM, live BOARD | `inject_channel_mask=0xFFFFFFFF` (all 32 channels enabled, all lanes) | all 256 bins eventually populated; per-lane Poisson uniformity check passes (no per-channel deficit > Poisson 3σ) | S/B |
| TPB021 | D | live SIM, live BOARD | `inject_channel_mask=0x0000FFFF` (lower half) | only lane-local channels 0..15 populated across all lanes; channels 16..31 are zero in every lane slice | S/B |
| TPB022 | D | live SIM, live BOARD | `inject_channel_mask=0xFFFF0000` (upper half) | inverse of TPB021 | S/B |
| TPB023 | D | live SIM, live BOARD | `inject_channel_mask=0x55555555` (even channels) | only even lane-local channels populated | S/B |
| TPB024 | D | live SIM, live BOARD | `inject_channel_mask=0xAAAAAAAA` (odd channels) | only odd lane-local channels populated | S/B |
| TPB025 | D | live SIM, live BOARD | `inject_channel_mask=0x00000001` (one channel only) | one channel per lane populated; cross-lane comparison shows identical population rate within Poisson tolerance | S/B |
| TPB026 | D | live SIM, live BOARD | `inject_channel_mask=0x00FF00FF` (byte-lane stripe) | byte-lane decoding correct in the channel field of the hit record | S/B |
| TPB027 | D | live SIM, live BOARD | `inject_channel_mask=0x80000001` (corner pair: top + bottom) | exactly two channels populated per lane | S/B |
| TPB028 | D | live SIM, live BOARD | per-lane unique mask: lane N has only bit N set (N=0..7) | every lane contributes exactly one channel; bins at indices `N*32 + N` for N=0..7 populated, all other bins zero | S/B |
| TPB029 | D | live SIM, live BOARD | mask=0 on every lane | `TOTAL_HITS` floor matches dark-rate noise (per `csr[0x01].noise_rate`); no histogram bin advances except possibly lane-broadcast noise | S/B |
| TPB030 | D | live TLM | TLM repeats the eight masks above and records expected per-bin distribution | TLM produces a per-bin expectation table consumed by TPB031 | T |
| TPB031 | D | live CMP | DISLIN per-bin overlay TLM vs SIM vs BOARD for the eight masks | three curves overlay within tolerance; on disagreement, debug SIM/RTL first — never edit TLM | C |

### TPB032–TPB055 — injection mode 1 (frame-synchronous, header-delay sweep — slide 24 truth)

Injection mode 1 is the frame-synchronous form: the injector pulse is locked to the MuTRiG frame mark; the only knob is the header delay (offset of the injection pulse relative to the frame preamble, in MuTRiG byte-clock cycles). Per slide 24 of `ethhw_reordering.pdf`, the egress latency distribution for each header_delay is a narrow rectangular pulse at `(FRAME_INTERVAL_SHORT - header_delay)` with width set by the L2 store-and-forward time. As header_delay sweeps 0 -> FRAME_INTERVAL_SHORT, the pulse traverses the full 0-to-1-frame interval. This is the deterministic delta-delay function this catalog requires.

Setup common to TPB032..TPB055:
- one channel enabled (mask=0x00000001 on lane 0; lanes 1..7 muted)
- `csr[0x00].enable=1, hit_mode=POISSON, short_mode=1`
- `csr[0x01].hit_rate=0` (no background)
- `csr[0x01].noise_rate=0`
- injector armed in mode 1 (frame-synchronous), period = `FRAME_INTERVAL_SHORT` cycles
- per-case `header_delay` sweeps `{50, 100, 200, 300, 400, 500, 600, 700, 800, 900}` cycles
- `INTERVAL_CFG` set to 256k cycles to give the histogram enough hits per bin to resolve the pulse

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB032 | D | live TLM | `header_delay=50`, run 10⁶ injections | TLM latency PDF is a rectangular pulse centred at `FRAME_INTERVAL_SHORT - 50 = 860` cycles, width ≤ 100 cycles; matches slide 24 envelope shape for `header_delay=100` (closest panel) | T |
| TPB033 | D | live SIM | same stimulus into RTL integration tb (`TB_DP_USE_PERIODIC_INJECTOR`, `TB_DP_INJECT_MODE=1`, `TB_DP_INJECT_PERIOD=910`, `TB_DP_INJECT_HEADER_DELAY=50`) | RTL `emulator_dispatch_latency_hist.csv` mode equals 860 ± 8 cycles, distribution width ≤ 100 cycles | S |
| TPB034 | D | live BOARD | same stimulus on FEB SciFi v3; collect `histogram_statistics_0.hist_bin` over the configured interval | board latency hist mode at 860 ± 16 cycles, width ≤ 120 cycles (board includes link L2 jitter) | B |
| TPB035 | D | live CMP | DISLIN overlay TPB032/TPB033/TPB034 — three latency PDFs on one panel | curves coincide; if SIM disagrees with TLM → debug RTL; if BOARD disagrees with SIM → debug board fabric. Never edit TLM. | C |
| TPB036 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=100`; expected mode 810 ± 8 | one delta pulse at 810 across all three layers | T/S/B/C |
| TPB037 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=200`; expected mode 710 ± 8 | one delta pulse at 710 across all three layers | T/S/B/C |
| TPB038 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=300`; expected mode 610 ± 8 | one delta pulse at 610 | T/S/B/C |
| TPB039 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=400`; expected mode 510 ± 8 | one delta pulse at 510 | T/S/B/C |
| TPB040 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=500`; expected mode 410 ± 8 | one delta pulse at 410 | T/S/B/C |
| TPB041 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=600`; expected mode 310 ± 8 | one delta pulse at 310 | T/S/B/C |
| TPB042 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=700`; expected mode 210 ± 8 | one delta pulse at 210 | T/S/B/C |
| TPB043 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=800`; expected mode 110 ± 8 | one delta pulse at 110 | T/S/B/C |
| TPB044 | D | live TLM, live SIM, live BOARD, live CMP | `header_delay=900`; expected mode ≤ 50 cycles | last panel: pulse approaches the frame mark; matches the slide-24 yellow-trace panel | T/S/B/C |
| TPB045 | D | live CMP | DISLIN small-multiples panel: TPB032..TPB044 all on one figure with one panel per `header_delay` (replicates slide 24 layout) | nine panels each show one narrow pulse at the predicted offset; total rendering passes `Warnings: 0` | C |
| TPB046 | D | live SIM, live BOARD | per-MuTRiG repeat for emulator_mutrig_1..7 with `header_delay=400` | each emulator independently produces the same delta pulse position; lane-uniform behavior confirmed | S/B |
| TPB047 | D | live SIM, live BOARD | injection mode 1 with `short_mode=0` (long frame, `FRAME_INTERVAL_LONG=1550`); `header_delay=400` | mode pulse at `1550 - 400 = 1150` cycles; pulse width ≤ 120 cycles | S/B |
| TPB048 | D | live SIM, live BOARD | injection mode 1 with two channels enabled (mask=0x00000003), `header_delay=400` | two superposed pulses at the same latency; aggregate `TOTAL_HITS` doubles vs TPB039 | S/B |
| TPB049 | R | live SIM, live BOARD | for header_delay ∈ {0..909} stride 10 (~91 settings) sweep on lane 0, single channel | the 91 DISLIN panels reproduce slide 24's continuous traversal of the frame interval | S/B |
| TPB050 | D | live BOARD | injection mode 1 stress: arm, run for 60 s at FRAME_INTERVAL_SHORT, observe `histogram_statistics_0.OVERFLOW_COUNT` | overflow stays at 0; if not zero, halt and route to TPBH series before any other TPB case proceeds | B |
| TPB051 | D | live SIM, live BOARD | injection mode 1 — disable injector mid-run, confirm pulse disappears within 1 frame | latency hist tail empties; no residual delta pulse after the next frame mark | S/B |
| TPB052 | D | live SIM, live BOARD | injection mode 1 — re-arm injector mid-run, confirm pulse reappears at the configured offset within 1 frame | latency hist re-acquires the predicted delta pulse | S/B |
| TPB053 | D | live BOARD | inject mode 1 with `INJ_ARM` SignalTap trigger from `TEST_PLAN.md` §4.3 (injector armed outside RUNNING) | trigger never fires during the test window; if it does, the test is invalid | B |
| TPB054 | D | live SIM | injector arm-while-IDLE (negative test — must not produce hits) | no hits enter the histogram, no `INJ_ARM` violation, no spurious `OVERFLOW` | S |
| TPB055 | D | live CMP | aggregate DISLIN summary plot for injection mode 1: TLM vs SIM vs BOARD across all header_delay points (peak position vs header_delay scatter) | the three curves are linear with slope -1 and intercept `FRAME_INTERVAL_SHORT`; deviation is logged and routed to debug | C |

### TPB056–TPB079 — injection mode 2 (free-running, rate sweep — slides 23, 25, 38 truth)

Injection mode 2 is the free-running form: the injector pulse is NOT locked to the MuTRiG frame; the only knob is the (per-MuTRiG, per-channel-aggregate) ingress rate. Per slide 23 the latency PDF is one rectangular block centred near 800 cycles whose right edge grows with rate. Per slide 25, panels for `ingress_rate=1..7` (events per frame) show the block widening monotonically from a narrow ~200-cycle bar at rate=1 to a ~700-cycle bar at rate=7, spanning roughly 0-to-2 short frames at the wire-speed limit. Per slide 38 (Figure 4(a)), the egress side of the re-sequencing buffer shifts the block by a bounded `T = V` and otherwise preserves the same shape.

Setup common to TPB056..TPB079:
- 32 channels enabled (`inject_channel_mask=0xFFFFFFFF`) on the lane(s) under test
- `csr[0x00].enable=1, hit_mode=POISSON_IID, short_mode=1`
- `csr[0x01].noise_rate=0`
- injector armed in mode 2 (free-running), period set to produce a target ingress rate
- per-case rate label `r=N` corresponds to the slide-25 ingress_rate, where `r=1 → ≈ 25/8 Mhit/s` per channel slot, scaled so `r=7` reaches the 25 Mhit/s per-MuTRiG cap

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB056 | D | live TLM | `r=1`, lane 0 only | TLM latency PDF is a narrow block from ~800 to ~1000 cycles; matches slide 25 panel `r=1` | T |
| TPB057 | D | live SIM | same stimulus into RTL integration tb (`TB_DP_USE_PERIODIC_INJECTOR`, `TB_DP_INJECT_MODE=2`, `TB_DP_INJECT_PERIOD` = rate-1 spec) | RTL latency hist matches the TLM block within tolerance | S |
| TPB058 | D | live BOARD | same stimulus on FEB SciFi v3; histogram CSR + `decoded_lane_fifo_N` levels | board latency hist matches SIM within tolerance; `DROPPED_HITS=0`, `OVERFLOW_COUNT=0` | B |
| TPB059 | D | live CMP | DISLIN overlay TPB056/TPB057/TPB058 | three curves coincide; failures route to RTL debug, then board debug — never edit TLM | C |
| TPB060 | D | live TLM, live SIM, live BOARD, live CMP | `r=2` | block widens to ~800–1100 cycles | T/S/B/C |
| TPB061 | D | live TLM, live SIM, live BOARD, live CMP | `r=3` | block widens to ~800–1200 cycles | T/S/B/C |
| TPB062 | D | live TLM, live SIM, live BOARD, live CMP | `r=4` | block widens to ~800–1300 cycles | T/S/B/C |
| TPB063 | D | live TLM, live SIM, live BOARD, live CMP | `r=5` | block widens to ~800–1400 cycles | T/S/B/C |
| TPB064 | D | live TLM, live SIM, live BOARD, live CMP | `r=6` | block widens to ~800–1500 cycles | T/S/B/C |
| TPB065 | D | live TLM, live SIM, live BOARD, live CMP | `r=7` (≈ 25 Mhit/s per MuTRiG, the wire-speed cap) | block spans ~800–1600 cycles, approaching 0-to-2-frame envelope; `latency_max ≤ pipe + 2*FRAME_INTERVAL_SHORT` from `MATH_REPORT.md` | T/S/B/C |
| TPB066 | D | live CMP | DISLIN small-multiples panel TPB056..TPB065 stacked vertically (replicates slide 25 layout) | seven panels show the monotone widening from r=1 to r=7 across all three layers | C |
| TPB067 | D | live BOARD | repeat `r=7` across emulator_mutrig_0..7 individually | each MuTRiG independently reaches the same 25 Mhit/s wire-speed cap with the same block envelope | B |
| TPB068 | D | live SIM, live BOARD | injection mode 2 with `short_mode=0` (long frames, `FRAME_INTERVAL_LONG=1550`), `r=4` | block scales with the longer frame interval; `latency_max ≤ pipe + 2*FRAME_INTERVAL_LONG` | S/B |
| TPB069 | D | live SIM, live BOARD | injection mode 2 with mask=0x00000001 (single channel) at saturation (per-channel rate hits the wire-speed cap at the channel level) | block exhibits one-channel queueing tail beyond `FRAME_INTERVAL_SHORT` due to channel-local L2 FIFO occupancy | S/B |
| TPB070 | D | live SIM, live BOARD | injection mode 2 with mask=0x000000FF (8 channels enabled, slide-44 "physical cluster" geometry) | per slide 25/41 with the cluster geometry, latency block consistent with localized L2 fill — `OVERFLOW_COUNT=0` | S/B |
| TPB071 | D | live SIM, live BOARD | injection mode 2 with two MuTRiG enabled (lane 0 and lane 1), independent injectors at `r=4` | aggregate latency hist = superposition of two independent blocks; cross-talk between lanes ≤ 1% | S/B |
| TPB072 | D | live SIM, live BOARD | injection mode 2 with all 8 MuTRiG at `r=4` (4 hits/frame each, ≈ 100 Mhit/s aggregate) | aggregate `TOTAL_HITS` ratio vs single-lane `r=4` is 8.0 ± 0.05; `DROPPED_HITS=0` | S/B |
| TPB073 | D | live SIM, live BOARD | injection mode 2 with all 8 MuTRiG at `r=7` (≈ 200 Mhit/s aggregate, the histogram input cap) | aggregate `TOTAL_HITS` rate is 200 Mhit/s ± 1%; `DROPPED_HITS=0`, `OVERFLOW_COUNT=0` | S/B |
| TPB074 | D | live BOARD | repeat TPB073 for 60 s soak with `--measure-after-end` post-end flush check | post-end flush clean; `DROPPED_HITS delta=0` | B |
| TPB075 | D | live CMP | DISLIN cross-layer summary for `r=7`: TLM (target 200 Mhit/s, 0-2-frame envelope) vs SIM vs BOARD aggregate latency PDF | three curves coincide within 5%; if board shows clipping below 200 Mhit/s (the historical 135 Mhit/s knee from `inputs/board/phase4_emulator_20260425_*`), the case fails and routes to RTL/board debug | C |
| TPB076 | D | live TLM | TLM ingress vs egress comparison (replicates slide 38 Figure 4(a)) — generates `phase4_tlm_ingress_egress.csv` | egress block is shifted right by `T = V` and otherwise the same shape; matches slide 38 within tolerance | T |
| TPB077 | D | live SIM, live CMP | RTL ingress (pre-RBCAM) vs egress (post-RBCAM) latency hist for `r=7`; DISLIN side-by-side panel matching slide 38 layout | RTL ingress and egress shapes match the TLM truth | S/C |
| TPB078 | D | live BOARD | board ingress (pre-hist-stack) vs egress (post-hist-stack) via `histogram_ingress_bridge_0` taps; DISLIN side-by-side panel | board ingress/egress shapes match SIM and TLM | B |
| TPB079 | D | live CMP | DISLIN final injection-mode-2 closure plot: combined {TLM, SIM, BOARD} × {ingress, egress} × {r=1..7} | every panel agrees across the three layers; failures are recorded with the per-panel discrepancy ratio for RTL/board debug | C |

### TPB080–TPB100 — physical rate sweep, lane-skew, mixed traffic, signoff

Setup: full 8-MuTRiG bring-up at varying rate; `inject_channel_mask=0xFFFFFFFF` unless noted.

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPB080 | D | live SIM, live BOARD | rate sweep `csr[0x01].hit_rate ∈ {0x0100, 0x0200, 0x0400, 0x0800, 0x1000, 0x2000, 0x4000, 0x8000}` (matches `TEST_REPORT.md` rate sweep grid) | rate-doubling ratio holds 2.0 ± 5% up to 0x0800; clip at 0x1000 reflects the 200 Mhit/s physical cap, NOT the historical 135 Mhit/s knee | S/B |
| TPB081 | D | live TLM | TLM rate sweep matching TPB080 | TLM clip at 0x1000 = 200 Mhit/s exactly; modeled accepted rate at 0x0800 = 195.286719 Mhit/s (matches `TLM_REPORT.md` table) | T |
| TPB082 | D | live CMP | DISLIN rate-sweep overlay TLM vs SIM vs BOARD (same axes as `phase4_rate_sweep.png`) | three curves coincide; the board curve is no longer permitted to clip at 135 Mhit/s | C |
| TPB083 | D | live BOARD | refreshed board run via `../../systems/system_20260427_testplanphase5/script/run_phase4_emulator.py --measure-after-end --output ../../systems/system_20260427_testplanphase5/reports/phase4_emulator_<date>_target200.md` | board run reports the 200 Mhit/s clip target, not the legacy 135 Mhit/s knee; `DROPPED_HITS=0`, post-end flush clean | B |
| TPB084 | D | live SIM, live BOARD | per-lane rate skew: lane 0 at `r=7`, lane 1..7 at `r=1` | aggregate `TOTAL_HITS` matches expected; per-lane DMA path retains independent counters; `OVERFLOW_COUNT=0` | S/B |
| TPB085 | D | live SIM, live BOARD | inverse skew: lane 0 at `r=1`, lane 1..7 at `r=7` | aggregate matches expected; lane-imbalance does not corrupt the histogram | S/B |
| TPB086 | D | live SIM, live BOARD | mixed traffic: 4 lanes Poisson at `r=4`, 4 lanes injection mode 1 at `header_delay=400` | latency hist superposes a wide Poisson block (slide 25) with a narrow delta pulse (slide 24); both features visible; `DROPPED_HITS=0` | S/B |
| TPB087 | D | live SIM, live BOARD | mixed traffic: 4 lanes Poisson at `r=4`, 4 lanes injection mode 2 at saturation | latency hist is a single broad block; `DROPPED_HITS=0`, `OVERFLOW_COUNT=0` | S/B |
| TPB088 | D | live SIM, live BOARD | local-cluster geometry: 8-channel cluster confined to lane 0 channels 0..7 at saturation | per `MATH_REPORT.md` queue-depth table (`local physical cluster, 8 bins`), depth-8 region holds; `OVERFLOW_COUNT=0` | S/B |
| TPB089 | D | live SIM, live BOARD | roaming cluster geometry: 8-channel cluster sweeps across all 256 bins | per `MATH_REPORT.md` (`roaming cluster-8 over 256 bins`), 1 ppm region requires depth 256; `OVERFLOW_COUNT=0` only if `COAL_QUEUE_DEPTH=256` | S/B |
| TPB090 | D | live SIM, live BOARD | all-channel injection burst: every channel asserts in the same frame | per `MATH_REPORT.md` (`all-256 injection burst`), depth-256 region required; `OVERFLOW_COUNT=0` only if `COAL_QUEUE_DEPTH=256`; otherwise overflow non-zero is the expected guarded fail | S/B |
| TPB091 | D | live BOARD | `BANK_STATUS` ping-pong sanity over 32 intervals | bank alternates with stddev < 1 interval (matches `TEST_PLAN.md` §4.5.4) | B |
| TPB092 | D | live BOARD | SignalTap one-shot capture for `OVRFL_INC` and `UNDR_INC` triggers (per `TEST_PLAN.md` §4.3) over 60 s clean run | neither trigger fires; if either does, halt and route to TPBH series before further TPB cases | B |
| TPB093 | D | live BOARD | SignalTap one-shot capture for `DROP_INC`, `RR_VIOL`, `SOP_NO_EOP`, `CRC_ERR` triggers over 60 s clean run | none fires; if any does, the run is recorded and routed to debug | B |
| TPB094 | D | live BOARD | repeat `histogram_statistics_0` UID/META/CONTROL read (TPB000 cross-check) at the end of every TPB run | UID still `0x48495354`; META still equals the packaged version; no CSR drift over the run | B |
| TPB095 | D | live SIM, live BOARD | bucket signoff for emulator+histogram: 8 lanes at `r=7`, 60-second soak, all integrity counters captured before/after | `TOTAL_HITS` advance ≥ expected; `DROPPED_HITS delta=0`; `OVERFLOW_COUNT delta=0`; `UNDERFLOW_COUNT delta=0`; ping-pong alternation regular | S/B |
| TPB096 | D | live CMP | DISLIN closure plot: stacked TLM vs SIM vs BOARD on rate, latency, queue depth, ingress vs egress (replicates slides 23, 25, 38, 40-42) | every panel agrees across all three layers within configured tolerance; the three layers form the in-situ comparison required by the workflow contract | C |
| TPB097 | D | live SIM, live BOARD | bucket-frame mode signoff: TPB001..TPB096 chained inside one continuous timeframe, no harness reset between cases | every case closes its own pass criteria with no inter-case state leakage | S/B |
| TPB098 | D | live BOARD | full-image regression: TPB000..TPB096 across the latest FEB SciFi v3 SOF and the latest SWB `online_sc` SOF | every case PASS; the `phase4_emulator_<date>.md` and `phase4_stage_probe_<date>.md` reports are checked into `../../systems/system_20260427_testplanphase5/reports/` | B |
| TPB099 | D | live CMP | TLM vs SIM vs BOARD signoff DISLIN page: one figure per slide-23, slide-24, slide-25, slide-38, slide-40 reproducing the upstream art | five DISLIN figures generated; each reproduces the upstream slide with the live data | C |
| TPB100 | D | live BOARD, live CMP | Phase 4 closure attestation: TPBH series (below) PASS + TPB000..TPB099 PASS + TPB003 plot bundle PASS + cross-layer disagreement ratios all within tolerance | no Phase 4 closure without this case PASS | B/C |

## Histogram-overflow pre-gate — TPBH001..TPBH030 (mandatory before Phase 4 closure)

The histogram_statistics IP is the rate and latency observation surface for every TPB case above. If it overflows under any traffic pattern within the basic bucket, every rate or latency number measured downstream is unreliable. The pre-gate proves that the IP cannot overflow under the maximum hit rate and any of the basic-bucket traffic patterns. Each case has TLM, RTL standalone tb, RTL integration sim, and on-board forms; the pre-gate closes only when all four agree that overflow stays at zero.

Setup common to TPBH series:
- DUT under TLM: [`scripts/phase4_queue_tlm.py`](scripts/phase4_queue_tlm.py) extended to record `(traffic_pattern, queue_depth, rate, overflow_count, peak_occupancy, dropped_count)` rows
- DUT under standalone RTL tb: [`../../../histogram_statistics/tb/`](../../../histogram_statistics/tb/) with `N_BINS=256, COAL_QUEUE_DEPTH=256, KICK_WIDTH=8` (verify against `histogram_statistics/rtl/coalescing_queue.vhd:29..30`)
- DUT under RTL integration sim: `histogram_statistics_0` inside the SciFi datapath, fed by the same emulator+injector configuration as the matching TPB case
- DUT on board: `histogram_statistics_0` on FEB SciFi v3, observed via `OVERFLOW_COUNT (0x24)`, `UNDERFLOW_COUNT (0x20)`, `TOTAL_HITS (0x34)`, `DROPPED_HITS (0x38)`, `BANK_STATUS (0x2C)`

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| TPBH001 | D | live TLM | iid Poisson over 256 bins at 200 Mhit/s, `COAL_QUEUE_DEPTH=256` | `overflow_count=0` for ≥ 10⁹ hit events; queue peak occupancy distribution matches `phase4_queue_depth_regions.csv` 1 ppm row (depth 256) | T |
| TPBH002 | D | live TLM | local 8-channel physical cluster at 200 Mhit/s, `COAL_QUEUE_DEPTH=8` | `overflow_count=0`; matches `MATH_REPORT.md` (depth 8 sufficient for local cluster) | T |
| TPBH003 | D | live TLM | roaming cluster-8 over 256 bins at 200 Mhit/s, `COAL_QUEUE_DEPTH=256` | `overflow_count=0` at 1 ppm | T |
| TPBH004 | D | live TLM | 50/50 iid + cluster-8 mix at 200 Mhit/s, `COAL_QUEUE_DEPTH=256` | `overflow_count=0` at 1 ppm | T |
| TPBH005 | D | live TLM | all-256 injection burst, `COAL_QUEUE_DEPTH=256` | `overflow_count=0` for the full burst; matches `MATH_REPORT.md` table all-256 row | T |
| TPBH006 | D | live TLM | wire-floor sweep at `COAL_QUEUE_DEPTH ∈ {8, 16, 32, 64, 128, 256}` for each of the five traffic patterns above | for every (pattern, depth) cell, `overflow_count` reproduces the analytic prediction in `MATH_REPORT.md` | T |
| TPBH007 | D | live SIM (standalone) | run `histogram_statistics/tb` with iid Poisson stimulus at saturation | tb logs `OVERFLOW_COUNT=0`; matches TPBH001 | S |
| TPBH008 | D | live SIM (standalone) | local 8-cluster stimulus at saturation | matches TPBH002 | S |
| TPBH009 | D | live SIM (standalone) | roaming cluster-8 stimulus at saturation | matches TPBH003 | S |
| TPBH010 | D | live SIM (standalone) | mixed iid+cluster stimulus at saturation | matches TPBH004 | S |
| TPBH011 | D | live SIM (standalone) | all-256 burst stimulus | matches TPBH005 | S |
| TPBH012 | D | live SIM (standalone) | depth-stress: rebuild standalone tb with `COAL_QUEUE_DEPTH=8` and replay TPBH006 patterns | overflow grows for non-local patterns and stays zero for the local cluster, matching the TLM table; this is the controlled negative gate that proves the overflow signal is observable | S |
| TPBH013 | D | live SIM (integration) | integration tb with `r=7` on all 8 MuTRiG, no injection | `OVERFLOW_COUNT=0`, `DROPPED_HITS=0`, peak ring-CAM fill matches `phase4_queue_depth_regions.csv` for the iid pattern | S |
| TPBH014 | D | live SIM (integration) | integration tb with `r=7` plus injection mode 2 at saturation on lane 0 | `OVERFLOW_COUNT=0`, `DROPPED_HITS=0`; peak fill matches expected | S |
| TPBH015 | D | live SIM (integration) | integration tb with all-channel injection burst | `OVERFLOW_COUNT=0`; coalescing queue absorbs the burst | S |
| TPBH016 | D | live SIM (integration) | integration tb with cluster-8 burst on each lane | `OVERFLOW_COUNT=0`; cluster geometry preserved through the queue | S |
| TPBH017 | D | live SIM (integration) | 60-second soak at the highest TPB rate point | `OVERFLOW_COUNT delta=0` over the full soak window | S |
| TPBH018 | D | live BOARD | `r=7` on all 8 MuTRiG for 60 s; read `OVERFLOW_COUNT` before/after | delta=0; if non-zero, the gate fails — every downstream TPB rate/latency number is invalidated until the gate is re-passed | B |
| TPBH019 | D | live BOARD | `r=7` plus injection mode 2 saturation on each lane in turn (8-iter sweep) | delta=0 across all 8 iterations | B |
| TPBH020 | D | live BOARD | injection mode 1 stress: arm injector at `header_delay=0`, run for 60 s | `OVERFLOW_COUNT delta=0`; matches TPB050 | B |
| TPBH021 | D | live BOARD | all-channel injection burst on board (per the slide-25 worst case) | delta=0 | B |
| TPBH022 | D | live BOARD | cluster-8 burst on each lane on board | delta=0 | B |
| TPBH023 | D | live BOARD | mixed traffic on board (matches TPB087) | delta=0 | B |
| TPBH024 | D | live BOARD | observability cross-check — write 1 to `OVERFLOW_COUNT` to test write-clear semantics where supported | counter clears as documented in the SVD; if not documented, this case is informational only and recorded | B |
| TPBH025 | D | live CMP | DISLIN overlay TLM (TPBH001..TPBH006) vs SIM (TPBH007..TPBH017) vs BOARD (TPBH018..TPBH023) on `(traffic_pattern, queue_depth, peak_occupancy)` | three curves agree across patterns; in particular the `peak_occupancy` PDF on board matches the TLM ring-CAM PDF (slides 40, 41, 42) | C |
| TPBH026 | D | live CMP | DISLIN overlay matching slide 40 ("PDF of ring-CAM fill-level") for `inject_interval ∈ {1000, 500, 250, 125}` | board PDF matches TLM PDF; if board shows tail beyond the TLM-predicted maximum, route to RTL debug | C |
| TPBH027 | D | live CMP | DISLIN overlay matching slide 41 ("fill-level of CAM") for `(rate=1, delay=100)` and `(rate=7, delay=100)` | board PDFs match TLM PDFs across both panels | C |
| TPBH028 | D | live CMP | DISLIN overlay matching slide 42 (rate sweep + injection-interval sweep ring-CAM PDF) | board curves match TLM curves across the full rate and interval sweep | C |
| TPBH029 | D | live BOARD | full pre-gate signoff run: TPBH018..TPBH023 chained, single bucket-frame, single report | one report file in `../../systems/system_20260427_testplanphase5/reports/phase4_overflow_pregate_<date>.md`; ALL deltas zero | B |
| TPBH030 | D | live CMP | pre-gate closure attestation: TPBH001..TPBH029 ALL PASS, three-layer agreement on every cell of the (pattern, depth) matrix | gate signed; without this case PASS, Phase 4 closure cannot proceed | C |

## Execution modes

- **isolated** — one TPB case at a time on TLM, SIM, or board (per the relevant runner script).
- **bucket_frame** — sweep TPB000..TPB100 in order inside one continuous timeframe; no harness reset between cases.
- **all_buckets_frame** — bucket order TPBH (pre-gate) → TPB000..TPB100; this is the canonical Phase 4 closure run and is the only mode that may produce the closure attestation report.

## Pass / fail aggregation

| Aggregate | Pass when |
|---|---|
| TPB000 wiring | every datapath in the wiring contract verified live |
| TPB004..TPB019 single-channel | every (lane, ch) combination produces exactly one nonzero bin at the predicted absolute index |
| TPB020..TPB031 mask patterns | every mask reproduces its predicted bin geometry; TLM↔SIM↔BOARD agree |
| TPB032..TPB055 injection mode 1 | latency PDF is a delta pulse at `FRAME_INTERVAL_SHORT - header_delay` for every header_delay; TLM↔SIM↔BOARD agree; matches slide 24 |
| TPB056..TPB079 injection mode 2 | latency PDF widens monotonically with rate, capped at `pipe + 2*FRAME_INTERVAL_SHORT`; TLM↔SIM↔BOARD agree; matches slides 23, 25, 38 |
| TPB080..TPB100 rate / signoff | rate sweep grows through the 0x0800 model point and clips only at the 200 Mhit/s physical target; `DROPPED_HITS=0`, `OVERFLOW_COUNT=0`, `UNDERFLOW_COUNT=0` everywhere |
| TPBH001..TPBH030 pre-gate | every cell of the (pattern, depth) matrix shows `OVERFLOW_COUNT=0` on TLM, SIM (standalone + integration), and BOARD; all three agree |

## Cross-layer disagreement protocol

If any DISLIN cross-layer comparison (live CMP) finds a discrepancy:

1. The TLM is treated as the architectural truth; do not modify it to chase a SIM or board observation.
2. If RTL SIM disagrees with TLM, debug the RTL — check `emulator_mutrig.sv`, `histogram_statistics.vhd`, `coalescing_queue.vhd`, and the integration tb stimulus, in that order.
3. If on-board disagrees with RTL SIM, debug the integration — flash state, SC bridge address, `histogram_ingress_bridge_0` mode, ping-pong interval, link L2 jitter, in that order.
4. Re-run the disagreeing case end-to-end; do not partial-update artifacts.
5. Append the disagreement and resolution to `BUG_HISTORY.md` of the relevant IP per the rtl-doc-style convention.

## Closure dependency graph

```text
TPBH001..TPBH030  (histogram-overflow pre-gate, hard prerequisite)
        │
        ▼
TPB000  (wiring preflight)
        │
        ▼
TPB001..TPB003  (TLM/SIM/CMP infrastructure live)
        │
        ▼
TPB004..TPB031  (channel-mask catalog)
        │
        ▼
TPB032..TPB055  (injection mode 1 — slide 24 truth)
TPB056..TPB079  (injection mode 2 — slides 23/25/38 truth)
        │
        ▼
TPB080..TPB096  (rate, lane-skew, mixed traffic, ping-pong, SignalTap)
        │
        ▼
TPB097..TPB100  (chained signoff, full-image regression, slide-replicating closure plots,
                 closure attestation)
```

A failure at any node halts the chain; the failing case is recorded with the cross-layer discrepancy ratio and routed per the disagreement protocol above. Phase 4 closes only when every node in the chain passes.
