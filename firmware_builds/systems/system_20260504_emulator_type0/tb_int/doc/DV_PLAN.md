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

Every monitor publishes via a `uvm_analysis_port` typed to a **`hit_record`** transaction. The transaction carries the on-wire hit fields plus two scoreboard-only metadata fields that make end-to-end OoO tracking deterministic:

| Field | Source | Width / type | Role |
|---|---|---|---|
| `uid` | assigned by `mutrig_phy_agent` at emit | 64-bit monotonic | Global unique hit identifier; primary key for the OoO scoreboard. The agent increments it per generated hit, never reused, never re-shuffled. |
| `true_ts_ps` | assigned by `mutrig_phy_agent` at emit | 64-bit ps | Ground-truth timestamp at the moment the hit was generated by the virtual MuTRiG, expressed in picoseconds (finer than the 8 ns datapath cycle). Used by the latency reporter as the time origin (every per-stage observation timestamp is `t_observed - true_ts_ps`). |
| `asic_id`, `channel`, `T_coarse`, `T_fine`, `E_coarse`, `E_flag` | on-wire MuTRiG fields | per the hit_type-1 layout | Natural identity used by downstream monitors to look up the matching `(uid, true_ts_ps)` from the agent's emit table. |
| `observation_point` | local to each monitor | enum {`L2_COMMIT`, `PRE_RBCAM`, `POST_RBCAM`, `FEB_EGRESS`} | Stage at which the monitor observed the hit. |
| `t_observed_ps` | `$realtime` at observation, in ps | 64-bit ps | Sim-time at observation. The latency at this stage is `t_observed_ps - true_ts_ps`. |

**Uid + true_ts_ps propagation.** The DUT does not carry `uid` or `true_ts_ps` in the on-wire payload — the MuTRiG hit_type-1 layout has no room for them, and the user-visible CSR / SOF must not be polluted with DV-only metadata. Instead:

1. The `mutrig_phy_agent` writes `(uid, true_ts_ps, asic_id, channel, T_coarse, T_fine, E_coarse, E_flag)` into a **shared ground-truth table** keyed by the natural identity tuple `(asic_id, channel, T_coarse, T_fine)` at the cycle it emits the hit.
2. Each downstream monitor (`l2_fifo_tlm_observer`, `lvds_decoded_monitor`, `rbcam_egress_monitor`, `feb_egress_monitor`) decodes the hit's natural identity from its own observation point and **looks up** `(uid, true_ts_ps)` in the ground-truth table. The lookup is unique by construction because the natural-identity tuple is per-hit unique within a single run (T_coarse + T_fine within a frame are unique per channel, and the agent staggers emissions so two hits never share the full tuple).
3. If a monitor sees a hit whose natural identity is **not** in the ground-truth table, it publishes a `hit_record` with `uid = 64'hFFFF_FFFF_FFFF_FFFF` (sentinel "ghost") and the OoO scoreboard hard-fails the test. Ghost hits are unambiguous bugs in the DUT, the lookup logic, or the natural-identity assumption.
4. After `RUN_TERMINATING`, the OoO scoreboard iterates the ground-truth table; any `uid` whose `seen_at_<stage>` field is missing for at least one stage is logged as a `dropped_at_stage_X` row in `drops.csv`.

This scheme keeps the DUT pure (no DV-only signals) while giving the scoreboard a per-hit identity that survives merge-FSM rewrites, RR arbitration, and FIFO reordering at every stage.

### 2.2 Scoreboard

`tb_int_ooo_scoreboard` consumes analysis-port traffic from all monitors and runs an **out-of-order hit reconciliation engine**:

- Every `hit_record` is keyed by the agent-assigned **`uid`** (the unique 64-bit primary key from §2.1), not by the natural-identity tuple. Lookup at downstream monitors converts natural identity → `uid` via the ground-truth table.
- The hash table tracks per-`uid`: `true_ts_ps`, `t_l2_commit_ps`, `t_pre_rbcam_ps`, `t_post_rbcam_ps`, `t_feb_egress_ps`. Each `t_*_ps` is the picosecond observation time at that stage; missing fields are `64'hFFFF_FFFF_FFFF_FFFF` (sentinel "not yet seen").
- Per-stage **latency = `t_<stage>_ps - true_ts_ps`**. CDFs and percentiles use this difference, not the bare sim time.
- Hits that complete the four-stage path are removed from the table and added to a closed-record collection.
- Hits that arrive at one stage but never reach the next within the configured stage timeout are flagged as **dropped at stage X** and recorded with their syndrome (last-seen stage, last-seen time, monitor port, run-state).
- Hits that arrive at a downstream stage with `uid = sentinel` (i.e. natural identity not found in the ground-truth table) are **ghost hits** — hard fail.
- `RUN_TERMINATING` triggers a final reconciliation pass: any open hit-records older than the latency budget are flagged as dropped.

After every test, the scoreboard exports:

1. Closed-record CSV under `tb_int/sim/<test>/closed_records.csv` (one row per hit, columns: `uid, true_ts_ps, asic, ch, t_coarse, t_fine, e_coarse, e_flag, t_l2_ps, t_pre_rbcam_ps, t_post_rbcam_ps, t_feb_egress_ps, lat_l2_ps, lat_pre_rbcam_ps, lat_post_rbcam_ps, lat_feb_egress_ps`). Each `lat_<stage>_ps = t_<stage>_ps - true_ts_ps`.
2. Drop CSV under `tb_int/sim/<test>/drops.csv` (one row per missed hit, columns: `uid, true_ts_ps, asic, ch, t_coarse, t_fine, last_seen_stage, last_seen_time_ps, last_seen_monitor, run_state_at_drop`).
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

Four buckets, each with three sections — **RC** (run-control), **SC** (slow-control), **DT** (datapath). Per-bucket case budgets (minimum):

| Bucket | RC | SC | DT | Total | Goal |
|---|---:|---:|---:|---:|---|
| BASIC | 32 | 32 | 128 | **192** | `DV_BASIC.md` — happy-path verification of the full RC/SC/DT axis |
| PROF | 32 | 32 | 128 | **192** | `DV_PROF.md` — sustained throughput, soak, peak rate, peak multiplicity |
| EDGE | 32 | 32 | 128 | **192** | `DV_EDGE.md` — boundary conditions per axis (FIFO full, RBCAM full, exact-cycle transitions, max-channel, max-cluster, sparse / dense, alignment edges) |
| ERROR | 32 | 32 | 128 | **192** | `DV_ERROR.md` — failure injection, bad-CRC frames, dropped frames, run-control mid-flight RESET, watchdog firings, protocol violations |
| **Total** | **128** | **128** | **512** | **768** | |

Per-section ID convention: `<bucket>-<section>-NNN`, e.g. `BASIC-DT-042`, `ERROR-RC-013`. Each case ID is unique within a bucket; case labels never repeat across buckets.

### 3.1 RC (run-control) per-bucket scope (32 cases each)

A single case = one unique run-control combinatorial sequence (a path through the run-state graph). Each case covers:

- **Sequencing**: random combinations of `IDLE → RUN_PREP → SYNC → RUNNING → TERMINATING → IDLE` and shortcuts (`RUN_PREP → RESET`, `SYNC → RESET`, `TERMINATING → RUN_PREP`, etc.). 32 unique paths per bucket.
- **Mid-flight RESET**: `RESET` injected at randomised cycles inside `RUN_PREP` / `SYNC` / `RUNNING` / `TERMINATING`, including hard-reset during functional-reset around the entering and exiting transitions of any state. Verify all IPs return to a consistent post-reset state and the run-control box's `RUN_NUMBER`, frame counters, and other observables react correctly per the `runctl_mgmt_host` contract.
- **Sync stability**: `RUN_SYNC` held for varying durations; verify all IPs stay in sync (no drift in `STATUS.run_state` between consumers).
- **`RUN_NUMBER` tracking**: bump `RUN_NUMBER` across each cycle and confirm `runctl_mgmt_host` records the new number; no off-by-one on `RUN_PREP` vs `IDLE`.

Bucket-specific RC scope:

| Bucket | RC focus |
|---|---|
| BASIC | Clean transitions, deterministic timing |
| PROF | Long `RUNNING` durations (10⁵ cycles), sustained `RUN_NUMBER` increments, watchdog overlap |
| EDGE | Back-to-back state transitions with zero gap, transitions on the same cycle as a CSR write |
| ERROR | Mid-flight RESET while an IP is mid-flush (e.g. `arb_hit_type0` during merge-packet close); back-to-back RESETs without intervening `IDLE`; truncated state words |

### 3.2 SC (slow-control) per-bucket scope (32 cases each)

A single case = one SC-traffic pattern against the focus-build CSR map. 32 cases per bucket cover:

- **Single-word read** of every CSR slave's identity header (`UID`, `META`).
- **Single-word write** of every RW field, with read-back confirmation.
- **Burst read across one slave aperture** (e.g. read all of `arb_hit_type0_0`'s 32 words with a single AVMM burst).
- **Burst read across half a slave aperture** (e.g. `0x00..0x0F` only, then `0x10..0x1F`) with verification that bursts don't cross the slave boundary.
- **Burst write** with mixed read-write addresses inside one burst (must be rejected or sequenced per the SC bridge contract).
- **Cross-slave back-to-back** writes/reads, exercising the `mm_bridge` arbitration.
- **Concurrent SC + RC traffic** (interleaved SC on the SC bridge and RC commands on synclink), proving the two control planes are independent.

Bucket-specific SC scope:

| Bucket | SC focus |
|---|---|
| BASIC | One-shot single-word reads/writes; identity scans; clean bursts inside one aperture |
| PROF | Sustained back-to-back SC traffic at the maximum SC bridge rate; soak |
| EDGE | Burst lengths at boundaries (1, 2, aperture-size, aperture-size minus 1, exactly-half); writes at the very last legal address; reads from undefined addresses |
| ERROR | Burst that overruns aperture (single-slave 4 KB limit); illegal address; write to RO field; read of W1P field; SC during RC `RESET` |

### 3.3 DT (datapath) per-bucket scope (128 cases each)

A single case = one (rate × multiplicity × spatial × temporal × phasing × source-mix) combination of virtual-MuTRiG hits. 128 cases per bucket cover:

- **Rate distribution**: `0` (no hits at all), `1` per frame, `10 kHz`, `100 kHz`, `500 kHz`, `1 MHz`, `2 MHz` per channel; sustained vs short bursts.
- **Multiplicity**: 2-channel cluster, 4, 8, 16, 32 channels; physical cluster (same `T_coarse + T_fine`) vs cluster with fine-time variance (Poisson jitter `0..16` cycles within the cluster).
- **Spatial patterns**: random in channel space; clustered (contiguous channel runs); intermediate (deterministic spacing of 2 / 4 / 8 channels); single-channel hot spot; uniform full-channel; source-split at the convention boundary (real on channel 7, emu on channel 8). The focus build is single-lane with 16 visible channels per source, so SMB-boundary mirroring at channel 128 does not apply here; that dimension is left for the future 8-lane integration TB.
- **Source mix**: real-only (mode REAL), emu-only (mode EMU), MIX_RR with both sources active, single-lane vs cross-lane (one virtual ASIC vs multi-ASIC for cluster generation).
- **Temporal placement around state changes**: no hits after `SYNC` (gate closed), all hits after `SYNC` (gate open), gate hits before `RUNNING` (must be discarded), drain hits after `TERMINATING` (must complete the in-flight frame and propagate `endofrun`).
- **Frame-boundary phasing**: hits aligned to frame start, hits at frame end, hits straddling frame boundary, frames with zero hits.
- **Latency target**: every case asserts the four-stage latency CDFs do not exceed the documented per-stage budget; histogram cross-check at every tap.

Bucket-specific DT scope:

| Bucket | DT focus |
|---|---|
| BASIC | Smoke (deterministic 16-hit patterns) plus rate sweep (10k / 100k / 500k / 1M kHz at cluster-size 1 / 4 / 8 / 16 / 32) plus spatial sweep |
| PROF | Sustained Poisson at 1 MHz × 32 channels for 10⁵ cycles; cross-source MIX_RR at the documented `1 hit / 3.5 cycles` ceiling; long-soak with mid-run `RUN_NUMBER` bumps |
| EDGE | Cluster-size at the 32-channel maximum with all hits in one frame; back-to-back single-channel saturation; frame-boundary hit straddling; FIFO-full induced drops with the watchdog firing exactly at the timeout boundary |
| ERROR | Bad CRC injected on virtual-MuTRiG frames; dropped frames mid-cluster; `RUN_PREP` mid-frame; emulator and real channels collide on the same channel ID (violates the `[0..7]` / `[8..15]` convention); SOP without EOP; double-EOP without intervening SOP |

`dv-workflow` skill format applies; `dv_bucket_format_check.py` lints every bucket file. Format conforms to per-IP DV docs under `mu3e-ip-cores/misc/arb_hit_type0/tb/DV_*.md`.

---

## 4. Bring-up Order

1. **BASIC bucket first** — RC plumbing, SC plumbing, DT smoke + rate sweep + multiplicity sweep. Every PASS from this bucket is a prerequisite for the higher buckets.
2. **EDGE bucket** — boundary conditions per axis. Catches off-by-one bugs that BASIC misses.
3. **ERROR bucket** — failure injection. Verifies the recovery path for every recorded upstream-bug surface (error counters, syndromes, sticky flags) and the run-control RESET cleanup contract.
4. **PROF bucket** — sustained / soak / peak. Runs last because it depends on BASIC closure and is long-running.
5. **All-buckets continuous-frame** — one final sign-off run that drives every case in case-id order inside one timeframe without DUT reset between cases (per `dv-workflow` skill §9 `all_buckets_frame`).

For per-stage latency reporting, every PROF case automatically refreshes the four CDFs at L2-commit / pre-rbCAM / post-rbCAM / FEB-egress.

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
- `tb_int/uvm/common/ground_truth_table/` — `uid + true_ts_ps` registry shared by the agent and every monitor; lookup keyed by natural-identity tuple.
- `tb_int/uvm/common/ooo_scoreboard/` — accepts any hit_record-typed analysis ports; primary-keyed on `uid`.
- `tb_int/uvm/common/latency_reporter/` — produces the three-stage CDFs and histogram cross-check.

The DUT-specific layer (focus-build wrapper instantiating the focus build's `.qsys` system, the bind probes for the L2 FIFO observer wire, and the per-test plumbing) lives at `tb_int/uvm/<system>/`.

---

## 7. Plan drift

Any deviation from this plan is recorded in `BUG_HISTORY.md` with date and rationale.
