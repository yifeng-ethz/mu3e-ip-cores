# Integration Testbench: `swb/rdma_pretest-260511/tb_int/`

**DUT:** SWB Arria 10 DE5 `top` from `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/`
**Companion docs:** [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Reference:** `firmware_builds/systems/v3_pretest-260511/tb_int/doc/DV_INT_PLAN.md` (FEB v3_pretest-260511 dual-env structural parent)
**Author:** Mu3e IP team.
**Date:** 2026-05-11
**Status:** Draft. Selected 22-case structural UVM sweep is implemented.

The staged board project and generated local Qsys synthesis outputs are the
canonical DUT inputs for this integration TB.

---

## 1. Purpose & Scope

`tb_int/` verifies the SWB-side RDMA pretest build staged from
`online_sc/online/switching_pc/a10_board` into this repository. The scope is
the Arria 10 DE5 SWB system with PCIe x8 host access, OPQ four-lane native_sv
at the deployed `0x800`-frame observation depth, and the `rdma_subsystem` on
both the FEB-to-SWB bridge ingress and the SWB-to-host DMA push path.

The integration target is not a standalone IP model. It must compile against
the staged board sources plus local Qsys-generated synthesis outputs so that
bridge wiring, clock/reset fanout, generated wrappers, and DMA endpoints are
observed as deployed.

In scope:
- Run-control propagation from the SWB reset-link transmitter into FEB
  run-state intent and into SWB-local run-control consumers.
- Host slow-control over `/dev/mudaq0` through the SWB AVMM master and
  `sc_hub_v2` path, with local JTAG as a limited debug fallback.
- SWB datapath tracking from FEB-to-SWB RDMA SQE ingress through OPQ,
  `musip_event_builder`, `swb_data_demerger`, `hit_compactor`, and host DMA.
- Per-stage queue and sidecar observability at the DEBUG_LEVEL values in
  section 2.3.
- BASIC/EDGE/ERROR/PROF bucket execution modes required by `dv-workflow`.

Out of scope:
- Full Quartus map/fit/asm timing closure for this turn.
- On-board programming and hardware bring-up.
- Moving vendor PLL, XCVR, or PCIe Platform Designer IPs into the central
  `quartus_systems/swb/` hub.

## 2. UVM Infra (dual env)

The SWB integration TB mirrors the FEB dual-env pattern:

1. `tb_int_nominal_env` observes synthesizable payload and counter fields.
   It is the default scoreboard path and must work with DEBUG_LEVEL 0/1
   production-style builds.
2. `tb_int_debug_env` observes DEBUG_LEVEL 2 sidecar lineage at the SWB
   ingress bridge and RDMA DMA path. It explains queue residency and packet
   identity when out-of-order buffering is legal.

Both envs share `tb_int_top`, `run_window_db`, `per_bucket_ledger_scoreboard`,
and the reusable common monitors copied from the May 4 integration reference.
SWB-specific bind interfaces live under `tb_int/uvm/swb_rdma_pretest/`.

### 2.1 Agents

| Agent | Direction | Role |
|---|---|---|
| `swb_runctl_agent` | active | Drives the SWB-local run-state model and records propagated state at local consumers. |
| `swb_sc_agent` | active | Models host PCIe `sc_tool` transactions over `/dev/mudaq0` into the SWB AVMM master. |
| **`host_memory_model`** | active behavioral | **Behavioral model of the PCIe host memory the rdma_subsystem talks to. Implements three address-mapped regions: (a) the Submission Queue ring, (b) the Completion Queue ring, (c) the segmented data buffer (one DMA segment per host slot). The model is an active responder on the rdma_subsystem AXI4 host master, mirroring how the real Linux mudaq driver presents host memory pages.** |
| `rdma_sqe_ingress_monitor` | passive | Samples FEB-to-SWB SQE ingress at the SWB-side `rdma_subsystem` boundary (the SUPERCORE, NOT the inner `rdma_dma_engine` IP). |
| `rdma_cqe_egress_monitor` | passive | Samples rdma_subsystem CQE pushes into the host CQ region of the host_memory_model. |
| `opq_lane_monitor[4]` | passive | Samples one or more OPQ four-lane native_sv ingress/egress fill points. |
| `event_builder_monitor` | passive | Tracks `musip_event_builder` host-packet packing and close events. |
| `demerger_monitor` | passive | Tracks `swb_data_demerger` split/fanout accounting. |
| `pcie_x8_egress_monitor` | passive | Samples the OPQ/event-builder-to-PCIe DMA egress event path. |
| `debug_sidecar_monitor` | passive | Samples DEBUG_LEVEL 2 sidecar lineage at the rdma_subsystem supercore boundary (not at individual sub-IPs). |

#### 2.1.1 DUT contract — rdma_subsystem SUPERCORE (NOT the old dma_engine)

The SWB tb_int DUT integration boundary is the **`rdma_subsystem` supercore**
at `mu3e-ip-cores/rdma_subsystem/`. This supercore wraps four sibling IPs
into one Qsys/AXI4 subsystem: `rdma_dma_engine`, `rdma_sq_fetcher`,
`rdma_cq_pusher`, `rdma_run_manager`. The harness MUST bind at the
supercore top-level ports listed in `rdma_subsystem/RTL_PLAN_INT.md`
section 3 (Top-level interface) — NOT at any individual sub-IP boundary,
and NOT at the legacy `dma_engine` / `dma_streaming` paths that the
Apr 27 reference build used.

Concretely:
- The SUPERCORE ingress = AVST sink for FEB-to-SWB hit_type1 SQEs
  (the same boundary that `swb_rdma_subsystem_bridge.sv` adapts).
- The SUPERCORE host master = AXI4 master that the `host_memory_model`
  must respond on. The supercore arbitrates the three internal masters
  (`sq_fetcher` reads, `dma_engine` writes, `cq_pusher` writes) onto a
  SINGLE AXI4 port to the host.
- The SUPERCORE CSR slave = BAR1 routing decoded by `rdma_subsystem_csr_decoder`,
  with the `rdma_run_manager` register file as the addressable target.

Any binding to `rdma_dma_engine` directly (legacy DMA engine path) is
NOT a valid SWB tb_int harness. The legacy DMA engine in the Apr 27
reference is a different IP and is NOT in the rdma_pretest-260511
build.

#### 2.1.2 host_memory_model contract (behavioral RDMA queues + segmented data)

The `host_memory_model` agent at `tb_int/uvm/common/host_memory_model/`
emulates the Linux host memory that the rdma_subsystem talks to via
PCIe DMA. It owns three address-mapped regions and acts as an active
responder on the supercore's AXI4 host master:

| Region | Base addr (TBD per supercore CSR) | Layout | Owned by | Purpose |
|---|---|---|---|---|
| **SQ (Submission Queue)** | `HOST_SQ_BASE` | Ring of 64-byte SQE entries (slot count `SQ_DEPTH`, default 256). Head/tail pointers shadowed in the rdma_run_manager CSR. | host_memory_model produces; rdma_sq_fetcher consumes | The host posts WQEs here; the SWB pulls SQEs and acts. |
| **CQ (Completion Queue)** | `HOST_CQ_BASE` | Ring of 16-byte CQE entries (slot count `CQ_DEPTH`, default 256). Head/tail pointers shadowed in the rdma_run_manager CSR. | rdma_cq_pusher produces; host_memory_model consumes/observes | The SWB posts completions back; host reads to know what landed. |
| **Data buffer (segmented)** | `HOST_DATA_BASE` | A pool of `N_SEGMENTS` segments (default 64), each `SEG_BYTES` (default 8 KB). Each segment is addressed by a base+stride scheme; the rdma_run_manager decides the destination segment per CQE. | rdma_dma_engine writes; host_memory_model captures | Per-event payload bytes go here. Segmented so OPQ-ordered events can spread across segments without wrap-around. |

Behavioral contract:

1. **SQ region**: `host_memory_model` exposes an injection API
   `host_post_sqe(slot_idx, sqe_bytes[63:0])` that writes a 64-byte SQE
   into the SQ ring at `HOST_SQ_BASE + slot_idx * 64`. The agent advances
   the doorbell so `rdma_sq_fetcher` notices a new WQE. Test sequences
   call `host_post_sqe` to drive a stimulus.
2. **CQ region**: the agent serves AXI4 writes from `rdma_cq_pusher` into
   `HOST_CQ_BASE + slot_idx * 16`. The agent emits an analysis port event
   on every write so the scoreboard can match against the SQE that
   produced it. The scoreboard reconciles SQE-to-CQE by sequence id.
3. **Data buffer**: the agent serves AXI4 writes from `rdma_dma_engine`
   into one of the `N_SEGMENTS` regions. The agent stores the written
   bytes per-segment and exposes a `host_segment_check(seg_idx, expected_bytes[])`
   API so the scoreboard can compare against the OPQ-emitted payload at
   the SWB upstream tap. Segments are zero-initialised at reset.
4. **AXI4 timing**: the model accepts any legal AXI4 burst size + length
   the supercore emits. Burst behaviour matches Linux DMA capabilities
   (4 KB-bounded bursts, no narrow transfers below 32 byte). The model
   inserts random small back-pressure to exercise the supercore's
   buffer + retry paths.
5. **Read-during-write**: the model supports SQE-read-then-CQE-write
   for the same logical event with overlapping AXI bursts, simulating
   the deployed PCIe behavior. The supercore must keep its three
   internal masters non-blocking.

Implementation location: `tb_int/uvm/common/host_memory_model/host_memory_model.sv`
+ `host_axi_responder.sv` + `host_memory_pkg.sv`. The agent is shared
between tb_int_nominal_env and tb_int_debug_env (a single instance, two
analysis-port consumers).

#### 2.1.3 Host execution model — NUMA-pinned polling core

The deployed `host_memory_model` represents a **single NUMA-pinned core**
on the host PC, dedicated solely to the SWB DMA workload. There is NO
interrupt path — the supercore does NOT raise PCIe MSI/MSI-X to the
host. The host core runs a tight poll loop equivalent to the production
mudaq software:

```
forever begin
    // POLL: read CQ head pointer (mmio polled, no IRQ)
    if (cq_head != prev_cq_head) begin
        // Consume new CQE(s)
        while (prev_cq_head != cq_head) begin
            cqe   = host_cq_region[prev_cq_head % CQ_DEPTH];
            seg   = cqe.segment_index;
            bytes = host_data_region[seg];
            host_record_log(cqe, bytes);              // write to record/log
            prev_cq_head = (prev_cq_head + 1) % CQ_DEPTH;
        end
    end
    // SUBMIT: post next SQE if test sequence has more work pending
    if (test_seq_has_pending_wqe) begin
        host_post_sqe(sq_tail, test_seq.next_wqe);
        sq_tail = (sq_tail + 1) % SQ_DEPTH;
    end
    // backoff: simulate a single core's poll cadence (modelled as 1-10 cycles)
    @(posedge clk);
end
```

This shape — "submit RQ, poll CQ, write log, no IRQ" — matches the
production host's CPU pinned to this work. The behavioral model
deliberately:

- Does NOT model multi-core contention; one core does all the SQ post +
  CQ poll work.
- Does NOT model IRQ latency; CQ events are detected by next-cycle
  polling, not by deferred interrupt handler.
- DOES model polling backoff (configurable 1..N cycles between two
  CQ-head reads) so the supercore's CQE-coalescing logic can be
  exercised under realistic poll cadences.
- DOES model record-write latency (configurable; default 0 cycles)
  for cases that exercise the host falling behind the SWB rate.

The poll-cadence + record-write-latency are exposed as agent config
fields so PROF cases can sweep them to match observed Mu3e teferi
software performance.

### 2.2 Scoreboard

The SWB scoreboard is a per-stage ledger:
- FEB-to-SWB SQE ingress accepted count.
- OPQ accepted, dropped, and emitted count by lane.
- Event-builder host-packet close count and byte count.
- DMA beat count, end-of-event count, and PCIe egress event count.

The BASIC smoke contract is `1/0/0` at each observed stage: one legal event,
zero errors, and zero drops. Any mismatch between nominal payload accounting and
DEBUG_LEVEL 2 sidecar lineage is a closure blocker.

### 2.3 DEBUG_LEVEL regulation per IP

| IP | DEBUG_LEVEL | Observable |
|---|:-:|---|
| `rdma_subsystem` (supercore) | 2 | SUPERCORE BOUNDARY: SQ/CQ ring per-WQE sidecar at the AVST ingress + AXI4 host-master lineage. The sub-IPs (`rdma_dma_engine`, `rdma_sq_fetcher`, `rdma_cq_pusher`, `rdma_run_manager`) are NOT separately monitored; only the supercore. |
| `ordered_priority_queue_native_sv_fixed4` | 1 | frame-level fill through page RAM occupancy and ticket FIFO |
| `musip_event_builder` | 1 | per-host packet fill |
| `swb_data_demerger` | 1 | demerger fill |
| `swb_rdma_subsystem_bridge` | 2 | per-SQE sidecar lineage at the FEB-to-SWB ingress (the adapter that feeds the supercore) |
| `hit_compactor` | 1 | compactor stage fill |
| `pcie_x8_256` | 0 | DMA endpoint; observed indirectly via `host_memory_model` AXI4 transactions |
| `a10_block` | 0 | board glue verified through neighboring observables |

Rules:
- DEBUG_LEVEL 2 is cumulative and includes DEBUG_LEVEL 1 fill observability.
- DEBUG_LEVEL 1 signals are legal in production-oriented builds.
- DEBUG_LEVEL 0 IPs are verified through upstream/downstream ledger closure.

### 2.4 Coverage

Coverage is tracked by counters and case reports:
- Run-state pair coverage and stable-window markers.
- Host slow-control read/write completion by SWB-local slave.
- SQE ingress, OPQ lane, event-builder packet, and PCIe DMA event ledgers.
- DEBUG_LEVEL 2 sidecar presence and identity match where exposed.
- Isolated, `bucket_frame`, and `all_buckets_frame` execution modes.

## 3. Test Buckets

| Bucket | RC | SC | DT | Total | Goal |
|---|---:|---:|---:|---:|---|
| BASIC | 32 | 32 | 128 | **192** | Happy-path SWB RC, SC, and DT smoke/nominal cases |
| EDGE | 32 | 32 | 128 | **192** | Legal boundaries for run-state phasing, control access, OPQ, packing, and DMA |
| ERROR | 32 | 32 | 128 | **192** | Fault injection and recovery |
| PROF | 32 | 32 | 128 | **192** | Sustained rate, queue-depth, and host-DMA performance |

### 3.1 RC (run-control)

Nominal SWB run-control is the SWB reset-link transmitter driving FEB
run-state intent while SWB-local run-control is propagated to local IPs through
the SWB-internal runctl bus.

#### 3.1.1 Pre-`RUNNING` sequence (NOMINAL = reset link)

All DT and PROF cases bring the system to `RUNNING` through the nominal
reset-link path with software-scale gaps between adjacent state writes. The
scoreboard opens the stable window only after the SWB-local state shadow and
the FEB-directed run-state intent agree.

#### 3.1.2 CSR-toggle RC fallback (LIMITED)

The SWB-local CSR-toggle path is a debug fallback for a limited subset of
BASIC and EDGE cases. It proves the fallback reaches the local run-state shadow
but does not replace the deployed reset-link path for datapath regression.

### 3.2 SC (slow-control)

#### 3.2.1 SC ingress (NOMINAL = PCIe host)

Nominal slow-control uses host PCIe `sc_tool` over `/dev/mudaq0`, then the SWB
AVMM master, then `sc_hub_v2` at SWB. All bucket cases use this path unless
they are explicitly part of the local JTAG fallback subset.

#### 3.2.2 JTAG-master SC fallback (LIMITED)

The SWB-local JTAG master is a limited debug fallback. It is used only to prove
that one identity read and one simple round-trip can be performed when the host
PCIe path is unavailable.

### 3.3 DT (datapath)

The DT bucket focuses on:
- SWB ingress from FEB-to-SWB RDMA SQEs.
- OPQ four-lane native_sv ordering and fill.
- Event-builder host-packet packing.
- RDMA host DMA push into the PCIe x8 endpoint path.
- PCIe endpoint sanity through a level-0 endpoint with the monitor bound at
  the OPQ/event-builder egress side.

## 4. Bring-up Order

1. Generate the local Qsys synthesis outputs.
2. Run BASIC B065 structural smoke against the staged synthesis tree.
3. Run the selected 22-case BASIC/EDGE/ERROR/PROF UVM shell sweep.
4. Expand BASIC RC and SC cases until the no-restart `bucket_frame` run is
   legal.
5. Add the remaining EDGE boundary cases.
6. Add the remaining ERROR recovery cases.
7. Add the remaining PROF sustained-rate cases.
8. Run `all_buckets_frame` as the final integration signoff mode.

## 5. Outputs

Expected per-run artifacts:
- `tb_int/sim/<case>/transcript` for each selected case.
- `tb_int/sim/logs/regress_selected_22.log`.
- `tb_int/DV_REPORT.md`, `tb_int/DV_COV.md`, and `tb_int/REPORT/`.
- Per-case result rows with status, evidence path, and ledger residuals.
- Future UCDB outputs under `tb_int/sim/cov/` once the full Questa harness is
  enabled.

## 6. Reuse contract

Reused from `firmware_builds/systems/system_20260504_emulator_type0/tb_int/uvm/common/`:
- `per_bucket_ledger_scoreboard`.
- `run_window_db`.
- `hit_record`, `hit_key_pkg`, and basic tap interfaces.
- Existing monitor scaffolding where the signal contract matches.

SWB-specific layer:
- `tb_int_top.sv`.
- `rdma_sqe_ingress_if.sv`.
- `rdma_cqe_egress_if.sv`.
- `opq_lane_if.sv`.
- `pcie_dma_egress_if.sv`.
- `tb_int_swb_case_model.sv`.
- `tb_int_swb_scoreboard.sv`.
- `tb_int_dual_env.sv`.
- `tb_int_base_test.sv`.
- `tb_int_smoke_test.sv`.

## 7. Implementation pointer

The first runnable target is BASIC B065. It performs a structural smoke against
the staged local synthesis tree and then checks the expected `1/0/0` per-stage
ledger closure for SWB ingress, OPQ, and PCIe-egress observables. The current
selected sweep implements 22 high-risk cases as a structural UVM shell with
passive boundary monitors. Later full-DUT simulation must enable
`TB_INT_BIND_REAL_DUT` and replace structural stimulus with live generated
hierarchy bindings without changing the selected case IDs or pass criteria.

## 8. Plan drift

When implementation diverges from this document, update the plan before adding
new evidence. This plan is the SWB integration contract for
`rdma_pretest-260511`.
