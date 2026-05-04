# Integration Testbench: `system_20260504_emulator_type0/tb_int/`

**DUT:** `top_nostp_emulator_type0` (full FEB SciFi single-lane focus build).
**Companion docs:** [`../../doc/SYSTEM_PLAN.md`](../../doc/SYSTEM_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md).
**Author:** Mu3e IP team
**Date:** 2026-05-04
**Status:** Draft. Awaits approval before harness construction.

---

## 1. Purpose & Scope

`tb_int/` is the **integration UVM testbench** that verifies the full datapath of `system_20260504_emulator_type0` end-to-end with all IPs in the loop. It is the layer between standalone IP DV (e.g. `mu3e-ip-cores/misc/arb_hit_type0/tb/`) and the on-board bring-up.

The testbench drives traffic at the **upstream LVDS PHY boundary** with a virtual MuTRiG model, runs through the integrated datapath inside the focus build (`emulator_mutrig_qsys_lane`, `lvds_rx_controller_pro`, `mutrig_frame_deassembly`, `arb_hit_type0`, `backpressure_fifo`, `mutrig_timestamp_processor`, `ring_buffer_cam`, `histogram_ingress_bridge`, `histogram_statistics`), and reconciles every hit end-to-end through an out-of-order scoreboard.

### In scope

1. **Run-control verification (RC):** `runctl_mgmt_host` ↔ `run_control_splitter` ↔ every IP. Verify `IDLE → RUN_PREP → SYNC → RUNNING → TERMINATING → IDLE` is broadcast correctly and every IP reacts per its own contract.
2. **Slow-control verification (SC):** `sc_hub_v2` ↔ `mm_bridge` ↔ every CSR slave on the focus build. Verify CSR addressing, address-aperture bounds, and read/write atomicity.
3. **Datapath verification (DT):** end-to-end hit tracking from virtual-MuTRiG-emitted hits to histogram-statistics bin counts. Out-of-order scoreboard catches dropped, reordered, mis-attributed, and corrupted hits.
4. **Latency measurement at three observation points:** pre-rbCAM (after `arb_hit_type0` → before `ring_buffer_cam`), post-rbCAM (after `ring_buffer_cam`), FEB egress (after `packet_scheduler` framing). Latency CDFs, percentiles, and per-source breakdowns.
5. **Histogram cross-check:** compare the OoO scoreboard's reconstructed delay distribution against `histogram_statistics_0`'s bin counts at the same tap point. Mismatch is a hard fail.
6. **Reusable UVM infra:** every agent, scoreboard, and coverage collector is built so the same harness can be reused for future Mu3e integration testbenches by swapping the DUT-binding interface.

### Out of scope

- Quartus place-and-route timing closure (covered by `timing-performance-resources-sign-off` skill).
- SWB / FEB programming (on-board bring-up).
- Multi-lane integration (focus build is single-lane; multi-lane uses `arb_hit_type0_supercore`).
- Histogram **egress** snoop (deferred per user; capture is recorded as an open-item agent slot for a later patch).

---

## 2. UVM Infra (reusable)

All components under `tb_int/uvm/` follow the standard Mu3e UVM agent pattern (driver / monitor / sequencer / agent / config object). Reused components are placed under `tb_int/uvm/common/` so future integration testbenches consume them by import.

### 2.1 Agents

| Agent | Direction | Role |
|---|---|---|
| `mutrig_phy_agent` | active source on the LVDS PHY pin pair | Virtual MuTRiG ASIC. Generates **byte-stream-encoded** MuTRiG frames at the LVDS data-clock boundary, including 8b/10b encoding, frame headers, hit payloads, frame trailers, and idle K-codes. Emits hits with the canonical 48-bit MuTRiG hit-type-1 layout (channel, T-fine, T-coarse, E-coarse, flags). |
| `runctl_phy_agent` | active source on the synclink AVST 9-bit boundary | Drives `runctl_mgmt_host`'s synclink input with run-state command bytes. |
| `sc_phy_agent` | active master on the SC-bridge AVMM pin boundary | Drives the SC bridge's PCIe-mapped AVMM master. Mirrors what `sc_tool` does in software but at the simulated bus level. |
| `lvds_decoded_monitor` | passive | Snoops the post-deassembly `aso_hit_type0` boundary inside the lane's `mutrig_datapath_subsystem` (the **pre-rbCAM tap**). |
| `rbcam_egress_monitor` | passive | Snoops the post-`ring_buffer_cam` `aso_hit_type2` boundary (the **post-rbCAM tap**). |
| `feb_egress_monitor` | passive | Snoops the FEB-egress framed boundary at `feb_frame_assembly` output (the **FEB egress tap**). |
| `histogram_csr_monitor` | passive | Periodically polls `histogram_statistics_0`'s bin counters via the SC bridge for cross-check against scoreboard. |
| `l2_fifo_tlm_observer` | passive | TLM model of the per-lane MuTRiG L2 FIFO. **Wiggles a SystemVerilog `wire` per hit commit** so the scoreboard can timestamp the commit precisely. See §3.1. |

Every monitor publishes via a `uvm_analysis_port` typed to a `hit_record` transaction (channel, T-fine, T-coarse, source-id, observation-point, sim-time stamp).

### 2.2 Scoreboard

`tb_int_ooo_scoreboard` consumes analysis-port traffic from all monitors and runs an **out-of-order hit reconciliation engine**:

- Every `hit_record` is hashed by `(asic_id, channel, T-coarse, T-fine)` and stored in a hash table keyed on the OoO id.
- The hash table tracks per-id: `seen_at_l2_commit`, `seen_at_pre_rbcam`, `seen_at_post_rbcam`, `seen_at_feb_egress`. Each is a sim-time timestamp.
- Hits that complete the four-stage path are removed from the table and added to a closed-record collection.
- Hits that arrive at one stage but never reach the next within a configurable timeout are flagged as **dropped at stage X** and recorded with their syndrome.
- Hits that arrive at a downstream stage without having been observed upstream are **ghost hits** — hard fail.
- `RUN_TERMINATING` triggers a final reconciliation pass: any open hit-records older than the latency budget are flagged as dropped.

After every test, the scoreboard exports:

1. Closed-record CSV under `tb_int/sim/<test>/closed_records.csv` (one row per hit: `id, asic, ch, t_coarse, t_fine, t_l2, t_pre_rbcam, t_post_rbcam, t_feb_egress`).
2. Drop CSV under `tb_int/sim/<test>/drops.csv` (one row per missed hit: `id, asic, ch, last_seen_stage, last_seen_time`).
3. **Per-stage latency CDF** (numpy / matplotlib) for the three required observation points, plus the L2-commit reference, written to `tb_int/reports/<test>/latency_<stage>_cdf.png`.
4. **Histogram-vs-scoreboard cross-check report** at `tb_int/reports/<test>/hist_xcheck_<stage>.md` that overlays the IP histogram with the scoreboard's reconstructed delay distribution.

### 2.3 L2 FIFO commit observer (TLM)

The MuTRiG L2 FIFO inside `emulator_mutrig` (and the equivalent decoder buffer inside the real-MuTRiG path) commits a hit at a deterministic point in its internal pipeline. The TLM observer:

- Models the L2 FIFO as a Python-friendly transaction queue (push on hit-write, pop on frame-assembly drain).
- Drives a SystemVerilog `wire` named `tb_int_l2_commit` (one per source) that wiggles `1` for one cycle on each commit.
- The `l2_fifo_tlm_observer` agent samples this wire every cycle and publishes a `hit_record` with `observation_point = L2_COMMIT` to the scoreboard.
- The wire is bound into the DUT via `bind`-attached probe ports inside the focus build's tb wrapper. **No DUT RTL change is needed**; the bind probes the FIFO's internal `commit_strobe` signal.

This gives the scoreboard a fourth, upstream-most observation point that anchors latency measurements to the moment the hit becomes "real" inside the model, not just when it was emitted from the virtual PHY.

### 2.4 Coverage

- **Functional bins** (counter-based; no `covergroup` for portability):
  - virtual MuTRiG mode × hit-rate × cluster-size × channel-mask
  - run-state transition every-pair coverage
  - `arb_hit_type0` mode (REAL / EMU / MIX_RR) crossed with watchdog enable
  - frame-counter ingress/egress reconciliation per source
- **Code coverage**: line ≥ 90%, branch ≥ 85%, toggle ≥ 80% across the full focus-build hierarchy under `tb_int/sim/<test>/cov/<test>.ucdb`.

---

## 3. Test Buckets

| Bucket | File | ID range | Goal |
|---|---|---|---|
| BASIC | `DV_BASIC.md` | `IB001..IB050` | Smoke + happy-path end-to-end traffic per RC + SC + DT axis |
| EDGE | `DV_EDGE.md` | `IE001..IE050` | Boundary cases at every stage transition (FIFO full, RBCAM full, rare frame pattern) |
| PROF | `DV_PROF.md` | `IP001..IP020` | Sustained Poisson at the documented rates from `firmware_builds/doc/MUTRIG.md`, soak runs, peak throughput |
| ERROR | `DV_ERROR.md` | `IR001..IR040` | Every documented upstream protocol violation, dropped frames, bad CRC, watchdog firings |
| CROSS | `DV_CROSS.md` | `IX001..IX010` | `bucket_frame` and `all_buckets_frame` continuous-frame baselines |
| LATENCY | `DV_LATENCY.md` | `IL001..IL020` | Every published rate / multiplicity sweep cell from `SYSTEM_PLAN.md` §5 reproduced in simulation; cross-checked with `histogram_statistics` |

Each bucket file follows the `dv-workflow` skill format and is linted by `dv_bucket_format_check.py`.

---

## 4. Bring-up Order

1. RC plumbing: drive run_ctrl from synclink, observe state broadcast at every IP. (`IB001..IB010`).
2. SC plumbing: write/read every CSR aperture in the focus build. (`IB011..IB025`).
3. DT smoke: virtual MuTRiG emits 16 deterministic hits, scoreboard observes all 4 stages, no drops. (`IB026..IB035`).
4. DT rate: virtual MuTRiG at 100 kHz, run for 100 µs sim time, scoreboard reconstructs all hits and produces latency CDF. (`IB036..IB050`).
5. EDGE: boundary cases per `DV_EDGE.md`.
6. ERROR: protocol violations, drops.
7. PROF: 1 / 100 / 500 kHz / 1 MHz sweep matching the SYSTEM_PLAN bring-up sweep.
8. LATENCY: rate × multiplicity matrix per SYSTEM_PLAN §5.
9. CROSS: `bucket_frame` and `all_buckets_frame`.

---

## 5. Outputs

Per-test artifacts under `tb_int/sim/<test>/`:

- `<test>.log` — raw simulator transcript.
- `closed_records.csv`, `drops.csv` — scoreboard results.
- `cov/<test>.ucdb` — code + functional coverage.

Per-test reports under `tb_int/reports/<test>/`:

- `latency_l2_commit_cdf.png`, `latency_pre_rbcam_cdf.png`, `latency_post_rbcam_cdf.png`, `latency_feb_egress_cdf.png` — per-stage latency CDFs.
- `hist_xcheck_pre_rbcam.md`, `hist_xcheck_post_rbcam.md`, `hist_xcheck_feb_egress.md` — cross-check vs `histogram_statistics_0` IP at each tap.
- `summary.md` — PASS/FAIL plus per-stage drop count, OoO ghost count, and the four latency percentiles (p50/p90/p99/p99.9).

---

## 6. Reuse contract

The harness is structured so **future integration testbenches** (e.g. an 8-lane integration tb for the supercore in `system_20260427_testplanphase5/tb_int/` once that lands) can reuse:

- `tb_int/uvm/common/mutrig_phy_agent/` — virtual MuTRiG with parameterised lane count.
- `tb_int/uvm/common/runctl_phy_agent/`, `sc_phy_agent/`.
- `tb_int/uvm/common/l2_fifo_tlm_observer/`.
- `tb_int/uvm/common/ooo_scoreboard/` — accepts any hit_record-typed analysis ports.
- `tb_int/uvm/common/latency_reporter/` — produces the three-stage CDFs and histogram cross-check.

The DUT-specific layer (focus-build wrapper instantiating the focus build's `.qsys` system, the bind probes for the L2 FIFO observer wire, and the per-test plumbing) lives at `tb_int/uvm/<system>/`.

---

## 7. Plan drift

Any deviation from this plan is recorded in `BUG_HISTORY.md` with date and rationale.
