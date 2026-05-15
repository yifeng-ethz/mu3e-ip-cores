# Integration Testbench: `v3_pretest-260511/tb_int/`

**DUT:** `feb_system_v3` (v3_pretest-260511 FEB-only pretest build).
The Qsys-generated synthesis tree at
`firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/` is the
canonical DUT. The standalone behavioral spec models are NOT the DUT; this is
an integration TB and must compile the actual generated wrappers / adapters /
clock-bridges to catch the bugs that integration exists to catch.
**Companion docs:** [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md),
[DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [BUG_HISTORY.md](BUG_HISTORY.md),
[TEST_PLAN.md](../../doc/TEST_PLAN.md), `DV_INT_HARNESS.md` (codex1).
**Reference:** `firmware_builds/systems/system_20260504_emulator_type0/tb_int/doc/DV_PLAN.md` (Apr 27 / May 4 emulator_type0 plan; structural parent).
**Author:** Mu3e IP team.
**Date:** 2026-05-11.
**Status:** Draft. Awaits codex1 harness construction.

---

## 1. Purpose & Scope

`tb_int/` is the **integration UVM testbench** that verifies the full datapath
of `feb_system_v3` in the v3_pretest-260511 build end-to-end with all IPs in
the loop. It is the layer between standalone IP DV (e.g.
`mu3e-ip-cores/<ip>/tb/`) and the on-board FEB+SWB bring-up.

This build keeps the FEB upload path on the legacy `feb_frame_assembly` plus
`upload_pkt_mux` egress. RDMA lives in the separate FEB+SWB cosim scope
(task #48), so the v3_pretest-260511 FEB-only integration scope is:

1. **Run-control verification (RC):** `runctl_mgmt_host` v26.3.0.0505 -> the
   readyless 1-source run-control fan-out -> every consumer IP. Verify
   `IDLE -> RUN_PREP -> SYNC -> RUNNING -> TERMINATING -> IDLE` is broadcast
   correctly and every IP reacts per its own contract. Run-control is
   `readyless`: NO consumer may backpressure a state transition.
2. **Slow-control verification (SC):** `sc_hub_v2` v26.6.9.414 <->
   `mm_bridge` <-> every CSR slave. Verify CSR addressing, address-aperture
   bounds, read/write atomicity, and cross-subsystem-bridge access (local
   JTAG master + SWB sc_hub both can reach the runctl_mgmt_host CSR).
3. **Datapath verification (DT):** end-to-end hit tracking from virtual or
   emulator MuTRiG to FEB-egress at the upload subsystem's `upload_pkt_mux`
   egress. The per-bucket FIFO-ledger scoreboard catches dropped / reordered /
   mis-attributed / corrupted hits.
4. **Latency measurement at four observation points**: Stage-A (L2 commit
   inside emulator_mutrig or `mutrig_frame_deassembly` decoded output),
   pre-rbCAM (rbCAM ingress), post-rbCAM (rbCAM hit_type2 egress), and FEB-
   egress (`upload_pkt_mux` output in this build, matching the Apr 27 legacy
   FEB layout).
5. **Histogram cross-check:** compare scoreboard's reconstructed delay
   distribution against `histogram_statistics_v2` v26.1.6.0429 bin counts at
   the pre-rbCAM and post-rbCAM taps.

### In scope

- Generated Qsys DUT compile (synthesis/ tree).
- Dual analysis-port observation: a synthesizable-payload monitor path +
  a DEBUG_LEVEL=2 sidecar-ID lineage path.
- Run-control readyless propagation through the entire chain.
- Legacy FEB upload egress contract at `upload_pkt_mux`.
- Coverage closure per `~/.codex/skills/dv-workflow/SKILL.md` §6 / §7.

### Out of scope

- Quartus timing closure (covered by the v3_pretest-260511 syn flow).
- On-board FEB+SWB programming (deferred to TEST_PLAN.md S0..S9).
- RDMA SQE/CQE cosim; that is task #48 in the FEB+SWB integration plan.
- Multi-FEB / multi-board cross-link tests (deferred).

---

## 2. UVM Infra (dual env)

The TB is structured as **two concurrent UVM environments wired to the same
DUT**, mirroring the source-model + DEBUG_LEVEL contract from the reference
plan with FEB egress bound to the legacy upload path:

1. **`tb_int_nominal_env`** — the synthesizable-payload observation path.
   Monitors at Stage-A / pre-rbCAM / post-rbCAM / FEB-egress carry the
   on-wire payload only. Exports `closed_records.csv` for latency CDFs.
2. **`tb_int_debug_env`** — the sidecar-ID lineage path.
   Monitors sample the **DEBUG_LEVEL=2 sidecar metadata** stream
   (per-hit `hit_id` + lineage) at every IP that emits a debug payload.
   Reconciles `debug_source -> pre-rbCAM -> post-rbCAM -> FEB-egress` by
   sidecar ID as the OoO scoreboard lineage model. Treats missing sidecar
   IDs as a closure blocker.

Both envs share:

- `tb_int_top` (DUT bind + clocks + resets + run-control source).
- `mutrig_phy_agent` (virtual MuTRiG source on the LVDS PHY pin pair).
- `runctl_phy_agent` (runctl synclink driver, readyless).
- `sc_phy_agent` (SC AVMM master driver via the SC bridge).
- `tb_int_run_window_db` (singleton, tracks `run_start` / `stable_start` /
  `stable_end` / `run_end`).
- `per_bucket_ledger_scoreboard` (per-`(lane, key)` FIFO-count reconciler,
  primary pattern from the reference plan §2.2).

### 2.1 Agents

| Agent | Direction | Role |
|---|---|---|
| `mutrig_phy_agent` | active source on the LVDS PHY pin pair | Virtual MuTRiG. Generates byte-stream-encoded MuTRiG frames at the LVDS data-clock boundary, including 8b/10b encoding, frame headers, hit payloads, frame trailers, idle K-codes. Per-hit 45-bit `hit_type0` payload per `frame_rcv_ip.vhd:580-585`. |
| `emulator_mutrig_force_agent` | active force on the generated `emulator_mutrig_qsys_lane` direct hit_type0 stream | Existing PROF-INT-002 emulator force path. Selected with `+TB_INT_SOURCE=emu_direct`. |
| `runctl_phy_agent` | active source on the synclink AVST 9-bit boundary | Drives `runctl_mgmt_host`'s synclink input with run-state command bytes. Readyless: no backpressure on state transitions. |
| `sc_phy_agent` | active master on the SC-bridge AVMM master | Drives the SC bridge's PCIe-mapped AVMM master. Mirrors `sc_tool` at the simulated bus level. |
| `lvds_decoded_monitor` | passive | Stage-A tap. Eight monitor instances (one per lane) fan into the scoreboard. |
| `pre_rbcam_monitor` | passive | Eight monitors at `ring_buffer_cam` ingress (rbCAM input). |
| `post_rbcam_monitor` | passive | Eight monitors at the post-`ring_buffer_cam` `aso_hit_type2` boundary. |
| `feb_egress_monitor` | passive | Two monitors at the legacy `upload_pkt_mux` egress. |
| `histogram_csr_monitor` | passive | Polls `histogram_statistics_v2_0` bin counters via SC bridge for cross-check. |
| `debug_l2_sidecar_monitor` | passive (interface-bind) | Samples DEBUG_LEVEL=2 sidecar at the L2 FIFO commit cycle inside `emulator_mutrig` (or the equivalent at `mutrig_frame_deassembly` for the virtual MuTRiG path). |
| `debug_pre_rbcam_sidecar_monitor` | passive | Samples DEBUG_LEVEL=2 sidecar at the pre-rbCAM boundary, carried via DEBUG_LEVEL=2 ports on `mts_preprocessor` / `arb_hit_type0`. |
| `debug_post_rbcam_sidecar_monitor` | passive | Samples DEBUG_LEVEL=2 sidecar at the post-rbCAM boundary. |
| `debug_feb_egress_sidecar_monitor` | passive | Samples DEBUG_LEVEL=2 sidecar at the legacy FEB upload egress. |
| `debug_fill_monitor[*]` | passive | One per DEBUG_LEVEL=1 IP (see §2.3 table). Samples queue/FIFO fill at the IP's exposed `*_filllevel` AVST status conduit. |

### 2.2 Scoreboard

`tb_int_per_bucket_ledger_scoreboard` consumes analysis-port traffic from
both envs. Reconciles:

- **Per-lane, per-stage, per-`hit_key_t` FIFO ledgers**. Count parity per
  `(lane, key)` bucket, never per-hit primary lookup.
- **Stage timeout / latency budgets** (extended for the v3_pretest build):
  - Stage-A -> pre-rbCAM: `[0, 2000]` cycles (rbCAM ingress accept window).
  - pre-rbCAM -> post-rbCAM: `[2000, 3000]` cycles (rbCAM hold + drain).
  - post-rbCAM -> FEB-egress (`upload_pkt_mux` output): `[2000, 7096]`
    cycles upper bound covers two `feb_frame_assembly` frame periods.
- **Sidecar ID lineage:** `debug_env` scoreboard reconciles by 64-bit
  `hit_id` sidecar, not FIFO-key match. Missing or wrong sidecar at any
  stage is a hard fail (NOT a count residual).
- **FEB upload egress check:** every post-rbCAM hit selected for upload must
  appear at the upload_pkt_mux egress within the stage budget.

### 2.3 DEBUG_LEVEL regulation per IP

The integration TB requires that each IP under DUT has its debug-port
configuration set so the analysis tap is meaningful. The user contract:

- **`DEBUG_LEVEL=1`** — synthesizable fill-level observability. The IP
  exposes one or more AVST status conduits (e.g. `*_filllevel`,
  `*_delay8loss`, `*_loss8fill`, `*_burst`) that the `debug_fill_monitor`
  taps for rate / queue-depth scoreboard observations. These conduits are
  synthesizable and may stay in the on-board build.
- **`DEBUG_LEVEL=2`** — cumulative; adds per-hit sidecar metadata
  (64-bit `hit_id`, `seq_in_bucket`, `abs_ts`, `run_origin`). Sidecar is
  carried over the IP's main `aso_*` AVST data port as an additional
  symbol/role or via a parallel `aso_*_sidecar` conduit. Sidecar paths
  are simulation-only and must NOT be synthesized in the on-board build.

Per-IP DEBUG_LEVEL mapping for `v3_pretest-260511`:

| IP | DEBUG_LEVEL | Analysis port → Scoreboard observable |
|---|:-:|---|
| `emulator_mutrig` | 2 | L2 commit sidecar (assigns `hit_id`); also L1/L2 fill at level 1 |
| `mutrig_frame_deassembly` | 2 | decoded hit_type0 sidecar (when virtual MuTRiG path is active); also frame fifo fill at level 1 |
| `mts_preprocessor` | 2 | timestamp-reconstructed sidecar + non-wrapping latency (`debug_ts`, `debug_burst`, `ts_delta`); also internal pipeline fill at level 1 |
| `arb_hit_type0` (inside `hit_stack_subsystem_*`) | 2 | post-arbitration sidecar pass-through; also EMU/REAL L1/L2 fill at level 1 |
| `ring_buffer_cam` (4x per hit_stack_subsystem, 8x total) | 2 | rbCAM bucket sidecar pass-through; also bucket fill + drain pressure at level 1 |
| `histogram_statistics_v2` | 1 | internal source selection through `CONTROL.in_port`, coalescing queue fill (`overflow_count`, `queue_hit_bin`), and selected extended-stream count model |
| `feb_frame_assembly` | 2 | legacy upload framing path before `upload_pkt_mux` |
| `mutrig_injector_multiheader` | 0 | source-side; no debug payload needed |
| `pulse_fanout8` | 0 | combinational fanout; no observable state |
| `mutrig_timestamp_processor` | 2 | non-wrapping latency sidecar; also internal stage fill at level 1 |
| `runctl_mgmt_host` | 0 | source; readyless broadcast; no fill observable |
| `sc_hub_v2` | 0 | bus master; no DV fill observable |
| `dbg_mm2runctrl` | hidden | HIDE_FROM_QUARTUS; not instantiated |

The IP-level `DEBUG_LEVEL` parameter is set per Qsys-instance via
`set_instance_parameter_value <inst> DEBUG_LEVEL <0/1/2>`.

`histogram_ingress_bridge` is retired in the bridge-free FEB v3 streaming-debug
topology. The old pre/post source switch is now absorbed inside
`histogram_statistics_v2`; `CONTROL.in_port = 1/2` selects the upper/lower MTS
extended stream directly.

**Hard contract (production vs debug vs sim):**

- **`DEBUG_LEVEL=0` is the synthesizable production default.** Every IP
  instance in the on-board v3_pretest-260511 board project MUST have
  `DEBUG_LEVEL=0` (or the IP-specific alias `DEBUG`, `DEBUG_LV`)
  explicitly pinned in the Qsys file. The production FEB board CANNOT
  fit the design if any instance is at a higher level. Verified on
  2026-05-11: a build with two `mts_preprocessor` instances left at
  `DEBUG=1` fit at 160% ALM utilization and aborted in quartus_fit
  (commit 96040d3f REPORT.md). After pinning DEBUG=0 the design fits.
- **`DEBUG_LEVEL=1` is for exceptional debug-variant builds only.** Use
  when on-board monitoring of queue fill / FIFO occupancy is explicitly
  requested (for example a histogram debug bitstream). The level-1
  observability exposes synthesizable `*_filllevel` / `*_debug_status`
  AVST status conduits. Do NOT enable level-1 on the production
  bitstream by default. A debug-variant build lives under a separate
  system snapshot, e.g. `firmware_builds/systems/v3_dbg-<date>/`.
- **`DEBUG_LEVEL=2` is NON-SYNTHESIZABLE — simulator only.** The
  level-2 sidecar metadata (`hit_type0_sidecar`, `hit_type1_sidecar`,
  64-bit `hit_id` lineage) is used by the integration TB's debug env
  and synthesizes away at `DEBUG_LEVEL=0`. NEVER put `DEBUG_LEVEL=2`
  into a Quartus build.

Mapping rules in the §2.3 table:
- The DEBUG_LEVEL column in the §2.3 table assigns the LEVEL the
  integration TB expects at SIMULATION TIME. At Quartus build time,
  every instance is pinned to `DEBUG_LEVEL=0` regardless of the table.
- Per-IP DEBUG_LEVEL elevation at sim happens via UVM-side instance
  parameter overrides (or a side Tcl that overrides DEBUG_LEVEL for the
  TB tree only). The production bitstream Qsys is unaffected.
- The user-clarified semantics on 2026-05-11: "DEBUG_LEVEL must 0 for
  synthesis to work. DEBUG_LEVEL=2 is non-synthesizable. DEBUG_LEVEL=1
  is only for exceptional cases such as monitoring fill-level (e.g. the
  histogram IP) when explicitly requested for a debug-variant firmware
  build."

### 2.4 Coverage

Bins reference `hit_key_t` (`{channel[4:0], t_fine[4:0]}`):

- Functional bins (counter-based, no `covergroup`): `(mode, real_fifo,
  emu_fifo)`, virtual MuTRiG mode x rate x cluster-size x channel-mask,
  run-state every-pair, `arb_hit_type0` mode (REAL/EMU/MIX_RR) x watchdog.
- Per-`(lane, key)` reconciliation closure: every test case must reconcile
  to count parity within the per-case threshold in `DV_COV.md` at
  `RUN_TERMINATING`.
- Sidecar-ID lineage closure: 100% of stable-window hits must have a sidecar
  ID at every stage they reach.
- Latency CDF coverage: Python-side from CSV.
- Code coverage gate: line >= 90%, branch >= 85%, toggle >= 80% across the
  v3_pretest-260511 generated hierarchy.

---

## 3. Test Buckets

Four buckets. Per-section budget conforms to the reference plan and the
`dv-workflow` skill format contract.

| Bucket | RC | SC | DT | Total | Goal |
|---|---:|---:|---:|---:|---|
| BASIC | 32 | 32 | 128 | **192** | `DV_BASIC.md` — happy-path RC / SC / DT |
| EDGE | 32 | 32 | 128 | **192** | `DV_EDGE.md` — boundary conditions |
| ERROR | 32 | 32 | 128 | **192** | `DV_ERROR.md` — failure injection |
| PROF | 32 | 32 | 128 | **192** | `DV_PROF.md` — sustained throughput |

### 3.1 RC (run-control)

`runctl_mgmt_host` is readyless. The integration TB MUST NOT allow any IP to
backpressure a state transition. Cases:

- Sequencing through every state pair (including shortcuts).
- Mid-flight RESET injected at randomised cycles in `RUN_PREP` / `SYNC` /
  `RUNNING` / `TERMINATING`.
- `TB_INT_RUNCTL_CPP_GAP_CYCLES` default 125000 (1 ms at 125 MHz) -
  matches deployed FEB flow's software-scale command gap.
- `RUN_NUMBER` increment tracking across each cycle.
- FEB upload run-state gating: upload packets only advance during stable
  RUNNING window; no upload egress during `RUN_PREP` or `TERMINATING`.

#### 3.1.1 Pre-`RUNNING` toggle sequence (NOMINAL = firefly)

Before any case in DT / PROF that exercises the `RUNNING` window, the
test MUST drive a properly-toggled run sequence to bring the FEB out of
IDLE and into `RUNNING` cleanly. There are two physical input paths
into `runctl_mgmt_host`; they are NOT symmetric in this DV scope:

| Path | Source agent | Wire boundary | Scope |
|---|---|---|---|
| **A. firefly link (NOMINAL)** | `runctl_phy_agent` on synclink AVST 9-bit | upload_subsystem synclink ingress (rxin from `runctl_mgmt_host_0.synclink_in`) | Deployed production flow: SWB reset-link transmitter drives the FEB run-state via the firefly downlink. **DEFAULT path for ALL BASIC / EDGE / ERROR / PROF RC + DT + PROF cases.** |
| **B. CSR toggle (DEBUG FALLBACK only)** | `sc_phy_agent` writing the `runctl_mgmt_host_0` control CSR | upload_avmm aperture into the host CSR (e.g. `csr_run_state_word`) | Fallback flow: local JTAG-master + bringup subsystem (or SWB sc_hub via the cross-subsystem bridge) writes the same one-hot state word. **Used only by a LIMITED dedicated subset of cases (see §3.1.2).** |

All cases other than the §3.1.2 subset run on **path A (firefly)
only**. No `_FF` / `_CSR` suffix — the case ID is the firefly nominal
case.

Both paths MUST observe a minimum **1 ms** gap between adjacent state
writes (`TB_INT_RUNCTL_CPP_GAP_CYCLES >= 125000` at 125 MHz). Do NOT
drive `IDLE -> RUN_PREP -> SYNC -> RUNNING` back-to-back unless the
case is an EDGE/zero-gap stress. The 1 ms gap matches the deployed C++
software-scale command cadence.

#### 3.1.2 CSR-toggle RC fallback (LIMITED)

A small dedicated subset exercises **path B** to prove that the CSR
toggle reaches `runctl_mgmt_host` and produces the same one-hot
broadcast as path A. These cases verify the FALLBACK only — they are
not regression coverage for run-control DT.

| ID | Bucket | Scope | Pass Criteria |
|---|---|---|---|
| `B-RC-CSR-001` | BASIC | IDLE -> RUN_PREP transition via CSR toggle alone | runctl_mgmt_host_0.run_ctrl egress reaches RUN_PREP one-hot; matches the path-A reference observation captured in B001 |
| `B-RC-CSR-002` | BASIC | Full IDLE -> RUNNING -> IDLE walk via CSR toggle with 1 ms gaps | run_window_db markers consistent with path A's B006 reference |
| `E-RC-CSR-001` | EDGE | Path A and Path B drive a state transition in the same ms — verify priority / no shadow drift | runctl_mgmt_host_0 broadcasts a single coherent one-hot per cycle; no glitch; arbitration logged |

No PROF / ERROR cases use path B by default. If a path-B bug is
discovered, document in BUG_HISTORY.md.

#### 3.1.3 Scoreboard cross-check (path A vs path B)

When the §3.1.2 subset runs, the scoreboard cross-checks the
`runctl_mgmt_host_0.run_ctrl` egress against the path-A reference
observation. Disagreement is a hard fail (RC ingress prioritisation
bug, CSR-vs-synclink shadow drift, or upload-vs-control aperture
aliasing).

### 3.2 SC (slow-control)

Identity scans, RW round-trips, burst-within-aperture, cross-slave
back-to-back, concurrent SC+RC traffic. New for v3_pretest:

- upload_subsystem runctl_mgmt_host and legacy upload path visibility.
- runctl_mgmt_host CSR visibility from BOTH local JTAG master (via the
  bringup subsystem) AND SWB sc_hub (via the cross-subsystem bridge).

#### 3.2.1 SC ingress paths (NOMINAL = firefly -> sc_hub)

There are two physical ingress paths into `sc_hub_v2`. They are NOT
symmetric in this DV scope; they mirror the §3.1 RC pattern:

| Path | Source agent | Wire boundary | Scope |
|---|---|---|---|
| **A. firefly link -> sc_hub (NOMINAL)** | `sc_phy_agent` driving the SWB-side sc_hub AVMM master | FEB-side firefly downlink -> upload_subsystem sc_downlink_cdc_bridge -> sc_hub_v2.hub | Deployed production flow: SWB sc_tool reaches FEB CSR slaves through the SC reset link / firefly transceiver. **DEFAULT path for ALL BASIC / EDGE / ERROR / PROF SC cases.** |
| **B. local JTAG master (DEBUG FALLBACK only)** | UVM bind into the bringup subsystem's `altera_jtag_avalon_master` | bringup_subsystem JTAG master AVMM port -> mm_bridge -> sc_hub_v2.hub | Fallback flow: local JTAG via USB-BlasterII for in-circuit debug. **Used only by a LIMITED dedicated subset of cases (see §3.2.2).** |

All cases other than the §3.2.2 subset run on **path A (firefly)
only**. No `_FF` / `_JTG` suffix — the case ID is the firefly nominal
case.

#### 3.2.2 JTAG-master SC fallback (LIMITED)

A small dedicated subset exercises **path B** to prove the local JTAG
master can reach the CSR slaves it cares about for in-circuit debug.
These cases verify the FALLBACK only — they are not regression
coverage for slow-control DT.

| ID | Bucket | Scope | Pass Criteria |
|---|---|---|---|
| `B-SC-JTG-001` | BASIC | Read UID of scratch_pad_ram via JTAG master | UID matches RTL constant; matches the path-A reference captured in B033 |
| `B-SC-JTG-002` | BASIC | Single-word RW round-trip on scratch_pad_ram via JTAG master | read-back agrees with path-A reference |
| `B-SC-JTG-003` | BASIC | Read runctl_mgmt_host_0 UID via JTAG master + cross-subsystem bridge | proves the cross-bridge access route works |
| `E-SC-CONC-001` | EDGE | Concurrent path A + path B SC traffic — verify sc_hub_v2 arbitration is fair / non-starving | both observers complete; arbitration log shows interleaving | TBD |

No PROF / ERROR cases use path B by default. If a path-B bug is
discovered, document in BUG_HISTORY.md.

### 3.3 DT (datapath)

Rate distribution, multiplicity, spatial patterns, source mix, temporal
placement around state changes, frame-boundary phasing, latency budget,
sidecar lineage. New for v3_pretest:

- upload_pkt_mux production rate at sustained 1 MHz / channel x 32 channel x
  8 lane (worst-case stable-window).
- DEBUG_LEVEL=2 sidecar carry-through must show 100% lineage in the
  stable window; missing sidecars block closure.

---

## 4. Bring-up Order

1. **BASIC bucket** - RC plumbing (readyless propagation) + SC plumbing
   (cross-bridge access) + DT smoke (16-hit deterministic patterns at
   100 kHz/channel, 1 lane, virtual MuTRiG source). Establish that the
   dual UVM env scoreboard agrees on every stage.
2. **EDGE bucket** - boundary conditions per axis; sidecar carry-through
   at every level-2 IP.
3. **ERROR bucket** - failure injection (bad CRC, dropped frames,
   mid-flight RESET, FEB upload egress timeout).
4. **PROF bucket** - sustained Poisson at 1 MHz x 32ch x 8 lane for 1 s
   stable window with 5 s outer window (matches the reference plan's
   PROF-INT-002 5s targets).
5. **All-buckets continuous-frame** - one final sign-off run.

---

## 5. Outputs

Per-test artifacts under `tb_int/sim/<test>/`:
- `<test>.log`, `closed_records.csv`, `drops.csv`, `cov/<test>.ucdb`.
- New for v3_pretest: `feb_egress_log.csv` for upload egress tracking.

Per-test reports under `tb_int/reports/<test>/`:
- `latency_l2_commit_cdf.png`, `latency_pre_rbcam_cdf.png`,
  `latency_post_rbcam_cdf.png`, `latency_feb_egress_cdf.png` (the
  feb_egress tap is the upload_pkt_mux egress for v3_pretest).
- `hist_xcheck_pre_rbcam.md`, `hist_xcheck_post_rbcam.md`.
- New: `feb_upload_turnaround_cdf.png`, `feb_upload_rate_vs_runctl.md`.
- `summary.md`.

---

## 6. Reuse contract

The harness reuses the Apr 27 reference's `tb_int/uvm/common/` directly:
- `mutrig_phy_agent`, `runctl_phy_agent`, `sc_phy_agent`.
- `per_bucket_ledger_scoreboard`, `run_window_db`, `hit_record`,
  `hit_key_pkg`.
- `lvds_decoded_monitor`, `rbcam_egress_monitor`, `feb_egress_monitor`
  (the last is rebound to upload_pkt_mux egress).

New for v3_pretest under `tb_int/uvm/common/`:
- `debug_l2_sidecar_monitor`, `debug_pre_rbcam_sidecar_monitor`,
  `debug_post_rbcam_sidecar_monitor`, `debug_feb_egress_sidecar_monitor`.
- `debug_fill_monitor` parameterised by IP and conduit name.

DUT-specific layer at `tb_int/uvm/v3_pretest-260511/`:
- `tb_int_top.sv` (binds the generated `feb_system_v3.vhd` from
  `firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/`).
- `tb_int_dual_env.sv` (instantiates both nominal_env and debug_env).
- `mutrig_l2_commit_if.sv` (interface-bind to the emulator L2 commit).
- `mutrig_frame_deassembly_decoded_if.sv` (interface-bind to the decoded
  hit_type0 boundary, when virtual MuTRiG source is active).
- `tb_int_base_test.sv`, `tb_int_smoke_test.sv`.

---

## 7. Implementation pointer

The harness construction is dispatched to **codex1** with this plan as
the contract. Codex1 must:

1. Author `tb_int/uvm/v3_pretest-260511/` DUT-bind layer.
2. Symlink (or copy) the reusable `tb_int/uvm/common/` agents from the
   Apr 27 reference at
   `firmware_builds/systems/system_20260504_emulator_type0/tb_int/uvm/common/`.
3. Add the new debug sidecar / fill monitors per §2.1 + §2.3.
4. Set per-IP DEBUG_LEVEL parameter overrides at Qsys-instance time via a
   one-shot Tcl script that re-parameterises the v3_pretest-260511
   feb_system_v3 instance to elevate the level-2 IPs at TB compile time
   ONLY. Document the script.
5. Implement `DV_BASIC.md` smoke first (16-hit deterministic, 1 lane,
   virtual MuTRiG); confirm dual env agreement before adding cases.
6. Pass the `dv_bucket_format_check.py` lint on every DV_*.md.

---

## 8. Plan drift

When this plan diverges from implementation, edit this file before merging
the implementation. The plan is the contract.
